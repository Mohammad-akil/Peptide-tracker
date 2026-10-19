import SwiftUI

/// The weekday names over a Sun–Sat row of days that pages a week at a time,
/// with the picked day in an accent circle and a dot under each day for how
/// its doses went. Below it, one label for the picked day ("Today, 16 Oct")
/// and a grabber.
///
/// Dragging down unrolls the whole month around the picked week: that row
/// holds still while the weeks above slide down into view and the ones below
/// are revealed, following the finger. On release it springs open or closed
/// from the finger's speed. Picking a day in the month folds back to its week.
struct WeekStrip: View {
    @Environment(MedicineStore.self) private var store
    @Binding var selection: Date
    let today: Date

    /// Weeks you can page to, either side of this one.
    static let weekRange = -8...8
    /// One row of days: the 42 pt date circle, the status dot, and room
    /// between rows. The same in the week and the month, so they line up.
    static let rowHeight: CGFloat = 58
    /// The weekday names, and the gap under them that keeps them clear of
    /// the circles.
    private static let headerHeight: CGFloat = 18
    private static let headerGap: CGFloat = 8

    @State private var shownWeek: Int?
    /// The month on show while the month is open.
    @State private var shownMonth = 0
    /// Whether the month grid is drawn in place of the week pager; true
    /// from the start of a drag until the strip has settled closed.
    @State private var showsMonth = false
    /// 0 shows the week, 1 the month; in between while dragging.
    @State private var expansion: CGFloat = 0
    /// `expansion` when the current drag began; nil when not dragging.
    @State private var dragStart: CGFloat?
    /// The drag's direction, settled by its first movement.
    @State private var dragAxis: Axis?
    /// Which way the last month change went, so the grid slides that way.
    @State private var monthMovesForward = true
    /// When the last up/down drag ended. A button under the finger as it
    /// lifts (the grabber rides down with the drag) would count that as a
    /// tap, so taps this close to a drag are ignored.
    @State private var lastDragEnded = Date.distantPast
    /// True while a drag is in progress; drops back on its own if the
    /// system cancels the drag, which never calls `onEnded`.
    @GestureState private var isDragging = false

    /// A tap that is really the end of a drag.
    private var isDragRelease: Bool {
        dragStart != nil || Date.now.timeIntervalSince(lastDragEnded) < 0.35
    }

    private var isExpanded: Bool { expansion > 0.5 }

    var body: some View {
        VStack(spacing: 0) {
            weekdayHeader
                .padding(.bottom, Self.headerGap)

            ZStack(alignment: .top) {
                // Kept while hidden so it stays on the picked week, ready to
                // show again without a jump.
                weekPager
                    .opacity(showsMonth ? 0 : 1)
                    .allowsHitTesting(!showsMonth)
                if showsMonth {
                    monthGrid(shownMonth)
                        // Collapsed, only the picked week's row shows; the
                        // rows above slide down into place as it opens.
                        .offset(y: -CGFloat(anchorRow) * Self.rowHeight * (1 - expansion))
                        .id(shownMonth)
                        .transition(.push(from: monthMovesForward ? .trailing : .leading))
                }
            }
            .frame(height: Self.rowHeight + (monthHeight - Self.rowHeight) * expansion, alignment: .top)
            .clipped()

            VStack(spacing: 10) {
                dateLabel
                grabber
            }
            .padding(.top, 6)
        }
        .contentShape(.rect)
        .simultaneousGesture(dragGesture)
        .onChange(of: selection) { _, day in
            // Picked from outside the open month (Today, or swiping the
            // doses): slide the grid to that day's month.
            let month = monthOffset(of: day)
            guard showsMonth, month != shownMonth, monthRange.contains(month) else { return }
            monthMovesForward = month > shownMonth
            withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) { shownMonth = month }
        }
        .onChange(of: isDragging) { _, dragging in
            // Cancelled mid-drag: settle wherever it's nearer.
            guard !dragging, let start = dragStart else { return }
            endVerticalDrag(open: isExpanded, start: start, velocity: 0)
        }
    }

    /// "Sun Mon Tue…", with today's column in accent while its week shows.
    private var weekdayHeader: some View {
        let start = weekStart(0)
        let showsThisWeek = !showsMonth && shownWeek == 0
        return HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { index in
                let day = start.adding(days: index)
                Text(day.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(showsThisWeek && day == today ? AppTheme.ColorToken.accent : AppTheme.ColorToken.secondaryText)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: Self.headerHeight)
        .animation(.snappy, value: showsThisWeek)
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
            withAnimation(.snappy) { shownWeek = weekOffset(of: day) }
        }
    }

    private func week(_ offset: Int) -> some View {
        let start = weekStart(offset)
        return HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { index in
                dayCell(start.adding(days: index))
            }
        }
        .padding(.horizontal, 8)
        .frame(height: Self.rowHeight, alignment: .top)
    }

    // MARK: Month

    /// The month's weeks, in rows the same as the week pager's.
    private func monthGrid(_ offset: Int) -> some View {
        let start = monthStart(offset)
        let gridStart = Calendar.current.dateInterval(of: .weekOfYear, for: start)?.start ?? start
        return VStack(spacing: 0) {
            ForEach(0..<rows(in: offset), id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { column in
                        let day = gridStart.adding(days: row * 7 + column)
                        if Calendar.current.isDate(day, equalTo: start, toGranularity: .month) {
                            dayCell(day)
                        } else {
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                }
                .frame(height: Self.rowHeight, alignment: .top)
            }
        }
        .padding(.horizontal, 8)
    }

    private func dayCell(_ day: Date) -> some View {
        DayCell(day: day, status: status(on: day), isSelected: day == selection, isToday: day == today) {
            guard !isDragRelease else { return }
            HapticFeedback.selection()
            withAnimation(.snappy) { selection = day }
            if showsMonth { setExpanded(false) }
        }
        .disabled(!isPickable(day))
        .opacity(isPickable(day) ? 1 : 0.35)
        .frame(maxWidth: .infinity)
    }

    /// The row of the picked day in the month on show; the row the month
    /// folds into.
    private var anchorRow: Int {
        guard monthOffset(of: selection) == shownMonth else { return 0 }
        let start = monthStart(shownMonth)
        let gridStart = Calendar.current.dateInterval(of: .weekOfYear, for: start)?.start ?? start
        return Calendar.current.days(from: gridStart, to: selection) / 7
    }

    private var monthHeight: CGFloat {
        CGFloat(rows(in: showsMonth ? shownMonth : monthOffset(of: selection))) * Self.rowHeight
    }

    /// Months that overlap the weeks you can page to.
    private var monthRange: ClosedRange<Int> {
        let first = weekStart(Self.weekRange.lowerBound)
        let last = weekStart(Self.weekRange.upperBound).adding(days: 6)
        return monthOffset(of: first)...monthOffset(of: last)
    }

    /// Pages the open month. Like Calendar, the new month picks a day:
    /// today if it's there, otherwise the first day you can pick.
    private func showMonth(_ offset: Int) {
        guard monthRange.contains(offset), offset != shownMonth else { return }
        let days = monthDays(offset).filter(isPickable)
        guard let day = days.first(where: { $0 == today }) ?? days.first else { return }
        HapticFeedback.selection()
        monthMovesForward = offset > shownMonth
        withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) {
            shownMonth = offset
            selection = day
        }
    }

    // MARK: Expanding

    /// The 20 × 3 pt handle under the date. Tapping it toggles the month.
    private var grabber: some View {
        Button {
            guard !isDragRelease else { return }
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

    /// Up and down drags anywhere on the strip open and close the month,
    /// following the finger. Sideways ones page the week (its own scroll
    /// view) or, while open, the month.
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($isDragging) { _, dragging, _ in dragging = true }
            .onChanged { value in
                if dragAxis == nil {
                    dragAxis = abs(value.translation.height) > abs(value.translation.width) ? .vertical : .horizontal
                }
                guard dragAxis == .vertical else { return }
                if dragStart == nil {
                    dragStart = expansion
                    openMonthGrid()
                }
                guard let dragStart else { return }
                let raw = dragStart + value.translation.height / travel
                // A little give past either end, as scroll views have.
                expansion = raw > 1 ? 1 + (raw - 1) * 0.15 : raw < 0 ? raw * 0.15 : raw
                expansion = min(max(expansion, 0), 1.06)
            }
            .onEnded { value in
                defer { dragAxis = nil }
                if dragAxis == .horizontal {
                    if showsMonth, isExpanded, abs(value.predictedEndTranslation.width) > 60 {
                        showMonth(shownMonth + (value.predictedEndTranslation.width < 0 ? 1 : -1))
                    }
                    return
                }
                guard let start = dragStart else { return }
                // Where a flick would carry it, so a quick swipe is enough.
                let open = start + value.predictedEndTranslation.height / travel > 0.5
                endVerticalDrag(open: open, start: start, velocity: value.velocity.height / travel)
            }
    }

    private func endVerticalDrag(open: Bool, start: CGFloat, velocity: CGFloat) {
        dragStart = nil
        dragAxis = nil
        lastDragEnded = .now
        setExpanded(open, from: start, velocity: velocity)
    }

    /// How far the finger moves to open the month fully.
    private var travel: CGFloat { max(monthHeight - Self.rowHeight, 1) }

    /// Draws the month in the week's place. At `expansion` 0 it shows just
    /// the picked week's row, so the swap can't be seen.
    private func openMonthGrid() {
        guard !showsMonth else { return }
        shownMonth = monthOffset(of: selection)
        showsMonth = true
    }

    /// Springs open or closed. `start` is where a drag began, so the tick
    /// plays only when the state changes; `velocity` (in strip heights a
    /// second) carries the finger's speed into the spring.
    private func setExpanded(_ open: Bool, from start: CGFloat? = nil, velocity: CGFloat = 0) {
        if open != ((start ?? expansion) > 0.5) { HapticFeedback.selection() }
        openMonthGrid()
        let target: CGFloat = open ? 1 : 0
        let distance = target - expansion
        let initialVelocity = abs(distance) > 0.01 ? min(max(velocity / distance, -12), 12) : 0
        withAnimation(.interpolatingSpring(duration: 0.45, bounce: 0.1, initialVelocity: initialVelocity)) {
            expansion = target
        } completion: {
            // Settled closed: hand back to the week pager, on the same week.
            guard !open, expansion == 0, dragStart == nil else { return }
            showsMonth = false
        }
    }

    // MARK: Label

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

/// "11" in a circle when picked, with a small status dot. The weekday sits
/// in the strip's header above.
private struct DayCell: View {
    enum Status { case none, planned, partial, missed, complete }

    let day: Date
    let status: Status
    let isSelected: Bool
    let isToday: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 4) {
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
