import Foundation

class CodexSession: AgentSession {
    private var process: Process?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private var lineBuffer = ""
    private(set) var isRunning = false
    private(set) var isBusy = false
    static var binaryPath: String?
    private var sawAssistantMessageThisTurn = false

    var onText: ((String) -> Void)?
    var onError: ((String) -> Void)?
    var onToolUse: ((String, [String: Any]) -> Void)?
    var onToolResult: ((String, Bool) -> Void)?
    var onSessionReady: (() -> Void)?
    var onTurnComplete: (() -> Void)?
    var onProcessExit: (() -> Void)?

    var history: [AgentMessage] = []

    private static func workspaceURL() -> URL {
        let fm = FileManager.default
        let base = fm.homeDirectoryForCurrentUser
            .appendingPathComponent(".local", isDirectory: true)
            .appendingPathComponent("share", isDirectory: true)
            .appendingPathComponent("fliggy-agents", isDirectory: true)
            .appendingPathComponent("codex-chat", isDirectory: true)
        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    // MARK: - Lifecycle

    func start() {
        if Self.binaryPath != nil {
            isRunning = true
            onSessionReady?()
            return
        }

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        ShellEnvironment.findBinary(name: "codex", fallbackPaths: [
            "\(home)/.local/bin/codex",
            "\(home)/.npm-global/bin/codex",
            "/usr/local/bin/codex",
            "/opt/homebrew/bin/codex"
        ]) { [weak self] path in
            guard let self = self, let binaryPath = path else {
                let msg = "Codex CLI not found.\n\n\(AgentProvider.codex.installInstructions)"
                self?.onError?(msg)
                self?.history.append(AgentMessage(role: .error, text: msg))
                return
            }
            Self.binaryPath = binaryPath
            self.isRunning = true
            self.onSessionReady?()
        }
    }

    func send(message: String) {
        guard isRunning, let binaryPath = Self.binaryPath else { return }
        isBusy = true
        sawAssistantMessageThisTurn = false
        history.append(AgentMessage(role: .user, text: message))
        lineBuffer = ""

        // Current Codex CLI: only `codex exec [OPTIONS] <PROMPT>` (resume/--last removed).
        let prompt = Self.execPrompt(priorMessages: history.dropLast(), latestUserMessage: message)

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binaryPath)

        proc.arguments = [
            "exec",
            "--json",
            "--sandbox", "read-only",
            "--skip-git-repo-check",
            "--ephemeral",
            prompt
        ]

        proc.currentDirectoryURL = Self.workspaceURL()
        var env = ShellEnvironment.processEnvironment(extraPaths: [
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".npm-global/bin").path
        ])
        env.removeValue(forKey: "CODEX_THREAD_ID")
        env.removeValue(forKey: "CODEX_SHELL")
        env.removeValue(forKey: "CODEX_INTERNAL_ORIGINATOR_OVERRIDE")
        proc.environment = env

        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        proc.terminationHandler = { [weak self] p in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.process = nil
                // Flush remaining buffer
                if !self.lineBuffer.isEmpty {
                    self.parseLine(self.lineBuffer)
                    self.lineBuffer = ""
                }
                if self.isBusy {
                    self.isBusy = false
                    self.onTurnComplete?()
                }
            }
        }

        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            if let text = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self?.processOutput(text)
                }
            }
        }

        errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            if let text = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self?.processErrorOutput(text)
                }
            }
        }

        do {
            try proc.run()
            process = proc
            outputPipe = outPipe
            errorPipe = errPipe
        } catch {
            isBusy = false
            let msg = "Failed to launch Codex CLI: \(error.localizedDescription)"
            onError?(msg)
            history.append(AgentMessage(role: .error, text: msg))
        }
    }

    func terminate() {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil
        process?.terminate()
        process = nil
        isRunning = false
        isBusy = false
    }

    // MARK: - Prompt (multi-turn without codex exec resume)

    private static func execPrompt(priorMessages: ArraySlice<AgentMessage>, latestUserMessage: String) -> String {
        let preamble = """
        You are a chat-only desktop assistant.
        Reply conversationally and directly to the user.
        Your tone is warm, relaxed, playful, and lightly bro-y, like "hey bro" energy.
        Sound like a smart close friend chatting casually, not a formal assistant.
        Use natural spoken language, short-to-medium replies, and occasional phrases like "hey bro", "yo", "got you", or "for sure" when they fit naturally.
        Stay clear and helpful, and avoid sounding cringe, salesy, or overdoing the slang.
        Do not inspect files, read workspace docs, run shell commands, or use tools unless the user explicitly asks you to.
        Assume there is no project context unless the user provides it in the chat.
        Keep normal chat replies concise.
        """

        guard !priorMessages.isEmpty else {
            return """
            \(preamble)

            User: \(latestUserMessage)
            """
        }
        var parts: [String] = []
        for m in priorMessages {
            switch m.role {
            case .user:
                parts.append("User: \(m.text)")
            case .assistant:
                parts.append("Assistant: \(m.text)")
            case .toolUse:
                parts.append("Tool: \(m.text)")
            case .toolResult:
                parts.append("Tool result: \(m.text)")
            case .error:
                parts.append("Error: \(m.text)")
            }
        }
        return """
        \(preamble)

        Conversation so far (for context; respond only to the follow-up):

        \(parts.joined(separator: "\n\n"))

        ---

        User (follow-up): \(latestUserMessage)
        """
    }

    private func processErrorOutput(_ text: String) {
        let filtered = text
            .components(separatedBy: .newlines)
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { return false }
                if trimmed.contains("unknown feature key in config") { return false }
                if trimmed.contains("migration 19 was previously applied") { return false }
                if trimmed.contains("Failed to delete shell snapshot") { return false }
                if trimmed.contains("retrying sampling request") { return false }
                return true
            }
            .joined(separator: "\n")

        guard !filtered.isEmpty else { return }
        onError?(filtered)
    }

    // MARK: - JSONL Parsing

    private func processOutput(_ text: String) {
        lineBuffer += text
        while let newlineRange = lineBuffer.range(of: "\n") {
            let line = String(lineBuffer[lineBuffer.startIndex..<newlineRange.lowerBound])
            lineBuffer = String(lineBuffer[newlineRange.upperBound...])
            if !line.isEmpty {
                parseLine(line)
            }
        }
    }

    private func parseLine(_ line: String) {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        let type = json["type"] as? String ?? ""

        switch type {
        case "thread.started":
            break // session tracking handled by codex internally

        case "item.started":
            if let item = json["item"] as? [String: Any] {
                let itemType = item["type"] as? String ?? ""
                if itemType == "command_execution" {
                    let command = item["command"] as? String ?? ""
                    history.append(AgentMessage(role: .toolUse, text: "Bash: \(command)"))
                    onToolUse?("Bash", ["command": command])
                }
            }

        case "item.completed":
            if let item = json["item"] as? [String: Any] {
                let itemType = item["type"] as? String ?? ""
                switch itemType {
                case "agent_message":
                    let text = item["text"] as? String ?? ""
                    if !text.isEmpty {
                        sawAssistantMessageThisTurn = true
                        history.append(AgentMessage(role: .assistant, text: text))
                        onText?(text)
                    }
                case "command_execution":
                    let status = item["status"] as? String ?? ""
                    let command = item["command"] as? String ?? ""
                    let isError = status == "failed"
                    let summary = command.isEmpty ? status : String(command.prefix(80))
                    history.append(AgentMessage(role: .toolResult, text: isError ? "ERROR: \(summary)" : summary))
                    onToolResult?(summary, isError)
                case "file_change":
                    let path = item["file"] as? String ?? item["path"] as? String ?? "file"
                    history.append(AgentMessage(role: .toolUse, text: "FileChange: \(path)"))
                    onToolUse?("FileChange", ["file_path": path])
                    history.append(AgentMessage(role: .toolResult, text: path))
                    onToolResult?(path, false)
                default:
                    break
                }
            }

        case "turn.completed":
            isBusy = false
            onTurnComplete?()

        case "turn.failed":
            isBusy = false
            let msg = json["message"] as? String ?? "Turn failed"
            onError?(msg)
            history.append(AgentMessage(role: .error, text: msg))
            onTurnComplete?()

        case "error":
            let msg = json["message"] as? String ?? json["error"] as? String ?? "Unknown error"
            onError?(msg)
            history.append(AgentMessage(role: .error, text: msg))

        default:
            break
        }
    }
}

final class CodexSkillRunner {
    private var process: Process?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private var lineBuffer = ""
    private(set) var isBusy = false

    var onText: ((String) -> Void)?
    var onError: ((String) -> Void)?
    var onToolUse: ((String, [String: Any]) -> Void)?
    var onToolResult: ((String, Bool) -> Void)?
    var onTurnComplete: (() -> Void)?

    func run(skills: [SkillDefinition], prompt: String, workspaceURL: URL) {
        guard !skills.isEmpty else {
            onError?("No skills selected.")
            onTurnComplete?()
            return
        }

        guard let binaryPath = resolveBinaryPath() else {
            onError?("Codex CLI not found. Install it first with `npm install -g @openai/codex`.")
            onTurnComplete?()
            return
        }

        isBusy = true
        lineBuffer = ""

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binaryPath)
        proc.arguments = [
            "exec",
            "--json",
            "--sandbox", "workspace-write",
            "--ask-for-approval", "never",
            "--skip-git-repo-check",
            "--cd", workspaceURL.path,
            buildPrompt(skills: skills, userPrompt: prompt, workspaceURL: workspaceURL)
        ]

        var env = ShellEnvironment.processEnvironment(extraPaths: [
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".npm-global/bin").path
        ])
        env.removeValue(forKey: "CODEX_THREAD_ID")
        env.removeValue(forKey: "CODEX_SHELL")
        env.removeValue(forKey: "CODEX_INTERNAL_ORIGINATOR_OVERRIDE")
        proc.environment = env
        proc.currentDirectoryURL = workspaceURL

        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        proc.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.process = nil
                if !self.lineBuffer.isEmpty {
                    self.parseLine(self.lineBuffer)
                    self.lineBuffer = ""
                }
                if self.isBusy {
                    self.isBusy = false
                    self.onTurnComplete?()
                }
            }
        }

        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            guard let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                self?.processOutput(text)
            }
        }

        errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            guard let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                self?.processErrorOutput(text)
            }
        }

        do {
            try proc.run()
            process = proc
            outputPipe = outPipe
            errorPipe = errPipe
        } catch {
            isBusy = false
            onError?("Failed to launch Codex skill runner: \(error.localizedDescription)")
            onTurnComplete?()
        }
    }

    func terminate() {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil
        process?.terminate()
        process = nil
        isBusy = false
    }

    private func resolveBinaryPath() -> String? {
        if let cached = CodexSession.binaryPath {
            return cached
        }

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let semaphore = DispatchSemaphore(value: 0)
        var resolved: String?

        ShellEnvironment.findBinary(name: "codex", fallbackPaths: [
            "\(home)/.local/bin/codex",
            "\(home)/.npm-global/bin/codex",
            "/usr/local/bin/codex",
            "/opt/homebrew/bin/codex"
        ]) { path in
            resolved = path
            semaphore.signal()
        }

        semaphore.wait()
        if let resolved {
            CodexSession.binaryPath = resolved
        }
        return resolved
    }

    private func buildPrompt(skills: [SkillDefinition], userPrompt: String, workspaceURL: URL) -> String {
        let sections = skills.map { skill -> String in
            let body = (try? String(contentsOf: skill.fileURL)) ?? "Skill file could not be read."
            return """
            ## Skill: \(skill.name)
            Path: \(skill.fileURL.path)
            Description: \(skill.description)

            \(body)
            """
        }.joined(separator: "\n\n")

        let skillNames = skills.map(\.name).joined(separator: ", ")
        return """
        You are running inside fliggy agents as a local skills agent.
        Execute the requested work using the provided Codex skill instructions.

        Active workspace: \(workspaceURL.path)
        Requested skills: \(skillNames)

        Rules:
        - Treat the skill files below as active instructions for this run.
        - Work directly in the active workspace when the request calls for code or file changes.
        - Use tools and shell commands when helpful.
        - Be concise but include a clear final outcome summary.
        - If a skill references another skill, follow that instruction too when possible.

        \(sections)

        ## User Request
        \(userPrompt)
        """
    }

    private func processErrorOutput(_ text: String) {
        let filtered = text
            .components(separatedBy: .newlines)
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { return false }
                if trimmed.contains("unknown feature key in config") { return false }
                if trimmed.contains("migration 19 was previously applied") { return false }
                if trimmed.contains("Failed to delete shell snapshot") { return false }
                if trimmed.contains("retrying sampling request") { return false }
                return true
            }
            .joined(separator: "\n")

        guard !filtered.isEmpty else { return }
        onError?(filtered)
    }

    private func processOutput(_ text: String) {
        lineBuffer += text
        while let newlineRange = lineBuffer.range(of: "\n") {
            let line = String(lineBuffer[lineBuffer.startIndex..<newlineRange.lowerBound])
            lineBuffer = String(lineBuffer[newlineRange.upperBound...])
            if !line.isEmpty {
                parseLine(line)
            }
        }
    }

    private func parseLine(_ line: String) {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        let type = json["type"] as? String ?? ""

        switch type {
        case "item.started":
            if let item = json["item"] as? [String: Any],
               (item["type"] as? String ?? "") == "command_execution" {
                let command = item["command"] as? String ?? ""
                onToolUse?("Bash", ["command": command])
            }

        case "item.completed":
            if let item = json["item"] as? [String: Any] {
                let itemType = item["type"] as? String ?? ""
                switch itemType {
                case "agent_message":
                    let text = item["text"] as? String ?? ""
                    if !text.isEmpty {
                        onText?(text)
                    }
                case "command_execution":
                    let status = item["status"] as? String ?? ""
                    let command = item["command"] as? String ?? ""
                    let isError = status == "failed"
                    let summary = command.isEmpty ? status : String(command.prefix(100))
                    onToolResult?(summary, isError)
                case "file_change":
                    let path = item["file"] as? String ?? item["path"] as? String ?? "file"
                    onToolUse?("FileChange", ["file_path": path])
                    onToolResult?(path, false)
                default:
                    break
                }
            }

        case "turn.completed":
            isBusy = false
            onTurnComplete?()

        case "turn.failed":
            isBusy = false
            onError?(json["message"] as? String ?? "Skill run failed")
            onTurnComplete?()

        case "error":
            onError?(json["message"] as? String ?? json["error"] as? String ?? "Unknown skill runner error")

        default:
            break
        }
    }
}
