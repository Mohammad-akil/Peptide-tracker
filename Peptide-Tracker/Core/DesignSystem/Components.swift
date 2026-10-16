import SwiftUI

// MARK: - Card surface

private struct CardSurface: ViewModifier {
    var padding: EdgeInsets
    var radius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.ColorToken.cardBackground, in: .rect(cornerRadius: radius))
            .shadow(color: Color(hex: 0x28185A, opacity: 0.04), radius: 1, y: 1)
            .shadow(color: Color(hex: 0x28185A, opacity: 0.06), radius: 14, y: 10)
    }
}

extension View {
    /// The raised white card used for nearly every content block.
    func card(
        padding: EdgeInsets = EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16),
        radius: CGFloat = AppTheme.Radius.card
    ) -> some View {
        modifier(CardSurface(padding: padding, radius: radius))
    }

    func card(horizontal: CGFloat, vertical: CGFloat, radius: CGFloat = AppTheme.Radius.card) -> some View {
        card(padding: EdgeInsets(top: vertical, leading: horizontal, bottom: vertical, trailing: horizontal), radius: radius)
    }
}

// MARK: - Text

/// Small uppercase label above grouped cards ("TYPE", "SUPPLY", "SEPTEMBER").
struct SectionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .textCase(.uppercase)
            .kerning(0.4)
            .foregroundStyle(AppTheme.ColorToken.secondaryText)
            .padding(.horizontal, 6)
    }
}

/// Large title row with an optional trailing control — the header every
/// tab root draws instead of a navigation bar.
struct ScreenHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppTheme.ColorToken.secondaryText)
                }
                Text(title)
                    .font(.system(size: 34, weight: .bold))
                    .kerning(-0.5)
                    .foregroundStyle(AppTheme.ColorToken.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
            trailing
        }
        .padding(.leading, 4)
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

// MARK: - Progress ring

struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat
    var tint: Color = AppTheme.ColorToken.accent
    var track: Color = AppTheme.ColorToken.ringTrack

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(progress, 1)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth / 2)
        .animation(.spring(response: 0.8, dampingFraction: 0.85), value: progress)
    }
}

// MARK: - Medicine icon

/// The tinted rounded-square tile that identifies a medicine by colour and
/// type everywhere it appears.
struct MedicineIconView: View {
    let type: MedicineType
    let color: MedicineColor
    var size: CGFloat = 42

    var body: some View {
        glyph
            .frame(width: size, height: size)
            .background(color.color.opacity(0.13), in: .rect(cornerRadius: size * 0.31, style: .continuous))
            .accessibilityHidden(true)
    }

    /// The asset pack's drawn glyph where there is one; the type's symbol in
    /// the tile colour for the rest (inhaler, powder, other).
    @ViewBuilder
    private var glyph: some View {
        if type.hasGlyph {
            type.glyph(in: color)
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.78, height: size * 0.78)
        } else {
            Image(systemName: type.symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(color.color)
        }
    }
}

extension MedicineIconView {
    init(medicine: Medicine, size: CGFloat = 42) {
        self.init(type: medicine.type, color: medicine.color, size: size)
    }
}

// MARK: - Chips

struct Chip: View {
    let text: String
    var foreground: Color = AppTheme.ColorToken.primaryText
    var background: Color = AppTheme.ColorToken.controlFill
    var bold = false

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: bold ? .bold : .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(background, in: .rect(cornerRadius: 9))
    }
}

struct UrgencyChip: View {
    let urgency: Urgency
    let text: String

    var body: some View {
        Chip(text: text, foreground: urgency.ink, background: urgency.wash, bold: true)
    }
}

// MARK: - Segmented control

/// The pill-shaped two-or-more option switch ("List | Timeline", "2W | 1M").
struct PillSegmentedControl<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    var height: CGFloat = 36
    var label: (Option) -> AnyView

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    HapticFeedback.selection()
                    withAnimation(.snappy(duration: 0.25)) { selection = option }
                } label: {
                    label(option)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? AppTheme.ColorToken.accent : AppTheme.ColorToken.secondaryText)
                        .padding(.horizontal, 12)
                        .frame(height: height)
                        .frame(maxWidth: .infinity)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(AppTheme.ColorToken.cardBackground)
                                    .shadow(color: Color(hex: 0x28185A, opacity: 0.14), radius: 4, y: 2)
                            }
                        }
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(AppTheme.ColorToken.controlFill, in: .capsule)
    }
}

// MARK: - Stepper

/// The "− | +" capsule stepper from the Add form.
struct CountStepper: View {
    @Binding var value: Int
    var range: ClosedRange<Int>
    var step = 1
    let accessibilityName: String
    /// Lets the number be typed as well as stepped — for large counts like
    /// pills in stock.
    var isTypeable = false

    var body: some View {
        HStack(spacing: 10) {
            if isTypeable {
                TextField(accessibilityName, value: $value, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 17, weight: .semibold))
                    .monospacedDigit()
                    .frame(width: 56)
                    .onChange(of: value) { _, newValue in
                        let clamped = min(max(newValue, range.lowerBound), range.upperBound)
                        if clamped != newValue { value = clamped }
                    }
            } else {
                Text("\(value)")
                    .font(.system(size: 17, weight: .semibold))
                    .monospacedDigit()
                    .frame(minWidth: 28, alignment: .trailing)
                    .contentTransition(.numericText(value: Double(value)))
            }
            HStack(spacing: 0) {
                stepButton(icon: .minus, label: "Decrease \(accessibilityName)", delta: -step)
                    .disabled(value <= range.lowerBound)
                Rectangle()
                    .fill(AppTheme.ColorToken.separator)
                    .frame(width: 1, height: 18)
                stepButton(icon: .plus, label: "Increase \(accessibilityName)", delta: step)
                    .disabled(value >= range.upperBound)
            }
            .frame(height: 40)
            .background(AppTheme.ColorToken.controlFill, in: .capsule)
        }
    }

    private func stepButton(icon: AppIcon, label: String, delta: Int) -> some View {
        Button {
            HapticFeedback.selection()
            withAnimation(.snappy) {
                value = min(max(value + delta, range.lowerBound), range.upperBound)
            }
        } label: {
            Icon(icon, size: 18)
                .frame(width: 48, height: 40)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(AppTheme.ColorToken.primaryText)
        .buttonRepeatBehavior(.enabled)
        .accessibilityLabel(label)
    }
}

// MARK: - Dose checkbox

struct DoseCheckmark: View {
    let isTaken: Bool
    var size: CGFloat = 26

    var body: some View {
        ZStack {
            if isTaken {
                Circle()
                    .fill(AppTheme.ColorToken.accent)
                    .frame(width: size + 2, height: size + 2)
                Icon(.check, size: size * 0.6)
                    .foregroundStyle(.white)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Circle()
                    .strokeBorder(AppTheme.ColorToken.uncheckedRing, lineWidth: 2)
                    .frame(width: size, height: size)
            }
        }
        .frame(width: 44, height: 44)
        .contentShape(.rect)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isTaken)
    }
}

// MARK: - Grouped rows

/// A label/value row inside a grouped card, with a hairline under every row
/// but the last.
struct FormRow<Content: View>: View {
    let title: String
    var showsDivider = true
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.ColorToken.primaryText)
                .layoutPriority(1)
            Spacer(minLength: 8)
            content
        }
        .frame(minHeight: 52)
        .overlay(alignment: .bottom) {
            if showsDivider {
                Rectangle().fill(AppTheme.ColorToken.separator).frame(height: 1)
            }
        }
    }
}
