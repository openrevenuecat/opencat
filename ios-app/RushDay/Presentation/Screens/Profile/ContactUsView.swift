import SwiftUI

// MARK: - Contact Us Screen
struct ContactUsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = ContactUsViewModel()
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false

    // MARK: - Dark Mode Colors
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(hex: "1C1C1E") : Color(hex: "F2F2F7")
    }

    private var inputBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "2C2C2E") : Color.white
    }

    private var textPrimaryColor: Color {
        colorScheme == .dark ? .white : Color(hex: "0D1017")
    }

    private var textPlaceholderColor: Color {
        colorScheme == .dark ? Color(hex: "8E8E93") : Color(hex: "9E9EAA")
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack(spacing: 0) {
                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Large Title
                        Text(L10n.contactUs)
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .foregroundColor(textPrimaryColor)
                            .tracking(0.38)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                        // Subject Field
                        VStack(spacing: 8) {
                            TextField(L10n.subject, text: $viewModel.subject)
                                .font(.system(size: 17))
                                .foregroundColor(textPrimaryColor)
                                .padding(.horizontal, 16)
                                .frame(height: 52)
                                .background(inputBackgroundColor)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 18)

                        // Body Field
                        VStack(spacing: 8) {
                            ZStack(alignment: .topLeading) {
                                if viewModel.body.isEmpty {
                                    Text(L10n.contactUsScreenDesc)
                                        .font(.system(size: 17))
                                        .foregroundColor(textPlaceholderColor)
                                        .tracking(-0.44)
                                        .padding(.horizontal, 16)
                                        .padding(.top, 16)
                                }

                                TextEditor(text: $viewModel.body)
                                    .font(.system(size: 17))
                                    .foregroundColor(textPrimaryColor)
                                    .tracking(-0.44)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 12)
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 162)
                            }
                            .background(inputBackgroundColor)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 16)

                        Spacer()
                    }
                }
                .scrollBounceHaptic()

                // Bottom Button
                VStack(spacing: 0) {
                    Divider()

                    RDGradientButton(
                        L10n.send,
                        isLoading: viewModel.isLoading,
                        isEnabled: viewModel.isFormValid
                    ) {
                        Task {
                            await viewModel.sendMessage()
                            if viewModel.sendSuccess {
                                showSuccessAlert = true
                            } else if viewModel.sendError {
                                showErrorAlert = true
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                .background(backgroundColor)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .medium))
                        Text("Back")
                            .font(.system(size: 17))
                    }
                    .foregroundColor(textPrimaryColor)
                }
            }
        }
        .alert(L10n.contactUsSuccessSendingTitle, isPresented: $showSuccessAlert) {
            Button(L10n.ok) {
                dismiss()
            }
        } message: {
            Text(L10n.contactUsSuccessSendingDesc)
        }
        .alert(L10n.contactUsErrorSendingTitle, isPresented: $showErrorAlert) {
            Button(L10n.ok) {}
        } message: {
            Text(L10n.contactUsErrorSendingDesc)
        }
    }
}

// MARK: - Contact Us ViewModel
@MainActor
class ContactUsViewModel: ObservableObject {
    @Published var subject = ""
    @Published var body = ""
    @Published var isLoading = false
    @Published var sendSuccess = false
    @Published var sendError = false

    private let authService: AuthServiceProtocol
    private let userRepository: UserRepositoryProtocol

    var isFormValid: Bool {
        !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init() {
        self.authService = DIContainer.shared.authService
        self.userRepository = DIContainer.shared.userRepository
    }

    func sendMessage() async {
        guard isFormValid else { return }

        isLoading = true
        sendSuccess = false
        sendError = false

        defer { isLoading = false }

        do {
            // Get current user
            guard let currentUser = authService.currentUser,
                  let user = try? await userRepository.getUser(id: currentUser.id) else {
                sendError = true
                return
            }

            // Get device info
            let deviceModel = UIDevice.current.model
            let osVersion = UIDevice.current.systemVersion

            // Send to feedback API (matches Flutter implementation)
            let apiUrl = "https://admin.rush-day.io/api/v1.1"
            guard let url = URL(string: apiUrl) else {
                sendError = true
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"

            let boundary = "Boundary-\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

            var body = Data()

            // Helper function to add form field
            func addFormField(name: String, value: String) {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(value)\r\n".data(using: .utf8)!)
            }

            // Add fields matching Flutter implementation
            addFormField(name: "userEmail", value: user.email)
            addFormField(name: "userName", value: user.name)
            addFormField(name: "subject", value: subject.trimmingCharacters(in: .whitespacesAndNewlines))
            addFormField(name: "body", value: self.body.trimmingCharacters(in: .whitespacesAndNewlines))
            addFormField(name: "meta[os]", value: "iOS")
            addFormField(name: "meta[osVersion]", value: osVersion)
            addFormField(name: "meta[device]", value: deviceModel)
            addFormField(name: "meta[appVersion]", value: Bundle.main.appVersion)

            body.append("--\(boundary)--\r\n".data(using: .utf8)!)

            request.httpBody = body

            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse,
               (200...201).contains(httpResponse.statusCode) {
                sendSuccess = true

                // Clear form
                subject = ""
                self.body = ""
            } else {
                sendError = true
            }

        } catch {
            sendError = true
        }
    }
}

#Preview {
    NavigationStack {
        ContactUsView()
    }
}
