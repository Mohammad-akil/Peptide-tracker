import LocalAuthentication
import SwiftUI
import UIKit

/// Privacy mode's lock: with App Lock on, the app asks for Face ID (or
/// Touch ID, or the passcode) on launch and whenever it comes back from the
/// background, and shows a blank card in the app switcher so nobody
/// glancing at the phone sees what's taken. Drawn in its own window above
/// everything, sheets and toasts included.
@MainActor
@Observable
final class AppLock {
    static let shared = AppLock()

    /// Needs unlocking before the app shows again.
    private(set) var isLocked = false
    /// Covered for the app switcher, without needing to unlock.
    private(set) var isObscured = false
    private(set) var isAuthenticating = false
    /// Set when the app went to the background (or launched locked), so
    /// coming back prompts once — not again after a cancelled prompt.
    @ObservationIgnored private var promptsOnActive = false

    // MARK: Device support

    /// "Face ID", "Touch ID", "Optic ID", or "Passcode" without biometrics.
    static var methodName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return switch context.biometryType {
        case .faceID: "Face ID"
        case .touchID: "Touch ID"
        case .opticID: "Optic ID"
        default: "Passcode"
        }
    }

    static var methodSymbol: String {
        switch methodName {
        case "Face ID": "faceid"
        case "Touch ID": "touchid"
        case "Optic ID": "opticid"
        default: "lock.fill"
        }
    }

    /// Whether the device has a passcode (and so can lock at all).
    static var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    /// Face ID / Touch ID with the passcode as fallback.
    func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }

    // MARK: Lifecycle

    /// At launch, before anything is on screen.
    func launch(enabled: Bool) {
        guard enabled else { return }
        isLocked = true
        promptsOnActive = true
        LockWindow.update()
    }

    func scenePhaseChanged(_ phase: ScenePhase, enabled: Bool) {
        guard enabled else {
            isLocked = false
            isObscured = false
            LockWindow.update()
            return
        }
        switch phase {
        case .background:
            isLocked = true
            isObscured = true
            promptsOnActive = true
        case .inactive:
            // The app switcher snapshot, or the Face ID prompt itself.
            if !isAuthenticating { isObscured = true }
        case .active:
            isObscured = false
            if isLocked, promptsOnActive {
                promptsOnActive = false
                Task { await unlock() }
            }
        @unknown default:
            break
        }
        LockWindow.update()
    }

    /// The lock screen's button, and the automatic prompt on return.
    func unlock() async {
        guard isLocked, !isAuthenticating else { return }
        isAuthenticating = true
        let unlocked = await authenticate(reason: "Unlock \(Bundle.main.appName) to see your medicines.")
        isAuthenticating = false
        if unlocked {
            withAnimation(.easeOut(duration: 0.25)) { isLocked = false }
        }
        LockWindow.update()
    }

    /// Turning App Lock off from Settings.
    func disable() {
        isLocked = false
        isObscured = false
        promptsOnActive = false
        LockWindow.update()
    }
}

// MARK: - Window

/// The window the lock draws in, above the toast window.
@MainActor
enum LockWindow {
    private static var window: UIWindow?

    static func install() {
        guard window == nil,
              let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else { return }
        let window = UIWindow(windowScene: scene)
        let host = UIHostingController(
            rootView: LockScreenView()
                .fontDesign(.rounded)
                .tint(AppTheme.ColorToken.accent)
        )
        host.view.backgroundColor = .clear
        window.rootViewController = host
        window.windowLevel = .alert + 2
        window.backgroundColor = .clear
        self.window = window
        update()
    }

    /// Shows the window while locked or obscured, hides it otherwise.
    static func update() {
        let lock = AppLock.shared
        let shows = lock.isLocked || lock.isObscured
        guard let window else { return }
        if shows {
            window.isHidden = false
        } else {
            // Let the lock screen fade before the window goes.
            Task {
                try? await Task.sleep(for: .milliseconds(260))
                if !(AppLock.shared.isLocked || AppLock.shared.isObscured) { window.isHidden = true }
            }
        }
    }
}

// MARK: - Lock screen

private struct LockScreenView: View {
    @State private var lock = AppLock.shared

    var body: some View {
        let shows = lock.isLocked || lock.isObscured

        ZStack {
            AppTheme.ColorToken.background
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 84, height: 84)
                    .background(
                        LinearGradient(colors: [Color(hex: 0x8A6CF0), AppTheme.ColorToken.accent], startPoint: .top, endPoint: .bottom),
                        in: .rect(cornerRadius: 24, style: .continuous)
                    )
                    .accessibilityHidden(true)

                Text("\(Bundle.main.appName) is locked")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.ColorToken.primaryText)

                if lock.isLocked && !lock.isObscured {
                    Button {
                        Task { await lock.unlock() }
                    } label: {
                        Label("Unlock with \(AppLock.methodName)", systemImage: AppLock.methodSymbol)
                    }
                    .buttonStyle(.glassPrimary)
                    .frame(maxWidth: 300)
                    .disabled(lock.isAuthenticating)
                    .padding(.top, 8)
                }
            }
            .padding(24)
        }
        .opacity(shows ? 1 : 0)
        .animation(.easeOut(duration: 0.25), value: shows)
        .accessibilityAddTraits(.isModal)
    }
}
