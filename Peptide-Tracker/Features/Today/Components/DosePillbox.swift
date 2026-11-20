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

    @Environment(\.horizontalSizeClass) private var sizeClass

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

        // Two lids a row on iPhone, three on iPad.
        let count = sizeClass == .regular ? 3 : 2
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: count), spacing: 12) {
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
        if style == .square {
            squareLid
        } else {
            roundLid
        }
    }

    // MARK: Square

    /// Every square lid is the same size whatever is inside: the time and
    /// how it's going top left, the tick top right, the medicines in a
    /// tidy three-across grid at the bottom, and a thin bar of how much of
    /// it is taken.
    private var squareLid: some View {
        let doses = compartment.doses
        let shown = Array(doses.prefix(doses.count > 6 ? 5 : 6))
        let taken = doses.filter(\.isTaken).count

        return Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(compartment.time.label)
                                .font(.system(size: 22, weight: .heavy))
                                .monospacedDigit()
                                .kerning(-0.4)
                                .foregroundStyle(AppTheme.ColorToken.primaryText)
                            Text(status)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(statusInk)
                                .contentTransition(.opacity)
                        }
                        Spacer(minLength: 4)
                        squareBadge
                    }

                    Spacer(minLength: 8)

                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(36), spacing: 8), count: 3), alignment: .leading, spacing: 8) {
                        ForEach(shown) { dose in
                            pill(dose, size: 36)
                        }
                        if doses.count > shown.count {
                            Text("+\(doses.count - shown.count)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(AppTheme.ColorToken.secondaryText)
                                .frame(width: 36, height: 36)
                                .background(AppTheme.ColorToken.controlFill, in: .rect(cornerRadius: 10, style: .continuous))
                        }
                    }

                    // How much of this time is taken. On every lid, so the
                    // icons sit at the same height across the row.
                    Group {
                        Capsule()
                            .fill(AppTheme.ColorToken.ringTrack)
                            .frame(height: 4)
                            .overlay(alignment: .leading) {
                                GeometryReader { proxy in
                                    Capsule()
                                        .fill(compartment.isDone ? Urgency.healthy.tint : AppTheme.ColorToken.accent)
                                        .frame(width: proxy.size.width * CGFloat(taken) / CGFloat(doses.count))
                                }
                            }
                            .padding(.top, 12)
                            .animation(.snappy, value: taken)
                    }
                }
                .padding(14)
            }
            .background(squareFill, in: .rect(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(isNext ? AppTheme.ColorToken.accent : Color(hex: 0x28185A, opacity: 0.06), lineWidth: isNext ? 2 : 0.5)
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: compartment.isDone)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("\(compartment.time.label), \(status)")
    }

    /// Top right: a green tick once taken, an amber mark if missed, the
    /// medicine count otherwise.
    @ViewBuilder
    private var squareBadge: some View {
        if compartment.isDone {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Urgency.healthy.tint)
                .transition(.scale.combined(with: .opacity))
        } else if isMissed {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Urgency.low.tint)
        } else {
            Text("\(compartment.doses.count)")
                .font(.system(size: 13, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(isNext ? AppTheme.ColorToken.accent : AppTheme.ColorToken.secondaryText)
                .frame(minWidth: 26, minHeight: 26)
                .background(isNext ? AppTheme.ColorToken.accentSoft : AppTheme.ColorToken.controlFill, in: .circle)
                .accessibilityLabel("\(compartment.doses.count) medicines")
        }
    }

    private var squareFill: Color {
        if compartment.isDone { return Urgency.healthy.wash }
        if isMissed { return Urgency.low.wash }
        // The one to take next carries a hint of the accent.
        if isNext { return AppTheme.ColorToken.accentSoft.opacity(0.55) }
        return AppTheme.ColorToken.cardBackground
    }

    // MARK: Round

    private var roundLid: some View {
        let doses = compartment.doses
        let shown = doses.prefix(visibleLimit)

        return VStack(spacing: 8) {
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
                    pill(dose, size: 34)
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
        .padding(18)
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
    private func pill(_ dose: ScheduledDose, size: CGFloat) -> some View {
        Button {
            // An injection asks where it went before it's ticked off.
            if dose.medicine.type == .injection && !dose.isTaken {
                router.sheet = .injectionSite(dose)
            } else {
                withAnimation(.snappy) { store.toggle(dose) }
            }
        } label: {
            MedicineIconView(medicine: dose.medicine, size: size, isVibrant: true)
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
