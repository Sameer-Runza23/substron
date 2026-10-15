import Foundation
import Combine

@MainActor
public class SubstronViewModel: ObservableObject {
    @Published public var skills: [SkillModel] = []
    @Published public var searchQuery: String = "docker"
    @Published public var searchLatency: Double = 0.0

    @Published public var activeSkillName: String = "General Assistant"
    @Published public var activeSkillCategory: String = "Conversation"
    @Published public var activeSkillDescription: String = "General software engineering and reasoning."
    @Published public var activeSkillPath: String = ""

    @Published public var selectedSkillForDetail: SkillModel?

    // Clean conversational chat messages
    @Published public var messages: [ChatMessage] = []

    // Live Technical Telemetry for the Right Inspector Panel
    @Published public var liveThoughts: [String] = []
    @Published public var liveToolActions: [ToolActionItem] = []
    @Published public var inspectorTab: Int = 0 // 0: Agent HUD, 1: Skill Intel, 2: M2 Silicon

    @Published public var telemetry: TelemetryModel = TelemetryModel(
        ram_used_gb: 9.4,
        ram_total_gb: 16.0,
        chip: "Apple M2 Pro (Metal GPU)",
        status: "Online"
    )
    @Published public var workspacePath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("SubstronWorkspace").path
        if !FileManager.default.fileExists(atPath: home) {
            try? FileManager.default.createDirectory(atPath: home, withIntermediateDirectories: true)
        }
        return home
    }()
    @Published public var promptText: String = ""
    @Published public var isExecuting: Bool = false
    @Published public var selectedModel: String = "qwen2.5-coder:7b"
    @Published public var availableModels: [String] = ["qwen2.5-coder:7b", "qwen2.5-coder:1.5b"]

    private var webSocketTask: URLSessionWebSocketTask?
    private var timer: Timer?

    public init() {
        fetchStatus()
        searchSkills(query: "docker")
        startTelemetryPolling()

        // Welcome message
        messages.append(ChatMessage(
            role: .assistant,
            content: "Hello! I am **Substron**, your 2050 autonomous coding agent running locally on Apple Silicon. I have **2,689 skills** ready on bare metal. How can I assist you with your project today?",
            thoughts: [],
            toolActions: [],
            activeSkillName: "General Assistant",
            activeSkillCategory: "Ready"
        ))
    }

    public func startTelemetryPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fetchStatus()
            }
        }
    }

    public func fetchStatus() {
        guard let url = URL(string: "http://127.0.0.1:8000/api/status") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let data = data, error == nil else { return }
            do {
                let res = try JSONDecoder().decode(StatusResponse.self, from: data)
                Task { @MainActor [weak self] in
                    self?.telemetry = res.telemetry
                }
            } catch {}
        }.resume()
    }

    public func searchSkills(query: String) {
        guard !query.isEmpty else { return }
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "http://127.0.0.1:8000/api/skills?q=\(encoded)&limit=30") else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let data = data, error == nil else { return }
            do {
                let res = try JSONDecoder().decode(SkillsSearchResponse.self, from: data)
                Task { @MainActor [weak self] in
                    self?.skills = res.skills
                    self?.searchLatency = res.latency_ms
                }
            } catch {}
        }.resume()
    }

    public func executeTask() {
        let text = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        promptText = ""
        isExecuting = true
        liveThoughts.removeAll()
        liveToolActions.removeAll()

        // 1. Add user message
        messages.append(ChatMessage(role: .user, content: text))

        // 2. Prepare streaming assistant placeholder
        let assistantMsg = ChatMessage(
            role: .assistant,
            content: "",
            thoughts: [],
            toolActions: [],
            isStreaming: true
        )
        messages.append(assistantMsg)

        connectWebSocketAndSend(instruction: text)
    }

    private func connectWebSocketAndSend(instruction: String) {
        guard let url = URL(string: "ws://127.0.0.1:8000/ws/agent") else { return }
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()

        listenWebSocket()

        let payload: [String: Any] = [
            "instruction": instruction,
            "workspace_dir": workspacePath,
            "model": selectedModel
        ]

        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let str = String(data: data, encoding: .utf8) {
            webSocketTask?.send(.string(str)) { error in
                if let error = error {
                    print("WS send error: \(error)")
                }
            }
        }
    }

    private func listenWebSocket() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .failure(let error):
                Task { @MainActor [weak self] in
                    self?.isExecuting = false
                    if let lastIdx = self?.messages.indices.last {
                        self?.messages[lastIdx].isStreaming = false
                        if self?.messages[lastIdx].content.isEmpty == true {
                            self?.messages[lastIdx].content = "Encountered a connection error with local daemon: \(error.localizedDescription)"
                        }
                    }
                }
            case .success(let message):
                switch message {
                case .string(let text):
                    Task { @MainActor [weak self] in
                        self?.handleEventMessage(text)
                    }
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        Task { @MainActor [weak self] in
                            self?.handleEventMessage(text)
                        }
                    }
                @unknown default:
                    break
                }
                Task { @MainActor [weak self] in
                    self?.listenWebSocket()
                }
            }
        }
    }

    private func handleEventMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        let type = json["type"] as? String ?? "info"

        if type == "skill_matched" {
            activeSkillName = json["skill"] as? String ?? "General Assistant"
            activeSkillCategory = json["category"] as? String ?? "General"
            activeSkillDescription = json["description"] as? String ?? ""
            activeSkillPath = json["path"] as? String ?? ""

            if let lastIdx = messages.indices.last, messages[lastIdx].role == .assistant {
                messages[lastIdx].activeSkillName = activeSkillName
                messages[lastIdx].activeSkillCategory = activeSkillCategory
            }
        } else if type == "agent_thought" {
            let thought = json["thought"] as? String ?? ""
            if !thought.isEmpty {
                liveThoughts.append(thought)
                if let lastIdx = messages.indices.last, messages[lastIdx].role == .assistant {
                    messages[lastIdx].thoughts.append(thought)
                }
            }
        } else if type == "tool_call" {
            let tool = json["tool"] as? String ?? ""
            let args = json["args"]
            let argsStr = (args != nil) ? String(describing: args!) : ""
            let action = ToolActionItem(tool: tool, details: argsStr, status: "running")
            liveToolActions.append(action)

            if let lastIdx = messages.indices.last, messages[lastIdx].role == .assistant {
                messages[lastIdx].toolActions.append(action)
            }
        } else if type == "observation" {
            let tool = json["tool"] as? String ?? ""
            let obs = json["observation"]
            let obsStr = (obs != nil) ? String(describing: obs!) : ""
            // Update last tool action status
            if let lastActionIdx = liveToolActions.indices.last {
                liveToolActions[lastActionIdx] = ToolActionItem(
                    tool: tool,
                    details: obsStr,
                    status: "success"
                )
            }
            if let lastIdx = messages.indices.last, messages[lastIdx].role == .assistant,
               let lastActIdx = messages[lastIdx].toolActions.indices.last {
                messages[lastIdx].toolActions[lastActIdx] = ToolActionItem(
                    tool: tool,
                    details: obsStr,
                    status: "success"
                )
            }
        } else if type == "assistant_message" {
            let content = json["content"] as? String ?? ""
            isExecuting = false
            if let lastIdx = messages.indices.last, messages[lastIdx].role == .assistant {
                messages[lastIdx].content = content
                messages[lastIdx].isStreaming = false
            }
        } else if type == "finish" || type == "task_finished" {
            isExecuting = false
            if let lastIdx = messages.indices.last, messages[lastIdx].role == .assistant {
                messages[lastIdx].isStreaming = false
                if let summary = json["summary"] as? String, messages[lastIdx].content.isEmpty {
                    messages[lastIdx].content = summary
                }
            }
        }
    }
}
