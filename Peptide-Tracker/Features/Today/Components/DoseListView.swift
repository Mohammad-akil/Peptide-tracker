import SwiftUI

/// The List view of a day: doses still to take in one card, then the ones
/// already taken.
struct DoseListView: View {
    @Environment(MedicineStore.self) private var store
    @Environment(AppRouter.self) private var router
    let doses: [ScheduledDose]
    let day: Date
    let now: Date

    var body: some View {
        let pending = doses.filter { !$0.isTaken }
        let taken = doses.filter(\.isTaken).sorted { ($0.takenAt ?? .distantPast) < ($1.takenAt ?? .distantPast) }

        VStack(alignment: .leading, spacing: 22) {
            if !pending.isEmpty {
                GroupedSection { rows(pending) }
            }
            if !taken.isEmpty {
                GroupedSection(title: "Taken", trailing: takenWhen(taken)) { rows(taken) }
            }
        }
    }

    private func rows(_ doses: [ScheduledDose]) -> some View {
        ForEach(Array(doses.enumerated()), id: \.element.id) { index, dose in
            DoseRow(dose: dose, canToggle: day <= now.startOfDay, showsDivider: index < doses.count - 1) {
                withAnimation(.snappy) { store.toggle(dose, now: now) }
            } onOpen: {
                router.push(.medicine(dose.medicine.id))
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    /// "this morning" when everything taken so far was before noon; the
    /// date when looking at another day.
    private func takenWhen(_ taken: [ScheduledDose]) -> String {
        guard Calendar.current.isDate(day, inSameDayAs: now) else { return day.weekdayDayMonth }
        let latest = taken.compactMap(\.takenAt).max() ?? now
        return Calendar.current.component(.hour, from: latest) < 12 ? "this morning" : "today"
    }
}

/// One dose: icon, name, amount and time, with a round checkbox.
struct DoseRow: View {
    let dose: ScheduledDose
    var canToggle = true
    var showsDivider = true
    let onToggle: () -> Void
    var onOpen: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onOpen) {
                HStack(spacing: 12) {
                    MedicineIconView(medicine: dose.medicine, size: 36)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(dose.medicine.name)
                            .font(.system(size: 17))
                            .foregroundStyle(dose.isTaken ? AppTheme.ColorToken.secondaryText : AppTheme.ColorToken.primaryText)
                        Text(subtitle)
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.ColorToken.secondaryText)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if !dose.isTaken {
                        Text(dose.time.label)
                            .font(.system(size: 15))
                            .monospacedDigit()
                            .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            Button(action: onToggle) {
                DoseCheckmark(isTaken: dose.isTaken)
            }
            .buttonStyle(.plain)
            .padding(.vertical, -8)
            .padding(.trailing, -8)
            .disabled(!canToggle)
            .opacity(canToggle ? 1 : 0.4)
            .accessibilityLabel(dose.isTaken ? "\(dose.medicine.name) taken" : "Mark \(dose.medicine.name) taken")
            .accessibilityAddTraits(dose.isTaken ? .isSelected : [])
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 52)
        .rowDivider(showsDivider, inset: 64)
    }

    /// "1 pill", "1 pill · taken 8:02"
    private var subtitle: String {
        let amount = dose.medicine.unit.format(dose.medicine.unitsPerIntake)
        guard let takenAt = dose.takenAt else { return amount }
        return "\(amount) · taken \(takenAt.clockTime)"
    }
}
