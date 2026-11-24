import SwiftUI

/// Opened from the mood button on Today: pick today's mood, see the last
/// two weeks, and "See all" for the full year as a GitHub-style grid.
struct MoodSheet: View {
    @Environment(MedicineStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var showsShare = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.cardGap) {
                    MoodCard()

                    NavigationLink {
                        MoodHistoryView()
                    } label: {
                        HStack(spacing: 14) {
                            SettingsTile(symbol: "square.grid.3x3.fill", tint: AppTheme.ColorToken.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("See all")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(AppTheme.ColorToken.primaryText)
                                Text("\(loggedRecently) days logged in the last 6 months")
                                    .font(.system(size: 13))
                                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                            }
                            Spacer(minLength: 8)
                            Chevron()
                        }
                        .padding(16)
                        .groupedCard()
                        .contentShape(.rect)
                    }
                    .buttonStyle(.pressable)
                }
                .padding(.horizontal, AppTheme.Spacing.medium)
                .padding(.top, 8)
                .padding(.bottom, AppTheme.Spacing.large)
            }
            .scrollIndicators(.hidden)
            .background(AppTheme.ColorToken.background.ignoresSafeArea())
            .navigationTitle("Mood")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CompatToolbarRoleButton(role: .close) { dismiss() }
                        .tint(AppTheme.ColorToken.primaryText)
                }
                if !store.checkIns.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Share", systemImage: "square.and.arrow.up") { showsShare = true }
                            .tint(AppTheme.ColorToken.primaryText)
                    }
                }
            }
            .shareMoments(isPresented: $showsShare, start: .mood)
        }
    }

    private var loggedRecently: Int {
        let since = Date.now.startOfDay.adding(days: -182)
        return store.checkIns.filter { $0.day > since }.count
    }
}

// MARK: - History

/// The whole year of moods: a GitHub-style grid (a column per week, a row
/// per weekday, each square in that day's mood colour), a few numbers, and
/// how the moods break down. Tap a square to see its day.
struct MoodHistoryView: View {
    @Environment(MedicineStore.self) private var store
    @State private var selectedDay: Date?
    /// The grid's width, measured, so the squares fill it edge to edge.
    @State private var gridWidth: CGFloat = 320

    private let calendar = Calendar.current
    /// 26 weeks: the last six months, every square big enough to tap.
    private static let weeks = 26
    private static let gap: CGFloat = 3
    private static let labelWidth: CGFloat = 14

    /// Square size that makes the 26 columns exactly fill the width.
    private var cell: CGFloat {
        let available = gridWidth - Self.labelWidth - Self.gap * CGFloat(Self.weeks)
        return max(6, floor(available / CGFloat(Self.weeks) * 10) / 10)
    }

    private var today: Date { Date.now.startOfDay }

    /// The first day of the first column: 52 weeks before this week's start.
    private var gridStart: Date {
        let offset = (calendar.component(.weekday, from: today) - calendar.firstWeekday + 7) % 7
        return today.adding(days: -offset - (Self.weeks - 1) * 7)
    }

    private var moodsByDay: [Date: DailyCheckIn.Mood] {
        Dictionary(store.checkIns.map { ($0.day, $0.mood) }, uniquingKeysWith: { _, last in last })
    }

    var body: some View {
        let moods = moodsByDay
        let inRange = moods.filter { $0.key >= gridStart && $0.key <= today }

        ScrollView {
            VStack(spacing: AppTheme.Spacing.cardGap) {
                stats(inRange)
                grid(moods)
                breakdown(inRange)
            }
            .padding(.horizontal, AppTheme.Spacing.medium)
            .padding(.top, 8)
            .padding(.bottom, AppTheme.Spacing.large)
        }
        .scrollIndicators(.hidden)
        .background(AppTheme.ColorToken.background.ignoresSafeArea())
        .navigationTitle("Mood history")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Stats

    private func stats(_ moods: [Date: DailyCheckIn.Mood]) -> some View {
        let counts = Dictionary(grouping: moods.values, by: { $0 }).mapValues(\.count)
        let common = counts.max { ($0.value, $0.key.rawValue) < ($1.value, $1.key.rawValue) }?.key

        return HStack(spacing: 10) {
            stat(value: "\(moods.count)", label: String(localized: "days logged"))
            stat(value: "\(store.checkInStreak())", label: String(localized: "day streak"))
            VStack(alignment: .leading, spacing: 4) {
                if let common {
                    common.illustration
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                } else {
                    Text("–").font(.system(size: 24, weight: .heavy))
                }
                Text(common.map { String(localized: "mostly \($0.title.lowercased())") } ?? "no moods yet")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .groupedCard()
        }
    }

    private func stat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 24, weight: .heavy))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .groupedCard()
    }

    // MARK: Grid

    private func grid(_ moods: [Date: DailyCheckIn.Mood]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last 6 months")
                .font(.system(size: 17, weight: .semibold))

            HStack(alignment: .top, spacing: Self.gap) {
                weekdayLabels
                ForEach(0..<Self.weeks, id: \.self) { week in
                    column(week, moods: moods)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { gridWidth = $0 }

            Group {
                if let day = selectedDay {
                    let mood = moods[day]
                    HStack(spacing: 8) {
                        if let mood {
                            mood.illustration.resizable().scaledToFit().frame(width: 20, height: 20)
                        }
                        Text("\(day.formatted(.dateTime.weekday(.wide).day().month(.wide))) · \(mood?.title ?? "Not logged")")
                    }
                } else {
                    Text("Tap a square to see that day.")
                }
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(AppTheme.ColorToken.secondaryText)
            .frame(height: 20)
            .contentTransition(.opacity)

            legend
        }
        .padding(16)
        .groupedCard()
    }

    /// Mon, Wed and Fri, like GitHub, lined up with their rows.
    private var weekdayLabels: some View {
        let symbols = calendar.orderedVeryShortWeekdays
        return VStack(alignment: .leading, spacing: Self.gap) {
            Color.clear.frame(height: 14)
            ForEach(0..<7, id: \.self) { row in
                Text(row % 2 == 1 ? symbols[row] : "")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppTheme.ColorToken.tertiaryText)
                    .frame(width: Self.labelWidth, height: cell)
            }
        }
    }

    private func column(_ week: Int, moods: [Date: DailyCheckIn.Mood]) -> some View {
        let first = gridStart.adding(days: week * 7)
        // A month label over the column where that month's first week starts.
        let showsMonth = calendar.component(.day, from: first) <= 7
        return VStack(spacing: Self.gap) {
            // The month name may overhang into the next columns, like GitHub,
            // without widening this one.
            Color.clear
                .frame(width: cell, height: 14)
                .overlay(alignment: .leading) {
                    if showsMonth {
                        Text(first.formatted(.dateTime.month(.abbreviated)))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AppTheme.ColorToken.tertiaryText)
                            .fixedSize()
                    }
                }
            ForEach(0..<7, id: \.self) { row in
                square(first.adding(days: row), moods: moods)
            }
        }
    }

    @ViewBuilder
    private func square(_ day: Date, moods: [Date: DailyCheckIn.Mood]) -> some View {
        if day > today {
            Color.clear.frame(width: cell, height: cell)
        } else {
            let mood = moods[day]
            let isSelected = selectedDay == day
            RoundedRectangle(cornerRadius: cell * 0.28, style: .continuous)
                .fill(mood?.tint ?? AppTheme.ColorToken.controlFill)
                .frame(width: cell, height: cell)
                .overlay {
                    if isSelected || day == today {
                        RoundedRectangle(cornerRadius: cell * 0.28, style: .continuous)
                            .strokeBorder(isSelected ? AppTheme.ColorToken.primaryText : AppTheme.ColorToken.accent, lineWidth: 1.5)
                    }
                }
                .contentShape(.rect)
                .onTapGesture {
                    HapticFeedback.selection()
                    withAnimation(.snappy) { selectedDay = isSelected ? nil : day }
                }
                .accessibilityElement()
                .accessibilityLabel("\(day.formatted(date: .abbreviated, time: .omitted)), \(mood?.title ?? "not logged")")
        }
    }

    private var legend: some View {
        HStack(spacing: 6) {
            Text("Bad")
            ForEach(DailyCheckIn.Mood.scale) { mood in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(mood.tint)
                    .frame(width: 12, height: 12)
            }
            Text("Great")
            Spacer(minLength: 8)
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(AppTheme.ColorToken.controlFill)
                .frame(width: 12, height: 12)
            Text("Not logged")
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(AppTheme.ColorToken.secondaryText)
        .accessibilityElement(children: .combine)
    }

    // MARK: Breakdown

    /// Each mood's share of the logged days, best first.
    private func breakdown(_ moods: [Date: DailyCheckIn.Mood]) -> some View {
        let total = max(moods.count, 1)
        let counts = Dictionary(grouping: moods.values, by: { $0 }).mapValues(\.count)

        return VStack(alignment: .leading, spacing: 12) {
            Text("How it breaks down")
                .font(.system(size: 17, weight: .semibold))
            ForEach(DailyCheckIn.Mood.scale.reversed()) { mood in
                let count = counts[mood] ?? 0
                HStack(spacing: 12) {
                    mood.illustration
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                    Text(mood.title)
                        .font(.system(size: 15, weight: .medium))
                        .frame(width: 52, alignment: .leading)
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(AppTheme.ColorToken.controlFill)
                            Capsule()
                                .fill(mood.tint)
                                .frame(width: proxy.size.width * CGFloat(count) / CGFloat(total))
                        }
                    }
                    .frame(height: 10)
                    Text("\(count)")
                        .font(.system(size: 14, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.ColorToken.secondaryText)
                        .frame(width: 32, alignment: .trailing)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(16)
        .groupedCard()
    }
}
