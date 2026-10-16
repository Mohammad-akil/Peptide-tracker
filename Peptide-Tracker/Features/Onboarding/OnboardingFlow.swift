import SwiftUI

/// First-run setup: Get started → feature tour → Welcome → five questions (with what the
/// lead-time answer means, as a chart) → notifications → setting up → the summary → Add medicine.
struct OnboardingFlow: View {
    @Environment(MedicineStore.self) private var store
    /// Called with whether to open Add straight away.
    let onFinish: (Bool) -> Void

    @State private var step: OnboardingStep
    @State private var answers = OnboardingAnswers()
    /// Set when a summary line is tapped, so Continue goes back to it.
    @State private var returnsToPlan = false

    init(startingAt step: OnboardingStep = .getStarted, onFinish: @escaping (Bool) -> Void) {
        _step = State(initialValue: step)
        self.onFinish = onFinish
    }

    var body: some View {
        ZStack {
            AppTheme.ColorToken.background.ignoresSafeArea()

            switch step {
            case .getStarted:
                GetStartedView { go(to: .tour) }
                    .transition(.opacity)
            case .tour:
                FeatureTourView { go(to: .welcome) }
                    .transition(.push(from: .trailing))
            case .welcome:
                WelcomeView(onContinue: { go(to: .who) })
                    .transition(.push(from: .trailing))
            case .settingUp:
                // Full screen, no back or progress bar; moves on by itself.
                SettingUpStep(answers: answers) { go(to: .plan) }
                    .padding(.horizontal, 20)
                    .transition(.opacity)
            default:
                questionFrame
                    .transition(.opacity)
            }
        }
        .animation(.snappy(duration: 0.35), value: step)
    }

    private var questionFrame: some View {
        VStack(spacing: 0) {
            OnboardingTopBar(
                progress: step.progress,
                onBack: back,
                onSkip: skipAction
            )
            .padding(.top, 8)

            ScrollView {
                stepContent
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                    .id(step)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)

            bottomBar
        }
    }

    private var skipAction: (() -> Void)? {
        step.isQuestion ? { skip() } : nil
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .who: WhoQuestion(answers: $answers)
        case .refill: RefillQuestion(answers: $answers)
        case .benefit: BenefitStep(answers: answers)
        case .doses: DosesQuestion(answers: $answers)
        case .time: TimeQuestion(answers: $answers)
        case .pharmacy: PharmacyQuestion(answers: $answers)
        case .notifications: NotificationsStep(answers: answers) { go(to: .settingUp) }
        case .plan: PlanSummary(answers: answers, onEdit: edit)
        default: EmptyView()
        }
    }

    /// The notifications step answers with its own Allow / Don't Allow.
    @ViewBuilder
    private var bottomBar: some View {
        if step != .notifications { continueBar }
    }

    private var continueBar: some View {
        VStack(spacing: 12) {
            if step == .refill {
                OnboardingNote(icon: .bell, text: leadTimeNote)
            }
            if step == .plan {
                Button("Add your first medicine") { finish(adding: true) }
                    .buttonStyle(.glassPrimary)
            } else {
                Button("Continue", action: advance)
                    .buttonStyle(.glassPrimary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private var leadTimeNote: Text {
        let days = Text("\(answers.leadTime.daysBefore) days").bold()
        return Text("We’ll remind you \(days) before each medicine runs out.")
    }

    // MARK: Navigation

    private func go(to target: OnboardingStep) {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        step = target
    }

    private func advance() {
        HapticFeedback.selection()
        if returnsToPlan {
            returnsToPlan = false
            go(to: .plan)
        } else if let next = step.next {
            go(to: next)
        }
    }

    /// A summary line was tapped: answer again, then come back.
    private func edit(_ target: OnboardingStep) {
        returnsToPlan = true
        go(to: target)
    }

    private func skip() {
        answers.reset(step)
        advance()
    }

    private func back() {
        returnsToPlan = false
        if let previous = step.previous { go(to: previous) }
    }

    private func finish(adding: Bool) {
        answers.apply(to: &store.settings)
        onFinish(adding)
    }
}

#Preview {
    OnboardingFlow { _ in }
        .environment(MedicineStore.preview(sample: false))
}
