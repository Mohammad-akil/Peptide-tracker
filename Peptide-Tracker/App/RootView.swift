import SwiftUI

/// One navigation stack over the tab shell, so pushed screens (medicine
/// detail, insights) cover the tab bar like the design shows, and
/// every sheet is presented from one place.
struct RootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(MedicineStore.self) private var store
    /// Set when the first medicine is saved; the "why we ask" sheet follows
    /// once the add sheet has gone.
    @State private var shouldAskForNotifications = false
    @Environment(PurchaseStore.self) private var purchases
    /// Kept from the old welcome screen so existing users skip setup.
    @AppStorage(Self.welcomeSeenKey) private var hasSeenWelcome = false
    /// Setup is the first screen rather than a cover slid over the app;
    /// whether it shows is decided during the splash.
    @State private var showsOnboarding: Bool
    /// After setup: the paywall, then Add once it closes.
    @State private var showsSetupPaywall = false

    private static let welcomeSeenKey = "welcome.seen"

    init(startsWithOnboarding: Bool) {
        _showsOnboarding = State(initialValue: startsWithOnboarding)
    }

    /// Whether launch should open on setup: never finished it and has no
    /// medicines yet (or a debug `-onboarding <step>` launch).
    static func needsOnboarding(store: MedicineStore) -> Bool {
        if debugOnboardingStep != nil { return true }
        return !UserDefaults.standard.bool(forKey: welcomeSeenKey) && store.medicines.isEmpty
    }

    var body: some View {
        ZStack {
            if showsOnboarding {
                OnboardingFlow(startingAt: Self.debugOnboardingStep ?? .getStarted) { _ in finishOnboarding() }
                    .transition(.opacity)
            } else {
                app
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: showsOnboarding)
        // Toasts and confetti draw in their own window above every sheet.
        .onAppear { OverlayWindow.install(router: router) }
    }

    private var app: some View {
        @Bindable var router = router

        return NavigationStack(path: $router.path) {
            MainTabView()
                .navigationDestination(for: AppRouter.Route.self) { route in
                    switch route {
                    case .medicine(let id):
                        MedicineDetailView(medicineID: id)
                    }
                }
        }
        .fullScreenCover(isPresented: $showsSetupPaywall, onDismiss: openAddAfterSetup) {
            PaywallView()
        }
        .onAppear {
            #if DEBUG
            // `-onboarding time` opens setup on a step; `-paywall YES` opens Pro.
            if UserDefaults.standard.bool(forKey: "paywall") { router.sheet = .paywall(reason: nil) }
            #endif
        }
        .sheet(item: $router.sheet, onDismiss: presentPermissionIfNeeded) { sheet in
            switch sheet {
            case .addMedicine:
                AddMedicineFlow(onSaved: medicineAdded)
            case .addMedicineNamed(let name):
                AddMedicineFlow(name: name, onSaved: medicineAdded)
            case .editMedicine(let id):
                AddMedicineView(editing: store.medicine(id: id)) { _ in }
            case .refill(let id):
                RefillSheet(medicineID: id)
                    .presentationDetents([.height(560)])
                    .presentationCornerRadius(44)
                    // Solid white (dark grey in dark mode), not the glass sheet.
                    .presentationBackground(AppTheme.ColorToken.cardBackground)
            case .injectionSite(let dose):
                InjectionSiteSheet(dose: dose)
                    .presentationDetents([.large])
                    .presentationCornerRadius(44)
                    .presentationBackground(AppTheme.ColorToken.cardBackground)
            case .paywall(let reason):
                PaywallView(reason: reason)
            case .notificationPermission:
                NotificationPermissionSheet()
                    .presentationDetents([.height(520)])
                    .presentationCornerRadius(44)
            }
        }
    }

    private static var debugOnboardingStep: OnboardingStep? {
        #if DEBUG
        let name = UserDefaults.standard.string(forKey: "onboarding")
        return OnboardingStep.allCases.first { String(describing: $0) == name }
        #else
        return nil
        #endif
    }

    /// Leaves setup for the paywall (unless already Pro), then Add.
    private func finishOnboarding() {
        hasSeenWelcome = true
        showsOnboarding = false
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            if purchases.isPro { openAddAfterSetup() } else { showsSetupPaywall = true }
        }
    }

    private func openAddAfterSetup() {
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            router.requestAddMedicine(count: store.medicines.count, purchases: purchases)
        }
    }

    private func medicineAdded(isFirstMedicine: Bool) {
        if isFirstMedicine { shouldAskForNotifications = true }
    }

    private func presentPermissionIfNeeded() {
        guard shouldAskForNotifications else { return }
        shouldAskForNotifications = false
        Task {
            guard await store.scheduler.authorizationStatus() == .notDetermined else { return }
            router.sheet = .notificationPermission
        }
    }
}

#Preview {
    RootView(startsWithOnboarding: false)
        .environment(MedicineStore.preview())
        .environment(AppRouter())
        .environment(PurchaseStore())
}
