import AVFoundation
import Combine
import Observation

@Observable final class PlaybackController {
    let player: AVPlayer
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var isPlaying = false
    private(set) var currentVideoURL: URL?

    var isLooping: Bool = false {
        didSet { updateLoopObserver() }
    }
    private(set) var activeRangeStart: TimeInterval?
    private(set) var activeRangeEnd: TimeInterval?

    private var periodicObserver: Any?
    private var loopObserver: Any?
    private var cancellables = Set<AnyCancellable>()

    init(videoURL: URL? = nil) {
        if let videoURL {
            let item = AVPlayerItem(url: videoURL)
            player = AVPlayer(playerItem: item)
            currentVideoURL = videoURL
        } else {
            player = AVPlayer()
        }
        setupObservers()
    }

    func loadVideo(url: URL) {
        guard url != currentVideoURL else { return }
        player.pause()
        duration = 0
        currentTime = 0
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        currentVideoURL = url
        setActiveRange(start: nil, end: nil)
    }

    func setActiveRange(start: TimeInterval?, end: TimeInterval?) {
        activeRangeStart = start
        activeRangeEnd = end
        updateLoopObserver()
    }

    deinit {
        if let obs = periodicObserver { player.removeTimeObserver(obs) }
        if let obs = loopObserver { player.removeTimeObserver(obs) }
    }

    func play() {
        prepareAudioSession()
        player.play()
    }
    func pause()  { player.pause() }

    func toggle() {
        if isPlaying { pause() } else { play() }
    }

    func seek(to t: TimeInterval) {
        let cmTime = CMTime(seconds: t, preferredTimescale: 600)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func updateLoopObserver() {
        if let obs = loopObserver {
            player.removeTimeObserver(obs)
            loopObserver = nil
        }
        guard isLooping,
              let start = activeRangeStart,
              let end = activeRangeEnd,
              end > start else { return }
        let cm = CMTime(seconds: end, preferredTimescale: 600)
        loopObserver = player.addBoundaryTimeObserver(
            forTimes: [NSValue(time: cm)],
            queue: .main
        ) { [weak self] in
            guard let self, self.isLooping else { return }
            self.seek(to: start)
        }
    }

    private func setupObservers() {
        let interval = CMTime(value: 1, timescale: 30)
        periodicObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.currentTime = time.seconds
        }

        player.publisher(for: \.rate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rate in self?.isPlaying = rate != 0 }
            .store(in: &cancellables)

        player.publisher(for: \.currentItem?.duration)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] dur in
                if let secs = dur?.seconds, secs.isFinite, secs > 0 {
                    self?.duration = secs
                }
            }
            .store(in: &cancellables)
    }

    private func prepareAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback)
        try? session.setActive(true)
    }
}
