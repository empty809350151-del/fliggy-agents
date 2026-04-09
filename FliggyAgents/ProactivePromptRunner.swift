import Foundation

enum ProactivePromptProvider: String, CaseIterable {
    case claude
    case codex
    case qoder
    case copilot
    case gemini
}

struct ProactivePromptResult: Equatable {
    let text: String
    let usedFallback: Bool
}

final class ProactivePromptRunner {
    typealias AvailabilityResolver = (ProactivePromptProvider) -> Bool
    typealias Executor = (_ prompt: String, _ provider: ProactivePromptProvider, _ completion: @escaping (String?) -> Void) -> Void
    private static let executionTimeout: TimeInterval = 8

    private let availabilityResolver: AvailabilityResolver
    private let executor: Executor

    init(
        availabilityResolver: @escaping AvailabilityResolver = ProactivePromptRunner.defaultAvailability,
        executor: @escaping Executor = ProactivePromptRunner.defaultExecutor
    ) {
        self.availabilityResolver = availabilityResolver
        self.executor = executor
    }

    func generate(
        prompt: String,
        provider: ProactivePromptProvider,
        fallback: String,
        completion: @escaping (ProactivePromptResult) -> Void
    ) {
        let deliver: (ProactivePromptResult) -> Void = { result in
            DispatchQueue.main.async {
                completion(result)
            }
        }

        DispatchQueue.global(qos: .utility).async { [self] in
            guard self.availabilityResolver(provider) else {
                deliver(ProactivePromptResult(text: fallback, usedFallback: true))
                return
            }

            self.executor(prompt, provider) { raw in
                let cleaned = Self.sanitize(raw)
                if let cleaned, !cleaned.isEmpty {
                    deliver(ProactivePromptResult(text: cleaned, usedFallback: false))
                } else {
                    deliver(ProactivePromptResult(text: fallback, usedFallback: true))
                }
            }
        }
    }

    private static func sanitize(_ raw: String?) -> String? {
        raw?
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func defaultAvailability(provider: ProactivePromptProvider) -> Bool {
        resolveBinary(for: provider) != nil
    }

    private static func defaultExecutor(
        prompt: String,
        provider: ProactivePromptProvider,
        completion: @escaping (String?) -> Void
    ) {
        DispatchQueue.global(qos: .utility).async {
            guard let binaryPath = resolveBinary(for: provider) else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }

            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: binaryPath)
            proc.arguments = arguments(for: provider, prompt: prompt)
            proc.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
            proc.environment = ShellEnvironment.processEnvironment(extraPaths: [
                FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".npm-global/bin").path,
                FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin").path
            ])

            let stdout = Pipe()
            let stderr = Pipe()
            proc.standardOutput = stdout
            proc.standardError = stderr

            do {
                try proc.run()
            } catch {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }

            let stateQueue = DispatchQueue(label: "fliggy-agents.proactive-prompt-runner")
            var didTimeout = false
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + Self.executionTimeout) {
                let shouldTerminate = stateQueue.sync { () -> Bool in
                    guard proc.isRunning else { return false }
                    didTimeout = true
                    return true
                }
                if shouldTerminate {
                    proc.terminate()
                }
            }

            proc.waitUntilExit()
            let output = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
            let errorOutput = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
            let combined = stateQueue.sync { () -> String? in
                guard !didTimeout else { return nil }
                return [output, errorOutput]
                    .compactMap { $0 }
                    .joined(separator: "\n")
            }

            DispatchQueue.main.async {
                completion(combined)
            }
        }
    }

    private static func resolveBinary(for provider: ProactivePromptProvider) -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let (name, fallbackPaths) = binaryDescriptor(for: provider, home: home)

        let semaphore = DispatchSemaphore(value: 0)
        var binaryPath: String?
        ShellEnvironment.findBinary(name: name, fallbackPaths: fallbackPaths) { path in
            binaryPath = path
            semaphore.signal()
        }
        semaphore.wait()
        return binaryPath
    }

    private static func binaryDescriptor(for provider: ProactivePromptProvider, home: String) -> (String, [String]) {
        switch provider {
        case .claude:
            return (
                "claude",
                [
                    "\(home)/.local/bin/claude",
                    "\(home)/.claude/local/bin/claude",
                    "/usr/local/bin/claude",
                    "/opt/homebrew/bin/claude"
                ]
            )
        case .codex:
            return (
                "codex",
                [
                    "\(home)/.local/bin/codex",
                    "\(home)/.npm-global/bin/codex",
                    "/usr/local/bin/codex",
                    "/opt/homebrew/bin/codex"
                ]
            )
        case .qoder:
            return (
                "qodercli",
                [
                    "\(home)/.local/bin/qodercli",
                    "\(home)/.npm-global/bin/qodercli",
                    "/usr/local/bin/qodercli",
                    "/opt/homebrew/bin/qodercli"
                ]
            )
        case .copilot:
            return (
                "copilot",
                [
                    "\(home)/.local/bin/copilot",
                    "\(home)/.npm-global/bin/copilot",
                    "/usr/local/bin/copilot",
                    "/opt/homebrew/bin/copilot"
                ]
            )
        case .gemini:
            return (
                "gemini",
                [
                    "\(home)/.local/bin/gemini",
                    "\(home)/.npm-global/bin/gemini",
                    "/usr/local/bin/gemini",
                    "/opt/homebrew/bin/gemini"
                ]
            )
        }
    }

    private static func arguments(for provider: ProactivePromptProvider, prompt: String) -> [String] {
        switch provider {
        case .claude:
            return ["-p", prompt]
        case .codex:
            return ["exec", "--sandbox", "read-only", "--skip-git-repo-check", "--ephemeral", prompt]
        case .qoder:
            return ["-p", prompt, "--output-format", "text", "-w", FileManager.default.homeDirectoryForCurrentUser.path]
        case .copilot:
            return ["-p", prompt, "-s", "--allow-all"]
        case .gemini:
            return ["--yolo", "-p", prompt]
        }
    }
}
