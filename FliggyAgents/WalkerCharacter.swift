import AVFoundation
import AppKit

private final class SkillOrbitWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class SkillOrbitHoverLabelView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

private final class SkillOrbitButton: NSButton {
    private var hoverTrackingArea: NSTrackingArea?
    var onHoverChanged: ((Bool) -> Void)?
    var normalBackgroundColor: NSColor = NSColor(calibratedWhite: 0.98, alpha: 0.98) {
        didSet { updateAppearance() }
    }
    var hoverBackgroundColor: NSColor = NSColor(calibratedRed: 1.0, green: 0.878, blue: 0.2, alpha: 0.98) {
        didSet { updateAppearance() }
    }
    var iconTintColor: NSColor = NSColor(calibratedWhite: 0.08, alpha: 1.0) {
        didSet { updateAppearance() }
    }
    private var isHovering = false {
        didSet { updateAppearance() }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        addCursorRect(bounds, cursor: .pointingHand)
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        let options: NSTrackingArea.Options = [.activeAlways, .mouseEnteredAndExited, .inVisibleRect]
        let trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        onHoverChanged?(true)
        super.mouseEntered(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        onHoverChanged?(false)
        super.mouseExited(with: event)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateAppearance()
    }

    private func updateAppearance() {
        layer?.backgroundColor = (isHovering ? hoverBackgroundColor : normalBackgroundColor).cgColor
        contentTintColor = iconTintColor
    }

    func resetHoverState() {
        isHovering = false
        onHoverChanged?(false)
    }
}

private final class BubbleContentView: NSView {
    weak var bubbleBodyView: NSView?
    var onClick: (() -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if let bubbleBodyView, bubbleBodyView.frame.contains(point) {
            return self
        }
        return nil
    }

    override func mouseUp(with event: NSEvent) {
        onClick?()
    }
}

class WalkerCharacter {
    private struct TransientBubbleState {
        var title: String?
        var body: String
        var expiresAt: CFTimeInterval
        var threadID: UUID?
    }

    let videoName: String
    var window: NSWindow!
    var playerLayer: AVPlayerLayer!
    var queuePlayer: AVQueuePlayer!
    var looper: AVPlayerLooper!

    let videoWidth: CGFloat = 1080
    let videoHeight: CGFloat = 1920
    let displayHeight: CGFloat = 200
    var displayWidth: CGFloat { displayHeight * (videoWidth / videoHeight) }

    // Walk timing (per-character, from frame analysis)
    let videoDuration: CFTimeInterval = 10.0
    var accelStart: CFTimeInterval = 3.0
    var fullSpeedStart: CFTimeInterval = 3.75
    var decelStart: CFTimeInterval = 7.5
    var walkStop: CFTimeInterval = 8.25
    var walkAmountRange: ClosedRange<CGFloat> = 0.25...0.5
    var yOffset: CGFloat = 0
    var flipXOffset: CGFloat = 0
    var characterColor: NSColor = .gray

    // Walk state
    var playCount = 0
    var walkStartTime: CFTimeInterval = 0
    var positionProgress: CGFloat = 0.0
    var isWalking = false
    var isPaused = true
    var pauseEndTime: CFTimeInterval = 0
    var goingRight = true
    var walkStartPos: CGFloat = 0.0
    var walkEndPos: CGFloat = 0.0
    var currentTravelDistance: CGFloat = 500.0
    // Walk endpoints stored in pixels for consistent speed across screen switches
    var walkStartPixel: CGFloat = 0.0
    var walkEndPixel: CGFloat = 0.0

    // Onboarding
    var isOnboarding = false

    // Popover state
    var isIdleForPopover = false
    var popoverWindow: NSWindow?
    var terminalView: TerminalView?
    var session: (any AgentSession)?
    var skillRunner: CodexSkillRunner?
    var clickOutsideMonitor: Any?
    var escapeKeyMonitor: Any?
    var currentStreamingText = ""
    weak var controller: FliggyAgentsController?
    var themeOverride: PopoverTheme?
    var isAgentBusy: Bool { (session?.isBusy ?? false) || (skillRunner?.isBusy ?? false) }
    var thinkingBubbleWindow: NSWindow?
    var skillOrbitWindow: NSWindow?
    private(set) var isManuallyVisible = true
    private var environmentHiddenAt: CFTimeInterval?
    private var wasPopoverVisibleBeforeEnvironmentHide = false
    private var wasBubbleVisibleBeforeEnvironmentHide = false
    private var wasSkillOrbitVisibleBeforeEnvironmentHide = false
    private(set) var isDragging = false
    private var dragDidMove = false
    private var dragMouseOffsetX: CGFloat = 0
    private var dragStartScreenX: CGFloat = 0
    private var lastDockX: CGFloat = 0
    private var lastDockWidth: CGFloat = 0
    private var lastDockTopY: CGFloat = 0
    private var currentThread: ChatThread?
    private var popoverSize: CGSize = CGSize(width: 420, height: 310)
    private var resizeHandles: [ResizeHandleView] = []
    private var resizeStartFrame: CGRect?
    private var isResizingPopover = false
    private var skillOrbitButtons: [SkillOrbitButton] = []
    private var skillOrbitHoverLabelContainer: NSView?
    private var skillOrbitHoverLabel: NSTextField?
    private var skillOrbitClickOutsideMonitor: Any?
    private var skillOrbitEscapeMonitor: Any?
    private var skillOrbitAnimationGeneration = 0
    private var skillOrbitAnimationWorkItems: [DispatchWorkItem] = []
    private var skillOrbitCurrentAnchor = CGPoint(x: 146, y: 62)
    private var isAnimatingSkillOrbitPresentation = false
    private var isAnimatingSkillOrbitButtons = false
    private var hoveredSkillOrbitButtonIndex: Int?
    private var transientBubbleState: TransientBubbleState?

    private static let skillOrbitSize = CGSize(width: 292, height: 248)
    private static let skillOrbSize: CGFloat = 56
    private static let skillOrbitAnchor = CGPoint(x: 146, y: 62)
    private static let skillOrbitRadius: CGFloat = 102
    private static let skillOrbitPresentationDuration: TimeInterval = 0.18
    private static func skillOrbitOffset(for item: QuickSkillSlotDefinition) -> CGPoint {
        let radians = item.angleDegrees * (.pi / 180)
        return CGPoint(
            x: cos(radians) * skillOrbitRadius,
            y: sin(radians) * skillOrbitRadius
        )
    }

    private struct SkillOrbitLayout {
        let orbitFrame: CGRect
        let orbitAnchor: CGPoint
        let characterOrigin: CGPoint
    }

    private static var skillOrbitAnchorBounds: CGRect {
        let offsets = QuickSkillShortcutCatalog.slotDefinitions.map(skillOrbitOffset(for:))
        let buttonRadius = skillOrbSize / 2
        let minOffsetX = offsets.map(\.x).min() ?? 0
        let maxOffsetX = offsets.map(\.x).max() ?? 0
        let minOffsetY = offsets.map(\.y).min() ?? 0
        let maxOffsetY = offsets.map(\.y).max() ?? 0

        let minX = buttonRadius - minOffsetX
        let maxX = skillOrbitSize.width - buttonRadius - maxOffsetX
        let minY = buttonRadius - minOffsetY
        let maxY = skillOrbitSize.height - buttonRadius - maxOffsetY

        return CGRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )
    }

    private static func skillOrbitCenterOrigin(for anchor: CGPoint) -> CGPoint {
        CGPoint(
            x: anchor.x - skillOrbSize / 2,
            y: anchor.y - skillOrbSize / 2
        )
    }

    private static func skillOrbitButtonOrigin(for item: QuickSkillSlotDefinition, anchor: CGPoint) -> CGPoint {
        let offset = skillOrbitOffset(for: item)
        let centerOrigin = skillOrbitCenterOrigin(for: anchor)
        return CGPoint(
            x: centerOrigin.x + offset.x,
            y: centerOrigin.y + offset.y
        )
    }

    init(videoName: String) {
        self.videoName = videoName
    }

    // MARK: - Setup

    func setup() {
        guard Bundle.main.url(forResource: videoName, withExtension: "mov") != nil else {
            print("Video \(videoName) not found")
            return
        }
        queuePlayer = AVQueuePlayer()
        applyAudioPreferences()

        playerLayer = AVPlayerLayer(player: queuePlayer)
        playerLayer.videoGravity = .resizeAspect
        playerLayer.backgroundColor = NSColor.clear.cgColor
        playerLayer.frame = CGRect(x: 0, y: 0, width: displayWidth, height: displayHeight)

        let screen = NSScreen.main!
        let dockTopY = screen.visibleFrame.origin.y
        let bottomPadding = displayHeight * 0.15
        let y = dockTopY - bottomPadding + yOffset

        let contentRect = CGRect(x: 0, y: y, width: displayWidth, height: displayHeight)
        window = NSWindow(
            contentRect: contentRect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .statusBar
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.moveToActiveSpace, .stationary]

        let hostView = CharacterContentView(frame: CGRect(x: 0, y: 0, width: displayWidth, height: displayHeight))
        hostView.character = self
        hostView.wantsLayer = true
        hostView.layer?.backgroundColor = NSColor.clear.cgColor
        hostView.layer?.addSublayer(playerLayer)

        window.contentView = hostView
        initializeMotionSystem()
        window.orderFrontRegardless()
    }

    // MARK: - Visibility

    func setManuallyVisible(_ visible: Bool) {
        isManuallyVisible = visible
        if visible {
            if environmentHiddenAt == nil {
                window.orderFrontRegardless()
            }
        } else {
            transientBubbleState = nil
            queuePlayer.pause()
            window.orderOut(nil)
            popoverWindow?.orderOut(nil)
            thinkingBubbleWindow?.orderOut(nil)
            skillOrbitWindow?.orderOut(nil)
        }
    }

    func hideForEnvironment() {
        guard environmentHiddenAt == nil else { return }

        environmentHiddenAt = CACurrentMediaTime()
        wasPopoverVisibleBeforeEnvironmentHide = popoverWindow?.isVisible ?? false
        wasBubbleVisibleBeforeEnvironmentHide = thinkingBubbleWindow?.isVisible ?? false
        wasSkillOrbitVisibleBeforeEnvironmentHide = skillOrbitWindow?.isVisible ?? false

        queuePlayer.pause()
        window.orderOut(nil)
        popoverWindow?.orderOut(nil)
        thinkingBubbleWindow?.orderOut(nil)
        skillOrbitWindow?.orderOut(nil)
    }

    func showForEnvironmentIfNeeded() {
        guard let hiddenAt = environmentHiddenAt else { return }

        let hiddenDuration = CACurrentMediaTime() - hiddenAt
        environmentHiddenAt = nil
        walkStartTime += hiddenDuration
        pauseEndTime += hiddenDuration
        completionBubbleExpiry += hiddenDuration
        lastPhraseUpdate += hiddenDuration
        if var transientBubbleState {
            transientBubbleState.expiresAt += hiddenDuration
            self.transientBubbleState = transientBubbleState
        }

        guard isManuallyVisible else { return }

        window.orderFrontRegardless()
        if isWalking {
            queuePlayer.play()
        }

        if isIdleForPopover && wasPopoverVisibleBeforeEnvironmentHide {
            updatePopoverPosition()
            popoverWindow?.orderFrontRegardless()
            popoverWindow?.makeKey()
            if let terminal = terminalView {
                popoverWindow?.makeFirstResponder(terminal.inputField)
            }
        }

        if wasBubbleVisibleBeforeEnvironmentHide {
            updateThinkingBubble()
        }

        if wasSkillOrbitVisibleBeforeEnvironmentHide {
            updateSkillOrbitPosition()
            skillOrbitWindow?.orderFrontRegardless()
        }

        syncMotionStateImmediately()
    }

    // MARK: - Click Handling & Popover

    func handleClick() {
        if dragDidMove {
            dragDidMove = false
            return
        }
        if skillOrbitWindow?.isVisible == true {
            closeSkillOrbit(animated: false)
        }
        if isOnboarding {
            openOnboardingPopover()
            return
        }
        if isIdleForPopover {
            closePopover()
        } else {
            openPopover()
        }
    }

    func handleSecondaryClick() {
        if dragDidMove {
            dragDidMove = false
            return
        }
        guard !isOnboarding else { return }

        if skillOrbitWindow?.isVisible == true {
            closeSkillOrbit(animated: true)
        } else {
            openSkillOrbit()
        }
    }

    private func enterSkillOrbitIdleState() {
        isWalking = false
        isPaused = true
        refreshMotionPlaybackState()
        hideBubble()
        syncMotionStateImmediately()
    }

    private func exitSkillOrbitIdleState() {
        isPaused = true
        pauseEndTime = CACurrentMediaTime() + Double.random(in: 1.2...2.8)
        refreshMotionPlaybackState()
        syncMotionStateImmediately()
    }

    func handleExternalFileDrop(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        openPopover()
        terminalView?.addPendingAttachments(urls: urls)
        popoverWindow?.orderFrontRegardless()
        popoverWindow?.makeKey()
        if let terminal = terminalView {
            popoverWindow?.makeFirstResponder(terminal.inputField)
        }
    }

    private func openOnboardingPopover() {
        showingCompletion = false
        hideBubble()

        isIdleForPopover = true
        isWalking = false
        isPaused = true
        queuePlayer.pause()
        queuePlayer.seek(to: .zero)

        if popoverWindow == nil {
            createPopoverWindow()
        }

        // Show a setup checklist instead of a generic welcome blurb.
        let fallbackState = AssistantHealthState(
            sourceOfTruthPath: AssistantSourceOfTruth.sourceOfTruthPath,
            buildCommand: AssistantSourceOfTruth.buildCommand,
            installAppPath: AssistantSourceOfTruth.installAppPath,
            currentProviderName: AgentProvider.current.displayName,
            isCurrentProviderReady: false,
            visibleCharacterCount: controller?.visibleCharacterCount ?? 0,
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
        let setupState = controller?.healthStateProvider?() ?? fallbackState
        currentThread = ChatThread(
            title: "Setup Checklist",
            titleSource: "setup",
            provider: ChatHistoryStore.reminderProvider,
            messages: [ChatHistoryMessage(role: .assistant, text: setupState.setupChecklistMessage())]
        )
        session?.history = currentThread?.messages.map(\.agentMessage) ?? []
        terminalView?.clearPendingAttachments()
        terminalView?.replayHistory(session?.history ?? [])
        applyCurrentThreadComposerState(readOnlyOverride: true, placeholderOverride: "Dismiss this checklist, then start a new chat when you're ready.")
        updatePopoverTitle()

        updatePopoverPosition()
        popoverWindow?.orderFrontRegardless()

        // Set up click-outside to dismiss and complete onboarding
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            self?.closeOnboarding()
        }
        escapeKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.closeOnboarding(); return nil }
            return event
        }
    }

    private func closeOnboarding() {
        if let monitor = clickOutsideMonitor { NSEvent.removeMonitor(monitor); clickOutsideMonitor = nil }
        if let monitor = escapeKeyMonitor { NSEvent.removeMonitor(monitor); escapeKeyMonitor = nil }
        popoverWindow?.orderOut(nil)
        popoverWindow = nil
        terminalView = nil
        isIdleForPopover = false
        isOnboarding = false
        isPaused = true
        pauseEndTime = CACurrentMediaTime() + Double.random(in: 1.0...3.0)
        queuePlayer.seek(to: .zero)
        controller?.completeOnboarding()
    }

    func openPopover() {
        closeSkillOrbit(animated: false)

        // Close any other open popover
        if let siblings = controller?.characters {
            for sibling in siblings where sibling !== self && sibling.isIdleForPopover {
                sibling.closePopover()
            }
        }

        isIdleForPopover = true
        isWalking = false
        isPaused = true
        queuePlayer.pause()
        queuePlayer.seek(to: .zero)

        // Always clear any bubble (thinking or completion) when popover opens
        showingCompletion = false
        hideBubble()

        if session == nil {
            let newSession = AgentProvider.current.createSession()
            session = newSession
            wireSession(newSession)
            newSession.start()
        }

        if popoverWindow == nil {
            createPopoverWindow()
        }

        if let terminal = terminalView {
            let messages = latestDisplayMessages()
            terminal.replayHistory(messages)
            if session?.isBusy == true {
                terminal.resumeThinkingIfNeeded()
            }
        }

        updatePopoverPosition()
        popoverWindow?.orderFrontRegardless()
        popoverWindow?.makeKey()

        if let terminal = terminalView {
            popoverWindow?.makeFirstResponder(terminal.inputField)
        }

        syncMotionStateImmediately()

        // Remove old monitors before adding new ones
        removeEventMonitors()

        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let popover = self.popoverWindow else { return }
            let popoverFrame = popover.frame
            let charFrame = self.window.frame
            if !popoverFrame.contains(NSEvent.mouseLocation) && !charFrame.contains(NSEvent.mouseLocation) {
                self.closePopover()
            }
        }

        escapeKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.closePopover()
                return nil
            }
            return event
        }
    }

    func noteProactiveHistoryUpdate() {
        guard isIdleForPopover else { return }
        terminalView?.reloadHistoryList()

        if currentThread?.titleSource == ChatHistoryStore.reminderThreadTitleSource,
           let reminderThread = ChatHistoryStore.shared.loadReminderThread() {
            currentThread = reminderThread
            session?.history = reminderThread.messages.map(\.agentMessage)
            terminalView?.replayHistory(session?.history ?? [])
            updatePopoverTitle()
            applyCurrentThreadComposerState()
        }
    }

    func openSetupChecklist(state: AssistantHealthState) {
        openPopover()
        currentThread = ChatThread(
            title: "Setup Checklist",
            titleSource: "setup",
            provider: ChatHistoryStore.reminderProvider,
            messages: [ChatHistoryMessage(role: .assistant, text: state.setupChecklistMessage())]
        )
        session?.history = currentThread?.messages.map(\.agentMessage) ?? []
        terminalView?.clearPendingAttachments()
        terminalView?.replayHistory(session?.history ?? [])
        terminalView?.toggleHistoryPanelIfNeededClose()
        applyCurrentThreadComposerState(
            readOnlyOverride: true,
            placeholderOverride: "Setup checklist is read-only. Start a new chat to ask something."
        )
        updatePopoverTitle()
        popoverWindow?.orderFrontRegardless()
        popoverWindow?.makeKey()
    }

    func openReminderInbox() {
        openReminderInbox(threadID: ChatHistoryStore.shared.loadReminderThread()?.id)
    }

    func openReminderInbox(threadID: UUID?) {
        openPopover()
        if let threadID {
            loadThread(id: threadID)
        } else {
            currentThread = ChatThread(
                title: ReminderEvent.defaultInboxThreadTitle,
                titleSource: ChatHistoryStore.reminderThreadTitleSource,
                provider: ChatHistoryStore.reminderProvider,
                messages: [ChatHistoryMessage(role: .assistant, text: "提醒会沉淀在这里。现在还没有新的提醒。")]
            )
            session?.history = currentThread?.messages.map(\.agentMessage) ?? []
            terminalView?.replayHistory(session?.history ?? [])
        }
        terminalView?.clearPendingAttachments()
        terminalView?.toggleHistoryPanelIfNeededClose()
        applyCurrentThreadComposerState()
        updatePopoverTitle()
        popoverWindow?.orderFrontRegardless()
        popoverWindow?.makeKey()
    }

    private func applyCurrentThreadComposerState(
        readOnlyOverride: Bool? = nil,
        placeholderOverride: String? = nil
    ) {
        guard let terminalView else { return }

        let isReadOnly = readOnlyOverride
            ?? (currentThread?.titleSource == ChatHistoryStore.reminderThreadTitleSource
                || currentThread?.titleSource == "setup")
        terminalView.inputField.isEditable = !isReadOnly
        terminalView.inputField.isSelectable = true

        let placeholder = placeholderOverride
            ?? (isReadOnly
                ? "Reminder inbox is read-only. Start a new chat to ask something."
                : AgentProvider.current.inputPlaceholder)

        if let paddedCell = terminalView.inputField.cell as? PaddedTextFieldCell {
            let theme = terminalView.theme
            paddedCell.placeholderAttributedString = NSAttributedString(
                string: placeholder,
                attributes: [.font: theme.font, .foregroundColor: theme.composerPlaceholder]
            )
        }
    }

    func showDebugConversation(title: String, messages: [AgentMessage]) {
        openPopover()
        currentThread = ChatThread(
            title: title,
            titleSource: "debug",
            provider: AgentProvider.current.rawValue,
            messages: messages.map { ChatHistoryMessage(role: $0.role, text: $0.text) }
        )
        session?.history = messages
        terminalView?.clearPendingAttachments()
        terminalView?.replayHistory(messages)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.terminalView?.scrollTranscriptToTopForDebug()
        }
        terminalView?.toggleHistoryPanelIfNeededClose()
        updatePopoverTitle()
        popoverWindow?.orderFrontRegardless()
        popoverWindow?.makeKey()
        if let terminal = terminalView {
            popoverWindow?.makeFirstResponder(terminal.inputField)
        }
    }

    func openHistoryDrawerForDebug() {
        openPopover()
        terminalView?.reloadHistoryList()
        terminalView?.toggleHistoryPanelIfNeededClose()
        terminalView?.toggleHistoryPanel()
        popoverWindow?.orderFrontRegardless()
        popoverWindow?.makeKey()
    }

    func closePopover() {
        guard isIdleForPopover else { return }

        persistCurrentThread()
        popoverWindow?.orderOut(nil)
        removeEventMonitors()

        isIdleForPopover = false

        // If still waiting for a response, show thinking bubble immediately
        // If completion came while popover was open, show completion bubble
        if let transientBubbleState, CACurrentMediaTime() < transientBubbleState.expiresAt {
            showBubble(
                text: transientBubbleState.body,
                title: transientBubbleState.title,
                isCompletion: false,
                allowsWrapping: true,
                showsCloseButton: true
            )
        } else if showingCompletion {
            // Reset expiry so user gets the full 3s from now
            completionBubbleExpiry = CACurrentMediaTime() + 3.0
            showBubble(text: currentPhrase, isCompletion: true)
        } else if isAgentBusy {
            // Force a fresh phrase pick and show immediately
            currentPhrase = ""
            lastPhraseUpdate = 0
            updateThinkingPhrase()
            showBubble(text: currentPhrase, isCompletion: false)
        }

        let delay = Double.random(in: 2.0...5.0)
        pauseEndTime = CACurrentMediaTime() + delay
        syncMotionStateImmediately()
    }

    private func latestDisplayMessages() -> [AgentMessage] {
        if let session, !session.history.isEmpty {
            return session.history
        }
        return currentThread?.messages.map(\.agentMessage) ?? []
    }

    private func removeEventMonitors() {
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }
        if let monitor = escapeKeyMonitor {
            NSEvent.removeMonitor(monitor)
            escapeKeyMonitor = nil
        }
    }

    private func removeSkillOrbitEventMonitors() {
        if let monitor = skillOrbitClickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            skillOrbitClickOutsideMonitor = nil
        }
        if let monitor = skillOrbitEscapeMonitor {
            NSEvent.removeMonitor(monitor)
            skillOrbitEscapeMonitor = nil
        }
    }

    var resolvedTheme: PopoverTheme {
        (themeOverride ?? PopoverTheme.current).withCharacterColor(characterColor).withCustomFont()
    }

    private var popoverSizeDefaultsKey: String {
        "popoverSize.\(videoName)"
    }

    private func loadPopoverSize() {
        let defaults = UserDefaults.standard
        let width = defaults.double(forKey: "\(popoverSizeDefaultsKey).width")
        let height = defaults.double(forKey: "\(popoverSizeDefaultsKey).height")
        if width > 0, height > 0 {
            popoverSize = CGSize(width: width, height: height)
        }
    }

    private func savePopoverSize() {
        let defaults = UserDefaults.standard
        defaults.set(popoverSize.width, forKey: "\(popoverSizeDefaultsKey).width")
        defaults.set(popoverSize.height, forKey: "\(popoverSizeDefaultsKey).height")
    }

    func createPopoverWindow() {
        let t = resolvedTheme
        loadPopoverSize()
        let popoverWidth = popoverSize.width
        let popoverHeight = popoverSize.height

        let win = KeyableWindow(
            contentRect: CGRect(x: 0, y: 0, width: popoverWidth, height: popoverHeight),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = true
        win.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 10)
        win.collectionBehavior = [.moveToActiveSpace, .stationary]
        win.appearance = nil

        let container = NSView(frame: NSRect(x: 0, y: 0, width: popoverWidth, height: popoverHeight))
        container.wantsLayer = true
        container.layer?.backgroundColor = t.popoverBg.cgColor
        container.layer?.cornerRadius = t.popoverCornerRadius
        container.layer?.masksToBounds = true
        container.layer?.borderWidth = t.popoverBorderWidth
        container.layer?.borderColor = t.popoverBorder.cgColor
        container.autoresizingMask = [.width, .height]
        container.identifier = NSUserInterfaceItemIdentifier("popoverContainer")

        let titleBarHeight: CGFloat = 34
        let titleBar = NSView(frame: NSRect(x: 0, y: popoverHeight - titleBarHeight, width: popoverWidth, height: titleBarHeight))
        titleBar.wantsLayer = true
        titleBar.layer?.backgroundColor = t.titleBarBg.cgColor
        titleBar.layer?.cornerRadius = t.popoverCornerRadius
        titleBar.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        titleBar.autoresizingMask = [.width, .minYMargin]
        titleBar.identifier = NSUserInterfaceItemIdentifier("titleBar")
        container.addSubview(titleBar)

        let titleLabel = NSTextField(labelWithString: currentThread?.title ?? t.titleString)
        titleLabel.font = t.titleFont
        titleLabel.textColor = t.titleText
        titleLabel.frame = NSRect(x: 14, y: 9, width: popoverWidth - 150, height: 18)
        titleLabel.identifier = NSUserInterfaceItemIdentifier("titleLabel")
        titleLabel.autoresizingMask = [.width]
        titleBar.addSubview(titleLabel)

        func configureTitleButton(_ button: HoverCursorButton, symbol: String, action: Selector, identifier: String, x: CGFloat) {
            button.frame = NSRect(x: x, y: 4, width: 26, height: 26)
            button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            button.imageScaling = .scaleProportionallyDown
            button.bezelStyle = .inline
            button.isBordered = false
            button.contentTintColor = t.titleIconTint
            button.normalBackgroundColor = t.titleIconBg
            button.hoverBackgroundColor = t.titleIconHoverBg
            button.pressedBackgroundColor = t.titleIconHoverBg.withAlphaComponent(0.84)
            button.hoverCornerRadius = 13
            button.autoresizingMask = [.minXMargin]
            button.target = self
            button.action = action
            button.identifier = NSUserInterfaceItemIdentifier(identifier)
            titleBar.addSubview(button)
        }

        let newChatBtn = HoverCursorButton(frame: .zero)
        newChatBtn.image = NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: "New chat")
        configureTitleButton(newChatBtn, symbol: "square.and.pencil", action: #selector(startNewChatFromButton), identifier: "newChatButton", x: popoverWidth - 92)

        let historyBtn = HoverCursorButton(frame: .zero)
        configureTitleButton(historyBtn, symbol: "sidebar.left", action: #selector(toggleHistoryFromButton), identifier: "historyButton", x: popoverWidth - 60)

        let copyBtn = HoverCursorButton(frame: .zero)
        configureTitleButton(copyBtn, symbol: "square.on.square", action: #selector(copyLastResponseFromButton), identifier: "copyButton", x: popoverWidth - 28)

        let sep = NSView(frame: NSRect(x: 0, y: popoverHeight - titleBarHeight - 1, width: popoverWidth, height: 1))
        sep.wantsLayer = true
        sep.layer?.backgroundColor = t.separatorColor.cgColor
        sep.autoresizingMask = [.width, .minYMargin]
        sep.identifier = NSUserInterfaceItemIdentifier("titleSeparator")
        sep.isHidden = true
        container.addSubview(sep)

        let terminal = TerminalView(frame: NSRect(x: 0, y: 0, width: popoverWidth, height: popoverHeight - titleBarHeight))
        terminal.characterColor = characterColor
        terminal.themeOverride = themeOverride
        terminal.autoresizingMask = [.width, .height]
        terminal.onSendMessage = { [weak self] message in
            self?.ensureCurrentThread(using: message)
            self?.currentStreamingText = ""
            self?.session?.send(message: message)
            self?.persistCurrentThread()
        }
        terminal.onSkillInvoked = { [weak self] invocation in
            self?.runSkillInvocation(invocation) ?? false
        }
        terminal.onRequestSkillList = { query in
            SkillRegistry.shared.renderSkillList(query: query)
        }
        terminal.onWorkspaceCommand = { [weak self] path in
            self?.handleWorkspaceCommand(path) ?? "Workspace control is unavailable."
        }
        terminal.onClearRequested = { [weak self] in
            self?.session?.history.removeAll()
            self?.currentThread?.messages.removeAll()
            self?.persistCurrentThread()
        }
        terminal.onRequestMessages = { [weak self] in
            self?.session?.history ?? []
        }
        terminal.onRequestHistory = { [weak self] in
            let threads = ChatHistoryStore.shared.loadThreads(for: AgentProvider.current)
            self?.refreshHistoryTitlesIfNeeded(threads)
            return threads
        }
        terminal.onRequestCurrentThreadID = { [weak self] in
            self?.currentThread?.id
        }
        terminal.onHistorySelected = { [weak self] id in
            NSLog("WalkerCharacter.terminal.onHistorySelected id=%@", id.uuidString)
            self?.loadThread(id: id)
        }
        terminal.onHistoryDelete = { [weak self] id in
            self?.deleteThread(id: id)
        }
        terminal.onThemeRefreshRequested = { [weak self] in
            self?.refreshPopoverChromeTheme()
        }
        container.addSubview(terminal)
        installResizeHandles(in: container)

        win.fileDropHandler = { [weak self] urls in
            self?.handleExternalFileDrop(urls)
        }
        win.contentView = container
        popoverWindow = win
        terminalView = terminal
        refreshPopoverChromeTheme()
        applyCurrentThreadComposerState()
    }

    private func wireSession(_ session: any AgentSession, providerName: String = AgentProvider.current.displayName) {
        session.onText = { [weak self] text in
            self?.currentStreamingText += text
            self?.terminalView?.appendStreamingText(text)
        }

        session.onTurnComplete = { [weak self] in
            self?.finalizeStreamingAssistantMessageIfNeeded()
            self?.terminalView?.endStreaming()
            self?.persistCurrentThread()
            self?.currentStreamingText = ""
            self?.playCompletionSound()
            self?.showCompletionBubble()
        }

        session.onError = { [weak self] text in
            self?.terminalView?.appendError(text)
            self?.persistCurrentThread()
            self?.currentStreamingText = ""
        }

        session.onToolUse = { [weak self] toolName, input in
            guard let self = self else { return }
            let summary = self.formatToolInput(input)
            self.terminalView?.appendToolUse(toolName: toolName, summary: summary)
        }

        session.onToolResult = { [weak self] summary, isError in
            self?.terminalView?.appendToolResult(summary: summary, isError: isError)
        }

        session.onProcessExit = { [weak self] in
            self?.terminalView?.endStreaming()
            self?.terminalView?.appendError("\(providerName) session ended.")
            self?.currentStreamingText = ""
        }
    }

    private func finalizeStreamingAssistantMessageIfNeeded() {
        guard let session else { return }
        let trimmed = currentStreamingText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let last = session.history.last,
           last.role == .assistant,
           last.text.trimmingCharacters(in: .whitespacesAndNewlines) == trimmed {
            return
        }

        session.history.append(AgentMessage(role: .assistant, text: trimmed))
    }

    @objc func copyLastResponseFromButton() {
        // Trigger the /copy slash command via the terminal view
        terminalView?.handleSlashCommandPublic("/copy")
    }

    @objc func toggleHistoryFromButton() {
        terminalView?.toggleHistoryPanel()
    }

    @objc func startNewChatFromButton() {
        persistCurrentThread()
        currentThread = nil
        session?.history.removeAll()
        skillRunner?.terminate()
        skillRunner = nil
        currentStreamingText = ""
        terminalView?.clearPendingAttachments()
        terminalView?.replayHistory([])
        terminalView?.toggleHistoryPanelIfNeededClose()
        updatePopoverTitle()
        applyCurrentThreadComposerState()
    }

    private func ensureCurrentThread(using firstUserMessage: String? = nil) {
        if currentThread != nil { return }
        currentThread = ChatThread(
            title: "New chat",
            titleSource: nil,
            provider: AgentProvider.current.rawValue,
            messages: session?.history.map { ChatHistoryMessage(role: $0.role, text: $0.text) } ?? []
        )
        refreshCurrentThreadTitleIfNeeded(firstUserMessage: firstUserMessage)
        updatePopoverTitle()
    }

    private func persistCurrentThread() {
        guard let session else { return }
        if currentThread?.titleSource == "setup" || currentThread?.titleSource == "debug" {
            return
        }
        if session.history.isEmpty && (currentThread?.messages.isEmpty ?? true) {
            return
        }
        ensureCurrentThread()
        guard var thread = currentThread else { return }
        thread.messages = session.history.map { ChatHistoryMessage(role: $0.role, text: $0.text) }
        thread.updatedAt = Date()
        currentThread = thread
        ChatHistoryStore.shared.upsert(thread: thread)
        refreshCurrentThreadTitleIfNeeded()
        updatePopoverTitle()
        applyCurrentThreadComposerState()
        terminalView?.reloadHistoryList()
    }

    private func loadThread(id: UUID) {
        NSLog("WalkerCharacter.loadThread.start id=%@", id.uuidString)
        guard let thread = ChatHistoryStore.shared.loadThreads(for: AgentProvider.current).first(where: { $0.id == id }) else { return }
        NSLog("WalkerCharacter.loadThread.found id=%@ title=%@", id.uuidString, thread.title)
        currentThread = thread
        session?.history = thread.messages.map(\.agentMessage)
        terminalView?.replayHistory(session?.history ?? [])
        refreshCurrentThreadTitleIfNeeded()
        updatePopoverTitle()
        applyCurrentThreadComposerState()
        terminalView?.reloadHistoryList()
        NSLog("WalkerCharacter.loadThread.completed id=%@ messageCount=%ld", id.uuidString, session?.history.count ?? 0)
    }

    private func deleteThread(id: UUID) {
        let provider = AgentProvider.current
        ChatHistoryStore.shared.deleteThread(id: id, provider: provider)

        if currentThread?.id == id {
            currentThread = nil
            session?.history.removeAll()
            currentStreamingText = ""
            terminalView?.clearPendingAttachments()
            terminalView?.replayHistory([])
            updatePopoverTitle()
        }

        terminalView?.reloadHistoryList()
    }

    private func refreshCurrentThreadTitleIfNeeded(firstUserMessage: String? = nil) {
        guard let thread = currentThread else { return }
        let provider = AgentProvider(rawValue: thread.provider) ?? AgentProvider.current

        var candidate = thread
        if candidate.messages.isEmpty,
           let firstUserMessage,
           !firstUserMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            candidate.messages = [ChatHistoryMessage(role: .user, text: firstUserMessage)]
        }

        ChatTitleGenerator.shared.refreshTitleIfNeeded(for: candidate, using: provider) { [weak self] title in
            guard let self else { return }
            guard var latest = ChatHistoryStore.shared.loadThreads(for: provider).first(where: { $0.id == candidate.id }) ?? self.currentThread,
                  latest.id == candidate.id else { return }

            latest.title = title
            latest.titleSource = "model"

            self.currentThread = latest
            ChatHistoryStore.shared.upsert(thread: latest)
            self.updatePopoverTitle()
            self.terminalView?.reloadHistoryList()
        }
    }

    private func refreshHistoryTitlesIfNeeded(_ threads: [ChatThread]) {
        for thread in threads {
            let provider = AgentProvider(rawValue: thread.provider) ?? AgentProvider.current
            ChatTitleGenerator.shared.refreshTitleIfNeeded(for: thread, using: provider) { [weak self] title in
                var updated = thread
                updated.title = title
                updated.titleSource = "model"

                if self?.currentThread?.id == updated.id {
                    self?.currentThread = updated
                    self?.updatePopoverTitle()
                }

                ChatHistoryStore.shared.upsert(thread: updated)
                self?.terminalView?.reloadHistoryList()
            }
        }
    }

    private func updatePopoverTitle() {
        guard let titleBar = popoverWindow?.contentView?.subviews.first?.subviews.first,
              let label = titleBar.subviews.first(where: { $0.identifier?.rawValue == "titleLabel" }) as? NSTextField else { return }
        label.stringValue = currentThread?.title ?? resolvedTheme.titleString
    }

    private func refreshPopoverChromeTheme() {
        guard let container = popoverWindow?.contentView?.subviews.first else { return }
        let t = resolvedTheme
        let titleBar = container.subviews.first(where: { $0.identifier?.rawValue == "titleBar" })
        container.wantsLayer = true
        container.layer?.backgroundColor = t.popoverBg.cgColor
        container.layer?.cornerRadius = t.popoverCornerRadius
        container.layer?.borderWidth = t.popoverBorderWidth
        container.layer?.borderColor = t.popoverBorder.cgColor

        if let titleBar {
            titleBar.wantsLayer = true
            titleBar.layer?.backgroundColor = t.titleBarBg.cgColor
            titleBar.layer?.cornerRadius = t.popoverCornerRadius
            titleBar.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        }

        if let separator = container.subviews.first(where: { $0.identifier?.rawValue == "titleSeparator" }) {
            separator.wantsLayer = true
            separator.layer?.backgroundColor = t.separatorColor.cgColor
            separator.isHidden = true
        }

        if let titleBar,
           let label = titleBar.subviews.first(where: { $0.identifier?.rawValue == "titleLabel" }) as? NSTextField {
            label.font = t.titleFont
            label.textColor = t.titleText
        }

        for buttonID in ["newChatButton", "historyButton", "copyButton"] {
            if let button = titleBar?.subviews
                .first(where: { $0.identifier?.rawValue == buttonID }) as? HoverCursorButton {
                button.contentTintColor = t.titleIconTint
                button.normalBackgroundColor = t.titleIconBg
                button.hoverBackgroundColor = t.titleIconHoverBg
                button.pressedBackgroundColor = t.titleIconHoverBg.withAlphaComponent(0.84)
                button.updateCursorIfMouseInside()
            }
        }
    }

    private func resizePopover(deltaX: CGFloat, deltaY: CGFloat) {
        resizePopover(edge: .bottomRight, deltaX: deltaX, deltaY: deltaY)
    }

    private func resizePopover(edge: ResizeEdge, deltaX: CGFloat, deltaY: CGFloat) {
        guard let popover = popoverWindow else { return }
        let startFrame = resizeStartFrame ?? popover.frame
        let minWidth: CGFloat = 360
        let minHeight: CGFloat = 260
        let maxWidth: CGFloat = 760
        let maxHeight: CGFloat = 720

        var newFrame = startFrame

        switch edge {
        case .left, .topLeft, .bottomLeft:
            let proposedWidth = startFrame.width - deltaX
            let clampedWidth = min(max(minWidth, proposedWidth), maxWidth)
            newFrame.origin.x = startFrame.maxX - clampedWidth
            newFrame.size.width = clampedWidth
        case .right, .topRight, .bottomRight:
            let proposedWidth = startFrame.width + deltaX
            newFrame.size.width = min(max(minWidth, proposedWidth), maxWidth)
        case .top, .bottom:
            break
        }

        switch edge {
        case .bottom, .bottomLeft, .bottomRight:
            let proposedHeight = startFrame.height - deltaY
            let clampedHeight = min(max(minHeight, proposedHeight), maxHeight)
            newFrame.origin.y = startFrame.maxY - clampedHeight
            newFrame.size.height = clampedHeight
        case .top, .topLeft, .topRight:
            let proposedHeight = startFrame.height + deltaY
            newFrame.size.height = min(max(minHeight, proposedHeight), maxHeight)
        case .left, .right:
            break
        }

        popoverSize = newFrame.size
        savePopoverSize()
        popover.setFrame(newFrame, display: true)
        if let container = popover.contentView {
            container.frame = NSRect(origin: .zero, size: popoverSize)
            if let terminal = terminalView {
                terminal.frame = NSRect(x: 0, y: 0, width: popoverSize.width, height: popoverSize.height - 34)
            }
        }
    }

    private func beginResize() {
        isResizingPopover = true
        resizeStartFrame = popoverWindow?.frame
    }

    private func endResize() {
        resizeStartFrame = nil
        isResizingPopover = false
    }

    private func installResizeHandles(in container: NSView) {
        resizeHandles.forEach { $0.removeFromSuperview() }
        resizeHandles.removeAll()

        let edgeThickness: CGFloat = 8
        let cornerSize: CGFloat = 18
        let w = popoverSize.width
        let h = popoverSize.height
        let definitions: [(ResizeEdge, NSRect, NSView.AutoresizingMask)] = [
            (.left, NSRect(x: 0, y: cornerSize, width: edgeThickness, height: max(0, h - cornerSize * 2)), [.height, .maxXMargin]),
            (.right, NSRect(x: w - edgeThickness, y: cornerSize, width: edgeThickness, height: max(0, h - cornerSize * 2)), [.height, .minXMargin]),
            (.top, NSRect(x: cornerSize, y: h - edgeThickness, width: max(0, w - cornerSize * 2), height: edgeThickness), [.width, .minYMargin]),
            (.bottom, NSRect(x: cornerSize, y: 0, width: max(0, w - cornerSize * 2), height: edgeThickness), [.width, .maxYMargin]),
            (.topLeft, NSRect(x: 0, y: h - cornerSize, width: cornerSize, height: cornerSize), [.maxXMargin, .minYMargin]),
            (.topRight, NSRect(x: w - cornerSize, y: h - cornerSize, width: cornerSize, height: cornerSize), [.minXMargin, .minYMargin]),
            (.bottomLeft, NSRect(x: 0, y: 0, width: cornerSize, height: cornerSize), [.maxXMargin, .maxYMargin]),
            (.bottomRight, NSRect(x: w - cornerSize, y: 0, width: cornerSize, height: cornerSize), [.minXMargin, .maxYMargin])
        ]

        for (edge, frame, autoresizing) in definitions {
            let view = ResizeHandleView(frame: frame, edge: edge)
            view.autoresizingMask = autoresizing
            view.onDragStart = { [weak self] _ in
                self?.beginResize()
            }
            view.onDrag = { [weak self] edge, dx, dy in
                self?.resizePopover(edge: edge, deltaX: dx, deltaY: dy)
            }
            view.onDragEnd = { [weak self] _ in
                self?.endResize()
            }
            container.addSubview(view)
            resizeHandles.append(view)
        }
    }

    private func formatToolInput(_ input: [String: Any]) -> String {
        if let cmd = input["command"] as? String { return cmd }
        if let path = input["file_path"] as? String { return path }
        if let pattern = input["pattern"] as? String { return pattern }
        return input.keys.sorted().prefix(3).joined(separator: ", ")
    }

    private func createSkillOrbitWindowIfNeeded() {
        guard skillOrbitWindow == nil else { return }

        let size = Self.skillOrbitSize
        let win = SkillOrbitWindow(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue - 1)
        win.collectionBehavior = [.moveToActiveSpace, .stationary]

        let container = NSView(frame: CGRect(origin: .zero, size: size))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor

        let hoverContainer = SkillOrbitHoverLabelView(frame: CGRect(x: 40, y: 204, width: 212, height: 30))
        hoverContainer.wantsLayer = true
        hoverContainer.layer?.backgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.94).cgColor
        hoverContainer.layer?.cornerRadius = 15
        hoverContainer.layer?.borderWidth = 1
        hoverContainer.layer?.borderColor = NSColor.white.withAlphaComponent(0.6).cgColor
        hoverContainer.layer?.shadowColor = NSColor.black.cgColor
        hoverContainer.layer?.shadowOpacity = 0.12
        hoverContainer.layer?.shadowRadius = 10
        hoverContainer.layer?.shadowOffset = CGSize(width: 0, height: -1)
        hoverContainer.layer?.zPosition = 20
        hoverContainer.alphaValue = 0
        hoverContainer.isHidden = true

        let hoverLabel = NSTextField(labelWithString: "")
        hoverLabel.frame = hoverContainer.bounds.insetBy(dx: 12, dy: 5)
        hoverLabel.alignment = .center
        hoverLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        hoverLabel.textColor = NSColor(calibratedWhite: 0.08, alpha: 1.0)
        hoverLabel.lineBreakMode = .byTruncatingTail
        hoverLabel.autoresizingMask = [.width, .height]
        hoverContainer.addSubview(hoverLabel)
        container.addSubview(hoverContainer)
        skillOrbitHoverLabelContainer = hoverContainer
        skillOrbitHoverLabel = hoverLabel

        let centerOrigin = Self.skillOrbitCenterOrigin(for: skillOrbitCurrentAnchor)
        let orbSize = Self.skillOrbSize

        skillOrbitButtons.removeAll()
        for (index, item) in QuickSkillShortcutCatalog.slotDefinitions.enumerated() {
            let button = SkillOrbitButton(frame: CGRect(origin: centerOrigin, size: CGSize(width: orbSize, height: orbSize)))
            button.wantsLayer = true
            button.isBordered = false
            button.bezelStyle = .regularSquare
            button.layer?.cornerRadius = orbSize / 2
            button.layer?.masksToBounds = false
            button.layer?.borderWidth = 1
            button.layer?.borderColor = NSColor.white.withAlphaComponent(0.55).cgColor
            button.normalBackgroundColor = NSColor(calibratedWhite: 0.98, alpha: 0.98)
            button.hoverBackgroundColor = NSColor(calibratedRed: 1.0, green: 0.878, blue: 0.2, alpha: 0.98)
            button.iconTintColor = NSColor(calibratedWhite: 0.08, alpha: 1.0)
            button.layer?.shadowColor = NSColor.black.cgColor
            button.layer?.shadowOpacity = 0.18
            button.layer?.shadowRadius = 14
            button.layer?.shadowOffset = CGSize(width: 0, height: -1)
            button.alphaValue = 0
            button.image = NSImage(systemSymbolName: QuickSkillShortcutStore.shared.iconSymbolName(for: item), accessibilityDescription: item.orbitLabel)
            button.imageScaling = .scaleProportionallyDown
            button.imagePosition = .imageOnly
            button.toolTip = nil
            button.onHoverChanged = { [weak self] isHovering in
                self?.updateSkillOrbitHoverLabel(for: item, buttonIndex: index, isHovering: isHovering)
            }
            button.tag = index
            button.target = self
            button.action = #selector(skillShortcutPressed(_:))
            container.addSubview(button)
            skillOrbitButtons.append(button)
        }

        win.contentView = container
        skillOrbitWindow = win
    }

    private func openSkillOrbit() {
        if let siblings = controller?.characters {
            for sibling in siblings where sibling !== self {
                sibling.closeSkillOrbit(animated: false)
            }
        }

        if isIdleForPopover {
            closePopover()
        }

        enterSkillOrbitIdleState()
        skillOrbitCurrentAnchor = Self.skillOrbitAnchor
        createSkillOrbitWindowIfNeeded()
        skillOrbitButtons.forEach { $0.resetHoverState() }
        hoveredSkillOrbitButtonIndex = nil
        updateSkillOrbitHoverLabel(text: nil, visible: false)
        let currentFrame = currentDockCharacterFrame()
        window.setFrameOrigin(currentFrame.origin)
        skillOrbitWindow?.setFrame(initialSkillOrbitFrame(for: currentFrame), display: false)
        skillOrbitWindow?.alphaValue = 1
        skillOrbitWindow?.orderFrontRegardless()
        syncMotionStateImmediately()

        removeSkillOrbitEventMonitors()
        skillOrbitClickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self else { return }
            let orbitFrame = self.skillOrbitWindow?.frame ?? .zero
            let charFrame = self.window.frame
            let mouse = NSEvent.mouseLocation
            if !orbitFrame.contains(mouse) && !charFrame.contains(mouse) {
                self.closeSkillOrbit(animated: true)
            }
        }
        skillOrbitEscapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.closeSkillOrbit(animated: true)
                return nil
            }
            return event
        }

        let finalLayout = skillOrbitLayout(for: currentFrame)
        animateSkillOrbitPresentation(to: finalLayout) { [weak self] in
            self?.animateSkillOrbit(expanding: true, completion: nil)
        }
    }

    private func closeSkillOrbit(animated: Bool, completion: (() -> Void)? = nil) {
        guard skillOrbitWindow?.isVisible == true else {
            completion?()
            return
        }

        removeSkillOrbitEventMonitors()
        skillOrbitButtons.forEach { $0.resetHoverState() }
        hoveredSkillOrbitButtonIndex = nil
        updateSkillOrbitHoverLabel(text: nil, visible: false)
        if animated {
            animateSkillOrbit(expanding: false) { [weak self] in
                guard let self else {
                    completion?()
                    return
                }
                self.animateSkillOrbitReturnToDockPosition {
                    self.skillOrbitWindow?.orderOut(nil)
                    self.exitSkillOrbitIdleState()
                    completion?()
                }
            }
        } else {
            cancelSkillOrbitAnimations()
            skillOrbitWindow?.orderOut(nil)
            exitSkillOrbitIdleState()
            completion?()
        }
    }

    private func cancelSkillOrbitAnimations() {
        skillOrbitAnimationGeneration += 1
        skillOrbitAnimationWorkItems.forEach { $0.cancel() }
        skillOrbitAnimationWorkItems.removeAll()
        isAnimatingSkillOrbitButtons = false
    }

    private func animateSkillOrbit(expanding: Bool, completion: (() -> Void)?) {
        guard !skillOrbitButtons.isEmpty else {
            isAnimatingSkillOrbitButtons = false
            completion?()
            return
        }

        cancelSkillOrbitAnimations()
        isAnimatingSkillOrbitButtons = true
        let generation = skillOrbitAnimationGeneration
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let baseDuration = reduceMotion ? 0.12 : (expanding ? 0.26 : 0.2)
        let stepDelay = reduceMotion ? 0.0 : 0.045
        let centerOrigin = Self.skillOrbitCenterOrigin(for: skillOrbitCurrentAnchor)

        let orderedIndices = expanding ? Array(skillOrbitButtons.indices) : Array(skillOrbitButtons.indices.reversed())

        if expanding {
            for button in skillOrbitButtons {
                button.frame.origin = centerOrigin
                button.alphaValue = reduceMotion ? 1 : 0
            }
        }

        for (order, buttonIndex) in orderedIndices.enumerated() {
            let workItem = DispatchWorkItem { [weak self] in
                guard let self, self.skillOrbitAnimationGeneration == generation else { return }
                let item = QuickSkillShortcutCatalog.slotDefinitions[buttonIndex]
                let button = self.skillOrbitButtons[buttonIndex]
                let targetOrigin = Self.skillOrbitButtonOrigin(for: item, anchor: self.skillOrbitCurrentAnchor)

                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = baseDuration
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    button.animator().setFrameOrigin(expanding ? targetOrigin : centerOrigin)
                    button.animator().alphaValue = expanding ? 1 : 0
                }, completionHandler: {
                    if order == orderedIndices.count - 1 {
                        self.isAnimatingSkillOrbitButtons = false
                        completion?()
                    }
                })
            }

            skillOrbitAnimationWorkItems.append(workItem)
            let delay = stepDelay * Double(order)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        }
    }

    private func animateSkillOrbitPresentation(to layout: SkillOrbitLayout, completion: @escaping () -> Void) {
        guard let orbit = skillOrbitWindow else {
            completion()
            return
        }

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let currentCharacterOrigin = window.frame.origin
        let currentOrbitOrigin = orbit.frame.origin
        let needsAnimation =
            !reduceMotion &&
            (abs(currentCharacterOrigin.x - layout.characterOrigin.x) > 0.5 ||
             abs(currentCharacterOrigin.y - layout.characterOrigin.y) > 0.5 ||
             abs(currentOrbitOrigin.x - layout.orbitFrame.origin.x) > 0.5 ||
             abs(currentOrbitOrigin.y - layout.orbitFrame.origin.y) > 0.5)

        skillOrbitCurrentAnchor = layout.orbitAnchor

        guard needsAnimation else {
            window.setFrameOrigin(layout.characterOrigin)
            orbit.setFrame(layout.orbitFrame, display: false)
            completion()
            return
        }

        isAnimatingSkillOrbitPresentation = true
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Self.skillOrbitPresentationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrameOrigin(layout.characterOrigin)
            orbit.animator().setFrameOrigin(layout.orbitFrame.origin)
        }, completionHandler: { [weak self] in
            guard let self else { return }
            self.isAnimatingSkillOrbitPresentation = false
            self.window.setFrameOrigin(layout.characterOrigin)
            orbit.setFrame(layout.orbitFrame, display: false)
            completion()
        })
    }

    private func animateSkillOrbitReturnToDockPosition(completion: @escaping () -> Void) {
        guard let orbit = skillOrbitWindow else {
            completion()
            return
        }

        let naturalFrame = currentDockCharacterFrame()
        let targetCharacterOrigin = naturalFrame.origin
        let targetOrbitFrame = initialSkillOrbitFrame(for: naturalFrame)
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let currentCharacterOrigin = window.frame.origin
        let currentOrbitOrigin = orbit.frame.origin
        let needsAnimation =
            !reduceMotion &&
            (abs(currentCharacterOrigin.x - targetCharacterOrigin.x) > 0.5 ||
             abs(currentCharacterOrigin.y - targetCharacterOrigin.y) > 0.5 ||
             abs(currentOrbitOrigin.x - targetOrbitFrame.origin.x) > 0.5 ||
             abs(currentOrbitOrigin.y - targetOrbitFrame.origin.y) > 0.5)

        skillOrbitCurrentAnchor = Self.skillOrbitAnchor

        guard needsAnimation else {
            window.setFrameOrigin(targetCharacterOrigin)
            orbit.setFrame(targetOrbitFrame, display: false)
            completion()
            return
        }

        isAnimatingSkillOrbitPresentation = true
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Self.skillOrbitPresentationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrameOrigin(targetCharacterOrigin)
            orbit.animator().setFrameOrigin(targetOrbitFrame.origin)
        }, completionHandler: { [weak self] in
            guard let self else { return }
            self.isAnimatingSkillOrbitPresentation = false
            self.window.setFrameOrigin(targetCharacterOrigin)
            orbit.setFrame(targetOrbitFrame, display: false)
            completion()
        })
    }

    @objc private func skillShortcutPressed(_ sender: NSButton) {
        let index = sender.tag
        guard QuickSkillShortcutCatalog.slotDefinitions.indices.contains(index) else { return }
        let item = QuickSkillShortcutCatalog.slotDefinitions[index]

        closeSkillOrbit(animated: true) { [weak self] in
            self?.runSkillShortcut(item)
        }
    }

    private func runSkillShortcut(_ item: QuickSkillSlotDefinition) {
        guard let resolvedSkillName = QuickSkillShortcutStore.shared.resolvedSkillName(for: item) else {
            openPopover()
            terminalView?.endStreaming()
            terminalView?.appendError("No installed skill is configured for \(item.menuTitle). Choose one from the menu bar Skills submenu first.")
            return
        }

        let (skills, missing) = SkillRegistry.shared.findSkills(named: [resolvedSkillName])
        guard missing.isEmpty, let skill = skills.first else {
            openPopover()
            terminalView?.endStreaming()
            terminalView?.appendError("The configured skill `\(resolvedSkillName)` is no longer available. Reassign \(item.menuTitle) from the menu bar Skills submenu.")
            return
        }

        openPopover()
        startNewChatFromButton()
        terminalView?.addPendingSkills([skill], preferredSymbolName: QuickSkillShortcutStore.shared.iconSymbolName(for: item))
        popoverWindow?.orderFrontRegardless()
        popoverWindow?.makeKey()
        if let terminal = terminalView {
            popoverWindow?.makeFirstResponder(terminal.inputField)
        }
    }

    func reloadSkillOrbitConfiguration() {
        let wasVisible = skillOrbitWindow?.isVisible == true
        cancelSkillOrbitAnimations()
        removeSkillOrbitEventMonitors()
        skillOrbitWindow?.orderOut(nil)
        skillOrbitWindow = nil
        skillOrbitButtons.removeAll()
        skillOrbitCurrentAnchor = Self.skillOrbitAnchor
        if wasVisible {
            openSkillOrbit()
        }
    }

    private func skillOrbitLayout(for characterFrame: CGRect) -> SkillOrbitLayout {
        let desiredAnchor = CGPoint(
            x: characterFrame.midX,
            y: characterFrame.minY + characterFrame.height * 0.58
        )
        let size = Self.skillOrbitSize
        var frame = CGRect(
            x: desiredAnchor.x - Self.skillOrbitAnchor.x,
            y: desiredAnchor.y - Self.skillOrbitAnchor.y,
            width: size.width,
            height: size.height
        )

        if let screen = window.screen ?? NSScreen.main {
            let bounds = screen.visibleFrame.insetBy(dx: 4, dy: 4)
            frame.origin.x = min(max(frame.origin.x, bounds.minX), bounds.maxX - frame.width)
            frame.origin.y = min(max(frame.origin.y, bounds.minY), bounds.maxY - frame.height)
        }

        let anchorBounds = Self.skillOrbitAnchorBounds
        let rawAnchor = CGPoint(
            x: desiredAnchor.x - frame.origin.x,
            y: desiredAnchor.y - frame.origin.y
        )
        let orbitAnchor = CGPoint(
            x: min(max(rawAnchor.x, anchorBounds.minX), anchorBounds.maxX),
            y: min(max(rawAnchor.y, anchorBounds.minY), anchorBounds.maxY)
        )
        let characterOrigin = CGPoint(
            x: frame.origin.x + orbitAnchor.x - characterFrame.width / 2,
            y: characterFrame.origin.y
        )

        return SkillOrbitLayout(
            orbitFrame: frame,
            orbitAnchor: orbitAnchor,
            characterOrigin: characterOrigin
        )
    }

    private func initialSkillOrbitFrame(for characterFrame: CGRect) -> CGRect {
        let desiredAnchor = CGPoint(
            x: characterFrame.midX,
            y: characterFrame.minY + characterFrame.height * 0.58
        )
        return CGRect(
            x: desiredAnchor.x - Self.skillOrbitAnchor.x,
            y: desiredAnchor.y - Self.skillOrbitAnchor.y,
            width: Self.skillOrbitSize.width,
            height: Self.skillOrbitSize.height
        )
    }

    private func currentDockCharacterFrame() -> CGRect {
        let travelDistance = max(lastDockWidth - displayWidth, 0)
        let x = lastDockX + travelDistance * positionProgress + currentFlipCompensation
        let bottomPadding = displayHeight * 0.15
        let y = lastDockTopY - bottomPadding + yOffset
        return CGRect(x: x, y: y, width: displayWidth, height: displayHeight)
    }

    private func syncSkillOrbitButtonsToExpandedState(anchor: CGPoint) {
        for (index, button) in skillOrbitButtons.enumerated() {
            let item = QuickSkillShortcutCatalog.slotDefinitions[index]
            button.frame.origin = Self.skillOrbitButtonOrigin(for: item, anchor: anchor)
            button.alphaValue = 1
        }
    }

    private func updateSkillOrbitHoverLabel(for item: QuickSkillSlotDefinition, buttonIndex: Int, isHovering: Bool) {
        if isHovering {
            hoveredSkillOrbitButtonIndex = buttonIndex
            updateSkillOrbitHoverLabel(text: QuickSkillShortcutStore.shared.displaySkillName(for: item), visible: true)
            return
        }

        guard hoveredSkillOrbitButtonIndex == buttonIndex else { return }
        hoveredSkillOrbitButtonIndex = nil
        updateSkillOrbitHoverLabel(text: nil, visible: false)
    }

    private func updateSkillOrbitHoverLabel(text: String?, visible: Bool) {
        guard let container = skillOrbitHoverLabelContainer, let label = skillOrbitHoverLabel else { return }

        label.stringValue = text ?? ""
        container.isHidden = !visible
        container.alphaValue = visible ? 1 : 0
    }

    private func updateSkillOrbitPosition(syncButtonsToExpandedState: Bool = true) {
        guard let orbit = skillOrbitWindow else { return }
        let layout = skillOrbitLayout(for: currentDockCharacterFrame())
        skillOrbitCurrentAnchor = layout.orbitAnchor
        window.setFrameOrigin(layout.characterOrigin)
        orbit.setFrame(layout.orbitFrame, display: false)
        if syncButtonsToExpandedState {
            syncSkillOrbitButtonsToExpandedState(anchor: layout.orbitAnchor)
        }
    }

    private func handleWorkspaceCommand(_ path: String?) -> String {
        guard let path, !path.isEmpty else {
            return "Current agent workspace: `\(AgentWorkspaceStore.shared.currentURL.path)`"
        }

        switch AgentWorkspaceStore.shared.update(path: path) {
        case .success(let url):
            return "Agent workspace updated to `\(url.path)`"
        case .failure(let error):
            return error.errorDescription ?? "Failed to update workspace."
        }
    }

    private func runSkillInvocation(_ invocation: SkillInvocation) -> Bool {
        let (skills, missing) = SkillRegistry.shared.findSkills(named: invocation.skillNames)
        guard missing.isEmpty else {
            terminalView?.endStreaming()
            terminalView?.appendError("Missing skill(s): \(missing.joined(separator: ", ")). Try `/skills` to browse installed skills.")
            return true
        }

        guard !skills.isEmpty else {
            terminalView?.endStreaming()
            terminalView?.appendError("No matching skills were found.")
            return true
        }

        if skillRunner?.isBusy == true {
            terminalView?.endStreaming()
            terminalView?.appendError("A skill run is already in progress. Wait for it to finish before starting another.")
            return true
        }

        ensureCurrentThread(using: invocation.commandText)
        session?.history.append(AgentMessage(role: .user, text: invocation.commandText))
        persistCurrentThread()

        let workspaceURL = AgentWorkspaceStore.shared.currentURL
        let runner = CodexSkillRunner()
        skillRunner = runner

        let skillSummary = skills.map(\.name).joined(separator: ", ")
        let startSummary = "\(skillSummary) @ \(workspaceURL.path)"
        session?.history.append(AgentMessage(role: .toolUse, text: "Skill: \(startSummary)"))
        terminalView?.appendToolUse(toolName: "Skill", summary: startSummary)

        runner.onText = { [weak self] text in
            guard let self else { return }
            self.currentStreamingText += text
            self.terminalView?.appendStreamingText(text)
        }

        runner.onError = { [weak self] text in
            guard let self else { return }
            self.session?.history.append(AgentMessage(role: .error, text: text))
            self.terminalView?.appendError(text)
            self.persistCurrentThread()
        }

        runner.onToolUse = { [weak self] toolName, input in
            guard let self else { return }
            let summary = self.formatToolInput(input)
            self.session?.history.append(AgentMessage(role: .toolUse, text: "\(toolName): \(summary)"))
            self.terminalView?.appendToolUse(toolName: toolName, summary: summary)
        }

        runner.onToolResult = { [weak self] summary, isError in
            guard let self else { return }
            self.session?.history.append(AgentMessage(role: .toolResult, text: isError ? "ERROR: \(summary)" : summary))
            self.terminalView?.appendToolResult(summary: summary, isError: isError)
        }

        runner.onTurnComplete = { [weak self] in
            guard let self else { return }
            self.finalizeStreamingAssistantMessageIfNeeded()
            self.terminalView?.endStreaming()
            self.persistCurrentThread()
            self.currentStreamingText = ""
            self.playCompletionSound()
            self.showCompletionBubble()
            self.skillRunner = nil
        }

        runner.run(
            skills: skills,
            prompt: invocation.composedPrompt(),
            workspaceURL: workspaceURL
        )
        return true
    }

    func updatePopoverPosition() {
        guard let popover = popoverWindow, isIdleForPopover else { return }
        guard !isResizingPopover else { return }
        guard let screen = NSScreen.main else { return }

        let charFrame = window.frame
        let popoverSize = popover.frame.size
        var x = charFrame.midX - popoverSize.width / 2
        let y = charFrame.maxY - 15

        let screenFrame = screen.frame
        x = max(screenFrame.minX + 4, min(x, screenFrame.maxX - popoverSize.width - 4))
        let clampedY = min(y, screenFrame.maxY - popoverSize.height - 4)

        popover.setFrameOrigin(NSPoint(x: x, y: clampedY))
    }

    // MARK: - Thinking Bubble

    private static let thinkingPhrases = [
        "hmm...", "thinking...", "one sec...", "ok hold on",
        "let me check", "working on it", "almost...", "bear with me",
        "on it!", "gimme a sec", "brb", "processing...",
        "hang tight", "just a moment", "figuring it out",
        "crunching...", "reading...", "looking...",
        "cooking...", "vibing...", "digging in",
        "connecting dots", "give me a sec",
        "don't rush me", "calculating...", "assembling\u{2026}"
    ]

    private static let completionPhrases = [
        "done!", "all set!", "ready!", "here you go", "got it!",
        "finished!", "ta-da!", "voila!",
        "boom!", "there ya go!", "check it out!"
    ]

    private var lastPhraseUpdate: CFTimeInterval = 0
    var currentPhrase = ""
    var completionBubbleExpiry: CFTimeInterval = 0
    var showingCompletion = false

    private static let bubbleMinH: CGFloat = 26
    private static let bubbleMaxWidth: CGFloat = 220
    private static let bubbleHorizontalPadding: CGFloat = 14
    private static let bubbleMeasurementSlack: CGFloat = 12
    private static let bubbleVerticalPadding: CGFloat = 8
    private static let bubbleTitleBodySpacing: CGFloat = 6
    private static let bubbleTitleColor = NSColor(
        red: 15.0 / 255.0,
        green: 19.0 / 255.0,
        blue: 26.0 / 255.0,
        alpha: 1.0
    )
    private static let bubbleBodyColor = NSColor(
        red: 92.0 / 255.0,
        green: 95.0 / 255.0,
        blue: 102.0 / 255.0,
        alpha: 1.0
    )
    private var phraseAnimating = false

    func showExternalNotificationBubble(text: String, duration: CFTimeInterval = 30.0, threadID: UUID? = nil) {
        let parsed = Self.parseBubbleTitleAndBody(from: text)
        let now = CACurrentMediaTime()
        transientBubbleState = TransientBubbleState(
            title: parsed.title,
            body: parsed.body,
            expiresAt: now + duration,
            threadID: threadID
        )
        requestMessagePrompt(at: now)
        syncMotionStateImmediately(at: now)
        updateThinkingBubble()
    }

    func showExternalNotificationBubble(title: String, body: String?, duration: CFTimeInterval = 30.0, threadID: UUID? = nil) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = body?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedContent: (title: String?, body: String)
        if trimmedBody?.isEmpty == false {
            resolvedContent = (trimmedTitle.isEmpty ? nil : trimmedTitle, trimmedBody!)
        } else {
            resolvedContent = Self.parseBubbleTitleAndBody(from: trimmedTitle)
        }
        let now = CACurrentMediaTime()
        transientBubbleState = TransientBubbleState(
            title: resolvedContent.title,
            body: resolvedContent.body,
            expiresAt: now + duration,
            threadID: threadID
        )
        requestMessagePrompt(at: now)
        syncMotionStateImmediately(at: now)
        updateThinkingBubble()
    }

    func updateThinkingBubble() {
        let now = CACurrentMediaTime()

        if let transientBubbleState {
            if now >= transientBubbleState.expiresAt {
                self.transientBubbleState = nil
                hideBubble()
                return
            }
            if isIdleForPopover {
                hideBubble()
            } else {
                showBubble(
                    text: transientBubbleState.body,
                    title: transientBubbleState.title,
                    isCompletion: false,
                    allowsWrapping: true,
                    showsCloseButton: true
                )
            }
            return
        }

        if showingCompletion {
            if now >= completionBubbleExpiry {
                showingCompletion = false
                hideBubble()
                return
            }
            if isIdleForPopover {
                completionBubbleExpiry += 1.0 / 60.0
                hideBubble()
            } else {
                showBubble(text: currentPhrase, isCompletion: true)
            }
            return
        }

        if isAgentBusy && !isIdleForPopover {
            let oldPhrase = currentPhrase
            updateThinkingPhrase()
            if currentPhrase != oldPhrase && !oldPhrase.isEmpty && !phraseAnimating {
                animatePhraseChange(to: currentPhrase, isCompletion: false)
            } else if !phraseAnimating {
                showBubble(text: currentPhrase, isCompletion: false)
            }
        } else if !showingCompletion {
            hideBubble()
        }
    }

    private func hideBubble() {
        thinkingBubbleWindow?.ignoresMouseEvents = true
        if thinkingBubbleWindow?.isVisible ?? false {
            thinkingBubbleWindow?.orderOut(nil)
        }
    }

    private func animatePhraseChange(to newText: String, isCompletion: Bool) {
        guard let win = thinkingBubbleWindow, win.isVisible,
              let label = win.contentView?.viewWithTag(100) as? NSTextField else {
            showBubble(text: newText, isCompletion: isCompletion)
            return
        }
        phraseAnimating = true

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            ctx.allowsImplicitAnimation = true
            label.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            self?.showBubble(text: newText, isCompletion: isCompletion)
            label.alphaValue = 0.0
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.25
                ctx.allowsImplicitAnimation = true
                label.animator().alphaValue = 1.0
            }, completionHandler: {
                self?.phraseAnimating = false
            })
        })
    }

    private func dismissTransientBubble() {
        transientBubbleState = nil
        hideBubble()
    }

    private func handleTransientBubbleClick() {
        guard let transientBubbleState else { return }
        if let threadID = transientBubbleState.threadID {
            openReminderInbox(threadID: threadID)
            return
        }
        dismissTransientBubble()
    }

    func showBubble(
        text: String,
        title: String? = nil,
        isCompletion: Bool,
        allowsWrapping: Bool = false,
        showsCloseButton: Bool = false
    ) {
        let t = resolvedTheme
        if thinkingBubbleWindow == nil {
            createThinkingBubble()
        }

        let baseFont = t.bubbleFont
        let font = showsCloseButton
            ? NSFont.systemFont(ofSize: baseFont.pointSize + 2, weight: .regular)
            : baseFont
        let titleFont = NSFont.systemFont(ofSize: font.pointSize + 5, weight: .bold)
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasTitle = !(trimmedTitle?.isEmpty ?? true)
        let screenBounds = (window.screen ?? NSScreen.main)?.visibleFrame.insetBy(dx: 4, dy: 4)
            ?? CGRect(x: 0, y: 0, width: Self.bubbleMaxWidth, height: Self.bubbleMinH)

        let maxBubbleWidth = min(Self.bubbleMaxWidth, screenBounds.width)

        let drawingOptions: NSString.DrawingOptions = allowsWrapping
            ? [.usesLineFragmentOrigin, .usesFontLeading]
            : [.usesFontLeading]
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = allowsWrapping ? .byWordWrapping : .byTruncatingTail
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle
        ]
        let singleLineTextWidth = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in
                ceil((String(line) as NSString).size(withAttributes: [.font: font]).width)
            }
            .max() ?? 0
        let singleLineTitleWidth = hasTitle
            ? (trimmedTitle ?? "")
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { line in
                    ceil((String(line) as NSString).size(withAttributes: [.font: titleFont]).width)
                }
                .max() ?? 0
            : 0

        let preferredBubbleWidth = max(singleLineTextWidth, singleLineTitleWidth) + Self.bubbleHorizontalPadding * 2 + Self.bubbleMeasurementSlack
        let bubbleW = min(max(preferredBubbleWidth, 48), maxBubbleWidth)
        let textWidth = max(
            1,
            bubbleW - Self.bubbleHorizontalPadding * 2
        )
        let titleHeight = hasTitle
            ? ((trimmedTitle ?? "") as NSString).boundingRect(
                with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: titleFont]
            ).integral.height
            : 0
        let textHeight = (text as NSString).boundingRect(
            with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: drawingOptions,
            attributes: textAttributes
        ).integral.height
        let titleBlockHeight = hasTitle ? titleHeight + Self.bubbleTitleBodySpacing : 0
        let bubbleH = max(Self.bubbleMinH, titleBlockHeight + textHeight + Self.bubbleVerticalPadding * 2)

        let charFrame = window.frame
        let x = max(screenBounds.minX, min(charFrame.midX - bubbleW / 2, screenBounds.maxX - bubbleW))
        let y = max(screenBounds.minY, min(charFrame.origin.y + charFrame.height * 0.88, screenBounds.maxY - bubbleH))
        thinkingBubbleWindow?.setFrame(CGRect(x: x, y: y, width: bubbleW, height: bubbleH), display: false)
        thinkingBubbleWindow?.ignoresMouseEvents = !showsCloseButton

        let borderColor = isCompletion ? t.bubbleCompletionBorder.cgColor : t.bubbleBorder.cgColor
        let defaultTextColor = isCompletion ? t.bubbleCompletionText : t.bubbleText
        let titleColor = showsCloseButton && hasTitle ? Self.bubbleTitleColor : defaultTextColor
        let bodyColor = showsCloseButton ? Self.bubbleBodyColor : defaultTextColor

        if let container = thinkingBubbleWindow?.contentView as? BubbleContentView {
            container.frame = NSRect(x: 0, y: 0, width: bubbleW, height: bubbleH)
            if let bubbleBody = container.bubbleBodyView {
                bubbleBody.frame = NSRect(x: 0, y: 0, width: bubbleW, height: bubbleH)
                bubbleBody.wantsLayer = true
                bubbleBody.layer?.backgroundColor = t.bubbleBg.cgColor
                bubbleBody.layer?.cornerRadius = t.bubbleCornerRadius
                bubbleBody.layer?.borderColor = borderColor
                bubbleBody.layer?.borderWidth = 1
            }
            if let titleLabel = container.viewWithTag(101) as? NSTextField {
                titleLabel.isHidden = !hasTitle
                titleLabel.font = titleFont
                titleLabel.alignment = .left
                titleLabel.lineBreakMode = .byWordWrapping
                titleLabel.maximumNumberOfLines = 0
                titleLabel.cell?.wraps = true
                titleLabel.cell?.usesSingleLineMode = false
                titleLabel.cell?.lineBreakMode = .byWordWrapping
                titleLabel.textColor = titleColor
                titleLabel.stringValue = trimmedTitle ?? ""
                titleLabel.frame = NSRect(
                    x: Self.bubbleHorizontalPadding,
                    y: bubbleH - Self.bubbleVerticalPadding - titleHeight,
                    width: textWidth,
                    height: titleHeight
                )
            }
            if let label = container.viewWithTag(100) as? NSTextField {
                label.font = font
                label.lineBreakMode = allowsWrapping ? .byWordWrapping : .byTruncatingTail
                label.maximumNumberOfLines = allowsWrapping ? 0 : 1
                label.alignment = allowsWrapping ? .left : .center
                label.cell?.wraps = allowsWrapping
                label.cell?.usesSingleLineMode = !allowsWrapping
                label.cell?.lineBreakMode = allowsWrapping ? .byWordWrapping : .byTruncatingTail
                let labelHeight = max(ceil(textHeight), ceil(font.ascender - font.descender))
                let labelY: CGFloat
                if hasTitle {
                    labelY = Self.bubbleVerticalPadding - 1
                } else if allowsWrapping {
                    labelY = Self.bubbleVerticalPadding - 1
                } else {
                    labelY = round((bubbleH - labelHeight) / 2) - 1
                }
                label.frame = NSRect(
                    x: Self.bubbleHorizontalPadding,
                    y: labelY,
                    width: textWidth,
                    height: allowsWrapping || hasTitle
                        ? max(labelHeight + 2, bubbleH - Self.bubbleVerticalPadding * 2 - titleBlockHeight)
                        : labelHeight + 2
                )
                label.stringValue = text
                label.textColor = bodyColor
            }
        }

        if !(thinkingBubbleWindow?.isVisible ?? false) {
            thinkingBubbleWindow?.alphaValue = 1.0
            thinkingBubbleWindow?.orderFrontRegardless()
        }
    }

    private func updateThinkingPhrase() {
        let now = CACurrentMediaTime()
        if currentPhrase.isEmpty || now - lastPhraseUpdate > Double.random(in: 3.0...5.0) {
            var next = Self.thinkingPhrases.randomElement() ?? "..."
            while next == currentPhrase && Self.thinkingPhrases.count > 1 {
                next = Self.thinkingPhrases.randomElement() ?? "..."
            }
            currentPhrase = next
            lastPhraseUpdate = now
        }
    }

    func showCompletionBubble() {
        currentPhrase = Self.completionPhrases.randomElement() ?? "done!"
        showingCompletion = true
        completionBubbleExpiry = CACurrentMediaTime() + 3.0
        lastPhraseUpdate = 0
        phraseAnimating = false
        if !isIdleForPopover {
            showBubble(text: currentPhrase, isCompletion: true)
        }
    }

    private func createThinkingBubble() {
        let t = resolvedTheme
        let w: CGFloat = 80
        let h = Self.bubbleMinH
        let win = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: w, height: h),
            styleMask: .borderless, backing: .buffered, defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = true
        win.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 5)
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.moveToActiveSpace, .stationary]

        let container = BubbleContentView(frame: NSRect(x: 0, y: 0, width: w, height: h))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor

        let bubbleBody = NSView(frame: NSRect(x: 0, y: 0, width: w, height: h))
        bubbleBody.wantsLayer = true
        bubbleBody.layer?.backgroundColor = t.bubbleBg.cgColor
        bubbleBody.layer?.cornerRadius = t.bubbleCornerRadius
        bubbleBody.layer?.borderWidth = 1
        bubbleBody.layer?.borderColor = t.bubbleBorder.cgColor
        container.addSubview(bubbleBody)

        let font = t.bubbleFont
        let lineH = ceil(("Xg" as NSString).size(withAttributes: [.font: font]).height)
        let labelY = round((h - lineH) / 2) - 1

        let label = NSTextField(labelWithString: "")
        label.font = font
        label.textColor = t.bubbleText
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.cell?.wraps = false
        label.cell?.usesSingleLineMode = true
        label.cell?.lineBreakMode = .byTruncatingTail
        label.drawsBackground = false
        label.isBordered = false
        label.isEditable = false
        label.frame = NSRect(x: 0, y: labelY, width: w, height: lineH + 2)
        label.tag = 100
        bubbleBody.addSubview(label)

        let titleLabel = NSTextField(labelWithString: "")
        titleLabel.font = NSFont.systemFont(ofSize: font.pointSize + 5, weight: .bold)
        titleLabel.textColor = t.bubbleText
        titleLabel.alignment = .left
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.maximumNumberOfLines = 0
        titleLabel.cell?.wraps = true
        titleLabel.cell?.usesSingleLineMode = false
        titleLabel.cell?.lineBreakMode = .byWordWrapping
        titleLabel.drawsBackground = false
        titleLabel.isBordered = false
        titleLabel.isEditable = false
        titleLabel.isHidden = true
        titleLabel.tag = 101
        bubbleBody.addSubview(titleLabel)

        container.onClick = { [weak self] in
            self?.handleTransientBubbleClick()
        }
        container.bubbleBodyView = bubbleBody

        win.contentView = container
        thinkingBubbleWindow = win
    }

    private static func parseBubbleTitleAndBody(from text: String) -> (title: String?, body: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return (nil, text)
        }

        let newlineParts = trimmed
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if newlineParts.count >= 2, newlineParts[0].count <= 16 {
            return (newlineParts[0], newlineParts.dropFirst().joined(separator: "\n"))
        }

        let separators: Set<Character> = ["：", ":", "，", ",", "、"]
        if let separatorIndex = trimmed.firstIndex(where: { separators.contains($0) }) {
            let title = String(trimmed[..<separatorIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            let bodyStart = trimmed.index(after: separatorIndex)
            let body = String(trimmed[bodyStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if Self.isLikelyBubbleTitle(title), !body.isEmpty {
                return (title, body)
            }
        }

        return (nil, trimmed)
    }

    private static func isLikelyBubbleTitle(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...10).contains(trimmed.count) else { return false }
        let pattern = #"^[\p{Han}A-Za-z·_\-]+$"#
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: - Completion Sound

    static var soundsEnabled = true

    func applyAudioPreferences() {
        queuePlayer?.isMuted = !Self.soundsEnabled
    }

    private static let completionSounds: [(name: String, ext: String)] = [
        ("ping-aa", "mp3"), ("ping-bb", "mp3"), ("ping-cc", "mp3"),
        ("ping-dd", "mp3"), ("ping-ee", "mp3"), ("ping-ff", "mp3"),
        ("ping-gg", "mp3"), ("ping-hh", "mp3"), ("ping-jj", "m4a")
    ]
    private static var lastSoundIndex: Int = -1

    func playCompletionSound() {
        guard Self.soundsEnabled else { return }
        var idx: Int
        repeat {
            idx = Int.random(in: 0..<Self.completionSounds.count)
        } while idx == Self.lastSoundIndex && Self.completionSounds.count > 1
        Self.lastSoundIndex = idx

        let s = Self.completionSounds[idx]
        if let url = Bundle.main.url(forResource: s.name, withExtension: s.ext, subdirectory: "Sounds"),
           let sound = NSSound(contentsOf: url, byReference: true) {
            sound.play()
        }
    }

    // MARK: - Walking

    func startWalk() {
        isPaused = false
        isWalking = true
        playCount = 0
        walkStartTime = CACurrentMediaTime()

        if let forcedDirection = consumeForcedWalkDirection() {
            goingRight = forcedDirection == .right
        } else if positionProgress > 0.85 {
            goingRight = false
        } else if positionProgress < 0.15 {
            goingRight = true
        } else {
            goingRight = Bool.random()
        }

        walkStartPos = positionProgress
        // Walk a fixed pixel distance (~200-325px) regardless of screen width.
        let referenceWidth: CGFloat = 500.0
        let walkPixels = CGFloat.random(in: walkAmountRange) * referenceWidth
        let walkAmount = currentTravelDistance > 0 ? walkPixels / currentTravelDistance : 0.3
        if goingRight {
            walkEndPos = min(walkStartPos + walkAmount, 1.0)
        } else {
            walkEndPos = max(walkStartPos - walkAmount, 0.0)
        }
        // Store pixel positions so walk speed stays consistent if screen changes mid-walk
        walkStartPixel = walkStartPos * currentTravelDistance
        walkEndPixel = walkEndPos * currentTravelDistance

        let minSeparation: CGFloat = 0.12
        if let siblings = controller?.characters {
            for sibling in siblings where sibling !== self {
                let sibPos = sibling.positionProgress
                if abs(walkEndPos - sibPos) < minSeparation {
                    if goingRight {
                        walkEndPos = max(walkStartPos, sibPos - minSeparation)
                    } else {
                        walkEndPos = min(walkStartPos, sibPos + minSeparation)
                    }
                }
            }
        }

        updateFlip()
        queuePlayer.seek(to: .zero)
        refreshMotionPlaybackState()
    }

    func enterPause() {
        isWalking = false
        isPaused = true
        // Keep the desktop characters feeling alive between walk loops.
        let delay = Double.random(in: 2.0...4.5)
        pauseEndTime = CACurrentMediaTime() + delay
        refreshMotionPlaybackState()
    }

    func updateFlip() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if CharacterFacingPresentation.shouldMirrorPose(
            state: currentMotionState,
            playbackMode: currentMotionPlaybackMode,
            isWalking: isWalking,
            goingRight: goingRight
        ) {
            playerLayer.transform = CATransform3DMakeScale(-1, 1, 1)
        } else {
            playerLayer.transform = CATransform3DIdentity
        }
        playerLayer.frame = CGRect(x: 0, y: 0, width: displayWidth, height: displayHeight)
        CATransaction.commit()
    }

    var currentFlipCompensation: CGFloat {
        CharacterFacingPresentation.shouldMirrorPose(
            state: currentMotionState,
            playbackMode: currentMotionPlaybackMode,
            isWalking: isWalking,
            goingRight: goingRight
        ) ? flipXOffset : 0
    }

    func beginDrag(screenPoint: NSPoint) {
        guard !isIdleForPopover else { return }
        isDragging = true
        dragDidMove = false
        dragStartScreenX = screenPoint.x
        dragMouseOffsetX = screenPoint.x - window.frame.origin.x
        isWalking = false
        isPaused = true
        setHoveringCharacter(false)
        refreshMotionPlaybackState()
        hideBubble()
        syncMotionStateImmediately()
    }

    func updateDrag(screenPoint: NSPoint) {
        guard isDragging else { return }
        let minMoved: CGFloat = 4
        if abs(screenPoint.x - dragStartScreenX) > minMoved {
            dragDidMove = true
        }

        let travelDistance = max(lastDockWidth - displayWidth, 0)
        guard travelDistance > 0 else { return }

        let rawX = screenPoint.x - dragMouseOffsetX
        let minX = lastDockX
        let maxX = lastDockX + travelDistance
        let clampedX = min(max(rawX, minX), maxX)
        positionProgress = min(max((clampedX - lastDockX) / travelDistance, 0), 1)

        goingRight = screenPoint.x >= window.frame.midX
        updateFlip()
        let bottomPadding = displayHeight * 0.15
        let y = lastDockTopY - bottomPadding + yOffset
        window.setFrameOrigin(NSPoint(x: clampedX + currentFlipCompensation, y: y))
    }

    func endDrag() {
        guard isDragging else { return }
        isDragging = false
        let delay = dragDidMove ? Double.random(in: 2.0...4.0) : pauseEndTime
        pauseEndTime = CACurrentMediaTime() + delay
        syncMotionStateImmediately()
    }

    private func holdAutomaticTranslationIfNeeded() {
        guard !currentMotionState.allowsAutomaticTranslation else { return }

        var needsPlaybackRefresh = false
        if isWalking {
            isWalking = false
            needsPlaybackRefresh = true
        }
        if !isPaused {
            isPaused = true
            needsPlaybackRefresh = true
        }

        if needsPlaybackRefresh {
            refreshMotionPlaybackState()
        }
    }

    func movementPosition(at videoTime: CFTimeInterval) -> CGFloat {
        let dIn = fullSpeedStart - accelStart
        let dLin = decelStart - fullSpeedStart
        let dOut = walkStop - decelStart
        let v = 1.0 / (dIn / 2.0 + dLin + dOut / 2.0)

        if videoTime <= accelStart {
            return 0.0
        } else if videoTime <= fullSpeedStart {
            let t = videoTime - accelStart
            return CGFloat(v * t * t / (2.0 * dIn))
        } else if videoTime <= decelStart {
            let easeInDist = v * dIn / 2.0
            let t = videoTime - fullSpeedStart
            return CGFloat(easeInDist + v * t)
        } else if videoTime <= walkStop {
            let easeInDist = v * dIn / 2.0
            let linearDist = v * dLin
            let t = videoTime - decelStart
            return CGFloat(easeInDist + linearDist + v * (t - t * t / (2.0 * dOut)))
        } else {
            return 1.0
        }
    }

    // MARK: - Frame Update

    func update(dockX: CGFloat, dockWidth: CGFloat, dockTopY: CGFloat) {
        lastDockX = dockX
        lastDockWidth = dockWidth
        lastDockTopY = dockTopY
        currentTravelDistance = max(dockWidth - displayWidth, 0)

        let now = CACurrentMediaTime()
        updateMotionState(now: now)

        if isDragging {
            updateThinkingBubble()
            return
        }
        if isIdleForPopover {
            let travelDistance = currentTravelDistance
            let x = dockX + travelDistance * positionProgress + currentFlipCompensation
            let bottomPadding = displayHeight * 0.15
            let y = dockTopY - bottomPadding + yOffset
            window.setFrameOrigin(NSPoint(x: x, y: y))
            if !isResizingPopover {
                updatePopoverPosition()
            }
            updateThinkingBubble()
            return
        }

        if skillOrbitWindow?.isVisible == true {
            guard !isAnimatingSkillOrbitPresentation else { return }
            let travelDistance = currentTravelDistance
            let x = dockX + travelDistance * positionProgress + currentFlipCompensation
            let bottomPadding = displayHeight * 0.15
            let y = dockTopY - bottomPadding + yOffset
            window.setFrameOrigin(NSPoint(x: x, y: y))
            updateSkillOrbitPosition(syncButtonsToExpandedState: !isAnimatingSkillOrbitButtons)
            return
        }

        if shouldResumeFromEdgeDock(now: now) {
            prepareEdgeDockRecoveryIfNeeded()
            startWalk()
            updateMotionState(now: now)
        }

        if currentMotionState == .edgeDockLeft || currentMotionState == .edgeDockRight {
            let travelDistance = max(dockWidth - displayWidth, 0)
            let x = dockX + travelDistance * positionProgress + currentFlipCompensation
            let bottomPadding = displayHeight * 0.15
            let y = dockTopY - bottomPadding + yOffset
            window.setFrameOrigin(NSPoint(x: x, y: y))
            updateThinkingBubble()
            return
        }

        if !currentMotionState.allowsAutomaticTranslation {
            holdAutomaticTranslationIfNeeded()
            let travelDistance = max(dockWidth - displayWidth, 0)
            let x = dockX + travelDistance * positionProgress + currentFlipCompensation
            let bottomPadding = displayHeight * 0.15
            let y = dockTopY - bottomPadding + yOffset
            window.setFrameOrigin(NSPoint(x: x, y: y))
            updateThinkingBubble()
            return
        }

        if isPaused {
            if now >= pauseEndTime {
                startWalk()
                updateMotionState(now: now)
            } else {
                let travelDistance = max(dockWidth - displayWidth, 0)
                let x = dockX + travelDistance * positionProgress + currentFlipCompensation
                let bottomPadding = displayHeight * 0.15
                let y = dockTopY - bottomPadding + yOffset
                window.setFrameOrigin(NSPoint(x: x, y: y))
                updateThinkingBubble()
                return
            }
        }

        if isWalking {
            let elapsed = now - walkStartTime
            let videoTime = min(elapsed, videoDuration)
            let travelDistance = currentTravelDistance

            let walkNorm = elapsed >= videoDuration ? 1.0 : movementPosition(at: videoTime)
            let currentPixel = walkStartPixel + (walkEndPixel - walkStartPixel) * walkNorm

            if travelDistance > 0 {
                positionProgress = min(max(currentPixel / travelDistance, 0), 1)
            }

            if elapsed >= videoDuration {
                walkEndPos = positionProgress
                enterPause()
                updateMotionState(now: now)
                return
            }

            let x = dockX + travelDistance * positionProgress + currentFlipCompensation
            let bottomPadding = displayHeight * 0.15
            let y = dockTopY - bottomPadding + yOffset
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        updateThinkingBubble()
    }
}
