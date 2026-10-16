import SwiftUI

/// The solid version of an asset-pack icon (onboarding, the paywall). The
/// pack only has outlines, so this draws the matching filled SF Symbol and
/// falls back to the outline where there's no symbol for it.
struct FilledIcon: View {
    let icon: AppIcon
    var size: CGFloat = 24

    init(_ icon: AppIcon, size: CGFloat = 24) {
        self.icon = icon
        self.size = size
    }

    var body: some View {
        if let symbol = icon.filledSymbol {
            Image(systemName: symbol)
                .font(.system(size: size * 0.9, weight: .semibold))
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        } else {
            Icon(icon, size: size)
        }
    }
}

extension AppIcon {
    /// The filled SF Symbol standing in for this icon, if there is one.
    var filledSymbol: String? {
        switch self {
        case .user: "person.fill"
        case .users: "person.2.fill"
        case .heart: "heart.fill"
        case .zap: "bolt.fill"
        case .store: "storefront.fill"
        case .truck: "truck.box.fill"
        case .steth: "stethoscope"
        case .check: "checkmark.circle.fill"
        case .pill: "pills.fill"
        case .sliders: "slider.horizontal.3"
        case .bell: "bell.fill"
        case .clock: "clock.fill"
        case .syringe: "syringe.fill"
        case .drop: "drop.fill"
        case .liquid: "waterbottle.fill"
        case .timeline: "chart.bar.fill"
        case .plus: "plus.circle.fill"
        case .share: "square.and.arrow.up.fill"
        default: nil
        }
    }
}
