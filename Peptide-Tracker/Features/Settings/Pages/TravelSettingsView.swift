import SwiftUI

/// One medicine's line in the trip planner.
struct TripSupplyLine: Identifiable {
    let medicine: Medicine
    let tripDays: Int
    /// Doses due over the trip and the spare days.
    let doses: Int
    /// Units those doses use.
    let units: Int
    /// What should be left by the day the trip starts.
    let onHandAtStart: Int

    var id: UUID { medicine.id }
    var isShort: Bool { onHandAtStart < units }
    var shortBy: Int { max(0, units - onHandAtStart) }
}

/// Settings → Travel: keep dose reminders on home time across time zones,
/// and work out what to pack for a trip. Counting only — how much to take
/// is always the prescriber's call.
struct TravelSettingsView: View {
    @Environment(MedicineStore.self) private var store
    @State private var start = Date.now.startOfDay.adding(days: 7)
    @State private var end = Date.now.startOfDay.adding(days: 13)
    @AppStorage("travel.spareDays") private var spareDays = 2

    var body: some View {
        SettingsPageScaffold(page: .travel) {
            timeZoneSection
            tripSection
        }
    }

    // MARK: Time zone

    private var timeZoneSection: some View {
        let settings = store.settings
        let home = settings.homeTimeZoneID.flatMap(TimeZone.init(identifier:))
        let isAway = settings.keepsHomeTime && home.map { $0.secondsFromGMT() != TimeZone.current.secondsFromGMT() } == true

        return VStack(alignment: .leading, spacing: 22) {
            GroupedSection(
                title: "Time zone",
                footer: settings.keepsHomeTime
                    ? "Dose reminders stay on \(home.map(Self.cityName) ?? "home") time wherever you are, so the gap between doses doesn’t change. Turn it off to switch to local time."
                    : "Off: reminders follow the clock where you are, so an 8:00 dose comes at 8:00 local time."
            ) {
                ControlRow(symbol: "globe.europe.africa.fill", tint: Color(hex: 0x0A84FF), title: "Keep home time", showsDivider: settings.keepsHomeTime) {
                    Toggle("Keep home time", isOn: Binding(
                        get: { store.settings.keepsHomeTime },
                        set: { isOn in
                            withAnimation(.snappy) {
                                store.settings.keepsHomeTime = isOn
                                if isOn, store.settings.homeTimeZoneID == nil {
                                    store.settings.homeTimeZoneID = TimeZone.current.identifier
                                }
                            }
                        }
                    ))
                    .labelsHidden()
                    .tint(AppTheme.ColorToken.accent)
                }
                if settings.keepsHomeTime {
                    ValueRow(title: "Home", value: home.map(Self.cityName) ?? "Not set", showsChevron: false, showsDivider: true)
                    Button {
                        HapticFeedback.selection()
                        store.settings.homeTimeZoneID = TimeZone.current.identifier
                    } label: {
                        Text("Set home to \(Self.cityName(.current))")
                            .font(.system(size: 17))
                            .foregroundStyle(AppTheme.ColorToken.accent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 52)
                            .contentShape(.rect)
                    }
                    .buttonStyle(RowPressStyle())
                }
            }

            if isAway, let home {
                GroupedSection(title: "Your dose times here", footer: "Home time on the left, local time on the right.") {
                    let times = Array(Set(store.medicines.flatMap(\.intakeTimes))).sorted()
                    ForEach(Array(times.enumerated()), id: \.element) { index, time in
                        ValueRow(
                            title: "\(time.label) \(Self.cityName(home))",
                            value: Self.localLabel(time, home: home),
                            showsChevron: false,
                            showsDivider: index < times.count - 1
                        )
                    }
                }
            }
        }
    }

    // MARK: Trip planner

    private var tripSection: some View {
        let lines = store.tripSupply(from: start, to: end, spareDays: spareDays)

        return VStack(alignment: .leading, spacing: 22) {
            GroupedSection(title: "Trip planner", footer: "Counts the doses on your schedule for the trip, plus spare days in case of delays.") {
                DatePicker("Leaving", selection: $start, in: Date.now.startOfDay..., displayedComponents: .date)
                    .font(.system(size: 17))
                    .padding(.horizontal, 16)
                    .frame(minHeight: 52)
                    .rowDivider(true)
                DatePicker("Back", selection: $end, in: start..., displayedComponents: .date)
                    .font(.system(size: 17))
                    .padding(.horizontal, 16)
                    .frame(minHeight: 52)
                    .rowDivider(true)
                HStack {
                    Text("Spare days").font(.system(size: 17))
                    Spacer()
                    CountStepper(value: $spareDays, range: 0...7, accessibilityName: "Spare days")
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
            }
            .onChange(of: start) { _, new in if end < new { end = new } }

            if lines.isEmpty {
                Text("Nothing on your schedule for those days.")
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    .padding(.horizontal, 16)
            } else {
                GroupedSection(title: "Pack", trailing: "\(lines.first?.tripDays ?? 0) days") {
                    ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                        packRow(line, showsDivider: index < lines.count - 1)
                    }
                }
                if lines.contains(where: { $0.medicine.type == .injection }) {
                    Label("Pack injections in your hand luggage with a cool bag, and keep the prescription or a letter from your doctor with them.", systemImage: "snowflake")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.ColorToken.accentInk)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.ColorToken.accentSoft, in: .rect(cornerRadius: 18, style: .continuous))
                }
            }
        }
    }

    private func packRow(_ line: TripSupplyLine, showsDivider: Bool) -> some View {
        HStack(spacing: 12) {
            MedicineIconView(medicine: line.medicine, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(line.medicine.name)
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(1)
                Text("\(line.doses) \(line.doses == 1 ? "dose" : "doses") · \(line.medicine.unit.format(line.units))")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
            }
            Spacer(minLength: 8)
            if line.isShort {
                UrgencyChip(urgency: .critical, text: "Short \(line.shortBy)")
            } else {
                UrgencyChip(urgency: .healthy, text: "Covered")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 60)
        .rowDivider(showsDivider, inset: 64)
    }

    // MARK: Formatting

    /// "London" from "Europe/London".
    nonisolated static func cityName(_ zone: TimeZone) -> String {
        zone.identifier.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") } ?? zone.identifier
    }

    /// A home-time dose time, as the local clock shows it.
    static func localLabel(_ time: TimeOfDay, home: TimeZone) -> String {
        var calendar = Calendar.current
        calendar.timeZone = home
        let date = time.on(Date.now, calendar: calendar)
        return date.formatted(.dateTime.hour().minute())
    }
}
