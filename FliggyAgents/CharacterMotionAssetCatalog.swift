import AVFoundation
import Foundation

struct CharacterMotionAssetCatalog {
    private let locomotionResourceName: String
    private let descriptors: [CharacterMotionClipKind: CharacterMotionClipDescriptor]
    private let resourceURLs: [String: URL]
    private let resourceDurations: [String: CFTimeInterval]

    init(videoName: String, bundle: Bundle = .main) {
        let locomotionResourceName = videoName
        let characterBaseName = Self.characterBaseName(from: locomotionResourceName)

        var availableNames = Set<String>()
        var resourceURLs: [String: URL] = [:]
        var resourceDurations: [String: CFTimeInterval] = [:]
        for kind in CharacterMotionClipKind.allCases {
            let name = kind == .locomotionLoop
                ? locomotionResourceName
                : Self.resourceName(for: kind, characterBaseName: characterBaseName)
            if let url = bundle.url(forResource: name, withExtension: "mov") {
                availableNames.insert(name)
                resourceURLs[name] = url
                resourceDurations[name] = Self.duration(for: url)
            }
        }

        self.init(
            locomotionResourceName: locomotionResourceName,
            availableResourceNames: availableNames,
            resourceURLs: resourceURLs,
            resourceDurations: resourceDurations
        )
    }

    init(
        locomotionResourceName: String,
        availableResourceNames: Set<String>,
        resourceDurations: [String: CFTimeInterval] = [:]
    ) {
        self.init(
            locomotionResourceName: locomotionResourceName,
            availableResourceNames: availableResourceNames,
            resourceURLs: [:],
            resourceDurations: resourceDurations
        )
    }

    private init(
        locomotionResourceName: String,
        availableResourceNames: Set<String>,
        resourceURLs: [String: URL],
        resourceDurations: [String: CFTimeInterval]
    ) {
        self.locomotionResourceName = locomotionResourceName
        self.resourceURLs = resourceURLs
        self.resourceDurations = resourceDurations

        let characterBaseName = Self.characterBaseName(from: locomotionResourceName)
        var descriptors: [CharacterMotionClipKind: CharacterMotionClipDescriptor] = [:]

        for kind in CharacterMotionClipKind.allCases {
            if kind == .locomotionLoop {
                descriptors[kind] = CharacterMotionClipDescriptor(
                    kind: kind,
                    resourceName: locomotionResourceName,
                    playbackMode: .loop,
                    usesFallback: false,
                    duration: resourceDurations[locomotionResourceName]
                )
                continue
            }

            let explicitName = Self.resourceName(for: kind, characterBaseName: characterBaseName)
            if availableResourceNames.contains(explicitName) {
                descriptors[kind] = CharacterMotionClipDescriptor(
                    kind: kind,
                    resourceName: explicitName,
                    playbackMode: kind.defaultPlaybackMode,
                    usesFallback: false,
                    duration: resourceDurations[explicitName]
                )
            } else {
                descriptors[kind] = CharacterMotionClipDescriptor(
                    kind: kind,
                    resourceName: locomotionResourceName,
                    playbackMode: .holdFirstFrame,
                    usesFallback: true,
                    duration: nil
                )
            }
        }

        self.descriptors = descriptors
    }

    func descriptor(for kind: CharacterMotionClipKind) -> CharacterMotionClipDescriptor {
        descriptors[kind] ?? CharacterMotionClipDescriptor(
            kind: kind,
            resourceName: locomotionResourceName,
            playbackMode: .holdFirstFrame,
            usesFallback: true,
            duration: nil
        )
    }

    func url(for kind: CharacterMotionClipKind, bundle: Bundle = .main) -> URL? {
        let descriptor = descriptor(for: kind)
        if let cached = resourceURLs[descriptor.resourceName] {
            return cached
        }
        return bundle.url(forResource: descriptor.resourceName, withExtension: "mov")
    }

    static func resourceName(for kind: CharacterMotionClipKind, characterBaseName: String) -> String {
        switch kind {
        case .locomotionLoop:
            return "walk-\(characterBaseName)-01"
        case .hoverOnce:
            return "hover-\(characterBaseName)-01"
        case .dragLoop:
            return "drag-\(characterBaseName)-01"
        case .contextMenuEnterOnce:
            return "context-menu-enter-\(characterBaseName)-01"
        case .contextMenuIdleLoop:
            return "context-menu-idle-\(characterBaseName)-01"
        case .edgeLeftLoop:
            return "edge-left-\(characterBaseName)-01"
        case .edgeRightLoop:
            return "edge-right-\(characterBaseName)-01"
        case .thinkingLoop:
            return "thinking-\(characterBaseName)-01"
        case .messagePromptOnce:
            return "message-prompt-\(characterBaseName)-01"
        }
    }

    static func characterBaseName(from locomotionResourceName: String) -> String {
        var name = locomotionResourceName
        if name.hasSuffix(".mov") {
            name = String(name.dropLast(4))
        }
        if name.hasPrefix("walk-") {
            name.removeFirst("walk-".count)
        }
        if name.hasSuffix("-01") {
            name = String(name.dropLast(3))
        }
        return name
    }

    private static func duration(for url: URL) -> CFTimeInterval {
        let asset = AVURLAsset(url: url)
        let seconds = CMTimeGetSeconds(asset.duration)
        guard seconds.isFinite, seconds > 0 else { return 0 }
        return seconds
    }
}
