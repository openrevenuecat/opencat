import SwiftUI
import UIKit

// MARK: - Corner Radius Extension
/// Allows applying corner radius to specific corners only
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(SpecificRoundedCorner(radius: radius, corners: corners))
    }
}

// MARK: - Specific Rounded Corner Shape
struct SpecificRoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
