import SwiftUI

/// Today's mood as a living character, drawn with shapes (not a picture)
/// so every part can morph: picking another mood bends the mouth into the
/// new curve, reshapes the eyes and brows, and blends the colour, with a
/// little pop. While idle it breathes and blinks; "Great" twinkles, "Bad"
/// sheds a tear. Tap it and it giggles. Reduce Motion keeps the morph but
/// drops the idle motion.
struct MoodCharacter: View {
    let mood: DailyCheckIn.Mood?
    var size: CGFloat = 150

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBlinking = false
    @State private var breathe = false
    @State private var pop = false
    @State private var wiggle = 0.0
    @State private var tearFall = false
    @State private var twinkle = false

    private var look: Look { Look(mood) }

    var body: some View {
        let s = size
        ZStack {
            // Sparkles, behind the face, for Great.
            ForEach(Array(Self.sparkles.enumerated()), id: \.offset) { index, spark in
                Sparkle()
                    .fill(index == 1 ? Color(hex: 0x8A6CF0) : Color(hex: 0xF5C451))
                    .frame(width: s * spark.size, height: s * spark.size)
                    .scaleEffect(twinkle == (index % 2 == 0) ? 1 : 0.55)
                    .rotationEffect(.degrees(twinkle ? 20 : -10))
                    .offset(x: s * spark.x, y: s * spark.y)
                    .opacity(look.sparkle)
            }

            Group {
                Circle().fill(look.shade).offset(y: s * 0.025)
                Circle().fill(look.face).padding(s * 0.015)
                Ellipse()
                    .fill(.white.opacity(0.3))
                    .frame(width: s * 0.28, height: s * 0.14)
                    .rotationEffect(.degrees(-32))
                    .offset(x: -s * 0.19, y: -s * 0.27)

                // Cheeks
                HStack(spacing: s * 0.36) {
                    Ellipse().frame(width: s * 0.14, height: s * 0.08)
                    Ellipse().frame(width: s * 0.14, height: s * 0.08)
                }
                .foregroundStyle(Color(hex: 0xFF7E98).opacity(look.cheeks))
                .offset(y: s * 0.09)

                eyes(s)
                brows(s)
                mouth(s)

                // A tear for Bad, rolling down and starting again.
                Teardrop()
                    .fill(Color(hex: 0x5AB4F0))
                    .frame(width: s * 0.07, height: s * 0.1)
                    .offset(x: s * 0.25, y: s * (tearFall ? 0.2 : 0.06))
                    .opacity(look.tear * (tearFall ? 0 : 1))
            }
            .frame(width: s, height: s)
            .scaleEffect(x: breathe ? 1.02 : 1, y: breathe ? 0.985 : 1, anchor: .bottom)
        }
        .frame(width: s * 1.35, height: s * 1.2)
        .scaleEffect(pop ? 1.1 : 1)
        .rotationEffect(.degrees(wiggle))
        .contentShape(.circle)
        .onTapGesture(perform: giggle)
        .onChange(of: mood) { _, _ in react() }
        .task { await idle() }
        .accessibilityElement()
        .accessibilityLabel(mood.map { String(localized: "Feeling \($0.title.lowercased())") } ?? "No mood logged today")
        .accessibilityAddTraits(.isImage)
    }

    // MARK: Parts

    private func eyes(_ s: CGFloat) -> some View {
        let open = isBlinking ? 0.08 : look.eyeOpen
        return HStack(spacing: s * 0.18) {
            ForEach([-1.0, 1.0], id: \.self) { side in
                ZStack {
                    // Round eyes, with a glint.
                    Ellipse()
                        .fill(Self.ink)
                        .frame(width: s * 0.1, height: s * 0.1 * max(open, 0.08))
                        .overlay(alignment: .topTrailing) {
                            Circle().fill(.white).frame(width: s * 0.03).offset(x: -s * 0.012, y: s * 0.012)
                                .opacity(open > 0.5 ? 1 : 0)
                        }
                        .opacity(look.roundEyes)
                    // Happy "^" eyes for Great.
                    HappyEye()
                        .stroke(Self.ink, style: StrokeStyle(lineWidth: s * 0.045, lineCap: .round))
                        .frame(width: s * 0.14, height: s * 0.07)
                        .opacity(look.happyEyes)
                    // Squeezed ">" "<" eyes for Bad.
                    SqueezeEye()
                        .stroke(Self.ink, style: StrokeStyle(lineWidth: s * 0.045, lineCap: .round, lineJoin: .round))
                        .frame(width: s * 0.1, height: s * 0.11)
                        .scaleEffect(x: side, y: 1)
                        .opacity(look.squeezeEyes)
                }
                .frame(width: s * 0.14, height: s * 0.12)
            }
        }
        .offset(y: -s * 0.06)
    }

    private func brows(_ s: CGFloat) -> some View {
        HStack(spacing: s * 0.2) {
            ForEach([-1.0, 1.0], id: \.self) { side in
                Capsule()
                    .fill(Self.ink)
                    .frame(width: s * 0.12, height: s * 0.032)
                    .rotationEffect(.degrees(side * look.browTilt))
            }
        }
        .offset(y: -s * 0.2)
        .opacity(look.brows)
    }

    private func mouth(_ s: CGFloat) -> some View {
        ZStack {
            Mouth(smile: look.smile)
                .stroke(Self.ink, style: StrokeStyle(lineWidth: s * 0.045, lineCap: .round))
                .opacity(1 - look.open)
            OpenMouth(depth: look.open)
                .fill(Self.ink)
                .overlay(alignment: .bottom) {
                    Ellipse()
                        .fill(Color(hex: 0xFF7E98))
                        .frame(width: s * 0.13, height: s * 0.06)
                        .offset(y: -s * 0.012)
                        .opacity(look.open)
                }
                .clipShape(OpenMouth(depth: max(look.open, 0.01)))
                .opacity(look.open)
        }
        .frame(width: s * 0.34, height: s * 0.14)
        .offset(y: s * 0.16)
    }

    // MARK: Motion

    /// A pop and a little shake when the mood changes.
    private func react() {
        guard !reduceMotion else { return }
        withAnimation(.spring(response: 0.22, dampingFraction: 0.45)) { pop = true; wiggle = -6 }
        Task {
            try? await Task.sleep(for: .milliseconds(160))
            withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) { pop = false; wiggle = 0 }
        }
    }

    private func giggle() {
        HapticFeedback.impact(.soft)
        guard !reduceMotion else { return }
        Task {
            for angle in [8.0, -8.0, 5.0, 0.0] {
                withAnimation(.spring(response: 0.12, dampingFraction: 0.5)) { wiggle = angle }
                try? await Task.sleep(for: .milliseconds(90))
            }
        }
        withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) { pop = true }
        Task {
            try? await Task.sleep(for: .milliseconds(180))
            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { pop = false }
        }
    }

    /// Breathing, blinking every few seconds, twinkles and the tear.
    private func idle() async {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { breathe = true }
        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { twinkle = true }
        var tick = 0
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(1600))
            guard !Task.isCancelled else { return }
            tick += 1
            if tick % 2 == 0 {
                withAnimation(.easeIn(duration: 0.07)) { isBlinking = true }
                try? await Task.sleep(for: .milliseconds(110))
                withAnimation(.easeOut(duration: 0.1)) { isBlinking = false }
            }
            if look.tear > 0 {
                withAnimation(.easeIn(duration: 1.2)) { tearFall = true }
                try? await Task.sleep(for: .milliseconds(1250))
                tearFall = false
            }
        }
    }

    // MARK: Looks

    static let ink = Color(hex: 0x1B1530)

    private static let sparkles: [(x: CGFloat, y: CGFloat, size: CGFloat)] = [
        (0.52, -0.42, 0.16), (-0.55, -0.22, 0.1), (0.5, 0.38, 0.09),
    ]

    /// Every number that shapes the face, per mood. SwiftUI animates
    /// between two looks, which is the morph.
    struct Look {
        var face: Color
        var shade: Color
        var smile: Double       // -1 frown … 1 smile
        var open: Double        // 0 closed … 1 open grin
        var eyeOpen: Double     // round eye height
        var roundEyes: Double
        var happyEyes: Double
        var squeezeEyes: Double
        var brows: Double
        var browTilt: Double    // degrees; positive = worried
        var cheeks: Double
        var tear: Double
        var sparkle: Double

        init(_ mood: DailyCheckIn.Mood?) {
            switch mood {
            case .great:
                self.init(face: Color(hex: 0x8A6CF0), shade: Color(hex: 0x6A45D8), smile: 1, open: 1, eyeOpen: 1,
                          roundEyes: 0, happyEyes: 1, squeezeEyes: 0, brows: 0, browTilt: 0, cheeks: 0.5, tear: 0, sparkle: 1)
            case .good:
                self.init(face: Color(hex: 0x46C38E), shade: Color(hex: 0x1F9E6A), smile: 0.75, open: 0, eyeOpen: 1,
                          roundEyes: 1, happyEyes: 0, squeezeEyes: 0, brows: 0, browTilt: 0, cheeks: 0.35, tear: 0, sparkle: 0)
            case .okay:
                self.init(face: Color(hex: 0xF5C451), shade: Color(hex: 0xD9A21E), smile: 0, open: 0, eyeOpen: 1,
                          roundEyes: 1, happyEyes: 0, squeezeEyes: 0, brows: 0, browTilt: 0, cheeks: 0, tear: 0, sparkle: 0)
            case .low:
                self.init(face: Color(hex: 0x8E9AC9), shade: Color(hex: 0x6B78AD), smile: -0.55, open: 0, eyeOpen: 0.85,
                          roundEyes: 1, happyEyes: 0, squeezeEyes: 0, brows: 1, browTilt: -18, cheeks: 0, tear: 0, sparkle: 0)
            case .bad:
                self.init(face: Color(hex: 0xF07A6E), shade: Color(hex: 0xD2554A), smile: -0.9, open: 0, eyeOpen: 1,
                          roundEyes: 0, happyEyes: 0, squeezeEyes: 1, brows: 0, browTilt: 0, cheeks: 0, tear: 1, sparkle: 0)
            case nil:
                // Not logged yet: a calm grey face, waiting.
                self.init(face: Color(hex: 0xDCD8E6), shade: Color(hex: 0xC2BDD1), smile: 0.2, open: 0, eyeOpen: 1,
                          roundEyes: 1, happyEyes: 0, squeezeEyes: 0, brows: 0, browTilt: 0, cheeks: 0, tear: 0, sparkle: 0)
            }
        }

        init(face: Color, shade: Color, smile: Double, open: Double, eyeOpen: Double, roundEyes: Double, happyEyes: Double,
             squeezeEyes: Double, brows: Double, browTilt: Double, cheeks: Double, tear: Double, sparkle: Double) {
            self.face = face; self.shade = shade; self.smile = smile; self.open = open; self.eyeOpen = eyeOpen
            self.roundEyes = roundEyes; self.happyEyes = happyEyes; self.squeezeEyes = squeezeEyes
            self.brows = brows; self.browTilt = browTilt; self.cheeks = cheeks; self.tear = tear; self.sparkle = sparkle
        }
    }
}

// MARK: - Animatable shapes

/// The mouth line: a curve whose bend is `smile`, so a frown can flow into
/// a smile point by point.
private struct Mouth: Shape {
    var smile: Double
    var animatableData: Double {
        get { smile }
        set { smile = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let y = rect.midY - CGFloat(smile) * rect.height * 0.25
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.08, y: y))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.08, y: y),
            control: CGPoint(x: rect.midX, y: y + CGFloat(smile) * rect.height * 1.1)
        )
        return path
    }
}

/// The open grin: a flat top and a round bottom whose depth animates.
private struct OpenMouth: Shape {
    var depth: Double
    var animatableData: Double {
        get { depth }
        set { depth = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let top = rect.minY + rect.height * 0.1
        path.move(to: CGPoint(x: rect.minX, y: top))
        path.addLine(to: CGPoint(x: rect.maxX, y: top))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: top),
            control: CGPoint(x: rect.midX, y: top + rect.height * 1.7 * CGFloat(depth))
        )
        path.closeSubpath()
        return path
    }
}

private struct HappyEye: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.6))
        return path
    }
}

/// ">" — mirrored for the other eye.
private struct SqueezeEye: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return path
    }
}

private struct Teardrop: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY - rect.width / 2), control: CGPoint(x: rect.maxX, y: rect.midY - rect.height * 0.1))
        path.addArc(center: CGPoint(x: rect.midX, y: rect.maxY - rect.width / 2), radius: rect.width / 2, startAngle: .zero, endAngle: .degrees(180), clockwise: false)
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.midY - rect.height * 0.1))
        return path
    }
}

/// A four-point twinkle.
private struct Sparkle: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        let k = r * 0.28
        var path = Path()
        path.move(to: CGPoint(x: c.x, y: c.y - r))
        path.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + k, y: c.y - k))
        path.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + k, y: c.y + k))
        path.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - k, y: c.y + k))
        path.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - k, y: c.y - k))
        return path
    }
}

#Preview {
    @Previewable @State var mood: DailyCheckIn.Mood? = .great
    VStack(spacing: 24) {
        MoodCharacter(mood: mood)
        Picker("Mood", selection: $mood) {
            Text("None").tag(DailyCheckIn.Mood?.none)
            ForEach(DailyCheckIn.Mood.scale) { Text($0.title).tag(Optional($0)) }
        }
        .pickerStyle(.segmented)
    }
    .padding()
    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: mood)
}
