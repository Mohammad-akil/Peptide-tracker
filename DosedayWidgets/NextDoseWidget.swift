import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Next dose countdown

/// A live countdown to the next dose: a ring that drains as the dose gets
/// closer and a ticking timer, both updated by the system every second
/// without waking the app. Weekly shots more than a day away read as
/// "2 days, 5 hours". Once a dose is due and not ticked off, it says so.
struct NextDoseWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DosedayNextDose", provider: NextDoseProvider()) { entry in
            NextDoseView(entry: entry)
                .widgetURL(URL(string: "doseday://today"))
                .containerBackground(for: .widget) { Color(.systemBackground) }
        }
        .configurationDisplayName(String(localized: "Next dose countdown"))
        .description(String(localized: "A live countdown to your next dose."))
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

private let countdownAccent = Color(red: 0.42, green: 0.27, blue: 0.85)
private let dueTint = Color.orange

// MARK: Timeline

/// Entries now, at every dose time in the next 8 days (so the countdown
/// moves on to the following dose), and a day before each (where the
/// "2 days, 5 hours" text turns into the ticking clock).
struct NextDoseProvider: TimelineProvider {
    func placeholder(in context: Context) -> DosedayEntry {
        DosedayEntry(date: .now, snapshot: SharedData.Snapshot())
    }

    func getSnapshot(in context: Context, completion: @escaping (DosedayEntry) -> Void) {
        completion(DosedayEntry(date: .now, snapshot: SharedData.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DosedayEntry>) -> Void) {
        let snapshot = SharedData.load()
        let now = Date.now
        let doseTimes = snapshot.upcomingDoseTimes(from: now, days: 8)
        let switchPoints = doseTimes.map { $0.addingTimeInterval(-86_400) }.filter { $0 > now }
        let times = Set(doseTimes + switchPoints).sorted().prefix(30)
        let entries = [DosedayEntry(date: now, snapshot: snapshot)]
            + times.map { DosedayEntry(date: $0, snapshot: snapshot) }
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now))!
        let refresh = max(times.last ?? tomorrow, tomorrow).addingTimeInterval(60)
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }
}

// MARK: Picking the dose

extension SharedData.Snapshot {
    /// What the countdown shows at `now`.
    struct Countdown {
        let dose: SharedData.Dose
        /// When the ring started draining: the dose before this one.
        let start: Date
        /// Due (its time has passed) and not ticked off yet.
        let isDue: Bool
    }

    /// Today's first dose that's due and not taken; otherwise the next
    /// untaken dose in the coming 8 days.
    func countdown(at now: Date) -> Countdown? {
        let calendar = Calendar.current
        let today = doses(on: now)
        if let due = today.first(where: { !$0.isTaken && $0.at <= now }) {
            return Countdown(dose: due, start: due.at, isDue: true)
        }
        for offset in 0...8 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) else { continue }
            let list = offset == 0 ? today : doses(on: day)
            if let next = list.first(where: { !$0.isTaken && $0.at > now }) {
                let start = lastDoseTime(before: now) ?? now
                return Countdown(dose: next, start: min(start, now), isDue: false)
            }
        }
        return nil
    }

    /// Every dose time from `now` over the next `days` days.
    func upcomingDoseTimes(from now: Date, days: Int) -> [Date] {
        let calendar = Calendar.current
        return (0...days).flatMap { offset -> [Date] in
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) else { return [] }
            return doses(on: day).map(\.at).filter { $0 > now }
        }
    }

    /// The most recent scheduled dose time at or before `now`, up to 8 days back.
    private func lastDoseTime(before now: Date) -> Date? {
        let calendar = Calendar.current
        for offset in 0...8 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: now)) else { continue }
            if let last = doses(on: day).map(\.at).filter({ $0 <= now }).max() { return last }
        }
        return nil
    }
}

// MARK: Views

struct NextDoseView: View {
    let entry: DosedayEntry
    @Environment(\.widgetFamily) private var family

    private var countdown: SharedData.Snapshot.Countdown? { entry.snapshot.countdown(at: entry.date) }

    var body: some View {
        if let countdown {
            switch family {
            case .accessoryCircular: circular(countdown)
            case .accessoryRectangular: rectangular(countdown)
            case .accessoryInline: inline(countdown)
            case .systemMedium: medium(countdown)
            default: small(countdown)
            }
        } else {
            empty
        }
    }

    // Home Screen

    private func small(_ c: SharedData.Snapshot.Countdown) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                medicineBadge(c.dose.medicine, size: 22)
                Text(c.dose.medicine.name)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            ZStack {
                ring(c, lineWidth: 9)
                VStack(spacing: 1) {
                    timeLeft(c)
                        .font(.system(size: 19, weight: .heavy))
                        .monospacedDigit()
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .lineLimit(2)
                    doseTime(c)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
            }
        }
        .fontDesign(.rounded)
    }

    private func medium(_ c: SharedData.Snapshot.Countdown) -> some View {
        HStack(spacing: 16) {
            ZStack {
                ring(c, lineWidth: 10)
                medicineBadge(c.dose.medicine, size: 34)
            }
            .frame(width: 108, height: 108)

            VStack(alignment: .leading, spacing: 3) {
                Text(c.isDue ? String(localized: "Due now") : String(localized: "Next dose"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(c.isDue ? dueTint : .secondary)
                Text(c.dose.medicine.name)
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(1)
                timeLeft(c)
                    .font(.system(size: 26, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(c.isDue ? dueTint : countdownAccent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                doseTime(c)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                if Calendar.current.isDateInToday(c.dose.at) {
                    Button(intent: ToggleDoseIntent(medicineID: c.dose.medicine.id.uuidString, minutes: c.dose.time.minutes)) {
                        Label("Taken", systemImage: "checkmark")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(countdownAccent)
                    .padding(.top, 4)
                }
            }
            Spacer(minLength: 0)
        }
        .fontDesign(.rounded)
    }

    // Lock Screen

    private func circular(_ c: SharedData.Snapshot.Countdown) -> some View {
        Group {
            if c.isDue {
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: c.dose.medicine.symbol).font(.system(size: 20, weight: .semibold))
                }
            } else if c.dose.at.timeIntervalSince(entry.date) < 86_400 {
                ProgressView(timerInterval: c.start...c.dose.at, countsDown: true) {
                    Image(systemName: c.dose.medicine.symbol)
                } currentValueLabel: {
                    Image(systemName: c.dose.medicine.symbol)
                }
                .progressViewStyle(.circular)
            } else {
                ZStack {
                    AccessoryWidgetBackground()
                    VStack(spacing: 0) {
                        Image(systemName: c.dose.medicine.symbol).font(.system(size: 12, weight: .semibold))
                        Text(c.dose.at, format: .dateTime.weekday(.abbreviated))
                            .font(.system(size: 12, weight: .bold))
                    }
                }
            }
        }
        .widgetAccentable()
    }

    private func rectangular(_ c: SharedData.Snapshot.Countdown) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Label(c.dose.medicine.name, systemImage: c.dose.medicine.symbol)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
                .widgetAccentable()
            timeLeft(c)
                .font(.system(size: 20, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            doseTime(c)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func inline(_ c: SharedData.Snapshot.Countdown) -> some View {
        Group {
            if c.isDue {
                Text(verbatim: "\(c.dose.medicine.name) · ") + Text(String(localized: "Due now"))
            } else if c.dose.at.timeIntervalSince(entry.date) < 86_400 {
                Text(verbatim: "\(c.dose.medicine.name) · ") + Text(timerInterval: entry.date...c.dose.at, countsDown: true)
            } else {
                Text(verbatim: "\(c.dose.medicine.name) · ") + Text(c.dose.at, format: .dateTime.weekday(.abbreviated).hour().minute())
            }
        }
    }

    // Pieces

    /// "Due now", a ticking "1:24:09" when the dose is under a day away,
    /// or "2 days, 5 hours" for weekly shots further out.
    @ViewBuilder
    private func timeLeft(_ c: SharedData.Snapshot.Countdown) -> some View {
        if c.isDue {
            Text(String(localized: "Due now")).foregroundStyle(dueTint)
        } else if c.dose.at.timeIntervalSince(entry.date) < 86_400 {
            Text(timerInterval: entry.date...c.dose.at, countsDown: true)
        } else {
            Text(c.dose.at, style: .relative)
        }
    }

    /// "8:00 PM", or "Tue 8:00 PM" when it isn't today.
    @ViewBuilder
    private func doseTime(_ c: SharedData.Snapshot.Countdown) -> some View {
        if Calendar.current.isDateInToday(c.dose.at) {
            Text(c.dose.at, style: .time)
        } else {
            Text(c.dose.at, format: .dateTime.weekday(.abbreviated).hour().minute())
        }
    }

    /// The track, and the live ring draining toward the dose.
    @ViewBuilder
    private func ring(_ c: SharedData.Snapshot.Countdown, lineWidth: CGFloat) -> some View {
        let tint = c.isDue ? dueTint : countdownAccent
        ZStack {
            Circle().stroke(tint.opacity(0.15), lineWidth: lineWidth)
            if c.isDue {
                Circle().stroke(tint, lineWidth: lineWidth)
            } else {
                ProgressView(timerInterval: c.start...c.dose.at, countsDown: true) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .progressViewStyle(.circular)
                .tint(tint)
            }
        }
    }

    private func medicineBadge(_ medicine: SharedData.Medicine, size: CGFloat) -> some View {
        Image(systemName: medicine.symbol)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(medicine.tint, in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
    }

    private var empty: some View {
        VStack(spacing: 6) {
            Image(systemName: "timer").font(.system(size: 24, weight: .semibold)).foregroundStyle(countdownAccent)
            Text("No upcoming doses")
                .font(.system(size: 13, weight: .semibold))
                .multilineTextAlignment(.center)
        }
        .fontDesign(.rounded)
    }
}
