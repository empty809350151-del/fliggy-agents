import Foundation

@main
enum CharacterResourceManifestTest {
    static func main() {
        let toolsURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
        let lilAgentsDirectory = toolsURL
            .deletingLastPathComponent()
        let projectFileURL = lilAgentsDirectory
            .deletingLastPathComponent()
            .appendingPathComponent("fliggy-agents.xcodeproj")
            .appendingPathComponent("project.pbxproj")

        let expectedVideos = [
            "walk-bruce-01.mov",
            "walk-jazz-01.mov",
            "walk-fliggy-01.mov",
            "walk-labubu-01.mov"
        ]
        let optionalReferencedVideos = [
            "context-menu-enter-fliggy-01.mov"
        ]

        for video in expectedVideos {
            let sourceURL = lilAgentsDirectory.appendingPathComponent(video)
            expect(
                FileManager.default.fileExists(atPath: sourceURL.path),
                "missing source asset \(video)"
            )
        }

        let projectText = read(projectFileURL)
        for video in expectedVideos {
            expect(
                projectText.contains(video),
                "project.pbxproj does not reference \(video)"
            )
            expect(
                projectText.contains("\(video) in Resources"),
                "\(video) is not included in the Resources build phase"
            )
        }

        for video in optionalReferencedVideos {
            let sourceURL = lilAgentsDirectory.appendingPathComponent(video)
            guard FileManager.default.fileExists(atPath: sourceURL.path) else { continue }

            expect(
                projectText.contains(video),
                "project.pbxproj does not reference optional asset \(video)"
            )
            expect(
                projectText.contains("\(video) in Resources"),
                "optional asset \(video) is not included in the Resources build phase"
            )
        }

        print("character_resource_manifest_test: PASS")
    }

    private static func read(_ url: URL) -> String {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            fail("could not read \(url.path)")
        }
        return text
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fail(message)
        }
    }

    private static func fail(_ message: String) -> Never {
        fputs("character_resource_manifest_test: FAIL - \(message)\n", stderr)
        exit(1)
    }
}
