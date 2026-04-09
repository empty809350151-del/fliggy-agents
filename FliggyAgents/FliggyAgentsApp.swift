import SwiftUI
import AppKit
import ApplicationServices

@main
struct FliggyAgentsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var controller: FliggyAgentsController?
    var statusItem: NSStatusItem?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var appObservers: [NSObjectProtocol] = []
    private var dingTalkNotificationMonitor: DingTalkNotificationMonitor?
    private var proactiveCoordinator: ProactiveEngagementCoordinator?
    private static let mirrorDingTalkNotificationsKey = "mirrorDingTalkNotifications"
    private static let debugProactiveDemoDefaultsKey = "debugProactiveDemo"
    private static let debugDingTalkBubbleDefaultsKey = "debugDingTalkBubble"
    private static let debugOpenPopoverDefaultsKey = "debugOpenPopover"
    private static let debugChatTranscriptDemoDefaultsKey = "debugChatTranscriptDemo"
    private static let debugOpenHistoryDrawerDefaultsKey = "debugOpenHistoryDrawer"
    private var hasRequestedAccessibilityPromptThisLaunch = false
    private var currentProviderReadiness: ProviderReadiness = .unknown

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        controller = FliggyAgentsController()
        controller?.healthStateProvider = { [weak self] in
            self?.currentHealthState() ?? self?.fallbackHealthState() ?? AssistantHealthState(
                sourceOfTruthPath: AssistantSourceOfTruth.sourceOfTruthPath,
                buildCommand: AssistantSourceOfTruth.buildCommand,
                installAppPath: AssistantSourceOfTruth.installAppPath,
                currentProviderName: AgentProvider.current.displayName,
                isCurrentProviderReady: false,
                visibleCharacterCount: 0,
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
        }
        NotificationCenter.default.addObserver(self, selector: #selector(handleQuickSkillSlotsChanged(_:)), name: .quickSkillShortcutSlotsDidChange, object: nil)
        DispatchQueue.main.async { [weak self] in
            self?.controller?.start()
            self?.configureDingTalkNotificationMonitor()
            self?.configureProactiveCoordinator()
            self?.refreshCurrentProviderReadiness()
            self?.setupMenuBar()
            self?.setupEnvironmentObservers()
            self?.openDebugSkillOrbitIfNeeded()
            self?.openDebugPopoverIfNeeded()
            self?.deliverDebugChatTranscriptDemoIfNeeded()
            self?.openDebugHistoryDrawerIfNeeded()
            self?.deliverDebugProactiveDemoIfNeeded()
            self?.deliverDebugDingTalkBubbleIfNeeded()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach(workspaceCenter.removeObserver)
        workspaceObservers.removeAll()
        appObservers.forEach(NotificationCenter.default.removeObserver)
        appObservers.removeAll()
        NotificationCenter.default.removeObserver(self, name: .quickSkillShortcutSlotsDidChange, object: nil)
        dingTalkNotificationMonitor?.stop()
        proactiveCoordinator?.stop()
        controller?.characters.forEach {
            $0.session?.terminate()
            $0.skillRunner?.terminate()
        }
    }

    private func setupEnvironmentObservers() {
        let center = NSWorkspace.shared.notificationCenter
        let workspaceNames: [Notification.Name] = [
            NSWorkspace.didWakeNotification,
            NSWorkspace.screensDidWakeNotification,
            NSWorkspace.sessionDidBecomeActiveNotification,
            NSWorkspace.activeSpaceDidChangeNotification,
            NSWorkspace.didActivateApplicationNotification
        ]

        for name in workspaceNames {
            let observer = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                if name == NSWorkspace.didActivateApplicationNotification,
                   let app = (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication) {
                    self?.proactiveCoordinator?.handleForegroundApplication(bundleIdentifier: app.bundleIdentifier)
                }
                self?.scheduleEnvironmentRefresh()
            }
            workspaceObservers.append(observer)
        }

        let appObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleEnvironmentRefresh()
        }
        appObservers.append(appObserver)
    }

    private func scheduleEnvironmentRefresh() {
        let delays: [TimeInterval] = [0, 0.35, 1.0]
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.dingTalkNotificationMonitor?.refresh()
                self?.proactiveCoordinator?.refresh()
                self?.controller?.refreshCharacterVisibility()
                self?.setupMenuBar()
            }
        }
    }

    private func openDebugSkillOrbitIfNeeded() {
        guard ProcessInfo.processInfo.environment["FLIGGY_AGENTS_DEBUG_OPEN_ORBIT"] == "1" else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.controller?.characters.first(where: \.isManuallyVisible)?.handleSecondaryClick()
        }
    }

    private func openDebugPopoverIfNeeded() {
        guard shouldDeliverDebugSample(
            environmentKey: "FLIGGY_AGENTS_DEBUG_OPEN_POPOVER",
            defaultsKey: Self.debugOpenPopoverDefaultsKey
        ) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let character = self?.controller?.characters.first(where: \.isManuallyVisible) ?? self?.controller?.characters.first else {
                return
            }
            NSLog("FLIGGY_AGENTS_DEBUG_OPEN_POPOVER opening lead character popover")
            character.openPopover()
            character.popoverWindow?.orderFrontRegardless()
            character.popoverWindow?.makeKey()
            if let terminal = character.terminalView {
                character.popoverWindow?.makeFirstResponder(terminal.inputField)
            }
        }
    }

    private func deliverDebugProactiveDemoIfNeeded() {
        guard shouldDeliverDebugSample(
            environmentKey: "FLIGGY_AGENTS_DEBUG_PROACTIVE_DEMO",
            defaultsKey: Self.debugProactiveDemoDefaultsKey
        ) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            let now = Date()
            let formatter = ISO8601DateFormatter()
            let key = "debug-demo|\(formatter.string(from: now))"
            let message = ProactiveMessage(
                kind: .careCheckIn,
                deliveryKey: key,
                bubbleText: "杭州21°C，多云，已经九点了，要不要先弄点夜宵垫一下",
                fullText: "天气我先帮你看了，杭州现在21°C，多云。已经九点了，如果你还在忙，先弄点夜宵垫一下，别让工作把人饿没了。",
                deliverAt: now
            )
            NSLog("FLIGGY_AGENTS_DEBUG_PROACTIVE_DEMO sending sample proactive message")
            self?.controller?.deliverProactiveMessage(message)
        }
    }

    private func deliverDebugChatTranscriptDemoIfNeeded() {
        guard shouldDeliverDebugSample(
            environmentKey: "FLIGGY_AGENTS_DEBUG_CHAT_TRANSCRIPT",
            defaultsKey: Self.debugChatTranscriptDemoDefaultsKey
        ) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) { [weak self] in
            guard let character = self?.controller?.characters.first(where: \.isManuallyVisible) ?? self?.controller?.characters.first else {
                return
            }
            NSLog("FLIGGY_AGENTS_DEBUG_CHAT_TRANSCRIPT loading sample transcript")
            character.showDebugConversation(
                title: "Fliggy Agent Chat Refresh",
                messages: [
                    AgentMessage(
                        role: .user,
                        text: "把 fliggy agent 的对话窗重构得更像 GPT / Gemini，但保留桌面助手的小窗气质。"
                    ),
                    AgentMessage(
                        role: .toolUse,
                        text: "Read: PopoverTheme.swift, TerminalView.swift, WalkerCharacter.swift"
                    ),
                    AgentMessage(
                        role: .toolResult,
                        text: "DONE found semantic theme tokens, WKWebView transcript renderer, and the popover chrome entry points."
                    ),
                    AgentMessage(
                        role: .assistant,
                        text: """
                        方向先收成“克制、干净、阅读优先”。

                        > 不做 IM 气泡感，回到 AI 阅读流。

                        ```swift
                        let theme = PopoverTheme.aiChat(for: effectiveAppearance)
                        ```

                        | Area | Goal |
                        | --- | --- |
                        | Transcript | 阅读优先 |
                        | Composer | 更像 GPT |
                        """
                    ),
                    AgentMessage(
                        role: .error,
                        text: "Location permission is unavailable, so weather-rich morning brief preview falls back to plain text."
                    )
                ]
            )
        }
    }

    private func openDebugHistoryDrawerIfNeeded() {
        guard shouldDeliverDebugSample(
            environmentKey: "FLIGGY_AGENTS_DEBUG_OPEN_HISTORY_DRAWER",
            defaultsKey: Self.debugOpenHistoryDrawerDefaultsKey
        ) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let character = self?.controller?.characters.first(where: \.isManuallyVisible) ?? self?.controller?.characters.first else {
                return
            }
            NSLog("FLIGGY_AGENTS_DEBUG_OPEN_HISTORY_DRAWER toggling history drawer")
            character.openPopover()
            character.openHistoryDrawerForDebug()
        }
    }

    private func deliverDebugDingTalkBubbleIfNeeded() {
        guard shouldDeliverDebugSample(
            environmentKey: "FLIGGY_AGENTS_DEBUG_DINGTALK_BUBBLE",
            defaultsKey: Self.debugDingTalkBubbleDefaultsKey
        ) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            let notification = MirroredDingTalkNotification(
                sourceAppName: "DingTalk",
                title: "鱼饼,1111477 楼上楼下了吧！然后呢吗叮咚路上海鲜花钱头了？你们的时候能发货呢？",
                body: nil,
                dedupeKey: "debug-dingtalk-bubble"
            )
            NSLog("FLIGGY_AGENTS_DEBUG_DINGTALK_BUBBLE sending sample mirrored notification")
            self?.controller?.showMirroredDingTalkNotification(notification)
        }
    }

    private func shouldDeliverDebugSample(environmentKey: String, defaultsKey: String) -> Bool {
        if ProcessInfo.processInfo.environment[environmentKey] == "1" {
            return true
        }

        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: defaultsKey) else { return false }
        defaults.removeObject(forKey: defaultsKey)
        return true
    }

    // MARK: - Menu Bar

    func setupMenuBar() {
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        }
        if let button = statusItem?.button {
            let image = NSImage(named: "MenuBarIcon") ?? NSImage(systemSymbolName: "figure.walk", accessibilityDescription: "fliggy agents")
            button.image = image
            button.imagePosition = image == nil ? .noImage : .imageOnly
            button.title = image == nil ? "FA" : ""
        }

        let menu = NSMenu()

        menu.addItem(characterMenuItem(title: "Bruce", action: #selector(toggleChar1), keyEquivalent: "1", index: 0))
        menu.addItem(characterMenuItem(title: "Jazz", action: #selector(toggleChar2), keyEquivalent: "2", index: 1))
        menu.addItem(characterMenuItem(title: "Fliggy", action: #selector(toggleChar3), keyEquivalent: "3", index: 2))
        menu.addItem(characterMenuItem(title: "LABUBU", action: #selector(toggleChar4), keyEquivalent: "4", index: 3))

        menu.addItem(NSMenuItem.separator())

        let soundItem = NSMenuItem(title: "Sounds", action: #selector(toggleSounds(_:)), keyEquivalent: "")
        soundItem.target = self
        soundItem.state = WalkerCharacter.soundsEnabled ? .on : .off
        menu.addItem(soundItem)

        let notificationsItem = NSMenuItem(title: "Notifications", action: nil, keyEquivalent: "")
        notificationsItem.submenu = buildNotificationsMenu()
        menu.addItem(notificationsItem)

        let skillsItem = NSMenuItem(title: "Skills", action: nil, keyEquivalent: "")
        skillsItem.submenu = buildSkillsMenu()
        menu.addItem(skillsItem)

        let providerItem = NSMenuItem(title: "Provider", action: nil, keyEquivalent: "")
        let providerMenu = NSMenu()
        for (index, provider) in AgentProvider.allCases.enumerated() {
            let item = NSMenuItem(title: provider.displayName, action: #selector(switchProvider(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            item.state = provider == AgentProvider.current ? .on : .off
            providerMenu.addItem(item)
        }
        providerItem.submenu = providerMenu
        menu.addItem(providerItem)

        let themeItem = NSMenuItem(title: "Style", action: nil, keyEquivalent: "")
        let themeMenu = NSMenu()
        for (index, theme) in PopoverTheme.allThemes.enumerated() {
            let item = NSMenuItem(title: theme.name, action: #selector(switchTheme(_:)), keyEquivalent: "")
            item.tag = index
            item.state = theme.name == PopoverTheme.current.name ? .on : .off
            themeMenu.addItem(item)
        }
        themeItem.submenu = themeMenu
        menu.addItem(themeItem)

        let displayItem = NSMenuItem(title: "Display", action: nil, keyEquivalent: "")
        let displayMenu = NSMenu()
        displayMenu.delegate = self
        let selectedDisplayIndex = controller?.pinnedScreenIndex ?? -1
        let autoItem = NSMenuItem(title: "Auto (Main Display)", action: #selector(switchDisplay(_:)), keyEquivalent: "")
        autoItem.target = self
        autoItem.tag = -1
        autoItem.state = selectedDisplayIndex == -1 ? .on : .off
        displayMenu.addItem(autoItem)
        displayMenu.addItem(NSMenuItem.separator())
        for (index, screen) in NSScreen.screens.enumerated() {
            let item = NSMenuItem(title: screen.localizedName, action: #selector(switchDisplay(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            item.state = selectedDisplayIndex == index ? .on : .off
            displayMenu.addItem(item)
        }
        displayItem.submenu = displayMenu
        menu.addItem(displayItem)

        menu.addItem(NSMenuItem.separator())

        let updateItem = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdatesDisabled), keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    private func characterMenuItem(title: String, action: Selector, keyEquivalent: String, index: Int) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        let characters = controller?.characters ?? []
        let character = index < characters.count ? characters[index] : nil
        item.isEnabled = character != nil
        item.state = character?.isManuallyVisible == true ? .on : .off
        return item
    }

    private func configureDingTalkNotificationMonitor() {
        let monitor = DingTalkNotificationMonitor()
        monitor.onNotification = { [weak self] notification in
            if self?.shouldMirrorDingTalkNotifications == true {
                self?.controller?.showMirroredDingTalkNotification(notification)
            }
            self?.proactiveCoordinator?.handle(notification: notification)
        }
        monitor.onStateChange = { [weak self] _ in
            self?.setupMenuBar()
        }

        let hasPermission = AXIsProcessTrusted()
        let savedValue = UserDefaults.standard.object(forKey: Self.mirrorDingTalkNotificationsKey) as? Bool
        let shouldEnable = hasPermission ? (savedValue ?? true) : false
        if savedValue == nil {
            UserDefaults.standard.set(shouldEnable, forKey: Self.mirrorDingTalkNotificationsKey)
        }

        dingTalkNotificationMonitor = monitor
        refreshDingTalkNotificationMonitoring()
    }

    private func configureProactiveCoordinator() {
        let coordinator = ProactiveEngagementCoordinator(controller: controller)
        coordinator.onStateChange = { [weak self] _ in
            self?.refreshDingTalkNotificationMonitoring()
            self?.setupMenuBar()
        }
        proactiveCoordinator = coordinator
        coordinator.start()
    }

    private var shouldMirrorDingTalkNotifications: Bool {
        UserDefaults.standard.bool(forKey: Self.mirrorDingTalkNotificationsKey)
    }

    private func refreshDingTalkNotificationMonitoring() {
        let hasPermission = AXIsProcessTrusted()
        let proactiveNeedsMonitor = proactiveCoordinator?.state.settings.requiresDingTalkMonitoring ?? false
        if !hasPermission, shouldMirrorDingTalkNotifications || proactiveNeedsMonitor {
            requestAccessibilityPermissionIfNeeded()
        }
        let shouldEnable = hasPermission && (shouldMirrorDingTalkNotifications || proactiveNeedsMonitor)
        NSLog(
            "FliggyAgentsApp.refreshDingTalkNotificationMonitoring permission=%{public}@ mirror=%{public}@ proactive=%{public}@ shouldEnable=%{public}@",
            hasPermission.description,
            shouldMirrorDingTalkNotifications.description,
            proactiveNeedsMonitor.description,
            shouldEnable.description
        )
        dingTalkNotificationMonitor?.setEnabled(shouldEnable)
    }

    private func requestAccessibilityPermissionIfNeeded() {
        guard !hasRequestedAccessibilityPromptThisLaunch else { return }
        hasRequestedAccessibilityPromptThisLaunch = true
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func refreshCurrentProviderReadiness() {
        let provider = AgentProvider.current
        currentProviderReadiness = .unknown
        setupMenuBar()
        CurrentProviderReadinessProbe.refresh(provider: provider) { [weak self] readiness in
            guard let self, AgentProvider.current == provider else { return }
            self.currentProviderReadiness = readiness
            self.setupMenuBar()
        }
    }

    private func fallbackHealthState() -> AssistantHealthState {
        let settings = proactiveCoordinator?.state.settings ?? ProactiveSettings.load()
        return AssistantHealthState(
            sourceOfTruthPath: AssistantSourceOfTruth.sourceOfTruthPath,
            buildCommand: AssistantSourceOfTruth.buildCommand,
            installAppPath: AssistantSourceOfTruth.installAppPath,
            currentProviderName: AgentProvider.current.displayName,
            isCurrentProviderReady: currentProviderReadiness.isReady,
            visibleCharacterCount: controller?.visibleCharacterCount ?? 0,
            hasAccessibilityPermission: dingTalkNotificationMonitor?.state.hasAccessibilityPermission ?? false,
            hasCalendarPermission: proactiveCoordinator?.state.hasCalendarPermission ?? false,
            hasLocationPermission: proactiveCoordinator?.state.hasLocationPermission ?? false,
            mirrorDingTalkNotificationsEnabled: shouldMirrorDingTalkNotifications,
            proactiveAssistantEnabled: settings.isEnabled,
            dingTalkMeetingReminderEnabled: settings.dingTalkMeetingReminderEnabled,
            dingTalkUnreadReminderEnabled: settings.dingTalkUnreadReminderEnabled,
            weatherEnabled: settings.weatherEnabled,
            dingTalkMonitoringEnabled: dingTalkNotificationMonitor?.state.isEnabled ?? false
        )
    }

    private func currentHealthState() -> AssistantHealthState {
        fallbackHealthState()
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func buildNotificationsMenu() -> NSMenu {
        let menu = NSMenu()
        let health = currentHealthState()

        menu.addItem(disabledItem("Assistant Status: \(health.statusTitle)"))
        menu.addItem(disabledItem(health.statusLine))
        menu.addItem(disabledItem("Provider: \(health.currentProviderName) — \(currentProviderReadiness.summary)"))
        menu.addItem(disabledItem("Visible characters: \(health.visibleCharacterCount)"))
        menu.addItem(disabledItem("Accessibility: \(health.hasAccessibilityPermission ? "Ready" : "Missing")"))
        menu.addItem(disabledItem("Calendar: \(health.hasCalendarPermission ? "Ready" : (health.needsCalendarPermission ? "Missing" : "Optional"))"))
        menu.addItem(disabledItem("Location: \(health.hasLocationPermission ? "Ready" : (health.needsLocationPermission ? "Missing" : "Optional"))"))
        menu.addItem(disabledItem("DingTalk monitor: \(health.dingTalkMonitoringEnabled ? "Active" : (health.requiresDingTalkMonitoring ? "Blocked" : "Not needed"))"))

        if !health.blockingReasons.isEmpty {
            menu.addItem(NSMenuItem.separator())
            for blocker in health.blockingReasons {
                menu.addItem(disabledItem("Blocker: \(blocker)"))
            }
        }

        menu.addItem(NSMenuItem.separator())

        let setupItem = NSMenuItem(title: "Open Setup Checklist", action: #selector(openSetupChecklistFromMenu(_:)), keyEquivalent: "")
        setupItem.target = self
        menu.addItem(setupItem)

        let reminderItem = NSMenuItem(title: "Open Reminder Inbox", action: #selector(openReminderInboxFromMenu(_:)), keyEquivalent: "")
        reminderItem.target = self
        menu.addItem(reminderItem)

        let buildChainItem = NSMenuItem(title: "Build & Install", action: nil, keyEquivalent: "")
        buildChainItem.submenu = buildBuildInstallMenu()
        menu.addItem(buildChainItem)

        let diagnosticsItem = NSMenuItem(title: "Diagnostics", action: nil, keyEquivalent: "")
        diagnosticsItem.submenu = buildDiagnosticsMenu()
        menu.addItem(diagnosticsItem)

        menu.addItem(NSMenuItem.separator())

        let dingTalkItem = NSMenuItem(
            title: "Mirror DingTalk Notifications",
            action: #selector(toggleDingTalkMirroring(_:)),
            keyEquivalent: ""
        )
        dingTalkItem.target = self
        dingTalkItem.state = shouldMirrorDingTalkNotifications ? .on : .off
        menu.addItem(dingTalkItem)

        let proactiveItem = NSMenuItem(title: "Proactive Assistant", action: nil, keyEquivalent: "")
        proactiveItem.submenu = buildProactiveAssistantMenu()
        menu.addItem(proactiveItem)

        return menu
    }

    private func buildBuildInstallMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(disabledItem("Source of truth:"))
        menu.addItem(disabledItem(AssistantSourceOfTruth.sourceOfTruthPath))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(disabledItem("Build command:"))
        menu.addItem(disabledItem(AssistantSourceOfTruth.buildCommand))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(disabledItem("Install app:"))
        menu.addItem(disabledItem(AssistantSourceOfTruth.installAppPath))
        menu.addItem(NSMenuItem.separator())

        let revealSourceItem = NSMenuItem(title: "Reveal Source Folder", action: #selector(revealSourceOfTruth(_:)), keyEquivalent: "")
        revealSourceItem.target = self
        menu.addItem(revealSourceItem)

        let revealInstallItem = NSMenuItem(title: "Reveal Installed App", action: #selector(revealInstalledApp(_:)), keyEquivalent: "")
        revealInstallItem.target = self
        menu.addItem(revealInstallItem)

        let revealReadmeItem = NSMenuItem(title: "Reveal Build README", action: #selector(revealBuildReadme(_:)), keyEquivalent: "")
        revealReadmeItem.target = self
        menu.addItem(revealReadmeItem)

        let revealScriptItem = NSMenuItem(title: "Reveal Install Script", action: #selector(revealInstallScript(_:)), keyEquivalent: "")
        revealScriptItem.target = self
        menu.addItem(revealScriptItem)

        return menu
    }

    private func buildDiagnosticsMenu() -> NSMenu {
        let menu = NSMenu()

        let setupItem = NSMenuItem(title: "Open Setup Checklist", action: #selector(openSetupChecklistFromMenu(_:)), keyEquivalent: "")
        setupItem.target = self
        menu.addItem(setupItem)

        let reminderItem = NSMenuItem(title: "Open Reminder Inbox", action: #selector(openReminderInboxFromMenu(_:)), keyEquivalent: "")
        reminderItem.target = self
        menu.addItem(reminderItem)

        menu.addItem(NSMenuItem.separator())

        let dingTalkDemoItem = NSMenuItem(title: "Send DingTalk Demo", action: #selector(sendDingTalkDemo(_:)), keyEquivalent: "")
        dingTalkDemoItem.target = self
        menu.addItem(dingTalkDemoItem)

        let proactiveDemoItem = NSMenuItem(title: "Send Proactive Demo", action: #selector(sendProactiveDemo(_:)), keyEquivalent: "")
        proactiveDemoItem.target = self
        menu.addItem(proactiveDemoItem)

        menu.addItem(NSMenuItem.separator())

        let revealReminderStoreItem = NSMenuItem(title: "Reveal Reminder Store", action: #selector(revealReminderStore(_:)), keyEquivalent: "")
        revealReminderStoreItem.target = self
        menu.addItem(revealReminderStoreItem)

        return menu
    }

    private func buildProactiveAssistantMenu() -> NSMenu {
        let menu = NSMenu()
        let state = proactiveCoordinator?.state ?? .init(
            settings: ProactiveSettings.load(),
            hasCalendarPermission: false,
            hasLocationPermission: false
        )

        menu.addItem(disabledItem(state.settings.isEnabled ? "Status: Enabled" : "Status: Disabled"))
        menu.addItem(toggleItem(title: "Enable Proactive Assistant", enabled: state.settings.isEnabled, action: #selector(toggleProactiveEnabled(_:))))
        menu.addItem(toggleItem(title: "Morning Brief", enabled: state.settings.morningBriefEnabled, action: #selector(toggleMorningBrief(_:))))
        menu.addItem(toggleItem(title: "Weather", enabled: state.settings.weatherEnabled, action: #selector(toggleWeather(_:))))
        menu.addItem(toggleItem(title: "Care Check-ins", enabled: state.settings.careCheckInsEnabled, action: #selector(toggleCareCheckIns(_:))))
        menu.addItem(toggleItem(title: "DingTalk Meeting Reminder", enabled: state.settings.dingTalkMeetingReminderEnabled, action: #selector(toggleDingTalkMeetingReminder(_:))))
        menu.addItem(toggleItem(title: "DingTalk Unread Reminder", enabled: state.settings.dingTalkUnreadReminderEnabled, action: #selector(toggleDingTalkUnreadReminder(_:))))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(disabledItem("Calendar permission: \(state.hasCalendarPermission ? "Ready" : (state.settings.dingTalkMeetingReminderEnabled ? "Missing" : "Optional"))"))
        menu.addItem(disabledItem("Location permission: \(state.hasLocationPermission ? "Ready" : (state.settings.weatherEnabled ? "Missing" : "Optional"))"))
        menu.addItem(disabledItem("DingTalk monitor required: \(state.settings.requiresDingTalkMonitoring ? "Yes" : "No")"))
        return menu
    }

    private func toggleItem(title: String, enabled: Bool, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.state = enabled ? .on : .off
        return item
    }

    private func buildSkillsMenu() -> NSMenu {
        let menu = NSMenu()
        let installedSkills = SkillRegistry.shared.allSkills()

        guard !installedSkills.isEmpty else {
            let emptyItem = NSMenuItem(title: "暂无可用技能", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
            return menu
        }

        for definition in QuickSkillShortcutCatalog.slotDefinitions {
            let currentSkillName = QuickSkillShortcutStore.shared.displaySkillName(for: definition)
            let submenuItem = NSMenuItem(
                title: "skill-\(definition.slotIndex + 1)-\(currentSkillName)",
                action: nil,
                keyEquivalent: ""
            )
            let slotMenu = NSMenu()

            for (categoryName, skills) in groupedSkillsForMenu(installedSkills) {
                let categoryItem = NSMenuItem(title: categoryName, action: nil, keyEquivalent: "")
                let categoryMenu = NSMenu()

                for skill in skills {
                    let item = NSMenuItem(title: skill.name, action: #selector(configureQuickSkill(_:)), keyEquivalent: "")
                    item.target = self
                    item.tag = definition.slotIndex
                    item.representedObject = skill.name
                    item.state = currentSkillName.caseInsensitiveCompare(skill.name) == .orderedSame ? .on : .off
                    categoryMenu.addItem(item)
                }

                categoryItem.submenu = categoryMenu
                slotMenu.addItem(categoryItem)
            }

            submenuItem.submenu = slotMenu
            menu.addItem(submenuItem)
        }

        return menu
    }

    private func groupedSkillsForMenu(_ skills: [SkillDefinition]) -> [(String, [SkillDefinition])] {
        let order = [
            "界面体验",
            "动效编排",
            "Figma 设计",
            "浏览器执行",
            "质检评审",
            "方案规划",
            "交付发布",
            "安全护栏",
            "内容物料",
            "工具扩展",
            "通用能力"
        ]

        let grouped = Dictionary(grouping: skills) { categorizeSkill($0) }
        return order.compactMap { category in
            guard let items = grouped[category], !items.isEmpty else { return nil }
            return (category, items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })
        }
    }

    private func categorizeSkill(_ skill: SkillDefinition) -> String {
        let haystack = "\(skill.name) \(skill.description)".lowercased()

        if haystack.contains("figma") {
            return "Figma 设计"
        }
        if haystack.contains("animate") || haystack.contains("motion") || haystack.contains("gsap") || haystack.contains("scrolltrigger") || haystack.contains("timeline") {
            return "动效编排"
        }
        if haystack.contains("design") || haystack.contains("frontend") || haystack.contains("ui") || haystack.contains("ux") || haystack.contains("typeset") || haystack.contains("color") || haystack.contains("layout") || haystack.contains("polish") || haystack.contains("delight") || haystack.contains("normalize") || haystack.contains("distill") || haystack.contains("onboard") || haystack.contains("clarify") || haystack.contains("extract") {
            return "界面体验"
        }
        if haystack.contains("browser") || haystack.contains("browse") || haystack.contains("cookies") || haystack.contains("canary") || haystack.contains("test-browser") {
            return "浏览器执行"
        }
        if haystack.contains("qa") || haystack.contains("review") || haystack.contains("audit") || haystack.contains("benchmark") || haystack.contains("critique") {
            return "质检评审"
        }
        if haystack.contains("plan") || haystack.contains("office-hours") || haystack.contains("brainstorm") || haystack.contains("autoplan") || haystack.contains("ceo") || haystack.contains("eng review") || haystack.contains("eng-review") {
            return "方案规划"
        }
        if haystack.contains("deploy") || haystack.contains("ship") || haystack.contains("release") || haystack.contains("retro") || haystack.contains("document") || haystack.contains("upgrade") {
            return "交付发布"
        }
        if haystack.contains("security") || haystack.contains("cso") || haystack.contains("guard") || haystack.contains("careful") || haystack.contains("freeze") || haystack.contains("unfreeze") {
            return "安全护栏"
        }
        if haystack.contains("image") || haystack.contains("banner") || haystack.contains("poster") || haystack.contains("content") {
            return "内容物料"
        }
        if haystack.contains("plugin") || haystack.contains("skill") || haystack.contains("openai") || haystack.contains("tool") || haystack.contains("mcp") {
            return "工具扩展"
        }
        return "通用能力"
    }

    // MARK: - Menu Actions

    @objc func switchTheme(_ sender: NSMenuItem) {
        let idx = sender.tag
        guard idx < PopoverTheme.allThemes.count else { return }
        PopoverTheme.current = PopoverTheme.allThemes[idx]

        if let themeMenu = sender.menu {
            for item in themeMenu.items {
                item.state = item.tag == idx ? .on : .off
            }
        }

        controller?.characters.forEach { char in
            let wasOpen = char.isIdleForPopover
            if wasOpen { char.popoverWindow?.orderOut(nil) }
            char.popoverWindow = nil
            char.terminalView = nil
            char.thinkingBubbleWindow = nil
            if wasOpen {
                char.createPopoverWindow()
                if let session = char.session, !session.history.isEmpty {
                    char.terminalView?.replayHistory(session.history)
                }
                char.updatePopoverPosition()
                char.popoverWindow?.orderFrontRegardless()
                char.popoverWindow?.makeKey()
                if let terminal = char.terminalView {
                    char.popoverWindow?.makeFirstResponder(terminal.inputField)
                }
            }
        }
    }

    @objc func switchProvider(_ sender: NSMenuItem) {
        let idx = sender.tag
        let allProviders = AgentProvider.allCases
        guard idx < allProviders.count else { return }
        AgentProvider.current = allProviders[idx]

        if let providerMenu = sender.menu {
            for item in providerMenu.items {
                item.state = item.tag == idx ? .on : .off
            }
        }

        controller?.characters.forEach { char in
            char.session?.terminate()
            char.session = nil
            char.skillRunner?.terminate()
            char.skillRunner = nil
            if char.isIdleForPopover {
                char.closePopover()
            }
            char.popoverWindow?.orderOut(nil)
            char.popoverWindow = nil
            char.terminalView = nil
            char.thinkingBubbleWindow?.orderOut(nil)
            char.thinkingBubbleWindow = nil
        }

        proactiveCoordinator?.refresh()
        refreshCurrentProviderReadiness()
        setupMenuBar()
    }

    @objc func switchDisplay(_ sender: NSMenuItem) {
        let idx = sender.tag
        controller?.pinnedScreenIndex = idx

        if let displayMenu = sender.menu {
            for item in displayMenu.items {
                item.state = item.tag == idx ? .on : .off
            }
        }
        setupMenuBar()
    }

    @objc func toggleChar1(_ sender: NSMenuItem) {
        toggleCharacter(at: 0, sender: sender)
    }

    @objc func toggleChar2(_ sender: NSMenuItem) {
        toggleCharacter(at: 1, sender: sender)
    }

    @objc func toggleChar3(_ sender: NSMenuItem) {
        toggleCharacter(at: 2, sender: sender)
    }

    @objc func toggleChar4(_ sender: NSMenuItem) {
        toggleCharacter(at: 3, sender: sender)
    }

    private func toggleCharacter(at index: Int, sender: NSMenuItem) {
        guard let chars = controller?.characters, chars.indices.contains(index) else { return }
        let char = chars[index]
        char.setManuallyVisible(!char.isManuallyVisible)
        sender.state = char.isManuallyVisible ? .on : .off
        setupMenuBar()
    }

    @objc func toggleDebug(_ sender: NSMenuItem) {
        guard let debugWin = controller?.debugWindow else { return }
        if debugWin.isVisible {
            debugWin.orderOut(nil)
            sender.state = .off
        } else {
            debugWin.orderFrontRegardless()
            sender.state = .on
        }
    }

    @objc func toggleSounds(_ sender: NSMenuItem) {
        WalkerCharacter.soundsEnabled.toggle()
        controller?.characters.forEach { $0.applyAudioPreferences() }
        sender.state = WalkerCharacter.soundsEnabled ? .on : .off
        setupMenuBar()
    }

    @objc private func openSetupChecklistFromMenu(_ sender: Any?) {
        controller?.openSetupChecklist()
    }

    @objc private func openReminderInboxFromMenu(_ sender: Any?) {
        controller?.openReminderInbox()
    }

    @objc private func sendDingTalkDemo(_ sender: Any?) {
        let notification = MirroredDingTalkNotification(
            sourceAppName: "DingTalk",
            title: "鱼饼",
            body: "楼下等你，看到后回一下。",
            dedupeKey: "diagnostics-dingtalk-\(UUID().uuidString)"
        )
        controller?.showMirroredDingTalkNotification(notification)
    }

    @objc private func sendProactiveDemo(_ sender: Any?) {
        let now = Date()
        let formatter = ISO8601DateFormatter()
        let message = ProactiveMessage(
            kind: .careCheckIn,
            deliveryKey: "diagnostics-proactive-\(formatter.string(from: now))",
            bubbleText: "已经下午了，要不要先收一轮消息，我帮你盯着后面的提醒。",
            fullText: "已经下午了，要不要先收一轮消息，我会继续把后面的提醒沉淀到助手提醒里，方便你回看。",
            deliverAt: now,
            usedFallback: true
        )
        controller?.deliverProactiveMessage(message)
    }

    @objc private func revealSourceOfTruth(_ sender: Any?) {
        revealPath(AssistantSourceOfTruth.sourceOfTruthPath)
    }

    @objc private func revealInstalledApp(_ sender: Any?) {
        revealPath(AssistantSourceOfTruth.installAppPath)
    }

    @objc private func revealBuildReadme(_ sender: Any?) {
        revealPath(AssistantSourceOfTruth.readmePath)
    }

    @objc private func revealInstallScript(_ sender: Any?) {
        revealPath(AssistantSourceOfTruth.buildScriptPath)
    }

    @objc private func revealReminderStore(_ sender: Any?) {
        revealPath(AssistantSourceOfTruth.reminderStorageDirectoryPath)
    }

    private func revealPath(_ path: String) {
        let url = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([url.deletingLastPathComponent()])
        }
    }

    @objc private func toggleDingTalkMirroring(_ sender: NSMenuItem) {
        let newValue = !shouldMirrorDingTalkNotifications
        UserDefaults.standard.set(newValue, forKey: Self.mirrorDingTalkNotificationsKey)
        refreshDingTalkNotificationMonitoring()
        sender.state = newValue ? .on : .off
        setupMenuBar()
    }

    @objc private func toggleProactiveEnabled(_ sender: NSMenuItem) {
        proactiveCoordinator?.setToggle(.enabled, enabled: sender.state != .on)
    }

    @objc private func toggleMorningBrief(_ sender: NSMenuItem) {
        proactiveCoordinator?.setToggle(.morningBrief, enabled: sender.state != .on)
    }

    @objc private func toggleWeather(_ sender: NSMenuItem) {
        proactiveCoordinator?.setToggle(.weather, enabled: sender.state != .on)
    }

    @objc private func toggleCareCheckIns(_ sender: NSMenuItem) {
        proactiveCoordinator?.setToggle(.careCheckIns, enabled: sender.state != .on)
    }

    @objc private func toggleDingTalkMeetingReminder(_ sender: NSMenuItem) {
        proactiveCoordinator?.setToggle(.dingTalkMeeting, enabled: sender.state != .on)
    }

    @objc private func toggleDingTalkUnreadReminder(_ sender: NSMenuItem) {
        proactiveCoordinator?.setToggle(.dingTalkUnread, enabled: sender.state != .on)
    }

    @objc private func configureQuickSkill(_ sender: NSMenuItem) {
        guard let skillName = sender.representedObject as? String else { return }
        QuickSkillShortcutStore.shared.setConfiguredSkillName(skillName, for: sender.tag)
    }

    @objc private func handleQuickSkillSlotsChanged(_ notification: Notification) {
        setupMenuBar()
        controller?.characters.forEach { $0.reloadSkillOrbitConfiguration() }
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
    @objc func checkForUpdatesDisabled(_ sender: Any?) {
        NSWorkspace.shared.open(URL(string: "https://github.com/ryanstephen/fliggy-agents")!)
    }
}

extension AppDelegate: NSMenuDelegate {}
