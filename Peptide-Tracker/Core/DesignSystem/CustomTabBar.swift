import SwiftUI

/// A native `UISegmentedControl` skinned with SwiftUI content — ported from
/// Plates (`CustomTabBar`, itself from Formly's `Create` category picker).
/// Renders `tabItemView` to an image per segment so the control keeps native
/// touch/selection behavior (and, on iOS 26+, its built-in press bounce)
/// while looking like any other SwiftUI control. Also drives the floating
/// tab bar before iOS 26 (`LegacyTabBar`).
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
        let control = CapsuleSegmentedControl(items: tabs.map(\.rawValue))
        control.selectedSegmentIndex = tabs.firstIndex(of: activeTab) ?? 0

        let key = renderKey(context.environment.colorScheme)
        updateSegmentImages(control, colorScheme: key.colorScheme)
        context.coordinator.renderedKey = key

        if #available(iOS 26, *) {
            // Hides the control's own background and dividers, keeping only
            // the selection indicator (the last image view).
            DispatchQueue.main.async {
                for subview in control.subviews {
                    if subview is UIImageView && subview !== control.subviews.last {
                        subview.alpha = 0
                    }
                }
            }
        } else {
            // Before iOS 26 the control lays out its image views differently,
            // and the trick above also hid the unselected tabs' icons. Remove
            // only the dividers, through the public API;
            // `CapsuleSegmentedControl` handles the rest.
            for left in [UIControl.State.normal, .selected] {
                for right in [UIControl.State.normal, .selected] {
                    control.setDividerImage(UIImage(), forLeftSegmentState: left, rightSegmentState: right, barMetrics: .default)
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

        // SwiftUI calls this for unrelated reasons too, a pager starting to
        // scroll is one. Swapping every segment's image each time makes the
        // control re-lay out its labels, which shows as a jiggle, so they're
        // only redone when something they depend on changed.
        let key = renderKey(context.environment.colorScheme)
        if context.coordinator.renderedKey != key {
            UIView.performWithoutAnimation {
                updateSegmentImages(uiView, colorScheme: key.colorScheme)
                applyColors(to: uiView)
                uiView.layoutIfNeeded()
            }
            context.coordinator.renderedKey = key
        }

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

    /// What the segment images depend on: the active tab, the size, and
    /// Light or Dark Mode, since the labels are baked into bitmaps.
    private func renderKey(_ colorScheme: ColorScheme) -> RenderKey {
        RenderKey(activeIndex: tabs.firstIndex(of: activeTab) ?? 0, size: size, colorScheme: colorScheme)
    }

    struct RenderKey: Equatable {
        let activeIndex: Int
        let size: CGSize
        let colorScheme: ColorScheme
    }

    private func updateSegmentImages(_ control: UISegmentedControl, colorScheme: ColorScheme) {
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
                        .environment(\.colorScheme, colorScheme)
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
        /// The state the segment images were last drawn for.
        var renderedKey: RenderKey?

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
            // The binding can refuse a tab (a locked range opens the paywall
            // instead), and then nothing else moves the control back.
            DispatchQueue.main.async { [weak control, weak self] in
                guard let control, let self else { return }
                let tabs = self.parent.tabs
                if let index = tabs.firstIndex(of: self.parent.activeTab), control.selectedSegmentIndex != index {
                    control.selectedSegmentIndex = index
                }
            }
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

/// Before iOS 26 the segmented control draws its background and its sliding
/// selection as rounded rectangles; inside the capsule bars both should be
/// capsules. iOS 26 already draws them that way, so it's left alone there.
private final class CapsuleSegmentedControl: UISegmentedControl {
    override func layoutSubviews() {
        super.layoutSubviews()
        guard #unavailable(iOS 26) else { return }

        // Clipped to a capsule. The control's own translucent gray
        // background and dividers are plain image views; hiding them lets
        // `backgroundColor`, the bar's color, show through.
        layer.cornerRadius = bounds.height / 2
        layer.cornerCurve = .continuous
        layer.masksToBounds = true
        // The background, the dividers and the selection indicator are plain
        // `UIImageView`s (the segments are `UISegment`s). UIKit reorders the
        // subviews as the selection moves, so the indicator is found by what
        // it is, never by index: painting by index can land on a segment and
        // leave it filled with the accent. It's the one already repainted
        // below, or on the first pass the last image view.
        let imageViews = subviews.compactMap { type(of: $0) == UIImageView.self ? $0 as? UIImageView : nil }
        guard let indicator = imageViews.first(where: { $0.image == nil && $0.backgroundColor != nil }) ?? imageViews.last
        else { return }
        for subview in subviews where !(subview is UIImageView) {
            subview.backgroundColor = nil
        }
        for imageView in imageViews where imageView !== indicator {
            imageView.alpha = 0
        }

        // Swap the indicator's rounded-rect image for a plain fill rounded
        // into a capsule, inset a little like the system's.
        indicator.image = nil
        indicator.backgroundColor = selectedSegmentTintColor
        indicator.layer.cornerRadius = (bounds.height - 4) / 2
        indicator.layer.cornerCurve = .continuous
        indicator.layer.masksToBounds = true
        indicator.frame = indicator.frame.insetBy(dx: 0, dy: (indicator.frame.height - (bounds.height - 4)) / 2)
    }
}
