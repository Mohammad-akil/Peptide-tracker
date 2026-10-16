import AVFoundation
import SwiftUI

/// A muted, looping, aspect-filled bundled video that plays only while
/// `isPlaying`. Shows `placeholder` when the file isn't in the bundle.
struct LoopingVideo<Placeholder: View>: View {
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
