import CoreGraphics
import Foundation

enum CharacterMotionPriority: Int, Comparable {
    case locomotion = 0
    case hover = 1
    case edgeDock = 2
    case thinking = 3
    case messagePrompt = 4
    case contextMenu = 5
    case dragging = 6

    static func < (lhs: CharacterMotionPriority, rhs: CharacterMotionPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum CharacterEdgeSide: Equatable {
    case left
    case right
}

enum CharacterWalkDirection: Equatable {
    case left
    case right
}

enum CharacterMotionPlaybackMode: Equatable {
    case loop
    case oneShot
    case holdFirstFrame
    case holdLastFrame
}

enum CharacterMotionClipKind: CaseIterable, Equatable {
    case locomotionLoop
    case hoverOnce
    case dragLoop
    case contextMenuEnterOnce
    case contextMenuIdleLoop
    case edgeLeftLoop
    case edgeRightLoop
    case thinkingLoop
    case messagePromptOnce

    var defaultPlaybackMode: CharacterMotionPlaybackMode {
        switch self {
        case .locomotionLoop, .dragLoop, .contextMenuIdleLoop, .edgeLeftLoop, .edgeRightLoop, .thinkingLoop:
            return .loop
        case .hoverOnce, .contextMenuEnterOnce, .messagePromptOnce:
            return .oneShot
        }
    }
}

enum CharacterMotionState: Equatable {
    case locomotion
    case hover
    case dragging
    case contextMenuEnter
    case contextMenuIdle
    case edgeDockLeft
    case edgeDockRight
    case thinking
    case messagePrompt

    var priority: CharacterMotionPriority {
        switch self {
        case .locomotion:
            return .locomotion
        case .hover:
            return .hover
        case .edgeDockLeft, .edgeDockRight:
            return .edgeDock
        case .thinking:
            return .thinking
        case .messagePrompt:
            return .messagePrompt
        case .contextMenuEnter, .contextMenuIdle:
            return .contextMenu
        case .dragging:
            return .dragging
        }
    }

    var clipKind: CharacterMotionClipKind {
        switch self {
        case .locomotion:
            return .locomotionLoop
        case .hover:
            return .hoverOnce
        case .dragging:
            return .dragLoop
        case .contextMenuEnter:
            return .contextMenuEnterOnce
        case .contextMenuIdle:
            return .contextMenuIdleLoop
        case .edgeDockLeft:
            return .edgeLeftLoop
        case .edgeDockRight:
            return .edgeRightLoop
        case .thinking:
            return .thinkingLoop
        case .messagePrompt:
            return .messagePromptOnce
        }
    }

    var isOneShot: Bool {
        switch self {
        case .hover, .contextMenuEnter, .messagePrompt:
            return true
        case .locomotion, .dragging, .contextMenuIdle, .edgeDockLeft, .edgeDockRight, .thinking:
            return false
        }
    }

    var allowsAutomaticTranslation: Bool {
        switch self {
        case .locomotion:
            return true
        case .hover, .dragging, .contextMenuEnter, .contextMenuIdle, .edgeDockLeft, .edgeDockRight, .thinking, .messagePrompt:
            return false
        }
    }
}

enum CharacterHoverHitTesting {
    static func fallbackInteractiveRect(for bounds: CGRect) -> CGRect {
        let insetX = bounds.width * 0.2
        let insetY = bounds.height * 0.15
        return bounds.insetBy(dx: insetX, dy: insetY)
    }

    static func isInteractive(point: CGPoint, bounds: CGRect, sampledOpaquePixel: Bool) -> Bool {
        guard bounds.contains(point) else { return false }
        if sampledOpaquePixel {
            return true
        }
        return fallbackInteractiveRect(for: bounds).contains(point)
    }
}

struct CharacterHoverStabilityResolution: Equatable {
    let isHovering: Bool
    let pendingExitDeadline: CFTimeInterval?
}

enum CharacterHoverStability {
    static func resolve(
        isHovering: Bool,
        wantsHover: Bool,
        pendingExitDeadline: CFTimeInterval?,
        now: CFTimeInterval,
        exitGracePeriod: CFTimeInterval = 0.12,
        forceExit: Bool = false
    ) -> CharacterHoverStabilityResolution {
        if forceExit {
            return CharacterHoverStabilityResolution(isHovering: false, pendingExitDeadline: nil)
        }

        if wantsHover {
            return CharacterHoverStabilityResolution(isHovering: true, pendingExitDeadline: nil)
        }

        guard isHovering else {
            return CharacterHoverStabilityResolution(isHovering: false, pendingExitDeadline: nil)
        }

        if let pendingExitDeadline {
            if now >= pendingExitDeadline {
                return CharacterHoverStabilityResolution(isHovering: false, pendingExitDeadline: nil)
            }
            return CharacterHoverStabilityResolution(isHovering: true, pendingExitDeadline: pendingExitDeadline)
        }

        return CharacterHoverStabilityResolution(
            isHovering: true,
            pendingExitDeadline: now + exitGracePeriod
        )
    }
}

enum CharacterMotionPlaybackTransition {
    static func requiresPlayerRebuild(
        currentResourceName: String?,
        currentPlaybackMode: CharacterMotionPlaybackMode?,
        nextDescriptor: CharacterMotionClipDescriptor,
        suppressedByPopover: Bool
    ) -> Bool {
        let effectiveMode: CharacterMotionPlaybackMode = suppressedByPopover ? .holdFirstFrame : nextDescriptor.playbackMode

        guard let currentResourceName else { return true }
        guard currentResourceName == nextDescriptor.resourceName else { return true }

        if currentPlaybackMode == effectiveMode {
            return false
        }

        if let currentPlaybackMode,
           isSafeInPlaceModeChange(from: currentPlaybackMode, to: effectiveMode) {
            return false
        }

        return true
    }

    private static func isSafeInPlaceModeChange(
        from currentPlaybackMode: CharacterMotionPlaybackMode,
        to nextPlaybackMode: CharacterMotionPlaybackMode
    ) -> Bool {
        switch (currentPlaybackMode, nextPlaybackMode) {
        case (.loop, .holdFirstFrame), (.holdFirstFrame, .loop):
            return true
        case (.oneShot, .holdLastFrame), (.holdLastFrame, .oneShot):
            return true
        case (.holdLastFrame, .holdLastFrame):
            return true
        case (.holdFirstFrame, .holdFirstFrame), (.loop, .loop), (.oneShot, .oneShot):
            return true
        case (.loop, .oneShot), (.oneShot, .loop), (.holdFirstFrame, .oneShot), (.oneShot, .holdFirstFrame):
            return false
        case (.loop, .holdLastFrame), (.holdLastFrame, .loop), (.holdFirstFrame, .holdLastFrame), (.holdLastFrame, .holdFirstFrame):
            return false
        }
    }
}

enum CharacterFacingPresentation {
    static func shouldMirrorPose(
        state: CharacterMotionState,
        playbackMode: CharacterMotionPlaybackMode?,
        isWalking: Bool,
        goingRight: Bool
    ) -> Bool {
        switch state {
        case .contextMenuEnter, .contextMenuIdle:
            return false
        case .locomotion, .hover, .dragging, .edgeDockLeft, .edgeDockRight, .thinking, .messagePrompt:
            break
        }

        guard !goingRight else { return false }

        if playbackMode == .holdFirstFrame {
            return false
        }

        if state == .locomotion && !isWalking {
            return false
        }

        return true
    }
}

struct CharacterMotionContext: Equatable {
    var isPopoverOpen: Bool
    var isDragging: Bool
    var isContextMenuVisible: Bool
    var isAgentBusy: Bool
    var isHovering: Bool
    var hoverStartedAt: CFTimeInterval?
    var edgeSide: CharacterEdgeSide?
    var hasFreshMessagePrompt: Bool
    var messagePromptStartedAt: CFTimeInterval?
    var stateStartedAt: CFTimeInterval?
}

struct CharacterMotionClipDescriptor: Equatable {
    let kind: CharacterMotionClipKind
    let resourceName: String
    let playbackMode: CharacterMotionPlaybackMode
    let usesFallback: Bool
    let duration: CFTimeInterval?
}

struct CharacterMotionResolution: Equatable {
    let state: CharacterMotionState
    let priority: CharacterMotionPriority
    let isSuppressedByPopover: Bool
    let shouldConsumeHoverTrigger: Bool
    let shouldConsumeMessagePrompt: Bool

    init(
        state: CharacterMotionState,
        isSuppressedByPopover: Bool = false,
        shouldConsumeHoverTrigger: Bool = false,
        shouldConsumeMessagePrompt: Bool = false
    ) {
        self.state = state
        self.priority = state.priority
        self.isSuppressedByPopover = isSuppressedByPopover
        self.shouldConsumeHoverTrigger = shouldConsumeHoverTrigger
        self.shouldConsumeMessagePrompt = shouldConsumeMessagePrompt
    }
}
