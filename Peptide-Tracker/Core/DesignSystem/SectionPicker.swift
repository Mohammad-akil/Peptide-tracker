import SwiftUI
import UIKit

/// The pill section switch at the top of a screen ("Medicines | Stock") —
/// Plates' Progress-tab picker: `CustomTabBar` (a native segmented control)
/// with an accent pill and white text, on a track that stands apart from
/// the white top panel.
struct SectionPicker<Value>: View
where Value: Hashable & CaseIterable & RawRepresentable, Value.RawValue == String, Value.AllCases: RandomAccessCollection {
    @Binding var selection: Value
    let title: (Value) -> String
    var height: CGFloat = 44

    /// Lavender in light mode, a lifted grey in dark, so the track reads
    /// against the panel behind it.
    private let trackBackground = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? .tertiarySystemBackground : UIColor(AppTheme.ColorToken.background)
    })

    var body: some View {
        GeometryReader { proxy in
            CustomTabBar(
                size: CGSize(width: max(proxy.size.width - 4, 0), height: max(proxy.size.height - 4, 0)),
                activeTint: .white,
                inactiveTint: AppTheme.ColorToken.secondaryText,
                barTint: AppTheme.ColorToken.accent,
                activeTab: $selection
            ) { value in
                Text(title(value))
                    // Segments are rendered off-screen, so they don't inherit
                    // the app's rounded design; set it here.
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(4)
            .background(trackBackground, in: .capsule)
        }
        .frame(height: height)
    }
}
