# ⚡ SUBSTRON 2050

<div align="center">

![Platform](https://img.shields.io/badge/Platform-macOS%20|%20Windows%20|%20Linux-blue?style=for-the-badge)
![Offline](https://img.shields.io/badge/Privacy-100%25%20Offline%20%26%20Local-green?style=for-the-badge)
![Skills](https://img.shields.io/badge/Skills%20Catalog-2%2C689%20Indexed-yellow?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-purple?style=for-the-badge)

### **The 2050 Autonomous Silicon Agent for Local Software Engineering**
*100% Free • Unlimited • Privacy-First • Native Apple Silicon GPU & CUDA Accelerated*

</div>

---

## 🌟 What is Substron?

**Substron** is an autonomous AI coding assistant and software engineering tool engineered to run completely on your local machine with **zero API costs**, **no rate limits**, and **complete data privacy**.

Equipped with a local index of **2,689 curated developer skills** (from the open-source `antigravity-awesome-skills` catalog), Substron automatically routes your tasks to standard production playbooks (Docker, FastAPI, Kubernetes, Security Audits, React, CI/CD, and more) in under **1 millisecond**.

---

## 🚀 Key Features

* **🧠 Local LLM Brain (Metal GPU / CUDA):** Powered by Ollama with `Qwen 2.5 Coder 7B / 14B`, delivering 30–110+ tokens/sec on Apple Silicon and modern GPUs.
* **⚡ 2,689 Developer Skills (SQLite FTS5):** Uses lightweight BM25 ranking to retrieve and progressively inject domain playbooks into context in **0.66ms** with zero RAM bloat.
* **🛠️ Autonomous Self-Healing ReAct Loop:** Substron doesn't just chat—it plans, reads codebases, writes files, applies surgical diffs, runs terminal commands (builds/tests), and self-corrects on syntax/runtime errors.
* **🍎 Native Apple macOS App (SwiftUI):** Full macOS 14+ native app with Glassmorphic 3-column NavigationSplitView, Collapsible Thought Stream, and real-time M2 Hardware Telemetry.
* **💻 Cross-Platform Web HUD (Windows & Linux):** Instant web interface served on `http://127.0.0.1:8000` so Windows and Linux developers get the exact same agent experience.

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     USER INTERFACE                          │
│   • macOS: Native SwiftUI App (Substron.app)                │
│   • Windows/Linux: Modern Dark-Mode Web HUD (Port 8000)     │
└──────────────────────────────┬──────────────────────────────┘
                               │ (WebSocket / REST IPC)
┌──────────────────────────────▼──────────────────────────────┐
│                SUBSTRON AUTONOMOUS AGENT CORE               │
│       • Conversational Router (Chat vs Action Engine)       │
│       • ReAct Planner (Plan ➔ Tool Call ➔ Observe ➔ Fix)     │
└──────────────────────────────┬──────────────────────────────┘
                               │
            ┌──────────────────┴──────────────────┐
            ▼                                     ▼
┌───────────────────────────┐       ┌───────────────────────────┐
│     SKILL ROUTER (RAG)    │       │     TOOL EXECUTION ENGINE │
│  2,689 Skills Fast Search │       │  • File Read / Write      │
│  (SQLite FTS5 BM25, 0.6ms)│       │  • Surgical Diff Patching │
└───────────┬───────────────┘       │  • Terminal / Shell Exec  │
            │                       └─────────────┬─────────────┘
            └──────────────────┬──────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│            LOCAL BRAIN (Ollama / Metal GPU / CUDA)          │
│            Qwen 2.5 Coder (7B / 14B) - 100% Offline         │
└─────────────────────────────────────────────────────────────┘
```

---

## ⚡ Quick Start (1-Click Install)

### 🍎 On macOS / 🐧 Linux:
Open your terminal and run:
```bash
git clone https://github.com/<your-username>/substron.git
cd substron
chmod +x setup.sh && ./setup.sh
```

### 🪟 On Windows:
1. Clone or download the repository.
2. Double-click **`setup.bat`** (or open PowerShell/Command Prompt and run `python setup.py`).

The setup script will automatically:
1. Initialize your isolated Python virtual environment and install dependencies.
2. Fetch and index the 2,689 skills catalog into a portable 2.4 MB SQLite database.
3. Verify Ollama and pull `qwen2.5-coder:7b`.
4. Launch the application (Native `.app` on Mac, or Web UI on Windows/Linux)!

---

## 💻 System Requirements

| Component | Minimum | Recommended (Sweet Spot) |
| :--- | :--- | :--- |
| **macOS** | Apple Silicon M1 (8GB Unified RAM) | Apple Silicon M2/M3/M4 (16GB+ RAM) |
| **Windows/Linux** | 16GB RAM + 6GB VRAM GPU | NVIDIA RTX 3060/4060+ (12GB+ VRAM) |
| **Disk Space** | ~8 GB (Model + 2.6K Skills Index) | 15 GB |

---

## 📁 Repository Structure

```
substron/
├── SubstronApp/         # Native Apple macOS App (Swift 6 / SwiftUI)
│   ├── Sources/         # ContentView, SubstronViewModel, Models
│   └── Package.swift    # Swift Package manifest (macOS 14+)
├── SubstronEngine/      # Autonomous Agent Daemon & Core
│   ├── agent.py         # Autonomous ReAct Execution Loop & Self-Healing
│   ├── server.py        # FastAPI / WebSocket Telemetry Daemon
│   ├── skills_indexer.py# 2,689 Skills SQLite FTS5 Search Engine
│   └── static/          # Cross-platform Web HUD (index.html)
├── SubstronSkills/      # Portable SQLite FTS5 database (substron_skills.db)
├── setup.py             # Universal 1-Click cross-platform installer
├── setup.sh             # macOS / Linux 1-click launcher
├── setup.bat            # Windows 1-click launcher
├── run_substron.sh      # Native macOS fast launcher
└── README.md            # Documentation
```

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
The skills catalog is sourced from [`sickn33/antigravity-awesome-skills`](https://github.com/sickn33/antigravity-awesome-skills).
