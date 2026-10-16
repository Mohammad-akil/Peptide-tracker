import SwiftUI

// Pieces shared by the add flow and the edit form, so both read as the
// same Settings-style screens.

/// A type to pick: its own colour tile with a white glyph, and its name.
struct TypeTile: View {
    let type: MedicineType
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                Image(systemName: type.symbol)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(
                        LinearGradient(colors: [type.tint.mix(with: .white, by: 0.18), type.tint], startPoint: .top, endPoint: .bottom),
                        in: .rect(cornerRadius: 42 * 0.31, style: .continuous)
                    )
                    .scaleEffect(isSelected ? 1.06 : 1)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                Text(type.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? AppTheme.ColorToken.accent : AppTheme.ColorToken.primaryText)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(
                isSelected ? AppTheme.ColorToken.accentSoft : AppTheme.ColorToken.cardBackground,
                in: .rect(cornerRadius: 20, style: .continuous)
            )
            .selectionBorder(isSelected, cornerRadius: 20)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(type.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// The six icon colours as the medicine's own icon, the chosen one ringed.
struct ColourChoices: View {
    let type: MedicineType
    @Binding var color: MedicineColor

    var body: some View {
        HStack {
            ForEach(MedicineColor.allCases) { option in
                let isSelected = color == option
                Button {
                    HapticFeedback.selection()
                    withAnimation(.snappy) { color = option }
                } label: {
                    MedicineIconView(type: type, color: option, size: 40, isVibrant: true)
                        .overlay {
                            RoundedRectangle(cornerRadius: 40 * 0.31 + 3, style: .continuous)
                                .strokeBorder(option.vibrant, lineWidth: 2)
                                .padding(-4)
                                .opacity(isSelected ? 1 : 0)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Colour \(option.rawValue)")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                if option != MedicineColor.allCases.last { Spacer(minLength: 0) }
            }
        }
    }
}

/// Tappable suggestions that fill a text answer ("Blood pressure").
struct SuggestionChips: View {
    let options: [String]
    @Binding var selection: String

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(options, id: \.self) { option in
                let isSelected = selection == option
                Button {
                    HapticFeedback.selection()
                    selection = isSelected ? "" : option
                } label: {
                    Text(option)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : AppTheme.ColorToken.primaryText)
                        .padding(.horizontal, 16)
                        .frame(height: 38)
                        // Glass capsules, the picked one filled with accent glass.
                        .glassEffect(
                            isSelected ? .regular.tint(AppTheme.ColorToken.accent).interactive() : .regular.interactive(),
                            in: .capsule
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
    }
}

/// A row as in iOS Settings: a small coloured tile with a white glyph, the
/// title, and whatever sits on the right (a value, a switch, a preview).
struct SettingsRow<Trailing: View>: View {
    let symbol: String
    let tint: Color
    let title: String
    let showsDivider: Bool
    let action: () -> Void
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            Button(action: action) {
                HStack(spacing: 14) {
                    SettingsTile(symbol: symbol, tint: tint)
                    Text(title)
                        .font(.system(size: 17))
                        .foregroundStyle(AppTheme.ColorToken.primaryText)
                    Spacer(minLength: 8)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            trailing
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .rowDivider(showsDivider, inset: 58)
    }
}

/// A Settings-style row whose control sits on the right (a stepper, a time
/// picker): the coloured tile, the title, the control.
struct ControlRow<Control: View>: View {
    let symbol: String
    let tint: Color
    let title: String
    var showsDivider = true
    @ViewBuilder var control: Control

    var body: some View {
        HStack(spacing: 14) {
            SettingsTile(symbol: symbol, tint: tint)
            Text(title)
                .font(.system(size: 17))
                .foregroundStyle(AppTheme.ColorToken.primaryText)
                .lineLimit(1)
            Spacer(minLength: 8)
            control
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .rowDivider(showsDivider, inset: 58)
    }
}

/// The small coloured square with a white glyph that leads a Settings row.
struct SettingsTile: View {
    let symbol: String
    let tint: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(tint, in: .rect(cornerRadius: 8, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// The chevron on a row that opens in place, turned down while open.
struct DisclosureMark: View {
    let isOpen: Bool

    var body: some View {
        Chevron()
            .rotationEffect(.degrees(isOpen ? 90 : 0))
            .animation(.snappy, value: isOpen)
    }
}

/// Lays chips out in rows, wrapping to the next row when one is full.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(for: subviews, width: proposal.width ?? .infinity)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(for: subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(for subviews: Subviews, width: CGFloat) -> [Row] {
        var rows = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if !rows[rows.count - 1].indices.isEmpty, rows[rows.count - 1].width + spacing + size.width > width {
                rows.append(Row())
            }
            var row = rows[rows.count - 1]
            row.width += (row.indices.isEmpty ? 0 : spacing) + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
            rows[rows.count - 1] = row
        }
        return rows
    }
}
