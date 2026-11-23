import SwiftUI

// MARK: - Goal weight

struct GoalQuestion: View {
    @Binding var answers: OnboardingAnswers

    private var heightCm: Double { Double(answers.heightCm ?? OnboardingAnswers.defaultHeightCm) }
    private var currentKg: Double { answers.currentWeightKg ?? OnboardingAnswers.defaultWeightKg }
    private var goalKg: Double { answers.goalWeightKg ?? answers.suggestedGoalKg }

    /// From a BMI of 16 up to the heavier of now and start, so a goal can
    /// never be set at an unsafe weight.
    private var range: ClosedRange<Double> {
        let metres = heightCm / 100
        let lower = max(30, 16 * metres * metres)
        let upper = max(currentKg, answers.startWeightKg ?? 0, lower + 10)
        return lower...upper
    }

    /// Half a unit per notch, in whichever unit is shown.
    private var step: Double { answers.weightUnit == .kg ? 0.5 : 0.5 / WeightUnit.poundsPerKilogram }

    var body: some View {
        let bmi = BodyMaths.bmi(weightKg: goalKg, heightCm: heightCm)
        VStack(alignment: .leading, spacing: 22) {
            OnboardingHeader(
                title: "Now, let’s set your target weight.",
                reason: "This will help us personalize your goal."
            )

            VStack(spacing: 6) {
                Text(answers.weightUnit.format(goalKg))
                    .font(.system(size: 44, weight: .heavy))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: goalKg))
                    .animation(.snappy, value: goalKg)
                Text(differenceText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: goalKg)
            }
            .frame(maxWidth: .infinity)
            .stagger(0)

            VStack(spacing: 6) {
                Slider(
                    value: Binding(get: { min(max(goalKg, range.lowerBound), range.upperBound) }, set: { answers.goalWeightKg = $0 }),
                    in: range,
                    step: step
                )
                .tint(AppTheme.ColorToken.accent)
                .sensoryFeedback(.selection, trigger: Int(goalKg / step))
                HStack {
                    Text(answers.weightUnit.format(range.lowerBound))
                    Spacer()
                    Text(answers.weightUnit.format(range.upperBound))
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.ColorToken.tertiaryText)
            }
            .stagger(1)

            GoalBMICard(
                currentBMI: BodyMaths.bmi(weightKg: currentKg, heightCm: heightCm),
                goalBMI: bmi
            )
            .stagger(2)
        }
        // What's shown is what Continue saves; Skip clears it.
        .onAppear { if answers.goalWeightKg == nil { answers.goalWeightKg = answers.suggestedGoalKg } }
    }

    private var differenceText: String {
        let delta = currentKg - goalKg
        guard abs(delta) >= 0.05 else { return "Same as your current weight" }
        let amount = answers.weightUnit.format(abs(delta))
        return delta > 0 ? "\(amount) less than now" : "\(amount) more than now"
    }
}

// MARK: - Goal BMI card

/// BMI now → at the goal, the category the goal lands in, and a scale with
/// both marked: the goal as a filled dot under a "Goal" bubble, now as a
/// hollow ring. The goal's band is named in its colour under the bar.
private struct GoalBMICard: View {
    let currentBMI: Double
    let goalBMI: Double

    private static let lower = 15.0
    private static let upper = 40.0
    /// Each band and where it ends.
    private static let bands: [(category: BMICategory, end: Double)] = [(.under, 18.5), (.healthy, 25), (.over, 30), (.obese, 40)]

    private var category: BMICategory { BMICategory(goalBMI) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                Text("Your BMI")
                    .font(.system(size: 13, weight: .bold))
                    .kerning(0.3)
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                Spacer(minLength: 8)
                HStack(spacing: 6) {
                    Circle().fill(category.tint).frame(width: 8, height: 8)
                    Text(category.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(category.tint)
                        .contentTransition(.opacity)
                }
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(category.tint.opacity(0.12), in: .capsule)
            }

            HStack(alignment: .lastTextBaseline, spacing: 14) {
                value(currentBMI, label: "Now", size: 30, tint: AppTheme.ColorToken.secondaryText)
                Image(systemName: "arrow.right")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.ColorToken.tertiaryText)
                    .padding(.bottom, 26)
                value(goalBMI, label: "Goal", size: 52, tint: category.tint)
                Spacer(minLength: 0)
            }

            scale
                .frame(height: 92)

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 13, weight: .semibold))
                Text("BMI is a general guide. It doesn’t account for muscle, age or body shape.")
                    .font(.system(size: 12))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(AppTheme.ColorToken.tertiaryText)
        }
        .padding(18)
        .background(AppTheme.ColorToken.cardBackground, in: .rect(cornerRadius: 22, style: .continuous))
        .animation(.snappy, value: category)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("BMI now \(format(currentBMI)). Goal BMI \(format(goalBMI)), \(category.title).")
    }

    private func value(_ bmi: Double, label: String, size: CGFloat, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(format(bmi))
                .font(.system(size: size, weight: .heavy))
                .kerning(-size * 0.03)
                .monospacedDigit()
                .foregroundStyle(tint)
                .contentTransition(.numericText(value: bmi))
                .animation(.snappy, value: bmi)
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
        }
    }

    private func format(_ bmi: Double) -> String {
        bmi.formatted(.number.precision(.fractionLength(1)))
    }

    private func position(_ bmi: Double, in width: CGFloat) -> CGFloat {
        CGFloat(min(max((bmi - Self.lower) / (Self.upper - Self.lower), 0), 1)) * width
    }

    // MARK: Scale

    private var scale: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let barY: CGFloat = 38
            let goalX = position(goalBMI, in: width)
            let nowX = position(currentBMI, in: width)

            ZStack(alignment: .topLeading) {
                // Bands
                HStack(spacing: 3) {
                    ForEach(Array(Self.bands.enumerated()), id: \.offset) { index, band in
                        let start = index == 0 ? Self.lower : Self.bands[index - 1].end
                        Capsule()
                            .fill(band.category.tint.opacity(band.category == category ? 1 : 0.35))
                            .frame(width: max(0, CGFloat((band.end - start) / (Self.upper - Self.lower)) * width - 3))
                    }
                }
                .frame(height: 10)
                .offset(y: barY - 5)

                // Boundaries
                ForEach([18.5, 25.0, 30.0], id: \.self) { mark in
                    Text(mark.formatted(.number.precision(.fractionLength(0...1))))
                        .font(.system(size: 10, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.ColorToken.tertiaryText)
                        .fixedSize()
                        .frame(width: 40)
                        .position(x: position(mark, in: width), y: barY + 18)
                }

                // Band names
                ForEach(Array(Self.bands.enumerated()), id: \.offset) { index, band in
                    let start = index == 0 ? Self.lower : Self.bands[index - 1].end
                    let isGoal = band.category == category
                    Text(band.category == .healthy ? "Healthy" : band.category == .under ? "Under" : band.category == .over ? "Over" : "Obesity")
                        .font(.system(size: 11, weight: isGoal ? .bold : .medium))
                        .foregroundStyle(isGoal ? band.category.tint : AppTheme.ColorToken.secondaryText)
                        .lineLimit(1)
                        .fixedSize()
                        .position(x: position((start + band.end) / 2, in: width), y: barY + 40)
                }

                // Now: hollow ring
                Circle()
                    .fill(AppTheme.ColorToken.cardBackground)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().strokeBorder(AppTheme.ColorToken.secondaryText, lineWidth: 2.5))
                    .position(x: nowX, y: barY)

                // Goal: filled dot under a bubble
                VStack(spacing: 3) {
                    Text("Goal")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(category.tint, in: .capsule)
                    Circle()
                        .fill(category.tint)
                        .frame(width: 20, height: 20)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                        .shadow(color: category.tint.opacity(0.4), radius: 4, y: 2)
                }
                .fixedSize()
                .position(x: min(max(goalX, 22), width - 22), y: barY - 13)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: goalBMI)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Keep the momentum

/// Not a question: how far is left to the goal, and a word of encouragement.
struct MomentumStep: View {
    let answers: OnboardingAnswers

    private var currentKg: Double { answers.currentWeightKg ?? OnboardingAnswers.defaultWeightKg }
    private var goalKg: Double { answers.goalWeightKg ?? answers.suggestedGoalKg }
    private var startKg: Double { answers.asks(.start) ? (answers.startWeightKg ?? currentKg) : currentKg }
    private var toGo: Double { abs(currentKg - goalKg) }
    private var atGoal: Bool { toGo < 0.05 }

    /// Share of the way from start to goal, once both differ.
    private var done: Double {
        let total = abs(startKg - goalKg)
        guard total > 0.05 else { return atGoal ? 1 : 0 }
        return min(max(abs(startKg - currentKg) / total, 0), 1)
    }

    @State private var fill: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            OnboardingHeader(
                eyebrow: "Your goal",
                title: atGoal
                    ? "You’re already at your goal."
                    : "You still have \(answers.weightUnit.format(toGo)) to go.",
                reason: atGoal
                    ? "Let’s keep it there together."
                    : "Let’s keep the momentum going together."
            )

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    marker("Start", startKg)
                    Spacer()
                    marker("Now", currentKg, alignment: .center)
                    Spacer()
                    marker("Goal", goalKg, alignment: .trailing)
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(hex: 0x767680, opacity: 0.18))
                        Capsule()
                            .fill(AppTheme.ColorToken.accent)
                            .frame(width: max(14, proxy.size.width * fill))
                    }
                }
                .frame(height: 14)
                Text(done > 0 && !atGoal ? "\(Int((done * 100).rounded()))% of the way there" : "Day one starts now")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.ColorToken.accentInk)
            }
            .padding(16)
            .background(AppTheme.ColorToken.cardBackground, in: .rect(cornerRadius: 22, style: .continuous))
            .stagger(0)

            HStack(alignment: .top, spacing: 12) {
                FilledIcon(.heart, size: 20)
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Color(hex: 0xFF3B30), in: .rect(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Small steps add up.")
                        .font(.system(size: 17, weight: .bold))
                    Text("Every dose and every weight you log moves you closer. You don’t have to be perfect, just consistent. We’ll be with you the whole way.")
                        .font(.system(size: 15))
                        .lineSpacing(2)
                        .foregroundStyle(AppTheme.ColorToken.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .background(AppTheme.ColorToken.accentSoft, in: .rect(cornerRadius: 20, style: .continuous))
            .accessibilityElement(children: .combine)
            .stagger(1)
        }
        .onAppear {
            if reduceMotion { fill = done } else {
                withAnimation(.spring(response: 1.1, dampingFraction: 0.85).delay(0.35)) { fill = done }
            }
        }
    }

    private func marker(_ label: String, _ kg: Double, alignment: HorizontalAlignment = .leading) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
            Text(answers.weightUnit.format(kg))
                .font(.system(size: 16, weight: .bold))
                .monospacedDigit()
        }
    }
}

// MARK: - Pace

struct PaceQuestion: View {
    @Binding var answers: OnboardingAnswers

    private var pace: GoalPace { answers.pace }
    private var toGoKg: Double {
        max((answers.currentWeightKg ?? OnboardingAnswers.defaultWeightKg) - (answers.goalWeightKg ?? answers.suggestedGoalKg), 0)
    }
    private var goalDate: Date {
        let weeks = Int((toGoKg / pace.kilogramsPerWeek).rounded(.up))
        return Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: .now) ?? .now
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            OnboardingHeader(
                title: "How quickly do you want to reach your goal?",
                reason: "Choose a pace that matches your lifestyle and goals. It’s your call."
            )

            VStack(spacing: 6) {
                Text(pace.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.ColorToken.accent)
                    .contentTransition(.opacity)
                Text(answers.weightUnit.format(pace.kilogramsPerWeek))
                    .font(.system(size: 44, weight: .heavy))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: pace.kilogramsPerWeek))
                Text("per week")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .animation(.snappy, value: pace)
            .stagger(0)

            VStack(spacing: 12) {
                HStack {
                    ForEach(GoalPace.allCases, id: \.self) { option in
                        Button {
                            HapticFeedback.selection()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { answers.pace = option }
                        } label: {
                            Image(systemName: option.symbol)
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(option == pace ? AppTheme.ColorToken.accent : AppTheme.ColorToken.tertiaryText)
                                .scaleEffect(option == pace ? 1.35 : 1)
                                .symbolEffect(.bounce, value: option == pace)
                                .frame(width: 52, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(option.title)
                        if option != .fast { Spacer() }
                    }
                }
                Slider(
                    value: Binding(
                        get: { Double(pace.rawValue) },
                        set: { value in
                            let picked = GoalPace(rawValue: Int(value.rounded())) ?? .balanced
                            guard picked != answers.pace else { return }
                            HapticFeedback.selection()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { answers.pace = picked }
                        }
                    ),
                    in: 0...2,
                    step: 1
                )
                .tint(AppTheme.ColorToken.accent)
                .accessibilityValue("\(pace.title), \(answers.weightUnit.format(pace.kilogramsPerWeek)) per week")
                HStack {
                    ForEach(GoalPace.allCases, id: \.self) { option in
                        Text(answers.weightUnit.format(option.kilogramsPerWeek))
                            .font(.system(size: 12, weight: option == pace ? .bold : .medium))
                            .foregroundStyle(option == pace ? AppTheme.ColorToken.primaryText : AppTheme.ColorToken.tertiaryText)
                            .frame(maxWidth: .infinity, alignment: option == .steady ? .leading : option == .fast ? .trailing : .center)
                    }
                }
            }
            .padding(16)
            .background(AppTheme.ColorToken.cardBackground, in: .rect(cornerRadius: 22, style: .continuous))
            .stagger(1)

            if toGoKg > 0 {
                HStack(spacing: 12) {
                    FilledIcon(.cal, size: 18)
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(AppTheme.ColorToken.accent, in: .rect(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("You could reach your goal by")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.ColorToken.secondaryText)
                        Text(goalDate.formatted(.dateTime.month(.wide).day().year()))
                            .font(.system(size: 18, weight: .bold))
                            .contentTransition(.numericText())
                    }
                    Spacer(minLength: 0)
                }
                .animation(.snappy, value: pace)
                .stagger(2)
            }

            OnboardingNote(icon: .heart, text: Text(pace.message), tint: Color(hex: 0xFF3B30))
                .contentTransition(.opacity)
                .animation(.snappy, value: pace)
                .stagger(3)
        }
    }
}
