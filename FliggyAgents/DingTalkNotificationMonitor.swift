import AppKit
import ApplicationServices
import Foundation

final class DingTalkNotificationMonitor {
    private static let dingTalkDisplayNames: Set<String> = ["DingTalk", "iDingTalk", "钉钉", "阿里钉"]
    private static let dingTalkBundleIdentifiers: Set<String> = ["dd.work.exclusive4aliding"]

    struct State: Equatable {
        var isEnabled = false
        var hasAccessibilityPermission = false
    }

    var onNotification: ((MirroredDingTalkNotification) -> Void)?
    var onStateChange: ((State) -> Void)?

    private(set) var state = State()

    private let normalizer = DingTalkNotificationNormalizer(
        acceptedBundleIdentifiers: DingTalkNotificationMonitor.dingTalkBundleIdentifiers,
        acceptedDisplayNames: DingTalkNotificationMonitor.dingTalkDisplayNames
    )
    private let contentParser = DingTalkNotificationContentParser(
        acceptedDisplayNames: DingTalkNotificationMonitor.dingTalkDisplayNames
    )
    private let fallbackBundleIdentifier = "dd.work.exclusive4aliding"
    private let notificationCenterBundleIdentifiers = [
        "com.apple.notificationcenterui",
        "com.apple.usernoted"
    ]
    private let notificationCenterProcessNames = [
        "NotificationCenter",
        "Notification Center"
    ]

    private var deduper = DingTalkNotificationDeduper(ttl: 6)
    private var activeNotificationKeys = Set<String>()
    private var hasEstablishedNotificationBaseline = false
    private var observer: AXObserver?
    private var observedApplicationElement: AXUIElement?
    private var observedProcessIdentifier: pid_t?
    private var pollTimer: Timer?
    private var lastPublishedState: State?
    private let scanQueue = DispatchQueue(label: "fliggy-agents.dingtalk-monitor.scan", qos: .utility)

    deinit {
        stop()
    }

    func setEnabled(_ enabled: Bool) {
        state.isEnabled = enabled
        NSLog("DingTalkNotificationMonitor.setEnabled enabled=%{public}@", enabled.description)
        refresh()
    }

    func refresh() {
        state.hasAccessibilityPermission = AXIsProcessTrusted()
        NSLog(
            "DingTalkNotificationMonitor.refresh enabled=%{public}@ accessibility=%{public}@",
            state.isEnabled.description,
            state.hasAccessibilityPermission.description
        )
        publishStateIfNeeded()

        guard state.isEnabled, state.hasAccessibilityPermission else {
            stopObservation()
            return
        }

        attachObserverIfNeeded()
        startPollingIfNeeded()
        scheduleScan(establishingBaseline: true)
    }

    func stop() {
        stopObservation()
    }

    private func stopObservation() {
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        }
        observer = nil
        observedApplicationElement = nil
        observedProcessIdentifier = nil
        pollTimer?.invalidate()
        pollTimer = nil
        activeNotificationKeys.removeAll()
        hasEstablishedNotificationBaseline = false
        deduper = DingTalkNotificationDeduper(ttl: 6)
    }

    private func publishStateIfNeeded() {
        guard state != lastPublishedState else { return }
        lastPublishedState = state
        onStateChange?(state)
    }

    private func startPollingIfNeeded() {
        guard pollTimer == nil else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.scheduleScan()
        }
        timer.tolerance = 0.25
        pollTimer = timer
    }

    private func attachObserverIfNeeded() {
        guard observer == nil || observedApplicationElement == nil else { return }
        guard let app = resolveNotificationCenterApplication() else { return }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var localObserver: AXObserver?
        let callback: AXObserverCallback = { _, _, _, refcon in
            guard let refcon else { return }
            let monitor = Unmanaged<DingTalkNotificationMonitor>.fromOpaque(refcon).takeUnretainedValue()
            monitor.scheduleScan()
        }

        guard AXObserverCreate(app.processIdentifier, callback, &localObserver) == .success,
              let localObserver else { return }

        observer = localObserver
        observedApplicationElement = appElement
        observedProcessIdentifier = app.processIdentifier

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        register(notification: kAXCreatedNotification as CFString, for: appElement, refcon: refcon)
        register(notification: kAXWindowCreatedNotification as CFString, for: appElement, refcon: refcon)

        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(localObserver), .defaultMode)
    }

    private func register(notification: CFString, for element: AXUIElement, refcon: UnsafeMutableRawPointer) {
        guard let observer else { return }
        _ = AXObserverAddNotification(observer, element, notification, refcon)
    }

    private func resolveNotificationCenterApplication() -> NSRunningApplication? {
        for bundleIdentifier in notificationCenterBundleIdentifiers {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first {
                return app
            }
        }

        return NSWorkspace.shared.runningApplications.first { app in
            notificationCenterProcessNames.contains(app.localizedName ?? "")
        }
    }

    private func scheduleScan(establishingBaseline: Bool = false) {
        scanQueue.async { [weak self] in
            self?.scanForNotifications(establishingBaseline: establishingBaseline)
        }
    }

    private func scanForNotifications(establishingBaseline: Bool = false) {
        var appElement: AXUIElement?
        DispatchQueue.main.sync {
            guard state.isEnabled, state.hasAccessibilityPermission else { return }

            if let app = resolveNotificationCenterApplication(),
               observedProcessIdentifier != app.processIdentifier {
                stopObservation()
                attachObserverIfNeeded()
            }

            appElement = observedApplicationElement
        }

        guard let appElement else { return }

        let notifications = collectCurrentNotifications(from: candidateRoots(from: appElement))
        let currentKeys = Set(notifications.map(\.dedupeKey))

        guard !establishingBaseline else {
            activeNotificationKeys = currentKeys
            hasEstablishedNotificationBaseline = true
            return
        }

        if !hasEstablishedNotificationBaseline {
            hasEstablishedNotificationBaseline = true
        }

        for notification in notifications where !activeNotificationKeys.contains(notification.dedupeKey) {
            guard deduper.shouldEmit(notification) else { continue }
            NSLog(
                "DingTalkNotificationMonitor.emit title=%{public}@ body=%{public}@ key=%{public}@",
                notification.title,
                notification.body ?? "",
                notification.dedupeKey
            )
            DispatchQueue.main.async { [weak self] in
                self?.onNotification?(notification)
            }
        }

        activeNotificationKeys = currentKeys
    }

    private func candidateRoots(from appElement: AXUIElement) -> [AXUIElement] {
        var roots: [AXUIElement] = [appElement]

        if let windows = copyElementArrayAttribute(kAXWindowsAttribute, from: appElement) {
            roots.append(contentsOf: windows)
        }
        if let children = copyElementArrayAttribute(kAXChildrenAttribute, from: appElement) {
            roots.append(contentsOf: children)
        }

        return roots
    }

    private func collectCurrentNotifications(from roots: [AXUIElement]) -> [MirroredDingTalkNotification] {
        var notifications: [MirroredDingTalkNotification] = []
        var seen = Set<String>()

        for root in roots {
            let strings = collectStrings(from: root, depth: 0, limit: 80)
            guard let candidate = makeCandidate(from: strings),
                  let normalized = normalizer.normalize(candidate),
                  seen.insert(normalized.dedupeKey).inserted else {
                continue
            }
            notifications.append(normalized)
        }

        return notifications
    }

    private func makeCandidate(from strings: [String]) -> DingTalkNotificationCandidate? {
        contentParser.makeCandidate(from: strings, fallbackBundleIdentifier: fallbackBundleIdentifier)
    }

    private func collectStrings(from element: AXUIElement, depth: Int, limit: Int) -> [String] {
        guard depth <= 6, limit > 0 else { return [] }

        var values: [String] = []
        if let title = copyStringAttribute(kAXTitleAttribute as String, from: element) {
            values.append(title)
        }
        if let value = copyStringAttribute(kAXValueAttribute as String, from: element) {
            values.append(value)
        }
        if let description = copyStringAttribute(kAXDescriptionAttribute as String, from: element) {
            values.append(description)
        }
        if let roleDescription = copyStringAttribute(kAXRoleDescriptionAttribute as String, from: element),
           roleDescription.localizedCaseInsensitiveContains("通知") {
            values.append(roleDescription)
        }

        guard values.count < limit,
              let children = copyElementArrayAttribute(kAXChildrenAttribute, from: element) else {
            return values
        }

        for child in children {
            values.append(contentsOf: collectStrings(from: child, depth: depth + 1, limit: limit - values.count))
            if values.count >= limit {
                break
            }
        }

        return values
    }

    private func copyStringAttribute(_ attribute: String, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }

        if let string = value as? String {
            return string
        }
        if let attributed = value as? NSAttributedString {
            return attributed.string
        }
        return nil
    }

    private func copyElementArrayAttribute(_ attribute: String, from element: AXUIElement) -> [AXUIElement]? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? [AXUIElement]
    }
}
