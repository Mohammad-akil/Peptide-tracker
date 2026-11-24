import SwiftUI

/// Health → Side effects: what the user has noticed, the patterns across
/// it ("Nausea is most often logged the day after a dose"), and a quick
/// way to log another. It describes what was logged; it never says what
/// caused it or what to do.
struct SideEffectsSheet: View {
    @Environment(MedicineStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var editing: SideEffectEntry?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Button { editing = newEntry() } label: {
                        Label("Log a side effect", systemImage: "plus")
                    }
                    .buttonStyle(.primary)

                    patterns
                    history

                    Label("Severe, lasting or worrying side effects? Contact your doctor or pharmacist. In an emergency, call your local emergency number.", systemImage: "stethoscope")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.ColorToken.secondaryText)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, AppTheme.Spacing.medium)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
            .background(AppTheme.ColorToken.background.ignoresSafeArea())
            .navigationTitle("Side effects")
            .navigationBarTitleDisplayMode(.inline)
            .compatNavigationBarBlur()
            .toolbar {
                // The toolbar's own close button, like the other sheets; the
                // standalone glass circle doubled up inside the bar's glass.
                ToolbarItem(placement: .cancellationAction) {
                    CompatToolbarRoleButton(role: .close) { dismiss() }
                        .tint(AppTheme.ColorToken.primaryText)
                }
            }
        }
        .sheet(item: $editing) { entry in
            SideEffectEditor(entry: entry, isNew: !store.sideEffects.contains { $0.id == entry.id })
        }
    }

    private func newEntry() -> SideEffectEntry {
        // Linked to the medicine taken most recently, which is most often right.
        let recent = store.doseLogs.filter(\.isTaken).max { $0.takenAt! < $1.takenAt! }?.medicineID
        return SideEffectEntry(date: .now, kind: .nausea, severity: .mild, medicineID: recent)
    }

    // MARK: Patterns

    @ViewBuilder
    private var patterns: some View {
        let patterns = store.sideEffectPatterns()
        if store.sideEffects.count >= 3, !patterns.isEmpty {
            GroupedSection(title: String(localized: "Patterns"), footer: String(localized: "Based on what you logged and the days you took each dose. Worth showing your doctor.")) {
                ForEach(Array(patterns.prefix(5).enumerated()), id: \.element.id) { index, pattern in
                    HStack(alignment: .top, spacing: 12) {
                        SettingsTile(symbol: pattern.kind.symbol, tint: pattern.kind.tint)
                        Text(pattern.sentence)
                            .font(.system(size: 15))
                            .foregroundStyle(AppTheme.ColorToken.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .rowDivider(index < min(patterns.count, 5) - 1, inset: 58)
                }
            }
        } else {
            GroupedSection(title: String(localized: "Patterns")) {
                Text("Log a few side effects and patterns show here — like which day after a dose they tend to come.")
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: History

    @ViewBuilder
    private var history: some View {
        let entries = Array(store.sideEffects.reversed().prefix(60))
        if !entries.isEmpty {
            GroupedSection(title: String(localized: "Logged"), trailing: "\(store.sideEffects.count)") {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    Button { editing = entry } label: {
                        row(entry, showsDivider: index < entries.count - 1)
                    }
                    .buttonStyle(RowPressStyle())
                    .contextMenu {
                        Button(role: .destructive) {
                            withAnimation(.snappy) { store.deleteSideEffect(id: entry.id) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private func row(_ entry: SideEffectEntry, showsDivider: Bool) -> some View {
        let medicine = entry.medicineID.flatMap(store.medicine(id:))
        let detail = [entry.severity.title, medicine?.name, entry.site?.title].compactMap { $0 }.joined(separator: " · ")
        return HStack(spacing: 12) {
            SettingsTile(symbol: entry.kind.symbol, tint: entry.kind.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.kind.title)
                    .font(.system(size: 17))
                    .foregroundStyle(AppTheme.ColorToken.primaryText)
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(entry.date.relativeDay())
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
            Chevron()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(minHeight: 56)
        .contentShape(.rect)
        .rowDivider(showsDivider, inset: 58)
    }
}

// MARK: - Editor

/// Logging or editing one side effect: what, how bad, which medicine,
/// where (for a site reaction), when, and a note.
private struct SideEffectEditor: View {
    @Environment(MedicineStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var entry: SideEffectEntry
    let isNew: Bool

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(SideEffectEntry.Kind.allCases) { kind in
                            kindButton(kind)
                        }
                    }

                    GroupedSection(title: String(localized: "How bad")) {
                        Picker("How bad", selection: $entry.severity) {
                            ForEach(SideEffectEntry.Severity.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .padding(12)
                    }

                    GroupedSection {
                        HStack {
                            Text("Medicine").font(.system(size: 17))
                            Spacer()
                            Picker("Medicine", selection: $entry.medicineID) {
                                Text("None").tag(UUID?.none)
                                ForEach(store.medicines) { Text($0.name).tag(UUID?.some($0.id)) }
                            }
                            .labelsHidden()
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 52)
                        .rowDivider(true)

                        if entry.kind == .siteReaction {
                            HStack {
                                Text("Site").font(.system(size: 17))
                                Spacer()
                                Picker("Site", selection: $entry.site) {
                                    Text("Not sure").tag(InjectionSite?.none)
                                    ForEach(InjectionSite.all) { Text($0.title).tag(InjectionSite?.some($0)) }
                                }
                                .labelsHidden()
                            }
                            .padding(.horizontal, 16)
                            .frame(minHeight: 52)
                            .rowDivider(true)
                        }

                        DatePicker("When", selection: $entry.date, in: ...Date.now)
                            .font(.system(size: 17))
                            .padding(.horizontal, 16)
                            .frame(minHeight: 52)
                    }

                    GroupedSection(title: String(localized: "Note")) {
                        TextField("Anything that might help, like what you ate", text: $entry.note, axis: .vertical)
                            .font(.system(size: 17))
                            .lineLimit(2...5)
                            .padding(16)
                    }

                    if !isNew {
                        Button(role: .destructive) {
                            store.deleteSideEffect(id: entry.id)
                            dismiss()
                        } label: {
                            Text("Delete")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(AppTheme.ColorToken.destructive)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.medium)
                .padding(.vertical, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppTheme.ColorToken.background.ignoresSafeArea())
            .navigationTitle(isNew ? "Log side effect" : "Side effect")
            .navigationBarTitleDisplayMode(.inline)
            .compatNavigationBarBlur()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if entry.kind != .siteReaction { entry.site = nil }
                        entry.note = entry.note.trimmingCharacters(in: .whitespacesAndNewlines)
                        store.save(entry)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func kindButton(_ kind: SideEffectEntry.Kind) -> some View {
        let isSelected = entry.kind == kind
        return Button {
            HapticFeedback.selection()
            withAnimation(.snappy) { entry.kind = kind }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: kind.symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : kind.tint)
                    .frame(width: 40, height: 40)
                    .background(isSelected ? kind.tint : kind.tint.opacity(0.14), in: .circle)
                Text(kind.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.ColorToken.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(AppTheme.ColorToken.cardBackground, in: .rect(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? kind.tint : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
