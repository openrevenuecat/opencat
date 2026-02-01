import SwiftUI
import UIKit

// MARK: - Shimmer Effect Modifier
/// Animated shimmer effect that slides a highlight gradient across the view
/// Based on Figma design: gradient rgba(225,225,231,0.6) → rgba(209,209,214,0.6)
struct ShimmerModifier: ViewModifier {
    let duration: Double = 1.5

    func body(content: Content) -> some View {
        content
            .overlay(
                TimelineView(.animation) { timeline in
                    let phase = calculatePhase(from: timeline.date)

                    // Animate gradient position using UnitPoint - no GeometryReader needed
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.4),
                            Color.clear
                        ],
                        startPoint: UnitPoint(x: phase - 1, y: 0.5),
                        endPoint: UnitPoint(x: phase, y: 0.5)
                    )
                }
            )
            .mask(content)  // Clip shimmer to match content shape (respects corner radius)
    }

    private func calculatePhase(from date: Date) -> CGFloat {
        let seconds = date.timeIntervalSinceReferenceDate
        let phase = (seconds.truncatingRemainder(dividingBy: duration)) / duration
        return CGFloat(phase * 2) // 0 to 2 range so gradient sweeps across
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Shimmer Rectangle
/// A pre-styled shimmer rectangle matching Figma design
/// Uses gradient: rgba(225,225,231,0.6) → rgba(209,209,214,0.6), corner radius 12
/// Figma: linear-gradient(176deg, first color at 30.77%, second at 100%)
struct ShimmerRect: View {
    let width: CGFloat?
    let height: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    init(width: CGFloat? = nil, height: CGFloat = 19) {
        self.width = width
        self.height = height
    }

    private var shimmerGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                stops: [
                    .init(color: Color(white: 0.25, opacity: 0.6), location: 0),
                    .init(color: Color(white: 0.25, opacity: 0.6), location: 0.31),
                    .init(color: Color(white: 0.2, opacity: 0.6), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            // Figma: linear-gradient(176.109deg, rgba(225,225,231,0.6) 30.769%, rgba(209,209,214,0.6) 100%)
            return LinearGradient(
                stops: [
                    .init(color: Color(red: 225/255, green: 225/255, blue: 231/255, opacity: 0.6), location: 0),
                    .init(color: Color(red: 225/255, green: 225/255, blue: 231/255, opacity: 0.6), location: 0.31),
                    .init(color: Color(red: 209/255, green: 209/255, blue: 214/255, opacity: 0.6), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(shimmerGradient)
            .frame(width: width, height: height)
            .shimmer()
    }
}

// MARK: - Shimmer Circle
/// A pre-styled shimmer circle for avatars and icons
struct ShimmerCircle: View {
    let size: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    init(size: CGFloat = 24) {
        self.size = size
    }

    private var shimmerColor: Color {
        colorScheme == .dark
            ? Color(white: 0.22, opacity: 0.6)
            : Color(red: 232/255, green: 232/255, blue: 232/255)
    }

    var body: some View {
        Circle()
            .fill(shimmerColor)
            .frame(width: size, height: size)
            .shimmer()
    }
}

// MARK: - Tasks Shimmer View
/// Skeleton loading view for Tasks list - Figma node 3796:11669
struct TasksShimmerView: View {
    @Environment(\.colorScheme) private var colorScheme

    private var cardBackground: Color {
        colorScheme == .dark ? Color(UIColor.secondarySystemGroupedBackground) : .white
    }

    // Figma: rgba(24,24,24,0.24)
    private var separatorColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.15)
            : Color(red: 24/255, green: 24/255, blue: 24/255, opacity: 0.24)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // White card with task rows
            VStack(spacing: 0) {
                ForEach(0..<6, id: \.self) { index in
                    TaskShimmerRow(width: taskWidth(for: index))

                    if index < 5 {
                        // Figma: 0.5px height, starts at 16px from cell left edge
                        Rectangle()
                            .fill(separatorColor)
                            .frame(height: 0.5)
                            .padding(.leading, 16)
                    }
                }
            }
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 16)
    }

    private func taskWidth(for index: Int) -> CGFloat {
        // Figma widths: 214, 153, 214, 241, 153, 214
        let widths: [CGFloat] = [214, 153, 214, 241, 153, 214]
        return widths[index % widths.count]
    }
}

// MARK: - Task Shimmer Row
private struct TaskShimmerRow: View {
    let width: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    // Radio button stroke color - matches Figma's subtle gray
    private var circleStrokeColor: Color {
        colorScheme == .dark
            ? Color(white: 0.4)
            : Color(red: 209/255, green: 209/255, blue: 214/255)  // #D1D1D6 - matches shimmer end color
    }

    var body: some View {
        HStack(spacing: 12) {
            // Radio button circle outline - Figma: 24x24 with thin stroke
            Circle()
                .stroke(circleStrokeColor, lineWidth: 1.5)
                .frame(width: 24, height: 24)

            // Text shimmer
            ShimmerRect(width: width, height: 19)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }
}

// MARK: - Guests Shimmer View
/// Skeleton loading view for Guests list - Figma node 3796:12667
struct GuestsShimmerView: View {
    @Environment(\.colorScheme) private var colorScheme

    private var cardBackground: Color {
        colorScheme == .dark ? Color(UIColor.secondarySystemGroupedBackground) : .white
    }

    // Figma: rgba(24,24,24,0.24)
    private var separatorColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.15)
            : Color(red: 24/255, green: 24/255, blue: 24/255, opacity: 0.24)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Import contacts card (visible during shimmer)
            ImportContactsShimmerCard()
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            // Guest list card
            VStack(spacing: 0) {
                ForEach(0..<6, id: \.self) { index in
                    GuestShimmerRow(width: guestWidth(for: index))

                    if index < 5 {
                        Rectangle()
                            .fill(separatorColor)
                            .frame(height: 0.5)
                            .padding(.leading, 16)
                    }
                }
            }
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private func guestWidth(for index: Int) -> CGFloat {
        // Figma widths: 176, 87, 170, 191, 141, 173
        let widths: [CGFloat] = [176, 87, 170, 191, 141, 173]
        return widths[index % widths.count]
    }
}

// MARK: - Import Contacts Shimmer Card
private struct ImportContactsShimmerCard: View {
    @Environment(\.colorScheme) private var colorScheme

    private var cardBackground: Color {
        colorScheme == .dark ? Color(UIColor.secondarySystemGroupedBackground) : .white
    }

    private var iconBackground: Color {
        colorScheme == .dark
            ? Color(white: 0.3)
            : Color(red: 232/255, green: 232/255, blue: 232/255)
    }

    var body: some View {
        HStack(spacing: 8) {
            // Plus icon in circle
            Circle()
                .fill(iconBackground)
                .frame(width: 22, height: 22)
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.rdTextTertiary)
                )

            Text("Import From Contacts")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.rdTextTertiary)

            Spacer()
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Guest Shimmer Row
private struct GuestShimmerRow: View {
    let width: CGFloat

    var body: some View {
        HStack(spacing: 8) {
            ShimmerRect(width: width, height: 19)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Agenda Shimmer View
/// Skeleton loading view for Agenda list - Figma node 3796:11877
struct AgendaShimmerView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Date header shimmer
            ShimmerRect(width: 200, height: 22)
                .padding(.leading, 16)

            // Timeline items
            VStack(spacing: 0) {
                ForEach(0..<8, id: \.self) { index in
                    AgendaShimmerRow(
                        titleWidth: agendaTitleWidth(for: index),
                        subtitleWidth: agendaSubtitleWidth(for: index),
                        isLast: index == 7
                    )
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 16)
    }

    private func agendaTitleWidth(for index: Int) -> CGFloat {
        // Varying widths matching Figma visual
        let widths: [CGFloat] = [280, 220, 180, 260, 200, 240, 160, 220]
        return widths[index % widths.count]
    }

    private func agendaSubtitleWidth(for index: Int) -> CGFloat? {
        // Some items have subtitle, some don't
        let subtitles: [CGFloat?] = [nil, 180, nil, 200, nil, 160, nil, 140]
        return subtitles[index % subtitles.count]
    }
}

// MARK: - Agenda Shimmer Row
private struct AgendaShimmerRow: View {
    let titleWidth: CGFloat
    let subtitleWidth: CGFloat?
    let isLast: Bool

    @Environment(\.colorScheme) private var colorScheme

    private var cardBackground: Color {
        colorScheme == .dark ? Color(UIColor.secondarySystemGroupedBackground) : .white
    }

    private var timelineLineColor: Color {
        colorScheme == .dark ? Color.rdPrimary.opacity(0.3) : Color.rdPrimary.opacity(0.2)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline dot and line
            VStack(spacing: 0) {
                // Purple dot with outer glow
                ZStack {
                    // Outer glow/ring
                    Circle()
                        .fill(Color.rdPrimary.opacity(0.2))
                        .frame(width: 16, height: 16)
                    // Inner dot
                    Circle()
                        .fill(Color.rdPrimary)
                        .frame(width: 10, height: 10)
                }
                .frame(width: 20, height: 20)

                // Connecting dashed line (not on last item)
                if !isLast {
                    Rectangle()
                        .fill(timelineLineColor)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 20)

            // Card content
            VStack(alignment: .leading, spacing: 6) {
                // Time shimmer (smaller)
                ShimmerRect(width: 80, height: 14)

                // Title shimmer
                ShimmerRect(width: titleWidth, height: 19)

                // Optional subtitle
                if let subtitleWidth = subtitleWidth {
                    ShimmerRect(width: subtitleWidth, height: 17)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.bottom, isLast ? 0 : 8)
    }
}

// MARK: - Expenses Shimmer View
/// Skeleton loading view for Expenses list - Figma node 3796:12308
struct ExpensesShimmerView: View {
    @Environment(\.colorScheme) private var colorScheme

    private var cardBackground: Color {
        colorScheme == .dark ? Color(UIColor.secondarySystemGroupedBackground) : .white
    }

    // Figma: rgba(24,24,24,0.24)
    private var separatorColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.15)
            : Color(red: 24/255, green: 24/255, blue: 24/255, opacity: 0.24)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Budget summary card
            ExpensesSummaryShimmerCard()

            // Expense list
            VStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { index in
                    ExpenseShimmerRow(titleWidth: expenseWidth(for: index))

                    if index < 6 {
                        Rectangle()
                            .fill(separatorColor)
                            .frame(height: 0.5)
                            .padding(.leading, 16)
                    }
                }
            }
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private func expenseWidth(for index: Int) -> CGFloat {
        // Figma widths for expense titles
        let widths: [CGFloat] = [160, 120, 180, 200, 110, 170, 140]
        return widths[index % widths.count]
    }
}

// MARK: - Expenses Summary Shimmer Card
private struct ExpensesSummaryShimmerCard: View {
    @Environment(\.colorScheme) private var colorScheme

    private var cardBackground: Color {
        colorScheme == .dark ? Color(UIColor.secondarySystemGroupedBackground) : .white
    }

    // Figma: rgba(24,24,24,0.24)
    private var separatorColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.15)
            : Color(red: 24/255, green: 24/255, blue: 24/255, opacity: 0.24)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Budget row
            ExpenseSummaryRow(icon: "banknote", label: "Budget")
                .padding(.vertical, 12)
            Rectangle().fill(separatorColor).frame(height: 0.5)

            // Planned row
            ExpenseSummaryRow(icon: "list.clipboard", label: "Planned")
                .padding(.vertical, 12)
            Rectangle().fill(separatorColor).frame(height: 0.5)

            // Remaining row
            ExpenseSummaryRow(icon: "wallet.bifold", label: "Remaining")
                .padding(.vertical, 12)
            Rectangle().fill(separatorColor).frame(height: 0.5)

            // Total Expenses row
            HStack {
                Text("Total Expenses")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                Spacer()
                ShimmerRect(width: 70, height: 19)
            }
            .padding(.vertical, 12)
        }
        .padding(.horizontal, 16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Expense Summary Row
private struct ExpenseSummaryRow: View {
    let icon: String
    let label: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.rdPrimary)
                .frame(width: 24, height: 24)

            Text(label)
                .font(.system(size: 17))
                .foregroundColor(colorScheme == .dark ? .white : .black)

            Spacer()

            ShimmerRect(width: 70, height: 19)
        }
    }
}

// MARK: - Expense Shimmer Row
private struct ExpenseShimmerRow: View {
    let titleWidth: CGFloat

    var body: some View {
        HStack(spacing: 12) {
            // Title shimmer
            ShimmerRect(width: titleWidth, height: 19)

            Spacer()

            // Amount shimmer - matches Figma ~50px
            ShimmerRect(width: 50, height: 19)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Home Events Shimmer View
/// Skeleton loading view for Home events list - Figma node 968:39018
struct HomeEventsShimmerView: View {
    @Environment(\.colorScheme) private var colorScheme

    private var shimmerGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    Color(white: 0.25, opacity: 0.6),
                    Color(white: 0.2, opacity: 0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color(red: 225/255, green: 225/255, blue: 231/255, opacity: 0.6),
                    Color(red: 209/255, green: 209/255, blue: 214/255, opacity: 0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // First card
                HomeEventShimmerCard(height: UIScreen.main.bounds.height * 0.55)

                // Second card (visible partially)
                HomeEventShimmerCard(height: UIScreen.main.bounds.height * 0.45)
            }
            .padding(.top, 16)
            .padding(.bottom, 64)
        }
    }
}

// MARK: - Home Event Shimmer Card
private struct HomeEventShimmerCard: View {
    let height: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    private var shimmerGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    Color(white: 0.25, opacity: 0.6),
                    Color(white: 0.2, opacity: 0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color(red: 225/255, green: 225/255, blue: 231/255, opacity: 0.6),
                    Color(red: 209/255, green: 209/255, blue: 214/255, opacity: 0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var infoBackgroundColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.3)
            : Color.black.opacity(0.1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            // Bottom info section with blur effect
            VStack(alignment: .leading, spacing: 12) {
                // Title shimmer (2 lines)
                ShimmerRect(height: 31)
                ShimmerRect(width: 214, height: 31)

                // Date shimmer
                ShimmerRect(width: 214, height: 19)

                // Location shimmer
                ShimmerRect(width: 324, height: 19)
            }
            .padding(16)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                infoBackgroundColor
                    .background(.ultraThinMaterial)
            )
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .background(shimmerGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 16)
        // Removed outer .shimmer() - individual ShimmerRect components already have shimmer
    }
}

// MARK: - Previews
#Preview("Tasks Shimmer") {
    ZStack {
        Color.rdBackground.ignoresSafeArea()
        TasksShimmerView()
    }
}

#Preview("Guests Shimmer") {
    ZStack {
        Color.rdBackground.ignoresSafeArea()
        GuestsShimmerView()
    }
}

#Preview("Agenda Shimmer") {
    ZStack {
        Color.rdBackground.ignoresSafeArea()
        AgendaShimmerView()
    }
}

#Preview("Expenses Shimmer") {
    ZStack {
        Color.rdBackground.ignoresSafeArea()
        ExpensesShimmerView()
    }
}

#Preview("Home Events Shimmer") {
    ZStack {
        Color.rdBackground.ignoresSafeArea()
        HomeEventsShimmerView()
    }
}
