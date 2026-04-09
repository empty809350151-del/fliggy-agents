import Foundation

final class DingTalkUnreadTracker {
    private struct Bucket {
        var title: String
        var lastBody: String?
        var firstSeenAt: Date
        var lastSeenAt: Date
        var count: Int
        var firstReminderSentAt: Date?
        var lastReminderSentAt: Date?
    }

    private let policy: ProactivePolicyEngine
    private let bucketWindow: TimeInterval = 10 * 60
    private let firstReminderDelay: TimeInterval = 5 * 60
    private let repeatReminderDelay: TimeInterval = 15 * 60
    private let dingTalkBundleIdentifier = "dd.work.exclusive4aliding"

    private var bucket: Bucket?

    init(policy: ProactivePolicyEngine) {
        self.policy = policy
    }

    func record(notification: MirroredDingTalkNotification, now: Date = Date()) {
        let title = notification.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = notification.body?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !title.isEmpty else { return }

        if var bucket, now.timeIntervalSince(bucket.lastSeenAt) <= bucketWindow {
            bucket.title = title
            bucket.lastBody = body ?? bucket.lastBody
            bucket.lastSeenAt = now
            bucket.count += 1
            self.bucket = bucket
            return
        }

        let newBucket = Bucket(
            title: title,
            lastBody: body,
            firstSeenAt: now,
            lastSeenAt: now,
            count: 1,
            firstReminderSentAt: nil,
            lastReminderSentAt: nil
        )
        bucket = newBucket
    }

    func dueReminder(now: Date = Date()) -> ProactiveUnreadReminder? {
        guard var bucket else { return nil }

        let triggerDate: Date
        if let lastReminderSentAt = bucket.lastReminderSentAt {
            triggerDate = lastReminderSentAt.addingTimeInterval(repeatReminderDelay)
        } else {
            triggerDate = bucket.firstSeenAt.addingTimeInterval(firstReminderDelay)
        }

        let deliverAt = policy.nextDeliverableDate(for: triggerDate, now: now)
        guard deliverAt <= now else { return nil }

        bucket.lastReminderSentAt = now
        if bucket.firstReminderSentAt == nil {
            bucket.firstReminderSentAt = now
        }
        self.bucket = bucket

        let countText = bucket.count > 1 ? "\(bucket.count)条" : "一条"
        let bodyPart = bucket.lastBody.map { "，最近一条是“\($0)”" } ?? ""
        let fullText = "钉钉还有\(countText)消息没处理，先看一眼吧\(bodyPart)。"
        let bubbleText = bucket.count > 1 ? "钉钉有\(bucket.count)条未读" : "钉钉有消息没看"
        let key = policy.deliveryKey(
            for: .dingTalkUnread,
            deliverAt: deliverAt,
            identifier: bucket.title.lowercased()
        )

        return ProactiveUnreadReminder(
            deliverAt: deliverAt,
            deliveryKey: key,
            bubbleText: bubbleText,
            fullText: fullText
        )
    }

    func handleForegroundApplication(bundleIdentifier: String?) {
        guard bundleIdentifier == dingTalkBundleIdentifier else { return }
        bucket = nil
    }
}
