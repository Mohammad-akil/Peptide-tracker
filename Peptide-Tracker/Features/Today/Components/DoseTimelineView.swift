import SwiftUI

/// The Timeline view of a day: doses grouped by time down a rail, with a
/// NOW marker between what's passed and what's coming.
struct DoseTimelineView: View {
    @Environment(MedicineStore.self) private var store
    let doses: [ScheduledDose]
    let day: Date
    let now: Date

    private struct Slot: Identifiable {
        let time: TimeOfDay
        let doses: [ScheduledDose]
        var id: Int { time.minutesSinceMidnight }
        var takenCount: Int { doses.filter(\.isTaken).count }
        var pending: [ScheduledDose] { doses.filter { !$0.isTaken } }
    }

    private var slots: [Slot] {
        Dictionary(grouping: doses, by: \.time)
            .map { Slot(time: $0.key, doses: $0.value) }
            .sorted { $0.time < $1.time }
    }

    private var isToday: Bool { Calendar.current.isDate(day, inSameDayAs: now) }
    private var isFuture: Bool { day > now.startOfDay }

    var body: some View {
        let slots = slots
        let nowMinutes = TimeOfDay(date: now).minutesSinceMidnight
        let nextSlotID = isToday ? slots.first { $0.id > nowMinutes && !$0.pending.isEmpty }?.id : nil

        VStack(spacing: 0) {
            ForEach(Array(slots.enumerated()), id: \.element.id) { index, slot in
                let isPast = !isFuture && (!isToday || slot.id <= nowMinutes)
                let showsNow = isToday && slot.id > nowMinutes && (index == 0 || slots[index - 1].id <= nowMinutes)
                if showsNow { nowMarker }
                slotRow(slot, isPast: isPast, isNext: slot.id == nextSlotID, isLast: index == slots.count - 1)
            }
            if isToday, let last = slots.last, last.id <= nowMinutes { nowMarker }
        }
    }

    // MARK: Rows

    private func slotRow(_ slot: Slot, isPast: Bool, isNext: Bool, isLast: Bool) -> some View {
        let isDone = slot.pending.isEmpty
        let isHighlighted = isNext || (isPast && !isDone)

        return HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .trailing, spacing: 0) {
                Text(slot.time.label)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(isNext ? AppTheme.ColorToken.accent : AppTheme.ColorToken.secondaryText)
                Text(slot.time.periodName)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
            }
            .frame(width: 52, alignment: .trailing)
            .padding(.top, 14)

            rail(isDone: isDone, isHighlighted: isHighlighted, isLast: isLast)

            card(for: slot, isPast: isPast, isNext: isNext, isDone: isDone)
                .padding(.bottom, 14)
        }
    }

    private func rail(isDone: Bool, isHighlighted: Bool, isLast: Bool) -> some View {
        ZStack(alignment: .top) {
            if !isLast {
                Rectangle()
                    .fill(AppTheme.ColorToken.ringTrack)
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
                    .padding(.top, 18)
            }
            Circle()
                .fill(isDone ? AppTheme.ColorToken.accent : AppTheme.ColorToken.cardBackground)
                .overlay {
                    if isDone {
                        Image(systemName: "checkmark").font(.system(size: 10, weight: .heavy)).foregroundStyle(.white)
                    } else {
                        Circle().strokeBorder(isHighlighted ? AppTheme.ColorToken.accent : AppTheme.ColorToken.uncheckedRing, lineWidth: 2.5)
                    }
                }
                .frame(width: 20, height: 20)
                .padding(.top, 16)
        }
        .frame(width: 24)
    }

    private func card(for slot: Slot, isPast: Bool, isNext: Bool, isDone: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(statusTitle(slot, isPast: isPast, isNext: isNext, isDone: isDone))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(isNext ? AppTheme.ColorToken.accent : AppTheme.ColorToken.secondaryText)
                Spacer()
                Text("\(slot.takenCount)/\(slot.doses.count)")
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
            }

            ForEach(slot.doses) { dose in
                HStack(spacing: 10) {
                    MedicineIconView(medicine: dose.medicine, size: 32)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(dose.medicine.name)
                            .font(.system(size: 15, weight: .semibold))
                            .strikethrough(dose.isTaken, color: AppTheme.ColorToken.secondaryText.opacity(0.5))
                            .foregroundStyle(dose.isTaken ? AppTheme.ColorToken.secondaryText : AppTheme.ColorToken.primaryText)
                        Text(dose.isTaken ? "taken \(dose.takenAt?.clockTime ?? "")" : dose.medicine.unit.format(dose.medicine.unitsPerIntake))
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    }
                    Spacer(minLength: 0)
                    Button {
                        withAnimation(.snappy) { store.toggle(dose, now: now) }
                    } label: {
                        DoseCheckmark(isTaken: dose.isTaken, size: 22)
                    }
                    .buttonStyle(.plain)
                    .disabled(isFuture)
                    .frame(width: 36, height: 36)
                    .accessibilityLabel(dose.isTaken ? "\(dose.medicine.name) taken" : "Mark \(dose.medicine.name) taken")
                }
            }

            let pending = slot.pending
            if !isFuture, !pending.isEmpty, isPast || isNext {
                Button {
                    withAnimation(.snappy) { store.markTaken(pending, now: now) }
                } label: {
                    Label(
                        pending.count == 1 ? "Take \(pending[0].medicine.name) now" : "Take all \(pending.count)",
                        systemImage: "checkmark"
                    )
                }
                .buttonStyle(.primary(height: 40, fullWidth: false))
                .padding(.top, 2)
            }
        }
        .card(horizontal: 14, vertical: 12, radius: 20)
        .overlay {
            if isNext {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(AppTheme.ColorToken.accent.opacity(0.35), lineWidth: 1.5)
            }
        }
    }

    private func statusTitle(_ slot: Slot, isPast: Bool, isNext: Bool, isDone: Bool) -> String {
        if isDone { return "Done" }
        if isNext { return "Up next" }
        if isPast { return slot.takenCount > 0 ? "Partly taken" : "Not taken yet" }
        return "Later"
    }

    private var nowMarker: some View {
        HStack(spacing: 10) {
            Text(now.clockTime)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.ColorToken.accent)
                .frame(width: 52, alignment: .trailing)
            Text("NOW")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(AppTheme.ColorToken.accent, in: .rect(cornerRadius: 9))
            Rectangle()
                .fill(AppTheme.ColorToken.accent)
                .frame(height: 2)
        }
        .padding(.bottom, 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Now, \(now.clockTime)")
    }
}
