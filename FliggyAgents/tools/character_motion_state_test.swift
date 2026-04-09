import Foundation

@main
enum CharacterMotionStateTest {
    static func main() {
        let machine = CharacterMotionStateMachine()

        let thinkingResolution = machine.resolveNextState(
            context: CharacterMotionContext(
                isPopoverOpen: false,
                isDragging: false,
                isContextMenuVisible: false,
                isAgentBusy: true,
                isHovering: false,
                hoverStartedAt: nil,
                edgeSide: nil,
                hasFreshMessagePrompt: false,
                messagePromptStartedAt: nil,
                stateStartedAt: nil
            ),
            previousState: .locomotion,
            now: 100
        )
        expect(thinkingResolution.state == .thinking, "busy agent should enter thinking")

        let promptResolution = machine.resolveNextState(
            context: CharacterMotionContext(
                isPopoverOpen: false,
                isDragging: false,
                isContextMenuVisible: false,
                isAgentBusy: true,
                isHovering: false,
                hoverStartedAt: nil,
                edgeSide: nil,
                hasFreshMessagePrompt: true,
                messagePromptStartedAt: 100,
                stateStartedAt: nil
            ),
            previousState: .thinking,
            now: 101
        )
        expect(promptResolution.state == .messagePrompt, "fresh message should preempt thinking")
        expect(promptResolution.shouldConsumeMessagePrompt, "message prompt should be consumed when entered")

        let blockedByContextMenu = machine.resolveNextState(
            context: CharacterMotionContext(
                isPopoverOpen: false,
                isDragging: false,
                isContextMenuVisible: true,
                isAgentBusy: true,
                isHovering: false,
                hoverStartedAt: nil,
                edgeSide: nil,
                hasFreshMessagePrompt: true,
                messagePromptStartedAt: 100,
                stateStartedAt: nil
            ),
            previousState: .thinking,
            now: 101
        )
        expect(blockedByContextMenu.state == .contextMenuEnter, "context menu should outrank message prompt")
        expect(!blockedByContextMenu.shouldConsumeMessagePrompt, "blocked prompt should stay pending")

        let returnToThinking = machine.resolveNextState(
            context: CharacterMotionContext(
                isPopoverOpen: false,
                isDragging: false,
                isContextMenuVisible: false,
                isAgentBusy: true,
                isHovering: false,
                hoverStartedAt: nil,
                edgeSide: nil,
                hasFreshMessagePrompt: false,
                messagePromptStartedAt: nil,
                stateStartedAt: 103
            ),
            previousState: .contextMenuIdle,
            now: 104
        )
        expect(returnToThinking.state == .thinking, "closing context menu while busy should return to thinking")

        let suppressed = machine.resolveNextState(
            context: CharacterMotionContext(
                isPopoverOpen: true,
                isDragging: false,
                isContextMenuVisible: false,
                isAgentBusy: true,
                isHovering: true,
                hoverStartedAt: 104,
                edgeSide: .left,
                hasFreshMessagePrompt: true,
                messagePromptStartedAt: 104,
                stateStartedAt: nil
            ),
            previousState: .thinking,
            now: 105
        )
        expect(suppressed.state == .locomotion, "popover should suppress motion to base locomotion")
        expect(suppressed.isSuppressedByPopover, "popover suppression flag should be set")

        expect(CharacterMotionState.locomotion.allowsAutomaticTranslation, "locomotion should allow automatic translation")
        expect(!CharacterMotionState.hover.allowsAutomaticTranslation, "hover should freeze automatic translation")
        expect(!CharacterMotionState.thinking.allowsAutomaticTranslation, "thinking should freeze automatic translation")
        expect(!CharacterMotionState.messagePrompt.allowsAutomaticTranslation, "message prompt should freeze automatic translation")
        expect(!CharacterMotionState.edgeDockLeft.allowsAutomaticTranslation, "edge dock should freeze automatic translation")

        print("character_motion_state_test: PASS")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fail(message)
        }
    }

    private static func fail(_ message: String) -> Never {
        fputs("character_motion_state_test: FAIL - \(message)\n", stderr)
        exit(1)
    }
}
