import SwiftUI

// MARK: - Range

/// How far back the weight chart looks.
enum WeightRange: String, CaseIterable, Hashable {
    case month = "1M"
    case quarter = "3M"
    case half = "6M"
    case year = "1Y"
    case all = "All"

    /// Days back from today; nil for everything.
    var days: Int? {
        switch self {
        case .month: 30
        case .quarter: 90
        case .half: 182
        case .year: 365
        case .all: nil
        }
    }

    var subtitle: String {
        switch self {
        case .month: String(localized: "Last 30 days")
        case .quarter: String(localized: "Last 90 days")
        case .half: String(localized: "Last 6 months")
        case .year: String(localized: "Last year")
        case .all: String(localized: "Since your first weigh-in")
        }
    }

    func entries(_ weights: [WeightEntry], now: Date = .now) -> [WeightEntry] {
        guard let days else { return weights }
        let since = now.startOfDay.adding(days: -days)
        return weights.filter { $0.day >= since }
    }
}

// MARK: - Body card

/// Height, BMI from the latest weigh-in, the goal weight and the weekly
/// pace, all from setup and all editable here.
struct BodyStatsCard: View {
    @Environment(MedicineStore.self) private var store
    @State private var editsHeight = false
    @State private var editsGoal = false

    var body: some View {
        let settings = store.settings
        let unit = settings.weightUnit
        let bmi = bmiValue

        VStack(alignment: .leading, spacing: 0) {
            Text("Body")
                .font(.system(size: 17, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 6)

            SettingsSheetRow(title: String(localized: "Height"), value: settings.heightCm.map { Self.heightLabel(cm: $0, imperial: unit == .lb) } ?? String(localized: "Add"), action: { editsHeight = true }) {
                SettingsTile(symbol: "ruler.fill", tint: Color(hex: 0x30B0C7))
            }

            HStack(spacing: 14) {
                SettingsTile(symbol: "figure.stand", tint: bmi.map { BMICategory($0).tint } ?? Color(hex: 0x8E8E93))
                Text("BMI")
                    .font(.system(size: 17))
                Spacer(minLength: 8)
                if let bmi {
                    Text(bmi.formatted(.number.precision(.fractionLength(1))))
                        .font(.system(size: 17, weight: .semibold))
                        .monospacedDigit()
                    Text(BMICategory(bmi).title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(BMICategory(bmi).tint)
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(BMICategory(bmi).tint.opacity(0.12), in: .capsule)
                } else {
                    Text(settings.heightCm == nil ? "Add your height" : "Log a weight")
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.ColorToken.secondaryText)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .rowDivider(true, inset: 58)
            .accessibilityElement(children: .combine)

            SettingsSheetRow(
                title: String(localized: "Goal weight"),
                value: settings.goalWeightKg.map { unit.format($0) } ?? String(localized: "Set a goal"),
                showsDivider: settings.weeklyGoalKg != nil,
                action: { editsGoal = true }
            ) {
                SettingsTile(symbol: "target", tint: Color(hex: 0xFF9F0A))
            }

            if let weekly = settings.weeklyGoalKg {
                HStack(spacing: 14) {
                    SettingsTile(symbol: "speedometer", tint: Color(hex: 0x30D158))
                    Text("Weekly pace")
                        .font(.system(size: 17))
                    Spacer(minLength: 8)
                    Text("\(unit.format(weekly)) a week")
                        .font(.system(size: 17))
                        .foregroundStyle(AppTheme.ColorToken.secondaryText)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.bottom, 4)
        .groupedCard()
        .sheet(isPresented: $editsHeight) { HeightEditSheet() }
        .sheet(isPresented: $editsGoal) { GoalWeightSheet() }
    }

    private var bmiValue: Double? {
        guard let height = store.settings.heightCm, height > 0, let weight = store.latestWeight else { return nil }
        return BodyMaths.bmi(weightKg: weight.kilograms, heightCm: height)
    }

    /// "172 cm", or "5′ 8″" for people who weigh in pounds.
    static func heightLabel(cm: Double, imperial: Bool) -> String {
        guard imperial else { return String(localized: "\(Int(cm.rounded())) cm") }
        let inches = Int((cm / 2.54).rounded())
        return "\(inches / 12)′ \(inches % 12)″"
    }
}

// MARK: - Height

/// Edit height in centimetres or feet and inches.
struct HeightEditSheet: View {
    @Environment(MedicineStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var cm = 165
    @State private var unit = HeightUnit.centimeters

    private var totalInches: Int { Int((Double(cm) / 2.54).rounded()) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                SectionPicker(selection: $unit.animation(.snappy), title: \.title, track: AppTheme.ColorToken.cardBackground)
                    .frame(height: 44)

                Group {
                    if unit == .centimeters {
                        Picker("Height", selection: $cm) {
                            ForEach(120...230, id: \.self) { Text("\($0) cm").tag($0) }
                        }
                        .pickerStyle(.wheel)
                    } else {
                        HStack(spacing: 0) {
                            Picker("Feet", selection: Binding(
                                get: { totalInches / 12 },
                                set: { cm = Int((Double($0 * 12 + totalInches % 12) * 2.54).rounded()) }
                            )) {
                                ForEach(4...7, id: \.self) { Text("\($0) ft").tag($0) }
                            }
                            .pickerStyle(.wheel)
                            Picker("Inches", selection: Binding(
                                get: { totalInches % 12 },
                                set: { cm = Int((Double(totalInches / 12 * 12 + $0) * 2.54).rounded()) }
                            )) {
                                ForEach(0...11, id: \.self) { Text("\($0) in").tag($0) }
                            }
                            .pickerStyle(.wheel)
                        }
                    }
                }
                .frame(height: 200)

                Spacer(minLength: 0)

                Button("Save") {
                    store.settings.heightCm = Double(cm)
                    HapticFeedback.notification(.success)
                    dismiss()
                }
                .buttonStyle(.primary)
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .background(AppTheme.ColorToken.background.ignoresSafeArea())
            .navigationTitle("Height")
            .navigationBarTitleDisplayMode(.inline)
            .compatNavigationBarBlur()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CompatToolbarRoleButton(role: .close) { dismiss() }
                        .tint(AppTheme.ColorToken.primaryText)
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            if let height = store.settings.heightCm { cm = min(max(Int(height.rounded()), 120), 230) }
            unit = store.settings.weightUnit == .lb ? .inches : .centimeters
        }
    }
}

// MARK: - Goal

/// Set, change or clear the goal weight.
struct GoalWeightSheet: View {
    @Environment(MedicineStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var goal: Double?

    var body: some View {
        let unit = store.settings.weightUnit
        NavigationStack {
            VStack(spacing: 16) {
                if let latest = store.latestWeight {
                    Text("Now \(unit.format(latest.kilograms))")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.ColorToken.secondaryText)
                }

                WeightWheel(kilograms: $goal, unit: unit, fallbackKg: store.latestWeight?.kilograms ?? 75)
                    .frame(height: 200)

                Spacer(minLength: 0)

                Button("Save goal") {
                    store.settings.goalWeightKg = goal ?? store.latestWeight?.kilograms
                    HapticFeedback.notification(.success)
                    dismiss()
                }
                .buttonStyle(.primary)

                if store.settings.goalWeightKg != nil {
                    Button("Remove goal") {
                        store.settings.goalWeightKg = nil
                        dismiss()
                    }
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(AppTheme.ColorToken.accent)
                    .frame(height: 44)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .background(AppTheme.ColorToken.background.ignoresSafeArea())
            .navigationTitle("Goal weight")
            .navigationBarTitleDisplayMode(.inline)
            .compatNavigationBarBlur()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CompatToolbarRoleButton(role: .close) { dismiss() }
                        .tint(AppTheme.ColorToken.primaryText)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear { goal = store.settings.goalWeightKg }
    }
}

#Preview {
    BodyStatsCard()
        .padding()
        .background(AppTheme.ColorToken.background)
        .environment(MedicineStore.preview())
}
