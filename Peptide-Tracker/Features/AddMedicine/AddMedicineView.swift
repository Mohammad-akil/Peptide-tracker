import SwiftUI

/// Add Medicine (and Edit) sheet: colour, type, name and strength, supply,
/// and reminder — with a live "you'll run out on…" preview underneath. The
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    appearanceRow
                    typeSection
                    medicineSection
                    supplySection
                    reminderSection
                    RunOutPreview(draft: draft, showsErrors: showsErrors || draft.stock > 0)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 24)
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

    private var appearanceRow: some View {
        HStack(spacing: 16) {
            MedicineIconView(type: draft.type, color: draft.color, size: 60)
                .animation(.snappy, value: draft.color)
            VStack(alignment: .leading, spacing: 8) {
                Text("Colour")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                HStack {
                    ForEach(MedicineColor.allCases) { color in
                        let isSelected = draft.color == color
                        Button {
                            HapticFeedback.selection()
                            draft.color = color
                        } label: {
                            Circle()
                                .fill(color.color)
                                .frame(width: 30, height: 30)
                                .padding(isSelected ? 3 : 0)
                                .overlay {
                                    if isSelected { Circle().strokeBorder(color.color, lineWidth: 2) }
                                }
                                .frame(width: 38, height: 38)
                                .contentShape(.circle)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Colour \(color.rawValue)")
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                        if color != MedicineColor.allCases.last { Spacer(minLength: 0) }
                    }
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "Type")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(MedicineType.allCases) { type in
                    let isSelected = draft.type == type
                    Button {
                        HapticFeedback.selection()
                        withAnimation(.snappy) { draft.type = type }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: type.symbol)
                                .font(.system(size: 20, weight: .semibold))
                                .frame(height: 24)
                            Text(type.title).font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(isSelected ? AppTheme.ColorToken.accent : AppTheme.ColorToken.primaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 64)
                        .background(AppTheme.ColorToken.cardBackground, in: .rect(cornerRadius: AppTheme.Radius.field, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: AppTheme.Radius.field, style: .continuous)
                                .strokeBorder(isSelected ? AppTheme.ColorToken.accent : .clear, lineWidth: 2)
                        }
                        .shadow(color: isSelected ? AppTheme.ColorToken.accent.opacity(0.12) : .clear, radius: 4, y: 2)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            if draft.type == .other {
                FormRow(title: "Type name", showsDivider: false) {
                    TextField("e.g. Patch", text: $draft.customTypeName)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .typeName)
                }
                .font(.system(size: 16))
                .card(horizontal: 16, vertical: 0)
            }
        }
    }

    private var medicineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "Medicine")
            VStack(spacing: 0) {
                FormRow(title: "Name") {
                    TextField("Required", text: $draft.name)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .brand }
                }
                FormRow(title: "Brand") {
                    TextField("Optional", text: $draft.brandName)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: .brand)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .strength }
                }
                FormRow(title: "Strength") {
                    TextField("Optional", text: $draft.strength)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .strength)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .reason }
                }
                FormRow(title: "Taking it for") {
                    TextField("Optional", text: $draft.reason)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .reason)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .instructions }
                }
                FormRow(title: "Instructions", showsDivider: false) {
                    TextField("e.g. With food", text: $draft.instructions)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .instructions)
                        .submitLabel(.done)
                }
            }
            .font(.system(size: 16))
            .card(horizontal: 16, vertical: 0)
            if showsErrors, let error = draft.nameError {
                ErrorText(error)
            }
        }
    }

    private var supplySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "Supply")
            VStack(spacing: 0) {
                FormRow(title: draft.type.stockLabel) {
                    CountStepper(value: $draft.stock, range: 0...9999, accessibilityName: draft.type.stockLabel.lowercased(), isTypeable: true)
                }
                FormRow(title: draft.type.perDayLabel, showsDivider: false) {
                    CountStepper(value: $draft.perDay, range: 0...50, accessibilityName: draft.type.perDayLabel.lowercased())
                }
            }
            .card(horizontal: 16, vertical: 0)
            if (showsErrors || draft.stock > 0), let error = draft.perDayError {
                ErrorText(error)
            } else if let hint = draft.type.supplyHint {
                Text(hint)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    .padding(.horizontal, 6)
            }
        }
    }

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "Reminder")
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
            .card(horizontal: 16, vertical: 0)
        }
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
