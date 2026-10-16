import SwiftUI

/// Pro: $3.99 a month (with a free trial for new subscribers) or $39.99 once. One screen — what you get, the two
/// plans, one button. Shown after setup and from Settings.
struct PaywallView: View {
    @Environment(PurchaseStore.self) private var purchases
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var plan = PurchaseStore.Plan.lifetime
    /// Why it opened, when a free limit was hit.
    var reason: String?

    private let features: [(AppIcon, String, String)] = [
        (.plus, "Unlimited medicines", "Free covers \(PurchaseStore.freeMedicineLimit). Pro tracks as many as you take."),
        (.bell, "Reminders for every medicine", "A heads-up timed to how long your refill takes."),
        (.timeline, "Dose list and timeline", "Tick off doses and keep your count exact."),
        (.share, "Medicine list as a PDF", "Handy for doctor and pharmacy visits."),
        (.heart, "Support an independent app", "No ads, no account, nothing sold."),
    ]

    var body: some View {
        @Bindable var purchases = purchases

        ScrollView {
            VStack(spacing: 0) {
                IllustrationView(.neverRunOut, width: 220)
                    .padding(.top, 12)

                Text("\(Bundle.main.appName) Pro")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.ColorToken.accent)
                    .padding(.top, 4)
                Text("Never run out again.")
                    .font(.system(size: 32, weight: .heavy))
                    .kerning(-0.8)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
                    .accessibilityAddTraits(.isHeader)

                if let reason {
                    Text(reason)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.ColorToken.accentInk)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(AppTheme.ColorToken.accentSoft, in: .rect(cornerRadius: 16, style: .continuous))
                        .padding(.top, 14)
                }

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(features, id: \.1) { icon, title, detail in
                        HStack(spacing: 12) {
                            FilledIcon(icon, size: 24)
                                .foregroundStyle(AppTheme.ColorToken.accent)
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(title).font(.system(size: 16, weight: .semibold))
                                Text(detail)
                                    .font(.system(size: 14))
                                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 24)

                VStack(spacing: 10) {
                    planCard(.lifetime, detail: "Pay once, yours forever", badge: "Best value")
                    planCard(
                        .monthly,
                        detail: trialDays.map { "\($0) days free, then cancel anytime" } ?? "Cancel anytime",
                        badge: trialDays.map { "\($0)-day free trial" }
                    )
                }
                .padding(.top, 24)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 4) {
                Button(action: buy) {
                    if purchases.isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text(buttonTitle)
                    }
                }
                .buttonStyle(.glassPrimary)
                .disabled(purchases.isPurchasing)

                Text(terms)
                    .font(.system(size: 13))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    .padding(.top, 4)

                HStack(spacing: 18) {
                    Button("Restore") { Task { await purchases.restore(); if purchases.isPro { dismiss() } } }
                    Button("Terms") { openURL(AppLinks.termsOfUse) }
                    Button("Privacy") { openURL(AppLinks.privacyPolicy) }
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.ColorToken.accent)
                .frame(height: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 36)
            .background {
                // Solid behind the buttons, fading to clear above them, so
                // the list softly disappears under the button.
                LinearGradient(
                    stops: [
                        .init(color: AppTheme.ColorToken.background.opacity(0), location: 0),
                        .init(color: AppTheme.ColorToken.background, location: 0.3),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
            }
        }
        .background(AppTheme.ColorToken.background.ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Icon(.x, size: 16)
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.ColorToken.controlFill, in: .circle)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 12)
            .padding(.top, 8)
            .accessibilityLabel("Close")
        }
        .alert("Purchase", isPresented: Binding(get: { purchases.errorMessage != nil }, set: { if !$0 { purchases.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(purchases.errorMessage ?? "")
        }
    }

    private var trialDays: Int? { purchases.monthlyTrialDays }

    private var buttonTitle: String {
        switch plan {
        case .lifetime: "Unlock forever"
        // "Free" only when the App Store will really give them the trial.
        case .monthly: trialDays != nil ? "Continue for free" : "Subscribe for \(purchases.price(for: .monthly))/month"
        }
    }

    /// What they'll pay and when, said plainly next to the button.
    private var terms: String {
        switch plan {
        case .lifetime: "One-time purchase. No subscription."
        case .monthly:
            if let trialDays {
                "Free for \(trialDays) days, then \(purchases.price(for: .monthly))/month. Cancel anytime in Settings."
            } else {
                "Renews monthly until cancelled in Settings."
            }
        }
    }

    private func planCard(_ option: PurchaseStore.Plan, detail: String, badge: String?) -> some View {
        let isSelected = plan == option
        return Button {
            HapticFeedback.selection()
            withAnimation(.snappy) { plan = option }
        } label: {
            HStack(spacing: 14) {
                RadioMark(isSelected: isSelected)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(option.title).font(.system(size: 17, weight: .semibold))
                        if let badge {
                            Text(badge)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(AppTheme.ColorToken.accent, in: .capsule)
                        }
                    }
                    Text(detail)
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.ColorToken.secondaryText)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 0) {
                    Text(purchases.price(for: option))
                        .font(.system(size: 19, weight: .bold))
                        .monospacedDigit()
                    Text(option == .monthly ? "per month" : "once")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.ColorToken.secondaryText)
                }
            }
            .foregroundStyle(AppTheme.ColorToken.primaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                isSelected ? AppTheme.ColorToken.accentSoft : AppTheme.ColorToken.cardBackground,
                in: .rect(cornerRadius: 20, style: .continuous)
            )
            .selectionBorder(isSelected, cornerRadius: 20)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("\(option.title), \(purchases.price(for: option)) \(option == .monthly ? "per month" : "one time")")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func buy() {
        Task {
            if await purchases.purchase(plan) { dismiss() }
        }
    }
}

#Preview {
    PaywallView()
        .environment(PurchaseStore())
}
