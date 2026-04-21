import Foundation

struct DingTalkNotificationCandidate: Equatable {
    let appName: String?
    let title: String?
    let body: String?
    let bundleIdentifier: String?
}

struct MirroredDingTalkNotification: Equatable {
    let sourceAppName: String
    let title: String
    let body: String?
    let dedupeKey: String

    var displayText: String {
        guard let body, !body.isEmpty else {
            return title
        }
        return "\(title)：\(body)"
    }
}

struct DingTalkNotificationContentParser {
    let acceptedDisplayNames: Set<String>
    var ignoredFragments: [String] = [
        "notification center",
        "通知中心",
        "关于本机",
        "banner",
        "横幅"
    ]
    var ignoredExactValues: Set<String> = ["notification", "通知", "apple"]

    func makeCandidate(from strings: [String], fallbackBundleIdentifier: String) -> DingTalkNotificationCandidate? {
        let orderedStrings = orderedUniqueStrings(from: strings)
        guard !orderedStrings.isEmpty,
              let appName = orderedStrings.first(where: containsDingTalkDisplayName(_:)) else {
            return nil
        }

        let relevantStrings = orderedStrings.compactMap(cleanedNotificationText)
        guard !relevantStrings.isEmpty else { return nil }

        let parsed = parseContactAndMessage(from: relevantStrings)
        guard let title = parsed.title, !title.isEmpty else { return nil }

        return DingTalkNotificationCandidate(
            appName: appName,
            title: title,
            body: parsed.body,
            bundleIdentifier: fallbackBundleIdentifier
        )
    }

    private func orderedUniqueStrings(from strings: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for raw in strings {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let key = trimmed.lowercased()
            guard seen.insert(key).inserted else { continue }
            result.append(trimmed)
        }

        return result
    }

    private func cleanedNotificationText(_ value: String) -> String? {
        var trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        for displayName in acceptedDisplayNames {
            if trimmed.caseInsensitiveCompare(displayName) == .orderedSame {
                return nil
            }

            if trimmed.lowercased().hasPrefix(displayName.lowercased() + " ") {
                trimmed = String(trimmed.dropFirst(displayName.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        let lowered = trimmed.lowercased()
        if ignoredExactValues.contains(lowered) {
            return nil
        }

        if ignoredFragments.contains(where: { lowered.contains($0) }) {
            return nil
        }

        return trimmed.isEmpty ? nil : trimmed
    }

    private func isDingTalkDisplayName(_ value: String) -> Bool {
        acceptedDisplayNames.contains { known in
            value.caseInsensitiveCompare(known) == .orderedSame
        }
    }

    private func containsDingTalkDisplayName(_ value: String) -> Bool {
        isDingTalkDisplayName(value) || acceptedDisplayNames.contains { known in
            value.lowercased().hasPrefix(known.lowercased() + " ")
        }
    }

    private func parseContactAndMessage(from values: [String]) -> (title: String?, body: String?) {
        guard let first = values.first else {
            return (nil, nil)
        }

        if let combined = splitCombinedContactAndMessage(first) {
            return combined
        }

        if values.count >= 2 {
            let title = values[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let body = values.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            if isLikelyContactName(title), !body.isEmpty {
                return (title, body)
            }
            return (body.isEmpty ? title : body, nil)
        }

        return (first, nil)
    }

    private func splitCombinedContactAndMessage(_ value: String) -> (title: String, body: String)? {
        let separators: Set<Character> = ["：", ":", "，", ",", "、"]
        guard let separatorIndex = value.firstIndex(where: { separators.contains($0) }) else {
            return nil
        }

        let title = String(value[..<separatorIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        let bodyStart = value.index(after: separatorIndex)
        let body = String(value[bodyStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard isLikelyContactName(title), !body.isEmpty else { return nil }
        return (title, body)
    }

    private func isLikelyContactName(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...10).contains(trimmed.count) else { return false }
        let pattern = #"^[\p{Han}A-Za-z·_\-]+$"#
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }
}

struct DingTalkNotificationNormalizer {
    let acceptedBundleIdentifiers: Set<String>
    let acceptedDisplayNames: Set<String>
    var maxTitleLength: Int = 28
    var maxBodyLength: Int = 42

    func normalize(_ candidate: DingTalkNotificationCandidate) -> MirroredDingTalkNotification? {
        let bundleID = candidate.bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let appName = candidate.appName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let normalizedName = appName.lowercased()
        let acceptedNames = Set(acceptedDisplayNames.map { $0.lowercased() })

        guard acceptedBundleIdentifiers.contains(bundleID) || acceptedNames.contains(normalizedName) else {
            return nil
        }

        let title = trimmed(candidate.title, limit: maxTitleLength)
        guard !title.isEmpty else { return nil }

        let body = trimmed(candidate.body, limit: maxBodyLength)
        let bodyValue = body.isEmpty ? nil : body
        let dedupeKey = [bundleID, normalizedName, title, bodyValue ?? ""]
            .joined(separator: "|")
            .lowercased()

        return MirroredDingTalkNotification(
            sourceAppName: appName.isEmpty ? "DingTalk" : appName,
            title: title,
            body: bodyValue,
            dedupeKey: dedupeKey
        )
    }

    private func trimmed(_ value: String?, limit: Int) -> String {
        let collapsed = (value ?? "")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard collapsed.count > limit else { return collapsed }
        return String(collapsed.prefix(max(0, limit - 1))) + "…"
    }
}

struct DingTalkNotificationDeduper {
    let ttl: TimeInterval
    private var lastSeenAt: [String: Date] = [:]

    init(ttl: TimeInterval) {
        self.ttl = ttl
    }

    mutating func shouldEmit(_ notification: MirroredDingTalkNotification, now: Date = Date()) -> Bool {
        prune(now: now)
        if let previous = lastSeenAt[notification.dedupeKey], now.timeIntervalSince(previous) < ttl {
            return false
        }
        lastSeenAt[notification.dedupeKey] = now
        return true
    }

    mutating func prune(now: Date = Date()) {
        lastSeenAt = lastSeenAt.filter { now.timeIntervalSince($0.value) < ttl }
    }
}
