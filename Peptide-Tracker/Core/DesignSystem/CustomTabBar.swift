import SwiftUI

/// A native `UISegmentedControl` skinned with SwiftUI content — ported from
/// Plates (`CustomTabBar`, itself from Formly's `Create` category picker).
/// Renders `tabItemView` to an image per segment so the control keeps native
/// touch/selection behavior (and, on iOS 26+, its built-in press bounce)
/// while looking like any other SwiftUI control.
struct CustomTabBar<Tab, TabItemView>: UIViewRepresentable
where
    Tab: Hashable & CaseIterable & RawRepresentable,
    Tab.RawValue == String,
    Tab.AllCases: RandomAccessCollection,
    TabItemView: View
{
    var size: CGSize
    var activeTint: Color = AppTheme.ColorToken.primaryText
    var inactiveTint: Color = AppTheme.ColorToken.secondaryText
    var barTint: Color = AppTheme.ColorToken.background
    var inactiveBackgroundColor: Color? = nil
    @Binding var activeTab: Tab
    @ViewBuilder var tabItemView: (Tab) -> TabItemView

    private var tabs: [Tab] {
        Array(Tab.allCases)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UISegmentedControl {
        let control = UISegmentedControl(items: tabs.map(\.rawValue))
        control.selectedSegmentIndex = tabs.firstIndex(of: activeTab) ?? 0

        updateSegmentImages(control)

        DispatchQueue.main.async {
            for subview in control.subviews {
                if subview is UIImageView && subview !== control.subviews.last {
                    subview.alpha = 0
                }
            }
        }

        applyColors(to: control)
        control.addTarget(
            context.coordinator,
            action: #selector(context.coordinator.tabSelected(_:)),
            for: .valueChanged
        )
        control.addTarget(
            context.coordinator,
            action: #selector(context.coordinator.tabPressed(_:)),
            for: .touchDown
        )
        control.addTarget(
            context.coordinator,
            action: #selector(context.coordinator.tabReleased(_:)),
            for: [.touchUpInside, .touchUpOutside, .touchCancel]
        )
        return control
    }

    func updateUIView(_ uiView: UISegmentedControl, context: Context) {
        context.coordinator.parent = self
        updateSegmentImages(uiView)
        applyColors(to: uiView)

        let index = tabs.firstIndex(of: activeTab) ?? 0
        if uiView.selectedSegmentIndex != index {
            if #available(iOS 26, *) {
                uiView.selectedSegmentIndex = index
            } else {
                UIView.animate(
                    withDuration: 0.32,
                    delay: 0,
                    options: [.allowUserInteraction, .beginFromCurrentState, .curveEaseInOut]
                ) {
                    uiView.selectedSegmentIndex = index
                    uiView.layoutIfNeeded()
                }
            }
        }
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: UISegmentedControl,
        context: Context
    ) -> CGSize? {
        size
    }

    private func updateSegmentImages(_ control: UISegmentedControl) {
        // `ImageRenderer` has no view hierarchy of its own to inherit a
        // trait collection from, so it defaults to light appearance and any
        // dynamic `Color` (like `inactiveTint`'s dark-mode branch) resolves
        // as if the device were always in light mode — running this inside
        // `performAsCurrent` on the control's own (real) trait collection
        // makes it resolve colors for whichever appearance is actually
        // active.
        control.traitCollection.performAsCurrent {
            for (index, tab) in tabs.enumerated() {
                let tint = activeTab == tab ? activeTint : inactiveTint
                let renderer = ImageRenderer(
                    content: tabItemView(tab)
                        .foregroundStyle(tint)
                )
                renderer.scale = 2

                let image = renderer.uiImage?.withRenderingMode(.alwaysOriginal)
                control.setImage(image, forSegmentAt: index)
            }
        }
    }

    private func applyColors(to control: UISegmentedControl) {
        // The control's base surface is visible behind every unselected segment.
        if let inactiveBackgroundColor {
            control.backgroundColor = UIColor(inactiveBackgroundColor)
        }
        control.selectedSegmentTintColor = UIColor(barTint)
        control.setTitleTextAttributes([.foregroundColor: UIColor(activeTint)], for: .selected)
        control.setTitleTextAttributes([.foregroundColor: UIColor(inactiveTint)], for: .normal)
    }

    final class Coordinator: NSObject {
        var parent: CustomTabBar

        init(parent: CustomTabBar) {
            self.parent = parent
        }

        @objc func tabSelected(_ control: UISegmentedControl) {
            let tabs = parent.tabs
            guard tabs.indices.contains(control.selectedSegmentIndex) else { return }
            let selected = tabs[control.selectedSegmentIndex]
            guard selected != parent.activeTab else { return }
            HapticFeedback.selection()
            parent.activeTab = selected
        }

        @objc func tabPressed(_ control: UISegmentedControl) {
            guard #available(iOS 26, *) else { return }

            UIView.animate(
                withDuration: 0.14,
                delay: 0,
                options: [.allowUserInteraction, .beginFromCurrentState, .curveEaseOut]
            ) {
                control.transform = CGAffineTransform(translationX: 0, y: -1.5)
                    .scaledBy(x: 1.015, y: 1.015)
            }
        }

        @objc func tabReleased(_ control: UISegmentedControl) {
            guard #available(iOS 26, *) else {
                control.transform = .identity
                return
            }

            UIView.animate(
                withDuration: 0.38,
                delay: 0,
                usingSpringWithDamping: 0.72,
                initialSpringVelocity: 0.15,
                options: [.allowUserInteraction, .beginFromCurrentState]
            ) {
                control.transform = .identity
            }
        }
    }
}
