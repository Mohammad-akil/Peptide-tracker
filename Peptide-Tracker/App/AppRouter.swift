import Observation
import SwiftUI

/// Navigation state for the whole app: the selected tab, the push stack
/// above the tabs, and whichever sheet is up. Lives at the root so a
/// notification tap or a banner anywhere can open any screen.
@MainActor
@Observable
final class AppRouter {
    enum Tab: Hashable, CaseIterable {
        case today, medicines, refills, settings

        var title: String {
            switch self {
            case .today: "Today"
            case .medicines: "Medicines"
            case .refills: "Refills"
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
    }

    enum Sheet: Identifiable {
        case addMedicine
        /// Add, starting from a name typed into search.
        case addMedicineNamed(String)
        case editMedicine(UUID)
        case refill(UUID)
        case notificationPermission
        /// `reason` says why it opened, when something hit the free limit.
        case paywall(reason: String?)

        var id: String {
            switch self {
            case .addMedicine: "add"
            case .addMedicineNamed(let name): "add-\(name)"
            case .editMedicine(let id): "edit-\(id)"
            case .refill(let id): "refill-\(id)"
            case .notificationPermission: "permission"
            case .paywall: "paywall"
            }
        }
    }

    var selectedTab: Tab = .today
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
