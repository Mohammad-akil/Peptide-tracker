import SwiftUI

/// "Which days": every day, once a week, every few days, certain weekdays,
/// or days on / days off — with the settings for the picked kind under it.
/// Everything except every day is Pro; free users picking one get the
/// paywall instead.
struct FrequencyPicker: View {
    @Binding var frequency: DoseFrequency
    @Binding var start: Date

    @Environment(PurchaseStore.self) private var purchases
    @State private var showsPaywall = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            GroupedSection(title: "Which days") {
                ForEach(Array(DoseFrequency.Kind.allCases.enumerated()), id: \.element) { index, kind in
                    row(kind, showsDivider: index < DoseFrequency.Kind.allCases.count - 1)
                }
            }

            if frequency.kind != .daily {
                GroupedSection(footer: footer) {
                    details
                }
                .transition(.opacity)
            }
        }
        .animation(.snappy, value: frequency.kind)
        .sheet(isPresented: $showsPaywall) {
            PaywallView(reason: "Weekly and custom schedules are part of Pro.")
        }
    }

    // MARK: Kinds

    private func row(_ kind: DoseFrequency.Kind, showsDivider: Bool) -> some View {
        let isSelected = frequency.kind == kind
        let isLocked = kind != .daily && !purchases.isPro
        return Button {
            HapticFeedback.selection()
            if isLocked {
                showsPaywall = true
            } else if !isSelected {
                withAnimation(.snappy) { frequency = kind.defaultFrequency }
            }
        } label: {
            HStack(spacing: 12) {
                Text(kind.title)
                    .font(.system(size: 17))
                    .foregroundStyle(AppTheme.ColorToken.primaryText)
                Spacer(minLength: 8)
                if isLocked {
                    ProCrownBadge(size: 20)
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.ColorToken.accent)
                        .frame(width: 20)
                        .opacity(isSelected ? 1 : 0)
                        .scaleEffect(isSelected ? 1 : 0.5)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .contentShape(.rect)
            .rowDivider(showsDivider)
        }
        .buttonStyle(RowPressStyle())
        .accessibilityLabel(isLocked ? "\(kind.title), Pro feature" : kind.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: Details

    @ViewBuilder
    private var details: some View {
        switch frequency {
        case .daily:
            EmptyView()
        case .everyNDays(let n):
            if frequency.kind == .everyFewDays {
                FormRow(title: "Every") {
                    CountStepper(value: Binding(get: { n }, set: { frequency = .everyNDays($0) }), range: 2...30, accessibilityName: "days between doses")
                    Text("days")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.ColorToken.secondaryText)
                }
                .padding(.horizontal, 16)
            }
            startRow
        case .weekdays(let days):
            weekdayPicker(days)
                .padding(16)
        case .cycle(let on, let off):
            FormRow(title: "Days on") {
                CountStepper(value: Binding(get: { on }, set: { frequency = .cycle(on: $0, off: off) }), range: 1...90, accessibilityName: "days on")
            }
            .padding(.horizontal, 16)
            FormRow(title: "Days off") {
                CountStepper(value: Binding(get: { off }, set: { frequency = .cycle(on: on, off: $0) }), range: 1...90, accessibilityName: "days off")
            }
            .padding(.horizontal, 16)
            startRow
        }
    }

    private var startRow: some View {
        FormRow(title: frequency.kind == .cycle ? "Cycle starts" : "Next dose", showsDivider: false) {
            DatePicker("Start", selection: $start, displayedComponents: .date)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
    }

    /// Seven round toggles, Monday first. At least one day stays on.
    private func weekdayPicker(_ days: Set<Int>) -> some View {
        HStack(spacing: 6) {
            ForEach(DoseFrequency.weekdaysMondayFirst, id: \.day) { weekday in
                let isOn = days.contains(weekday.day)
                Button {
                    HapticFeedback.selection()
                    var next = days
                    if isOn { next.remove(weekday.day) } else { next.insert(weekday.day) }
                    guard !next.isEmpty else { return }
                    frequency = .weekdays(next)
                } label: {
                    Text(weekday.symbol.prefix(2))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isOn ? .white : AppTheme.ColorToken.primaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(isOn ? AppTheme.ColorToken.accent : AppTheme.ColorToken.controlFill, in: .circle)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(weekday.symbol)
                .accessibilityAddTraits(isOn ? [.isSelected] : [])
            }
        }
    }

    private var footer: String? {
        switch frequency.kind {
        case .weekly, .everyFewDays: "Pick the day of your next dose; the schedule repeats from there."
        case .cycle: "Doses repeat for the days on, then pause for the days off."
        case .weekdays: "Doses happen only on the days you pick."
        case .daily: nil
        }
    }
}
