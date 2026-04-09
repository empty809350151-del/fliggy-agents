import Foundation

class QoderSession: AgentSession {
    private var process: Process?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private var lineBuffer = ""
    private(set) var isRunning = false
    private(set) var isBusy = false
    private var didReceiveJsonLine = false
    private var streamedAssistantText = ""
    private var didStoreAssistantMessageThisTurn = false
    static var binaryPath: String?

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
            .appendingPathComponent("qoder-chat", isDirectory: true)
        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    func start() {
        if Self.binaryPath != nil {
            isRunning = true
            onSessionReady?()
            return
        }

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        ShellEnvironment.findBinary(name: "qodercli", fallbackPaths: [
            "\(home)/.local/bin/qodercli",
            "\(home)/.npm-global/bin/qodercli",
            "/usr/local/bin/qodercli",
            "/opt/homebrew/bin/qodercli"
        ]) { [weak self] path in
            guard let self = self, let binaryPath = path else {
                let msg = "Qoder CLI not found.\n\n\(AgentProvider.qoder.installInstructions)"
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
        didReceiveJsonLine = false
        didStoreAssistantMessageThisTurn = false
        lineBuffer = ""
        streamedAssistantText = ""
        history.append(AgentMessage(role: .user, text: message))

        let prompt = Self.execPrompt(priorMessages: history.dropLast(), latestUserMessage: message)
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binaryPath)
        proc.arguments = [
            "-p", prompt,
            "--output-format", "stream-json",
            "--max-turns", "1",
            "-w", Self.workspaceURL().path
        ]
        proc.currentDirectoryURL = Self.workspaceURL()
        proc.environment = ShellEnvironment.processEnvironment(extraPaths: [
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".npm-global/bin").path,
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin").path
        ])

        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        var collectedPlainText = ""

        proc.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.process = nil

                if !self.lineBuffer.isEmpty {
                    self.parseLine(self.lineBuffer)
                    self.lineBuffer = ""
                }

                if !self.didReceiveJsonLine {
                    let finalText = collectedPlainText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !finalText.isEmpty {
                        self.streamedAssistantText = finalText
                        self.onText?(finalText)
                    }
                }

                if !self.didStoreAssistantMessageThisTurn,
                   !self.streamedAssistantText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.history.append(AgentMessage(role: .assistant, text: self.streamedAssistantText.trimmingCharacters(in: .whitespacesAndNewlines)))
                    self.didStoreAssistantMessageThisTurn = true
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
                collectedPlainText += text
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
            let msg = "Failed to launch Qoder CLI: \(error.localizedDescription)"
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
        for message in priorMessages {
            switch message.role {
            case .user:
                parts.append("User: \(message.text)")
            case .assistant:
                parts.append("Assistant: \(message.text)")
            case .toolUse:
                parts.append("Tool: \(message.text)")
            case .toolResult:
                parts.append("Tool result: \(message.text)")
            case .error:
                parts.append("Error: \(message.text)")
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
                if trimmed.hasPrefix("Loaded cached auth token") { return false }
                if trimmed.hasPrefix("Resolved prompt templates") { return false }
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
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            if !didReceiveJsonLine {
                let text = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return }
                if !streamedAssistantText.isEmpty {
                    streamedAssistantText += "\n"
                }
                streamedAssistantText += text
            }
            return
        }

        didReceiveJsonLine = true
        handleJsonEvent(json)
    }

    private func handleJsonEvent(_ json: [String: Any]) {
        let type = json["type"] as? String ?? json["event"] as? String ?? ""
        let data = json["data"] as? [String: Any] ?? json

        switch type {
        case "system":
            let subtype = json["subtype"] as? String ?? ""
            if subtype == "init" {
                onSessionReady?()
            }

        case "assistant":
            let subtype = json["subtype"] as? String ?? ""
            if subtype == "message",
               let message = json["message"] as? [String: Any],
               let content = message["content"] as? [[String: Any]] {
                for block in content {
                    let blockType = block["type"] as? String ?? ""
                    if blockType == "text", let text = block["text"] as? String, !text.isEmpty {
                        streamedAssistantText += text
                        onText?(text)
                    } else if blockType == "finish",
                              let reason = block["reason"] as? String,
                              reason == "end_turn",
                              isBusy {
                        isBusy = false
                        if !streamedAssistantText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                           history.last?.text != streamedAssistantText.trimmingCharacters(in: .whitespacesAndNewlines) {
                            history.append(AgentMessage(role: .assistant, text: streamedAssistantText.trimmingCharacters(in: .whitespacesAndNewlines)))
                            didStoreAssistantMessageThisTurn = true
                        }
                        onTurnComplete?()
                    }
                }
            }

        case "assistant.message_delta", "assistant.message.chunk", "content", "text", "delta", "message":
            let text = data["deltaContent"] as? String ??
                data["text"] as? String ??
                data["content"] as? String ??
                json["text"] as? String ?? ""
            guard !text.isEmpty else { return }
            streamedAssistantText += text
            onText?(text)

        case "assistant.message", "result":
            let text = data["content"] as? String ??
                data["text"] as? String ??
                json["result"] as? String ??
                extractTextBlocks(from: json["message"] as? [String: Any]) ?? ""
            guard !text.isEmpty else { return }
            if streamedAssistantText.isEmpty {
                streamedAssistantText = text
                onText?(text)
            }

        case "assistant.tool_call", "tool_call", "function_call":
            let toolName = data["name"] as? String ?? data["tool"] as? String ?? "Tool"
            let input = data["input"] as? [String: Any] ?? data["arguments"] as? [String: Any] ?? [:]
            let summary = input["command"] as? String ?? toolName
            history.append(AgentMessage(role: .toolUse, text: "\(toolName): \(summary)"))
            onToolUse?(toolName, input)

        case "assistant.tool_result", "tool_result", "function_result":
            let output = data["output"] as? String ?? data["result"] as? String ?? data["content"] as? String ?? ""
            let isError = data["is_error"] as? Bool ?? false
            let summary = String(output.prefix(80))
            history.append(AgentMessage(role: .toolResult, text: isError ? "ERROR: \(summary)" : summary))
            onToolResult?(summary, isError)

        case "assistant.turn_end", "turn_end", "done", "complete":
            if isBusy {
                isBusy = false
                if !streamedAssistantText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   history.last?.text != streamedAssistantText.trimmingCharacters(in: .whitespacesAndNewlines) {
                    history.append(AgentMessage(role: .assistant, text: streamedAssistantText.trimmingCharacters(in: .whitespacesAndNewlines)))
                    didStoreAssistantMessageThisTurn = true
                }
                onTurnComplete?()
            }

        case "error":
            let message = data["message"] as? String ?? data["error"] as? String ?? "Unknown Qoder error"
            onError?(message)
            history.append(AgentMessage(role: .error, text: message))

        default:
            if let text = json["text"] as? String ?? json["content"] as? String, !text.isEmpty {
                streamedAssistantText += text
                onText?(text)
            }
        }
    }

    private func extractTextBlocks(from message: [String: Any]?) -> String? {
        guard let message,
              let content = message["content"] as? [[String: Any]] else { return nil }

        let text = content.compactMap { block -> String? in
            guard (block["type"] as? String) == "text" else { return nil }
            return block["text"] as? String
        }.joined()

        return text.isEmpty ? nil : text
    }
}
