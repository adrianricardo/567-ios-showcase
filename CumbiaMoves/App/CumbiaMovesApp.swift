import SwiftUI
import SwiftData
import AVFoundation

@main
struct CumbiaMovesApp: App {
    let container: ModelContainer

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)

        let schema = Schema([Video.self, Move.self])
        let config = ModelConfiguration()

        do {
            container = try ModelContainer(
                for: schema,
                migrationPlan: CumbiaMovesMigrationPlan.self,
                configurations: config
            )
        } catch {
            print("ModelContainer load failed: \(error). Wiping store and retrying.")
            Self.wipeDefaultStore()
            do {
                container = try ModelContainer(
                    for: schema,
                    migrationPlan: CumbiaMovesMigrationPlan.self,
                    configurations: config
                )
            } catch {
                fatalError("ModelContainer load failed even after wipe: \(error)")
            }
        }
    }

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

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
