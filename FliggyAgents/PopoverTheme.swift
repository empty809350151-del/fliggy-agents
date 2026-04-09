import AppKit

struct PopoverTheme {
    let name: String

    // Popover shell
    let popoverBg: NSColor
    let popoverBorder: NSColor
    let popoverBorderWidth: CGFloat
    let popoverCornerRadius: CGFloat
    let surfacePrimary: NSColor
    let surfaceSecondary: NSColor
    let surfaceTertiary: NSColor
    let scrimColor: NSColor

    // Title bar
    let titleBarBg: NSColor
    let titleText: NSColor
    let titleFont: NSFont
    let titleFormat: TitleFormat
    var titleString: String { AgentProvider.current.titleString(format: titleFormat) }
    let separatorColor: NSColor
    let titleIconTint: NSColor
    let titleIconBg: NSColor
    let titleIconHoverBg: NSColor

    // Shared typography
    let font: NSFont
    let fontBold: NSFont
    let textPrimary: NSColor
    let textDim: NSColor
    let accentColor: NSColor
    let errorColor: NSColor
    let successColor: NSColor

    // Composer
    let composerBg: NSColor
    let composerBorder: NSColor
    let composerFocusRing: NSColor
    let composerText: NSColor
    let composerPlaceholder: NSColor
    let composerCornerRadius: CGFloat
    let sendButtonBg: NSColor
    let sendButtonHoverBg: NSColor
    let sendButtonDisabledBg: NSColor
    let sendButtonText: NSColor
    let sendButtonDisabledText: NSColor

    // History
    let historyPanelBg: NSColor
    let historyPanelBorder: NSColor
    let historyRowBg: NSColor
    let historyRowHoverBg: NSColor
    let historyRowSelectedBg: NSColor
    let historyRowBorder: NSColor
    let historyRowSelectedBorder: NSColor
    let historyRowText: NSColor
    let historyRowSelectedText: NSColor
    let historyMetaText: NSColor
    let historyBadgeBg: NSColor
    let historyBadgeText: NSColor

    // Attachments
    let attachmentFileBg: NSColor
    let attachmentFileBorder: NSColor
    let attachmentFileText: NSColor
    let attachmentImageBg: NSColor
    let attachmentImageBorder: NSColor
    let attachmentImageText: NSColor
    let attachmentSkillBg: NSColor
    let attachmentSkillBorder: NSColor
    let attachmentSkillText: NSColor

    // Transcript
    let messageUserBg: NSColor
    let messageUserBorder: NSColor
    let messageUserText: NSColor
    let messageAssistantBg: NSColor
    let messageAssistantBorder: NSColor
    let messageAssistantText: NSColor
    let messageToolBg: NSColor
    let messageToolBorder: NSColor
    let messageToolText: NSColor
    let messageErrorBg: NSColor
    let messageErrorBorder: NSColor
    let messageErrorText: NSColor
    let codeBlockBg: NSColor
    let codeInlineBg: NSColor
    let quoteBarColor: NSColor
    let tableBorderColor: NSColor
    let tableHeaderBg: NSColor

    // Bubble
    let bubbleBg: NSColor
    let bubbleBorder: NSColor
    let bubbleText: NSColor
    let bubbleCompletionBorder: NSColor
    let bubbleCompletionText: NSColor
    let bubbleFont: NSFont
    let bubbleCornerRadius: CGFloat

    // Compatibility aliases
    var inputBg: NSColor { composerBg }
    var inputCornerRadius: CGFloat { composerCornerRadius }

    static let aiChat = PopoverTheme(
        name: "AI Chat",
        popoverBg: dynamicColor(light: rgba(248, 249, 251, 0.98), dark: rgba(23, 24, 28, 0.98)),
        popoverBorder: dynamicColor(light: rgba(229, 231, 235, 1), dark: rgba(43, 46, 54, 1)),
        popoverBorderWidth: 0,
        popoverCornerRadius: 22,
        surfacePrimary: dynamicColor(light: rgba(255, 255, 255, 0.96), dark: rgba(30, 32, 37, 0.96)),
        surfaceSecondary: dynamicColor(light: rgba(244, 246, 248, 0.94), dark: rgba(35, 37, 44, 0.94)),
        surfaceTertiary: dynamicColor(light: rgba(236, 240, 244, 0.94), dark: rgba(41, 44, 52, 0.94)),
        scrimColor: dynamicColor(light: rgba(15, 23, 42, 0.12), dark: rgba(0, 0, 0, 0.28)),
        titleBarBg: dynamicColor(light: rgba(248, 249, 251, 0.9), dark: rgba(23, 24, 28, 0.9)),
        titleText: dynamicColor(light: rgba(17, 24, 39, 1), dark: rgba(243, 244, 246, 1)),
        titleFont: .systemFont(ofSize: 13, weight: .semibold),
        titleFormat: .capitalized,
        separatorColor: dynamicColor(light: rgba(229, 231, 235, 0), dark: rgba(43, 46, 54, 0)),
        titleIconTint: dynamicColor(light: rgba(75, 85, 99, 1), dark: rgba(199, 208, 220, 1)),
        titleIconBg: .clear,
        titleIconHoverBg: dynamicColor(light: rgba(233, 236, 241, 1), dark: rgba(43, 46, 54, 1)),
        font: .systemFont(ofSize: 13, weight: .regular),
        fontBold: .systemFont(ofSize: 13, weight: .semibold),
        textPrimary: dynamicColor(light: rgba(17, 24, 39, 1), dark: rgba(243, 244, 246, 1)),
        textDim: dynamicColor(light: rgba(107, 114, 128, 1), dark: rgba(154, 163, 175, 1)),
        accentColor: dynamicColor(light: rgba(15, 118, 209, 1), dark: rgba(102, 185, 255, 1)),
        errorColor: dynamicColor(light: rgba(180, 35, 24, 1), dark: rgba(255, 138, 128, 1)),
        successColor: dynamicColor(light: rgba(15, 118, 92, 1), dark: rgba(94, 214, 179, 1)),
        composerBg: dynamicColor(light: rgba(255, 255, 255, 0.98), dark: rgba(31, 33, 39, 0.98)),
        composerBorder: dynamicColor(light: rgba(216, 221, 228, 1), dark: rgba(53, 57, 66, 1)),
        composerFocusRing: dynamicColor(light: rgba(138, 200, 255, 1), dark: rgba(102, 185, 255, 1)),
        composerText: dynamicColor(light: rgba(17, 24, 39, 1), dark: rgba(249, 250, 251, 1)),
        composerPlaceholder: dynamicColor(light: rgba(138, 145, 158, 1), dark: rgba(143, 151, 164, 1)),
        composerCornerRadius: 18,
        sendButtonBg: dynamicColor(light: rgba(17, 24, 39, 1), dark: rgba(243, 244, 246, 1)),
        sendButtonHoverBg: dynamicColor(light: rgba(31, 41, 55, 1), dark: rgba(255, 255, 255, 1)),
        sendButtonDisabledBg: dynamicColor(light: rgba(234, 236, 240, 1), dark: rgba(42, 45, 52, 1)),
        sendButtonText: dynamicColor(light: rgba(255, 255, 255, 1), dark: rgba(15, 23, 42, 1)),
        sendButtonDisabledText: dynamicColor(light: rgba(163, 171, 183, 1), dark: rgba(107, 114, 128, 1)),
        historyPanelBg: dynamicColor(light: rgba(244, 246, 249, 0.98), dark: rgba(26, 28, 34, 0.98)),
        historyPanelBorder: dynamicColor(light: rgba(229, 231, 235, 1), dark: rgba(43, 46, 54, 1)),
        historyRowBg: .clear,
        historyRowHoverBg: dynamicColor(light: rgba(235, 238, 242, 1), dark: rgba(35, 38, 45, 1)),
        historyRowSelectedBg: dynamicColor(light: rgba(229, 241, 255, 1), dark: rgba(24, 48, 74, 1)),
        historyRowBorder: .clear,
        historyRowSelectedBorder: dynamicColor(light: rgba(191, 219, 254, 1), dark: rgba(29, 78, 137, 1)),
        historyRowText: dynamicColor(light: rgba(31, 41, 55, 1), dark: rgba(229, 231, 235, 1)),
        historyRowSelectedText: dynamicColor(light: rgba(15, 23, 42, 1), dark: rgba(248, 250, 252, 1)),
        historyMetaText: dynamicColor(light: rgba(122, 132, 147, 1), dark: rgba(139, 149, 163, 1)),
        historyBadgeBg: dynamicColor(light: rgba(224, 236, 255, 1), dark: rgba(27, 58, 91, 1)),
        historyBadgeText: dynamicColor(light: rgba(29, 78, 137, 1), dark: rgba(191, 219, 254, 1)),
        attachmentFileBg: dynamicColor(light: rgba(236, 247, 248, 1), dark: rgba(17, 53, 57, 1)),
        attachmentFileBorder: dynamicColor(light: rgba(199, 235, 238, 1), dark: rgba(27, 74, 79, 1)),
        attachmentFileText: dynamicColor(light: rgba(15, 109, 119, 1), dark: rgba(138, 235, 241, 1)),
        attachmentImageBg: dynamicColor(light: rgba(238, 244, 255, 1), dark: rgba(17, 36, 64, 1)),
        attachmentImageBorder: dynamicColor(light: rgba(214, 228, 255, 1), dark: rgba(29, 63, 106, 1)),
        attachmentImageText: dynamicColor(light: rgba(29, 78, 137, 1), dark: rgba(158, 197, 255, 1)),
        attachmentSkillBg: dynamicColor(light: rgba(255, 244, 230, 1), dark: rgba(59, 43, 15, 1)),
        attachmentSkillBorder: dynamicColor(light: rgba(253, 220, 183, 1), dark: rgba(99, 71, 22, 1)),
        attachmentSkillText: dynamicColor(light: rgba(154, 87, 16, 1), dark: rgba(255, 210, 138, 1)),
        messageUserBg: dynamicColor(light: rgba(232, 240, 255, 1), dark: rgba(28, 45, 69, 1)),
        messageUserBorder: dynamicColor(light: rgba(209, 228, 255, 1), dark: rgba(42, 74, 114, 1)),
        messageUserText: dynamicColor(light: rgba(15, 23, 42, 1), dark: rgba(245, 249, 255, 1)),
        messageAssistantBg: dynamicColor(light: rgba(255, 255, 255, 0.92), dark: rgba(32, 34, 40, 0.94)),
        messageAssistantBorder: dynamicColor(light: rgba(231, 233, 238, 1), dark: rgba(50, 53, 61, 1)),
        messageAssistantText: dynamicColor(light: rgba(17, 24, 39, 1), dark: rgba(243, 244, 246, 1)),
        messageToolBg: dynamicColor(light: rgba(247, 248, 250, 1), dark: rgba(27, 29, 34, 1)),
        messageToolBorder: dynamicColor(light: rgba(229, 231, 235, 1), dark: rgba(43, 46, 54, 1)),
        messageToolText: dynamicColor(light: rgba(92, 102, 116, 1), dark: rgba(167, 175, 186, 1)),
        messageErrorBg: dynamicColor(light: rgba(254, 242, 242, 1), dark: rgba(58, 27, 29, 1)),
        messageErrorBorder: dynamicColor(light: rgba(254, 205, 211, 1), dark: rgba(108, 43, 51, 1)),
        messageErrorText: dynamicColor(light: rgba(180, 35, 24, 1), dark: rgba(255, 180, 171, 1)),
        codeBlockBg: dynamicColor(light: rgba(245, 247, 250, 1), dark: rgba(21, 23, 29, 1)),
        codeInlineBg: dynamicColor(light: rgba(241, 244, 248, 1), dark: rgba(42, 45, 52, 1)),
        quoteBarColor: dynamicColor(light: rgba(191, 200, 212, 1), dark: rgba(75, 85, 99, 1)),
        tableBorderColor: dynamicColor(light: rgba(224, 229, 235, 1), dark: rgba(55, 59, 68, 1)),
        tableHeaderBg: dynamicColor(light: rgba(244, 246, 248, 1), dark: rgba(37, 40, 48, 1)),
        bubbleBg: dynamicColor(light: rgba(255, 255, 255, 0.96), dark: rgba(36, 38, 44, 0.96)),
        bubbleBorder: dynamicColor(light: rgba(216, 221, 228, 1), dark: rgba(53, 57, 66, 1)),
        bubbleText: dynamicColor(light: rgba(92, 95, 102, 1), dark: rgba(199, 208, 220, 1)),
        bubbleCompletionBorder: dynamicColor(light: rgba(183, 235, 213, 1), dark: rgba(27, 92, 75, 1)),
        bubbleCompletionText: dynamicColor(light: rgba(15, 118, 92, 1), dark: rgba(121, 226, 198, 1)),
        bubbleFont: .systemFont(ofSize: 11, weight: .medium),
        bubbleCornerRadius: 16
    )

    static let teenageEngineering = legacyTheme(
        name: "Midnight",
        popoverBg: rgba(18, 18, 19, 0.98),
        popoverBorder: rgba(255, 102, 26, 0.55),
        titleBarBg: rgba(20, 20, 22, 1),
        titleText: rgba(255, 102, 26, 1),
        titleFont: NSFont(name: "SFMono-Bold", size: 10) ?? .monospacedSystemFont(ofSize: 10, weight: .bold),
        titleFormat: .uppercase,
        separatorColor: rgba(255, 102, 26, 0.2),
        iconTint: rgba(255, 155, 103, 1),
        iconHoverBg: rgba(42, 30, 24, 1),
        font: NSFont(name: "SFMono-Regular", size: 11.5) ?? .monospacedSystemFont(ofSize: 11.5, weight: .regular),
        fontBold: NSFont(name: "SFMono-Medium", size: 11.5) ?? .monospacedSystemFont(ofSize: 11.5, weight: .medium),
        textPrimary: .white,
        textDim: rgba(149, 149, 160, 1),
        accentColor: rgba(255, 102, 26, 1),
        composerBg: rgba(23, 23, 27, 1),
        composerBorder: rgba(51, 39, 34, 1),
        composerFocusRing: rgba(255, 102, 26, 0.55),
        sendButtonBg: rgba(255, 102, 26, 1),
        sendButtonText: rgba(20, 20, 22, 1),
        historyPanelBg: rgba(18, 18, 21, 0.98),
        historyPanelBorder: rgba(44, 33, 29, 1),
        messageUserBg: rgba(39, 37, 56, 1),
        messageUserBorder: rgba(68, 59, 103, 1),
        messageAssistantBg: rgba(24, 24, 28, 1),
        messageAssistantBorder: rgba(43, 43, 49, 1),
        toolBg: rgba(20, 20, 24, 1),
        codeBg: rgba(16, 16, 19, 1),
        bubbleBg: rgba(20, 20, 22, 0.95),
        bubbleBorder: rgba(255, 102, 26, 0.45),
        bubbleText: rgba(196, 196, 204, 1)
    )

    static let playful = legacyTheme(
        name: "Peach",
        popoverBg: rgba(255, 248, 242, 0.98),
        popoverBorder: rgba(243, 168, 178, 0.75),
        titleBarBg: rgba(254, 241, 234, 1),
        titleText: rgba(212, 88, 108, 1),
        titleFont: .systemFont(ofSize: 12, weight: .heavy),
        titleFormat: .lowercaseTilde,
        separatorColor: rgba(243, 168, 178, 0.22),
        iconTint: rgba(199, 90, 104, 1),
        iconHoverBg: rgba(250, 228, 232, 1),
        font: .systemFont(ofSize: 12, weight: .regular),
        fontBold: .systemFont(ofSize: 12, weight: .semibold),
        textPrimary: rgba(50, 42, 49, 1),
        textDim: rgba(123, 112, 121, 1),
        accentColor: rgba(212, 88, 108, 1),
        composerBg: rgba(255, 255, 255, 0.9),
        composerBorder: rgba(245, 214, 217, 1),
        composerFocusRing: rgba(243, 168, 178, 1),
        sendButtonBg: rgba(212, 88, 108, 1),
        sendButtonText: .white,
        historyPanelBg: rgba(255, 251, 248, 0.98),
        historyPanelBorder: rgba(245, 214, 217, 1),
        messageUserBg: rgba(250, 225, 230, 1),
        messageUserBorder: rgba(245, 199, 207, 1),
        messageAssistantBg: rgba(255, 255, 255, 0.92),
        messageAssistantBorder: rgba(245, 225, 221, 1),
        toolBg: rgba(254, 244, 241, 1),
        codeBg: rgba(251, 245, 241, 1),
        bubbleBg: rgba(255, 247, 242, 0.95),
        bubbleBorder: rgba(243, 168, 178, 0.45),
        bubbleText: rgba(110, 97, 103, 1)
    )

    static let wii = legacyTheme(
        name: "Cloud",
        popoverBg: rgba(244, 246, 248, 0.98),
        popoverBorder: rgba(207, 213, 222, 1),
        titleBarBg: rgba(237, 241, 245, 1),
        titleText: rgba(58, 68, 84, 1),
        titleFont: .systemFont(ofSize: 12, weight: .semibold),
        titleFormat: .lowercaseTilde,
        separatorColor: rgba(216, 222, 231, 1),
        iconTint: rgba(90, 108, 131, 1),
        iconHoverBg: rgba(224, 231, 239, 1),
        font: .systemFont(ofSize: 12, weight: .regular),
        fontBold: .systemFont(ofSize: 12, weight: .semibold),
        textPrimary: rgba(24, 31, 42, 1),
        textDim: rgba(112, 122, 137, 1),
        accentColor: rgba(10, 115, 204, 1),
        composerBg: .white,
        composerBorder: rgba(211, 219, 231, 1),
        composerFocusRing: rgba(148, 202, 255, 1),
        sendButtonBg: rgba(10, 115, 204, 1),
        sendButtonText: .white,
        historyPanelBg: rgba(247, 249, 251, 0.98),
        historyPanelBorder: rgba(216, 222, 231, 1),
        messageUserBg: rgba(216, 235, 255, 1),
        messageUserBorder: rgba(183, 216, 250, 1),
        messageAssistantBg: .white,
        messageAssistantBorder: rgba(225, 231, 239, 1),
        toolBg: rgba(242, 246, 250, 1),
        codeBg: rgba(245, 248, 252, 1),
        bubbleBg: rgba(245, 247, 250, 0.95),
        bubbleBorder: rgba(201, 215, 234, 1),
        bubbleText: rgba(108, 116, 130, 1)
    )

    static let iPod = legacyTheme(
        name: "Moss",
        popoverBg: rgba(213, 217, 202, 0.98),
        popoverBorder: rgba(139, 146, 125, 0.85),
        titleBarBg: rgba(199, 204, 188, 1),
        titleText: rgba(29, 34, 24, 1),
        titleFont: NSFont(name: "Chicago", size: 11) ?? .systemFont(ofSize: 11, weight: .bold),
        titleFormat: .capitalized,
        separatorColor: rgba(152, 158, 139, 1),
        iconTint: rgba(49, 57, 41, 1),
        iconHoverBg: rgba(185, 190, 175, 1),
        font: NSFont(name: "Geneva", size: 11) ?? .systemFont(ofSize: 11, weight: .regular),
        fontBold: NSFont(name: "Geneva", size: 11) ?? .systemFont(ofSize: 11, weight: .semibold),
        textPrimary: rgba(26, 32, 22, 1),
        textDim: rgba(79, 86, 70, 1),
        accentColor: rgba(63, 75, 52, 1),
        composerBg: rgba(235, 238, 228, 1),
        composerBorder: rgba(162, 169, 152, 1),
        composerFocusRing: rgba(93, 108, 74, 0.5),
        sendButtonBg: rgba(63, 75, 52, 1),
        sendButtonText: rgba(248, 250, 242, 1),
        historyPanelBg: rgba(217, 221, 208, 0.98),
        historyPanelBorder: rgba(154, 161, 142, 1),
        messageUserBg: rgba(201, 213, 195, 1),
        messageUserBorder: rgba(160, 171, 156, 1),
        messageAssistantBg: rgba(230, 234, 222, 1),
        messageAssistantBorder: rgba(182, 188, 173, 1),
        toolBg: rgba(211, 216, 201, 1),
        codeBg: rgba(216, 221, 208, 1),
        bubbleBg: rgba(215, 219, 206, 0.95),
        bubbleBorder: rgba(160, 167, 148, 1),
        bubbleText: rgba(85, 90, 80, 1)
    )

    static let allThemes: [PopoverTheme] = [.aiChat, .playful, .teenageEngineering, .wii, .iPod]

    private static let themeKey = "selectedThemeName"

    static var current: PopoverTheme {
        get {
            if let saved = UserDefaults.standard.string(forKey: themeKey),
               let match = allThemes.first(where: { $0.name == saved }) {
                return match
            }
            return .aiChat
        }
        set {
            UserDefaults.standard.set(newValue.name, forKey: themeKey)
        }
    }

    static var customFontName: String? = ".AppleSystemUIFontRounded"
    static var customFontSize: CGFloat = 13

    func withCharacterColor(_ color: NSColor) -> PopoverTheme {
        guard name == PopoverTheme.aiChat.name || name == PopoverTheme.playful.name else { return self }

        let rgbColor = color.usingColorSpace(.deviceRGB) ?? color
        let softTint = NSColor(
            red: min(rgbColor.redComponent * 0.18 + 0.88, 1),
            green: min(rgbColor.greenComponent * 0.18 + 0.88, 1),
            blue: min(rgbColor.blueComponent * 0.18 + 0.88, 1),
            alpha: 1
        )
        let hoverTint = NSColor(
            red: min(rgbColor.redComponent * 0.12 + 0.84, 1),
            green: min(rgbColor.greenComponent * 0.12 + 0.84, 1),
            blue: min(rgbColor.blueComponent * 0.12 + 0.84, 1),
            alpha: 1
        )

        return replacing(
            titleText: rgbColor,
            accentColor: rgbColor,
            composerFocusRing: rgbColor.withAlphaComponent(0.42),
            titleIconHoverBg: hoverTint,
            historyRowSelectedBg: softTint,
            historyRowSelectedBorder: rgbColor.withAlphaComponent(0.38),
            historyBadgeBg: softTint,
            historyBadgeText: rgbColor,
            messageUserBg: softTint,
            messageUserBorder: rgbColor.withAlphaComponent(0.24),
            quoteBarColor: rgbColor.withAlphaComponent(0.42)
        )
    }

    func withCustomFont() -> PopoverTheme {
        guard name != PopoverTheme.teenageEngineering.name else { return self }
        guard let fontName = PopoverTheme.customFontName,
              let baseFont = NSFont(name: fontName, size: PopoverTheme.customFontSize) else {
            return self
        }

        let boldFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
        let smallFont = NSFont(name: fontName, size: PopoverTheme.customFontSize - 1) ?? baseFont

        return replacing(font: baseFont, fontBold: boldFont, bubbleFont: smallFont)
    }

    private func replacing(
        titleText: NSColor? = nil,
        font: NSFont? = nil,
        fontBold: NSFont? = nil,
        accentColor: NSColor? = nil,
        composerFocusRing: NSColor? = nil,
        titleIconHoverBg: NSColor? = nil,
        historyRowSelectedBg: NSColor? = nil,
        historyRowSelectedBorder: NSColor? = nil,
        historyBadgeBg: NSColor? = nil,
        historyBadgeText: NSColor? = nil,
        messageUserBg: NSColor? = nil,
        messageUserBorder: NSColor? = nil,
        bubbleFont: NSFont? = nil,
        quoteBarColor: NSColor? = nil
    ) -> PopoverTheme {
        PopoverTheme(
            name: name,
            popoverBg: popoverBg,
            popoverBorder: popoverBorder,
            popoverBorderWidth: popoverBorderWidth,
            popoverCornerRadius: popoverCornerRadius,
            surfacePrimary: surfacePrimary,
            surfaceSecondary: surfaceSecondary,
            surfaceTertiary: surfaceTertiary,
            scrimColor: scrimColor,
            titleBarBg: titleBarBg,
            titleText: titleText ?? self.titleText,
            titleFont: titleFont,
            titleFormat: titleFormat,
            separatorColor: separatorColor,
            titleIconTint: titleIconTint,
            titleIconBg: titleIconBg,
            titleIconHoverBg: titleIconHoverBg ?? self.titleIconHoverBg,
            font: font ?? self.font,
            fontBold: fontBold ?? self.fontBold,
            textPrimary: textPrimary,
            textDim: textDim,
            accentColor: accentColor ?? self.accentColor,
            errorColor: errorColor,
            successColor: successColor,
            composerBg: composerBg,
            composerBorder: composerBorder,
            composerFocusRing: composerFocusRing ?? self.composerFocusRing,
            composerText: composerText,
            composerPlaceholder: composerPlaceholder,
            composerCornerRadius: composerCornerRadius,
            sendButtonBg: sendButtonBg,
            sendButtonHoverBg: sendButtonHoverBg,
            sendButtonDisabledBg: sendButtonDisabledBg,
            sendButtonText: sendButtonText,
            sendButtonDisabledText: sendButtonDisabledText,
            historyPanelBg: historyPanelBg,
            historyPanelBorder: historyPanelBorder,
            historyRowBg: historyRowBg,
            historyRowHoverBg: historyRowHoverBg,
            historyRowSelectedBg: historyRowSelectedBg ?? self.historyRowSelectedBg,
            historyRowBorder: historyRowBorder,
            historyRowSelectedBorder: historyRowSelectedBorder ?? self.historyRowSelectedBorder,
            historyRowText: historyRowText,
            historyRowSelectedText: historyRowSelectedText,
            historyMetaText: historyMetaText,
            historyBadgeBg: historyBadgeBg ?? self.historyBadgeBg,
            historyBadgeText: historyBadgeText ?? self.historyBadgeText,
            attachmentFileBg: attachmentFileBg,
            attachmentFileBorder: attachmentFileBorder,
            attachmentFileText: attachmentFileText,
            attachmentImageBg: attachmentImageBg,
            attachmentImageBorder: attachmentImageBorder,
            attachmentImageText: attachmentImageText,
            attachmentSkillBg: attachmentSkillBg,
            attachmentSkillBorder: attachmentSkillBorder,
            attachmentSkillText: attachmentSkillText,
            messageUserBg: messageUserBg ?? self.messageUserBg,
            messageUserBorder: messageUserBorder ?? self.messageUserBorder,
            messageUserText: messageUserText,
            messageAssistantBg: messageAssistantBg,
            messageAssistantBorder: messageAssistantBorder,
            messageAssistantText: messageAssistantText,
            messageToolBg: messageToolBg,
            messageToolBorder: messageToolBorder,
            messageToolText: messageToolText,
            messageErrorBg: messageErrorBg,
            messageErrorBorder: messageErrorBorder,
            messageErrorText: messageErrorText,
            codeBlockBg: codeBlockBg,
            codeInlineBg: codeInlineBg,
            quoteBarColor: quoteBarColor ?? self.quoteBarColor,
            tableBorderColor: tableBorderColor,
            tableHeaderBg: tableHeaderBg,
            bubbleBg: bubbleBg,
            bubbleBorder: bubbleBorder,
            bubbleText: bubbleText,
            bubbleCompletionBorder: bubbleCompletionBorder,
            bubbleCompletionText: bubbleCompletionText,
            bubbleFont: bubbleFont ?? self.bubbleFont,
            bubbleCornerRadius: bubbleCornerRadius
        )
    }

    private static func legacyTheme(
        name: String,
        popoverBg: NSColor,
        popoverBorder: NSColor,
        titleBarBg: NSColor,
        titleText: NSColor,
        titleFont: NSFont,
        titleFormat: TitleFormat,
        separatorColor: NSColor,
        iconTint: NSColor,
        iconHoverBg: NSColor,
        font: NSFont,
        fontBold: NSFont,
        textPrimary: NSColor,
        textDim: NSColor,
        accentColor: NSColor,
        composerBg: NSColor,
        composerBorder: NSColor,
        composerFocusRing: NSColor,
        sendButtonBg: NSColor,
        sendButtonText: NSColor,
        historyPanelBg: NSColor,
        historyPanelBorder: NSColor,
        messageUserBg: NSColor,
        messageUserBorder: NSColor,
        messageAssistantBg: NSColor,
        messageAssistantBorder: NSColor,
        toolBg: NSColor,
        codeBg: NSColor,
        bubbleBg: NSColor,
        bubbleBorder: NSColor,
        bubbleText: NSColor
    ) -> PopoverTheme {
        PopoverTheme(
            name: name,
            popoverBg: popoverBg,
            popoverBorder: popoverBorder,
            popoverBorderWidth: 1.5,
            popoverCornerRadius: 16,
            surfacePrimary: messageAssistantBg,
            surfaceSecondary: toolBg,
            surfaceTertiary: composerBg,
            scrimColor: rgba(0, 0, 0, 0.16),
            titleBarBg: titleBarBg,
            titleText: titleText,
            titleFont: titleFont,
            titleFormat: titleFormat,
            separatorColor: separatorColor,
            titleIconTint: iconTint,
            titleIconBg: .clear,
            titleIconHoverBg: iconHoverBg,
            font: font,
            fontBold: fontBold,
            textPrimary: textPrimary,
            textDim: textDim,
            accentColor: accentColor,
            errorColor: blend(textPrimary, with: .systemRed, amount: 0.6),
            successColor: blend(textPrimary, with: .systemGreen, amount: 0.6),
            composerBg: composerBg,
            composerBorder: composerBorder,
            composerFocusRing: composerFocusRing,
            composerText: textPrimary,
            composerPlaceholder: textDim,
            composerCornerRadius: 14,
            sendButtonBg: sendButtonBg,
            sendButtonHoverBg: sendButtonBg.withAlphaComponent(0.88),
            sendButtonDisabledBg: composerBorder.withAlphaComponent(0.65),
            sendButtonText: sendButtonText,
            sendButtonDisabledText: textDim,
            historyPanelBg: historyPanelBg,
            historyPanelBorder: historyPanelBorder,
            historyRowBg: .clear,
            historyRowHoverBg: composerBg.withAlphaComponent(0.82),
            historyRowSelectedBg: messageUserBg,
            historyRowBorder: .clear,
            historyRowSelectedBorder: messageUserBorder,
            historyRowText: textPrimary,
            historyRowSelectedText: textPrimary,
            historyMetaText: textDim,
            historyBadgeBg: messageUserBg,
            historyBadgeText: accentColor,
            attachmentFileBg: blend(composerBg, with: .systemTeal, amount: 0.16),
            attachmentFileBorder: blend(composerBorder, with: .systemTeal, amount: 0.25),
            attachmentFileText: blend(textPrimary, with: .systemTeal, amount: 0.42),
            attachmentImageBg: blend(composerBg, with: .systemBlue, amount: 0.14),
            attachmentImageBorder: blend(composerBorder, with: .systemBlue, amount: 0.25),
            attachmentImageText: blend(textPrimary, with: .systemBlue, amount: 0.38),
            attachmentSkillBg: blend(composerBg, with: .systemOrange, amount: 0.2),
            attachmentSkillBorder: blend(composerBorder, with: .systemOrange, amount: 0.32),
            attachmentSkillText: blend(textPrimary, with: .systemOrange, amount: 0.45),
            messageUserBg: messageUserBg,
            messageUserBorder: messageUserBorder,
            messageUserText: textPrimary,
            messageAssistantBg: messageAssistantBg,
            messageAssistantBorder: messageAssistantBorder,
            messageAssistantText: textPrimary,
            messageToolBg: toolBg,
            messageToolBorder: composerBorder.withAlphaComponent(0.65),
            messageToolText: textDim,
            messageErrorBg: blend(toolBg, with: .systemRed, amount: 0.16),
            messageErrorBorder: blend(composerBorder, with: .systemRed, amount: 0.28),
            messageErrorText: blend(textPrimary, with: .systemRed, amount: 0.55),
            codeBlockBg: codeBg,
            codeInlineBg: composerBg.withAlphaComponent(0.92),
            quoteBarColor: accentColor.withAlphaComponent(0.5),
            tableBorderColor: composerBorder,
            tableHeaderBg: toolBg,
            bubbleBg: bubbleBg,
            bubbleBorder: bubbleBorder,
            bubbleText: bubbleText,
            bubbleCompletionBorder: blend(bubbleBorder, with: .systemGreen, amount: 0.55),
            bubbleCompletionText: blend(bubbleText, with: .systemGreen, amount: 0.55),
            bubbleFont: font.withSize(max(font.pointSize - 1, 10)),
            bubbleCornerRadius: 14
        )
    }
}

private func dynamicColor(light: NSColor, dark: NSColor) -> NSColor {
    NSColor(name: nil) { appearance in
        let match = appearance.bestMatch(from: [.darkAqua, .aqua]) ?? .aqua
        return match == .darkAqua ? dark : light
    }
}

private func rgba(_ red: Int, _ green: Int, _ blue: Int, _ alpha: CGFloat) -> NSColor {
    NSColor(
        red: CGFloat(red) / 255,
        green: CGFloat(green) / 255,
        blue: CGFloat(blue) / 255,
        alpha: alpha
    )
}

private func blend(_ color: NSColor, with other: NSColor, amount: CGFloat) -> NSColor {
    let lhs = color.usingColorSpace(.deviceRGB) ?? color
    let rhs = other.usingColorSpace(.deviceRGB) ?? other
    let mix = max(0, min(amount, 1))
    return NSColor(
        red: lhs.redComponent + (rhs.redComponent - lhs.redComponent) * mix,
        green: lhs.greenComponent + (rhs.greenComponent - lhs.greenComponent) * mix,
        blue: lhs.blueComponent + (rhs.blueComponent - lhs.blueComponent) * mix,
        alpha: lhs.alphaComponent + (rhs.alphaComponent - lhs.alphaComponent) * mix
    )
}
