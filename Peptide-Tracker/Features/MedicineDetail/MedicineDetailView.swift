import SwiftUI

/// One medicine up close: days left in a big ring, a banner when it needs
/// attention, schedule / reminder / pharmacy, and the stock forecast, with
/// Ordered and Refilled pinned to the bottom.
struct MedicineDetailView: View {
    @Environment(MedicineStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.openURL) private var openURL
    let medicineID: UUID
    @State private var pendingDelete: Medicine?
    @State private var isCorrectingCount = false
    @State private var countDraft = ""

    var body: some View {
        Group {
            if let medicine = store.medicine(id: medicineID) {
                content(medicine)
            } else {
                // Deleted from elsewhere (e.g. a notification action).
                Color.clear.onAppear { pop() }
            }
        }
        .background(AppTheme.ColorToken.background)
        .deleteMedicineAlert($pendingDelete, onDeleted: pop)
    }

    private func content(_ medicine: Medicine) -> some View {
        let now = Date.now
        return ScrollView {
            VStack(spacing: 16) {
                titleBlock(medicine)
                SupplyRing(medicine: medicine, now: now)
                if let banner = banner(for: medicine, now: now) {
                    Label { Text(banner.text) } icon: { Icon(banner.icon, size: 18) }
                        .font(.system(size: 15, weight: .semibold))
                        .lineSpacing(2)
                        .foregroundStyle(banner.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(banner.wash, in: .rect(cornerRadius: 18, style: .continuous))
                }
                infoRows(medicine, now: now)
                StockForecastCard(medicine: medicine, refills: store.refills(for: medicine.id), now: now)
            }
            .padding(.horizontal, AppTheme.Spacing.medium)
            .padding(.bottom, 24)
            .animation(.snappy, value: medicine)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) { bottomBar(medicine) }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { router.sheet = .editMedicine(medicine.id) } label: {
                    Icon(.edit, size: 20)
                }
                .accessibilityLabel("Edit")
                Menu {
                    moreMenu(medicine)
                } label: {
                    Icon(.more, size: 22)
                }
                .accessibilityLabel("More options")
            }
        }
        .alert("Correct \(medicine.unit.singular) count", isPresented: $isCorrectingCount) {
            TextField("\(medicine.unit.plural.capitalizedFirst) left", text: $countDraft)
                .keyboardType(.numberPad)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                if let count = Int(countDraft.trimmingCharacters(in: .whitespaces)) {
                    store.correctStock(medicine.id, to: min(count, 9999))
                }
            }
        } message: {
            Text("How many \(medicine.unit.plural) do you have right now? Use this after missed or extra doses.")
        }
    }

    @ViewBuilder
    private func moreMenu(_ medicine: Medicine) -> some View {
        Button { router.sheet = .editMedicine(medicine.id) } label: {
            Label("Edit", systemImage: "pencil")
        }
        Button {
            countDraft = "\(medicine.stock)"
            isCorrectingCount = true
        } label: {
            Label("Correct \(medicine.unit.singular) count", systemImage: "number")
        }
        Button {
            store.setRemindersPaused(!medicine.remindersPaused, for: medicine.id)
        } label: {
            medicine.remindersPaused
                ? Label("Resume reminders", systemImage: "bell")
                : Label("Pause reminders", systemImage: "bell.slash")
        }
        if medicine.isOrdered {
            Button { store.cancelOrder(medicine.id) } label: {
                Label("Not ordered", systemImage: "shippingbox.and.arrow.backward")
            }
        }
        Divider()
        Button(role: .destructive) { pendingDelete = medicine } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func titleBlock(_ medicine: Medicine) -> some View {
        VStack(spacing: 2) {
            Text(medicine.name)
                .font(.system(size: 28, weight: .bold))
                .kerning(-0.5)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(medicine.detailSubtitle)
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private struct Banner {
        let text: String
        let icon: AppIcon
        let ink: Color
        let wash: Color
    }

    private func banner(for medicine: Medicine, now: Date) -> Banner? {
        if let orderedAt = medicine.orderedAt {
            return Banner(
                text: "Ordered on \(orderedAt.weekdayDayMonth). Tap Refilled when you pick it up.",
                icon: .truck,
                ink: AppTheme.ColorToken.accentInk,
                wash: AppTheme.ColorToken.accentSoft
            )
        }
        switch medicine.urgency {
        case .out:
            return Banner(text: "You’re out. Refill now to restart your reminders.", icon: .alert,
                          ink: medicine.urgency.ink, wash: medicine.urgency.wash)
        case .critical:
            let days = medicine.daysLeft
            return Banner(text: "Runs out in \(days) \(days == 1 ? "day" : "days"). Order a refill today.",
                          icon: .alert, ink: medicine.urgency.ink, wash: medicine.urgency.wash)
        default:
            return nil
        }
    }

    private func infoRows(_ medicine: Medicine, now: Date) -> some View {
        let pharmacy = store.settings.pharmacyName.trimmingCharacters(in: .whitespaces)
        let phone = store.settings.pharmacyPhone.filter { $0.isNumber || $0 == "+" }

        return VStack(spacing: 0) {
            ValueRow(title: "Schedule", value: medicine.scheduleList) {
                router.sheet = .editMedicine(medicine.id)
            }
            ValueRow(title: "Reminder", value: reminderValue(medicine, now: now)) {
                router.sheet = .editMedicine(medicine.id)
            }
            ValueRow(
                title: "Pharmacy",
                value: pharmacy.isEmpty ? "Add" : pharmacy,
                valueTint: pharmacy.isEmpty ? AppTheme.ColorToken.accent : AppTheme.ColorToken.secondaryText,
                showsDivider: false
            ) {
                if !phone.isEmpty, let url = URL(string: "tel:\(phone)") {
                    openURL(url)
                } else {
                    router.path = []
                    router.selectedTab = .settings
                }
            }
        }
        .groupedCard()
    }

    /// "Fri 9 Oct, 9:00", "Sent 29 Sep", "Paused"
    private func reminderValue(_ medicine: Medicine, now: Date) -> String {
        if medicine.remindersPaused { return "Paused" }
        if medicine.isOrdered { return "Paused until pickup" }
        if medicine.urgency == .out { return "Sent" }
        let date = medicine.reminderDate(now: now)
        return date <= now ? "Sent \(date.dayMonth)" : "\(date.weekdayDayMonth), \(medicine.reminderTime.label)"
    }

    /// Ordered sits beside Refilled while a low medicine waits to be
    /// ordered. Healthy, run out or already ordered: just Refilled.
    private func bottomBar(_ medicine: Medicine) -> some View {
        let offersOrdered = !medicine.isOrdered && (medicine.urgency == .critical || medicine.urgency == .low)
        return GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                if offersOrdered {
                    Button {
                        HapticFeedback.selection()
                        store.markOrdered(medicine.id)
                        router.showToast("Ordered. Reminders paused until pickup")
                    } label: {
                        Text("Ordered")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AppTheme.ColorToken.primaryText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .contentShape(.capsule)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .capsule)
                }
                Button { router.sheet = .refill(medicine.id) } label: {
                    Label { Text("Refilled") } icon: { Icon(.up, size: 20) }
                }
                .buttonStyle(PrimaryButtonStyle(height: 56))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .animation(.snappy, value: offersOrdered)
    }

    private func pop() {
        router.path.removeAll { $0 == .medicine(medicineID) }
    }
}

// MARK: - Supply ring

private struct SupplyRing: View {
    let medicine: Medicine
    let now: Date

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                ProgressRing(progress: medicine.stockFraction, lineWidth: 12, tint: medicine.urgency.tint)
                VStack(spacing: 4) {
                    Text("\(medicine.daysLeft)")
                        .font(.system(size: 60, weight: .heavy))
                        .kerning(-2)
                        .monospacedDigit()
                        .foregroundStyle(medicine.urgency.tint)
                        .contentTransition(.numericText(value: Double(medicine.daysLeft)))
                    Text(medicine.daysLeft == 1 ? "day left" : "days left")
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .frame(width: 180, height: 180)
            .animation(.spring(response: 0.6, dampingFraction: 0.75), value: medicine.daysLeft)

            (Text("\(medicine.urgency == .out ? "Ran out" : "Runs out") \(medicine.runOutDate(now: now).weekdayDayMonth)")
                .fontWeight(.semibold)
                .foregroundStyle(AppTheme.ColorToken.primaryText)
             + Text(" · \(medicine.stock) of \(medicine.unit.format(medicine.capacity)) left"))
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(medicine.daysLeft) days left, runs out \(medicine.runOutDate(now: now).weekdayDayMonth), \(medicine.stock) of \(medicine.unit.format(medicine.capacity)) left")
    }
}

#Preview {
    let store = MedicineStore.preview()
    return NavigationStack {
        MedicineDetailView(medicineID: store.medicines[0].id)
    }
    .environment(store)
    .environment(AppRouter())
}
