import Charts
import SwiftUI

/// "Pills on hand" over the next three months for one example medicine —
/// 60-pill packs at two a day. Without reminders the supply hits zero and
/// waits three days for the next pack; with them, the heads-up comes
/// `daysBefore` days early and the pack lands before the last pill.
/// The takeaway sits on top as two numbers, so it reads before the chart.
struct BenefitChart: View {
    let daysBefore: Int

    private static let pack = 60
    private static let perDay = 2
    private static let days = 90
    /// Days spent waiting for a refill once out, without reminders.
    private static let gapDays = 3
    private static let packDays = pack / perDay

    private static let withoutColor = Color(light: 0xA9A4B8, dark: 0x7D7890)
    private static let gridColor = Color(light: 0xECEAF3, dark: 0x2C2A36)
    private static let gapColor = Color(hex: 0xC8372D, opacity: 0.13)

    @State private var drawn: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The chart starts today, so the months are the user's own.
    private let start = Calendar.current.startOfDay(for: .now)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Pills on hand").font(.system(size: 17, weight: .bold))
                Spacer()
                Text("Example · next 3 months")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
            }

            HStack(spacing: 10) {
                stat(value: Self.daysWithoutMedicine, label: "days with nothing to take, no reminders", tint: Urgency.critical.tint)
                stat(value: 0, label: "days with nothing to take, with reminders", tint: AppTheme.ColorToken.accent)
            }

            chart
                .frame(height: 190)

            HStack(spacing: 14) {
                legend("No reminders") {
                    DashLine()
                        .stroke(Self.withoutColor, style: StrokeStyle(lineWidth: 2.5, dash: [4, 3]))
                        .frame(width: 18, height: 3)
                }
                legend("With reminders") {
                    Capsule().fill(AppTheme.ColorToken.accent).frame(width: 18, height: 4)
                }
                legend("Reminder") { reminderDot(size: 14) }
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(AppTheme.ColorToken.secondaryText)
        }
        .padding(16)
        .background(AppTheme.ColorToken.cardBackground, in: .rect(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Example supply over the next three months. Without reminders the supply runs out twice, \(Self.daysWithoutMedicine) days with nothing to take. With a reminder \(daysBefore) days ahead, each refill arrives before it runs out.")
        .onAppear {
            if reduceMotion { drawn = 1 } else {
                withAnimation(.easeInOut(duration: 1.3).delay(0.2)) { drawn = 1 }
            }
        }
    }

    // MARK: Summary

    private func stat(value: Int, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(value)")
                    .font(.system(size: 28, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                Text(value == 1 ? "day" : "days")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
            }
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.1), in: .rect(cornerRadius: 16, style: .continuous))
    }

    private func legend<Swatch: View>(_ label: String, @ViewBuilder swatch: () -> Swatch) -> some View {
        HStack(spacing: 6) {
            swatch()
            Text(label).lineLimit(1).minimumScaleFactor(0.8)
        }
    }

    private func reminderDot(size: CGFloat) -> some View {
        Image(systemName: "bell.fill")
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(AppTheme.ColorToken.accent, in: .circle)
            .overlay(Circle().stroke(AppTheme.ColorToken.cardBackground, lineWidth: 2))
    }

    // MARK: Chart

    private var chart: some View {
        let with = withPoints()
        return Chart {
            ForEach(Self.gapStarts, id: \.self) { gapStart in
                RectangleMark(
                    xStart: .value("Day", date(gapStart)),
                    xEnd: .value("Day", date(min(gapStart + Self.gapDays, Self.days)))
                )
                .foregroundStyle(Self.gapColor)
                .annotation(position: .top, alignment: .center, spacing: 2) {
                    Text("Out \(Self.gapDays)d")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Urgency.critical.ink)
                        .fixedSize()
                }
            }

            ForEach(Array(with.enumerated()), id: \.offset) { _, point in
                AreaMark(x: .value("Day", date(point.day)), y: .value("Pills", point.pills))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.ColorToken.accent.opacity(0.22), AppTheme.ColorToken.accent.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            ForEach(Array(Self.withoutPoints.enumerated()), id: \.offset) { _, point in
                LineMark(x: .value("Day", date(point.day)), y: .value("Pills", point.pills), series: .value("Plan", "No reminders"))
                    .foregroundStyle(Self.withoutColor)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineJoin: .round, dash: [5, 5]))
            }

            ForEach(Array(with.enumerated()), id: \.offset) { _, point in
                LineMark(x: .value("Day", date(point.day)), y: .value("Pills", point.pills), series: .value("Plan", "With reminders"))
                    .foregroundStyle(AppTheme.ColorToken.accent)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }

            ForEach(reminderDays, id: \.self) { day in
                PointMark(x: .value("Day", date(day)), y: .value("Pills", stock(onDay: day)))
                    .symbol { reminderDot(size: 20) }
            }
        }
        .chartYScale(domain: 0...yMax(with))
        .chartXScale(domain: date(0)...date(Self.days))
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 30, 60]) { _ in
                AxisGridLine().foregroundStyle(Self.gridColor)
                AxisValueLabel()
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.ColorToken.tertiaryText)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated))
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.ColorToken.tertiaryText)
            }
        }
        .chartLegend(.hidden)
        // Draws in from the left.
        .mask {
            GeometryReader { proxy in
                Rectangle().frame(width: proxy.size.width * drawn)
            }
        }
    }

    private func date(_ day: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: day, to: start) ?? start
    }

    private func yMax(_ points: [(day: Int, pills: Int)]) -> Int {
        max(Self.pack, points.map(\.pills).max() ?? Self.pack) + 8
    }

    // MARK: Data

    /// Where each run-out starts, without reminders.
    private static var gapStarts: [Int] {
        var starts: [Int] = []
        var cycle = 1
        while true {
            let gapStart = cycle * packDays + (cycle - 1) * gapDays
            guard gapStart < days else { break }
            starts.append(gapStart)
            cycle += 1
        }
        return starts
    }

    private static var daysWithoutMedicine: Int {
        gapStarts.reduce(0) { $0 + min(gapDays, days - $1) }
    }

    /// Supply drops to zero, sits there for the gap, then a full pack.
    private static var withoutPoints: [(day: Int, pills: Int)] {
        var points: [(day: Int, pills: Int)] = [(0, pack)]
        var day = 0
        while day < days {
            let out = min(day + packDays, days)
            points.append((out, pack - (out - day) * perDay))
            guard out < days else { break }
            let back = min(out + gapDays, days)
            points.append((back, 0))
            guard back < days else { break }
            points.append((back, pack))
            day = back
        }
        return points
    }

    /// The heads-up lands `daysBefore` days ahead; the pack arrives so the
    /// supply never drops below three days' worth.
    private var refillDays: [Int] {
        let arrivalLead = max(daysBefore - 3, 0)
        return reminderDays.map { $0 + arrivalLead }.filter { $0 < Self.days }
    }

    /// Every pack lands before the last pill, so run-outs stay one pack
    /// apart and each heads-up sits `daysBefore` ahead of one.
    private var reminderDays: [Int] {
        stride(from: Self.packDays, through: Self.days, by: Self.packDays)
            .map { $0 - daysBefore }
            .filter { $0 > 0 && $0 < Self.days }
    }

    private func stock(onDay day: Int) -> Int {
        let added = refillDays.filter { $0 <= day }.count * Self.pack
        return Self.pack + added - day * Self.perDay
    }

    private func withPoints() -> [(day: Int, pills: Int)] {
        var points: [(day: Int, pills: Int)] = [(0, Self.pack)]
        for day in refillDays {
            points.append((day, stock(onDay: day) - Self.pack))
            points.append((day, stock(onDay: day)))
        }
        points.append((Self.days, stock(onDay: Self.days)))
        return points
    }
}

private struct DashLine: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
    }
}

#Preview {
    BenefitChart(daysBefore: 5)
        .padding()
        .background(AppTheme.ColorToken.background)
}
