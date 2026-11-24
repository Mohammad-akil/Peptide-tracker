import SwiftUI

/// The people and places in your care — doctors, carers, clinics — each
/// with one-tap call, message and email. Tap one to edit it; + adds one.
struct HealthContactsSettingsView: View {
    @Environment(MedicineStore.self) private var store
    @Environment(\.openURL) private var openURL
    /// The contact open in the editor; a fresh one when adding.
    @State private var editing: HealthContact?

    var body: some View {
        SettingsPageScaffold(page: .contacts) {
            if store.contacts.isEmpty {
                emptyState
            } else {
                GroupedSection(footer: String(localized: "Your pharmacy has its own page in Settings, so medicine pages can call it.")) {
                    ForEach(Array(store.contacts.enumerated()), id: \.element.id) { index, contact in
                        row(contact, showsDivider: index < store.contacts.count - 1)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { editing = HealthContact() } label: {
                    Image(systemName: "plus")
                }
                .tint(AppTheme.ColorToken.primaryText)
                .accessibilityLabel("Add contact")
            }
        }
        .sheet(item: $editing) { contact in
            HealthContactEditor(contact: contact, isNew: !store.contacts.contains { $0.id == contact.id })
        }
        .animation(.snappy, value: store.contacts)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(AppTheme.ColorToken.accent)
            Text("No contacts yet")
                .font(.system(size: 17, weight: .semibold))
            Text("Add your doctor, specialist or carer to reach them in one tap.")
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
                .multilineTextAlignment(.center)
            Button("Add a contact") { editing = HealthContact() }
                .buttonStyle(.primary(height: 48, fullWidth: false))
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .groupedCard()
    }

    /// Role tile, name and role · phone, then quick call / message / email.
    private func row(_ contact: HealthContact, showsDivider: Bool) -> some View {
        HStack(spacing: 12) {
            Button { editing = contact } label: {
                HStack(spacing: 14) {
                    SettingsTile(symbol: contact.role.symbol, tint: contact.role.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(contact.name)
                            .font(.system(size: 17))
                            .foregroundStyle(AppTheme.ColorToken.primaryText)
                            .lineLimit(1)
                        Text([contact.role.title, contact.phone].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.ColorToken.secondaryText)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                if !contact.dialablePhone.isEmpty {
                    quickAction("message.fill", tint: Color(hex: 0x30D158), label: String(localized: "Message \(contact.name)"), url: "sms:\(contact.dialablePhone)")
                    quickAction("phone.fill", tint: Color(hex: 0x0A84FF), label: String(localized: "Call \(contact.name)"), url: "tel:\(contact.dialablePhone)")
                }
                if !contact.trimmedEmail.isEmpty {
                    quickAction("envelope.fill", tint: Color(hex: 0xFF9F0A), label: String(localized: "Email \(contact.name)"), url: "mailto:\(contact.trimmedEmail)")
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 60)
        .rowDivider(showsDivider, inset: 58)
        .contextMenu {
            Button("Edit", systemImage: "pencil") { editing = contact }
            Button("Delete", systemImage: "trash", role: .destructive) { store.deleteContact(id: contact.id) }
        }
    }

    /// A round quick action in its own colour, like Phone, Messages and
    /// Mail: a soft wash of the colour with the glyph in full colour.
    private func quickAction(_ symbol: String, tint: Color, label: String, url: String) -> some View {
        Button {
            if let url = URL(string: url) { openURL(url) }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.15), in: .circle)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(label)
    }
}

/// Adding or editing one contact.
private struct HealthContactEditor: View {
    @Environment(MedicineStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var contact: HealthContact
    let isNew: Bool
    @State private var confirmsDelete = false

    private var canSave: Bool { !contact.name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    GroupedSection {
                        FieldRow(title: String(localized: "Name"), placeholder: String(localized: "Dr Patel"), text: $contact.name)
                            .textInputAutocapitalization(.words)
                            .textContentType(.name)
                        FieldRow(title: String(localized: "Phone"), placeholder: String(localized: "Add"), text: $contact.phone)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                        FieldRow(title: String(localized: "Email"), placeholder: String(localized: "Add"), text: $contact.email, showsDivider: false)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                    }

                    GroupedSection(title: String(localized: "Role")) {
                        FlowLayout(spacing: 8) {
                            ForEach(HealthContact.Role.allCases) { role in
                                roleChip(role)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    GroupedSection(title: String(localized: "Notes")) {
                        TextField("e.g. Practice on Elm Road, sees me every 3 months", text: $contact.notes, axis: .vertical)
                            .font(.system(size: 17))
                            .lineLimit(2...5)
                            .padding(16)
                    }

                    if !isNew {
                        Button("Delete contact", role: .destructive) { confirmsDelete = true }
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(AppTheme.ColorToken.destructive)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .groupedCard()
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.medium)
                .padding(.top, 8)
                .padding(.bottom, AppTheme.Spacing.large)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppTheme.ColorToken.background.ignoresSafeArea())
            .navigationTitle(isNew ? "New contact" : "Edit contact")
            .navigationBarTitleDisplayMode(.inline)
            .compatNavigationBarBlur()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(AppTheme.ColorToken.primaryText)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        contact.name = contact.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        store.save(contact)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .confirmationDialog("Delete \(contact.name)?", isPresented: $confirmsDelete, titleVisibility: .visible) {
                Button("Delete contact", role: .destructive) {
                    store.deleteContact(id: contact.id)
                    dismiss()
                }
            }
        }
        .interactiveDismissDisabled(isNew && canSave)
    }

    private func roleChip(_ role: HealthContact.Role) -> some View {
        let isSelected = contact.role == role
        return Button {
            HapticFeedback.selection()
            withAnimation(.snappy) { contact.role = role }
        } label: {
            Label(role.title, systemImage: role.symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? .white : AppTheme.ColorToken.primaryText)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(isSelected ? AppTheme.ColorToken.accent : AppTheme.ColorToken.controlFill, in: .capsule)
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    NavigationStack { HealthContactsSettingsView() }
        .environment(MedicineStore.preview())
}
