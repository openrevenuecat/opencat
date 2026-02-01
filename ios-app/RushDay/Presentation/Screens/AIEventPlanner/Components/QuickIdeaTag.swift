import SwiftUI

// MARK: - Quick Idea Tag

struct QuickIdeaTag: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : Color(hex: "364153"))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    isSelected
                    ? LinearGradient(
                        gradient: Gradient(colors: [Color(hex: "8251EB"), Color(hex: "A78BFA")]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    : LinearGradient(
                        gradient: Gradient(colors: [Color.white, Color.white]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            isSelected ? Color.clear : Color(hex: "E5E7EB"),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: isSelected ? Color(hex: "8251EB").opacity(0.2) : Color.clear,
                    radius: 4,
                    x: 0,
                    y: 2
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Quick Idea Category Section

struct QuickIdeaCategorySection: View {
    let category: QuickIdeaCategory
    @Binding var selectedTags: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category title
            Text(category.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "6B7280"))

            // Tags flow layout
            FlowLayout(spacing: 8) {
                ForEach(category.tags, id: \.self) { tag in
                    QuickIdeaTag(
                        title: tag,
                        isSelected: selectedTags.contains(tag),
                        action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if selectedTags.contains(tag) {
                                    selectedTags.remove(tag)
                                } else {
                                    selectedTags.insert(tag)
                                }
                            }
                            // Haptic feedback
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        }
                    )
                }
            }
        }
    }
}

// MARK: - All Quick Ideas Section

struct QuickIdeasSection: View {
    @Binding var selectedTags: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ForEach(QuickIdeaCategory.allCategories) { category in
                QuickIdeaCategorySection(
                    category: category,
                    selectedTags: $selectedTags
                )
            }
        }
    }
}

// MARK: - Preview

#Preview("Quick Idea Tag") {
    HStack(spacing: 8) {
        QuickIdeaTag(title: "Tropical Paradise", isSelected: true, action: {})
        QuickIdeaTag(title: "Rustic Charm", isSelected: false, action: {})
        QuickIdeaTag(title: "Modern Minimal", isSelected: false, action: {})
    }
    .padding(24)
    .background(Color(hex: "F8F9FC"))
}

#Preview("Quick Ideas Section") {
    struct PreviewWrapper: View {
        @State private var selected: Set<String> = ["Tropical Paradise", "Casual & Fun"]

        var body: some View {
            ScrollView {
                QuickIdeasSection(selectedTags: $selected)
                    .padding(24)
            }
            .background(Color(hex: "F8F9FC"))
        }
    }

    return PreviewWrapper()
}
