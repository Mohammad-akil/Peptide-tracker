import SwiftUI

/// "See all" under Today's bell: every medicine's refill reminder, grouped
/// by what needs doing — run out and running out first, then low, ordered,
/// set, and paused last with a way to resume. Tapping one opens the medicine.
struct AllRemindersView: View {
    @Environment(MedicineStore.self) private var store
    @Environment(AppRouter.self) private var router

    /// The groups in the order they need attention.
    private enum Bucket: CaseIterable {
        case needsAction, low, ordered, scheduled, paused

        var title: String {
            switch self {
            case .needsAction: String(localized: "Needs refill")
            case .low: String(localized: "Getting low")
            case .ordered: String(localized: "Ordered")
            case .scheduled: String(localized: "Coming up")
            case .paused: String(localized: "Paused")
            }
        }

        var footer: String? {
            switch self {
            case .ordered: String(localized: "Reminders pause until you mark these refilled.")
            case .paused: String(localized: "No refill reminders for these until you resume them.")
            default: nil
            }
        }
    }

    var body: some View {
        let now = Date.now
        let grouped = Dictionary(grouping: store.medicinesByUrgency) { group(for: $0) }

        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if store.medicines.isEmpty {
                    EmptyStateView(
                        illustration: .notifications,
                        title: String(localized: "No reminders yet"),
                        message: String(localized: "Add a medicine and you’ll get a reminder a few days before it runs out.")
                    ) { EmptyView() }
                } else {
                    summary(grouped, now: now)

                    ForEach(Bucket.allCases, id: \.self) { group in
                        if let medicines = grouped[group], !medicines.isEmpty {
                            GroupedSection(title: group.title, trailing: "\(medicines.count)", footer: group.footer) {
                                ForEach(Array(medicines.enumerated()), id: \.element.id) { index, medicine in
                                    row(medicine, group: group, now: now, showsDivider: index < medicines.count - 1)
                                }
                            }
                        }
                    }

                    GroupedSection {
                        SettingsLinkRow(page: .reminders, value: store.remindersSummary, showsDivider: false)
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.medium)
            .readableWidth()
            .padding(.top, 8)
            .padding(.bottom, AppTheme.Spacing.large)
            .animation(.snappy, value: store.medicines)
        }
        .scrollIndicators(.hidden)
        .background(AppTheme.ColorToken.background.ignoresSafeArea())
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .compatNavigationBarBlur()
    }

    private func group(for medicine: Medicine) -> Bucket {
        if medicine.remindersPaused { return .paused }
        switch ReminderKind(medicine) {
        case .out, .critical: return .needsAction
        case .low: return .low
        case .ordered: return .ordered
        case .scheduled: return .scheduled
        }
    }

    /// "Next reminder Tue 24 Nov · Metformin", or reminders off.
    @ViewBuilder
    private func summary(_ grouped: [Bucket: [Medicine]], now: Date) -> some View {
        let needing = grouped[.needsAction]?.count ?? 0
        HStack(spacing: 14) {
            Image(systemName: store.settings.notificationsEnabled ? "bell.badge.fill" : "bell.slash.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(store.settings.notificationsEnabled ? AppTheme.ColorToken.accent : Urgency.low.tint, in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(needing > 0 ? (needing == 1 ? String(localized: "1 medicine needs a refill") : String(localized: "\(needing) medicines need a refill")) : "Nothing needs a refill")
                    .font(.system(size: 17, weight: .semibold))
                Group {
                    if !store.settings.notificationsEnabled {
                        Text("Reminders are off in Settings")
                    } else if let next = store.nextReminder(now: now) {
                        Text("Next: \(store.settings.reminderName(for: next.medicine)), \(next.date.weekdayDayMonth) at \(next.date.clockTime)")
                    } else {
                        Text("No reminders scheduled")
                    }
                }
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
                .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .groupedCard()
    }

    private func row(_ medicine: Medicine, group: Bucket, now: Date, showsDivider: Bool) -> some View {
        let kind = ReminderKind(medicine)
        let tint = group == .paused ? AppTheme.ColorToken.tertiaryText : kind.tint

        return HStack(spacing: 12) {
            Button { router.push(.medicine(medicine.id)) } label: {
                HStack(spacing: 12) {
                    SettingsTile(symbol: group == .paused ? "bell.slash.fill" : kind.symbol, tint: tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(medicine.name)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AppTheme.ColorToken.primaryText)
                            .lineLimit(1)
                        Text(detail(medicine, kind: kind, group: group, now: now))
                            .font(.system(size: 14))
                            .foregroundStyle(group == .scheduled || group == .paused ? AppTheme.ColorToken.secondaryText : kind.tint)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    if group != .paused {
                        Text(medicine.daysLeftLabel)
                            .font(.system(size: 15, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(medicine.urgency.tint)
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if group == .paused {
                Button("Resume") {
                    HapticFeedback.selection()
                    withAnimation(.snappy) { store.setRemindersPaused(false, for: medicine.id) }
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.ColorToken.accent)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(AppTheme.ColorToken.accentSoft, in: .capsule)
                .buttonStyle(.plain)
            } else {
                Chevron()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 60)
        .rowDivider(showsDivider, inset: 58)
        .accessibilityElement(children: .combine)
    }

    /// "Reminder sent 12 Nov", "Reminder Tue 24 Nov, 9:00", "Ordered 18 Nov"
    private func detail(_ medicine: Medicine, kind: ReminderKind, group: Bucket, now: Date) -> String {
        if group == .paused { return medicine.urgency == .out ? String(localized: "Reminders paused · run out") : String(localized: "Reminders paused · \(medicine.daysLeftLabel) left") }
        if let ordered = medicine.orderedAt { return String(localized: "Ordered \(ordered.dayMonth) · waiting for pickup") }
        if kind == .out { return String(localized: "Run out · refill now") }
        let date = medicine.reminderDate(now: now)
        return date <= now
            ? String(localized: "Reminder sent \(date.dayMonth)")
            : String(localized: "Reminder \(date.weekdayDayMonth), \(medicine.reminderTime.label)")
    }
}
