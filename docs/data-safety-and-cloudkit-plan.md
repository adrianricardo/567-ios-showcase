# Data Safety & CloudKit Sync — Planning Document

> Captures the reasoning trail behind the v1.0 data-safety scope. Companion document: [`v1-spec.md`](./v1-spec.md) (implementation contract).

**Date:** 2026-05-19
**Status:** Decision recorded — scope locked for v1.0; CloudKit work deferred to v1.1+
**Last reviewed by:** Codex (`/codex:rescue`, session `019e41a7-8cf3-7003-b975-3f7a8bc47faf`) + local `swiftdata` and `app-store-review` skills

---

## Starting question

> "Are the videos and moves I save on the app I've built to my iPhone safe? Or not safe until I publish the app? I want to start using the app but will likely keep iterating."

The user wants to start using Cumbia Moves for real personal data (dance practice videos + move annotations) while continuing to iterate on the code. Eventual goal: App Store submission. Question is whether data created during the iteration phase is durable enough to trust.

---

## What we learned

### Where data actually lives today

| Layer | Location | Code reference |
|---|---|---|
| Video files | `Documents/videos/<uuid>.mov` (app sandbox) | `Services/VideoImporter.swift:48` |
| Move + Video metadata | SwiftData store in `Application Support/default.store` | `App/CumbiaMovesApp.swift` |
| Photos asset linkage | `Video.sourceAssetID` (optional `PHAsset.localIdentifier`) | `Models/Video.swift:8` |

**Key property:** the local video file at `Documents/videos/<uuid>.mov` is *independent* of the Photos library after import. Deleting from Photos does not break in-app playback.

### What's safe today

- Xcode "Run" replaces the binary but does not delete the app sandbox → data persists across iteration.
- iCloud Backup (when the user has it enabled) includes both `Documents/` and `Application Support/` → data survives full-phone restore.
- Free-account provisioning expires every 7 days; re-signing via Xcode preserves data.

### What's *not* safe today — the silent-wipe foot-gun

`App/CumbiaMovesApp.swift:18-30` currently catches **any** `ModelContainer` load failure, deletes `default.store{,-shm,-wal}` from Application Support, and retries with an empty store.

**Impact:** if a schema change ever fails to migrate cleanly, every `Move` and `Video` row is silently destroyed. Video files on disk survive but become orphans (nothing references them). The user sees a clean app and assumes everything is fine — there is no error, no log shown to the user, no opportunity to recover.

This was acceptable as a dev-mode behavior on an empty database. It is not acceptable once any real annotations exist.

### What other safety gaps exist

1. **No app-level export.** If iCloud Backup is off and the phone is lost or the app is deleted, all annotations are gone with no recovery path.
2. **No multi-device sync.** iPhone-only experience; an iPad install starts empty.
3. **No app-store-grade privacy manifest.** `PrivacyInfo.xcprivacy` is required when touching certain APIs (file timestamps, UserDefaults, etc.). `Services/VideoImporter.swift` uses `FileManager` operations that hit the file-timestamp required-reason category.
4. **Unjustified background mode.** `Info.plist:32-35` declares `UIBackgroundModes: audio` but the app does not implement background audio playback. App Store review flags unused background modes (Guideline 2.5.4, confirmed by `app-store-review` skill: *"Each mode must be justified and actively used."*).

---

## The CloudKit fork — what we considered and rejected for v1.0

### The temptation: ship CloudKit-compatible schema in v1.0

Initial proposal: do a one-time schema refactor in v1.0 to make models CloudKit-compatible (drop `@Attribute(.unique)`, make all properties optional or defaulted, add explicit inverses, add `SchemaV3` migration). Claim: this would let v1.1 turn on sync with a single-line `ModelConfiguration(cloudKitDatabase: .private(...))` change.

### Why we rejected it (Codex pressure-test + skill cross-check)

Codex's adversarial review (verbatim output preserved in conversation history) plus cross-check against the local `swiftdata` skill confirmed:

1. **The schema refactor is necessary but nowhere near sufficient.** Real v1.1 work that the refactor does *not* address:
   - **File sync.** SwiftData+CloudKit syncs `localFilename` strings but not the bytes at `Documents/videos/<uuid>.mov`. A second device receives Move/Video records pointing to missing files. Solving this needs an iCloud Documents ubiquity container (with `NSFileCoordinator`, availability handling) or `CKAsset` storage — neither is a flag flip.
   - **Duplicate detection on second-device sign-in.** Current import dedupes only by `PhotosPickerItem.itemIdentifier` against local `existingSourceIDs` (`Services/VideoImporter.swift:29`). With CloudKit, two devices importing the same video pre-sync produce two `Video` rows that survive (because we dropped `.unique`).
   - **Delete semantics.** `Video.moves` cascade-deletes locally; under CloudKit, deletes propagate asynchronously and need an explicit product decision when a deleted video, its orphan moves, and the file all need to be reconciled.
   - **Conflict resolution.** `Move.updatedAt` exists but no merge policy is defined for concurrent edits to `name`, `status`, `time`, `endTime`, `notes`, `isExcluded`.
   - **CloudKit dev-schema initialization + production promotion** is a manual deploy step, not a runtime flag.

2. **The "make all properties optional" requirement is invasive.** The `swiftdata` skill confirms CloudKit requires *optional or defaulted* attributes (not strictly optional). Many of our scalars — `Video.displayName`, `Video.localFilename`, `Video.duration`, `Move.name`, `Move.time` — are reasonable to keep non-optional in the local model. Adding defaults to satisfy a future CloudKit move pollutes the local API now for no current benefit.

3. **The only justification for doing the refactor pre-launch was the "one-line v1.1 flip" claim.** Since that claim is false, the schema work belongs *with* the v1.1 sync design, not separated from it.

**Conclusion:** keep `@Attribute(.unique)`, keep non-optional scalars, leave the schema as-is for v1.0. Design the CloudKit-compatible schema as part of v1.1 — atomically with file sync, duplicate detection, deletes, and conflicts.

---

## Decision summary

**v1.0 scope (what we ship before App Store):**

1. Replace the silent wipe with a real error screen.
2. Add an Export action (zip videos + JSON of moves to Files).
3. Add `PrivacyInfo.xcprivacy` with file-timestamp reason code.
4. Remove `audio` from `UIBackgroundModes` in `Info.plist`.
5. Add an integrity check inside Export (orphan files; rows with missing files).

**Deferred to v1.1+ (designed together, not piecemeal):**

- SwiftData schema refactor for CloudKit compatibility (drop uniqueness, optionalize relationships, add explicit inverses, `SchemaV3`).
- CloudKit private database enablement.
- iCloud Documents ubiquity container for `Documents/videos/` (or `CKAsset` alternative).
- Duplicate-import detection across devices.
- Delete propagation + conflict resolution policy.
- CloudKit entitlement + container setup in Xcode project.
- iCloud capability in Info.plist.

**Explicit non-goals (not even v1.1):**

- Multi-user / sharing moves with other dancers.
- Web view of dance library.
- Android / cross-platform sync.

---

## User-facing scope comparison

| Capability | v1.0 | v1.1+ |
|---|:---:|:---:|
| Import videos from Photos | ✅ | ✅ |
| Annotate moves (name, range, category, status, notes, exclude) | ✅ | ✅ |
| Trim timeline + thumbnails + scrubbing | ✅ | ✅ |
| Data survives Xcode rebuilds + TestFlight updates | ✅ | ✅ |
| Migration failure shows an error screen, doesn't silently wipe | ✅ (new) | ✅ |
| Export to Files (zip of videos + JSON) | ✅ (new) | ✅ |
| Data survives iCloud Backup → new phone restore | ✅ (passive) | ✅ (passive) |
| Cross-device sync (iPhone ↔ iPad ↔ Mac) | ❌ | ✅ |
| App-level cloud backup independent of phone backup | ❌ | ✅ |
| Lost phone, no phone backup → recover annotations on new phone | ❌ | ✅ |
| Schema CloudKit-compat refactor | ❌ (deferred) | ✅ |
| Duplicate-import detection across devices | n/a | ✅ |
| Delete propagation + conflict resolution | n/a | ✅ |

**For a personal-use-first iPhone-only app, v1.0 is sufficient.** The user is one person on one device; cross-device sync is the headline feature of v1.1 but not a daily blocker for v1.0.

---

## References & sources

- Codex adversarial review: session `019e41a7-8cf3-7003-b975-3f7a8bc47faf`, completed 2026-05-19 (full transcript preserved in chat history).
- Local skill: `swiftdata` (verifies CloudKit model constraints; common-mistake #10 and #11; review checklist).
- Local skill: `app-store-review` (verifies background-mode and privacy-manifest claims; Guideline 2.5.4 wording).
- Apple — [Syncing model data across a person's devices](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices).
- Apple — [`ModelConfiguration.CloudKitDatabase`](https://developer.apple.com/documentation/swiftdata/modelconfiguration/cloudkitdatabase-swift.struct).

---

## Open questions for v1.1 design (capture for later — do not act on now)

- Does v1.1 sync the trimmed/derived video bytes, or rely on each device having Photos access to re-resolve from `sourceAssetID`?
- If `sourceAssetID` is dead on a new device (user deleted from Photos), do we show "video unavailable" or fall back to a synced local copy?
- Conflict policy on `Move` edits: last-writer-wins by `updatedAt`, or per-field merge?
- Do we keep `Documents/videos/` as the canonical location and just put it in the ubiquity container, or restructure?
- How does the Export format from v1.0 evolve once CloudKit owns the source of truth?
