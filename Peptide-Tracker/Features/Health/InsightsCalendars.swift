import SwiftUI

// MARK: - Small month (year view)

/// One month of the year page: its name, then a tiny grid of days, each
/// filled with how that day went.
struct MiniMonth: View {
    let month: Date
    let summaries: [Date: DaySummary]

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)

    var body: some View {
        let isThisMonth = calendar.isDate(.now, equalTo: month, toGranularity: .month)
        VStack(alignment: .leading, spacing: 6) {
            Text(month.formatted(.dateTime.month(.abbreviated)))
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(isThisMonth ? AppTheme.ColorToken.accent : AppTheme.ColorToken.primaryText)
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(Array(calendar.gridDays(of: month).enumerated()), id: \.offset) { _, day in
                    if let day {
                        cell(day)
                    } else {
                        Color.clear.aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.ColorToken.cardBackground, in: .rect(cornerRadius: 16, style: .continuous))
        .contentShape(.rect(cornerRadius: 16))
    }

    private func cell(_ day: Date) -> some View {
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

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                arrow("chevron.backward", label: "Previous month") { onStep(-1) }
                Spacer()
                Text(month.formatted(.dateTime.month(.wide).year()))
                    .font(.system(size: 17, weight: .bold))
                    .contentTransition(.opacity)
                Spacer()
                arrow("chevron.forward", label: "Next month") { onStep(1) }
                    .disabled(isCurrentOrLater)
                    .opacity(isCurrentOrLater ? 0.3 : 1)
            }

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(calendar.orderedVeryShortWeekdays.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.ColorToken.tertiaryText)
                        .frame(maxWidth: .infinity)
                }
                ForEach(Array(calendar.gridDays(of: month).enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayButton(day)
                    } else {
                        Color.clear.frame(height: 50)
                    }
                }
            }
        }
        .padding(14)
        .background(AppTheme.ColorToken.cardBackground, in: .rect(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }

    private var isCurrentOrLater: Bool {
        guard let next = calendar.date(byAdding: .month, value: 1, to: month) else { return true }
        return next > .now
    }

    private func arrow(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.ColorToken.primaryText)
                .frame(width: 36, height: 36)
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
                    .font(.system(size: 16, weight: isToday || isSelected ? .bold : .semibold))
                    .monospacedDigit()
                    .foregroundStyle(InsightsPalette.ink(status, isToday: isToday))
                    .frame(width: 38, height: 38)
                    .background(InsightsPalette.fill(status), in: .circle)
                    .overlay {
                        // A partly taken day shows how much as a ring.
                        if status == .partial, let summary {
                            ProgressRing(progress: summary.rate, lineWidth: 2.5, tint: AppTheme.ColorToken.accent, track: .clear)
                        }
                    }
                    .overlay {
                        Circle()
                            .strokeBorder(isSelected ? AppTheme.ColorToken.primaryText : (isToday ? AppTheme.ColorToken.accent : .clear), lineWidth: 2)
                            .padding(-3)
                    }
                // Doses still to come on this day.
                Circle()
                    .fill(status == .upcoming ? AppTheme.ColorToken.accent : .clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .contentShape(.rect)
            .scaleEffect(isSelected ? 1.06 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(day, summary: summary))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func accessibilityLabel(_ day: Date, summary: DaySummary?) -> String {
        let date = day.formatted(.dateTime.weekday(.wide).day().month(.wide))
        guard let summary else { return "\(date), no doses" }
        switch summary.status {
        case .upcoming: return "\(date), \(summary.scheduled) doses to come"
        default: return "\(date), \(summary.taken) of \(summary.due) doses taken"
        }
    }
}

// MARK: - Legend

struct InsightsLegend: View {
    var body: some View {
        HStack(spacing: 16) {
            item("All taken", fill: InsightsPalette.all)
            item("Some taken", fill: InsightsPalette.partial)
            item("Missed", fill: InsightsPalette.missed)
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(AppTheme.ColorToken.secondaryText)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func item(_ title: String, fill: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(fill).frame(width: 12, height: 12)
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
            pill("Taken \(takenAt.formatted(date: .omitted, time: .shortened))", symbol: "checkmark", fill: AppTheme.ColorToken.accentSoft, ink: AppTheme.ColorToken.accentInk)
        } else if dose.scheduledAt <= now {
            pill("Missed", symbol: "xmark", fill: InsightsPalette.missed, ink: InsightsPalette.missedInk)
        } else {
            pill("To come", symbol: "clock", fill: AppTheme.ColorToken.controlFill, ink: AppTheme.ColorToken.secondaryText)
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
