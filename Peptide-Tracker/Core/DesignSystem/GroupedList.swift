import SwiftUI

// MARK: - Grouped section

/// The design's list group: a bold heading with an optional trailing note
/// ("Refill soon  2", "Taken  this morning"), a white card of rows, and an
/// optional footer that explains the group.
struct GroupedSection<Content: View>: View {
    var title: String?
    var trailing: String?
    var footer: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if title != nil || trailing != nil {
                HStack(alignment: .firstTextBaseline) {
                    if let title {
                        Text(title)
                            .font(.system(size: 20, weight: .bold))
                            .kerning(-0.3)
                            .foregroundStyle(AppTheme.ColorToken.primaryText)
                    }
                    Spacer(minLength: 8)
                    if let trailing {
                        Text(trailing)
                            .font(.system(size: 15))
                            .foregroundStyle(AppTheme.ColorToken.secondaryText)
                            .contentTransition(.numericText())
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 8)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
            }

            VStack(spacing: 0) { content }
                .frame(maxWidth: .infinity)
                .groupedCard()

            if let footer {
                Text(footer)
                    .font(.system(size: 13))
                    .lineSpacing(2)
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
        }
    }
}

extension View {
    /// White rounded card with the hairline edge used by grouped lists.
    func groupedCard(radius: CGFloat = AppTheme.Radius.tile) -> some View {
        background(AppTheme.ColorToken.cardBackground, in: .rect(cornerRadius: radius, style: .continuous))
            .clipShape(.rect(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color(hex: 0x28185A, opacity: 0.06), lineWidth: 0.5)
            }
    }

    /// The inset hairline under a grouped row. `inset` lines it up with the
    /// row's text rather than its icon.
    func rowDivider(_ isShown: Bool, inset: CGFloat = 16) -> some View {
        overlay(alignment: .bottom) {
            if isShown {
                Rectangle()
                    .fill(AppTheme.ColorToken.separator)
                    .frame(height: 0.5)
                    .padding(.leading, inset)
            }
        }
    }
}

// MARK: - Rows

/// "Reminder ·········· Fri 9 Oct, 9:00 ›" — a tappable label/value row.
struct ValueRow: View {
    let title: String
    var value: String?
    var valueTint: Color = AppTheme.ColorToken.secondaryText
    var showsChevron = true
    var showsDivider = true
    var action: (() -> Void)?

    var body: some View {
        if let action {
            Button(action: action) { label }
                .buttonStyle(RowPressStyle())
        } else {
            label
        }
    }

    private var label: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 17))
                .foregroundStyle(AppTheme.ColorToken.primaryText)
            Spacer(minLength: 8)
            if let value {
                Text(value)
                    .font(.system(size: 17))
                    .foregroundStyle(valueTint)
                    .lineLimit(1)
            }
            if showsChevron && action != nil {
                Chevron()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 52)
        .contentShape(.rect)
        .rowDivider(showsDivider)
    }
}

/// A row with a switch, as in Settings.
struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    var showsDivider = false

    var body: some View {
        Toggle(title, isOn: $isOn)
            .font(.system(size: 17))
            .foregroundStyle(AppTheme.ColorToken.primaryText)
            .tint(AppTheme.ColorToken.accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 52)
            .rowDivider(showsDivider)
    }
}

struct Chevron: View {
    var body: some View {
        Icon(.chevR, size: 16)
            .foregroundStyle(Color(light: 0xBDB9C9, dark: 0x5C5868))
            .accessibilityHidden(true)
    }
}

/// Highlights a whole row while pressed, like a table cell.
struct RowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? AppTheme.ColorToken.controlFill : .clear)
    }
}

// MARK: - Stock ring

/// The medicine tile inside a ring that shows how much of a full pack is
/// left, in the urgency colour — the design's identity mark for a medicine
/// in lists.
struct StockRingIcon: View {
    let medicine: Medicine
    var size: CGFloat = 46

    var body: some View {
        ZStack {
            ProgressRing(progress: medicine.stockFraction, lineWidth: 3, tint: medicine.urgency.tint)
            MedicineIconView(medicine: medicine, size: size * 0.7)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Buttons

/// The grey capsule beside a primary button ("Ordered").
struct SecondaryButtonStyle: ButtonStyle {
    var height: CGFloat = 48

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(AppTheme.ColorToken.primaryText)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(AppTheme.ColorToken.controlFill, in: .capsule)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}
