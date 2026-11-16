import Observation
import SwiftUI

/// Navigation state for the whole app: the selected tab, the push stack
/// above the tabs, and whichever sheet is up. Lives at the root so a
/// notification tap or a banner anywhere can open any screen.
@MainActor
@Observable
final class AppRouter {
    enum Tab: Hashable, CaseIterable {
        case today, medicines, settings

        var title: String {
            switch self {
            case .today: "Today"
            case .medicines: "Medicines"
            case .settings: "Settings"
            }
        }

        /// Outline glyph when unselected, filled when selected.
        func image(selected: Bool) -> Image {
            let name = String(describing: self)
            return Image(selected ? "tab-\(name)-fill" : "tab-\(name)")
        }
    }

    enum Route: Hashable {
        case medicine(UUID)
        case settings(SettingsPage)
    }

    enum Sheet: Identifiable {
        case addMedicine
        /// Add, starting from a name typed into search.
        case addMedicineNamed(String)
        case editMedicine(UUID)
        case refill(UUID)
        /// "Where did you inject?" before an injection is ticked off.
        case injectionSite(ScheduledDose)
        case notificationPermission
        /// `reason` says why it opened, when something hit the free limit.
        case paywall(reason: String?)

        var id: String {
            switch self {
            case .addMedicine: "add"
            case .addMedicineNamed(let name): "add-\(name)"
            case .editMedicine(let id): "edit-\(id)"
            case .refill(let id): "refill-\(id)"
            case .injectionSite(let dose): "site-\(dose.id)"
            case .notificationPermission: "permission"
            case .paywall: "paywall"
            }
        }
    }

    /// Something Today should open as soon as it's on screen — from a
    /// deep link, a widget or a notification.
    enum TodayRequest: Equatable {
        case mood, calendar
        /// Show this day's doses.
        case day(Date)
    }

    var selectedTab: Tab = .today
    var todayRequest: TodayRequest?
    var path: [Route] = []
    var sheet: Sheet?
    /// The message at the top of the screen, drawn by `OverlayWindow` above
    /// everything, sheets included.
    private(set) var toast: Toast?
    /// Bumped to fire confetti for a moment worth celebrating.
    private(set) var celebrations = 0
    private var toastTask: Task<Void, Never>?

    func openMedicine(_ id: UUID) {
        sheet = nil
        selectedTab = .medicines
        path = [.medicine(id)]
    }

    /// Opens Add, or the paywall once a free user is at the medicine limit.
    func requestAddMedicine(named name: String? = nil, count: Int, purchases: PurchaseStore) {
        guard purchases.canAddMedicine(count: count) else {
            let limit = PurchaseStore.freeMedicineLimit
            sheet = .paywall(reason: "You’re tracking \(limit) medicines, the free limit. Go Pro to add more.")
            return
        }
        if let name, !name.isEmpty {
            sheet = .addMedicineNamed(name)
        } else {
            sheet = .addMedicine
        }
    }

    // MARK: Deep links

    /// Opens what a `doseday://` link points at — from the widgets and
    /// anywhere else that links into the app:
    /// `doseday://today`, `doseday://day/<yyyy-MM-dd>`, `doseday://medicine/<id>`,
    /// `doseday://mood`, `doseday://calendar`, `doseday://add`, `doseday://pro`.
    func handle(_ url: URL, medicineCount: Int, purchases: PurchaseStore) {
        guard url.scheme == "doseday" else { return }
        let argument = url.pathComponents.dropFirst().first
        switch url.host() {
        case "today":
            showToday(nil)
        case "day":
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            showToday(argument.flatMap { formatter.date(from: $0) }.map { .day($0) })
        case "medicine":
            if let id = argument.flatMap(UUID.init(uuidString:)) { openMedicine(id) }
        case "mood":
            showToday(.mood)
        case "calendar":
            showToday(.calendar)
        case "add":
            showToday(nil)
            requestAddMedicine(count: medicineCount, purchases: purchases)
        case "pro":
            showToday(nil)
            if !purchases.isPro { sheet = .paywall(reason: nil) }
        default:
            break
        }
    }

    /// Today, on top, with an optional thing to open there.
    func showToday(_ request: TodayRequest?) {
        sheet = nil
        path = []
        selectedTab = .today
        todayRequest = request
    }

    func push(_ route: Route) {
        path.append(route)
    }

    /// A quick success confirmation ("Refilled. Next reminder Tue 24 Oct.").
    func showToast(_ message: String) {
        show(.success(message))
    }

    func show(_ toast: Toast) {
        var toast = toast
        // A result replacing a spinner keeps its place, so it morphs.
        if let current = self.toast, current.style == .loading { toast.id = current.id }
        toastTask?.cancel()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) { self.toast = toast }
        toast.style.playHaptic()
        AccessibilityNotification.Announcement(toast.title).post()
        guard let duration = toast.style.duration else { return }
        toastTask = Task {
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            dismissToast()
        }
    }

    func dismissToast() {
        toastTask?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { toast = nil }
    }

    /// Runs `operation` under a loading toast, then turns it into a success
    /// or an error. Returns whether it worked.
    @discardableResult
    func withLoadingToast(
        _ loading: String,
        success: Toast,
        failureTitle: String,
        operation: () async throws -> Void
    ) async -> Bool {
        show(.loading(loading))
        do {
            try await operation()
            show(success)
            return true
        } catch {
            show(.error(failureTitle, message: error.localizedDescription))
            return false
        }
    }

    /// Confetti, for a step worth celebrating.
    func celebrate() {
        celebrations += 1
    }
}
