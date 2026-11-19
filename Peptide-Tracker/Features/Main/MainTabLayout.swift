import SwiftUI

/// Which tab bar the app uses. iPhone on iOS 26 keeps the native `TabView`
/// bar (Liquid Glass, with "+" in its own circle). Before iOS 26 the native
/// bar is the old flat one, so a floating capsule stands in. Same split as
/// Plates' `MainTabLayout`.
enum MainTabLayout {
    static var usesCustomTabBar: Bool { LegacyStyle.isActive }
}

/// The iOS 18–25 floating tab bar: a capsule of the three tabs (Plates'
/// `CustomTabBar`, a native segmented control skinned with each tab's icon
/// and title) and a round accent "+" beside it, standing in for iOS 26's
/// glass bar and its separate search-role circle.
struct LegacyTabBar: View {
    @Binding var selection: AppRouter.Tab
    let onAdd: () -> Void

    private let height: CGFloat = 64

    var body: some View {
        HStack(spacing: 12) {
            GeometryReader { proxy in
                CustomTabBar(
                    size: CGSize(width: max(proxy.size.width - 4, 0), height: max(proxy.size.height - 4, 0)),
                    activeTint: .white,
                    inactiveTint: TabBarPalette.inactive,
                    barTint: AppTheme.ColorToken.accent,
                    inactiveBackgroundColor: TabBarPalette.background,
                    activeTab: $selection
                ) { tab in
                    VStack(spacing: 3) {
                        tab.image(selected: selection == tab)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .frame(height: 26)
                        Text(tab.title)
                            .font(.system(size: 10, weight: .medium))
                            .lineLimit(1)
                    }
                    .fontDesign(.rounded)
                    .frame(maxWidth: .infinity)
                    // Each tab is snapshotted with `ImageRenderer`, which
                    // clips to the layout bounds; equal room on every side
                    // keeps the item whole and centred.
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                }
                .padding(2)
                .background(TabBarPalette.background, in: Capsule())
                .modifier(GlassLikeSurface(shape: Capsule(), tint: AnyShapeStyle(TabBarPalette.background)))
            }
            .frame(height: height)

            Button(action: onAdd) {
                Image("icon-plus")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(.white)
                    .frame(width: height, height: height)
                    .background(AppTheme.ColorToken.accent, in: Circle())
                    .modifier(GlassLikeSurface(shape: Circle(), tint: AnyShapeStyle(AppTheme.ColorToken.accent)))
                    .contentShape(Circle())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Add medicine")
        }
        .frame(maxWidth: 500)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

/// The floating tab bar's colors: white bar (dark gray in dark mode) with
/// black / white unselected tabs and the accent selection.
private enum TabBarPalette {
    static let background = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x2C / 255, green: 0x2C / 255, blue: 0x2E / 255, alpha: 1)
            : .white
    })
    static let inactive = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? .white : .black
    })
}
