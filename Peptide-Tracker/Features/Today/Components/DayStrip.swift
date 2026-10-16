import SwiftUI

/// A full-width strip of days, two weeks either side of today, that snaps
/// day by day. Each card shows how that day's doses went: a tick when all
/// were taken, a bar when some were, a hollow dot for days still to come.
struct DayStrip: View {
    @Environment(MedicineStore.self) private var store
    @Binding var selection: Date
    let today: Date

    static let range = -14...14

    @State private var scrolledDay: Date?

    private var days: [Date] { Self.range.map { today.adding(days: $0) } }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 8) {
                ForEach(days, id: \.self) { day in
                    DayCard(
                        day: day,
                        progress: progress(on: day),
                        isSelected: day == selection,
                        isToday: day == today,
                        isFuture: day > today
                    ) {
                        HapticFeedback.selection()
                        selection = day
                    }
                    .id(day)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $scrolledDay, anchor: .center)
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .onAppear { scrolledDay = selection }
        .onChange(of: selection) { _, day in
            withAnimation(.snappy) { scrolledDay = day }
        }
    }

    private func progress(on day: Date) -> DayCard.Progress {
        let doses = store.doses(on: day)
        let taken = doses.filter(\.isTaken).count
        return DayCard.Progress(taken: taken, total: doses.count)
    }
}

/// One day: "MON", "12", and how its doses went.
private struct DayCard: View {
    struct Progress {
        let taken: Int
        let total: Int
        var fraction: Double { total > 0 ? Double(taken) / Double(total) : 0 }
        var isComplete: Bool { total > 0 && taken == total }
    }

    let day: Date
    let progress: Progress
    let isSelected: Bool
    let isToday: Bool
    let isFuture: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                Text(day.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .kerning(0.4)
                    .foregroundStyle(isSelected ? .white.opacity(0.85) : AppTheme.ColorToken.secondaryText)
                Text(day.formatted(.dateTime.day()))
                    .font(.system(size: 21, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? .white : isToday ? AppTheme.ColorToken.accent : AppTheme.ColorToken.primaryText)
                indicator
                    .frame(height: 12)
            }
            .frame(width: 54, height: 82)
            .background(
                isSelected ? AppTheme.ColorToken.accent : AppTheme.ColorToken.cardBackground,
                in: .rect(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                // Today keeps a ring while another day is picked.
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(AppTheme.ColorToken.accent, lineWidth: 1.5)
                    .opacity(isToday && !isSelected ? 1 : 0)
            }
            .shadow(color: isSelected ? AppTheme.ColorToken.accent.opacity(0.35) : .clear, radius: 10, y: 6)
            .scaleEffect(isSelected ? 1.04 : 1)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isSelected)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var indicator: some View {
        if progress.total == 0 {
            Color.clear.frame(width: 6, height: 6)
        } else if isFuture {
            Circle()
                .strokeBorder(isSelected ? .white.opacity(0.8) : AppTheme.ColorToken.tertiaryText, lineWidth: 1.5)
                .frame(width: 7, height: 7)
        } else if progress.isComplete {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isSelected ? .white : Urgency.healthy.tint)
        } else {
            ZStack(alignment: .leading) {
                Capsule().fill(isSelected ? .white.opacity(0.35) : AppTheme.ColorToken.accent.opacity(0.18))
                Capsule()
                    .fill(isSelected ? .white : AppTheme.ColorToken.accent)
                    .frame(width: 24 * progress.fraction)
            }
            .frame(width: 24, height: 4)
        }
    }

    private var accessibilityText: String {
        let date = day.weekdayDayMonth
        guard progress.total > 0 else { return "\(date), no doses" }
        if isFuture { return "\(date), \(progress.total) doses planned" }
        return "\(date), \(progress.taken) of \(progress.total) taken"
    }
}
