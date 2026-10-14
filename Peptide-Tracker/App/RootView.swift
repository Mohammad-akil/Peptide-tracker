import SwiftUI

/// One navigation stack over the tab shell, so pushed screens (medicine
/// detail, insights) cover the floating tab bar like the design shows, and
/// every sheet is presented from one place.
struct RootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(MedicineStore.self) private var store
    /// Set when the first medicine is saved; the "why we ask" sheet follows
    /// once the add sheet has gone.
    @State private var shouldAskForNotifications = false
    @Environment(PurchaseStore.self) private var purchases
    /// Kept from the old welcome screen so existing users skip setup.
    @AppStorage("welcome.seen") private var hasSeenWelcome = false
    @State private var showsOnboarding = false
    /// After setup: the paywall, then Add once it closes.
    @State private var showsSetupPaywall = false

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            MainTabView()
                .navigationDestination(for: AppRouter.Route.self) { route in
                    switch route {
                    case .medicine(let id):
                        MedicineDetailView(medicineID: id)
                    }
                }
        }
        .overlay(alignment: .top) {
            if let toast = router.toast {
                Label(toast, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.ColorToken.primaryText)
                    .symbolRenderingMode(.multicolor)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .accessibilityAddTraits(.isStaticText)
            }
        }
        .fullScreenCover(isPresented: $showsOnboarding) {
            OnboardingFlow(startingAt: debugOnboardingStep ?? .getStarted) { _ in finishOnboarding() }
        }
        .fullScreenCover(isPresented: $showsSetupPaywall, onDismiss: openAddAfterSetup) {
            PaywallView()
        }
        .onAppear {
            if !hasSeenWelcome && store.medicines.isEmpty { showsOnboarding = true }
            #if DEBUG
            // `-onboarding time` opens setup on a step; `-paywall YES` opens Pro.
            if debugOnboardingStep != nil { showsOnboarding = true }
            if UserDefaults.standard.bool(forKey: "paywall") { router.sheet = .paywall(reason: nil) }
            #endif
        }
        .sheet(item: $router.sheet, onDismiss: presentPermissionIfNeeded) { sheet in
            switch sheet {
            case .addMedicine:
                AddMedicineView(editing: nil) { isFirstMedicine in
                    if isFirstMedicine { shouldAskForNotifications = true }
                }
            case .addMedicineNamed(let name):
                AddMedicineView(editing: nil, name: name) { isFirstMedicine in
                    if isFirstMedicine { shouldAskForNotifications = true }
                }
            case .editMedicine(let id):
                AddMedicineView(editing: store.medicine(id: id)) { _ in }
            case .refill(let id):
                RefillSheet(medicineID: id)
                    .presentationDetents([.height(560)])
                    .presentationCornerRadius(44)
            case .paywall(let reason):
                PaywallView(reason: reason)
            case .notificationPermission:
                NotificationPermissionSheet()
                    .presentationDetents([.height(520)])
                    .presentationCornerRadius(44)
            }
        }
    }

    private var debugOnboardingStep: OnboardingStep? {
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
    RootView()
        .environment(MedicineStore.preview())
        .environment(AppRouter())
        .environment(PurchaseStore())
}
