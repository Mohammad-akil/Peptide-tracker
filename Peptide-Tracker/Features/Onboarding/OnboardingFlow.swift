import SwiftUI

/// First-run setup: Get started → feature tour → Welcome → the GLP-1,
/// body and goal questions (with a few info screens between) → setting
/// up → the paywall. Steps that don't apply to the answers are skipped.
struct OnboardingFlow: View {
    @Environment(MedicineStore.self) private var store
    /// Called with whether to open Add straight away.
    let onFinish: (Bool) -> Void

    @State private var step: OnboardingStep
    @State private var answers = OnboardingAnswers()
    /// Which way the last move went, so Back slides the other way.
    @State private var isMovingForward = true

    init(startingAt step: OnboardingStep = .getStarted, onFinish: @escaping (Bool) -> Void) {
        _step = State(initialValue: step)
        self.onFinish = onFinish
    }

    var body: some View {
        ZStack {
            AppTheme.ColorToken.background.ignoresSafeArea()

            Group {
            switch step {
            case .getStarted:
                GetStartedView { go(to: .tour) }
                    .transition(.opacity)
            case .tour:
                FeatureTourView { go(to: .welcome) }
                    .transition(.push(from: .trailing))
            case .welcome:
                WelcomeView(onContinue: { go(to: .journey) })
                    .transition(.push(from: .trailing))
            case .settingUp:
                // Full screen, no back or progress bar; moves on by itself.
                SettingUpStep(answers: answers) { finish(adding: true) }
                    .padding(.horizontal, 20)
                    .transition(.opacity)
            default:
                questionFrame
                    .transition(.opacity)
            }
            }
            // One column on iPad, like a phone-sized card in the middle.
            .readableWidth(AppTheme.Layout.narrow)
        }
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
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                    .id(step)
                    .transition(.asymmetric(
                        insertion: .move(edge: isMovingForward ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: isMovingForward ? .leading : .trailing).combined(with: .opacity)
                    ))
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .clipped()

            bottomBar
        }
    }

    private var skipAction: (() -> Void)? {
        step.isQuestion ? { skip() } : nil
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .journey: JourneyQuestion(answers: $answers)
        case .route: RouteQuestion(answers: $answers)
        case .medication: MedicationQuestion(answers: $answers)
        case .dose: DoseQuestion(answers: $answers)
        case .device: DeviceQuestion(answers: $answers)
        case .frequency: FrequencyQuestion(answers: $answers)
        case .height: HeightQuestion(answers: $answers)
        case .weight: WeightQuestion(answers: $answers)
        case .start: StartQuestion(answers: $answers)
        case .goal: GoalQuestion(answers: $answers)
        case .momentum: MomentumStep(answers: answers)
        case .pace: PaceQuestion(answers: $answers)
        case .comparison: ComparisonStep(answers: answers)
        case .sideEffects: SideEffectsQuestion(answers: $answers)
        case .reason: ReasonQuestion(answers: $answers)
        default: EmptyView()
        }
    }

    private var bottomBar: some View {
        Button("Continue", action: advance)
            .buttonStyle(.glassPrimary)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
    }

    // MARK: Navigation

    private func go(to target: OnboardingStep) {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        isMovingForward = target > step
        withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) { step = target }
    }

    private func advance() {
        HapticFeedback.selection()
        guard var next = step.next else { return }
        while !answers.asks(next), let after = next.next { next = after }
        go(to: next)
    }

    private func skip() {
        answers.reset(step)
        advance()
    }

    private func back() {
        guard var previous = step.previous else { return }
        while !answers.asks(previous), let before = previous.previous { previous = before }
        go(to: previous)
    }

    private func finish(adding: Bool) {
        answers.apply(to: &store.settings)
        for entry in answers.weighIns { store.logWeight(kilograms: entry.kilograms, on: entry.day, asksForRating: false) }
        onFinish(adding)
    }
}

#Preview {
    OnboardingFlow { _ in }
        .environment(MedicineStore.preview(sample: false))
}
