# 0008 — Guided segment splitting and timing adjustment tutorial

**Status:** Approved scope on 2026-07-27; revised 2026-07-28 after a frame-level
review of the reference. P1 is preserved on `codex/segment-splitting-tutorial`
at `c003b9d` but is not merge-ready; P2–P5 remain.

## Current implementation and repository cleanup

On 2026-09-17, the P1 state reducer, static tutorial card, Reduce Motion
composition, `VideoDetailView` integration, tests, and this plan were preserved
in commit `c003b9d` on `codex/segment-splitting-tutorial`. The branch is pushed
to `origin` and checked out at `build/segment-tutorial-worktree`.

Commit `f34b7c9` was mislabeled as removing the demo-video fallback; its only
change enabled `guidedTutorial: .onboarding` without committing the supporting
implementation. Forward repair `8f08b35` removed that activation from `main`,
and the P1 implementation was removed from the active working tree after its
preservation was verified. No history was rewritten.

A clean checkout of `8f08b35` passed `make build`, `make test`, and
`git diff --check`: the unit run reported 54 tests with six existing known
migration issues, and all 27 UI tests passed. Adrian reviewed milestone 1 and
authorized its push on 2026-09-17. This verifies the repaired release line,
not completion of the tutorial.

P1 intentionally renders a static finished miniature. The P2 animation and P3
production split/divider event wiring are not implemented yet.

Remaining completion order:

1. Continue on `codex/segment-splitting-tutorial`. When integrating the finished
   feature with current `main`, explicitly restore the onboarding opt-in:
   merging alone can retain `main`'s removal of that call-site argument.
2. Implement and visually verify P2 motion choreography.
3. Wire P3 to successful production split and meaningful divider-adjustment
   events using the existing editor paths.
4. Complete P4 accessibility/gesture hardening and P5 end-to-end coverage.
5. Run `make build`, `make test`, `git diff --check`, and the focused simulator
   matrix before merging the feature branch.

**Repository:** `~/Code/567-ios`

**Reference:** `~/Downloads/shuffles-2.mp4` — a 7.28-second,
1180×2556, 60 fps tutorial loop (Pinterest Shuffles "Tune your feed"
onboarding) that uses a dimmed background, one focused card, a large animated
hand, obvious cause-and-effect, and a seamless reset. Use it as a quality bar,
not as an asset to ship.

### What the reference actually does

Verified by frame extraction on 2026-07-28. These are the structural decisions
this plan copies, and the reasons they matter:

- The real screen is dimmed behind the card, but the screen's own top chrome
  (title, subtitle, and **Skip**) stays legible and lives **outside** the card.
- The card is two stacked panels: an illustration area on top, an information
  panel below carrying the headline, two lines of copy, and **one** primary
  button.
- **The animation is an abstract miniature inside the illustration panel.** A
  small phone-shaped card stands in for real content. It is emphatically *not*
  a scale-accurate replica of the real UI behind the scrim. This is why the loop
  reads instantly: the motion is enormous relative to its own bounded frame.
- The card copy is **static** for the entire loop. There are no per-beat
  captions.
- The loop is roughly **four beats with long holds**, not a dense sequence. The
  result state alone holds for over a second.
- The hand is an oversized outlined pointer with a drop shadow that never
  leaves the card.
- There is **no success cue**. The reference simply holds the resulting state.
  This plan intentionally adds a restrained one.
- In the reference, the primary button merely dismisses to the live screen.
  The live guided interaction in this plan is a deliberate addition with no
  reference precedent — see “Live guided interaction”.

## Goal

Teach a first-time user the complete segment-editing mental model inside the
onboarding editor:

1. Find the moment where one move ends.
2. Tap **Split** to turn one video range into two segments.
3. Drag the divider between the segments to fine-tune the cut.
4. See and feel that the adjustment changed the real move timing.

The tutorial should match the reference's motion quality and exceed it in
learning value by moving directly from a short demonstration into a real,
guided interaction on the user's imported video.

## User outcome

After the guided editor beat, the user should understand:

- **Split creates a boundary at the current playback position.**
- **The boundary is adjustable.** Dragging the divider changes the end of the
  segment before it and the start of the segment after it.
- The operation is reversible and precise; an imperfect first split is not a
  mistake they must delete and redo.

The tutorial should call the draggable object the **divider**, **boundary**, or
**segment edge**. It must not imply that the whole segment can be picked up and
reordered; the current product adjusts adjacent timing through the shared
boundary.

## Non-goals

- Do not add segment reordering.
- Do not add overlapping segments, gaps, ripple editing, or a second trimming
  model.
- Do not duplicate split or boundary-adjustment persistence logic for the
  tutorial.
- Do not mutate the user's `Move` records while the scripted demonstration is
  playing.
- Do not require a bundled demo video or reintroduce the superseded demo-import
  path from `specs/done/0007-onboarding-core-ui-redesign.plan.md`.
- Do not add third-party animation frameworks, analytics, accounts, or backend
  work.
- Do not show the full tutorial in every normal editor session. This plan adds
  it to the onboarding guided-editor beat. Replay Onboarding may replay it.
- Do not add unattended haptics during the looping demonstration.

## Locked experience

### Entry

The tutorial begins when onboarding opens the real `VideoDetailView` editor and
the video duration is known. Pause playback while the introduction is visible.
Keep onboarding progress and the editor's existing escape action available.

Present a focused tutorial card over a dimmed editor. The card has two stacked
panels, matching the reference:

- **Illustration panel (top).** Bounded area that contains the entire scripted
  demonstration. Nothing animates outside it.
- **Information panel (bottom).**
  - Headline: **Split your video into moves**
  - Supporting copy: **Find where a move ends, tap Split, then drag the divider
    to fine-tune the timing.**
  - Single primary action: **Try it**

The card carries exactly one action. Do not add a “Skip demo” secondary button.
The existing **I'll do this later** action remains the canonical and only way to
skip editing and continue onboarding, and it stays reachable outside the card
while the demonstration runs — the same relationship the reference has between
its card and the screen-level **Skip**.

### Scripted demonstration

Run a seamless loop of approximately 6.5–7.0 seconds inside the card's
illustration panel.

**Staging: miniature abstraction, not a scale replica.** The loop is a
self-contained miniature scene — a simplified mini-track and playhead sized to
the illustration panel, so the split and the divider drag are large gestures
*within that frame*. It deliberately does not mirror the real timeline's
proportions. A real-proportion track would make the key teaching moment (a
divider moving a few points inside a thin bar) the smallest motion on screen,
which is exactly what the reference avoids. Share theme tokens and the visual
language of the real track; do not share its geometry.

The loop is view-only. It does not insert or update SwiftData models.

**The card's headline and supporting copy never change during the loop.** There
are no per-beat captions. The motion carries the lesson; the copy names it once.

Four beats with generous holds. Resist adding intermediate flourishes — the
reference's clarity comes from how long it rests on each state.

| Time | Demonstration |
|---|---|
| 0.0–1.6 s | One continuous mini-segment settles in. The outlined hand enters and scrubs the playhead to the end of a move; the timestamp tracks with it. |
| 1.6–2.6 s | The hand taps the scissors, which compresses slightly on contact. The single track becomes two segments and a divider appears with one restrained seam glow. |
| 2.6–4.4 s | The hand presses the divider (it grows slightly to show acquisition) and drags it a short distance, then releases. Adjacent segment widths and the timestamp update continuously. No corrective wobble. |
| 4.4–6.3 s | The divider settles with one subtle checkmark or glow, then the finished two-segment state holds — the longest hold in the loop. No confetti, no repeated state cues. |
| 6.3–7.0 s | Crossfade/reset to the initial continuous segment without a visible jump. |

Use a scalable SF Symbol hand with a contrasting outline and small shadow,
matching the reference's legibility without adding a custom animation
dependency. Use `KeyframeAnimator` or a small `PhaseAnimator`/keyframe
composition available on iOS 18; do not drive the sequence with chains of
`DispatchQueue.asyncAfter`.

### Live guided interaction

Tapping **Try it** dissolves the card and moves guidance onto the real editor.
The tutorial becomes progressive, not modal.

This section has **no reference precedent** — in the reference, the primary
button simply dismisses to the live screen. Everything below is the deliberate
“exceed it in learning value” half of this plan, so its motion language must be
derived from the app's existing Quiet Stage rules rather than from the video.
Because the demonstration is a miniature abstraction, expect a deliberate scale
change here; cover the transition with the card dissolve and let the real
timeline's own highlight establish the new frame. Do not attempt to morph the
miniature into the real track.

#### Step 1 — Make the split

- Highlight the real timeline and Split control using geometry anchors rather
  than device-specific offsets.
- Instruction: **Move to the end of a move, then tap Split.**
- The user may play, pause, or scrub normally.
- Tapping the real Split button calls the existing split implementation.
- Advance only after a valid split actually creates a boundary.
- Give the existing medium haptic at the successful split. Do not add a second
  haptic from the tutorial layer.

If Split is attempted too close to the beginning/end or before duration is
available, do not advance. Show brief inline recovery copy:

**Choose a point a little farther from the start or end.**

The normal editor may retain its existing quiet behavior outside tutorial mode.

#### Step 2 — Fine-tune the boundary

- Move the highlight to the newly created divider.
- Instruction: **Drag the divider to fine-tune the cut.**
- Run one small, non-blocking divider nudge to demonstrate direction. Stop that
  nudge as soon as the user touches the track.
- The user drags the actual boundary through `TrimTrackView`'s existing gesture.
- While dragging, keep the current lightweight behavior: pause playback, seek
  to the boundary, update the previous segment's `endTime`, and update the next
  segment's `time`.
- Advance only when the boundary moved by a meaningful amount and the real drag
  completed. A touch without movement does not count.
- Use the existing release haptic only; do not layer another tutorial haptic.

#### Step 3 — Success

On the real completed drag:

- Remove the scrim/highlight with a short smooth transition.
- Show: **Nice — your cut is ready.**
- Keep the edited segment selected or the playhead at the adjusted boundary so
  the result remains legible.
- Keep **Continue** under user control; never auto-advance to the result reveal.

### Existing-content and re-entry behavior

- If the onboarding seed has no real boundary, **Try it** starts at Step 1.
- If an interrupted/replayed onboarding seed already has two or more segments,
  the scripted loop still demonstrates both operations, but the live guidance
  starts at Step 2 on the most relevant existing divider. Do not force another
  split merely to satisfy the tutorial.
- If the user backs out and returns during the same presentation, restarting
  the short demonstration is acceptable. Do not persist a second tutorial
  state machine.
- If the video is too short to create two legal ranges under the editor's
  minimum-duration rules, show the static/reduced-motion explanation and allow
  the user to continue. Do not loosen data-safety clamps for tutorial success.

## Motion and visual rules

- Preserve the app's Quiet Stage hierarchy. The tutorial may dim context, but
  the real timeline and active target remain visually recognizable.
- Use one visible teaching cue at a time: target highlight, hand, or success
  state. Do not stack pulsing rings, arrows, labels, and color to repeat the
  same fact.
- Prefer `.smooth` for card/coach transitions and a restrained `.snappy` spring
  for hand contact, divider acquisition, and the split seam.
- Keep ordinary feedback transitions in the 200–400 ms range.
- Scope implicit animations to their explicit values. Do not apply a broad
  `.animation` to `VideoDetailView` or `TrimTrackView`.
- Animation closures may change only visual values. Do not seek video, save
  models, or perform layout discovery from a per-frame animation closure.
- The auto-loop may be expressive because it is shown once during onboarding.
  Real editor interactions remain calm and responsive.

## Gesture and interaction rules

- Preserve one `DragGesture` owner for the trim track. Do not lay a tutorial
  drag recognizer over the production gesture.
- The scripted hand is hit-test disabled.
- Guidance overlays must either pass touches through to the active target or
  remove themselves before the live step begins.
- Increase boundary acquisition to a 44-point effective target while keeping
  the visual divider narrow. Resolve overlapping boundary hit regions by
  choosing the nearest valid divider.
- Keep continuous drag work lightweight. Model/timestamp updates already needed
  for live feedback may run in `onChanged`; completion bookkeeping and tutorial
  progression happen once in `onEnded`.
- The track's scrub-versus-boundary decision remains single-path: a press within
  a divider target adjusts that divider; another drag scrubs.
- Preserve the existing minimum adjacent segment duration clamp and edge haptic.

## Accessibility contract

### Reduce Motion

When `accessibilityReduceMotion` is enabled:

- Do not run the hand travel, repeating scrub, seam burst, or divider nudge.
- Replace the auto-loop with three static states in the same card:
  **Find the end → Split → Drag the divider**.
- Use a short opacity transition only.
- The live interaction remains available; success is communicated with text,
  final geometry, and the existing user-triggered haptic.

### VoiceOver and Switch Control

The drag gesture needs an equivalent non-drag path:

- Expose each editable divider as an accessibility element named
  **Segment divider** with its timestamp as the value.
- Provide an adjustable action: swipe up/down to move the divider later/earlier
  by a small deterministic increment while applying the same clamping and
  adjacent-range updates as touch dragging.
- Add named actions **Move earlier** and **Move later** if they materially
  improve discoverability.
- Extract one canonical boundary-adjustment method so touch drag and
  accessibility adjustments cannot diverge.
- Announce successful split creation and timing adjustment once. Do not announce
  every continuous drag update.
- Move accessibility focus from the tutorial card to the timeline/Split control,
  then to the new divider, then to the success message.

### Layout

- All actions and divider hit regions are at least 44×44 points.
- Verify the card and live coaching at accessibility-extra-extra-extra-large
  text without clipping or covering the current target.
- Use anchors and safe-area-aware placement on small and large iPhones; do not
  hard-code coordinates copied from the reference video.
- Increase Contrast must preserve target boundaries without adding redundant
  visible selection cues in the default mode.

## Implementation architecture

### New view and state

Add a focused file such as:

`Five67/Views/Onboarding/SegmentSplitTutorialView.swift`

It should contain:

- `SegmentSplitTutorialPhase`
  - `demonstration`
  - `makeSplit`
  - `adjustBoundary`
  - `complete`
  - `dismissed`
- A small, pure event transition function/reducer so progression can be unit
  tested independently of animation.
- `SegmentSplitTutorialCard`, including the reduced-motion static variant.
- A view-only miniature demo model holding normalized (0–1) segment boundaries
  and playhead position, rendered to the illustration panel's own bounds. It may
  share theme tokens, but it must not adopt `TrimTrackView`'s geometry, and it
  must not create fake `Video`/`Move` models or write SwiftData.
- The outlined tutorial hand and keyframe values.
- Target/highlight overlay primitives.

Do not put onboarding flags or scripted fake data branches into production
split persistence.

### `OnboardingFlow`

In `Five67/Views/Onboarding/OnboardingFlow.swift`:

- Pass an explicit guided-segment-tutorial configuration into the editor beat.
- Keep the existing seven-beat onboarding sequence and top progress position.
- Keep both `Continue` and **I'll do this later** behavior routed through the
  existing editor completion path.

### `VideoDetailView`

In `Five67/Views/VideoDetail/VideoDetailView.swift`:

- Own the tutorial presentation only when explicit onboarding configuration is
  present.
- Pause/resume playback deliberately around the introduction.
- Report a successful real split to the tutorial state only after model
  insertion/range update succeeds.
- Pass the new divider identity/index into the adjustment step when practical.
- Connect `VideoHeroView.onHandleDragComplete` to tutorial progression without
  replacing the production callback or gesture.
- Keep normal editor behavior unchanged when tutorial configuration is absent.

Refactor `split()` only as much as necessary to expose success/failure and the
created boundary. The real Split button, empty-state scissors button, and
tutorial-guided Split action must still call the same implementation.

### `VideoHeroView` and target geometry

In `Five67/Views/Shared/VideoHeroView.swift`:

- Preserve its reusable player/track role.
- Surface stable anchors or frames for the timeline, Split button, and divider
  targets as needed by the parent overlay.
- Do not make `VideoHeroView` own onboarding state or copy.

### `TrimTrackView`

In `Five67/Views/VideoDetail/TrimTrackView.swift`:

- Keep the existing scrub/handle drag gesture as the single touch path.
- Expand the invisible divider hit area to meet the 44-point requirement.
- Extend drag-completion reporting with the adjusted divider identity/index and
  whether meaningful movement occurred.
- Extract canonical clamped boundary adjustment so touch drag, VoiceOver
  adjustable actions, and named accessibility actions update the same two
  adjacent moves.
- Emit generic divider geometry/accessibility information; do not import or
  depend on onboarding types.

### Tests

Prefer a new focused unit test file:

`Five67Tests/SegmentSplitTutorialTests.swift`

Extend:

- `Five67UITests/TabBarVerifyTests.swift`
- accessibility/visual suites only where they already own the relevant device
  configurations.

## Phased implementation

### P1 — State contract and static composition

1. Add the tutorial phase/event model and unit tests.
2. Build the two-panel tutorial card with a static miniature
   one-segment/two-segment/adjusted composition in the illustration panel.
3. Add normal and Reduce Motion variants.
4. Integrate the card into the onboarding editor behind explicit
   configuration.
5. Verify **I'll do this later**, Back, and Continue routes, and that
   **I'll do this later** stays reachable while the card is presented.

**Acceptance:** No SwiftData changes occur while the demonstration is visible;
normal editors never show the tutorial; the card carries exactly one action;
`make build` passes.

### P2 — Motion choreography

1. Implement the 6.5–7.0-second keyframe loop in the illustration panel.
2. Add hand contact, split seam, boundary drag, hold, and seamless reset.
3. Confirm the split and drag read as large motions relative to the panel, and
   that nothing animates outside the panel's bounds.
4. Tune on the smallest and largest supported iPhones at normal text size.
5. Confirm the loop remains smooth with the real editor dimmed behind it, and
   that the static copy stays legible for the whole loop.

**Acceptance:** The demonstration clearly communicates both Split and boundary
drag without reading the copy, holds each state long enough to be understood,
remains responsive, and matches the reference's perceived polish.

### P3 — Real “Try it” progression

1. Add target geometry/highlights without hard-coded screen coordinates.
2. Advance from split guidance only on a successful production split.
3. Advance from adjustment guidance only after a meaningful production divider
   drag completes.
4. Handle seeds with existing segments and invalid/too-short split positions.
5. Preserve all existing editor exits and the result reveal.

**Acceptance:** The user performs both real operations through existing code
paths; no tutorial-only model mutation or parallel editor state machine exists.

### P4 — Accessibility and gesture hardening

1. Add the 44-point effective divider target.
2. Add accessible divider elements and adjustable/named actions using the
   canonical boundary-adjustment method.
3. Add focus movement and single success announcements.
4. Verify Reduce Motion, Increase Contrast, VoiceOver, Switch Control reachability,
   and accessibility-extra-extra-extra-large text.

**Acceptance:** A user who cannot drag can complete the same timing adjustment,
and all alternatives modify the same adjacent ranges.

### P5 — Tests and final visual polish

1. Add unit tests for tutorial progression and boundary adjustment.
2. Add focused UI coverage for demonstration → Try it → Split → divider
   adjustment → success → Continue.
3. Capture/review the full loop and reduced-motion states at 60 fps where the
   simulator/device supports it.
4. Remove debug overlays and temporary motion logs.
5. Run the full verification suite once at the end of the coherent UI round.

## Verification matrix

### Unit tests

- Demo event → `makeSplit`.
- Valid real split → `adjustBoundary`.
- Invalid split does not advance.
- Meaningful real boundary drag → `complete`.
- Tap/no movement does not complete the drag step.
- Existing two-segment seed starts live guidance at adjustment.
- Tutorial configuration absent → no tutorial state/presentation.
- Touch and accessibility boundary adjustment share clamp behavior.
- Adjustment never crosses the minimum adjacent segment duration.

### UI journeys

- Fresh onboarding seed → tutorial card appears once.
- Loop visibly demonstrates scrub, Split, divider drag, and reset.
- Card copy does not change across the loop.
- **I'll do this later** is reachable while the card is presented and preserves
  all data.
- **Try it** → real Split → real divider drag → success → Continue → real result
  reveal.
- **I'll do this later** still creates the existing single full-video move only
  when needed.
- Back/re-entry never duplicates seed videos or moves.
- Existing-segment re-entry starts at divider adjustment.
- Normal Library/Feed editor never shows onboarding tutorial chrome.

### Accessibility and visual

- Smallest and largest supported iPhone.
- Normal and accessibility-extra-extra-extra-large text.
- Reduce Motion static sequence.
- Increase Contrast.
- VoiceOver split and boundary-adjustment path.
- 44-point Split and divider targets.
- Color and grayscale target legibility.
- Tutorial overlay never blocks Back, Continue, or **I'll do this later**.

### Commands and evidence

During implementation:

```bash
make build
```

Run after each coherent small change, followed by a focused simulator check of
the affected tutorial state. Run targeted tests earlier when changing boundary
clamping or accessibility adjustment behavior.

At the end:

```bash
make test
git diff --check
```

Use `make run-fresh` for the full onboarding path. Read focused
`build/logs/*.pretty.log` files first. `make ui-test` remains an opt-in
placeholder unless the Makefile changes; do not claim it verified the journey.

Record:

- exact commands and results;
- device/simulator and OS;
- normal-motion screen recording;
- Reduce Motion screenshots;
- VoiceOver adjustment result;
- any simulator, signing, or environment limitation.

## Definition of done

- The tutorial demonstrates both splitting and dragging the divider in one
  polished, seamless loop, staged as a miniature abstraction inside the card's
  illustration panel under a single static caption.
- **Try it** hands off to the real editor without a visual or conceptual jump.
- The user's successful real split and real timing adjustment drive tutorial
  completion.
- The demonstration never changes user data.
- All split entry points still use one implementation.
- Touch drag and accessibility adjustment share one clamped boundary-update
  implementation.
- Existing onboarding exits, persistence safety, result reveal, paywall, and
  Feed landing remain intact.
- Reduce Motion and non-drag accessibility alternatives are complete.
- `make build`, `make test`, and `git diff --check` pass.
- Focused visual evidence meets or exceeds the reference's clarity and motion
  polish.

## Current-state note

Before this plan was added, both repository worktrees were clean. `main` was
two committed changes ahead of `origin/main`. This plan file is intentionally
the only new source-controlled change created by the planning task and remains
uncommitted until Adrian explicitly requests a commit.
