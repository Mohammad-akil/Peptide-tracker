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

    enum FinishOption { case instructions, reminders, icon }

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
        HStack(spacing: 0) {
            Button(action: leadingAction) {
                Icon(step == .name ? .x : .chev, size: step == .name ? 18 : 22)
                    .foregroundStyle(AppTheme.ColorToken.primaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel(step == .name ? "Cancel" : "Back")

            HStack(spacing: 5) {
                ForEach(Step.allCases, id: \.self) { item in
                    Capsule()
                        .fill(item <= step ? AppTheme.ColorToken.accent : Color(hex: 0x767680, opacity: 0.18))
                        .frame(height: 5)
                }
            }
            .padding(.horizontal, 14)
            .animation(.snappy, value: step)
            .accessibilityElement()
            .accessibilityLabel("Step \(step.rawValue + 1) of \(Step.allCases.count)")

            if step.isOptional {
                Button("Skip", action: skip)
                    .font(.system(size: 17))
                    .foregroundStyle(AppTheme.ColorToken.accent)
                    .padding(.horizontal, 4)
                    .frame(height: 44)
            } else {
                Color.clear.frame(width: 40, height: 44)
            }
        }
        .padding(.horizontal, 16)
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
            VStack(spacing: 14) {
                OnboardingField(label: "Brand name", placeholder: "e.g. Glucophage", text: $draft.brandName)
                    .textInputAutocapitalization(.words)
                    .focused($isTyping)
                OnboardingField(label: "Strength", placeholder: "e.g. 500 mg", text: $draft.strength)
            }
            .padding(16)
            .background(AppTheme.ColorToken.accentSoft.opacity(0.6), in: .rect(cornerRadius: 20, style: .continuous))
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
        let isSelected = draft.type == type
        return Button {
            HapticFeedback.selection()
            draft.type = type
            if type == .other { isTyping = true }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: type.symbol)
                    .font(.system(size: 24, weight: .semibold))
                    .frame(height: 28)
                Text(type.title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(isSelected ? AppTheme.ColorToken.accent : AppTheme.ColorToken.primaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 88)
            .background(
                isSelected ? AppTheme.ColorToken.accentSoft : AppTheme.ColorToken.cardBackground,
                in: .rect(cornerRadius: 20, style: .continuous)
            )
            .selectionBorder(isSelected, cornerRadius: 20)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(type.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
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
        VStack(alignment: .leading, spacing: 22) {
            OnboardingHeader(
                title: "How often do you take it?",
                reason: "Pick the times a day. You can change the exact times later."
            )
            VStack(spacing: 10) {
                frequency(1, icon: .sun, title: "Once a day")
                frequency(2, icon: .moon, title: "Twice a day")
                frequency(3, icon: .clock, title: "3 times a day")
                frequency(4, icon: .clock, title: "4 times a day")
            }
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(title: "Each time")
                FormRow(title: "\(draft.type.unit.plural.capitalizedFirst) each time", showsDivider: false) {
                    CountStepper(value: $perDose, range: 1...20, accessibilityName: "\(draft.type.unit.plural) each time")
                }
                .card(horizontal: 16, vertical: 0)
                Text("That’s \(draft.type.unit.format(draft.perDay)) a day.")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    .padding(.horizontal, 6)
                    .contentTransition(.numericText())
            }
        }
    }

    private func frequency(_ count: Int, icon: AppIcon, title: String) -> some View {
        OnboardingChoice(
            icon: icon,
            title: title,
            subtitle: TimeOfDay.schedule(count: count).map(\.label).joined(separator: " · "),
            isSelected: draft.dosesPerDay == count,
            action: { draft.dosesPerDay = count }
        )
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
        VStack(alignment: .leading, spacing: 22) {
            OnboardingHeader(title: "Almost done", reason: "Add anything else you’d like, then save.")

            summary

            VStack(spacing: 10) {
                instructionsOption
                remindersOption
                iconOption
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
            MedicineIconView(type: draft.type, color: draft.color, size: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text(draft.trimmedName)
                    .font(.system(size: 19, weight: .bold))
                Text(summaryDetail)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(AppTheme.ColorToken.cardBackground, in: .rect(cornerRadius: 20, style: .continuous))
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

    private var instructionsOption: some View {
        OptionCard(
            icon: .list,
            title: "Add instructions",
            value: draft.instructions.isEmpty ? "Optional" : draft.instructions,
            isExpanded: expandedOption == .instructions,
            onTap: { toggle(.instructions) }
        ) {
            InputCard {
                TextField("e.g. Take with food", text: $draft.instructions, axis: .vertical)
                    .font(.system(size: 16))
                    .lineLimit(1...4)
            }
            SuggestionChips(
                options: ["With food", "Before bed", "On an empty stomach", "With a full glass of water"],
                selection: $draft.instructions
            )
        }
    }

    private var remindersOption: some View {
        OptionCard(
            icon: .bell,
            title: "Get refill reminders",
            value: draft.remindersOn
                ? "\(draft.reminderDaysBefore) days before you run out, at \(draft.reminderTime.label)"
                : "Off",
            isExpanded: expandedOption == .reminders && draft.remindersOn,
            onTap: { toggle(.reminders) },
            trailing: {
                Toggle("Get refill reminders", isOn: $draft.remindersOn)
                    .labelsHidden()
                    .tint(AppTheme.ColorToken.accent)
            }
        ) {
            VStack(spacing: 0) {
                FormRow(title: "Days before") {
                    CountStepper(value: $draft.reminderDaysBefore, range: 0...30, accessibilityName: "days before")
                }
                FormRow(title: "Time", showsDivider: false) {
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
            .background(AppTheme.ColorToken.cardBackground, in: .rect(cornerRadius: 14, style: .continuous))
        }
    }

    private var iconOption: some View {
        OptionCard(
            icon: .sparkle,
            title: "Change medicine icon",
            value: "Pick a colour",
            isExpanded: expandedOption == .icon,
            onTap: { toggle(.icon) },
            trailing: { MedicineIconView(type: draft.type, color: draft.color, size: 34) }
        ) {
            HStack {
                ForEach(MedicineColor.allCases) { color in
                    let isSelected = draft.color == color
                    Button {
                        HapticFeedback.selection()
                        withAnimation(.snappy) { draft.color = color }
                    } label: {
                        MedicineIconView(type: draft.type, color: color, size: 44)
                            .overlay {
                                RoundedRectangle(cornerRadius: 44 * 0.31, style: .continuous)
                                    .strokeBorder(color.color, lineWidth: isSelected ? 2 : 0)
                            }
                            .scaleEffect(isSelected ? 1.08 : 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Colour \(color.rawValue)")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    if color != MedicineColor.allCases.last { Spacer(minLength: 0) }
                }
            }
        }
    }

    private func toggle(_ option: FinishOption) {
        HapticFeedback.selection()
        if option == .reminders && !draft.remindersOn { draft.remindersOn = true }
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

    /// Cancel on the first step, Back after that.
    private func leadingAction() {
        if step == .name { dismiss() } else { back() }
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

/// A white rounded card holding one big input.
private struct InputCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.ColorToken.cardBackground, in: .rect(cornerRadius: 18, style: .continuous))
    }
}

/// Tappable suggestions that fill a text answer ("Blood pressure").
private struct SuggestionChips: View {
    let options: [String]
    @Binding var selection: String

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(options, id: \.self) { option in
                let isSelected = selection == option
                Button {
                    HapticFeedback.selection()
                    selection = isSelected ? "" : option
                } label: {
                    Text(option)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : AppTheme.ColorToken.primaryText)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .background(isSelected ? AppTheme.ColorToken.accent : AppTheme.ColorToken.cardBackground, in: .capsule)
                }
                .buttonStyle(.pressable)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
    }
}

/// One finishing option: icon, title and its current value, opening to
/// show its controls. `trailing` replaces the chevron (a toggle, a preview).
private struct OptionCard<Trailing: View, Detail: View>: View {
    let icon: AppIcon
    let title: String
    let value: String
    let isExpanded: Bool
    let onTap: () -> Void
    @ViewBuilder var trailing: Trailing
    @ViewBuilder var detail: Detail

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                // Only the icon and words are the button, so a trailing
                // toggle stays its own control.
                Button(action: onTap) {
                    HStack(spacing: 14) {
                        FilledIcon(icon, size: 21)
                            .foregroundStyle(AppTheme.ColorToken.accent)
                            .frame(width: 42, height: 42)
                            .background(AppTheme.ColorToken.accentSoft, in: .rect(cornerRadius: 13, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(AppTheme.ColorToken.primaryText)
                            Text(value)
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.ColorToken.secondaryText)
                                .lineLimit(2)
                        }
                        Spacer(minLength: 0)
                    }
                    .multilineTextAlignment(.leading)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)

                trailing
            }

            if isExpanded {
                detail
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            isExpanded ? AppTheme.ColorToken.accentSoft : AppTheme.ColorToken.cardBackground,
            in: .rect(cornerRadius: 20, style: .continuous)
        )
        .selectionBorder(isExpanded, cornerRadius: 20)
    }
}

extension OptionCard where Trailing == ChevronMark {
    init(icon: AppIcon, title: String, value: String, isExpanded: Bool, onTap: @escaping () -> Void, @ViewBuilder detail: () -> Detail) {
        self.init(icon: icon, title: title, value: value, isExpanded: isExpanded, onTap: onTap, trailing: { ChevronMark(isOpen: isExpanded, onTap: onTap) }, detail: detail)
    }
}

/// The down chevron on an option that opens, turned up while open. It
/// sits outside the option's button, so it handles its own tap.
private struct ChevronMark: View {
    let isOpen: Bool
    let onTap: () -> Void

    var body: some View {
        Image(systemName: "chevron.down")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(AppTheme.ColorToken.tertiaryText)
            .rotationEffect(.degrees(isOpen ? 180 : 0))
            .frame(width: 32, height: 42)
            .contentShape(.rect)
            .onTapGesture(perform: onTap)
            .accessibilityHidden(true)
    }
}

/// Lays chips out in rows, wrapping to the next row when one is full.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(for: subviews, width: proposal.width ?? .infinity)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(for: subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(for subviews: Subviews, width: CGFloat) -> [Row] {
        var rows = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if !rows[rows.count - 1].indices.isEmpty, rows[rows.count - 1].width + spacing + size.width > width {
                rows.append(Row())
            }
            var row = rows[rows.count - 1]
            row.width += (row.indices.isEmpty ? 0 : spacing) + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
            rows[rows.count - 1] = row
        }
        return rows
    }
}

extension AddMedicineFlow.Step: Comparable {
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

#Preview {
    AddMedicineFlow { _ in }
        .environment(MedicineStore.preview(sample: false))
}
