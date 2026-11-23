import UIKit

/// The user's profile photo, kept beside the medicines file in Application
/// Support and never sent anywhere. Saved small: it's only ever shown in a
/// circle.
enum ProfilePhoto {
    private static let url: URL = {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "profile.jpg")
    }()

    /// The longest side it's stored at, in pixels.
    private static let maxSide: CGFloat = 512

    /// The decoded photo, kept in memory once loaded so Settings shows it
    /// without touching the disk. Nil until `preload()` finishes, or when
    /// there's no photo.
    @MainActor private(set) static var cached: UIImage?
    @MainActor private static var hasLoaded = false

    /// Reads and decodes the photo off the main thread (during the splash),
    /// so the first visit to Settings never waits on the file.
    @MainActor
    static func preload() async {
        guard !hasLoaded else { return }
        let file = url
        let image = await Task.detached(priority: .utility) { () -> UIImage? in
            guard let data = try? Data(contentsOf: file), let image = UIImage(data: data) else { return nil }
            // Decode now, not on first draw.
            return await image.byPreparingForDisplay() ?? image
        }.value
        cached = image
        hasLoaded = true
    }

    /// The cached photo, loading it in the background first if needed.
    @MainActor
    static func load() async -> UIImage? {
        await preload()
        return cached
    }

    /// Scales the picked image down and saves it. Returns what was saved.
    @MainActor
    @discardableResult
    static func save(_ data: Data) -> UIImage? {
        guard let image = UIImage(data: data) else { return nil }
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let jpeg = resized.jpegData(compressionQuality: 0.85) else { return nil }
        try? jpeg.write(to: url, options: [.atomic, .completeFileProtection])
        cached = resized
        hasLoaded = true
        return resized
    }

    @MainActor
    static func remove() {
        try? FileManager.default.removeItem(at: url)
        cached = nil
        hasLoaded = true
    }
}
