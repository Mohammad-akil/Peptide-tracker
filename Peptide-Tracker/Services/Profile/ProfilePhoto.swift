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

    static func load() -> UIImage? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    /// Scales the picked image down and saves it. Returns what was saved.
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
        return resized
    }

    static func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}
