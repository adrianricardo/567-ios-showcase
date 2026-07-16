# 0006 — Finish, polish, monetize, and release

**Status:** Ready for implementation after Adrian confirms the paywall release cut in Gate G2.

**Milestone:** Finish all in-flight iOS work, commit it, apply the approved design system across the entire user-facing app (including every onboarding beat and the paywall), finish and test a truthful entitlement-backed paywall, and ship the resulting update through TestFlight and App Review.

**Repository:** `~/Code/567-ios`

## Goal

Produce a clean, committed, release-ready update in which:

1. The approved Groups 0–5 design migration is finalized and committed without losing the existing dirty baseline.
2. Every user-facing surface has an explicit, verified design-system disposition.
3. The onboarding paywall sells only functionality present in the submitted binary.
4. Purchase, restore, entitlement, grandfathering, and free-limit behavior work locally and through Apple's sandbox/TestFlight environment.
5. The exact uploaded build passes real-device smoke testing and is ready to submit with its first in-app purchase.

## Non-goals

Do not start or include any of the following in this release unless Adrian changes this plan in writing:

- Smart location-based import or new location persistence.
- The recent-video recommendation surface.
- iCloud cleanup implementation.
- New accounts, backend integration, analytics, or tracking.
- V1/V2/V3 SwiftData schema pruning.
- Library-versus-Feed information-architecture reconsideration.
- Class recap sharing (`specs/0004-*`).
- Creator funnel work (`specs/0003-*`).
- Marketplace/backend work.
- A new app-wide architecture or parallel state machine.

## Required reading

Read these before changing code:

1. `AGENTS.md`
2. `docs/design-system.md`
3. `docs/design-decisions.md`
4. `docs/design-migration.md`
5. `docs/design-foundation/proposal.md`
6. `specs/0005-freemium-unlock-smart-import.md` sections 2–4 and 8–9
7. `docs/onboarding-0005.md`
8. `docs/launch-punch-list.md`
9. This plan
10. The current `git status` and full existing diff

Use these skills when available:

- `swiftui-view-refactor`
- `ios-accessibility`
- `ios-debugger-agent`
- `app-store-review`
- `swift-testing`
- `photokit` only when verifying the existing onboarding import path; do not expand into smart import.

## Current state snapshot

The worktree is intentionally dirty. It contains Adrian's approved, uncommitted Groups 0–4 baseline plus completed Group 5 cleanup. Do not discard, restore, or rewrite it.

At plan creation, the existing dirty baseline was:

```text
M Five67/App/Five67App.swift
M Five67/Services/AppRouter.swift
M Five67/Services/StyleStore.swift
M Five67/Views/Feed/VideoFeedView.swift
M Five67/Views/Library/LibraryPaneView.swift
M Five67/Views/Onboarding/OnboardingFlow.swift
M Five67/Views/Onboarding/OnboardingGateView.swift
M Five67/Views/Root/RootView.swift
M Five67/Views/Shared/PlayerOverlay.swift
M Five67/Views/Shared/Theme.swift
M Five67/Views/Shared/VideoHeroView.swift
M Five67/Views/VideoDetail/MoveRowView.swift
M Five67/Views/VideoDetail/TrimTrackView.swift
M Five67/Views/VideoDetail/VideoDetailView.swift
M Five67Tests/OnboardingTests.swift
M Five67UITests/TabBarVerifyTests.swift
M docs/README.md
M docs/brand.md
?? docs/design-decisions.md
?? docs/design-foundation-brief.md
?? docs/design-foundation/
?? docs/design-migration.md
?? docs/design-system.md
```

Group 5 verification already completed once:

- `make build` passed.
- `make test` passed, including all unit suites and 13 UI tests.
- Focused onboarding → Library, Library → practice, playback/seek/split, and practice → changed Feed-result journeys passed.
- Reduce Motion, Increase Contrast, and accessibility-extra-large walkthroughs passed.
- Color/grayscale evidence exists under `build/group5-evidence/`.
- `git diff --check` passed.

Re-run the release gates; do not rely only on the old result.

### Known release gaps

1. `docs/design-migration.md` still describes the migration as “plan only / not started” even though Groups 0–5 are implemented.
2. Design-system application is not yet proven app-wide. For example, most onboarding beats use adaptive/system styling while only the style-selection beat uses the complete Quiet Stage recipe; other views such as `StylePickerPaneView`, import/rename/status surfaces, and root states require explicit review.
3. `UnlockStore` can load, purchase, verify, and restore a non-consumable, but `isUnlocked` currently does not gate or unlock product behavior.
4. The paywall and local StoreKit product advertise iCloud cleanup, which is not implemented.
5. There is no complete StoreKitTest coverage or TestFlight sandbox evidence for the first IAP.
6. The current marketing version is `1.0.2`; the next version must be chosen against App Store Connect rather than guessed.

## Locked design rules

- Warm white identifies the one primary action in a state.
- Persistent selection never uses a warm-white fill.
- Selected option: one trailing checkmark.
- Playing row: one style-accent waveform.
- Local mode: one selected container.
- Style accent is content identity/progress, not global navigation chrome.
- Quiet Stage has canvas, content surface, and structurally raised surface only.
- Native utility chrome and system dialogs may remain adaptive/native when intentional.
- Immersive video remains black-framed and may use white over-video controls.
- Do not force every surface onto Quiet Stage merely to remove `Color(.systemBackground)`; classify the semantic context first.
- Every state remains understandable without color alone.
- Minimum interactive target is 44×44 points.
- Reduce Motion preserves orientation and outcome without travel.
- One code path per action.

## Product assumption for this release

This plan uses the smallest truthful paywall cut:

- Free: up to 10 videos and 1 active dance style.
- Paid non-consumable: unlimited videos and unlimited styles.
- Existing v1.0 users: permanent legacy-unlimited access.
- iCloud cleanup: deferred and removed from all release-facing paywall/product copy.

This keeps the paywall meaningful without pulling the high-risk iCloud file-migration feature into the release. Do not silently change this scope.

## Route and model tier

**Route: Phased.** One retained-context implementation agent should execute P0–P4 sequentially. The phases share the same SwiftUI hierarchy, environment objects, UI fixtures, StoreKit surface, and tests. Multiple cold agents would reread the same files and risk conflicting design or entitlement paths.

**Cheapest reliable tier: Standard.** Recommended: Claude Sonnet 4.6 or Codex `gpt-5.5` with medium reasoning. Do not give the whole plan to an economy/Haiku agent: design judgment, legacy entitlement behavior, StoreKit transactions, and release submission have expensive failure modes. Economy may be used only for a mechanical screenshot-name/doc-string cleanup after the standard agent has fixed the semantic design.

Escalate to a premier agent only if implementation reveals:

- A required SwiftData schema migration.
- A data-loss risk in video-cap enforcement.
- A need to change the locked paywall scope.
- Conflicting receipt/grandfathering behavior that cannot be resolved from StoreKit 2 documentation.

## Approval gates

| Gate | Required approval/evidence | Blocks |
|---|---|---|
| G1 | Existing Groups 0–5 diff summarized; full tests green; Adrian authorizes baseline commit if not already authorized in the implementation session. | C1 baseline commit |
| G2 | Adrian accepts this release cut: unlimited videos/styles only; iCloud cleanup removed from paywall/product copy. | P2 paywall implementation |
| G3 | App-wide coverage matrix and representative screenshots reviewed; no unclassified user-facing surface remains. | P3 final integration |
| G4 | Exact TestFlight build passes real-device new-user, legacy-user, purchase, and restore smoke tests. | App Review submission |
| G5 | Adrian explicitly authorizes push and App Review submission/release action. | Push/submission/release |

If the implementation-session prompt already explicitly authorizes a gate, record that authorization in `## Handoff`; do not ask twice.

## Phases

| ID | Phase | Tier | Depends on | Output / handoff |
|---|---|---|---|---|
| P0 | Reconcile and commit all current in-flight Groups 0–5 work | Standard | — | Clean verified baseline commits; migration docs reflect reality |
| P1 | App-wide design-system coverage and UI polish | Standard | P0 | Coverage matrix, consistent app-wide UI, screenshots, accessibility evidence, atomic commit |
| P2 | Finish the entitlement-backed paywall | Standard | P1, G2 | Truthful paid product, centralized access policy, StoreKit tests, atomic commit |
| P3 | Integrated release-candidate QA and polish | Standard | P2, G3 | Clean release candidate with final regression/a11y/visual evidence, atomic fix commit if needed |
| P4 | App Store/TestFlight release preparation and submission | Standard + Adrian gates | P3 | Archive, uploaded build, sandbox validation, metadata/IAP submission package, release |

Do not parallelize P1 and P2: onboarding and paywall share `OnboardingFlow`, `Theme`, environment state, UI fixtures, and screenshots. Do not parallelize P3/P4 with implementation because the exact final binary must be tested.

---

## P0 — Reconcile and commit in-flight work

### Objective

Turn the existing approved dirty Groups 0–5 work into a verified, documented baseline without changing approved behavior or losing user changes.

### Steps

1. Run `git status --short` and save the output in the plan handoff.
2. Read the current full diff before editing. Treat all pre-existing modifications as user-owned and intentional.
3. Confirm there are no remaining references to:
   - `Theme.rowActiveBackground`
   - `Theme.nowPlayingIndicator`
   - `LibraryPlaybackCuePolicy`
   - `stageSelectionSurface`
   - `-Five67UITestReviewOnboardingCompletion`
   - Group 4 test/screenshot fixture names
4. Update migration documentation so it says Groups 0–5 are implemented, while preserving the historical group plan and deferred decisions.
5. Confirm the Group 3 decision remains final: Loop is the only looping control; do not restore “Practice this loop.”
6. Run:

   ```bash
   make build
   make test
   git diff --check
   ```

7. Inspect `build/logs/*.pretty.log` first. Do not claim success if signing, simulator, Xcode, or environment failures blocked a command.
8. Use explicit atomic commits; never `git add .`.

### Commit boundaries

Prefer these two commits:

1. `Agent <name>: add v1.1 release closure plan`
   - `specs/0006-release-closure.plan.md`
2. `Agent <name>: complete Warm Stage migration`
   - every existing Groups 0–5 source/test/design-doc file, explicitly listed to `scripts/atomic_commit.sh`

If Adrian wants the plan kept uncommitted, omit commit 1 and record that choice.

### P0 acceptance criteria

- Groups 0–5 compile and all tests pass.
- `git diff --check` passes.
- Migration docs no longer claim implementation has not started.
- No obsolete aliases/fixtures remain.
- Commits contain only explicitly listed files.
- `git status --short` contains no unexplained pre-P1 modifications.

---

## P1 — App-wide design-system coverage and polish

### Objective

Prove and implement the new design system across the entire user-facing app, not only the three original migration surfaces. “Covered” means each surface either uses the approved Warm/Quiet Stage recipe or has a documented reason to remain immersive/native utility chrome.

### First output: coverage matrix

Create `docs/design-system-coverage.md` with one row per surface and these columns:

| Surface | Entry/state | Visual context | Primary action | Selection/current cue | Design status | Accessibility status | Evidence |
|---|---|---|---|---|---|---|---|

The matrix must cover at least:

#### Root and global navigation

- `SplashView`
- `MigrationFailureView`
- `RootView`
- Global bottom navigation and add action
- App-level loading and routing/focus destinations

#### Onboarding — every beat

- Hook
- Value-proposition survey
- Pain cards
- Style personalization
- Video-volume personalization
- Payoff
- Photos permission primer/result states
- Single-video seed import, empty/error/cancel states
- Real editor handoff
- Processing moment
- Paywall, unavailable-product, purchasing, pending, failure, restore, and success states
- Completion → first populated Library state

#### Feed

- Empty feed
- Populated immersive feed
- Top/bottom chrome and progress rail
- Swipe/tap coaching overlays
- Action tray
- Import actions
- Loading/playback errors
- Completion return state

#### Library and import

- Library Moves and Videos modes
- Search, empty search, filters, grouped content
- Playing row and inactive rows
- `VideoRowView`
- `ImportPreviewSheet`
- Rename, exclude/include, delete confirmation, export entry

#### Practice/editor

- Immersive hero and controls
- Trim track and handles
- Active/inactive move rows
- Split, loop, rename, exclude/include, delete
- Empty moves state
- Completion and back-navigation state

#### Style and shared surfaces

- `StylePickerPaneView`
- `NowPlayingStripView`
- `RenameSheet`
- `StatusPill`
- `PlayerOverlay`
- `VideoHeroView`
- Any alert, confirmation dialog, menu, sheet, or error state reachable in the app

### Implementation rules

1. Audit first; edit after the matrix identifies a real inconsistency.
2. Reuse semantic tokens and existing shared components. Do not add aliases that merely rename colors.
3. Centralize repeated primary-action, selected-row, playing-waveform, and local-mode recipes.
4. Keep system alerts, menus, and destructive confirmations native.
5. Keep immersive video black and its over-video controls legible.
6. Apply Quiet Stage consistently to authored product surfaces, including all onboarding beats and paywall, unless the matrix documents a stronger semantic reason not to.
7. Do not visually communicate the same fact with multiple stacked cues.
8. Preserve stable view identity, playback continuity, focus routing, persistence, and one action path.
9. Replace placeholder-looking onboarding hook/payoff visuals if they remain visually temporary. Use existing real app content or a checked-in branded asset; do not ship test fixtures or fake user content.
10. Update screenshot/UI tests that intentionally encode final treatments; avoid brittle pixel-coordinate assertions.

### P1 verification

Run and record:

```bash
make build
make test
make run-fresh
git diff --check
```

Perform simulator walkthroughs for:

- Complete clean-install onboarding, including cancel/retry on seed import.
- Onboarding → populated Library.
- Library Moves/Videos, search, filter, rename, exclude/include, delete confirmation.
- Library → practice → completion → changed Feed result.
- Empty Feed, populated Feed, coaches, action tray, and import.
- Style picker and export entry.
- Migration failure state through a safe UI fixture if one exists; do not corrupt real data to trigger it.

Exercise:

- Default Dynamic Type.
- One accessibility Dynamic Type size.
- Reduce Motion.
- Increase Contrast.
- VoiceOver labels, values, focus landing, and named actions.
- Color and grayscale screenshots.
- Minimum 44×44-point targets.

Capture representative final screenshots under `build/release-evidence/design/`; do not commit build artifacts unless Adrian explicitly requests it.

### P1 acceptance criteria

- `docs/design-system-coverage.md` contains every reachable surface and no “unreviewed” rows.
- All onboarding beats and paywall use a coherent final design.
- Utility/native and immersive exceptions are intentional and documented.
- No state relies only on color.
- No visible placeholder/mock content remains in a shipping flow.
- Full build/tests and focused journeys pass.
- Atomic commit: `Agent <name>: apply Warm Stage across the app`.

---

## P2 — Finish the entitlement-backed paywall

### Objective

Make the $6.99 non-consumable a truthful, durable product rather than a transaction-only UI.

### Required product behavior

1. **Free access:** maximum 10 videos present in the library; maximum 1 active dance style.
2. **Paid access:** unlimited videos and styles.
3. **Legacy access:** existing v1.0 users remain unlimited permanently.
4. **Existing content safety:** never hide, lock, or delete videos/moves already present. A free user already above a cap may continue viewing/editing existing content; block only the next additive action.
5. **No destructive cap escape prompt:** do not suggest deleting a video to free a slot. If deletion is independently initiated, clearly state how many named moves it removes.
6. **Restore:** available from onboarding paywall and a durable post-onboarding location such as the Style pane/unlock sheet.
7. **Paywall entry:** cap hits and the durable unlock entry present the same canonical paywall component.
8. **Truthful copy:** remove iCloud cleanup from `OnboardingFlow`, `Five67.storekit`, App Store IAP metadata, screenshots, and review notes for this release.

### Architecture constraints

- Introduce one canonical access-policy path used by import and style-selection actions.
- `UnlockStore` remains the StoreKit transaction/entitlement owner.
- Do not scatter `isUnlocked` checks through unrelated views.
- UI affordances call the same import/style action implementation used elsewhere.
- Use StoreKit 2 verified `Transaction.currentEntitlements` for paid state.
- Listen to `Transaction.updates` and finish verified relevant transactions.
- Handle purchase success, cancellation, pending/Ask to Buy, unverified, failure, restore success, restore-none, revocation, relaunch, and product-unavailable states.
- Do not hardcode a localized price when the product fails to load. Show product-derived `displayPrice` only when available.

### Grandfathering requirements

- Persist a permanent `legacyUnlimited` decision after first evaluation.
- In production, use StoreKit 2 app transaction/receipt original-version evidence to recognize pre-freemium installs.
- Scope receipt-based version logic so Xcode StoreKit and TestFlight sandbox do not falsely grandfather every tester.
- Also grandfather an existing non-empty library at migration, as locked in spec 0005.
- Add focused tests for production/sandbox environment distinctions and existing-library detection.
- Do not perform a SwiftData schema migration solely to store the entitlement; use an appropriate durable app preference plus StoreKit receipt state.

### Enforcement points

Audit and cover every path that can add a video or activate/create a style:

- Onboarding seed import: remains one video and must never hit the paywall.
- Feed Photos import.
- Feed Files import.
- Any Library/add-button import path.
- Style creation/selection/tagging from onboarding, Style pane, Library, and editor.
- Test fixtures must explicitly choose free, paid, or legacy state.

Do not create separate cap state machines for each entry point.

### StoreKit tests

Add StoreKitTest-backed coverage where supported and focused logic tests for injected transaction/access states. Cover:

- Product loads and localized price renders.
- Successful purchase unlocks immediately.
- Cancel keeps free behavior and produces no false error.
- Pending leaves access unchanged and explains pending state.
- Failed/unverified purchase leaves access unchanged.
- Current entitlement restores after relaunch.
- Restore succeeds after clearing local state.
- Restore-none is understandable.
- Revoked/refunded entitlement removes paid access unless legacy-unlimited.
- Existing v1.0 user is legacy-unlimited.
- Fresh sandbox/TestFlight user is not falsely grandfathered.
- Video 1–10 import normally; video 11 presents paywall without importing.
- Paid/legacy user can import video 11.
- First style works free; second style presents paywall without losing the user's intended choice/context.
- Existing above-cap content remains accessible and unchanged.

### Runtime StoreKit verification

1. `make run-xcode` with `Five67.storekit`:
   - Purchase.
   - Cancel.
   - Pending/Ask to Buy.
   - Failed transaction.
   - Restore.
   - Refund/revocation if available in StoreKit Transaction Manager.
2. Launch without a StoreKit configuration and verify graceful product-unavailable behavior.
3. After App Store Connect configuration, test the real product through a TestFlight build on a physical device. TestFlight uses sandbox and must not charge.

### P2 verification

```bash
make build
make test
git diff --check
```

Then complete the runtime StoreKit matrix above and save concise results under `build/release-evidence/storekit/`.

### P2 acceptance criteria

- The unlock changes real behavior.
- All additive paths use one access policy.
- Existing data is never removed or hidden by caps.
- Grandfathering is durable and sandbox-safe.
- Purchase and restore work after relaunch.
- Paywall advertises only unlimited videos/styles.
- StoreKit automated tests and runtime scenarios pass.
- Atomic commit: `Agent <name>: finish the 567 lifetime unlock`.

---

## P3 — Integrated release-candidate QA and polish

### Objective

Test the combined design and monetization build as users and App Review will experience it, fix only concrete release defects, and freeze the release candidate.

### Test matrix

#### Install/upgrade cohorts

- Fresh free install.
- Fresh install that purchases during onboarding.
- Fresh install that skips, later hits video cap, then purchases.
- Fresh install that skips, later selects a second style, then purchases.
- Existing v1.0 user with content → legacy unlimited.
- Existing v1.0 user with an empty library, using production receipt evidence.
- Paid user after app reinstall → restore/current entitlement.
- Product unavailable/offline.

#### Device/configuration matrix

- Current small supported iPhone simulator.
- Current 6.9-inch iPhone simulator for screenshots.
- Physical iPhone through TestFlight in P4.
- Default and accessibility Dynamic Type.
- Reduce Motion on/off.
- Increase Contrast on/off.
- VoiceOver critical journeys.
- Color and grayscale review.

#### Critical journeys

- Full onboarding with seed import, editor, processing, paywall skip/purchase, and first Library result.
- All import entry points under free, paid, legacy, limited Photos access, cancel, duplicate, and failure conditions.
- Library search/filter/rename/exclude/include/delete.
- Playback continuity Library → practice → completion → Feed.
- Loop remains the only loop control.
- Restore purchase after onboarding.
- App relaunch preserves onboarding, entitlement, selected style, Library mode, playback destination, and data.

### Release-candidate gates

```bash
make doctor
make build
make test
git diff --check
```

- Review focused `.pretty.log` files and archive raw logs.
- Confirm no warnings introduced by this milestone.
- Confirm no placeholder strings/assets/test arguments leak into release behavior.
- Search for debug logging, hardcoded price copy, stale iCloud paywall claims, TODO/FIXME release blockers, and obsolete Group names.
- Inspect the built app's `PrivacyInfo.xcprivacy` and Info.plist.
- Confirm only justified entitlements/capabilities exist.
- Confirm forced Dark appearance is deliberate and every screen is legible in that appearance.

### P3 acceptance criteria

- All matrix rows pass or have an explicit Adrian-approved defer.
- App-wide coverage matrix matches the final UI.
- Final color/grayscale screenshots show no color-only state.
- No known data-loss, paywall, restore, navigation, accessibility, or placeholder-content defect remains.
- Worktree is clean after an atomic release-fix commit, or no commit is needed.
- Candidate commit SHA is recorded in `## Handoff`.

---

## P4 — TestFlight, App Store review, and release

### Objective

Archive, upload, validate, and submit the exact release candidate and its first non-consumable IAP.

### App Store Connect/IAP preparation

For `com.nopalstudio.five67.unlock`:

- Type: non-consumable.
- Price: configured in App Store Connect; app displays StoreKit's localized price.
- Family Sharing: confirm intended setting is enabled.
- Localized display name/description mention only unlimited videos and styles.
- Availability/territories configured.
- Review screenshot shows the real final paywall.
- Review notes explain how to reach the paywall, skip it, hit both caps, restore, and verify unlocked behavior.
- Status is Ready to Submit before app submission.
- Because this is the app's first IAP, submit it with the new app version.

### App metadata/privacy review

- Choose the next unused marketing version in App Store Connect, then update `project.yml`; regenerate the project and verify generated `Info.plist` values.
- Build number remains derived from git commit count; confirm the resulting build number is accepted and greater than prior uploaded builds.
- Screenshots show the actual final UI and no unshipped iCloud cleanup or smart-import feature.
- App description contains no hardcoded price.
- Privacy policy is reachable in App Store Connect and from the app if the current product requires it.
- Privacy nutrition label still matches on-device-only behavior.
- `PrivacyInfo.xcprivacy` declares actual required-reason APIs and no tracking.
- No ATT prompt unless cross-app tracking exists; this release should not add tracking.
- `NSPhotoLibraryUsageDescription` accurately describes import behavior.
- Encryption, age rating, category, territories, and support URL remain correct.

### Archive and TestFlight

1. Ensure P3 candidate is committed and the worktree is clean.
2. Run a Release archive using the `Five67` scheme and org team `HML25PC4DU`.
3. Validate the archive before upload; record warnings and validation output.
4. Upload to App Store Connect/TestFlight.
5. Wait for processing; do not test a locally rebuilt binary instead.
6. Install the exact TestFlight build on a physical iPhone.
7. With a fresh sandbox-capable user/install, test:
   - Product load and localized price.
   - Purchase and immediate unlock.
   - Relaunch entitlement.
   - Restore on a clean install.
   - Free cap behavior before purchase.
8. With an upgrade/legacy fixture or real eligible account, test grandfathering separately.
9. Repeat the critical onboarding, Library, practice, and accessibility smoke paths.
10. Record the TestFlight build number, device/OS, account cohort type, and result.

### Submission and release

- Gate on G4 and G5.
- Push the committed release branch only after explicit authorization.
- Attach the first IAP to the new version submission.
- Add concise App Review notes explaining the on-device app, Photos import, paywall paths, free limits, lifetime unlock, and restore location.
- Submit the app version and IAP for review together.
- After approval, release according to Adrian's chosen manual/phased/automatic release setting.
- Record App Store Connect status and any reviewer communication in `docs/launch-punch-list.md`.

If App Store Connect or signing access is unavailable, do not claim release. Mark P4 blocked with the exact missing account role, certificate, IAP metadata, device, or signed-in session required.

### P4 acceptance criteria

- Release archive validates and uploads.
- The exact TestFlight build passes physical-device and sandbox purchase/restore testing.
- IAP metadata is complete and truthful.
- App metadata/screenshots/privacy declarations match the submitted binary.
- App and first IAP are submitted together after approval.
- Final repository state is committed and, if authorized, pushed.
- Release status is recorded accurately.

---

## Whole-effort acceptance criteria

- No unexplained dirty files remain.
- Groups 0–5 and this milestone are represented by atomic commits.
- Every reachable app surface appears in `docs/design-system-coverage.md` with an intentional recipe.
- Every onboarding beat, including the paywall, matches the approved design language.
- The paywall unlocks real functionality and makes no unimplemented claims.
- Legacy users retain unlimited access and existing content is safe.
- Purchase, restore, pending, cancellation, failure, revocation, and unavailable-product states behave correctly.
- Full automated tests, focused UI journeys, accessibility variants, visual comparisons, Release archive validation, and TestFlight real-device tests pass.
- The submitted screenshots and metadata describe only features in the binary.
- The app and its first IAP reach App Review together, and release status is reported honestly.

## Progress

| ID | Status | Owner/session | Last update | Notes |
|---|---|---|---|---|
| P0 | done | Codex implementation session | 2026-07-16 | Green build/tests/diff check; plan commit `9792afc`; exact Groups 0–5 baseline commit `2bad989` |
| P1 | done | Codex implementation session | 2026-07-16 | Complete coverage matrix, Warm Stage implementation, accessibility/visual evidence, build/test/fresh-launch verification; atomic commit pending below |
| P2 | pending | - | - | Entitlement-backed paywall; Gate G2 required |
| P3 | pending | - | - | Integrated release-candidate QA |
| P4 | pending | - | - | TestFlight/App Review; Gates G4–G5 required |

Status values: `pending`, `in-progress`, `blocked`, `done`.

## Handoff

Current state: P0 is complete at clean commit `2bad989`; P1 implementation and verification are complete and ready for the required atomic commit. The implementation session began from the exact intentional Groups 0–5 dirty baseline recorded in `Current state snapshot`; all tracked diffs and untracked design artifacts were reviewed, and the 16 source/test files remained byte-for-byte identical to their recorded SHA-256 baseline through the P0 verification and commit boundary.

Next step: create the P1 atomic commit, record its SHA here, then stop. P2 must not begin until Adrian authorizes G2. P3 must not begin until Adrian reviews the P1 coverage matrix/screenshots and satisfies G3.

Files changed in P0: the existing Groups 0–5 source/test/design baseline was committed exactly as reviewed; stale migration-status wording was reconciled in `docs/design-migration.md`, `docs/README.md`, and `docs/design-foundation-brief.md`; this plan records progress and evidence.

Files changed in P1: `docs/design-system-coverage.md` classifies every reachable surface; `Theme.swift` centralizes the Warm Stage selectable-row and secondary-action recipes; onboarding and splash now use the Warm Stage throughout, checked-in 567 artwork, the exact approved two-card pain beat, non-placeholder payoff art, and Reduce Motion/accessibility semantics; Styles and import preview use the shared stage recipe; Feed removes the decorative gradient/glow and adds playback recovery; shared status, export-progress, and video-row semantics are no longer color-only or forced-motion; deterministic UI review fixtures and two focused P1 UI journeys cover the final treatments.

P1 checks run (2026-07-16):

- `make build` — passed; `build/logs/build.pretty.log` ends in `Build Succeeded`.
- Focused onboarding UI journey — passed after correcting the approved pain beat and making the review fixture reset persisted survey answers; 1 test, zero failures.
- `make test` — passed; all Swift Testing suites and all 15 `TabBarVerifyTests` UI tests completed with zero failures. The accepted V3→V4 migration known-issue `duplicate ZSTYLE` diagnostics remain unchanged and outside P1.
- `make run-fresh` — passed; uninstalled the app/data, rebuilt, installed, and launched the clean-install Warm Stage onboarding.
- `git diff --check` — passed with no output.
- Simulator accessibility/visual exercise — default and accessibility XXXL Dynamic Type, Reduce Motion, Increase Contrast, selected traits/named actions/focus discovery in UI tests, 44-point minimum actions, and color/grayscale screenshot inspection all passed.

P1 evidence is stored in ignored `build/release-evidence/design/`: final clean hook, pain, payoff, unavailable-product paywall shell, populated Library, Feed, Styles, add-video dialog, accessibility XXXL, Reduce Motion, Increase Contrast, and grayscale captures. Native Photos/StoreKit transactions, migration failure, playback failure, export progress, and the preview-only import summary were not artificially forced; `docs/design-system-coverage.md` records the exact code-review/runtime boundary. StoreKit behavior remains P2-owned behind G2.

Checks run (2026-07-16):

- `make build` — passed; `build/logs/build.pretty.log` ends in `Build Succeeded`.
- `make test` — passed; all Swift Testing suites and all 13 `TabBarVerifyTests` UI tests completed with zero failures. The accepted V3→V4 migration known-issue diagnostics remain unchanged and are outside this milestone.
- `git diff --check` — passed with no output.
- Obsolete-symbol/fixture search — no matches in `Five67`, `Five67Tests`, or `Five67UITests`. Historical migration docs intentionally retain former token/group names. The UI suite asserts that “Practice this loop” is absent and Loop remains the only looping control.
- Post-verification SHA-256 comparison — all 16 pre-existing source/test files match the pre-edit inventory exactly.

P0 commits:

- `9792afc` — `Agent Codex: add v1.1 release closure plan`
- `2bad989` — `Agent Codex: complete Warm Stage migration`

P0 boundary status: `git status --short` produced no output immediately after `2bad989`; there were no unexplained pre-P1 modifications.

Initial `git status --short` (2026-07-16, before implementation edits):

```text
 M Five67/App/Five67App.swift
 M Five67/Services/AppRouter.swift
 M Five67/Services/StyleStore.swift
 M Five67/Views/Feed/VideoFeedView.swift
 M Five67/Views/Library/LibraryPaneView.swift
 M Five67/Views/Onboarding/OnboardingFlow.swift
 M Five67/Views/Onboarding/OnboardingGateView.swift
 M Five67/Views/Root/RootView.swift
 M Five67/Views/Shared/PlayerOverlay.swift
 M Five67/Views/Shared/Theme.swift
 M Five67/Views/Shared/VideoHeroView.swift
 M Five67/Views/VideoDetail/MoveRowView.swift
 M Five67/Views/VideoDetail/TrimTrackView.swift
 M Five67/Views/VideoDetail/VideoDetailView.swift
 M Five67Tests/OnboardingTests.swift
 M Five67UITests/TabBarVerifyTests.swift
 M docs/README.md
 M docs/brand.md
?? docs/design-decisions.md
?? docs/design-foundation-brief.md
?? docs/design-foundation/
?? docs/design-migration.md
?? docs/design-system.md
?? specs/0006-release-closure.plan.md
```

Approval record:

- **G1 authorized (2026-07-16):** Adrian explicitly instructed this implementation session to implement the plan sequentially beginning with P0, preserve the approved Groups 0–5 baseline exactly, and obey the approval gates. This authorizes the P0 baseline commits after the required evidence is green.
- **G2 not yet authorized:** do not begin P2 paywall implementation until Adrian explicitly accepts the unlimited-videos/styles-only release cut and removal of iCloud cleanup copy.
- **G3–G5 not yet authorized/satisfied.**

Open questions:

1. Gate G2: confirm the release paywall should sell unlimited videos/styles only and remove the unimplemented iCloud cleanup claim.
2. Gate G5: confirm whether the implementing agent may push and submit, or must stop after TestFlight validation for Adrian to perform final submission.
