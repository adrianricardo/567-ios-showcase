# v1.0 Data-Safety Spec — Implementation Contract

> Companion to [`data-safety-and-cloudkit-plan.md`](./data-safety-and-cloudkit-plan.md) (decision rationale). This document defines *what* to build for v1.0; the plan document explains *why*.

**Date:** 2026-05-19
**Target:** First App Store submission of Cumbia Moves.
**Out of scope:** CloudKit sync, schema refactor, multi-device — all deferred to v1.1+ and designed together. See plan doc §"Decision summary."

---

## Items at a glance

| # | Item | Effort | Risk if skipped |
|---|---|:---:|---|
| 1 | Remove `audio` from `UIBackgroundModes` | XS | App Store rejection (Guideline 2.5.4) |
| 2 | Replace silent-wipe with error screen | S | Silent data loss for real users |
| 3 | Add `PrivacyInfo.xcprivacy` | S | App Store rejection (Guideline 5.1.1) |
| 4 | Add Export-to-Files action | M | No recovery path if iCloud Backup is off |
| 5 | Integrity check inside Export | S | Orphan files + missing-file rows go unnoticed |

**Recommended build order:** 1 → 2 → 3 → 4 (with 5 folded into 4).

---

## 1. Remove unused `audio` background mode

**Motivation:** `Info.plist:32-35` declares `UIBackgroundModes: audio`, but the app does not implement background audio session activation. App Store review rejects unjustified background entitlements (Guideline 2.5.4, confirmed by `app-store-review` skill).

**Files affected:**
- `CumbiaMoves/Resources/Info.plist`

**Acceptance criteria:**
- [ ] `UIBackgroundModes` key and its `<array>` are removed from `Info.plist`.
- [ ] App still launches, plays video in foreground, and behaves correctly when backgrounded (player pauses, which is the desired behavior anyway).
- [ ] No regression in Now Playing or AVPlayer behavior.

**Approach:** Delete lines 32-35 of `Info.plist`. No code changes elsewhere.

**Test plan:**
- Launch app, import a video, start playback.
- Background the app (home gesture). Confirm playback pauses cleanly.
- Foreground again; confirm playback can resume from where it paused.

**Rollback:** Trivial — revert the Info.plist change.

---

## 2. Replace silent-wipe-on-migration-failure with a real error surface

**Motivation:** `App/CumbiaMovesApp.swift:18-30` currently catches any `ModelContainer` load failure, deletes the SwiftData store files, and retries with an empty database. This destroys user data with no warning and orphans the video files in `Documents/videos/`.

**Files affected:**
- `CumbiaMoves/App/CumbiaMovesApp.swift`
- New: `CumbiaMoves/Views/Root/MigrationFailureView.swift` (error screen)

**Acceptance criteria:**
- [ ] `ModelContainer` initialization no longer wipes the store on failure.
- [ ] On `ModelContainer` init failure, the app shows a full-screen error view containing:
  - Clear failure title (e.g., "Couldn't open your library").
  - The underlying error description.
  - Action: "Export current data" — copies the raw `default.store{,-shm,-wal}` files + `Documents/videos/` contents to a user-selected Files location (best-effort; works even when models are unreadable).
  - Action: "Reset library" — explicit, confirmation-gated; wipes the store *only* if the user confirms.
  - Action: "Contact support" — opens a mailto with the error attached.
- [ ] No code path silently deletes `default.store*`.
- [ ] Existing successful-launch behavior is unchanged.

**Approach:**
1. Refactor `CumbiaMovesApp` to store an optional `Result<ModelContainer, Error>` instead of force-initializing.
2. In `body`, branch on the result: success → normal `WindowGroup` with `.modelContainer`; failure → `MigrationFailureView` in a `WindowGroup`.
3. Remove `wipeDefaultStore()` from the init path. Keep the function but call it only from the explicit "Reset library" action.
4. `MigrationFailureView` exposes the three actions above. "Export current data" uses `UIDocumentPickerViewController` (or `fileExporter` modifier) to let the user pick a destination, then copies the raw files there.

**Test plan:**
- Happy path: app launches normally with existing data → no behavior change.
- Failure path simulation: temporarily corrupt the store file (`xxd /path/to/default.store | head -c 100 > corrupted; cp corrupted ...`) → confirm error view shows with the actual error.
- Export action: confirm files land at the chosen Files location and can be inspected.
- Reset library: confirm it only runs after the confirmation dialog and that the app recovers cleanly on next launch.

**Rollback:** Revert `CumbiaMovesApp.swift` to the prior init pattern. Delete `MigrationFailureView.swift`.

---

## 3. Add `PrivacyInfo.xcprivacy` privacy manifest

**Motivation:** Required for App Store submission when the app touches "required reason" APIs. `Services/VideoImporter.swift` uses `FileManager` operations that hit the file-timestamp category. Skill (`app-store-review`) confirms: *"File timestamp, system boot time, disk space, user defaults, and active keyboard APIs all require reason codes."*

**Files affected:**
- New: `CumbiaMoves/Resources/PrivacyInfo.xcprivacy`
- Possibly: `project.yml` (ensure the file is included in the Resources build phase via xcodegen)

**Acceptance criteria:**
- [ ] `PrivacyInfo.xcprivacy` exists at `CumbiaMoves/Resources/PrivacyInfo.xcprivacy` and is included in the app target's Resources.
- [ ] Manifest declares:
  - `NSPrivacyAccessedAPICategoryFileTimestamp` with reason code `C617.1` (Files within the app container).
  - `NSPrivacyAccessedAPICategoryDiskSpace` only if we actually query disk space (audit first; likely not needed).
  - `NSPrivacyTracking: false` (we don't track users).
  - `NSPrivacyTrackingDomains: []` (none).
  - `NSPrivacyCollectedDataTypes: []` (no data collected by the first-party app; the only data leaving the device is what the user explicitly exports).
- [ ] xcodebuild succeeds; archive contains the manifest in the .app bundle.

**Approach:**
1. Audit `Services/VideoImporter.swift`, `Services/PlaybackController.swift`, `Services/VideoMetadata.swift`, `Services/ThumbnailService.swift` for required-reason API usage. Document each usage and its category.
2. Write the plist with the minimum-viable entries based on the audit.
3. Update `project.yml` if needed so xcodegen wires the file into the bundle.

**Test plan:**
- Build & archive locally; inspect the .app bundle for `PrivacyInfo.xcprivacy` in `Contents/Resources/`.
- Upload a TestFlight build; confirm App Store Connect's "Privacy" section doesn't flag anything missing.

**Rollback:** Delete the file from Resources.

**Note:** This manifest is for first-party code only. If we add any third-party SDKs later, each one must ship its own manifest (skill: *"Every third-party SDK must ship its own privacy manifest."*).

---

## 4. Add Export-to-Files action (with integrity check — item 5 folded in)

**Motivation:** Without app-level export, a user who has iCloud Backup off (or who deletes the app) has no recovery path. Export is also a cheap belt-and-braces backup before any risky operation.

**Files affected:**
- New: `CumbiaMoves/Services/LibraryExporter.swift`
- New or modified: a UI entry point (likely a button in `LibraryView` or a settings screen — TBD during implementation).

**Acceptance criteria:**
- [ ] User can trigger "Export Library" from a clearly-discoverable location in the app.
- [ ] Export produces a single `.zip` file at a user-chosen Files location, containing:
  - All `.mov` files from `Documents/videos/`.
  - A `library.json` with all `Video` and `Move` rows (Codable-encoded, including all fields, ISO-8601 dates, embedded `sourceAssetID`).
  - A `manifest.json` with: app version, export date, schema version, counts (videos, moves), and an integrity report (see below).
- [ ] **Integrity report** (item 5):
  - List of `Video` rows whose `fileURL` resolves to a missing file ("missing files").
  - List of `.mov` files in `Documents/videos/` not referenced by any `Video.localFilename` ("orphan files").
  - List of `Move` rows with `video == nil` ("orphan moves").
  - All four counts are also shown in the export-completed UI alert so the user notices without opening the zip.
- [ ] Export runs off the main actor (uses `@ModelActor` or background task pattern from the `swiftdata` skill); UI shows a progress indicator and is not frozen.
- [ ] Export completes in reasonable time on a library of 10 videos / 100 moves (target: < 30s for the JSON portion; zip time is dominated by file copy size).
- [ ] Failure modes (disk full, user cancels picker, file copy error) surface a non-fatal error and leave existing data untouched.

**Approach:**
1. Define export-side Codable DTOs for `Video` and `Move` (decoupled from the @Model classes so we can evolve the schema without breaking exports). Date strategy: ISO-8601. Enum strategy: raw string.
2. Implement `LibraryExporter` as an `actor` (or `@ModelActor`) that:
   - Fetches all `Video` and `Move` rows via `FetchDescriptor`.
   - Builds the integrity report by cross-referencing `FileManager.contentsOfDirectory(at: Documents/videos)` against `Video.localFilename` values.
   - Writes `library.json` + `manifest.json` to a temp directory.
   - Copies `.mov` files into the temp directory.
   - Zips the temp directory to the user-selected destination.
3. UI entry point: a button in `LibraryView` toolbar (most discoverable). Tapping opens a `fileExporter` (or `UIDocumentPicker`) for destination selection.
4. After completion, show a sheet with: success message, file location, and the four integrity counts. If any counts are nonzero, the message offers a "Show details" expansion.

**Test plan:**
- Empty library: export produces a zip with empty arrays and zero counts.
- Typical library (5 videos, 30 moves): export succeeds, zip extracts cleanly, all moves present in JSON with correct `videoID` references.
- Inject an orphan: manually copy a `.mov` into `Documents/videos/` without inserting a `Video` row → export's integrity report lists it.
- Inject a missing file: insert a `Video` row pointing to a nonexistent filename → integrity report lists it.
- Cancel the destination picker mid-flow → no partial files left in temp; no crash.
- Disk-full simulation (e.g., export to a tiny-volume external drive) → error surfaces, app unchanged.
- Background interruption: trigger export, background the app, return → export resumes or fails cleanly.

**Rollback:** Remove `LibraryExporter.swift` and the UI entry point.

**Open implementation questions:**
- Zip implementation: use `Foundation`'s built-in `Archive` API (iOS 26+), or fall back to `NSFileCoordinator.coordinate(writingItemAt:options:.forReplacing)` with a directory and let the user zip externally? Decide during implementation.
- Should the export include thumbnails (`Caches/thumbs/`)? Probably no — they're cacheable and bloat the export. Worth confirming.

---

## Out-of-scope reminders

These items are **explicitly deferred to v1.1+** and should not creep into v1.0:

- ❌ Drop `@Attribute(.unique)` on `Video.id` / `Move.id`.
- ❌ Make `Video.moves` optional / declare explicit `inverse:`.
- ❌ Add `SchemaV3`.
- ❌ Enable CloudKit on `ModelConfiguration`.
- ❌ Add iCloud entitlement / container.
- ❌ Move `Documents/videos/` into a ubiquity container.
- ❌ Multi-device duplicate detection.
- ❌ Conflict-resolution policy for `Move` edits.

If any of these become tempting during v1.0 implementation, stop and reconsider scope — they belong with the v1.1 sync design as a coherent unit. See plan doc §"Why we rejected it" for the reasoning.

---

## Done definition for v1.0

- [ ] All five spec items meet their acceptance criteria.
- [ ] App archives clean in Release configuration with zero warnings.
- [ ] TestFlight internal build installed; happy-path flow verified on real device.
- [ ] One full export → wipe → restore cycle tested manually to verify recovery works.
- [ ] App Store Connect privacy nutrition labels filled out, consistent with `PrivacyInfo.xcprivacy`.
- [ ] App Store Connect demo credentials field filled out (even though there's no login — note "no login required; sample video included on first launch" if relevant).
- [ ] Submitted for App Review.
