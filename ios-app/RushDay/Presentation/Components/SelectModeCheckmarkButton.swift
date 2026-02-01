import SwiftUI

/// Checkmark button for select mode toolbar
/// - No selection (Figma 3860:14501): Glass with no tint
/// - Has selection (Figma 3860:13090): Glass with purple tint
/// Works on all iOS versions with glass effect on iOS 26+
struct SelectModeCheckmarkButton: View {
    let hasSelection: Bool
    let action: () -> Void

    var body: some View {
        if #available(iOS 26.0, *) {
            // iOS 26+: Glass prominent with tint and white icon
            Button(action: action) {
                Image(systemName: "checkmark")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.circle)
            .tint(hasSelection ? Color(hex: "8251EB") : Color(hex: "DEDEDE"))
        } else {
            // Pre-iOS 26: Solid fills with white checkmark
            Button(action: action) {
                Image(systemName: "checkmark")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background {
                        Circle()
                            .fill(hasSelection ? Color(hex: "8251EB") : Color(hex: "DEDEDE"))
                    }
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview("No Selection") {
    SelectModeCheckmarkButton(hasSelection: false) {
        print("Tapped")
    }
}

#Preview("Has Selection") {
    SelectModeCheckmarkButton(hasSelection: true) {
        print("Tapped")
    }
}
