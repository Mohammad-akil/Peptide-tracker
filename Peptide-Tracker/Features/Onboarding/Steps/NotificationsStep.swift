import SwiftUI

// MARK: - Notifications

/// Asks for notification permission in context, right after the reminder
/// questions, with a stand-in of the system alert (Cal AI style) and a hand
/// pointing at Allow. "Allow" shows the real system prompt; "Don't Allow" moves on
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

            Image(systemName: "bell.badge.fill")
                .font(.system(size: 30, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(Urgency.critical.tint, .white)
                .frame(width: 64, height: 64)
                .background(AppTheme.ColorToken.accent, in: .rect(cornerRadius: 18, style: .continuous))
                .symbolEffect(.wiggle, options: .repeating.speed(0.6), isActive: !reduceMotion)
                .padding(.bottom, 20)
                .accessibilityHidden(true)

            Text(title)
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
                .padding(.bottom, 32)

            permissionCard

            // Points up at Allow, nudging toward it.
            HStack {
                Spacer()
                Image(systemName: "hand.point.up.left.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(AppTheme.ColorToken.accent)
                    .offset(y: isPointing ? -6 : 6)
                    .frame(maxWidth: .infinity)
            }
            .frame(width: 270)
            .padding(.top, 10)
            .accessibilityHidden(true)

            Spacer(minLength: 0)

            Text("You can change this anytime in Settings.")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.ColorToken.tertiaryText)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { isPointing = true }
        }
    }

    private var title: String {
        answers.tracksDoses ? "Never miss a dose" : "Never miss a refill"
    }

    private var reason: String {
        let days = answers.leadTime.daysBefore
        return answers.tracksDoses
            ? "Get a reminder at each dose time, and \(days) days before a medicine runs out."
            : "Get a reminder \(days) days before a medicine runs out, in time to refill."
    }

    /// Drawn like the iOS alert, so the real one that follows is expected:
    /// Allow highlighted on the right, with the hand under it.
    private var permissionCard: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("“\(Bundle.main.appName)” Would Like to Send You Notifications")
                    .font(.system(size: 17, weight: .semibold))
                Text("Notifications may include alerts, sounds and icon badges. These can be configured in Settings.")
                    .font(.system(size: 13))
            }
            .multilineTextAlignment(.center)
            .foregroundStyle(AppTheme.ColorToken.primaryText)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Rectangle().fill(AppTheme.ColorToken.separator).frame(height: 0.5)

            HStack(spacing: 0) {
                Button {
                    HapticFeedback.impact()
                    onFinish()
                } label: {
                    Text("Don’t Allow")
                        .font(.system(size: 17))
                        .foregroundStyle(AppTheme.ColorToken.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)

                Rectangle().fill(AppTheme.ColorToken.separator).frame(width: 0.5, height: 50)

                Button(action: requestPermission) {
                    Group {
                        if isRequesting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Allow")
                                .font(.system(size: 17, weight: .semibold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(AppTheme.ColorToken.accent)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .disabled(isRequesting)
            }
        }
        .frame(width: 270)
        .background(.regularMaterial, in: .rect(cornerRadius: 14, style: .continuous))
        .clipShape(.rect(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 24, y: 12)
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
