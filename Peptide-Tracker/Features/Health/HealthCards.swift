import Charts
import SwiftUI

// MARK: - Mood

extension DailyCheckIn.Mood {
    /// The drawn face in Assets → Moods ("mood-great" …).
    var illustration: Image { Image("mood-\(String(describing: self))") }

    var tint: Color {
        switch self {
        case .great: Color(hex: 0x6A45D8)
        case .good: Color(hex: 0x1F9E6A)
        case .okay: Color(hex: 0xC48A12)
        case .low: Color(hex: 0x5D6BA3)
        case .bad: Color(hex: 0xD2554A)
        }
    }

    /// Worst to best, left to right.
    static var scale: [Self] { allCases.sorted { $0.rawValue < $1.rawValue } }
}

/// The heart of the mood sheet: today's mood as a living character in the
/// middle, its name under it, and the five faces to pick from — the
/// highlight slides to the chosen one while the character morphs into it.
/// Then the week so far.
struct MoodCard: View {
    @Environment(MedicineStore.self) private var store
    @Namespace private var selection

    var body: some View {
        let now = Date.now
        let today = store.checkIn(on: now)?.mood
        let streak = store.checkInStreak(now: now)

        VStack(spacing: 0) {
            HStack {
                Text(now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                Spacer(minLength: 8)
                if streak > 1 {
                    Label("\(streak)-day streak", systemImage: "flame.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Urgency.low.ink)
                        .padding(.horizontal, 10)
                        .frame(height: 24)
                        .background(Urgency.low.wash, in: .capsule)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            MoodCharacter(mood: today, size: 132)
                .padding(.top, 4)

            Text(today?.title ?? "How are you feeling?")
                .font(.system(size: today == nil ? 22 : 28, weight: .heavy))
                .kerning(-0.5)
                .foregroundStyle(today?.tint ?? AppTheme.ColorToken.primaryText)
                .contentTransition(.interpolate)
            Text(today == nil ? "Pick the face that fits today." : "Logged for today · tap another face to change it")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
                .padding(.top, 2)

            picker(today)
                .padding(.top, 18)

            Rectangle()
                .fill(AppTheme.ColorToken.separator)
                .frame(height: 1)
                .padding(.vertical, 16)

            week(now: now)
        }
        .padding(16)
        .groupedCard()
        .animation(.spring(response: 0.5, dampingFraction: 0.72), value: today)
    }

    // MARK: Picker

    private func picker(_ today: DailyCheckIn.Mood?) -> some View {
        HStack(spacing: 4) {
            ForEach(DailyCheckIn.Mood.scale) { mood in
                let isSelected = today == mood
                Button {
                    guard !isSelected else { return }
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) {
                        store.checkIn(mood)
                    }
                } label: {
                    mood.illustration
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .scaleEffect(isSelected ? 1.08 : 1)
                        .saturation(today == nil || isSelected ? 1 : 0.35)
                        .opacity(today == nil || isSelected ? 1 : 0.7)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(mood.tint.opacity(0.14))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .strokeBorder(mood.tint.opacity(0.5), lineWidth: 1.5)
                                    )
                                    .matchedGeometryEffect(id: "selected", in: selection)
                            }
                        }
                        .contentShape(.rect)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(mood.title)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(4)
        .background(AppTheme.ColorToken.background, in: .rect(cornerRadius: 20, style: .continuous))
    }

    // MARK: Week

    private func week(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("This week")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { offset in
                    let day = now.startOfDay.adding(days: offset - 6)
                    let isToday = offset == 6
                    VStack(spacing: 6) {
                        Group {
                            if let mood = store.checkIn(on: day)?.mood {
                                mood.illustration
                                    .resizable()
                                    .scaledToFit()
                                    .transition(.scale.combined(with: .opacity))
                            } else {
                                Circle()
                                    .strokeBorder(AppTheme.ColorToken.uncheckedRing, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                                    .padding(2)
                            }
                        }
                        .frame(width: 30, height: 30)
                        Text(day.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.system(size: 11, weight: isToday ? .bold : .medium))
                            .foregroundStyle(isToday ? AppTheme.ColorToken.accent : AppTheme.ColorToken.tertiaryText)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Moods logged on \(loggedThisWeek(now: now)) of the last 7 days")
        }
    }

    private func loggedThisWeek(now: Date) -> Int {
        (0..<7).filter { store.checkIn(on: now.startOfDay.adding(days: -$0)) != nil }.count
    }
}

// MARK: - Weight

/// The latest weight, the change over the last 90 days, and a trend line.
struct WeightCard: View {
    @Environment(MedicineStore.self) private var store
    @State private var showsLog = false

    var body: some View {
        let unit = store.settings.weightUnit
        let since = Date.now.startOfDay.adding(days: -90)
        let recent = store.weights.filter { $0.day >= since }

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weight")
                        .font(.system(size: 17, weight: .semibold))
                    Text("Last 90 days")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.ColorToken.secondaryText)
                }
                Spacer(minLength: 8)
                Button { showsLog = true } label: {
                    Label("Log", systemImage: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(AppTheme.ColorToken.accent, in: .capsule)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Log weight")
            }

            if let latest = store.latestWeight {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(unit.value(fromKilograms: latest.kilograms).formatted(.number.precision(.fractionLength(1))))
                        .font(.system(size: 34, weight: .heavy))
                        .kerning(-0.8)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: latest.kilograms))
                    Text(unit.rawValue)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    Spacer(minLength: 8)
                    if let first = recent.first, recent.count > 1, first.id != latest.id {
                        changeChip(from: first, to: latest, unit: unit)
                    }
                }

                if recent.count > 1 {
                    chart(recent, unit: unit)
                        .frame(height: 150)
                } else {
                    Text("Log a few more days to see your trend.")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.ColorToken.secondaryText)
                }
            } else {
                VStack(spacing: 4) {
                    IllustrationView(.weightEmpty, width: 180)
                    Text("Log your weight to see how it changes over time.")
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.ColorToken.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .groupedCard()
        .sheet(isPresented: $showsLog) {
            WeightLogSheet()
        }
    }

    /// "−2.3 kg since 18 Aug" — neutral colours, since gaining or losing
    /// can each be the goal.
    private func changeChip(from first: WeightEntry, to latest: WeightEntry, unit: WeightUnit) -> some View {
        let delta = unit.value(fromKilograms: latest.kilograms) - unit.value(fromKilograms: first.kilograms)
        let sign = delta > 0 ? "+" : delta < 0 ? "−" : ""
        return Label {
            Text("\(sign)\(abs(delta).formatted(.number.precision(.fractionLength(1)))) \(unit.rawValue) since \(first.day.dayMonth)")
        } icon: {
            Image(systemName: delta > 0 ? "arrow.up.right" : delta < 0 ? "arrow.down.right" : "equal")
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(AppTheme.ColorToken.accentInk)
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(AppTheme.ColorToken.accentSoft, in: .capsule)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private func chart(_ entries: [WeightEntry], unit: WeightUnit) -> some View {
        let values = entries.map { unit.value(fromKilograms: $0.kilograms) }
        let low = (values.min() ?? 0).rounded(.down) - 1
        let high = (values.max() ?? 0).rounded(.up) + 1
        return Chart(entries) { entry in
            AreaMark(
                x: .value("Day", entry.day),
                yStart: .value("Base", low),
                yEnd: .value("Weight", unit.value(fromKilograms: entry.kilograms))
            )
            .foregroundStyle(LinearGradient(
                colors: [AppTheme.ColorToken.accent.opacity(0.22), AppTheme.ColorToken.accent.opacity(0.02)],
                startPoint: .top,
                endPoint: .bottom
            ))
            .interpolationMethod(.monotone)
            LineMark(x: .value("Day", entry.day), y: .value("Weight", unit.value(fromKilograms: entry.kilograms)))
                .foregroundStyle(AppTheme.ColorToken.accent)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)
            PointMark(x: .value("Day", entry.day), y: .value("Weight", unit.value(fromKilograms: entry.kilograms)))
                .foregroundStyle(AppTheme.ColorToken.accent)
                .symbolSize(28)
        }
        .chartYScale(domain: low...high)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(AppTheme.ColorToken.ringTrack)
                AxisValueLabel().font(.system(size: 11)).foregroundStyle(AppTheme.ColorToken.tertiaryText)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated)).font(.system(size: 11)).foregroundStyle(AppTheme.ColorToken.tertiaryText)
            }
        }
        .accessibilityLabel("Weight trend over the last 90 days")
    }
}

/// Log a weight for any past day (one per day), switch kg / lb, and see or
/// delete earlier weigh-ins.
struct WeightLogSheet: View {
    @Environment(MedicineStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var value: Double?
    @State private var day = Date.now
    @FocusState private var isTyping: Bool

    private var unit: WeightUnit { store.settings.weightUnit }

    private var isValid: Bool {
        guard let value else { return false }
        return (20...400).contains(unit.kilograms(from: value))
    }

    var body: some View {
        @Bindable var store = store

        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        TextField("0.0", value: $value, format: .number.precision(.fractionLength(0...1)))
                            .keyboardType(.decimalPad)
                            .font(.system(size: 34, weight: .heavy))
                            .monospacedDigit()
                            .focused($isTyping)
                        Picker("Unit", selection: $store.settings.weightUnit) {
                            ForEach(WeightUnit.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 110)
                    }
                    DatePicker("Date", selection: $day, in: ...Date.now, displayedComponents: .date)
                        .tint(AppTheme.ColorToken.accent)
                }

                if !store.weights.isEmpty {
                    Section("History") {
                        ForEach(store.weights.reversed()) { entry in
                            HStack {
                                Text(entry.day.formatted(date: .abbreviated, time: .omitted))
                                Spacer()
                                Text(unit.format(entry.kilograms))
                                    .monospacedDigit()
                                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                            }
                        }
                        .onDelete { offsets in
                            let entries = Array(store.weights.reversed())
                            for index in offsets { store.deleteWeight(id: entries[index].id) }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.ColorToken.background)
            .navigationTitle("Log weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CompatToolbarRoleButton(role: .cancel) { dismiss() }
                        .tint(AppTheme.ColorToken.primaryText)
                }
                ToolbarItem(placement: .confirmationAction) {
                    CompatToolbarRoleButton(role: .confirm, action: save)
                        .tint(AppTheme.ColorToken.accent)
                        .disabled(!isValid)
                        .accessibilityLabel("Save")
                }
            }
            .onAppear {
                value = store.latestWeight.map { (unit.value(fromKilograms: $0.kilograms) * 10).rounded() / 10 }
                isTyping = true
            }
        }
        .presentationDetents([.large])
    }

    private func save() {
        guard let value, isValid else { return }
        store.logWeight(kilograms: unit.kilograms(from: value), on: day)
        HapticFeedback.notification(.success)
        dismiss()
    }
}

/// Settings → Health → Weight: the trend card, with Log inside it.
struct WeightSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                WeightCard()
                    .padding(.horizontal, AppTheme.Spacing.medium)
                    .padding(.top, 8)
                    .padding(.bottom, AppTheme.Spacing.large)
            }
            .scrollIndicators(.hidden)
            .background(AppTheme.ColorToken.background.ignoresSafeArea())
            .navigationTitle("Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CompatToolbarRoleButton(role: .close) { dismiss() }
                        .tint(AppTheme.ColorToken.primaryText)
                }
            }
        }
        .presentationDetents([.large])
    }
}
