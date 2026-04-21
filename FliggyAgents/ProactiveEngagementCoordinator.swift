import EventKit
import Foundation

final class ProactiveEngagementCoordinator {
    struct State: Equatable {
        var settings: ProactiveSettings
        var hasCalendarPermission: Bool
        var hasLocationPermission: Bool
    }

    enum ToggleKey {
        case enabled
        case morningBrief
        case weather
        case careCheckIns
        case dingTalkMeeting
        case dingTalkUnread
    }

    var onStateChange: ((State) -> Void)?

    private weak var controller: FliggyAgentsController?
    private let defaults = UserDefaults.standard
    private let eventStore = EKEventStore()
    private let weatherService = WeatherService()
    private let promptRunner = ProactivePromptRunner()
    private let morningComposer = MorningDigestComposer()
    private let policy: ProactivePolicyEngine
    private let unreadTracker: DingTalkUnreadTracker
    private lazy var meetingResolver = DingTalkMeetingResolver(
        calendar: policy.calendar,
        calendarEventsProvider: { [weak self] startDate, endDate in
            self?.calendarEvents(startDate: startDate, endDate: endDate) ?? []
        }
    )

    private var timer: Timer?
    private var isProcessing = false
    private var lastPublishedState: State?

    private static let deliveredKeysDefaultsKey = "proactiveAssistant.deliveredKeys"
    private static let lastMorningBriefDateKey = "proactiveAssistant.lastMorningBriefDate"
    private static let weatherFetchTimeout: TimeInterval = 3

    private(set) var state: State

    init(controller: FliggyAgentsController?) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let policy = ProactivePolicyEngine(calendar: calendar, minimumDeliveryHour: 10)
        self.policy = policy
        self.unreadTracker = DingTalkUnreadTracker(policy: policy)
        self.controller = controller
        self.state = State(
            settings: ProactiveSettings.load(),
            hasCalendarPermission: false,
            hasLocationPermission: false
        )
        refreshState()
    }

    func start() {
        requestMissingPermissionsIfNeeded()
        startTimerIfNeeded()
        tick()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        refreshState()
        requestMissingPermissionsIfNeeded()
        tick()
    }

    func setToggle(_ key: ToggleKey, enabled: Bool) {
        var settings = state.settings
        switch key {
        case .enabled:
            settings.isEnabled = enabled
        case .morningBrief:
            settings.morningBriefEnabled = enabled
        case .weather:
            settings.weatherEnabled = enabled
        case .careCheckIns:
            settings.careCheckInsEnabled = enabled
        case .dingTalkMeeting:
            settings.dingTalkMeetingReminderEnabled = enabled
        case .dingTalkUnread:
            settings.dingTalkUnreadReminderEnabled = enabled
        }
        settings.save(defaults: defaults)
        refresh()
    }

    func handle(notification: MirroredDingTalkNotification, now: Date = Date()) {
        guard state.settings.isEnabled else { return }

        if state.settings.dingTalkUnreadReminderEnabled {
            unreadTracker.record(notification: notification, now: now)
        }
        if state.settings.dingTalkMeetingReminderEnabled {
            meetingResolver.record(notification: notification, now: now)
        }

        tick(now: now)
    }

    func handleForegroundApplication(bundleIdentifier: String?) {
        unreadTracker.handleForegroundApplication(bundleIdentifier: bundleIdentifier)
    }

    private func startTimerIfNeeded() {
        guard timer == nil else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.tick()
        }
        timer.tolerance = 5
        self.timer = timer
    }

    func tick(now: Date = Date()) {
        refreshState()
        guard state.settings.isEnabled, !isProcessing else { return }

        let deliveredKeys = loadDeliveredKeys()

        if state.settings.morningBriefEnabled,
           startMorningBriefIfNeeded(now: now, deliveredKeys: deliveredKeys) {
            return
        }

        if state.settings.careCheckInsEnabled {
            let slots = policy.dueCareCheckInSlots(
                now: now,
                deliveredKeys: deliveredKeys,
                suppressWorkStartSlot: morningBriefAlreadyDelivered(on: now, deliveredKeys: deliveredKeys)
            )
            if let slot = slots.first {
                dispatchPromptBackedMessage(
                    kind: .careCheckIn,
                    deliveryKey: policy.deliveryKey(
                        for: .careCheckIn,
                        deliverAt: policy.deliveryDate(for: slot, on: now),
                        identifier: slot.rawValue
                    ),
                    deliverAt: policy.deliveryDate(for: slot, on: now),
                    bubbleText: slot.bubbleText,
                    fallbackText: slot.fallbackText,
                    prompt: """
                    你是桌面助手。请写一句中文关心话，像熟一点的同事或桌面搭子在提醒我，长度不超过38字。
                    要有人味，但不要油，不要鸡汤，不要像客服。
                    场景：\(slot.bubbleText)
                    """
                )
                return
            }
        }

        if state.settings.dingTalkUnreadReminderEnabled,
           let unread = unreadTracker.dueReminder(now: now),
           !deliveredKeys.contains(unread.deliveryKey) {
            dispatchPromptBackedMessage(
                kind: .dingTalkUnread,
                deliveryKey: unread.deliveryKey,
                deliverAt: unread.deliverAt,
                bubbleText: unread.bubbleText,
                fallbackText: unread.fullText,
                prompt: """
                你是桌面助手。请把下面这条钉钉未读提醒改写成自然、轻提醒、有陪伴感的中文一句话，不超过40字。
                像熟同事顺嘴提醒一下，不要像系统通知。
                \(unread.fullText)
                """
            )
            return
        }

        if state.settings.dingTalkMeetingReminderEnabled {
            let reminders = meetingResolver.dueReminders(
                now: now,
                policy: policy,
                deliveredKeys: deliveredKeys
            )
            if let reminder = reminders.first {
                dispatchPromptBackedMessage(
                    kind: .dingTalkMeeting,
                    deliveryKey: reminder.deliveryKey,
                    deliverAt: reminder.deliverAt,
                    bubbleText: reminder.bubbleText,
                    fallbackText: reminder.fullText,
                    prompt: """
                    你是桌面助手。请把下面这条会议提醒改写成自然、简短、像熟同事提醒的中文一句话，不超过40字。
                    要温和一点，但别废话。
                    \(reminder.fullText)
                    """
                )
            }
        }
    }

    @discardableResult
    private func startMorningBriefIfNeeded(now: Date, deliveredKeys: Set<String>) -> Bool {
        let deliverAt = policy.minimumDeliveryDate(on: now)
        guard now >= deliverAt else { return false }

        let key = policy.deliveryKey(for: .morningBrief, deliverAt: deliverAt)
        guard !deliveredKeys.contains(key) else { return false }

        isProcessing = true
        let since = defaults.object(forKey: Self.lastMorningBriefDateKey) as? Date
        let threads = ChatHistoryStore.shared.loadAllThreads()
            .filter { $0.title != ChatHistoryStore.proactiveThreadTitle }
            .filter { since == nil || $0.updatedAt > since! }
            .sorted { $0.updatedAt > $1.updatedAt }

        var pendingWeatherSummary: String?
        let group = DispatchGroup()
        if state.settings.weatherEnabled {
            group.enter()
            var didResolveWeather = false
            let resolveWeather: (WeatherSnapshot?) -> Void = { snapshot in
                guard !didResolveWeather else { return }
                didResolveWeather = true
                pendingWeatherSummary = snapshot?.summary
                group.leave()
            }
            weatherService.fetchSummary { snapshot in
                resolveWeather(snapshot)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.weatherFetchTimeout) {
                resolveWeather(nil)
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            let context = MorningDigestContext(
                now: now,
                since: since,
                recentThreads: threads,
                weatherSummary: pendingWeatherSummary,
                meetingSummaries: self.meetingResolver.meetingSummaries(on: now)
            )
            let draft = self.morningComposer.makeDraft(context: context)
            let provider = self.currentPromptProvider()
            self.promptRunner.generate(prompt: draft.prompt, provider: provider, fallback: draft.fallbackText) { result in
                let resultMessage = ProactiveMessage(
                    kind: .morningBrief,
                    deliveryKey: key,
                    bubbleText: draft.bubbleText,
                    fullText: result.text,
                    deliverAt: deliverAt,
                    usedFallback: result.usedFallback
                )
                self.finishProcessing(with: resultMessage, markMorningSentAt: now)
            }
        }

        return true
    }

    private func dispatchPromptBackedMessage(
        kind: ProactiveEventKind,
        deliveryKey: String,
        deliverAt: Date,
        bubbleText: String,
        fallbackText: String,
        prompt: String
    ) {
        isProcessing = true
        let provider = currentPromptProvider()
        promptRunner.generate(prompt: prompt, provider: provider, fallback: fallbackText) { result in
            let message = ProactiveMessage(
                kind: kind,
                deliveryKey: deliveryKey,
                bubbleText: bubbleText,
                fullText: result.text,
                deliverAt: deliverAt,
                usedFallback: result.usedFallback
            )
            self.finishProcessing(with: message, markMorningSentAt: nil)
        }
    }

    private func finishProcessing(with message: ProactiveMessage, markMorningSentAt: Date?) {
        controller?.deliverProactiveMessage(message)
        recordDeliveredKey(message.deliveryKey)
        if let markMorningSentAt {
            defaults.set(markMorningSentAt, forKey: Self.lastMorningBriefDateKey)
        }
        isProcessing = false
    }

    private func refreshState() {
        let newState = State(
            settings: ProactiveSettings.load(defaults: defaults),
            hasCalendarPermission: hasCalendarAccess,
            hasLocationPermission: weatherService.hasLocationPermission
        )
        state = newState
        publishStateIfNeeded()
    }

    private func publishStateIfNeeded() {
        guard state != lastPublishedState else { return }
        lastPublishedState = state
        onStateChange?(state)
    }

    private func requestMissingPermissionsIfNeeded() {
        if state.settings.isEnabled && state.settings.weatherEnabled {
            weatherService.ensureAuthorization()
        }

        if state.settings.isEnabled && state.settings.dingTalkMeetingReminderEnabled {
            let status = EKEventStore.authorizationStatus(for: .event)
            if status == .notDetermined {
                eventStore.requestAccess(to: .event) { [weak self] _, _ in
                    DispatchQueue.main.async {
                        self?.refreshState()
                    }
                }
            }
        }
    }

    private func morningBriefAlreadyDelivered(on now: Date, deliveredKeys: Set<String>) -> Bool {
        deliveredKeys.contains(policy.deliveryKey(for: .morningBrief, deliverAt: policy.minimumDeliveryDate(on: now)))
    }

    private func currentPromptProvider() -> ProactivePromptProvider {
        switch AgentProvider.current {
        case .claude:
            return .claude
        case .codex:
            return .codex
        case .qoder:
            return .qoder
        case .copilot:
            return .copilot
        case .gemini:
            return .gemini
        }
    }

    private func calendarEvents(startDate: Date, endDate: Date) -> [ProactiveCalendarEvent] {
        guard hasCalendarAccess else { return [] }
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        return eventStore.events(matching: predicate).map { event in
            ProactiveCalendarEvent(
                title: event.title,
                startDate: event.startDate,
                notes: event.notes,
                urlString: event.url?.absoluteString
            )
        }
    }

    private func loadDeliveredKeys() -> Set<String> {
        Set(defaults.stringArray(forKey: Self.deliveredKeysDefaultsKey) ?? [])
    }

    private func recordDeliveredKey(_ key: String) {
        var keys = loadDeliveredKeys()
        keys.insert(key)
        let trimmed = Array(keys).sorted().suffix(256)
        defaults.set(Array(trimmed), forKey: Self.deliveredKeysDefaultsKey)
    }

    private var hasCalendarAccess: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(macOS 14.0, *) {
            return status == .authorized || status == .fullAccess || status == .writeOnly
        }
        return status == .authorized
    }
}
