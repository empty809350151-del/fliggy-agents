import Foundation

struct MorningDigestContext {
    let now: Date
    let since: Date?
    let recentThreads: [ChatThread]
    let weatherSummary: String?
    let meetingSummaries: [String]
}

struct MorningDigestDraft {
    let bubbleText: String
    let fallbackText: String
    let prompt: String
}

final class MorningDigestComposer {
    func makeDraft(context: MorningDigestContext) -> MorningDigestDraft {
        let fallback = makeFallback(context: context)
        let prompt = makePrompt(context: context)
        return MorningDigestDraft(
            bubbleText: "10点啦，今天我先陪你开工",
            fallbackText: fallback,
            prompt: prompt
        )
    }

    private func makeFallback(context: MorningDigestContext) -> String {
        var sections: [String] = ["10点啦，我先帮你把今天的头开好。"]

        if !context.recentThreads.isEmpty {
            let lines = context.recentThreads.prefix(3).map { thread in
                let preview = thread.messages.last?.text ?? thread.title
                return "• \(thread.title)：\(preview)"
            }
            sections.append("昨晚到现在最值得接着推进的，还是这些：\n" + lines.joined(separator: "\n"))
        } else {
            sections.append("昨晚到现在没有冒出新的重点对话，今天可以直接按你自己的主线推进。")
        }

        if let weatherSummary = context.weatherSummary, !weatherSummary.isEmpty {
            sections.append("天气这边我也顺手看了，\(weatherSummary)。")
        }

        if !context.meetingSummaries.isEmpty {
            sections.append("今天钉钉会议先记这几场：\n" + context.meetingSummaries.prefix(3).map { "• \($0)" }.joined(separator: "\n"))
        } else {
            sections.append("今天我这边暂时没识别到钉钉会议，你可以先按自己的节奏把最重要的那段做掉。")
        }

        sections.append("别一上来就想把今天全打穿，先拿下一件最关键的就很赚了。")
        return sections.joined(separator: "\n\n")
    }

    private func makePrompt(context: MorningDigestContext) -> String {
        let sinceText: String
        if let since = context.since {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.timeZone = Calendar.current.timeZone
            formatter.dateFormat = "M月d日 HH:mm"
            sinceText = formatter.string(from: since)
        } else {
            sinceText = "昨晚"
        }

        let threadSummary = context.recentThreads.prefix(6).map { thread in
            let preview = thread.messages.last?.text ?? thread.title
            return "- \(thread.title)：\(preview)"
        }.joined(separator: "\n")

        let weatherText = context.weatherSummary ?? "无天气数据"
        let meetingsText = context.meetingSummaries.isEmpty
            ? "今天暂无识别到的钉钉会议"
            : context.meetingSummaries.joined(separator: "\n")

        return """
        你是一个桌面助手，要给用户生成一条 10:00 的中文晨报。

        要求：
        - 输出 4 段以内，口吻自然、有人味，像熟悉的同事或搭子，不要像公告。
        - 必须包含：AI咨询整理、天气、今日会议、上班问候。
        - 总长度控制在 140 字以内。
        - 不要使用 Markdown 标题，不要编号，不要官话。
        - 优先写得像“我在陪你开工”，不是“系统播报”。

        时间范围：整理自 \(sinceText) 以来的对话

        AI咨询候选：
        \(threadSummary.isEmpty ? "- 暂无新的重点对话" : threadSummary)

        天气：
        \(weatherText)

        今日会议：
        \(meetingsText)
        """
    }
}
