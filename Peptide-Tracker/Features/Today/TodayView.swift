import SwiftUI

/// Home: the week up top, then the picked day's doses grouped by time.
/// Only what needs doing gets a line above the doses — notifications being
/// off, or a medicine to refill. What runs out next lives under
/// Medicines → Stock.
struct TodayView: View {
    @Environment(MedicineStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(PurchaseStore.self) private var purchases
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    /// List or Timeline, chosen in Settings.
    @AppStorage(DoseLayout.storageKey) private var doseLayout: DoseLayout = .list
    /// iOS-level permission, which can be switched off outside the app.
    @State private var systemNotificationsDenied = false
    @State private var viewportHeight: CGFloat = 0
    /// The day whose doses show; today unless another is picked.
    @State private var selectedDay = Date.now.startOfDay
    /// The calendar (full screen) and mood (sheet) zoom out of their header
    /// buttons; one namespace serves both.
    @State private var showsCalendar = false
    /// The mood sheet zooms out of the mood button the same way.
    @State private var showsMood = false
    @State private var showsShare = false
    /// Whether the next-dose Live Activity is up (ActivityKit isn't observable).
    @State private var isPinned = DoseActivityController.isRunning
    @State private var showsSharps = false
    @Namespace private var calendarZoom
    /// Which way the last day change went, so the doses slide that way.
    @State private var dayMovesForward = true

    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = context.date
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if store.medicines.isEmpty {
                        Spacer(minLength: 0)
                        TodayEmptyState(
                            onAdd: { router.requestAddMedicine(count: store.medicines.count, purchases: purchases) },
                            onLearnMore: { router.selectedTab = .medicines }
                        )
                        Spacer(minLength: 0)
                    } else {
                        alerts(now: now)
                        if store.settings.tracksDoses {
                            dayDoses(now: now)
                            pinNextDose(now: now)
                            dayDoneCard(now: now)
                        } else {
                            CompactNote(symbol: "checklist", tint: AppTheme.ColorToken.accent, title: String(localized: "Dose tracking is off"), action: String(localized: "Turn on")) {
                                router.selectedTab = .settings
                            }
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.medium)
                .readableWidth()
                .padding(.top, 20)
                .padding(.bottom, AppTheme.Spacing.tabBarClearance)
                .fillsViewport(store.medicines.isEmpty, height: viewportHeight)
            }
            .measuresViewport($viewportHeight)
            .scrollIndicators(.hidden)
            // Pinned: the week stays put while the doses slide under it.
            .safeAreaInset(edge: .top, spacing: 0) { topPanel(now: now) }
            // Deep links and notifications ask Today to open something.
            .onAppear { consume(router.todayRequest) }
            .onChange(of: router.todayRequest) { _, request in consume(request) }
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

    // MARK: Top

    /// Pinned panel: the month, the reminders bell and the week.
    private func topPanel(now: Date) -> some View {
        TopPanel(title: selectedDay.monthName, titleValue: Double(monthNumber(of: selectedDay))) {
            HStack(spacing: 8) {
                // Back to today, beside the bell, once another day is picked.
                if selectedDay != now.startOfDay {
                    Button("Today") {
                        HapticFeedback.selection()
                        withAnimation(.snappy) { selectedDay = now.startOfDay }
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.ColorToken.accent)
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .compatGlass(interactive: true, in: .capsule)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
                moodButton(now: now)
                calendarButton
                RemindersMenu(now: now)
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: selectedDay == now.startOfDay)
        } controls: {
            if !store.medicines.isEmpty && store.settings.tracksDoses {
                WeekStrip(selection: $selectedDay, today: now.startOfDay)
            }
        }
        .animation(.snappy, value: selectedDay.monthName)
    }

    /// Months counted from year zero, so the title rolls the right way.
    private func monthNumber(of day: Date) -> Int {
        let parts = Calendar.current.dateComponents([.year, .month], from: day)
        return (parts.year ?? 0) * 12 + (parts.month ?? 0)
    }

    // MARK: Needs doing

    @ViewBuilder
    private func alerts(now: Date) -> some View {
        let needing = store.medicinesNeedingRefill(now: now)
        let notificationsOff = systemNotificationsDenied || !store.settings.notificationsEnabled
        if notificationsOff {
            CompactNote(symbol: "bell.slash.fill", tint: Urgency.low.tint, title: String(localized: "Reminders are off"), action: String(localized: "Turn on"), onAction: turnOn)
        }
        ForEach(store.medicinesNearDiscard(now: now)) { medicine in
            let days = medicine.daysUntilDiscard(now: now) ?? 0
            CompactNote(
                symbol: "calendar.badge.exclamationmark",
                tint: Urgency.low.tint,
                title: days < 0 ? String(localized: "\(medicine.name) is past its use-by") : days == 0 ? String(localized: "Last day for this \(medicine.name)") : (days == 1 ? String(localized: "\(medicine.name): 1 day left once opened") : String(localized: "\(medicine.name): \(days) days left once opened")),
                action: String(localized: "New one")
            ) {
                store.markOpened(medicine.id)
                router.showToast(String(localized: "New \(medicine.name) opened today"))
            }
        }
        if store.settings.tracksSharps, store.sharpsFraction >= 0.9 {
            CompactNote(
                symbol: "trash.square.fill",
                tint: Urgency.critical.tint,
                title: store.sharpsFraction >= 1 ? String(localized: "Sharps container is full") : String(localized: "Sharps container nearly full"),
                action: String(localized: "View")
            ) { showsSharps = true }
            .sheet(isPresented: $showsSharps) { SharpsSheet() }
        }
        if !needing.isEmpty {
            GroupedSection(title: String(localized: "Needs refill"), trailing: "\(needing.count)") {
                ForEach(Array(needing.enumerated()), id: \.element.id) { index, medicine in
                    RefillAlert(medicine: medicine, showsDivider: index < needing.count - 1)
                }
            }
            .animation(.snappy, value: needing.map(\.id))
        }
    }

    // MARK: Doses

    /// The picked day's doses, sliding in from the side you moved to.
    /// Swiping sideways changes the day too.
    @ViewBuilder
    private func dayDoses(now: Date) -> some View {
        let doses = store.doses(on: selectedDay)
        Group {
            if doses.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(AppTheme.ColorToken.tertiaryText)
                    Text("No doses this day")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppTheme.ColorToken.secondaryText)
                }
                .frame(maxWidth: .infinity, minHeight: 140)
            } else {
                switch doseLayout {
                case .list: DoseSchedule(doses: doses, day: selectedDay, now: now)
                case .timeline: DoseTimeline(doses: doses, day: selectedDay, now: now)
                case .squarePillbox: DosePillbox(doses: doses, day: selectedDay, now: now, style: .square)
                case .roundPillbox: DosePillbox(doses: doses, day: selectedDay, now: now, style: .round)
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
                let target = selectedDay.adding(days: value.translation.width < 0 ? 1 : -1)
                let weeks = Calendar.current.days(from: now.startOfDay, to: target) / 7
                guard WeekStrip.weekRange.contains(weeks) else { return }
                HapticFeedback.selection()
                withAnimation(.snappy) { selectedDay = target }
            }
        )
    }

    /// A quiet link to put today's next dose on the Lock Screen and in the
    /// Dynamic Island, while there's one still to take.
    @ViewBuilder
    private func pinNextDose(now: Date) -> some View {
        if selectedDay == now.startOfDay, DoseActivityController.isAvailable, store.nextDueDose(now: now) != nil {
            Button {
                HapticFeedback.selection()
                if isPinned {
                    DoseActivityController.end()
                    isPinned = false
                } else {
                    isPinned = DoseActivityController.start(store: store)
                    router.showToast(isPinned
                        ? String(localized: "Next dose pinned to Lock Screen")
                        : String(localized: "Couldn’t pin. Check Live Activities in Settings."))
                }
            } label: {
                Label(isPinned ? "Unpin from Lock Screen" : "Pin next dose to Lock Screen", systemImage: isPinned ? "pin.slash" : "pin.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.ColorToken.accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .onAppear { isPinned = DoseActivityController.isRunning }
        }
    }

    /// Once every one of today's doses is ticked off: a small celebration
    /// with a way to share the moment.
    @ViewBuilder
    private func dayDoneCard(now: Date) -> some View {
        let doses = store.doses(on: now.startOfDay)
        if selectedDay == now.startOfDay, !doses.isEmpty, doses.allSatisfy(\.isTaken) {
            Button {
                HapticFeedback.impact()
                showsShare = true
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "party.popper.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(AppTheme.ColorToken.accent, in: .circle)
                        .symbolEffect(.bounce, value: doses.count)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("All done for today")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AppTheme.ColorToken.primaryText)
                        Text("Share your progress")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.ColorToken.accent)
                }
                .padding(14)
                .groupedCard()
                .contentShape(.rect)
            }
            .buttonStyle(.pressable)
            .transition(.scale(scale: 0.92).combined(with: .opacity))
            .shareMoments(isPresented: $showsShare, start: .today)
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

    private func consume(_ request: AppRouter.TodayRequest?) {
        guard let request else { return }
        router.todayRequest = nil
        switch request {
        case .mood: showsMood = true
        case .calendar: showsCalendar = true
        case .day(let day):
            withAnimation(.snappy) { selectedDay = day.startOfDay }
        }
    }

    /// Today's mood: its face once logged, a smiley until then. Opens the
    /// mood sheet. Styled like the reminders bell.
    private func moodButton(now: Date) -> some View {
        Button {
            HapticFeedback.selection()
            showsMood = true
        } label: {
            Group {
                if let mood = store.checkIn(on: now)?.mood {
                    mood.illustration
                        .resizable()
                        .scaledToFit()
                        .frame(width: 26, height: 26)
                } else {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(AppTheme.ColorToken.primaryText)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .compatGlass(interactive: true, in: .circle)
        .matchedTransitionSource(id: Self.moodZoomID, in: calendarZoom) { $0.background(.clear).clipShape(RoundedRectangle(cornerRadius: 22)) }
        .accessibilityLabel(store.checkIn(on: now).map { String(localized: "Mood: \($0.mood.title)") } ?? "Log your mood")
        .sheet(isPresented: $showsMood) {
            MoodSheet()
                .presentationDetents([.large])
                .navigationTransition(.zoom(sourceID: Self.moodZoomID, in: calendarZoom))
        }
    }

    private static let moodZoomID = "mood"

    /// Opens the dose calendar full screen, zooming out of this button
    /// (and back into it on close or swipe down). Styled like the bell.
    private var calendarButton: some View {
        Button {
            HapticFeedback.selection()
            showsCalendar = true
        } label: {
            Image(systemName: "calendar")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.ColorToken.primaryText)
                .frame(width: 44, height: 44)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .compatGlass(interactive: true, in: .circle)
        .matchedTransitionSource(id: Self.calendarZoomID, in: calendarZoom) { $0.background(.clear).clipShape(RoundedRectangle(cornerRadius: 22)) }
        .accessibilityLabel("Calendar")
        .fullScreenCover(isPresented: $showsCalendar) {
            CalendarView()
                .background(AppTheme.ColorToken.background.ignoresSafeArea())
                .navigationTransition(.zoom(sourceID: Self.calendarZoomID, in: calendarZoom))
        }
    }

    private static let calendarZoomID = "calendar"

}

// MARK: - Rows

/// A medicine that needs refilling, in the same shape as every list row:
/// icon, name, how long it lasts, and Refill. Ordering lives on its page.
private struct RefillAlert: View {
    @Environment(AppRouter.self) private var router
    let medicine: Medicine
    let showsDivider: Bool

    var body: some View {
        HStack(spacing: 14) {
            Button { router.push(.medicine(medicine.id)) } label: {
                HStack(spacing: 14) {
                    MedicineIconView(medicine: medicine, size: 36, isVibrant: true)
                    Text(medicine.name)
                        .font(.system(size: 17))
                        .foregroundStyle(AppTheme.ColorToken.primaryText)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(status)
                        .font(.system(size: 17))
                        .monospacedDigit()
                        .foregroundStyle(medicine.isOrdered ? AppTheme.ColorToken.accent : medicine.urgency.ink)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            Button("Refill") { router.sheet = .refill(medicine.id) }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(height: 32)
                .background(AppTheme.ColorToken.accent, in: .capsule)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 60)
        .rowDivider(showsDivider, inset: 66)
    }

    /// "3 days", "Run out", "On order"
    private var status: String {
        medicine.isOrdered ? String(localized: "On order") : medicine.daysLeftLabel
    }
}

/// A one-line notice with a single action ("Reminders are off · Turn on").
private struct CompactNote: View {
    let symbol: String
    let tint: Color
    let title: String
    let action: String
    let onAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.13), in: .circle)
            Text(title)
                .font(.system(size: 16, weight: .semibold))
            Spacer(minLength: 0)
            Button(action, action: onAction)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.ColorToken.accent)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(AppTheme.ColorToken.accentSoft, in: .capsule)
        }
        .padding(12)
        .background(AppTheme.ColorToken.cardBackground, in: .rect(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Header bell

/// The bell in Today's header. A red dot means something needs refilling;
/// the menu lists the reminders coming up.
private struct RemindersMenu: View {
    @Environment(MedicineStore.self) private var store
    let now: Date

    @State private var isOpen = false

    var body: some View {
        Button {
            HapticFeedback.selection()
            isOpen = true
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
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .compatGlass(interactive: true, in: .circle)
        .accessibilityLabel("Reminders")
        .popover(isPresented: $isOpen, arrowEdge: .top) {
            RemindersList(now: now) { isOpen = false }
                .presentationCompactAdaptation(.popover)
        }
    }
}

/// What kind of reminder a medicine has, each with its own colour, so the
/// list reads at a glance: run out and running out in red, low in amber,
/// ordered in blue, the rest in the app's purple.
enum ReminderKind {
    case out, critical, low, ordered, scheduled

    init(_ medicine: Medicine) {
        if medicine.isOrdered { self = .ordered; return }
        switch medicine.urgency {
        case .out: self = .out
        case .critical: self = .critical
        case .low: self = .low
        case .healthy: self = .scheduled
        }
    }

    var symbol: String {
        switch self {
        case .out: "exclamationmark.triangle.fill"
        case .critical: "exclamationmark.circle.fill"
        case .low: "hourglass"
        case .ordered: "shippingbox.fill"
        case .scheduled: "bell.fill"
        }
    }

    var tint: Color {
        switch self {
        case .out, .critical: Urgency.critical.tint
        case .low: Color(hex: 0xFF9F0A)
        case .ordered: Color(hex: 0x0A84FF)
        case .scheduled: AppTheme.ColorToken.accent
        }
    }

    var title: String {
        switch self {
        case .out: String(localized: "Run out")
        case .critical: String(localized: "Running out")
        case .low: String(localized: "Getting low")
        case .ordered: String(localized: "Ordered")
        case .scheduled: String(localized: "Reminder set")
        }
    }
}

/// The bell's popover: every refill reminder, most urgent first, each
/// with a coloured icon for its kind. Tapping one opens the medicine.
private struct RemindersList: View {
    @Environment(MedicineStore.self) private var store
    @Environment(AppRouter.self) private var router
    let now: Date
    let close: () -> Void

    var body: some View {
        let medicines = store.medicinesByUrgency.filter { !$0.remindersPaused }

        VStack(alignment: .leading, spacing: 0) {
            Text("Reminders")
                .font(.system(size: 17, weight: .bold))
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            if medicines.isEmpty {
                Text("No reminders yet")
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(medicines.enumerated()), id: \.element.id) { index, medicine in
                            row(medicine, showsDivider: index < medicines.count - 1)
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxHeight: 380)
            }

            if !store.medicines.isEmpty {
                Button {
                    close()
                    router.push(.reminders)
                } label: {
                    HStack {
                        Text("See all")
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                        Image(systemName: "chevron.forward")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(AppTheme.ColorToken.accent)
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .contentShape(.rect)
                    .overlay(alignment: .top) {
                        Rectangle().fill(AppTheme.ColorToken.separator).frame(height: 0.5)
                    }
                }
                .buttonStyle(RowPressStyle())
                .accessibilityLabel("See all reminders")
            }
        }
        .frame(width: 330)
    }

    private func row(_ medicine: Medicine, showsDivider: Bool) -> some View {
        let kind = ReminderKind(medicine)
        return Button {
            close()
            router.push(.medicine(medicine.id))
        } label: {
            HStack(spacing: 12) {
                SettingsTile(symbol: kind.symbol, tint: kind.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(medicine.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.ColorToken.primaryText)
                        .lineLimit(1)
                    Text(detail(medicine, kind: kind))
                        .font(.system(size: 13))
                        .foregroundStyle(kind == .scheduled ? AppTheme.ColorToken.secondaryText : kind.tint)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Chevron()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(.rect)
            .rowDivider(showsDivider, inset: 58)
        }
        .buttonStyle(RowPressStyle())
        .accessibilityLabel("\(medicine.name), \(detail(medicine, kind: kind))")
    }

    /// "Running out · reminder sent 12 Nov", "Ordered · waiting for pickup"
    private func detail(_ medicine: Medicine, kind: ReminderKind) -> String {
        if kind == .ordered { return String(localized: "Ordered · waiting to be picked up") }
        if kind == .out { return String(localized: "Run out · refill now") }
        let date = medicine.reminderDate(now: now)
        return (date <= now ? String(localized: "\(kind.title) · reminder sent \(date.dayMonth)") : String(localized: "\(kind.title) · reminder on \(date.dayMonth)"))
    }
}

// MARK: - Empty state

/// No medicines yet: what Today will do, and the way in.
private struct TodayEmptyState: View {
    let onAdd: () -> Void
    let onLearnMore: () -> Void

    var body: some View {
        EmptyStateView(
            illustration: .welcome,
            title: String(localized: "Nothing to track yet"),
            message: String(localized: "Add the medicines you take and Today will show what to do and when.")
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

#Preview {
    TodayView()
        .environment(MedicineStore.preview())
        .environment(AppRouter())
        .environment(PurchaseStore())
        .background(AppTheme.ColorToken.background)
}
