import Foundation

struct ProactiveCalendarEvent: Equatable {
    let title: String
    let startDate: Date
    let notes: String?
    let urlString: String?
}

final class DingTalkMeetingResolver {
    typealias CalendarEventsProvider = (_ startDate: Date, _ endDate: Date) -> [ProactiveCalendarEvent]

    private struct Candidate: Equatable {
        let identifier: String
        let title: String
        let startDate: Date
    }

    private let calendar: Calendar
    private let calendarEventsProvider: CalendarEventsProvider
    private let dingTalkKeywords = ["钉钉", "dingtalk", "meeting.dingtalk", "dingtalk://"]

    private var notificationCandidates: [Candidate] = []

    init(
        calendar: Calendar = .current,
        calendarEventsProvider: @escaping CalendarEventsProvider = { _, _ in [] }
    ) {
        self.calendar = calendar
        self.calendarEventsProvider = calendarEventsProvider
    }

    func record(notification: MirroredDingTalkNotification, now: Date = Date()) {
        guard let startDate = parseMeetingDate(from: notification, now: now) else { return }

        let identifier = "notification:\(notification.dedupeKey)"
        let candidate = Candidate(identifier: identifier, title: notification.title, startDate: startDate)
        if !notificationCandidates.contains(candidate) {
            notificationCandidates.append(candidate)
        }
    }

    func dueReminders(
        now: Date = Date(),
        policy: ProactivePolicyEngine,
        deliveredKeys: Set<String>
    ) -> [ProactiveMeetingReminder] {
        let startOfDay = calendar.startOfDay(for: now)
        let endOfWindow = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? now

        var candidates = notificationCandidates.filter { $0.startDate >= startOfDay }
        candidates.append(contentsOf: calendarCandidates(startDate: startOfDay, endDate: endOfWindow))

        var reminders: [ProactiveMeetingReminder] = []
        var seenIdentifiers = Set<String>()

        for candidate in candidates.sorted(by: { $0.startDate < $1.startDate }) {
            guard seenIdentifiers.insert(candidate.identifier).inserted else { continue }

            let triggerDate = candidate.startDate.addingTimeInterval(-20 * 60)
            let deliverAt = policy.nextDeliverableDate(for: triggerDate, now: now)
            guard deliverAt <= now else { continue }
            guard candidate.startDate > now else { continue }

            let key = policy.deliveryKey(for: .dingTalkMeeting, deliverAt: deliverAt, identifier: candidate.identifier)
            guard !deliveredKeys.contains(key) else { continue }

            let timeFormatter = DateFormatter()
            timeFormatter.calendar = calendar
            timeFormatter.timeZone = calendar.timeZone
            timeFormatter.locale = Locale(identifier: "zh_CN")
            timeFormatter.dateFormat = "HH:mm"

            reminders.append(
                ProactiveMeetingReminder(
                    identifier: candidate.identifier,
                    title: candidate.title,
                    startDate: candidate.startDate,
                    deliverAt: deliverAt,
                    deliveryKey: key,
                    bubbleText: "\(candidate.title)快开始了",
                    fullText: "钉钉会议“\(candidate.title)”会在\(timeFormatter.string(from: candidate.startDate))开始，差不多该准备进会了。"
                )
            )
        }

        return reminders
    }

    func meetingSummaries(on date: Date = Date()) -> [String] {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfWindow = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"

        var candidates = notificationCandidates.filter { $0.startDate >= startOfDay }
        candidates.append(contentsOf: calendarCandidates(startDate: startOfDay, endDate: endOfWindow))

        var seen = Set<String>()
        return candidates
            .sorted(by: { $0.startDate < $1.startDate })
            .compactMap { candidate in
                guard seen.insert(candidate.identifier).inserted else { return nil }
                return "\(formatter.string(from: candidate.startDate)) \(candidate.title)"
            }
    }

    private func calendarCandidates(startDate: Date, endDate: Date) -> [Candidate] {
        calendarEventsProvider(startDate, endDate).compactMap { event in
            let haystack = [
                event.title,
                event.notes ?? "",
                event.urlString ?? ""
            ].joined(separator: "\n").lowercased()

            guard dingTalkKeywords.contains(where: { haystack.contains($0.lowercased()) }) else {
                return nil
            }

            return Candidate(
                identifier: "calendar:\(event.title.lowercased())|\(event.startDate.timeIntervalSince1970)",
                title: event.title,
                startDate: event.startDate
            )
        }
    }

    private func parseMeetingDate(from notification: MirroredDingTalkNotification, now: Date) -> Date? {
        let text = [notification.title, notification.body ?? ""].joined(separator: " ")
        let pattern = #"(?:(今天|明天)\s*)?(\d{1,2}):(\d{2})"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else { return nil }

        let dayToken = Range(match.range(at: 1), in: text).map { String(text[$0]) } ?? "今天"
        guard
            let hourRange = Range(match.range(at: 2), in: text),
            let minuteRange = Range(match.range(at: 3), in: text),
            let hour = Int(text[hourRange]),
            let minute = Int(text[minuteRange])
        else {
            return nil
        }

        let dayOffset = dayToken == "明天" ? 1 : 0
        let startOfDay = calendar.startOfDay(for: now)
        let targetDay = calendar.date(byAdding: .day, value: dayOffset, to: startOfDay) ?? startOfDay
        return calendar.date(byAdding: DateComponents(hour: hour, minute: minute), to: targetDay)
    }
}
