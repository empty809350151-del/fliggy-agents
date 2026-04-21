import Foundation

@main
enum ProactivePromptRunnerTest {
    static func main() {
        let unavailableRunner = ProactivePromptRunner(
            availabilityResolver: { _ in false },
            executor: { _, _, completion in
                completion("should not be used")
            }
        )
        let unavailableResult = waitForResult(from: unavailableRunner, fallback: "模板兜底")
        assert(unavailableResult.text == "模板兜底", "Expected fallback text when provider is unavailable")
        assert(unavailableResult.usedFallback, "Expected provider unavailable path to use fallback")

        let emptyRunner = ProactivePromptRunner(
            availabilityResolver: { _ in true },
            executor: { _, _, completion in
                completion("   \n")
            }
        )
        let emptyResult = waitForResult(from: emptyRunner, fallback: "空结果兜底")
        assert(emptyResult.text == "空结果兜底", "Expected fallback when AI returns empty content")
        assert(emptyResult.usedFallback, "Expected empty AI response to use fallback")

        let successRunner = ProactivePromptRunner(
            availabilityResolver: { _ in true },
            executor: { _, _, completion in
                completion("  今天先把最重要的两件事收住。  ")
            }
        )
        let successResult = waitForResult(from: successRunner, fallback: "不该走这里")
        assert(successResult.text == "今天先把最重要的两件事收住。", "Expected generated text to be sanitized")
        assert(!successResult.usedFallback, "Expected successful AI response to skip fallback")

        print("proactive_prompt_runner_test: PASS")
    }

    private static func waitForResult(from runner: ProactivePromptRunner, fallback: String) -> ProactivePromptResult {
        var result: ProactivePromptResult?
        let timeoutDate = Date().addingTimeInterval(2)

        runner.generate(
            prompt: "test prompt",
            provider: .codex,
            fallback: fallback
        ) { value in
            result = value
        }

        while result == nil && Date() < timeoutDate {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }

        guard let result else {
            fatalError("Timed out waiting for proactive prompt result")
        }
        return result
    }
}
