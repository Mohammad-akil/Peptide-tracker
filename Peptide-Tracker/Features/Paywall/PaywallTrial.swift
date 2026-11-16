import SwiftUI
import UserNotifications

/// Paywall step 2: how the free trial works, as a Day 1 → last-day timeline.
/// Only shown when the App Store will really give this Apple Account a trial.
struct PaywallTrialPage: View {
    let plan: PurchaseStore.Plan
    let days: Int

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Try Pro \(Text("free for \(days) days").foregroundStyle(PaywallPalette.accent))")
                        .font(.system(size: 30, weight: .heavy))
                        .kerning(-0.75)
                        .foregroundStyle(AppTheme.ColorToken.primaryText)
                        .accessibilityAddTraits(.isHeader)
                    Text("Here’s how your free trial works. No charge today.")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.ColorToken.secondaryText)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .padding(.bottom, AppTheme.Spacing.large)

                PaywallTrialTimeline(plan: plan, days: days)
            }
            .padding(.horizontal, AppTheme.Spacing.mediumLarge)
            .padding(.bottom, AppTheme.Spacing.medium)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
    }
}

/// The trial as a day-by-day track: today (everything unlocks), a
/// mid-trial check-in, the reminder two days before it ends, and the day it
/// ends with the exact price. The line fills stop by stop on a loop;
/// Reduce Motion shows the finished track, still. Text never animates.
struct PaywallTrialTimeline: View {
    let plan: PurchaseStore.Plan
    let days: Int

    @Environment(PurchaseStore.self) private var purchases
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var filledConnectors = 0
    @State private var reachedStops = 1

    private struct Stop: Identifiable {
        let day: Int
        let title: String
        let detail: String
        let symbol: String
        let tint: Color
        var showsBell = false
        var id: Int { day }
    }

    private var stops: [Stop] {
        let reminderDay = max(2, days - TrialReminder.daysBeforeEnd)
        var stops = [
            Stop(day: 1, title: "Today", detail: "Every Pro feature unlocks. You won’t be charged today.", symbol: "lock.open.fill", tint: PaywallPalette.green),
        ]
        let midDay = max(2, (days - 1) / 2)
        if midDay < reminderDay {
            stops.append(Stop(day: midDay, title: "Your report takes shape", detail: "Your adherence report fills in with every dose you tick off.", symbol: "chart.bar.fill", tint: PaywallPalette.accent))
        }
        if reminderDay < days {
            stops.append(Stop(day: reminderDay, title: "Trial reminder", detail: "We’ll remind you before your trial ends.", symbol: "calendar.badge.clock", tint: PaywallPalette.orange, showsBell: true))
        }
        let price = purchases.price(for: plan)
        stops.append(Stop(day: days, title: "Trial ends", detail: "You’ll be charged \(price) \(plan.period). Cancel anytime before.", symbol: "crown.fill", tint: PaywallPalette.gold))
        return stops
    }

    var body: some View {
        let stops = stops
        let dot: CGFloat = 44
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                row(stop, isCurrent: index == 0, isReached: index < reachedStops, dot: dot)
                    .background(alignment: .topLeading) {
                        if index < stops.count - 1 {
                            connector(from: stop.tint, to: stops[index + 1].tint, isFilled: index < filledConnectors)
                                .padding(.top, dot + 4)
                                .padding(.bottom, 4)
                                .padding(.leading, dot / 2 - 1.5)
                        }
                    }
            }
        }
        .task(id: stops.count) { await play(stopCount: stops.count) }
    }

    private func play(stopCount: Int) async {
        guard !reduceMotion else {
            filledConnectors = stopCount - 1
            reachedStops = stopCount
            return
        }
        filledConnectors = 0
        reachedStops = 1
        try? await Task.sleep(for: .milliseconds(450))
        var isFirstPass = true
        while !Task.isCancelled {
            for next in 1..<max(stopCount, 2) {
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.55)) { filledConnectors = next }
                try? await Task.sleep(for: .milliseconds(520))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.38, dampingFraction: 0.55)) { reachedStops = next + 1 }
                if isFirstPass { HapticFeedback.impact(.soft) }
                try? await Task.sleep(for: .milliseconds(260))
            }
            isFirstPass = false
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.4)) {
                filledConnectors = 0
                reachedStops = 1
            }
            try? await Task.sleep(for: .milliseconds(700))
        }
    }

    private func connector(from: Color, to: Color, isFilled: Bool) -> some View {
        Capsule()
            .fill(AppTheme.ColorToken.separator)
            .overlay(alignment: .top) {
                Capsule()
                    .fill(LinearGradient(colors: [from, to], startPoint: .top, endPoint: .bottom))
                    .scaleEffect(x: 1, y: isFilled ? 1 : 0, anchor: .top)
            }
            .frame(width: 3)
    }

    private func row(_ stop: Stop, isCurrent: Bool, isReached: Bool, dot: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: stop.symbol)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(isCurrent ? .white : stop.tint)
                .symbolEffect(.bounce, value: isReached)
                .frame(width: dot, height: dot)
                .background(isCurrent ? AnyShapeStyle(stop.tint) : AnyShapeStyle(stop.tint.opacity(0.18)), in: .circle)
                .background {
                    if isCurrent {
                        Circle().fill(stop.tint.opacity(0.22)).padding(-6)
                    }
                }
                .scaleEffect(isReached ? 1 : 0.82)
                .opacity(isReached ? 1 : 0.35)
                .saturation(isReached ? 1 : 0.2)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("DAY \(stop.day)")
                        .font(.system(size: 12, weight: .black))
                        .kerning(1)
                        .foregroundStyle(stop.tint)
                    if isCurrent {
                        Text("NOW")
                            .font(.system(size: 10, weight: .black))
                            .kerning(0.8)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(stop.tint, in: .capsule)
                    }
                }
                HStack(spacing: 6) {
                    Text(stop.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppTheme.ColorToken.primaryText)
                    if stop.showsBell {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(stop.tint)
                            .symbolEffect(.wiggle, options: .repeating, isActive: !reduceMotion)
                            .opacity(isReached ? 1 : 0.35)
                            .accessibilityHidden(true)
                    }
                }
                Text(stop.detail)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 2)
            .padding(.bottom, AppTheme.Spacing.mediumLarge)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Day \(stop.day), \(stop.title). \(stop.detail)")
    }
}

/// Keeps the timeline's promise: a local notification two days before a
/// free trial turns into a paid subscription.
enum TrialReminder {
    static let identifier = "pro.trial.reminder"
    static let daysBeforeEnd = 2

    /// Call after a purchase that started a free trial.
    static func schedule(trialDays: Int, price: String, period: String) async {
        guard trialDays > daysBeforeEnd else { return }
        let center = UNUserNotificationCenter.current()
        if await center.notificationSettings().authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        }
        let content = UNMutableNotificationContent()
        content.title = "Your free trial ends in \(daysBeforeEnd) days"
        content.body = "Then it’s \(price) \(period). Cancel anytime in Settings before then if Pro isn’t for you."
        content.sound = .default
        let seconds = Double(trialDays - daysBeforeEnd) * 86_400
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(60, seconds), repeats: false)
        try? await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }
}
