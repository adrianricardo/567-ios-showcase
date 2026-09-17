# 567 iOS design migration

> **Status: Groups 0–5 implemented and approved (2026-07-16).** The staged plan below is preserved as the historical implementation record. App-wide coverage beyond these original migration groups remains separately scoped in `specs/pending/0006-release-closure.plan.md` P1.

## Implementation record

- Groups 0–3 established the approved tokens and primitives, onboarding style selection, Library organization, and practice/video-detail treatments.
- Group 4 completed the onboarding → Library, Library → practice, and practice → changed Feed-result continuity pass.
- Group 5 removed obsolete aliases and fixtures and completed focused visual, motion, contrast, accessibility, build, and test verification.
- The final Group 3 product decision is that **Loop is the only looping control**. The proposed “Practice this loop” action was not restored.
- Broader authored surfaces—including the remaining onboarding beats, paywall, import/status sheets, root states, and shared utility surfaces—were intentionally outside Groups 0–5 and are audited in release-closure P1 rather than being silently treated as complete.

## Migration rules

- One code path per action; design changes must not introduce parallel state machines or fallback UI.
- Preserve SwiftData behavior and playback behavior. A visual migration must not alter data ownership, persistence, clipping, or navigation semantics.
- Make each group independently buildable and reviewable.
- Compare color and grayscale captures. Verify “What would you tap next?” and “What is current?” without explaining the screen.
- Do not migrate unrelated utility/settings surfaces merely for visual consistency.

### Required Family Values pass in every group

Every surface group must answer three questions before its visual review gate:

1. **Simplicity:** What can stay hidden until relevant, and is there exactly one obvious next action?
2. **Fluidity:** Which elements persist or travel into the next state, and does every transition preserve orientation?
3. **Delight:** Which frequent interactions need subtle tactile polish, and is there a rarer completion/first-use moment worth stronger emphasis?

“No additional delight needed” is a valid answer when efficiency is the better experience. The pass must produce intentional decisions, not mandatory animation.

## Group 0 — Token and primitive preparation (implemented)

Scope:

- Split/rename `stageSelectionSurface` into `stageActionSurface`.
- Add focused reusable styles only where they remove duplication: primary action, selectable row checkmark, playing waveform, local mode selector.
- Keep existing POC aliases temporarily only when required for an atomic group; remove them by the final cleanup group.

Verification:

- `make build`
- `make test`
- Contrast tests for stage ink/action fill and approved accents.

Review gate: token diff and isolated component states; no screen-wide rollout yet.

## Group 1 — Onboarding dance-style selection (implemented)

Scope:

- Keep all rows on the same graphite surface.
- Show one trailing checkmark for the chosen style.
- Remove visible “Selected” copy, leading notch, selection fill, and redundant selection summary in the Continue action.
- Preserve single-selection persistence, full-row tap target, `.isSelected`, haptic, and Reduce Motion behavior.
- Keep stable onboarding elements in place between beats and move only the content that changes.
- Treat first-value/onboarding completion as a candidate for stronger but brief delight; ordinary style selection stays subtle.

Verification:

- `make test`
- `make run-fresh`
- VoiceOver: row label + selected trait, no duplicate “selected” announcement.
- Dynamic Type and grayscale captures.
- Half-speed transition review across adjacent onboarding beats.

Visual review gate: approve onboarding before touching Library.

## Group 2 — Library / home organization (implemented)

Scope:

- Use one selected container for Moves/Videos mode; remove extra underline/tint.
- Use one trailing style-accent waveform for the currently playing item; remove light active-row fill, rail, and visible “Playing” copy.
- Keep style identity dot and style filter as metadata, not state indicators.
- Preserve row actions, search, grouping, playback routing, and native neutral tab chrome.
- Preserve context when a move opens practice/detail; use shared geometry or the smallest native transition that visibly connects the row to its destination.
- Give empty/first-library states authored guidance; keep repeat browsing and filtering fast and quiet.

Verification:

- `make build`
- Focused library/playback tests.
- Manual row selection, rename, exclude, delete, search, and tab routing.
- VoiceOver value “Playing” on the active row; grayscale capture.
- Half-speed review of mode changes and Library → practice/detail continuity.

Visual review gate: approve Library before touching practice/video detail.

## Group 3 — Practice / video detail (implemented)

Scope:

- Adopt solid Quiet Stage content surfaces below the immersive video.
- Use style accent for progress and one waveform for the active clip.
- Add one warm-white Practice action only where it matches the existing product flow; do not invent a second playback state machine.
- Keep editing and destructive actions secondary/native.
- Keep the video and persistent playback controls visually continuous when entering clip/detail states; avoid remount-like flashes.
- Use subtle feedback for frequent loop actions and reserve stronger delight for first clip or meaningful practice completion.

Verification:

- `make build`
- Playback, seeking, loop, split, rename, exclude, delete, and back-navigation checks.
- Reduce Motion, VoiceOver, Dynamic Type, and grayscale capture.
- Half-speed review of Library/feed → detail, clip activation, and completion transitions.

Visual review gate: approve immersive practice before broader cleanup.

## Group 4 — Cross-surface continuity and delight pass (implemented)

Scope:

- Review onboarding → first library, Library → practice/detail, and practice completion → return destination as connected journeys.
- Ensure loading, completion, and focus land where the result now lives.
- Remove teleporting or redundant animations; keep persistent elements stable.
- Calibrate delight by frequency and remove any effect that competes with practice.
- Do not add new product features or propagate the visual system beyond the three approved surface groups.

Verification:

- Record the three journeys and review at normal speed and 0.5×.
- Verify Reduce Motion substitutions preserve orientation and outcome clarity.
- Run the two comprehension checks without explanation: “What would you tap next?” and “What changed?”

Visual review gate: approve the connected experience before cleanup.

## Group 5 — Focused cleanup (implemented)

Scope:

- Remove obsolete POC aliases and duplicated component styling from the migrated surfaces.
- Search for warm-white fills used as persistent state and review each occurrence deliberately.
- Update tests and screenshots that encode superseded treatments.
- Do not propagate into settings, exports, paywall, or unrelated sheets without a separate scoped decision.

Verification:

- `make build`
- `make test`
- Targeted simulator walkthrough of the three approved surfaces.
- Accessibility Inspector audit and final color/grayscale comparison.

## Deferred decisions

- Whether Library is the product home or an organization destination beside Feed remains an information-architecture question, not a blocker for the visual recipes.
- Broader system-utility styling and paywall treatment require separate scope and evidence.
- App-wide migration and autopilot require explicit authorization after this plan is reviewed.
