import Foundation

protocol ProactiveEventSource: AnyObject {
    func start()
    func stop()
}

enum ProactiveEventKind: String, Codable {
    case morningBrief
    case careCheckIn
    case dingTalkUnread
    case dingTalkMeeting
}

struct ProactiveEvent: Equatable {
    let kind: ProactiveEventKind
    let identifier: String
    let scheduledAt: Date
}

struct ProactiveMessage: Equatable {
    let kind: ProactiveEventKind
    let deliveryKey: String
    let bubbleText: String
    let fullText: String
    let deliverAt: Date
    let usedFallback: Bool

    init(
        kind: ProactiveEventKind,
        deliveryKey: String,
        bubbleText: String,
        fullText: String,
        deliverAt: Date,
        usedFallback: Bool = false
    ) {
        self.kind = kind
        self.deliveryKey = deliveryKey
        self.bubbleText = bubbleText
        self.fullText = fullText
        self.deliverAt = deliverAt
        self.usedFallback = usedFallback
    }
}

struct ProactiveSettings: Equatable {
    static let defaultsKeyPrefix = "proactiveAssistant"

    var isEnabled: Bool
    var morningBriefEnabled: Bool
    var weatherEnabled: Bool
    var careCheckInsEnabled: Bool
    var dingTalkMeetingReminderEnabled: Bool
    var dingTalkUnreadReminderEnabled: Bool

    init(
        isEnabled: Bool = true,
        morningBriefEnabled: Bool = true,
        weatherEnabled: Bool = true,
        careCheckInsEnabled: Bool = true,
        dingTalkMeetingReminderEnabled: Bool = true,
        dingTalkUnreadReminderEnabled: Bool = true
    ) {
        self.isEnabled = isEnabled
        self.morningBriefEnabled = morningBriefEnabled
        self.weatherEnabled = weatherEnabled
        self.careCheckInsEnabled = careCheckInsEnabled
        self.dingTalkMeetingReminderEnabled = dingTalkMeetingReminderEnabled
        self.dingTalkUnreadReminderEnabled = dingTalkUnreadReminderEnabled
    }

    static func load(defaults: UserDefaults = .standard) -> ProactiveSettings {
        func value(_ suffix: String, default defaultValue: Bool) -> Bool {
            let key = "\(defaultsKeyPrefix).\(suffix)"
            guard defaults.object(forKey: key) != nil else { return defaultValue }
            return defaults.bool(forKey: key)
        }

        return ProactiveSettings(
            isEnabled: value("enabled", default: true),
            morningBriefEnabled: value("morningBrief", default: true),
            weatherEnabled: value("weather", default: true),
            careCheckInsEnabled: value("careCheckIns", default: true),
            dingTalkMeetingReminderEnabled: value("dingTalkMeeting", default: true),
            dingTalkUnreadReminderEnabled: value("dingTalkUnread", default: true)
        )
    }

    func save(defaults: UserDefaults = .standard) {
        defaults.set(isEnabled, forKey: "\(Self.defaultsKeyPrefix).enabled")
        defaults.set(morningBriefEnabled, forKey: "\(Self.defaultsKeyPrefix).morningBrief")
        defaults.set(weatherEnabled, forKey: "\(Self.defaultsKeyPrefix).weather")
        defaults.set(careCheckInsEnabled, forKey: "\(Self.defaultsKeyPrefix).careCheckIns")
        defaults.set(dingTalkMeetingReminderEnabled, forKey: "\(Self.defaultsKeyPrefix).dingTalkMeeting")
        defaults.set(dingTalkUnreadReminderEnabled, forKey: "\(Self.defaultsKeyPrefix).dingTalkUnread")
    }

    var requiresDingTalkMonitoring: Bool {
        isEnabled && (dingTalkMeetingReminderEnabled || dingTalkUnreadReminderEnabled)
    }
}
