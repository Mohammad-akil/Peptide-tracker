import SwiftUI

// MARK: - Height

/// A wheel in centimetres, or feet and inches, with the unit toggle below.
/// Always stored in centimetres.
struct HeightQuestion: View {
    @Binding var answers: OnboardingAnswers

    private var cm: Binding<Int> {
        Binding(get: { answers.heightCm ?? OnboardingAnswers.defaultHeightCm }, set: { answers.heightCm = $0 })
    }

    private var totalInches: Int { Int((Double(cm.wrappedValue) / 2.54).rounded()) }

    private var feet: Binding<Int> {
        Binding(get: { totalInches / 12 }, set: { setInches($0 * 12 + totalInches % 12) })
    }

    private var inches: Binding<Int> {
        Binding(get: { totalInches % 12 }, set: { setInches(totalInches / 12 * 12 + $0) })
    }

    private func setInches(_ value: Int) {
        answers.heightCm = Int((Double(value) * 2.54).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            OnboardingHeader(
                title: String(localized: "What’s your height?"),
                reason: String(localized: "Your height helps us calculate your BMI and personalize your goal.")
            )

            Text(answers.usesImperialHeight ? String(localized: "\(feet.wrappedValue) ft \(inches.wrappedValue) in") : String(localized: "\(cm.wrappedValue) cm"))
                .font(.system(size: 44, weight: .heavy))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy, value: cm.wrappedValue)
                .frame(maxWidth: .infinity)
                .stagger(0)

            Group {
                if answers.usesImperialHeight {
                    HStack(spacing: 0) {
                        wheel(feet, range: 3...7, unit: "ft")
                        wheel(inches, range: 0...11, unit: "in")
                    }
                } else {
                    wheel(cm, range: 100...230, unit: "cm")
                }
            }
            .frame(height: 200)
            .background(AppTheme.ColorToken.cardBackground, in: .rect(cornerRadius: 20, style: .continuous))
            .transition(.opacity)
            .id(answers.usesImperialHeight)
            .stagger(1)

            SectionPicker(
                selection: Binding(
                    get: { answers.usesImperialHeight ? HeightUnit.inches : .centimeters },
                    set: { answers.usesImperialHeight = $0 == .inches }
                ).animation(.snappy),
                title: \.title,
                track: AppTheme.ColorToken.cardBackground
            )
            .stagger(2)
            .onChange(of: answers.usesImperialHeight) { HapticFeedback.selection() }
        }
        .onAppear { if answers.heightCm == nil { answers.heightCm = OnboardingAnswers.defaultHeightCm } }
    }

    private func wheel(_ selection: Binding<Int>, range: ClosedRange<Int>, unit: String) -> some View {
        Picker(unit, selection: selection) {
            ForEach(range, id: \.self) { Text("\($0) \(unit)").tag($0) }
        }
        .pickerStyle(.wheel)
        .frame(maxWidth: .infinity)
        .clipped()
    }
}

/// The height wheel's units, for the unit switch under it.
enum HeightUnit: String, CaseIterable {
    case centimeters, inches

    var title: String { self == .inches ? String(localized: "Inches") : String(localized: "Centimeters") }
}
