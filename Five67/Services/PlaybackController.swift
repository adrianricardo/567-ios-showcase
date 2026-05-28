import AVFoundation
import Combine
import Observation
import OSLog

@MainActor
@Observable final class PlaybackController {
    let player: AVPlayer
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var isPlaying = false
    private(set) var currentVideoURL: URL?
    private(set) var videoSize: CGSize = .zero

    var isLooping: Bool = false {
        didSet { updateLoopObserver() }
    }
    var isMuted: Bool = false {
        didSet { player.isMuted = isMuted }
    }
    private(set) var activeRangeStart: TimeInterval?
    private(set) var activeRangeEnd: TimeInterval?

    private var periodicObserver: Any?
    private var loopObserver: Any?
    private var pendingPlaybackStart: TimeInterval?
    private var pendingPlaybackEnd: TimeInterval?
    private var itemStatusObservation: NSKeyValueObservation?
    private var assetPreflightTask: Task<Void, Never>?
    private var readinessTimeoutTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "Five67", category: "Playback")

    init(videoURL: URL? = nil) {
        player = AVPlayer()
        setupObservers()
        if let videoURL {
            loadVideo(url: videoURL)
        }
    }

    func loadVideo(url: URL) {
        guard url != currentVideoURL else { return }
        player.pause()
        duration = 0
        currentTime = 0
        videoSize = .zero
        pendingPlaybackStart = nil
        pendingPlaybackEnd = nil
        assetPreflightTask?.cancel()
        readinessTimeoutTask?.cancel()

        let asset = AVURLAsset(url: url)
        let item = makePlayerItem(asset: asset)
        observeStatus(of: item)
        player.replaceCurrentItem(with: item)
        currentVideoURL = url
        setActiveRange(start: nil, end: nil)
        logLoadedVideo(url)
        startAssetPreflight(asset, item: item, url: url)
        scheduleReadinessTimeout(for: item, url: url)
    }

    func setActiveRange(start: TimeInterval?, end: TimeInterval?) {
        activeRangeStart = start
        activeRangeEnd = end
        updateLoopObserver()
    }

    deinit {
        MainActor.assumeIsolated {
            assetPreflightTask?.cancel()
            readinessTimeoutTask?.cancel()
            if let obs = periodicObserver { player.removeTimeObserver(obs) }
            if let obs = loopObserver { player.removeTimeObserver(obs) }
        }
    }

    func play() {
        prepareAudioSession()
        // If the player is parked at the end of the item (natural end-of-
        // playback), `player.play()` is a no-op. Rewind to the active range
        // start so a tap on the play affordance restarts the video instead of
        // doing nothing.
        rewindIfAtEnd()
        player.play()
        if let error = player.currentItem?.error ?? player.error {
            logger.error("Playback error while starting: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func rewindIfAtEnd() {
        guard let totalDuration = currentPlayableDuration(), totalDuration > 0 else { return }
        guard currentTime >= totalDuration - 0.1 else { return }
        seek(to: activeRangeStart ?? 0)
    }

    func playRange(start: TimeInterval, end: TimeInterval?) {
        setActiveRange(start: start, end: end)

        guard player.currentItem?.status == .readyToPlay else {
            pendingPlaybackStart = start
            pendingPlaybackEnd = end
            logger.debug("Queued range playback until item is ready. start=\(start, privacy: .public)")
            return
        }

        startPlayback(start: start, end: end)
    }

    func pause()  { player.pause() }

    func toggle() {
        if isPlaying { pause() } else { play() }
    }

    func seek(to t: TimeInterval) {
        guard t.isFinite, t >= 0 else {
            logger.error("Ignoring invalid seek time: \(t, privacy: .public)")
            return
        }

        let duration = currentPlayableDuration()
        let target = duration.map { min(t, max(0, $0)) } ?? t
        let cmTime = CMTime(seconds: target, preferredTimescale: 600)
        let tolerance = CMTime(value: 1, timescale: 30)

        logger.debug("Seeking to \(target, privacy: .public)")
        currentTime = target
        player.seek(to: cmTime, toleranceBefore: tolerance, toleranceAfter: tolerance) { [weak self] finished in
            guard let self else { return }
            if !finished {
                self.logger.debug("Seek cancelled before completion")
            }
            if let error = self.player.currentItem?.error ?? self.player.error {
                self.logger.error("Seek error: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func makePlayerItem(asset: AVURLAsset) -> AVPlayerItem {
        AVPlayerItem(
            asset: asset,
            automaticallyLoadedAssetKeys: [.duration, .tracks, .isPlayable]
        )
    }

    private func observeStatus(of item: AVPlayerItem) {
        itemStatusObservation = item.observe(\.status, options: [.new, .initial]) { [weak self, weak item] observedItem, _ in
            Task { @MainActor in
                self?.handleItemStatus(item ?? observedItem)
            }
        }
    }

    private func startAssetPreflight(_ asset: AVURLAsset, item: AVPlayerItem, url: URL) {
        assetPreflightTask = Task { [weak self, weak item] in
            do {
                let (duration, isPlayable, tracks) = try await asset.load(.duration, .isPlayable, .tracks)
                await MainActor.run { [weak self, weak item] in
                    guard let controller = self,
                          let currentItem = item,
                          currentItem === controller.player.currentItem else { return }
                    controller.logger.info(
                        "Asset preflight succeeded: \(url.lastPathComponent, privacy: .public), playable=\(isPlayable, privacy: .public), duration=\(duration.seconds, privacy: .public), tracks=\(tracks.count, privacy: .public)"
                    )
                    if !isPlayable {
                        controller.logger.error("Asset is not playable: \(url.lastPathComponent, privacy: .public)")
                    }
                }
            } catch {
                await MainActor.run { [weak self, weak item] in
                    guard let controller = self,
                          let currentItem = item,
                          currentItem === controller.player.currentItem else { return }
                    controller.pendingPlaybackStart = nil
                    controller.pendingPlaybackEnd = nil
                    controller.logger.error(
                        "Asset preflight failed: \(url.lastPathComponent, privacy: .public), error=\(error.localizedDescription, privacy: .public)"
                    )
                }
            }
        }
    }

    private func scheduleReadinessTimeout(for item: AVPlayerItem, url: URL) {
        readinessTimeoutTask = Task { [weak self, weak item] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self, weak item] in
                guard let controller = self,
                      let currentItem = item,
                      currentItem === controller.player.currentItem else { return }
                guard currentItem.status == .unknown else { return }
                let message = currentItem.error?.localizedDescription ?? "No item error reported"
                controller.logger.error(
                    "Player item still not ready after timeout: \(url.lastPathComponent, privacy: .public), status=unknown, error=\(message, privacy: .public)"
                )
            }
        }
    }

    private func handleItemStatus(_ item: AVPlayerItem) {
        guard item === player.currentItem else { return }

        switch item.status {
        case .readyToPlay:
            readinessTimeoutTask?.cancel()
            logger.info("Player item ready")
            playPendingRangeIfNeeded()
        case .failed:
            readinessTimeoutTask?.cancel()
            let message = item.error?.localizedDescription ?? "Unknown AVPlayerItem error"
            pendingPlaybackStart = nil
            pendingPlaybackEnd = nil
            logger.error("Player item failed: \(message, privacy: .public)")
        case .unknown:
            logger.debug("Player item status unknown")
        @unknown default:
            logger.error("Player item status unrecognized")
        }
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
            MainActor.assumeIsolated {
                guard let self, self.isLooping else { return }
                self.seek(to: start)
            }
        }
    }

    private func setupObservers() {
        let interval = CMTime(value: 1, timescale: 30)
        periodicObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                let seconds = time.seconds
                guard seconds.isFinite, seconds >= 0 else { return }
                self?.currentTime = seconds
            }
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

        player.publisher(for: \.currentItem?.presentationSize)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] size in
                guard let self, let size,
                      size.width > 0, size.height > 0,
                      size != self.videoSize else { return }
                self.videoSize = size
            }
            .store(in: &cancellables)
    }

    private func currentPlayableDuration() -> TimeInterval? {
        if duration.isFinite, duration > 0 {
            return duration
        }
        guard let seconds = player.currentItem?.duration.seconds,
              seconds.isFinite,
              seconds > 0 else {
            return nil
        }
        return seconds
    }

    private func playPendingRangeIfNeeded() {
        guard let start = pendingPlaybackStart else { return }
        let end = pendingPlaybackEnd
        pendingPlaybackStart = nil
        pendingPlaybackEnd = nil
        logger.debug("Starting queued range playback. start=\(start, privacy: .public)")
        startPlayback(start: start, end: end)
    }

    private func startPlayback(start: TimeInterval, end: TimeInterval?) {
        setActiveRange(start: start, end: end)
        seek(to: start)
        play()
    }

    private func logLoadedVideo(_ url: URL) {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isReadableKey])
        let fileSize = values?.fileSize ?? -1
        let isReadable = values?.isReadable ?? false
        logger.info(
            "Loaded video: \(url.lastPathComponent, privacy: .public), exists=\(FileManager.default.fileExists(atPath: url.path), privacy: .public), readable=\(isReadable, privacy: .public), bytes=\(fileSize, privacy: .public)"
        )
    }

    private func prepareAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback)
        try? session.setActive(true)
    }
}
