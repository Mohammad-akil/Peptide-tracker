import SwiftUI

/// Everything the share cards show, read from the store once when the share
/// sheet opens. Only counts, rates and moods: never medicine names.
struct ShareMoment {
    enum Kind: String { case today, streak, week, month, mood }

    struct Day: Identifiable {
        let date: Date
        let due: Int
        let taken: Int
        var id: Date { date }
        var rate: Double { due > 0 ? Double(taken) / Double(due) : 0 }
        var isFull: Bool { due > 0 && taken >= due }
    }

    let now: Date
    let todayDue: Int
    let todayTaken: Int
    let streak: Int
    let weekRate: Double?
    let weekTaken: Int
    let week: [Day]
    let monthStart: Date
    let month: [Date: DaySummary]
    struct MoodDay: Identifiable {
        let day: Date
        let mood: DailyCheckIn.Mood?
        var id: Date { day }
    }

    let moods: [MoodDay]
    let checkInStreak: Int

    @MainActor
    init(store: MedicineStore, now: Date = .now) {
        self.now = now
        let today = now.startOfDay
        let todays = store.doses(on: today)
        todayDue = todays.count
        todayTaken = todays.filter(\.isTaken).count

        streak = store.adherenceReport(.quarter).streak
        let report = store.adherenceReport(.week)
        weekRate = report.rate
        weekTaken = report.taken
        week = report.buckets.map { Day(date: $0.start, due: $0.due, taken: $0.taken) }

        let calendar = Calendar.current
        monthStart = calendar.dateInterval(of: .month, for: today)?.start ?? today
        month = store.daySummaries(year: calendar.component(.year, from: today))

        moods = (0..<7).map { offset in
            let day = today.adding(days: offset - 6)
            return MoodDay(day: day, mood: store.checkIn(on: day)?.mood)
        }
        checkInStreak = store.checkInStreak(now: now)
    }

    var moodsLogged: Int { moods.compactMap(\.mood).count }
    var topMood: DailyCheckIn.Mood? {
        let counts = Dictionary(grouping: moods.compactMap(\.mood), by: { $0 }).mapValues(\.count)
        return counts.max { ($0.value, $0.key.rawValue) < ($1.value, $1.key.rawValue) }?.key
    }
    var monthDays: [Date] {
        let calendar = Calendar.current
        let count = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
        return (0..<count).map { monthStart.adding(days: $0) }
    }
    var monthFullDays: Int { monthDays.filter { month[$0]?.status == .all }.count }

    var dateLabel: String { now.formatted(.dateTime.day().month(.abbreviated).year()) }

    /// The cards worth sharing right now, the most relevant first.
    var variants: [ShareCardVariant] {
        var list: [ShareCardVariant] = []
        if todayDue > 0 {
            list.append(.init(id: Kind.today.rawValue, name: "Today", systemImage: "checkmark.circle.fill") { TodayShareCard(data: self, format: $0, theme: $1) })
        }
        if streak > 0 {
            list.append(.init(id: Kind.streak.rawValue, name: "Streak", systemImage: "flame.fill") { StreakShareCard(data: self, format: $0, theme: $1) })
        }
        list.append(.init(id: Kind.week.rawValue, name: "This week", systemImage: "chart.bar.fill") { WeekShareCard(data: self, format: $0, theme: $1) })
        list.append(.init(id: Kind.month.rawValue, name: "This month", systemImage: "calendar") { MonthShareCard(data: self, format: $0, theme: $1) })
        if moodsLogged > 0 {
            list.append(.init(id: Kind.mood.rawValue, name: "Mood", systemImage: "face.smiling") { MoodShareCard(data: self, format: $0, theme: $1) })
        }
        return list
    }
}

// MARK: - 1. Today

/// A full ring and "All doses taken": the day-done card.
struct TodayShareCard: View {
    let data: ShareMoment
    let format: ShareCardFormat
    let theme: ShareCardTheme

    private var rate: Double { data.todayDue > 0 ? Double(data.todayTaken) / Double(data.todayDue) : 0 }
    private var isDone: Bool { data.todayDue > 0 && data.todayTaken >= data.todayDue }

    var body: some View {
        ShareCardScaffold(format: format, theme: theme, eyebrow: "Today", eyebrowIcon: "sun.max.fill", footnote: data.dateLabel) {
            VStack(spacing: format.isStory ? 26 : 14) {
                Spacer(minLength: 0)
                ring
                VStack(spacing: 6) {
                    Text(isDone ? "All doses taken" : "\(data.todayTaken) of \(data.todayDue) taken")
                        .font(ShareCardFont.rounded(format.isStory ? 30 : 24, .heavy))
                        .foregroundStyle(theme.primary)
                    Text(isDone ? "Another day on track." : "Keeping on track, one dose at a time.")
                        .font(ShareCardFont.rounded(format.isStory ? 15 : 13, .medium))
                        .foregroundStyle(theme.secondary)
                }
                .multilineTextAlignment(.center)
                Spacer(minLength: 0)
                if format.isStory {
                    HStack(spacing: 10) {
                        ShareCardStat(value: "\(data.todayTaken)/\(data.todayDue)", label: "Doses today", theme: theme)
                        ShareCardStat(value: data.streak > 0 ? "\(data.streak)" : "–", label: "Day streak", theme: theme)
                    }
                }
            }
        }
    }

    private var ring: some View {
        let side: CGFloat = format.isStory ? 180 : 132
        return ZStack {
            Circle().stroke(theme.subtle, lineWidth: side * 0.1)
            Circle()
                .trim(from: 0, to: max(rate, 0.001))
                .stroke(theme.accent, style: StrokeStyle(lineWidth: side * 0.1, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: isDone ? "checkmark" : "pills.fill")
                .font(.system(size: side * 0.3, weight: .heavy))
                .foregroundStyle(theme.accent)
        }
        .frame(width: side, height: side)
        .background {
            Circle().fill(theme.accent.opacity(0.18)).frame(width: side * 1.4, height: side * 1.4).blur(radius: 22)
        }
    }
}

// MARK: - 2. Streak

/// The number of days in a row with every dose taken, big.
struct StreakShareCard: View {
    let data: ShareMoment
    let format: ShareCardFormat
    let theme: ShareCardTheme

    var body: some View {
        ShareCardScaffold(format: format, theme: theme, eyebrow: "Streak", eyebrowIcon: "flame.fill", footnote: data.dateLabel) {
            VStack(spacing: format.isStory ? 14 : 6) {
                Spacer(minLength: 0)
                Image(systemName: "flame.fill")
                    .font(.system(size: format.isStory ? 84 : 58, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [Color(red: 1, green: 0.78, blue: 0.3), Color(red: 1, green: 0.45, blue: 0.25)], startPoint: .top, endPoint: .bottom))
                    .background {
                        Circle().fill(Color.orange.opacity(0.25)).frame(width: 150, height: 150).blur(radius: 26)
                    }
                Text("\(data.streak)")
                    .font(ShareCardFont.rounded(format.isStory ? 120 : 84, .black))
                    .foregroundStyle(theme.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(data.streak == 1 ? "DAY ON TRACK" : "DAYS ON TRACK")
                    .font(ShareCardFont.rounded(format.isStory ? 15 : 13, .bold))
                    .tracking(2)
                    .foregroundStyle(theme.secondary)
                Spacer(minLength: 0)
                if format.isStory {
                    ShareWeekDots(days: data.week, theme: theme)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        .background(theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
    }
}

/// Seven days, a filled check on each one with every dose taken.
struct ShareWeekDots: View {
    let days: [ShareMoment.Day]
    let theme: ShareCardTheme

    var body: some View {
        HStack(spacing: 0) {
            ForEach(days) { day in
                VStack(spacing: 6) {
                    ZStack {
                        Circle().fill(day.isFull ? theme.accent : (day.taken > 0 ? theme.partial : theme.subtle))
                        if day.isFull {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .heavy))
                                .foregroundStyle(theme.onAccent)
                        }
                    }
                    .frame(width: 32, height: 32)
                    Text(day.date.formatted(.dateTime.weekday(.narrow)))
                        .font(ShareCardFont.rounded(11, .semibold))
                        .foregroundStyle(theme.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - 3. Week

/// The week's adherence and a bar per day.
struct WeekShareCard: View {
    let data: ShareMoment
    let format: ShareCardFormat
    let theme: ShareCardTheme

    var body: some View {
        ShareCardScaffold(format: format, theme: theme, eyebrow: "This week", eyebrowIcon: "chart.bar.fill", footnote: data.dateLabel) {
            VStack(alignment: .leading, spacing: format.isStory ? 18 : 10) {
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 2) {
                    Text(data.weekRate?.percentLabel ?? "–")
                        .font(ShareCardFont.rounded(format.isStory ? 96 : 68, .black))
                        .foregroundStyle(theme.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("of doses taken on time this week")
                        .font(ShareCardFont.rounded(format.isStory ? 16 : 14, .semibold))
                        .foregroundStyle(theme.secondary)
                }
                bars
                    .frame(height: format.isStory ? 170 : 110)
                Spacer(minLength: 0)
                if format.isStory {
                    HStack(spacing: 10) {
                        ShareCardStat(value: "\(data.weekTaken)", label: "Doses taken", theme: theme)
                        ShareCardStat(value: "\(data.week.filter(\.isFull).count)/7", label: "Perfect days", theme: theme)
                    }
                }
            }
        }
    }

    private var bars: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(data.week) { day in
                VStack(spacing: 6) {
                    GeometryReader { proxy in
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(day.due == 0 ? theme.subtle : theme.accent)
                                .frame(height: max(proxy.size.height * (day.due == 0 ? 0.06 : day.rate), 8))
                        }
                        .frame(maxWidth: .infinity)
                        .background(theme.subtle.opacity(0.5), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    Text(day.date.formatted(.dateTime.weekday(.narrow)))
                        .font(ShareCardFont.rounded(11, .semibold))
                        .foregroundStyle(theme.secondary)
                }
            }
        }
    }
}

// MARK: - 4. Month

/// The month as a calendar, every on-track day filled.
struct MonthShareCard: View {
    let data: ShareMoment
    let format: ShareCardFormat
    let theme: ShareCardTheme

    private var leadingBlanks: Int {
        let calendar = Calendar.current
        return (calendar.component(.weekday, from: data.monthStart) - calendar.firstWeekday + 7) % 7
    }

    var body: some View {
        ShareCardScaffold(format: format, theme: theme, eyebrow: data.monthStart.formatted(.dateTime.month(.wide)), eyebrowIcon: "calendar", footnote: data.monthStart.formatted(.dateTime.year())) {
            VStack(alignment: .leading, spacing: format.isStory ? 18 : 10) {
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(data.monthFullDays)")
                        .font(ShareCardFont.rounded(format.isStory ? 72 : 52, .black))
                        .foregroundStyle(theme.primary)
                    Text(data.monthFullDays == 1 ? "day with every dose taken" : "days with every dose taken")
                        .font(ShareCardFont.rounded(format.isStory ? 16 : 14, .semibold))
                        .foregroundStyle(theme.secondary)
                }
                grid
                Spacer(minLength: 0)
            }
        }
    }

    private var grid: some View {
        let cell: CGFloat = format.isStory ? 34 : 26
        let columns = Array(repeating: GridItem(.fixed(cell), spacing: format.isStory ? 9 : 7), count: 7)
        return LazyVGrid(columns: columns, spacing: format.isStory ? 9 : 6) {
            ForEach(0..<leadingBlanks, id: \.self) { _ in Color.clear.frame(width: cell, height: cell) }
            ForEach(data.monthDays, id: \.self) { day in
                let status = data.month[day]?.status
                RoundedRectangle(cornerRadius: cell * 0.3, style: .continuous)
                    .fill(fill(status, isFuture: day > data.now))
                    .overlay {
                        Text(day.formatted(.dateTime.day()))
                            .font(ShareCardFont.rounded(cell * 0.36, .bold))
                            .foregroundStyle(status == .all ? theme.onAccent : theme.secondary)
                    }
                    .frame(width: cell, height: cell)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func fill(_ status: DaySummary.Status?, isFuture: Bool) -> Color {
        if isFuture { return theme.subtle.opacity(0.45) }
        switch status {
        case .all: return theme.accent
        case .partial: return theme.partial
        default: return theme.subtle
        }
    }
}

// MARK: - 5. Mood

/// The week's moods as the drawn faces.
struct MoodShareCard: View {
    let data: ShareMoment
    let format: ShareCardFormat
    let theme: ShareCardTheme

    var body: some View {
        ShareCardScaffold(format: format, theme: theme, eyebrow: "My week", eyebrowIcon: "face.smiling", footnote: data.dateLabel) {
            VStack(spacing: format.isStory ? 22 : 12) {
                Spacer(minLength: 0)
                if let top = data.topMood {
                    top.illustration
                        .resizable()
                        .scaledToFit()
                        .frame(width: format.isStory ? 150 : 104)
                        .background {
                            Circle().fill(top.tint.opacity(0.35)).frame(width: 180, height: 180).blur(radius: 30)
                        }
                    VStack(spacing: 4) {
                        Text("Mostly \(top.title.lowercased())")
                            .font(ShareCardFont.rounded(format.isStory ? 32 : 26, .heavy))
                            .foregroundStyle(theme.primary)
                        Text("\(data.moodsLogged) of 7 days checked in")
                            .font(ShareCardFont.rounded(format.isStory ? 15 : 13, .medium))
                            .foregroundStyle(theme.secondary)
                    }
                }
                Spacer(minLength: 0)
                HStack(spacing: 0) {
                    ForEach(data.moods) { entry in
                        VStack(spacing: 6) {
                            Group {
                                if let mood = entry.mood {
                                    mood.illustration.resizable().scaledToFit()
                                } else {
                                    Circle().fill(theme.subtle)
                                }
                            }
                            .frame(width: 34, height: 34)
                            Text(entry.day.formatted(.dateTime.weekday(.narrow)))
                                .font(ShareCardFont.rounded(11, .semibold))
                                .foregroundStyle(theme.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 10)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }
}
