import Foundation

@main
enum AssistantHealthStateTest {
    static func main() {
        let state = AssistantHealthState(
            sourceOfTruthPath: "/Users/tianzhongyi/Documents/fliggy agents/fliggy-agents/build/src/FliggyAgents",
            buildCommand: "/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project fliggy-agents/build/src/fliggy-agents.xcodeproj -scheme FliggyAgents -configuration Debug CODE_SIGNING_ALLOWED=NO build",
            installAppPath: "/Users/tianzhongyi/Applications/fliggy agents.app",
            currentProviderName: "Codex",
            isCurrentProviderReady: false,
            visibleCharacterCount: 0,
            hasAccessibilityPermission: false,
            hasCalendarPermission: false,
            hasLocationPermission: true,
            mirrorDingTalkNotificationsEnabled: true,
            proactiveAssistantEnabled: true,
            dingTalkMeetingReminderEnabled: true,
            dingTalkUnreadReminderEnabled: true,
            weatherEnabled: false,
            dingTalkMonitoringEnabled: false
        )

        assert(
            state.blockingReasons.contains("Accessibility permission is required for DingTalk mirroring and monitored reminders."),
            "Expected accessibility to be called out as a blocker"
        )
        assert(
            state.blockingReasons.contains("Current provider Codex is not ready."),
            "Expected provider readiness to be called out as a blocker"
        )
        assert(
            state.blockingReasons.contains("No visible characters are enabled."),
            "Expected visible character requirement to be called out as a blocker"
        )

        let checklist = state.setupChecklistItems
        assert(
            checklist.contains(where: { $0.title == "Grant Accessibility Permission" && !$0.isComplete }),
            "Expected checklist to include accessibility setup"
        )
        assert(
            checklist.contains(where: { $0.title == "Enable a Visible Character" && !$0.isComplete }),
            "Expected checklist to include visible character setup"
        )
        assert(
            checklist.contains(where: { $0.title == "Pick a Ready Provider" && !$0.isComplete }),
            "Expected checklist to include provider setup"
        )

        let event = ReminderEvent(
            kind: .dingTalkMirror,
            source: "DingTalk",
            deliveryKey: "dingtalk-1",
            bubbleTitle: "鱼饼",
            bubbleText: "鱼饼：楼下等你",
            fullText: "鱼饼：楼下等你，看到后回一下。",
            createdAt: Date(timeIntervalSince1970: 1_775_280_000),
            outcomes: [.usedFallback, .delivered],
            metadata: ["thread_title": "助手提醒"]
        )

        assert(event.inboxThreadTitle == "助手提醒", "Expected reminder events to land in the unified inbox")
        assert(event.outcomeSummary == "used_fallback, delivered", "Expected outcomes to be rendered in a stable order")
        assert(
            event.historyMessageText.contains("鱼饼：楼下等你"),
            "Expected reminder history text to preserve the user-facing content"
        )

        print("assistant_health_state_test: PASS")
    }
}
