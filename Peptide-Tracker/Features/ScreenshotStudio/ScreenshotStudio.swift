#if DEBUG
import Photos
import SwiftUI
import UIKit

/// App Store screenshots made inside the app, debug builds only — the same
/// idea as Plates' Screenshot Studio. Settings → Developer → Screenshot
/// Studio lists every major screen; "Capture all" walks through them with
/// demo data and keeps a full-resolution PNG of each. With Screenshot mode
/// on, a floating download button sits on every screen and saves exactly
/// what's showing to Photos. The button lives in its own window, so it is
/// never in the picture.
@MainActor
@Observable
final class ScreenshotStudio {
    static let shared = ScreenshotStudio()

    struct Shot: Identifiable {
        let id = UUID()
        let title: String
        let image: UIImage
        let url: URL
    }

    /// The floating download button on every screen.
    var isModeOn: Bool = UserDefaults.standard.bool(forKey: "studio.mode") {
        didSet {
            UserDefaults.standard.set(isModeOn, forKey: "studio.mode")
            StudioButtonWindow.update()
        }
    }

    private(set) var shots: [Shot] = []
    private(set) var isCapturingAll = false
    private(set) var progress: String?
    /// Counts single downloads, for their file names.
    private var singleCount = 0

    // MARK: Capturing

    /// The app's own window — not the toast, lock or button windows.
    private static var appWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.windowLevel == .normal && !$0.isHidden }
    }

    /// The app window as it looks now, at the screen's full resolution
    /// (1320 × 2868 on iPhone 17 Pro Max, 2064 × 2752 on iPad Pro 13").
    func capture(title: String) -> Shot? {
        guard let window = Self.appWindow else { return nil }
        let format = UIGraphicsImageRendererFormat(for: window.traitCollection)
        format.scale = window.screen.scale
        format.opaque = true
        let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let folder = FileManager.default.temporaryDirectory.appending(path: "Doseday Screenshots")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: "\(title).png")
        guard let data = image.pngData(), (try? data.write(to: url, options: .atomic)) != nil else { return nil }
        return Shot(title: title, image: image, url: url)
    }

    /// The floating button: this screen, straight to Photos.
    func downloadCurrentScreen(router: AppRouter) async {
        singleCount += 1
        let name = "Doseday \(Self.stamp) \(singleCount)"
        guard let shot = capture(title: name) else {
            router.show(.error("Couldn’t capture the screen"))
            return
        }
        shots.append(shot)
        if await Self.saveToPhotos([shot.image]) {
            router.show(.success("Saved to Photos", message: "\(Int(shot.image.size.width * shot.image.scale)) × \(Int(shot.image.size.height * shot.image.scale))"))
        } else {
            router.show(.warning("Allow Photos access", message: "Settings → Doseday → Photos, or share it from the Studio."))
        }
    }

    /// Opens every screen in turn and captures it, then comes back to the
    /// Studio with the results.
    func captureAll(_ scenes: [ScreenshotScene], router: AppRouter, store: MedicineStore) async {
        guard !isCapturingAll else { return }
        isCapturingAll = true
        shots.removeAll()
        router.sheet = nil
        StudioButtonWindow.update()
        try? await Task.sleep(for: .milliseconds(700))

        for (index, scene) in scenes.enumerated() {
            progress = "\(index + 1) of \(scenes.count): \(scene.title)"
            scene.open(router: router, store: store)
            // Long enough for pushes, sheets and charts to settle.
            try? await Task.sleep(for: .milliseconds(1800))
            let number = String(format: "%02d", index + 1)
            if let shot = capture(title: "\(number) \(scene.title)") { shots.append(shot) }
        }

        progress = nil
        router.sheet = nil
        router.path = []
        router.selectedTab = .settings
        try? await Task.sleep(for: .milliseconds(500))
        isCapturingAll = false
        StudioButtonWindow.update()
        router.sheet = .screenshotStudio
    }

    func clear() {
        shots.removeAll()
        try? FileManager.default.removeItem(at: FileManager.default.temporaryDirectory.appending(path: "Doseday Screenshots"))
    }

    // MARK: Saving

    static func saveToPhotos(_ images: [UIImage]) async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return false }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                for image in images { PHAssetChangeRequest.creationRequestForAsset(from: image) }
            }
            return true
        } catch {
            return false
        }
    }

    private static var stamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH.mm.ss"
        return formatter.string(from: .now)
    }
}

// MARK: - Studio

/// Settings → Developer → Screenshot Studio.
struct ScreenshotStudioView: View {
    @Environment(MedicineStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppearanceMode.storageKey) private var appearance = AppearanceMode.system.rawValue
    @State private var studio = ScreenshotStudio.shared
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: $studio.isModeOn) {
                        Label("Floating download button", systemImage: "arrow.down.circle.fill")
                    }
                    Picker(selection: $appearance) {
                        Text("Light").tag(AppearanceMode.light.rawValue)
                        Text("Dark").tag(AppearanceMode.dark.rawValue)
                        Text("System").tag(AppearanceMode.system.rawValue)
                    } label: {
                        Label("Appearance", systemImage: "circle.lefthalf.filled")
                    }
                } footer: {
                    Text("With the button on, tap it on any screen to save exactly what’s showing to Photos at full resolution. The button itself is never in the picture. Long-press it for the Studio.")
                }

                Section {
                    Button {
                        Task { await studio.captureAll(ScreenshotScene.allCases, router: router, store: store) }
                    } label: {
                        Label("Capture all \(ScreenshotScene.allCases.count) screens", systemImage: "camera.on.rectangle.fill")
                            .fontWeight(.semibold)
                    }
                    .disabled(studio.isCapturingAll)
                } footer: {
                    Text("Loads demo data and captures every screen below in order. For the App Store, run it on iPhone 17 Pro Max (6.9\") and iPad Pro 13\", in light mode.")
                }

                if !studio.shots.isEmpty {
                    capturedSection
                }

                Section("App Store screens") {
                    ForEach(Array(ScreenshotScene.allCases.enumerated()), id: \.element) { index, scene in
                        Button { open(scene) } label: {
                            HStack(spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 26, height: 26)
                                    .background(AppTheme.ColorToken.accent, in: .circle)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(scene.title).foregroundStyle(AppTheme.ColorToken.primaryText)
                                    Text(scene.hint)
                                        .font(.footnote)
                                        .foregroundStyle(AppTheme.ColorToken.secondaryText)
                                }
                                Spacer()
                                Image(systemName: scene.symbol)
                                    .foregroundStyle(AppTheme.ColorToken.tertiaryText)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Screenshot Studio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var capturedSection: some View {
        Section {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 10) {
                    ForEach(studio.shots) { shot in
                        VStack(spacing: 4) {
                            Image(uiImage: shot.image)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 170)
                                .clipShape(.rect(cornerRadius: 10, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(AppTheme.ColorToken.separator)
                                }
                            Text(shot.title)
                                .font(.caption2)
                                .foregroundStyle(AppTheme.ColorToken.secondaryText)
                                .lineLimit(1)
                                .frame(maxWidth: 90)
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .scrollIndicators(.hidden)

            Button {
                Task {
                    isSaving = true
                    let saved = await ScreenshotStudio.saveToPhotos(studio.shots.map(\.image))
                    isSaving = false
                    router.show(saved
                        ? .success("\(studio.shots.count) screenshots saved to Photos")
                        : .warning("Allow Photos access", message: "Or use Share to save them to Files."))
                }
            } label: {
                Label(isSaving ? "Saving…" : "Save all to Photos", systemImage: "square.and.arrow.down.fill")
            }
            .disabled(isSaving)

            ShareLink(items: studio.shots.map(\.url)) {
                Label("Share PNGs (AirDrop, Files…)", systemImage: "square.and.arrow.up")
            }

            Button("Clear", role: .destructive) { studio.clear() }
        } header: {
            Text("Captured (\(studio.shots.count))")
        }
    }

    private func open(_ scene: ScreenshotScene) {
        studio.isModeOn = true
        dismiss()
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            scene.open(router: router, store: store)
        }
    }
}

// MARK: - Floating download button

/// The window the floating button lives in, above the app and its sheets.
/// Touches pass through everywhere except the button.
@MainActor
enum StudioButtonWindow {
    private static var window: StudioPassthroughWindow?

    static func install(router: AppRouter) {
        guard window == nil,
              let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else { return }
        let window = StudioPassthroughWindow(windowScene: scene)
        window.overrideUserInterfaceStyle = AppearanceMode.current.interfaceStyle
        let host = UIHostingController(
            rootView: StudioDownloadButton { frame in window.touchableFrame = frame }
                .environment(router)
                .fontDesign(.rounded)
        )
        host.view.backgroundColor = .clear
        window.rootViewController = host
        window.windowLevel = .alert + 1
        window.backgroundColor = .clear
        self.window = window
        update()
    }

    /// Shown while Screenshot mode is on, hidden while capturing all.
    static func update() {
        let studio = ScreenshotStudio.shared
        window?.isHidden = !studio.isModeOn || studio.isCapturingAll
    }
}

private final class StudioPassthroughWindow: UIWindow {
    var touchableFrame: CGRect = .zero

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        touchableFrame.contains(point)
    }
}

private struct StudioDownloadButton: View {
    let reportFrame: (CGRect) -> Void
    @Environment(AppRouter.self) private var router
    @State private var isBusy = false

    var body: some View {
        Menu {
            Button("Open Screenshot Studio", systemImage: "camera.viewfinder") {
                router.sheet = .screenshotStudio
            }
            Button("Hide button", systemImage: "eye.slash") {
                ScreenshotStudio.shared.isModeOn = false
            }
        } label: {
            Image(systemName: isBusy ? "hourglass" : "arrow.down.to.line")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(AppTheme.ColorToken.accent.gradient, in: .circle)
                .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1))
                .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
        } primaryAction: {
            guard !isBusy else { return }
            isBusy = true
            HapticFeedback.impact()
            Task {
                await ScreenshotStudio.shared.downloadCurrentScreen(router: router)
                isBusy = false
            }
        }
        .accessibilityLabel("Save this screen to Photos")
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { reportFrame($0) }
        .padding(.trailing, 18)
        .padding(.bottom, 150)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }
}
#endif
