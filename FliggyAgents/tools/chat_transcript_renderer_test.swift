import AppKit
import Foundation

@main
enum ChatTranscriptRendererTest {
    static func main() {
        let html = ChatTranscriptRenderer.buildHTML(
            messages: [
                AgentMessage(role: .user, text: "How should I restyle this window?"),
                AgentMessage(role: .assistant, text: "Use a calmer surface hierarchy with clearer message separation."),
                AgentMessage(role: .toolUse, text: "BASH rg --files"),
                AgentMessage(role: .toolResult, text: "DONE found 3 files")
            ],
            streamingText: "Streaming reply...",
            theme: .aiChat,
            showsThinking: true
        )

        assert(html.contains("transcript-shell"), "Expected transcript shell wrapper")
        assert(html.contains("message user"), "Expected user message class")
        assert(html.contains("message assistant"), "Expected assistant message class")
        assert(html.contains("message tool"), "Expected tool message class")
        assert(html.contains("thinking-indicator"), "Expected thinking indicator class")
        assert(html.contains("--message-user-bg"), "Expected semantic transcript token")
        assert(html.contains("--composer-bg"), "Expected composer token exposure for shared styling")

        let theme = PopoverTheme.aiChat
        assert(theme.name == "AI Chat", "Expected AI Chat theme to exist")
        assert(theme.titleFormat == TitleFormat.capitalized, "Expected AI Chat title to use capitalized provider naming")

        print("chat_transcript_renderer_test: PASS")
    }
}
