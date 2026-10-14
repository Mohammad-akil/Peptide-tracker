import SwiftUI

/// The Today tab answers one question first: do I need to do anything? A
/// refill card shows only when a medicine needs one; otherwise "You're all
/// set" with what runs out next. Below that, today's doses as a list or a
/// timeline.
struct TodayView: View {
    enum Mode: String, CaseIterable {
        case list, timeline

        var title: String { self == .list ? "List" : "Timeline" }
        var icon: AppIcon { self == .list ? .list : .timeline }
    }

    @Environment(MedicineStore.self) private var store
    @Environment(AppRouter.self) private var router
    @AppStorage("today.mode") private var mode: Mode = .list
    @Environment(PurchaseStore.self) private var purchases
    @Environment(\.scenePhase) private var scenePhase
    /// iOS-level permission, which can be switched off outside the app.
    @State private var systemNotificationsDenied = false

    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = context.date
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.cardGap) {
                    ScreenHeader(title: "Today", subtitle: now.longWeekdayDayMonth) {
                        RemindersMenu(now: now)
                    }
                    .padding(.bottom, 10)

                    if store.medicines.isEmpty {
                        TodayEmptyState(
                            onAdd: { router.requestAddMedicine(count: store.medicines.count, purchases: purchases) },
                            onLearnMore: { router.selectedTab = .medicines }
                        )
                    } else {
                        if systemNotificationsDenied || !store.settings.notificationsEnabled {
                            NotificationsOffBanner(isDenied: systemNotificationsDenied)
                        }
                        RefillStatusSection(now: now)
                        if !store.settings.tracksDoses {
                            Text("Doses")
                                .font(.system(size: 20, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.top, 6)
                            DosesOffCard { router.selectedTab = .settings }
                        } else {
                            dosesHeader(now: now)
                                .padding(.top, 6)
                            let doses = store.doses(on: now)
                            switch mode {
                            case .list:
                                DoseListView(doses: doses, day: now.startOfDay, now: now)
                            case .timeline:
                                DoseTimelineView(doses: doses, day: now.startOfDay, now: now)
                            }
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.medium)
                .padding(.top, 8)
                .padding(.bottom, AppTheme.Spacing.tabBarClearance)
                .animation(.snappy, value: mode)
            }
            .scrollIndicators(.hidden)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .onChange(of: now.startOfDay) { _, _ in
                store.runDailyCountdown(now: now)
            }
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            systemNotificationsDenied = await store.scheduler.authorizationStatus() == .denied
        }
    }

    private func dosesHeader(now: Date) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Doses")
                    .font(.system(size: 20, weight: .bold))
                    .kerning(-0.3)
                Text(dosesSubtitle(now: now))
                    .font(.system(size: 14))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    .contentTransition(.numericText())
            }
            Spacer(minLength: 0)
            PillSegmentedControl(options: Mode.allCases, selection: $mode) { option in
                AnyView(Label { Text(option.title) } icon: { Icon(option.icon, size: 16) }.labelStyle(.titleAndIcon))
            }
            .fixedSize()
        }
        .padding(.horizontal, 4)
    }

    /// "3 of 9 taken · next at 20:00"
    private func dosesSubtitle(now: Date) -> String {
        let doses = store.doses(on: now)
        let taken = doses.filter(\.isTaken).count
        let summary = "\(taken) of \(doses.count) taken"
        guard let next = doses.first(where: { !$0.isTaken && $0.scheduledAt >= now }) else {
            return taken == doses.count ? "All \(doses.count) taken today" : summary
        }
        return "\(summary) · next at \(next.time.label)"
    }
}

// MARK: - Refill status

/// "Amlodipine needs a refill." with Ordered / Refilled, or "You're all
/// set." with the next few run-out dates.
private struct RefillStatusSection: View {
    @Environment(MedicineStore.self) private var store
    @Environment(AppRouter.self) private var router
    let now: Date

    var body: some View {
        let needing = store.medicinesNeedingRefill(now: now)

        VStack(alignment: .leading, spacing: AppTheme.Spacing.cardGap) {
            VStack(alignment: .leading, spacing: 4) {
                Text(headline(needing))
                    .font(.system(size: 22, weight: .bold))
                    .kerning(-0.3)
                Text(subtitle(needing))
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
            }
            .padding(.horizontal, 4)
            .accessibilityElement(children: .combine)

            if needing.isEmpty {
                upcomingCard
            } else {
                ForEach(needing) { medicine in
                    RefillCard(medicine: medicine, now: now)
                }
            }
        }
        .animation(.snappy, value: needing.map(\.id))
    }

    private func headline(_ needing: [Medicine]) -> String {
        let waiting = needing.filter { !$0.isOrdered }
        switch waiting.count {
        case 0 where !needing.isEmpty:
            return needing.count == 1 ? "\(needing[0].name) is on order." : "Your refills are on order."
        case 0: return "You’re all set."
        case 1: return "\(waiting[0].name) needs a refill."
        default: return "\(waiting.count) medicines need a refill."
        }
    }

    private func subtitle(_ needing: [Medicine]) -> String {
        if needing.isEmpty {
            guard let next = store.nextReminder(now: now) else { return "Nothing runs out soon." }
            return "Next reminder \(next.date.weekdayDayMonth) for \(next.medicine.name)."
        }
        let others = store.medicines.filter { medicine in !needing.contains { $0.id == medicine.id } }
        guard let soonest = others.map(\.daysLeft).min() else { return "Tap Refilled when you’ve picked it up." }
        return soonest >= 7
            ? "Everything else lasts at least a week."
            : "Everything else lasts at least \(soonest) \(soonest == 1 ? "day" : "days")."
    }

    /// The three medicines that run out soonest.
    private var upcomingCard: some View {
        let upcoming = Array(store.medicinesByUrgency.prefix(3))
        return VStack(spacing: 0) {
            ForEach(Array(upcoming.enumerated()), id: \.element.id) { index, medicine in
                Button { router.push(.medicine(medicine.id)) } label: {
                    HStack(spacing: 12) {
                        StockRingIcon(medicine: medicine, size: 40)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(medicine.name)
                                .font(.system(size: 17))
                                .foregroundStyle(AppTheme.ColorToken.primaryText)
                            Text("Runs out \(medicine.runOutDate(now: now).weekdayDayMonth)")
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.ColorToken.secondaryText)
                        }
                        Spacer(minLength: 8)
                        Text(medicine.daysLeftLabel)
                            .font(.system(size: 15, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(medicine.urgency.ink)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(minHeight: 52)
                    .contentShape(.rect)
                    .rowDivider(index < upcoming.count - 1, inset: 68)
                }
                .buttonStyle(RowPressStyle())
            }
        }
        .groupedCard()
    }
}

/// One medicine that needs a refill: what's left and when it runs out, with
/// Ordered beside Refilled. Once ordered, only Refilled is left to do.
struct RefillCard: View {
    @Environment(MedicineStore.self) private var store
    @Environment(AppRouter.self) private var router
    let medicine: Medicine
    let now: Date

    var body: some View {
        VStack(spacing: 14) {
            Button { router.push(.medicine(medicine.id)) } label: {
                HStack(spacing: 12) {
                    StockRingIcon(medicine: medicine)
                    VStack(alignment: .leading, spacing: 1) {
                        (Text(medicine.name).fontWeight(.semibold)
                         + Text(medicine.strength.isEmpty ? "" : " \(medicine.strength)")
                            .foregroundStyle(AppTheme.ColorToken.secondaryText))
                            .font(.system(size: 17))
                            .foregroundStyle(AppTheme.ColorToken.primaryText)
                        Text(statusLine)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(medicine.isOrdered ? AppTheme.ColorToken.accentInk : medicine.urgency.ink)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                if !medicine.isOrdered && medicine.urgency != .out {
                    Button("Ordered") {
                        HapticFeedback.selection()
                        withAnimation(.snappy) { store.markOrdered(medicine.id) }
                        router.showToast("Ordered. Reminders paused until pickup")
                    }
                    .buttonStyle(.secondary)
                }
                Button { router.sheet = .refill(medicine.id) } label: {
                    Label { Text("Refilled") } icon: { Icon(.up, size: 19) }
                }
                .buttonStyle(.primary(height: 48))
            }
        }
        .padding(14)
        .groupedCard()
    }

    private var statusLine: String {
        let left = "\(medicine.unit.format(medicine.stock)) left"
        if let orderedAt = medicine.orderedAt {
            return "Ordered \(orderedAt.weekdayDayMonth) · \(left)"
        }
        if medicine.urgency == .out { return "Run out · \(left)" }
        return "\(left) · runs out \(medicine.runOutDate(now: now).weekdayDayMonth)"
    }
}

// MARK: - Header bell

/// The bell in Today's header. A red dot means something needs refilling;
/// the menu lists the reminders coming up.
private struct RemindersMenu: View {
    @Environment(MedicineStore.self) private var store
    @Environment(AppRouter.self) private var router
    let now: Date

    var body: some View {
        Menu {
            let medicines = store.medicinesByUrgency.filter { !$0.remindersPaused }
            if medicines.isEmpty {
                Text("No reminders yet")
            }
            ForEach(medicines) { medicine in
                Button {
                    router.push(.medicine(medicine.id))
                } label: {
                    Label(reminderLabel(medicine), systemImage: medicine.isOrdered ? "shippingbox" : medicine.urgency <= .critical ? "exclamationmark.circle" : "bell")
                }
            }
        } label: {
            Icon(.bell, size: 20)
                .foregroundStyle(AppTheme.ColorToken.primaryText)
                .frame(width: 44, height: 44)
                .overlay(alignment: .topTrailing) {
                    if store.medicinesNeedingRefill(now: now).contains(where: { !$0.isOrdered }) {
                        Circle()
                            .fill(AppTheme.ColorToken.destructive)
                            .frame(width: 9, height: 9)
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                            .offset(x: -9, y: 9)
                    }
                }
        }
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("Reminders")
    }

    private func reminderLabel(_ medicine: Medicine) -> String {
        if medicine.isOrdered { return "\(medicine.name) · ordered" }
        let date = medicine.reminderDate(now: now)
        return "\(medicine.name) · \(date <= now ? "sent" : "on") \(date.dayMonth)"
    }
}

// MARK: - Empty and edge states

/// No medicines yet: what Today will do, and the way in.
private struct TodayEmptyState: View {
    let onAdd: () -> Void
    let onLearnMore: () -> Void

    var body: some View {
        EmptyStateView(
            illustration: .welcome,
            title: "Nothing to track yet",
            message: "Add the medicines you take and Today will show what to do and when."
        ) {
            Button("Add your first medicine", action: onAdd)
                .buttonStyle(.primary(height: 52))
            Button("See how it works", action: onLearnMore)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(AppTheme.ColorToken.accent)
                .frame(height: 44)
        }
        .padding(.top, 12)
    }
}

/// Dose tracking is off: the count runs from the schedule, so there's
/// nothing to tick.
private struct DosesOffCard: View {
    let onTurnOn: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            IllustrationView(.noDosesToday, width: 112)
            VStack(alignment: .leading, spacing: 2) {
                Text("Dose reminders are off")
                    .font(.system(size: 16, weight: .semibold))
                Text("We count down from your schedule. Turn them on to tick off doses.")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Turn on in Settings", action: onTurnOn)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.ColorToken.accent)
                    .frame(height: 36)
            }
            Spacer(minLength: 0)
        }
        .card(horizontal: 14, vertical: 12, radius: 22)
    }
}

/// Reminders can't arrive: shown above everything until notifications are
/// back on.
private struct NotificationsOffBanner: View {
    @Environment(MedicineStore.self) private var store
    @Environment(\.openURL) private var openURL
    let isDenied: Bool

    var body: some View {
        HStack(spacing: 12) {
            IllustrationView(.notificationsOff, width: 80)
            VStack(alignment: .leading, spacing: 2) {
                Text("Reminders can’t reach you")
                    .font(.system(size: 15, weight: .bold))
                Text("Notifications are off for this app.")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
            }
            Spacer(minLength: 0)
            Button("Turn on", action: turnOn)
                .buttonStyle(PrimaryButtonStyle(height: 40, fullWidth: false))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(AppTheme.ColorToken.cardBackground, in: .rect(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22).strokeBorder(Urgency.low.tint, lineWidth: 1.5)
        }
    }

    private func turnOn() {
        Task {
            switch await store.scheduler.authorizationStatus() {
            case .notDetermined:
                store.settings.notificationsEnabled = await store.scheduler.requestAuthorization()
            case .denied:
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            default:
                store.settings.notificationsEnabled = true
            }
        }
    }
}

#Preview {
    TodayView()
        .environment(MedicineStore.preview())
        .environment(AppRouter())
        .background(AppTheme.ColorToken.background)
}
