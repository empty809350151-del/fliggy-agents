import Foundation

@main
enum DingTalkMeetingResolverTest {
    static func main() {
        let timeZone = TimeZone(identifier: "Asia/Shanghai")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let engine = ProactivePolicyEngine(calendar: calendar, minimumDeliveryHour: 10)

        let resolver = DingTalkMeetingResolver(
            calendar: calendar,
            calendarEventsProvider: { _, _ in
                [
                    ProactiveCalendarEvent(
                        title: "钉钉站会",
                        startDate: date("2026-04-03 11:00", calendar: calendar),
                        notes: "dingtalk://meeting/join",
                        urlString: "dingtalk://meeting/join"
                    ),
                    ProactiveCalendarEvent(
                        title: "普通会议",
                        startDate: date("2026-04-03 11:00", calendar: calendar),
                        notes: nil,
                        urlString: nil
                    )
                ]
            }
        )

        resolver.record(
            notification: MirroredDingTalkNotification(
                sourceAppName: "钉钉",
                title: "项目例会",
                body: "今天 10:30 开始",
                dedupeKey: "meeting-1"
            ),
            now: date("2026-04-03 09:40", calendar: calendar)
        )

        let fromNotification = resolver.dueReminders(
            now: date("2026-04-03 10:10", calendar: calendar),
            policy: engine,
            deliveredKeys: []
        )
        assert(fromNotification.contains(where: { $0.title == "项目例会" }), "Expected DingTalk notification meeting to trigger at T-20")

        let fromCalendar = resolver.dueReminders(
            now: date("2026-04-03 10:40", calendar: calendar),
            policy: engine,
            deliveredKeys: Set(fromNotification.map(\.deliveryKey))
        )
        assert(fromCalendar.contains(where: { $0.title == "钉钉站会" }), "Expected EventKit DingTalk event to trigger as fallback")
        assert(!fromCalendar.contains(where: { $0.title == "普通会议" }), "Expected non-DingTalk event to stay ignored")

        let earlyMeetingResolver = DingTalkMeetingResolver(
            calendar: calendar,
            calendarEventsProvider: { _, _ in
                [
                    ProactiveCalendarEvent(
                        title: "早会",
                        startDate: date("2026-04-03 09:50", calendar: calendar),
                        notes: "meeting.dingtalk.com/abc",
                        urlString: nil
                    )
                ]
            }
        )
        let earlyDue = earlyMeetingResolver.dueReminders(
            now: date("2026-04-03 10:00", calendar: calendar),
            policy: engine,
            deliveredKeys: []
        )
        assert(earlyDue.isEmpty, "Expected meetings already in the past at 10:00 to not be backfilled")

        print("dingtalk_meeting_resolver_test: PASS")
    }

    private static func date(_ string: String, calendar: Calendar) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        guard let value = formatter.date(from: string) else {
            fatalError("Invalid date string: \(string)")
        }
        return value
    }
}
