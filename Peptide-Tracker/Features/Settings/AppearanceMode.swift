import SwiftUI
import UIKit

/// The app's look: follow the phone, or always Light or Dark. Applied to
/// the windows themselves (not `.preferredColorScheme`) so sheets and UIKit
/// pieces switch together. `PeptideTrackerApp` applies it on launch.
enum AppearanceMode: String, CaseIterable {
    case system, light, dark

    static let storageKey = "appearanceMode"

    /// The mode picked in Settings, for windows created after launch (the
    /// toast and lock windows), which `apply()` ran too early to reach.
    static var current: AppearanceMode {
        UserDefaults.standard.string(forKey: storageKey).flatMap(Self.init(rawValue:)) ?? .system
    }

    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .light: .light
        case .dark: .dark
        case .system: .unspecified
        }
    }

    var label: String {
        switch self {
        case .system: String(localized: "System")
        case .light: String(localized: "Light")
        case .dark: String(localized: "Dark")
        }
    }

    var systemImage: String {
        switch self {
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        case .system: "circle.lefthalf.filled"
        }
    }

    @MainActor
    func apply() {
        for window in UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows) {
            window.overrideUserInterfaceStyle = interfaceStyle
        }
    }
}

// MARK: - Theme row

/// Settings → Appearance → Theme: the current mode's tile over a
/// System / Light / Dark switch. Picking one reveals it in a circle growing
/// out of the option tapped.
struct AppearanceThemeRow: View {
    @AppStorage(AppearanceMode.storageKey) private var modeRaw = AppearanceMode.system.rawValue
    @State private var switchFrame: CGRect = .zero

    private var mode: AppearanceMode { AppearanceMode(rawValue: modeRaw) ?? .system }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                SettingsTile(symbol: mode.systemImage, tint: Color(hex: 0x5856D6))
                    .contentTransition(.symbolEffect(.replace))
                Text("Theme")
                    .font(.system(size: 17))
                    .foregroundStyle(AppTheme.ColorToken.primaryText)
                Spacer(minLength: 0)
            }
            .frame(minHeight: 52)

            PillSwitch(options: AppearanceMode.allCases.map { ($0.label, $0) }, selection: selection)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { switchFrame = $0 }
                .padding(.bottom, 16)
        }
        .padding(.horizontal, 16)
    }

    private var selection: Binding<AppearanceMode> {
        Binding(
            get: { mode },
            set: { newValue in
                guard newValue != mode else { return }
                let options = AppearanceMode.allCases
                let index = CGFloat(options.firstIndex(of: newValue) ?? 0)
                let origin = switchFrame.isEmpty ? nil : CGPoint(
                    x: switchFrame.minX + switchFrame.width * (index + 0.5) / CGFloat(options.count),
                    y: switchFrame.midY
                )
                AppearanceTransition.switchTo(newValue, from: origin) { modeRaw = newValue.rawValue }
            }
        )
    }
}

/// A capsule switch with a raised pill that slides to the picked option.
struct PillSwitch<Value: Hashable>: View {
    let options: [(title: String, value: Value)]
    @Binding var selection: Value
    @Namespace private var pill

    private static var raised: Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 0.29, green: 0.28, blue: 0.33, alpha: 1) : .white })
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.value) { option in
                let isSelected = option.value == selection
                Button { selection = option.value } label: {
                    Text(option.title)
                        .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? AppTheme.ColorToken.primaryText : AppTheme.ColorToken.secondaryText)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(Self.raised)
                                    .shadow(color: .black.opacity(0.08), radius: 5, y: 2)
                                    .matchedGeometryEffect(id: "pill", in: pill)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(AppTheme.ColorToken.controlFill, in: Capsule())
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selection)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

// MARK: - Animated switch

/// The screen as it was is frozen in a snapshot on top, the new look is
/// applied underneath, and a circle growing from the tapped option cuts
/// through the snapshot. Nothing recolours in place, so there's no flash.
/// With Reduce Motion on, the snapshot just fades.
@MainActor
enum AppearanceTransition {
    private static weak var activeSnapshot: UIView?

    static func switchTo(_ mode: AppearanceMode, from origin: CGPoint?, commit: () -> Void) {
        guard let window = keyWindow else { mode.apply(); commit(); return }

        let before = window.traitCollection.userInterfaceStyle
        let systemStyle = window.windowScene?.traitCollection.userInterfaceStyle ?? before
        let after = mode.interfaceStyle == .unspecified ? systemStyle : mode.interfaceStyle
        guard after != before, let snapshot = window.snapshotView(afterScreenUpdates: false) else {
            mode.apply(); commit(); return
        }

        activeSnapshot?.removeFromSuperview()
        snapshot.frame = window.bounds
        snapshot.isUserInteractionEnabled = false
        window.addSubview(snapshot)
        activeSnapshot = snapshot

        mode.apply()
        commit()

        if UIAccessibility.isReduceMotionEnabled {
            UIView.animate(withDuration: 0.3, animations: { snapshot.alpha = 0 }) { _ in snapshot.removeFromSuperview() }
            return
        }
        reveal(through: snapshot, from: origin ?? CGPoint(x: window.bounds.midX, y: window.bounds.midY))
    }

    private static func reveal(through snapshot: UIView, from origin: CGPoint) {
        let bounds = snapshot.bounds
        let corners = [CGPoint(x: bounds.minX, y: bounds.minY), CGPoint(x: bounds.maxX, y: bounds.minY),
                       CGPoint(x: bounds.minX, y: bounds.maxY), CGPoint(x: bounds.maxX, y: bounds.maxY)]
        let radius = corners.map { hypot($0.x - origin.x, $0.y - origin.y) }.max() ?? 0

        func path(radius: CGFloat) -> CGPath {
            let path = UIBezierPath(rect: bounds)
            path.append(UIBezierPath(arcCenter: origin, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: true))
            return path.cgPath
        }

        let mask = CAShapeLayer()
        mask.fillRule = .evenOdd
        mask.path = path(radius: radius)
        snapshot.layer.mask = mask

        CATransaction.begin()
        CATransaction.setCompletionBlock { snapshot.removeFromSuperview() }
        let grow = CABasicAnimation(keyPath: "path")
        grow.fromValue = path(radius: 0.1)
        grow.toValue = mask.path
        grow.duration = 0.55
        grow.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0, 0.2, 1)
        mask.add(grow, forKey: "reveal")
        CATransaction.commit()
    }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }
}

// MARK: - Header toggle

/// The sun/moon glass button in the Settings header: flips between Light
/// and Dark, revealing the new look in a circle growing out of the button,
/// the same effect as the Theme switch in Appearance.
struct AppearanceToggleButton: View {
    @AppStorage(AppearanceMode.storageKey) private var modeRaw = AppearanceMode.system.rawValue
    @Environment(\.colorScheme) private var colorScheme
    @State private var frame: CGRect = .zero

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        Button {
            HapticFeedback.impact()
            let next: AppearanceMode = isDark ? .light : .dark
            let origin = frame.isEmpty ? nil : CGPoint(x: frame.midX, y: frame.midY)
            AppearanceTransition.switchTo(next, from: origin) { modeRaw = next.rawValue }
        } label: {
            Image(systemName: isDark ? "moon.fill" : "sun.max.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.ColorToken.primaryText)
                .contentTransition(.symbolEffect(.replace.downUp))
                .frame(width: 44, height: 44)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .compatGlass(interactive: true, in: .circle)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
        .accessibilityLabel(isDark ? "Switch to Light Mode" : "Switch to Dark Mode")
    }
}
