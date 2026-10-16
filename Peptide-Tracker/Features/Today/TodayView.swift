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
    @State private var viewportHeight: CGFloat = 0
    /// The day whose doses show below the strip; today unless picked.
    @State private var selectedDay = Date.now.startOfDay
    /// Which way the last day change went, so the list slides that way.
    @State private var dayMovesForward = true

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
                        Spacer(minLength: 0)
                        TodayEmptyState(
                            onAdd: { router.requestAddMedicine(count: store.medicines.count, purchases: purchases) },
                            onLearnMore: { router.selectedTab = .medicines }
                        )
                        Spacer(minLength: 0)
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
                            DayStrip(selection: $selectedDay, today: now.startOfDay)
                                // Edge to edge, past the page's side padding.
                                .padding(.horizontal, -AppTheme.Spacing.medium)
                            dayDoses(now: now)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.medium)
                .padding(.top, 8)
                .padding(.bottom, AppTheme.Spacing.tabBarClearance)
                .fillsViewport(store.medicines.isEmpty, height: viewportHeight)
                .animation(.snappy, value: mode)
            }
            .measuresViewport($viewportHeight)
            .scrollIndicators(.hidden)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .onChange(of: now.startOfDay) { oldDay, newDay in
                store.runDailyCountdown(now: now)
                // Still looking at "today" when midnight passes: follow it.
                if selectedDay == oldDay { selectedDay = newDay }
            }
            .onChange(of: selectedDay) { oldDay, newDay in
                dayMovesForward = newDay > oldDay
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
                HStack(spacing: 8) {
                    Text(dayTitle(now: now))
                        .font(.system(size: 20, weight: .bold))
                        .kerning(-0.3)
                        .contentTransition(.opacity)
                    if selectedDay != now.startOfDay {
                        Button("Today") {
                            HapticFeedback.selection()
                            withAnimation(.snappy) { selectedDay = now.startOfDay }
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.ColorToken.accent)
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background(AppTheme.ColorToken.accentSoft, in: .capsule)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
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

    /// The selected day's doses: list or timeline, sliding in from the side
    /// you moved to. Swiping sideways changes the day too.
    @ViewBuilder
    private func dayDoses(now: Date) -> some View {
        let doses = store.doses(on: selectedDay)
        Group {
            if doses.isEmpty {
                Text("No doses on \(selectedDay.weekdayDayMonth).")
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .background(AppTheme.ColorToken.cardBackground, in: .rect(cornerRadius: 20, style: .continuous))
            } else {
                switch mode {
                case .list:
                    DoseListView(doses: doses, day: selectedDay, now: now)
                case .timeline:
                    DoseTimelineView(doses: doses, day: selectedDay, now: now)
                }
            }
        }
        .id(selectedDay)
        .transition(.asymmetric(
            insertion: .move(edge: dayMovesForward ? .trailing : .leading).combined(with: .opacity),
            removal: .opacity
        ))
        .animation(.snappy(duration: 0.35), value: selectedDay)
        .contentShape(.rect)
        .simultaneousGesture(
            DragGesture(minimumDistance: 30).onEnded { value in
                // Only clearly sideways swipes; vertical ones scroll the page.
                guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                let step = value.translation.width < 0 ? 1 : -1
                let target = selectedDay.adding(days: step)
                let offset = Calendar.current.days(from: now.startOfDay, to: target)
                guard DayStrip.range.contains(offset) else { return }
                HapticFeedback.selection()
                selectedDay = target
            }
        )
    }

    /// "Today", "Yesterday", "Tomorrow", or "Mon 12 Oct".
    private func dayTitle(now: Date) -> String {
        switch Calendar.current.days(from: now.startOfDay, to: selectedDay) {
        case 0: "Today"
        case -1: "Yesterday"
        case 1: "Tomorrow"
        default: selectedDay.weekdayDayMonth
        }
    }

    /// "3 of 9 taken · next at 20:00", or for other days "9 of 9 taken" /
    /// "9 doses planned".
    private func dosesSubtitle(now: Date) -> String {
        let isToday = selectedDay == now.startOfDay
        let doses = store.doses(on: isToday ? now : selectedDay)
        let taken = doses.filter(\.isTaken).count
        if selectedDay > now.startOfDay {
            return doses.count == 1 ? "1 dose planned" : "\(doses.count) doses planned"
        }
        let summary = "\(taken) of \(doses.count) taken"
        guard isToday else { return summary }
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
