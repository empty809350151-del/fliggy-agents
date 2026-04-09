import CoreGraphics
import Foundation

@main
enum CharacterEdgeDockStateTest {
    static func main() {
        let visibleFrame = CGRect(x: 100, y: 50, width: 800, height: 600)
        let leftFrame = CGRect(x: 110, y: 60, width: 120, height: 200)
        let neutralFrame = CGRect(x: 170, y: 60, width: 120, height: 200)
        let rightFrame = CGRect(x: 770, y: 60, width: 120, height: 200)

        let leftEdge = CharacterMotionStateMachine.resolveEdgeSide(
            characterFrame: leftFrame,
            visibleFrame: visibleFrame,
            previousEdgeSide: nil,
            previousState: .locomotion,
            stateStartedAt: nil,
            now: 10
        )
        expect(leftEdge == .left, "left threshold should enter edge state")

        let stickyLeft = CharacterMotionStateMachine.resolveEdgeSide(
            characterFrame: neutralFrame,
            visibleFrame: visibleFrame,
            previousEdgeSide: .left,
            previousState: .edgeDockLeft,
            stateStartedAt: 10,
            now: 10.8
        )
        expect(stickyLeft == .left, "edge state should stick during minimum dwell")

        let releasedLeft = CharacterMotionStateMachine.resolveEdgeSide(
            characterFrame: neutralFrame,
            visibleFrame: visibleFrame,
            previousEdgeSide: .left,
            previousState: .edgeDockLeft,
            stateStartedAt: 10,
            now: 12.0
        )
        expect(releasedLeft == nil, "edge state should release after exit threshold and minimum dwell")

        let rightEdge = CharacterMotionStateMachine.resolveEdgeSide(
            characterFrame: rightFrame,
            visibleFrame: visibleFrame,
            previousEdgeSide: nil,
            previousState: .locomotion,
            stateStartedAt: nil,
            now: 20
        )
        expect(rightEdge == .right, "right threshold should enter edge state")

        let inward = CharacterMotionStateMachine.recoveryDirectionAfterEdgeDock(previousState: .edgeDockLeft)
        expect(inward == .right, "left edge recovery should force walking inward")

        print("character_edge_dock_state_test: PASS")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fail(message)
        }
    }

    private static func fail(_ message: String) -> Never {
        fputs("character_edge_dock_state_test: FAIL - \(message)\n", stderr)
        exit(1)
    }
}
