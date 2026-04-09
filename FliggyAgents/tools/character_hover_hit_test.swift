import CoreGraphics
import Foundation

@main
enum CharacterHoverHitTest {
    static func main() {
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 200)
        let centerPoint = CGPoint(x: 50, y: 100)
        let edgePoint = CGPoint(x: 5, y: 100)
        let outsidePoint = CGPoint(x: -10, y: 100)

        let fallbackRect = CharacterHoverHitTesting.fallbackInteractiveRect(for: bounds)
        expect(fallbackRect.contains(centerPoint), "fallback rect should preserve the stable body hit area")
        expect(!fallbackRect.contains(edgePoint), "fallback rect should still exclude transparent edge margins")

        expect(
            CharacterHoverHitTesting.isInteractive(point: centerPoint, bounds: bounds, sampledOpaquePixel: false),
            "fallback hit area should keep hover stable when pixel sampling cannot confirm opacity"
        )
        expect(
            CharacterHoverHitTesting.isInteractive(point: edgePoint, bounds: bounds, sampledOpaquePixel: true),
            "confirmed opaque pixels near the edge should still count as interactive"
        )
        expect(
            !CharacterHoverHitTesting.isInteractive(point: edgePoint, bounds: bounds, sampledOpaquePixel: false),
            "transparent edge pixels should stay non-interactive without a stable fallback hit"
        )
        expect(
            !CharacterHoverHitTesting.isInteractive(point: outsidePoint, bounds: bounds, sampledOpaquePixel: true),
            "points outside bounds should never hit"
        )

        let delayedExit = CharacterHoverStability.resolve(
            isHovering: true,
            wantsHover: false,
            pendingExitDeadline: nil,
            now: 10
        )
        expect(delayedExit.isHovering, "hover should stay active during the exit grace window")
        expect(delayedExit.pendingExitDeadline == 10.12, "exit grace window should be scheduled once")

        let stickyDuringGrace = CharacterHoverStability.resolve(
            isHovering: true,
            wantsHover: false,
            pendingExitDeadline: 10.12,
            now: 10.05
        )
        expect(stickyDuringGrace.isHovering, "hover should remain sticky before the grace deadline")
        expect(stickyDuringGrace.pendingExitDeadline == 10.12, "existing grace deadline should be reused")

        let clearedAfterGrace = CharacterHoverStability.resolve(
            isHovering: true,
            wantsHover: false,
            pendingExitDeadline: 10.12,
            now: 10.13
        )
        expect(!clearedAfterGrace.isHovering, "hover should clear once the grace deadline expires")
        expect(clearedAfterGrace.pendingExitDeadline == nil, "expired grace deadline should be cleared")

        let recoveredHover = CharacterHoverStability.resolve(
            isHovering: true,
            wantsHover: true,
            pendingExitDeadline: 10.12,
            now: 10.05
        )
        expect(recoveredHover.isHovering, "confirmed hover should stay active")
        expect(recoveredHover.pendingExitDeadline == nil, "confirmed hover should cancel any pending exit")

        print("character_hover_hit_test: PASS")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fail(message)
        }
    }

    private static func fail(_ message: String) -> Never {
        fputs("character_hover_hit_test: FAIL - \(message)\n", stderr)
        exit(1)
    }
}
