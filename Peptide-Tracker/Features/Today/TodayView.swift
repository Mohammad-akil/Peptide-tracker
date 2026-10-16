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
    /// iOS-level permission, which can be switched off outside the app.
    @State private var systemNotificationsDenied = false
    @State private var viewportHeight: CGFloat = 0
    /// The day whose doses show; today unless another is picked.
    @State private var selectedDay = Date.now.startOfDay
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
                        } else {
                            CompactNote(symbol: "checklist", tint: AppTheme.ColorToken.accent, title: "Dose tracking is off", action: "Turn on") {
                                router.selectedTab = .settings
                            }
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.medium)
                .padding(.top, 20)
                .padding(.bottom, AppTheme.Spacing.tabBarClearance)
                .fillsViewport(store.medicines.isEmpty, height: viewportHeight)
            }
            .measuresViewport($viewportHeight)
            .scrollIndicators(.hidden)
            // Pinned: the week stays put while the doses slide under it.
            .safeAreaInset(edge: .top, spacing: 0) { topPanel(now: now) }
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
        TopPanel(title: selectedDay.monthName) {
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
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
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

    // MARK: Needs doing

    @ViewBuilder
    private func alerts(now: Date) -> some View {
        let needing = store.medicinesNeedingRefill(now: now)
        let notificationsOff = systemNotificationsDenied || !store.settings.notificationsEnabled
        if notificationsOff {
            CompactNote(symbol: "bell.slash.fill", tint: Urgency.low.tint, title: "Reminders are off", action: "Turn on", onAction: turnOn)
        }
        if !needing.isEmpty {
            GroupedSection(title: "Needs refill", trailing: "\(needing.count)") {
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
                DoseSchedule(doses: doses, day: selectedDay, now: now)
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
        medicine.isOrdered ? "On order" : medicine.daysLeftLabel
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

// MARK: - Empty state

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

#Preview {
    TodayView()
        .environment(MedicineStore.preview())
        .environment(AppRouter())
        .environment(PurchaseStore())
        .background(AppTheme.ColorToken.background)
}
