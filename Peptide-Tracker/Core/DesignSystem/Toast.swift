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

    /// The symbol drawn white inside the coloured circle.
    var glyph: String {
        switch self {
        case .success: "checkmark"
        case .info: "info"
        case .warning: "exclamationmark"
        case .error: "xmark"
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

/// The toast itself: a coloured round icon (white symbol, or a spinner
/// while loading), the title and an optional line of detail, on a solid
/// card in a thin glass rim. One line is a pill; with detail it's a
/// rounded card. Follows the app's Light / Dark choice through its window.
struct ToastView: View {
    let toast: Toast

    @Environment(\.colorScheme) private var colorScheme

    private var radius: CGFloat { toast.message == nil ? 30 : 24 }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(toast.style == .loading ? toast.style.tint.opacity(0.14) : toast.style.tint)
                if toast.style == .loading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(toast.style.tint)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                } else {
                    Image(systemName: toast.style.glyph)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .symbolEffect(.bounce, value: toast.style)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
            }
            .frame(width: 32, height: 32)
            .animation(.snappy, value: toast.style)

            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.ColorToken.primaryText)
                    .lineLimit(2)
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
        .padding(.leading, 10)
        .padding(.trailing, 18)
        .padding(.vertical, 10)
        .frame(maxWidth: 380)
        .background(AppTheme.ColorToken.cardBackground, in: .rect(cornerRadius: radius, style: .continuous))
        // A hairline so the card holds its edge on dark backgrounds too.
        .overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(colorScheme == .dark ? Color.white.opacity(0.10) : Color(hex: 0x28185A, opacity: 0.06), lineWidth: 0.75)
        }
        // Solid inside, Liquid Glass only round the edge.
        .padding(3)
        .compatGlass(in: .rect(cornerRadius: radius + 3, style: .continuous))
        .shadow(color: colorScheme == .dark ? .black.opacity(0.45) : Color(hex: 0x28185A, opacity: 0.14), radius: 20, y: 10)
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
    .background(AppTheme.ColorToken.background)
}
