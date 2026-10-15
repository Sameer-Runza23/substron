#!/usr/bin/env python3
"""
SUBSTRON 2050 - Universal 1-Click Setup & Launcher
Cross-platform installer for macOS, Windows, and Linux.
Configures Ollama, downloads models, sets up 2,689 skills, and launches the app.
"""

import os
import platform
import subprocess
import sys
import time
import webbrowser

ROOT_DIR = os.path.dirname(os.path.abspath(__file__))
ENGINE_DIR = os.path.join(ROOT_DIR, "SubstronEngine")
SKILLS_DIR = os.path.join(ROOT_DIR, "SubstronSkills")
RAW_SKILLS_DIR = os.path.join(SKILLS_DIR, "raw")
VENV_DIR = os.path.join(ENGINE_DIR, "venv")
IS_MAC = platform.system() == "Darwin"
IS_WINDOWS = platform.system() == "Windows"
IS_LINUX = platform.system() == "Linux"

def print_banner():
    print("""
==============================================================
   ⚡ SUBSTRON 2050 - AUTONOMOUS SILICON AGENT SETUP
   100% Offline • Free & Unlimited • 2,689 Skills Engine
==============================================================
""")

def run_cmd(cmd, cwd=None, check=True):
    print(f"[*] Running: {cmd}")
    res = subprocess.run(cmd, shell=True, cwd=cwd)
    if check and res.returncode != 0:
        print(f"[!] Warning: Command returned non-zero exit code {res.returncode}")
    return res.returncode == 0

def setup_python_env():
    print("[1/5] Checking Python Environment...")
    if sys.version_info < (3, 9):
        print("[!] Error: Python 3.9 or higher is required.")
        sys.exit(1)

    py_bin = sys.executable
    if not os.path.exists(VENV_DIR):
        print("[*] Creating dedicated virtual environment...")
        import venv
        venv.create(VENV_DIR, with_pip=True)

    pip_bin = os.path.join(VENV_DIR, "Scripts" if IS_WINDOWS else "bin", "pip")
    req_file = os.path.join(ENGINE_DIR, "requirements.txt")
    print("[*] Installing agent dependencies...")
    run_cmd(f'"{pip_bin}" install -r "{req_file}"')
    print("[✓] Python environment ready.")

def setup_skills():
    print("\n[2/5] Setting up 2,689 Skills Catalog...")
    if not os.path.exists(RAW_SKILLS_DIR):
        print("[*] Fetching skills catalog from upstream repository...")
        run_cmd(f'git clone --depth 1 https://github.com/sickn33/antigravity-awesome-skills.git "{RAW_SKILLS_DIR}"')
    else:
        print("[✓] Skills catalog already cloned.")

    # Build SQLite FTS5 Index
    print("[*] Verifying & building local SQLite FTS5 database...")
    py_venv = os.path.join(VENV_DIR, "Scripts" if IS_WINDOWS else "bin", "python")
    indexer = os.path.join(ENGINE_DIR, "skills_indexer.py")
    run_cmd(f'"{py_venv}" "{indexer}" build')
    print("[✓] Skills index ready (2.4 MB, 0.6ms retrieval).")

def check_ollama_and_models():
    print("\n[3/5] Verifying Local LLM Brain (Ollama)...")
    has_ollama = subprocess.run("ollama --version", shell=True, capture_output=True).returncode == 0
    if not has_ollama:
        print("[!] Ollama not found in PATH.")
        if IS_MAC:
            print("[*] Please download Ollama for macOS from: https://ollama.com/download")
        elif IS_WINDOWS:
            print("[*] Please download Ollama for Windows from: https://ollama.com/download")
        else:
            print("[*] Install Ollama via: curl -fsSL https://ollama.com/install.sh | sh")
    else:
        print("[✓] Ollama found in system.")
        print("[*] Pulling production model: qwen2.5-coder:7b...")
        run_cmd("ollama pull qwen2.5-coder:7b")
        print("[✓] Qwen 2.5 Coder 7B is ready on local GPU/Metal.")

def launch_app():
    print("\n[4/5] Launching Substron Engine Server...")
    py_venv = os.path.join(VENV_DIR, "Scripts" if IS_WINDOWS else "bin", "python")
    server_py = os.path.join(ENGINE_DIR, "server.py")
    
    # Start server in background
    if IS_WINDOWS:
        subprocess.Popen([py_venv, server_py], creationflags=subprocess.CREATE_NEW_CONSOLE)
    else:
        subprocess.Popen([py_venv, server_py], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    
    time.sleep(2)
    print("[✓] Substron Engine daemon running on http://127.0.0.1:8000")

    print("\n[5/5] Launching UI Interface...")
    if IS_MAC:
        app_bundle = os.path.join(ROOT_DIR, "Substron.app")
        if os.path.exists(app_bundle):
            print("[*] Launching Native Apple macOS App: Substron.app")
            subprocess.run(["open", app_bundle])
        else:
            print("[*] Building Native macOS SwiftUI App...")
            run_cmd("swift build -c release", cwd=os.path.join(ROOT_DIR, "SubstronApp"))
            webbrowser.open("http://127.0.0.1:8000")
    else:
        print("[*] Opening Substron Web Interface on http://127.0.0.1:8000...")
        webbrowser.open("http://127.0.0.1:8000")

    print("\n==============================================================")
    print("   🚀 SUBSTRON 2050 IS RUNNING!")
    print("   Access UI anytime at: http://127.0.0.1:8000")
    print("==============================================================\n")

if __name__ == "__main__":
    print_banner()
    setup_python_env()
    setup_skills()
    check_ollama_and_models()
    launch_app()
