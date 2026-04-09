import AppKit

enum HistoryRowHitTarget: Equatable {
    case none
    case row
    case deleteButton
}

enum HistoryRowHitTargetResolver {
    static func resolve(
        point: NSPoint,
        bounds: NSRect,
        deleteButtonFrame: NSRect,
        deleteButtonIsInteractive: Bool
    ) -> HistoryRowHitTarget {
        guard bounds.contains(point) else { return .none }
        if deleteButtonIsInteractive, deleteButtonFrame.contains(point) {
            return .deleteButton
        }
        return .row
    }
}
