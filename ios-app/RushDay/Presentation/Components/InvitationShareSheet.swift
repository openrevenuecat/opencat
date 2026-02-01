import SwiftUI
import UIKit

// MARK: - InvitationShareSheet

/// A share sheet for sharing event invitations
struct InvitationShareSheet: View {
    let event: Event
    let invitationLink: String
    let onDismiss: () -> Void

    @State private var showShareSheet = false
    @State private var showCopiedToast = false

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text(L10n.shareInvitation)
                    .font(.rdHeadline())
                    .foregroundStyle(Color.rdTextPrimary)

                Text(event.name)
                    .font(.rdBody())
                    .foregroundStyle(Color.rdTextSecondary)
                    .lineLimit(1)
            }

            // Link Preview
            HStack {
                Text(invitationLink)
                    .font(.rdCaption())
                    .foregroundStyle(Color.rdTextSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Button {
                    copyToClipboard()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.rdPrimary)
                }
            }
            .padding(12)
            .background(Color.rdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Share Options
            HStack(spacing: 16) {
                ShareOptionButton(
                    icon: "square.and.arrow.up",
                    title: L10n.share,
                    color: .rdPrimary
                ) {
                    showShareSheet = true
                }

                ShareOptionButton(
                    icon: "envelope",
                    title: L10n.email,
                    color: .blue
                ) {
                    shareViaEmail()
                }

                ShareOptionButton(
                    icon: "message",
                    title: L10n.invitationMessage,
                    color: .green
                ) {
                    shareViaSMS()
                }

                ShareOptionButton(
                    icon: "doc.on.doc",
                    title: L10n.copy,
                    color: .orange
                ) {
                    copyToClipboard()
                }
            }

            // Done Button
            Button {
                onDismiss()
            } label: {
                Text(L10n.done)
                    .font(.rdBody())
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.rdPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.rdPrimaryLight)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(24)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.1), radius: 20, y: -5)
        .sheet(isPresented: $showShareSheet) {
            ActivityViewController(activityItems: [invitationLink])
        }
        .overlay {
            if showCopiedToast {
                VStack {
                    Spacer()
                    CopiedToast()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 100)
                }
                .animation(.spring(response: 0.3), value: showCopiedToast)
            }
        }
    }

    // MARK: - Actions

    private func copyToClipboard() {
        UIPasteboard.general.string = invitationLink
        showCopiedToast = true

        // Track analytics
        AnalyticsService.shared.logEvent("invitation_link_copied", parameters: [
            "event_id": event.id
        ])

        // Hide toast after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopiedToast = false
        }
    }

    private func shareViaEmail() {
        let subject = L10n.invitationEmailSubject(event.name)
        let body = L10n.invitationEmailBody(event.name, invitationLink)

        guard let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "mailto:?subject=\(encodedSubject)&body=\(encodedBody)") else {
            return
        }

        UIApplication.shared.open(url)

        // Track analytics
        AnalyticsService.shared.logEvent("invitation_shared_email", parameters: [
            "event_id": event.id
        ])
    }

    private func shareViaSMS() {
        let body = L10n.invitationSMSBody(event.name, invitationLink)

        guard let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "sms:&body=\(encodedBody)") else {
            return
        }

        UIApplication.shared.open(url)

        // Track analytics
        AnalyticsService.shared.logEvent("invitation_shared_sms", parameters: [
            "event_id": event.id
        ])
    }
}

// MARK: - Share Option Button

private struct ShareOptionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 20))
                            .foregroundStyle(color)
                    )

                Text(title)
                    .font(.rdCaption())
                    .foregroundStyle(Color.rdTextSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Copied Toast

private struct CopiedToast: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)

            Text(L10n.copiedToClipboard)
                .font(.rdBody())
                .foregroundStyle(Color.rdTextPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}

// MARK: - Activity View Controller

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Invitation Accept Dialog

/// Dialog shown when user opens an invitation deep link
struct InvitationAcceptDialog: View {
    let event: Event
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Event Image
            if let coverImage = event.coverImage, !coverImage.isEmpty {
                CachedAsyncImage(url: URL(string: coverImage)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    eventImagePlaceholder
                }
                .frame(height: 150)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                eventImagePlaceholder
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            // Event Info
            VStack(spacing: 8) {
                Text(L10n.youAreInvited)
                    .font(.rdBody())
                    .foregroundStyle(Color.rdTextSecondary)

                Text(event.name)
                    .font(.rdHeadline())
                    .foregroundStyle(Color.rdTextPrimary)
                    .multilineTextAlignment(.center)

                if let venue = event.venue {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 12))
                        Text(venue)
                            .font(.rdCaption())
                    }
                    .foregroundStyle(Color.rdTextSecondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                    Text(event.startDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.rdCaption())
                }
                .foregroundStyle(Color.rdTextSecondary)
            }

            // Buttons
            VStack(spacing: 12) {
                RDGradientButton(L10n.accept, action: onAccept)

                Button {
                    onDecline()
                } label: {
                    Text(L10n.decline)
                        .font(.rdBody())
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.rdTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.rdSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(24)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
        .padding(.horizontal, 32)
    }

    private var eventImagePlaceholder: some View {
        LinearGradient(
            colors: [Color.rdPrimary.opacity(0.8), Color.rdAccent.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "calendar")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.5))
        )
    }
}

// MARK: - Preview

#Preview("Share Sheet") {
    InvitationShareSheet(
        event: .preview,
        invitationLink: "https://rushday.app/invitations/abc123"
    ) {}
}

#Preview("Accept Dialog") {
    ZStack {
        Color.black.opacity(0.5).ignoresSafeArea()

        InvitationAcceptDialog(
            event: .preview,
            onAccept: {},
            onDecline: {}
        )
    }
}
