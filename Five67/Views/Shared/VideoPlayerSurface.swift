import AVFoundation
import SwiftUI
import UIKit

struct VideoPlayerSurface: UIViewRepresentable {
    let controller: PlaybackController
    var videoGravity: AVLayerVideoGravity = .resizeAspect

    func makeUIView(context: Context) -> PlayerSurfaceView {
        let view = PlayerSurfaceView()
        view.player = controller.player
        view.videoGravity = videoGravity
        view.onTap = { [controller] in controller.toggle() }
        return view
    }

    func updateUIView(_ uiView: PlayerSurfaceView, context: Context) {
        if uiView.player !== controller.player {
            uiView.player = controller.player
        }
        if uiView.videoGravity != videoGravity {
            uiView.videoGravity = videoGravity
        }
    }
}

final class PlayerSurfaceView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }

    var videoGravity: AVLayerVideoGravity {
        get { playerLayer.videoGravity }
        set { playerLayer.videoGravity = newValue }
    }

    var onTap: (@MainActor () -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        playerLayer.videoGravity = .resizeAspect
        backgroundColor = .black
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func handleTap() { onTap?() }
}
