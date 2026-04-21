import Foundation

final class ReminderInboxStore {
    static let shared = ReminderInboxStore()

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local", isDirectory: true)
            .appendingPathComponent("share", isDirectory: true)
            .appendingPathComponent("fliggy-agents", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("reminder-events.json")
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func loadEvents() -> [ReminderEvent] {
        guard let data = try? Data(contentsOf: fileURL),
              let events = try? decoder.decode([ReminderEvent].self, from: data) else {
            return []
        }
        return events.sorted { $0.createdAt > $1.createdAt }
    }

    @discardableResult
    func record(_ event: ReminderEvent) -> ReminderEvent {
        var allEvents = loadEvents()
        if let index = allEvents.firstIndex(where: { $0.deliveryKey == event.deliveryKey && $0.kind == event.kind }) {
            allEvents[index] = event
        } else {
            allEvents.append(event)
        }
        allEvents.sort { $0.createdAt > $1.createdAt }
        persist(allEvents)
        return event
    }

    func event(for deliveryKey: String, kind: ReminderEventKind) -> ReminderEvent? {
        loadEvents().first { $0.deliveryKey == deliveryKey && $0.kind == kind }
    }

    private func persist(_ events: [ReminderEvent]) {
        if let data = try? encoder.encode(events) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
