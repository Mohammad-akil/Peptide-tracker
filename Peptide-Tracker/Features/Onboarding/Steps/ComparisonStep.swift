import Charts
import SwiftUI

// MARK: - With and without Doseday

/// Not a question: an illustrative weight curve from the user's own
/// numbers — steady progress to the goal with support, and a stall and
/// slide back without it. A shape, not a study, so it's labelled as one.
struct ComparisonStep: View {
    let answers: OnboardingAnswers

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingHeader(
                eyebrow: String(localized: "Why Doseday"),
                title: String(localized: "Make your GLP-1 work for you."),
                reason: String(localized: "Enjoy a smoother experience, from managing side effects to hitting your weight loss milestones with less stress.")
            )
            WeightComparisonChart(answers: answers).stagger(0)
            VStack(alignment: .leading, spacing: 12) {
                point(.bell, String(localized: "Never miss a dose or a refill"), tint: Color(hex: 0xFF9F0A)).stagger(1)
                point(.heart, String(localized: "Log side effects and spot patterns"), tint: Color(hex: 0xFF3B30)).stagger(2)
                point(.timeline, String(localized: "See every milestone as you hit it"), tint: Color(hex: 0x30B07A)).stagger(3)
            }
        }
    }

    /// Each benefit its own colour tile with a white icon.
    private func point(_ icon: AppIcon, _ text: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            FilledIcon(icon, size: 17)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(tint, in: .rect(cornerRadius: 10, style: .continuous))
            Text(text).font(.system(size: 16, weight: .medium))
        }
        .accessibilityElement(children: .combine)
    }
}

private struct WeightComparisonChart: View {
    let answers: OnboardingAnswers

    private static let withoutColor = Color(light: 0xA9A4B8, dark: 0x7D7890)
    private static let gridColor = Color(light: 0xECEAF3, dark: 0x2C2A36)

    @State private var drawn: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var unit: WeightUnit { answers.weightUnit }
    private var startKg: Double { answers.currentWeightKg ?? OnboardingAnswers.defaultWeightKg }
    /// At least a little to lose, so the curves always read.
    private var lossKg: Double {
        max(startKg - (answers.goalWeightKg ?? answers.suggestedGoalKg), startKg * 0.1)
    }
    private var weeks: Int {
        min(max(Int((lossKg / answers.pace.kilogramsPerWeek).rounded(.up)), 12), 104)
    }

    /// Eases into the goal.
    private func with(_ week: Int) -> Double {
        let t = Double(week) / Double(weeks)
        return unit.value(fromKilograms: startKg - lossKg * (1 - pow(1 - t, 1.6)))
    }

    /// Loses about half as much, stalls, then drifts back up.
    private func without(_ week: Int) -> Double {
        let t = Double(week) / Double(weeks)
        let loss = lossKg * 0.5 * sin(min(t / 0.6, 1) * .pi / 2)
        let regain = t > 0.6 ? lossKg * 0.15 * (t - 0.6) / 0.4 : 0
        return unit.value(fromKilograms: startKg - loss + regain)
    }

    private var points: [Int] { Array(stride(from: 0, through: weeks, by: max(weeks / 24, 1))) + [weeks] }

    var body: some View {
        let withEnd = with(weeks)
        let withoutEnd = without(weeks)
        let low = withEnd - unit.value(fromKilograms: lossKg) * 0.12
        let high = unit.value(fromKilograms: startKg) + unit.value(fromKilograms: lossKg) * 0.08

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Weight change").font(.system(size: 17, weight: .bold))
                Spacer()
                Text("Illustration")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
            }

            Chart {
                ForEach(points, id: \.self) { week in
                    AreaMark(x: .value("Week", week), yStart: .value("Weight", low), yEnd: .value("Weight", with(week)))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.ColorToken.accent.opacity(0.2), AppTheme.ColorToken.accent.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                ForEach(points, id: \.self) { week in
                    LineMark(x: .value("Week", week), y: .value("Weight", without(week)), series: .value("Plan", "Without"))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Self.withoutColor)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineJoin: .round, dash: [5, 5]))
                }
                ForEach(points, id: \.self) { week in
                    LineMark(x: .value("Week", week), y: .value("Weight", with(week)), series: .value("Plan", "With"))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(AppTheme.ColorToken.accent)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                }
                PointMark(x: .value("Week", weeks), y: .value("Weight", withEnd))
                    .foregroundStyle(AppTheme.ColorToken.accent)
                    .symbolSize(90)
                    .annotation(position: .top, alignment: .trailing, spacing: 6) {
                        Text("Goal")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(AppTheme.ColorToken.accent, in: .capsule)
                    }
                PointMark(x: .value("Week", weeks), y: .value("Weight", withoutEnd))
                    .foregroundStyle(Self.withoutColor)
                    .symbolSize(60)
            }
            .chartYScale(domain: low...high)
            .chartXScale(domain: 0...weeks)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine().foregroundStyle(Self.gridColor)
                    AxisValueLabel()
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.ColorToken.tertiaryText)
                }
            }
            .chartXAxis {
                AxisMarks(values: [0, weeks / 2, weeks]) { value in
                    AxisValueLabel {
                        let week = value.as(Int.self) ?? 0
                        Text(week == 0 ? "Today" : String(localized: "Week \(week)"))
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.ColorToken.tertiaryText)
                }
            }
            .chartLegend(.hidden)
            .frame(height: 190)
            .mask {
                GeometryReader { proxy in
                    Rectangle().frame(width: proxy.size.width * drawn)
                }
            }

            HStack(spacing: 14) {
                legend(String(localized: "With Doseday")) {
                    Capsule().fill(AppTheme.ColorToken.accent).frame(width: 18, height: 4)
                }
                legend(String(localized: "Without an app")) {
                    Capsule().fill(Self.withoutColor).frame(width: 18, height: 3)
                }
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(AppTheme.ColorToken.secondaryText)

            Text("Weight change with and without the app, for illustration only. Results vary from person to person.")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(AppTheme.ColorToken.cardBackground, in: .rect(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Illustration: with Doseday, weight steadily reaches your goal. Without an app, it stalls and drifts back up.")
        .onAppear {
            if reduceMotion { drawn = 1 } else {
                withAnimation(.easeInOut(duration: 1.4).delay(0.2)) { drawn = 1 }
            }
        }
    }

    private func legend<Swatch: View>(_ label: String, @ViewBuilder swatch: () -> Swatch) -> some View {
        HStack(spacing: 6) {
            swatch()
            Text(label).lineLimit(1)
        }
    }
}
