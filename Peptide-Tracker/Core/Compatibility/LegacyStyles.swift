import SwiftUI
import UIKit

// Everything drawn only on iOS 18–25: the app's own stand-ins for Liquid
// Glass and the other iOS 26 looks. iOS 26 and later never use any of it;
// the wrappers in Compatibility.swift pick between the system API and these.
// Ported from Plates (Core/Compatibility/LegacyStyles.swift).

/// iOS 18–25 metrics and colors.
enum LegacyToolbar {
    /// Sheet corners on iOS 18–25, close to iOS 26's rounder sheets (iOS 26
    /// keeps its own). Applied by `compatSheetCornerRadius()`.
    static let sheetCornerRadius: CGFloat = 38
    static let glassShadow = Color(red: 49 / 255, green: 53 / 255, blue: 61 / 255).opacity(0.12)
}

/// Glass drawn without the iOS 26 glass APIs: a frosted material (under the
/// tint, if any), a light sheen across the top, a bright rim that fades from
/// the top-leading corner, and a soft layered shadow.
struct GlassLikeSurface<S: Shape>: ViewModifier {
    let shape: S
    var tint: AnyShapeStyle?

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let isDark = colorScheme == .dark

        content
            .background {
                ZStack {
                    shape.fill(.ultraThinMaterial)

                    if let tint {
                        shape.fill(tint).opacity(0.88)
                    }

                    // Light catching the upper half of the surface.
                    shape.fill(
                        LinearGradient(
                            colors: [.white.opacity(isDark ? 0.12 : 0.35), .white.opacity(0)],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                }
            }
            .overlay {
                shape
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(isDark ? 0.35 : 0.8),
                                .white.opacity(isDark ? 0.05 : 0.15),
                                .white.opacity(isDark ? 0.15 : 0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
            }
            .shadow(color: LegacyToolbar.glassShadow.opacity(0.8), radius: 1, y: 0.5)
            .shadow(color: LegacyToolbar.glassShadow, radius: 8, y: 4)
    }
}

/// Stand-in for the iOS 26 `.glass` / `.glassProminent` button styles: the
/// `GlassLikeSurface` look (filled with the button's tint when prominent), a
/// springy press, and a light haptic.
struct GlassLikeButtonStyle: ButtonStyle {
    enum ButtonShape {
        case capsule, circle
    }

    var prominent = false
    var shape: ButtonShape = .capsule
    var diameter: CGFloat = 36

    func makeBody(configuration: Configuration) -> some View {
        GlassLikeButton(configuration: configuration, prominent: prominent, shape: shape, diameter: diameter)
    }

    private struct GlassLikeButton: View {
        let configuration: Configuration
        let prominent: Bool
        let shape: ButtonShape
        let diameter: CGFloat

        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            let label = configuration.label
                .foregroundStyle(prominent ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            let tint = prominent ? AnyShapeStyle(.tint) : nil

            Group {
                switch shape {
                case .capsule:
                    label
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .frame(minHeight: 34)
                        .contentShape(Capsule())
                        .modifier(GlassLikeSurface(shape: Capsule(), tint: tint))
                case .circle:
                    label
                        .frame(width: diameter, height: diameter)
                        .contentShape(Circle())
                        .modifier(GlassLikeSurface(shape: Circle(), tint: tint))
                }
            }
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .brightness(configuration.isPressed ? 0.04 : 0)
            .opacity(isEnabled ? 1 : 0.5)
            .animation(.spring(duration: 0.25, bounce: 0.4), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed { HapticFeedback.impact() }
            }
        }
    }
}
