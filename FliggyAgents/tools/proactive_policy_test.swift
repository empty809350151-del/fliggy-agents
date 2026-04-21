import Foundation

@main
enum ProactivePolicyTest {
    static func main() {
        let timeZone = TimeZone(identifier: "Asia/Shanghai")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let engine = ProactivePolicyEngine(calendar: calendar, minimumDeliveryHour: 10)

        assert(
            engine.nextDeliverableDate(
                for: date("2026-04-03 09:15", calendar: calendar),
                now: date("2026-04-03 08:00", calendar: calendar)
            ) == date("2026-04-03 10:00", calendar: calendar),
            "Expected events before 10:00 to be delayed until 10:00"
        )

        assert(
            engine.nextDeliverableDate(
                for: date("2026-04-03 11:15", calendar: calendar),
                now: date("2026-04-03 08:00", calendar: calendar)
            ) == date("2026-04-03 11:15", calendar: calendar),
            "Expected events after 10:00 to keep their original delivery time"
        )

        let deliveredMorning = Set<String>([engine.deliveryKey(for: .morningBrief, deliverAt: date("2026-04-03 10:00", calendar: calendar))])
        let tenAMCare = engine.dueCareCheckInSlots(
            now: date("2026-04-03 10:00", calendar: calendar),
            deliveredKeys: deliveredMorning,
            suppressWorkStartSlot: true
        )
        assert(tenAMCare.isEmpty, "Expected 10:00 care check-in to be suppressed when morning brief already covers it")

        let noonCare = engine.dueCareCheckInSlots(
            now: date("2026-04-03 11:30", calendar: calendar),
            deliveredKeys: [],
            suppressWorkStartSlot: true
        )
        assert(noonCare == [.lunchPrep], "Expected 11:30 care check-in to be due")

        let tracker = DingTalkUnreadTracker(policy: engine)
        let message = MirroredDingTalkNotification(
            sourceAppName: "钉钉",
            title: "审批提醒",
            body: "请处理请假审批",
            dedupeKey: "approval-1"
        )

        tracker.record(notification: message, now: date("2026-04-03 09:52", calendar: calendar))
        assert(
            tracker.dueReminder(now: date("2026-04-03 09:58", calendar: calendar)) == nil,
            "Expected unread reminder to stay gated before 10:00"
        )

        let firstReminder = tracker.dueReminder(now: date("2026-04-03 10:00", calendar: calendar))
        assert(firstReminder != nil, "Expected first unread reminder at 10:00 once gate opens")
        assert(firstReminder?.deliverAt == date("2026-04-03 10:00", calendar: calendar))

        assert(
            tracker.dueReminder(now: date("2026-04-03 10:10", calendar: calendar)) == nil,
            "Expected unread reminders to throttle after the first delivery"
        )

        let secondReminder = tracker.dueReminder(now: date("2026-04-03 10:15", calendar: calendar))
        assert(secondReminder != nil, "Expected follow-up unread reminder after 15 minutes")

        tracker.handleForegroundApplication(bundleIdentifier: "dd.work.exclusive4aliding")
        assert(
            tracker.dueReminder(now: date("2026-04-03 10:30", calendar: calendar)) == nil,
            "Expected unread bucket to clear once DingTalk becomes foreground"
        )

        print("proactive_policy_test: PASS")
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
