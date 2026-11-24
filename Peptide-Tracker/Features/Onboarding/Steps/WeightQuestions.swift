import SwiftUI

// MARK: - Current weight

struct WeightQuestion: View {
    @Binding var answers: OnboardingAnswers

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            OnboardingHeader(
                title: String(localized: "What’s your current weight?"),
                reason: String(localized: "We’ll use it with your height to work out your BMI and track your progress.")
            )
            Text(answers.weightUnit.format(answers.currentWeightKg ?? OnboardingAnswers.defaultWeightKg))
                .font(.system(size: 44, weight: .heavy))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy, value: answers.currentWeightKg)
                .frame(maxWidth: .infinity)
                .stagger(0)
            WeightWheel(kilograms: $answers.currentWeightKg, unit: answers.weightUnit, fallbackKg: OnboardingAnswers.defaultWeightKg)
                .frame(height: 200)
                .background(AppTheme.ColorToken.cardBackground, in: .rect(cornerRadius: 20, style: .continuous))
                .id(answers.weightUnit)
                .transition(.opacity)
                .stagger(1)
            WeightUnitToggle(unit: $answers.weightUnit)
                .stagger(2)
        }
        .onAppear { if answers.currentWeightKg == nil { answers.currentWeightKg = OnboardingAnswers.defaultWeightKg } }
    }
}

// MARK: - Where you started

/// Start weight and start date, each edited from its own row.
struct StartQuestion: View {
    @Binding var answers: OnboardingAnswers

    private enum Editing: Identifiable {
        case weight, date
        var id: Self { self }
    }

    @State private var editing: Editing?

    private var startKg: Double { answers.startWeightKg ?? answers.currentWeightKg ?? OnboardingAnswers.defaultWeightKg }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            OnboardingHeader(
                title: String(localized: "Tell us where you started."),
                reason: String(localized: "Add the weight you were when you started your journey, along with your start date.")
            )
            progressCard
                .stagger(0)
            VStack(spacing: 0) {
                editRow(.timeline, String(localized: "Start weight"), answers.startWeightKg.map(answers.weightUnit.format) ?? String(localized: "Add"), edit: .weight, showsDivider: true)
                editRow(.cal, String(localized: "Start date"), answers.startDate.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? String(localized: "Add"), edit: .date, showsDivider: false)
            }
            .groupedCard()
            .stagger(1)
        }
        .sheet(item: $editing) { item in
            sheet(for: item)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    /// Start → now, and the change between them, once both are known.
    private var progressCard: some View {
        HStack(spacing: 0) {
            stat("Start", answers.startWeightKg.map(answers.weightUnit.format) ?? String(localized: "Not set"))
            Image(systemName: "arrow.forward")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppTheme.ColorToken.accent)
            stat("Now", answers.currentWeightKg.map(answers.weightUnit.format) ?? String(localized: "Not set"))
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .animation(.snappy, value: answers.startWeightKg)
        .animation(.snappy, value: answers.weightUnit)
        .background(AppTheme.ColorToken.accentSoft, in: .rect(cornerRadius: 20, style: .continuous))
        .overlay(alignment: .bottom) {
            if let change = changeText {
                Text(change)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.ColorToken.accentInk)
                    .padding(.bottom, 8)
            }
        }
    }

    private var changeText: String? {
        guard let start = answers.startWeightKg, let now = answers.currentWeightKg else { return nil }
        let delta = start - now
        guard abs(delta) >= 0.05 else { return nil }
        let amount = answers.weightUnit.format(abs(delta))
        return delta > 0 ? String(localized: "\(amount) down so far") : String(localized: "\(amount) up since you started")
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
            Text(value)
                .font(.system(size: 24, weight: .heavy))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, changeText == nil ? 0 : 14)
    }

    private func editRow(_ icon: AppIcon, _ title: String, _ value: String, edit: Editing, showsDivider: Bool) -> some View {
        Button {
            HapticFeedback.selection()
            if edit == .weight, answers.startWeightKg == nil { answers.startWeightKg = startKg }
            if edit == .date, answers.startDate == nil { answers.startDate = Calendar.current.date(byAdding: .month, value: -1, to: .now) }
            editing = edit
        } label: {
            HStack(spacing: 12) {
                FilledIcon(icon, size: 18)
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(AppTheme.ColorToken.accent, in: .rect(cornerRadius: 10, style: .continuous))
                Text(title)
                    .font(.system(size: 17))
                    .foregroundStyle(AppTheme.ColorToken.primaryText)
                Spacer(minLength: 8)
                Text(value)
                    .font(.system(size: 17))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    .lineLimit(1)
                Image(systemName: "pencil")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.ColorToken.accent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 52)
            .contentShape(.rect)
            .rowDivider(showsDivider, inset: 62)
        }
        .buttonStyle(RowPressStyle())
        .accessibilityHint("Edit \(title.lowercased())")
    }

    @ViewBuilder
    private func sheet(for item: Editing) -> some View {
        NavigationStack {
            Group {
                switch item {
                case .weight:
                    VStack(spacing: 18) {
                        WeightWheel(kilograms: $answers.startWeightKg, unit: answers.weightUnit, fallbackKg: startKg)
                            .frame(height: 200)
                        WeightUnitToggle(unit: $answers.weightUnit)
                    }
                case .date:
                    DatePicker(
                        String(localized: "Start date"),
                        selection: Binding(get: { answers.startDate ?? .now }, set: { answers.startDate = $0 }),
                        in: ...Date.now,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                }
            }
            .padding(.horizontal, 20)
            .navigationTitle(item == .weight ? "Start weight" : "Start date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { editing = nil }
                }
            }
        }
    }
}
