import SwiftUI

/// Pro: $3.99 a month or $39.99 once. One screen — what you get, the two
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

        VStack(spacing: 0) {
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
                                Icon(icon, size: 18)
                                    .foregroundStyle(AppTheme.ColorToken.accent)
                                    .frame(width: 34, height: 34)
                                    .background(AppTheme.ColorToken.accentSoft, in: .rect(cornerRadius: 10, style: .continuous))
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
                        planCard(.monthly, detail: "Cancel anytime", badge: nil)
                    }
                    .padding(.top, 24)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: 4) {
                Button(action: buy) {
                    if purchases.isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text(plan == .lifetime ? "Unlock for \(purchases.price(for: .lifetime))" : "Subscribe for \(purchases.price(for: .monthly))/month")
                    }
                }
                .buttonStyle(.primary(height: 56))
                .disabled(purchases.isPurchasing)

                Text(plan == .lifetime ? "One-time purchase. No subscription." : "Renews monthly until cancelled in Settings.")
                    .font(.system(size: 13))
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
            .padding(.top, 10)
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
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        isSelected ? AppTheme.ColorToken.accent : Color(hex: 0x28185A, opacity: 0.08),
                        lineWidth: isSelected ? 2 : 0.5
                    )
            }
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
