import SwiftUI
import SwiftData

@main
struct Five67App: App {
    @State private var loadResult: Result<ModelContainer, Error>
    @State private var playbackSession = PlaybackSession()
    @State private var router = AppRouter()
    @State private var styleStore = StyleStore()

    init() {
        _loadResult = State(initialValue: Self.loadContainer())
    }

    var body: some Scene {
        WindowGroup {
            switch loadResult {
            case .success(let container):
                RootView()
                    .modelContainer(container)
                    .environment(playbackSession)
                    .environment(router)
                    .environment(styleStore)
            case .failure(let error):
                MigrationFailureView(error: error) {
                    Self.wipeDefaultStore()
                    loadResult = Self.loadContainer()
                }
            }
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
