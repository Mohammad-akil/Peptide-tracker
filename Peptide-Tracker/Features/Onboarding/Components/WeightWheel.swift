import SwiftUI

/// Whole and tenths wheels for a weight in the given unit. The value is
/// always kilograms; nil shows `fallbackKg` until the wheel is turned.
struct WeightWheel: View {
    @Binding var kilograms: Double?
    let unit: WeightUnit
    var fallbackKg: Double = 75

    private var tenths: Int {
        Int((unit.value(fromKilograms: kilograms ?? fallbackKg) * 10).rounded())
    }

    private func set(tenths: Int) {
        kilograms = unit.kilograms(from: Double(tenths) / 10)
    }

    private var range: ClosedRange<Int> { unit == .kg ? 30...250 : 66...550 }

    var body: some View {
        HStack(spacing: 0) {
            Picker("Whole", selection: Binding(get: { tenths / 10 }, set: { set(tenths: $0 * 10 + tenths % 10) })) {
                ForEach(range, id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .clipped()
            Picker("Decimal", selection: Binding(get: { tenths % 10 }, set: { set(tenths: tenths / 10 * 10 + $0) })) {
                ForEach(0...9, id: \.self) { Text(".\($0)").tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(width: 70)
            .clipped()
            Text(unit.title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
                .frame(width: 50, alignment: .leading)
        }
        .padding(.horizontal, 12)
    }
}

/// Pounds / kilograms, under a weight wheel.
struct WeightUnitToggle: View {
    @Binding var unit: WeightUnit

    var body: some View {
        SectionPicker(
            selection: $unit.animation(.snappy),
            title: { $0 == .kg ? String(localized: "Kilograms") : String(localized: "Pounds") },
            track: AppTheme.ColorToken.cardBackground
        )
        .onChange(of: unit) { HapticFeedback.selection() }
    }
}
