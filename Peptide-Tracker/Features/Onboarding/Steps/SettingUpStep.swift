import SwiftUI

// MARK: - Setting up

/// A short "setting everything up" beat between the last question and the
/// summary: a counting percentage, a status line and a checklist of what the
/// answers just configured. Moves on by itself; going back skips over it.
/// Same choreography as the team's other apps.
struct SettingUpStep: View {
    let answers: OnboardingAnswers
    let onFinish: () -> Void

    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: Double = 0

    /// Each item ticks once `progress` passes its threshold; the status line
    /// shows the first unticked one.
    private var items: [(title: String, status: String)] {
        [
            ("Who you’re tracking for", "Setting up \(trackingName)…"),
            ("Refill heads-up", "Timing reminders \(answers.leadTime.daysBefore) days ahead…"),
            (answers.tracksDoses ? "Dose reminders" : "Supply countdown",
             answers.tracksDoses ? "Turning on dose reminders…" : "Starting your supply countdown…"),
            ("Reminder time", "Scheduling reminders for \(answers.reminderTime.label)…"),
            ("Pharmacy", pharmacyStatus),
        ]
    }

    private var pharmacyStatus: String {
        switch answers.pharmacyKind {
        case .one: "Adding your pharmacy to reminders…"
        case .delivery: "Leaving time for delivery…"
        case .varies: "Keeping reminders pharmacy-free…"
        }
    }

    private var trackingName: String {
        let name = answers.personName.trimmingCharacters(in: .whitespaces)
        return answers.trackingFor == .someoneElse && !name.isEmpty ? "\(name)’s list" : "your list"
    }

    private func threshold(for index: Int) -> Double {
        Double(index + 1) / Double(items.count)
    }

    private var statusText: String {
        items.indices.first { progress < threshold(for: $0) }.map { items[$0].status } ?? "All set!"
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            Text(verbatim: "\(Int((progress * 100).rounded()))%")
                .font(.system(size: 64, weight: .heavy))
                .kerning(-2)
                .contentTransition(.numericText(value: progress))
                .monospacedDigit()

            Text("We’re setting everything up for you")
                .font(.system(size: 26, weight: .bold))
                .kerning(-0.5)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)

            progressBar
                .padding(.top, 24)

            Text(statusText)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
                .contentTransition(.opacity)
                .padding(.top, 16)

            checklist
                .padding(.top, 32)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .task { await run() }
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(hex: 0x767680, opacity: 0.18))
                // Purples only (lilac → accent → indigo) so the bar stays on
                // the app's theme while still reading as a gradient.
                Capsule()
                    .fill(LinearGradient(
                        colors: [Color(hex: 0xA88BFF), AppTheme.ColorToken.accent, Color(hex: 0x4B2DB8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: proxy.size.width * progress)
                    .shadow(color: AppTheme.ColorToken.accent.opacity(0.35), radius: 6, y: 2)
            }
        }
        .frame(height: 8)
    }

    private var checklist: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your reminder setup")
                .font(.system(size: 16, weight: .bold))

            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                let isDone = progress >= threshold(for: index)
                HStack {
                    Text("•  \(item.title)")
                        .font(.system(size: 15, weight: .medium))
                    Spacer(minLength: 0)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(AppTheme.ColorToken.accent)
                        .scaleEffect(isDone ? 1 : 0.3)
                        .opacity(isDone ? 1 : 0)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.ColorToken.cardBackground, in: .rect(cornerRadius: 20, style: .continuous))
    }

    /// About 4 seconds end to end (quicker with Reduce Motion), with a tick
    /// of haptic feedback as each checklist item completes.
    private func run() async {
        let steps = 50
        let stepDuration: Duration = reduceMotion ? .milliseconds(30) : .milliseconds(80)
        for step in 1...steps {
            try? await Task.sleep(for: stepDuration)
            guard !Task.isCancelled else { return }
            let next = Double(step) / Double(steps)
            let crossedItem = items.indices.contains { progress < threshold(for: $0) && next >= threshold(for: $0) }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { progress = next }
            if crossedItem { HapticFeedback.selection() }
        }
        HapticFeedback.notification(.success)
        router.celebrate()
        try? await Task.sleep(for: .milliseconds(1200))
        guard !Task.isCancelled else { return }
        onFinish()
    }
}

#Preview {
    SettingUpStep(answers: OnboardingAnswers()) {}
        .padding(.horizontal, 20)
        .environment(AppRouter())
}
