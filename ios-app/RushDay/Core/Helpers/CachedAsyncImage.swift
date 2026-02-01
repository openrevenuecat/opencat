import SwiftUI

// MARK: - Image Cache Manager

class ImageCache {
    static let shared = ImageCache()

    private let cache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    private init() {
        // Create cache directory
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("ImageCache")

        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // Configure cache limits
        cache.countLimit = 200 // Max 200 images in memory
        cache.totalCostLimit = 100 * 1024 * 1024 // 100 MB memory limit
    }

    func get(forKey key: String) -> UIImage? {
        // Check memory cache first
        if let cachedImage = cache.object(forKey: key as NSString) {
            return cachedImage
        }

        // Check disk cache
        let fileURL = cacheDirectory.appendingPathComponent(key.toFileName())
        if let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            // Store in memory for next time
            cache.setObject(image, forKey: key as NSString)
            return image
        }

        return nil
    }

    func set(_ image: UIImage, forKey key: String) {
        // Store in memory
        cache.setObject(image, forKey: key as NSString)

        // Store on disk
        let fileURL = cacheDirectory.appendingPathComponent(key.toFileName())
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: fileURL)
        }
    }

    func clearMemoryCache() {
        cache.removeAllObjects()
    }

    func clearDiskCache() {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    /// Prefetch an image from URL and cache it for later use
    func prefetch(url: URL?) {
        guard let url = url else { return }
        let cacheKey = url.absoluteString

        // Skip if already cached
        if get(forKey: cacheKey) != nil {
            return
        }

        // Download in background
        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)

                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200,
                      let downloadedImage = UIImage(data: data) else {
                    return
                }

                // Cache the image
                set(downloadedImage, forKey: cacheKey)
            } catch {
                // Prefetch failed silently
            }
        }
    }

    /// Prefetch multiple images
    func prefetch(urls: [URL?]) {
        for url in urls {
            prefetch(url: url)
        }
    }
}

private extension String {
    func toFileName() -> String {
        // Convert URL to safe filename
        return self
            .addingPercentEncoding(withAllowedCharacters: .alphanumerics)?
            .replacingOccurrences(of: "%", with: "_")
            ?? UUID().uuidString
    }
}

// MARK: - Cached Async Image View

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let timeout: TimeInterval
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var loadFailed = false
    @State private var showImage = false

    // Check cache synchronously on init for instant display
    private let cachedImage: UIImage?

    init(
        url: URL?,
        timeout: TimeInterval = 15.0,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.timeout = timeout
        self.content = content
        self.placeholder = placeholder

        // Synchronously check cache on init - this makes cached images appear instantly
        if let url = url {
            self.cachedImage = ImageCache.shared.get(forKey: url.absoluteString)
        } else {
            self.cachedImage = nil
        }
    }

    var body: some View {
        ZStack {
            // Always show placeholder behind
            placeholder()

            if let image = image {
                // Image loaded asynchronously - fade in
                content(Image(uiImage: image))
                    .opacity(showImage ? 1 : 0)
                    .onAppear {
                        withAnimation(.easeIn(duration: 0.3)) {
                            showImage = true
                        }
                    }
            } else if let cachedImage = cachedImage {
                // Image found in cache on init - display immediately (no animation needed)
                content(Image(uiImage: cachedImage))
            } else if !loadFailed {
                Color.clear
                    .task {
                        await loadImage()
                    }
            }
        }
    }

    private func loadImage() async {
        guard let url = url else {
            loadFailed = true
            return
        }

        let cacheKey = url.absoluteString

        // Double-check cache (might have been loaded by another view)
        if let cachedImage = ImageCache.shared.get(forKey: cacheKey) {
            self.image = cachedImage
            return
        }

        // Download with timeout
        isLoading = true

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let downloadedImage = UIImage(data: data) else {
                loadFailed = true
                return
            }

            // Cache the image
            ImageCache.shared.set(downloadedImage, forKey: cacheKey)

            // Update UI
            await MainActor.run {
                self.image = downloadedImage
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.loadFailed = true
                self.isLoading = false
            }
        }
    }
}

// MARK: - Convenience Initializer

extension CachedAsyncImage where Content == Image, Placeholder == Color {
    init(url: URL?, timeout: TimeInterval = 15.0) {
        self.init(
            url: url,
            timeout: timeout,
            content: { image in image },
            placeholder: { Color.gray.opacity(0.2) }
        )
    }
}
