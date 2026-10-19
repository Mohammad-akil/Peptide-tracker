import SwiftUI

/// The front and back of the body side by side, with the injection sites
/// filled: the picked one in accent, the suggested one in a lighter accent,
/// sites used in the last few days in grey, and the rest faintly so they
/// read as tappable. Tapping a site picks it; without `onSelect` the map
/// only shows.
struct BodyMap: View {
    var selected: InjectionSite?
    var suggested: InjectionSite?
    /// When each site was last used.
    var lastUsed: [InjectionSite: Date] = [:]
    var now: Date = .now
    var onSelect: ((InjectionSite) -> Void)?

    /// Sites used this recently are greyed out.
    static let restDays = 3

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            side("Front", paths: InjectionSitePaths.frontParsed, viewBox: InjectionSitePaths.frontViewBox)
            side("Back", paths: InjectionSitePaths.backParsed, viewBox: InjectionSitePaths.backViewBox)
        }
    }

    private func side(_ title: String, paths: [(site: InjectionSite?, path: Path)], viewBox: CGSize) -> some View {
        VStack(spacing: 8) {
            BodyMapSide(paths: paths, viewBox: viewBox, fill: fill(for:), onSelect: onSelect)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private func fill(for site: InjectionSite) -> Color {
        if site == selected { return AppTheme.ColorToken.accent }
        if site == suggested { return AppTheme.ColorToken.accent.opacity(0.35) }
        if Self.isResting(lastUsed: lastUsed[site], now: now) { return AppTheme.ColorToken.tertiaryText.opacity(0.4) }
        return AppTheme.ColorToken.accent.opacity(0.1)
    }

    /// Whether a site last used at `lastUsed` should still rest.
    static func isResting(lastUsed: Date?, now: Date) -> Bool {
        guard let lastUsed else { return false }
        return Calendar.current.days(from: lastUsed, to: now) < restDays
    }
}

/// One side of the body drawn in a `Canvas`. Taps are tested against each
/// site's path in artwork coordinates, top-most first, as in Plates'
/// `MuscleSilhouetteSide`.
private struct BodyMapSide: View {
    let paths: [(site: InjectionSite?, path: Path)]
    let viewBox: CGSize
    let fill: (InjectionSite) -> Color
    let onSelect: ((InjectionSite) -> Void)?

    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / viewBox.width, geometry.size.height / viewBox.height)
            let offset = CGPoint(
                x: (geometry.size.width - viewBox.width * scale) / 2,
                y: (geometry.size.height - viewBox.height * scale) / 2
            )

            Canvas { context, _ in
                context.translateBy(x: offset.x, y: offset.y)
                context.scaleBy(x: scale, y: scale)
                for entry in paths {
                    if let site = entry.site {
                        context.fill(entry.path, with: .color(fill(site)))
                    }
                    context.stroke(
                        entry.path,
                        with: .color(AppTheme.ColorToken.tertiaryText.opacity(0.6)),
                        style: StrokeStyle(lineWidth: 1.2 / scale, lineJoin: .round)
                    )
                }
            }
            .contentShape(.rect)
            .gesture(
                SpatialTapGesture().onEnded { value in
                    guard let onSelect, scale > 0 else { return }
                    let point = CGPoint(x: (value.location.x - offset.x) / scale, y: (value.location.y - offset.y) / scale)
                    guard let site = paths.reversed().first(where: { $0.site != nil && $0.path.contains(point) })?.site else { return }
                    onSelect(site)
                },
                including: onSelect == nil ? .none : .all
            )
        }
        .aspectRatio(viewBox.width / viewBox.height, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

#Preview {
    BodyMap(selected: .thighLeft, suggested: .abdomenRight, lastUsed: [.armLeft: .now]) { _ in }
        .padding()
}
