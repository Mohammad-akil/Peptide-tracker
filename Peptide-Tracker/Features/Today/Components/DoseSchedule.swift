import SwiftUI

/// A day's doses grouped under their time ("8:00"), one card per medicine.
/// Today's next time is flagged, and a time with several doses left can be
/// taken in one go. Future days are view-only.
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
                    ForEach(group.doses) { dose in
                        DoseCard(dose: dose, isFuture: isFuture, isPast: !isFuture && !isToday)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
    }

    private func header(for group: (time: TimeOfDay, doses: [ScheduledDose])) -> some View {
        let pending = group.doses.filter { !$0.isTaken }
        return HStack(spacing: 10) {
            Text(group.time.label)
                .font(.system(size: 22, weight: .bold))
                .monospacedDigit()
            if group.time == nextTime {
                Text("Up next")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.ColorToken.accent)
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(AppTheme.ColorToken.accentSoft, in: .capsule)
            }
            Spacer(minLength: 0)
            if !isFuture, pending.count > 1 {
                Button("Take all") {
                    withAnimation(.snappy) { store.markTaken(pending, now: now) }
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.ColorToken.accent)
            }
        }
        .padding(.horizontal, 4)
    }
}

/// One dose: the medicine's icon, a hairline, what to take, and a check.
private struct DoseCard: View {
    @Environment(MedicineStore.self) private var store
    @Environment(AppRouter.self) private var router
    let dose: ScheduledDose
    let isFuture: Bool
    /// A past day, where an unticked dose was missed.
    let isPast: Bool

    var body: some View {
        HStack(spacing: 14) {
            Button { router.push(.medicine(dose.medicine.id)) } label: {
                HStack(spacing: 14) {
                    MedicineIconView(medicine: dose.medicine, size: 46)
                    Rectangle()
                        .fill(AppTheme.ColorToken.separator)
                        .frame(width: 1, height: 38)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(dose.medicine.name)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(dose.isTaken ? AppTheme.ColorToken.secondaryText : AppTheme.ColorToken.primaryText)
                        Text(detail)
                            .font(.system(size: 14))
                            .foregroundStyle(isMissed ? Urgency.low.ink : AppTheme.ColorToken.secondaryText)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.snappy) { store.toggle(dose) }
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
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(AppTheme.ColorToken.cardBackground, in: .rect(cornerRadius: 20, style: .continuous))
    }

    private var isMissed: Bool { isPast && !dose.isTaken }

    /// "Take 1 pill · With food", "Taken at 8:02", "Not taken"
    private var detail: String {
        if let takenAt = dose.takenAt { return "Taken at \(takenAt.clockTime)" }
        if isMissed { return "Not taken" }
        let amount = "Take \(dose.medicine.unit.format(dose.medicine.unitsPerIntake))"
        let instructions = dose.medicine.instructions
        return instructions.isEmpty ? amount : "\(amount) · \(instructions)"
    }
}
