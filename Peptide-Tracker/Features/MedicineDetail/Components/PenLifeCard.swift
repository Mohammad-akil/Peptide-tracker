import SwiftUI

/// "In use": when the pen, vial or bottle was opened, how long it can be
/// used once open (the user copies it from the leaflet), and a nudge to
/// take it out of the fridge before each dose. The discard date gets its
/// own reminder.
struct PenLifeCard: View {
    @Environment(MedicineStore.self) private var store
    @Environment(AppRouter.self) private var router
    let medicine: Medicine
    let now: Date

    static let usableOptions = [7, 14, 21, 28, 30, 42, 56, 60, 90]
    static let prepOptions = [15, 30, 45, 60]

    /// Types that usually come in something opened and used over weeks.
    static func applies(to type: MedicineType) -> Bool {
        [.injection, .liquid, .drops, .inhaler, .cream].contains(type)
    }

    private var noun: String {
        switch medicine.type {
        case .injection: String(localized: "pen or vial")
        case .inhaler: "inhaler"
        case .cream: "tube"
        default: "bottle"
        }
    }

    var body: some View {
        GroupedSection(
            title: String(localized: "In use"),
            trailing: trailing,
            footer: String(localized: "Copy the “use within” time from the leaflet. You get a reminder the day before it’s due to be thrown away.")
        ) {
            if let opened = medicine.openedAt, medicine.discardDate != nil {
                statusRow(opened: opened)
            }

            HStack {
                Text("Usable once opened").font(.system(size: 17))
                Spacer()
                Menu {
                    Picker("Usable once opened", selection: Binding(
                        get: { medicine.usableDaysAfterOpening ?? 0 },
                        set: { store.setUsableDays($0 == 0 ? nil : $0, for: medicine.id) }
                    )) {
                        Text("Not tracked").tag(0)
                        ForEach(Self.usableOptions, id: \.self) { Text("\($0) days").tag($0) }
                    }
                } label: {
                    menuLabel((medicine.usableDaysAfterOpening ?? 0) > 0 ? String(localized: "\(medicine.usableDaysAfterOpening!) days") : String(localized: "Not tracked"))
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .rowDivider(true)

            if medicine.type == .injection {
                HStack {
                    Text("Out-of-fridge reminder").font(.system(size: 17))
                    Spacer()
                    Menu {
                        Picker("Out-of-fridge reminder", selection: Binding(
                            get: { medicine.prepMinutes ?? 0 },
                            set: { store.setPrepMinutes($0 == 0 ? nil : $0, for: medicine.id) }
                        )) {
                            Text("Off").tag(0)
                            ForEach(Self.prepOptions, id: \.self) { Text("\($0) min before").tag($0) }
                        }
                    } label: {
                        menuLabel(medicine.hasPrepReminder ? String(localized: "\(medicine.prepMinutes!) min before") : String(localized: "Off"))
                    }
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                .rowDivider(true)
            }

            Button {
                HapticFeedback.selection()
                store.markOpened(medicine.id)
                router.showToast(String(localized: "New \(noun) opened today"))
            } label: {
                Label("Opened a new \(noun)", systemImage: "sparkles")
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

    private var trailing: String? {
        guard let days = medicine.daysUntilDiscard(now: now) else { return nil }
        if days < 0 { return String(localized: "Past use-by") }
        return days == 0 ? String(localized: "Use by today") : (days == 1 ? String(localized: "1 day left") : String(localized: "\(days) days left"))
    }

    private func statusRow(opened: Date) -> some View {
        let days = medicine.daysUntilDiscard(now: now) ?? 0
        let urgency: Urgency = days < 0 ? .out : days <= 2 ? .critical : days <= 5 ? .low : .healthy
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Opened \(opened.weekdayDayMonth)")
                    .font(.system(size: 17))
                Text("Throw away after \(medicine.discardDate!.weekdayDayMonth)")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
            }
            Spacer(minLength: 8)
            UrgencyChip(urgency: urgency, text: days < 0 ? String(localized: "Expired") : days == 0 ? String(localized: "Today") : "\(days)d")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 60)
        .rowDivider(true)
    }

    private func menuLabel(_ text: String) -> some View {
        HStack(spacing: 4) {
            Text(text)
            Image(systemName: "chevron.up.chevron.down").font(.system(size: 12, weight: .semibold))
        }
        .font(.system(size: 17))
        .foregroundStyle(AppTheme.ColorToken.secondaryText)
    }
}
