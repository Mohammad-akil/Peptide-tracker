import Charts
import SwiftUI

/// The share of doses taken, a bar per day (a week for 90 days), on a
/// 0–100% scale. One series, so one hue and no legend; the card's title
/// names it. Touching the chart shows a bar's day and counts.
struct AdherenceChart: View {
    let report: AdherenceReport
    @State private var selectedDate: Date?

    /// The accent, one step lighter in dark mode so the bars hold 3:1
    /// against the dark card (checked with the dataviz validator).
    private static let barColor = Color(light: 0x6A45D8, dark: 0x8A6CF0)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(report.isWeekly ? "Taken each week" : "Taken each day")
                    .font(.system(size: 17, weight: .semibold))
                Spacer(minLength: 8)
                Text(readout)
                    .font(.system(size: 13))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: selectedDate)
            }

            Chart {
                ForEach(report.buckets) { bucket in
                    if let rate = bucket.rate {
                        BarMark(
                            x: .value("Day", bucket.start, unit: report.isWeekly ? .weekOfYear : .day),
                            y: .value("Taken", rate * 100),
                            width: .ratio(0.62)
                        )
                        .foregroundStyle(Self.barColor.opacity(selected == nil || selected?.id == bucket.id ? 1 : 0.35))
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4, style: .continuous))
                    }
                }
                if let selected {
                    RuleMark(x: .value("Day", selected.start, unit: report.isWeekly ? .weekOfYear : .day))
                        .foregroundStyle(AppTheme.ColorToken.tertiaryText.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(AppTheme.ColorToken.separator)
                    AxisValueLabel {
                        if let percent = value.as(Int.self) {
                            Text("\(percent)%")
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.ColorToken.tertiaryText)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: xAxisDates) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(xLabel(date))
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.ColorToken.tertiaryText)
                        }
                    }
                }
            }
            .chartXSelection(value: $selectedDate)
            .frame(height: 170)
            .accessibilityLabel(accessibilitySummary)
        }
        .padding(16)
        .groupedCard()
    }

    // MARK: Selection

    /// The bar under the finger, if any.
    private var selected: AdherenceReport.Bucket? {
        guard let selectedDate else { return nil }
        let calendar = Calendar.current
        return report.buckets.last { bucket in
            report.isWeekly
                ? bucket.start <= selectedDate
                : calendar.isDate(bucket.start, inSameDayAs: selectedDate)
        }
    }

    /// "Mon 12 Oct · 80% (4 of 5)", or the hint while nothing's picked.
    private var readout: String {
        guard let selected else { return "Touch a bar" }
        let date = report.isWeekly ? "Week of \(selected.start.dayMonth)" : selected.start.weekdayDayMonth
        guard let rate = selected.rate else { return "\(date) · nothing due" }
        return "\(date) · \(rate.percentLabel) (\(selected.taken) of \(selected.due))"
    }

    // MARK: Axis

    /// A few evenly spaced dates, so labels never crowd.
    private var xAxisDates: [Date] {
        let starts = report.buckets.map(\.start)
        guard starts.count > 7 else { return starts }
        let step = max(starts.count / 5, 1)
        return stride(from: 0, to: starts.count, by: step).map { starts[$0] }
    }

    private func xLabel(_ date: Date) -> String {
        report.period == .week ? date.formatted(.dateTime.weekday(.abbreviated)) : date.dayMonth
    }

    private var accessibilitySummary: String {
        let rated = report.buckets.compactMap(\.rate)
        guard let best = rated.max(), let worst = rated.min() else { return "No doses due in this period" }
        return "Doses taken over the \(report.period.phrase), from \(worst.percentLabel) to \(best.percentLabel) \(report.isWeekly ? "a week" : "a day")"
    }
}
