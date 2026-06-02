# Five67 Data Durability Posture

How user data survives TestFlight → launch → ongoing schema migrations on an on-device-only app.

Last updated: 2026-05-27

---

## Durability philosophy

**Piggyback on the user's existing phone-backup hygiene. We do not run our own backup infrastructure.**

The premise: the categories of event that destroy Five67's data — device loss, theft, hardware failure, factory reset — are the same categories that destroy everything else on the user's phone. Users already have a strategy for those (iCloud Backup, encrypted Finder/iTunes backup, or accepting the risk). The same mechanism that restores their photos, messages, and Notes also restores Five67. We piggyback on it; we don't replicate it.

The library export (Style picker → "Export Library") is a **belt** for users without whole-phone backup — turned-off-iCloud-Backup, low-quota, privacy-conscious. We surface it but cannot rely on adoption; most users will never tap it.

### Known gaps in this philosophy

We accept these gaps for v1 because closing any of them is its own engineering project, not a small fix:

1. **Migration / store corruption is not a whole-phone event.** A corrupted SwiftData store gets backed up corrupted; restoring from iCloud Backup restores the corruption. `MigrationFailureView` mitigates this with a **raw-store export** path (`RawStoreExport.buildBundle` at `Five67/Views/Root/MigrationFailureView.swift:167`) — copies the SQLite files + `Documents/videos/` + a README into a recovery folder the user can save off-device. The header copy nudges them to export before resetting. **What this gives the user**: their video files are safely off the device, and the SQLite file is structurally recoverable by us via manual sqlite tooling + support intervention. **What it does not give**: in-app per-record salvage. Recovery requires the user to contact support and hand us the bundle. Future-work item: automatic in-app salvage of moves/names/timestamps from a degraded store.
2. **No-backup users have no safety net beyond the manual export.** Some meaningful (but unknown) portion of iPhone users have iCloud Backup off. For them, current durability = the export button, which we know will see low adoption. The v1.1 off-device durability design pass exists specifically to address this population.
3. **Long-gap reinstall.** iCloud Backup retention can roll off older device backups after extended periods without new ones. The "I deleted the app last year, want my data back" case has no recovery path.

### Why we accept these for v1

- Early-user population skews to people with iCloud Backup on (typical iPhone setup).
- The alternative — running our own cloud durability layer (iCloud Drive, CloudKit, custom backend) — is a meaningfully bigger commitment with edge cases worth a dedicated design pass. Deferred to v1.1 (see Decisions Log).
- The export feature exists as a low-cost safety valve for users motivated enough to use it.

---

## TL;DR

- **Backup posture: solid by default.** Videos live in `Documents/videos/`, the SwiftData store lives in `Application Support/`. Both are backed up by iCloud Backup. No `excludedFromBackup` flags. Locked in by `Five67Tests/BackupAuditTests.swift`.
- **Migration test harness: in place.** `Five67Tests/MigrationTests.swift` exercises every schema version against the live plan and locks in the working V4 paths.
- **Old V1/V2/V3 → V4 migration is broken, but irrelevant in practice.** No real users exist on any pre-V4 build (no testers had installed before V4 shipped). Every install going forward starts at V4 and never hits the broken stage. Tests document the bug via `withKnownIssue` for archaeological purposes only. See *V3→V4 footnote* below.
- **Library export is UI-exposed** via the Style picker footer (`StylePickerPaneView` → "Export Library" button). Two options surface: **Full Export (Videos + Metadata)** and **Metadata Only (No Videos)**. Both are user-initiated through the system share/save sheet, gated behind a confirmation dialog that warns about size.
- **CloudKit sync is deferred but kept as an option.** Current schema is mostly CloudKit-compatible (optionals, UUID identities, no required relationships) — flip it on later if/when desired.

---

## Where user data lives on disk

| Data | Location | Backed up by iCloud Backup? |
|------|----------|----------------------------|
| Video files | `Documents/videos/` | Yes (Documents is backed up) |
| SwiftData store (`default.store` + `-shm`, `-wal`) | `Application Support/` | Yes (Application Support is backed up; only `Caches/` and `tmp/` are not) |
| Thumbnails | (cache, not backed up — acceptable; regenerated from videos) | n/a |

Audit: see `Five67Tests/BackupAuditTests.swift`. Treat a failure there as a launch-blocker.

The user must have iCloud Backup turned on for this to actually protect them. There's no in-app indicator of that. **Implication:** the only real safety net for a non-iCloud-Backup user is the in-app export (Style picker → "Export Library"), which surfaces both Metadata-only and Full options.

---

## Migration testing policy

Every schema bump must:

1. Add the new versioned schema to `Five67/Models/SchemaMigrations.swift` (with the prior version inlined so its on-disk shape is frozen).
2. Add tests in `Five67Tests/MigrationTests.swift` that seed the new version at known shape and verify it lands cleanly at the new live schema.
3. Run `make test` and confirm green.

If a future schema makes the lightweight/custom split tricky again, the safe pattern is: **insert an intermediate "drop-only" schema** between the old and new, so the column-renaming/retyping problem is split into two lightweight steps. (See the V3→V4 case for what happens when you don't do this.)

---

## V3→V4 footnote — broken, but no users exposed

**Symptom in tests:** Any V1/V2/V3 store hitting the current live migration plan fails with `Cannot migrate store in-place: SQLite error code:1, 'duplicate column name: ZSTYLE'`.

**Why:** V3's `Video.style: DanceStyle?` (scalar) and V4's `Video.style: Style?` (relationship) both want a SQLite column named `ZSTYLE` with incompatible structure. `MigrationStage.custom` doesn't rebuild the store — it still relies on lightweight schema diffing, which can't reconcile the conflict.

**Why it doesn't matter:** No real users exist on V1, V2, or V3. The app didn't ship to anyone before V4. Every install — TestFlight or future App Store — starts at V4 from scratch and never runs migration code at all. V4 users updating to a future V5 build would run only V4→V5 and would skip V3→V4 entirely. So this stage is effectively dead code.

**Why keep the tests at all:** They're cheap, and they leave a clear paper trail. If anyone someday reaches back through git history to understand the schema lineage, the test output explains exactly what happened. They also exercise the V1/V2/V3 model definitions, which keeps them compiling cleanly even though no one will ever migrate through them.

**Tests:** V1→V4, V2→V4, and V3→V4 tests in `MigrationTests.swift` are wrapped in `withKnownIssue(...)` so the suite stays green and the failure stays visible in test output for any future reader.

---

## Recovery paths the user has today

1. **Device-level**: iCloud Backup restore on a new/wiped device brings back both the SwiftData store and the videos. Implicit; requires the user to have iCloud Backup on.
2. **Library export (Metadata or Full)**: `LibraryExporter` produces a zip — `Five67-Metadata-*.zip` (just `library.json` + `manifest.json`) or `Five67-Library-*.zip` (same metadata plus all video files). Triggered from the Style picker footer's "Export Library" button. The system save/share sheet handles where it lands.
3. **Raw-store recovery bundle for the store-corruption case**: `MigrationFailureView` shows three actions when the store fails to load — **"Export current data"** (primary), **"Contact support"**, **"Reset library"** (destructive, confirmation-dialog gated). The export path calls `RawStoreExport.buildBundle` (`Five67/Views/Root/MigrationFailureView.swift:167`), which copies the SwiftData SQLite files (`default.store`, `-shm`, `-wal`), the entire `Documents/videos/` directory, and a README into a folder the user saves via `fileExporter(contentType: .folder)`. The user's *video files* land safely off-device immediately; the SQLite file is recoverable by us via manual tooling. Cannot run `LibraryExporter` here because the SwiftData store didn't load — no `@Model` objects to serialize. No automatic in-app per-record salvage; recovery beyond the raw bundle requires support contact.

### Two exporters, two states — what each gives the user

There are two distinct export paths in the codebase. They run in different app states and produce different bundles. Knowing which is which is important for support conversations and for setting honest expectations.

| | `LibraryExporter` (healthy app) | `RawStoreExport` (migration failure) |
|---|---|---|
| Entry point | Style picker → "Export Library" footer | `MigrationFailureView` → "Export current data" |
| When it runs | SwiftData store loaded normally | SwiftData store failed to load |
| Videos included | Optional (Full vs Metadata-only dialog) | Always (entire `Documents/videos/`) |
| Metadata format | `library.json` + `manifest.json` (human-readable) | Raw `default.store` SQLite binary |
| Self-serve recovery? | Yes — user can read the JSON | No — needs sqlite tooling or our help |
| Why the difference | Can walk `@Model` objects and serialize them | Cannot instantiate `@Model` objects when the store won't load; only option is to copy the binary files off |

**The honest framing for users in the migration-failure case:** their *videos* are always safe — they're standard `.mov` files, usable immediately in any app. Their *moves and notes* are saved in the recovery bundle too, but getting them back into a usable form requires us extracting from the SQLite file via manual tooling. This is the gap that the future-work "in-app per-record salvage" item targets — automatic reconstruction from filename/EXIF metadata so users don't need a support round-trip for the common cases.

### Decision: surface both Metadata-only and Full export

The exporter has an `includeVideos: Bool = true` parameter and the UI exposes both paths via a confirmation dialog. Tradeoffs:

| Dimension | Metadata-only | Include videos |
|---|---|---|
| Recovery scope | Moves, names, timestamps, styles | Everything |
| File size | KB | GB (entire library) |
| Time to produce | Instant | Minutes |
| iOS share-sheet | Works cleanly | Hits AirDrop / email size limits |
| Where users store it | Anywhere (email, Notes, Drive) | Awkward — needs cloud storage |
| Frequency users would run it | Realistic — "save my catalog" | Rare — explicit "archive everything" |

iCloud Backup remains the realistic everyday videos-recovery path. Metadata-only is the cheap belt for non-iCloud-Backup users. Full export is available but user-initiated and the dialog warns about size; it is a fundamentally different risk class than automatic video upload (no quota surprise, no background uploads, no entitlement footprint).

---

## CloudKit sync — option held open

Not enabled. Schema is mostly compatible if/when we decide to turn it on:

- All `@Model` types use UUID identities ✓
- Relationships are to-one optional or to-many ✓ (CloudKit doesn't enforce required relationships)
- No `@Attribute(.unique)` enforcement reliance beyond IDs (CloudKit can't enforce uniqueness server-side, but UUIDs make collisions effectively impossible)

The thing to watch: if we ever add a NOT-NULL relationship, that locks out CloudKit later. Keep relationships optional.

To turn it on: change `ModelConfiguration()` in `Five67App.loadContainer()` to `ModelConfiguration(cloudKitDatabase: .private("iCloud.com.nopal.five67"))`, add the entitlement, add `NSUbiquitousContainers` to Info.plist. SwiftData handles the rest including CKAsset for video file sync.

### Cons of enabling CloudKit sync

The real reasons we haven't turned it on:

- **Schema constraints bake in at design time.** Everything must be optional, no server-side uniqueness, no required relationships. Retrofitting is painful — adding a NOT NULL relationship later locks out CloudKit forever.
- **Eventual consistency.** Changes propagate over seconds to minutes. You need conflict resolution logic (last-write-wins, or smarter), which is its own correctness surface.
- **iCloud quota.** Counts against the user's storage. Heavy-video users could fill their iCloud and silently stop syncing.
- **Privacy posture changes.** Data leaves the device. PrivacyInfo.xcprivacy may need updating. Some users explicitly prefer on-device-only — that promise breaks.
- **Outage dependence.** CloudKit goes down rarely but does; when it does, the app feels broken.
- **Debugging cost.** Sync bugs are async, multi-device, hard to reproduce, and Apple's CloudKit dashboard is bare-bones.
- **Testing cost.** Needs real CloudKit infrastructure or elaborate mocking — neither is fun.
- **Account complexity.** Signed-out users get no sync; multi-Apple-ID users get confused; family sharing has edge cases.
- **Migration cost when enabling later.** Existing on-device V4 stores need a one-time reconciliation with cloud state. Non-trivial; would need its own test harness.

Summary: CloudKit is a real product upgrade (data follows you across devices, survives device loss without iCloud Backup hygiene) but a meaningful complexity step. Keep the schema CloudKit-compatible to hold the option open, decide later.

---

## Open question: making backups automatic + protecting videos

Current posture relies on iCloud Backup, which means: if the user hasn't enabled it (or has it off), and they delete the source video from Photos after importing into Five67, the only copy lives in `Documents/videos/`. Lose the device or delete the app → videos are gone forever.

This is a real failure mode worth addressing before launch. The space of options:

### Failure mode we're trying to fix

User imports video → deletes the original from Photos to free space → device lost / app deleted / fresh install → no recovery path. Today: iCloud Backup catches this *if* the user has it on. Many users don't.

### Options

#### Option 1 — iCloud Drive ubiquity container (write app data to user's iCloud)

On import, after writing the video to `Documents/videos/`, also call `setUbiquitous(true, itemAt:, destinationURL:)` to mirror the file into the app's iCloud container. iOS handles upload in the background with retries, Wi-Fi-only support, and low-power-mode awareness. On fresh install, files appear as placeholders and download on first access (or pre-download).

- **Pros**: native, free, no backend; works for videos imported from Photos *and* Files; survives device loss + app deletion + no-iCloud-Backup; can also be used for the metadata JSON (one writer, two file types).
- **Cons**: requires iCloud Drive enabled (default on, but not universal); counts against user's iCloud quota; signs the app up as an iCloud-aware app (entitlement, container ID).
- **Cost**: ~1 day of work.

#### Option 2 — CloudKit + CKAsset (SwiftData-native sync)

`ModelConfiguration(cloudKitDatabase: .private("iCloud.com.nopal.five67"))`. SwiftData syncs the store; video files become CKAssets.

- **Pros**: gives multi-device sync as a free side benefit.
- **Cons**: all the CloudKit cons in the section above (eventual consistency, schema constraints, debugging cost, account complexity). Bigger surface to test. Overkill for a single-device-per-user app.
- **Cost**: multi-day.

#### Option 3 — Custom backend (S3 / R2 / Supabase Storage)

App uploads videos to our own cloud.

- **Pros**: full control; works for Android someday; not dependent on user's iCloud.
- **Cons**: **we pay the storage bill** at ~150 MB / minute of 1080p video; requires user accounts (auth + signup friction); privacy posture changes (we become data custodian); we own the ops (uptime, retention, GDPR/CCPA).
- **Cost**: weeks + ongoing. Wrong v1 move unless we've decided to be a multi-platform service.

#### Option 4 — Don't copy; reference PHAssets directly

For videos imported from Photos, store only `sourceAssetID` and stream from PHAsset. If the user has iCloud Photos on, the video is already backed up by Photos itself.

- **Pros**: zero storage cost in our container; genuinely seamless — Apple does the backup work; benefits from Photos features like cross-device sync.
- **Cons**: breaks for videos imported from Files.app; breaks if user deletes from Photos (same failure mode we're trying to fix, just one indirection away); big architectural change — trim/playback flows currently assume a local file URL.
- **Cost**: significant refactor of `VideoImporter`, `PlaybackController`, etc.

### The hard constraint: storage cost

Whichever cloud we pick, *somebody pays per GB*:

- 1 min of 1080p ≈ 150 MB
- 50 videos averaging 90 sec ≈ ~11 GB
- Free iCloud tier is 5 GB total (shared with Photos, Messages, everything else)
- So a real Five67 user almost certainly already has iCloud+ ($0.99/mo and up), OR they'll need it.

Not a blocker — most iPhone users with photo libraries already have paid iCloud — but worth honest framing in onboarding: *"Five67 uses your iCloud to keep your dance library safe. If iCloud storage fills up, new videos will only be saved on this device."*

### Current leaning

Option 1 (iCloud Drive ubiquity container) is the right point on the curve for v1:

- No user accounts. No backend. No CloudKit complexity.
- Works for both Photos-imported and Files-imported videos.
- Fixes the "deleted from Photos + no iCloud Backup" failure mode.
- Uses Apple's infrastructure (Apple's problem, not ours).
- Doesn't paint us into a corner — we can still add CloudKit later for multi-device, or a custom backend later for cross-platform.
- The same ubiquity-container writer covers metadata JSON, so we get the "automatic metadata backup" feature for free in the same change.

### Open decisions (rolled into the v1.1 design pass)

These were "TBD" earlier; the 2026-05-27 planning pass decided to bundle them into a single v1.1 off-device durability writeup before any code lands. No pre-launch action.

- **Final target**: deferred. iCloud Drive ubiquity container is still the leaning, but we want a real-implementation-surface writeup (entitlement footprint, restore UX, placeholder downloads, file coordination, quota states, conflict handling, real-device + multi-Apple-ID testing) before committing.
- **Metadata-only auto-backup as a smaller first step**: also deferred — grouped with the larger iCloud Drive decision rather than shipped pre-launch on its own.
- **User framing**: deferred. Quiet default vs. first-run banner vs. opt-out toggle is part of the v1.1 writeup.
- **Quota guardrails**: deferred. Belongs in the v1.1 writeup.
- **Restore UX**: deferred. Auto-restore vs. prompt-on-first-launch decides in v1.1.

---

## Decisions Log

### 2026-05-27 — Pre-launch durability scope locked

Interview-driven planning pass triggered by a Codex audit of this doc. Confirmed which durability work ships pre-launch and which slips to v1.1.

**Pre-launch — committed:**
- Library export UI shipped (Style picker → "Export Library" footer; both Metadata-only and Full options surface through a size-warning dialog).
- Backup audit + migration test harness already in place; treat `BackupAuditTests.swift` failure as a launch-blocker.
- **Prune V1/V2/V3 schemas + their `withKnownIssue`-wrapped migration tests** as dead code (no users ever existed on pre-V4; the column-collision bug only triggers in test harnesses). Smoke-test fresh-install after.

**Pre-launch — explicit "not doing"** (so these don't drift back onto the list):
- Onboarding / in-app copy explaining the data story. Lean on App Store description + standard iOS affordances; revisit only if user feedback shows confusion.
- iCloud Drive ubiquity container in any form, including metadata-only. Deferred wholesale to the v1.1 design pass.
- CloudKit enablement. Schema-compatibility constraints stay in (optional relationships, UUID identities) so the option remains open; no code change.

**v1.1 — single design pass before code:**
- One synthesized doc covering off-device durability holistically: iCloud Drive ubiquity container (videos and/or metadata), quota guardrails, restore UX, user framing, and a CloudKit revisit. Implementation only after the doc lands.

**Long-shelf, no commitment:**
- CloudKit if multi-device sync becomes a real product ask.
- Custom backend (Option 3) only if Five67 ever goes cross-platform.

---

## Future work (not blocked, just queued)

- Consider adding "Export reminder" notification or empty-state nudge for users with N+ videos.
- Reconsider whether the export entry point should also live on the Library pane (currently Style picker only).
- **User-initiated "delete original from Photos" after import** — uses `PHAssetChangeRequest.deleteAssets`; requires `NSPhotoLibraryUsageDescription` to be present for the delete confirmation. Lets storage-conscious users opt down from ~2x to 1x storage cost after Five67 has its own copy. Standard iOS pattern, low risk. Important framing: only safe for users *with* iCloud Backup, since deleting from Photos removes the redundancy that the duplication originally provided. See the "Video storage today" note below.
- **Storage transparency** — Settings or Library-pane page showing "Five67 is using X GB across N videos." Pairs naturally with the delete-from-Photos opt-in (helps users see the cost they're paying). No PhotoKit dependency.
- **In-app per-record salvage** for the migration-corruption gap (philosophy gap #1 above). Today `MigrationFailureView` lets the user save a raw-store bundle (SQLite + videos) and contact support, but offers no automatic in-app recovery. Future-work: walk `Documents/videos/` after a load failure and reconstruct a minimal `Video` record per file from filename/EXIF metadata, so users can keep going without a support round-trip. Engineering-heavy; only worth doing if we see real migration failures in the wild.

### Video storage today (context for the delete-from-Photos future-work item)

Current behavior: `VideoImporter.ingest` at `Five67/Services/VideoImporter.swift:92` does `FileManager.copyItem(at: tmp, to: Documents/videos/...)`. The Photos original stays untouched. After import:
- Photos library: original retained (may be optimized to a placeholder if iCloud Photos + Optimize Storage is on).
- `Documents/videos/`: full permanent copy.

Effective on-device storage is ~2x in the worst case, closer to ~1.1x for users with iCloud Photos optimization. This is the **standard iOS pattern for editor-class apps** (apps that trim/markup/transform media need a stable local file URL through edits, and need durability independent of the user's Photos hygiene). Apple does not flag this in review; it does not violate HIG. The duplication is a deliberate cost we pay for app self-sufficiency.
- Resolve open decisions above and implement the chosen backup target.
- If/when CloudKit is enabled: write integration tests for round-trip sync.
