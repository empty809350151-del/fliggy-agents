import AppKit

@main
enum HistoryRowHitTargetTest {
    static func main() {
        let bounds = NSRect(x: 0, y: 0, width: 216, height: 50)
        let deleteFrame = NSRect(x: 180, y: 10, width: 30, height: 30)

        expect(
            HistoryRowHitTargetResolver.resolve(
                point: NSPoint(x: 24, y: 20),
                bounds: bounds,
                deleteButtonFrame: deleteFrame,
                deleteButtonIsInteractive: false
            ),
            equals: .row,
            label: "title area routes to row"
        )

        expect(
            HistoryRowHitTargetResolver.resolve(
                point: NSPoint(x: 150, y: 20),
                bounds: bounds,
                deleteButtonFrame: deleteFrame,
                deleteButtonIsInteractive: false
            ),
            equals: .row,
            label: "right side is still selectable when delete is hidden"
        )

        expect(
            HistoryRowHitTargetResolver.resolve(
                point: NSPoint(x: 195, y: 20),
                bounds: bounds,
                deleteButtonFrame: deleteFrame,
                deleteButtonIsInteractive: true
            ),
            equals: .deleteButton,
            label: "visible delete zone routes to delete"
        )

        expect(
            HistoryRowHitTargetResolver.resolve(
                point: NSPoint(x: 250, y: 20),
                bounds: bounds,
                deleteButtonFrame: deleteFrame,
                deleteButtonIsInteractive: false
            ),
            equals: .none,
            label: "outside row is ignored"
        )

        print("history_row_hit_target_test: PASS")
    }

    private static func expect(
        _ actual: HistoryRowHitTarget,
        equals expected: HistoryRowHitTarget,
        label: String
    ) {
        guard actual == expected else {
            fputs("history_row_hit_target_test: FAIL - \(label): expected \(expected) got \(actual)\n", stderr)
            exit(1)
        }
    }
}
