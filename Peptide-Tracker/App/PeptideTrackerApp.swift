import SwiftUI

@main
struct PeptideTrackerApp: App {
    @AppStorage(AppearanceMode.storageKey) private var appearanceModeRaw = AppearanceMode.system.rawValue
    @AppStorage(AppLanguage.storageKey) private var appLanguageRaw = ""
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    @State private var isShowingLaunchScreen = true
    @State private var isFinishingLaunchAnimation = false
    @State private var isRevealingApp = false
    /// Decided while the splash is up, so the first screen (Get started or
    /// the app) is mounted once and never swapped or slid in.
    @State private var startsWithOnboarding: Bool?

    private static let minimumSplashDuration = SplashScreenView.entranceDuration
    private static let logoExitDuration: Duration = .milliseconds(250)
    private static let contentRevealDuration: Duration = .milliseconds(300)

    init() {
        // Before any view reads a string, so the first frame is already in
        // the chosen language.
        AppLanguage.applyStoredChoice()
    }

    private var appLanguage: AppLanguage { AppLanguage(rawValue: appLanguageRaw) ?? .deviceDefault }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if let startsWithOnboarding {
                    RootView(startsWithOnboarding: startsWithOnboarding)
                        // A language switch rebuilds the tree so every string
                        // is read again from the new language.
                        .id(appLanguageRaw)
                        .opacity(isRevealingApp ? 1 : 0)
                        .scaleEffect(isRevealingApp ? 1 : 1.008)
                }

                if isShowingLaunchScreen {
                    SplashScreenView(
                        isFinishing: isFinishingLaunchAnimation,
                        isRevealingApp: isRevealingApp
                    )
                    .zIndex(1)
                }
            }
            .environment(appDelegate.store)
            .environment(appDelegate.router)
            .environment(appDelegate.purchases)
            .environment(\.locale, appLanguageRaw.isEmpty ? .current : appLanguage.locale)
            .environment(\.layoutDirection, appLanguage.layoutDirection)
            .tint(AppTheme.ColorToken.accent)
            // SF Pro Rounded everywhere: every `.system` font picks it up.
            .fontDesign(.rounded)
            .task { await runSplashSequence() }
            // doseday:// links, from the widgets and elsewhere.
            .onChange(of: appearanceModeRaw, initial: true) { _, raw in
                (AppearanceMode(rawValue: raw) ?? .system).apply()
            }
            .onOpenURL { url in
                appDelegate.router.handle(url, medicineCount: appDelegate.store.medicines.count, purchases: appDelegate.purchases)
            }
            .onChange(of: scenePhase) { _, phase in
                AppLock.shared.scenePhaseChanged(phase, enabled: appDelegate.store.settings.appLock)
                // Days may have ended while the app was in the background.
                if phase == .active {
                    // A new day may have started; refetch what depends on it.
                    QueryClient.shared.invalidate(.day)
                    // Doses and moods logged from a widget while away.
                    appDelegate.store.reloadFromDisk()
                    appDelegate.store.runDailyCountdown()
                }
            }
        }
    }

    // MARK: - Splash

    /// Plays the splash with nothing else on the main thread, lets the icon
    /// exit, crossfades into the first screen, and only then warms the
    /// caches, so the animation never stutters.
    private func runSplashSequence() async {
        let needsOnboarding = RootView.needsOnboarding(store: appDelegate.store)
        // The splash is on screen now; do the launch work that was waiting.
        await Task.yield()
        appDelegate.finishLaunching()
        try? await Task.sleep(for: Self.minimumSplashDuration)
        guard !Task.isCancelled else { return }

        isFinishingLaunchAnimation = true
        try? await Task.sleep(for: Self.logoExitDuration)
        guard !Task.isCancelled else { return }

        startsWithOnboarding = needsOnboarding
        await Task.yield()

        withAnimation(.easeInOut(duration: 0.42)) {
            isRevealingApp = true
        }

        try? await Task.sleep(for: Self.contentRevealDuration)
        guard !Task.isCancelled else { return }
        isShowingLaunchScreen = false

        // Now the app is on screen: warm Calendar, Report, the catalogue and
        // the profile photo, a frame after the splash has gone.
        await Task.yield()
        appDelegate.store.preload()
        // Then bring in anything from iCloud and back up what's here.
        CloudSync.shared.start(store: appDelegate.store)
    }
}
