import AppKit

@main
enum HistoryPanelWindowClickTest {
    static func main() {
        _ = NSApplication.shared

        let newestID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let olderID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

        assertWindowClickSelects(
            targetThreadID: newestID,
            expectedTitle: "Newest thread"
        )
        assertWindowClickSelects(
            targetThreadID: olderID,
            expectedTitle: "Older thread"
        )

        print("history_panel_window_click_test: PASS")
    }

    private static func assertWindowClickSelects(targetThreadID: UUID, expectedTitle: String) {
        let terminal = TerminalView(frame: NSRect(x: 0, y: 0, width: 420, height: 320))
        let threads = [
            ChatThread(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                title: "Newest thread",
                provider: AgentProvider.current.rawValue,
                messages: [ChatHistoryMessage(role: .assistant, text: "newest")]
            ),
            ChatThread(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                title: "Older thread",
                provider: AgentProvider.current.rawValue,
                messages: [ChatHistoryMessage(role: .assistant, text: "older")]
            )
        ]

        var selectedThreadID: UUID?
        terminal.onRequestHistory = { threads }
        terminal.onRequestCurrentThreadID = { nil }
        terminal.onHistorySelected = { selectedThreadID = $0 }

        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 420, height: 320),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView = terminal
        window.makeKeyAndOrderFront(nil)

        terminal.toggleHistoryPanel()
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))

        guard let row = terminal.historyStack.arrangedSubviews
            .compactMap({ $0 as? HistoryRowView })
            .first(where: { $0.threadID == targetThreadID }) else {
            fail("could not find history row for \(expectedTitle)")
        }

        let eventLocation = row.convert(
            CGPoint(x: row.bounds.midX, y: row.bounds.midY),
            to: nil
        )

        guard let mouseDown = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: eventLocation,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 1
        ), let mouseUp = NSEvent.mouseEvent(
            with: .leftMouseUp,
            location: eventLocation,
            modifierFlags: [],
            timestamp: 0.01,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 2,
            clickCount: 1,
            pressure: 0
        ) else {
            fail("could not synthesize click events for \(expectedTitle)")
        }

        window.sendEvent(mouseDown)
        window.sendEvent(mouseUp)
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))

        expect(
            selectedThreadID == targetThreadID,
            "clicking \(expectedTitle) should select its thread"
        )
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fail(message)
        }
    }

    private static func fail(_ message: String) -> Never {
        fputs("history_panel_window_click_test: FAIL - \(message)\n", stderr)
        exit(1)
    }
}
