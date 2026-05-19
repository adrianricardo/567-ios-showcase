# v1.0 Implementation Notes

Running log of decisions, deviations, and tradeoffs made while implementing [`v1-spec.md`](./v1-spec.md). Update as work proceeds.

**Started:** 2026-05-19

---

## Item 1: Remove `audio` from `UIBackgroundModes`

**Done.**

- Removed `UIBackgroundModes: [audio]` from both `project.yml` (the xcodegen source of truth) and `CumbiaMoves/Resources/Info.plist` (the materialized file that's currently in the repo). Without doing both, the next `xcodegen generate` would either re-introduce it or — depending on Info.plist merge behavior — leave Info.plist drifted from project.yml.
- **Kept the `AVAudioSession.setCategory(.playback)` call in `PlaybackController.prepareAudioSession()`** even though it's the category typically associated with background audio. In the foreground it's still the correct choice: it ensures video audio plays even when the ringer/silent switch is on, which is the user expectation for a video playback app. Without the background mode entitlement, the system will pause AVPlayer automatically when the app backgrounds — which matches the spec's acceptance criterion ("player pauses, which is the desired behavior anyway").
- Did **not** add an explicit "pause on background" handler. Relying on AVPlayer's default behavior; if QA finds the audio session lingers and creates "stuck audio" symptoms, we'll revisit.

---

## Item 2: Replace silent-wipe-on-migration-failure with a real error surface

**Done.**

- `CumbiaMovesApp` now stores `Result<ModelContainer, Error>` in `@State` and branches the `WindowGroup` between `RootView` (success) and `MigrationFailureView` (failure). The "Reset library" action calls `wipeDefaultStore()` and then retries the load by reassigning `loadResult`. **No silent wipe path remains.**
- "Export current data" implementation choice: rather than wrestling with `UIDocumentPickerViewController` for a folder destination from within SwiftUI, I used SwiftUI's `fileExporter(... contentType: .folder, ...)` with a custom `FileDocument` (`RawStoreExportDocument`) that wraps a temporary directory and returns a `FileWrapper(url:)`. The bundle includes:
  - `store/default.store(-shm|-wal)?` (raw SQLite files copied out of Application Support so the user can inspect them even when SwiftData cannot)
  - `videos/` (the contents of `Documents/videos/`, copied wholesale)
  - `README.txt` explaining the layout.
  This is *deliberately* raw rather than the JSON+zip used by item 4: when the model layer is broken, we cannot trust `FetchDescriptor`. The recovery bundle preserves what's on disk, exactly as it is. The user can still try the normal export from item 4 after they pick "Reset library" and the load fails again — but that path needs a working `ModelContainer`, so raw-files-only is the right fallback here.
- "Contact support" uses a `mailto:` URL with the error in the body. The address is a placeholder (`support@cumbiamoves.app`) — **TODO**: replace with the real support address before submission.
- The reset confirmation dialog explicitly tells the user that the `Documents/videos/` directory is *not* touched by reset. We only wipe the SwiftData store. This is consistent with the existing `wipeDefaultStore()` behavior and avoids losing the actual video bytes when the user is hoping a database reset will recover them.
- The error description is rendered via `String(describing: error)` (rather than `error.localizedDescription`) because SwiftData/CoreData errors frequently have empty/uselessly-vague localized descriptions but rich `description` output that includes the underlying NSError userInfo.
- I considered making the export an async operation with a progress view, but kept it synchronous: even for a large library the file copies are I/O-bound and on first-launch failure the user has nothing else to wait for. If this turns out to be janky on real devices with multi-GB libraries we can revisit.

---

## Item 3: Add `PrivacyInfo.xcprivacy` privacy manifest

**Done.**

### API audit results

Grepped the codebase for the required-reason API call sites Apple enumerates:

| API category | Found in code? | Notes |
|---|---|---|
| File timestamp (`attributesOfItem`, `modificationDate`, `creationDate`, `getattrlist`, `stat`, etc.) | **Not explicitly.** `FileManager.copyItem`/`removeItem` are used but don't directly read timestamps; `AVAsset.load(.creationDate)` reads asset metadata, not the file's POSIX timestamp. | Declared anyway with reason `C617.1` per the spec ("Files within the app container"). Conservative — the cost of an extra entry is zero and Apple reviewers can be inconsistent. |
| Disk space (`volumeAvailableCapacityKey`, `systemFreeSize`, `statfs`, …) | **No.** `PlaybackController` uses `url.resourceValues(forKeys: [.fileSizeKey])` — that's per-file size, *not* a volume capacity query, so it does not fall under this category. | Not declared. |
| User defaults | **No.** No `UserDefaults` / `@AppStorage` usage. | Not declared. |
| Active keyboards | **No.** | Not declared. |
| System boot time | **No.** | Not declared. |

### Manifest contents

- `NSPrivacyTracking: false`
- `NSPrivacyTrackingDomains: []`
- `NSPrivacyCollectedDataTypes: []` — the app collects nothing first-party. The library export (item 4) is user-initiated and writes to a location the user picks; it is not "collection" in Apple's sense.
- `NSPrivacyAccessedAPITypes`: one entry for `NSPrivacyAccessedAPICategoryFileTimestamp` with reason `C617.1`.

### Wiring

- Added `CumbiaMoves/Resources/PrivacyInfo.xcprivacy` to the `resources:` list in `project.yml` so xcodegen wires it into the app bundle's Resources phase.
- After `xcodegen generate`, this will appear in the .app bundle at `PrivacyInfo.xcprivacy` (no `Contents/Resources/` subpath on iOS — iOS bundles are flat).
- If we later add a third-party SDK, each will need its own privacy manifest; this manifest covers first-party code only.

---

## Item 4 + 5: Library export with integrity check

**Done.**

### Zip strategy

The spec's open question: `Foundation.Archive` (iOS 26+) vs. `NSFileCoordinator` fallback. Deployment target is **iOS 18** (`project.yml`), so the new Foundation API is unavailable. **Picked `NSFileCoordinator.coordinate(readingItemAt: .forUploading)`** — this is the long-standing documented technique for getting a zipped representation of a directory and works back to iOS 8. Result is a real `.zip` recognized by Finder/Files. Downside: the coordinator's callback block hands you a temp URL that only lives for the duration of the callback, so we `copyItem` it out into our own temp location before returning. The `DispatchSemaphore` is belt-and-braces since the documented call is synchronous for local URLs.

### `@ModelActor` design

- `LibraryExporter` is a `@ModelActor` actor, instantiated from the view with `LibraryExporter(modelContainer: modelContext.container)`. Per the `swiftdata` skill, this is the standard pattern for off-main-thread fetches that don't need to interact with view state.
- Fetched all `Video` and `Move` rows via `FetchDescriptor`. No cursor-style pagination — for a library size in the dozens, this is fine. If we ever hit thousands of moves, we'd want batching.
- Note that `modelContext.save()` is called from the **calling view** before constructing the actor. This flushes any unsaved edits so the export reflects the user's latest state. Otherwise an unsaved rename could be missing from a "just exported" snapshot.

### DTO decoupling

- Built `VideoDTO` / `MoveDTO` separate from the `@Model` classes. This is a deliberate hedge for v1.1+: when we change the SwiftData schema (drop `@Attribute(.unique)`, add `inverse:`, etc., per the plan doc), the export *format* shouldn't move with it. Old exports stay valid; new exports keep the same shape.
- Enum encoding: raw string (`category.rawValue`, `status.rawValue`). Not raw int — strings are human-readable in the JSON and survive enum case renames more gracefully (we can map old strings to new cases in a future importer).
- Date encoding: ISO-8601 via `JSONEncoder.dateEncodingStrategy = .iso8601`.
- `MoveDTO.videoID` captures the relationship by ID. If the `Move.video` relationship is nil, `videoID` is nil — and the integrity report counts those as orphan moves.

### Integrity report

Three counts (per the spec's item 5):

| Field | Definition |
|---|---|
| `missingFiles` | `Video.localFilename` values whose file is absent from `Documents/videos/`. |
| `orphanFiles` | `.mov`-style files on disk not referenced by any `Video.localFilename`. |
| `orphanMoveCount` | `Move` rows whose `video` relationship is nil. |

All three are surfaced in the post-export sheet, with a `DisclosureGroup` for the file lists. Counts are also included in `manifest.json` so a power user inspecting the zip externally sees the same data.

### UI entry point

- Placed in `LibraryView` toolbar, inside a `Menu` at `.topBarLeading` (using `ellipsis.circle`). Reasoning: the `+` import button owns `.primaryAction`; adding a sibling button there would clutter the most-tapped placement. A menu leaves room to add future actions (Import from Files, Diagnostics, etc.) without redesign. Also makes the action feel "less risky" — exposed via menu rather than as a top-level icon.
- Progress: while exporting, the menu's icon swaps to a `ProgressView`. The button is disabled to prevent re-entry. The UI is not frozen because the work happens on `LibraryExporter` (off-main).
- Completion flow: `fileExporter` for the zip destination → on success, present `ExportSummarySheet` with counts and integrity details. On user cancel, no error is shown (matches user expectation; we filter on `NSUserCancelledError`).

### What I did *not* include in the export

- **Thumbnails (`Caches/thumbs/`)**: skipped per the spec's open question — they're regenerable, would bloat the export, and would invalidate the moment a video is edited.
- **Application Support raw store files**: skipped intentionally. Those are the SwiftData-internal SQLite files; including them in the user-facing export would be confusing (two copies of the data, one of which is opaque). The migration-failure path (item 2) is the right place to ship raw store files — that's specifically when the JSON representation can't be trusted.

### Known gaps / things I did not verify

- **Did not run the app on a simulator end-to-end** in this session. The Xcode build (Debug *and* Release for iOS Simulator) succeeds, but I have not visually confirmed the new UI (export menu, summary sheet, migration error view). Recommend a manual pass before TestFlight.
- **Pre-existing Swift 6 concurrency warning** in `LibraryView.swift` for the `isImporting` read inside `PhotosPicker`'s `@Sendable` label closure: **fixed** by extracting an `ImportPickerButton` subview. Pushing the state read into a normal `View.body` (which is `@MainActor`) clears the warning without `@preconcurrency` hacks. Release build is now warning-free.
- **Disk-full simulation, NSFileCoordinator with multi-GB libraries, and the 60-second semaphore timeout** are untested. For typical practice-video sizes this should be fine.
- **Support email address**: set to `567@agentmail.to`.

---

## Verification

- `xcodegen generate` ✅
- `xcodebuild ... -configuration Debug build` ✅ build succeeds, app bundle contains `PrivacyInfo.xcprivacy`.
- `xcodebuild ... -configuration Release build` ✅ same warnings as Debug; 2 pre-existing `isImporting` Sendable warnings (see Item 4 notes), no new warnings.

### Not verified in this session

- App not booted on simulator or device.
- No manual export → wipe → restore round-trip executed.
- No TestFlight build cut.
- App Store Connect privacy nutrition labels not filled out (manual step in App Store Connect).

These are part of the spec's "Done definition for v1.0" but are outside what I can do from the local toolchain without launching the app interactively — flagged as follow-up.
