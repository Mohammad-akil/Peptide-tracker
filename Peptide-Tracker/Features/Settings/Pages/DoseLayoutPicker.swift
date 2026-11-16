import SwiftUI

/// Settings → Doses → Home style: a 2×2 grid of small drawings of each
/// layout, so you can see what Today will look like before picking.
struct DoseLayoutPicker: View {
    @Binding var selection: DoseLayout

    private let columns = [
        GridItem(.flexible(), spacing: AppTheme.Spacing.smallMedium),
        GridItem(.flexible(), spacing: AppTheme.Spacing.smallMedium),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Home style")
                .font(.system(size: 17))
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: columns, spacing: AppTheme.Spacing.smallMedium) {
                ForEach(DoseLayout.allCases, id: \.self) { layout in
                    DoseLayoutTile(layout: layout, isSelected: selection == layout) {
                        withAnimation(.snappy) { selection = layout }
                    }
                }
            }

            Text(selection.detail)
                .font(.footnote)
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .contentTransition(.opacity)
                .id(selection)
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

private struct DoseLayoutTile: View {
    let layout: DoseLayout
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                DoseLayoutThumbnail(layout: layout)
                    .frame(height: 112)
                    .frame(maxWidth: .infinity)
                    .background(AppTheme.ColorToken.background, in: .rect(cornerRadius: 14))

                HStack(spacing: 6) {
                    Text(layout.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.ColorToken.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: 0)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18))
                        .foregroundStyle(isSelected ? AppTheme.ColorToken.accent : AppTheme.ColorToken.uncheckedRing)
                        .contentTransition(.symbolEffect(.replace))
                }
                .padding(.horizontal, 4)
            }
            .padding(10)
            .background(AppTheme.ColorToken.cardBackground, in: .rect(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(isSelected ? AppTheme.ColorToken.accent : .clear, lineWidth: 2)
            }
            .scaleEffect(isSelected ? 1 : 0.98)
            .contentShape(.rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(layout.title)
        .accessibilityHint(layout.detail)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Thumbnails

/// A tiny, data-free sketch of each Today layout, drawn with shapes so it
/// follows light and dark mode.
struct DoseLayoutThumbnail: View {
    let layout: DoseLayout

    private typealias C = AppTheme.ColorToken

    var body: some View {
        Group {
            switch layout {
            case .list: list
            case .timeline: timeline
            case .squarePillbox: pillbox(round: false)
            case .roundPillbox: pillbox(round: true)
            }
        }
        .padding(12)
        .accessibilityHidden(true)
    }

    // List: a time label, then rows of icon · name · check.
    private var list: some View {
        VStack(alignment: .leading, spacing: 5) {
            bar(width: 26, height: 4, color: C.tertiaryText.opacity(0.6))
            VStack(spacing: 0) {
                row(done: true)
                Divider().overlay(C.separator).padding(.leading, 20)
                row(done: true)
            }
            .background(C.cardBackground, in: .rect(cornerRadius: 8))
            bar(width: 26, height: 4, color: C.tertiaryText.opacity(0.6))
                .padding(.top, 2)
            row(done: false)
                .background(C.cardBackground, in: .rect(cornerRadius: 8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func row(done: Bool) -> some View {
        HStack(spacing: 6) {
            Circle().fill(C.accentSoft)
                .overlay(Circle().fill(C.accent).padding(3.5))
                .frame(width: 13, height: 13)
            VStack(alignment: .leading, spacing: 2.5) {
                bar(width: 34, height: 3.5, color: C.primaryText.opacity(0.75))
                bar(width: 20, height: 3, color: C.tertiaryText.opacity(0.6))
            }
            Spacer(minLength: 0)
            check(done: done, size: 11)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
    }

    // Timeline: a rail of dots, with a NOW line between past and upcoming.
    private var timeline: some View {
        VStack(spacing: 0) {
            slot(done: true, railTop: false)
            slot(done: true, railTop: true)
            HStack(spacing: 4) {
                Circle().fill(C.accent).frame(width: 6, height: 6)
                Capsule().fill(C.accent).frame(height: 1.5)
                Text("NOW")
                    .font(.system(size: 6.5, weight: .bold))
                    .foregroundStyle(C.accent)
            }
            .padding(.leading, 2)
            .padding(.vertical, 3)
            slot(done: false, railTop: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func slot(done: Bool, railTop: Bool) -> some View {
        HStack(alignment: .center, spacing: 6) {
            ZStack {
                Rectangle().fill(C.accentMuted).frame(width: 1.5)
                Circle()
                    .fill(done ? C.accent : C.cardBackground)
                    .overlay(Circle().strokeBorder(done ? .clear : C.uncheckedRing, lineWidth: 1.5))
                    .frame(width: 8, height: 8)
            }
            .frame(width: 10)
            HStack(spacing: 5) {
                Circle().fill(C.accentSoft).frame(width: 10, height: 10)
                bar(width: 30, height: 3.5, color: C.primaryText.opacity(done ? 0.4 : 0.75))
                Spacer(minLength: 0)
                check(done: done, size: 10)
            }
            .padding(.horizontal, 6)
            .frame(height: 20)
            .background(C.cardBackground, in: .rect(cornerRadius: 6))
        }
        .frame(height: 24)
    }

    // Pillbox: four compartments, square or round, with pills inside.
    private func pillbox(round: Bool) -> some View {
        let labels = ["AM", "NOON", "PM", "BED"]
        return Grid(horizontalSpacing: 7, verticalSpacing: 7) {
            ForEach(0..<2) { r in
                GridRow {
                    ForEach(0..<2) { c in
                        let i = r * 2 + c
                        compartment(label: labels[i], done: i < 2, next: i == 2, pills: [2, 1, 2, 1][i], round: round)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func compartment(label: String, done: Bool, next: Bool, pills: Int, round: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: round ? 100 : 9, style: .continuous)
        return VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 6, weight: .bold))
                .foregroundStyle(done ? Color.white.opacity(0.9) : C.tertiaryText)
            if done {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(.white)
            } else {
                HStack(spacing: 2.5) {
                    ForEach(0..<pills, id: \.self) { p in
                        Capsule()
                            .fill(p.isMultiple(of: 2) ? C.accent : C.accentMuted)
                            .frame(width: 5, height: 10)
                            .rotationEffect(.degrees(p.isMultiple(of: 2) ? -20 : 15))
                    }
                }
            }
        }
        .frame(width: round ? 40 : 46, height: 40)
        .background(shape.fill(done ? C.accent : C.cardBackground))
        .overlay(shape.strokeBorder(next ? C.accent : .clear, lineWidth: 1.5))
    }

    // MARK: Bits

    private func bar(width: CGFloat, height: CGFloat, color: Color) -> some View {
        Capsule().fill(color).frame(width: width, height: height)
    }

    private func check(done: Bool, size: CGFloat) -> some View {
        Circle()
            .fill(done ? C.accent : .clear)
            .overlay(Circle().strokeBorder(done ? .clear : C.uncheckedRing, lineWidth: 1.3))
            .overlay {
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.5, weight: .heavy))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: size, height: size)
    }
}

#Preview {
    @Previewable @State var layout: DoseLayout = .list
    ScrollView { DoseLayoutPicker(selection: $layout).padding() }
        .background(AppTheme.ColorToken.background)
}
