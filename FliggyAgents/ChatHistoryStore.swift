import Foundation

struct ChatThread: Codable {
    let id: UUID
    var title: String
    var titleSource: String?
    let provider: String
    var messages: [ChatHistoryMessage]
    var updatedAt: Date

    init(id: UUID = UUID(), title: String, titleSource: String? = nil, provider: String, messages: [ChatHistoryMessage], updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.titleSource = titleSource
        self.provider = provider
        self.messages = messages
        self.updatedAt = updatedAt
    }
}

struct ChatHistoryMessage: Codable {
    let role: String
    let text: String

    init(role: AgentMessage.Role, text: String) {
        switch role {
        case .user: self.role = "user"
        case .assistant: self.role = "assistant"
        case .error: self.role = "error"
        case .toolUse: self.role = "toolUse"
        case .toolResult: self.role = "toolResult"
        }
        self.text = text
    }

    var agentMessage: AgentMessage {
        let mappedRole: AgentMessage.Role
        switch role {
        case "user": mappedRole = .user
        case "assistant": mappedRole = .assistant
        case "error": mappedRole = .error
        case "toolUse": mappedRole = .toolUse
        case "toolResult": mappedRole = .toolResult
        default: mappedRole = .assistant
        }
        return AgentMessage(role: mappedRole, text: text)
    }
}

final class ChatHistoryStore {
    static let shared = ChatHistoryStore()
    static let proactiveThreadTitle = ReminderEvent.defaultInboxThreadTitle
    static let reminderProvider = "__assistant__"
    static let reminderThreadTitleSource = "assistant-reminder"

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local", isDirectory: true)
            .appendingPathComponent("share", isDirectory: true)
            .appendingPathComponent("fliggy-agents", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("chat-history.json")
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func loadThreads(for provider: AgentProvider) -> [ChatThread] {
        loadAllThreads()
            .filter { $0.provider == provider.rawValue || $0.provider == Self.reminderProvider }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func loadAllThreads() -> [ChatThread] {
        guard let data = try? Data(contentsOf: fileURL),
              let threads = try? decoder.decode([ChatThread].self, from: data) else {
            return []
        }
        return threads
    }

    func upsert(thread: ChatThread) {
        var allThreads = loadAllThreads()
        if let index = allThreads.firstIndex(where: { $0.id == thread.id }) {
            allThreads[index] = thread
        } else {
            allThreads.append(thread)
        }
        persist(allThreads)
    }

    func deleteThread(id: UUID, provider: AgentProvider) {
        var allThreads = loadAllThreads()
        allThreads.removeAll { thread in
            thread.id == id && (thread.provider == provider.rawValue || thread.provider == Self.reminderProvider)
        }
        persist(allThreads)
    }

    func loadReminderThread() -> ChatThread? {
        loadAllThreads().first {
            $0.provider == Self.reminderProvider && $0.titleSource == Self.reminderThreadTitleSource
        }
    }

    @discardableResult
    func appendReminderEvent(_ event: ReminderEvent) -> ChatThread {
        ReminderInboxStore.shared.record(event)

        let existing = loadReminderThread()
        var thread = existing ?? ChatThread(
            title: event.inboxThreadTitle,
            titleSource: Self.reminderThreadTitleSource,
            provider: Self.reminderProvider,
            messages: []
        )
        thread.title = event.inboxThreadTitle
        thread.messages.append(ChatHistoryMessage(role: .assistant, text: event.historyMessageText))
        thread.updatedAt = event.createdAt
        upsert(thread: thread)
        return thread
    }

    @discardableResult
    func appendProactiveMessage(text: String, provider: AgentProvider, date: Date = Date()) -> ChatThread {
        appendReminderEvent(
            ReminderEvent(
                kind: .careCheckIn,
                source: provider.displayName,
                deliveryKey: UUID().uuidString,
                bubbleText: text,
                fullText: text,
                createdAt: date,
                outcomes: [.delivered]
            )
        )
    }

    private func persist(_ threads: [ChatThread]) {
        let sortedThreads = threads.sorted { $0.updatedAt > $1.updatedAt }
        if let data = try? encoder.encode(sortedThreads) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}

final class ChatTitleGenerator {
    static let shared = ChatTitleGenerator()

    private let queue = DispatchQueue(label: "com.fliggyagents.chat-title-generator", qos: .utility)
    private var inflightIDs = Set<UUID>()

    func refreshTitleIfNeeded(
        for thread: ChatThread,
        using provider: AgentProvider,
        completion: @escaping (String) -> Void
    ) {
        guard shouldGenerateTitle(for: thread) else { return }

        let threadID = thread.id
        let messages = thread.messages

        queue.async { [weak self] in
            guard let self else { return }
            guard self.begin(threadID) else { return }

            defer { self.finish(threadID) }

            let prompt = Self.prompt(for: messages)
            guard let title = self.runPrompt(prompt, provider: provider) else { return }

            DispatchQueue.main.async {
                completion(title)
            }
        }
    }

    private func shouldGenerateTitle(for thread: ChatThread) -> Bool {
        if thread.titleSource == "model" { return false }
        return thread.messages.contains { $0.role == "user" && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func begin(_ id: UUID) -> Bool {
        if inflightIDs.contains(id) { return false }
        inflightIDs.insert(id)
        return true
    }

    private func finish(_ id: UUID) {
        inflightIDs.remove(id)
    }

    private func runPrompt(_ prompt: String, provider: AgentProvider) -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let (binaryName, fallbackPaths, arguments): (String, [String], [String]) = {
            switch provider {
            case .claude:
                return (
                    "claude",
                    [
                        "\(home)/.local/bin/claude",
                        "\(home)/.claude/local/bin/claude",
                        "/usr/local/bin/claude",
                        "/opt/homebrew/bin/claude"
                    ],
                    ["-p", prompt]
                )
            case .codex:
                return (
                    "codex",
                    [
                        "\(home)/.local/bin/codex",
                        "\(home)/.npm-global/bin/codex",
                        "/usr/local/bin/codex",
                        "/opt/homebrew/bin/codex"
                    ],
                    ["exec", "--sandbox", "read-only", "--skip-git-repo-check", "--ephemeral", prompt]
                )
            case .copilot:
                return (
                    "copilot",
                    [
                        "\(home)/.local/bin/copilot",
                        "\(home)/.npm-global/bin/copilot",
                        "/usr/local/bin/copilot",
                        "/opt/homebrew/bin/copilot"
                    ],
                    ["-p", prompt, "-s", "--allow-all"]
                )
            case .qoder:
                return (
                    "qodercli",
                    [
                        "\(home)/.local/bin/qodercli",
                        "\(home)/.npm-global/bin/qodercli",
                        "/usr/local/bin/qodercli",
                        "/opt/homebrew/bin/qodercli"
                    ],
                    ["-p", prompt, "--output-format", "text", "-w", home]
                )
            case .gemini:
                return (
                    "gemini",
                    [
                        "\(home)/.local/bin/gemini",
                        "\(home)/.npm-global/bin/gemini",
                        "/usr/local/bin/gemini",
                        "/opt/homebrew/bin/gemini"
                    ],
                    ["--yolo", "-p", prompt]
                )
            }
        }()

        let semaphore = DispatchSemaphore(value: 0)
        var binaryPath: String?
        ShellEnvironment.findBinary(name: binaryName, fallbackPaths: fallbackPaths) { path in
            binaryPath = path
            semaphore.signal()
        }
        semaphore.wait()

        guard let binaryPath else { return nil }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binaryPath)
        proc.arguments = arguments
        proc.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        proc.environment = ShellEnvironment.processEnvironment(extraPaths: [
            "\(home)/.npm-global/bin",
            "\(home)/.local/bin"
        ])

        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        do {
            try proc.run()
        } catch {
            return nil
        }

        proc.waitUntilExit()

        let outputData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let combined = (String(data: outputData, encoding: .utf8) ?? "")
            + "\n"
            + (String(data: errorData, encoding: .utf8) ?? "")

        return Self.sanitizeTitle(from: combined)
    }

    private static func prompt(for messages: [ChatHistoryMessage]) -> String {
        let usefulMessages = messages
            .filter { $0.role == "user" || $0.role == "assistant" }
            .prefix(8)
            .map { message in
                let role = message.role == "user" ? "User" : "Assistant"
                return "\(role): \(message.text)"
            }
            .joined(separator: "\n\n")

        return """
        Summarize this chat into a short sidebar conversation title.

        Rules:
        - Capture the topic, not the first sentence.
        - If the chat is in Chinese, return 4-12 Chinese characters.
        - Otherwise return 2-6 words.
        - No quotes.
        - No ending punctuation.
        - Return title only.

        Chat:
        \(usefulMessages)
        """
    }

    private static func sanitizeTitle(from raw: String) -> String? {
        let cleanedLines = raw
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter {
                !$0.isEmpty &&
                !$0.hasPrefix("error:") &&
                !$0.hasPrefix("Warning:") &&
                !$0.hasPrefix("warning:")
            }

        guard let first = cleanedLines.first else { return nil }

        var title = first
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'`“”‘’[](){}<> "))

        if let colon = title.firstIndex(of: ":"),
           title.distance(from: title.startIndex, to: colon) < 12 {
            let suffix = title[title.index(after: colon)...].trimmingCharacters(in: .whitespacesAndNewlines)
            if !suffix.isEmpty {
                title = suffix
            }
        }

        title = title
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if title.count > 24 {
            title = String(title.prefix(24)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return title.isEmpty ? nil : title
    }
}
