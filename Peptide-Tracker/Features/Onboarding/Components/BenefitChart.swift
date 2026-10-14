import SwiftUI

/// "Pills on hand" over three months for one example medicine — 60-pill
/// packs at two a day. Without reminders the supply hits zero and waits
/// three days for the next pack; with them, the heads-up comes `daysBefore`
/// days early and the pack lands before the last pill.
struct BenefitChart: View {
    let daysBefore: Int

    private static let pack = 60
    private static let perDay = 2
    private static let days = 90
    /// Days spent waiting for a refill once out, without reminders.
    private static let gapDays = 3
    private static let packDays = pack / perDay

    @State private var drawn: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Pills on hand").font(.system(size: 17, weight: .bold))
                Spacer()
                Text("Example · 3 months")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
            }
            .padding(.bottom, 6)

            HStack(spacing: 16) {
                legend("Without reminders") { DashLine().stroke(Self.withoutColor, style: StrokeStyle(lineWidth: 2.5, dash: [4, 3])).frame(width: 18, height: 3) }
                legend("With reminders") { Capsule().fill(AppTheme.ColorToken.accent).frame(width: 18, height: 3) }
                legend("Reminder") { Circle().fill(AppTheme.ColorToken.accent).frame(width: 10, height: 10) }
            }
            .font(.system(size: 13))
            .foregroundStyle(AppTheme.ColorToken.secondaryText)
            .padding(.bottom, 8)

            plot
                .frame(height: 200)
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 10, trailing: 16))
        .background(AppTheme.ColorToken.cardBackground, in: .rect(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Example supply over three months. Without reminders the supply hits zero twice, for three days each time. With reminders a refill arrives before it runs out.")
        .onAppear {
            if reduceMotion { drawn = 1 } else {
                withAnimation(.easeInOut(duration: 1.4).delay(0.2)) { drawn = 1 }
            }
        }
    }

    private static let withoutColor = Color(hex: 0xA9A4B8)
    private static let gridColor = Color(light: 0xECEAF3, dark: 0x2C2A36)
    private static let gapColor = Color(hex: 0xC8372D, opacity: 0.14)

    private func legend<Swatch: View>(_ label: String, @ViewBuilder swatch: () -> Swatch) -> some View {
        HStack(spacing: 6) {
            swatch()
            Text(label).lineLimit(1).minimumScaleFactor(0.8)
        }
    }

    // MARK: Plot

    private var plot: some View {
        GeometryReader { proxy in
            let frame = PlotFrame(size: proxy.size, days: Self.days, maxValue: Self.pack)
            let without = Self.withoutPoints()
            let with = withPoints()

            ZStack(alignment: .topLeading) {
                // Grid and axis labels
                ForEach([0, 30, 60], id: \.self) { value in
                    Path { path in
                        path.move(to: frame.point(day: 0, value: value))
                        path.addLine(to: frame.point(day: Self.days, value: value))
                    }
                    .stroke(Self.gridColor, lineWidth: 1)
                    Text("\(value)")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.ColorToken.tertiaryText)
                        .frame(width: 22, alignment: .trailing)
                        .position(x: frame.left - 15, y: frame.y(value))
                }
                ForEach(Array(["Oct", "Nov", "Dec", "Jan"].enumerated()), id: \.offset) { index, month in
                    Text(month)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.ColorToken.tertiaryText)
                        .position(x: frame.x(index * 30) + (index == 0 ? 10 : index == 3 ? -10 : 0), y: frame.bottom + 16)
                }

                // Days without medicine
                ForEach(1...2, id: \.self) { cycle in
                    let start = cycle * Self.packDays + (cycle - 1) * Self.gapDays
                    Rectangle()
                        .fill(Self.gapColor)
                        .frame(width: frame.x(start + Self.gapDays) - frame.x(start), height: frame.bottom - frame.top)
                        .position(x: (frame.x(start) + frame.x(start + Self.gapDays)) / 2, y: (frame.top + frame.bottom) / 2)
                        .opacity(drawn)
                }
                Text("\(Self.gapDays) days without")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Urgency.critical.ink)
                    .fixedSize()
                    .position(x: frame.x(Self.packDays + 1), y: frame.top - 12)
                    .opacity(drawn)

                // Lines
                Self.path(without, in: frame)
                    .trim(from: 0, to: drawn)
                    .stroke(Self.withoutColor, style: StrokeStyle(lineWidth: 2.5, lineJoin: .round, dash: [5, 5]))
                area(with, in: frame)
                    .fill(AppTheme.ColorToken.accent.opacity(0.12))
                    .opacity(drawn)
                Self.path(with, in: frame)
                    .trim(from: 0, to: drawn)
                    .stroke(AppTheme.ColorToken.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                // Reminder dots
                ForEach(reminderDays, id: \.self) { day in
                    Circle()
                        .fill(AppTheme.ColorToken.accent)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(AppTheme.ColorToken.cardBackground, lineWidth: 2))
                        .position(frame.point(day: day, value: stock(onDay: day)))
                        .scaleEffect(drawn)
                }
            }
        }
    }

    // MARK: Data

    /// Supply drops to zero, sits there for the gap, then a full pack.
    private static func withoutPoints() -> [(Int, Int)] {
        var points = [(0, pack)]
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

    private func withPoints() -> [(Int, Int)] {
        var points = [(0, Self.pack)]
        for day in refillDays {
            points.append((day, stock(onDay: day) - Self.pack))
            points.append((day, stock(onDay: day)))
        }
        points.append((Self.days, stock(onDay: Self.days)))
        return points
    }

    private static func path(_ points: [(Int, Int)], in frame: PlotFrame) -> Path {
        Path { path in
            for (index, point) in points.enumerated() {
                let location = frame.point(day: point.0, value: point.1)
                if index == 0 { path.move(to: location) } else { path.addLine(to: location) }
            }
        }
    }

    private func area(_ points: [(Int, Int)], in frame: PlotFrame) -> Path {
        var path = Self.path(points, in: frame)
        path.addLine(to: frame.point(day: Self.days, value: 0))
        path.addLine(to: frame.point(day: 0, value: 0))
        path.closeSubpath()
        return path
    }
}

/// Maps days and pill counts into the plot, leaving room for axis labels.
private struct PlotFrame {
    let size: CGSize
    let days: Int
    let maxValue: Int

    var left: CGFloat { 30 }
    var right: CGFloat { size.width - 4 }
    var top: CGFloat { 30 }
    var bottom: CGFloat { size.height - 28 }

    func x(_ day: Int) -> CGFloat { left + (right - left) * CGFloat(day) / CGFloat(days) }
    /// The top pack sits a little under the plot's top so a refill above a
    /// full pack still fits.
    func y(_ value: Int) -> CGFloat { bottom - (bottom - top - 20) * CGFloat(value) / CGFloat(maxValue) }
    func point(day: Int, value: Int) -> CGPoint { CGPoint(x: x(day), y: y(value)) }
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
