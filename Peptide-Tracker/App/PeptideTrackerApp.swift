import SwiftUI

@main
struct PeptideTrackerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    @State private var isShowingLaunchScreen = true
    @State private var isFinishingLaunchAnimation = false
    @State private var isRevealingApp = false
    /// Decided while the splash is up, so the first screen (Get started or
    /// the app) is mounted once and never swapped or slid in.
    @State private var startsWithOnboarding: Bool?

    private static let minimumSplashDuration = SplashScreenView.entranceDuration
    private static let logoExitDuration: Duration = .milliseconds(380)
    private static let contentRevealDuration: Duration = .milliseconds(400)

    var body: some Scene {
        WindowGroup {
            ZStack {
                if let startsWithOnboarding {
                    RootView(startsWithOnboarding: startsWithOnboarding)
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
            .tint(AppTheme.ColorToken.accent)
            .task { await runSplashSequence() }
            .onChange(of: scenePhase) { _, phase in
                // Days may have ended while the app was in the background.
                if phase == .active { appDelegate.store.runDailyCountdown() }
            }
        }
    }

    // MARK: - Splash

    /// Holds the splash for a minimum beat while checking whether setup is
    /// done, lets the icon exit, then crossfades into the first screen.
    private func runSplashSequence() async {
        let needsOnboarding = RootView.needsOnboarding(store: appDelegate.store)
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
    }
}
