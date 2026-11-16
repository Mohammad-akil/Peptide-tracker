import SwiftUI

/// The dose calendar, opened from the calendar button on Today: how each
/// day went, on a calendar like Apple's. The year
/// is twelve small months, three to a row; tap a month and it zooms open
/// full size; tap a day and its doses open underneath. Days are coloured by
/// how much was taken — everything, some of it, or none.
struct CalendarView: View {
    @Environment(MedicineStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Where on the year page the open month sits, so it zooms out of
    /// (and back into) its own card, like Calendar.
    @State private var zoomAnchor = UnitPoint.center
    /// Which way the last month step went, for the slide between months.
    @State private var stepsForward = true
    @Environment(\.dismiss) private var dismiss
    @State private var showsShare = false

    @State private var year = Calendar.current.component(.year, from: .now)
    /// The first day of the month that's open, or nil for the year.
    @State private var openMonth: Date?
    @State private var selectedDay: Date?

    private let calendar = Calendar.current

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            Color.clear.frame(height: 0).id(Self.topID)
            Group {
                if let month = openMonth {
                    monthPage(month)
                } else {
                    yearPage
                }
            }
            .padding(.horizontal, AppTheme.Spacing.medium)
            .padding(.top, 20)
            .padding(.bottom, AppTheme.Spacing.tabBarClearance)
        }
        .scrollIndicators(.hidden)
        // Opening or closing a month starts at the top, never mid-scroll.
        .onChange(of: openMonth == nil) { _, _ in proxy.scrollTo(Self.topID, anchor: .top) }
        }
        .safeAreaInset(edge: .top, spacing: 0) { topPanel }
    }

    /// The year's day summaries, from the query cache: computed once,
    /// refetched only when doses, medicines or the day change.
    private var summaries: [Date: DaySummary] { store.daySummaries(year: year) }

    private static let topID = "insights.top"

    /// Settles without overshoot, so the zoom never wobbles.
    private var spring: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.42, dampingFraction: 0.92)
    }

    /// The month's card position in the 3 × 4 grid, as a unit point.
    private func anchor(for month: Date) -> UnitPoint {
        let index = calendar.component(.month, from: month) - 1
        return UnitPoint(x: (Double(index % 3) * 2 + 1) / 6, y: 0.14 + Double(index / 3) * 0.24)
    }

    /// Year → month: the month grows out of its card while the year zooms
    /// past it; back again in reverse. Reduce Motion just cross-fades.
    private var monthTransition: AnyTransition {
        reduceMotion ? .opacity : .scale(scale: 0.32, anchor: zoomAnchor).combined(with: .opacity)
    }

    private var yearTransition: AnyTransition {
        reduceMotion ? .opacity : .scale(scale: 1.7, anchor: zoomAnchor).combined(with: .opacity)
    }

    // MARK: Top panel

    private var topPanel: some View {
        TopPanel(title: openMonth.map { $0.formatted(.dateTime.month(.wide)) } ?? "Calendar",
                 titleValue: openMonth.map { Double(calendar.component(.month, from: $0)) }) {
            Button { showsShare = true } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.ColorToken.primaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel("Share progress")
            .shareMoments(isPresented: $showsShare, start: .month)
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.ColorToken.primaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel("Close")
        } controls: {
            calendarControls
        }
    }

    private var calendarControls: some View {
            HStack(spacing: 12) {
                if openMonth != nil {
                    Button(action: closeMonth) {
                        Label(String(year), systemImage: "chevron.backward")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AppTheme.ColorToken.primaryText)
                            .frame(minHeight: 44)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back to \(String(year))")
                } else {
                    yearSwitcher
                }
                Spacer(minLength: 8)
                rateChip
            }
            .padding(.horizontal, 20)
    }

    private var yearSwitcher: some View {
        let thisYear = calendar.component(.year, from: .now)
        return HStack(spacing: 4) {
            stepButton("chevron.backward", label: "Previous year") { changeYear(by: -1) }
            Text(verbatim: String(year))
                .font(.system(size: 20, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(year)))
                .frame(minWidth: 56)
            stepButton("chevron.forward", label: "Next year") { changeYear(by: 1) }
                .disabled(year >= thisYear)
                .opacity(year >= thisYear ? 0.3 : 1)
        }
    }

    private func stepButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
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

    /// "92% taken" for the year, or the open month.
    @ViewBuilder
    private var rateChip: some View {
        let range = openMonth.map { month in summaries.filter { calendar.isDate($0.key, equalTo: month, toGranularity: .month) } } ?? summaries
        let due = range.values.reduce(0) { $0 + $1.due }
        let taken = range.values.reduce(0) { $0 + $1.taken }
        if due > 0 {
            let rate = Double(taken) / Double(due)
            HStack(spacing: 6) {
                ProgressRing(progress: rate, lineWidth: 3)
                    .frame(width: 16, height: 16)
                Text("\(Int((rate * 100).rounded()))% taken")
                    .font(.system(size: 14, weight: .semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: rate))
            }
            .foregroundStyle(AppTheme.ColorToken.accentInk)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(AppTheme.ColorToken.accentSoft, in: .capsule)
        }
    }

    // MARK: Year

    private var months: [Date] {
        (1...12).compactMap { calendar.date(from: DateComponents(year: year, month: $0, day: 1)) }
    }

    private var yearPage: some View {
        VStack(spacing: 20) {
            // Until there's anything to colour in, say what this will show.
            if summaries.values.allSatisfy({ $0.due == 0 }) {
                VStack(spacing: 6) {
                    IllustrationView(.calendarInsights, width: 200)
                    Text("Your year at a glance")
                        .font(.system(size: 20, weight: .heavy))
                    Text("Each day fills in purple as you tick off doses. Tap a month to see it up close.")
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.ColorToken.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(AppTheme.ColorToken.cardBackground, in: .rect(cornerRadius: AppTheme.Radius.card, style: .continuous))
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: 3), spacing: 10) {
                ForEach(months, id: \.self) { month in
                    Button { open(month) } label: {
                        MiniMonth(month: month, summaries: summaries)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel(month.formatted(.dateTime.month(.wide).year()))
                    .accessibilityHint("Opens the month")
                }
            }
            InsightsLegend()
        }
        .transition(yearTransition)
    }

    // MARK: Month

    private func monthPage(_ month: Date) -> some View {
        VStack(spacing: 16) {
            MonthCalendar(
                month: month,
                summaries: summaries,
                selectedDay: selectedDay,
                onSelect: select,
                onStep: { step(month, by: $0) }
            )
            // Stepping months slides the grid across; the card keeps its
            // height (always six weeks), so nothing below jumps.
            .id(month)
            .transition(.asymmetric(
                insertion: .move(edge: stepsForward ? .trailing : .leading).combined(with: .opacity),
                removal: .move(edge: stepsForward ? .leading : .trailing).combined(with: .opacity)
            ))
            .clipped()

            InsightsLegend()

            if let day = selectedDay {
                DayDetailCard(
                    day: day,
                    doses: store.doses(on: day),
                    mood: store.checkIn(on: day)?.mood,
                    weight: store.weight(on: day),
                    unit: store.settings.weightUnit
                )
                    .id(day)
                    .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
            }
        }
        .transition(monthTransition)
    }

    // MARK: Actions

    private func open(_ month: Date) {
        HapticFeedback.selection()
        // Set before animating, so the transition reads the right anchor.
        zoomAnchor = anchor(for: month)
        withAnimation(spring) {
            openMonth = month
            // Open on today when it's in this month, like Calendar.
            selectedDay = calendar.isDate(.now, equalTo: month, toGranularity: .month) ? Date.now.startOfDay : nil
        }
    }

    private func closeMonth() {
        HapticFeedback.selection()
        withAnimation(spring) {
            openMonth = nil
            selectedDay = nil
        }
    }

    private func select(_ day: Date) {
        HapticFeedback.selection()
        withAnimation(spring) {
            selectedDay = selectedDay == day ? nil : day
        }
    }

    /// Previous or next month; crossing a year boundary moves the year too.
    private func step(_ month: Date, by value: Int) {
        guard let next = calendar.date(byAdding: .month, value: value, to: month) else { return }
        HapticFeedback.selection()
        let nextYear = calendar.component(.year, from: next)
        stepsForward = value > 0
        // Closing later zooms back into this month's card.
        zoomAnchor = anchor(for: next)
        withAnimation(spring) {
            if nextYear != year { year = nextYear }
            openMonth = next
            selectedDay = nil
        }
    }

    private func changeYear(by value: Int) {
        HapticFeedback.selection()
        withAnimation(.snappy) { year += value }
    }

    // MARK: Data

    /// Every day of `year` that had or has doses, by its start of day.
    static func summaries(year: Int, store: MedicineStore, calendar: Calendar) -> [Date: DaySummary] {
        guard let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let end = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) else { return [:] }
        let now = Date.now
        var result: [Date: DaySummary] = [:]
        var day = start
        while day < end {
            let doses = store.doses(on: day)
            if !doses.isEmpty {
                let due = doses.filter { $0.isTaken || $0.scheduledAt <= now }
                result[day] = DaySummary(scheduled: doses.count, due: due.count, taken: due.filter(\.isTaken).count)
            }
            day = day.adding(days: 1)
        }
        return result
    }
}

// MARK: - Day summary

/// One day's doses: how many were scheduled, how many are due by now, and
/// how many of those were taken.
struct DaySummary: Equatable {
    let scheduled: Int
    let due: Int
    let taken: Int

    enum Status { case upcoming, all, partial, missed }

    var status: Status {
        guard due > 0 else { return .upcoming }
        if taken == due { return .all }
        return taken == 0 ? .missed : .partial
    }

    var rate: Double { due > 0 ? Double(taken) / Double(due) : 0 }
}

/// The day colours, shared by the small and large calendars and the legend.
enum InsightsPalette {
    static let all = AppTheme.ColorToken.accent
    static let partial = AppTheme.ColorToken.accentMuted
    static let missed = Color(light: 0xF6D5D2, dark: 0x4A1F1C)
    static let missedInk = Color(light: 0xA12A21, dark: 0xF2A49C)

    static func fill(_ status: DaySummary.Status?) -> Color {
        switch status {
        case .all: all
        case .partial: partial
        case .missed: missed
        case .upcoming, nil: .clear
        }
    }

    static func ink(_ status: DaySummary.Status?, isToday: Bool) -> Color {
        switch status {
        case .all: .white
        case .partial: AppTheme.ColorToken.accentInk
        case .missed: missedInk
        case .upcoming, nil: isToday ? AppTheme.ColorToken.accent : AppTheme.ColorToken.primaryText
        }
    }
}

// MARK: - Calendar maths

extension Calendar {
    /// The month's days, with nil for the blank cells before the 1st so the
    /// grid lines up under the right weekday.
    /// Always six weeks (42 cells), padded with blanks at the end, so every
    /// month — four, five or six weeks long — is the same height.
    func gridDays(of month: Date) -> [Date?] {
        guard let range = range(of: .day, in: .month, for: month) else { return [] }
        let firstWeekday = component(.weekday, from: month)
        let blanks = (firstWeekday - self.firstWeekday + 7) % 7
        let days: [Date?] = range.compactMap { date(byAdding: .day, value: $0 - 1, to: month) }
        let cells = Array(repeating: nil, count: blanks) + days
        return cells + Array(repeating: nil, count: max(0, 42 - cells.count))
    }

    /// "M T W T F S S", starting on the user's first weekday.
    var orderedVeryShortWeekdays: [String] {
        let symbols = veryShortStandaloneWeekdaySymbols
        let start = firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }
}

#Preview {
    CalendarView()
        .environment(MedicineStore.preview())
}
