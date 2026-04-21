import AppKit

@main
enum HistoryPanelClickRoutingTest {
    static func main() {
        _ = NSApplication.shared

        let terminal = TerminalView(frame: NSRect(x: 0, y: 0, width: 420, height: 310))
        let firstID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let secondID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let threads = [
            ChatThread(
                id: firstID,
                title: "First thread",
                provider: AgentProvider.current.rawValue,
                messages: [ChatHistoryMessage(role: .assistant, text: "one")]
            ),
            ChatThread(
                id: secondID,
                title: "Second thread",
                provider: AgentProvider.current.rawValue,
                messages: [ChatHistoryMessage(role: .assistant, text: "two")]
            )
        ]

        var selectedThreadID: UUID?
        terminal.onRequestHistory = { threads }
        terminal.onRequestCurrentThreadID = { nil }
        terminal.onHistorySelected = { selectedThreadID = $0 }

        terminal.reloadHistoryList()
        terminal.layoutSubtreeIfNeeded()

        let rows = terminal.historyStack.arrangedSubviews.compactMap { $0 as? HistoryRowView }
        guard rows.count == 2 else {
            fail("expected 2 history rows, got \(rows.count)")
        }

        let secondRow = rows[1]
        let secondRowCenter = terminal.historyContentView.convert(
            CGPoint(x: secondRow.bounds.midX, y: secondRow.bounds.midY),
            from: secondRow
        )
        let routedThreadID = terminal.routeHistoryClick(at: secondRowCenter)

        expect(routedThreadID == secondID, "routeHistoryClick should return second thread id")
        expect(selectedThreadID == secondID, "routeHistoryClick should forward second thread id")

        let deletePoint = terminal.historyContentView.convert(
            CGPoint(x: secondRow.bounds.maxX - 8, y: secondRow.bounds.midY),
            from: secondRow
        )
        let deleteThreadID = terminal.routeHistoryClick(at: deletePoint)
        expect(deleteThreadID == secondID, "hidden delete zone should still forward row selection")

        print("history_panel_click_routing_test: PASS")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fail(message)
        }
    }

    private static func fail(_ message: String) -> Never {
        fputs("history_panel_click_routing_test: FAIL - \(message)\n", stderr)
        exit(1)
    }
}
