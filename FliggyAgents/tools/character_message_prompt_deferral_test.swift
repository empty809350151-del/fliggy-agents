import Foundation

@main
enum CharacterMessagePromptDeferralTest {
    static func main() {
        let machine = CharacterMotionStateMachine()

        let blockedByDrag = machine.resolveNextState(
            context: CharacterMotionContext(
                isPopoverOpen: false,
                isDragging: true,
                isContextMenuVisible: false,
                isAgentBusy: false,
                isHovering: false,
                hoverStartedAt: nil,
                edgeSide: nil,
                hasFreshMessagePrompt: true,
                messagePromptStartedAt: 10,
                stateStartedAt: nil
            ),
            previousState: .locomotion,
            now: 11
        )
        expect(blockedByDrag.state == .dragging, "dragging should block message prompt")
        expect(!blockedByDrag.shouldConsumeMessagePrompt, "blocked prompt should remain pending")

        let deferredPrompt = machine.resolveNextState(
            context: CharacterMotionContext(
                isPopoverOpen: false,
                isDragging: false,
                isContextMenuVisible: false,
                isAgentBusy: false,
                isHovering: false,
                hoverStartedAt: nil,
                edgeSide: nil,
                hasFreshMessagePrompt: true,
                messagePromptStartedAt: 10,
                stateStartedAt: nil
            ),
            previousState: .dragging,
            now: 12
        )
        expect(deferredPrompt.state == .messagePrompt, "prompt should fire once blocking state clears")
        expect(deferredPrompt.shouldConsumeMessagePrompt, "deferred prompt should be consumed when entered")

        let stalePrompt = machine.resolveNextState(
            context: CharacterMotionContext(
                isPopoverOpen: false,
                isDragging: false,
                isContextMenuVisible: false,
                isAgentBusy: false,
                isHovering: false,
                hoverStartedAt: nil,
                edgeSide: nil,
                hasFreshMessagePrompt: true,
                messagePromptStartedAt: 10,
                stateStartedAt: nil
            ),
            previousState: .dragging,
            now: 16
        )
        expect(stalePrompt.state == .locomotion, "stale prompt should not fire")
        expect(stalePrompt.shouldConsumeMessagePrompt, "stale prompt should be cleared")

        print("character_message_prompt_deferral_test: PASS")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fail(message)
        }
    }

    private static func fail(_ message: String) -> Never {
        fputs("character_message_prompt_deferral_test: FAIL - \(message)\n", stderr)
        exit(1)
    }
}
