import AppKit

class FliggyAgentsController {
    var characters: [WalkerCharacter] = []
    private var displayLink: CVDisplayLink?
    var debugWindow: NSWindow?
    var pinnedScreenIndex: Int = -1
    private static let onboardingKey = "hasCompletedOnboarding"
    private var isHiddenForEnvironment = false
    var healthStateProvider: (() -> AssistantHealthState)?

    func start() {
        let char1 = WalkerCharacter(videoName: "walk-bruce-01")
        char1.accelStart = 3.0
        char1.fullSpeedStart = 3.75
        char1.decelStart = 8.0
        char1.walkStop = 8.5
        char1.walkAmountRange = 0.4...0.65

        let char2 = WalkerCharacter(videoName: "walk-jazz-01")
        char2.accelStart = 3.9
        char2.fullSpeedStart = 4.5
        char2.decelStart = 8.0
        char2.walkStop = 8.75
        char2.walkAmountRange = 0.35...0.6

        let char3 = WalkerCharacter(videoName: "walk-fliggy-01")
        char3.accelStart = 3.3
        char3.fullSpeedStart = 4.0
        char3.decelStart = 8.0
        char3.walkStop = 8.6
        char3.walkAmountRange = 0.3...0.55

        let char4 = WalkerCharacter(videoName: "walk-labubu-01")
        char4.accelStart = 3.6
        char4.fullSpeedStart = 4.25
        char4.decelStart = 8.1
        char4.walkStop = 8.7
        char4.walkAmountRange = 0.28...0.52

        char1.yOffset = -3
        char2.yOffset = -7
        char3.yOffset = -5
        char4.yOffset = -6
        char1.characterColor = NSColor(red: 0.4, green: 0.72, blue: 0.55, alpha: 1.0)
        char2.characterColor = NSColor(red: 1.0, green: 0.4, blue: 0.0, alpha: 1.0)
        char3.characterColor = NSColor(red: 1.0, green: 0.58, blue: 0.12, alpha: 1.0)
        char4.characterColor = NSColor(red: 0.92, green: 0.72, blue: 0.34, alpha: 1.0)

        char1.flipXOffset = 0
        char2.flipXOffset = -9
        char3.flipXOffset = -4
        char4.flipXOffset = -6

        char1.positionProgress = 0.12
        char2.positionProgress = 0.36
        char3.positionProgress = 0.62
        char4.positionProgress = 0.86

        char1.pauseEndTime = CACurrentMediaTime() + Double.random(in: 0.4...1.4)
        char2.pauseEndTime = CACurrentMediaTime() + Double.random(in: 1.0...2.4)
        char3.pauseEndTime = CACurrentMediaTime() + Double.random(in: 0.8...2.2)
        char4.pauseEndTime = CACurrentMediaTime() + Double.random(in: 1.8...3.4)

        char1.setup()
        char2.setup()
        char3.setup()
        char4.setup()

        characters = [char1, char2, char3, char4].filter { $0.window != nil }
        characters.forEach { $0.controller = self }
        if characters.indices.contains(0) { characters[0].setManuallyVisible(false) }
        if characters.indices.contains(1) { characters[1].setManuallyVisible(false) }

        setupDebugLine()
        startDisplayLink()

        if !UserDefaults.standard.bool(forKey: Self.onboardingKey) {
            triggerOnboarding()
        }
    }

    var visibleCharacterCount: Int {
        characters.filter { $0.isManuallyVisible && $0.window?.isVisible == true }.count
    }

    private func triggerOnboarding() {
        guard let leadCharacter = reminderTargetCharacter() ?? characters.first else { return }
        leadCharacter.isOnboarding = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            leadCharacter.currentPhrase = "setup"
            leadCharacter.showingCompletion = true
            leadCharacter.completionBubbleExpiry = CACurrentMediaTime() + 600
            leadCharacter.showBubble(
                text: "打开 setup checklist",
                title: "Hi, 我在这儿",
                isCompletion: true,
                allowsWrapping: true,
                showsCloseButton: true
            )
            leadCharacter.playCompletionSound()
        }
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: Self.onboardingKey)
        characters.forEach { $0.isOnboarding = false }
    }

    func openSetupChecklist() {
        let fallbackState = AssistantHealthState(
            sourceOfTruthPath: AssistantSourceOfTruth.sourceOfTruthPath,
            buildCommand: AssistantSourceOfTruth.buildCommand,
            installAppPath: AssistantSourceOfTruth.installAppPath,
            currentProviderName: AgentProvider.current.displayName,
            isCurrentProviderReady: false,
            visibleCharacterCount: visibleCharacterCount,
            hasAccessibilityPermission: false,
            hasCalendarPermission: false,
            hasLocationPermission: false,
            mirrorDingTalkNotificationsEnabled: false,
            proactiveAssistantEnabled: false,
            dingTalkMeetingReminderEnabled: false,
            dingTalkUnreadReminderEnabled: false,
            weatherEnabled: false,
            dingTalkMonitoringEnabled: false
        )
        let state = healthStateProvider?() ?? fallbackState
        let target = reminderTargetCharacter() ?? characters.first
        target?.openSetupChecklist(state: state)
    }

    func openReminderInbox() {
        let target = reminderTargetCharacter() ?? characters.first
        target?.openReminderInbox()
    }

    func showMirroredDingTalkNotification(_ notification: MirroredDingTalkNotification) {
        let activePopover = characters.first(where: { $0.isIdleForPopover && $0.isManuallyVisible && $0.window?.isVisible == true })
        let target = reminderTargetCharacter()
        let outcomes: [DeliveryOutcome]
        if activePopover != nil || target != nil {
            outcomes = [.delivered]
        } else {
            outcomes = [.skippedNoVisibleCharacter]
        }

        let event = ReminderEvent(
            kind: .dingTalkMirror,
            source: notification.sourceAppName,
            deliveryKey: notification.dedupeKey,
            bubbleTitle: notification.title,
            bubbleText: notification.displayText,
            fullText: notification.displayText,
            outcomes: outcomes,
            metadata: ["thread_title": ReminderEvent.defaultInboxThreadTitle]
        )
        let thread = ChatHistoryStore.shared.appendReminderEvent(event)

        if let activePopover {
            activePopover.noteProactiveHistoryUpdate()
            return
        }

        guard let target else {
            NSLog(
                "FliggyAgentsController.showMirroredDingTalkNotification dropped title=%{public}@ body=%{public}@ reason=no-visible-character",
                notification.title,
                notification.body ?? ""
            )
            return
        }

        NSLog(
            "FliggyAgentsController.showMirroredDingTalkNotification title=%{public}@ body=%{public}@ target=%{public}@",
            notification.title,
            notification.body ?? "",
            target.window?.title ?? "unknown"
        )
        target.showExternalNotificationBubble(
            title: notification.title,
            body: notification.body,
            duration: 30.0,
            threadID: thread.id
        )
    }

    func deliverProactiveMessage(_ message: ProactiveMessage) {
        let activePopover = characters.first(where: { $0.isIdleForPopover && $0.isManuallyVisible && $0.window?.isVisible == true })
        let target = reminderTargetCharacter()

        var outcomes: [DeliveryOutcome] = []
        if message.usedFallback {
            outcomes.append(.usedFallback)
        }
        if activePopover != nil || target != nil {
            outcomes.append(.delivered)
        } else {
            outcomes.append(.skippedNoVisibleCharacter)
        }

        let event = ReminderEvent(
            kind: reminderEventKind(for: message.kind),
            source: "Proactive Assistant",
            deliveryKey: message.deliveryKey,
            bubbleText: message.bubbleText,
            fullText: message.fullText,
            createdAt: message.deliverAt,
            outcomes: outcomes,
            metadata: ["thread_title": ReminderEvent.defaultInboxThreadTitle]
        )
        let thread = ChatHistoryStore.shared.appendReminderEvent(event)

        if let activePopover {
            activePopover.noteProactiveHistoryUpdate()
            return
        }

        guard let target else {
            return
        }
        target.showExternalNotificationBubble(title: "", body: message.fullText, duration: 30.0, threadID: thread.id)
    }

    private func reminderEventKind(for proactiveKind: ProactiveEventKind) -> ReminderEventKind {
        switch proactiveKind {
        case .morningBrief:
            return .morningBrief
        case .careCheckIn:
            return .careCheckIn
        case .dingTalkUnread:
            return .dingTalkUnread
        case .dingTalkMeeting:
            return .dingTalkMeeting
        }
    }

    private func reminderTargetCharacter() -> WalkerCharacter? {
        characters.first(where: { $0.isManuallyVisible && $0.window?.isVisible == true })
    }

    // MARK: - Debug

    private func setupDebugLine() {
        let win = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 100, height: 2),
                           styleMask: .borderless, backing: .buffered, defer: false)
        win.isOpaque = false
        win.backgroundColor = NSColor.red
        win.hasShadow = false
        win.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 10)
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.moveToActiveSpace, .stationary]
        win.orderOut(nil)
        debugWindow = win
    }

    private func updateDebugLine(dockX: CGFloat, dockWidth: CGFloat, dockTopY: CGFloat) {
        guard let win = debugWindow, win.isVisible else { return }
        win.setFrame(CGRect(x: dockX, y: dockTopY, width: dockWidth, height: 2), display: true)
    }

    // MARK: - Dock Geometry

    private func getDockActivityArea(screen: NSScreen) -> (x: CGFloat, width: CGFloat) {
        let screenFrame = screen.frame
        let rightQuarterWidth = screenFrame.width * 0.25
        let horizontalPadding: CGFloat = 20
        let x = screenFrame.maxX - rightQuarterWidth + horizontalPadding
        let width = max(rightQuarterWidth - horizontalPadding * 2, 220)
        return (x, width)
    }

    private func dockAutohideEnabled() -> Bool {
        let dockDefaults = UserDefaults(suiteName: "com.apple.dock")
        return dockDefaults?.bool(forKey: "autohide") ?? false
    }

    // MARK: - Display Link

    private func startDisplayLink() {
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        guard let displayLink = displayLink else { return }

        let callback: CVDisplayLinkOutputCallback = { _, _, _, _, _, userInfo -> CVReturn in
            let controller = Unmanaged<FliggyAgentsController>.fromOpaque(userInfo!).takeUnretainedValue()
            DispatchQueue.main.async {
                controller.tick()
            }
            return kCVReturnSuccess
        }

        CVDisplayLinkSetOutputCallback(displayLink, callback,
                                       Unmanaged.passUnretained(self).toOpaque())
        CVDisplayLinkStart(displayLink)
    }

    var activeScreen: NSScreen? {
        if pinnedScreenIndex >= 0, pinnedScreenIndex < NSScreen.screens.count {
            return NSScreen.screens[pinnedScreenIndex]
        }
        return NSScreen.main
    }

    /// The dock lives on the screen where visibleFrame.origin.y > frame.origin.y (bottom dock)
    /// On screens without the dock, visibleFrame.origin.y == frame.origin.y
    private func screenHasDock(_ screen: NSScreen) -> Bool {
        return screen.visibleFrame.origin.y > screen.frame.origin.y
    }

    private func shouldShowCharacters(on screen: NSScreen) -> Bool {
        if screen == NSScreen.main {
            return true
        }

        if screenHasDock(screen) {
            return true
        }

        // With dock auto-hide enabled on the active desktop, the dock can still be
        // present even though visibleFrame starts at the screen origin. In fullscreen
        // spaces, both the dock and menu bar are absent, so visibleFrame matches frame.
        let menuBarVisible = screen.visibleFrame.maxY < screen.frame.maxY
        return dockAutohideEnabled() && screen == NSScreen.main && menuBarVisible
    }

    @discardableResult
    private func updateEnvironmentVisibility(for screen: NSScreen) -> Bool {
        let shouldShow = shouldShowCharacters(on: screen)
        guard shouldShow != !isHiddenForEnvironment else { return shouldShow }

        isHiddenForEnvironment = !shouldShow

        if shouldShow {
            characters.forEach { $0.showForEnvironmentIfNeeded() }
        } else {
            debugWindow?.orderOut(nil)
            characters.forEach { $0.hideForEnvironment() }
        }

        return shouldShow
    }

    func refreshCharacterVisibility() {
        guard let screen = activeScreen else { return }
        let shouldShow = shouldShowCharacters(on: screen)
        isHiddenForEnvironment = !shouldShow

        if shouldShow {
            characters.forEach { character in
                character.showForEnvironmentIfNeeded()
                if character.isManuallyVisible {
                    character.window.orderFrontRegardless()
                    if character.isIdleForPopover {
                        character.updatePopoverPosition()
                        character.popoverWindow?.orderFrontRegardless()
                    }
                    if character.isAgentBusy {
                        character.updateThinkingBubble()
                    }
                }
            }
        } else {
            debugWindow?.orderOut(nil)
            characters.forEach { $0.hideForEnvironment() }
        }

        tick()
    }

    func tick() {
        guard let screen = activeScreen else { return }
        guard updateEnvironmentVisibility(for: screen) else { return }

        let dockX: CGFloat
        let dockWidth: CGFloat
        let dockTopY: CGFloat

        // Keep the characters in the rightmost quarter of the dock area so they
        // stay out of the middle of the screen and don't wander under active work.
        (dockX, dockWidth) = getDockActivityArea(screen: screen)
        dockTopY = screen.visibleFrame.origin.y

        updateDebugLine(dockX: dockX, dockWidth: dockWidth, dockTopY: dockTopY)

        let activeChars = characters.filter { character in
            guard let window = character.window else { return false }
            return window.isVisible && character.isManuallyVisible
        }

        let now = CACurrentMediaTime()
        let anyWalking = activeChars.contains { $0.isWalking }
        for char in activeChars {
            if char.isIdleForPopover { continue }
            if char.isPaused && now >= char.pauseEndTime && anyWalking {
                char.pauseEndTime = now + Double.random(in: 5.0...10.0)
            }
        }
        for char in activeChars {
            char.update(dockX: dockX, dockWidth: dockWidth, dockTopY: dockTopY)
        }

        let sorted = activeChars.sorted { $0.positionProgress < $1.positionProgress }
        for (i, char) in sorted.enumerated() {
            char.window?.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + i)
        }
    }

    deinit {
        if let displayLink = displayLink {
            CVDisplayLinkStop(displayLink)
        }
    }
}
