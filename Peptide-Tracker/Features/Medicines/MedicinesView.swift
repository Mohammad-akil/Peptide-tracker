import SwiftUI

/// The Medicines tab, with two sides switched at the top. Medicines: the cabinet, split into
/// what needs a refill soon and what's stocked — each row's ring shows how
/// much of a full pack is left, days left sit on the right in the urgency
/// colour, and a long-press opens quick actions. Stock: what runs out
/// next and every refill logged.
struct MedicinesView: View {
    enum Sort: String {
        case daysLeft, name
    }

    enum Pane: String, CaseIterable {
        case medicines, stock

        var title: String { self == .medicines ? "Medicines" : "Stock" }
    }

    @Environment(MedicineStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(PurchaseStore.self) private var purchases
    @AppStorage("medicines.sort") private var sort: Sort = .daysLeft
    @AppStorage("medicines.pane") private var pane: Pane = .medicines
    @AppStorage("medicines.isListView") private var isListView = true
    @State private var pendingDelete: Medicine?
    @State private var query = ""
    @State private var viewportHeight: CGFloat = 0

    var body: some View {
        let now = Date.now
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if showsStock {
                    RefillsSection(now: now)
                } else if store.medicines.isEmpty {
                    Spacer(minLength: 0)
                    EmptyCabinetView { addMedicine() }
                    Spacer(minLength: 0)
                } else if store.medicines.count == 1, let only = store.medicines.first {
                    firstMedicine(only, now: now)
                } else if matches.isEmpty {
                    Spacer(minLength: 0)
                    noResults
                    Spacer(minLength: 0)
                } else {
                    cabinet(now: now)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.medium)
            .padding(.top, 20)
            .padding(.bottom, AppTheme.Spacing.tabBarClearance)
            .fillsViewport(showsEmptyState, height: viewportHeight)
            .animation(.snappy, value: store.medicines.map(\.id))
            .animation(.snappy, value: pane)
            .animation(.smooth(duration: 0.42), value: isListView)
        }
        .measuresViewport($viewportHeight)
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
        // Pinned: the title, the switch and search stay put while the list
        // scrolls under them.
        .safeAreaInset(edge: .top, spacing: 0) { topPanel(now: now) }
        .deleteMedicineAlert($pendingDelete)
    }

    private func topPanel(now: Date) -> some View {
        TopPanel(title: "Medicines") {
            if showsStock {
                shareButton(now: now)
            } else if store.medicines.count > 1 {
                HStack(spacing: 8) {
                    LayoutToggle(isListView: $isListView)
                    sortMenu
                }
            }
        } controls: {
            if !store.medicines.isEmpty {
                VStack(spacing: 12) {
                    PillSegmentedControl(options: Pane.allCases, selection: $pane, height: 38) { option in
                        AnyView(Text(option.title))
                    }
                    if pane == .medicines && store.medicines.count > 1 {
                        SearchField(text: $query)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    /// The Stock side, once there's a medicine to keep stocked.
    private var showsStock: Bool { pane == .stock && !store.medicines.isEmpty }

    /// No medicines, no refills yet, or a search with no matches.
    private var showsEmptyState: Bool {
        if showsStock { return store.refills.isEmpty }
        return store.medicines.isEmpty || (store.medicines.count > 1 && matches.isEmpty)
    }

    private func shareButton(now: Date) -> some View {
        ShareLink(item: RefillListExport.text(store: store, now: now)) {
            Icon(.share, size: 20)
                .foregroundStyle(AppTheme.ColorToken.primaryText)
                .frame(width: 44, height: 44)
        }
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("Share refill list")
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort by", selection: $sort) {
                Label("Run-out date", systemImage: "hourglass").tag(Sort.daysLeft)
                Label("Name", systemImage: "textformat").tag(Sort.name)
            }
        } label: {
            Icon(.sliders, size: 20)
                .foregroundStyle(AppTheme.ColorToken.primaryText)
                .frame(width: 44, height: 44)
        }
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("Sort")
    }

    private func addMedicine(named name: String? = nil) {
        router.requestAddMedicine(named: name, count: store.medicines.count, purchases: purchases)
    }

    // MARK: Search

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespaces) }

    /// Medicines whose name or strength contains the search text.
    private var matches: [Medicine] {
        guard !trimmedQuery.isEmpty else { return store.medicines }
        return store.medicines.filter {
            $0.name.localizedCaseInsensitiveContains(trimmedQuery)
                || $0.strength.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    private var noResults: some View {
        EmptyStateView(
            illustration: .noSearchResults,
            title: "No match for “\(trimmedQuery)”",
            message: "Check the spelling, or add it as a new medicine."
        ) {
            Button("Add “\(trimmedQuery)”") {
                addMedicine(named: trimmedQuery)
                query = ""
            }
            .buttonStyle(.primary(height: 52))
        }
    }

    // MARK: Many

    @ViewBuilder
    private func cabinet(now: Date) -> some View {
        switch sort {
        case .daysLeft:
            let sorted = store.medicinesByUrgency.filter { medicine in matches.contains { $0.id == medicine.id } }
            let soon = sorted.filter { $0.urgency.isRunningLow }
            let stocked = sorted.filter { !$0.urgency.isRunningLow }
            if !soon.isEmpty { section("Refill soon", soon, now: now) }
            if !stocked.isEmpty { section("Stocked", stocked, now: now) }
        case .name:
            let sorted = matches.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            section("All medicines", sorted, now: now)
        }
    }

    /// A titled group of medicines as list rows or a two-column grid.
    @ViewBuilder
    private func section(_ title: String, _ medicines: [Medicine], now: Date) -> some View {
        Group {
            if isListView {
                GroupedSection(title: title, trailing: "\(medicines.count)") { rows(medicines, now: now) }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    // Same header as a grouped list, so both layouts read alike.
                    HStack {
                        Text(title)
                        Spacer(minLength: 8)
                        Text("\(medicines.count)").monospacedDigit()
                    }
                    .font(.system(size: 17))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    .padding(.horizontal, 16)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                        ForEach(medicines) { medicine in
                            Button { router.push(.medicine(medicine.id)) } label: {
                                MedicineTile(medicine: medicine)
                            }
                            .buttonStyle(.pressable)
                            .contentShape(.contextMenuPreview, .rect(cornerRadius: 22, style: .continuous))
                            .contextMenu {
                                MedicineQuickActions(medicine: medicine, pendingDelete: $pendingDelete)
                            }
                        }
                    }
                }
            }
        }
        .id(isListView)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    private func rows(_ medicines: [Medicine], now: Date) -> some View {
        ForEach(Array(medicines.enumerated()), id: \.element.id) { index, medicine in
            Button { router.push(.medicine(medicine.id)) } label: {
                MedicineRow(medicine: medicine, now: now, showsDivider: index < medicines.count - 1, isVibrant: true)
            }
            .buttonStyle(RowPressStyle())
            .contextMenu {
                MedicineQuickActions(medicine: medicine, pendingDelete: $pendingDelete)
            } preview: {
                MedicineRow(medicine: medicine, now: now, showsDivider: false, isVibrant: true)
                    .frame(width: 358)
                    .background(AppTheme.ColorToken.cardBackground)
            }
        }
    }

    // MARK: One

    /// Right after the first medicine is saved: its row and a way to add
    /// the next one.
    private func firstMedicine(_ medicine: Medicine, now: Date) -> some View {
        GroupedSection {
            Button { router.push(.medicine(medicine.id)) } label: {
                MedicineRow(medicine: medicine, now: now, showsDivider: true, isVibrant: true)
            }
            .buttonStyle(RowPressStyle())
            .contextMenu { MedicineQuickActions(medicine: medicine, pendingDelete: $pendingDelete) }

            Button { addMedicine() } label: {
                HStack(spacing: 12) {
                    Icon(.plus, size: 24)
                        .frame(width: 46)
                    Text("Add another medicine")
                        .font(.system(size: 17, weight: .medium))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(AppTheme.ColorToken.accent)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(minHeight: 52)
                .contentShape(.rect)
            }
            .buttonStyle(RowPressStyle())
        }
    }
}

// MARK: - Row

/// One medicine, Apple-list style: its icon, the name, days left (in the
/// urgency colour once it's running low) and a chevron to its page.
struct MedicineRow: View {
    let medicine: Medicine
    let now: Date
    var showsDivider = true
    /// Bright tile with a white glyph, as in the Medicines list.
    var isVibrant = false

    var body: some View {
        HStack(spacing: 14) {
            MedicineIconView(medicine: medicine, size: 36, isVibrant: isVibrant)
            Text(medicine.name)
                .font(.system(size: 17))
                .foregroundStyle(AppTheme.ColorToken.primaryText)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 17))
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .contentTransition(.numericText(value: Double(medicine.daysLeft)))
            Chevron()
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 60)
        .contentShape(.rect)
        .rowDivider(showsDivider, inset: 66)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Long-press for quick actions")
    }

    /// "13 days", "Run out", "On order"
    private var value: String {
        medicine.isOrdered ? "On order" : medicine.daysLeftLabel
    }

    private var valueColor: Color {
        if medicine.isOrdered { return AppTheme.ColorToken.accent }
        return medicine.urgency.isRunningLow ? medicine.urgency.ink : AppTheme.ColorToken.secondaryText
    }
}

/// A medicine as a grid card: the bright icon, its name and days left.
struct MedicineTile: View {
    let medicine: Medicine

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MedicineIconView(medicine: medicine, size: 44, isVibrant: true)
            Spacer(minLength: 14)
            Text(medicine.name)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.ColorToken.primaryText)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Text(value)
                .font(.system(size: 14, weight: medicine.urgency.isRunningLow ? .semibold : .regular))
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .padding(14)
        .background(AppTheme.ColorToken.cardBackground, in: .rect(cornerRadius: 22, style: .continuous))
        .contentShape(.rect(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Long-press for quick actions")
    }

    /// "13 days left", "Run out", "On order"
    private var value: String {
        if medicine.isOrdered { return "On order" }
        return medicine.urgency == .out ? "Run out" : "\(medicine.daysLeftLabel) left"
    }

    private var valueColor: Color {
        if medicine.isOrdered { return AppTheme.ColorToken.accent }
        return medicine.urgency.isRunningLow ? medicine.urgency.ink : AppTheme.ColorToken.secondaryText
    }
}

/// List or grid, as two small round buttons; the active one is tinted.
private struct LayoutToggle: View {
    @Binding var isListView: Bool

    var body: some View {
        HStack(spacing: 2) {
            option(isList: true, symbol: "list.bullet", name: "List")
            option(isList: false, symbol: "square.grid.2x2", name: "Grid")
        }
        .padding(3)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    private func option(isList: Bool, symbol: String, name: String) -> some View {
        let isActive = isListView == isList
        return Button {
            guard !isActive else { return }
            HapticFeedback.impact(.light)
            withAnimation(.smooth(duration: 0.42)) { isListView = isList }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isActive ? AppTheme.ColorToken.accent : AppTheme.ColorToken.secondaryText)
                .frame(width: 38, height: 38)
                .background(isActive ? AppTheme.ColorToken.accentSoft : .clear, in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isActive ? "\(name) view, selected" : "Show \(name.lowercased()) view")
    }
}

// MARK: - Quick actions

/// The long-press menu on a medicine row.
struct MedicineQuickActions: View {
    @Environment(MedicineStore.self) private var store
    @Environment(AppRouter.self) private var router
    let medicine: Medicine
    @Binding var pendingDelete: Medicine?

    var body: some View {
        Button { router.sheet = .refill(medicine.id) } label: {
            Label("Refilled", systemImage: "arrow.up.circle")
        }
        if medicine.isOrdered {
            Button { store.cancelOrder(medicine.id) } label: {
                Label("Not ordered", systemImage: "shippingbox.and.arrow.backward")
            }
        } else {
            Button { store.markOrdered(medicine.id) } label: {
                Label("Ordered", systemImage: "shippingbox")
            }
        }
        Button { router.sheet = .editMedicine(medicine.id) } label: {
            Label("Edit", systemImage: "pencil")
        }
        Divider()
        Button(role: .destructive) { pendingDelete = medicine } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

extension View {
    /// "Delete Metformin?" — its reminder and refill history go too.
    func deleteMedicineAlert(_ medicine: Binding<Medicine?>, onDeleted: @escaping () -> Void = {}) -> some View {
        modifier(DeleteMedicineAlert(medicine: medicine, onDeleted: onDeleted))
    }
}

private struct DeleteMedicineAlert: ViewModifier {
    @Environment(MedicineStore.self) private var store
    @Binding var medicine: Medicine?
    let onDeleted: () -> Void

    func body(content: Content) -> some View {
        content.alert(
            "Delete \(medicine?.name ?? "medicine")?",
            isPresented: Binding(get: { medicine != nil }, set: { if !$0 { medicine = nil } }),
            presenting: medicine
        ) { medicine in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                HapticFeedback.notification(.warning)
                onDeleted()
                withAnimation(.snappy) { store.delete(id: medicine.id) }
            }
        } message: { _ in
            Text("Its reminder and refill history go too. You can’t undo this.")
        }
    }
}

#Preview("Cabinet") {
    MedicinesView()
        .environment(MedicineStore.preview())
        .environment(AppRouter())
        .background(AppTheme.ColorToken.background)
}

#Preview("Empty") {
    MedicinesView()
        .environment(MedicineStore.preview(sample: false))
        .environment(AppRouter())
        .background(AppTheme.ColorToken.background)
}

/// The rounded search field above the cabinet.
private struct SearchField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Icon(.search, size: 18)
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
            TextField("Search medicines", text: $text)
                .font(.system(size: 17))
                .focused($isFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Icon(.x, size: 13)
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Color(light: 0xA9A6B4, dark: 0x5C5868), in: .circle)
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .padding(.trailing, -11)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(AppTheme.ColorToken.controlFill, in: .capsule)
    }
}
