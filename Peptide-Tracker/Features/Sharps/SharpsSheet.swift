import SwiftUI

/// Health → Sharps container: how full the needle bin is, counted from
/// the injections ticked off since it was last emptied, with its size and
/// an "I emptied it" button.
struct SharpsSheet: View {
    @Environment(MedicineStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var store = store
        let used = store.sharpsUsed
        let capacity = store.settings.sharpsCapacity
        let fraction = store.sharpsFraction
        let tint = Self.tint(for: fraction)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(spacing: 10) {
                        ZStack {
                            ProgressRing(progress: fraction, lineWidth: 12, tint: tint)
                            VStack(spacing: 2) {
                                Text("\(used)")
                                    .font(.system(size: 52, weight: .heavy))
                                    .monospacedDigit()
                                    .foregroundStyle(tint)
                                    .contentTransition(.numericText(value: Double(used)))
                                Text("of \(capacity) needles")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                        }
                        .frame(width: 180, height: 180)

                        Text(Self.status(fraction: fraction, emptiedAt: store.settings.sharpsEmptiedAt))
                            .font(.system(size: 15))
                            .foregroundStyle(AppTheme.ColorToken.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .accessibilityElement(children: .combine)

                    GroupedSection(footer: String(localized: "Each injection you tick off counts as one needle. Counting starts when you turn this on or empty the container.")) {
                        ControlRow(symbol: "trash.square.fill", tint: Color(hex: 0xFF9F0A), title: String(localized: "Track sharps"), showsDivider: store.settings.tracksSharps) {
                            Toggle("Track sharps", isOn: Binding(
                                get: { store.settings.tracksSharps },
                                set: { isOn in
                                    withAnimation(.snappy) {
                                        store.settings.tracksSharps = isOn
                                        if isOn, store.settings.sharpsEmptiedAt == nil { store.emptySharps() }
                                    }
                                }
                            ))
                            .labelsHidden()
                            .tint(AppTheme.ColorToken.accent)
                        }
                        if store.settings.tracksSharps {
                            HStack {
                                Text("Container holds").font(.system(size: 17))
                                Spacer()
                                CountStepper(value: $store.settings.sharpsCapacity, range: 10...500, step: 10, accessibilityName: String(localized: "Container size"))
                            }
                            .padding(.horizontal, 16)
                            .frame(minHeight: 52)
                        }
                    }

                    if store.settings.tracksSharps {
                        Button {
                            store.emptySharps()
                            router.showToast(String(localized: "Sharps container emptied"))
                        } label: {
                            Label("I emptied it", systemImage: "arrow.counterclockwise")
                        }
                        .buttonStyle(.primary)
                        .disabled(used == 0)

                        Text("Close a full container and take it where your area accepts sharps, often a pharmacy or GP surgery. Never put needles in household rubbish.")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.ColorToken.secondaryText)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.medium)
                .padding(.vertical, 16)
                .animation(.snappy, value: store.settings.tracksSharps)
            }
            .scrollIndicators(.hidden)
            .background(AppTheme.ColorToken.background.ignoresSafeArea())
            .navigationTitle("Sharps container")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CompatToolbarRoleButton(role: .close) { dismiss() }
                        .tint(AppTheme.ColorToken.primaryText)
                }
            }
        }
    }

    static func tint(for fraction: Double) -> Color {
        if fraction >= 0.9 { return Urgency.critical.tint }
        if fraction >= 0.75 { return Urgency.low.tint }
        return Urgency.healthy.tint
    }

    static func status(fraction: Double, emptiedAt: Date?) -> String {
        let since = emptiedAt.map { String(localized: " since \($0.dayMonth)") } ?? ""
        if fraction >= 1 { return String(localized: "Full\(since). Time to close it and swap for a new one.") }
        if fraction >= 0.9 { return String(localized: "Nearly full\(since). Get a new container ready.") }
        return String(localized: "Counting\(since).")
    }
}

extension MedicineStore {
    /// "37 of 100", or "Off".
    var sharpsSummary: String {
        settings.tracksSharps ? String(localized: "\(sharpsUsed) of \(settings.sharpsCapacity)") : String(localized: "Off")
    }
}
