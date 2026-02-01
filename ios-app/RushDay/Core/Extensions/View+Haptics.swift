import SwiftUI

// MARK: - Scroll Bounce Haptic Modifier

/// A view modifier that provides subtle haptic feedback when the user overscrolls
/// past the top or bottom bounds of a ScrollView.
///
/// Usage:
/// ```swift
/// ScrollView {
///     // content
/// }
/// .scrollBounceHaptic()
/// ```
struct ScrollBounceHapticModifier: ViewModifier {
    @State private var hasTriggeredTop = false
    @State private var hasTriggeredBottom = false

    private let softFeedback = UIImpactFeedbackGenerator(style: .soft)

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.contentOffset.y
                } action: { _, newValue in
                    // Trigger at top bounce (negative offset means overscroll at top)
                    if newValue < -10 && !hasTriggeredTop {
                        softFeedback.impactOccurred(intensity: 0.5)
                        hasTriggeredTop = true
                    } else if newValue >= 0 {
                        hasTriggeredTop = false
                    }
                }
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    // Check if we're at the bottom and overscrolling
                    let contentHeight = geometry.contentSize.height
                    let containerHeight = geometry.containerSize.height
                    let offset = geometry.contentOffset.y
                    let maxOffset = contentHeight - containerHeight
                    return offset > maxOffset + 10
                } action: { _, newValue in
                    if newValue && !hasTriggeredBottom {
                        softFeedback.impactOccurred(intensity: 0.5)
                        hasTriggeredBottom = true
                    } else if !newValue {
                        hasTriggeredBottom = false
                    }
                }
        } else {
            // Fallback for iOS 17 - no scroll bounce haptic (graceful degradation)
            content
        }
    }
}

// MARK: - View Extension

extension View {
    /// Adds subtle haptic feedback when the user overscrolls past the top or bottom
    /// bounds of a ScrollView.
    ///
    /// The haptic uses a soft impact with 0.5 intensity for a non-intrusive feel.
    /// It only triggers once per overscroll to avoid being annoying.
    ///
    /// Note: This feature requires iOS 18+. On iOS 17, this modifier has no effect.
    ///
    /// - Returns: A view with scroll bounce haptic feedback enabled.
    func scrollBounceHaptic() -> some View {
        modifier(ScrollBounceHapticModifier())
    }
}
