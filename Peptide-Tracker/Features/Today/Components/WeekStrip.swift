import SwiftUI

/// A Sun–Sat row of days that pages a week at a time, with the picked day
/// in an accent circle and a dot under each day for how its doses went.
/// Below it, one label for the picked day ("Today, 16 Oct").
struct WeekStrip: View {
    @Environment(MedicineStore.self) private var store
    @Binding var selection: Date
    let today: Date

    /// Weeks you can page to, either side of this one.
    static let weekRange = -8...8
    /// Weekday, the 42 pt date circle and the status dot, with their gaps.
    static let rowHeight: CGFloat = 82

    @State private var shownWeek: Int?

    var body: some View {
        VStack(spacing: 14) {
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

            dateLabel
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
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                Text(day.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isToday ? AppTheme.ColorToken.accent : AppTheme.ColorToken.secondaryText)
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
