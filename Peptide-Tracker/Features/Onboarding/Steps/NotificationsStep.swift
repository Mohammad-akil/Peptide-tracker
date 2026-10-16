import SwiftUI

// MARK: - Notifications

/// Asks for notification permission in context, right after the reminder
/// questions, with a stand-in of the system alert and a hand pointing at
/// Allow. "Allow" shows the real system prompt; "Don't Allow" moves on
/// without asking, so nobody is pushed into it. Same as the team's other apps.
struct NotificationsStep: View {
    let answers: OnboardingAnswers
    let onFinish: () -> Void

    @Environment(MedicineStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPointing = false
    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            Text("Never miss a refill")
                .font(.system(size: 30, weight: .heavy))
                .kerning(-0.7)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text(reason)
                .font(.system(size: 16))
                .lineSpacing(3)
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
                .padding(.bottom, 28)

            permissionCard

            Text("👆")
                .font(.system(size: 34))
                .offset(x: 62, y: isPointing ? -4 : 6)
                .padding(.top, 8)
                .accessibilityHidden(true)

            Spacer(minLength: 0)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { isPointing = true }
        }
    }

    private var reason: String {
        let days = answers.leadTime.daysBefore
        return answers.tracksDoses
            ? "We’ll tell you \(days) days before a medicine runs out, and when it’s time for each dose."
            : "We’ll tell you \(days) days before a medicine runs out, in time to refill."
    }

    /// Looks like the system alert, so the real one that follows is expected.
    private var permissionCard: some View {
        VStack(spacing: 0) {
            Text("“\(Bundle.main.appName)” would like to send you notifications")
                .font(.system(size: 16, weight: .semibold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.vertical, 24)

            HStack(spacing: 0) {
                Button {
                    HapticFeedback.impact()
                    onFinish()
                } label: {
                    Text("Don’t Allow")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.ColorToken.primaryText)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)

                Button(action: requestPermission) {
                    Group {
                        if isRequesting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Allow")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(AppTheme.ColorToken.accent)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .disabled(isRequesting)
            }
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(AppTheme.ColorToken.separator)
                    .frame(height: 0.5)
            }
        }
        .background(AppTheme.ColorToken.cardBackground)
        .clipShape(.rect(cornerRadius: 18, style: .continuous))
        .shadow(color: Color(hex: 0x28185A, opacity: 0.08), radius: 16, y: 10)
        .padding(.horizontal, 16)
    }

    /// Shows the system prompt (a no-op if it was already answered, e.g. on
    /// a reinstall), then moves on whatever they choose.
    private func requestPermission() {
        HapticFeedback.impact()
        isRequesting = true
        Task {
            store.settings.notificationsEnabled = await store.scheduler.requestAuthorization()
            isRequesting = false
            onFinish()
        }
    }
}

#Preview {
    NotificationsStep(answers: OnboardingAnswers()) {}
        .padding(.horizontal, 20)
        .environment(MedicineStore.preview(sample: false))
}
