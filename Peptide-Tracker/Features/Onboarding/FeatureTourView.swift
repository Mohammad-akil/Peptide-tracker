import AVFoundation
import SwiftUI

/// Three swipeable pages after Get started, each with a short looping video
/// of what the app does. Videos live in `Resources/OnboardingVideos` as
/// `onboarding-1.mp4` … `onboarding-3.mp4`; a missing file shows the icon
/// tile instead, so the tour works before the videos are added.
struct FeatureTourView: View {
    let onContinue: () -> Void

    @State private var page = 0

    private let pages: [FeaturePage] = [
        FeaturePage(
            video: "onboarding-1",
            icon: .pill,
            title: "Add what you take.",
            text: "Pills, injections, creams, liquids and drops — with how much you have and how often you take it."
        ),
        FeaturePage(
            video: "onboarding-2",
            icon: .timeline,
            title: "Watch your supply count down.",
            text: "See exactly how many days each medicine has left, updated with every dose."
        ),
        FeaturePage(
            video: "onboarding-3",
            icon: .bell,
            title: "Get reminded in time to refill.",
            text: "A heads-up timed to how long your refill really takes, so you never run out."
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    pageView(pages[index], isCurrent: index == page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea(edges: .top)
            .overlay(alignment: .topTrailing) {
                Button("Skip", action: onContinue)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.ColorToken.primaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.trailing, 20)
                    .opacity(isLastPage ? 0 : 1)
            }

            dots
                .padding(.bottom, 20)

            Button(isLastPage ? "Continue" : "Next", action: next)
                .buttonStyle(.primary(height: 56))
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.ColorToken.background.ignoresSafeArea())
        .animation(.snappy, value: page)
    }

    private var isLastPage: Bool { page == pages.count - 1 }

    private func pageView(_ feature: FeaturePage, isCurrent: Bool) -> some View {
        VStack(spacing: 0) {
            // Edge to edge with no frame; the bottom fades into the page.
            LoopingVideo(name: feature.video, isPlaying: isCurrent) {
                Icon(feature.icon, size: 72)
                    .foregroundStyle(AppTheme.ColorToken.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.ColorToken.accentSoft)
            }
            .clipped()
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [AppTheme.ColorToken.background.opacity(0), AppTheme.ColorToken.background],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 120)
            }
            .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text(feature.title)
                    .font(.system(size: 30, weight: .heavy))
                    .kerning(-0.6)
                    .accessibilityAddTraits(.isHeader)
                Text(feature.text)
                    .font(.system(size: 17))
                    .lineSpacing(3)
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 28)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
    }

    private var dots: some View {
        HStack(spacing: 8) {
            ForEach(pages.indices, id: \.self) { index in
                Capsule()
                    .fill(index == page ? AppTheme.ColorToken.accent : AppTheme.ColorToken.accent.opacity(0.2))
                    .frame(width: index == page ? 22 : 8, height: 8)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Page \(page + 1) of \(pages.count)")
    }

    private func next() {
        HapticFeedback.selection()
        if isLastPage { onContinue() } else { page += 1 }
    }
}

private struct FeaturePage {
    let video: String
    let icon: AppIcon
    let title: String
    let text: String
}

// MARK: - Video

/// A muted, looping, aspect-filled bundled video that plays only while
/// `isPlaying`. Shows `placeholder` when the file isn't in the bundle.
private struct LoopingVideo<Placeholder: View>: View {
    let name: String
    let isPlaying: Bool
    @ViewBuilder let placeholder: () -> Placeholder

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let url = Bundle.main.url(forResource: name, withExtension: "mp4") {
            // Reduce Motion: hold the first frame instead of playing.
            PlayerView(url: url, isPlaying: isPlaying && !reduceMotion)
        } else {
            placeholder()
        }
    }
}

private struct PlayerView: UIViewRepresentable {
    let url: URL
    let isPlaying: Bool

    func makeUIView(context: Context) -> PlayerUIView {
        PlayerUIView(url: url)
    }

    func updateUIView(_ view: PlayerUIView, context: Context) {
        if isPlaying {
            view.player.seek(to: .zero)
            view.player.play()
        } else {
            view.player.pause()
        }
    }
}

private final class PlayerUIView: UIView {
    let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?

    override class var layerClass: AnyClass { AVPlayerLayer.self }

    init(url: URL) {
        super.init(frame: .zero)
        // Muted and ambient, so the tour never stops the user's music.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        let layer = layer as! AVPlayerLayer
        layer.player = player
        layer.videoGravity = .resizeAspectFill
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

#Preview {
    FeatureTourView {}
}
