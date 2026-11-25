import SwiftUI

/// The centred iCloud popup: what goes to iCloud, where it lives and who
/// can see it, then "Turn on iCloud backup" or "Not now". iCloud sync stays
/// off until someone says yes here (Guideline 5.1.3(ii)).
///
/// Shown once after setup (from `RootView`), and again whenever iCloud sync
/// is switched on in Settings.
extension View {
    /// Presents the popup over everything, the tab bar and navigation bar
    /// included. `onChoice` gets whether they turned iCloud on.
    func iCloudConsentPopup(isPresented: Binding<Bool>, onChoice: @escaping (Bool) -> Void = { _ in }) -> some View {
        modifier(ICloudConsentPresenter(isPresented: isPresented, onChoice: onChoice))
    }
}

private struct ICloudConsentPresenter: ViewModifier {
    @Binding var isPresented: Bool
    let onChoice: (Bool) -> Void

    /// The cover itself, shown and hidden without the sheet slide: the popup
    /// fades and scales in and out on its own.
    @State private var isCoverShown = false

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $isCoverShown) {
                ICloudConsentPopup { enabled in
                    CloudSync.shared.isEnabled = enabled
                    onChoice(enabled)
                    withoutAnimation { isCoverShown = false }
                    isPresented = false
                }
                .presentationBackground(.clear)
            }
            .onChange(of: isPresented, initial: true) { _, shown in
                guard shown != isCoverShown else { return }
                withoutAnimation { isCoverShown = shown }
            }
    }

    private func withoutAnimation(_ change: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, change)
    }
}

/// The dimmed backdrop and the card in the middle of the screen.
private struct ICloudConsentPopup: View {
    let onChoice: (Bool) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShown = false

    var body: some View {
        ZStack {
            Color.black
                .opacity(isShown ? 0.45 : 0)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            ScrollView {
                card
                    .padding(.horizontal, 24)
                    .padding(.vertical, 32)
                    .frame(maxWidth: .infinity)
                    .containerRelativeFrame(.vertical, alignment: .center) { length, _ in length }
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .opacity(isShown ? 1 : 0)
            .scaleEffect(isShown || reduceMotion ? 1 : 0.92)
        }
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.4, dampingFraction: 0.82)) { isShown = true }
        }
    }

    private var card: some View {
        VStack(spacing: 0) {
            Image(systemName: "icloud.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(Color(hex: 0x32ADE6), in: .circle)
                .accessibilityHidden(true)

            Text("Back up to iCloud?")
                .font(.system(size: 22, weight: .bold))
                .kerning(-0.3)
                .multilineTextAlignment(.center)
                .padding(.top, 16)
                .accessibilityAddTraits(.isHeader)

            Text("Save your medicines, doses, weights, check-ins and side effects to your own iCloud, so they’re safe if you lose or change your phone and stay in sync on your iPhone and iPad.")
                .font(.system(size: 15))
                .lineSpacing(2)
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 12) {
                fact("lock.fill", String(localized: "Stored in your private iCloud account, run by Apple."))
                fact("eye.slash.fill", String(localized: "Only you can see it. Nothing is sent to us."))
                fact("switch.2", String(localized: "You can turn it off anytime in Settings."))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.ColorToken.background, in: .rect(cornerRadius: 16, style: .continuous))
            .padding(.top, 18)

            Button("Turn on iCloud backup") { choose(true) }
                .buttonStyle(.primary)
                .padding(.top, 20)

            Button("Not now") { choose(false) }
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.ColorToken.accent)
                .frame(maxWidth: .infinity, minHeight: 48)
                .contentShape(.rect)
                .padding(.top, 2)

            Text("If you choose Not now, your data stays only on this device.")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.ColorToken.tertiaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 22)
        .padding(.top, 26)
        .padding(.bottom, 18)
        .frame(maxWidth: 380)
        .background(AppTheme.ColorToken.cardBackground, in: .rect(cornerRadius: 30, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 30, y: 12)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    private func fact(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(hex: 0x32ADE6))
                .frame(width: 20, height: 20)
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func choose(_ enabled: Bool) {
        if enabled { HapticFeedback.notification(.success) } else { HapticFeedback.selection() }
        withAnimation(.easeOut(duration: 0.18)) { isShown = false }
        Task {
            try? await Task.sleep(for: .milliseconds(180))
            onChoice(enabled)
        }
    }
}

#Preview {
    Color.gray.opacity(0.2).ignoresSafeArea()
        .iCloudConsentPopup(isPresented: .constant(true))
}
