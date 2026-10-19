import SwiftUI

/// A day's doses, Apple-list style: one inset group per time ("8:00"), each
/// row the medicine's icon, its name, the amount, and a check. Today's next
/// time is flagged, and a time with several doses left can be taken in one
/// go. Future days are view-only.
struct DoseSchedule: View {
    @Environment(MedicineStore.self) private var store
    let doses: [ScheduledDose]
    let day: Date
    let now: Date

    private var isToday: Bool { day == now.startOfDay }
    private var isFuture: Bool { day > now.startOfDay }

    private var groups: [(time: TimeOfDay, doses: [ScheduledDose])] {
        Dictionary(grouping: doses, by: \.time)
            .map { (time: $0.key, doses: $0.value.sorted { $0.medicine.name < $1.medicine.name }) }
            .sorted { $0.time < $1.time }
    }

    /// Today's first time that still has doses to take.
    private var nextTime: TimeOfDay? {
        guard isToday else { return nil }
        return groups.first { group in group.doses.contains { !$0.isTaken } && group.time >= TimeOfDay(date: now) }?.time
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ForEach(groups, id: \.time) { group in
                VStack(alignment: .leading, spacing: 10) {
                    header(for: group)
                    VStack(spacing: 0) {
                        ForEach(Array(group.doses.enumerated()), id: \.element.id) { index, dose in
                            DoseRow(
                                dose: dose,
                                isFuture: isFuture,
                                isPast: !isFuture && !isToday,
                                showsDivider: index < group.doses.count - 1
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .groupedCard()
                }
            }
        }
    }

    /// The quiet list header: the time (with Up next today), and Take all.
    private func header(for group: (time: TimeOfDay, doses: [ScheduledDose])) -> some View {
        let pending = group.doses.filter { !$0.isTaken }
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(group.time.label)
                .monospacedDigit()
            if group.time == nextTime {
                Text("Up next")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.ColorToken.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppTheme.ColorToken.accentSoft, in: .capsule)
            }
            Spacer(minLength: 8)
            if !isFuture, pending.count > 1 {
                Button("Take all") {
                    withAnimation(.snappy) { store.markTaken(pending, now: now) }
                }
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(AppTheme.ColorToken.accent)
            }
        }
        .font(.system(size: 17))
        .foregroundStyle(AppTheme.ColorToken.secondaryText)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .contain)
    }
}

/// One dose in the same shape as every list row: icon, name, the amount on
/// the right, and a check where the chevron would be.
private struct DoseRow: View {
    @Environment(MedicineStore.self) private var store
    @Environment(AppRouter.self) private var router
    let dose: ScheduledDose
    let isFuture: Bool
    /// A past day, where an unticked dose was missed.
    let isPast: Bool
    let showsDivider: Bool

    var body: some View {
        HStack(spacing: 14) {
            Button { router.push(.medicine(dose.medicine.id)) } label: {
                HStack(spacing: 14) {
                    MedicineIconView(medicine: dose.medicine, size: 36, isVibrant: true)
                        .opacity(dose.isTaken ? 0.55 : 1)
                    Text(dose.medicine.name)
                        .font(.system(size: 17))
                        .foregroundStyle(dose.isTaken ? AppTheme.ColorToken.secondaryText : AppTheme.ColorToken.primaryText)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(value)
                        .font(.system(size: 17))
                        .monospacedDigit()
                        .foregroundStyle(valueColor)
                        .contentTransition(.opacity)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            Button {
                // An injection asks where it went before it's ticked off.
                if dose.medicine.type == .injection && !dose.isTaken {
                    router.sheet = .injectionSite(dose)
                } else {
                    withAnimation(.snappy) { store.toggle(dose) }
                }
            } label: {
                DoseCheckmark(isTaken: dose.isTaken)
            }
            .buttonStyle(.plain)
            .padding(.trailing, -8)
            .disabled(isFuture)
            .opacity(isFuture ? 0.35 : 1)
            .accessibilityLabel(dose.isTaken ? "\(dose.medicine.name) taken" : "Mark \(dose.medicine.name) taken")
            .accessibilityAddTraits(dose.isTaken ? .isSelected : [])
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 60)
        .rowDivider(showsDivider, inset: 66)
    }

    private var isMissed: Bool { isPast && !dose.isTaken }

    /// "1 pill", "8:02" once taken, "Missed" on a past day.
    private var value: String {
        if let takenAt = dose.takenAt { return takenAt.clockTime }
        if isMissed { return "Missed" }
        return dose.medicine.unit.format(dose.medicine.unitsPerIntake)
    }

    private var valueColor: Color {
        if dose.isTaken { return Urgency.healthy.ink }
        if isMissed { return Urgency.low.ink }
        return AppTheme.ColorToken.secondaryText
    }
}
