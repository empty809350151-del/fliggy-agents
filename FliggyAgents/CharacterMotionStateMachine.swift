import CoreGraphics
import Foundation

struct CharacterMotionStateMachine {
    let messagePromptFreshness: CFTimeInterval
    let edgeEnterThreshold: CGFloat
    let edgeExitThreshold: CGFloat
    let edgeMinimumDwell: CFTimeInterval

    init(
        messagePromptFreshness: CFTimeInterval = 5.0,
        edgeEnterThreshold: CGFloat = 24,
        edgeExitThreshold: CGFloat = 40,
        edgeMinimumDwell: CFTimeInterval = 1.5
    ) {
        self.messagePromptFreshness = messagePromptFreshness
        self.edgeEnterThreshold = edgeEnterThreshold
        self.edgeExitThreshold = edgeExitThreshold
        self.edgeMinimumDwell = edgeMinimumDwell
    }

    func resolveNextState(
        context: CharacterMotionContext,
        previousState: CharacterMotionState,
        now: CFTimeInterval
    ) -> CharacterMotionResolution {
        let promptIsFresh = isMessagePromptFresh(context: context, now: now)
        let shouldClearStalePrompt = context.hasFreshMessagePrompt && !promptIsFresh

        if context.isPopoverOpen {
            return CharacterMotionResolution(
                state: .locomotion,
                isSuppressedByPopover: true,
                shouldConsumeMessagePrompt: shouldClearStalePrompt
            )
        }

        if context.isDragging {
            return CharacterMotionResolution(
                state: .dragging,
                shouldConsumeMessagePrompt: shouldClearStalePrompt
            )
        }

        if context.isContextMenuVisible {
            let state: CharacterMotionState
            switch previousState {
            case .contextMenuEnter, .contextMenuIdle:
                state = .contextMenuIdle
            default:
                state = .contextMenuEnter
            }
            return CharacterMotionResolution(
                state: state,
                shouldConsumeMessagePrompt: shouldClearStalePrompt
            )
        }

        if promptIsFresh && previousState != .messagePrompt {
            return CharacterMotionResolution(
                state: .messagePrompt,
                shouldConsumeMessagePrompt: true
            )
        }

        if context.isAgentBusy {
            return CharacterMotionResolution(
                state: .thinking,
                shouldConsumeMessagePrompt: shouldClearStalePrompt
            )
        }

        if let edgeSide = context.edgeSide {
            let edgeState: CharacterMotionState = edgeSide == .left ? .edgeDockLeft : .edgeDockRight
            return CharacterMotionResolution(
                state: edgeState,
                shouldConsumeMessagePrompt: shouldClearStalePrompt
            )
        }

        if context.isHovering,
           context.hoverStartedAt != nil,
           previousState != .hover {
            return CharacterMotionResolution(
                state: .hover,
                shouldConsumeHoverTrigger: true,
                shouldConsumeMessagePrompt: shouldClearStalePrompt
            )
        }

        return CharacterMotionResolution(
            state: .locomotion,
            shouldConsumeMessagePrompt: shouldClearStalePrompt
        )
    }

    private func isMessagePromptFresh(context: CharacterMotionContext, now: CFTimeInterval) -> Bool {
        guard context.hasFreshMessagePrompt,
              let startedAt = context.messagePromptStartedAt else {
            return false
        }
        return now - startedAt <= messagePromptFreshness
    }

    static func resolveEdgeSide(
        characterFrame: CGRect,
        visibleFrame: CGRect,
        previousEdgeSide: CharacterEdgeSide?,
        previousState: CharacterMotionState,
        stateStartedAt: CFTimeInterval?,
        now: CFTimeInterval,
        enterThreshold: CGFloat = 24,
        exitThreshold: CGFloat = 40,
        minimumDwell: CFTimeInterval = 1.5
    ) -> CharacterEdgeSide? {
        let leftDistance = characterFrame.minX - visibleFrame.minX
        let rightDistance = visibleFrame.maxX - characterFrame.maxX

        let previousWasLeft = previousEdgeSide == .left || previousState == .edgeDockLeft
        let previousWasRight = previousEdgeSide == .right || previousState == .edgeDockRight
        let dwellElapsed = stateStartedAt.map { now - $0 } ?? .greatestFiniteMagnitude

        if previousWasLeft {
            if dwellElapsed < minimumDwell {
                return .left
            }
            if leftDistance < exitThreshold {
                return .left
            }
        }

        if previousWasRight {
            if dwellElapsed < minimumDwell {
                return .right
            }
            if rightDistance < exitThreshold {
                return .right
            }
        }

        if leftDistance <= enterThreshold {
            return .left
        }
        if rightDistance <= enterThreshold {
            return .right
        }
        return nil
    }

    static func recoveryDirectionAfterEdgeDock(previousState: CharacterMotionState) -> CharacterWalkDirection? {
        switch previousState {
        case .edgeDockLeft:
            return .right
        case .edgeDockRight:
            return .left
        default:
            return nil
        }
    }
}
