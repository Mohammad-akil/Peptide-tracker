import SwiftUI
import UIKit

/// A short message dropped in at the top of the screen. A loading toast
/// stays until it's replaced; replacing it with a result keeps its place,
/// so the spinner morphs into a tick or a warning instead of popping.
struct Toast: Identifiable, Equatable {
    enum Style: Equatable {
        case success, info, warning, error, loading
    }

    var id = UUID()
    var style: Style
    var title: String
    var message: String?

    static func success(_ title: String, message: String? = nil) -> Toast { Toast(style: .success, title: title, message: message) }
    static func info(_ title: String, message: String? = nil) -> Toast { Toast(style: .info, title: title, message: message) }
    static func warning(_ title: String, message: String? = nil) -> Toast { Toast(style: .warning, title: title, message: message) }
    static func error(_ title: String, message: String? = nil) -> Toast { Toast(style: .error, title: title, message: message) }
    static func loading(_ title: String, message: String? = nil) -> Toast { Toast(style: .loading, title: title, message: message) }
}

extension Toast.Style {
    var symbol: String {
        switch self {
        case .success: "checkmark.circle.fill"
        case .info: "info.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.octagon.fill"
        case .loading: "circle.dotted"
        }
    }

    var tint: Color {
        switch self {
        case .success: Urgency.healthy.tint
        case .warning: Urgency.low.tint
        case .error: AppTheme.ColorToken.destructive
        case .info, .loading: AppTheme.ColorToken.accent
        }
    }

    /// How long it stays up; loading stays until replaced. Problems linger
    /// a little longer so there's time to read them.
    var duration: Duration? {
        switch self {
        case .loading: nil
        case .error: .seconds(4)
        case .warning: .seconds(3.5)
        case .success, .info: .seconds(2.6)
        }
    }

    func playHaptic() {
        switch self {
        case .success: HapticFeedback.notification(.success)
        case .warning: HapticFeedback.notification(.warning)
        case .error: HapticFeedback.notification(.error)
        case .info: HapticFeedback.selection()
        case .loading: break
        }
    }
}

/// The toast itself: a tinted glass pill with a spinner or a bouncing icon,
/// the title and an optional line of detail.
struct ToastView: View {
    let toast: Toast

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if toast.style == .loading {
                    ProgressView()
                        .tint(toast.style.tint)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                } else {
                    Image(systemName: toast.style.symbol)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(toast.style.tint)
                        .symbolEffect(.bounce, value: toast.style)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.ColorToken.primaryText)
                    .contentTransition(.opacity)
                if let message = toast.message {
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.ColorToken.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                }
            }
            .frame(minWidth: 0, alignment: .leading)
        }
        .padding(.leading, 14)
        .padding(.trailing, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: 380)
        .glassEffect(.regular.tint(toast.style.tint.opacity(0.12)), in: .rect(cornerRadius: 26, style: .continuous))
        .shadow(color: Color(hex: 0x28185A, opacity: 0.12), radius: 18, y: 10)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: toast)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: 16) {
        ToastView(toast: .success("Metformin added", message: "We’ll remind you on 9 Oct"))
        ToastView(toast: .loading("Contacting the App Store…"))
        ToastView(toast: .warning("No earlier purchase found"))
        ToastView(toast: .error("Purchase didn’t go through", message: "Check your connection and try again."))
        ToastView(toast: .info("Reminders paused"))
    }
    .padding()
}
