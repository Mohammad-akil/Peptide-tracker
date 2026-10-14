import SwiftUI

/// The tab shell from the design: four tabs in a floating Liquid Glass bar
/// with a separate round "+" beside it for adding a medicine. Every tab stays
/// mounted so scroll positions survive switching.
struct MainTabView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        ZStack {
            AppTheme.ColorToken.background.ignoresSafeArea()

            ForEach(AppRouter.Tab.allCases, id: \.self) { tab in
                let isSelected = router.selectedTab == tab
                content(for: tab)
                    .opacity(isSelected ? 1 : 0)
                    .allowsHitTesting(isSelected)
                    .accessibilityHidden(!isSelected)
            }
        }
        .overlay(alignment: .bottom) {
            FloatingTabBar()
                .padding(.horizontal, 14)
                .padding(.bottom, 4)
        }
        .toolbarVisibility(.hidden, for: .navigationBar)
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

private struct FloatingTabBar: View {
    @Environment(AppRouter.self) private var router
    @Environment(MedicineStore.self) private var store
    @Environment(PurchaseStore.self) private var purchases
    @Namespace private var selection

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                HStack(spacing: 2) {
                    ForEach(AppRouter.Tab.allCases, id: \.self) { tab in
                        tabButton(tab)
                    }
                }
                .padding(.horizontal, 5)
                .frame(height: 64)
                .glassEffect(.regular.interactive(), in: .capsule)

                Button {
                    HapticFeedback.impact(.medium)
                    router.requestAddMedicine(count: store.medicines.count, purchases: purchases)
                } label: {
                    Icon(.plus, size: 28)
                        .foregroundStyle(AppTheme.ColorToken.accent)
                        .frame(width: 64, height: 64)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Add medicine")
            }
        }
        .background(alignment: .bottom) {
            // Soft fade so scrolling content doesn't fight the glass.
            LinearGradient(
                colors: [AppTheme.ColorToken.background.opacity(0), AppTheme.ColorToken.background.opacity(0.9)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 130)
            .padding(.horizontal, -14)
            .offset(y: 40)
            .allowsHitTesting(false)
            .ignoresSafeArea()
        }
    }

    private func tabButton(_ tab: AppRouter.Tab) -> some View {
        let isSelected = router.selectedTab == tab
        return Button {
            guard !isSelected else { return }
            HapticFeedback.selection()
            withAnimation(.snappy(duration: 0.3)) { router.selectedTab = tab }
        } label: {
            VStack(spacing: 2) {
                tab.image(selected: isSelected)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)
                Text(tab.title)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(isSelected ? AppTheme.ColorToken.accent : AppTheme.ColorToken.primaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background {
                if isSelected {
                    Capsule()
                        .fill(AppTheme.ColorToken.controlFill.opacity(1.2))
                        .matchedGeometryEffect(id: "selection", in: selection)
                }
            }
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    MainTabView()
        .environment(MedicineStore.preview())
        .environment(AppRouter())
        .environment(PurchaseStore())
}
