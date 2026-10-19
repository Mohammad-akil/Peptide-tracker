import SwiftUI

/// How Today lays out a day's doses, picked in Settings.
enum DoseLayout: String, CaseIterable {
    case list, timeline, squarePillbox, roundPillbox

    static let storageKey = "today.doseLayout"

    var title: String {
        switch self {
        case .list: "List"
        case .timeline: "Timeline"
        case .squarePillbox: "Square pillbox"
        case .roundPillbox: "Round pillbox"
        }
    }

    /// The line under it in Settings → Doses.
    var detail: String {
        switch self {
        case .list: "Doses grouped by time, as a list."
        case .timeline: "Doses down the day, with a line for now."
        case .squarePillbox: "A square compartment for each time, like a pill organiser."
        case .roundPillbox: "The same compartments, round."
        }
    }
}

/// The Timeline view of a day: each dose time down a rail, with a NOW line
/// between what's passed and what's coming. Each time's doses sit in a card
/// with the same rows as the list (icon, name, amount, check).
struct DoseTimeline: View {
    @Environment(MedicineStore.self) private var store
    let doses: [ScheduledDose]
    let day: Date
    let now: Date

    private struct Slot: Identifiable {
        let time: TimeOfDay
        let doses: [ScheduledDose]
        var id: Int { time.minutesSinceMidnight }
        var pending: [ScheduledDose] { doses.filter { !$0.isTaken } }
        var isDone: Bool { pending.isEmpty }
    }

    private var slots: [Slot] {
        Dictionary(grouping: doses, by: \.time)
            .map { Slot(time: $0.key, doses: $0.value.sorted { $0.medicine.name < $1.medicine.name }) }
            .sorted { $0.time < $1.time }
    }

    private var isToday: Bool { day == now.startOfDay }
    private var isFuture: Bool { day > now.startOfDay }

    var body: some View {
        let slots = slots
        let nowMinutes = TimeOfDay(date: now).minutesSinceMidnight
        let nextID = isToday ? slots.first { $0.id > nowMinutes && !$0.isDone }?.id : nil

        VStack(spacing: 0) {
            ForEach(Array(slots.enumerated()), id: \.element.id) { index, slot in
                let isPast = !isFuture && (!isToday || slot.id <= nowMinutes)
                let showsNow = isToday && slot.id > nowMinutes && (index == 0 || slots[index - 1].id <= nowMinutes)
                if showsNow { nowLine }
                slotRow(slot, isPast: isPast, isNext: slot.id == nextID, isLast: index == slots.count - 1)
            }
            if isToday, let last = slots.last, last.id <= nowMinutes { nowLine }
        }
    }

    // MARK: Slot

    private func slotRow(_ slot: Slot, isPast: Bool, isNext: Bool, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .trailing, spacing: 1) {
                Text(slot.time.label)
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(isNext ? AppTheme.ColorToken.accent : AppTheme.ColorToken.primaryText)
                Text(slot.time.periodName)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
            }
            .frame(width: 54, alignment: .trailing)
            .padding(.top, 14)

            rail(isDone: slot.isDone, isHighlighted: isNext || (isPast && !slot.isDone), isLast: isLast)

            card(for: slot, isPast: isPast, isNext: isNext)
                .padding(.bottom, 16)
        }
    }

    private func rail(isDone: Bool, isHighlighted: Bool, isLast: Bool) -> some View {
        ZStack(alignment: .top) {
            if !isLast {
                Rectangle()
                    .fill(AppTheme.ColorToken.ringTrack)
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
                    .padding(.top, 20)
            }
            Circle()
                .fill(isDone ? Urgency.healthy.tint : AppTheme.ColorToken.cardBackground)
                .overlay {
                    if isDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(.white)
                    } else {
                        Circle().strokeBorder(isHighlighted ? AppTheme.ColorToken.accent : AppTheme.ColorToken.uncheckedRing, lineWidth: 2.5)
                    }
                }
                .frame(width: 20, height: 20)
                .padding(.top, 16)
        }
        .frame(width: 24)
    }

    /// The same shape as every section in the app: a quiet header (status,
    /// Up next, Take all) over an inset group of rows.
    private func card(for slot: Slot, isPast: Bool, isNext: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if isNext {
                    Text("Up next")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.ColorToken.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppTheme.ColorToken.accentSoft, in: .capsule)
                } else {
                    Text(status(slot, isPast: isPast))
                }
                Spacer(minLength: 8)
                if !isFuture, slot.pending.count > 1 {
                    Button("Take all") {
                        withAnimation(.snappy) { store.markTaken(slot.pending, now: now) }
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.ColorToken.accent)
                }
            }
            .font(.system(size: 15))
            .foregroundStyle(AppTheme.ColorToken.secondaryText)
            .padding(.horizontal, 14)
            .frame(minHeight: 22)

            VStack(spacing: 0) {
                ForEach(Array(slot.doses.enumerated()), id: \.element.id) { index, dose in
                    TimelineDoseRow(
                        dose: dose,
                        isFuture: isFuture,
                        isMissed: isPast && !isToday && !dose.isTaken,
                        showsDivider: index < slot.doses.count - 1
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .groupedCard()
            .selectionBorder(isNext, cornerRadius: AppTheme.Radius.tile)
        }
        .padding(.top, 14)
    }

    private func status(_ slot: Slot, isPast: Bool) -> String {
        if slot.isDone { return "Done" }
        if isPast { return slot.pending.count < slot.doses.count ? "Partly taken" : "Not taken yet" }
        return "Later"
    }

    private var nowLine: some View {
        HStack(spacing: 10) {
            Text(now.clockTime)
                .font(.system(size: 12, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(AppTheme.ColorToken.accent)
                .frame(width: 54, alignment: .trailing)
            Text("NOW")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(AppTheme.ColorToken.accent, in: .capsule)
            Rectangle()
                .fill(AppTheme.ColorToken.accent)
                .frame(height: 2)
        }
        .padding(.bottom, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Now, \(now.clockTime)")
    }
}

/// A dose inside a timeline card: the list row, a touch more compact.
private struct TimelineDoseRow: View {
    @Environment(MedicineStore.self) private var store
    @Environment(AppRouter.self) private var router
    let dose: ScheduledDose
    let isFuture: Bool
    let isMissed: Bool
    let showsDivider: Bool

    var body: some View {
        HStack(spacing: 12) {
            Button { router.push(.medicine(dose.medicine.id)) } label: {
                HStack(spacing: 12) {
                    MedicineIconView(medicine: dose.medicine, size: 32, isVibrant: true)
                        .opacity(dose.isTaken ? 0.55 : 1)
                    Text(dose.medicine.name)
                        .font(.system(size: 16))
                        .foregroundStyle(dose.isTaken ? AppTheme.ColorToken.secondaryText : AppTheme.ColorToken.primaryText)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(value)
                        .font(.system(size: 15))
                        .monospacedDigit()
                        .foregroundStyle(valueColor)
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
                DoseCheckmark(isTaken: dose.isTaken, size: 24)
            }
            .buttonStyle(.plain)
            .padding(.trailing, -8)
            .disabled(isFuture)
            .opacity(isFuture ? 0.35 : 1)
            .accessibilityLabel(dose.isTaken ? "\(dose.medicine.name) taken" : "Mark \(dose.medicine.name) taken")
            .accessibilityAddTraits(dose.isTaken ? .isSelected : [])
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 52)
        .rowDivider(showsDivider, inset: 58)
    }

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
