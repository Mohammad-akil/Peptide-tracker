import SwiftUI

/// The Medicines tab — the cabinet, split into what needs a refill soon and
/// what's stocked. Each row's ring shows how much of a full pack is left;
/// days left sit on the right in the urgency colour. Long-press a row for
/// quick actions.
struct MedicinesView: View {
    enum Sort: String {
        case daysLeft, name
    }

    @Environment(MedicineStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(PurchaseStore.self) private var purchases
    @AppStorage("medicines.sort") private var sort: Sort = .daysLeft
    @State private var pendingDelete: Medicine?
    @State private var query = ""
    @State private var viewportHeight: CGFloat = 0

    var body: some View {
        let now = Date.now
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ScreenHeader(title: "Medicines") { sortMenu }

                if store.medicines.isEmpty {
                    Spacer(minLength: 0)
                    EmptyCabinetView { addMedicine() }
                    Spacer(minLength: 0)
                } else if store.medicines.count == 1, let only = store.medicines.first {
                    firstMedicine(only, now: now)
                    HowItWorksCard()
                } else {
                    SearchField(text: $query)
                    if matches.isEmpty {
                        Spacer(minLength: 0)
                        noResults
                        Spacer(minLength: 0)
                    } else {
                        cabinet(now: now)
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.medium)
            .padding(.top, 8)
            .padding(.bottom, AppTheme.Spacing.tabBarClearance)
            .fillsViewport(showsEmptyState, height: viewportHeight)
            .animation(.snappy, value: store.medicines.map(\.id))
        }
        .measuresViewport($viewportHeight)
        .scrollIndicators(.hidden)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .deleteMedicineAlert($pendingDelete)
    }

    /// No medicines, or a search with no matches.
    private var showsEmptyState: Bool {
        store.medicines.isEmpty || (store.medicines.count > 1 && matches.isEmpty)
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
            if !soon.isEmpty {
                GroupedSection(title: "Refill soon", trailing: "\(soon.count)") { rows(soon, now: now) }
            }
            if !stocked.isEmpty {
                GroupedSection(
                    title: "Stocked",
                    trailing: "\(stocked.count)",
                    footer: "Sorted by run-out date. The ring shows how much is left of a full pack."
                ) { rows(stocked, now: now) }
            }
        case .name:
            let sorted = matches.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            GroupedSection(
                title: "All medicines",
                trailing: "\(sorted.count)",
                footer: "Sorted by name. The ring shows how much is left of a full pack."
            ) { rows(sorted, now: now) }
        }
    }

    private func rows(_ medicines: [Medicine], now: Date) -> some View {
        ForEach(Array(medicines.enumerated()), id: \.element.id) { index, medicine in
            Button { router.push(.medicine(medicine.id)) } label: {
                MedicineRow(medicine: medicine, now: now, showsDivider: index < medicines.count - 1)
            }
            .buttonStyle(RowPressStyle())
            .contextMenu {
                MedicineQuickActions(medicine: medicine, pendingDelete: $pendingDelete)
            } preview: {
                MedicineRow(medicine: medicine, now: now, showsDivider: false)
                    .frame(width: 358)
                    .background(AppTheme.ColorToken.cardBackground)
            }
        }
    }

    // MARK: One

    /// Right after the first medicine is saved: its row, a way to add the
    /// next one, and when the first reminder comes.
    private func firstMedicine(_ medicine: Medicine, now: Date) -> some View {
        GroupedSection(footer: firstReminderNote(medicine, now: now)) {
            Button { router.push(.medicine(medicine.id)) } label: {
                MedicineRow(medicine: medicine, now: now, showsDivider: true)
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

    /// "First reminder Fri 9 Oct at 9:00, five days before Metformin runs out."
    private func firstReminderNote(_ medicine: Medicine, now: Date) -> String? {
        guard medicine.wantsReminder else { return nil }
        let date = medicine.reminderDate(now: now)
        guard date > now else { return nil }
        let days = medicine.reminderDaysBefore
        return "First reminder \(date.weekdayDayMonth) at \(date.clockTime), \(days.spelledOut) \(days == 1 ? "day" : "days") before \(medicine.name) runs out."
    }
}

// MARK: - Row

/// Ring and tile, name with strength and daily amount, days left and the
/// run-out date.
struct MedicineRow: View {
    let medicine: Medicine
    let now: Date
    var showsDivider = true

    var body: some View {
        HStack(spacing: 12) {
            StockRingIcon(medicine: medicine)
            VStack(alignment: .leading, spacing: 1) {
                Text(medicine.name)
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    .lineLimit(1)
            }
            .foregroundStyle(AppTheme.ColorToken.primaryText)
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 1) {
                Text(medicine.daysLeftLabel)
                    .font(.system(size: 16, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(medicine.urgency.ink)
                    .contentTransition(.numericText(value: Double(medicine.daysLeft)))
                Text(medicine.runOutDate(now: now).weekdayDayMonth)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 52)
        .contentShape(.rect)
        .rowDivider(showsDivider, inset: 74)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Long-press for quick actions")
    }

    private var subtitle: String {
        medicine.isOrdered ? "Ordered \(medicine.orderedAt?.weekdayDayMonth ?? "")" : medicine.detailSubtitle
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
        .padding(.top, -8)
    }
}
