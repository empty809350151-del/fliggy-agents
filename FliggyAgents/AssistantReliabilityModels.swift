import Foundation

enum DeliveryOutcome: String, Codable, CaseIterable {
    case delivered = "delivered"
    case skippedNoPermission = "skipped_no_permission"
    case skippedNoVisibleCharacter = "skipped_no_visible_character"
    case deduped = "deduped"
    case usedFallback = "used_fallback"
    case expired = "expired"
}

enum ReminderEventKind: String, Codable, CaseIterable {
    case setupChecklist = "setup_checklist"
    case dingTalkMirror = "dingtalk_mirror"
    case morningBrief = "morning_brief"
    case careCheckIn = "care_check_in"
    case dingTalkUnread = "dingtalk_unread"
    case dingTalkMeeting = "dingtalk_meeting"
    case diagnostics = "diagnostics"
}

struct ReminderEvent: Codable, Equatable {
    static let defaultInboxThreadTitle = "助手提醒"

    let id: UUID
    let kind: ReminderEventKind
    let source: String
    let deliveryKey: String
    let bubbleTitle: String?
    let bubbleText: String
    let fullText: String
    let createdAt: Date
    let outcomes: [DeliveryOutcome]
    let metadata: [String: String]

    init(
        id: UUID = UUID(),
        kind: ReminderEventKind,
        source: String,
        deliveryKey: String,
        bubbleTitle: String? = nil,
        bubbleText: String,
        fullText: String,
        createdAt: Date = Date(),
        outcomes: [DeliveryOutcome] = [],
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.kind = kind
        self.source = source
        self.deliveryKey = deliveryKey
        self.bubbleTitle = bubbleTitle
        self.bubbleText = bubbleText
        self.fullText = fullText
        self.createdAt = createdAt
        self.outcomes = outcomes
        self.metadata = metadata
    }

    var inboxThreadTitle: String {
        metadata["thread_title"] ?? Self.defaultInboxThreadTitle
    }

    var historyMessageText: String {
        let content = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        return content.isEmpty ? bubbleText : content
    }

    var outcomeSummary: String {
        outcomes
            .sorted { lhs, rhs in
                Self.outcomeRank(lhs) < Self.outcomeRank(rhs)
            }
            .map(\.rawValue)
            .joined(separator: ", ")
    }

    func withAdditionalOutcome(_ outcome: DeliveryOutcome) -> ReminderEvent {
        guard !outcomes.contains(outcome) else { return self }
        var updatedOutcomes = outcomes
        updatedOutcomes.append(outcome)
        return ReminderEvent(
            id: id,
            kind: kind,
            source: source,
            deliveryKey: deliveryKey,
            bubbleTitle: bubbleTitle,
            bubbleText: bubbleText,
            fullText: fullText,
            createdAt: createdAt,
            outcomes: updatedOutcomes,
            metadata: metadata
        )
    }

    private static func outcomeRank(_ outcome: DeliveryOutcome) -> Int {
        switch outcome {
        case .usedFallback: return 0
        case .deduped: return 1
        case .skippedNoPermission: return 2
        case .skippedNoVisibleCharacter: return 3
        case .expired: return 4
        case .delivered: return 5
        }
    }
}

struct SetupChecklistItem: Equatable {
    let title: String
    let detail: String
    let isComplete: Bool

    var marker: String {
        isComplete ? "[x]" : "[ ]"
    }
}

enum ProviderReadiness: Equatable {
    case unknown
    case ready(path: String)
    case missing

    var isReady: Bool {
        if case .ready = self {
            return true
        }
        return false
    }

    var summary: String {
        switch self {
        case .unknown:
            return "Checking provider readiness…"
        case let .ready(path):
            return "Ready (\(path))"
        case .missing:
            return "CLI not found"
        }
    }
}

enum AssistantSourceOfTruth {
    static let sourceOfTruthPath = "/Users/tianzhongyi/Documents/fliggy agents/fliggy-agents/build/src/FliggyAgents"
    static let buildCommand = "/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project fliggy-agents/build/src/fliggy-agents.xcodeproj -scheme FliggyAgents -configuration Debug CODE_SIGNING_ALLOWED=NO build"
    static let installAppPath = "/Users/tianzhongyi/Applications/fliggy agents.app"
    static let buildScriptPath = "/Users/tianzhongyi/Documents/fliggy agents/fliggy-agents/build/src/scripts/install_debug_app.sh"
    static let readmePath = "/Users/tianzhongyi/Documents/fliggy agents/fliggy-agents/build/src/README.md"
    static let reminderStorageDirectoryPath = "/Users/tianzhongyi/.local/share/fliggy-agents"
}

struct AssistantHealthState: Equatable {
    let sourceOfTruthPath: String
    let buildCommand: String
    let installAppPath: String
    let currentProviderName: String
    let isCurrentProviderReady: Bool
    let visibleCharacterCount: Int
    let hasAccessibilityPermission: Bool
    let hasCalendarPermission: Bool
    let hasLocationPermission: Bool
    let mirrorDingTalkNotificationsEnabled: Bool
    let proactiveAssistantEnabled: Bool
    let dingTalkMeetingReminderEnabled: Bool
    let dingTalkUnreadReminderEnabled: Bool
    let weatherEnabled: Bool
    let dingTalkMonitoringEnabled: Bool

    var requiresDingTalkMonitoring: Bool {
        mirrorDingTalkNotificationsEnabled
            || (proactiveAssistantEnabled && (dingTalkMeetingReminderEnabled || dingTalkUnreadReminderEnabled))
    }

    var needsCalendarPermission: Bool {
        proactiveAssistantEnabled && dingTalkMeetingReminderEnabled
    }

    var needsLocationPermission: Bool {
        proactiveAssistantEnabled && weatherEnabled
    }

    var blockingReasons: [String] {
        var reasons: [String] = []

        if requiresDingTalkMonitoring && !hasAccessibilityPermission {
            reasons.append("Accessibility permission is required for DingTalk mirroring and monitored reminders.")
        }
        if needsCalendarPermission && !hasCalendarPermission {
            reasons.append("Calendar permission is required for meeting reminders.")
        }
        if needsLocationPermission && !hasLocationPermission {
            reasons.append("Location permission is required for weather-rich morning briefs.")
        }
        if !isCurrentProviderReady {
            reasons.append("Current provider \(currentProviderName) is not ready.")
        }
        if visibleCharacterCount == 0 {
            reasons.append("No visible characters are enabled.")
        }
        if requiresDingTalkMonitoring && !dingTalkMonitoringEnabled {
            reasons.append("DingTalk monitoring is not active yet.")
        }

        return reasons
    }

    var statusTitle: String {
        blockingReasons.isEmpty ? "Ready" : "Needs Attention"
    }

    var statusLine: String {
        blockingReasons.isEmpty
            ? "All reminder and monitoring prerequisites look healthy."
            : "\(blockingReasons.count) blocker(s) need attention before the assistant is fully reliable."
    }

    var setupChecklistItems: [SetupChecklistItem] {
        [
            SetupChecklistItem(
                title: "Enable a Visible Character",
                detail: visibleCharacterCount > 0 ? "\(visibleCharacterCount) visible character(s) ready on the desktop." : "Turn on at least one desktop character from the menu bar.",
                isComplete: visibleCharacterCount > 0
            ),
            SetupChecklistItem(
                title: "Pick a Ready Provider",
                detail: isCurrentProviderReady ? "\(currentProviderName) is installed and ready." : "Install or switch to a working provider before relying on the assistant.",
                isComplete: isCurrentProviderReady
            ),
            SetupChecklistItem(
                title: "Grant Accessibility Permission",
                detail: accessibilityChecklistDetail,
                isComplete: !requiresDingTalkMonitoring || hasAccessibilityPermission
            ),
            SetupChecklistItem(
                title: "Grant Calendar Permission",
                detail: calendarChecklistDetail,
                isComplete: !needsCalendarPermission || hasCalendarPermission
            ),
            SetupChecklistItem(
                title: "Grant Location Permission",
                detail: locationChecklistDetail,
                isComplete: !needsLocationPermission || hasLocationPermission
            ),
            SetupChecklistItem(
                title: "Open the Reminder Inbox",
                detail: "Use the reminder inbox to confirm proactive messages and mirrored notifications are being persisted.",
                isComplete: true
            )
        ]
    }

    func setupChecklistMessage(appName: String = "fliggy agents") -> String {
        let checklist = setupChecklistItems
            .map { "\($0.marker) \($0.title) — \($0.detail)" }
            .joined(separator: "\n")

        let blockers = blockingReasons.isEmpty
            ? "No active blockers."
            : blockingReasons.map { "- \($0)" }.joined(separator: "\n")

        return """
        Hi, 我在这儿。先把 \(appName) 的闭环检查一遍：

        \(checklist)

        Current blockers:
        \(blockers)

        Source of truth:
        \(sourceOfTruthPath)

        Build command:
        \(buildCommand)

        Install app:
        \(installAppPath)
        """
    }

    private var accessibilityChecklistDetail: String {
        if !requiresDingTalkMonitoring {
            return "Required when DingTalk mirroring or DingTalk-based reminders are enabled."
        }
        if hasAccessibilityPermission {
            return "Accessibility access is active for notification mirroring and DingTalk monitoring."
        }
        return "Required for DingTalk mirroring and proactive unread/meeting detection."
    }

    private var calendarChecklistDetail: String {
        if !needsCalendarPermission {
            return "Meeting reminders are off, so Calendar permission is optional right now."
        }
        if hasCalendarPermission {
            return "Calendar access is active for meeting reminders."
        }
        return "Required if you want DingTalk meeting reminders to stay accurate."
    }

    private var locationChecklistDetail: String {
        if !needsLocationPermission {
            return "Weather is off, so Location permission is optional right now."
        }
        if hasLocationPermission {
            return "Location access is active for weather-rich morning briefs."
        }
        return "Optional overall, but required if morning briefs should include local weather."
    }
}

enum ProviderBinaryDescriptor {
    static func fallbackPaths(for provider: AgentProvider) -> (name: String, paths: [String]) {
        let home = FileManager.default.homeDirectoryForCurrentUser.path

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
}

final class CurrentProviderReadinessProbe {
    static func refresh(provider: AgentProvider, completion: @escaping (ProviderReadiness) -> Void) {
        let descriptor = ProviderBinaryDescriptor.fallbackPaths(for: provider)
        ShellEnvironment.findBinary(name: descriptor.name, fallbackPaths: descriptor.paths) { path in
            if let path {
                completion(.ready(path: path))
            } else {
                completion(.missing)
            }
        }
    }
}
