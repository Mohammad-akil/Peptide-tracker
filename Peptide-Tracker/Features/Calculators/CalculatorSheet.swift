import Charts
import SwiftUI

/// One calculator: the answer on top (with Save), the inputs under it,
/// the saved history as a trend, and where the formula comes from.
/// History shows the last 3 months free; 6 and 9 months, a year and all
/// time are Pro. Everything saved is kept either way. Opens filled in from the user's last weigh-in and
/// what they entered before; units follow the kg / lb setting.
struct CalculatorSheet: View {
    let kind: HealthCalculator

    @Environment(MedicineStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(AppRouter.self) private var router
    @Environment(PurchaseStore.self) private var purchases
    @State private var range = HistoryRange.threeMonths
    @State private var showsPaywall = false

    @State private var sex = BodySex.female
    @State private var age = 30
    @State private var heightCm = 165
    @State private var weightValue: Double?
    @State private var activity = ActivityLevel.light
    @State private var goal = CalorieGoal.maintain
    @State private var split = MacroSplit.balanced
    @State private var didLoad = false

    private var unit: WeightUnit { store.settings.weightUnit }
    private var isMetric: Bool { unit == .kg }

    private var weightKg: Double? {
        guard let weightValue, weightValue > 0 else { return nil }
        let kg = unit.kilograms(from: weightValue)
        return (20...400).contains(kg) ? kg : nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    result
                    inputs
                    history
                    sourceNote
                }
                .padding(.horizontal, AppTheme.Spacing.medium)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppTheme.ColorToken.background)
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                        .tint(AppTheme.ColorToken.primaryText)
                }
            }
            .animation(.snappy, value: weightKg)
        }
        .onAppear(perform: load)
        .onDisappear(perform: remember)
        .sheet(isPresented: $showsPaywall) {
            PaywallView(reason: "See 6 months, 9 months, a year or all of your calculator history with Pro.")
        }
    }

    // MARK: Result

    @ViewBuilder
    private var result: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                kind.illustration
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .accessibilityHidden(true)
                Text(kind.subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let weightKg {
                switch kind {
                case .bmi:
                    bmiResult(BodyMaths.bmi(weightKg: weightKg, heightCm: Double(heightCm)))
                case .bmr:
                    bigNumber(bmr(weightKg), unit: "kcal / day", caption: "at complete rest")
                case .tdee:
                    bigNumber(BodyMaths.tdee(bmr: bmr(weightKg), activity: activity), unit: "kcal / day", caption: "to keep your weight, at \(activity.title.lowercased()) activity")
                case .macros:
                    macrosResult(weightKg)
                }
                saveButton(weightKg)
            } else {
                Text("Enter your weight to see your result.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    .padding(.vertical, 8)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.ColorToken.cardBackground, in: .rect(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }

    // MARK: Saving

    /// What would be saved for these inputs.
    private func currentResult(_ weightKg: Double) -> CalculatorResult {
        var result = CalculatorResult(day: .now, kind: kind, value: 0, weightKg: weightKg)
        switch kind {
        case .bmi:
            result.value = BodyMaths.bmi(weightKg: weightKg, heightCm: Double(heightCm))
        case .bmr:
            result.value = Double(bmr(weightKg))
        case .tdee:
            result.value = Double(BodyMaths.tdee(bmr: bmr(weightKg), activity: activity))
        case .macros:
            let calories = macroCalories(weightKg)
            let grams = BodyMaths.macros(calories: calories, split: split)
            result.value = Double(calories)
            result.protein = grams.protein
            result.carbs = grams.carbs
            result.fat = grams.fat
        }
        return result
    }

    private func saveButton(_ weightKg: Double) -> some View {
        let today = store.calculatorResults(for: kind).last { $0.day == Date.now.startOfDay }
        let current = currentResult(weightKg)
        let isSaved = today.map { abs($0.value - current.value) < 0.05 } ?? false
        return Button {
            store.saveCalculatorResult(current)
            HapticFeedback.notification(.success)
            router.show(.success("Saved", message: "\(kind.title): \(kind.format(current.value))"))
        } label: {
            Label(isSaved ? "Saved today" : (today == nil ? "Save to history" : "Update today’s result"),
                  systemImage: isSaved ? "checkmark" : "square.and.arrow.down")
        }
        .buttonStyle(.primary(height: 44))
        .disabled(isSaved)
        .opacity(isSaved ? 0.6 : 1)
        .animation(.snappy, value: isSaved)
    }

    private func macroCalories(_ weightKg: Double) -> Int {
        max(1200, BodyMaths.tdee(bmr: bmr(weightKg), activity: activity) + goal.adjustment)
    }

    // MARK: History

    private var history: some View {
        let saved = store.calculatorResults(for: kind)
        let start = range.start()
        let shown = saved.filter { start == nil || $0.day >= start! }
        let hasOlder = start.map { first in saved.contains { $0.day < first } } ?? false

        return VStack(alignment: .leading, spacing: 14) {
            Text("Your history")
                .font(.system(size: 17, weight: .semibold))

            HStack(spacing: 6) {
                ForEach(HistoryRange.allCases) { option in
                    let isLocked = option.isPro && !purchases.isPro
                    Button {
                        HapticFeedback.selection()
                        if isLocked { showsPaywall = true } else { withAnimation(.snappy) { range = option } }
                    } label: {
                        HStack(spacing: 3) {
                            Text(option.title)
                            if isLocked {
                                Image(systemName: "crown.fill").font(.system(size: 9, weight: .bold))
                            }
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(range == option ? .white : (isLocked ? PaywallPalette.goldInk : AppTheme.ColorToken.primaryText))
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background(
                            range == option ? AppTheme.ColorToken.accent : (isLocked ? PaywallPalette.gold.opacity(0.22) : AppTheme.ColorToken.controlFill),
                            in: .capsule
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isLocked ? "\(option.title), Pro" : option.title)
                    .accessibilityAddTraits(range == option ? [.isSelected] : [])
                }
            }

            if shown.count > 1 {
                trendChart(shown)
                    .frame(height: 160)
            } else {
                Text(shown.isEmpty ? "Save a result to start your trend." : "Save on another day to see your trend.")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
            }

            if !shown.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(shown.reversed().prefix(12).enumerated()), id: \.element.id) { index, entry in
                        historyRow(entry)
                            .rowDivider(index < min(shown.count, 12) - 1, inset: 0)
                    }
                }
            }

            if hasOlder && !purchases.isPro {
                Button { showsPaywall = true } label: {
                    Label("Older results are saved — see them all with Pro", systemImage: "crown.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PaywallPalette.goldInk)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(PaywallPalette.gold.opacity(0.22), in: .capsule)
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.ColorToken.cardBackground, in: .rect(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }

    private func historyRow(_ entry: CalculatorResult) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.day.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 15, weight: .medium))
                if let protein = entry.protein, let carbs = entry.carbs, let fat = entry.fat {
                    Text("P \(protein) g · C \(carbs) g · F \(fat) g")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.ColorToken.secondaryText)
                } else if let weight = entry.weightKg {
                    Text("at \(unit.format(weight))")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.ColorToken.secondaryText)
                }
            }
            Spacer(minLength: 8)
            Text(kind.format(entry.value))
                .font(.system(size: 15, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(kind.tint)
        }
        .padding(.vertical, 10)
        .contentShape(.rect)
        .contextMenu {
            Button(role: .destructive) {
                store.deleteCalculatorResult(id: entry.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func trendChart(_ entries: [CalculatorResult]) -> some View {
        let values = entries.map(\.value)
        let pad = kind == .bmi ? 1.0 : 100.0
        let low = (values.min() ?? 0) - pad
        let high = (values.max() ?? 0) + pad
        return Chart(entries) { entry in
            AreaMark(x: .value("Day", entry.day), yStart: .value("Base", low), yEnd: .value("Value", entry.value))
                .foregroundStyle(LinearGradient(colors: [kind.tint.opacity(0.22), kind.tint.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                .interpolationMethod(.monotone)
            LineMark(x: .value("Day", entry.day), y: .value("Value", entry.value))
                .foregroundStyle(kind.tint)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)
            PointMark(x: .value("Day", entry.day), y: .value("Value", entry.value))
                .foregroundStyle(kind.tint)
                .symbolSize(30)
        }
        .chartYScale(domain: low...high)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(AppTheme.ColorToken.ringTrack)
                AxisValueLabel().font(.system(size: 11)).foregroundStyle(AppTheme.ColorToken.tertiaryText)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day()).font(.system(size: 11)).foregroundStyle(AppTheme.ColorToken.tertiaryText)
            }
        }
        .accessibilityLabel("\(kind.title) trend")
    }

    private func bmr(_ weightKg: Double) -> Int {
        BodyMaths.bmr(sex: sex, age: age, heightCm: Double(heightCm), weightKg: weightKg)
    }

    private func bigNumber(_ value: Int, unit: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value.formatted())
                    .font(.system(size: 44, weight: .heavy))
                    .kerning(-1)
                    .monospacedDigit()
                    .foregroundStyle(kind.tint)
                    .contentTransition(.numericText(value: Double(value)))
                Text(unit)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
            }
            Text(caption)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
        }
    }

    private func bmiResult(_ bmi: Double) -> some View {
        let category = BMICategory(bmi)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(bmi.formatted(.number.precision(.fractionLength(1))))
                    .font(.system(size: 44, weight: .heavy))
                    .kerning(-1)
                    .monospacedDigit()
                    .foregroundStyle(category.tint)
                    .contentTransition(.numericText(value: bmi))
                Text(category.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(category.tint)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(category.tint.opacity(0.12), in: .capsule)
            }
            BMIScale(bmi: bmi)
        }
    }

    private func macrosResult(_ weightKg: Double) -> some View {
        let calories = macroCalories(weightKg)
        let grams = BodyMaths.macros(calories: calories, split: split)
        return VStack(alignment: .leading, spacing: 14) {
            bigNumber(calories, unit: "kcal / day", caption: goal.title)
            HStack(spacing: 10) {
                macroTile("Protein", grams.protein, percent: split.percentages.protein, tint: Color(hex: 0xFF453A))
                macroTile("Carbs", grams.carbs, percent: split.percentages.carbs, tint: Color(hex: 0xFF9F0A))
                macroTile("Fat", grams.fat, percent: split.percentages.fat, tint: Color(hex: 0x30B0C7))
            }
        }
    }

    private func macroTile(_ title: String, _ grams: Int, percent: Int, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(grams)")
                    .font(.system(size: 22, weight: .heavy))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(grams)))
                Text("g").font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(tint)
            ProgressView(value: Double(percent), total: 100)
                .tint(tint)
            Text("\(percent)% of calories")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.ColorToken.tertiaryText)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.08), in: .rect(cornerRadius: 16, style: .continuous))
    }

    // MARK: Inputs

    private var inputs: some View {
        VStack(alignment: .leading, spacing: 24) {
            GroupedSection(title: "About you") {
                if kind.usesAgeAndSex {
                    FormRow(title: "Sex") {
                        Picker("Sex", selection: $sex) {
                            ForEach(BodySex.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 180)
                    }
                    .padding(.horizontal, 16)
                    FormRow(title: "Age") {
                        CountStepper(value: $age, range: 18...100, accessibilityName: "age", isTypeable: true)
                    }
                    .padding(.horizontal, 16)
                }
                heightRow
                FormRow(title: "Weight", showsDivider: false) {
                    HStack(spacing: 6) {
                        TextField("0", value: $weightValue, format: .number.precision(.fractionLength(0...1)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: 17, weight: .semibold))
                            .monospacedDigit()
                            .frame(width: 80)
                        Text(unit.rawValue)
                            .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    }
                }
                .padding(.horizontal, 16)
            }

            if kind.usesActivity {
                GroupedSection(title: "Activity", footer: activity.detail) {
                    menuRow("Level", selection: $activity, options: ActivityLevel.allCases, title: \.title, showsDivider: kind == .macros)
                    if kind == .macros {
                        menuRow("Goal", selection: $goal, options: CalorieGoal.allCases, title: \.title)
                        menuRow("Diet", selection: $split, options: MacroSplit.allCases, title: \.title, showsDivider: false)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var heightRow: some View {
        if isMetric {
            FormRow(title: "Height (cm)") {
                CountStepper(value: $heightCm, range: 120...230, accessibilityName: "height in centimetres", isTypeable: true)
            }
            .padding(.horizontal, 16)
        } else {
            FormRow(title: "Height") {
                HStack(spacing: 8) {
                    CountStepper(value: feet, range: 4...7, accessibilityName: "feet")
                    Text("ft").foregroundStyle(AppTheme.ColorToken.secondaryText)
                    CountStepper(value: inches, range: 0...11, accessibilityName: "inches")
                    Text("in").foregroundStyle(AppTheme.ColorToken.secondaryText)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var totalInches: Int { Int((Double(heightCm) / 2.54).rounded()) }

    private var feet: Binding<Int> {
        Binding(get: { totalInches / 12 }, set: { heightCm = Int((Double($0 * 12 + totalInches % 12) * 2.54).rounded()) })
    }

    private var inches: Binding<Int> {
        Binding(get: { totalInches % 12 }, set: { heightCm = Int((Double(totalInches / 12 * 12 + $0) * 2.54).rounded()) })
    }

    private func menuRow<Option: Hashable & Identifiable>(
        _ title: String,
        selection: Binding<Option>,
        options: [Option],
        title optionTitle: KeyPath<Option, String>,
        showsDivider: Bool = true
    ) -> some View {
        FormRow(title: title, showsDivider: showsDivider) {
            Picker(title, selection: selection) {
                ForEach(options) { Text($0[keyPath: optionTitle]).tag($0) }
            }
            .pickerStyle(.menu)
            .tint(AppTheme.ColorToken.accent)
        }
        .padding(.horizontal, 16)
    }

    // MARK: Source

    private var sourceNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("An estimate for healthy adults, not medical advice. Talk to your doctor before changing your diet or weight.")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Button { openURL(kind.source.url) } label: {
                Label("Source: \(kind.source.title)", systemImage: "book.closed.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.ColorToken.accent)
                    .multilineTextAlignment(.leading)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
    }

    // MARK: Memory

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        let settings = store.settings
        if let saved = settings.sex { sex = saved }
        if let year = settings.birthYear {
            age = min(max(Calendar.current.component(.year, from: .now) - year, 18), 100)
        }
        if let height = settings.heightCm { heightCm = Int(height.rounded()) }
        if let latest = store.latestWeight {
            weightValue = (unit.value(fromKilograms: latest.kilograms) * 10).rounded() / 10
        }
    }

    /// Keeps sex, age and height for next time; never weight, which comes
    /// from the weigh-ins.
    private func remember() {
        var settings = store.settings
        if kind.usesAgeAndSex {
            settings.sex = sex
            settings.birthYear = Calendar.current.component(.year, from: .now) - age
        }
        settings.heightCm = Double(heightCm)
        if settings != store.settings { store.settings = settings }
    }
}

/// The four WHO bands as one bar, with a marker at this BMI.
private struct BMIScale: View {
    let bmi: Double

    private let lower = 15.0
    private let upper = 40.0
    private let bands: [(BMICategory, Double)] = [(.under, 18.5), (.healthy, 25), (.over, 30), (.obese, 40)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    HStack(spacing: 2) {
                        ForEach(Array(bands.enumerated()), id: \.offset) { index, band in
                            let start = index == 0 ? lower : bands[index - 1].1
                            Capsule()
                                .fill(band.0.tint.opacity(0.85))
                                .frame(width: max(0, (band.1 - start) / (upper - lower) * width - 2))
                        }
                    }
                    Circle()
                        .fill(.white)
                        .frame(width: 16, height: 16)
                        .overlay(Circle().stroke(AppTheme.ColorToken.primaryText, lineWidth: 2.5))
                        .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
                        .offset(x: min(max((bmi - lower) / (upper - lower), 0), 1) * width - 8)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: bmi)
                }
                .frame(height: 16)
            }
            .frame(height: 16)
            HStack {
                ForEach(BMICategory.allCases, id: \.self) { category in
                    Text(category.range)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.ColorToken.tertiaryText)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityHidden(true)
    }
}
