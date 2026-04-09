import Foundation

@main
enum CharacterMotionAssetCatalogTest {
    static func main() {
        let catalog = CharacterMotionAssetCatalog(
            locomotionResourceName: "walk-bruce-01",
            availableResourceNames: ["walk-bruce-01", "thinking-bruce-01", "context-menu-idle-bruce-01"]
        )

        let locomotion = catalog.descriptor(for: .locomotionLoop)
        expect(locomotion.resourceName == "walk-bruce-01", "walk resource should back locomotion")
        expect(!locomotion.usesFallback, "locomotion should not use fallback")

        let thinking = catalog.descriptor(for: .thinkingLoop)
        expect(thinking.resourceName == "thinking-bruce-01", "thinking should resolve explicit resource")
        expect(thinking.playbackMode == .loop, "thinking resource should loop")

        let hover = catalog.descriptor(for: .hoverOnce)
        expect(hover.resourceName == "walk-bruce-01", "missing hover should fall back to walk")
        expect(hover.usesFallback, "missing hover should use fallback")
        expect(hover.playbackMode == .holdFirstFrame, "missing hover should hold first frame")

        expect(
            !CharacterMotionPlaybackTransition.requiresPlayerRebuild(
                currentResourceName: "walk-bruce-01",
                currentPlaybackMode: .loop,
                nextDescriptor: hover,
                suppressedByPopover: false
            ),
            "fallback hover on the same walk resource should reuse the current player item"
        )

        expect(
            !CharacterMotionPlaybackTransition.requiresPlayerRebuild(
                currentResourceName: "walk-bruce-01",
                currentPlaybackMode: .holdFirstFrame,
                nextDescriptor: locomotion,
                suppressedByPopover: false
            ),
            "returning from fallback hold to locomotion on the same resource should reuse the current player item"
        )

        let explicitThinking = catalog.descriptor(for: .thinkingLoop)
        expect(
            CharacterMotionPlaybackTransition.requiresPlayerRebuild(
                currentResourceName: "walk-bruce-01",
                currentPlaybackMode: .loop,
                nextDescriptor: explicitThinking,
                suppressedByPopover: false
            ),
            "switching to a different explicit resource should still rebuild the player"
        )

        expect(
            CharacterMotionAssetCatalog.resourceName(for: .messagePromptOnce, characterBaseName: "bruce") == "message-prompt-bruce-01",
            "resource name generation should follow convention"
        )

        print("character_motion_asset_catalog_test: PASS")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fail(message)
        }
    }

    private static func fail(_ message: String) -> Never {
        fputs("character_motion_asset_catalog_test: FAIL - \(message)\n", stderr)
        exit(1)
    }
}
