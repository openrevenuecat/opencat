import SwiftUI

// MARK: - Join As Co-Host Dialog
/// Custom alert dialog matching iOS style with custom button colors
struct JoinAsCoHostDialog: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) private var colorScheme

    private var backgroundColor: Color {
        colorScheme == .dark ? Color(hex: "2C2C2E") : .white
    }

    private var secondaryText: Color {
        colorScheme == .dark ? Color(hex: "98989E") : Color(hex: "6B6B6B")
    }

    private var buttonBackground: Color {
        colorScheme == .dark ? Color(hex: "3A3A3C") : Color(hex: "E8E8E8")
    }

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .onTapGesture {
                    appState.declineInvitation()
                }

            // Alert card
            VStack(spacing: 16) {
                // Title
                Text("Join as Co-Host")
                    .font(.system(size: 17, weight: .semibold))
                    .multilineTextAlignment(.center)

                // Message
                Group {
                    if let event = appState.invitationEvent {
                        Text("Welcome! You've been invited to co-organize \(event.name). Accept this invitation to start planning and collaborating on the event.")
                    } else {
                        Text("Welcome! You've been invited to co-organize this event. Accept this invitation to start planning and collaborating on the event.")
                    }
                }
                .font(.system(size: 13))
                .foregroundColor(secondaryText)
                .multilineTextAlignment(.center)

                // Buttons
                HStack(spacing: 8) {
                    // Accept button (gradient)
                    RDGradientButton(
                        "Accept",
                        isEnabled: !appState.isLoading,
                        height: 44
                    ) {
                        appState.acceptInvitation()
                    }

                    // Decline button (red text)
                    Button {
                        appState.declineInvitation()
                    } label: {
                        Text("Decline")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(buttonBackground)
                            .cornerRadius(12)
                    }
                    .disabled(appState.isLoading)
                }
            }
            .padding(20)
            .background(backgroundColor)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.15), radius: 20, y: 5)
            .padding(.horizontal, 40)
        }
    }
}
