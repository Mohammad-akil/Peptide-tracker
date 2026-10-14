import Charts
import SwiftUI

/// Projected stock over the next month: a line that falls by
/// the daily amount, the reminder day marked, and — right after a refill —
/// the old projection dashed underneath so the jump is visible.
struct StockForecastCard: View {
    let medicine: Medicine
    let refills: [RefillEvent]
    let now: Date
    private let days = 30

    private struct Point: Identifiable {
        let day: Date
        let stock: Int
        let series: String
        var id: String { "\(series)-\(day.timeIntervalSince1970)" }
    }

    /// The refill made today, if any — drives the "Before" line.
    private var todaysRefill: RefillEvent? {
        refills.first { Calendar.current.isDate($0.date, inSameDayAs: now) }
    }

    private func projection(from stock: Int, series: String) -> [Point] {
        (0...days).map { offset in
            Point(day: now.startOfDay.adding(days: offset), stock: max(stock - offset * medicine.perDay, 0), series: series)
        }
    }

    var body: some View {
        let points = projection(from: medicine.stock, series: "Now")
            + (todaysRefill.map { projection(from: max(medicine.stock - $0.amount, 0), series: "Before") } ?? [])
        let reminderDay = medicine.reminderDate(now: now).startOfDay
        let showsReminder = reminderDay >= now.startOfDay && reminderDay <= now.startOfDay.adding(days: days)

        VStack(alignment: .leading, spacing: 8) {
            Text("Stock forecast")
                .font(.system(size: 17, weight: .semibold))
                .accessibilityAddTraits(.isHeader)

            Chart {
                ForEach(points) { point in
                    AreaMark(x: .value("Day", point.day), y: .value("Stock", point.stock))
                        .foregroundStyle(by: .value("Series", point.series))
                        .opacity(point.series == "Now" ? 0.12 : 0)
                        .interpolationMethod(.linear)
                    LineMark(x: .value("Day", point.day), y: .value("Stock", point.stock), series: .value("Series", point.series))
                        .foregroundStyle(by: .value("Series", point.series))
                        .lineStyle(point.series == "Now" ? StrokeStyle(lineWidth: 3, lineCap: .round) : StrokeStyle(lineWidth: 2, dash: [4, 4]))
                }
                if showsReminder {
                    RuleMark(x: .value("Reminder", reminderDay))
                        .foregroundStyle(AppTheme.ColorToken.primaryText.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                        .annotation(position: .top, alignment: .center, spacing: 2) {
                            Icon(.bell, size: 12)
                                .foregroundStyle(AppTheme.ColorToken.secondaryText)
                        }
                }
                RuleMark(y: .value("Empty", 0))
                    .foregroundStyle(AppTheme.ColorToken.separator)
            }
            .chartForegroundStyleScale([
                "Now": medicine.urgency.tint,
                "Before": AppTheme.ColorToken.tertiaryText,
            ])
            .chartLegend(todaysRefill == nil ? .hidden : .visible)
            .chartLegend(position: .top, alignment: .trailing)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisGridLine().foregroundStyle(AppTheme.ColorToken.separator)
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine().foregroundStyle(AppTheme.ColorToken.separator)
                    AxisValueLabel()
                }
            }
            .chartYScale(domain: 0...max(medicine.capacity, medicine.stock, 1))
            .frame(height: 150)
            .accessibilityLabel("Stock forecast")
            .accessibilityValue("\(medicine.unit.format(medicine.stock)) now, running out \(medicine.runOutDate(now: now).dayMonth)")
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 10, trailing: 16))
        .frame(maxWidth: .infinity, alignment: .leading)
        .groupedCard()
    }
}
