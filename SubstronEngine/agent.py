#!/usr/bin/env python3
"""
Substron Autonomous Agent Core
Designed for Apple Silicon (M2 Metal GPU) + Ollama + 2,600+ Skills Catalog.
Implements the Autonomous ReAct Loop with conversational chat, tool-calling, and clean event streams.
"""

import json
import os
import re
import subprocess
import sys
import time
from typing import Any, Dict, List, Optional
import urllib.request

# Base paths
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKILLS_DB_PATH = os.path.join(BASE_DIR, "SubstronSkills", "substron_skills.db")
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from skills_indexer import search_skills

OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://127.0.0.1:11434")
DEFAULT_MODEL = os.environ.get("SUBSTRON_MODEL", "qwen2.5-coder:7b")

class SubstronTools:
    def __init__(self, workspace_dir: str):
        self.workspace_dir = os.path.abspath(workspace_dir)

    def _resolve(self, path: str) -> str:
        if os.path.isabs(path):
            return path
        return os.path.join(self.workspace_dir, path)

    def read_file(self, path: str) -> Dict[str, Any]:
        target = self._resolve(path)
        if not os.path.exists(target):
            return {"status": "error", "error": f"File '{path}' does not exist."}
        try:
            with open(target, "r", encoding="utf-8", errors="replace") as f:
                content = f.read()
            return {"status": "success", "path": path, "content": content}
        except Exception as e:
            return {"status": "error", "error": str(e)}

    def write_file(self, path: str, content: str) -> Dict[str, Any]:
        target = self._resolve(path)
        try:
            os.makedirs(os.path.dirname(target), exist_ok=True)
            with open(target, "w", encoding="utf-8") as f:
                f.write(content)
            return {"status": "success", "path": path, "bytes_written": len(content)}
        except Exception as e:
            return {"status": "error", "error": str(e)}

    def apply_patch(self, path: str, old_str: str, new_str: str) -> Dict[str, Any]:
        target = self._resolve(path)
        if not os.path.exists(target):
            return {"status": "error", "error": f"File '{path}' does not exist."}
        try:
            with open(target, "r", encoding="utf-8") as f:
                original = f.read()
            if old_str not in original:
                return {"status": "error", "error": "Target chunk not found in file."}
            updated = original.replace(old_str, new_str, 1)
            with open(target, "w", encoding="utf-8") as f:
                f.write(updated)
            return {"status": "success", "path": path, "message": "Patch applied successfully."}
        except Exception as e:
            return {"status": "error", "error": str(e)}

    def run_command(self, command: str) -> Dict[str, Any]:
        try:
            proc = subprocess.run(
                command,
                shell=True,
                cwd=self.workspace_dir,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                timeout=60
            )
            return {
                "status": "success",
                "exit_code": proc.returncode,
                "stdout": proc.stdout[:3000],
                "stderr": proc.stderr[:3000]
            }
        except subprocess.TimeoutExpired:
            return {"status": "error", "error": "Command execution timed out (60s)."}
        except Exception as e:
            return {"status": "error", "error": str(e)}

    def list_dir(self, path: str = ".") -> Dict[str, Any]:
        target = self._resolve(path)
        if not os.path.exists(target):
            return {"status": "error", "error": f"Directory '{path}' not found."}
        try:
            entries = os.listdir(target)
            return {"status": "success", "path": path, "entries": sorted(entries)}
        except Exception as e:
            return {"status": "error", "error": str(e)}

class SubstronAgent:
    def __init__(self, workspace_dir: str, model_name: str = DEFAULT_MODEL):
        self.workspace_dir = workspace_dir
        self.tools = SubstronTools(workspace_dir)
        self.model_name = model_name

    def call_ollama(self, messages: List[Dict[str, str]]) -> str:
        url = f"{OLLAMA_URL}/api/chat"
        payload = {
            "model": self.model_name,
            "messages": messages,
            "stream": False,
            "options": {
                "temperature": 0.2
            }
        }
        req = urllib.request.Request(
            url,
            data=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json"}
        )
        with urllib.request.urlopen(req, timeout=120) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return data["message"]["content"]

    def execute_task(self, user_instruction: str, max_turns: int = 8, callback=None):
        # 1. Check if instruction is a simple conversational greeting / question
        is_greeting = bool(re.match(r"^(hi|hello|hey|who are you|help|howdy|good morning|namaste)\b", user_instruction.strip().lower()))

        # 2. Match relevant skill from the 2,600+ catalog
        skills, latency = search_skills(user_instruction, limit=1)
        active_skill = skills[0] if (skills and not is_greeting) else None
        skill_prompt = ""
        if active_skill:
            skill_path = active_skill["full_path"]
            if os.path.exists(skill_path):
                with open(skill_path, "r", encoding="utf-8", errors="replace") as f:
                    skill_prompt = f.read()

        if callback:
            callback({
                "type": "skill_matched",
                "skill": active_skill["name"] if active_skill else "General Assistant",
                "category": active_skill["category"] if active_skill else "Conversation",
                "latency_ms": latency if active_skill else 0.5,
                "description": active_skill["description"] if active_skill else "General software knowledge & dialogue.",
                "path": active_skill["full_path"] if active_skill else ""
            })

        system_prompt = f"""You are SUBSTRON, a futuristic 2050 autonomous AI software engineer and intelligent coding assistant running natively on Apple Silicon.

GUIDELINES:
1. For casual greetings, questions, or conceptual discussions (e.g. "hi", "how does this work?"):
   Respond directly and helpfully in plain text or markdown. DO NOT call tools or create files unnecessarily.
2. For coding tasks that require reading code, creating files, applying edits, or running terminal commands:
   Call the appropriate tool using a JSON block:
   ```json
   {{
     "thought": "Your internal technical reasoning",
     "tool": "read_file" | "write_file" | "apply_patch" | "run_command" | "list_dir" | "finish",
     "args": {{ ... }}
   }}
   ```
3. When the task is completed, invoke tool "finish" with an args object containing:
   - "summary": A clear, elegant, beautifully formatted markdown response explaining what you did, what was created/modified, and any test results.

AVAILABLE TOOLS:
- read_file: {{"path": "relative_path"}}
- write_file: {{"path": "relative_path", "content": "file contents"}}
- apply_patch: {{"path": "relative_path", "old_str": "...", "new_str": "..."}}
- run_command: {{"command": "shell command to run (tests, builds, etc.)"}}
- list_dir: {{"path": "."}}
- finish: {{"summary": "Your final formatted response to the user"}}

ACTIVE SKILL PLAYBOOK:
{skill_prompt[:2500] if skill_prompt else "Follow clean code, modern architecture, and standard best practices."}
"""

        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_instruction}
        ]

        collected_thoughts = []
        collected_tools = []

        for turn in range(max_turns):
            response = self.call_ollama(messages)
            messages.append({"role": "assistant", "content": response})

            # Check if model gave a tool call
            tool_call = self._extract_json(response)
            
            # If no tool call, it is a direct conversational response
            if not tool_call or "tool" not in tool_call:
                clean_text = self._strip_json_blocks(response)
                if callback:
                    callback({
                        "type": "assistant_message",
                        "content": clean_text,
                        "thoughts": collected_thoughts,
                        "tool_calls": collected_tools
                    })
                return clean_text

            tool_name = tool_call.get("tool")
            args = tool_call.get("args", {})
            thought = tool_call.get("thought", "")

            if thought:
                collected_thoughts.append(thought)
                if callback:
                    callback({
                        "type": "agent_thought",
                        "thought": thought,
                        "turn": turn + 1
                    })

            collected_tools.append({"tool": tool_name, "args": args})
            if callback:
                callback({
                    "type": "tool_call",
                    "thought": thought,
                    "tool": tool_name,
                    "args": args,
                    "turn": turn + 1
                })

            if tool_name == "finish":
                final_summary = args.get("summary", "Task completed.")
                if callback:
                    callback({
                        "type": "assistant_message",
                        "content": final_summary,
                        "thoughts": collected_thoughts,
                        "tool_calls": collected_tools
                    })
                return final_summary

            # Execute tool
            obs = self._dispatch_tool(tool_name, args)
            if callback:
                callback({
                    "type": "observation",
                    "tool": tool_name,
                    "observation": obs
                })

            messages.append({
                "role": "user",
                "content": f"OBSERVATION from {tool_name}:\n{json.dumps(obs, indent=2)}"
            })

        fallback = "Completed execution across maximum allowed turns."
        if callback:
            callback({
                "type": "assistant_message",
                "content": fallback,
                "thoughts": collected_thoughts,
                "tool_calls": collected_tools
            })
        return fallback

    def _dispatch_tool(self, tool_name: str, args: Dict[str, Any]) -> Dict[str, Any]:
        if tool_name == "read_file":
            return self.tools.read_file(args.get("path", ""))
        elif tool_name == "write_file":
            return self.tools.write_file(args.get("path", ""), args.get("content", ""))
        elif tool_name == "apply_patch":
            return self.tools.apply_patch(args.get("path", ""), args.get("old_str", ""), args.get("new_str", ""))
        elif tool_name == "run_command":
            return self.tools.run_command(args.get("command", ""))
        elif tool_name == "list_dir":
            return self.tools.list_dir(args.get("path", "."))
        else:
            return {"status": "error", "error": f"Unknown tool: '{tool_name}'"}

    def _extract_json(self, text: str) -> Optional[Dict[str, Any]]:
        chunk = text
        if "```json" in text:
            start = text.find("```json") + 7
            end = text.find("```", start)
            if end != -1:
                chunk = text[start:end].strip()
        elif "```" in text:
            start = text.find("```") + 3
            end = text.find("```", start)
            if end != -1:
                chunk = text[start:end].strip()

        try:
            return json.loads(chunk)
        except Exception:
            pass

        try:
            fixed = re.sub(
                r'("content"\s*:\s*)"""(.*?)"""',
                lambda m: m.group(1) + json.dumps(m.group(2)),
                chunk,
                flags=re.DOTALL
            )
            return json.loads(fixed)
        except Exception:
            pass

        s = chunk.find("{")
        e = chunk.rfind("}")
        if s != -1 and e != -1 and e > s:
            sub = chunk[s:e+1]
            try:
                return json.loads(sub)
            except Exception:
                try:
                    fixed = re.sub(
                        r'("content"\s*:\s*)"""(.*?)"""',
                        lambda m: m.group(1) + json.dumps(m.group(2)),
                        sub,
                        flags=re.DOTALL
                    )
                    return json.loads(fixed)
                except Exception:
                    pass
        return None

    def _strip_json_blocks(self, text: str) -> str:
        # Removes ```json blocks if present in pure text
        cleaned = re.sub(r"```(json)?\s*\{.*?\}\s*```", "", text, flags=re.DOTALL).strip()
        return cleaned if cleaned else text
