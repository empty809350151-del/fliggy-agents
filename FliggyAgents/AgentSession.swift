import Foundation

// MARK: - Provider

enum AgentProvider: String, CaseIterable {
    case claude, codex, qoder, copilot, gemini

    private static let defaultsKey = "selectedProvider"

    static var current: AgentProvider {
        get {
            let raw = UserDefaults.standard.string(forKey: defaultsKey) ?? "claude"
            return AgentProvider(rawValue: raw) ?? .claude
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey)
        }
    }

    var displayName: String {
        switch self {
        case .claude:  return "Claude"
        case .codex:   return "Codex"
        case .qoder:   return "Qoder"
        case .copilot: return "Copilot"
        case .gemini:  return "Gemini"
        }
    }

    var inputPlaceholder: String {
        "Ask \(displayName)..."
    }

    /// Returns provider name styled per theme format.
    func titleString(format: TitleFormat) -> String {
        switch format {
        case .uppercase:      return displayName.uppercased()
        case .lowercaseTilde: return "\(displayName.lowercased()) ~"
        case .capitalized:    return displayName
        }
    }

    var installInstructions: String {
        switch self {
        case .claude:
            return "To install, run this in Terminal:\n  curl -fsSL https://claude.ai/install.sh | sh\n\nOr download from https://claude.ai/download"
        case .codex:
            return "To install, run this in Terminal:\n  npm install -g @openai/codex"
        case .qoder:
            return "To install, run this in Terminal:\n  npm install -g @qoder-ai/qodercli\n\nOr on macOS/Linux:\n  brew install qoderai/qoder/qodercli --cask"
        case .copilot:
            return "To install, run this in Terminal:\n  brew install copilot-cli\n\nOr: npm install -g @github/copilot-cli"
        case .gemini:
            return "To install, run this in Terminal:\n  npm install -g @google/gemini-cli\n\nThen authenticate:\n  gemini auth"
        }
    }

    func createSession() -> any AgentSession {
        switch self {
        case .claude:  return ClaudeSession()
        case .codex:   return CodexSession()
        case .qoder:   return QoderSession()
        case .copilot: return CopilotSession()
        case .gemini:  return GeminiSession()
        }
    }
}

// MARK: - Title Format

enum TitleFormat {
    case uppercase       // "CLAUDE"
    case lowercaseTilde  // "claude ~"
    case capitalized     // "Claude"
}

// MARK: - Message

struct AgentMessage {
    enum Role { case user, assistant, error, toolUse, toolResult }
    let role: Role
    let text: String
}

// MARK: - Session Protocol

protocol AgentSession: AnyObject {
    var isRunning: Bool { get }
    var isBusy: Bool { get }
    var history: [AgentMessage] { get set }

    var onText: ((String) -> Void)? { get set }
    var onError: ((String) -> Void)? { get set }
    var onToolUse: ((String, [String: Any]) -> Void)? { get set }
    var onToolResult: ((String, Bool) -> Void)? { get set }
    var onSessionReady: (() -> Void)? { get set }
    var onTurnComplete: (() -> Void)? { get set }
    var onProcessExit: (() -> Void)? { get set }

    func start()
    func send(message: String)
    func terminate()
}

struct SkillDefinition: Equatable {
    let name: String
    let description: String
    let fileURL: URL

    var id: String {
        name.lowercased()
    }
}

struct PendingAttachment: Equatable {
    enum Kind: Equatable {
        case file
        case skill
    }

    let url: URL
    let kind: Kind
    let displayNameOverride: String?
    let iconSymbolNameOverride: String?
    let detailTextOverride: String?

    init(url: URL) {
        self.url = url.standardizedFileURL
        self.kind = .file
        self.displayNameOverride = nil
        self.iconSymbolNameOverride = nil
        self.detailTextOverride = nil
    }

    init(skill: SkillDefinition, iconSymbolName: String? = nil) {
        self.url = skill.fileURL.standardizedFileURL
        self.kind = .skill
        self.displayNameOverride = skill.name
        self.iconSymbolNameOverride = iconSymbolName
        self.detailTextOverride = skill.description
    }

    var id: String {
        switch kind {
        case .file:
            return url.standardizedFileURL.path
        case .skill:
            return "skill:\(displayName.lowercased())"
        }
    }

    var displayName: String {
        displayNameOverride ?? url.lastPathComponent
    }

    var isSkill: Bool {
        kind == .skill
    }
}

struct SkillInvocation {
    let commandText: String
    let skillNames: [String]
    let instruction: String
    let attachments: [PendingAttachment]

    func composedPrompt() -> String {
        guard !attachments.isEmpty else { return instruction }

        let names = attachments.map(\.displayName).joined(separator: ", ")
        return """
        Attached files: \(names)

        \(instruction)
        """
    }
}

struct QuickSkillSlotDefinition {
    let slotIndex: Int
    let orbitLabel: String
    let symbolName: String
    let defaultSkillNames: [String]
    let instruction: String
    let angleDegrees: CGFloat

    var menuTitle: String {
        "Right-click Function \(slotIndex + 1)"
    }
}

enum QuickSkillShortcutCatalog {
    static let slotDefinitions: [QuickSkillSlotDefinition] = [
        QuickSkillSlotDefinition(
            slotIndex: 0,
            orbitLabel: "Brainstorming",
            symbolName: "text.bubble",
            defaultSkillNames: ["ce-brainstorm", "brainstorming"],
            instruction: "Brainstorm the next concrete improvement for the current workspace and then execute the best scoped option.",
            angleDegrees: 166
        ),
        QuickSkillSlotDefinition(
            slotIndex: 1,
            orbitLabel: "Animate",
            symbolName: "sparkles",
            defaultSkillNames: ["animate"],
            instruction: "Add purposeful motion and interaction feedback to the current feature without breaking existing behavior.",
            angleDegrees: 128
        ),
        QuickSkillSlotDefinition(
            slotIndex: 2,
            orbitLabel: "Design",
            symbolName: "square.grid.2x2",
            defaultSkillNames: ["frontend-design"],
            instruction: "Review the current UI and improve the layout, hierarchy, and visual quality while respecting the existing product style.",
            angleDegrees: 90
        ),
        QuickSkillSlotDefinition(
            slotIndex: 3,
            orbitLabel: "Polish",
            symbolName: "wand.and.stars",
            defaultSkillNames: ["polish"],
            instruction: "Polish the current implementation, fix visual rough edges, and tighten the overall finish.",
            angleDegrees: 52
        ),
        QuickSkillSlotDefinition(
            slotIndex: 4,
            orbitLabel: "Browser Test",
            symbolName: "globe",
            defaultSkillNames: ["test-browser"],
            instruction: "Test the current user flow in a browser and report or fix the most obvious issues you find.",
            angleDegrees: 14
        )
    ]
}

final class QuickSkillShortcutStore {
    static let shared = QuickSkillShortcutStore()

    private let defaultsKey = "quickSkillShortcutSlots"
    private static let iconMappings: [(symbolName: String, keywords: [String])] = [
        ("paintpalette", ["figma"]),
        ("sparkles", ["animate", "motion", "gsap", "scrolltrigger", "timeline"]),
        ("square.grid.2x2", ["design", "frontend", "ui", "ux", "typeset", "color", "layout", "polish", "delight", "normalize", "distill", "onboard", "clarify", "extract"]),
        ("globe", ["browser", "browse", "cookies", "canary", "test-browser"]),
        ("checkmark.shield", ["qa", "review", "audit", "benchmark", "critique"]),
        ("text.bubble", ["plan", "office-hours", "brainstorm", "autoplan", "ceo", "eng-review"]),
        ("shippingbox", ["deploy", "ship", "release", "retro", "document", "upgrade"]),
        ("lock.shield", ["security", "cso", "guard", "careful", "freeze", "unfreeze"]),
        ("photo", ["image", "banner", "poster", "content"]),
        ("wrench.and.screwdriver", ["plugin", "skill", "openai", "tool", "mcp"])
    ]

    func configuredSkillName(for slotIndex: Int) -> String? {
        storedMappings()[String(slotIndex)]
    }

    func setConfiguredSkillName(_ skillName: String, for slotIndex: Int) {
        var mappings = storedMappings()
        mappings[String(slotIndex)] = skillName
        UserDefaults.standard.set(mappings, forKey: defaultsKey)
        NotificationCenter.default.post(name: .quickSkillShortcutSlotsDidChange, object: nil)
    }

    func displaySkillName(for definition: QuickSkillSlotDefinition) -> String {
        resolvedSkillName(for: definition) ?? configuredSkillName(for: definition.slotIndex) ?? definition.defaultSkillNames.first ?? "Unassigned"
    }

    func iconSymbolName(for definition: QuickSkillSlotDefinition) -> String {
        let fallback = definition.symbolName
        let skillName = resolvedSkillName(for: definition) ?? configuredSkillName(for: definition.slotIndex) ?? ""
        let haystack = skillName.lowercased()

        guard !haystack.isEmpty else { return fallback }

        for mapping in Self.iconMappings {
            if mapping.keywords.contains(where: haystack.contains) {
                return mapping.symbolName
            }
        }

        return fallback
    }

    func resolvedSkillName(for definition: QuickSkillSlotDefinition) -> String? {
        if let configured = configuredSkillName(for: definition.slotIndex) {
            let (_, missing) = SkillRegistry.shared.findSkills(named: [configured])
            if missing.isEmpty {
                return configured
            }
        }

        for candidate in definition.defaultSkillNames {
            let (_, missing) = SkillRegistry.shared.findSkills(named: [candidate])
            if missing.isEmpty {
                return candidate
            }
        }

        return configuredSkillName(for: definition.slotIndex)
    }

    private func storedMappings() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: String] ?? [:]
    }
}

final class AgentWorkspaceStore {
    static let shared = AgentWorkspaceStore()

    private let defaultsKey = "agentWorkspacePath"
    private let fm = FileManager.default

    enum UpdateError: Error, LocalizedError {
        case invalidUsage
        case directoryNotFound(String)

        var errorDescription: String? {
            switch self {
            case .invalidUsage:
                return "Usage: /cwd /absolute/or/tilde/path"
            case .directoryNotFound(let path):
                return "Directory not found: \(path)"
            }
        }
    }

    var currentURL: URL {
        let raw = UserDefaults.standard.string(forKey: defaultsKey) ?? fm.homeDirectoryForCurrentUser.path
        let expanded = NSString(string: raw).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded, isDirectory: true).standardizedFileURL
        if isValidDirectory(url) {
            return url
        }
        return fm.homeDirectoryForCurrentUser
    }

    @discardableResult
    func update(path: String) -> Result<URL, UpdateError> {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(.invalidUsage)
        }

        let expanded = NSString(string: trimmed).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded, isDirectory: true).standardizedFileURL
        guard isValidDirectory(url) else {
            return .failure(.directoryNotFound(expanded))
        }

        UserDefaults.standard.set(url.path, forKey: defaultsKey)
        return .success(url)
    }

    private func isValidDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fm.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}

extension Notification.Name {
    static let quickSkillShortcutSlotsDidChange = Notification.Name("quickSkillShortcutSlotsDidChange")
}

final class SkillRegistry {
    static let shared = SkillRegistry()

    private let fm = FileManager.default
    private var cachedSkills: [SkillDefinition]?

    func allSkills() -> [SkillDefinition] {
        if let cachedSkills {
            return cachedSkills
        }

        var seen = Set<String>()
        var results: [SkillDefinition] = []

        for root in skillRoots() {
            guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: nil) else { continue }
            for case let fileURL as URL in enumerator {
                guard fileURL.lastPathComponent == "SKILL.md" else { continue }
                let skill = loadSkill(from: fileURL)
                if seen.insert(skill.id).inserted {
                    results.append(skill)
                }
            }
        }

        let sorted = results.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        cachedSkills = sorted
        return sorted
    }

    func findSkills(named names: [String]) -> ([SkillDefinition], [String]) {
        let catalog = allSkills()
        var found: [SkillDefinition] = []
        var missing: [String] = []

        for rawName in names {
            let normalized = rawName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !normalized.isEmpty else { continue }

            if let match = catalog.first(where: { skill in
                skill.name.lowercased() == normalized ||
                skill.fileURL.deletingLastPathComponent().lastPathComponent.lowercased() == normalized
            }) {
                found.append(match)
            } else {
                missing.append(rawName)
            }
        }

        return (found, missing)
    }

    func renderSkillList(query: String?) -> String {
        let trimmedQuery = query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let catalog = allSkills().filter { skill in
            guard !trimmedQuery.isEmpty else { return true }
            let haystack = "\(skill.name) \(skill.description)".lowercased()
            return haystack.contains(trimmedQuery.lowercased())
        }

        guard !catalog.isEmpty else {
            if trimmedQuery.isEmpty {
                return "No skills found under `~/.codex/skills` or `~/.agents/skills`."
            }
            return "No skills matched `\(trimmedQuery)`."
        }

        let preview = catalog.prefix(24).map { skill in
            "- `\(skill.name)`: \(skill.description)"
        }.joined(separator: "\n")

        let suffix = catalog.count > 24 ? "\n\nShowing 24 of \(catalog.count) skills." : ""
        return """
        Available skills:

        \(preview)\(suffix)

        Usage:
        - `/skill animate add hover motion to the current page`
        - `/skill frontend-design,polish redesign the hero section`
        - `/skills motion`
        """
    }

    private func skillRoots() -> [URL] {
        let env = ProcessInfo.processInfo.environment
        let home = fm.homeDirectoryForCurrentUser
        var roots: [URL] = []

        if let codexHome = env["CODEX_HOME"], !codexHome.isEmpty {
            roots.append(URL(fileURLWithPath: codexHome, isDirectory: true).appendingPathComponent("skills", isDirectory: true))
        }

        roots.append(home.appendingPathComponent(".codex", isDirectory: true).appendingPathComponent("skills", isDirectory: true))
        roots.append(home.appendingPathComponent(".agents", isDirectory: true).appendingPathComponent("skills", isDirectory: true))

        return roots.filter { url in
            var isDirectory: ObjCBool = false
            return fm.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
        }
    }

    private func loadSkill(from fileURL: URL) -> SkillDefinition {
        let directoryName = fileURL.deletingLastPathComponent().lastPathComponent
        guard let body = try? String(contentsOf: fileURL) else {
            return SkillDefinition(name: directoryName, description: "No description available.", fileURL: fileURL)
        }

        let parsed = parseFrontMatter(from: body)
        let trimmedName = parsed["name"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = (trimmedName?.isEmpty == false ? trimmedName : nil) ?? directoryName
        let trimmedDescription = parsed["description"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = (trimmedDescription?.isEmpty == false ? trimmedDescription : nil) ?? "No description available."

        return SkillDefinition(name: name, description: description, fileURL: fileURL)
    }

    private func parseFrontMatter(from body: String) -> [String: String] {
        let lines = body.components(separatedBy: .newlines)
        guard lines.first == "---" else { return [:] }

        var result: [String: String] = [:]
        for line in lines.dropFirst() {
            if line == "---" { break }
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<colon]).trimmingCharacters(in: .whitespacesAndNewlines)
            let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            result[key] = value
        }
        return result
    }
}
