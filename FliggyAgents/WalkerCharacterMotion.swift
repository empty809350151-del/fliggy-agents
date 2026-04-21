import AVFoundation
import AppKit
import Foundation

private final class WalkerCharacterMotionRuntime {
    let stateMachine = CharacterMotionStateMachine()
    var assetCatalog: CharacterMotionAssetCatalog?
    var currentState: CharacterMotionState = .locomotion
    var currentStateStartedAt: CFTimeInterval = 0
    var currentClipDescriptor: CharacterMotionClipDescriptor?
    var currentResourceName: String?
    var currentPlaybackMode: CharacterMotionPlaybackMode?
    var hasStartedCurrentOneShotPlayback = false
    var isSuppressedByPopover = false
    var isHoveringCharacter = false
    var hoverStartedAt: CFTimeInterval?
    var pendingMessagePromptAt: CFTimeInterval?
    var previousEdgeSide: CharacterEdgeSide?
    var edgeRecoveryDirection: CharacterWalkDirection?
    var forcedWalkDirection: CharacterWalkDirection?
}

private enum WalkerCharacterMotionRuntimeStore {
    static var runtimes: [ObjectIdentifier: WalkerCharacterMotionRuntime] = [:]
}

extension WalkerCharacter {
    private var motionRuntime: WalkerCharacterMotionRuntime {
        let key = ObjectIdentifier(self)
        if let existing = WalkerCharacterMotionRuntimeStore.runtimes[key] {
            return existing
        }
        let runtime = WalkerCharacterMotionRuntime()
        WalkerCharacterMotionRuntimeStore.runtimes[key] = runtime
        return runtime
    }

    var currentMotionState: CharacterMotionState {
        motionRuntime.currentState
    }

    var currentMotionStateStartedAt: CFTimeInterval {
        motionRuntime.currentStateStartedAt
    }

    var currentMotionPlaybackMode: CharacterMotionPlaybackMode? {
        motionRuntime.currentPlaybackMode
    }

    func initializeMotionSystem() {
        motionRuntime.assetCatalog = CharacterMotionAssetCatalog(videoName: videoName)
        motionRuntime.currentState = .locomotion
        motionRuntime.currentStateStartedAt = CACurrentMediaTime()
        applyMotionResolution(
            CharacterMotionResolution(state: .locomotion),
            now: motionRuntime.currentStateStartedAt,
            force: true
        )
    }

    func requestMessagePrompt(at time: CFTimeInterval = CACurrentMediaTime()) {
        motionRuntime.pendingMessagePromptAt = time
    }

    func setHoveringCharacter(_ isHovering: Bool, at time: CFTimeInterval = CACurrentMediaTime()) {
        if isHovering {
            guard !motionRuntime.isHoveringCharacter else { return }
            motionRuntime.isHoveringCharacter = true
            motionRuntime.hoverStartedAt = time
        } else {
            motionRuntime.isHoveringCharacter = false
            motionRuntime.hoverStartedAt = nil
        }
        syncMotionStateImmediately(at: time)
    }

    func refreshHoverFromCurrentMouseLocation() {
        guard let contentView = window.contentView as? CharacterContentView else { return }
        setHoveringCharacter(contentView.isMouseOverInteractiveContent())
    }

    func completeOneShotMotionIfNeeded(now: CFTimeInterval) -> Bool {
        guard currentMotionState.isOneShot else { return true }
        return now - currentMotionStateStartedAt >= oneShotDuration(for: currentMotionState)
    }

    func updateMotionContext(now: CFTimeInterval) -> CharacterMotionContext {
        CharacterMotionContext(
            isPopoverOpen: isIdleForPopover,
            isDragging: isDragging,
            isContextMenuVisible: skillOrbitWindow?.isVisible == true,
            isAgentBusy: isAgentBusy,
            isHovering: motionRuntime.isHoveringCharacter,
            hoverStartedAt: motionRuntime.hoverStartedAt,
            edgeSide: resolvedEdgeSide(now: now),
            hasFreshMessagePrompt: motionRuntime.pendingMessagePromptAt != nil,
            messagePromptStartedAt: motionRuntime.pendingMessagePromptAt,
            stateStartedAt: motionRuntime.currentStateStartedAt
        )
    }

    func applyMotionResolution(_ resolution: CharacterMotionResolution, now: CFTimeInterval, force: Bool = false) {
        if resolution.shouldConsumeHoverTrigger {
            motionRuntime.hoverStartedAt = nil
        }
        if resolution.shouldConsumeMessagePrompt {
            motionRuntime.pendingMessagePromptAt = nil
        }

        let stateChanged = force
            || resolution.state != motionRuntime.currentState
            || resolution.isSuppressedByPopover != motionRuntime.isSuppressedByPopover

        if !stateChanged {
            refreshMotionPlaybackState()
            return
        }

        let previousState = motionRuntime.currentState
        motionRuntime.currentState = resolution.state
        motionRuntime.currentStateStartedAt = now
        motionRuntime.isSuppressedByPopover = resolution.isSuppressedByPopover
        motionRuntime.hasStartedCurrentOneShotPlayback = false

        if resolution.state == .edgeDockLeft || resolution.state == .edgeDockRight {
            motionRuntime.previousEdgeSide = resolution.state == .edgeDockLeft ? .left : .right
            motionRuntime.edgeRecoveryDirection = nil
            if isWalking {
                enterPause()
            }
            if resolution.state == .edgeDockLeft {
                goingRight = true
            } else {
                goingRight = false
            }
            updateFlip()
        } else if previousState == .edgeDockLeft || previousState == .edgeDockRight {
            motionRuntime.previousEdgeSide = nil
        }

        if !resolution.state.allowsAutomaticTranslation,
           resolution.state != .edgeDockLeft,
           resolution.state != .edgeDockRight {
            isWalking = false
            isPaused = true
        }

        if let descriptor = motionDescriptor(for: resolution.state, previousState: previousState) {
            configurePlayerIfNeeded(descriptor: descriptor, suppressedByPopover: resolution.isSuppressedByPopover)
        }
        refreshMotionPlaybackState()
    }

    func syncMotionStateImmediately(at now: CFTimeInterval = CACurrentMediaTime()) {
        updateMotionState(now: now)
    }

    func updateMotionState(now: CFTimeInterval) {
        guard queuePlayer != nil else { return }
        if currentMotionState.isOneShot, !completeOneShotMotionIfNeeded(now: now) {
            refreshMotionPlaybackState()
            return
        }

        let context = updateMotionContext(now: now)
        let resolution = motionRuntime.stateMachine.resolveNextState(
            context: context,
            previousState: currentMotionState,
            now: now
        )
        applyMotionResolution(resolution, now: now)
    }

    func shouldResumeFromEdgeDock(now: CFTimeInterval) -> Bool {
        guard currentMotionState == .edgeDockLeft || currentMotionState == .edgeDockRight else { return false }
        let dwellDeadline = currentMotionStateStartedAt + motionRuntime.stateMachine.edgeMinimumDwell
        return isPaused && now >= pauseEndTime && now >= dwellDeadline
    }

    func prepareEdgeDockRecoveryIfNeeded() {
        guard let direction = CharacterMotionStateMachine.recoveryDirectionAfterEdgeDock(previousState: currentMotionState) else {
            return
        }
        motionRuntime.edgeRecoveryDirection = direction
        motionRuntime.forcedWalkDirection = direction
    }

    func consumeForcedWalkDirection() -> CharacterWalkDirection? {
        let direction = motionRuntime.forcedWalkDirection
        motionRuntime.forcedWalkDirection = nil
        return direction
    }

    func refreshMotionPlaybackState() {
        guard let playbackMode = motionRuntime.currentPlaybackMode else { return }
        updateFlip()
        applyPlaybackBoundaryBehavior(for: playbackMode)
        switch playbackMode {
        case .holdFirstFrame:
            queuePlayer.pause()
            seekPrecisely(to: .zero)
        case .holdLastFrame:
            holdCurrentClipLastFrame()
        case .oneShot:
            if !motionRuntime.hasStartedCurrentOneShotPlayback {
                seekPrecisely(to: .zero)
                queuePlayer.play()
                motionRuntime.hasStartedCurrentOneShotPlayback = true
            }
        case .loop:
            if motionRuntime.currentState == .locomotion {
                if isWalking && !isIdleForPopover {
                    queuePlayer.play()
                } else {
                    queuePlayer.pause()
                    seekPrecisely(to: .zero)
                }
            } else if isIdleForPopover {
                queuePlayer.pause()
                seekPrecisely(to: .zero)
            } else {
                queuePlayer.play()
            }
        }
    }

    private func configurePlayerIfNeeded(descriptor: CharacterMotionClipDescriptor, suppressedByPopover: Bool) {
        let effectiveMode: CharacterMotionPlaybackMode = suppressedByPopover ? .holdFirstFrame : descriptor.playbackMode
        if !CharacterMotionPlaybackTransition.requiresPlayerRebuild(
            currentResourceName: motionRuntime.currentResourceName,
            currentPlaybackMode: motionRuntime.currentPlaybackMode,
            nextDescriptor: descriptor,
            suppressedByPopover: suppressedByPopover
        ) {
            motionRuntime.currentClipDescriptor = descriptor
            motionRuntime.currentResourceName = descriptor.resourceName
            motionRuntime.currentPlaybackMode = effectiveMode
            return
        }

        guard let assetCatalog = motionRuntime.assetCatalog,
              let url = assetCatalog.url(for: descriptor.kind) ?? Bundle.main.url(forResource: descriptor.resourceName, withExtension: "mov") else {
            return
        }

        motionRuntime.currentClipDescriptor = descriptor
        motionRuntime.currentResourceName = descriptor.resourceName
        motionRuntime.currentPlaybackMode = effectiveMode

        looper = nil
        queuePlayer.removeAllItems()
        applyPlaybackBoundaryBehavior(for: effectiveMode)

        let item = AVPlayerItem(asset: AVAsset(url: url))
        switch effectiveMode {
        case .loop:
            looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        case .oneShot, .holdFirstFrame, .holdLastFrame:
            queuePlayer.insert(item, after: nil)
        }
    }

    private func motionDescriptor(
        for state: CharacterMotionState,
        previousState: CharacterMotionState
    ) -> CharacterMotionClipDescriptor? {
        guard let descriptor = motionRuntime.assetCatalog?.descriptor(for: state.clipKind) else {
            return nil
        }

        if state == .contextMenuIdle,
           descriptor.usesFallback,
           previousState == .contextMenuEnter,
           let currentDescriptor = motionRuntime.currentClipDescriptor,
           currentDescriptor.kind == .contextMenuEnterOnce,
           !currentDescriptor.usesFallback {
            return CharacterMotionClipDescriptor(
                kind: currentDescriptor.kind,
                resourceName: currentDescriptor.resourceName,
                playbackMode: .holdLastFrame,
                usesFallback: true,
                duration: currentDescriptor.duration
            )
        }

        return descriptor
    }

    private func resolvedEdgeSide(now: CFTimeInterval) -> CharacterEdgeSide? {
        guard let screen = window.screen ?? NSScreen.main else {
            return nil
        }

        if motionRuntime.edgeRecoveryDirection != nil {
            let stillNearEdge = CharacterMotionStateMachine.resolveEdgeSide(
                characterFrame: window.frame,
                visibleFrame: screen.visibleFrame,
                previousEdgeSide: nil,
                previousState: .locomotion,
                stateStartedAt: nil,
                now: now,
                enterThreshold: motionRuntime.stateMachine.edgeEnterThreshold,
                exitThreshold: motionRuntime.stateMachine.edgeExitThreshold,
                minimumDwell: motionRuntime.stateMachine.edgeMinimumDwell
            )
            if stillNearEdge == nil {
                motionRuntime.edgeRecoveryDirection = nil
            } else {
                return nil
            }
        }

        return CharacterMotionStateMachine.resolveEdgeSide(
            characterFrame: window.frame,
            visibleFrame: screen.visibleFrame,
            previousEdgeSide: motionRuntime.previousEdgeSide,
            previousState: currentMotionState,
            stateStartedAt: currentMotionStateStartedAt,
            now: now,
            enterThreshold: motionRuntime.stateMachine.edgeEnterThreshold,
            exitThreshold: motionRuntime.stateMachine.edgeExitThreshold,
            minimumDwell: motionRuntime.stateMachine.edgeMinimumDwell
        )
    }

    private func oneShotDuration(for state: CharacterMotionState) -> CFTimeInterval {
        if let clipDuration = motionRuntime.currentClipDescriptor?.duration,
           motionRuntime.currentClipDescriptor?.playbackMode == .oneShot,
           clipDuration > 0 {
            return clipDuration
        }

        switch state {
        case .hover:
            return 0.4
        case .contextMenuEnter:
            return 0.2
        case .messagePrompt:
            return 0.75
        case .locomotion, .dragging, .contextMenuIdle, .edgeDockLeft, .edgeDockRight, .thinking:
            return 0
        }
    }

    private func applyPlaybackBoundaryBehavior(for playbackMode: CharacterMotionPlaybackMode) {
        switch playbackMode {
        case .loop:
            queuePlayer.actionAtItemEnd = .advance
        case .oneShot, .holdFirstFrame, .holdLastFrame:
            queuePlayer.actionAtItemEnd = .pause
        }
    }

    private func holdCurrentClipLastFrame() {
        queuePlayer.pause()
        guard let tailTime = currentClipTailTime() else { return }

        let currentSeconds = CMTimeGetSeconds(queuePlayer.currentTime())
        let tailSeconds = CMTimeGetSeconds(tailTime)
        let isAlreadyAtTail = currentSeconds.isFinite
            && tailSeconds.isFinite
            && abs(currentSeconds - tailSeconds) <= (1.0 / 600.0)

        if !isAlreadyAtTail {
            seekPrecisely(to: tailTime)
        }
    }

    private func currentClipTailTime() -> CMTime? {
        let durationSeconds: Double
        if let clipDuration = motionRuntime.currentClipDescriptor?.duration, clipDuration > 0 {
            durationSeconds = clipDuration
        } else if let currentItem = queuePlayer.currentItem {
            let itemDuration = CMTimeGetSeconds(currentItem.duration)
            guard itemDuration.isFinite, itemDuration > 0 else { return nil }
            durationSeconds = itemDuration
        } else {
            return nil
        }

        let preferredTimescale: CMTimeScale = 600
        let frameEpsilon = 1.0 / Double(preferredTimescale)
        let tailSeconds = max(durationSeconds - frameEpsilon, 0)
        return CMTime(seconds: tailSeconds, preferredTimescale: preferredTimescale)
    }

    private func seekPrecisely(to time: CMTime) {
        queuePlayer.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }
}
