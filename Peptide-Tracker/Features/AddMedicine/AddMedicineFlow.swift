import SwiftUI

/// Adding a medicine as a short guided sheet, one question per screen:
/// name → brand → type → what it's for → how often → how many you have →
/// the finishing touches (instructions, refill reminders, icon colour) with
/// a preview of when you'll be reminded. Editing keeps the one-page
/// `AddMedicineView`, where every field is reachable at once.
struct AddMedicineFlow: View {
    @Environment(MedicineStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    /// Called after saving; `true` when this was the first medicine added.
    let onSaved: (Bool) -> Void

    @State private var step = Step.name
    @State private var draft: MedicineDraft
    /// Units taken each time; `draft.perDay` is this times doses a day.
    @State private var perDose = 1
    /// Which way the last move went, so screens slide in from that side.
    @State private var isMovingForward = true
    @State private var expandedOption: FinishOption?
    @FocusState private var isTyping: Bool

    enum Step: Int, CaseIterable {
        case name, brand, type, reason, schedule, supply, finish

        /// Steps that can be left blank show Skip.
        var isOptional: Bool { [.brand, .reason].contains(self) }
    }

    enum FinishOption { case instructions, icon }

    init(name: String = "", onSaved: @escaping (Bool) -> Void) {
        var draft = MedicineDraft(settings: AppSettings())
        draft.name = name
        draft.dosesPerDay = 1
        draft.perDay = 1
        _draft = State(initialValue: draft)
        self.onSaved = onSaved
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.top, 14)

            ScrollView {
                content
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                    .id(step)
                    .transition(.asymmetric(
                        insertion: .move(edge: isMovingForward ? .trailing : .leading).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        .background(AppTheme.ColorToken.background.ignoresSafeArea())
        .animation(.snappy(duration: 0.35), value: step)
        .task {
            // New medicines start from the user's reminder defaults.
            draft.reminderDaysBefore = store.settings.defaultDaysBefore
            draft.reminderTime = store.settings.defaultReminderTime
            if draft.trimmedName.isEmpty { isTyping = true }
        }
        .onChange(of: perDose) { _, _ in updatePerDay() }
        .onChange(of: draft.dosesPerDay) { _, _ in updatePerDay() }
        .interactiveDismissDisabled(!draft.trimmedName.isEmpty)
    }

    // MARK: Frame

    private var topBar: some View {
        HStack(spacing: 10) {
            // Back from step 2 on; closing lives on the right.
            Button(action: back) {
                Icon(.chev, size: 22)
                    .foregroundStyle(AppTheme.ColorToken.primaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel("Back")
            .opacity(step == .name ? 0 : 1)
            .disabled(step == .name)

            HStack(spacing: 5) {
                ForEach(Step.allCases, id: \.self) { item in
                    Capsule()
                        .fill(item <= step ? AppTheme.ColorToken.accent : Color(hex: 0x767680, opacity: 0.18))
                        .frame(height: 5)
                }
            }
            .padding(.horizontal, 4)
            .animation(.snappy, value: step)
            .accessibilityElement()
            .accessibilityLabel("Step \(step.rawValue + 1) of \(Step.allCases.count)")

            if step.isOptional {
                Button("Skip", action: skip)
                    .font(.system(size: 17))
                    .foregroundStyle(AppTheme.ColorToken.accent)
                    .frame(height: 44)
                    .transition(.opacity)
            }

            // The system close button: glass circle, xmark, "Close" for VoiceOver.
            Button(role: .close) { dismiss() } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.large)
        }
        .padding(.horizontal, 16)
        .animation(.snappy, value: step.isOptional)
    }

    private var bottomBar: some View {
        Button(step == .finish ? "Save medicine" : "Continue", action: step == .finish ? save : advance)
            .buttonStyle(.glassPrimary)
            .disabled(!canContinue)
            .opacity(canContinue ? 1 : 0.5)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 8)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .name: nameStep
        case .brand: brandStep
        case .type: typeStep
        case .reason: reasonStep
        case .schedule: scheduleStep
        case .supply: supplyStep
        case .finish: finishStep
        }
    }

    // MARK: 1 Name

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            OnboardingHeader(
                title: "What medicine would you like to add?",
                reason: "Use the name on the box or your prescription."
            )
            InputCard {
                TextField("e.g. Metformin", text: $draft.name)
                    .font(.system(size: 20, weight: .semibold))
                    .textInputAutocapitalization(.words)
                    .focused($isTyping)
                    .submitLabel(.next)
                    .onSubmit { if canContinue { advance() } }
            }
        }
    }

    // MARK: 2 Brand

    private var brandStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            OnboardingHeader(
                title: "What’s the brand name?",
                reason: "Optional. Handy when the box says something different from the medicine’s name."
            )
            VStack(alignment: .leading, spacing: 18) {
                labelled("Brand name") {
                    InputCard {
                        TextField("e.g. Glucophage", text: $draft.brandName)
                            .font(.system(size: 18, weight: .medium))
                            .textInputAutocapitalization(.words)
                            .focused($isTyping)
                            .submitLabel(.next)
                    }
                }
                labelled("Strength") {
                    InputCard {
                        TextField("e.g. 500 mg", text: $draft.strength)
                            .font(.system(size: 18, weight: .medium))
                            .submitLabel(.next)
                            .onSubmit(advance)
                    }
                }
            }
        }
    }

    /// A small grey label over an input, lined up with the text inside it.
    private func labelled<Field: View>(_ title: String, @ViewBuilder field: () -> Field) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
                .padding(.horizontal, 22)
            field()
        }
    }

    // MARK: 3 Type

    private var typeStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            OnboardingHeader(
                title: "What type of medicine is it?",
                reason: "This sets how we count it: pills, puffs, millilitres and so on."
            )
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(MedicineType.allCases) { type in
                    typeTile(type)
                }
            }
            if draft.type == .other {
                OnboardingField(label: "What type is it?", placeholder: "e.g. Patch, spray, gel", text: $draft.customTypeName)
                    .focused($isTyping)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.snappy, value: draft.type)
    }

    private func typeTile(_ type: MedicineType) -> some View {
        TypeTile(type: type, isSelected: draft.type == type) {
            HapticFeedback.selection()
            draft.type = type
            if type == .other { isTyping = true }
        }
    }

    // MARK: 4 Reason

    private let commonReasons = [
        "Blood pressure", "Diabetes", "Cholesterol", "Heart", "Thyroid",
        "Pain", "Allergies", "Sleep", "Vitamins", "Mental health",
    ]

    private var reasonStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            OnboardingHeader(
                title: "What are you taking it for?",
                reason: "Optional. It helps tell your medicines apart."
            )
            InputCard {
                TextField("e.g. Blood pressure", text: $draft.reason)
                    .font(.system(size: 18, weight: .medium))
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.next)
                    .onSubmit(advance)
            }
            SuggestionChips(options: commonReasons, selection: $draft.reason)
        }
    }

    // MARK: 5 How often

    private var scheduleStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingHeader(
                title: "How often do you take it?",
                reason: "Pick the times a day. You can change the exact times later."
            )
            // Apple's pick-one list: rows with a checkmark on the chosen one.
            GroupedSection(title: "How often") {
                ForEach(1...4, id: \.self) { count in
                    frequency(count, showsDivider: count < 4)
                }
            }
            GroupedSection(title: "Each time", footer: "That’s \(draft.type.unit.format(draft.perDay)) a day.") {
                FormRow(title: draft.type.unit.plural.capitalizedFirst, showsDivider: false) {
                    CountStepper(value: $perDose, range: 1...20, accessibilityName: "\(draft.type.unit.plural) each time")
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func frequency(_ count: Int, showsDivider: Bool) -> some View {
        let isSelected = draft.dosesPerDay == count
        let title = count == 1 ? "Once a day" : count == 2 ? "Twice a day" : "\(count) times a day"
        return Button {
            HapticFeedback.selection()
            withAnimation(.snappy) { draft.dosesPerDay = count }
        } label: {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 17))
                    .foregroundStyle(AppTheme.ColorToken.primaryText)
                Spacer(minLength: 8)
                Text(TimeOfDay.schedule(count: count).map(\.label).joined(separator: " · "))
                    .font(.system(size: 15))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.ColorToken.accent)
                    .frame(width: 20)
                    .opacity(isSelected ? 1 : 0)
                    .scaleEffect(isSelected ? 1 : 0.5)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .contentShape(.rect)
            .rowDivider(showsDivider)
        }
        .buttonStyle(RowPressStyle())
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: 6 How many

    private var supplyStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            OnboardingHeader(
                title: "How many do you have right now?",
                reason: "We count down from here and warn you before you run out."
            )
            VStack(alignment: .leading, spacing: 8) {
                FormRow(title: draft.type.stockLabel, showsDivider: false) {
                    CountStepper(value: $draft.stock, range: 0...9999, accessibilityName: draft.type.stockLabel.lowercased(), isTypeable: true)
                }
                .card(horizontal: 16, vertical: 0)
                if let hint = draft.type.supplyHint {
                    Text(hint)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.ColorToken.secondaryText)
                        .padding(.horizontal, 6)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(title: "Common pack sizes")
                HStack(spacing: 8) {
                    ForEach(draft.type.commonPackSizes, id: \.self) { size in
                        Button {
                            HapticFeedback.selection()
                            withAnimation(.snappy) { draft.stock = size }
                        } label: {
                            Text(draft.type.unit.format(size))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(draft.stock == size ? .white : AppTheme.ColorToken.primaryText)
                                .padding(.horizontal, 14)
                                .frame(height: 40)
                                .background(
                                    draft.stock == size ? AppTheme.ColorToken.accent : AppTheme.ColorToken.cardBackground,
                                    in: .capsule
                                )
                        }
                        .buttonStyle(.pressable)
                    }
                }
            }
        }
    }

    // MARK: 7 Finish

    private var finishStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingHeader(title: "Almost done", reason: "Add anything else you’d like, then save.")

            GroupedSection { summary }

            // Settings-style list: a coloured tile per row, controls opening
            // inside the list.
            GroupedSection(title: "Details") {
                instructionsRows
                remindersRows
                iconRows
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(title: "Your reminder")
                if draft.remindersOn {
                    RunOutPreview(draft: draft, showsErrors: false)
                } else {
                    OnboardingNote(icon: .bell, text: Text("Refill reminders are off for this medicine. Turn them on above or later from its page."))
                }
            }
        }
        .animation(.snappy, value: expandedOption)
        .animation(.snappy, value: draft.remindersOn)
    }

    private var summary: some View {
        HStack(spacing: 14) {
            MedicineIconView(type: draft.type, color: draft.color, size: 44, isVibrant: true)
            VStack(alignment: .leading, spacing: 2) {
                Text(draft.trimmedName)
                    .font(.system(size: 17, weight: .semibold))
                Text(summaryDetail)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    /// "Glucophage · 500 mg · Pill · 2 pills a day · Blood pressure"
    private var summaryDetail: String {
        let medicine = draft.build()
        return [
            draft.brandName, draft.strength, medicine.typeTitle,
            "\(medicine.unit.format(draft.perDay)) a day", draft.reason,
        ]
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
        .joined(separator: " · ")
    }

    @ViewBuilder
    private var instructionsRows: some View {
        let isOpen = expandedOption == .instructions
        SettingsRow(symbol: "list.clipboard.fill", tint: Color(hex: 0xFF9F0A), title: "Instructions", showsDivider: true) {
            toggle(.instructions)
        } trailing: {
            Text(draft.instructions.isEmpty ? "None" : draft.instructions)
                .font(.system(size: 17))
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
                .lineLimit(1)
            DisclosureMark(isOpen: isOpen)
        }
        if isOpen {
            VStack(alignment: .leading, spacing: 12) {
                TextField("e.g. Take with food", text: $draft.instructions, axis: .vertical)
                    .font(.system(size: 17))
                    .lineLimit(1...4)
                SuggestionChips(
                    options: ["With food", "Before bed", "On an empty stomach", "With a full glass of water"],
                    selection: $draft.instructions
                )
            }
            .padding(.leading, 58)
            .padding(.trailing, 16)
            .padding(.vertical, 12)
            .rowDivider(true, inset: 58)
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var remindersRows: some View {
        SettingsRow(symbol: "bell.fill", tint: Color(hex: 0xFF453A), title: "Refill reminders", showsDivider: true) {
            withAnimation(.snappy) { draft.remindersOn.toggle() }
        } trailing: {
            Toggle("Refill reminders", isOn: $draft.remindersOn)
                .labelsHidden()
                .tint(AppTheme.ColorToken.accent)
        }
        if draft.remindersOn {
            Group {
                ControlRow(symbol: "calendar", tint: Color(hex: 0x0A84FF), title: "Days before") {
                    CountStepper(value: $draft.reminderDaysBefore, range: 0...30, accessibilityName: "days before")
                }
                ControlRow(symbol: "clock.fill", tint: Color(hex: 0x30B0C7), title: "Time") {
                    DatePicker(
                        "Time",
                        selection: Binding(
                            get: { draft.reminderTime.on(.now) },
                            set: { draft.reminderTime = TimeOfDay(date: $0) }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "en_GB"))
                }
            }
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var iconRows: some View {
        let isOpen = expandedOption == .icon
        SettingsRow(symbol: "paintpalette.fill", tint: Color(hex: 0xBF5AF2), title: "Icon colour", showsDivider: isOpen) {
            toggle(.icon)
        } trailing: {
            MedicineIconView(type: draft.type, color: draft.color, size: 28, isVibrant: true)
            DisclosureMark(isOpen: isOpen)
        }
        if isOpen {
            ColourChoices(type: draft.type, color: $draft.color)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .transition(.opacity)
        }
    }

    private func toggle(_ option: FinishOption) {
        HapticFeedback.selection()
        expandedOption = expandedOption == option ? nil : option
    }

    // MARK: Navigation

    private var canContinue: Bool {
        switch step {
        case .name: !draft.trimmedName.isEmpty
        default: true
        }
    }

    private func advance() {
        guard canContinue, let next = Step(rawValue: step.rawValue + 1) else { return }
        HapticFeedback.selection()
        isMovingForward = true
        isTyping = false
        step = next
        if next == .brand { isTyping = true }
    }

    private func back() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        isMovingForward = false
        isTyping = false
        step = previous
    }

    /// Leaves the optional answer blank and moves on.
    private func skip() {
        switch step {
        case .brand: draft.brandName = ""; draft.strength = ""
        case .reason: draft.reason = ""
        default: break
        }
        advance()
    }

    private func updatePerDay() {
        draft.perDay = max(draft.dosesPerDay ?? 1, 1) * perDose
    }

    private func save() {
        let isFirst = store.medicines.isEmpty
        let medicine = draft.build()
        store.add(medicine)
        router.show(.success("\(medicine.name) added", message: savedMessage(for: medicine)))
        router.celebrate()
        onSaved(isFirst)
        dismiss()
    }

    /// "We’ll remind you on 9 Oct at 9:00."
    private func savedMessage(for medicine: Medicine) -> String? {
        guard draft.remindersOn, medicine.stock > 0 else { return nil }
        let reminder = medicine.reminderDate()
        guard reminder > .now else { return "It’s already time to refill." }
        return "We’ll remind you on \(reminder.dayMonth) at \(medicine.reminderTime.label)."
    }
}

// MARK: - Pieces

/// One big single-line input: a full capsule in Liquid Glass.
private struct InputCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .contentShape(.rect)
            .glassEffect(.regular.interactive(), in: .capsule)
    }
}

extension AddMedicineFlow.Step: Comparable {
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

#Preview {
    AddMedicineFlow { _ in }
        .environment(MedicineStore.preview(sample: false))
}
