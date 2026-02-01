import SwiftUI
import PhotosUI
import Photos
import FirebaseAuth

// MARK: - Edit Profile View Model
@MainActor
class EditProfileViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var avatarImage: UIImage?
    @Published var currentAvatarURL: String?
    @Published var uploadedAvatarURL: String? // URL after immediate upload
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var isUploadingImage = false
    @Published var uploadProgress: CGFloat = 0 // Progress 0.0 to 1.0
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var showPhotoPicker = false
    @Published var showDeleteConfirmation = false
    @Published var showDeleteAccountConfirmation = false
    @Published var selectedPhotoItem: PhotosPickerItem?

    private let originalName: String
    private let originalAvatarURL: String?
    private let userId: String

    private let grpcService: GRPCClientService
    private let storageService: StorageServiceProtocol
    private let authService: AuthServiceProtocol

    var hasChanges: Bool {
        name != originalName || uploadedAvatarURL != nil || (currentAvatarURL == nil && originalAvatarURL != nil)
    }

    /// Returns true if there's a pending image that failed to upload
    var hasFailedUpload: Bool {
        avatarImage != nil && uploadedAvatarURL == nil && !isUploadingImage
    }

    /// Shows combined loading state (uploading or saving)
    var isProcessing: Bool {
        isSaving
    }

    init(
        user: User,
        grpcService: GRPCClientService = .shared,
        storageService: StorageServiceProtocol = DIContainer.shared.storageService,
        authService: AuthServiceProtocol = DIContainer.shared.authService
    ) {
        self.grpcService = grpcService
        self.storageService = storageService
        self.authService = authService
        self.userId = user.id
        self.name = user.name
        self.originalName = user.name
        self.currentAvatarURL = user.photoUrl
        self.originalAvatarURL = user.photoUrl
    }

    func loadSelectedImage() async {
        guard let item = selectedPhotoItem else { return }

        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                avatarImage = image
                // Upload immediately after selecting
                await uploadAvatarImage(image)
            }
        } catch {
            // Image load failed
            errorMessage = "Failed to load image"
        }
    }

    /// Upload avatar image immediately when selected
    func uploadAvatarImage(_ image: UIImage) async {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            errorMessage = "Failed to process image"
            showError = true
            return
        }

        isUploadingImage = true
        uploadProgress = 0.05 // Start at 5% to show immediate feedback

        // Simulate progress while uploading
        let progressTask = Task {
            for i in 1...8 {
                try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 second
                if !Task.isCancelled {
                    await MainActor.run {
                        uploadProgress = 0.05 + CGFloat(i) * 0.1
                    }
                }
            }
        }

        do {
            let timestamp = Int(Date().timeIntervalSince1970 * 1000)
            let path = "users/\(userId)/profile_image/\(timestamp).jpg"

            let avatarURL = try await storageService.uploadImage(data: imageData, path: path)
            progressTask.cancel()

            uploadProgress = 1.0
            uploadedAvatarURL = avatarURL

            // Small delay to show completion
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 second
        } catch {
            progressTask.cancel()
            errorMessage = "Failed to upload image. Tap photo to retry."
            showError = true
            // Keep avatarImage so user can see what they selected and retry
            uploadedAvatarURL = nil
        }

        isUploadingImage = false
        uploadProgress = 0
    }

    /// Retry upload with current avatar image
    func retryUpload() async {
        guard let image = avatarImage else { return }
        await uploadAvatarImage(image)
    }

    func deleteAvatar() {
        avatarImage = nil
        currentAvatarURL = nil
        uploadedAvatarURL = nil
    }

    func save() async -> User? {
        guard hasChanges else {
            return nil
        }

        // Don't save while still uploading
        guard !isUploadingImage else {
            return nil
        }

        errorMessage = nil
        isSaving = true

        do {
            var request = Rushday_V1_UpdateUserRequest()

            // Update name if changed
            if name != originalName {
                request.name = name
            }

            // Use already-uploaded avatar URL
            if let uploadedURL = uploadedAvatarURL {
                request.avatar = uploadedURL
            } else if currentAvatarURL == nil && originalAvatarURL != nil {
                // Avatar was deleted - set to empty string to clear it
                request.avatar = ""
            }

            let updatedUser = try await grpcService.updateUser(request)
            let domainUser = User(from: updatedUser)

            isSaving = false

            // Post notification to refresh user data everywhere (centralized in AppState)
            await MainActor.run {
                NotificationCenter.default.post(name: .userProfileUpdated, object: domainUser)
            }

            return domainUser
        } catch {
            isSaving = false
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func deleteAccount() async -> Bool {
        isSaving = true
        errorMessage = nil
        showError = false
        defer { isSaving = false }

        do {
            // Refresh the auth token before making the delete call
            if let firebaseUser = Auth.auth().currentUser {
                let token = try await firebaseUser.getIDToken(forcingRefresh: true)
                grpcService.setAuthToken(token)
            } else {
                errorMessage = "Not authenticated. Please sign in again."
                showError = true
                return false
            }

            // First, verify the token works by calling getCurrentUser
            let _ = try await grpcService.getCurrentUser()

            _ = try await grpcService.deleteUser()

            // Reset migration status so it will re-run when user signs in again
            DIContainer.shared.migrationService.resetMigrationStatus()

            // Don't sign out here - let the caller handle navigation via AppState.handleAccountDeleted()
            return true
        } catch {
            // Delete failed
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }
}

// MARK: - Edit Profile View
struct EditProfileView: View {
    @StateObject private var viewModel: EditProfileViewModel
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    init(user: User) {
        _viewModel = StateObject(wrappedValue: EditProfileViewModel(user: user))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Avatar Section
            EditAvatarSection(viewModel: viewModel)
                .padding(.top, 24)

            // Set Photo Button
            SetPhotoButton(viewModel: viewModel)
                .padding(.top, 8)

            // Name Input
            NameInputSection(name: $viewModel.name)
                .padding(.top, 24)
                .padding(.horizontal, 16)

            // Delete Account Button
            DeleteAccountButton {
                viewModel.showDeleteAccountConfirmation = true
            }
            .padding(.top, 36)

            Spacer()
        }
        .background(Color.rdBackground)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(L10n.editProfile)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("", systemImage: "chevron.left") {
                    dismiss()
                }
                .tint(.rdPrimaryDark)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(L10n.done) {
                    Task {
                        if await viewModel.save() != nil {
                            dismiss()
                        }
                    }
                }
                .font(.bodyMedium)
                .fontWeight(.semibold)
                .foregroundColor(viewModel.hasChanges && !viewModel.isUploadingImage && !viewModel.isSaving ? .rdPrimaryDark : .rdTextTertiary)
                .disabled(!viewModel.hasChanges || viewModel.isUploadingImage || viewModel.isSaving)
            }
        }
        .onChange(of: viewModel.selectedPhotoItem) { _, _ in
            Task {
                await viewModel.loadSelectedImage()
                viewModel.showPhotoPicker = false
            }
        }
        .sheet(isPresented: $viewModel.showPhotoPicker) {
            InlinePhotoPickerSheet(
                hasPhoto: viewModel.avatarImage != nil || (viewModel.currentAvatarURL != nil && !viewModel.currentAvatarURL!.isEmpty),
                onSelectImage: { image in
                    viewModel.avatarImage = image
                    viewModel.showPhotoPicker = false
                    // Upload immediately after selecting
                    Task { @MainActor in
                        await viewModel.uploadAvatarImage(image)
                    }
                },
                onDelete: {
                    viewModel.deleteAvatar()
                    viewModel.showPhotoPicker = false
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .alert(L10n.deleteAccountTitle, isPresented: $viewModel.showDeleteAccountConfirmation) {
            Button(L10n.cancel, role: .cancel) {}
            Button(L10n.deleteAccount, role: .destructive) {
                Task {
                    let success = await viewModel.deleteAccount()
                    if success {
                        // Navigate to AI wizard (user is starting fresh)
                        appState.handleAccountDeleted()
                    }
                }
            }
        } message: {
            Text(L10n.deleteAccountDesc)
        }
        .alert(L10n.error, isPresented: $viewModel.showError) {
            Button(L10n.ok, role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
        .overlay {
            if viewModel.isSaving {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(.white)

                            Text("Saving...")
                                .font(.rdBody())
                                .foregroundColor(.white)
                        }
                        .padding(24)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(16)
                    }
            }
        }
    }
}

// MARK: - Edit Avatar Section
struct EditAvatarSection: View {
    @ObservedObject var viewModel: EditProfileViewModel

    private let avatarSize: CGFloat = 96
    private let progressLineWidth: CGFloat = 4

    var body: some View {
        ZStack {
            // Avatar image
            avatarView
                .frame(width: avatarSize, height: avatarSize)
                .clipShape(Circle())

            // Circular progress overlay during upload
            if viewModel.isUploadingImage {
                // Background circle (track)
                Circle()
                    .stroke(Color.rdPrimary.opacity(0.3), lineWidth: progressLineWidth)
                    .frame(width: avatarSize + progressLineWidth * 2, height: avatarSize + progressLineWidth * 2)

                // Progress circle
                Circle()
                    .trim(from: 0, to: viewModel.uploadProgress)
                    .stroke(Color.rdPrimary, style: StrokeStyle(lineWidth: progressLineWidth, lineCap: .round))
                    .frame(width: avatarSize + progressLineWidth * 2, height: avatarSize + progressLineWidth * 2)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.1), value: viewModel.uploadProgress)

                // Dim overlay on avatar
                Circle()
                    .fill(Color.black.opacity(0.3))
                    .frame(width: avatarSize, height: avatarSize)
            }

            // Failed upload overlay - show retry icon
            if viewModel.hasFailedUpload {
                Circle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: avatarSize, height: avatarSize)

                VStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Retry")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                }
            }
        }
        .onTapGesture {
            if viewModel.isUploadingImage {
                return
            }
            // If there's a failed upload, retry it
            if viewModel.hasFailedUpload {
                Task {
                    await viewModel.retryUpload()
                }
            } else {
                viewModel.showPhotoPicker = true
            }
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        if let image = viewModel.avatarImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if let url = viewModel.currentAvatarURL, !url.isEmpty {
            CachedAsyncImage(url: URL(string: url)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                AvatarPlaceholderView(name: viewModel.name)
            }
            .id(url) // Force view recreation when URL changes
        } else {
            AvatarPlaceholderView(name: viewModel.name)
        }
    }
}

struct AvatarPlaceholderView: View {
    let name: String

    // Gray color from Figma: #9C9CA6 at 20% opacity
    private let placeholderBackground = Color(red: 156/255, green: 156/255, blue: 166/255).opacity(0.2)
    private let iconColor = Color(red: 158/255, green: 158/255, blue: 170/255) // #9E9EAA

    private var initials: String {
        guard !name.isEmpty else { return "" }
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(placeholderBackground)

            if !initials.isEmpty {
                Text(initials)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(iconColor)
            } else {
                Image("ic_user_placeholder")
                    .resizable()
                    .renderingMode(.original)
                    .frame(width: 48, height: 48)
            }
        }
    }
}

// MARK: - Set Photo Button
struct SetPhotoButton: View {
    @ObservedObject var viewModel: EditProfileViewModel

    var hasPhoto: Bool {
        viewModel.avatarImage != nil || (viewModel.currentAvatarURL != nil && !viewModel.currentAvatarURL!.isEmpty)
    }

    var body: some View {
        Button {
            viewModel.showPhotoPicker = true
        } label: {
            Text(hasPhoto ? L10n.changePhoto : L10n.setNewPhoto)
                .font(.bodyMedium)
                .foregroundColor(.rdPrimaryDark)
        }
    }
}

// MARK: - Inline Photo Picker Sheet (Telegram-style)
struct InlinePhotoPickerSheet: View {
    let hasPhoto: Bool
    let onSelectImage: (UIImage) -> Void
    let onDelete: () -> Void

    @StateObject private var photoLoader = PhotoLibraryLoader()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var isLoadingImage = false

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    private var backgroundColor: Color {
        colorScheme == .dark ? Color(hex: "1C1C1E") : Color.rdBackground
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with X button and title
                photoPickerHeader

                // Photo grid
                if photoLoader.authorizationStatus == .authorized || photoLoader.authorizationStatus == .limited {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(photoLoader.photos) { photo in
                                PhotoGridItem(photo: photo) {
                                    isLoadingImage = true
                                    Task {
                                        if let image = await photoLoader.loadFullImage(for: photo) {
                                            onSelectImage(image)
                                        }
                                        isLoadingImage = false
                                    }
                                }
                            }
                        }
                    }
                    .scrollBounceHaptic()
                } else if photoLoader.authorizationStatus == .denied || photoLoader.authorizationStatus == .restricted {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 48))
                            .foregroundColor(.rdTextTertiary)

                        Text("Photo Access Required")
                            .font(.headline)
                            .foregroundColor(.rdTextPrimary)

                        Text("Please enable photo access in Settings to select a profile photo.")
                            .font(.subheadline)
                            .foregroundColor(.rdTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.rdPrimary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Bottom Remove Photo button (Telegram-style)
                if hasPhoto {
                    Button(action: onDelete) {
                        Text("Remove Photo")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(.rdWarning)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .background(backgroundColor)
                }
            }

            // Loading overlay
            if isLoadingImage {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay(ProgressView())
            }
        }
        .task {
            await photoLoader.requestAuthorization()
            if photoLoader.authorizationStatus == .authorized || photoLoader.authorizationStatus == .limited {
                await photoLoader.loadPhotos()
            }
        }
    }

    // MARK: - Photo Picker Header (Telegram-style)
    private var photoPickerHeader: some View {
        VStack(spacing: 0) {
            // Grabber
            Capsule()
                .fill(Color(hex: "3A3A3C"))
                .frame(width: 36, height: 5)
                .padding(.top, 5)
                .padding(.bottom, 8)

            // Header row
            HStack {
                // X button (left)
                Button(action: { dismiss() }) {
                    Image("icon_xmark_close")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(Color(hex: "999999"))
                        .frame(width: 44, height: 44)
                        .background {
                            Circle()
                                .fill(Color(hex: "9C9CA6").opacity(0.2))
                        }
                }
                .buttonStyle(.plain)

                Spacer()

                // Title (center)
                Text("Recents")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : Color(hex: "0D1017"))

                Spacer()

                // Invisible spacer to balance the X button
                Color.clear
                    .frame(width: 44, height: 44)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }
}

// MARK: - Photo Grid Item
struct PhotoGridItem: View {
    let photo: PhotoAsset
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            if let image = photo.thumbnail {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.rdSurface)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(ProgressView())
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Photo Asset Model
struct PhotoAsset: Identifiable {
    let id: String
    let asset: PHAsset
    var thumbnail: UIImage?
}

// MARK: - Photo Library Loader
@MainActor
class PhotoLibraryLoader: ObservableObject {
    @Published var photos: [PhotoAsset] = []
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined

    private let imageManager = PHCachingImageManager()
    private let thumbnailSize = CGSize(width: 300, height: 300)  // Higher res thumbnails

    func requestAuthorization() async {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        if authorizationStatus == .notDetermined {
            authorizationStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
    }

    func loadPhotos() async {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 100

        let results = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        var loadedPhotos: [PhotoAsset] = []

        results.enumerateObjects { asset, _, _ in
            loadedPhotos.append(PhotoAsset(id: asset.localIdentifier, asset: asset, thumbnail: nil))
        }

        photos = loadedPhotos

        // Load thumbnails
        for (index, photo) in photos.enumerated() {
            await loadThumbnail(for: photo, at: index)
        }
    }

    private func loadThumbnail(for photo: PhotoAsset, at index: Int) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic  // Get fast preview then high quality
            options.isNetworkAccessAllowed = true
            options.resizeMode = .fast
            options.isSynchronous = false

            var hasResumed = false

            imageManager.requestImage(
                for: photo.asset,
                targetSize: thumbnailSize,
                contentMode: .aspectFill,
                options: options
            ) { [weak self] image, info in
                // Update thumbnail with whatever quality we get
                if let self = self, let image = image, index < self.photos.count {
                    self.photos[index].thumbnail = image
                }

                // Only resume once on final callback
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !isDegraded && !hasResumed {
                    hasResumed = true
                    continuation.resume()
                }
            }
        }
    }

    func loadFullImage(for photo: PhotoAsset) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat  // Get high quality image
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            options.resizeMode = .fast // Use fast to avoid quality-related issues

            // Track if we've resumed to handle any edge cases
            var hasResumed = false

            imageManager.requestImage(
                for: photo.asset,
                targetSize: CGSize(width: 1024, height: 1024),  // Reasonable size, not maximum
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                // Ensure we only resume once
                guard !hasResumed else { return }

                // Check if this is the final image (not cancelled, not degraded)
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                let isCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false

                // Accept even degraded images if no final image comes
                if !isCancelled && image != nil && !isDegraded {
                    hasResumed = true
                    continuation.resume(returning: image)
                } else if !isCancelled && image != nil && isDegraded {
                    // Accept degraded image after a timeout if final doesn't come
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        if !hasResumed {
                            hasResumed = true
                            continuation.resume(returning: image)
                        }
                    }
                } else if !hasResumed && isCancelled {
                    hasResumed = true
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

// MARK: - Name Input Section
struct NameInputSection: View {
    @Binding var name: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField(L10n.yourName, text: $name)
                    .font(.bodyMedium)
                    .foregroundColor(.rdTextPrimary)

                // Clear button
                if !name.isEmpty {
                    Button {
                        name = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color(red: 24/255, green: 24/255, blue: 24/255).opacity(0.24))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(Color.rdBackgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Delete Account Button
struct DeleteAccountButton: View {
    let action: () -> Void

    // Warning color from Figma: #DB4F47
    private let warningColor = Color(red: 219/255, green: 79/255, blue: 71/255)

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image("icon_swipe_bin")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                Text(L10n.deleteProfile)
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(warningColor)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    EditProfileView(user: .mock)
}
