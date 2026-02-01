import SwiftUI

// MARK: - Scroll Position Tracking
private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Custom Markdown Parser
/// Parses markdown text into styled AttributedString with support for:
/// - Headers (###, ##, #)
/// - Bullet points (*, -)
/// - Numbered lists (1., 2., etc.)
/// - Bold (**text**)
/// - Preserves line breaks and paragraph spacing
private func markdownAttributedString(_ text: String, baseFont: Font = .system(size: 17, weight: .regular)) -> AttributedString {
    var result = AttributedString()
    let lines = text.components(separatedBy: "\n")

    for (index, line) in lines.enumerated() {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)

        // Skip empty lines but preserve paragraph spacing
        if trimmedLine.isEmpty {
            if index > 0 {
                result.append(AttributedString("\n"))
            }
            continue
        }

        // Add newline before non-first lines (except after empty lines which already have one)
        if index > 0 && !lines[index - 1].trimmingCharacters(in: .whitespaces).isEmpty {
            result.append(AttributedString("\n"))
        }

        // Parse the line based on its prefix
        if let headerLine = parseHeader(trimmedLine) {
            result.append(headerLine)
        } else if let bulletLine = parseBulletPoint(trimmedLine) {
            result.append(bulletLine)
        } else if let numberedLine = parseNumberedList(trimmedLine) {
            result.append(numberedLine)
        } else {
            // Regular text - parse inline formatting
            result.append(parseInlineFormatting(trimmedLine))
        }
    }

    return result
}

/// Parses header lines (###, ##, #)
private func parseHeader(_ line: String) -> AttributedString? {
    let patterns: [(prefix: String, size: CGFloat, weight: Font.Weight)] = [
        ("### ", 19, .semibold),  // H3
        ("## ", 21, .semibold),   // H2
        ("# ", 24, .bold)         // H1
    ]

    for pattern in patterns {
        if line.hasPrefix(pattern.prefix) {
            let content = String(line.dropFirst(pattern.prefix.count))
            var attributed = parseInlineFormatting(content)
            attributed.font = .system(size: pattern.size, weight: pattern.weight)

            // Add extra spacing after headers
            var result = AttributedString("\n")
            result.append(attributed)
            return result
        }
    }

    return nil
}

/// Parses bullet point lines (*, -)
private func parseBulletPoint(_ line: String) -> AttributedString? {
    // Match "* " or "- " at the start
    let bulletPrefixes = ["* ", "- ", "• "]

    for prefix in bulletPrefixes {
        if line.hasPrefix(prefix) {
            let content = String(line.dropFirst(prefix.count))
            var bulletText = AttributedString("  •  ")  // Indented bullet
            bulletText.font = .system(size: 17, weight: .regular)

            var contentText = parseInlineFormatting(content)
            contentText.font = .system(size: 17, weight: .regular)

            var result = bulletText
            result.append(contentText)
            return result
        }
    }

    return nil
}

/// Parses numbered list items (1., 2., etc.)
private func parseNumberedList(_ line: String) -> AttributedString? {
    // Match "1. ", "2. ", etc.
    let regex = try? NSRegularExpression(pattern: "^(\\d+)\\.\\s+", options: [])
    let range = NSRange(line.startIndex..., in: line)

    if let match = regex?.firstMatch(in: line, options: [], range: range) {
        let numberRange = Range(match.range(at: 1), in: line)!
        let number = String(line[numberRange])
        let fullMatchRange = Range(match.range, in: line)!
        let content = String(line[fullMatchRange.upperBound...])

        var numberText = AttributedString("  \(number).  ")
        numberText.font = .system(size: 17, weight: .medium)

        var contentText = parseInlineFormatting(content)
        contentText.font = .system(size: 17, weight: .regular)

        var result = numberText
        result.append(contentText)
        return result
    }

    return nil
}

/// Represents an inline formatting match
private struct InlineMatch {
    let range: NSRange
    let type: InlineMatchType
    let content: String
    let url: String?

    enum InlineMatchType {
        case bold
        case link
    }
}

/// Parses inline formatting (**bold** and [text](url) links)
private func parseInlineFormatting(_ text: String) -> AttributedString {
    var result = AttributedString()
    let nsText = text as NSString
    var allMatches: [InlineMatch] = []

    // Find all **bold** patterns
    if let boldPattern = try? NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*", options: []) {
        let boldMatches = boldPattern.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        for match in boldMatches {
            if let contentRange = Range(match.range(at: 1), in: text) {
                allMatches.append(InlineMatch(
                    range: match.range,
                    type: .bold,
                    content: String(text[contentRange]),
                    url: nil
                ))
            }
        }
    }

    // Find all [text](url) link patterns
    if let linkPattern = try? NSRegularExpression(pattern: "\\[([^\\]]+)\\]\\(([^)]+)\\)", options: []) {
        let linkMatches = linkPattern.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        for match in linkMatches {
            if let textRange = Range(match.range(at: 1), in: text),
               let urlRange = Range(match.range(at: 2), in: text) {
                allMatches.append(InlineMatch(
                    range: match.range,
                    type: .link,
                    content: String(text[textRange]),
                    url: String(text[urlRange])
                ))
            }
        }
    }

    // Sort matches by position
    allMatches.sort { $0.range.location < $1.range.location }

    // Process text with matches
    var currentLocation = 0

    for match in allMatches {
        // Skip overlapping matches
        if match.range.location < currentLocation {
            continue
        }

        // Add text before this match
        if match.range.location > currentLocation {
            let beforeRange = NSRange(location: currentLocation, length: match.range.location - currentLocation)
            if let swiftRange = Range(beforeRange, in: text) {
                let beforeText = String(text[swiftRange])
                var attributed = AttributedString(beforeText)
                attributed.font = .system(size: 17, weight: .regular)
                result.append(attributed)
            }
        }

        // Add the formatted content
        switch match.type {
        case .bold:
            var boldText = AttributedString(match.content)
            boldText.font = .system(size: 17, weight: .semibold)
            result.append(boldText)

        case .link:
            var linkText = AttributedString(match.content)
            linkText.font = .system(size: 17, weight: .regular)
            linkText.foregroundColor = Color(hex: "8251EB") // Purple accent color
            linkText.underlineStyle = .single
            if let urlString = match.url, let url = URL(string: urlString) {
                linkText.link = url
            }
            result.append(linkText)
        }

        currentLocation = match.range.location + match.range.length
    }

    // Add remaining text after last match
    if currentLocation < nsText.length {
        let remainingRange = NSRange(location: currentLocation, length: nsText.length - currentLocation)
        if let swiftRange = Range(remainingRange, in: text) {
            let remainingText = String(text[swiftRange])
            var attributed = AttributedString(remainingText)
            attributed.font = .system(size: 17, weight: .regular)
            result.append(attributed)
        }
    }

    // If no matches found, return the whole text
    if allMatches.isEmpty {
        var attributed = AttributedString(text)
        attributed.font = .system(size: 17, weight: .regular)
        return attributed
    }

    return result
}

// MARK: - iOS 18+ Toolbar Background Visibility
extension View {
    @ViewBuilder
    func toolbarBackgroundVisibilityIfAvailable(_ visibility: Visibility, for bars: ToolbarPlacement) -> some View {
        if #available(iOS 18.0, *) {
            self.toolbarBackgroundVisibility(visibility, for: bars)
        } else {
            self
        }
    }
}

// MARK: - Chat Theme (Dark Mode Support)
/// Adaptive colors for AI Event Chat - supports light and dark mode
struct ChatTheme {
    let colorScheme: ColorScheme

    // Backgrounds
    var background: Color {
        colorScheme == .dark ? Color(hex: "000000") : Color(hex: "F2F2F7")
    }
    var inputBackground: Color {
        colorScheme == .dark ? Color(hex: "1C1C1E") : Color.white
    }
    var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1C1C1E") : Color.white.opacity(0.5)
    }
    var inputBarBackground: Color {
        colorScheme == .dark ? Color(hex: "000000").opacity(0.95) : Color.white.opacity(0.7)
    }

    // Text
    var textPrimary: Color {
        colorScheme == .dark ? Color.white : Color(hex: "0D1017")
    }
    var textSecondary: Color {
        colorScheme == .dark ? Color(hex: "9CA3AF") : Color(hex: "83828D")
    }
    var textTertiary: Color {
        colorScheme == .dark ? Color(hex: "6B7280") : Color(hex: "9E9EAA")
    }
    var textTitle: Color {
        colorScheme == .dark ? Color.white : Color(hex: "101828")
    }

    // Placeholder / Disabled
    var placeholder: Color {
        colorScheme == .dark ? Color(hex: "48484A") : Color(hex: "D1D5DC")
    }

    // Primary accent (stays consistent)
    var accent: Color { Color(hex: "8251EB") }
    var accentLight: Color { Color(hex: "A17BF4") }

    // User message bubble - purple in both modes for consistency
    var userBubble: Color {
        colorScheme == .dark ? Color(hex: "3A3A3C") : Color.white
    }

    // User text color - white on dark bubble in dark mode
    var userText: Color {
        colorScheme == .dark ? Color.white : Color(hex: "0D1017")
    }

    // Divider
    var divider: Color {
        colorScheme == .dark ? Color(hex: "38383A") : Color(hex: "FFFFFF").opacity(0.5)
    }

    // Empty state icon
    var emptyIcon: Color {
        colorScheme == .dark ? Color(hex: "48484A") : Color(hex: "D1D5DC")
    }
}

// MARK: - AI Event Chat View
/// Main chat view for AI event assistance - matching Figma design exactly
struct AIEventChatView: View {
    @StateObject private var viewModel: AIEventChatViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isInputFocused: Bool
    @State private var showSavedPage = false
    @State private var isNearBottom = true  // Track if user is at bottom for auto-scroll

    private var theme: ChatTheme { ChatTheme(colorScheme: colorScheme) }

    init(event: Event) {
        _viewModel = StateObject(wrappedValue: AIEventChatViewModel(event: event))
    }

    /// Check if this is the last AI message in the conversation
    private func isLastAIMessage(at index: Int) -> Bool {
        let message = viewModel.messages[index]
        guard !message.isUser else { return false }

        // Check if there are any AI messages after this one
        let remainingMessages = viewModel.messages.suffix(from: index + 1)
        return remainingMessages.allSatisfy { $0.isUser }
    }

    var body: some View {
        ZStack {
            // Background - extends behind navigation bar
            theme.background
                .ignoresSafeArea(.all)

            VStack(spacing: 0) {
                // Chat content
                if viewModel.messages.isEmpty && !isInputFocused {
                    // Welcome section centered when no messages and keyboard not active
                    Spacer()
                    WelcomeSection(
                        onTopicSelected: { topic in
                            viewModel.selectTopic(topic)
                        }
                    )
                    .padding(.horizontal, 16)
                    Spacer()
                } else {
                    // Scrollable chat content
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 0) {
                                // Welcome section at top when keyboard is active
                                if viewModel.messages.isEmpty {
                                    WelcomeSection(
                                        onTopicSelected: { topic in
                                            viewModel.selectTopic(topic)
                                        }
                                    )
                                    .padding(.top, 16)
                                }

                                // Messages
                                ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                                    ChatMessageView(
                                        message: message,
                                        isLastAIMessage: isLastAIMessage(at: index),
                                        isConversationSaved: viewModel.isConversationSaved,
                                        isStreaming: !viewModel.isStreamingComplete,
                                        onToggleChecklistItem: { itemId in
                                            viewModel.toggleChecklistItem(messageId: message.id, itemId: itemId)
                                        },
                                        onSave: {
                                            viewModel.toggleSaveConversation()
                                        },
                                        onAddChecklistItems: {
                                            viewModel.addChecklistItems(messageId: message.id)
                                        },
                                        onApplyAction: {
                                            viewModel.applySuggestedAction(messageId: message.id)
                                        },
                                        onDeclineAction: {
                                            viewModel.declineSuggestedAction(messageId: message.id)
                                        }
                                    )
                                    .id(message.id)
                                }

                                // Typing indicator
                                if viewModel.isTyping {
                                    AITypingIndicatorView()
                                        .padding(.top, 16)
                                        .id("typing-indicator")
                                }

                                // Bottom anchor to detect scroll position
                                GeometryReader { geo in
                                    Color.clear
                                        .preference(
                                            key: ScrollOffsetPreferenceKey.self,
                                            value: geo.frame(in: .named("chatScroll")).maxY
                                        )
                                }
                                .frame(height: 1)

                                // Bottom spacer for input
                                Color.clear.frame(height: 100)
                                    .id("bottom-spacer")
                            }
                            .padding(.horizontal, 16)
                        }
                        .coordinateSpace(name: "chatScroll")
                        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { maxY in
                            // User is near bottom if the bottom anchor is within ~1000pt (typical screen + buffer)
                            isNearBottom = maxY < 1000
                        }
                        .scrollContentBackground(.hidden)
                        .contentMargins(.top, 16, for: .scrollContent)
                        .onChange(of: viewModel.messages.count) { _, _ in
                            // Always scroll when new message is added (user sent or AI started)
                            if let lastMessage = viewModel.messages.last {
                                withAnimation {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                                isNearBottom = true
                            }
                        }
                        .onChange(of: viewModel.isTyping) { _, isTyping in
                            // Scroll to typing indicator only if user is near bottom
                            if isTyping && isNearBottom {
                                withAnimation {
                                    proxy.scrollTo("typing-indicator", anchor: .bottom)
                                }
                            }
                        }
                        .onChange(of: viewModel.messages.last?.content) { _, _ in
                            // Scroll as streaming content updates only if user is near bottom
                            if isNearBottom, let lastMessage = viewModel.messages.last {
                                withAnimation(.easeOut(duration: 0.1)) {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                        .onChange(of: viewModel.scrollToMessageId) { _, messageId in
                            if let messageId {
                                withAnimation {
                                    proxy.scrollTo(messageId, anchor: .center)
                                }
                                viewModel.scrollToMessageId = nil
                            }
                        }
                        .onChange(of: viewModel.isStreamingComplete) { _, isComplete in
                            // Scroll to save button when streaming completes
                            if isComplete && !viewModel.messages.isEmpty {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    proxy.scrollTo("save-button", anchor: .bottom)
                                }
                            }
                        }
                        .onAppear {
                            // Handle pending scroll when returning from saved page
                            if let messageId = viewModel.scrollToMessageId {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation {
                                        proxy.scrollTo(messageId, anchor: .center)
                                    }
                                    viewModel.scrollToMessageId = nil
                                }
                            }
                        }
                    }
                }

                // Input area
                ChatInputBar(
                    text: $viewModel.inputText,
                    isFocused: $isInputFocused,
                    hintText: viewModel.hintText,
                    onSend: {
                        viewModel.sendMessage()
                    }
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top) {
            HStack(spacing: 12) {
                // Back button
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .white : Color(hex: "8251EB"))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }

                // Event pill
                if #available(iOS 26.0, *) {
                    Button { } label: {
                        HStack(spacing: 8) {
                            CachedAsyncImage(url: URL(string: viewModel.event.effectiveCoverImage)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Color(hex: "D1D5DC")
                            }
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())

                            Text(viewModel.event.name)
                                .font(Font.custom("Inter", size: 17))
                                .foregroundColor(theme.textPrimary)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.roundedRectangle(radius: 22))
                    .frame(maxWidth: .infinity)
                } else {
                    HStack(spacing: 8) {
                        CachedAsyncImage(url: URL(string: viewModel.event.effectiveCoverImage)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color(hex: "D1D5DC")
                        }
                        .frame(width: 49, height: 49)
                        .clipShape(Circle())

                        Text(viewModel.event.name)
                            .font(.system(size: 17, weight: .regular))
                            .tracking(-0.87)
                            .foregroundColor(theme.textPrimary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        BlurView(style: colorScheme == .dark ? .dark : .extraLight)
                            .clipShape(RoundedRectangle(cornerRadius: 22))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                }

                // Heart button
                Button {
                    showSavedPage = true
                } label: {
                    Image(systemName: viewModel.isConversationSaved ? "heart.fill" : "heart")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color(hex: "8251EB"))
                }
                .frame(width: 44, height: 44)
                .background(
                    Group {
                        if #available(iOS 26.0, *) {
                            AnyView(Color.clear.glassEffect(.regular.interactive(), in: .circle))
                        } else {
                            AnyView(BlurView(style: colorScheme == .dark ? .dark : .extraLight)
                                .clipShape(Circle()))
                        }
                    }
                )
                .clipShape(Circle())
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .navigationDestination(isPresented: $showSavedPage) {
            SavedChatsView(viewModel: viewModel)
        }
        .task {
            // Only load hints, not chat history (chat should be fresh each session)
            await viewModel.loadChatHints()
        }
        .onChange(of: showSavedPage) { _, isShowing in
            // When returning from saved page, check for pending conversation to load
            if !isShowing, let conversationId = viewModel.pendingConversationId {
                viewModel.pendingConversationId = nil
                Task {
                    await viewModel.loadConversation(conversationId: conversationId)
                }
            }
        }
        .onDisappear {
            viewModel.stopHintRotation()
            viewModel.cancelSendTask()
        }
        .background(theme.background.ignoresSafeArea())
    }
}

// MARK: - Welcome Section
/// Shows AI avatar, title and topic pills - matching Figma node 3103:43663
struct WelcomeSection: View {
    let onTopicSelected: (AITopicType) -> Void
    @Environment(\.colorScheme) private var colorScheme
    private var theme: ChatTheme { ChatTheme(colorScheme: colorScheme) }

    var body: some View {
        VStack(spacing: 0) {
            // Animated AI Avatar - reusing AIAvatarView component
            ZStack {
                AIAvatarView(size: .large, isAnimating: true)

                // Bottom shadow ellipse - per Figma node 3103:43673
                Ellipse()
                    .fill(theme.accent.opacity(0.4))
                    .frame(width: 64, height: 12)
                    .blur(radius: 8)
                    .offset(y: 72)
            }
            .frame(width: 96, height: 121)

            Spacer().frame(height: 32) // Gap per Figma

            // Title - Inter Bold 36px, tracking 0.37 per Figma node 3103:43676
            Text("Hi! I'm Your\nAI Agent")
                .font(.system(size: 36, weight: .bold))
                .tracking(0.37)
                .lineSpacing(9) // 45 - 36 = 9
                .foregroundColor(theme.textTitle)
                .multilineTextAlignment(.center)
                .frame(width: 298)

            // Subtitle and topic pills container - per Figma node 3103:43677
            VStack(alignment: .leading, spacing: 16) {
                // Subtitle - SF Pro Rounded Medium 20px per Figma node 3103:43704
                Text("Let's get started! What interests you most?")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .tracking(0.4)
                    .lineSpacing(8) // 28 - 20 = 8
                    .foregroundColor(theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8) // Gap from title

                // Topic pills - horizontal scroll per Figma node 3103:43678
                AITopicPillsView(onTopicSelected: onTopicSelected)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Chat Message View
/// Individual message bubble with support for text and checklists
struct ChatMessageView: View {
    let message: AIChatMessage
    let isLastAIMessage: Bool
    let isConversationSaved: Bool  // Whether the current conversation is saved
    let isStreaming: Bool  // Whether AI is currently streaming a response
    let onToggleChecklistItem: (String) -> Void
    let onSave: () -> Void
    let onAddChecklistItems: () -> Void
    let onApplyAction: () -> Void
    let onDeclineAction: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    private var theme: ChatTheme { ChatTheme(colorScheme: colorScheme) }

    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
            if message.isUser {
                // User message - right aligned bubble (white in light, dark gray in dark)
                HStack {
                    Spacer(minLength: 60)
                    Text(message.content)
                        .font(.system(size: 17, weight: .medium))
                        .tracking(-0.44)
                        .foregroundColor(theme.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(theme.userBubble)
                        .cornerRadius(24, corners: [.topLeft, .topRight, .bottomLeft])
                }
            } else {
                // AI message - left aligned with avatar
                // Only show if there's content, tool executions, or a suggested action
                let hasContent = !message.content.isEmpty || message.toolExecutions?.isEmpty == false || message.suggestedAction != nil || message.checklist != nil

                if hasContent {
                    HStack(alignment: .top, spacing: 16) {
                        // Reuse AIAvatarView component
                        AIAvatarView(size: .small, isAnimating: false)
                            .frame(width: 64, height: 64)

                        Spacer(minLength: 0)
                    }

                    // Tool executions - show above response
                    if let executions = message.toolExecutions, !executions.isEmpty {
                        ToolExecutionsView(executions: executions)
                            .padding(.top, 8)
                    }

                    // AI text response (always show if content exists) - supports markdown
                    if !message.content.isEmpty {
                        Text(markdownAttributedString(message.content))
                            .font(.system(size: 17, weight: .regular))
                            .tracking(-0.44)
                            .lineSpacing(4)
                            .foregroundColor(theme.textPrimary)
                            .padding(.top, 8)
                    }
                }

                // Suggested action card - show when action exists
                if let action = message.suggestedAction, action.isValid {
                    AISuggestedActionCard(
                        action: action,
                        isApplied: message.actionApplied,
                        onApply: onApplyAction,
                        onDecline: onDeclineAction
                    )
                    .padding(.top, 8)
                }

                // Checklist if present - with contextual "Add to..." button
                if let checklist = message.checklist {
                    let actionType = ChecklistActionType.from(topic: checklist.topic)
                    AIChecklistCard(
                        checklist: checklist,
                        onToggleItem: onToggleChecklistItem,
                        onSave: onSave,
                        isSaved: isConversationSaved,
                        onAddItems: onAddChecklistItems,
                        itemsAdded: message.checklistTasksAdded,
                        actionType: actionType
                    )
                    .padding(.top, 8)
                }

                // "❤ Saved" pill below last AI message - only after streaming completes
                if isLastAIMessage && !isStreaming && !message.content.isEmpty {
                    SavedPillButton(isSaved: isConversationSaved, onTap: onSave)
                        .padding(.top, 8)
                        .transition(.scale.combined(with: .opacity))
                        .id("save-button")
                }
            }
        }
        .padding(.top, 16)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isStreaming)
    }
}

// MARK: - Saved Pill Button
/// Pill button showing save state (per Figma node 3103:43882)
struct SavedPillButton: View {
    let isSaved: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 12))
                Text(isSaved ? "Saved" : "Save")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(isSaved ? .white : Color(hex: "6B7280"))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSaved ? Color(hex: "8251EB") : Color.white)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tool Executions View
/// Shows the tools that were executed during the AI response
struct ToolExecutionsView: View {
    let executions: [ToolExecution]
    @Environment(\.colorScheme) private var colorScheme
    private var theme: ChatTheme { ChatTheme(colorScheme: colorScheme) }

    /// Filter out pending_approval executions since the action card handles those
    private var displayableExecutions: [ToolExecution] {
        executions.filter { !$0.isPendingApproval }
    }

    var body: some View {
        if !displayableExecutions.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(displayableExecutions) { execution in
                    HStack(spacing: 8) {
                        // Status indicator: spinner for in_progress, checkmark/x for complete
                        if execution.isInProgress {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 14, height: 14)
                        } else {
                            Image(systemName: execution.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(execution.isSuccess ? .green : .red)
                        }

                        Image(systemName: execution.icon)
                            .font(.system(size: 11))
                            .foregroundColor(execution.isInProgress ? .rdPrimary : theme.textSecondary)

                        Text(execution.summary)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(execution.isInProgress ? theme.textPrimary : theme.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(theme.cardBackground.opacity(0.6))
            )
        }
    }
}

// MARK: - AI Suggested Action Card
/// Card displaying action buttons for applying AI suggestions
struct AISuggestedActionCard: View {
    let action: SuggestedAction
    let isApplied: Bool
    let onApply: () -> Void
    let onDecline: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var isExpanded = false
    private var theme: ChatTheme { ChatTheme(colorScheme: colorScheme) }

    private var itemsToShow: [SuggestedActionItem] {
        if isExpanded || action.items.count <= 3 {
            return action.items
        }
        return Array(action.items.prefix(3))
    }

    private var hiddenCount: Int {
        action.items.count - 3
    }

    private var appliedMessage: String {
        switch action.actionType {
        case .addTasks:
            return "Tasks added"
        case .removeTasks:
            return "Tasks removed"
        case .updateTasks:
            return "Tasks updated"
        case .addAgenda:
            return "Agenda items added"
        case .removeAgenda:
            return "Agenda items removed"
        case .updateAgenda:
            return "Agenda updated"
        case .addExpenses:
            return "Expenses added"
        case .removeExpenses:
            return "Expenses removed"
        case .updateExpenses:
            return "Expenses updated"
        case .updateBudget:
            return "Budget updated"
        case .none:
            return "Applied"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Prompt text or applied status
            if isApplied {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                    Text(appliedMessage)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.green)
                }
            } else {
                Text(action.promptText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(theme.textSecondary)
            }

            // Items (tappable to expand)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(itemsToShow) { item in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(isApplied ? .green : theme.accent)
                            .frame(width: 6, height: 6)
                        Text(item.title)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(theme.textPrimary)
                    }
                }

                // Show "+X more" hint when collapsed
                if action.items.count > 3 && !isExpanded {
                    Text("+\(hiddenCount) more")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(theme.accent)
                        .padding(.leading, 14)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if action.items.count > 3 {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }
            }

            // Action buttons - only show when not applied
            if !isApplied {
                HStack(spacing: 12) {
                    // Confirm button
                    Button(action: onApply) {
                        Text(action.confirmButtonText)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(theme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Decline button
                    Button(action: onDecline) {
                        Text(action.declineButtonText)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(theme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(theme.divider, lineWidth: 1)
                            )
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.cardBackground)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isApplied ? Color.green.opacity(0.3) : theme.accent.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - AI Typing Indicator View
struct AITypingIndicatorView: View {
    @State private var dotOffsets: [CGFloat] = [0, 0, 0]

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Reuse AIAvatarView component - mini size
            AIAvatarView(size: .mini, isAnimating: true)
                .frame(width: 32, height: 32)

            // Typing dots - purple color, centered with avatar
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color(hex: "8251EB"))
                        .frame(width: 8, height: 8)
                        .offset(y: dotOffsets[index])
                }
            }

            Spacer()
        }
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        for i in 0..<3 {
            withAnimation(
                Animation
                    .easeInOut(duration: 0.4)
                    .repeatForever(autoreverses: true)
                    .delay(Double(i) * 0.15)
            ) {
                dotOffsets[i] = -6
            }
        }
    }
}

// MARK: - Chat Input Bar
/// Matching Figma node 3103:43706
struct ChatInputBar: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    let hintText: String
    let onSend: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    private var theme: ChatTheme { ChatTheme(colorScheme: colorScheme) }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: 13) { // 13.3px per Figma
            // Text field - adaptive bg, 24px corners, shadow per Figma node 3103:43708
            TextField(hintText, text: $text)
                .font(.system(size: 17, weight: .regular))
                .tracking(-0.87)
                .foregroundColor(theme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(height: 49.5) // Per Figma h-[49.5px]
                .background(theme.inputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 3, x: 0, y: 1)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.1), radius: 2, x: 0, y: 1)
                .focused($isFocused)

            // Send button - 49px, 16px corners per Figma node 3103:43711
            Button(action: onSend) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 49, height: 49)
                    .background(canSend ? theme.accent : theme.placeholder)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(!canSend)
        }
        .padding(.leading, 16)
        .padding(.trailing, 17) // 17.3px per Figma
        .frame(height: 84) // Container height per Figma h-[84px]
        .background(
            theme.inputBarBackground
                .overlay(
                    Rectangle()
                        .fill(theme.divider)
                        .frame(height: 1),
                    alignment: .top
                )
        )
    }
}

// MARK: - Saved Checklists View
/// Shows saved checklists - matching Figma node 3103:43927
struct SavedChatsView: View {
    @ObservedObject var viewModel: AIEventChatViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    private var theme: ChatTheme { ChatTheme(colorScheme: colorScheme) }

    var body: some View {
        ZStack {
            // Background
            theme.background
                .ignoresSafeArea()

            if viewModel.isLoadingSaved {
                ProgressView()
                    .tint(theme.accent)
            } else if viewModel.savedConversations.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "heart")
                        .font(.system(size: 64))
                        .foregroundColor(theme.emptyIcon)

                    Text("No saved chats yet")
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundColor(theme.textSecondary)

                    Text("Save a chat to see it here")
                        .font(.system(size: 15))
                        .foregroundColor(theme.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
            } else {
                // Saved conversations list - per Figma design
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(viewModel.savedConversations) { conversation in
                            SavedConversationRow(
                                conversation: conversation,
                                onTap: {
                                    // Set pending conversation, then dismiss
                                    viewModel.pendingConversationId = conversation.conversationId
                                    dismiss()
                                },
                                onUnsave: {
                                    viewModel.unsaveConversation(conversation.conversationId)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
        }
        .task {
            await viewModel.loadSavedConversations()
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top) {
            HStack(spacing: 12) {
                // Back button
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(theme.textPrimary)
                }
                .frame(width: 44, height: 44)

                // Event pill
                if #available(iOS 26.0, *) {
                    Button { } label: {
                        HStack(spacing: 8) {
                            CachedAsyncImage(url: URL(string: viewModel.event.effectiveCoverImage)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Color(hex: "D1D5DC")
                            }
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())

                            Text(viewModel.event.name)
                                .font(Font.custom("Inter", size: 17))
                                .foregroundColor(theme.textPrimary)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.roundedRectangle(radius: 22))
                    .frame(maxWidth: .infinity)
                } else {
                    HStack(spacing: 8) {
                        CachedAsyncImage(url: URL(string: viewModel.event.effectiveCoverImage)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color(hex: "D1D5DC")
                        }
                        .frame(width: 49, height: 49)
                        .clipShape(Circle())

                        Text(viewModel.event.name)
                            .font(.system(size: 17, weight: .regular))
                            .tracking(-0.87)
                            .foregroundColor(theme.textPrimary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        BlurView(style: colorScheme == .dark ? .dark : .extraLight)
                    )
                    .frame(width: 298)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                }

                // Heart button
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.white)
                }
                .frame(width: 44, height: 44)
                .background(Color(hex: "8251EB"))
                .clipShape(Circle())
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
        }
    }
}

// MARK: - Saved Conversation Row
/// Shows saved conversation with title/preview and "Saved" badge - per Figma node 3103:43927
struct SavedConversationRow: View {
    let conversation: SavedConversation
    let onTap: () -> Void
    let onUnsave: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    private var theme: ChatTheme { ChatTheme(colorScheme: colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Conversation title/preview - SF Pro Rounded Medium 20px
            Text(conversation.title.isEmpty ? conversation.preview : conversation.title)
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .tracking(0.4)
                .lineSpacing(8)
                .foregroundColor(theme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            // Message count and date
            HStack(spacing: 8) {
                Text("\(conversation.messageCount) messages")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(theme.textSecondary)

                Text("•")
                    .font(.system(size: 13))
                    .foregroundColor(theme.textTertiary)

                Text(conversation.savedAt, style: .date)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(theme.textSecondary)
            }

            // Saved badge - purple rounded rect with heart
            Button {
                onUnsave()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10))
                    Text("Saved")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(height: 30)
                .padding(.horizontal, 12)
                .background(theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        AIEventChatView(event: Event.preview)
    }
}
