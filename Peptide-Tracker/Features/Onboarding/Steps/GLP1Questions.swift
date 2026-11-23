import SwiftUI

// MARK: - Q1 Journey

struct JourneyQuestion: View {
    @Binding var answers: OnboardingAnswers

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            OnboardingHeader(
                title: "Are you already taking a GLP-1 medication?",
                reason: "We’ll customize the app based on where you are in your GLP-1 journey."
            )
            VStack(spacing: 10) {
                choice(.taking, icon: .check, subtitle: "Track doses, supply and refills").stagger(0)
                choice(.notStarted, icon: .cal, subtitle: "Get ready for your first dose").stagger(1)
            }
        }
    }

    private func choice(_ option: GLP1Journey, icon: AppIcon, subtitle: String) -> some View {
        OnboardingChoice(
            icon: icon,
            title: option.title,
            subtitle: subtitle,
            isSelected: answers.journey == option,
            action: { answers.journey = option }
        )
    }
}

// MARK: - Q2 Route

struct RouteQuestion: View {
    @Binding var answers: OnboardingAnswers

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            OnboardingHeader(
                title: answers.journey == .notStarted
                    ? "How will you take your GLP-1 medication?"
                    : "How do you take your GLP-1 medication?",
                reason: "We’ll customize the app based on your treatment type."
            )
            VStack(spacing: 10) {
                choice(.injection, icon: .syringe, subtitle: "A pen or vial, usually once a week").stagger(0)
                choice(.pill, icon: .pill, subtitle: "A tablet you swallow, usually daily").stagger(1)
                choice(.notSure, icon: .info, subtitle: "You can change this later").stagger(2)
            }
        }
    }

    private func choice(_ option: GLP1Route, icon: AppIcon, subtitle: String) -> some View {
        OnboardingChoice(
            icon: icon,
            title: option.title,
            subtitle: subtitle,
            isSelected: answers.route == option,
            action: {
                answers.route = option
                // Drop a medication that doesn't come in this form.
                if let medication = answers.medication,
                   !GLP1Medication.options(for: option).contains(medication) {
                    answers.medication = nil
                }
                if let dose = answers.dose,
                   !(answers.medication ?? .dontKnow).doses(route: option).contains(dose) {
                    answers.dose = nil
                }
            }
        )
    }
}

// MARK: - Q3 Medication

struct MedicationQuestion: View {
    @Binding var answers: OnboardingAnswers

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            OnboardingHeader(
                title: answers.journey == .notStarted
                    ? "Which GLP-1 medication are you planning to take?"
                    : "Which GLP-1 medication are you taking?",
                reason: "If it’s not listed, choose Other."
            )
            VStack(spacing: 10) {
                ForEach(Array(GLP1Medication.options(for: answers.route).enumerated()), id: \.element) { index, option in
                    choice(option).stagger(index)
                }
            }
        }
    }

    private func choice(_ option: GLP1Medication) -> some View {
        let isSelected = answers.medication == option
        return OnboardingChoice(
            icon: icon(for: option),
            title: option.title,
            subtitle: option.subtitle,
            isSelected: isSelected,
            action: {
                answers.medication = option
                if let dose = answers.dose, !option.doses(route: answers.route).contains(dose) {
                    answers.dose = nil
                }
            }
        ) {
            if isSelected && option == .other {
                ChoiceDivider()
                OnboardingField(label: "Medication name", placeholder: "e.g. Dulaglutide", text: $answers.otherMedication)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
            }
        }
    }

    private func icon(for option: GLP1Medication) -> AppIcon {
        switch option {
        case .other: .edit
        case .dontKnow: .info
        case .rybelsus: .pill
        case .wegovyPill: .pill
        default: .syringe
        }
    }
}

// MARK: - Q4 Dose

struct DoseQuestion: View {
    @Binding var answers: OnboardingAnswers

    private var doses: [Double] {
        (answers.medication ?? .dontKnow).doses(route: answers.route)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            OnboardingHeader(
                title: answers.journey == .notStarted
                    ? "What dose will you start on?"
                    : "What’s your current dose?",
                reason: "If it’s not listed, choose Other."
            )
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(Array(doses.enumerated()), id: \.element) { index, dose in
                    doseTile((answers.medication ?? .dontKnow).doseLabel(dose), isSelected: answers.dose == dose && !answers.isOtherDose) {
                        answers.dose = dose
                        answers.isOtherDose = false
                    }
                    .stagger(index)
                }
            }
            OnboardingChoice(
                icon: .edit,
                title: "Other",
                subtitle: "Type your dose",
                isSelected: answers.isOtherDose,
                action: { answers.isOtherDose = true; answers.dose = nil }
            ) {
                if answers.isOtherDose {
                    ChoiceDivider()
                    OnboardingField(label: "Your dose", placeholder: answers.medication?.doseUnit == "units" ? "e.g. 24 units" : "e.g. 0.75 mg", text: $answers.otherDose)
                        .keyboardType(.decimalPad)
                }
            }
            .stagger(doses.count)
        }
    }

    private func doseTile(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            HapticFeedback.selection()
            withAnimation(.snappy) { action() }
        } label: {
            HStack {
                Text(label)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.ColorToken.primaryText)
                Spacer(minLength: 0)
                RadioMark(isSelected: isSelected, size: 22)
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(
                isSelected ? AppTheme.ColorToken.accentSoft : AppTheme.ColorToken.cardBackground,
                in: .rect(cornerRadius: 18, style: .continuous)
            )
            .selectionBorder(isSelected, cornerRadius: 18)
            .scaleEffect(isSelected ? 1.02 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Q5 Device

struct DeviceQuestion: View {
    @Binding var answers: OnboardingAnswers

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            OnboardingHeader(
                title: answers.journey == .notStarted
                    ? "What will you use to take your GLP-1 shots?"
                    : "What do you use to take your GLP-1 shots?",
                reason: "We’ll tailor injection tips and supply tracking to your device."
            )
            VStack(spacing: 10) {
                choice(.singleUsePen, icon: .syringe, subtitle: "A new prefilled pen for each dose").stagger(0)
                choice(.autoInjector, icon: .zap, subtitle: "Press it on and it injects for you").stagger(1)
                choice(.syringeAndVial, icon: .drop, subtitle: "Draw up each dose from a vial").stagger(2)
                choice(.other, icon: .edit, subtitle: "Type what you use").stagger(3)
            }
        }
    }

    private func choice(_ option: GLP1Device, icon: AppIcon, subtitle: String) -> some View {
        let isSelected = answers.device == option
        return OnboardingChoice(
            icon: icon,
            title: option.title,
            subtitle: subtitle,
            isSelected: isSelected,
            action: { answers.device = option }
        ) {
            if isSelected && option == .other {
                ChoiceDivider()
                OnboardingField(label: "Your device", placeholder: "e.g. Reusable pen", text: $answers.otherDevice)
                    .textInputAutocapitalization(.sentences)
            }
        }
    }
}

// MARK: - Q6 Frequency

struct FrequencyQuestion: View {
    @Binding var answers: OnboardingAnswers

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            OnboardingHeader(
                title: answers.route == .pill
                    ? "How often do you take your GLP-1?"
                    : "How often do you take your shots?",
                reason: "We’ll schedule your dose reminders around it."
            )
            VStack(spacing: 10) {
                choice(.daily, icon: .sun, subtitle: "One dose a day").stagger(0)
                choice(.weekly, icon: .cal, subtitle: "Once a week, on the same day").stagger(1)
                choice(.everyTwoWeeks, icon: .cal, subtitle: "Once every two weeks").stagger(2)
                choice(.custom, icon: .sliders, subtitle: "Pick the number of days between doses").stagger(3)
            }
        }
    }

    private func choice(_ option: GLP1Frequency, icon: AppIcon, subtitle: String) -> some View {
        let isSelected = answers.frequency == option
        return OnboardingChoice(
            icon: icon,
            title: option.title,
            subtitle: subtitle,
            isSelected: isSelected,
            action: { answers.frequency = option }
        ) {
            if isSelected && option == .custom {
                ChoiceDivider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("Days between doses")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    Picker("Days between doses", selection: $answers.customIntervalDays) {
                        ForEach(1...21, id: \.self) { days in
                            Text(days == 1 ? "Every day" : "Every \(days) days").tag(days)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 140)
                    .clipped()
                    .background(AppTheme.ColorToken.cardBackground, in: .rect(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }
}
