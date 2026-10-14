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
    /// A short confirmation shown above everything ("Refilled. Reminder
    /// moved to 24 Oct").
    private(set) var toast: String?
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

    func showToast(_ message: String) {
        toastTask?.cancel()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { toast = message }
        toastTask = Task {
            try? await Task.sleep(for: .seconds(2.6))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) { toast = nil }
        }
    }
}
