import SwiftUI

// Wrappers for the iOS 26 (Liquid Glass) APIs the app uses. On iOS 26 each
// one calls straight through to the system API, exactly as before; on iOS
// 18–25 it falls back to the stand-ins in LegacyStyles.swift. These are the
// only switch points, so the two versions never share styling code.
// Ported from Plates (Core/Compatibility/Compatibility.swift).

/// For style choices that are values rather than views (a color, a size):
/// `true` on iOS 18–25, where the app draws its own stand-ins for Liquid
/// Glass. iOS 26 and later keep the original values.
enum LegacyStyle {
    static var isActive: Bool {
        if #available(iOS 26, *) { false } else { true }
    }
}

extension View {
    /// A soft blur under the navigation bar instead of the hard translucent
    /// one: the iOS 26 soft scroll edge effect, and on iOS 18–25 a frosted
    /// strip that fades out just below the bar (as in Plates).
    @ViewBuilder
    func compatNavigationBarBlur(background: Color = AppTheme.ColorToken.background) -> some View {
        if #available(iOS 26, *) {
            scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            toolbarBackground(.hidden, for: .navigationBar)
                .safeAreaInset(edge: .top, spacing: 0) {
                    // Zero height, so the layout doesn't move; the blur
                    // reaches up through the bar and fades below it.
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .frame(height: 0)
                        .background { ScrollEdgeBlur(edge: .top, tint: background) }
                }
        }
    }

    /// `.glassEffect(.regular…)` (or `.clear…` with `clear: true`) on iOS 26.
    /// Before that, a hand-drawn glass look (`GlassLikeSurface`) stands in
    /// for it, tinted with `fallbackTint` when given, otherwise with `tint`.
    @ViewBuilder
    func compatGlass<S: Shape>(
        clear: Bool = false,
        tint: Color? = nil,
        interactive: Bool = false,
        fallbackTint: Color? = nil,
        in shape: S
    ) -> some View {
        if #available(iOS 26, *) {
            glassEffect((clear ? Glass.clear : Glass.regular).tint(tint).interactive(interactive), in: shape)
        } else {
            modifier(GlassLikeSurface(shape: shape, tint: (fallbackTint ?? tint).map { AnyShapeStyle($0) }))
        }
    }

    /// The `.glass` / `.glassProminent` button styles on iOS 26; the
    /// look-alike `GlassLikeButtonStyle` before it. On iOS 26 the shape
    /// comes from `.buttonBorderShape`; `shape` only applies to the fallback.
    @ViewBuilder
    func compatGlassButtonStyle(
        prominent: Bool = false,
        shape: GlassLikeButtonStyle.ButtonShape = .capsule
    ) -> some View {
        if #available(iOS 26, *) {
            if prominent {
                buttonStyle(.glassProminent)
            } else {
                buttonStyle(.glass)
            }
        } else {
            buttonStyle(GlassLikeButtonStyle(prominent: prominent, shape: shape))
        }
    }

    /// Rounder sheet corners on iOS 18–25, where the system default is much
    /// tighter than iOS 26's. iOS 26 keeps its native sheet shape. Goes on a
    /// sheet's outermost view, next to `.presentationDetents`.
    func compatSheetCornerRadius() -> some View {
        modifier(CompatSheetCornerRadius())
    }
}

/// `GlassEffectContainer` on iOS 26, so nearby glass surfaces blend and
/// morph as one region. Before it, the same layout with each surface
/// drawing its own `compatGlass` fallback.
struct AppGlassEffectContainer<Content: View>: View {
    var spacing: CGFloat? = nil
    @ViewBuilder var content: Content

    init(spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

/// The system close button: on iOS 26 a `.close`-role button in a glass
/// circle; before it, the same xmark in the look-alike glass circle, with
/// "Close" for VoiceOver.
struct CompatCloseButton: View {
    let action: () -> Void

    var body: some View {
        if #available(iOS 26, *) {
            Button(role: .close, action: action) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.large)
        } else {
            Button(action: action) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.ColorToken.primaryText)
            }
            .buttonStyle(GlassLikeButtonStyle(shape: .circle, diameter: 48))
            .accessibilityLabel("Close")
        }
    }
}

/// A toolbar Close / Cancel / Save: the iOS 26 `.close`, `.cancel` and
/// `.confirm` role buttons (glyphs in the bar's glass); before it, the
/// iOS 18 equivalents — an xmark for Close, "Cancel" and a bold "Save".
struct CompatToolbarRoleButton: View {
    enum Role { case close, cancel, confirm }

    let role: Role
    let action: () -> Void

    var body: some View {
        if #available(iOS 26, *) {
            switch role {
            case .close: Button(role: .close, action: action)
            case .cancel: Button(role: .cancel, action: action)
            case .confirm: Button(role: .confirm, action: action)
            }
        } else {
            switch role {
            case .close:
                Button("Close", systemImage: "xmark", action: action)
                    .labelStyle(.iconOnly)
                    .fontWeight(.semibold)
            case .cancel:
                Button("Cancel", action: action)
            case .confirm:
                Button("Save", action: action)
                    .fontWeight(.semibold)
            }
        }
    }
}

private struct CompatSheetCornerRadius: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
        } else {
            content.presentationCornerRadius(LegacyToolbar.sheetCornerRadius)
        }
    }
}

extension View {
    /// `.tabBarMinimizeBehavior(.never)` on iOS 26; nothing before it.
    @ViewBuilder
    func compatTabBarNeverMinimizes() -> some View {
        if #available(iOS 26, *) {
            tabBarMinimizeBehavior(.never)
        } else {
            self
        }
    }
}


/// The blur behind a pinned bar on iOS 18–25, standing in for the iOS 26
/// soft scroll edge effect: a material that fades out over `fadeLength`
/// past the bar's edge instead of ending on a hard line.
struct ScrollEdgeBlur: View {
    let edge: VerticalEdge
    var tint: Color = AppTheme.ColorToken.background
    var fadeLength: CGFloat = 24

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            if edge == .bottom { tint.opacity(0.55) }
        }
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.6),
                    .init(color: .clear, location: 1),
                ],
                startPoint: edge == .top ? .top : .bottom,
                endPoint: edge == .top ? .bottom : .top
            )
        }
        .padding(edge == .top ? .bottom : .top, -fadeLength)
        .ignoresSafeArea(edges: edge == .top ? .top : .bottom)
        .allowsHitTesting(false)
    }
}
