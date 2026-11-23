import Charts
import SwiftUI

// MARK: - Learn with Doseday

/// Not a question: what the education tools are for, with an illustrative
/// chart of confidence growing faster with guidance than alone.
struct EducationStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingHeader(
                eyebrow: "Built to help you learn",
                title: "Doseday can help your GLP-1 journey with educational tools.",
                reason: "Feel more confident by learning how these medications work."
            )
            VStack(alignment: .leading, spacing: 12) {
                point(.list, "Short guides on how GLP-1s work").stagger(0)
                point(.syringe, "Injection tips and site rotation").stagger(1)
                point(.timeline, "What to expect as your dose steps up").stagger(2)
            }
            ConfidenceChart().stagger(3)
        }
    }

    private func point(_ icon: AppIcon, _ text: String) -> some View {
        HStack(spacing: 12) {
            FilledIcon(icon, size: 17)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(AppTheme.ColorToken.accent, in: .rect(cornerRadius: 10, style: .continuous))
            Text(text).font(.system(size: 16, weight: .medium))
        }
        .accessibilityElement(children: .combine)
    }
}

/// Confidence over the first eight weeks, learning with Doseday versus on
/// your own. Illustrative shape only, so the y axis carries no numbers.
private struct ConfidenceChart: View {
    private static let withoutColor = Color(light: 0xA9A4B8, dark: 0x7D7890)
    private static let gridColor = Color(light: 0xECEAF3, dark: 0x2C2A36)

    private static let weeks = Array(0...8)
    private static func withDoseday(_ week: Int) -> Double { 20 + 72 * (1 - exp(-Double(week) / 2.6)) }
    private static func alone(_ week: Int) -> Double { 20 + 38 * (1 - exp(-Double(week) / 6)) }

    @State private var drawn: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your confidence").font(.system(size: 17, weight: .bold))
                Spacer()
                Text("Illustration · first 8 weeks")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
            }

            Chart {
                ForEach(Self.weeks, id: \.self) { week in
                    AreaMark(x: .value("Week", week), y: .value("Confidence", Self.withDoseday(week)))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.ColorToken.accent.opacity(0.22), AppTheme.ColorToken.accent.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                ForEach(Self.weeks, id: \.self) { week in
                    LineMark(x: .value("Week", week), y: .value("Confidence", Self.alone(week)), series: .value("Plan", "On your own"))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Self.withoutColor)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineJoin: .round, dash: [5, 5]))
                }
                ForEach(Self.weeks, id: \.self) { week in
                    LineMark(x: .value("Week", week), y: .value("Confidence", Self.withDoseday(week)), series: .value("Plan", "With Doseday"))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(AppTheme.ColorToken.accent)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                }
                PointMark(x: .value("Week", 8), y: .value("Confidence", Self.withDoseday(8)))
                    .foregroundStyle(AppTheme.ColorToken.accent)
                    .symbolSize(90)
            }
            .chartYScale(domain: 0...100)
            .chartXScale(domain: 0...8)
            .chartYAxis {
                AxisMarks(position: .leading, values: [10, 90]) { value in
                    AxisGridLine().foregroundStyle(Self.gridColor)
                    AxisValueLabel { Text(value.as(Int.self) == 10 ? "Low" : "High") }
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.ColorToken.tertiaryText)
                }
            }
            .chartXAxis {
                AxisMarks(values: [0, 4, 8]) { value in
                    AxisValueLabel { Text(value.as(Int.self) == 0 ? "Start" : "Week \(value.as(Int.self) ?? 0)") }
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.ColorToken.tertiaryText)
                }
            }
            .chartLegend(.hidden)
            .frame(height: 170)
            .mask {
                GeometryReader { proxy in
                    Rectangle().frame(width: proxy.size.width * drawn)
                }
            }

            HStack(spacing: 14) {
                legend("With Doseday") {
                    Capsule().fill(AppTheme.ColorToken.accent).frame(width: 18, height: 4)
                }
                legend("On your own") {
                    Capsule().fill(Self.withoutColor).frame(width: 18, height: 3)
                }
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(AppTheme.ColorToken.secondaryText)
        }
        .padding(16)
        .background(AppTheme.ColorToken.cardBackground, in: .rect(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Illustration: confidence rises faster over the first eight weeks when learning with Doseday than on your own.")
        .onAppear {
            if reduceMotion { drawn = 1 } else {
                withAnimation(.easeInOut(duration: 1.3).delay(0.2)) { drawn = 1 }
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

#Preview {
    EducationStep()
        .padding()
        .background(AppTheme.ColorToken.background)
}
