import Foundation

@main
enum ProjectWithoutSparkleTest {
    static func main() throws {
        let projectPath = URL(fileURLWithPath: "fliggy-agents/build/src/fliggy-agents.xcodeproj/project.pbxproj")
        let project = try String(contentsOf: projectPath, encoding: .utf8)

        let forbiddenFragments = [
            "Sparkle in Frameworks",
            "XCRemoteSwiftPackageReference \"Sparkle\"",
            "productName = Sparkle;"
        ]

        let offenders = forbiddenFragments.filter { project.contains($0) }
        guard offenders.isEmpty else {
            fputs("project_without_sparkle_test: FAIL\n", stderr)
            for offender in offenders {
                fputs("Found forbidden Sparkle reference: \(offender)\n", stderr)
            }
            exit(1)
        }

        print("project_without_sparkle_test: PASS")
    }
}
