import SwiftUI

public struct ContentView: View {
    @ObservedObject var vm: SubstronViewModel
    @State private var expandedThoughtIds: Set<UUID> = []

    public init(vm: SubstronViewModel) {
        self.vm = vm
    }

    public var body: some View {
        NavigationSplitView {
            // LEFT SIDEBAR: Workspace & Skills Explorer
            sidebarView
                .navigationSplitViewColumnWidth(min: 250, ideal: 280, max: 320)
        } content: {
            // CENTER: 2050 Conversational AI Interface
            chatCanvasView
        } detail: {
            // RIGHT: Agent Brain HUD, Skill Intel & M2 Telemetry
            inspectorHUDView
                .navigationSplitViewColumnWidth(min: 300, ideal: 340, max: 420)
        }
        .frame(minWidth: 1100, minHeight: 720)
    }

    // MARK: - SIDEBAR: 2.6K SKILLS EXPLORER
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Logo Branding
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 30, height: 30)
                    Image(systemName: "cpu.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 15, weight: .bold))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("SUBSTRON")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                    Text("2050 SILICON AGENT")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.cyan)
                }
            }
            .padding(.top, 14)
            .padding(.horizontal, 14)

            Divider()

            // Workspace
            VStack(alignment: .leading, spacing: 4) {
                Label("WORKSPACE", systemImage: "folder.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                Text(vm.workspacePath)
                    .font(.system(size: 10, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(6)
            }
            .padding(.horizontal, 14)

            // Skills Search Header
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("SKILLS REPO", systemImage: "bolt.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("2,689 READY")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundColor(.cyan)
                }

                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 11))
                    TextField("Search skills...", text: $vm.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .onSubmit {
                            vm.searchSkills(query: vm.searchQuery)
                        }
                    if vm.searchLatency > 0 {
                        Text("\(String(format: "%.1f", vm.searchLatency))ms")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                    }
                }
                .padding(6)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            .padding(.horizontal, 14)

            // Skills List
            List(vm.skills, id: \.id) { skill in
                Button(action: {
                    vm.selectedSkillForDetail = skill
                    vm.inspectorTab = 1 // Switch to Skill Intel
                }) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(skill.name)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Spacer()
                            Text(skill.category)
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.cyan.opacity(0.12))
                                .foregroundColor(.cyan)
                                .cornerRadius(4)
                        }
                        Text(skill.description)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 3)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.sidebar)
        }
    }

    // MARK: - CENTER: 2050 CONVERSATIONAL AI CHAT
    private var chatCanvasView: some View {
        VStack(spacing: 0) {
            // Modern Header
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(vm.isExecuting ? Color.orange : Color.green)
                        .frame(width: 7, height: 7)
                    Text(vm.isExecuting ? "AGENT ACTIVE" : "ONLINE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(vm.isExecuting ? .orange : .green)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)

                // Active Skill Tag
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.yellow)
                        .font(.system(size: 10))
                    Text("ACTIVE: \(vm.activeSkillName)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.yellow)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(6)

                Spacer()

                // Model Selector
                Picker("", selection: $vm.selectedModel) {
                    ForEach(vm.availableModels, id: \.self) { m in
                        Text(m).tag(m)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 175)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Chat ScrollView
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 20) {
                        ForEach(vm.messages) { msg in
                            chatBubble(msg)
                                .id(msg.id)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                }
                .onChange(of: vm.messages.count) {
                    if let last = vm.messages.last {
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Futuristic Command Input Bar
            HStack(spacing: 10) {
                Image(systemName: "terminal.fill")
                    .foregroundColor(.cyan)
                    .font(.system(size: 13))

                TextField("Ask anything or give a coding task...", text: $vm.promptText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .onSubmit {
                        vm.executeTask()
                    }

                Button(action: {
                    vm.executeTask()
                }) {
                    HStack(spacing: 5) {
                        if vm.isExecuting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 12))
                            Text("RUN")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(vm.isExecuting)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
        }
    }

    // MARK: - CHAT BUBBLE
    @ViewBuilder
    private func chatBubble(_ msg: ChatMessage) -> some View {
        if msg.role == .user {
            // User Message (Right Aligned)
            HStack {
                Spacer()
                Text(msg.content)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(LinearGradient(colors: [Color.cyan.opacity(0.4), Color.blue.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cyan.opacity(0.5), lineWidth: 1))
                    .frame(maxWidth: 580, alignment: .trailing)
            }
        } else {
            // Assistant Message (Left Aligned, Clean & Formatted)
            HStack(alignment: .top, spacing: 12) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.cyan, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 32, height: 32)
                    Image(systemName: "atom")
                        .foregroundColor(.white)
                        .font(.system(size: 16))
                }

                VStack(alignment: .leading, spacing: 8) {
                    // Collapsible Reasoning Pill if agent did internal work
                    if !msg.thoughts.isEmpty || !msg.toolActions.isEmpty {
                        let isExpanded = expandedThoughtIds.contains(msg.id)
                        Button(action: {
                            if isExpanded {
                                expandedThoughtIds.remove(msg.id)
                            } else {
                                expandedThoughtIds.insert(msg.id)
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "brain.head.profile")
                                    .foregroundColor(.cyan)
                                    .font(.system(size: 10))
                                Text(msg.toolActions.isEmpty ? "Agent Reasoning Process" : "Reasoned & Executed \(msg.toolActions.count) Actions")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.cyan)
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.cyan.opacity(0.12))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)

                        if isExpanded {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(msg.thoughts, id: \.self) { th in
                                    Text("• \(th)")
                                        .font(.system(size: 11, design: .serif))
                                        .foregroundColor(.secondary)
                                }
                                ForEach(msg.toolActions) { act in
                                    HStack {
                                        Image(systemName: "wrench.fill")
                                            .foregroundColor(.orange)
                                            .font(.system(size: 9))
                                        Text("\(act.tool): \(act.details)")
                                            .font(.system(size: 10, design: .monospaced))
                                            .lineLimit(1)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(10)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                            .cornerRadius(8)
                        }
                    }

                    // Main Readable Content
                    if msg.isStreaming && msg.content.isEmpty {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Substron is synthesizing code...")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    } else {
                        Text(LocalizedStringKey(msg.content))
                            .font(.system(size: 13, weight: .regular))
                            .lineSpacing(4)
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - RIGHT INSPECTOR: AGENT HUD, SKILL INTEL, M2 SILICON
    private var inspectorHUDView: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Segmented Tab Picker
            Picker("", selection: $vm.inspectorTab) {
                Text("🧠 AGENT HUD").tag(0)
                Text("⚡ SKILL INTEL").tag(1)
                Text("📊 M2 SILICON").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.top, 10)
            .padding(.horizontal, 12)

            Divider()

            if vm.inspectorTab == 0 {
                // TAB 0: AGENT HUD
                agentHUDTab
            } else if vm.inspectorTab == 1 {
                // TAB 1: SKILL INTEL
                skillIntelTab
            } else {
                // TAB 2: M2 SILICON TELEMETRY
                m2SiliconTab
            }

            Spacer()
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    // TAB 0: Agent HUD
    private var agentHUDTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("LIVE REASONING MATRIX", systemImage: "waveform.path.ecg")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if vm.liveThoughts.isEmpty && vm.liveToolActions.isEmpty {
                        Text("No active execution. Send a task to inspect live agent reasoning.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.top, 40)
                    } else {
                        ForEach(vm.liveThoughts, id: \.self) { th in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Image(systemName: "brain.head.profile")
                                        .foregroundColor(.cyan)
                                    Text("THOUGHT")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundColor(.cyan)
                                }
                                Text(th)
                                    .font(.system(size: 11, design: .serif))
                                    .foregroundColor(.secondary)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
                            .cornerRadius(6)
                        }

                        ForEach(vm.liveToolActions) { act in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Image(systemName: "wrench.and.screwdriver.fill")
                                        .foregroundColor(.orange)
                                    Text("ACTION: \(act.tool)")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundColor(.orange)
                                    Spacer()
                                    Text(act.status.uppercased())
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(act.status == "success" ? .green : .orange)
                                }
                                Text(act.details)
                                    .font(.system(size: 9, design: .monospaced))
                                    .lineLimit(3)
                                    .foregroundColor(.secondary)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.08))
                            .cornerRadius(6)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
    }

    // TAB 1: Skill Intel
    private var skillIntelTab: some View {
        let skillToShow = vm.selectedSkillForDetail
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("SKILL INTELLIGENCE", systemImage: "sparkles")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.yellow)
                Spacer()
                Text("2,689 CATALOG")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(skillToShow?.name ?? vm.activeSkillName)
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(.primary)

                HStack {
                    Text(skillToShow?.category ?? vm.activeSkillCategory)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.yellow.opacity(0.15))
                        .foregroundColor(.yellow)
                        .cornerRadius(4)

                    Text("RISK: SAFE")
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                }

                Divider()

                Text("DESCRIPTION & RUNBOOK:")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)

                ScrollView {
                    Text(skillToShow?.description ?? vm.activeSkillDescription)
                        .font(.system(size: 11))
                        .lineSpacing(3)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
        }
        .padding(.horizontal, 14)
    }

    // TAB 2: M2 Silicon Telemetry
    private var m2SiliconTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("APPLE SILICON TELEMETRY", systemImage: "gauge.with.needle.fill")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(vm.telemetry.chip)
                            .font(.system(size: 13, weight: .bold))
                        Text("Metal GPU Inference Engine")
                            .font(.system(size: 9))
                            .foregroundColor(.green)
                    }
                    Spacer()
                    Text("100% LOCAL")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                }

                Divider()

                // RAM Gauge
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Unified Memory:")
                            .font(.system(size: 10))
                        Spacer()
                        Text("\(String(format: "%.1f", vm.telemetry.ram_used_gb)) / \(String(format: "%.0f", vm.telemetry.ram_total_gb)) GB")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                    }
                    ProgressView(value: vm.telemetry.ram_used_gb, total: vm.telemetry.ram_total_gb)
                        .progressViewStyle(.linear)
                        .tint(.cyan)
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("ACTIVE MODEL")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                    Text(vm.selectedModel)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
        }
        .padding(.horizontal, 14)
    }
}
