import SwiftUI

// MARK: - Co-Host Details View
struct CoHostDetailsView: View {
    let sharedUser: SharedUser
    let event: Event
    let onRemove: (SharedUser) -> Void
    let onAccessRoleChanged: (SharedUser, SharedUser.AccessRole) -> Void
    let onDismiss: () -> Void

    @State private var selectedAccessRole: SharedUser.AccessRole
    @State private var showRemoveAlert = false
    @State private var showCopiedToast = false
    @State private var isUpdating = false
    @Environment(\.colorScheme) private var colorScheme

    init(
        sharedUser: SharedUser,
        event: Event,
        onRemove: @escaping (SharedUser) -> Void,
        onAccessRoleChanged: @escaping (SharedUser, SharedUser.AccessRole) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.sharedUser = sharedUser
        self.event = event
        self.onRemove = onRemove
        self.onAccessRoleChanged = onAccessRoleChanged
        self.onDismiss = onDismiss
        _selectedAccessRole = State(initialValue: sharedUser.accessRole)
    }

    // MARK: - Invite Link (for pending invitations)
    private var inviteLink: String? {
        guard !sharedUser.accepted, !sharedUser.secret.isEmpty else { return nil }

        let config = AppConfig.shared
        let domain = config.oneLinkDomain
        let appId = config.appsFlyerOneLinkId
        let deepLinkValue = "/invite?secret=\(sharedUser.secret)"

        var components = URLComponents()
        components.scheme = "https"
        components.host = domain
        components.path = "/\(appId)"
        components.queryItems = [
            URLQueryItem(name: "deep_link_value", value: deepLinkValue),
            URLQueryItem(name: "af_force_deeplink", value: "true")
        ]

        return components.url?.absoluteString
    }

    // MARK: - Theme Colors
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(hex: "1C1C1E") : Color(hex: "F2F2F7")
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "2C2C2E") : Color.white
    }

    private var textColor: Color {
        colorScheme == .dark ? .white : Color(hex: "181818")
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color(hex: "8E8E93") : Color(hex: "181818").opacity(0.64)
    }

    private var separatorColor: Color {
        colorScheme == .dark ? Color(hex: "3A3A3C") : Color(hex: "181818").opacity(0.24)
    }

    private var navBarBackground: Color {
        colorScheme == .dark ? Color(hex: "1C1C1E").opacity(0.78) : Color.white.opacity(0.78)
    }

    // MARK: - Initials
    private var initials: String {
        let parts = sharedUser.name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(sharedUser.name.prefix(2)).uppercased()
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with glass effect buttons
                RDSheetHeader(
                    title: "Host Details",
                    canSave: true,
                    onDismiss: { onDismiss() },
                    onSave: { onDismiss() }
                )

                // Avatar Section
                VStack(spacing: 0) {
                    Circle()
                        .fill(Color(hex: "9C9CA6").opacity(0.2))
                        .frame(width: 95, height: 95)
                        .overlay(
                            Text(initials)
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundColor(.rdPrimary)
                        )
                        .padding(.top, 24)
                }

                // Name Input
                VStack(spacing: 0) {
                    HStack {
                        Text(sharedUser.name)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(textColor)
                            .tracking(-0.44)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .background(cardBackground)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)

                // Access Type Row
                VStack(spacing: 0) {
                    HStack {
                        Text("Access type")
                            .font(.system(size: 17))
                            .foregroundColor(textColor)
                            .tracking(-0.41)

                        Spacer()

                        Menu {
                            ForEach(SharedUser.AccessRole.allCases) { role in
                                Button {
                                    if selectedAccessRole != role {
                                        updateAccessRole(to: role)
                                    }
                                } label: {
                                    HStack {
                                        Text(role.displayName)
                                        if selectedAccessRole == role {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if isUpdating {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Text(selectedAccessRole.displayName)
                                        .font(.system(size: 17))
                                        .foregroundColor(secondaryTextColor)
                                        .tracking(-0.41)
                                }

                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(secondaryTextColor)
                            }
                        }
                        .disabled(isUpdating)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                }
                .background(cardBackground)
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.top, 16)

                // Invite Link Section (only for pending invitations)
                if let link = inviteLink {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Invite Link")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(secondaryTextColor)
                            .textCase(.uppercase)
                            .padding(.horizontal, 16)

                        HStack(spacing: 12) {
                            Text(link)
                                .font(.system(size: 15))
                                .foregroundColor(textColor)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()

                            Button {
                                UIPasteboard.general.string = link
                                showCopiedToast = true

                                // Hide toast after delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    showCopiedToast = false
                                }

                                // Track analytics
                                AnalyticsService.shared.logEvent("co_host_link_copied", parameters: [
                                    "event_id": event.id
                                ])
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 17))
                                    .foregroundColor(.rdPrimary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(cardBackground)
                        .cornerRadius(12)
                        .padding(.horizontal, 16)

                        Text("Invite pending")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "FF9500"))
                            .padding(.horizontal, 16)
                    }
                    .padding(.top, 24)
                }

                // Remove Co-Host Button
                Button {
                    showRemoveAlert = true
                } label: {
                    Text("Remove Co-Host")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.rdWarning)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.rdWarning, lineWidth: 1)
                        )
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)

                Spacer()
            }

            // Copied Toast
            if showCopiedToast {
                VStack {
                    Spacer()
                    Text("Copied")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(20)
                        .padding(.bottom, 40)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(.easeInOut(duration: 0.2), value: showCopiedToast)
            }
        }
        .alert("Remove Co-Host?", isPresented: $showRemoveAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                onRemove(sharedUser)
                onDismiss()
            }
        } message: {
            Text("Are you sure you want to remove \(sharedUser.name) from this event? They will lose access to all event details and planning tools. This action cannot be undone.")
        }
    }

    // MARK: - Update Access Role
    private func updateAccessRole(to newRole: SharedUser.AccessRole) {
        let previousRole = selectedAccessRole
        selectedAccessRole = newRole
        isUpdating = true

        Task {
            do {
                _ = try await GRPCClientService.shared.updateSharedUser(
                    eventId: event.id,
                    secret: sharedUser.secret,
                    accessRole: newRole.rawValue
                )

                await MainActor.run {
                    isUpdating = false
                    onAccessRoleChanged(sharedUser, newRole)
                }

                // Track analytics
                AnalyticsService.shared.logEvent("co_host_access_role_changed", parameters: [
                    "event_id": event.id,
                    "new_role": newRole.rawValue
                ])
            } catch {
                // Rollback on failure
                await MainActor.run {
                    selectedAccessRole = previousRole
                    isUpdating = false
                }
                print("Failed to update access role: \(error)")
            }
        }
    }
}

// MARK: - Preview
#Preview("Accepted") {
    CoHostDetailsView(
        sharedUser: SharedUser(
            name: "Chloe Cook",
            accepted: true,
            userId: "user_123",
            secret: "secret_abc",
            accessRole: .admin
        ),
        event: .preview,
        onRemove: { _ in },
        onAccessRoleChanged: { _, _ in },
        onDismiss: { }
    )
}

#Preview("Pending") {
    CoHostDetailsView(
        sharedUser: SharedUser(
            name: "John Doe",
            accepted: false,
            userId: "",
            secret: "abc123def456",
            accessRole: .viewer
        ),
        event: .preview,
        onRemove: { _ in },
        onAccessRoleChanged: { _, _ in },
        onDismiss: { }
    )
}
