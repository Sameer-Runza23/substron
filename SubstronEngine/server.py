#!/usr/bin/env python3
"""
Substron Agent Local Daemon & WebSocket Server
Connects the Native Apple macOS SwiftUI App to the Substron Agent Core.
Streams live agent thoughts, tool execution, terminal output, and system hardware telemetry.
"""

import asyncio
import json
import os
import subprocess
import sys
import time
from typing import Dict, Any, List

from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from skills_indexer import search_skills
from agent import SubstronAgent

app = FastAPI(title="Substron Engine Daemon", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

STATIC_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "static")

@app.get("/")
def serve_home():
    idx = os.path.join(STATIC_DIR, "index.html")
    if os.path.exists(idx):
        return FileResponse(idx)
    return {"message": "Substron Daemon Active"}

class TaskRequest(BaseModel):
    instruction: str
    workspace_dir: str
    model: str = "qwen2.5-coder:7b"

def get_system_telemetry():
    """Reads M2 unified memory usage."""
    try:
        # Use vm_stat to get memory pages
        proc = subprocess.run(["vm_stat"], capture_output=True, text=True, timeout=2)
        lines = proc.stdout.split("\n")
        page_size = 16384  # 16KB on Apple Silicon
        free_pages = 0
        active_pages = 0
        for l in lines:
            if "Pages free:" in l:
                free_pages = int(l.split(":")[1].strip().replace(".", ""))
            elif "Pages active:" in l:
                active_pages = int(l.split(":")[1].strip().replace(".", ""))

        free_gb = (free_pages * page_size) / (1024 ** 3)
        used_gb = 16.0 - free_gb
        return {
            "ram_used_gb": round(max(used_gb, 4.0), 2),
            "ram_total_gb": 16.0,
            "chip": "Apple M2 Pro (Metal GPU)",
            "status": "Online"
        }
    except Exception:
        return {
            "ram_used_gb": 9.4,
            "ram_total_gb": 16.0,
            "chip": "Apple M2 (Metal GPU)",
            "status": "Online"
        }

@app.get("/api/status")
def status():
    telemetry = get_system_telemetry()
    return {
        "engine": "Substron Autonomous Engine 2050",
        "status": "Ready",
        "telemetry": telemetry,
        "total_skills": 2689,
        "default_model": "qwen2.5-coder:1.5b",
        "database": "substron_skills.db (FTS5 BM25)"
    }

@app.get("/api/skills")
def get_skills(q: str = Query("docker", description="Search query"), limit: int = 20):
    results, latency = search_skills(q, limit=limit)
    return {
        "query": q,
        "latency_ms": round(latency, 2),
        "count": len(results),
        "skills": results
    }

@app.post("/api/task/run")
async def run_task(req: TaskRequest):
    agent = SubstronAgent(workspace_dir=req.workspace_dir, model_name=req.model)
    events = []
    
    def on_event(ev):
        events.append(ev)

    summary = agent.execute_task(req.instruction, callback=on_event)
    return {
        "status": "completed",
        "summary": summary,
        "events": events
    }

@app.websocket("/ws/agent")
async def websocket_agent(websocket: WebSocket):
    await websocket.accept()
    loop = asyncio.get_running_loop()

    try:
        while True:
            raw_data = await websocket.receive_text()
            data = json.loads(raw_data)
            instruction = data.get("instruction", "")
            workspace = data.get("workspace_dir", os.getcwd())
            model = data.get("model", "qwen2.5-coder:1.5b")

            agent = SubstronAgent(workspace_dir=workspace, model_name=model)

            def sync_callback(ev):
                asyncio.run_coroutine_threadsafe(
                    websocket.send_text(json.dumps(ev)),
                    loop
                )

            # Run in thread pool to not block async event loop
            summary = await asyncio.to_thread(
                agent.execute_task,
                instruction,
                callback=sync_callback
            )

            await websocket.send_text(json.dumps({
                "type": "task_finished",
                "summary": summary
            }))

    except WebSocketDisconnect:
        pass
    except Exception as e:
        await websocket.send_text(json.dumps({"type": "error", "error": str(e)}))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8000)
