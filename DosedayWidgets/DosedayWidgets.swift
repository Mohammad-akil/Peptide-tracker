import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Bundle

@main
struct DosedayWidgets: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        MoodWidget()
        SupplyWidget()
        DoseLiveActivity()
        LogNextDoseControl()
    }
}

private let accent = Color(red: 0.42, green: 0.27, blue: 0.85)
private let ink = Color.primary
private let secondaryInk = Color.secondary

// MARK: - Timeline

struct DosedayEntry: TimelineEntry {
    let date: Date
    let snapshot: SharedData.Snapshot
}

/// One entry now and one at each of today's dose times (so "Next" moves on
/// by itself), then again just after midnight for the new day.
struct DosedayProvider: TimelineProvider {
    func placeholder(in context: Context) -> DosedayEntry {
        DosedayEntry(date: .now, snapshot: SharedData.Snapshot())
    }

    func getSnapshot(in context: Context, completion: @escaping (DosedayEntry) -> Void) {
        completion(DosedayEntry(date: .now, snapshot: SharedData.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DosedayEntry>) -> Void) {
        let snapshot = SharedData.load()
        let now = Date.now
        let times = snapshot.doses().map(\.at).filter { $0 > now }
        var entries = [DosedayEntry(date: now, snapshot: snapshot)]
        entries += Set(times).sorted().prefix(12).map { DosedayEntry(date: $0, snapshot: snapshot) }
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now))!
        completion(Timeline(entries: entries, policy: .after(tomorrow.addingTimeInterval(60))))
    }
}

// MARK: - Today

/// Today's doses: a ring of how many are taken, the next one with a tick
/// button (small), the list with a tick on each (medium), and a ring or
/// the next dose on the Lock Screen.
struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DosedayToday", provider: DosedayProvider()) { entry in
            TodayWidgetView(entry: entry)
                .widgetURL(URL(string: "doseday://today"))
                .containerBackground(for: .widget) { Color(.systemBackground) }
        }
        .configurationDisplayName(String(localized: "Today’s doses"))
        .description(String(localized: "See what’s next and tick doses off without opening the app."))
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct TodayWidgetView: View {
    let entry: DosedayEntry
    @Environment(\.widgetFamily) private var family

    private var doses: [SharedData.Dose] { entry.snapshot.doses(on: entry.date) }
    private var taken: Int { doses.filter(\.isTaken).count }
    private var progress: Double { doses.isEmpty ? 0 : Double(taken) / Double(doses.count) }
    /// The first dose not taken yet, overdue ones first.
    private var next: SharedData.Dose? { doses.first { !$0.isTaken } }

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .accessoryInline: inline
        case .systemMedium: medium
        default: small
        }
    }

    // Home Screen

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                ring(size: 44, lineWidth: 6)
                Spacer()
                Image(systemName: "pills.fill").foregroundStyle(accent)
            }
            Spacer(minLength: 6)
            if let next {
                Text(next.at <= entry.date ? "Due now" : String(localized: "Next · \(next.time.label)"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(next.at <= entry.date ? Color.red : secondaryInk)
                Text(next.medicine.name)
                    .font(.system(size: 15, weight: .bold))
                    .lineLimit(1)
                Button(intent: ToggleDoseIntent(medicineID: next.medicine.id.uuidString, minutes: next.time.minutes)) {
                    Label("Taken", systemImage: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .padding(.top, 6)
            } else {
                Text(doses.isEmpty ? "No doses today" : "All done")
                    .font(.system(size: 15, weight: .bold))
                Text(doses.isEmpty ? "Enjoy your day" : "Every dose taken")
                    .font(.system(size: 12))
                    .foregroundStyle(secondaryInk)
            }
        }
        .fontDesign(.rounded)
    }

    private var medium: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                ring(size: 62, lineWidth: 8)
                Text("Today")
                    .font(.system(size: 15, weight: .bold))
                Text(doses.isEmpty ? "No doses" : String(localized: "\(taken) of \(doses.count) taken"))
                    .font(.system(size: 12))
                    .foregroundStyle(secondaryInk)
            }
            .frame(width: 92, alignment: .leading)

            VStack(spacing: 6) {
                if doses.isEmpty {
                    Text("Nothing scheduled today.")
                        .font(.system(size: 13))
                        .foregroundStyle(secondaryInk)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ForEach(visibleDoses) { dose in
                        doseRow(dose)
                    }
                    if doses.count > visibleDoses.count {
                        Text("+\(doses.count - visibleDoses.count) more")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(secondaryInk)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .fontDesign(.rounded)
    }

    /// Up to four: what's still to take first, then what's done.
    private var visibleDoses: [SharedData.Dose] {
        Array((doses.filter { !$0.isTaken } + doses.filter(\.isTaken)).prefix(4))
    }

    private func doseRow(_ dose: SharedData.Dose) -> some View {
        HStack(spacing: 8) {
            Image(systemName: dose.medicine.symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(dose.medicine.tint, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 0) {
                Text(dose.medicine.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .strikethrough(dose.isTaken)
                    .foregroundStyle(dose.isTaken ? secondaryInk : ink)
                Text(dose.time.label)
                    .font(.system(size: 11))
                    .foregroundStyle(!dose.isTaken && dose.at <= entry.date ? Color.red : secondaryInk)
            }
            Spacer(minLength: 4)
            Button(intent: ToggleDoseIntent(medicineID: dose.medicine.id.uuidString, minutes: dose.time.minutes)) {
                Image(systemName: dose.isTaken ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(dose.isTaken ? accent : secondaryInk)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(dose.isTaken ? String(localized: "Taken, \(dose.medicine.name)") : String(localized: "Mark \(dose.medicine.name) taken"))
        }
    }

    private func ring(size: CGFloat, lineWidth: CGFloat) -> some View {
        ZStack {
            Circle().stroke(accent.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(taken)/\(doses.count)")
                .font(.system(size: size * 0.26, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.6)
        }
        .frame(width: size, height: size)
    }

    // Lock Screen

    private var circular: some View {
        Gauge(value: progress) {
            Image(systemName: "pills.fill")
        } currentValueLabel: {
            Text("\(taken)/\(doses.count)")
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetAccentable()
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            Label("Doseday", systemImage: "pills.fill")
                .font(.system(size: 12, weight: .semibold))
                .widgetAccentable()
            if let next {
                Text(next.medicine.name).font(.system(size: 15, weight: .bold)).lineLimit(1)
                Text(next.at <= entry.date ? "Due now" : String(localized: "at \(next.time.label)"))
                    .font(.system(size: 13))
            } else {
                Text(doses.isEmpty ? "No doses today" : "All doses taken").font(.system(size: 15, weight: .bold))
                Text("\(taken) of \(doses.count) taken").font(.system(size: 13))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var inline: some View {
        if let next {
            Label("\(next.medicine.name) · \(next.time.label)", systemImage: "pills.fill")
        } else {
            Label("\(taken)/\(doses.count) doses taken", systemImage: "checkmark.circle")
        }
    }
}

// MARK: - Mood

/// Five faces: tap one to log today's mood. Once logged, today's face with
/// the others small underneath to change it.
struct MoodWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DosedayMood", provider: DosedayProvider()) { entry in
            MoodWidgetView(entry: entry)
                .widgetURL(URL(string: "doseday://mood"))
                .containerBackground(for: .widget) { Color(.systemBackground) }
        }
        .configurationDisplayName("Mood")
        .description(String(localized: "Log how you feel with one tap."))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct MoodWidgetView: View {
    let entry: DosedayEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let today = entry.snapshot.mood(on: entry.date)
        VStack(alignment: .leading, spacing: family == .systemSmall ? 6 : 10) {
            HStack {
                Text(today == nil ? "How are you?" : "Today")
                    .font(.system(size: family == .systemSmall ? 14 : 16, weight: .bold))
                Spacer()
                if let today {
                    Text(today.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(today.tint)
                }
            }
            if let today, family == .systemSmall {
                today.image
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if family == .systemMedium || today == nil {
                Spacer(minLength: 0)
                faces(selected: today, size: family == .systemSmall ? 24 : 44)
            }
        }
        .fontDesign(.rounded)
    }

    private func faces(selected: SharedData.Mood?, size: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(SharedData.Mood.allCases) { mood in
                Button(intent: LogMoodIntent(mood: mood.rawValue)) {
                    VStack(spacing: 3) {
                        mood.image
                            .resizable()
                            .scaledToFit()
                            .frame(width: size, height: size)
                            .opacity(selected == nil || selected == mood ? 1 : 0.4)
                            .scaleEffect(selected == mood ? 1.12 : 1)
                        if family == .systemMedium {
                            Text(mood.title)
                                .font(.system(size: 10, weight: selected == mood ? .bold : .medium))
                                .foregroundStyle(selected == mood ? mood.tint : secondaryInk)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(mood.title)
            }
        }
    }
}

// MARK: - Supply

/// The medicine that runs out soonest: days left on a ring.
struct SupplyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DosedaySupply", provider: DosedayProvider()) { entry in
            SupplyWidgetView(entry: entry)
                .widgetURL(entry.snapshot.lowestSupply.flatMap { URL(string: "doseday://medicine/\($0.id.uuidString)") } ?? URL(string: "doseday://today"))
                .containerBackground(for: .widget) { Color(.systemBackground) }
        }
        .configurationDisplayName("Supply")
        .description(String(localized: "The medicine that runs out soonest."))
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

struct SupplyWidgetView: View {
    let entry: DosedayEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let medicine = entry.snapshot.lowestSupply {
            let days = medicine.daysLeft
            let tint: Color = days < 5 ? .red : days < 10 ? .orange : .green
            if family == .accessoryCircular {
                Gauge(value: Double(min(days, 30)), in: 0...30) {
                    Image(systemName: medicine.symbol)
                } currentValueLabel: {
                    Text("\(days)d")
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .widgetAccentable()
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: medicine.symbol)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(medicine.tint, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        Spacer()
                        Text("Supply")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(secondaryInk)
                    }
                    Spacer(minLength: 0)
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(days)")
                            .font(.system(size: 38, weight: .heavy))
                            .foregroundStyle(tint)
                        Text(days == 1 ? "day left" : "days left")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(secondaryInk)
                    }
                    Text(medicine.name)
                        .font(.system(size: 14, weight: .bold))
                        .lineLimit(1)
                    Text("\(medicine.stock) left")
                        .font(.system(size: 12))
                        .foregroundStyle(secondaryInk)
                }
                .fontDesign(.rounded)
            }
        } else {
            VStack(spacing: 6) {
                Image(systemName: "pills.fill").font(.system(size: 26)).foregroundStyle(accent)
                Text("Add a medicine in Doseday").font(.system(size: 13, weight: .semibold)).multilineTextAlignment(.center)
            }
        }
    }
}
