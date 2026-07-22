import SwiftUI
import SwiftData

#if DEBUG
import AVFoundation
import CoreVideo
#endif

@main
struct Five67App: App {
    @State private var loadResult: Result<ModelContainer, Error>
    @State private var playbackSession = PlaybackSession()
    @State private var router = AppRouter()
    @State private var styleStore = StyleStore()
    @State private var unlockStore = UnlockStore()
    @State private var splashFinished = false

    init() {
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-Five67UITestSkipOnboarding") {
            UserDefaults.standard.set(
                OnboardingStatus.completed.rawValue,
                forKey: OnboardingPreferences.Keys.status
            )
        }
#endif
        let result = Self.loadContainer()
#if DEBUG
        if arguments.contains("-Five67UITestSeedLibrary")
            || arguments.contains("-Five67UITestVideoCapFixture")
            || arguments.contains("-Five67UITestAboveVideoCapFixture"),
           case .success(let container) = result {
            UserDefaults.standard.set(PaneTab.moves.rawValue, forKey: "libraryPaneTab")
            UserDefaults.standard.set("", forKey: "styleStore.activeStyleID")
            let videoCount: Int
            if arguments.contains("-Five67UITestAboveVideoCapFixture") {
                videoCount = AccessPolicy.freeVideoLimit + 2
            } else if arguments.contains("-Five67UITestVideoCapFixture") {
                videoCount = AccessPolicy.freeVideoLimit
            } else {
                videoCount = 1
            }
            Self.seedUITestLibrary(in: container, videoCount: videoCount)
        }
        if arguments.contains("-Five67UITestOnboardingCompletionFixture")
            || arguments.contains("-Five67UITestReviewOnboarding"),
           case .success(let container) = result {
            UserDefaults.standard.set(
                OnboardingStatus.notStarted.rawValue,
                forKey: OnboardingPreferences.Keys.status
            )
            UserDefaults.standard.removeObject(forKey: OnboardingPreferences.Keys.hasCompleted)
            UserDefaults.standard.removeObject(forKey: OnboardingPreferences.Keys.seedVideoID)
            Self.clearUITestLibrary(in: container)
        }
#endif
        _loadResult = State(initialValue: result)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                switch loadResult {
                case .success(let container):
                    OnboardingGateView {
                        RootView()
                    }
                        .modelContainer(container)
                        .environment(playbackSession)
                        .environment(router)
                        .environment(styleStore)
                        .environment(unlockStore)
                case .failure(let error):
                    MigrationFailureView(error: error) {
                        Self.wipeDefaultStore()
                        loadResult = Self.loadContainer()
                    }
                }

                if !splashFinished {
                    SplashView { splashFinished = true }
                        .transition(.identity)
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    private static func loadContainer() -> Result<ModelContainer, Error> {
        let schema = Schema([Video.self, Move.self])
        let config = ModelConfiguration()
        do {
            let container = try ModelContainer(
                for: schema,
                migrationPlan: Five67MigrationPlan.self,
                configurations: config
            )
            return .success(container)
        } catch {
            return .failure(error)
        }
    }

#if DEBUG
    private static func seedUITestLibrary(in container: ModelContainer, videoCount: Int) {
        let context = container.mainContext
        let existing = (try? context.fetch(FetchDescriptor<Video>())) ?? []
        existing.forEach(context.delete)

        let fixtureFilename = prepareUITestVideo()
        let styles = Style.seedDefaultsIfNeeded(in: context)
        let salsa = styles.first { $0.id == Style.Default.salsa }
        for index in 0..<videoCount {
            let date = Date(timeIntervalSince1970: 1_720_483_200 + Double(index))
            let video = Video(
                displayName: index == 0 ? "Studio 22 practice" : "Practice video \(index + 1)",
                localFilename: fixtureFilename,
                importedAt: date,
                recordedAt: date,
                duration: 24,
                style: salsa
            )
            context.insert(video)
            if index == 0 {
                context.insert(Move(name: "Cross-body lead", time: 0, endTime: 12, video: video))
                context.insert(Move(name: "Inside turn setup", time: 12, endTime: 24, video: video))
            }
        }
        try? context.save()
    }

    private static func prepareUITestVideo() -> String {
        let filename = "ui-test-fixture.mov"
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("videos", isDirectory: true)
        let url = directory.appendingPathComponent(filename)

        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard !FileManager.default.fileExists(atPath: url.path) else { return filename }

        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mov) else {
            return filename
        }
        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: 160,
                AVVideoHeightKey: 90
            ]
        )
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: 160,
                kCVPixelBufferHeightKey as String: 90
            ]
        )
        guard writer.canAdd(input) else { return filename }
        writer.add(input)
        guard writer.startWriting() else { return filename }
        writer.startSession(atSourceTime: .zero)

        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            160,
            90,
            kCVPixelFormatType_32BGRA,
            nil,
            &pixelBuffer
        )
        guard let pixelBuffer else {
            writer.cancelWriting()
            return filename
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        if let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) {
            memset(baseAddress, 0, CVPixelBufferGetDataSize(pixelBuffer))
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

        for second in 0...24 {
            while !input.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.002)
            }
            guard adaptor.append(pixelBuffer, withPresentationTime: CMTime(value: Int64(second), timescale: 1)) else {
                writer.cancelWriting()
                return filename
            }
        }
        input.markAsFinished()

        let finished = DispatchSemaphore(value: 0)
        writer.finishWriting { finished.signal() }
        _ = finished.wait(timeout: .now() + 5)
        return filename
    }

    private static func clearUITestLibrary(in container: ModelContainer) {
        let context = container.mainContext
        let existing = (try? context.fetch(FetchDescriptor<Video>())) ?? []
        existing.forEach(context.delete)
        try? context.save()
    }
#endif

    /// Removes the SwiftData store files. Only invoked from the explicit "Reset library"
    /// action in `MigrationFailureView`. **Never** called as a silent fallback.
    private static func wipeDefaultStore() {
        guard let supportDir = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else { return }
        for suffix in ["", "-shm", "-wal"] {
            let url = supportDir.appendingPathComponent("default.store\(suffix)")
            try? FileManager.default.removeItem(at: url)
        }
    }
}
