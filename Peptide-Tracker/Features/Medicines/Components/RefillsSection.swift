import SwiftUI

/// The Stock side of the Medicines tab: what runs out in the next three
/// weeks first, then every refill logged, grouped by month. Laid out in the
/// tab's own stack, so it has no header or scroll view of its own.
struct RefillsSection: View {
    @Environment(MedicineStore.self) private var store
    @Environment(AppRouter.self) private var router
    let now: Date

    private static let horizonDays = 21

    var body: some View {
        if store.refills.isEmpty {
            Spacer(minLength: 0)
            EmptyStateView(
                illustration: .noRefillsYet,
                title: "No refills yet",
                message: "When you mark a medicine as refilled, it shows up here with the date and amount."
            )
            if !store.medicines.isEmpty { comingUp(now: now) }
            Spacer(minLength: 0)
        } else {
            comingUp(now: now)
            history
        }
    }

    // MARK: Coming up

    @ViewBuilder
    private func comingUp(now: Date) -> some View {
        let horizon = now.startOfDay.adding(days: Self.horizonDays)
        let upcoming = store.medicinesByUrgency.filter { $0.runOutDate(now: now) <= horizon }

        GroupedSection(title: "Coming up", trailing: upcoming.isEmpty ? nil : "\(upcoming.count)") {
            if upcoming.isEmpty {
                Text("Nothing runs out in the next three weeks.")
                    .font(.system(size: 17))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
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

        ForEach(months, id: \.self) { month in
            let refills = (groups[month] ?? []).sorted { $0.date > $1.date }
            GroupedSection(title: month.monthName, trailing: "\(refills.count)") {
                RefillRows(refills: refills)
            }
        }
    }
}

/// Coming up, in the same shape as every list row: the medicine's icon, its
/// name, when it runs out, and a chevron.
private struct UpcomingRefillRow: View {
    let medicine: Medicine
    let now: Date
    let showsDivider: Bool

    var body: some View {
        HStack(spacing: 14) {
            MedicineIconView(medicine: medicine, size: 36, isVibrant: true)
            Text(medicine.name)
                .font(.system(size: 17))
                .foregroundStyle(AppTheme.ColorToken.primaryText)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 17))
                .monospacedDigit()
                .foregroundStyle(valueColor)
            Chevron()
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 60)
        .contentShape(.rect)
        .rowDivider(showsDivider, inset: 66)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(medicine.name), \(accessibilityValue)")
    }

    private var runOut: Date { medicine.runOutDate(now: now) }

    /// "20 Oct", "On order", "Ran out"
    private var value: String {
        if medicine.isOrdered { return "On order" }
        if medicine.urgency == .out { return "Ran out" }
        return runOut.dayMonth
    }

    private var valueColor: Color {
        if medicine.isOrdered { return AppTheme.ColorToken.accent }
        return medicine.urgency.isRunningLow ? medicine.urgency.ink : AppTheme.ColorToken.secondaryText
    }

    private var accessibilityValue: String {
        if medicine.isOrdered { return "on order" }
        if medicine.urgency == .out { return "ran out" }
        return "runs out \(runOut.weekdayDayMonth)"
    }
}

/// Refill history, Medicines-list style: the medicine's icon, its name,
/// how much was added and when, and a chevron to the medicine.
struct RefillRows: View {
    @Environment(MedicineStore.self) private var store
    @Environment(AppRouter.self) private var router
    let refills: [RefillEvent]

    var body: some View {
        ForEach(Array(refills.enumerated()), id: \.element.id) { index, refill in
            let medicine = store.medicine(id: refill.medicineID)
            Button {
                if let medicine { router.push(.medicine(medicine.id)) }
            } label: {
                HStack(spacing: 14) {
                    if let medicine {
                        MedicineIconView(medicine: medicine, size: 36, isVibrant: true)
                    } else {
                        MedicineIconView(type: .capsule, color: .slate, size: 36, isVibrant: true)
                    }
                    Text(refill.medicineName)
                        .font(.system(size: 17))
                        .foregroundStyle(AppTheme.ColorToken.primaryText)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    // The amount added reads as a gain, in green; the date
                    // stays quiet beside it.
                    (Text("+\(refill.amount)").foregroundStyle(Urgency.healthy.ink)
                        + Text(" · \(refill.date.dayMonth)").foregroundStyle(AppTheme.ColorToken.secondaryText))
                        .font(.system(size: 17))
                        .monospacedDigit()
                    if medicine != nil { Chevron() }
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 60)
                .contentShape(.rect)
                .rowDivider(index < refills.count - 1, inset: 66)
            }
            .buttonStyle(RowPressStyle())
            .disabled(medicine == nil)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(refill.medicineName), added \(medicine?.unit.format(refill.amount) ?? "\(refill.amount)") on \(refill.date.weekdayDayMonth)")
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
    ScrollView {
        VStack(alignment: .leading, spacing: 22) { RefillsSection(now: .now) }
            .padding(.horizontal, 16)
    }
        .environment(MedicineStore.preview())
        .environment(AppRouter())
        .background(AppTheme.ColorToken.background)
}
