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

    private enum Field { case name, strength }

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
                            Icon(type.icon, size: 22)
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
                        .onSubmit { focusedField = .strength }
                }
                FormRow(title: "Strength", showsDivider: false) {
                    TextField("Optional", text: $draft.strength)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .strength)
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

/// "You'll run out on 14 Oct. We'll remind you on 9 Oct at 9:00." with a
/// little Today → Reminder → Out track.
private struct RunOutPreview: View {
    let draft: MedicineDraft
    let showsErrors: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            message
                .font(.system(size: 15))
                .lineSpacing(2)
            if let medicine = draft.previewMedicine(), medicine.stock > 0 {
                track(for: medicine)
            }
        }
        .foregroundStyle(AppTheme.ColorToken.accentInk)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.ColorToken.accentSoft, in: .rect(cornerRadius: 20, style: .continuous))
        .animation(.snappy, value: draft.stock)
        .animation(.snappy, value: draft.perDay)
        .accessibilityElement(children: .combine)
    }

    private var message: Text {
        guard let medicine = draft.previewMedicine() else {
            return Text(showsErrors && draft.perDayError != nil
                        ? "Fix the daily amount to see your run-out date."
                        : "Add how much you have and your daily amount to see when you’ll run out.")
        }
        guard medicine.stock > 0 else {
            return Text("Add how many \(medicine.unit.plural) you have to see when you’ll run out.")
        }
        let runOut = medicine.runOutDate()
        let reminder = medicine.reminderDate()
        if reminder <= .now {
            return Text("You’ll run out on ") + Text(runOut.dayMonth).bold()
                + Text(". That’s inside your heads-up window, so it’s time to refill.")
        }
        return Text("You’ll run out on ") + Text(runOut.dayMonth).bold()
            + Text(". We’ll remind you on ") + Text("\(reminder.dayMonth) at \(medicine.reminderTime.label)").bold() + Text(".")
    }

    private func track(for medicine: Medicine) -> some View {
        let total = max(medicine.daysLeft, 1)
        let reminderOffset = Calendar.current.days(from: .now, to: medicine.reminderDate())
        let fraction = min(max(Double(reminderOffset) / Double(total), 0), 1)

        return GeometryReader { proxy in
            let width = proxy.size.width - 12
            ZStack(alignment: .topLeading) {
                Capsule().fill(AppTheme.ColorToken.accent.opacity(0.25)).frame(height: 4).offset(x: 6, y: 6).frame(width: width)
                Capsule().fill(AppTheme.ColorToken.accent).frame(width: width * fraction, height: 4).offset(x: 6, y: 6)
                Circle().fill(AppTheme.ColorToken.accent).frame(width: 12, height: 12).offset(y: 2)
                Circle()
                    .fill(.white)
                    .overlay(Circle().strokeBorder(AppTheme.ColorToken.accent, lineWidth: 3))
                    .frame(width: 16, height: 16)
                    .offset(x: 6 + width * fraction - 8)
                Circle().fill(AppTheme.ColorToken.destructive).frame(width: 12, height: 12).offset(x: width, y: 2)

                Text("Today").offset(y: 20)
                Text("Reminder \(medicine.reminderDate().dayMonth)")
                    .fixedSize()
                    .frame(width: 0)
                    .offset(x: 6 + width * fraction, y: 20)
                    .opacity(fraction > 0.18 && fraction < 0.82 ? 1 : 0)
                Text("Out \(medicine.runOutDate().dayMonth)")
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .offset(y: 20)
            }
            .font(.system(size: 12, weight: .semibold))
        }
        .frame(height: 36)
    }
}

#Preview {
    AddMedicineView(editing: nil) { _ in }
        .environment(MedicineStore.preview(sample: false))
}
