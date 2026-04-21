import AppKit

@main
enum HistoryPanelLayoutOrderTest {
    static func main() {
        _ = NSApplication.shared

        let terminal = TerminalView(frame: NSRect(x: 0, y: 0, width: 420, height: 320))
        let newestID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let olderID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let threads = [
            ChatThread(
                id: newestID,
                title: "Newest thread",
                provider: AgentProvider.current.rawValue,
                messages: [ChatHistoryMessage(role: .assistant, text: "newest")]
            ),
            ChatThread(
                id: olderID,
                title: "Older thread",
                provider: AgentProvider.current.rawValue,
                messages: [ChatHistoryMessage(role: .assistant, text: "older")]
            )
        ]

        terminal.onRequestHistory = { threads }
        terminal.onRequestCurrentThreadID = { nil }

        terminal.reloadHistoryList()
        terminal.layoutSubtreeIfNeeded()
        terminal.historyContentView.layoutSubtreeIfNeeded()
        terminal.historyStack.layoutSubtreeIfNeeded()

        let rowsByID: [UUID: HistoryRowView] = Dictionary(
            uniqueKeysWithValues: terminal.historyStack.arrangedSubviews.compactMap { view in
                guard let row = view as? HistoryRowView else { return nil }
                return (row.threadID, row)
            }
        )

        guard let newestRow = rowsByID[newestID], let olderRow = rowsByID[olderID] else {
            fail("expected rows for both thread ids")
        }

        expect(
            newestRow.frame.minY < olderRow.frame.minY,
            "newest thread should render above older thread in the history panel"
        )

        print("history_panel_layout_order_test: PASS")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fail(message)
        }
    }

    private static func fail(_ message: String) -> Never {
        fputs("history_panel_layout_order_test: FAIL - \(message)\n", stderr)
        exit(1)
    }
}
