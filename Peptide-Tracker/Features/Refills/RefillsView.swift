import SwiftUI

/// The Refills tab: what runs out in the next three weeks first, then every
/// refill logged, grouped by month.
struct RefillsView: View {
    @Environment(MedicineStore.self) private var store
    @Environment(AppRouter.self) private var router

    private static let horizonDays = 21

    var body: some View {
        let now = Date.now
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ScreenHeader(title: "Refills") {
                    ShareLink(item: RefillListExport.text(store: store, now: now)) {
                        Icon(.share, size: 20)
                            .foregroundStyle(AppTheme.ColorToken.primaryText)
                            .frame(width: 44, height: 44)
                    }
                    .glassEffect(.regular.interactive(), in: .circle)
                    .accessibilityLabel("Share refill list")
                    .disabled(store.medicines.isEmpty)
                }

                if store.refills.isEmpty {
                    EmptyStateView(
                        illustration: .noRefillsYet,
                        title: "No refills yet",
                        message: "When you mark a medicine as refilled, it shows up here with the date and amount."
                    )
                    if !store.medicines.isEmpty { comingUp(now: now) }
                } else {
                    comingUp(now: now)
                    history
                }
            }
            .padding(.horizontal, AppTheme.Spacing.medium)
            .padding(.top, 8)
            .padding(.bottom, AppTheme.Spacing.tabBarClearance)
        }
        .scrollIndicators(.hidden)
        .scrollEdgeEffectStyle(.soft, for: .top)
    }

    // MARK: Coming up

    @ViewBuilder
    private func comingUp(now: Date) -> some View {
        let horizon = now.startOfDay.adding(days: Self.horizonDays)
        let upcoming = store.medicinesByUrgency.filter { $0.runOutDate(now: now) <= horizon }

        GroupedSection(title: "Coming up", trailing: "Next 3 weeks") {
            if upcoming.isEmpty {
                Text("Nothing runs out in the next three weeks.")
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            }
            ForEach(Array(upcoming.enumerated()), id: \.element.id) { index, medicine in
                Button { router.push(.medicine(medicine.id)) } label: {
                    UpcomingRefillRow(medicine: medicine, now: now, showsDivider: index < upcoming.count - 1)
                }
                .buttonStyle(RowPressStyle())
            }
        }
    }

    // MARK: History

    @ViewBuilder
    private var history: some View {
        let groups = Dictionary(grouping: store.refills) {
            Calendar.current.dateInterval(of: .month, for: $0.date)?.start ?? $0.date
        }
        let months = groups.keys.sorted(by: >)

        ForEach(Array(months.enumerated()), id: \.element) { index, month in
            let refills = (groups[month] ?? []).sorted { $0.date > $1.date }
            GroupedSection(title: index == 0 ? "History" : nil, trailing: month.monthName) {
                RefillRows(refills: refills)
            }
        }
    }
}

/// "Oct 4 · Amlodipine · Runs out · order now ›"
private struct UpcomingRefillRow: View {
    let medicine: Medicine
    let now: Date
    let showsDivider: Bool

    var body: some View {
        let runOut = medicine.runOutDate(now: now)
        let tone = badgeTone

        HStack(spacing: 12) {
            VStack(spacing: 0) {
                Text(runOut.monthAbbrev)
                    .font(.system(size: 11, weight: .bold))
                    .textCase(.uppercase)
                Text(runOut.formatted(.dateTime.day()))
                    .font(.system(size: 19, weight: .bold))
            }
            .foregroundStyle(tone.ink)
            .frame(width: 46, height: 48)
            .background(tone.wash, in: .rect(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(medicine.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.ColorToken.primaryText)
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
            }
            Spacer(minLength: 8)
            Chevron()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 52)
        .contentShape(.rect)
        .rowDivider(showsDivider, inset: 74)
        .accessibilityElement(children: .combine)
    }

    private var badgeTone: (ink: Color, wash: Color) {
        switch medicine.urgency {
        case .out, .critical, .low: (medicine.urgency.ink, medicine.urgency.wash)
        case .healthy: (AppTheme.ColorToken.primaryText, AppTheme.ColorToken.controlFill)
        }
    }

    private var subtitle: String {
        let verb = medicine.urgency == .out ? "Ran out" : "Runs out"
        if medicine.isOrdered { return "\(verb) · ordered" }
        let reminder = medicine.reminderDate(now: now)
        if medicine.urgency <= .critical || reminder <= now { return "\(verb) · order now" }
        if medicine.remindersPaused { return "\(verb) · reminders paused" }
        return "\(verb) · reminder \(reminder.weekdayDayMonth)"
    }
}

/// Refill rows: icon, name, date, "+60 pills".
struct RefillRows: View {
    @Environment(MedicineStore.self) private var store
    let refills: [RefillEvent]

    var body: some View {
        ForEach(Array(refills.enumerated()), id: \.element.id) { index, refill in
            let medicine = store.medicine(id: refill.medicineID)
            HStack(spacing: 12) {
                if let medicine {
                    MedicineIconView(medicine: medicine, size: 36)
                } else {
                    MedicineIconView(type: .capsule, color: .slate, size: 36)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(refill.medicineName).font(.system(size: 17))
                    Text(refill.date.weekdayDayMonth)
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.ColorToken.secondaryText)
                }
                Spacer(minLength: 8)
                Text("+\(medicine?.unit.format(refill.amount) ?? "\(refill.amount)")")
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()
            }
            .foregroundStyle(AppTheme.ColorToken.primaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 52)
            .rowDivider(index < refills.count - 1, inset: 64)
            .accessibilityElement(children: .combine)
        }
    }
}

/// Plain-text refill list for sharing with a pharmacy or carer.
enum RefillListExport {
    @MainActor
    static func text(store: MedicineStore, now: Date) -> String {
        var lines = ["Refill list · \(now.weekdayDayMonth)"]
        if !store.settings.pharmacyName.isEmpty { lines.append("Pharmacy: \(store.settings.pharmacyName)") }
        lines.append("")
        for medicine in store.medicinesByUrgency {
            let strength = medicine.strength.isEmpty ? "" : " \(medicine.strength)"
            lines.append("• \(medicine.name)\(strength) — \(medicine.unit.format(medicine.stock)) left, runs out \(medicine.runOutDate(now: now).weekdayDayMonth)")
        }
        return lines.joined(separator: "\n")
    }
}

#Preview {
    RefillsView()
        .environment(MedicineStore.preview())
        .environment(AppRouter())
        .background(AppTheme.ColorToken.background)
}
