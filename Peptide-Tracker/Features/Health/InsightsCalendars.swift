import SwiftUI

// MARK: - Small month (year view)

/// One month of the year page: its name, then a tiny grid of days, each
/// filled with how that day went.
struct MiniMonth: View {
    let month: Date
    let summaries: [Date: DaySummary]

    @Environment(\.horizontalSizeClass) private var sizeClass
    private let calendar = Calendar.current

    /// iPad's cards are three times as wide, so everything in them grows.
    private var isLarge: Bool { sizeClass == .regular }
    private var columns: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: isLarge ? 4 : 1), count: 7) }

    var body: some View {
        let isThisMonth = calendar.isDate(.now, equalTo: month, toGranularity: .month)
        VStack(alignment: .leading, spacing: isLarge ? 12 : 6) {
            Text(month.formatted(.dateTime.month(isLarge ? .wide : .abbreviated)))
                .font(.system(size: isLarge ? 22 : 15, weight: .bold))
                .foregroundStyle(isThisMonth ? AppTheme.ColorToken.accent : AppTheme.ColorToken.primaryText)
            if isLarge {
                // Weekday letters, as there's room for them on iPad.
                LazyVGrid(columns: columns, spacing: 0) {
                    ForEach(Array(calendar.orderedVeryShortWeekdays.enumerated()), id: \.offset) { _, symbol in
                        Text(symbol)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.ColorToken.tertiaryText)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            LazyVGrid(columns: columns, spacing: isLarge ? 6 : 2) {
                ForEach(Array(calendar.gridDays(of: month).enumerated()), id: \.offset) { _, day in
                    if let day {
                        cell(day)
                    } else if isLarge {
                        Color.clear.frame(height: Self.largeCell)
                    } else {
                        Color.clear.aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
        .padding(isLarge ? 18 : 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.ColorToken.cardBackground, in: .rect(cornerRadius: isLarge ? 24 : 16, style: .continuous))
        .contentShape(.rect(cornerRadius: isLarge ? 24 : 16))
    }

    /// The day circle on iPad: a fixed size, so every row and every month
    /// card is the same height.
    private static let largeCell: CGFloat = 34

    @ViewBuilder
    private func cell(_ day: Date) -> some View {
        if isLarge { largeCell(day) } else { smallCell(day) }
    }

    private func largeCell(_ day: Date) -> some View {
        let status = summaries[day]?.status
        let isToday = calendar.isDateInToday(day)
        return Text("\(calendar.component(.day, from: day))")
            .font(.system(size: 15, weight: isToday ? .heavy : .semibold))
            .monospacedDigit()
            .minimumScaleFactor(0.7)
            .foregroundStyle(InsightsPalette.ink(status, isToday: isToday))
            .frame(width: Self.largeCell, height: Self.largeCell)
            .background(InsightsPalette.fill(status), in: .circle)
            .overlay {
                if isToday { Circle().strokeBorder(AppTheme.ColorToken.accent, lineWidth: 2) }
            }
            .frame(maxWidth: .infinity)
    }

    private func smallCell(_ day: Date) -> some View {
        let status = summaries[day]?.status
        let isToday = calendar.isDateInToday(day)
        return Text("\(calendar.component(.day, from: day))")
            .font(.system(size: 8.5, weight: isToday ? .heavy : .semibold))
            .monospacedDigit()
            .minimumScaleFactor(0.6)
            .foregroundStyle(InsightsPalette.ink(status, isToday: isToday))
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(InsightsPalette.fill(status), in: .circle)
            .overlay {
                if isToday { Circle().strokeBorder(AppTheme.ColorToken.accent, lineWidth: 1) }
            }
    }
}

// MARK: - Full month

/// The open month: weekday letters, a large day grid with each day's dose
/// ring, and arrows to the months either side. Tapping a day selects it.
struct MonthCalendar: View {
    let month: Date
    let summaries: [Date: DaySummary]
    let selectedDay: Date?
    let onSelect: (Date) -> Void
    let onStep: (Int) -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass
    private let calendar = Calendar.current

    /// Bigger days, rings and labels on iPad, where the card is far wider.
    private var isLarge: Bool { sizeClass == .regular }
    private var circle: CGFloat { isLarge ? 62 : 38 }
    private var cellHeight: CGFloat { isLarge ? 84 : 50 }
    private var columns: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: isLarge ? 8 : 4), count: 7) }

    var body: some View {
        VStack(spacing: isLarge ? 20 : 12) {
            HStack {
                arrow("chevron.backward", label: String(localized: "Previous month")) { onStep(-1) }
                Spacer()
                Text(month.formatted(.dateTime.month(.wide).year()))
                    .font(.system(size: isLarge ? 24 : 17, weight: .bold))
                    .contentTransition(.opacity)
                Spacer()
                arrow("chevron.forward", label: String(localized: "Next month")) { onStep(1) }
                    .disabled(isCurrentOrLater)
                    .opacity(isCurrentOrLater ? 0.3 : 1)
            }

            LazyVGrid(columns: columns, spacing: isLarge ? 8 : 4) {
                ForEach(Array(calendar.orderedVeryShortWeekdays.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.system(size: isLarge ? 16 : 12, weight: .semibold))
                        .foregroundStyle(AppTheme.ColorToken.tertiaryText)
                        .frame(maxWidth: .infinity)
                }
                ForEach(Array(calendar.gridDays(of: month).enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayButton(day)
                    } else {
                        Color.clear.frame(height: cellHeight)
                    }
                }
            }
        }
        .padding(isLarge ? 24 : 14)
        .background(AppTheme.ColorToken.cardBackground, in: .rect(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }

    private var isCurrentOrLater: Bool {
        guard let next = calendar.date(byAdding: .month, value: 1, to: month) else { return true }
        return next > .now
    }

    private func arrow(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: isLarge ? 18 : 15, weight: .bold))
                .foregroundStyle(AppTheme.ColorToken.primaryText)
                .frame(width: isLarge ? 44 : 36, height: isLarge ? 44 : 36)
                .background(AppTheme.ColorToken.controlFill, in: .circle)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(label)
    }

    private func dayButton(_ day: Date) -> some View {
        let summary = summaries[day]
        let status = summary?.status
        let isToday = calendar.isDateInToday(day)
        let isSelected = selectedDay == day
        return Button { onSelect(day) } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.system(size: isLarge ? 24 : 16, weight: isToday || isSelected ? .bold : .semibold))
                    .monospacedDigit()
                    .foregroundStyle(InsightsPalette.ink(status, isToday: isToday))
                    .frame(width: circle, height: circle)
                    .background(InsightsPalette.fill(status), in: .circle)
                    .overlay {
                        // A partly taken day shows how much as a ring.
                        if status == .partial, let summary {
                            ProgressRing(progress: summary.rate, lineWidth: isLarge ? 4 : 2.5, tint: AppTheme.ColorToken.accent, track: .clear)
                        }
                    }
                    .overlay {
                        Circle()
                            .strokeBorder(isSelected ? AppTheme.ColorToken.primaryText : (isToday ? AppTheme.ColorToken.accent : .clear), lineWidth: isLarge ? 2.5 : 2)
                            .padding(isLarge ? -4 : -3)
                    }
                // Doses still to come on this day.
                Circle()
                    .fill(status == .upcoming ? AppTheme.ColorToken.accent : .clear)
                    .frame(width: isLarge ? 7 : 5, height: isLarge ? 7 : 5)
            }
            .frame(maxWidth: .infinity, minHeight: cellHeight)
            .contentShape(.rect)
            .scaleEffect(isSelected ? 1.06 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(day, summary: summary))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func accessibilityLabel(_ day: Date, summary: DaySummary?) -> String {
        let date = day.formatted(.dateTime.weekday(.wide).day().month(.wide))
        guard let summary else { return String(localized: "\(date), no doses") }
        switch summary.status {
        case .upcoming: return String(localized: "\(date), \(summary.scheduled) doses to come")
        default: return String(localized: "\(date), \(summary.taken) of \(summary.due) doses taken")
        }
    }
}

// MARK: - Legend

struct InsightsLegend: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        let isLarge = sizeClass == .regular
        HStack(spacing: isLarge ? 28 : 16) {
            item(String(localized: "All taken"), fill: InsightsPalette.all)
            item(String(localized: "Some taken"), fill: InsightsPalette.partial)
            item("Missed", fill: InsightsPalette.missed)
        }
        .font(.system(size: isLarge ? 16 : 13, weight: .medium))
        .foregroundStyle(AppTheme.ColorToken.secondaryText)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func item(_ title: String, fill: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(fill).frame(width: sizeClass == .regular ? 15 : 12, height: sizeClass == .regular ? 15 : 12)
            Text(title)
        }
    }
}

// MARK: - Day detail

/// The selected day under the month: the date, how many doses were taken,
/// and each dose with its time and what happened — taken (and when, and
/// where for injections), missed, or still to come.
struct DayDetailCard: View {
    let day: Date
    let doses: [ScheduledDose]
    var mood: DailyCheckIn.Mood?
    var weight: WeightEntry?
    var unit: WeightUnit = .kg

    var body: some View {
        let now = Date.now
        let due = doses.filter { $0.isTaken || $0.scheduledAt <= now }
        let taken = due.filter(\.isTaken).count

        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(day.formatted(.dateTime.weekday(.wide)))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.ColorToken.accent)
                    Text(day.formatted(.dateTime.day().month(.wide)))
                        .font(.system(size: 22, weight: .heavy))
                        .kerning(-0.4)
                }
                Spacer(minLength: 8)
                if !due.isEmpty {
                    let rate = Double(taken) / Double(due.count)
                    ZStack {
                        ProgressRing(progress: rate, lineWidth: 5)
                        Text("\(taken)/\(due.count)")
                            .font(.system(size: 13, weight: .heavy))
                            .monospacedDigit()
                    }
                    .frame(width: 52, height: 52)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(taken) of \(due.count) doses taken")
                }
            }

            if mood != nil || weight != nil {
                HStack(spacing: 8) {
                    if let mood {
                        HStack(spacing: 6) {
                            mood.illustration
                                .resizable()
                                .scaledToFit()
                                .frame(width: 22, height: 22)
                            Text("Felt \(mood.title.lowercased())")
                        }
                        .foregroundStyle(mood.tint)
                        .padding(.leading, 4)
                        .padding(.trailing, 12)
                        .frame(height: 32)
                        .background(mood.tint.opacity(0.1), in: .capsule)
                    }
                    if let weight {
                        Label(unit.format(weight.kilograms), systemImage: "scalemass.fill")
                            .foregroundStyle(Color(hex: 0x22769A))
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .background(Color(hex: 0x30B0C7).opacity(0.12), in: .capsule)
                    }
                }
                .font(.system(size: 13, weight: .semibold))
            }

            if doses.isEmpty {
                VStack(spacing: 4) {
                    IllustrationView(.noDosesDay, width: 150)
                    Text("No doses on this day")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppTheme.ColorToken.secondaryText)
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(doses.enumerated()), id: \.element.id) { index, dose in
                        row(dose, now: now)
                            .rowDivider(index < doses.count - 1, inset: 50)
                    }
                }
            }
        }
        .padding(16)
        .background(AppTheme.ColorToken.cardBackground, in: .rect(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }

    private func row(_ dose: ScheduledDose, now: Date) -> some View {
        HStack(spacing: 12) {
            MedicineIconView(medicine: dose.medicine, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(dose.medicine.name)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                Text(detail(dose))
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            statusPill(dose, now: now)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    /// "8:00 · 1 injection · Left abdomen"
    private func detail(_ dose: ScheduledDose) -> String {
        var parts = [dose.time.label, dose.medicine.unit.format(dose.medicine.unitsPerIntake)]
        if let site = dose.site { parts.append(site.title) }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func statusPill(_ dose: ScheduledDose, now: Date) -> some View {
        if let takenAt = dose.takenAt {
            pill(String(localized: "Taken \(takenAt.formatted(date: .omitted, time: .shortened))"), symbol: "checkmark", fill: AppTheme.ColorToken.accentSoft, ink: AppTheme.ColorToken.accentInk)
        } else if dose.scheduledAt <= now {
            pill("Missed", symbol: "xmark", fill: InsightsPalette.missed, ink: InsightsPalette.missedInk)
        } else {
            pill(String(localized: "To come"), symbol: "clock", fill: AppTheme.ColorToken.controlFill, ink: AppTheme.ColorToken.secondaryText)
        }
    }

    private func pill(_ title: String, symbol: String, fill: Color, ink: Color) -> some View {
        Label(title, systemImage: symbol)
            .font(.system(size: 12, weight: .bold))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(ink)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(fill, in: .capsule)
            .fixedSize()
    }
}
