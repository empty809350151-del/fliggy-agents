import Foundation

@main
enum CharacterFacingPresentationTest {
    static func main() {
        expect(
            !CharacterFacingPresentation.shouldMirrorPose(
                state: .locomotion,
                playbackMode: .loop,
                isWalking: false,
                goingRight: false
            ),
            "paused locomotion should keep the natural, non-mirrored pose"
        )

        expect(
            !CharacterFacingPresentation.shouldMirrorPose(
                state: .locomotion,
                playbackMode: .holdFirstFrame,
                isWalking: false,
                goingRight: false
            ),
            "hold-first-frame fallback should not reuse mirrored walk facing"
        )

        expect(
            CharacterFacingPresentation.shouldMirrorPose(
                state: .locomotion,
                playbackMode: .loop,
                isWalking: true,
                goingRight: false
            ),
            "active leftward locomotion should still mirror the sprite"
        )

        expect(
            !CharacterFacingPresentation.shouldMirrorPose(
                state: .edgeDockLeft,
                playbackMode: .loop,
                isWalking: false,
                goingRight: true
            ),
            "right-facing states should remain non-mirrored"
        )

        print("character_facing_presentation_test: PASS")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fail(message)
        }
    }

    private static func fail(_ message: String) -> Never {
        fputs("character_facing_presentation_test: FAIL - \(message)\n", stderr)
        exit(1)
    }
}
