import SwiftUI

/// The screens of first-run setup, in order. Every question changes how the
/// app behaves; skipping one keeps its default.
enum OnboardingStep: Int, CaseIterable, Comparable {
    // Raw names double as `-onboarding <step>` debug launch arguments.
    case getStarted, tour, welcome, who, refill, benefit, doses, time, pharmacy, plan

    static let questionCount = 5

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Filled segments of the progress bar.
    var progress: Int {
        switch self {
        case .getStarted, .tour, .welcome: 0
        case .who: 1
        case .refill, .benefit: 2
        case .doses: 3
        case .time: 4
        case .pharmacy, .plan: 5
        }
    }

    var isQuestion: Bool { [.who, .refill, .doses, .time, .pharmacy].contains(self) }

    var next: Self? { Self(rawValue: rawValue + 1) }
    var previous: Self? { Self(rawValue: rawValue - 1) }
}

/// What the user picked, applied to settings only when setup finishes.
struct OnboardingAnswers {
    var trackingFor = TrackingFor.me
    var personName = ""
    var leadTime = RefillLeadTime.oneToTwoDays
    var tracksDoses = true
    var reminderTime = TimeOfDay.defaultReminder
    var pharmacyKind = PharmacyKind.one
    var pharmacyName = ""
    var pharmacyPhone = ""

    /// Puts a question back to its default — what Skip does.
    mutating func reset(_ step: OnboardingStep) {
        let defaults = OnboardingAnswers()
        switch step {
        case .who: trackingFor = defaults.trackingFor; personName = ""
        case .refill: leadTime = defaults.leadTime
        case .doses: tracksDoses = defaults.tracksDoses
        case .time: reminderTime = defaults.reminderTime
        case .pharmacy: pharmacyKind = defaults.pharmacyKind; pharmacyName = ""; pharmacyPhone = ""
        default: break
        }
    }

    func apply(to settings: inout AppSettings) {
        settings.trackingFor = trackingFor
        settings.personName = trackingFor == .me ? "" : personName.trimmingCharacters(in: .whitespaces)
        settings.defaultDaysBefore = leadTime.daysBefore
        settings.tracksDoses = tracksDoses
        settings.defaultReminderTime = reminderTime
        settings.pharmacyKind = pharmacyKind
        if pharmacyKind == .one {
            settings.pharmacyName = pharmacyName.trimmingCharacters(in: .whitespaces)
            settings.pharmacyPhone = pharmacyPhone.trimmingCharacters(in: .whitespaces)
        }
    }
}

/// First-run setup: Get started → feature tour → Welcome → five questions (with what the
/// lead-time answer means, as a chart) → the summary → Add medicine.
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
        case .plan: PlanSummary(answers: answers, onEdit: edit)
        default: EmptyView()
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            if step == .refill {
                OnboardingNote(icon: .bell, text: leadTimeNote)
            }
            if step == .plan {
                Button("Add your first medicine") { finish(adding: true) }
                    .buttonStyle(.primary(height: 56))
            } else {
                Button("Continue", action: advance)
                    .buttonStyle(.primary(height: 56))
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

// MARK: - Q1 Who

private struct WhoQuestion: View {
    @Binding var answers: OnboardingAnswers

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            OnboardingHeader(
                eyebrow: "Question 1 of 5",
                title: "Who are you tracking medicines for?",
                reason: "So reminders use the right name. You can add more people later."
            )
            VStack(spacing: 10) {
                choice(.me, icon: .user, subtitle: "Track my own medicines")
                choice(.someoneElse, icon: .heart, subtitle: "A parent, child or partner")
                choice(.both, icon: .users, subtitle: "Keep a separate list for each person")
            }
        }
    }

    private func choice(_ option: TrackingFor, icon: AppIcon, subtitle: String) -> some View {
        let isSelected = answers.trackingFor == option
        return OnboardingChoice(
            icon: icon,
            title: option.title,
            subtitle: subtitle,
            isSelected: isSelected,
            action: { answers.trackingFor = option }
        ) {
            if isSelected && option == .someoneElse {
                ChoiceDivider()
                OnboardingField(label: "Their name", placeholder: "e.g. Mum", text: $answers.personName)
                    .textContentType(.givenName)
                Text("Reminders will say “\(answers.personName.isEmpty ? "Mum" : answers.personName)’s Metformin runs out in 5 days”.")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
            }
        }
    }
}

// MARK: - Q2 Refill lead time

private struct RefillQuestion: View {
    @Binding var answers: OnboardingAnswers

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            OnboardingHeader(
                eyebrow: "Question 2 of 5",
                title: "How long does a refill usually take you?",
                reason: "From the moment you order to having it in your hand. This sets how early we remind you."
            )
            VStack(spacing: 10) {
                choice(.sameDay, icon: .zap, title: "Same day", subtitle: "I pick it up whenever I need it")
                choice(.oneToTwoDays, icon: .store, title: "1 to 2 days", subtitle: "The pharmacy orders it in")
                choice(.threeToFiveDays, icon: .truck, title: "3 to 5 days", subtitle: "It comes by delivery or post")
                choice(.weekOrMore, icon: .steth, title: "A week or more", subtitle: "My doctor has to renew the prescription")
            }
        }
    }

    private func choice(_ option: RefillLeadTime, icon: AppIcon, title: String, subtitle: String) -> some View {
        OnboardingChoice(
            icon: icon,
            title: title,
            subtitle: subtitle,
            isSelected: answers.leadTime == option,
            action: { answers.leadTime = option }
        )
    }
}

// MARK: - Q2b What this means

private struct BenefitStep: View {
    let answers: OnboardingAnswers

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingHeader(eyebrow: "What this means for you", title: "No more running out between packs.")
            BenefitChart(daysBefore: answers.leadTime.daysBefore)
            VStack(alignment: .leading, spacing: 12) {
                point(.bell, "A reminder \(answers.leadTime.daysBefore) days before each run-out")
                point(.store, "Time to order and pick up, without rushing")
                point(.check, "No gaps between packs")
            }
            Text("Example for one medicine taken twice a day from 60-pill packs. Your dates depend on what you add.")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func point(_ icon: AppIcon, _ text: String) -> some View {
        HStack(spacing: 12) {
            Icon(icon, size: 17)
                .foregroundStyle(AppTheme.ColorToken.accent)
                .frame(width: 32, height: 32)
                .background(AppTheme.ColorToken.accentSoft, in: .rect(cornerRadius: 10, style: .continuous))
            Text(text).font(.system(size: 16, weight: .medium))
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Q3 Doses

private struct DosesQuestion: View {
    @Binding var answers: OnboardingAnswers

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            OnboardingHeader(
                eyebrow: "Question 3 of 5",
                title: "Do you want dose reminders too?",
                reason: "Refill reminders are always on. Dose reminders are optional."
            )
            VStack(spacing: 12) {
                OnboardingChoice(
                    icon: .check,
                    title: "Remind me to take doses",
                    subtitle: "Tick off each dose and your count stays exact.",
                    isSelected: answers.tracksDoses,
                    action: { answers.tracksDoses = true }
                ) {
                    example {
                        (Text("Metformin ").fontWeight(.semibold) + Text("· 20:00").foregroundStyle(AppTheme.ColorToken.secondaryText))
                        Spacer(minLength: 0)
                        Circle()
                            .strokeBorder(Color(light: 0xCBC6D9, dark: 0x4C4858), lineWidth: 2)
                            .frame(width: 24, height: 24)
                    }
                }
                OnboardingChoice(
                    icon: .pill,
                    title: "Just track my supply",
                    subtitle: "We count down from your schedule. One reminder before you run out.",
                    isSelected: !answers.tracksDoses,
                    action: { answers.tracksDoses = false }
                ) {
                    example {
                        Text("Metformin").fontWeight(.semibold)
                        Spacer(minLength: 0)
                        Text("13 days left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Urgency.healthy.ink)
                    }
                }
            }
        }
    }

    /// A small preview row of what the choice looks like on Today.
    private func example<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 10) {
            MedicineIconView(type: .capsule, color: .blue, size: 30)
            content()
        }
        .font(.system(size: 15))
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.ColorToken.background, in: .rect(cornerRadius: 14, style: .continuous))
        .accessibilityHidden(true)
    }
}

// MARK: - Q4 Reminder time

private struct TimeQuestion: View {
    @Binding var answers: OnboardingAnswers
    @State private var picksCustomTime = false

    private let presets: [(TimeOfDay, String)] = [
        (TimeOfDay(hour: 9, minute: 0), "Morning"),
        (TimeOfDay(hour: 13, minute: 0), "Lunchtime"),
        (TimeOfDay(hour: 18, minute: 0), "After work"),
        (TimeOfDay(hour: 20, minute: 0), "Evening"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            OnboardingHeader(
                eyebrow: "Question 4 of 5",
                title: "When should refill reminders arrive?",
                reason: "Pick a time you can act on, like before you pass the pharmacy."
            )
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                ForEach(presets, id: \.0) { time, name in
                    preset(time, name: name)
                }
            }

            Button { picksCustomTime = true } label: {
                Label {
                    Text(isCustom ? "Another time · \(answers.reminderTime.label)" : "Choose another time")
                } icon: {
                    Icon(.clock, size: 18)
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.ColorToken.accent)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .padding(.vertical, -11)

            VStack(alignment: .leading, spacing: 8) {
                Text("Preview")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    .padding(.leading, 4)
                HStack(alignment: .top, spacing: 12) {
                    Icon(.pill, size: 20)
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.ColorToken.accent, in: .rect(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Metformin runs out in 5 days").font(.system(size: 15, weight: .semibold))
                            Spacer(minLength: 8)
                            Text(answers.reminderTime.label)
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.ColorToken.secondaryText)
                                .contentTransition(.numericText())
                        }
                        Text("Tap to refill.").font(.system(size: 15))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(AppTheme.ColorToken.cardBackground, in: .rect(cornerRadius: 22, style: .continuous))
                .shadow(color: Color(hex: 0x28185A, opacity: 0.08), radius: 12, y: 8)
                .accessibilityElement(children: .combine)
            }
        }
        .sheet(isPresented: $picksCustomTime) {
            ReminderTimePicker(time: $answers.reminderTime)
        }
    }

    private var isCustom: Bool { !presets.contains { $0.0 == answers.reminderTime } }

    private func preset(_ time: TimeOfDay, name: String) -> some View {
        let isSelected = answers.reminderTime == time
        return Button {
            HapticFeedback.selection()
            withAnimation(.snappy) { answers.reminderTime = time }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(time.label)
                    .font(.system(size: 24, weight: .bold))
                    .kerning(-0.4)
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? AppTheme.ColorToken.accent : AppTheme.ColorToken.primaryText)
                Text(name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 82)
            .background(
                isSelected ? AppTheme.ColorToken.accentSoft : AppTheme.ColorToken.cardBackground,
                in: .rect(cornerRadius: 20, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        isSelected ? AppTheme.ColorToken.accent : Color(hex: 0x28185A, opacity: 0.08),
                        lineWidth: isSelected ? 2 : 0.5
                    )
            }
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("\(time.label), \(name)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct ReminderTimePicker: View {
    @Binding var time: TimeOfDay
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            DatePicker(
                "Reminder time",
                selection: Binding(get: { time.on(.now) }, set: { time = TimeOfDay(date: $0) }),
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .environment(\.locale, Locale(identifier: "en_GB"))
            .navigationTitle("Reminder time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(320)])
    }
}

// MARK: - Q5 Pharmacy

private struct PharmacyQuestion: View {
    @Binding var answers: OnboardingAnswers

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            OnboardingHeader(
                eyebrow: "Question 5 of 5",
                title: "Where do you get your refills?",
                reason: "Optional. With a pharmacy saved, reminders get a Call pharmacy button."
            )
            VStack(spacing: 10) {
                OnboardingChoice(
                    icon: .store,
                    title: "One pharmacy I go to",
                    subtitle: "Add it to every reminder",
                    isSelected: answers.pharmacyKind == .one,
                    action: { answers.pharmacyKind = .one }
                ) {
                    if answers.pharmacyKind == .one {
                        ChoiceDivider()
                        OnboardingField(label: "Pharmacy name", placeholder: "e.g. the one on your street", text: $answers.pharmacyName)
                            .textContentType(.organizationName)
                        OnboardingField(label: "Phone (optional)", placeholder: "For the Call pharmacy button", text: $answers.pharmacyPhone)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                    }
                }
                OnboardingChoice(
                    icon: .truck,
                    title: "Delivery or online pharmacy",
                    subtitle: "Reminders come early enough for shipping",
                    isSelected: answers.pharmacyKind == .delivery,
                    action: { answers.pharmacyKind = .delivery }
                )
                OnboardingChoice(
                    icon: .sliders,
                    title: "It varies",
                    subtitle: "No pharmacy on reminders",
                    isSelected: answers.pharmacyKind == .varies,
                    action: { answers.pharmacyKind = .varies }
                )
            }
        }
    }
}

// MARK: - You're set up

private struct PlanSummary: View {
    let answers: OnboardingAnswers
    let onEdit: (OnboardingStep) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            OnboardingHeader(
                eyebrow: "All done",
                title: "You’re set up.",
                reason: "Here’s how reminders will work. Tap a line to change it."
            )
            VStack(spacing: 0) {
                row(.user, "Tracking for", trackingValue, step: .who)
                row(.bell, "Heads-up", "\(answers.leadTime.daysBefore) days before", step: .refill)
                row(.clock, "Reminder time", answers.reminderTime.label, step: .time)
                row(.check, "Dose reminders", answers.tracksDoses ? "On" : "Off", step: .doses)
                row(.store, "Pharmacy", pharmacyValue, step: .pharmacy, showsDivider: false)
            }
            .groupedCard()

            OnboardingNote(icon: .sliders, text: Text("Change any of this later in Settings."))
        }
    }

    private var trackingValue: String {
        let name = answers.personName.trimmingCharacters(in: .whitespaces)
        return answers.trackingFor == .someoneElse && !name.isEmpty ? name : answers.trackingFor.title
    }

    private var pharmacyValue: String {
        let name = answers.pharmacyName.trimmingCharacters(in: .whitespaces)
        return answers.pharmacyKind == .one && !name.isEmpty ? name : answers.pharmacyKind.title
    }

    private func row(_ icon: AppIcon, _ title: String, _ value: String, step: OnboardingStep, showsDivider: Bool = true) -> some View {
        Button { onEdit(step) } label: {
            HStack(spacing: 12) {
                Icon(icon, size: 18)
                    .foregroundStyle(AppTheme.ColorToken.accent)
                    .frame(width: 34, height: 34)
                    .background(AppTheme.ColorToken.accentSoft, in: .rect(cornerRadius: 10, style: .continuous))
                Text(title)
                    .font(.system(size: 17))
                    .foregroundStyle(AppTheme.ColorToken.primaryText)
                Spacer(minLength: 8)
                Text(value)
                    .font(.system(size: 17))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    .lineLimit(1)
                Chevron()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 52)
            .contentShape(.rect)
            .rowDivider(showsDivider, inset: 62)
        }
        .buttonStyle(RowPressStyle())
    }
}

#Preview {
    OnboardingFlow { _ in }
        .environment(MedicineStore.preview(sample: false))
}
