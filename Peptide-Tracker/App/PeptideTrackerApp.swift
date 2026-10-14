import SwiftUI

@main
struct PeptideTrackerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appDelegate.store)
                .environment(appDelegate.router)
                .environment(appDelegate.purchases)
                .tint(AppTheme.ColorToken.accent)
                .onChange(of: scenePhase) { _, phase in
                    // Days may have ended while the app was in the background.
                    if phase == .active { appDelegate.store.runDailyCountdown() }
                }
        }
    }
}
