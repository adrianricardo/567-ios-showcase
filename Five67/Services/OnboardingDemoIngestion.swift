import Foundation
import SwiftData

/// Copies the bundled licensed demo clip into owned storage through the *normal*
/// video-import path and finishes insertion through `VideoImportPersistence`.
/// There is deliberately no parallel model-insertion path here.
///
/// Demo content is excluded from free-video counts, free-style claims, legacy
/// grandfathering, and library exports (see `Video.isDemo` and its callers). It
/// is deletable like any other video.
enum OnboardingDemoIngestion {
    /// Stable identifier for the bundled asset. Used for dedupe so an
    /// interrupted-and-restarted onboarding never ingests the demo twice.
    static let bundledSourceID = "com.nopalstudio.five67.onboarding.demo.v1"

    static let resourceName = "OnboardingDemo"
    static let resourceExtension = "mp4"

    /// Shown in the library so the clip reads unambiguously as sample content.
    static let displayName = "Demo class clip"

    /// The demo's accurate dance style, preassigned on ingest. Applied *without*
    /// calling `UnlockStore.recordStyleUse`, so the demo never claims the user's
    /// one free style.
    ///
    /// - Note: Confirm against the licensed asset when it lands (see the plan's
    ///   "Assumptions and Required Inputs"). Adrian supplies the style label.
    static let styleID = Style.Default.salsa

    enum IngestionError: LocalizedError {
        case assetMissing

        var errorDescription: String? {
            switch self {
            case .assetMissing:
                "The demo video isn't available in this build."
            }
        }
    }

    /// Nil until the licensed `OnboardingDemo.mp4` is added to the app target.
    static var bundledURL: URL? {
        Bundle.main.url(forResource: resourceName, withExtension: resourceExtension)
    }

    static var isAvailable: Bool { bundledURL != nil }

    /// Returns the already-ingested demo row if present, otherwise copies the
    /// bundled asset into storage and inserts it. Never inserts a duplicate.
    @MainActor
    @discardableResult
    static func ingest(in context: ModelContext) async throws -> Video {
        if let existing = existingDemo(in: context) { return existing }
        guard let bundledURL else { throw IngestionError.assetMissing }

        let result = try await VideoImporter.import(
            fromFileURL: bundledURL,
            sourceID: bundledSourceID
        )
        let video = VideoImportPersistence.insertVideo(
            from: result,
            in: context,
            isDemo: true
        )
        video.displayName = displayName
        video.style = demoStyle(in: context)
        return video
    }

    /// Dedupe lookup. Matches on the persistent demo marker first, falling back
    /// to the stable bundled source ID for rows written before the marker existed.
    static func existingDemo(in context: ModelContext) -> Video? {
        let sourceID = bundledSourceID
        let descriptor = FetchDescriptor<Video>(
            predicate: #Predicate { $0.isDemo || $0.sourceAssetID == sourceID }
        )
        return try? context.fetch(descriptor).first
    }

    private static func demoStyle(in context: ModelContext) -> Style? {
        let id = styleID
        let descriptor = FetchDescriptor<Style>(predicate: #Predicate { $0.id == id })
        if let existing = try? context.fetch(descriptor).first { return existing }
        return Style.seedDefaultsIfNeeded(in: context).first { $0.id == id }
    }
}
