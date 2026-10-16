import SwiftUI

/// The Edit Medicine sheet, every field on one page in Settings-style
/// sections: the icon and its colour, type, the medicine's details, supply
/// and the refill reminder, with a live "you'll run out on…" preview. The
/// type sets the unit in every label, hint and the preview.
struct AddMedicineView: View {
    @Environment(MedicineStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: MedicineDraft
    @State private var showsErrors = false
    @FocusState private var focusedField: Field?

    private enum Field { case name, brand, strength, typeName, reason, instructions }

    /// Called after saving; `true` when this was the first medicine added.
    let onSaved: (Bool) -> Void

    init(editing medicine: Medicine?, name: String = "", onSaved: @escaping (Bool) -> Void) {
        var draft = medicine.map(MedicineDraft.init(editing:)) ?? MedicineDraft(settings: AppSettings())
        if medicine == nil { draft.name = name }
        _draft = State(initialValue: draft)
        self.onSaved = onSaved
    }

    @State private var showsColours = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    typeSection
                    medicineSection
                    supplySection
                    reminderSection
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(title: "Your reminder")
                        if draft.remindersOn {
                            RunOutPreview(draft: draft, showsErrors: showsErrors || draft.stock > 0)
                        } else {
                            OnboardingNote(icon: .bell, text: Text("Refill reminders are off for this medicine."))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .animation(.snappy, value: draft.type)
                .animation(.snappy, value: draft.remindersOn)
                .animation(.snappy, value: showsColours)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppTheme.ColorToken.background)
            .navigationTitle(draft.isEditing ? "Edit Medicine" : "Add Medicine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm, action: save)
                        .tint(AppTheme.ColorToken.accent)
                        .accessibilityLabel("Save")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil; hideKeyboard() }
                }
            }
        }
        .task {
            // New medicines start from the user's reminder defaults.
            if !draft.isEditing {
                draft.reminderDaysBefore = store.settings.defaultDaysBefore
                draft.reminderTime = store.settings.defaultReminderTime
                focusedField = .name
            }
        }
        .interactiveDismissDisabled(!draft.trimmedName.isEmpty && !draft.isEditing)
    }

    // MARK: Sections

    /// The medicine's icon as it'll look, with Icon colour opening the
    /// colour choices in place.
    private var header: some View {
        GroupedSection {
            HStack(spacing: 14) {
                MedicineIconView(type: draft.type, color: draft.color, size: 52, isVibrant: true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(draft.trimmedName.isEmpty ? "New medicine" : draft.trimmedName)
                        .font(.system(size: 19, weight: .semibold))
                        .lineLimit(1)
                    Text(draft.build().typeTitle)
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.ColorToken.secondaryText)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .rowDivider(true, inset: 16)

            SettingsRow(symbol: "paintpalette.fill", tint: Color(hex: 0xBF5AF2), title: "Icon colour", showsDivider: showsColours) {
                HapticFeedback.selection()
                showsColours.toggle()
            } trailing: {
                MedicineIconView(type: draft.type, color: draft.color, size: 28, isVibrant: true)
                DisclosureMark(isOpen: showsColours)
            }
            if showsColours {
                ColourChoices(type: draft.type, color: $draft.color)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .transition(.opacity)
            }
        }
    }

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Type")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(MedicineType.allCases) { type in
                    TypeTile(type: type, isSelected: draft.type == type) {
                        HapticFeedback.selection()
                        draft.type = type
                        if type == .other { focusedField = .typeName }
                    }
                }
            }
            if draft.type == .other {
                GroupedSection {
                    ControlRow(symbol: "cross.case.fill", tint: Color(hex: 0x8E8E93), title: "Type name", showsDivider: false) {
                        field("e.g. Patch", text: $draft.customTypeName, focus: .typeName)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var medicineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            GroupedSection(title: "Medicine") {
                ControlRow(symbol: "pills.fill", tint: Color(hex: 0x0A84FF), title: "Name") {
                    field("Required", text: $draft.name, focus: .name, next: .brand)
                        .textInputAutocapitalization(.words)
                }
                ControlRow(symbol: "tag.fill", tint: Color(hex: 0x5E5CE6), title: "Brand") {
                    field("Optional", text: $draft.brandName, focus: .brand, next: .strength)
                        .textInputAutocapitalization(.words)
                }
                ControlRow(symbol: "scalemass.fill", tint: Color(hex: 0x30B0C7), title: "Strength") {
                    field("Optional", text: $draft.strength, focus: .strength, next: .reason)
                }
                ControlRow(symbol: "heart.fill", tint: Color(hex: 0xFF375F), title: "Taking it for") {
                    field("Optional", text: $draft.reason, focus: .reason, next: .instructions)
                }
                ControlRow(symbol: "list.clipboard.fill", tint: Color(hex: 0xFF9F0A), title: "Instructions", showsDivider: false) {
                    field("e.g. With food", text: $draft.instructions, focus: .instructions)
                }
            }
            if showsErrors, let error = draft.nameError {
                ErrorText(error)
            }
        }
    }

    private var supplySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            GroupedSection(title: "Supply", footer: draft.type.supplyHint) {
                ControlRow(symbol: "shippingbox.fill", tint: Color(hex: 0x30D158), title: draft.type.stockLabel) {
                    CountStepper(value: $draft.stock, range: 0...9999, accessibilityName: draft.type.stockLabel.lowercased(), isTypeable: true)
                }
                ControlRow(symbol: "clock.arrow.circlepath", tint: Color(hex: 0xBF5AF2), title: draft.type.perDayLabel, showsDivider: false) {
                    CountStepper(value: $draft.perDay, range: 0...50, accessibilityName: draft.type.perDayLabel.lowercased())
                }
            }
            if (showsErrors || draft.stock > 0), let error = draft.perDayError {
                ErrorText(error)
            }
        }
    }

    /// The same rows as the add flow's Refill reminders.
    private var reminderSection: some View {
        GroupedSection(title: "Reminder") {
            ControlRow(symbol: "bell.fill", tint: Color(hex: 0xFF453A), title: "Refill reminders", showsDivider: draft.remindersOn) {
                Toggle("Refill reminders", isOn: $draft.remindersOn)
                    .labelsHidden()
                    .tint(AppTheme.ColorToken.accent)
            }
            if draft.remindersOn {
                ControlRow(symbol: "calendar", tint: Color(hex: 0x0A84FF), title: "Days before") {
                    CountStepper(value: $draft.reminderDaysBefore, range: 0...30, accessibilityName: "days before")
                }
                ControlRow(symbol: "clock.fill", tint: Color(hex: 0x30B0C7), title: "Time", showsDivider: false) {
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
        }
    }

    /// A right-aligned text field for a row, moving on to `next` on return.
    private func field(_ placeholder: String, text: Binding<String>, focus: Field, next: Field? = nil) -> some View {
        TextField(placeholder, text: text)
            .font(.system(size: 17))
            .multilineTextAlignment(.trailing)
            .foregroundStyle(AppTheme.ColorToken.secondaryText)
            .focused($focusedField, equals: focus)
            .submitLabel(next == nil ? .done : .next)
            .onSubmit { focusedField = next }
    }

    // MARK: Save

    private func save() {
        guard draft.isValid else {
            HapticFeedback.notification(.error)
            withAnimation(.snappy) { showsErrors = true }
            return
        }
        let medicine = draft.build()
        let isFirst = store.medicines.isEmpty
        if draft.isEditing {
            store.update(medicine)
        } else {
            store.add(medicine)
        }
        HapticFeedback.notification(.success)
        onSaved(isFirst && !draft.isEditing)
        dismiss()
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

private struct ErrorText: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Label { Text(text) } icon: { Icon(.alert, size: 15) }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Urgency.critical.ink)
            .padding(.horizontal, 6)
            .transition(.opacity)
    }
}

#Preview {
    AddMedicineView(editing: nil) { _ in }
        .environment(MedicineStore.preview(sample: false))
}
