import SwiftUI

// MARK: - Legacy Button Component (Deprecated - Use native Button with .rdButtonStyle() instead)

enum RDButtonStyle {
    case primary
    case secondary
    case outline
    case ghost
    case destructive
}

// MARK: - Native ButtonStyle Implementation

struct RDPrimaryButtonStyle: ButtonStyle {
    var size: RDButtonSize = .large
    var isFullWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.font)
            .fontWeight(.semibold)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .frame(height: size.height)
            .foregroundColor(.white)
            .background(Color.rdAccent)
            .cornerRadius(size == .large ? 16 : 12)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct RDSecondaryButtonStyle: ButtonStyle {
    var size: RDButtonSize = .large
    var isFullWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.font)
            .fontWeight(.semibold)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .frame(height: size.height)
            .foregroundColor(.rdAccent)
            .background(
                ZStack {
                    // White base
                    Color.rdBackgroundSecondary

                    // Subtle glassmorphism overlay
                    Rectangle()
                        .fill(.ultraThinMaterial.opacity(0.3))
                }
            )
            .cornerRadius(size == .large ? 16 : 12)
            .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct RDOutlineButtonStyle: ButtonStyle {
    var size: RDButtonSize = .large
    var isFullWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        let radius: CGFloat = size == .large ? 16 : 12
        configuration.label
            .font(size.font)
            .fontWeight(.semibold)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .frame(height: size.height)
            .foregroundColor(.rdAccent)
            .background(Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(Color.rdAccent, lineWidth: 1.5)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

struct RDGhostButtonStyle: ButtonStyle {
    var size: RDButtonSize = .large
    var isFullWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.font)
            .fontWeight(.semibold)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .frame(height: size.height)
            .foregroundColor(.rdTextSecondary)
            .background(Color.clear)
            .cornerRadius(size == .large ? 16 : 12)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}

struct RDDestructiveButtonStyle: ButtonStyle {
    var size: RDButtonSize = .large
    var isFullWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.font)
            .fontWeight(.semibold)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .frame(height: size.height)
            .foregroundColor(.white)
            .background(Color.rdError)
            .cornerRadius(size == .large ? 16 : 12)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

enum RDButtonStyleType {
    case primary
    case secondary
    case outline
    case ghost
    case destructive
}

// MARK: - View Extension for Easy Usage

extension View {
    func rdButtonStyle(
        _ style: RDButtonStyleType,
        size: RDButtonSize = .large,
        isFullWidth: Bool = true
    ) -> some View {
        switch style {
        case .primary:
            return AnyView(self.buttonStyle(RDPrimaryButtonStyle(size: size, isFullWidth: isFullWidth)))
        case .secondary:
            return AnyView(self.buttonStyle(RDSecondaryButtonStyle(size: size, isFullWidth: isFullWidth)))
        case .outline:
            return AnyView(self.buttonStyle(RDOutlineButtonStyle(size: size, isFullWidth: isFullWidth)))
        case .ghost:
            return AnyView(self.buttonStyle(RDGhostButtonStyle(size: size, isFullWidth: isFullWidth)))
        case .destructive:
            return AnyView(self.buttonStyle(RDDestructiveButtonStyle(size: size, isFullWidth: isFullWidth)))
        }
    }
}

enum RDButtonSize {
    case small
    case medium
    case large

    var height: CGFloat {
        switch self {
        case .small: return 36
        case .medium: return 44
        case .large: return 56
        }
    }

    var font: Font {
        switch self {
        case .small: return .labelMedium
        case .medium: return .titleSmall
        case .large: return .titleMedium
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .small: return 16
        case .medium: return 20
        case .large: return 24
        }
    }
}

struct RDButton: View {
    let title: String
    let style: RDButtonStyle
    let size: RDButtonSize
    let icon: String?
    let iconPosition: IconPosition
    let isLoading: Bool
    let isFullWidth: Bool
    let action: () -> Void

    enum IconPosition {
        case leading
        case trailing
    }

    init(
        _ title: String,
        style: RDButtonStyle = .primary,
        size: RDButtonSize = .large,
        icon: String? = nil,
        iconPosition: IconPosition = .leading,
        isLoading: Bool = false,
        isFullWidth: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.size = size
        self.icon = icon
        self.iconPosition = iconPosition
        self.isLoading = isLoading
        self.isFullWidth = isFullWidth
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(foregroundColor)
                } else {
                    if let icon = icon, iconPosition == .leading {
                        Image(systemName: icon)
                            .font(.system(size: size.iconSize))
                    }

                    Text(title)
                        .font(size.font)
                        .fontWeight(.semibold)

                    if let icon = icon, iconPosition == .trailing {
                        Image(systemName: icon)
                            .font(.system(size: size.iconSize))
                    }
                }
            }
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .frame(height: size.height)
            .foregroundColor(foregroundColor)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: size == .large ? 16 : 12))
            .overlay(
                RoundedRectangle(cornerRadius: size == .large ? 16 : 12)
                    .strokeBorder(borderColor, lineWidth: style == .outline ? 1.5 : 0)
            )
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.7 : 1)
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: return .rdAccent
        case .secondary: return .rdBackgroundSecondary
        case .outline, .ghost: return .clear
        case .destructive: return .rdError
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary, .destructive: return .white
        case .secondary: return .rdTextPrimary
        case .outline: return .rdAccent
        case .ghost: return .rdTextSecondary
        }
    }

    private var borderColor: Color {
        switch style {
        case .outline: return .rdAccent
        default: return .clear
        }
    }
}

// MARK: - Icon Button
struct RDIconButton: View {
    let icon: String
    let size: CGFloat
    let style: RDButtonStyle
    let action: () -> Void

    init(
        icon: String,
        size: CGFloat = 44,
        style: RDButtonStyle = .ghost,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.size = size
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.45))
                .frame(width: size, height: size)
                .foregroundColor(foregroundColor)
                .background(backgroundColor)
                .cornerRadius(size / 2)
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: return .rdAccent
        case .secondary: return .rdBackgroundSecondary
        case .outline, .ghost: return .clear
        case .destructive: return .rdError
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary, .destructive: return .white
        case .secondary, .ghost: return .rdTextPrimary
        case .outline: return .rdAccent
        }
    }
}

// MARK: - Gradient Button

/// Primary gradient button for confirm/add/save actions
/// Uses horizontal gradient from Figma: #8251EB → #A78BFA → #6366F1
struct RDGradientButton: View {
    let title: String
    let icon: String?
    let iconPosition: RDButton.IconPosition
    let isLoading: Bool
    let isEnabled: Bool
    let height: CGFloat
    let cornerRadius: CGFloat
    let includeShadow: Bool
    let action: () -> Void

    /// Gradient colors for the button background
    private static let gradientColors: [Color] = [
        Color(hex: "8251EB"),
        Color(hex: "A78BFA"),
        Color(hex: "6366F1")
    ]

    init(
        _ title: String,
        icon: String? = nil,
        iconPosition: RDButton.IconPosition = .leading,
        isLoading: Bool = false,
        isEnabled: Bool = true,
        height: CGFloat = 48,
        cornerRadius: CGFloat = 12,
        includeShadow: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.iconPosition = iconPosition
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.height = height
        self.cornerRadius = cornerRadius
        self.includeShadow = includeShadow
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    if let icon = icon, iconPosition == .leading {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                    }

                    Text(title)
                        .font(.system(size: 15, weight: .semibold))

                    if let icon = icon, iconPosition == .trailing {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                Group {
                    if isEnabled {
                        LinearGradient(
                            colors: Self.gradientColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else {
                        Color.gray.opacity(0.5)
                    }
                }
            )
            .cornerRadius(cornerRadius)
            .if(includeShadow && isEnabled) { view in
                view.shadow(
                    color: Color.black.opacity(0.1),
                    radius: 10,
                    x: 0,
                    y: 4
                )
            }
        }
        .disabled(!isEnabled || isLoading)
        .opacity(isLoading ? 0.9 : 1.0)
    }
}

/// Button style for gradient buttons with scale animation on press
struct RDGradientButtonStyle: ButtonStyle {
    var height: CGFloat = 48
    var cornerRadius: CGFloat = 12
    var isEnabled: Bool = true
    var includeShadow: Bool = true

    private static let gradientColors: [Color] = [
        Color(hex: "8251EB"),
        Color(hex: "A78BFA"),
        Color(hex: "6366F1")
    ]

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                Group {
                    if isEnabled {
                        LinearGradient(
                            colors: Self.gradientColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else {
                        Color.gray.opacity(0.5)
                    }
                }
            )
            .cornerRadius(cornerRadius)
            .shadow(
                color: includeShadow && isEnabled ? Color.black.opacity(0.1) : Color.clear,
                radius: 10,
                x: 0,
                y: 4
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - View Extension for Gradient Button Style

extension View {
    func rdGradientButtonStyle(
        height: CGFloat = 48,
        cornerRadius: CGFloat = 12,
        isEnabled: Bool = true,
        includeShadow: Bool = true
    ) -> some View {
        self.buttonStyle(RDGradientButtonStyle(
            height: height,
            cornerRadius: cornerRadius,
            isEnabled: isEnabled,
            includeShadow: includeShadow
        ))
    }
}

// MARK: - Close Button
/// Standard close button for edit modals
/// - iOS 26+: Uses liquid glass effect with 44x44 size, gray icon (#999)
/// - Below iOS 26: Uses semi-transparent gray background with 32x32 size
/// Usage: RDCloseButton { dismiss() }
/// Usage with tint: RDCloseButton(tint: Color(hex: "A17BF4")) { dismiss() }
struct RDCloseButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let tint: Color?
    let action: () -> Void

    /// Default gray tint color for pre-iOS 26
    private static let defaultTint = Color(hex: "9C9CA6")
    /// iOS 26 icon color (secondary gray from Figma)
    private static let iOS26IconColor = Color(hex: "999999")
    /// Light mode background color
    private static let lightModeBackground = Color(red: 0.61, green: 0.61, blue: 0.65).opacity(0.2)

    init(tint: Color? = nil, action: @escaping () -> Void) {
        self.tint = tint
        self.action = action
    }

    private var iconColor: Color {
        tint ?? Self.defaultTint
    }

    private var circleBackground: Color {
        if colorScheme == .dark {
            return iconColor.opacity(0.2)
        } else {
            return Self.lightModeBackground
        }
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            // iOS 26+ with liquid glass effect
            // Use same pattern as imagesButton - Button with systemImage parameter
            Button("", systemImage: "xmark", action: action)
                .glassEffect(.regular)
        } else {
            // Pre-iOS 26 matching Figma: 32px circle (16px icon + 8px padding each side)
            Button(action: action) {
                Image("icon_xmark_close")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .foregroundColor(iconColor)
            }
            .frame(width: 32, height: 32)
            .background(
                Circle()
                    .fill(circleBackground)
            )
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Confirm Button
/// Standard confirm/checkmark button for edit modals
/// - iOS 26+: Purple gradient background with white checkmark
/// - Below iOS 26: Purple gradient background with white checkmark
/// Usage: RDConfirmButton { save() }
/// Usage disabled: RDConfirmButton(isEnabled: false) { save() }
struct RDConfirmButton: View {
    let isEnabled: Bool
    let action: () -> Void

    /// Purple gradient colors from Figma
    private static let gradientStart = Color(hex: "A17BF4")  // rgb(161, 123, 244)
    private static let gradientEnd = Color(hex: "8251EB")    // rgb(130, 81, 235)

    init(isEnabled: Bool = true, action: @escaping () -> Void) {
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            // iOS 26+ with purple gradient and glass effect
            // Figma: 44x44px circular, gradient background, 17pt medium white checkmark
            Button(action: action) {
                Image(systemName: "checkmark")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
            }
            .frame(width: 44, height: 44)
            .background(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isEnabled ? [Self.gradientStart, Self.gradientEnd] : [Color.gray.opacity(0.5)],
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading
                        )
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 0)
                    .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 1)
            )
            .glassEffect(.regular.interactive(), in: .circle)
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1.0 : 0.5)
        } else {
            // Pre-iOS 26 matching Figma: 44px pill, 36px inner icon area
            Button(action: action) {
                Image(systemName: "checkmark")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
            }
            .frame(width: 44, height: 44)
            .background(
                Circle()
                    .fill(
                        isEnabled
                            ? AnyShapeStyle(LinearGradient(
                                colors: [Self.gradientStart, Self.gradientEnd],
                                startPoint: .topTrailing,
                                endPoint: .bottomLeading
                              ))
                            : AnyShapeStyle(Color(hex: "9C9CA6").opacity(0.2))
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 0)
                    .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 1)
            )
            .buttonStyle(.plain)
            .disabled(!isEnabled)
        }
    }
}

// MARK: - Floating Add Button Style
/// Standard floating action button with blur background and purple overlay
/// Matches the Tasks page design - use this everywhere for consistency
struct FloatingAddButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            // Blur background
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 56, height: 56)

            // Purple overlay
            Circle()
                .fill(Color(hex: "8251EB").opacity(0.85))
                .frame(width: 56, height: 56)

            // Icon
            configuration.label
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.white)
        }
        .shadow(color: Color(hex: "8251EB").opacity(0.3), radius: 12, x: 0, y: 6)
        .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
        .opacity(configuration.isPressed ? 0.9 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
        .padding(.trailing, 16)
        .padding(.bottom, 34)
    }
}

#Preview {
    VStack(spacing: 16) {
        // Gradient buttons (new style)
        RDGradientButton("Confirm", action: {})
        RDGradientButton("Save", isEnabled: false, action: {})
        RDGradientButton("Add Guest", icon: "plus", action: {})

        Button("Native Gradient") {}
            .rdGradientButtonStyle()

        Divider()

        // Legacy solid buttons
        RDButton("Continue", action: {})
        RDButton("Continue", style: .secondary, action: {})
        RDButton("Continue", style: .outline, action: {})
        RDButton("Continue", style: .destructive, action: {})
        RDButton("Loading", isLoading: true, action: {})
        RDButton("With Icon", icon: "arrow.right", iconPosition: .trailing, action: {})

        HStack {
            RDIconButton(icon: "plus", style: .primary, action: {})
            RDIconButton(icon: "xmark", style: .secondary, action: {})
            RDIconButton(icon: "chevron.left", action: {})
            RDCloseButton(action: {})
            RDConfirmButton(action: {})
            RDConfirmButton(isEnabled: false, action: {})
        }

        Divider()

        // Native button styles
        VStack(spacing: 16) {
            Button("Native Primary") {}
                .rdButtonStyle(.primary)

            Button("Native Outline") {}
                .rdButtonStyle(.outline)

            Button {
                // action
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("With Icon")
                }
            }
            .rdButtonStyle(.secondary)
        }

        Spacer()

        // Floating add button
        ZStack(alignment: .bottomTrailing) {
            Color.clear

            Button {
                // action
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(FloatingAddButtonStyle())
        }
        .frame(height: 100)
    }
    .padding()
}

// MARK: - Edit Sheet Wrapper
/// A reusable edit sheet wrapper that handles iOS version differences
/// - iOS 26+: Uses RDSheetHeader with checkmark save button (no bottom save)
/// - Pre-iOS 26: Uses NavigationStack with toolbar close button and bottom save button
struct RDEditSheet<Content: View>: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let canSave: Bool
    let onSave: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        if #available(iOS 26.0, *) {
            // iOS 26+ with RDSheetHeader
            ZStack {
                Color.rdBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    RDSheetHeader(
                        title: title,
                        canSave: canSave,
                        onDismiss: { dismiss() },
                        onSave: {
                            onSave()
                            dismiss()
                        }
                    )

                    content()
                }
            }
        } else {
            // Pre-iOS 26 with NavigationStack and bottom Save button
            NavigationStack {
                ZStack {
                    Color.rdBackground.ignoresSafeArea()

                    VStack(spacing: 0) {
                        content()

                        // Bottom Save Button (only for pre-iOS 26)
                        Button {
                            onSave()
                            dismiss()
                        } label: {
                            Text("Save")
                        }
                        .rdGradientButtonStyle(isEnabled: canSave)
                        .disabled(!canSave)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                }
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        RDCloseButton(tint: Color(hex: "A17BF4")) { dismiss() }
                    }
                }
            }
        }
    }
}

// MARK: - Sheet Header
/// A reusable sheet header component for iOS 26+ with glass effect buttons
/// Also works on pre-iOS 26 with standard styling
struct RDSheetHeader: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let canSave: Bool
    let onDismiss: () -> Void
    let onSave: () -> Void

    /// Default gray color for disabled state
    private static let disabledColor = Color(hex: "9C9CA6")
    /// Purple color for enabled state
    private static let enabledColor = Color(hex: "8251EB")
    /// Gray color for X button
    private static let xmarkColor = Color(hex: "999999")

    private var titleColor: Color {
        colorScheme == .dark ? .white : Color(hex: "170E0D")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Grabber/handle indicator
            Capsule()
                .fill(Color(hex: "3A3A3C"))
                .frame(width: 36, height: 5)
                .padding(.top, 5)
                .padding(.bottom, 4)

            // Header content
            HStack {
                // X button (left)
                RDCloseButton(action: onDismiss)

                Spacer()

                // Title (center)
                Text(title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(titleColor)
                    .tracking(-0.44)

                Spacer()

                // Checkmark button (right)
                RDConfirmButton(isEnabled: canSave, action: onSave)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }
}
