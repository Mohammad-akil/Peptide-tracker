import SwiftUI

/// The pillbox views of a day: one compartment per dose time, like the
/// lids of a pill organiser, two to a row — square or round. Inside, each
/// medicine is its icon; tap it to take it (an injection asks for its site
/// first). A compartment turns green with a tick once everything in it is
/// taken, and today's next one is outlined. Future days are view-only.
struct DosePillbox: View {
    enum Style { case square, round }

    let doses: [ScheduledDose]
    let day: Date
    let now: Date
    let style: Style

    struct Compartment: Identifiable {
        let time: TimeOfDay
        let doses: [ScheduledDose]
        var id: Int { time.minutesSinceMidnight }
        var isDone: Bool { doses.allSatisfy(\.isTaken) }
    }

    private var compartments: [Compartment] {
        Dictionary(grouping: doses, by: \.time)
            .map { Compartment(time: $0.key, doses: $0.value.sorted { $0.medicine.name < $1.medicine.name }) }
            .sorted { $0.time < $1.time }
    }

    private var isToday: Bool { day == now.startOfDay }
    private var isFuture: Bool { day > now.startOfDay }

    var body: some View {
        let compartments = compartments
        let nowMinutes = TimeOfDay(date: now).minutesSinceMidnight
        // The first time still to take, today: overdue ones first.
        let nextID = isToday ? compartments.first { !$0.isDone }?.id : nil

        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(compartments) { compartment in
                let isPast = !isFuture && (!isToday || compartment.id <= nowMinutes)
                PillboxCompartment(
                    compartment: compartment,
                    style: style,
                    isNext: compartment.id == nextID,
                    isMissed: !isToday && !isFuture && !compartment.isDone && isPast,
                    isFuture: isFuture
                )
            }
        }
    }
}

/// One lid: the time and its period, the medicines inside, and its state.
private struct PillboxCompartment: View {
    @Environment(MedicineStore.self) private var store
    @Environment(AppRouter.self) private var router
    let compartment: DosePillbox.Compartment
    let style: DosePillbox.Style
    let isNext: Bool
    let isMissed: Bool
    let isFuture: Bool

    /// Icons shown before the rest fold into "+2".
    private var visibleLimit: Int { style == .round ? 3 : 6 }

    var body: some View {
        let doses = compartment.doses
        let shown = doses.prefix(visibleLimit)

        VStack(spacing: style == .round ? 8 : 10) {
            VStack(spacing: 1) {
                Text(compartment.time.label)
                    .font(.system(size: 17, weight: .bold))
                    .monospacedDigit()
                Text(status)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(statusInk)
            }

            FlowLayout(spacing: 6) {
                ForEach(shown) { dose in
                    pill(dose)
                }
                if doses.count > shown.count {
                    Text("+\(doses.count - shown.count)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.ColorToken.secondaryText)
                        .frame(width: 34, height: 34)
                        .background(AppTheme.ColorToken.controlFill, in: .circle)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(style == .round ? 18 : 14)
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(fill, in: outline)
        .overlay {
            outline
                .stroke(isNext ? AppTheme.ColorToken.accent : Color(hex: 0x28185A, opacity: 0.06), lineWidth: isNext ? 2 : 0.5)
                .padding(isNext ? 1 : 0.25)
        }
        .overlay(alignment: style == .round ? .top : .topTrailing) {
            if compartment.isDone {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Urgency.healthy.tint)
                    .background(Circle().fill(AppTheme.ColorToken.cardBackground).padding(2))
                    .padding(style == .round ? 4 : 10)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: compartment.isDone)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(compartment.time.label), \(status)")
    }

    private var outline: AnyShape {
        style == .round ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var fill: Color {
        if compartment.isDone { return Urgency.healthy.wash }
        if isMissed { return Urgency.low.wash }
        return AppTheme.ColorToken.cardBackground
    }

    /// "Morning", "Taken", "Missed", "2 left"
    private var status: String {
        if compartment.isDone { return "Taken" }
        if isMissed { return "Missed" }
        let left = compartment.doses.filter { !$0.isTaken }.count
        return left == compartment.doses.count ? compartment.time.periodName : "\(left) left"
    }

    private var statusInk: Color {
        if compartment.isDone { return Urgency.healthy.ink }
        if isMissed { return Urgency.low.ink }
        return isNext ? AppTheme.ColorToken.accent : AppTheme.ColorToken.secondaryText
    }

    /// A medicine in the compartment; faded with a tick once taken.
    private func pill(_ dose: ScheduledDose) -> some View {
        Button {
            // An injection asks where it went before it's ticked off.
            if dose.medicine.type == .injection && !dose.isTaken {
                router.sheet = .injectionSite(dose)
            } else {
                withAnimation(.snappy) { store.toggle(dose) }
            }
        } label: {
            MedicineIconView(medicine: dose.medicine, size: 34, isVibrant: true)
                .opacity(dose.isTaken ? 0.4 : 1)
                .overlay(alignment: .bottomTrailing) {
                    if dose.isTaken {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white, AppTheme.ColorToken.accent)
                            .offset(x: 4, y: 4)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
        }
        .buttonStyle(.pressable)
        .disabled(isFuture)
        .contextMenu {
            Button("Open \(dose.medicine.name)", systemImage: "arrow.up.right") {
                router.push(.medicine(dose.medicine.id))
            }
        }
        .accessibilityLabel(dose.isTaken ? "\(dose.medicine.name) taken" : "Mark \(dose.medicine.name) taken")
        .accessibilityAddTraits(dose.isTaken ? .isSelected : [])
    }
}
