import AppKit
import PDFKit
import UniformTypeIdentifiers
import WebKit

class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

enum ChatTranscriptRenderer {
    static func buildHTML(messages: [AgentMessage], streamingText: String?, theme t: PopoverTheme, showsThinking: Bool) -> String {
        buildDocumentHTML(
            transcriptHTML: buildTranscriptHTML(
                messages: messages,
                streamingText: streamingText,
                theme: t,
                showsThinking: showsThinking
            ),
            theme: t
        )
    }

    static func buildDocumentHTML(transcriptHTML: String, theme t: PopoverTheme) -> String {
        """
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        :root {
          --text: \(cssColor(t.textPrimary));
          --text-dim: \(cssColor(t.textDim));
          --accent: \(cssColor(t.accentColor));
          --error: \(cssColor(t.errorColor));
          --success: \(cssColor(t.successColor));
          --surface-primary: \(cssColor(t.surfacePrimary));
          --surface-secondary: \(cssColor(t.surfaceSecondary));
          --surface-tertiary: \(cssColor(t.surfaceTertiary));
          --message-user-bg: \(cssColor(t.messageUserBg));
          --message-user-border: \(cssColor(t.messageUserBorder));
          --message-user-text: \(cssColor(t.messageUserText));
          --message-assistant-bg: \(cssColor(t.messageAssistantBg));
          --message-assistant-border: \(cssColor(t.messageAssistantBorder));
          --message-assistant-text: \(cssColor(t.messageAssistantText));
          --message-tool-bg: \(cssColor(t.messageToolBg));
          --message-tool-border: \(cssColor(t.messageToolBorder));
          --message-tool-text: \(cssColor(t.messageToolText));
          --message-error-bg: \(cssColor(t.messageErrorBg));
          --message-error-border: \(cssColor(t.messageErrorBorder));
          --message-error-text: \(cssColor(t.messageErrorText));
          --code-bg: \(cssColor(t.codeBlockBg));
          --code-inline-bg: \(cssColor(t.codeInlineBg));
          --quote-bar: \(cssColor(t.quoteBarColor));
          --table-border: \(cssColor(t.tableBorderColor));
          --table-header-bg: \(cssColor(t.tableHeaderBg));
          --composer-bg: \(cssColor(t.composerBg));
        }

        * { box-sizing: border-box; }
        html, body { margin: 0; background: transparent; }
        body {
          padding: 0 0 18px;
          color: var(--text);
          font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'PingFang SC', sans-serif;
          font-size: \(max(Int(round(t.font.pointSize)), 13))px;
          line-height: 1.6;
          user-select: text;
          -webkit-user-select: text;
        }

        .transcript-shell {
          display: flex;
          flex-direction: column;
          gap: 12px;
          padding: 8px 2px 2px;
        }

        .message {
          display: flex;
          width: 100%;
        }

        .message.user {
          justify-content: flex-end;
        }

        .message-inner {
          max-width: min(100%, 720px);
          width: fit-content;
          border-radius: 18px;
          border: 1px solid transparent;
          padding: 12px 14px;
          box-shadow: 0 1px 2px rgba(15, 23, 42, 0.03);
        }

        .message.user .message-inner {
          max-width: min(86%, 560px);
          background: var(--message-user-bg);
          border-color: var(--message-user-border);
          color: var(--message-user-text);
        }

        .message.assistant .message-inner {
          width: min(100%, 100%);
          background: var(--message-assistant-bg);
          border-color: var(--message-assistant-border);
          color: var(--message-assistant-text);
        }

        .message.tool .message-inner {
          background: var(--message-tool-bg);
          border-color: var(--message-tool-border);
          color: var(--message-tool-text);
          width: fit-content;
        }

        .message.error .message-inner {
          background: var(--message-error-bg);
          border-color: var(--message-error-border);
          color: var(--message-error-text);
          width: min(100%, 100%);
        }

        .message.streaming .message-inner {
          border-style: dashed;
        }

        .message-label {
          display: inline-flex;
          align-items: center;
          gap: 6px;
          margin-bottom: 8px;
          font-size: 11px;
          font-weight: 700;
          letter-spacing: 0.04em;
          text-transform: uppercase;
          color: var(--text-dim);
        }

        .message-label:empty {
          display: none;
          margin-bottom: 0;
        }

        .tool-pill {
          display: inline-flex;
          align-items: center;
          padding: 3px 8px;
          border-radius: 999px;
          background: rgba(127, 127, 127, 0.12);
          font-size: 11px;
          font-weight: 700;
        }

        .message-content > :first-child { margin-top: 0; }
        .message-content > :last-child { margin-bottom: 0; }
        .message-content p { margin: 0 0 10px; }
        .message-content h1, .message-content h2, .message-content h3,
        .message-content h4, .message-content h5, .message-content h6 {
          margin: 0 0 10px;
          line-height: 1.3;
          color: var(--text);
        }
        .message-content ul, .message-content ol {
          margin: 0 0 10px 20px;
          padding: 0;
        }
        .message-content li { margin: 4px 0; }
        .message-content blockquote {
          margin: 0 0 10px;
          padding: 4px 0 4px 14px;
          border-left: 3px solid var(--quote-bar);
          color: var(--text-dim);
          background: var(--surface-secondary);
          border-radius: 0 10px 10px 0;
        }
        .message-content pre {
          margin: 0 0 10px;
          padding: 12px 14px;
          background: var(--code-bg);
          border-radius: 14px;
          overflow-x: auto;
          white-space: pre-wrap;
          word-break: break-word;
        }
        .message-content code {
          padding: 1px 6px;
          border-radius: 8px;
          background: var(--code-inline-bg);
          font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
          font-size: 0.94em;
        }
        .message-content pre code {
          padding: 0;
          background: transparent;
        }
        .message-content hr {
          border: 0;
          border-top: 1px solid var(--table-border);
          margin: 12px 0;
        }
        .message-content table {
          width: 100%;
          border-collapse: collapse;
          margin: 0 0 10px;
        }
        .message-content th, .message-content td {
          border: 1px solid var(--table-border);
          padding: 10px 12px;
          text-align: left;
          vertical-align: top;
        }
        .message-content th {
          background: var(--table-header-bg);
          font-weight: 700;
        }
        .message-content a {
          color: var(--accent);
          text-decoration: underline;
          text-underline-offset: 2px;
        }

        .empty-state {
          display: flex;
          justify-content: flex-start;
        }

        .empty-card {
          width: min(100%, 100%);
          padding: 18px 18px 16px;
          border-radius: 20px;
          background: var(--message-assistant-bg);
          border: 1px solid var(--message-assistant-border);
          box-shadow: 0 1px 2px rgba(15, 23, 42, 0.03);
        }

        .empty-title {
          margin: 0 0 8px;
          font-size: 15px;
          font-weight: 700;
          color: var(--text);
        }

        .empty-body {
          margin: 0;
          color: var(--text-dim);
        }

        .typing-dots {
          display: inline-flex;
          gap: 4px;
          margin-left: 8px;
          vertical-align: middle;
        }
        .typing-dots i {
          width: 5px;
          height: 5px;
          border-radius: 999px;
          background: currentColor;
          opacity: 0.35;
          animation: pulse 1.2s infinite ease-in-out;
        }
        .typing-dots i:nth-child(2) { animation-delay: 0.15s; }
        .typing-dots i:nth-child(3) { animation-delay: 0.3s; }

        @keyframes pulse {
          0%, 80%, 100% { transform: translateY(0); opacity: 0.25; }
          40% { transform: translateY(-2px); opacity: 0.7; }
        }
        </style>
        </head>
        <body>
          <div id="transcript-root">\(transcriptHTML)</div>
          <script>
            window.__lilAgentsIsNearBottom = function() {
              return window.innerHeight + window.scrollY >= document.documentElement.scrollHeight - 28;
            };
            window.__lilAgentsTranscriptUpdate = function(html, forceBottom) {
              var root = document.getElementById('transcript-root');
              if (!root) return;
              var shouldStick = forceBottom || window.__lilAgentsIsNearBottom();
              root.innerHTML = html;
              if (shouldStick) {
                window.scrollTo({ top: document.documentElement.scrollHeight, behavior: 'auto' });
              }
            };
            window.__lilAgentsScrollToTop = function() {
              window.scrollTo({ top: 0, behavior: 'auto' });
            };
            window.__lilAgentsScrollToBottom = function() {
              window.scrollTo({ top: document.documentElement.scrollHeight, behavior: 'auto' });
            };
          </script>
        </body>
        </html>
        """
    }

    static func buildTranscriptHTML(messages: [AgentMessage], streamingText: String?, theme t: PopoverTheme, showsThinking: Bool) -> String {
        var body = "<div class='transcript-shell'>"
        if messages.isEmpty, (streamingText?.isEmpty ?? true), !showsThinking {
            body += """
            <div class='empty-state'>
              <div class='empty-card'>
                <p class='empty-title'>Hi, 我在这儿。</p>
                <p class='empty-body'>直接告诉我你现在想继续什么，我会按这个窗口的上下文接着做。</p>
              </div>
            </div>
            """
        }
        for msg in messages {
            body += renderMessageHTML(msg, theme: t)
        }
        if showsThinking {
            body += """
            <div class='message assistant streaming thinking-indicator'>
              <div class='message-inner'>
                <div class='message-content'>Thinking<span class='typing-dots'><i></i><i></i><i></i></span></div>
              </div>
            </div>
            """
        }
        if let streamingText, !streamingText.isEmpty {
            body += renderMessageHTML(AgentMessage(role: .assistant, text: streamingText), theme: t, isStreaming: true)
        }
        body += "</div>"
        return body
    }

    private static func renderMessageHTML(_ msg: AgentMessage, theme t: PopoverTheme, isStreaming: Bool = false) -> String {
        switch msg.role {
        case .user:
            return """
            <div class='message user'>
              <div class='message-inner'>
                <div class='message-content'>\(plainTextToHTML(msg.text))</div>
              </div>
            </div>
            """
        case .assistant:
            let streamingClass = isStreaming ? " streaming" : ""
            return """
            <div class='message assistant\(streamingClass)'>
              <div class='message-inner'>
                <div class='message-content'>\(markdownToHTML(msg.text))</div>
              </div>
            </div>
            """
        case .error:
            return """
            <div class='message error'>
              <div class='message-inner'>
                <div class='message-label'>Issue</div>
                <div class='message-content'>\(plainTextToHTML(msg.text))</div>
              </div>
            </div>
            """
        case .toolUse:
            return """
            <div class='message tool'>
              <div class='message-inner'>
                <div class='message-label'><span class='tool-pill'>Tool</span></div>
                <div class='message-content'>\(plainTextToHTML(msg.text))</div>
              </div>
            </div>
            """
        case .toolResult:
            let label = msg.text.uppercased().hasPrefix("FAIL") ? "Tool Error" : "Tool Result"
            return """
            <div class='message tool'>
              <div class='message-inner'>
                <div class='message-label'><span class='tool-pill'>\(label)</span></div>
                <div class='message-content'>\(plainTextToHTML(msg.text))</div>
              </div>
            </div>
            """
        }
    }


    private static func plainTextToHTML(_ text: String) -> String {
        escapeHTML(text).replacingOccurrences(of: "\n", with: "<br/>")
    }

    private static func markdownToHTML(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        var html = ""
        var inCode = false
        var codeBuffer: [String] = []
        var tableLines: [String] = []
        var paragraph: [String] = []

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            let joined = paragraph.joined(separator: "<br/>")
            html += "<p>\(inlineMarkdownToHTML(joined))</p>"
            paragraph.removeAll()
        }

        func flushCode() {
            guard !codeBuffer.isEmpty else { return }
            html += "<pre><code>\(escapeHTML(codeBuffer.joined(separator: "\n")))</code></pre>"
            codeBuffer.removeAll()
        }

        func flushTable() {
            guard !tableLines.isEmpty else { return }
            let rows = tableLines.map(parseTableCells).filter { !$0.isEmpty }
            let isSeparator: ([String]) -> Bool = { row in
                !row.isEmpty && row.allSatisfy { cell in
                    let trimmed = cell.replacingOccurrences(of: ":", with: "").replacingOccurrences(of: "-", with: "")
                    return trimmed.isEmpty
                }
            }
            let contentRows = rows.filter { !isSeparator($0) }
            guard !contentRows.isEmpty else {
                tableLines.removeAll()
                return
            }

            let header = contentRows.first ?? []
            let body = contentRows.dropFirst()
            html += "<table><thead><tr>"
            html += header.map { "<th>\(inlineMarkdownToHTML(escapeHTML($0)))</th>" }.joined()
            html += "</tr></thead><tbody>"
            for row in body {
                html += "<tr>" + row.map { "<td>\(inlineMarkdownToHTML(escapeHTML($0)))</td>" }.joined() + "</tr>"
            }
            html += "</tbody></table>"
            tableLines.removeAll()
        }

        for line in lines {
            if line.hasPrefix("```") {
                flushParagraph()
                flushTable()
                if inCode {
                    flushCode()
                    inCode = false
                } else {
                    inCode = true
                }
                continue
            }

            if inCode {
                codeBuffer.append(line)
                continue
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                flushParagraph()
                flushTable()
                continue
            }

            if isTableRow(trimmed) {
                flushParagraph()
                tableLines.append(trimmed)
                continue
            } else if !tableLines.isEmpty {
                flushTable()
            }

            if let heading = headingLevel(for: trimmed) {
                flushParagraph()
                html += "<h\(heading.level)>\(inlineMarkdownToHTML(escapeHTML(heading.text)))</h\(heading.level)>"
            } else if isHorizontalRule(trimmed) {
                flushParagraph()
                html += "<hr/>"
            } else if let quote = blockquoteContent(for: line) {
                flushParagraph()
                html += "<blockquote>\(inlineMarkdownToHTML(escapeHTML(quote)))</blockquote>"
            } else if let ordered = orderedListContent(for: line) {
                flushParagraph()
                html += "<ol><li>\(inlineMarkdownToHTML(escapeHTML(ordered.text)))</li></ol>"
            } else if let unordered = unorderedListContent(for: line) {
                flushParagraph()
                html += "<ul><li>\(inlineMarkdownToHTML(escapeHTML(unordered)))</li></ul>"
            } else if let task = taskListContent(for: line) {
                flushParagraph()
                let box = task.checked ? "☑" : "☐"
                html += "<ul><li>\(box) \(inlineMarkdownToHTML(escapeHTML(task.text)))</li></ul>"
            } else {
                paragraph.append(escapeHTML(line))
            }
        }

        flushParagraph()
        flushTable()
        if inCode { flushCode() }
        return html
    }

    private static func inlineMarkdownToHTML(_ text: String) -> String {
        var out = text
        out = out.replacingOccurrences(of: "`([^`]+)`", with: "<code>$1</code>", options: .regularExpression)
        out = out.replacingOccurrences(of: "\\*\\*([^*]+)\\*\\*", with: "<strong>$1</strong>", options: .regularExpression)
        out = out.replacingOccurrences(of: "\\*([^*]+)\\*", with: "<em>$1</em>", options: .regularExpression)
        out = out.replacingOccurrences(of: "~~([^~]+)~~", with: "<del>$1</del>", options: .regularExpression)
        out = out.replacingOccurrences(of: "\\[([^\\]]+)\\]\\(([^\\)]+)\\)", with: "<a href=\"$2\">$1</a>", options: .regularExpression)
        return out
    }

    private static func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func cssColor(_ color: NSColor) -> String {
        let resolved = color.usingColorSpace(.deviceRGB) ?? color
        return String(
            format: "rgba(%d,%d,%d,%.3f)",
            Int(round(resolved.redComponent * 255)),
            Int(round(resolved.greenComponent * 255)),
            Int(round(resolved.blueComponent * 255)),
            resolved.alphaComponent
        )
    }


static func themeSignature(_ theme: PopoverTheme) -> String {
    [
        cssColor(theme.textPrimary),
        cssColor(theme.textDim),
        cssColor(theme.accentColor),
        cssColor(theme.messageUserBg),
        cssColor(theme.messageAssistantBg),
        cssColor(theme.messageToolBg),
        cssColor(theme.messageErrorBg),
        cssColor(theme.codeBlockBg),
        cssColor(theme.tableBorderColor),
        String(max(Int(round(theme.font.pointSize)), 13))
    ].joined(separator: "|")
}
    private static func parseTableCells(_ line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") { trimmed.removeFirst() }
        if trimmed.hasSuffix("|") { trimmed.removeLast() }
        return trimmed.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func isTableRow(_ line: String) -> Bool {
        line.contains("|") && parseTableCells(line).count >= 2
    }

    private static func headingLevel(for line: String) -> (level: Int, text: String)? {
        let hashes = line.prefix { $0 == "#" }
        guard !hashes.isEmpty, hashes.count <= 6 else { return nil }
        let remainder = line.dropFirst(hashes.count).trimmingCharacters(in: .whitespaces)
        guard !remainder.isEmpty else { return nil }
        return (hashes.count, remainder)
    }

    private static func blockquoteContent(for line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix(">") else { return nil }
        return trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
    }

    private static func orderedListContent(for line: String) -> (text: String, index: Int)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2, let number = Int(parts[0]) else { return nil }
        let content = parts[1].trimmingCharacters(in: .whitespaces)
        return content.isEmpty ? nil : (content, number)
    }

    private static func unorderedListContent(for line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let markers = ["- ", "* ", "+ "]
        guard let marker = markers.first(where: { trimmed.hasPrefix($0) }) else { return nil }
        let content = String(trimmed.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
        return content.isEmpty ? nil : content
    }

    private static func taskListContent(for line: String) -> (text: String, checked: Bool)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("- [ ] ") || trimmed.hasPrefix("* [ ] ") {
            return (String(trimmed.dropFirst(6)), false)
        }
        if trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") || trimmed.hasPrefix("* [x] ") || trimmed.hasPrefix("* [X] ") {
            return (String(trimmed.dropFirst(6)), true)
        }
        return nil
    }

    private static func isHorizontalRule(_ line: String) -> Bool {
        let reduced = line.replacingOccurrences(of: " ", with: "")
        return reduced == "---" || reduced == "***"
    }
}

class HistoryRowButton: NSButton {
    override func awakeFromNib() {
        super.awakeFromNib()
        isBordered = false
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override var isHighlighted: Bool {
        get { false }
        set {}
    }
}

final class HistoryRowSelectionButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override var isHighlighted: Bool {
        get { false }
        set {}
    }
}

final class ManualHistoryListView: FlippedView {
    private(set) var arrangedSubviews: [NSView] = []
    var spacing: CGFloat = 6
    var bottomInset: CGFloat = 8

    func addArrangedSubview(_ view: NSView) {
        arrangedSubviews.append(view)
        addSubview(view)
    }

    func removeArrangedSubview(_ view: NSView) {
        arrangedSubviews.removeAll { $0 === view }
    }

    func relayout(width: CGFloat) {
        var nextY: CGFloat = 0
        for view in arrangedSubviews {
            let preferredHeight = measuredHeight(for: view)
            view.frame = NSRect(x: 0, y: nextY, width: width, height: preferredHeight)
            nextY += preferredHeight + spacing
        }

        if !arrangedSubviews.isEmpty {
            nextY -= spacing
        }

        frame.size = NSSize(width: width, height: nextY + bottomInset)
    }

    private func measuredHeight(for view: NSView) -> CGFloat {
        let fittingHeight = view.fittingSize.height
        if fittingHeight > 0 {
            return fittingHeight
        }
        if view.frame.height > 0 {
            return view.frame.height
        }
        return 24
    }
}

final class HoverCursorButton: NSButton {
    private var tracking: NSTrackingArea?
    private var isCursorPushed = false
    var normalBackgroundColor: NSColor = .clear
    var hoverBackgroundColor: NSColor = .clear
    var pressedBackgroundColor: NSColor?
    var hoverCornerRadius: CGFloat = 0
    private var isHovering = false

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking {
            removeTrackingArea(tracking)
        }
        let options: NSTrackingArea.Options = [.activeAlways, .inVisibleRect, .cursorUpdate, .mouseEnteredAndExited]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        tracking = area
    }

    override func cursorUpdate(with event: NSEvent) {
        applyPointingCursor()
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isHovering = true
        applyPointingCursor()
        applyBackgroundState()
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isHovering = false
        restoreCursorIfNeeded()
        applyBackgroundState()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            restoreCursorIfNeeded()
        }
        applyBackgroundState()
    }

    override var isHighlighted: Bool {
        didSet {
            applyBackgroundState()
        }
    }

    func updateCursorIfMouseInside() {
        guard let window else { return }
        let mouseInWindow = window.mouseLocationOutsideOfEventStream
        let mouseInLocal = convert(mouseInWindow, from: nil)
        if bounds.contains(mouseInLocal), !isHidden, alphaValue > 0.01 {
            applyPointingCursor()
        } else {
            restoreCursorIfNeeded()
        }
    }

    private func applyBackgroundState() {
        guard wantsLayer || layer != nil else { return }
        wantsLayer = true
        layer?.cornerRadius = hoverCornerRadius
        let fill: NSColor
        if isHighlighted {
            fill = pressedBackgroundColor ?? hoverBackgroundColor
        } else if isHovering {
            fill = hoverBackgroundColor
        } else {
            fill = normalBackgroundColor
        }
        layer?.backgroundColor = fill.cgColor
    }

    private func applyPointingCursor() {
        if !isCursorPushed {
            NSCursor.pointingHand.push()
            isCursorPushed = true
        } else {
            NSCursor.pointingHand.set()
        }
    }

    private func restoreCursorIfNeeded() {
        guard isCursorPushed else { return }
        NSCursor.pop()
        isCursorPushed = false
    }
}

final class HistoryRowView: FlippedView {
    let threadID: UUID
    let selectionButton: HistoryRowSelectionButton
    let titleButton: HistoryRowButton
    let deleteButton: HoverCursorButton
    let metadataLabel: NSTextField
    let badgeLabel: NSTextField
    var onDelete: ((HistoryRowView) -> Void)?
    var onSelect: ((HistoryRowView) -> Void)?
    private var tracking: NSTrackingArea?
    private var isDeleting = false
    private var isHovering = false
    private let theme: PopoverTheme
    private let isSelected: Bool
    private let isProactiveThread: Bool

    init(thread: ChatThread, width: CGFloat, theme: PopoverTheme, isSelected: Bool, target: AnyObject?, action: Selector?) {
        self.threadID = thread.id
        self.selectionButton = HistoryRowSelectionButton(frame: .zero)
        self.titleButton = HistoryRowButton(title: thread.title, target: target, action: action)
        self.deleteButton = HoverCursorButton(frame: .zero)
        self.metadataLabel = NSTextField(labelWithString: HistoryRowView.metadataText(for: thread))
        self.badgeLabel = NSTextField(labelWithString: thread.title == ChatHistoryStore.proactiveThreadTitle ? "提醒" : "")
        self.theme = theme
        self.isSelected = isSelected
        self.isProactiveThread = thread.title == ChatHistoryStore.proactiveThreadTitle
        let rowHeight: CGFloat = isProactiveThread ? 56 : 50
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: rowHeight))
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.borderWidth = 1
        applyTheme(isHovering: false)

        selectionButton.title = ""
        selectionButton.isBordered = false
        selectionButton.bezelStyle = .regularSquare
        selectionButton.target = self
        selectionButton.action = #selector(selectTapped)
        addSubview(selectionButton)

        titleButton.isBordered = false
        titleButton.wantsLayer = true
        titleButton.layer?.backgroundColor = NSColor.clear.cgColor
        titleButton.alignment = .left
        titleButton.font = isProactiveThread ? theme.fontBold : theme.font
        titleButton.lineBreakMode = .byTruncatingTail
        titleButton.identifier = NSUserInterfaceItemIdentifier(thread.id.uuidString)
        addSubview(titleButton)

        metadataLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        metadataLabel.textColor = theme.historyMetaText
        metadataLabel.lineBreakMode = .byTruncatingTail
        addSubview(metadataLabel)

        badgeLabel.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        badgeLabel.alignment = .center
        badgeLabel.wantsLayer = true
        badgeLabel.layer?.cornerRadius = 8
        badgeLabel.layer?.masksToBounds = true
        badgeLabel.textColor = theme.historyBadgeText
        badgeLabel.backgroundColor = theme.historyBadgeBg
        badgeLabel.isHidden = !isProactiveThread
        addSubview(badgeLabel)

        deleteButton.title = ""
        let symbolConfig = NSImage.SymbolConfiguration(pointSize: 10, weight: .medium)
        deleteButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Delete chat")?.withSymbolConfiguration(symbolConfig)
        deleteButton.imagePosition = .imageOnly
        deleteButton.imageScaling = .scaleProportionallyDown
        deleteButton.isBordered = false
        deleteButton.bezelStyle = .inline
        deleteButton.contentTintColor = theme.historyMetaText
        deleteButton.wantsLayer = true
        deleteButton.normalBackgroundColor = .clear
        deleteButton.hoverBackgroundColor = theme.titleIconHoverBg
        deleteButton.pressedBackgroundColor = theme.titleIconHoverBg.withAlphaComponent(0.8)
        deleteButton.hoverCornerRadius = 11
        deleteButton.layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        deleteButton.layer?.opacity = 0
        deleteButton.layer?.transform = CATransform3DMakeScale(0.9, 0.9, 1)
        deleteButton.alphaValue = 0
        deleteButton.isEnabled = false
        deleteButton.isHidden = true
        deleteButton.target = self
        deleteButton.action = #selector(deleteTapped)
        addSubview(deleteButton)

        updateLayout()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        updateLayout()
        syncHoverStateWithMouseLocation()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking {
            removeTrackingArea(tracking)
        }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways, .inVisibleRect, .enabledDuringMouseDrag]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        tracking = area
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        setHovering(true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        setHovering(false)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        syncHoverStateWithMouseLocation()
    }

    @objc private func deleteTapped() {
        onDelete?(self)
    }

    func hitTarget(at point: NSPoint) -> HistoryRowHitTarget {
        HistoryRowHitTargetResolver.resolve(
            point: point,
            bounds: bounds,
            deleteButtonFrame: deleteButton.frame,
            deleteButtonIsInteractive: isDeleteButtonInteractive
        )
    }

    func triggerSelectionFromContainer() {
        selectTapped()
    }

    @objc private func selectTapped() {
        guard !isDeleting else { return }
        NSLog("HistoryRowView.selectTapped threadID=%@", threadID.uuidString)
        onSelect?(self)
    }

    func animateDeletion(completion: @escaping () -> Void) {
        guard !isDeleting else { return }
        isDeleting = true
        deleteButton.isEnabled = false
        deleteButton.isHidden = false
        deleteButton.updateCursorIfMouseInside()

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.24
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.allowsImplicitAnimation = true
            animator().alphaValue = 0
            layer?.animateScale(to: 0.98, duration: context.duration)
        }, completionHandler: completion)
    }

    private func setDeleteButtonVisible(_ visible: Bool) {
        guard !isDeleting else { return }
        if visible {
            deleteButton.isHidden = false
        }
        deleteButton.isEnabled = visible
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = visible ? 0.18 : 0.14
            context.timingFunction = CAMediaTimingFunction(name: visible ? .easeOut : .easeIn)
            deleteButton.animator().alphaValue = visible ? 1 : 0
            deleteButton.layer?.animateOpacity(to: visible ? 1 : 0, duration: context.duration)
            deleteButton.layer?.animateScale(to: visible ? 1.0 : 0.9, duration: context.duration)
        }, completionHandler: { [weak self] in
            if !visible {
                self?.deleteButton.isHidden = true
            }
            self?.deleteButton.updateCursorIfMouseInside()
        })
        deleteButton.updateCursorIfMouseInside()
    }

    private func setHovering(_ hovering: Bool) {
        guard isHovering != hovering else { return }
        isHovering = hovering
        applyTheme(isHovering: hovering)
        setDeleteButtonVisible(hovering)
    }

    func refreshHoverState() {
        syncHoverStateWithMouseLocation()
    }

    func clearHoverState() {
        setHovering(false)
    }

    private func syncHoverStateWithMouseLocation() {
        guard let window, !isHidden, alphaValue > 0.01 else {
            setHovering(false)
            return
        }

        let mouseOnScreen = NSEvent.mouseLocation
        let mouseInWindow = window.convertPoint(fromScreen: mouseOnScreen)
        let mouseInLocal = convert(mouseInWindow, from: nil)
        setHovering(bounds.contains(mouseInLocal))
    }

    private func updateLayout() {
        let horizontalPadding: CGFloat = 12
        let deleteHitSize: CGFloat = 30
        let deleteRightInset: CGFloat = 6
        selectionButton.frame = bounds
        deleteButton.frame = NSRect(
            x: bounds.width - deleteRightInset - deleteHitSize,
            y: round((bounds.height - deleteHitSize) / 2),
            width: deleteHitSize,
            height: deleteHitSize
        )

        let badgeWidth: CGFloat = isProactiveThread ? 34 : 0
        let badgeX = deleteButton.frame.minX - badgeWidth - 8
        badgeLabel.frame = NSRect(x: badgeX, y: 11, width: badgeWidth, height: 16)

        let titleWidth = max(40, badgeX - horizontalPadding - 8)
        titleButton.frame = NSRect(x: horizontalPadding, y: isProactiveThread ? 7 : 8, width: titleWidth, height: 18)
        metadataLabel.frame = NSRect(x: horizontalPadding, y: 28, width: titleWidth, height: 15)
        metadataLabel.isHidden = !isProactiveThread && metadataLabel.stringValue.isEmpty
        titleButton.autoresizingMask = [.width]
    }

    private var isDeleteButtonInteractive: Bool {
        !deleteButton.isHidden && deleteButton.alphaValue > 0.01 && deleteButton.isEnabled
    }

    private func applyTheme(isHovering: Bool) {
        let background: NSColor
        let border: NSColor
        if isSelected {
            background = theme.historyRowSelectedBg
            border = theme.historyRowSelectedBorder
        } else if isHovering {
            background = theme.historyRowHoverBg
            border = theme.historyRowBorder.withAlphaComponent(0.25)
        } else {
            background = theme.historyRowBg
            border = theme.historyRowBorder
        }

        layer?.backgroundColor = background.cgColor
        layer?.borderColor = border.cgColor
        updateTitleAppearance()
        metadataLabel.textColor = theme.historyMetaText
        badgeLabel.textColor = theme.historyBadgeText
        badgeLabel.backgroundColor = theme.historyBadgeBg
    }

    private func updateTitleAppearance() {
        let color = isSelected ? theme.historyRowSelectedText : theme.historyRowText
        let font = isProactiveThread ? theme.fontBold : theme.font
        titleButton.attributedTitle = NSAttributedString(
            string: titleButton.title,
            attributes: [
                .font: font,
                .foregroundColor: color
            ]
        )
    }

    private static func metadataText(for thread: ChatThread) -> String {
        if thread.title == ChatHistoryStore.proactiveThreadTitle {
            return "系统与主动提醒"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: thread.updatedAt, relativeTo: Date())
    }
}


private extension CALayer {
    func animateOpacity(to value: Float, duration: TimeInterval) {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = presentation()?.opacity ?? opacity
        animation.toValue = value
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        opacity = value
        add(animation, forKey: "historyDeleteOpacity")
    }

    func animateScale(to value: CGFloat, duration: TimeInterval) {
        let animation = CABasicAnimation(keyPath: "transform")
        animation.fromValue = presentation()?.transform ?? transform
        animation.toValue = CATransform3DMakeScale(value, value, 1)
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        transform = CATransform3DMakeScale(value, value, 1)
        add(animation, forKey: "historyDeleteScale")
    }
}

class PaddedTextFieldCell: NSTextFieldCell {
    private let inset = NSSize(width: 8, height: 2)
    var fieldBackgroundColor: NSColor?
    var fieldCornerRadius: CGFloat = 4

    override var focusRingType: NSFocusRingType {
        get { .none }
        set {}
    }

    override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
        if let bg = fieldBackgroundColor {
            let path = NSBezierPath(roundedRect: cellFrame, xRadius: fieldCornerRadius, yRadius: fieldCornerRadius)
            bg.setFill()
            path.fill()
        }
        drawInterior(withFrame: cellFrame, in: controlView)
    }

    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        let base = super.drawingRect(forBounds: rect)
        return base.insetBy(dx: inset.width, dy: inset.height)
    }

    private func configureEditor(_ textObj: NSText) {
        if let color = textColor {
            textObj.textColor = color
        }
        if let tv = textObj as? NSTextView {
            tv.insertionPointColor = textColor ?? .textColor
            tv.drawsBackground = false
            tv.backgroundColor = .clear
        }
        textObj.font = font
    }

    override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
        configureEditor(textObj)
        super.edit(withFrame: rect.insetBy(dx: inset.width, dy: inset.height), in: controlView, editor: textObj, delegate: delegate, event: event)
    }

    override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        configureEditor(textObj)
        super.select(withFrame: rect.insetBy(dx: inset.width, dy: inset.height), in: controlView, editor: textObj, delegate: delegate, start: selStart, length: selLength)
    }
}

class AttachmentAwareTextField: NSTextField {
    var onPasteAttachments: (([URL]) -> Bool)?

    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(bounds, cursor: .iBeam)
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.iBeam.set()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let isPasteShortcut = event.type == .keyDown
            && event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command)
            && event.charactersIgnoringModifiers?.lowercased() == "v"
        if isPasteShortcut,
           let urls = Self.readAttachmentURLsFromPasteboard(),
           !urls.isEmpty {
            if onPasteAttachments?(urls) == true {
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }

    private static func readAttachmentURLsFromPasteboard() -> [URL]? {
        let pasteboard = NSPasteboard.general

        let classes: [AnyClass] = [NSURL.self]
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        if let fileURLs = pasteboard.readObjects(forClasses: classes, options: options) as? [URL],
           !fileURLs.isEmpty {
            return fileURLs.filter { $0.isFileURL }
        }

        guard let image = NSImage(pasteboard: pasteboard),
              let url = writePastedImageToTemporaryFile(image) else {
            return nil
        }
        return [url]
    }

    private static func writePastedImageToTemporaryFile(_ image: NSImage) -> URL? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }

        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("fliggy-agents-pasted-images", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let filename = "pasted-image-\(UUID().uuidString).png"
        let fileURL = folder.appendingPathComponent(filename)
        do {
            try pngData.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            return nil
        }
    }
}

final class ChatTextView: NSTextView {
    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(bounds, cursor: .arrow)
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.arrow.set()
    }
}

class AttachmentChipView: NSView {
    enum Style {
        case file
        case image
        case skill
    }

    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let removeButton = NSButton()
    private let attachment: PendingAttachment
    private let onRemove: (PendingAttachment) -> Void
    private let chipHeight: CGFloat = 36
    private let style: Style
    private let theme: PopoverTheme

    init(attachment: PendingAttachment, style: Style, theme: PopoverTheme, onRemove: @escaping (PendingAttachment) -> Void) {
        self.attachment = attachment
        self.style = style
        self.theme = theme
        self.onRemove = onRemove
        super.init(frame: NSRect(x: 0, y: 0, width: 220, height: chipHeight))
        wantsLayer = true
        applyStyle()
        layer?.borderWidth = 1
        layer?.cornerRadius = chipHeight / 2

        iconView.contentTintColor = foregroundColor
        iconView.image = iconImage()
        iconView.frame = NSRect(x: 14, y: 9, width: 18, height: 18)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(iconView)

        titleLabel.stringValue = attachment.displayName
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = foregroundColor
        titleLabel.lineBreakMode = .byTruncatingMiddle
        addSubview(titleLabel)

        removeButton.title = ""
        removeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Remove attachment")
        removeButton.imageScaling = .scaleProportionallyDown
        removeButton.isBordered = false
        removeButton.contentTintColor = foregroundColor
        removeButton.target = self
        removeButton.action = #selector(removeTapped)
        addSubview(removeButton)

        updateLayout()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    @objc private func removeTapped() {
        onRemove(attachment)
    }

    var attachmentID: String {
        attachment.id
    }

    var preferredHeight: CGFloat {
        chipHeight
    }

    override func layout() {
        super.layout()
        updateLayout()
    }

    private func updateLayout() {
        let bounds = self.bounds
        let buttonSize: CGFloat = 16
        let buttonY = round((bounds.height - buttonSize) / 2)
        removeButton.frame = NSRect(x: bounds.width - 30, y: buttonY, width: buttonSize, height: buttonSize)
        let titleX: CGFloat = 42
        let titleWidth = max(40, removeButton.frame.minX - titleX - 10)
        let titleHeight: CGFloat = 18
        let titleY = round((bounds.height - titleHeight) / 2)
        titleLabel.frame = NSRect(x: titleX, y: titleY, width: titleWidth, height: titleHeight)
    }

    private var foregroundColor: NSColor {
        switch style {
        case .file:
            return theme.attachmentFileText
        case .image:
            return theme.attachmentImageText
        case .skill:
            return theme.attachmentSkillText
        }
    }

    private func applyStyle() {
        switch style {
        case .file:
            layer?.backgroundColor = theme.attachmentFileBg.cgColor
            layer?.borderColor = theme.attachmentFileBorder.cgColor
        case .image:
            layer?.backgroundColor = theme.attachmentImageBg.cgColor
            layer?.borderColor = theme.attachmentImageBorder.cgColor
        case .skill:
            layer?.backgroundColor = theme.attachmentSkillBg.cgColor
            layer?.borderColor = theme.attachmentSkillBorder.cgColor
        }
    }

    private func iconImage() -> NSImage? {
        switch style {
        case .skill:
            let symbolName = attachment.iconSymbolNameOverride ?? "wand.and.stars"
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
            return NSImage(systemSymbolName: symbolName, accessibilityDescription: attachment.displayName)?
                .withSymbolConfiguration(config)
        case .file, .image:
            let icon = NSWorkspace.shared.icon(forFileType: attachment.url.pathExtension.isEmpty ? "txt" : attachment.url.pathExtension)
            icon.size = NSSize(width: 18, height: 18)
            return icon
        }
    }
}

class TerminalView: NSView, WKNavigationDelegate, NSTextFieldDelegate {
    let scrollView = NSScrollView()
    let textView = ChatTextView()
    let webView = WKWebView(frame: .zero)
    let attachmentStrip = NSView()
    let composerContainer = NSView()
    let inputField = AttachmentAwareTextField()
    let sendButton = HoverCursorButton(frame: .zero)
    let historyBackdrop = NSButton()
    let historyPanel = NSView()
    let historyScrollView = NSScrollView()
    let historyContentView = FlippedView()
    let historyTitleLabel = NSTextField(labelWithString: "历史对话")
    let historyStack = ManualHistoryListView()
    var onSendMessage: ((String) -> Void)?
    var onSkillInvoked: ((SkillInvocation) -> Bool)?
    var onRequestSkillList: ((String?) -> String)?
    var onWorkspaceCommand: ((String?) -> String)?
    var onClearRequested: (() -> Void)?
    var onRequestMessages: (() -> [AgentMessage])?
    var onHistorySelected: ((UUID) -> Void)?
    var onHistoryDelete: ((UUID) -> Void)?
    var onRequestHistory: (() -> [ChatThread])?
    var onRequestCurrentThreadID: (() -> UUID?)?
    var onThemeRefreshRequested: (() -> Void)?
    var historyPanelWidth: CGFloat = 236

    private var currentAssistantText = ""
    private var lastAssistantText = ""
    private var isStreaming = false
    private var assistantRenderStartLocation: Int?
    private var thinkingRange: NSRange?
    private var pendingStreamText = ""
    private var streamingTimer: Timer?
    private var streamingTickIndex = 0
    private var shouldFinishAfterStreaming = false
    private var isHistoryVisible = false
    private var isThinkingIndicatorVisible = false
    private var pendingAttachments: [PendingAttachment] = []
    private let maxInlineAttachmentBytes = 180_000
    private let maxInlineAttachmentCharacters = 20_000
    private let attachmentBarHeight: CGFloat = 40
    private let attachmentTopSpacing: CGFloat = 8
    private let attachmentBottomSpacing: CGFloat = 6
    private let attachmentChipSpacing: CGFloat = 8
    private let attachmentRowSpacing: CGFloat = 8
    private var currentAttachmentHeight: CGFloat = 0
    private var attachmentChipViews: [String: AttachmentChipView] = [:]
    private var historyHoverGlobalMonitor: Any?
    private var historyHoverLocalMonitor: Any?
    private var displayMessages: [AgentMessage] = []
    private var lastMarkdownRenderWidth: CGFloat = 0
    private var pendingScrollToBottom = false
    private var lastRenderedTranscriptContentHTML = ""
    private var lastRenderedTranscriptThemeSignature = ""
    private var isTranscriptShellLoaded = false
    private var lastHistorySelection: (threadID: UUID, timestamp: CFTimeInterval)?
    private var isFileDropTargeted = false {
        didSet { updateAttachmentDropState() }
    }
    private var isComposerFocused = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    deinit {
        removeHistoryHoverMonitors()
    }

    override func layout() {
        super.layout()
        layoutContentFrames()
        layoutAttachmentChips(animated: false)
        window?.invalidateCursorRects(for: self)
        historyBackdrop.frame = bounds
        if !isHistoryVisible {
            historyPanel.frame = NSRect(x: -historyPanelWidth, y: 0, width: historyPanelWidth, height: bounds.height)
        } else {
            historyPanel.frame = NSRect(x: 0, y: 0, width: historyPanelWidth, height: bounds.height)
        }
        rerenderMarkdownIfNeededForWidthChange()
    }

    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(bounds, cursor: .arrow)
        addCursorRect(composerContainer.frame, cursor: .iBeam)
    }

    override func cursorUpdate(with event: NSEvent) {
        let localPoint = convert(event.locationInWindow, from: nil)
        if composerContainer.frame.contains(localPoint) {
            NSCursor.iBeam.set()
        } else {
            NSCursor.arrow.set()
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyTheme()
        onThemeRefreshRequested?()
        renderTranscriptHTML(streamingText: isStreaming ? currentAssistantText : nil)
        reloadHistoryList()
        refreshAttachmentUI()
    }

    var characterColor: NSColor?
    var themeOverride: PopoverTheme?
    var theme: PopoverTheme {
        var t = themeOverride ?? PopoverTheme.current
        if let color = characterColor { t = t.withCharacterColor(color) }
        t = t.withCustomFont()
        return t
    }

    // MARK: - Setup

    private func setupViews() {
        let t = theme
        registerForDraggedTypes([.fileURL])
        wantsLayer = true
        layer?.backgroundColor = t.surfacePrimary.cgColor

        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = false
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.isHidden = true

        textView.autoresizingMask = [.width]
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.textColor = t.textPrimary
        textView.font = t.font
        textView.isRichText = true
        textView.textContainerInset = NSSize(width: 2, height: 4)
        let defaultPara = NSMutableParagraphStyle()
        defaultPara.paragraphSpacing = 8
        textView.defaultParagraphStyle = defaultPara
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.linkTextAttributes = [
            .foregroundColor: t.accentColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]

        scrollView.documentView = textView
        addSubview(scrollView)

        webView.autoresizingMask = [.width, .height]
        webView.setValue(false, forKey: "drawsBackground")
        webView.setValue(false, forKey: "opaque")
        webView.allowsBackForwardNavigationGestures = false
        webView.setValue(false, forKey: "allowsLinkPreview")
        webView.navigationDelegate = self
        if #available(macOS 11.0, *) {
            webView.allowsMagnification = false
        }
        webView.isHidden = false
        webView.alphaValue = 1
        webView.loadHTMLString("", baseURL: nil)
        addSubview(webView)

        attachmentStrip.wantsLayer = true
        attachmentStrip.layer?.backgroundColor = NSColor.clear.cgColor
        attachmentStrip.alphaValue = 0
        attachmentStrip.isHidden = true
        attachmentStrip.autoresizingMask = [.width]
        addSubview(attachmentStrip)

        composerContainer.wantsLayer = true
        composerContainer.autoresizingMask = [.width]
        addSubview(composerContainer)

        inputField.autoresizingMask = [.width]
        inputField.focusRingType = .none
        inputField.delegate = self
        let paddedCell = PaddedTextFieldCell(textCell: "")
        paddedCell.isEditable = true
        paddedCell.isScrollable = true
        paddedCell.font = t.font
        paddedCell.textColor = t.composerText
        paddedCell.drawsBackground = false
        paddedCell.isBezeled = false
        paddedCell.fieldBackgroundColor = nil
        paddedCell.fieldCornerRadius = 0
        paddedCell.placeholderAttributedString = NSAttributedString(
            string: AgentProvider.current.inputPlaceholder,
            attributes: [.font: t.font, .foregroundColor: t.composerPlaceholder]
        )
        inputField.cell = paddedCell
        inputField.onPasteAttachments = { [weak self] urls in
            guard let self else { return false }
            self.addPendingAttachments(urls: urls)
            return true
        }
        inputField.target = self
        inputField.action = #selector(inputSubmitted)
        composerContainer.addSubview(inputField)

        sendButton.title = ""
        sendButton.image = NSImage(systemSymbolName: "arrow.up", accessibilityDescription: "Send")
        sendButton.imageScaling = .scaleProportionallyDown
        sendButton.imagePosition = .imageOnly
        sendButton.isBordered = false
        sendButton.hoverCornerRadius = 14
        sendButton.target = self
        sendButton.action = #selector(sendButtonTapped)
        composerContainer.addSubview(sendButton)

        historyBackdrop.frame = bounds
        historyBackdrop.autoresizingMask = [.width, .height]
        historyBackdrop.isBordered = false
        historyBackdrop.title = ""
        historyBackdrop.wantsLayer = true
        historyBackdrop.layer?.backgroundColor = t.scrimColor.cgColor
        historyBackdrop.alphaValue = 0
        historyBackdrop.isHidden = true
        historyBackdrop.target = self
        historyBackdrop.action = #selector(closeHistoryPanelFromBackdrop)
        addSubview(historyBackdrop)

        historyPanel.frame = NSRect(x: -historyPanelWidth, y: 0, width: historyPanelWidth, height: frame.height)
        historyPanel.autoresizingMask = [.height]
        historyPanel.wantsLayer = true
        historyPanel.layer?.backgroundColor = t.historyPanelBg.cgColor
        historyPanel.layer?.borderWidth = 1
        historyPanel.layer?.borderColor = t.historyPanelBorder.cgColor
        historyPanel.layer?.cornerRadius = 18
        historyPanel.layer?.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        historyPanel.alphaValue = 0
        historyPanel.isHidden = true
        addSubview(historyPanel)

        historyScrollView.frame = historyPanel.bounds.insetBy(dx: 10, dy: 10)
        historyScrollView.autoresizingMask = [.width, .height]
        historyScrollView.drawsBackground = false
        historyScrollView.borderType = .noBorder
        historyScrollView.hasVerticalScroller = false
        historyScrollView.scrollerStyle = .overlay
        historyScrollView.autohidesScrollers = true
        historyPanel.addSubview(historyScrollView)

        historyContentView.frame = historyScrollView.bounds
        historyScrollView.documentView = historyContentView
        let historyClickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleHistoryListClick(_:)))
        historyClickGesture.numberOfClicksRequired = 1
        historyClickGesture.delaysPrimaryMouseButtonEvents = false
        historyContentView.addGestureRecognizer(historyClickGesture)

        historyTitleLabel.frame = NSRect(x: 6, y: 6, width: historyPanelWidth - 32, height: 24)
        historyTitleLabel.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        historyTitleLabel.textColor = t.historyRowText
        historyTitleLabel.autoresizingMask = [.width]
        historyContentView.addSubview(historyTitleLabel)

        historyStack.spacing = 6
        historyContentView.addSubview(historyStack)

        addSubview(historyPanel)
        layoutContentFrames()
        layoutHistoryListFrames()
        applyTheme()
        refreshComposerState()
    }

    // MARK: - Input

    @objc private func inputSubmitted() {
        submitCurrentInput()
    }

    @objc private func sendButtonTapped() {
        submitCurrentInput()
    }

    private func submitCurrentInput() {
        let text = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !pendingAttachments.isEmpty else { return }
        inputField.stringValue = ""
        refreshComposerState()

        if handleSlashCommand(text, attachments: pendingAttachments) { return }

        let sentAttachments = pendingAttachments
        appendUser(text, attachments: sentAttachments)
        let payload = composeMessage(text: text, attachments: sentAttachments)
        pendingAttachments.removeAll()
        refreshAttachmentUI()
        beginAssistantTurn()
        onSendMessage?(payload)
    }

    func controlTextDidBeginEditing(_ obj: Notification) {
        isComposerFocused = true
        applyTheme()
        refreshComposerState()
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        isComposerFocused = false
        applyTheme()
        refreshComposerState()
    }

    func controlTextDidChange(_ obj: Notification) {
        refreshComposerState()
    }

    // MARK: - Slash Commands

    func handleSlashCommandPublic(_ text: String) {
        _ = handleSlashCommand(text, attachments: [])
    }

    private func handleSlashCommand(_ text: String, attachments: [PendingAttachment]) -> Bool {
        guard text.hasPrefix("/") else { return false }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()

        switch true {
        case lowercased == "/clear":
            guard attachments.isEmpty else {
                displayMessages.append(AgentMessage(role: .error, text: "`/clear` does not take attachments."))
                renderTranscriptHTML(streamingText: nil)
                return true
            }
            resetStreamingState()
            displayMessages.removeAll()
            clearPendingAttachments()
            onClearRequested?()
            renderTranscriptHTML(streamingText: nil)
            return true

        case lowercased == "/copy":
            guard attachments.isEmpty else {
                displayMessages.append(AgentMessage(role: .error, text: "`/copy` does not take attachments."))
                renderTranscriptHTML(streamingText: nil)
                return true
            }
            let toCopy = lastAssistantText.isEmpty ? "nothing to copy yet" : lastAssistantText
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(toCopy, forType: .string)
            displayMessages.append(AgentMessage(role: .toolResult, text: "DONE copied to clipboard"))
            renderTranscriptHTML(streamingText: nil)
            return true

        case lowercased == "/help":
            guard attachments.isEmpty else {
                displayMessages.append(AgentMessage(role: .error, text: "`/help` does not take attachments."))
                renderTranscriptHTML(streamingText: nil)
                return true
            }
            let helpText = """
            fliggy agents — slash commands
            /clear                     clear chat history
            /copy                      copy last response
            /help                      show this message
            /skills [query]            list installed skills
            /cwd [path]                show or set the agent workspace
            /skill name task...        run one skill with Codex
            /skill a,b task...         run multiple skills together
            """
            displayMessages.append(AgentMessage(role: .assistant, text: helpText))
            renderTranscriptHTML(streamingText: nil)
            return true

        case lowercased.hasPrefix("/skills"):
            guard attachments.isEmpty else {
                displayMessages.append(AgentMessage(role: .error, text: "`/skills` does not take attachments."))
                renderTranscriptHTML(streamingText: nil)
                return true
            }
            let query = extractCommandRemainder(trimmed, command: "/skills")
            let response = onRequestSkillList?(query?.isEmpty == true ? nil : query) ?? "No skill registry is available."
            displayMessages.append(AgentMessage(role: .assistant, text: response))
            renderTranscriptHTML(streamingText: nil)
            return true

        case lowercased.hasPrefix("/cwd"):
            guard attachments.isEmpty else {
                displayMessages.append(AgentMessage(role: .error, text: "`/cwd` does not take attachments."))
                renderTranscriptHTML(streamingText: nil)
                return true
            }
            let path = extractCommandRemainder(trimmed, command: "/cwd")
            let response = onWorkspaceCommand?(path?.isEmpty == true ? nil : path) ?? "Workspace control is unavailable."
            displayMessages.append(AgentMessage(role: .assistant, text: response))
            renderTranscriptHTML(streamingText: nil)
            return true

        case lowercased.hasPrefix("/skill"):
            guard let invocation = parseSkillInvocation(from: trimmed, attachments: attachments) else {
                displayMessages.append(AgentMessage(role: .error, text: "Usage: `/skill animate add hover motion to the current page`"))
                renderTranscriptHTML(streamingText: nil)
                return true
            }

            appendUser(trimmed, attachments: attachments)
            pendingAttachments.removeAll()
            refreshAttachmentUI()
            beginAssistantTurn()

            if onSkillInvoked?(invocation) == true {
                return true
            }

            endStreaming()
            displayMessages.append(AgentMessage(role: .error, text: "Skill execution is unavailable right now."))
            renderTranscriptHTML(streamingText: nil)
            return true

        default:
            displayMessages.append(AgentMessage(role: .error, text: "unknown command: \(text) (try /help)"))
            renderTranscriptHTML(streamingText: nil)
            return true
        }
    }

    private func extractCommandRemainder(_ text: String, command: String) -> String? {
        guard text.count >= command.count else { return nil }
        let index = text.index(text.startIndex, offsetBy: command.count)
        let remainder = String(text[index...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return remainder.isEmpty ? nil : remainder
    }

    private func parseSkillInvocation(from text: String, attachments: [PendingAttachment]) -> SkillInvocation? {
        guard let remainder = extractCommandRemainder(text, command: "/skill"),
              !remainder.isEmpty else {
            return nil
        }

        let parts = remainder.split(maxSplits: 1, whereSeparator: \.isWhitespace)
        guard let namesPart = parts.first else { return nil }
        let skillNames = namesPart
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let instruction = parts.count > 1
            ? String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            : ""

        guard !skillNames.isEmpty, !instruction.isEmpty else { return nil }

        return SkillInvocation(
            commandText: text,
            skillNames: skillNames,
            instruction: instruction,
            attachments: attachments
        )
    }

    // MARK: - Append Methods

    private var messageSpacing: NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.paragraphSpacingBefore = 8
        return p
    }

    private func ensureNewline() {
        if let storage = textView.textStorage, storage.length > 0 {
            if !storage.string.hasSuffix("\n") {
                storage.append(NSAttributedString(string: "\n"))
            }
        }
    }

    func appendUser(_ text: String, attachments: [PendingAttachment] = []) {
        let userLine = text.isEmpty ? "(attachment only)" : text
        if attachments.isEmpty {
            displayMessages.append(AgentMessage(role: .user, text: userLine))
        } else {
            let skillNames = attachments.filter(\.isSkill).map(\.displayName)
            let fileNames = attachments.filter { !$0.isSkill }.map(\.displayName)
            var attachmentLines: [String] = []
            if !skillNames.isEmpty {
                attachmentLines.append("[skills] \(skillNames.joined(separator: ", "))")
            }
            if !fileNames.isEmpty {
                attachmentLines.append("[files] \(fileNames.joined(separator: ", "))")
            }
            displayMessages.append(AgentMessage(role: .user, text: "\(userLine)\n\(attachmentLines.joined(separator: "\n"))"))
        }
        renderTranscriptHTML(streamingText: nil)
    }

    private func renderUserAttachmentLine(_ attachments: [PendingAttachment]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for (index, attachment) in attachments.enumerated() {
            if index > 0 {
                result.append(NSAttributedString(string: "  "))
            }
            let style = attachmentStyle(for: attachment)
            let image = renderAttachmentChipImage(
                filename: attachment.displayName,
                style: style
            )
            let attachmentString = NSMutableAttributedString(attachment: NSTextAttachment())
            if let textAttachment = attachmentString.attribute(.attachment, at: 0, effectiveRange: nil) as? NSTextAttachment {
                textAttachment.image = image
                textAttachment.bounds = NSRect(x: 0, y: -8, width: image.size.width, height: image.size.height)
            }
            result.append(attachmentString)
        }
        return result
    }

    private func renderAttachmentChipImage(filename: String, style: AttachmentChipView.Style) -> NSImage {
        let chipHeight: CGFloat = 28
        let horizontalPadding: CGFloat = 12
        let iconSize: CGFloat = 14
        let closeSize: CGFloat = 12
        let gap: CGFloat = 8
        let font = NSFont.systemFont(ofSize: 12, weight: .medium)
        let maxTextWidth: CGFloat = 160
        let measuredTextWidth = min((filename as NSString).size(withAttributes: [.font: font]).width, maxTextWidth)
        let chipWidth = horizontalPadding + iconSize + gap + measuredTextWidth + gap + closeSize + horizontalPadding

        let image = NSImage(size: NSSize(width: chipWidth, height: chipHeight))
        image.lockFocus()

        let backgroundColor: NSColor
        let borderColor: NSColor
        let foregroundColor: NSColor
        switch style {
        case .file:
            backgroundColor = NSColor(calibratedRed: 0.87, green: 0.95, blue: 0.95, alpha: 1)
            borderColor = NSColor(calibratedRed: 0.72, green: 0.87, blue: 0.87, alpha: 1)
            foregroundColor = NSColor(calibratedRed: 0.16, green: 0.62, blue: 0.65, alpha: 1)
        case .image:
            backgroundColor = NSColor(calibratedRed: 0.90, green: 0.95, blue: 1.00, alpha: 1)
            borderColor = NSColor(calibratedRed: 0.72, green: 0.83, blue: 0.98, alpha: 1)
            foregroundColor = NSColor(calibratedRed: 0.20, green: 0.47, blue: 0.88, alpha: 1)
        case .skill:
            backgroundColor = NSColor(calibratedRed: 1.00, green: 0.96, blue: 0.83, alpha: 1)
            borderColor = NSColor(calibratedRed: 0.95, green: 0.84, blue: 0.46, alpha: 1)
            foregroundColor = NSColor(calibratedRed: 0.53, green: 0.35, blue: 0.04, alpha: 1)
        }

        let path = NSBezierPath(roundedRect: NSRect(x: 0.5, y: 0.5, width: chipWidth - 1, height: chipHeight - 1), xRadius: chipHeight / 2, yRadius: chipHeight / 2)
        backgroundColor.setFill()
        path.fill()
        borderColor.setStroke()
        path.lineWidth = 1
        path.stroke()

        let iconRect = NSRect(x: horizontalPadding, y: round((chipHeight - iconSize) / 2), width: iconSize, height: iconSize)
        if style == .skill {
            let config = NSImage.SymbolConfiguration(pointSize: iconSize, weight: .medium)
            let skillIcon = NSImage(systemSymbolName: "wand.and.stars", accessibilityDescription: nil)?
                .withSymbolConfiguration(config)
            skillIcon?.draw(in: iconRect)
        } else {
            let fileIcon = NSWorkspace.shared.icon(forFileType: NSString(string: filename).pathExtension.isEmpty ? "txt" : NSString(string: filename).pathExtension)
            fileIcon.size = NSSize(width: iconSize, height: iconSize)
            fileIcon.draw(in: iconRect)
        }

        let textRect = NSRect(x: iconRect.maxX + gap, y: round((chipHeight - 16) / 2) - 1, width: measuredTextWidth, height: 16)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingMiddle
        (filename as NSString).draw(in: textRect, withAttributes: [
            .font: font,
            .foregroundColor: foregroundColor,
            .paragraphStyle: paragraph
        ])

        let closeRect = NSRect(x: chipWidth - horizontalPadding - closeSize, y: round((chipHeight - closeSize) / 2), width: closeSize, height: closeSize)
        if let closeImage = NSImage(systemSymbolName: "xmark", accessibilityDescription: nil) {
            closeImage.withSymbolConfiguration(.init(pointSize: closeSize, weight: .regular))?
                .draw(in: closeRect)
        } else {
            ("×" as NSString).draw(in: closeRect, withAttributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: foregroundColor])
        }

        image.unlockFocus()
        return image
    }

    func appendStreamingText(_ text: String) {
        if !isStreaming {
            beginAssistantTurn()
        }

        var cleaned = text
        if currentAssistantText.isEmpty {
            cleaned = cleaned.replacingOccurrences(of: "^\n+", with: "", options: .regularExpression)
        }
        guard !cleaned.isEmpty else { return }

        pendingStreamText += cleaned
        startStreamingTimerIfNeeded()
    }

    func endStreaming() {
        shouldFinishAfterStreaming = true
        if pendingStreamText.isEmpty {
            finishAssistantTurn()
        } else {
            startStreamingTimerIfNeeded()
        }
    }

    func appendError(_ text: String) {
        clearThinkingIndicator()
        displayMessages.append(AgentMessage(role: .error, text: text))
        renderTranscriptHTML(streamingText: nil)
    }

    func appendToolUse(toolName: String, summary: String) {
        endStreaming()
        displayMessages.append(AgentMessage(role: .toolUse, text: "\(toolName.uppercased()) \(summary)"))
        renderTranscriptHTML(streamingText: nil)
    }

    func appendToolResult(summary: String, isError: Bool) {
        let prefix = isError ? "FAIL" : "DONE"
        displayMessages.append(AgentMessage(role: .toolResult, text: "\(prefix) \(summary)"))
        renderTranscriptHTML(streamingText: nil)
    }

    func replayHistory(_ messages: [AgentMessage]) {
        lastMarkdownRenderWidth = currentMarkdownRenderWidth()
        resetStreamingState()
        displayMessages = messages
        renderTranscriptHTML(streamingText: nil)
    }

func scrollTranscriptToTopForDebug() {
    webView.evaluateJavaScript("window.__lilAgentsScrollToTop && window.__lilAgentsScrollToTop();", completionHandler: nil)
}

    func resumeThinkingIfNeeded() {
        guard !isStreaming else { return }
        beginAssistantTurn()
        renderTranscriptHTML(streamingText: nil)
    }

private func scrollToBottom() {
    pendingScrollToBottom = true
    webView.evaluateJavaScript("window.__lilAgentsScrollToBottom && window.__lilAgentsScrollToBottom();") { [weak self] _, _ in
        self?.pendingScrollToBottom = false
    }
}

private func applyTranscriptHTMLUpdate(_ html: String, forceScrollToBottom: Bool) {
    let forceFlag = forceScrollToBottom ? "true" : "false"
    let script = "window.__lilAgentsTranscriptUpdate(\(javaScriptStringLiteral(html)), \(forceFlag));"
    webView.evaluateJavaScript(script) { [weak self] _, _ in
        if forceScrollToBottom {
            self?.pendingScrollToBottom = false
        }
    }
}

private func javaScriptStringLiteral(_ value: String) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: [value]),
          let encoded = String(data: data, encoding: .utf8),
          encoded.count >= 2 else {
        return "\"\""
    }
    return String(encoded.dropFirst().dropLast())
}

    func toggleHistoryPanel() {
        isHistoryVisible.toggle()
        if isHistoryVisible {
            reloadHistoryList()
            installHistoryHoverMonitorsIfNeeded()
            historyBackdrop.isHidden = false
            historyPanel.isHidden = false
            syncHistoryHoverStates()
        } else {
            removeHistoryHoverMonitors()
            syncHistoryHoverStates()
        }
        let targetX: CGFloat = isHistoryVisible ? 0 : -historyPanelWidth
        let targetAlpha: CGFloat = isHistoryVisible ? 1 : 0
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            historyBackdrop.animator().alphaValue = targetAlpha
            historyPanel.animator().setFrameOrigin(NSPoint(x: targetX, y: 0))
            historyPanel.animator().alphaValue = targetAlpha
        }, completionHandler: { [weak self] in
            guard let self else { return }
            if !self.isHistoryVisible {
                self.historyBackdrop.isHidden = true
                self.historyPanel.isHidden = true
            }
            self.syncHistoryHoverStates()
        })
    }

    func toggleHistoryPanelIfNeededClose() {
        guard isHistoryVisible else { return }
        toggleHistoryPanel()
    }

    func reloadHistoryList() {
        historyStack.arrangedSubviews.forEach {
            historyStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let t = theme
        let threads = onRequestHistory?() ?? []
        if threads.isEmpty {
            let label = NSTextField(labelWithString: "No chats yet")
            label.font = t.font
            label.textColor = t.textDim
            label.frame.size.height = 24
            historyStack.addArrangedSubview(label)
            layoutHistoryListFrames()
            syncHistoryHoverStates()
            return
        }

        for thread in threads {
            let row = HistoryRowView(
                thread: thread,
                width: historyPanelWidth - 20,
                theme: t,
                isSelected: thread.id == onRequestCurrentThreadID?(),
                target: nil,
                action: nil
            )
            row.onDelete = { [weak self] row in
                self?.animateHistoryRowDeletion(row)
            }
            row.onSelect = { [weak self] row in
                NSLog("TerminalView.reloadHistoryList.onSelect threadID=%@", row.threadID.uuidString)
                self?.handleHistorySelection(threadID: row.threadID, source: "row")
            }
            historyStack.addArrangedSubview(row)
        }

        layoutHistoryListFrames()
        syncHistoryHoverStates()
        DispatchQueue.main.async { [weak self] in
            self?.logHistoryLayoutSnapshot(reason: "reloadHistoryList")
        }
    }

    private func logHistoryLayoutSnapshot(reason: String) {
        layoutSubtreeIfNeeded()
        historyPanel.layoutSubtreeIfNeeded()
        historyContentView.layoutSubtreeIfNeeded()
        historyStack.layoutSubtreeIfNeeded()

        NSLog(
            "TerminalView.historyLayout reason=%@ panel=%@ scroll=%@ content=%@ stack=%@",
            reason,
            NSStringFromRect(historyPanel.frame),
            NSStringFromRect(historyScrollView.frame),
            NSStringFromRect(historyContentView.frame),
            NSStringFromRect(historyStack.frame)
        )

        for row in historyStack.arrangedSubviews.compactMap({ $0 as? HistoryRowView }) {
            let rowInWindow = row.convert(row.bounds, to: nil)
            let rowOnScreen = window?.convertToScreen(rowInWindow) ?? .zero
            let rowCenterInWindow = CGPoint(x: rowInWindow.midX, y: rowInWindow.midY)
            let contentHitView: NSView?
            if let window,
               let contentView = window.contentView {
                let pointInContent = contentView.convert(rowCenterInWindow, from: nil)
                contentHitView = contentView.hitTest(pointInContent)
            } else {
                contentHitView = nil
            }
            let terminalHitView: NSView?
            if let terminalSuperviewPoint = superview?.convert(rowCenterInWindow, from: nil) {
                terminalHitView = hitTest(terminalSuperviewPoint)
            } else {
                terminalHitView = nil
            }
            NSLog(
                "TerminalView.historyLayout.row id=%@ frame=%@ window=%@ screen=%@ delete=%@ title=%@ contentHit=%@ terminalHit=%@",
                row.threadID.uuidString,
                NSStringFromRect(row.frame),
                NSStringFromRect(rowInWindow),
                NSStringFromRect(rowOnScreen),
                NSStringFromRect(row.deleteButton.frame),
                NSStringFromRect(row.titleButton.frame),
                debugViewDescription(contentHitView),
                debugViewDescription(terminalHitView)
            )
        }
    }

    private func debugViewDescription(_ view: NSView?) -> String {
        guard let view else { return "<nil>" }
        let identifier = view.identifier?.rawValue ?? "nil"
        return "\(type(of: view))(id=\(identifier), frame=\(NSStringFromRect(view.frame)))"
    }

    @objc private func handleHistoryListClick(_ recognizer: NSClickGestureRecognizer) {
        guard recognizer.state == .ended else { return }

        let pointInContent = recognizer.location(in: historyContentView)
        NSLog(
            "TerminalView.handleHistoryListClick contentPoint=%@",
            NSStringFromPoint(pointInContent)
        )
        _ = routeHistoryClick(at: pointInContent)
    }

    private func installHistoryHoverMonitorsIfNeeded() {
        guard historyHoverGlobalMonitor == nil else { return }

        historyHoverGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .rightMouseDown]) { [weak self] _ in
            DispatchQueue.main.async {
                self?.syncHistoryHoverStates()
            }
        }

        historyHoverLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.syncHistoryHoverStates()
            return event
        }
    }

    private func removeHistoryHoverMonitors() {
        if let historyHoverGlobalMonitor {
            NSEvent.removeMonitor(historyHoverGlobalMonitor)
            self.historyHoverGlobalMonitor = nil
        }
        if let historyHoverLocalMonitor {
            NSEvent.removeMonitor(historyHoverLocalMonitor)
            self.historyHoverLocalMonitor = nil
        }
    }

    private func syncHistoryHoverStates() {
        let rows = historyStack.arrangedSubviews.compactMap { $0 as? HistoryRowView }
        let shouldHighlight = isHistoryVisible && !historyPanel.isHidden && historyPanel.alphaValue > 0.01
        for row in rows {
            if shouldHighlight {
                row.refreshHoverState()
            } else {
                row.clearHoverState()
            }
        }
    }

    private func animateHistoryRowDeletion(_ row: HistoryRowView) {
        row.animateDeletion { [weak self] in
            guard let self else { return }
            self.onHistoryDelete?(row.threadID)
        }
    }

    @discardableResult
    func routeHistoryClick(at pointInContent: CGPoint) -> UUID? {
        for row in historyStack.arrangedSubviews.compactMap({ $0 as? HistoryRowView }) {
            let pointInRow = row.convert(pointInContent, from: historyContentView)
            switch row.hitTarget(at: pointInRow) {
            case .row:
                NSLog("TerminalView.routeHistoryClick.routeRow threadID=%@", row.threadID.uuidString)
                row.triggerSelectionFromContainer()
                return row.threadID
            case .deleteButton:
                NSLog("TerminalView.routeHistoryClick.routeDelete threadID=%@", row.threadID.uuidString)
                return nil
            case .none:
                continue
            }
        }
        NSLog("TerminalView.routeHistoryClick.miss point=%@", NSStringFromPoint(pointInContent))
        return nil
    }

    private func handleHistorySelection(threadID: UUID, source: String) {
        let now = CACurrentMediaTime()
        if let lastHistorySelection,
           lastHistorySelection.threadID == threadID,
           now - lastHistorySelection.timestamp < 0.35 {
            NSLog("TerminalView.handleHistorySelection.dedup threadID=%@ source=%@", threadID.uuidString, source)
            return
        }

        lastHistorySelection = (threadID, now)
        NSLog("TerminalView.handleHistorySelection.forward threadID=%@ source=%@", threadID.uuidString, source)
        toggleHistoryPanelIfNeededClose()
        onHistorySelected?(threadID)
    }


    @objc private func closeHistoryPanelFromBackdrop() {
        toggleHistoryPanelIfNeededClose()
    }

    private func layoutContentFrames() {
        let composerHeight: CGFloat = 52
        let padding: CGFloat = 12
        let attachmentHeight = pendingAttachments.isEmpty ? 0 : currentAttachmentHeight
        let attachmentY = composerHeight + padding + attachmentBottomSpacing
        let attachmentBlockHeight = pendingAttachments.isEmpty ? 0 : attachmentHeight + attachmentTopSpacing
        let width = frame.width - padding * 2
        scrollView.frame = NSRect(
            x: padding,
            y: composerHeight + padding + 8 + attachmentBlockHeight,
            width: width,
            height: frame.height - composerHeight - padding - 12 - attachmentBlockHeight
        )
        webView.frame = scrollView.frame
        attachmentStrip.frame = NSRect(
            x: padding,
            y: attachmentY,
            width: width,
            height: attachmentHeight
        )
        composerContainer.frame = NSRect(
            x: padding,
            y: 6,
            width: width,
            height: composerHeight
        )
        let sendButtonSize: CGFloat = 32
        let composerInset: CGFloat = 10
        sendButton.frame = NSRect(
            x: composerContainer.bounds.width - sendButtonSize - composerInset,
            y: round((composerContainer.bounds.height - sendButtonSize) / 2),
            width: sendButtonSize,
            height: sendButtonSize
        )
        inputField.frame = NSRect(
            x: composerInset,
            y: 6,
            width: max(60, sendButton.frame.minX - composerInset - 8),
            height: composerHeight - 12
        )
        layoutHistoryListFrames()
    }

    private func layoutHistoryListFrames() {
        let contentWidth = historyScrollView.contentView.bounds.width
        historyTitleLabel.frame = NSRect(x: 6, y: 6, width: historyPanelWidth - 32, height: 24)
        historyStack.frame.origin = NSPoint(x: 0, y: historyTitleLabel.frame.maxY + 10)
        historyStack.relayout(width: contentWidth)

        let totalHeight = max(
            historyScrollView.contentView.bounds.height,
            historyStack.frame.maxY
        )
        historyContentView.frame = NSRect(x: 0, y: 0, width: contentWidth, height: totalHeight)
    }

    private func refreshAttachmentUI() {
        let hasAttachments = !pendingAttachments.isEmpty
        attachmentStrip.isHidden = !hasAttachments
        attachmentStrip.alphaValue = hasAttachments ? 1 : 0
        guard hasAttachments else {
            currentAttachmentHeight = 0
            attachmentChipViews.values.forEach { $0.removeFromSuperview() }
            attachmentChipViews.removeAll()
            layoutContentFrames()
            needsLayout = true
            refreshComposerState()
            return
        }

        let t = theme
        let desiredIDs = Set(pendingAttachments.map(\.id))
        for (id, chip) in attachmentChipViews where !desiredIDs.contains(id) {
            chip.removeFromSuperview()
            attachmentChipViews.removeValue(forKey: id)
        }

        for attachment in pendingAttachments where attachmentChipViews[attachment.id] == nil {
            let chip = AttachmentChipView(
                attachment: attachment,
                style: attachmentStyle(for: attachment),
                theme: t
            ) { [weak self] item in
                self?.removeAttachment(item)
            }
            chip.alphaValue = 0
            attachmentStrip.addSubview(chip)
            attachmentChipViews[attachment.id] = chip
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                chip.animator().alphaValue = 1
            }
        }

        layoutAttachmentChips(animated: true)
        layoutContentFrames()
        needsLayout = true
        refreshComposerState()
    }

    private func removeAttachment(_ attachment: PendingAttachment) {
        pendingAttachments.removeAll { $0.id == attachment.id }
        if let chip = attachmentChipViews[attachment.id] {
            attachmentChipViews.removeValue(forKey: attachment.id)
            layoutAttachmentChips(animated: true)
            layoutContentFrames()
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.18
                chip.animator().alphaValue = 0
            }, completionHandler: { [weak self, weak chip] in
                chip?.removeFromSuperview()
                self?.refreshAttachmentUI()
            })
        } else {
            refreshAttachmentUI()
        }
    }

    func addPendingAttachments(urls: [URL]) {
        let fileAttachments = urls
            .filter { $0.isFileURL }
            .map { PendingAttachment(url: $0.standardizedFileURL) }
        guard !fileAttachments.isEmpty else { return }

        var seen = Set(pendingAttachments.map(\.id))
        for attachment in fileAttachments where !seen.contains(attachment.id) {
            pendingAttachments.append(attachment)
            seen.insert(attachment.id)
        }
        refreshAttachmentUI()
    }

    func addPendingSkills(_ skills: [SkillDefinition], preferredSymbolName: String? = nil) {
        guard !skills.isEmpty else { return }

        var seen = Set(pendingAttachments.map(\.id))
        for skill in skills {
            let attachment = PendingAttachment(skill: skill, iconSymbolName: preferredSymbolName)
            guard !seen.contains(attachment.id) else { continue }
            pendingAttachments.append(attachment)
            seen.insert(attachment.id)
        }

        refreshAttachmentUI()
    }

    func clearPendingAttachments() {
        pendingAttachments.removeAll()
        refreshAttachmentUI()
    }

    private func layoutAttachmentChips(animated: Bool) {
        guard !pendingAttachments.isEmpty else { return }

        let availableWidth = max(attachmentStrip.bounds.width, bounds.width - 20)
        guard availableWidth > 0 else { return }

        let minimumChipWidth: CGFloat = 170
        let idealChipWidth: CGFloat = 210
        let chipHeight = attachmentBarHeight - 4
        let columns = max(1, Int((availableWidth + attachmentChipSpacing) / (idealChipWidth + attachmentChipSpacing)))
        let computedWidth = floor((availableWidth - CGFloat(columns - 1) * attachmentChipSpacing) / CGFloat(columns))
        let chipWidth = max(minimumChipWidth, computedWidth)

        var cursorX: CGFloat = 0
        var cursorY: CGFloat = 0
        for attachment in pendingAttachments {
            guard let chip = attachmentChipViews[attachment.id] else { continue }
            if cursorX + chipWidth > availableWidth && cursorX > 0 {
                cursorX = 0
                cursorY += attachmentBarHeight + attachmentRowSpacing
            }

            let frame = NSRect(x: cursorX, y: cursorY + 2, width: chipWidth, height: chipHeight)
            if animated {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.18
                    chip.animator().frame = frame
                }
            } else {
                chip.frame = frame
            }
            cursorX += chipWidth + attachmentChipSpacing
        }

        currentAttachmentHeight = cursorY + attachmentBarHeight
        attachmentStrip.frame.size.height = currentAttachmentHeight
    }

    private func attachmentStyle(for attachment: PendingAttachment) -> AttachmentChipView.Style {
        if attachment.isSkill {
            return .skill
        }

        let resourceValues = try? attachment.url.resourceValues(forKeys: [.contentTypeKey])
        if let type = resourceValues?.contentType, type.conforms(to: .image) {
            return .image
        }

        let ext = attachment.url.pathExtension.lowercased()
        let imageExtensions = ["png", "jpg", "jpeg", "gif", "webp", "heic", "heif", "bmp", "tiff", "svg", "avif"]
        return imageExtensions.contains(ext) ? .image : .file
    }

    private func updateAttachmentDropState() {
        let targetColor = isFileDropTargeted
            ? theme.accentColor.withAlphaComponent(0.07)
            : NSColor.clear
        attachmentStrip.wantsLayer = true
        attachmentStrip.layer?.cornerRadius = 14
        attachmentStrip.layer?.backgroundColor = targetColor.cgColor
        attachmentStrip.layer?.borderWidth = isFileDropTargeted ? 1 : 0
        attachmentStrip.layer?.borderColor = theme.accentColor.withAlphaComponent(0.45).cgColor
        if isFileDropTargeted {
            isComposerFocused = true
        }
        applyTheme()
    }

    private func refreshComposerState() {
        let canSend = !inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !pendingAttachments.isEmpty
        sendButton.isEnabled = canSend
        sendButton.alphaValue = canSend ? 1 : 0.92
        sendButton.contentTintColor = canSend ? theme.sendButtonText : theme.sendButtonDisabledText
        sendButton.normalBackgroundColor = canSend ? theme.sendButtonBg : theme.sendButtonDisabledBg
        sendButton.hoverBackgroundColor = canSend ? theme.sendButtonHoverBg : theme.sendButtonDisabledBg
        sendButton.pressedBackgroundColor = canSend ? theme.sendButtonHoverBg.withAlphaComponent(0.86) : theme.sendButtonDisabledBg
        sendButton.updateCursorIfMouseInside()
    }

    private func applyTheme() {
        let t = theme
        layer?.backgroundColor = t.surfacePrimary.cgColor

        composerContainer.wantsLayer = true
        composerContainer.layer?.cornerRadius = t.composerCornerRadius
        composerContainer.layer?.backgroundColor = t.composerBg.cgColor
        composerContainer.layer?.borderWidth = 1.5
        composerContainer.layer?.borderColor = (isComposerFocused || isFileDropTargeted ? t.composerFocusRing : t.composerBorder).cgColor

        if let paddedCell = inputField.cell as? PaddedTextFieldCell {
            paddedCell.font = t.font
            paddedCell.textColor = t.composerText
            paddedCell.placeholderAttributedString = NSAttributedString(
                string: AgentProvider.current.inputPlaceholder,
                attributes: [.font: t.font, .foregroundColor: t.composerPlaceholder]
            )
        }
        inputField.textColor = t.composerText
        inputField.font = t.font

        scrollView.drawsBackground = false
        textView.textColor = t.textPrimary
        textView.font = t.font
        textView.linkTextAttributes = [
            .foregroundColor: t.accentColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]

        historyBackdrop.layer?.backgroundColor = t.scrimColor.cgColor
        historyPanel.layer?.backgroundColor = t.historyPanelBg.cgColor
        historyPanel.layer?.borderColor = t.historyPanelBorder.cgColor
        historyTitleLabel.textColor = t.historyRowText
        historyContentView.layer?.backgroundColor = NSColor.clear.cgColor

        sendButton.image = NSImage(systemSymbolName: "arrow.up", accessibilityDescription: "Send")
        sendButton.hoverCornerRadius = 14

        refreshComposerState()
    }

    private func draggedFileURLs(from sender: NSDraggingInfo) -> [URL] {
        let classes: [AnyClass] = [NSURL.self]
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        let objects = sender.draggingPasteboard.readObjects(forClasses: classes, options: options) as? [URL]
        return (objects ?? []).filter { $0.isFileURL }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let urls = draggedFileURLs(from: sender)
        isFileDropTargeted = !urls.isEmpty
        return urls.isEmpty ? [] : .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let urls = draggedFileURLs(from: sender)
        isFileDropTargeted = !urls.isEmpty
        return urls.isEmpty ? [] : .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        isFileDropTargeted = false
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        !draggedFileURLs(from: sender).isEmpty
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = draggedFileURLs(from: sender)
        guard !urls.isEmpty else {
            isFileDropTargeted = false
            return false
        }
        addPendingAttachments(urls: urls)
        isFileDropTargeted = false
        return true
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        isFileDropTargeted = false
    }

    private func composeMessage(text: String, attachments: [PendingAttachment]) -> String {
        guard !attachments.isEmpty else { return text }

        let skillSections = attachments.filter(\.isSkill).map(buildAttachmentSection)
        let fileSections = attachments.filter { !$0.isSkill }.map(buildAttachmentSection)
        var preambleBlocks: [String] = []

        if !skillSections.isEmpty {
            preambleBlocks.append("""
            Selected skills for this message:

            \(skillSections.joined(separator: "\n\n"))
            """)
        }

        if !fileSections.isEmpty {
            preambleBlocks.append("""
            Attached files for this message:

            \(fileSections.joined(separator: "\n\n"))
            """)
        }

        let preamble = preambleBlocks.joined(separator: "\n\n")

        if text.isEmpty {
            return preamble
        }

        return """
        \(preamble)

        User request:
        \(text)
        """
    }

    private func buildAttachmentSection(for attachment: PendingAttachment) -> String {
        if attachment.isSkill {
            let detail = attachment.detailTextOverride ?? "No description available."
            return """
            Skill: \(attachment.displayName)
            Description: \(detail)
            Local skill file: \(attachment.url.path)
            Instruction: Use this installed local skill as guidance for the following user request.
            """
        }

        let url = attachment.url
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey, .isDirectoryKey])
        let sizeText = Self.formatBytes(values?.fileSize)

        if values?.isDirectory == true {
            return """
            File: \(attachment.displayName)
            Type: directory
            Size: \(sizeText)
            Note: Directory uploads are not expanded automatically in fliggy agents yet.
            """
        }

        if let type = values?.contentType, type.conforms(to: .pdf), let doc = PDFDocument(url: url) {
            let pdfText = (doc.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !pdfText.isEmpty {
                return """
                File: \(attachment.displayName)
                Type: PDF document
                Size: \(sizeText)
                Content:
                \(Self.truncate(pdfText, limit: maxInlineAttachmentCharacters))
                """
            }
        }

        if shouldInlineTextFile(url: url, type: values?.contentType, size: values?.fileSize),
           let text = try? String(contentsOf: url),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return """
            File: \(attachment.displayName)
            Type: text
            Size: \(sizeText)
            Content:
            \(Self.truncate(text, limit: maxInlineAttachmentCharacters))
            """
        }

        let fileType = values?.contentType?.localizedDescription ?? url.pathExtension.uppercased()
        return """
        File: \(attachment.displayName)
        Type: \(fileType.isEmpty ? "file" : fileType)
        Size: \(sizeText)
        Note: Binary or unsupported file preview. The file was attached in the UI, but this provider currently receives metadata only.
        Local path: \(url.path)
        """
    }

    private func shouldInlineTextFile(url: URL, type: UTType?, size: Int?) -> Bool {
        if let size, size > maxInlineAttachmentBytes { return false }
        if let type {
            if type.conforms(to: .text) || type.conforms(to: .sourceCode) || type.conforms(to: .json) || type.conforms(to: .xml) {
                return true
            }
            if type.conforms(to: .image) || type.conforms(to: .audiovisualContent) || type.conforms(to: .archive) {
                return false
            }
        }

        let ext = url.pathExtension.lowercased()
        return [
            "txt", "md", "markdown", "csv", "json", "yaml", "yml", "toml", "xml", "html", "css",
            "js", "jsx", "ts", "tsx", "swift", "py", "rb", "go", "java", "kt", "rs", "c", "cc",
            "cpp", "h", "hpp", "m", "mm", "sh", "zsh", "bash", "sql", "log"
        ].contains(ext)
    }

    private static func truncate(_ text: String, limit: Int) -> String {
        if text.count <= limit { return text }
        let end = text.index(text.startIndex, offsetBy: limit)
        return String(text[..<end]) + "\n\n[truncated by fliggy agents]"
    }

    private static func formatBytes(_ bytes: Int?) -> String {
        guard let bytes else { return "Unknown" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func beginAssistantTurn() {
        resetStreamingState()
        isStreaming = true
        currentAssistantText = ""
        appendThinkingIndicator()
    }

    private func finishAssistantTurn() {
        stopStreamingTimer()
        clearThinkingIndicator()
        if isStreaming, !currentAssistantText.isEmpty {
            lastAssistantText = currentAssistantText
            displayMessages.append(AgentMessage(role: .assistant, text: currentAssistantText))
            renderTranscriptHTML(streamingText: nil)
        }
        isStreaming = false
        pendingStreamText = ""
        shouldFinishAfterStreaming = false
    }

    private func resetStreamingState() {
        stopStreamingTimer()
        pendingStreamText = ""
        currentAssistantText = ""
        streamingTickIndex = 0
        shouldFinishAfterStreaming = false
        assistantRenderStartLocation = nil
        thinkingRange = nil
        isStreaming = false
        isThinkingIndicatorVisible = false
    }

    private func startStreamingTimerIfNeeded() {
        guard streamingTimer == nil else { return }
        streamingTimer = Timer.scheduledTimer(withTimeInterval: nextStreamingDelay(), repeats: false) { [weak self] _ in
            self?.streamingTimer = nil
            self?.drainPendingStreamTextTick()
        }
        if let streamingTimer {
            RunLoop.main.add(streamingTimer, forMode: .common)
        }
    }

    private func stopStreamingTimer() {
        streamingTimer?.invalidate()
        streamingTimer = nil
    }

    private func flushPendingStreamText() {
        while !pendingStreamText.isEmpty {
            drainPendingStreamTextTick(forceAll: true)
        }
    }

    private func drainPendingStreamTextTick(forceAll: Bool = false) {
        guard !pendingStreamText.isEmpty else {
            stopStreamingTimer()
            if shouldFinishAfterStreaming, isStreaming {
                finishAssistantTurn()
            }
            return
        }

        let chunkCount = forceAll ? pendingStreamText.count : min(nextStreamingChunkCount(), pendingStreamText.count)
        let chunkEnd = pendingStreamText.index(pendingStreamText.startIndex, offsetBy: chunkCount)
        let chunk = String(pendingStreamText[..<chunkEnd])
        pendingStreamText.removeSubrange(..<chunkEnd)

        currentAssistantText += chunk
        streamingTickIndex += 1
        renderAssistantStreamingState()

        if pendingStreamText.isEmpty {
            stopStreamingTimer()
            if shouldFinishAfterStreaming, isStreaming {
                finishAssistantTurn()
            }
        } else if !forceAll {
            startStreamingTimerIfNeeded()
        }
    }

    private func nextStreamingChunkCount() -> Int {
        let remaining = pendingStreamText.count
        if remaining <= 2 { return 1 }

        if let first = pendingStreamText.first, first == "\n" {
            return 1
        }

        if streamingTickIndex < 8 { return 1 }
        if streamingTickIndex < 30 { return 2 }
        if remaining > 140 { return 3 }
        return 2
    }

    private func nextStreamingDelay() -> TimeInterval {
        guard let lastChar = currentAssistantText.last else { return 0.055 }

        switch lastChar {
        case "\n":
            return 0.11
        case ".", "!", "?", "。", "！", "？":
            return 0.095
        case ",", ";", ":", "，", "；", "：", "、":
            return 0.075
        case " ":
            return 0.05
        default:
            return streamingTickIndex < 10 ? 0.06 : 0.042
        }
    }

    private func appendThinkingIndicator() {
        isThinkingIndicatorVisible = true
        renderTranscriptHTML(streamingText: currentAssistantText.isEmpty ? nil : currentAssistantText)
    }

    private func clearThinkingIndicator() {
        isThinkingIndicatorVisible = false
    }

    private func renderAssistantStreamingState() {
        if !currentAssistantText.isEmpty {
            clearThinkingIndicator()
        }
        lastMarkdownRenderWidth = currentMarkdownRenderWidth()
        renderTranscriptHTML(streamingText: currentAssistantText)
    }

    private func currentMarkdownRenderWidth() -> CGFloat {
        max(webView.frame.width, scrollView.contentSize.width, 0)
    }

    private func rerenderMarkdownIfNeededForWidthChange() {
        let currentWidth = currentMarkdownRenderWidth()
        guard currentWidth > 0 else { return }
        guard abs(currentWidth - lastMarkdownRenderWidth) > 8 else { return }

        lastMarkdownRenderWidth = currentWidth

        if isStreaming {
            renderAssistantStreamingState()
            return
        }

        guard let messages = onRequestMessages?(), !messages.isEmpty else { return }
        replayHistory(messages)
    }

private func renderTranscriptHTML(streamingText: String?) {
    let t = theme
    let contentHTML = ChatTranscriptRenderer.buildTranscriptHTML(
        messages: displayMessages,
        streamingText: streamingText,
        theme: t,
        showsThinking: isThinkingIndicatorVisible
    )
    let themeSignature = ChatTranscriptRenderer.themeSignature(t)
    let shouldReloadShell = !isTranscriptShellLoaded || themeSignature != lastRenderedTranscriptThemeSignature
    pendingScrollToBottom = true

    if shouldReloadShell {
        lastRenderedTranscriptContentHTML = contentHTML
        lastRenderedTranscriptThemeSignature = themeSignature
        isTranscriptShellLoaded = false
        let documentHTML = ChatTranscriptRenderer.buildDocumentHTML(transcriptHTML: contentHTML, theme: t)
        webView.loadHTMLString(documentHTML, baseURL: nil)
        return
    }

    guard contentHTML != lastRenderedTranscriptContentHTML else {
        scrollToBottom()
        return
    }

    lastRenderedTranscriptContentHTML = contentHTML
    applyTranscriptHTMLUpdate(contentHTML, forceScrollToBottom: true)
}

    private func buildTranscriptHTML(messages: [AgentMessage], streamingText: String?, theme t: PopoverTheme) -> String {
        var body = ""
        for msg in messages {
            body += renderMessageHTML(msg, theme: t)
        }
        if isThinkingIndicatorVisible {
            body += "<div class='msg assistant dim'>thinking……（其实是loading为了有AI味改的 &gt; _ &lt;）</div>"
        }
        if let streamingText, !streamingText.isEmpty {
            body += renderMessageHTML(AgentMessage(role: .assistant, text: streamingText), theme: t, isStreaming: true)
        }
        return """
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        :root {
          --text: \(cssColor(t.textPrimary));
          --dim: \(cssColor(t.textDim));
          --accent: \(cssColor(t.accentColor));
          --bg: rgba(255,255,255,0);
          --separator: \(cssColor(t.separatorColor.withAlphaComponent(0.5)));
          --error: \(cssColor(t.errorColor));
          --success: \(cssColor(t.successColor));
          --code-bg: \(cssColor(t.inputBg));
        }
        * { box-sizing: border-box; }
        body {
          margin: 0;
          padding: 4px 0 12px 0;
          font-family: -apple-system, BlinkMacSystemFont, 'PingFang SC', 'Hiragino Sans GB', sans-serif;
          color: var(--text);
          background: var(--bg);
          font-size: \(max(Int(round(t.font.pointSize)), 13))px;
          line-height: 1.55;
          user-select: text;
          -webkit-user-select: text;
        }
        .msg { padding: 6px 8px; }
        .user { font-weight: 600; }
        .user .label { color: var(--accent); margin-right: 6px; }
        .assistant { }
        .dim { color: var(--dim); }
        .error { color: var(--error); }
        .tool { color: var(--dim); font-size: 0.95em; }
        .tool .tag { color: var(--accent); font-weight: 600; margin-right: 6px; }
        .tool.result.ok .tag { color: var(--success); }
        .tool.result.fail .tag { color: var(--error); }
        h1,h2,h3,h4,h5,h6 { margin: 10px 0 6px; color: var(--accent); }
        p { margin: 6px 0; }
        pre { background: var(--code-bg); padding: 10px; border-radius: 8px; overflow-x: auto; }
        code { background: var(--code-bg); padding: 1px 4px; border-radius: 4px; }
        blockquote { border-left: 3px solid var(--accent); margin: 6px 0; padding-left: 10px; color: var(--dim); }
        hr { border: none; border-top: 1px solid var(--separator); margin: 10px 0; }
        table { width: 100%; border-collapse: collapse; margin: 8px 0; }
        th, td { border: 1px solid var(--separator); padding: 10px 12px; text-align: left; vertical-align: top; }
        th { background: rgba(255,255,255,0.7); font-weight: 700; }
        a { color: var(--accent); text-decoration: underline; }
        ul, ol { margin: 6px 0 6px 20px; }
        li { margin: 4px 0; }
        </style>
        </head>
        <body>\(body)</body>
        </html>
        """
    }

    private func renderMessageHTML(_ msg: AgentMessage, theme t: PopoverTheme, isStreaming: Bool = false) -> String {
        switch msg.role {
        case .user:
            let safe = escapeHTML(msg.text)
            return "<div class='msg user'><span class='label'>&gt;</span>\(safe)</div>"
        case .assistant:
            let html = markdownToHTML(msg.text)
            return "<div class='msg assistant'>\(html)</div>"
        case .error:
            let safe = escapeHTML(msg.text)
            return "<div class='msg error'>\(safe)</div>"
        case .toolUse:
            let safe = escapeHTML(msg.text)
            return "<div class='msg tool'><span class='tag'>TOOL</span>\(safe)</div>"
        case .toolResult:
            let safe = escapeHTML(msg.text)
            let isFail = msg.text.uppercased().hasPrefix("FAIL")
            let cls = isFail ? "fail" : "ok"
            let tag = isFail ? "FAIL" : "DONE"
            return "<div class='msg tool result \(cls)'><span class='tag'>\(tag)</span>\(safe)</div>"
        }
    }

    private func markdownToHTML(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        var html = ""
        var inCode = false
        var codeBuffer: [String] = []
        var tableLines: [String] = []
        var paragraph: [String] = []

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            let joined = paragraph.joined(separator: "<br/>")
            html += "<p>\(inlineMarkdownToHTML(joined))</p>"
            paragraph.removeAll()
        }

        func flushCode() {
            guard !codeBuffer.isEmpty else { return }
            let code = escapeHTML(codeBuffer.joined(separator: "\n"))
            html += "<pre><code>\(code)</code></pre>"
            codeBuffer.removeAll()
        }

        func flushTable() {
            guard !tableLines.isEmpty else { return }
            let rows = tableLines.map { parseTableCells(from: $0) }.filter { !$0.isEmpty }
            let isSeparator: ([String]) -> Bool = { row in
                !row.isEmpty && row.allSatisfy { cell in
                    let trimmed = cell.replacingOccurrences(of: ":", with: "").replacingOccurrences(of: "-", with: "")
                    return trimmed.isEmpty
                }
            }
            let contentRows = rows.filter { !isSeparator($0) }
            guard !contentRows.isEmpty else {
                tableLines.removeAll()
                return
            }
            let header = contentRows.first ?? []
            let body = contentRows.dropFirst()
            html += "<table><thead><tr>" + header.map { "<th>\(inlineMarkdownToHTML(escapeHTML($0)))</th>" }.joined() + "</tr></thead><tbody>"
            for row in body {
                html += "<tr>" + row.map { "<td>\(inlineMarkdownToHTML(escapeHTML($0)))</td>" }.joined() + "</tr>"
            }
            html += "</tbody></table>"
            tableLines.removeAll()
        }

        for line in lines {
            if line.hasPrefix("```") {
                flushParagraph()
                flushTable()
                if inCode {
                    flushCode()
                    inCode = false
                } else {
                    inCode = true
                }
                continue
            }
            if inCode {
                codeBuffer.append(line)
                continue
            }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                flushParagraph()
                flushTable()
                continue
            }
            if isTableRow(trimmed) {
                flushParagraph()
                tableLines.append(trimmed)
                continue
            } else if !tableLines.isEmpty {
                flushTable()
            }
            if let heading = headingLevel(for: trimmed) {
                flushParagraph()
                html += "<h\(heading.level)>\(inlineMarkdownToHTML(escapeHTML(heading.text)))</h\(heading.level)>"
            } else if isHorizontalRule(trimmed) {
                flushParagraph()
                html += "<hr/>"
            } else if let quote = blockquoteContent(for: line) {
                flushParagraph()
                html += "<blockquote>\(inlineMarkdownToHTML(escapeHTML(quote)))</blockquote>"
            } else if let ordered = orderedListContent(for: line) {
                flushParagraph()
                html += "<ol><li>\(inlineMarkdownToHTML(escapeHTML(ordered.text)))</li></ol>"
            } else if let unordered = unorderedListContent(for: line) {
                flushParagraph()
                html += "<ul><li>\(inlineMarkdownToHTML(escapeHTML(unordered.text)))</li></ul>"
            } else if let task = taskListContent(for: line) {
                flushParagraph()
                let box = task.checked ? "☑" : "☐"
                html += "<ul><li>\(box) \(inlineMarkdownToHTML(escapeHTML(task.text)))</li></ul>"
            } else {
                paragraph.append(escapeHTML(line))
            }
        }
        flushParagraph()
        flushTable()
        if inCode { flushCode() }
        return html
    }

    private func inlineMarkdownToHTML(_ text: String) -> String {
        var out = text
        out = out.replacingOccurrences(of: "`([^`]+)`", with: "<code>$1</code>", options: .regularExpression)
        out = out.replacingOccurrences(of: "\\*\\*([^*]+)\\*\\*", with: "<strong>$1</strong>", options: .regularExpression)
        out = out.replacingOccurrences(of: "\\*([^*]+)\\*", with: "<em>$1</em>", options: .regularExpression)
        out = out.replacingOccurrences(of: "~~([^~]+)~~", with: "<del>$1</del>", options: .regularExpression)
        out = out.replacingOccurrences(of: "\\[([^\\]]+)\\]\\(([^\\)]+)\\)", with: "<a href=\"$2\">$1</a>", options: .regularExpression)
        return out
    }

    private func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private func cssColor(_ color: NSColor) -> String {
        let resolved = color.usingColorSpace(.deviceRGB) ?? color
        return String(
            format: "rgba(%d,%d,%d,%.3f)",
            Int(round(resolved.redComponent * 255)),
            Int(round(resolved.greenComponent * 255)),
            Int(round(resolved.blueComponent * 255)),
            resolved.alphaComponent
        )
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url, navigationAction.navigationType == .linkActivated {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    isTranscriptShellLoaded = true
    guard pendingScrollToBottom else { return }
    pendingScrollToBottom = false
    webView.evaluateJavaScript("window.__lilAgentsScrollToBottom && window.__lilAgentsScrollToBottom();", completionHandler: nil)
}

    // MARK: - Markdown Rendering

    private func renderMarkdown(_ text: String) -> NSAttributedString {
        let t = theme
        let result = NSMutableAttributedString()
        let lines = text.components(separatedBy: "\n")
        var inCodeBlock = false
        var codeFenceLanguage: String?
        var codeLines: [String] = []
        var paragraphLines: [String] = []
        var tableLines: [String] = []

        func flushParagraph() {
            guard !paragraphLines.isEmpty else { return }
            let joined = paragraphLines.joined(separator: "\n").trimmingCharacters(in: .newlines)
            paragraphLines.removeAll()
            guard !joined.isEmpty else { return }
            result.append(renderParagraph(joined, theme: t))
        }

        func flushTable() {
            guard !tableLines.isEmpty else { return }
            result.append(renderTable(tableLines, theme: t))
            tableLines.removeAll()
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("```") {
                flushParagraph()
                flushTable()
                if inCodeBlock {
                    result.append(renderCodeBlock(codeLines.joined(separator: "\n"), language: codeFenceLanguage, theme: t))
                    inCodeBlock = false
                    codeFenceLanguage = nil
                    codeLines = []
                } else {
                    inCodeBlock = true
                    let fenceSuffix = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    codeFenceLanguage = fenceSuffix.isEmpty ? nil : fenceSuffix
                }
                continue
            }

            if inCodeBlock {
                codeLines.append(line)
                continue
            }

            if trimmed.isEmpty {
                flushParagraph()
                flushTable()
                result.append(NSAttributedString(string: "\n"))
                continue
            }

            if isTableRow(trimmed) {
                flushParagraph()
                tableLines.append(trimmed)
                continue
            } else {
                flushTable()
            }

            if let heading = headingLevel(for: trimmed) {
                flushParagraph()
                result.append(renderHeading(text: heading.text, level: heading.level, theme: t))
            } else if isHorizontalRule(trimmed) {
                flushParagraph()
                result.append(renderHorizontalRule(theme: t))
            } else if let quote = blockquoteContent(for: line) {
                flushParagraph()
                result.append(renderBlockquote(quote, theme: t))
            } else if let ordered = orderedListContent(for: line) {
                flushParagraph()
                result.append(renderListItem(ordered.text, marker: "\(ordered.index).", indentLevel: ordered.indentLevel, theme: t))
            } else if let task = taskListContent(for: line) {
                flushParagraph()
                result.append(renderTaskListItem(task.text, checked: task.checked, indentLevel: task.indentLevel, theme: t))
            } else if unorderedListContent(for: line) != nil {
                flushParagraph()
                let unordered = unorderedListContent(for: line)!
                result.append(renderListItem(unordered.text, marker: "\u{2022}", indentLevel: unordered.indentLevel, theme: t))
            } else {
                paragraphLines.append(line)
            }
        }

        flushParagraph()
        flushTable()

        if inCodeBlock && !codeLines.isEmpty {
            result.append(renderCodeBlock(codeLines.joined(separator: "\n"), language: codeFenceLanguage, theme: t))
        }

        return result
    }

    private func renderParagraph(_ text: String, theme t: PopoverTheme) -> NSAttributedString {
        let p = NSMutableParagraphStyle()
        p.lineSpacing = 2
        p.paragraphSpacing = 10
        let rendered = NSMutableAttributedString(attributedString: renderInlineMarkdown(text, theme: t))
        rendered.addAttributes([
            .paragraphStyle: p
        ], range: NSRange(location: 0, length: rendered.length))
        rendered.append(NSAttributedString(string: "\n"))
        return rendered
    }

    private func renderHeading(text: String, level: Int, theme t: PopoverTheme) -> NSAttributedString {
        let size = t.font.pointSize + CGFloat(max(0, 4 - level)) * 1.5
        let paragraph = NSMutableParagraphStyle()
        paragraph.paragraphSpacing = 10
        paragraph.paragraphSpacingBefore = 6
        return NSAttributedString(string: text + "\n", attributes: [
            .font: NSFont.systemFont(ofSize: size, weight: .bold),
            .foregroundColor: t.accentColor,
            .paragraphStyle: paragraph
        ])
    }

    private func renderListItem(_ text: String, marker: String, indentLevel: Int = 0, theme t: PopoverTheme) -> NSAttributedString {
        let indentOffset = CGFloat(max(0, indentLevel)) * 18
        let paragraph = NSMutableParagraphStyle()
        paragraph.headIndent = 22 + indentOffset
        paragraph.firstLineHeadIndent = 8 + indentOffset
        paragraph.paragraphSpacing = 6
        let result = NSMutableAttributedString()
        result.append(NSAttributedString(string: "\(marker) ", attributes: [
            .font: t.fontBold,
            .foregroundColor: t.accentColor,
            .paragraphStyle: paragraph
        ]))
        let content = NSMutableAttributedString(attributedString: renderInlineMarkdown(text, theme: t))
        content.addAttributes([.paragraphStyle: paragraph], range: NSRange(location: 0, length: content.length))
        result.append(content)
        result.append(NSAttributedString(string: "\n"))
        return result
    }

    private func renderBlockquote(_ text: String, theme t: PopoverTheme) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.headIndent = 16
        paragraph.firstLineHeadIndent = 16
        paragraph.paragraphSpacing = 8
        let result = NSMutableAttributedString()
        result.append(NSAttributedString(string: "│ ", attributes: [
            .font: t.fontBold,
            .foregroundColor: t.accentColor.withAlphaComponent(0.85),
            .paragraphStyle: paragraph
        ]))
        let content = NSMutableAttributedString(attributedString: renderInlineMarkdown(text, theme: t))
        content.addAttributes([
            .foregroundColor: t.textDim,
            .paragraphStyle: paragraph
        ], range: NSRange(location: 0, length: content.length))
        result.append(content)
        result.append(NSAttributedString(string: "\n"))
        return result
    }

    private func renderCodeBlock(_ text: String, language: String?, theme t: PopoverTheme) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.paragraphSpacing = 10
        paragraph.paragraphSpacingBefore = 4
        paragraph.headIndent = 10
        paragraph.firstLineHeadIndent = 10
        let codeFont = NSFont.monospacedSystemFont(ofSize: t.font.pointSize - 0.5, weight: .regular)
        let result = NSMutableAttributedString()
        if let language, !language.isEmpty {
            result.append(NSAttributedString(string: language + "\n", attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: max(t.font.pointSize - 2, 10), weight: .semibold),
                .foregroundColor: t.textDim,
                .backgroundColor: t.inputBg,
                .paragraphStyle: paragraph
            ]))
        }
        result.append(NSAttributedString(string: text + "\n", attributes: [
            .font: codeFont,
            .foregroundColor: t.textPrimary,
            .backgroundColor: t.inputBg,
            .paragraphStyle: paragraph
        ]))
        return result
    }

    private func renderHorizontalRule(theme t: PopoverTheme) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.paragraphSpacing = 10
        return NSAttributedString(string: "────────────────────────\n", attributes: [
            .font: t.font,
            .foregroundColor: t.textDim.withAlphaComponent(0.65),
            .paragraphStyle: paragraph
        ])
    }

    private func renderTable(_ rows: [String], theme t: PopoverTheme) -> NSAttributedString {
        let parsedRows = rows.map { parseTableCells(from: $0) }.filter { !$0.isEmpty }
        guard !parsedRows.isEmpty else { return NSAttributedString(string: "") }

        let isSeparatorRow: ([String]) -> Bool = { row in
            !row.isEmpty && row.allSatisfy { cell in
                let trimmed = cell.replacingOccurrences(of: ":", with: "").replacingOccurrences(of: "-", with: "")
                return trimmed.isEmpty
            }
        }

        let contentRows = parsedRows.filter { !isSeparatorRow($0) }
        guard !contentRows.isEmpty else { return NSAttributedString(string: "") }

        let columnCount = contentRows.map(\.count).max() ?? 0
        guard columnCount > 0 else { return NSAttributedString(string: "") }
        let normalizedRows = contentRows.map { row in
            row + Array(repeating: "", count: max(0, columnCount - row.count))
        }

        if let image = makeTableImage(rows: normalizedRows, theme: t) {
            let attachment = NSTextAttachment()
            attachment.image = image
            let result = NSMutableAttributedString(attachment: attachment)
            result.append(NSAttributedString(string: "\n\n"))
            return result
        }

        return fallbackPlainTable(rows: normalizedRows, theme: t)
    }

    private func parseTableCells(from line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") { trimmed.removeFirst() }
        if trimmed.hasSuffix("|") { trimmed.removeLast() }
        return trimmed
            .components(separatedBy: "|")
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private func isTableRow(_ line: String) -> Bool {
        guard line.contains("|") else { return false }
        let cells = parseTableCells(from: line)
        return cells.count >= 2
    }

    private func fallbackPlainTable(rows: [[String]], theme t: PopoverTheme) -> NSAttributedString {
        let fallback = rows.map { " | " + $0.joined(separator: " | ") + " |" }.joined(separator: "\n")
        return NSAttributedString(string: fallback + "\n\n", attributes: [
            .font: t.font,
            .foregroundColor: t.textPrimary
        ])
    }

    private func makeTableImage(rows: [[String]], theme t: PopoverTheme) -> NSImage? {
        guard let firstRow = rows.first else { return nil }
        let columnCount = firstRow.count
        guard columnCount > 0 else { return nil }

        let maxWidth = max((scrollView.contentSize.width > 0 ? scrollView.contentSize.width : bounds.width) - 20, 320)
        let horizontalPadding: CGFloat = 16
        let verticalPadding: CGFloat = 12
        let borderWidth: CGFloat = 1
        let tableWidth = maxWidth

        var weights = Array(repeating: CGFloat(1), count: columnCount)
        if columnCount == 2 {
            weights = [1, 1.6]
        } else if columnCount == 3 {
            weights = [0.9, 1.5, 1.5]
        } else if columnCount >= 4 {
            weights[0] = 0.9
            for index in 1..<(columnCount - 1) {
                weights[index] = 1.35
            }
            weights[columnCount - 1] = 0.95
        }
        let weightSum = max(weights.reduce(0, +), 1)
        var columnWidths = weights.map { floor(tableWidth * ($0 / weightSum)) }
        if let last = columnWidths.indices.last {
            columnWidths[last] += tableWidth - columnWidths.reduce(0, +)
        }

        let bodyFont = NSFont.systemFont(ofSize: max(t.font.pointSize + 2, 15), weight: .regular)
        let headerFont = NSFont.systemFont(ofSize: max(t.font.pointSize + 2, 15), weight: .semibold)

        func textHeight(_ text: String, font: NSFont, width: CGFloat) -> CGFloat {
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byWordWrapping
            paragraph.lineSpacing = 2
            let rect = (text as NSString).boundingRect(
                with: NSSize(width: max(width - horizontalPadding * 2, 40), height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [
                    .font: font,
                    .paragraphStyle: paragraph
                ]
            )
            return ceil(rect.height)
        }

        let rowHeights: [CGFloat] = rows.enumerated().map { rowIndex, row in
            let font = rowIndex == 0 ? headerFont : bodyFont
            let maxTextHeight = row.enumerated().map { index, cell in
                textHeight(cell, font: font, width: columnWidths[index])
            }.max() ?? 0
            return max(maxTextHeight + verticalPadding * 2, rowIndex == 0 ? 54 : 52)
        }

        let tableHeight = rowHeights.reduce(0, +)
        let image = NSImage(size: NSSize(width: tableWidth, height: tableHeight))

        image.lockFocus()
        defer { image.unlockFocus() }

        NSColor.clear.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: tableWidth, height: tableHeight)).fill()

        let tableRect = NSRect(x: 0, y: 0, width: tableWidth, height: tableHeight)
        let roundedPath = NSBezierPath(roundedRect: tableRect, xRadius: 14, yRadius: 14)
        let borderColor = t.separatorColor.withAlphaComponent(0.5)
        let headerFill = NSColor.white.withAlphaComponent(0.84)
        let bodyFill = NSColor.white.withAlphaComponent(0.18)
        let altFill = NSColor.white.withAlphaComponent(0.28)

        // Most of this UI uses flipped views (top-left origin), but NSImage.lockFocus()
        // renders into an unflipped image context (bottom-left origin). Keep the layout
        // math in top-origin space and convert once here so rows don't appear upside down.
        func imageRect(topY: CGFloat, height: CGFloat) -> NSRect {
            NSRect(x: 0, y: tableHeight - topY - height, width: tableWidth, height: height)
        }

        bodyFill.setFill()
        roundedPath.fill()

        var currentTopY: CGFloat = 0
        for (rowIndex, row) in rows.enumerated() {
            let rowHeight = rowHeights[rowIndex]
            let rowRect = imageRect(topY: currentTopY, height: rowHeight)
            let fillColor = rowIndex == 0 ? headerFill : (rowIndex % 2 == 0 ? altFill : bodyFill)

            NSGraphicsContext.saveGraphicsState()
            roundedPath.addClip()
            fillColor.setFill()
            NSBezierPath(rect: rowRect).fill()
            NSGraphicsContext.restoreGraphicsState()

            var currentX: CGFloat = 0
            for (columnIndex, cell) in row.enumerated() {
                let cellRect = NSRect(x: currentX, y: rowRect.minY, width: columnWidths[columnIndex], height: rowHeight)
                let textRect = NSRect(
                    x: cellRect.minX + horizontalPadding,
                    y: cellRect.minY + verticalPadding,
                    width: cellRect.width - horizontalPadding * 2,
                    height: cellRect.height - verticalPadding * 2
                )

                let paragraph = NSMutableParagraphStyle()
                paragraph.lineBreakMode = .byWordWrapping
                paragraph.lineSpacing = 2
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: rowIndex == 0 ? headerFont : bodyFont,
                    .foregroundColor: t.textPrimary,
                    .paragraphStyle: paragraph
                ]
                (cell as NSString).draw(with: textRect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs)

                if columnIndex < columnCount - 1 {
                    let line = NSBezierPath()
                    line.move(to: NSPoint(x: cellRect.maxX, y: cellRect.minY))
                    line.line(to: NSPoint(x: cellRect.maxX, y: cellRect.maxY))
                    line.lineWidth = borderWidth
                    borderColor.setStroke()
                    line.stroke()
                }
                currentX += columnWidths[columnIndex]
            }

            if rowIndex < rows.count - 1 {
                let divider = NSBezierPath()
                divider.move(to: NSPoint(x: 0, y: rowRect.maxY))
                divider.line(to: NSPoint(x: tableWidth, y: rowRect.maxY))
                divider.lineWidth = borderWidth
                borderColor.setStroke()
                divider.stroke()
            }

            currentTopY += rowHeight
        }

        borderColor.setStroke()
        roundedPath.lineWidth = borderWidth
        roundedPath.stroke()

        return image
    }

    private func headingLevel(for line: String) -> (level: Int, text: String)? {
        let prefixes = ["###### ", "##### ", "#### ", "### ", "## ", "# "]
        for (index, prefix) in prefixes.enumerated() where line.hasPrefix(prefix) {
            return (6 - index, String(line.dropFirst(prefix.count)))
        }
        return nil
    }

    private func blockquoteContent(for line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("> ") else { return nil }
        return String(trimmed.dropFirst(2))
    }

    private func orderedListContent(for line: String) -> (index: String, text: String, indentLevel: Int)? {
        let indentWidth = line.prefix { $0 == " " }.count
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let dotIndex = trimmed.firstIndex(of: ".") else { return nil }
        let prefix = String(trimmed[..<dotIndex])
        guard !prefix.isEmpty, prefix.allSatisfy(\.isNumber) else { return nil }
        let textStart = trimmed.index(after: dotIndex)
        let remaining = trimmed[textStart...].trimmingCharacters(in: .whitespaces)
        guard !remaining.isEmpty else { return nil }
        return (prefix, remaining, indentWidth / 2)
    }

    private func unorderedListContent(for line: String) -> (text: String, indentLevel: Int)? {
        let indentWidth = line.prefix { $0 == " " }.count
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") else { return nil }
        let text = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        return (text, indentWidth / 2)
    }

    private func taskListContent(for line: String) -> (text: String, checked: Bool, indentLevel: Int)? {
        let indentWidth = line.prefix { $0 == " " }.count
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("- [") || trimmed.hasPrefix("* [") else { return nil }
        guard trimmed.count >= 6 else { return nil }
        let chars = Array(trimmed)
        guard chars[2] == "[", chars[4] == "]" else { return nil }
        let marker = chars[3]
        guard marker == " " || marker == "x" || marker == "X" else { return nil }
        let text = String(chars.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        return (text, marker == "x" || marker == "X", indentWidth / 2)
    }

    private func renderTaskListItem(_ text: String, checked: Bool, indentLevel: Int = 0, theme t: PopoverTheme) -> NSAttributedString {
        let marker = checked ? "☑" : "☐"
        return renderListItem(text, marker: marker, indentLevel: indentLevel, theme: t)
    }

    private func isHorizontalRule(_ line: String) -> Bool {
        let reduced = line.replacingOccurrences(of: " ", with: "")
        return reduced == "---" || reduced == "***"
    }

    private func renderInlineMarkdown(_ text: String, theme t: PopoverTheme) -> NSAttributedString {
        if #available(macOS 12.0, *) {
            var options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            options.failurePolicy = .returnPartiallyParsedIfPossible

            if let attributed = try? AttributedString(markdown: text, options: options) {
                let result = NSMutableAttributedString(attributed)
                let fullRange = NSRange(location: 0, length: result.length)
                result.addAttributes([
                    .font: t.font,
                    .foregroundColor: t.textPrimary
                ], range: fullRange)

                result.enumerateAttributes(in: fullRange) { attrs, range, _ in
                    var replacements: [NSAttributedString.Key: Any] = [:]

                    if let intent = attrs[.inlinePresentationIntent] as? InlinePresentationIntent {
                        if intent.contains(.stronglyEmphasized) {
                            replacements[.font] = t.fontBold
                        }
                        if intent.contains(.emphasized) {
                            let base = replacements[.font] as? NSFont ?? t.font
                            replacements[.font] = NSFontManager.shared.convert(base, toHaveTrait: .italicFontMask)
                        }
                        if intent.contains(.code) {
                            replacements[.font] = NSFont.monospacedSystemFont(ofSize: t.font.pointSize - 0.5, weight: .regular)
                            replacements[.foregroundColor] = t.accentColor
                            replacements[.backgroundColor] = t.inputBg
                        }
                        if intent.contains(.strikethrough) {
                            replacements[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                        }
                    }

                    if let link = attrs[.link] {
                        replacements[.link] = link
                        replacements[.foregroundColor] = t.accentColor
                        replacements[.underlineStyle] = NSUnderlineStyle.single.rawValue
                        replacements[.cursor] = NSCursor.pointingHand
                    }

                    if !replacements.isEmpty {
                        result.addAttributes(replacements, range: range)
                    }
                }

                return result
            }
        }

        return NSAttributedString(string: text, attributes: [
            .font: t.font,
            .foregroundColor: t.textPrimary
        ])
    }
}
