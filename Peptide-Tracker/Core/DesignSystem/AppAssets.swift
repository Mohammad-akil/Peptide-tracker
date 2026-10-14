import SwiftUI

/// The interface icons from the design's asset pack. Each is a 24 pt
/// template image, so it takes the surrounding foreground style.
enum AppIcon: String {
    case plus, minus, check, x, chev, chevR, more, edit, trash
    case bell, bellOff, clock, cal, today, history, up, arrowR
    case store, phone, share, cloud, info, user, users, heart
    case truck, steth, sliders, list, timeline, sun, moon, alert
    case search, pill, round, syringe, cream, liquid, drop, gear, zap, sparkle

    var image: Image { Image("icon-\(rawValue)") }
}

/// An asset-pack icon drawn at a given point size.
struct Icon: View {
    let icon: AppIcon
    var size: CGFloat = 24

    init(_ icon: AppIcon, size: CGFloat = 24) {
        self.icon = icon
        self.size = size
    }

    var body: some View {
        icon.image
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// The 23 spot illustrations, 240 × 180 pt, one per empty or edge state.
enum Illustration: String {
    case emptyState = "empty-state"
    case refillLeadTime = "refill-lead-time"
    case doseReminders = "dose-reminders"
    case reminderTime = "reminder-time"
    case pharmacy
    case caringForSomeone = "caring-for-someone"
    case allSet = "all-set"
    case notifications
    case welcome
    case neverRunOut = "never-run-out"
    case refillNeeded = "refill-needed"
    case onOrder = "on-order"
    case refilled
    case ranOut = "ran-out"
    case noDosesToday = "no-doses-today"
    case timelineEmpty = "timeline-empty"
    case noRefillsYet = "no-refills-yet"
    case noSearchResults = "no-search-results"
    case notificationsOff = "notifications-off"
    case syncProblem = "sync-problem"
    case addPerson = "add-person"
    case exportList = "export-list"
    case setupComplete = "setup-complete"

    var image: Image { Image("illo-\(rawValue)") }
}

struct IllustrationView: View {
    let illustration: Illustration
    var width: CGFloat = 240

    init(_ illustration: Illustration, width: CGFloat = 240) {
        self.illustration = illustration
        self.width = width
    }

    var body: some View {
        illustration.image
            .resizable()
            .scaledToFit()
            .frame(width: width, height: width * 0.75)
            .accessibilityHidden(true)
    }
}

/// The centred illustration, title, message and actions every empty state
/// shares ("No medicines yet", "No refills yet"…).
struct EmptyStateView<Actions: View>: View {
    let illustration: Illustration
    let title: String
    let message: String
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(spacing: 0) {
            IllustrationView(illustration)
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .kerning(-0.3)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
                .padding(.bottom, 6)
            Text(message)
                .font(.system(size: 16))
                .lineSpacing(3)
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 0) { actions }
                .padding(.top, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
    }
}

extension EmptyStateView where Actions == EmptyView {
    init(illustration: Illustration, title: String, message: String) {
        self.init(illustration: illustration, title: title, message: message) { EmptyView() }
    }
}
