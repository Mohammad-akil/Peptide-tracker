import SwiftUI

/// The tab shell: the system tab bar with the four tabs, and "+" for adding
/// a medicine in the separate round slot beside it. "+" opens Add (or the
/// paywall) instead of becoming a tab.
struct MainTabView: View {
    @Environment(AppRouter.self) private var router
    @Environment(MedicineStore.self) private var store
    @Environment(PurchaseStore.self) private var purchases

    /// What the tab bar can select: a real tab, or the "+" slot.
    private enum Item: Hashable {
        case tab(AppRouter.Tab)
        case add
    }

    var body: some View {
        TabView(selection: selection) {
            ForEach(AppRouter.Tab.allCases, id: \.self) { tab in
                Tab(value: Item.tab(tab)) {
                    content(for: tab)
                } label: {
                    Label {
                        Text(tab.title)
                    } icon: {
                        tab.image(selected: router.selectedTab == tab)
                    }
                }
            }

            // The search role puts "+" in its own circle, apart from the tabs.
            Tab(value: Item.add, role: .search) {
                Color.clear
            } label: {
                Label {
                    Text("Add medicine")
                } icon: {
                    Image("icon-plus")
                }
            }
        }
        .tint(AppTheme.ColorToken.accent)
        .toolbarVisibility(.hidden, for: .navigationBar)
    }

    /// Keeps "+" from ever becoming the selected tab.
    private var selection: Binding<Item> {
        Binding {
            .tab(router.selectedTab)
        } set: { item in
            switch item {
            case .tab(let tab):
                guard tab != router.selectedTab else { return }
                HapticFeedback.selection()
                router.selectedTab = tab
            case .add:
                HapticFeedback.impact(.medium)
                router.requestAddMedicine(count: store.medicines.count, purchases: purchases)
            }
        }
    }

    @ViewBuilder
    private func content(for tab: AppRouter.Tab) -> some View {
        switch tab {
        case .today: TodayView()
        case .medicines: MedicinesView()
        case .refills: RefillsView()
        case .settings: SettingsView()
        }
    }
}

#Preview {
    MainTabView()
        .environment(MedicineStore.preview())
        .environment(AppRouter())
        .environment(PurchaseStore())
}
