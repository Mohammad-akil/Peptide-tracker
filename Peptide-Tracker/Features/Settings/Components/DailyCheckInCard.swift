import SwiftUI

/// Under the profile: today at a glance and a one-tap check-in. Today's
/// doses as a small ring (tap to go to Today), "How are you feeling?" with
/// five faces, the streak of days checked in, and the week's check-ins.
struct DailyCheckInCard: View {
    @Environment(MedicineStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        let now = Date.now
        let today = store.checkIn(on: now)
        let streak = store.checkInStreak(now: now)

        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily check-in")
                        .font(.system(size: 17, weight: .semibold))
                    Text(now.longWeekdayDayMonth)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.ColorToken.secondaryText)
                }
                Spacer(minLength: 8)
                if streak > 0 {
                    Label("\(streak) \(streak == 1 ? "day" : "days")", systemImage: "flame.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Urgency.low.ink)
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background(Urgency.low.wash, in: .capsule)
                        .contentTransition(.numericText(value: Double(streak)))
                        .accessibilityLabel("\(streak) day check-in streak")
                }
            }

            dosesToday(now: now)

            VStack(alignment: .leading, spacing: 10) {
                Text(today.map { "Feeling \($0.mood.title.lowercased()) today" } ?? "How are you feeling?")
                    .font(.system(size: 15, weight: .semibold))
                    .contentTransition(.opacity)
                HStack(spacing: 8) {
                    ForEach(DailyCheckIn.Mood.allCases) { mood in
                        moodButton(mood, isSelected: today?.mood == mood)
                    }
                }
            }

            week(now: now)
        }
        .padding(16)
        .groupedCard()
        .animation(.snappy, value: today)
    }

    // MARK: Doses

    /// "3 of 5 doses taken" with a ring; opens Today.
    @ViewBuilder
    private func dosesToday(now: Date) -> some View {
        let doses = store.settings.tracksDoses ? store.doses(on: now) : []
        let taken = doses.filter(\.isTaken).count
        Button {
            router.path = []
            router.selectedTab = .today
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    ProgressRing(progress: doses.isEmpty ? 0 : Double(taken) / Double(doses.count), lineWidth: 5)
                    Image(systemName: doses.isEmpty || taken < doses.count ? "pills.fill" : "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.ColorToken.accent)
                }
                .frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text(doses.isEmpty ? "No doses today" : "\(taken) of \(doses.count) doses taken")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.ColorToken.primaryText)
                        .contentTransition(.numericText(value: Double(taken)))
                    Text(doses.isEmpty ? "Nothing to tick off" : taken == doses.count ? "All done for today" : "Open Today to tick them off")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.ColorToken.secondaryText)
                }
                Spacer(minLength: 8)
                Chevron()
            }
            .padding(12)
            .background(AppTheme.ColorToken.background, in: .rect(cornerRadius: 16, style: .continuous))
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .disabled(doses.isEmpty)
    }

    // MARK: Mood

    private func moodButton(_ mood: DailyCheckIn.Mood, isSelected: Bool) -> some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.7)) { store.checkIn(mood) }
        } label: {
            VStack(spacing: 4) {
                Text(mood.emoji)
                    .font(.system(size: 26))
                    .scaleEffect(isSelected ? 1.15 : 1)
                Text(mood.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? AppTheme.ColorToken.accent : AppTheme.ColorToken.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? AppTheme.ColorToken.accentSoft : AppTheme.ColorToken.controlFill, in: .rect(cornerRadius: 14, style: .continuous))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(AppTheme.ColorToken.accent, lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Feeling \(mood.title.lowercased())")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: Week

    /// The last seven days: that day's face, or an empty dot.
    private func week(now: Date) -> some View {
        let today = now.startOfDay
        return HStack(spacing: 0) {
            ForEach((0..<7).reversed(), id: \.self) { back in
                let day = today.adding(days: -back)
                let checkIn = store.checkIn(on: day)
                VStack(spacing: 4) {
                    ZStack {
                        if let checkIn {
                            Text(checkIn.mood.emoji).font(.system(size: 16))
                        } else {
                            Circle()
                                .strokeBorder(AppTheme.ColorToken.uncheckedRing, style: StrokeStyle(lineWidth: 1.5, dash: day == today ? [3, 3] : []))
                                .frame(width: 18, height: 18)
                        }
                    }
                    .frame(height: 22)
                    Text(day.formatted(.dateTime.weekday(.narrow)))
                        .font(.system(size: 11, weight: day == today ? .bold : .medium))
                        .foregroundStyle(day == today ? AppTheme.ColorToken.accent : AppTheme.ColorToken.tertiaryText)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(day.weekdayDayMonth), \(checkIn.map { "felt \($0.mood.title.lowercased())" } ?? "no check-in")")
            }
        }
    }
}

#Preview {
    DailyCheckInCard()
        .padding()
        .environment(MedicineStore.preview())
        .environment(AppRouter())
        .background(AppTheme.ColorToken.background)
}
