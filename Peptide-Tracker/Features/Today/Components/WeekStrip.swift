import SwiftUI

/// A Sun–Sat row of days that pages a week at a time, with the picked day
/// in an accent circle and a dot under each day for how its doses went.
/// Below it, one label for the picked day ("Today, 16 Oct") and a grabber:
/// dragging down unrolls the whole month, following the finger, and it
/// settles open or closed on release. Picking a day in the month folds it
/// back to the week.
struct WeekStrip: View {
    @Environment(MedicineStore.self) private var store
    @Binding var selection: Date
    let today: Date

    /// Weeks you can page to, either side of this one.
    static let weekRange = -8...8
    /// Weekday, the 42 pt date circle and the status dot, with their gaps.
    static let rowHeight: CGFloat = 82

    /// A day in the month grid, without the weekday above it.
    static let monthRowHeight: CGFloat = 54
    /// The weekday letters over the month grid, and the gap under them.
    static let monthHeaderHeight: CGFloat = 22

    @State private var shownWeek: Int?
    @State private var shownMonth: Int?
    /// 0 shows the week, 1 the month; in between while dragging.
    @State private var expansion: CGFloat = 0
    /// `expansion` when the current drag began; nil when not dragging.
    @State private var dragStart: CGFloat?

    private var isExpanded: Bool { expansion > 0.5 }

    var body: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .top) {
                weekPager
                    .opacity(Double(max(0, 1 - expansion * 2.5)))
                    .allowsHitTesting(!isExpanded)
                if expansion > 0 {
                    monthPager
                        .opacity(Double(min(1, max(0, expansion * 2 - 0.3))))
                        .allowsHitTesting(isExpanded)
                }
            }
            // Grows with the drag and clips, so the month unrolls downwards.
            .frame(height: Self.rowHeight + (monthHeight - Self.rowHeight) * expansion, alignment: .top)
            .clipped()
            // Months of five and six weeks differ in height.
            .animation(.snappy, value: shownMonth)

            VStack(spacing: 10) {
                dateLabel
                grabber
            }
        }
        .contentShape(.rect)
        .simultaneousGesture(expandGesture)
    }

    // MARK: Week

    private var weekPager: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(Self.weekRange, id: \.self) { offset in
                    week(offset)
                        .containerRelativeFrame(.horizontal)
                        .id(offset)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $shownWeek)
        // A sideways scroll view takes all the height it's offered;
        // pin it to one row of days.
        .frame(height: Self.rowHeight)
        .onAppear { shownWeek = weekOffset(of: selection) }
        .onChange(of: selection) { _, day in
            withAnimation(.snappy) {
                shownWeek = weekOffset(of: day)
                if expansion > 0 { shownMonth = monthOffset(of: day) }
            }
        }
    }

    private func week(_ offset: Int) -> some View {
        let start = weekStart(offset)
        return HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { index in
                let day = start.adding(days: index)
                DayCell(
                    day: day,
                    status: status(on: day),
                    isSelected: day == selection,
                    isToday: day == today
                ) {
                    HapticFeedback.selection()
                    withAnimation(.snappy) { selection = day }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: Month

    /// Months that overlap the weeks you can page to.
    private var monthRange: ClosedRange<Int> {
        let first = weekStart(Self.weekRange.lowerBound)
        let last = weekStart(Self.weekRange.upperBound).adding(days: 6)
        return monthOffset(of: first)...monthOffset(of: last)
    }

    private var monthPager: some View {
        VStack(spacing: 0) {
            // Weekday names, in the week row's place, so they hold still
            // while the grid unrolls under them.
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { index in
                    Text(weekStart(0).adding(days: index).formatted(.dateTime.weekday(.abbreviated)))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.ColorToken.secondaryText)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: Self.monthHeaderHeight, alignment: .top)

            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 0) {
                    ForEach(monthRange, id: \.self) { offset in
                        month(offset)
                            .containerRelativeFrame(.horizontal)
                            .id(offset)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $shownMonth)
            .frame(height: CGFloat(rows(in: shownMonth ?? monthOffset(of: selection))) * Self.monthRowHeight, alignment: .top)
        }
        .onAppear { shownMonth = monthOffset(of: selection) }
        .onChange(of: shownMonth) { _, month in
            // Swiping to another month picks a day in it, as Calendar does:
            // today if it's there, otherwise the first day you can pick.
            guard let month, month != monthOffset(of: selection) else { return }
            let days = monthDays(month).filter(isPickable)
            guard let day = days.first(where: { $0 == today }) ?? days.first else { return }
            HapticFeedback.selection()
            selection = day
        }
    }

    private func month(_ offset: Int) -> some View {
        let start = monthStart(offset)
        let gridStart = Calendar.current.dateInterval(of: .weekOfYear, for: start)?.start ?? start
        return VStack(spacing: 0) {
            ForEach(0..<rows(in: offset), id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { column in
                        let day = gridStart.adding(days: row * 7 + column)
                        Group {
                            if Calendar.current.isDate(day, equalTo: start, toGranularity: .month) {
                                DayCell(
                                    day: day,
                                    status: status(on: day),
                                    isSelected: day == selection,
                                    isToday: day == today,
                                    showsWeekday: false
                                ) {
                                    HapticFeedback.selection()
                                    withAnimation(.snappy) { selection = day }
                                    setExpanded(false)
                                }
                                .disabled(!isPickable(day))
                                .opacity(isPickable(day) ? 1 : 0.35)
                            } else {
                                Color.clear
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: Self.monthRowHeight, alignment: .top)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
    }

    /// The month grid's full height for the month on show.
    private var monthHeight: CGFloat {
        Self.monthHeaderHeight + CGFloat(rows(in: shownMonth ?? monthOffset(of: selection))) * Self.monthRowHeight
    }

    // MARK: Expanding

    /// The 20 × 3 pt handle under the date. Tapping it toggles the month.
    private var grabber: some View {
        Button {
            setExpanded(!isExpanded)
        } label: {
            Capsule()
                .fill(AppTheme.ColorToken.tertiaryText.opacity(0.55))
                .frame(width: 20, height: 3)
                .frame(width: 60, height: 14)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isExpanded ? "Show week" : "Show month")
    }

    /// Vertical drags anywhere on the strip follow the finger; sideways
    /// ones are left to the week and month pagers.
    private var expandGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                if dragStart == nil {
                    guard abs(value.translation.height) > abs(value.translation.width) else { return }
                    dragStart = expansion
                    if shownMonth == nil { shownMonth = monthOffset(of: selection) }
                }
                guard let dragStart else { return }
                let travel = max(monthHeight - Self.rowHeight, 1)
                expansion = min(max(dragStart + value.translation.height / travel, 0), 1)
            }
            .onEnded { value in
                guard let start = dragStart else { return }
                dragStart = nil
                // Where a flick would carry it, so a quick swipe is enough.
                let travel = max(monthHeight - Self.rowHeight, 1)
                setExpanded(start + value.predictedEndTranslation.height / travel > 0.5, from: start)
            }
    }

    /// Settles open or closed. `start` is where a drag began, so the tick
    /// plays only when the strip actually changes state.
    private func setExpanded(_ open: Bool, from start: CGFloat? = nil) {
        if open != ((start ?? expansion) > 0.5) { HapticFeedback.selection() }
        if open { shownMonth = monthOffset(of: selection) }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            expansion = open ? 1 : 0
        }
    }

    /// "Today, 16 Oct", or the picked day. The way back to today sits in
    /// the panel's top corner, beside the bell.
    private var dateLabel: some View {
        Text(dayName)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(selection == today ? AppTheme.ColorToken.accent : AppTheme.ColorToken.primaryText)
            .contentTransition(.opacity)
            .animation(.snappy, value: selection)
    }

    private var dayName: String {
        let date = selection.formatted(.dateTime.day().month(.abbreviated))
        switch Calendar.current.days(from: today, to: selection) {
        case 0: return "Today, \(date)"
        case -1: return "Yesterday, \(date)"
        case 1: return "Tomorrow, \(date)"
        default: return "\(selection.formatted(.dateTime.weekday(.abbreviated))), \(date)"
        }
    }

    // MARK: Dates

    private func weekStart(_ offset: Int) -> Date {
        let start = Calendar.current.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        return start.adding(days: offset * 7)
    }

    private func weekOffset(of day: Date) -> Int {
        let days = Calendar.current.days(from: weekStart(0), to: day)
        return Int((Double(days) / 7).rounded(.down))
    }

    private func monthStart(_ offset: Int) -> Date {
        let start = Calendar.current.dateInterval(of: .month, for: today)?.start ?? today
        return Calendar.current.date(byAdding: .month, value: offset, to: start) ?? start
    }

    private func monthOffset(of day: Date) -> Int {
        let calendar = Calendar.current
        let from = calendar.dateComponents([.year, .month], from: today)
        let to = calendar.dateComponents([.year, .month], from: day)
        return ((to.year ?? 0) - (from.year ?? 0)) * 12 + (to.month ?? 0) - (from.month ?? 0)
    }

    /// Every day of a month, in order.
    private func monthDays(_ offset: Int) -> [Date] {
        let start = monthStart(offset)
        let count = Calendar.current.range(of: .day, in: .month, for: start)?.count ?? 30
        return (0..<count).map { start.adding(days: $0) }
    }

    /// Weeks the month spans, so the grid is only as tall as it needs.
    private func rows(in offset: Int) -> Int {
        let start = monthStart(offset)
        let gridStart = Calendar.current.dateInterval(of: .weekOfYear, for: start)?.start ?? start
        let leading = Calendar.current.days(from: gridStart, to: start)
        return Int((Double(leading + monthDays(offset).count) / 7).rounded(.up))
    }

    /// Days inside the weeks the strip can page to.
    private func isPickable(_ day: Date) -> Bool {
        Self.weekRange.contains(weekOffset(of: day))
    }

    private func status(on day: Date) -> DayCell.Status {
        let doses = store.doses(on: day)
        guard !doses.isEmpty else { return .none }
        if day > today { return .planned }
        let taken = doses.filter(\.isTaken).count
        if taken == doses.count { return .complete }
        return taken > 0 || day == today ? .partial : .missed
    }
}

/// "Sun" over "11" in a circle when picked, with a small status dot.
private struct DayCell: View {
    enum Status { case none, planned, partial, missed, complete }

    let day: Date
    let status: Status
    let isSelected: Bool
    let isToday: Bool
    /// Off in the month grid, where the weekdays head the columns.
    var showsWeekday = true
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                if showsWeekday {
                    Text(day.formatted(.dateTime.weekday(.abbreviated)))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isToday ? AppTheme.ColorToken.accent : AppTheme.ColorToken.secondaryText)
                }
                Text(day.formatted(.dateTime.day()))
                    .font(.system(size: 19, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? .white : isToday ? AppTheme.ColorToken.accent : AppTheme.ColorToken.primaryText)
                    .frame(width: 42, height: 42)
                    .background {
                        Circle()
                            .fill(AppTheme.ColorToken.accent)
                            .scaleEffect(isSelected ? 1 : 0.4)
                            .opacity(isSelected ? 1 : 0)
                    }
                    .animation(.spring(response: 0.32, dampingFraction: 0.7), value: isSelected)
                dot
                    .frame(height: 6)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var dot: some View {
        switch status {
        case .none:
            Color.clear.frame(width: 6, height: 6)
        case .planned:
            Circle().strokeBorder(AppTheme.ColorToken.tertiaryText, lineWidth: 1.2).frame(width: 6, height: 6)
        case .partial:
            Circle().fill(AppTheme.ColorToken.accent).frame(width: 6, height: 6)
        case .missed:
            Circle().fill(Urgency.low.tint).frame(width: 6, height: 6)
        case .complete:
            Circle().fill(Urgency.healthy.tint).frame(width: 6, height: 6)
        }
    }

    private var accessibilityText: String {
        let date = day.weekdayDayMonth
        switch status {
        case .none: return date
        case .planned: return "\(date), doses planned"
        case .partial: return "\(date), some doses taken"
        case .missed: return "\(date), doses missed"
        case .complete: return "\(date), all doses taken"
        }
    }
}
