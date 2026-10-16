import ConfettiSwiftUI
import SwiftUI
import UIKit

/// A see-through window above the app (and above its sheets and covers)
/// that shows toasts and confetti. Only the toast takes touches; everything
/// else passes through to the app underneath.
@MainActor
enum OverlayWindow {
    private static var window: PassthroughWindow?

    /// Called once the app's first window is up.
    static func install(router: AppRouter) {
        guard window == nil,
              let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else { return }
        let window = PassthroughWindow(windowScene: scene)
        let host = UIHostingController(
            rootView: OverlayHost { frame in window.touchableFrame = frame }
                .environment(router)
                .fontDesign(.rounded)
                .tint(AppTheme.ColorToken.accent)
        )
        host.view.backgroundColor = .clear
        window.rootViewController = host
        window.windowLevel = .alert + 1
        window.backgroundColor = .clear
        window.isHidden = false
        self.window = window
    }
}

/// Lets touches through everywhere except over the toast.
private final class PassthroughWindow: UIWindow {
    var touchableFrame: CGRect = .zero

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        touchableFrame.contains(point)
    }
}

/// What the overlay window draws: the current toast at the top, and the
/// confetti cannon that `AppRouter.celebrate()` fires.
private struct OverlayHost: View {
    let reportToastFrame: (CGRect) -> Void

    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var confetti = 0

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .confettiCannon(
                    trigger: $confetti,
                    num: 60,
                    colors: [
                        AppTheme.ColorToken.accent, Color(hex: 0xA88BFF), Color(hex: 0xD2558E),
                        Color(hex: 0x22769A), Color(hex: 0xF2B33D), Color(hex: 0x2C5FC4),
                    ],
                    confettiSize: 11,
                    rainHeight: 700,
                    openingAngle: .degrees(50),
                    closingAngle: .degrees(130),
                    radius: 420,
                    repetitions: 2,
                    repetitionInterval: 0.25,
                    hapticFeedback: false
                )
                .allowsHitTesting(false)

            if let toast = router.toast {
                ToastView(toast: toast)
                    .id(toast.id)
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { reportToastFrame($0) }
                    .onTapGesture { if toast.style != .loading { router.dismissToast() } }
                    .gesture(
                        DragGesture(minimumDistance: 8).onEnded { value in
                            if value.translation.height < -12, toast.style != .loading { router.dismissToast() }
                        }
                    )
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .top).combined(with: .scale(scale: 0.85, anchor: .top)).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        )
                    )
            }
        }
        .onChange(of: router.toast == nil) { _, isGone in
            if isGone { reportToastFrame(.zero) }
        }
        .onChange(of: router.celebrations) { _, _ in
            // Confetti is all motion, so Reduce Motion skips it.
            if !reduceMotion { confetti += 1 }
        }
    }
}
