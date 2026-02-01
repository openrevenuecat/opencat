import SwiftUI

struct RDTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var icon: String?
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences
    var errorMessage: String?

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.isEmpty {
                Text(title)
                    .font(.labelLarge)
                    .foregroundColor(.rdTextSecondary)
            }

            HStack(spacing: 12) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(isFocused ? .rdAccent : .rdTextTertiary)
                        .frame(width: 24)
                }

                Group {
                    if isSecure {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                            .keyboardType(keyboardType)
                            .textInputAutocapitalization(autocapitalization)
                    }
                }
                .font(.bodyLarge)
                .foregroundColor(.rdTextPrimary)
                .focused($isFocused)
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(Color.rdSurface)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: 1.5)
            )

            if let error = errorMessage, !error.isEmpty {
                Text(error)
                    .font(.captionMedium)
                    .foregroundColor(.rdError)
            }
        }
    }

    private var borderColor: Color {
        if errorMessage != nil && !errorMessage!.isEmpty {
            return .rdError
        }
        return isFocused ? .rdAccent : .clear
    }
}

// MARK: - Large Input Field (for sections)
struct RDLargeInputField: View {
    let title: String
    var subtitle: String?
    var icon: String?
    var value: String?
    var placeholder: String = ""
    var action: (() -> Void)?

    var body: some View {
        Button(action: { action?() }) {
            VStack(alignment: .leading, spacing: 4) {
                if !title.isEmpty {
                    Text(title.uppercased())
                        .font(.captionLarge)
                        .foregroundColor(.rdTextTertiary)
                        .tracking(0.5)
                }

                HStack(spacing: 12) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 20))
                            .foregroundColor(.rdTextSecondary)
                            .frame(width: 24)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        if let value = value, !value.isEmpty {
                            Text(value)
                                .font(.bodyLarge)
                                .foregroundColor(.rdTextPrimary)
                                .lineLimit(2)
                        } else {
                            Text(placeholder)
                                .font(.bodyLarge)
                                .foregroundColor(.rdTextTertiary)
                        }

                        if let subtitle = subtitle {
                            Text(subtitle)
                                .font(.captionMedium)
                                .foregroundColor(.rdTextSecondary)
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 56)
                .background(Color.rdSurface)
                .cornerRadius(16)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Text Area
struct RDTextArea: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var minHeight: CGFloat = 100

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.isEmpty {
                Text(title)
                    .font(.labelLarge)
                    .foregroundColor(.rdTextSecondary)
            }

            TextEditor(text: $text)
                .font(.bodyLarge)
                .foregroundColor(.rdTextPrimary)
                .scrollContentBackground(.hidden)
                .padding(12)
                .frame(minHeight: minHeight)
                .background(Color.rdSurface)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isFocused ? Color.rdAccent : Color.clear, lineWidth: 1.5)
                )
                .focused($isFocused)
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(placeholder)
                            .font(.bodyLarge)
                            .foregroundColor(.rdTextTertiary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)
                    }
                }
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        RDTextField(
            title: "Email",
            placeholder: "Enter your email",
            text: .constant(""),
            icon: "envelope"
        )

        RDTextField(
            title: "Password",
            placeholder: "Enter password",
            text: .constant(""),
            icon: "lock",
            isSecure: true
        )

        RDTextField(
            title: "Error Field",
            placeholder: "Enter something",
            text: .constant("Invalid"),
            errorMessage: "This field is invalid"
        )

        RDLargeInputField(
            title: "Event Name",
            icon: "pencil",
            value: nil,
            placeholder: "Enter event name"
        )

        RDLargeInputField(
            title: "Date & Time",
            icon: "calendar",
            value: "December 25, 2024 at 6:00 PM"
        )

        RDTextArea(
            title: "Description",
            placeholder: "Add a description...",
            text: .constant("")
        )
    }
    .padding()
    .background(Color.rdBackground)
}
