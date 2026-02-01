import SwiftUI
import UIKit

// MARK: - Select Mode Toolbar
/// Bottom toolbar for select mode with glass pill buttons
/// Matches Figma design node 3860:14452
/// - iOS 26+: Uses liquid glass effect
/// - Below iOS 26: Uses semi-transparent background with blur
struct SelectModeToolbar: View {
    let isAllSelected: Bool
    let hasSelection: Bool
    let showCompleteButton: Bool
    let canComplete: Bool
    let onSelectAll: () -> Void
    let onDelete: () -> Void
    let onComplete: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    /// Accent color from Figma (#00BB8B)
    private var accentColor: Color { Color(hex: "00BB8B") }
    /// Delete/error color from Figma (#EB4B33)
    private var deleteColor: Color { Color(hex: "EB4B33") }

    init(
        isAllSelected: Bool,
        hasSelection: Bool,
        showCompleteButton: Bool = true,
        canComplete: Bool = true,
        onSelectAll: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onComplete: (() -> Void)? = nil
    ) {
        self.isAllSelected = isAllSelected
        self.hasSelection = hasSelection
        self.showCompleteButton = showCompleteButton
        self.canComplete = canComplete
        self.onSelectAll = onSelectAll
        self.onDelete = onDelete
        self.onComplete = onComplete
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            iOS26Content
        } else {
            legacyContent
        }
    }

    // MARK: - iOS 26+ Glass Effect
    @available(iOS 26.0, *)
    private var iOS26Content: some View {
        HStack {
            // Select All / Deselect All button
            Button(action: onSelectAll) {
                Text(isAllSelected ? "Deselect All" : "Select All")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 12)
                    .frame(height: 48)
            }
            .background {
                Capsule()
                    .fill(.clear)
                    .glassEffect(.regular.interactive(), in: .capsule)
            }

            Spacer()

            HStack(spacing: 16) {
                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(hasSelection ? deleteColor : deleteColor.opacity(0.4))
                        .frame(width: 48, height: 48)
                }
                .background {
                    Capsule()
                        .fill(.clear)
                        .glassEffect(.regular.interactive(), in: .capsule)
                }
                .disabled(!hasSelection)

                // Complete button (optional)
                if showCompleteButton {
                    Button(action: { onComplete?() }) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(canComplete ? accentColor : accentColor.opacity(0.4))
                            .frame(width: 48, height: 48)
                    }
                    .background {
                        Capsule()
                            .fill(.clear)
                            .glassEffect(.regular.interactive(), in: .capsule)
                    }
                    .disabled(!canComplete)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .background(Color.clear.ignoresSafeArea(edges: .bottom))
    }

    // MARK: - Legacy (Pre-iOS 26)
    private var legacyContent: some View {
        HStack {
            // Select All / Deselect All button (no background for pre-iOS 26)
            Button(action: onSelectAll) {
                Text(isAllSelected ? "Deselect All" : "Select All")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 12)
                    .frame(height: 48)
            }

            Spacer()

            HStack(spacing: 16) {
                // Delete button (no background for pre-iOS 26)
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(hasSelection ? deleteColor : deleteColor.opacity(0.4))
                        .frame(width: 48, height: 48)
                }
                .disabled(!hasSelection)

                // Complete button (optional, no background for pre-iOS 26)
                if showCompleteButton {
                    Button(action: { onComplete?() }) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(canComplete ? accentColor : accentColor.opacity(0.4))
                            .frame(width: 48, height: 48)
                    }
                    .disabled(!canComplete)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
    }

}

// MARK: - Preview
#Preview("Select Mode Toolbar") {
    VStack {
        Spacer()
        SelectModeToolbar(
            isAllSelected: false,
            hasSelection: true,
            showCompleteButton: true,
            canComplete: true,
            onSelectAll: {},
            onDelete: {},
            onComplete: {}
        )
    }
    .background(Color(UIColor.systemGroupedBackground))
}

#Preview("Select Mode Toolbar - All Selected") {
    VStack {
        Spacer()
        SelectModeToolbar(
            isAllSelected: true,
            hasSelection: true,
            showCompleteButton: true,
            canComplete: false,
            onSelectAll: {},
            onDelete: {},
            onComplete: {}
        )
    }
    .background(Color(UIColor.systemGroupedBackground))
}

#Preview("Select Mode Toolbar - No Complete") {
    VStack {
        Spacer()
        SelectModeToolbar(
            isAllSelected: false,
            hasSelection: true,
            showCompleteButton: false,
            canComplete: false,
            onSelectAll: {},
            onDelete: {},
            onComplete: nil
        )
    }
    .background(Color(UIColor.systemGroupedBackground))
}
