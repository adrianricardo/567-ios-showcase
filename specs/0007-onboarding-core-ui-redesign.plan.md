# 567 Onboarding and Core UI Redesign

> **Decision update — 2026-07-22:** The bundled demo-video concept was removed
> before release. All demo-specific requirements and implementation notes below
> are retained only as historical execution context and are superseded. The live
> onboarding requires a user-selected video, uses no bundled media asset, and
> remains on schema V4 with no demo marker or policy/export exceptions.

## Summary

Implement the approved redesign as one cohesive batch for fresh installs only. Existing users remain permanently legacy-unlimited and do not see onboarding again.

The batch includes onboarding, paywall, freemium-policy changes, shared interaction surfaces, Library row fixes, and neutral design-token updates. It excludes product-research collection, analytics, automatic recent-video suggestions, iCloud cleanup, and the Apple Account prompt investigation; that prompt remains a separate pre-submission diagnostic.

### Implementation contract

- Execute this as one sequential implementation session/batch. Do not split schema, access policy, onboarding state, and deletion semantics across cold agents; each later UI step depends on those foundations.
- Minimum agent capability: use a competent Swift implementation model for P1–P5 because the batch combines SwiftData migration, grandfathering, StoreKit preservation, and navigation state. A lower-cost mechanical agent is appropriate for P6 only after the APIs and behavior are green.
- Read `AGENTS.md`, this plan, and only the files named below before expanding discovery. Preserve unrelated worktree changes and the repo’s one-code-path rule.
- Do not reinterpret product decisions. Stop and report a blocker if the licensed demo asset is unavailable when runtime verification begins, or if current code contradicts a locked contract below.
- Do not commit, stage, submit, or edit the shared product brain unless explicitly asked. App/spec implementation and verification come first; brain updates are the final documentation step.

## Experience and UI Changes

### Onboarding sequence

1. **Hook**
   - Headline: “Never forget a turn or combo again.”
   - Supporting copy: “Turn class videos into named moves you can find, loop, and practice.”
   - Use a live SwiftUI product composition with current named-move and looping-video UI—not a static or stale screenshot.
   - Merge the former pain cards into this screen; remove “Sound familiar?”

2. **Motivation**
   - Require one selection:
     - Remember moves when I’m out dancing
     - Practice what I learned between classes
     - Organize my class videos
   - Use the answer only within the onboarding narrative; do not persist it as analytics/research.

3. **Tailored payoff**
   - Show the real video → named move → loop transformation.
   - Adapt the headline:
     - “See every move you’ve learned in one place.”
     - “Loop the exact part until it sticks.”
     - “Give every class video a home.”
   - Organization supporting copy: “Keep them organized by style instead of buried in Photos.”
   - Remove the separate video-volume question.

4. **Seed video**
   - Remove broad Photo Library authorization and its permission primer.
   - Primary action opens Apple’s private PhotosPicker for one video.
   - Visible secondary action: “I don’t have one—try a demo.”
   - Remove `NSPhotoLibraryUsageDescription` after confirming no remaining full-PhotoKit API use.
   - Personal imports immediately present the new compact style-selection bottom sheet; demo content arrives pre-styled.

5. **Guided editor**
   - Use the real editor with progress fixed at the top.
   - Restore inline “Add name” in onboarding and every normal editor.
   - Use the standard onboarding primary action labeled “Continue.”
   - Keep a visible “I’ll do this later” action.
   - Skipping creates one unnamed full-video move so playback and the next screen still work.

6. **Result reveal**
   - Replace fake “Building your library…” processing with the actual named or unnamed move looping.
   - Headline: “Your first move is ready.”
   - Wait for the user to tap Continue; never auto-advance.

7. **Paywall**
   - Typography-only layout with no decorative visual anchor or enclosing benefit card.
   - Headline: “Unlock unlimited videos & styles.”
   - Two open benefit rows: Unlimited videos and Unlimited dance styles.
   - Purchase CTA uses StoreKit’s localized price: “Pay once — \(displayPrice).”
   - Secondary action: “Not now.”
   - Keep Restore Purchase and all loading, pending, cancellation, failure, revocation, and accessibility behavior.
   - Purchase or dismissal routes to Feed, focused on and looping the onboarding result.

Back navigation remains available on every reversible onboarding state, including seed selection, editor, result reveal, and paywall. Progress stays in one top position throughout.

### Core-product surfaces

- Replace Add Video and post-import style `confirmationDialog` popovers with compact custom bottom sheets. Empty-Feed Photos/Files buttons continue opening their source directly.
- Keep Styles as a bottom-navigation destination. The Library style chip opens a lightweight sheet using the exact shared style rows and selection/access logic; management, export, creation, rename, and durable unlock remain in the Styles tab.
- Replace video-delete confirmation with a contextual bottom sheet showing the video identity and exact named-move impact.
- Keep move swipe deletion behavior, but render an explicit visible red trash symbol.
- Move the sole now-playing cue from the trailing row action area onto the thumbnail so “Add name” never wraps around it.
- Shift Quiet Stage to neutral white/gray foreground tokens. Remove routine card/button strokes and retain outlines only for focus, contrast, or otherwise ambiguous boundaries.

## State, Data, and Policy Changes

- Add a SwiftData schema version with persistent demo identification (`isDemo`, default `false`). Existing videos migrate as personal content.
- Copy the bundled licensed demo through the normal video-storage path. Label it clearly as Demo, allow deletion, preassign its accurate style, and exclude it from:
  - free video counts;
  - free-style claims;
  - legacy/grandfather evaluation;
  - user-library exports.
- Change the free allowance from 10 to **3 personal videos**. Importing a fourth personal video presents the canonical paywall before import.
- Keep one personal-content style free:
  - demo content never claims it;
  - with zero personal videos, clear the claim and allow any style;
  - the next styled personal video establishes the free style;
  - assigning personal content to a second style presents the paywall.
- Centralize video deletion so Library and editor deletion share file removal, thumbnail cleanup, SwiftData deletion, personal-video recounting, and zero-video style-claim reset.
- Introduce explicit onboarding state: not started, in progress, completed, plus the seed video identifier.
  - Fresh empty installs start onboarding.
  - Existing installs without an in-progress marker remain grandfathered past onboarding.
  - If interrupted, restart at the hook but reuse the existing seed/demo video when the user reaches that step; never duplicate imports.
  - Active fresh-install onboarding content must never trigger content-based legacy access.
- Extract a canonical style-selection list with contextual modes: quick selection sheet, post-import tagging sheet, and full Styles management destination.
- Update active iOS specs, App Review notes, paywall screenshots/copy, and shared product-brain decisions to record the three-video cap and superseded onboarding flow.

## Execution Order and Code Map

Use the following order inside the single batch. Build and run focused tests after each numbered step before proceeding.

### 1. Persistence and policy foundation

Primary files: `Five67/Models/Video.swift`, `Five67/Models/SchemaMigrations.swift`, `Five67/Services/AccessPolicy.swift`, `Five67/Services/UnlockStore.swift`, `Five67/Services/LibraryExporter.swift`.

- Current live schema is V4. Add V5 with non-optional `Video.isDemo` defaulting to `false`; migrate all existing rows as personal content.
- Change `AccessPolicy.freeVideoLimit` from 10 to 3 and rename count inputs to make **personal-video count** explicit.
- Add canonical helpers for `personalVideos`, `personalVideoCount`, and demo exclusion; do not scatter `!isDemo` filters across views.
- Preserve paid and legacy access. Active fresh onboarding sessions are never eligible for library-content grandfathering, and demo rows never contribute to legacy evidence.
- Make `UnlockStore` clear `claimedFreeStyleID` when personal-video count reaches zero. Demo style IDs never call `recordStyleUse`.
- Exclude demo rows and files from `LibraryExporter` output and integrity totals.

### 2. Onboarding session and demo ingestion

Primary files: `Five67/Services/OnboardingPreferences.swift`, `Five67/Views/Onboarding/OnboardingGateView.swift`, `Five67/Services/VideoImportPersistence.swift`.

- Replace the Boolean-only gate with `OnboardingStatus: String` (`notStarted`, `inProgress`, `completed`) plus an optional persisted `seedVideoID`.
- Compatibility rules:
  - existing `hasCompleted == true` migrates to `completed`;
  - no status + nonempty pre-update library migrates to `completed` and keeps legacy-unlimited behavior;
  - no status + empty library becomes `notStarted`;
  - `inProgress` always presents onboarding even when its seed video exists.
- Mark `inProgress` when a fresh user starts. On process relaunch, restart the narrative at Hook and clear the session-only motivation, but keep `seedVideoID`.
- When Seed is reached again, resolve and reuse the persisted video automatically. If the row or file is missing, clear the stale ID and show PhotosPicker/demo actions. Never insert a duplicate.
- Mark `completed` only after purchase success or “Not now” exits the paywall; then clear `seedVideoID` while retaining the content.
- Add one bundled-demo ingestion service that copies `OnboardingDemo.mp4` into owned storage and finishes insertion through `VideoImportPersistence`; do not create a parallel model-insertion path. Use a stable bundled-source identifier for dedupe.

### 3. Shared actions, deletion, and style selection

Primary files: `Five67/Views/Feed/VideoFeedView.swift`, `Five67/Views/Library/LibraryPaneView.swift`, `Five67/Views/Style/StylePickerPaneView.swift`.

- Extract reusable `ImportSourceSheet` and `StyleSelectionList` components. Feed remains the canonical owner of Photos/Files import and access-policy decisions.
- `StyleSelectionList` accepts a context/closure rather than routing internally:
  - post-import sheet applies a video style or Skip;
  - Library quick sheet updates the global filter and dismisses to Library;
  - Styles tab retains create, rename, export, and durable unlock management.
- Add one `VideoDeletionService` used by Library and editor. It owns file deletion, thumbnail-cache clearing, SwiftData deletion, personal-count recalculation, and zero-personal-video style-claim clearing.
- Replace video `confirmationDialog` with a contextual bottom sheet that shows title, thumbnail, and exact named-move impact. Keep move swipe deletion immediate and make its `trash` symbol visibly red on iOS 26.
- Move playing state into a thumbnail overlay for both move and video rows; remove the trailing waveform so row actions never wrap.

### 4. Onboarding UI and navigation

Primary files: `Five67/Views/Onboarding/OnboardingFlow.swift`, `Five67/Views/Onboarding/OnboardingArtwork.swift`, `Five67/Views/VideoDetail/VideoDetailView.swift`.

- Replace the current `Beat` cases (`valueSurvey`, `pain`, `styles`, `volume`, `permission`, `processing`) with only the approved sequence. Define `OnboardingMotivation` as a session-only enum that owns its label and payoff copy.
- Remove `PHPhotoLibrary.requestAuthorization`, Photo authorization state/copy, and `NSPhotoLibraryUsageDescription`; keep `PhotosPicker` with one-video selection.
- Personal seed: insert once, persist its ID, present canonical style sheet, then open editor. Demo seed: ingest/dedupe, persist ID, preassign the asset’s configured style without claiming free access, then open editor.
- Make `VideoDetailView` expose onboarding chrome through explicit inputs: top progress, primary `Continue`, secondary “I’ll do this later,” and inline move rename. Inline “Add name” also becomes visible in normal editor use.
- Skip behavior creates exactly one `Move(name: "", time: 0, endTime: duration)` only when the video has no moves; never add a duplicate full-video move.
- Result reveal uses the real persisted move and playback controller. Continue opens the paywall; purchase or dismissal calls one completion action that routes via `AppRouter` to Feed with the seed video/move selected and looping.
- Replace `showLibraryAfterOnboarding` with a Feed-specific completion route; remove the Library-ready toast and replace it only if the Feed needs a brief accessible success announcement.

### 5. Paywall and visual-system pass

Primary files: `Five67/Views/Shared/UnlockPaywallView.swift`, `Five67/Views/Shared/Theme.swift`, and the shared sheet/button primitives created above.

- Preserve the canonical StoreKit purchase/restore implementation and reason enum; change presentation, copy, and free-limit text only.
- Use the localized StoreKit price in “Pay once — \(displayPrice).” Never hard-code `$6.99` in runtime UI.
- Update every video-cap message from 10 to 3. Keep reason-specific explanatory text below the universal feature-led headline.
- Replace warm foreground values (`primary`, `secondary`, `actionSurface`, `ink`) with clean neutral grayscale values that continue passing contrast tests. Style accents remain unchanged.
- Remove routine `stageStroke` overlays from cards, buttons, fields, and rows. Retain a boundary only when grayscale/Increase Contrast review shows the surface is otherwise ambiguous.
- Apply the same sheet styling to Add Video, style tagging, quick style selection, and video deletion; do not independently design four sheet variants.

### 6. Project metadata, tests, and documentation

Primary files: relevant Swift Testing/UI fixture suites, `Five67/Resources/Info.plist`, active iOS onboarding/release docs, and the shared brain only after explicit approval.

- Add `OnboardingDemo.mp4` to the app target only after the licensed asset and style label are supplied; verify target membership and installed-bundle lookup.
- Update StoreKit fixtures, UI-test arguments, App Review reachability notes, and screenshots to the three-video policy and Feed completion route.
- Remove obsolete onboarding preference keys and fixtures only after compatibility migration tests pass.
- Do not update historical decision records as if they never existed; append the new cap/onboarding decision and identify which prior plan it supersedes.

## Existing-Code Traps

> These describe the codebase **as it was when the plan was written**. Entries
> marked ✅ were resolved by the phase named; they are kept so the reasoning is
> auditable, but do **not** treat them as current facts. Only the ⚠️ entries
> still describe live code.

- ✅ *(P2)* `OnboardingGatePolicy` currently requires `videoCount == 0`; changing only the view state will still bypass interrupted onboarding after seed import.
- ✅ *(P4)* `OnboardingGateView` currently routes through `showLibraryAfterOnboarding` and shows a Library-ready toast.
- ✅ *(P4)* `OnboardingFlow.toggleStyle` is single-select despite the older multi-select language; the approved redesign removes this question entirely.
- ✅ *(P4)* `OnboardingFlow` currently requests full Photos authorization before opening a private picker. Remove both the API call and all now-dead limited/denied branches.
- ✅ *(P3)* `VideoDetailView` passes `showsInlineRename: false`, while `MoveRowView` already contains the desired Add Name UI.
- ✅ *(P1)* `AccessPolicy.freeVideoLimit` is 10, and `UnlockStore.claimedFreeStyleID` is durable UserDefaults state; both unit and UI fixtures encode the current behavior.
- ✅ *(P3)* Feed, Library, and editor currently contain adjacent import/style/delete logic. Reuse their action methods or extract one owner; do not add fallback state machines.
- ✅ *(P3 code; visually confirmed in P6)* Current move swipe code requests the `trash` symbol, but its iOS 26 presentation renders white-on-white. An explicit destructive tint/state is required and must be visually verified. — The P6 audit screenshot shows a white trash glyph on a red capsule. Resolved.
- ✅ *(P5)* The current paywall component already handles StoreKit loading, purchase, restore, and accessibility focus. Redesign its view hierarchy without replacing transaction logic.

## Verification

- Unit tests:
  - three personal videos allowed; fourth blocked;
  - demo excluded from cap, style claim, export, and grandfathering;
  - zero personal videos clear the free-style claim;
  - first personal style succeeds and second triggers paywall;
  - schema migration marks all existing videos non-demo;
  - interrupted onboarding restarts the narrative and reuses its seed;
  - existing users remain legacy-unlimited and never re-enter onboarding;
  - motivation-to-payoff copy mapping;
  - centralized deletion and named-move impact.
- UI/runtime journeys:
  - personal-video path with named move;
  - personal-video path using editor skip;
  - demo path, removal, and non-counting behavior;
  - PhotosPicker import with no Photo Library authorization prompt;
  - post-import style bottom sheet and Library quick-style sheet;
  - paywall purchase, restore, unavailable product, “Not now,” and Feed landing;
  - fourth-video and second-style paywall triggers;
  - visible move-delete trash icon and contextual video-delete sheet;
  - relaunch from each onboarding phase without duplicate content.
- Visual/accessibility:
  - neutral palette and stroke audit in color and grayscale;
  - Dynamic Type, VoiceOver, Increase Contrast, Reduce Motion, and 44-point targets;
  - verify progress remains at the top and now-playing overlay does not obscure thumbnails or text.
- Commands: `make build`, `make test`, `make run-fresh`, and `make run-xcode` for StoreKit. Record any native-picker or simulator-only boundary honestly.

## Assumptions and Required Inputs

- Adrian will later provide a redistribution-safe licensed portrait dance clip, target name `OnboardingDemo.mp4`, plus its dance-style label. It must contain no unlicensed music. Final demo verification and shipping are blocked until this asset arrives.
- Automatic Photos scanning, research/analytics, and iCloud cleanup remain out of scope.
- The unexpected Apple Account prompt is investigated separately before App Store submission.
- The final private-picker decision supersedes the earlier plan to prompt every onboarding user for full Photo Library access.

## Progress

| ID | Status | Owner/session | Last update | Notes |
|----|--------|---------------|-------------|-------|
| P1 Persistence and policy | done | claude-code | 2026-07-22 | Cap 3 and style reset retained; pre-release demo marker removed, leaving live schema V4 |
| P2 Onboarding session | done | claude-code | 2026-07-22 | Status/seed reuse retained; bundled demo ingestion removed |
| P3 Shared actions and rows | done | claude-code | 2026-07-21 | Shared sheets, `VideoDeletionService`, style list, thumbnail cue. `make build` + `make test` green. Sheet *styling* not yet eyeballed — see P6 |
| P4 Onboarding UI/navigation | done | claude-code | 2026-07-21 | Approved 7-beat sequence, PhotoKit removed, Feed completion route. `make build` + `make test` green |
| P5 Paywall/visual system | done | claude-code | 2026-07-21 | Typography-only paywall, localized price CTA, neutral tokens, strokes reduced to a contrast-only rule. `make build` + `make test` green. *Visual/grayscale audit still owed to P6* |
| P6 Verification/docs | done* | claude-code | 2026-07-22 | Visual audit run and reviewed; App Review notes and decisions updated. *On-device Increase Contrast verification remains |

Status values: `pending`, `in-progress`, `blocked`, `done`.

## Handoff

### Start here (cold session)

1. Read `AGENTS.md`/`CLAUDE.md`, then this plan top-to-bottom. Do not re-derive
   P1–P6 — they are green (P1–P4 committed; P5–P6 in the worktree).
2. **All six phases are implemented.** The demo path was deliberately removed
   before release. What remains is release validation:
   a. verify the Increase Contrast boundary on a physical device
      (`docs/open-questions-ios.md`);
   b. re-shoot the App Review screenshots from a `make run-xcode` build so the
      paywall shows the real localized price, then work
      `docs/p4-submission.md`'s checklist.
3. Verify with `make build`, then
   `xcodebuild test -scheme Five67 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build/DerivedData -only-testing:Five67Tests`
   for a fast loop; run the full `make test` (adds ~5 min of UI tests) before
   closing a phase.
4. `MigrationTests` passing "with 6 known issues" is expected and correct — that
   is the accepted V3→V4 ZSTYLE breakage, not a regression.

Current state: **P1–P6 complete and locally green**. The demo concept is removed,
the app remains on the shipped V4 schema, and final build/unit/UI verification
passed on iOS 26.1. On-device Increase Contrast remains open.

#### Environment facts

- The Xcode project is generated by **XcodeGen** (`make generate`, run
  automatically by `make build`). New Swift files under `Five67/` are picked up
  from the directory — **do not hand-edit `Five67.xcodeproj/project.pbxproj`**;
  it is gitignored and regenerated on the next build.
- If `xcodebuild` aborts instantly with SIGABRT, check
  `getconf DARWIN_USER_CACHE_DIR` — an `Input/output error` there is an OS fault,
  not a code problem (seen 2026-07-21; it cleared on its own).
- If UI tests fail with "Application failed preflight checks", run
  `xcrun simctl shutdown all` and re-run.
- `xcrun simctl io booted screenshot` proved unreliable for visual checks: it
  kept returning the stale Apple Account sign-in prompt rather than the app under
  test. Use `XCUIScreen.main.screenshot()` attachments inside a UI test, or check
  visuals by hand, if you need to confirm appearance.

#### Reference: what P6 inherited from P1–P5 (do not rebuild these)

- **Every code change §1–§5 asks for is in.** P6 is the metadata, asset, test-
  fixture, and documentation phase plus the one thing no earlier phase could do:
  the *visual* audit. Do not reopen P1–P5 design decisions to "improve" them.
- The three-video cap is already reflected in runtime copy, unit tests, and UI
  fixtures. What §6 still wants is the **App Review reachability notes and
  screenshots** updated to the new paywall and the Feed completion route.
- No hard-coded `10` and no hard-coded `$6.99` remain in runtime code
  (`$6.99` appears only in the two `.storekit` fixtures and the
  `UnlockStoreTests` assertion about them, which is correct).

#### P6 starting facts (verified 2026-07-21; kept for auditability)

- **Two visual items are explicitly owed to P6 and are the only unverified work
  in the whole batch:**
  1. the compact sheets' appearance and the red swipe-delete trash glyph (P3);
  2. the neutral-token/stroke pass in color **and grayscale**, plus Increase
     Contrast (P5) — confirming no surface became ambiguous now that routine
     hairlines are gone.
- **Screenshots from `xcrun simctl io booted screenshot` are not trustworthy
  here** — they kept returning the stale Apple Account sign-in prompt. Use
  `XCUIScreen.main.screenshot()` attachments inside a UI test (the existing
  `testScreenshotsAllTabs` is the natural hook) or check by hand.
- **Blocked input, unchanged:** the licensed `OnboardingDemo.mp4` and its style
  label. Until it lands, `OnboardingDemoIngestion` throws `.assetMissing`, its
  `styleID` defaults to Salsa, and the demo journey cannot be run. Add the file
  to the app target and confirm target membership + installed-bundle lookup when
  it arrives.
- **`Info.plist` work for §6 is already done** — `NSPhotoLibraryUsageDescription`
  was removed in P4 from both `project.yml` and `Five67/Resources/Info.plist`.
  Remember the project is XcodeGen-generated: edit `project.yml`, never the
  `.xcodeproj`.
- **Obsolete onboarding preference keys:** P2 already stopped writing the legacy
  `hasCompleted` Boolean and the survey keys; `hasCompleted` is still *read* once
  for migration and must stay until the compatibility path is retired
  deliberately, which is not a P6 cleanup.

### P1 (done)
- `Models/Video.swift`: non-optional `isDemo: Bool = false` (+ init param);
  `Sequence<Video>.personalVideos` / `.personalVideoCount` canonical helpers.
- `Models/SchemaMigrations.swift`: frozen inlined `SchemaV4` (Video/Move/Style);
  new `SchemaV5` (live) + lightweight `v4ToV5`; `v3ToV4.didMigrate` repinned to
  `SchemaV4.*` so its destination shape is fixed.
- `Services/AccessPolicy.swift`: `freeVideoLimit` 10→3; `videoImportAllowance`
  param renamed to `personalVideoCount:`; videoLimit copy says "3 videos".
- `Services/UnlockStore.swift`: added `recountPersonalVideos(_:)` clearing
  `claimedFreeStyleID` at zero personal videos — **still needs to be called from
  the P3 `VideoDeletionService`**.
- `Services/LibraryExporter.swift`: demo rows, their moves, and their files
  excluded from DTOs, orphan detection, and copies.
- `Views/Feed/VideoFeedView.swift`: 3 allowance call sites pass personal count.
- Tests: `AccessPolicyTests`, `MigrationTests` (+`withV4Container` harness, V4→V5
  non-demo test, V5 risk re-affirmed in header), `Five67UITests` cap fixtures now
  derive from a `freeVideoLimit = 3` constant instead of hardcoding 10/12.

### P2 (done, one blocked input)
- `Services/OnboardingPreferences.swift`: rewritten. `OnboardingStatus`
  (notStarted/inProgress/completed) + persisted `seedVideoID`;
  `OnboardingGatePolicy.shouldPresent(status:)` and `.migratedStatus(...)`
  implementing the compatibility rules; `resolveStatus(existingLibraryCount:)`.
  Legacy `hasCompleted` key is read once for migration, never written.
- `Services/OnboardingDemoIngestion.swift` (new): copies `OnboardingDemo.mp4`
  through `VideoImporter.import(fromFileURL:sourceID:)` and finishes via
  `VideoImportPersistence` — no parallel insertion path. Dedupes on
  `bundledSourceID`, preassigns `styleID` **without** claiming the free style.
  Throws `.assetMissing` until the licensed asset is added to the target.
- `Services/VideoImporter.swift`: `import(fromFileURL:sourceID:)` gained an
  optional stable source ID. `Services/VideoImportPersistence.swift`: `isDemo:`.
- `Views/Onboarding/OnboardingGateView.swift`: status-driven gate; passes
  `personalVideoCount` to legacy evaluation only when `completed`, so a fresh
  install's own onboarding content can never grandfather it.
- `Views/Onboarding/OnboardingFlow.swift`: survey answers are now session-only
  (all `saveValueProps`/`saveDanceStyles`/`saveVideoVolume` calls removed per the
  "do not persist as analytics" contract); added `adoptSeed(_:)` and
  `restorePersistedSeedIfAvailable()` so a relaunch reuses the seed and clears a
  stale ID. Beat structure itself is untouched — P4 replaces it.
- `App/Five67App.swift`: UI-test fixtures write `OnboardingStatus` instead of the
  removed Boolean/survey keys.

### P3 (done)
- `Views/Shared/StageSheet.swift` (new): top-level `ImportSource` enum (promoted
  out of `VideoFeedView`), the one `StageSheet` container every compact sheet
  presents through, `StageSheetActionRow`, and `ImportSourceSheet`. All four
  sheets share `[.medium, .large]` detents, the stage background, and the drag
  indicator — there is no per-sheet styling.
- `Views/Shared/StyleSelectionSheet.swift` (new): `StyleSelectionList` (the
  canonical style rows) plus `StyleSelectionSheet` with a `StyleSelectionContext`
  of `.quickFilter` / `.tagImport(count:)`. The Styles tab renders the same
  `StyleSelectionList` rows inside its own `List` so it keeps swipe actions.
- `Views/Shared/StageThumbnailView.swift` (new): the shared thumbnail and the
  **only** place the now-playing cue is drawn (overlaid on the image). The
  trailing `waveform` is gone from both move and video rows, so "Add name" no
  longer wraps around it.
- `Views/Shared/VideoDeleteSheet.swift` (new): contextual delete confirmation
  showing thumbnail, title, and exact named-move impact.
- `Services/VideoDeletionService.swift` (new): the single deletion owner —
  thumbnail cache, file, SwiftData row, then `UnlockStore.recountPersonalVideos`
  from a fresh fetch (the just-deleted row filtered by id, since a caller's
  `@Query` snapshot has not observed the delete yet). Library and the editor both
  call it. This closes the P1 to-do.
- `VideoFeedView`: both `confirmationDialog`s replaced. Sheet choices are applied
  in `onDismiss` (`handleAddVideoSheetDismiss`, `handleStyleTagSheetDismiss`) so
  the Photos/Files picker or the paywall never races a dismissing sheet.
- `LibraryPaneView`: the style chip is now a button opening the `.quickFilter`
  sheet, gated by the same `unlockStore.canUseStyle` check the Styles tab uses;
  delete routes through `VideoDeleteSheet`.
- `MoveRowView`: `showsInlineRename` removed entirely — inline "Add name" is now
  visible in the normal editor too. The swipe delete uses an explicit `.tint(.red)`
  instead of `role: .destructive`, which rendered white-on-white on iOS 26.
- Tests: `TabBarVerifyTests` gained
  `testLibraryQuickStyleSheetFiltersWithoutLeavingLibrary` and
  `testLibraryVideoDeleteSheetShowsIdentityAndImpact`; the style-chip assertion in
  `testLibraryPopulatedReviewFlow` now reads the chip's accessibility value.

**Not verified in P3:** the sheets' and the red trash glyph's *appearance* was not
eyeballed. Attempts to capture the simulator display kept returning the stale
Apple Account sign-in prompt (the separate pre-submission issue). Behavior is
covered by the tests above; the pixel audit belongs to P6's visual pass.

### P4 (done)
- `Views/Onboarding/OnboardingMotivation.swift` (new): the session-only enum
  owning each answer's label, payoff headline, and supporting copy. Nothing
  persists it.
- `Views/Onboarding/OnboardingProgressDots.swift` (new): `OnboardingProgress`
  (index/total) + the dots view. Extracted so the *same* cue renders in the
  onboarding scaffold and inside the guided editor, keeping one top position.
- `Views/Onboarding/OnboardingFlow.swift`: rewritten to the approved 7 beats —
  `hook, motivation, payoff, seed, editor, result, paywall`. `import Photos`,
  `PHPhotoLibrary.requestAuthorization`, `photosStatus`, the permission primer,
  the styles/volume/pain/value-survey beats, and the fake `processing` beat are
  all gone. Back is offered on every beat except Hook and the paywall (leaving
  the paywall *is* completion).
- Seed step: primary opens `PhotosPicker`; secondary is
  "I don't have one—try a demo" → `OnboardingDemoIngestion`. A personal import
  opens `StyleSelectionSheet(context: .tagImport(count: 1))` and enters the
  editor on its dismissal; demo content is pre-styled and skips it. A **restored**
  seed renders a distinct confirm state ("Your video's still here.") with
  Continue / "Choose a different video" rather than auto-advancing — auto-advance
  would make Back from the editor bounce forward forever.
- `ensureSeedMoveExists()` is called from *both* editor exits (one code path), so
  Continue-without-marking and "I'll do this later" each guarantee exactly one
  full-video move and never a duplicate.
- Result reveal (`OnboardingResultReveal`): the real persisted move on a real
  `PlaybackController` with `isLooping = true`; no auto-advance.
- `Views/Onboarding/OnboardingArtwork.swift`: `OnboardingBrandHero`,
  `OnboardingPayoffArtwork`, and `ProcessingMark` replaced by
  `OnboardingProductPreview` — a live composition built from the shipped
  `StageThumbnailView` (including its now-playing cue) and the move row's
  name/duration/"Add name" layout, so it cannot go stale. `Five67BrandMark`
  stays (SplashView uses it).
- `Views/VideoDetail/VideoDetailView.swift`: two new explicit inputs —
  `progress: OnboardingProgress?` (pinned above the top bar) and
  `onSecondaryFinish`. `secondaryFinishTitle` now renders in the **leading** slot
  so "I'll do this later" and "Continue" are visible together;
  `finishEditing(isSecondary:)` routes the two exits apart.
- `Services/AppRouter.swift`: `showLibraryAfterOnboarding` and the whole
  `LibraryArrival` / `pendingLibraryArrival` mechanism removed (onboarding was
  its only producer) in favor of `showFeedAfterOnboarding(_:)`, which delegates
  to the existing `showInFeed`. `LibraryPaneView.focusPendingArrival` deleted.
- `Views/Onboarding/OnboardingGateView.swift`: routes to Feed; the Library-ready
  toast is gone and was not replaced (the Feed lands focused on the looping
  result, which is its own confirmation).
- `Views/Feed/VideoFeedView.swift`: dropped the unused `import Photos`.
- `project.yml` + `Five67/Resources/Info.plist`: `NSPhotoLibraryUsageDescription`
  removed after confirming no full-PhotoKit API use remains anywhere.
- Tests: `OnboardingTests` gained the motivation→payoff copy mapping and the two
  Feed-completion router tests (replacing the Library-arrival one);
  `TabBarVerifyTests` replaced its two onboarding journeys with
  `testOnboardingCompletionLandsInFeed`,
  `testOnboardingReachesSeedWithoutAPhotoPermissionPrompt` (asserts no system
  alert and no permission primer), and `testOnboardingSeedStepCanNavigateBack`.

**Not verified in P4:** the seed→editor→result journey end-to-end with a real
video. The UI tests cannot drive Apple's private picker, and the demo path stays
blocked on the licensed `OnboardingDemo.mp4`. Everything up to the seed step, the
completion route, and the copy mapping are covered.

### P5 (done)
- `Services/AccessPolicy.swift`: `UnlockPromptReason.title`/`.subtitle` collapsed
  into one `explanation` line. The headline is now universal and owned by the
  view, so the enum only answers "why is *this* user seeing it":
  `.onboarding`/`.durableEntry` → "One payment. No subscription, ever.";
  `.videoLimit` → "Your free library includes \(AccessPolicy.freeVideoLimit)
  videos." (interpolated, so the cap can never drift out of the copy again);
  `.styleLimit` → "Your free library includes one dance style."
- `Views/Shared/UnlockPaywallView.swift`: typography-only. Leading-aligned
  headline "Unlock unlimited videos & styles." + `reason.explanation`, then two
  **open** benefit rows (title + supporting line, no card, no background, no
  stroke) built by a private `benefitRow(_:_:)`. The enclosing
  `RoundedRectangle`/`stageStroke` card is gone. `unlockButtonTitle` now returns
  `"Pay once — \(displayPrice)"`; its "Unlock unavailable" branch is untouched,
  so the view still never invents a price. StoreKit purchase/restore,
  `UnlockPurchaseOutcome` handling, the status messages, and the
  `@AccessibilityFocusState` focus moves were **not** modified.
- `Views/Onboarding/OnboardingFlow.swift`: `BulletLine` deleted — the benefit
  rows replaced its only use.
- `Views/Shared/Theme.swift`: the four warm foregrounds are now pure neutrals —
  `primary` `0xF7F3E9`→`0xF2F2F2`, `secondary` `0xB8B1A7`→`0xB0B0B0`,
  `actionSurface` `0xFFFDF7`→`0xFFFFFF`, `ink` `0x10100F`→`0x101010`. Style
  accents are unchanged and remain the only color the app spends.
- **Strokes are now one rule, not 12 decisions.** `Theme.stageStroke` (a flat
  `white.opacity(0.09)`) is deleted and replaced by
  `Theme.stageBoundary(_ contrast: ColorSchemeContrast)`, which returns `.clear`
  normally and `stageSecondary.opacity(0.6)` under Increase Contrast. Surfaces
  are distinguished by fill (`stageSurface` on `stageBackground`); a hairline
  comes back only where it carries meaning. This generalizes the treatment
  `VideoDetailView` already had rather than inventing a new one. All call sites
  route through it: `StageSelectableRow` and `StageSecondaryActionButtonStyle`
  (both gained `@Environment(\.colorSchemeContrast)`), `StylePickerPaneView`
  (same), and the local `stageStroke` helpers in `LibraryPaneView` and
  `VideoDetailView`, which now just forward to it.
- Tests: `OnboardingTests.quiet_stage_neutrals_carry_no_color_cast` asserts
  R==G==B for all seven `StagePalette` neutrals, so a warm value cannot creep
  back; the existing contrast test still passes unchanged. The three paywall
  assertions in `TabBarVerifyTests` now check the shared `paywallHeadline`
  constant plus the reason-specific explanation.

**Not verified in P5:** appearance. The neutral swap and the stroke removal were
verified numerically (contrast + neutrality tests) but not reviewed in color,
grayscale, or Increase Contrast on a device. That review is P6's, together with
P3's sheet/trash-glyph audit.

### P6 (done, two external blockers)

- `Five67UITests/VisualAuditTests.swift` (new): captures the surfaces whose
  *appearance* P3/P5 changed — library rows, the swipe-delete glyph, all four
  compact sheets, the styles tab, the paywall, and the onboarding hook — as
  in-process `XCUIScreen.main.screenshot()` attachments, because
  `simctl io booted screenshot` is unreliable in this project. Export them with
  `xcrun xcresulttool export attachments --path <result>.xcresult
  --output-path <dir>`; the file header documents the flow. Adds ~60s to
  `make test`.
- **Visual audit result (reviewed, not just captured):**
  - the red swipe-delete trash renders correctly — this closes P3's ⚠️ trap;
  - the paywall matches §7: universal headline, two open rows, no card, neutral;
  - library rows, sheets, and fields stay legible with the routine strokes gone —
    `stageSurface` on `stageBackground` is a sufficient boundary;
  - grayscale pass: nothing depends on color alone (selection is the checkmark,
    the destructive action carries a glyph and the word "Delete", style dots are
    identity metadata beside a text label);
  - the now-playing cue sits on the thumbnail and obscures neither art nor text.
- **Increase Contrast could NOT be verified** and is now the one accessibility
  gap. `xcrun simctl ui booted increase_contrast enabled` changes nothing in the
  app — confirmed by pixel diff before *and* after a full simulator reboot, and
  iOS's own chrome doesn't change either, so the toggle isn't reaching app
  processes on this runtime. This matters more after P5 than before it: routine
  hairlines are gone, so `Theme.stageBoundary` is now the only thing that ever
  draws one. Locked by the unit test
  `stage_boundary_is_drawn_only_under_increased_contrast`, and logged for device
  verification in `docs/open-questions-ios.md`.
- `docs/p4-submission.md`: App Review notes rewritten to the shipped 0007 flow —
  the demo escape hatch, "Not now", and an explicit statement that the app never
  requests Photo Library access (private picker; `NSPhotoLibraryUsageDescription`
  intentionally absent). The IAP review-screenshot spec now names the new
  headline, benefit rows, and `Pay once — <price>` CTA, and warns that a CLI run
  without StoreKit shows the "Unlock unavailable" fallback, which must not be
  submitted. Added checklist rows for the Info.plist check and re-shooting every
  pre-0007 screenshot.
- `docs/design-decisions.md`: two appended records — the three-video cap and
  redesigned onboarding (naming 0005's 10-video cap, `onboarding-0005.md`, and
  0006's product assumption as superseded, without rewriting them), and the
  neutral-token/boundary decision (an *amendment* to Warm Stage, not a
  replacement).
- `docs/design-system.md`: the token table now documents `stageBoundary(_:)` in
  place of `stageStroke`, and the warm-white language is corrected to neutral;
  `docs/design-system-coverage.md` notes that "Warm Stage" is now a historical
  name for an all-neutral palette.
- Verified no work was needed on: StoreKit fixtures (both `.storekit` files carry
  only the product/price and say nothing about caps or iCloud cleanup), UI-test
  launch arguments (every argument the tests pass is handled in `Five67App` or
  `UnlockStore` — no orphans in either direction), and obsolete preference keys
  (P2 already stopped writing the survey keys; `hasCompleted` is still *read* for
  migration and must stay).

**Blocked in P6 (external input, not code):**
1. On-device Increase Contrast verification (above).

Next step: re-shoot App Review screenshots from a `make run-xcode` build
(StoreKit loaded) and run the device accessibility check.

Files changed: the P1–P6 files listed above,
`Five67Tests/OnboardingTests.swift`, `Five67UITests/TabBarVerifyTests.swift`,
`Five67UITests/VisualAuditTests.swift`, `docs/p4-submission.md`,
`docs/design-decisions.md`, `docs/design-system.md`,
`docs/design-system-coverage.md`, `docs/open-questions-ios.md`, and this plan.

Checks run (all green, 2026-07-21):
- `make build` → BUILD SUCCEEDED.
- `xcodebuild test -only-testing:Five67Tests` → 54 tests / 7 suites passed;
  MigrationTests passes with 6 pre-existing known issues (V3→V4 ZSTYLE, accepted).
  The `Lifetime unlock StoreKit behavior` suite is **skipped** on this CLI path —
  it needs the Xcode scheme's StoreKit config (`make run-xcode`).
- `make test` → 24/24 UI tests, 0 failures.
- Visual audit captured and reviewed in color and grayscale (see P6 above).
  Increase Contrast could not be exercised in the simulator.

Release-candidate rerun (green, 2026-07-22):
- `make build` → BUILD SUCCEEDED with no bundled demo media.
- Focused onboarding UI journey → 1/1 passed; payoff and seed captures reviewed.
- `make test TEST_DESTINATION='platform=iOS Simulator,id=C476C564-C536-4C23-AA15-C0A1934D79E6'`
  on the known-good iOS 26.1 runtime → all unit suites and 24/24 UI tests passed.
  The logged V1–V3 migration failures remain the accepted `withKnownIssue`
  probes documented above; the shipped V4 path and fresh-install path pass.

Open questions: none in the plan. The on-device Increase Contrast check remains
tracked in `docs/open-questions-ios.md`.
