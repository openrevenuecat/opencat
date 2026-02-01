import SwiftUI
import PhotosUI

// MARK: - Cover Selection Sheet

struct CoverSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CoverSelectionViewModel
    @Binding var selectedCoverUrl: String?

    init(selectedCoverUrl: Binding<String?>) {
        self._selectedCoverUrl = selectedCoverUrl
        self._viewModel = StateObject(wrappedValue: CoverSelectionViewModel())
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom header with left-aligned title
                HStack {
                    Text("Set Cover")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.rdTextPrimary)

                    Spacer()

                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.rdTextSecondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

                coverListContent
            }
            .background(Color.rdBackground)
            .navigationBarHidden(true)
                .photosPicker(
                    isPresented: $viewModel.isPhotoPickerPresented,
                    selection: $viewModel.selectedPhotoItem,
                    matching: .images
                )
                .onChange(of: viewModel.selectedPhotoItem) { _, newItem in
                    Task {
                        if let url = await viewModel.handleSelectedPhoto(newItem) {
                            selectedCoverUrl = url
                            dismiss()
                        }
                    }
                }
        }
        .task {
            await viewModel.loadCovers()
        }
    }

    private var coverListContent: some View {
        SwiftUI.ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(alignment: .leading, spacing: 24) {
                if viewModel.isLoading {
                    // Shimmer skeleton while loading
                    ForEach(0..<4, id: \.self) { _ in
                        shimmerSection
                    }
                } else {
                    ForEach(viewModel.coverTypes) { coverType in
                        coverTypeSection(coverType)
                    }
                }
            }
            .padding(.top, 24)
            .padding(.bottom, 48)
        }
    }

    private var shimmerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Shimmer title
            ShimmerPlaceholder()
                .frame(width: 100, height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .padding(.horizontal, 16)

            // Shimmer image grid
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { _ in
                        ShimmerPlaceholder()
                            .frame(width: 105, height: 101)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func coverTypeSection(_ coverType: EventCoverType) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section Title
            Text(coverType.displayTitle)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.rdTextPrimary)
                .padding(.horizontal, 16)

            // Horizontal scroll of covers
            SwiftUI.ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Upload button for recents section
                    if coverType.typeName == "recents" {
                        uploadCoverButton
                    }

                    // Cover images
                    ForEach(coverType.images) { image in
                        coverImageItem(image)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func coverImageItem(_ image: EventCoverImage) -> some View {
        Button {
            selectedCoverUrl = image.fullUrl
            viewModel.saveToRecents(image.fullUrl)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                dismiss()
            }
        } label: {
            ZStack {
                CachedAsyncImage(
                    url: URL(string: image.fullUrl),
                    timeout: 20.0,
                    content: { loadedImage in
                        loadedImage
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    },
                    placeholder: {
                        ShimmerPlaceholder()
                    }
                )
                .frame(width: 105, height: 101)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Selection overlay
                if selectedCoverUrl
                    == image.fullUrl {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.3))
                        .frame(width: 105, height: 101)
                        .overlay {
                            Image(systemName: "checkmark")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                        }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var uploadCoverButton: some View {
        Button {
            viewModel.showPhotoPicker()
        } label: {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: "9C9CA6").opacity(0.2))
                .frame(width: 105, height: 101)
                .overlay {
                    Image("icon_gallery_add")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(Color(hex: "9E9EAA"))
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - View Model

@MainActor
class CoverSelectionViewModel: ObservableObject {
    @Published var coverTypes: [EventCoverType] = []
    @Published var isLoading = false
    @Published var isPhotoPickerPresented = false
    @Published var selectedPhotoItem: PhotosPickerItem?

    private let coverService: EventCoverServiceProtocol
    private let recentCoversStorage: RecentCoversStorage

    init(
        coverService: EventCoverServiceProtocol = EventCoverService.shared,
        recentCoversStorage: RecentCoversStorage = .shared
    ) {
        self.coverService = coverService
        self.recentCoversStorage = recentCoversStorage
    }

    func loadCovers() async {
        isLoading = true
        defer { isLoading = false }

        do {
            var types = try await coverService.getCoversByType()

            // Build recents section from stored recent covers
            let recentUrls = recentCoversStorage.recentCovers
            let recentImages = recentUrls.map { url in
                EventCoverImage(
                    type: "recents",
                    shortName: URL(string: url)?.lastPathComponent ?? "recent",
                    fullUrl: url
                )
            }
            let recentsType = EventCoverType(typeName: "recents", images: recentImages)
            types.insert(recentsType, at: 0)

            coverTypes = types
        } catch {
            // Error handled silently - still show recents section
            let recentUrls = recentCoversStorage.recentCovers
            let recentImages = recentUrls.map { url in
                EventCoverImage(
                    type: "recents",
                    shortName: URL(string: url)?.lastPathComponent ?? "recent",
                    fullUrl: url
                )
            }
            coverTypes = [EventCoverType(typeName: "recents", images: recentImages)]
        }
    }

    /// Save a cover URL to recents
    func saveToRecents(_ url: String) {
        recentCoversStorage.addCover(url)
    }

    func showPhotoPicker() {
        isPhotoPickerPresented = true
    }

    func handleSelectedPhoto(_ item: PhotosPickerItem?) async -> String? {
        guard let item = item else { return nil }

        do {
            // Load the image data
            guard let data = try await item.loadTransferable(type: Data.self) else {
                return nil
            }

            // Upload to Firebase Storage
            let storageService = DIContainer.shared.storageService
            guard let userId = DIContainer.shared.authService.currentUser?.id else {
                return nil
            }

            // Generate unique filename
            let filename = "cover_\(UUID().uuidString).jpg"
            let path = "users/\(userId)/covers/\(filename)"

            // Upload and get URL
            let uploadedUrl = try await storageService.uploadImage(data: data, path: path)

            // Save to recents
            saveToRecents(uploadedUrl)

            return uploadedUrl
        } catch {
            // Error handled silently
            return nil
        }
    }
}

// MARK: - Shimmer Placeholder
/// Animated shimmer effect for loading images
private struct ShimmerPlaceholder: View {
    @State private var shimmerOffset: CGFloat = -1.0

    var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(Color(hex: "E5E5EA"))
                .overlay {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            Color.white.opacity(0.6),
                            Color.clear
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 0.6)
                    .offset(x: shimmerOffset * geometry.size.width * 1.5)
                }
                .clipped()
        }
        .onAppear {
            withAnimation(
                Animation
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
            ) {
                shimmerOffset = 2.0
            }
        }
    }
}

// MARK: - Preview
// Using CachedAsyncImage from Core/Helpers/CachedAsyncImage.swift

#Preview {
    CoverSelectionSheet(selectedCoverUrl: .constant(nil))
}
