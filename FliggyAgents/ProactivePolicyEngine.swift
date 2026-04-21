import Foundation

enum CareCheckInSlot: String, CaseIterable, Equatable {
    case workStart
    case lunchPrep
    case afternoonStart
    case afternoonSlump
    case dinnerPrep
    case nightSnack
    case lateWrap

    var hour: Int {
        switch self {
        case .workStart: return 10
        case .lunchPrep: return 11
        case .afternoonStart: return 14
        case .afternoonSlump: return 16
        case .dinnerPrep: return 17
        case .nightSnack: return 21
        case .lateWrap: return 22
        }
    }

    var minute: Int {
        switch self {
        case .workStart: return 0
        case .lunchPrep: return 30
        case .afternoonStart: return 0
        case .afternoonSlump: return 30
        case .dinnerPrep: return 30
        case .nightSnack: return 0
        case .lateWrap: return 0
        }
    }

    var fallbackText: String {
        switch self {
        case .workStart: return "10点啦，今天我先陪你开工，别一上来就想把所有事都打穿，先收住最重要的那一件。"
        case .lunchPrep: return "11点半了，先别跟工作硬耗，去吃点东西，回来脑子会清楚很多。"
        case .afternoonStart: return "两点了，下半场开工，我们把最难啃的那块先推进一点，不求一口吃完。"
        case .afternoonSlump: return "四点半这个点最容易掉电，起来动两分钟也行，别让自己闷着顶。"
        case .dinnerPrep: return "五点半快到了，先想想晚饭，别忙着忙着又把饭点拖过去了。"
        case .nightSnack: return "九点了，如果你还在干活，记得顺手给自己弄点夜宵，别只喂工作不喂自己。"
        case .lateWrap: return "十点了，真的别再无限往后拖了，能收就收一点，留点体力给明天。"
        }
    }

    var bubbleText: String {
        switch self {
        case .workStart: return "10点啦，今天我先陪你开工"
        case .lunchPrep: return "11点半啦，先去吃点东西"
        case .afternoonStart: return "下午开工啦"
        case .afternoonSlump: return "四点半了，别硬扛"
        case .dinnerPrep: return "马上到晚饭点啦"
        case .nightSnack: return "九点了，要不要搞点夜宵"
        case .lateWrap: return "别干到太晚"
        }
    }
}

struct ProactiveUnreadReminder: Equatable {
    let deliverAt: Date
    let deliveryKey: String
    let bubbleText: String
    let fullText: String
}

struct ProactiveMeetingReminder: Equatable {
    let identifier: String
    let title: String
    let startDate: Date
    let deliverAt: Date
    let deliveryKey: String
    let bubbleText: String
    let fullText: String
}

final class ProactivePolicyEngine {
    let calendar: Calendar
    let minimumDeliveryHour: Int

    init(calendar: Calendar = .current, minimumDeliveryHour: Int = 10) {
        self.calendar = calendar
        self.minimumDeliveryHour = minimumDeliveryHour
    }

    func minimumDeliveryDate(on date: Date) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .hour, value: minimumDeliveryHour, to: startOfDay) ?? startOfDay
    }

    func nextDeliverableDate(for eventDate: Date, now: Date = Date()) -> Date {
        let gatedEventDate = max(eventDate, minimumDeliveryDate(on: eventDate))
        let todayGate = minimumDeliveryDate(on: now)
        if gatedEventDate < todayGate {
            return todayGate
        }
        return gatedEventDate
    }

    func deliveryDate(for slot: CareCheckInSlot, on date: Date) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        let slotDate = calendar.date(byAdding: DateComponents(hour: slot.hour, minute: slot.minute), to: startOfDay) ?? startOfDay
        return nextDeliverableDate(for: slotDate, now: date)
    }

    func dueCareCheckInSlots(
        now: Date = Date(),
        deliveredKeys: Set<String>,
        suppressWorkStartSlot: Bool
    ) -> [CareCheckInSlot] {
        CareCheckInSlot.allCases.filter { slot in
            if suppressWorkStartSlot && slot == .workStart {
                return false
            }
            let deliverAt = deliveryDate(for: slot, on: now)
            guard deliverAt <= now else { return false }
            let key = deliveryKey(for: .careCheckIn, deliverAt: deliverAt, identifier: slot.rawValue)
            return !deliveredKeys.contains(key)
        }
    }

    func deliveryKey(for kind: ProactiveEventKind, deliverAt: Date, identifier: String? = nil) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let day = formatter.string(from: deliverAt)
        if let identifier, !identifier.isEmpty {
            return "\(day)|\(kind.rawValue)|\(identifier)"
        }
        return "\(day)|\(kind.rawValue)"
    }
}
