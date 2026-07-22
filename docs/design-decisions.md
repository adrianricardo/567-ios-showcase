# 567 iOS design decisions

Newest decisions first. These are approved iOS experience decisions; product-level principles also live in the shared product brain.

## 2026-07-21 — Three-video free cap and the redesigned onboarding

**Decision:** The free tier keeps **3 personal videos** and one personal-content style. Onboarding becomes the approved 7-beat sequence — hook, motivation, tailored payoff, seed video, guided editor, result reveal, paywall — and ends by routing to the Feed focused on the user's own first move. The bundled demo clip is identified persistently (`Video.isDemo`, schema V5) and never counts toward the cap, the free-style claim, legacy grandfathering, or library exports. Video selection uses Apple's private `PhotosPicker` only; the app no longer requests Photo Library authorization and ships without `NSPhotoLibraryUsageDescription`.

**Supersedes:** `specs/0005-freemium-unlock-smart-import.md`'s **10-video** cap and its 12-beat onboarding blueprint (`docs/onboarding-0005.md`), and the "up to 10 videos" product assumption recorded in `specs/0006-release-closure.plan.md`. Those documents remain accurate records of what shipped as v1.0 — do not read them as current behavior.

**Rationale:** 10 videos put the cap-hit roughly a month out, long after the moment the user has felt the product work. Three lands the decision while the first named move is still the thing they are looking at. The demo exclusion is what makes that honest: a user who never imported anything of their own is never charged for the clip 567 gave them.

**Evidence:** `specs/0007-onboarding-core-ui-redesign.plan.md` (P1–P6), and Adrian's approval of the redesign sequence.

## 2026-07-21 — Neutral Quiet Stage foreground, and boundaries only where they mean something

**Decision:** The Quiet Stage foreground tokens become pure neutrals (`primary` `0xF2F2F2`, `secondary` `0xB0B0B0`, `actionSurface` `0xFFFFFF`, `ink` `0x101010`); every `StagePalette` value now has equal RGB channels. Routine hairline strokes are removed from cards, buttons, fields, and rows — a surface is distinguished by its **fill**, not by an outline. `Theme.stageBoundary(_:)` is the single boundary recipe and draws only under Increase Contrast.

**Rationale:** Warm white competed with the dance-style accents, which are supposed to be the only color the app spends. The strokes were doing the same thing in miniature — decorating a boundary that `stageSurface` on `stageBackground` already states. Keeping one contrast-aware helper means the exception stays reviewable instead of being re-decided per view.

**Amends:** the Warm Stage foundation (2026-07-14) — its structure, single-cue rule, and accent policy are unchanged; only the warmth of the neutrals and the routine strokes are withdrawn.

**Evidence:** `specs/0007-onboarding-core-ui-redesign.plan.md` P5, the `quiet_stage_neutrals_carry_no_color_cast` and contrast tests, and the P6 visual audit. The Increase Contrast branch is verified by unit test but **not yet on a device** — see `open-questions-ios.md`.

## 2026-07-14 — Use Family Values as the primary experience-craft framework

**Decision:** Heavily adopt Family Values' ordered principles—simplicity through gradual revelation, fluidity through continuity, and delight through selective emphasis—across 567's onboarding, organization, and practice journeys. Adapt the principles to 567 and native iOS; do not copy Family's wallet-specific UI or tokens literally.

**Implementation consequence:** Every migration group includes an explicit simplicity, fluidity, and delight pass. Transitions are reviewed at half speed, persistent content stays persistent, and delight intensity follows interaction frequency.

**Rationale:** Warm Stage defines appearance and semantic hierarchy; Family Values defines how the product unfolds, moves, and rewards progress. Both are required for the intended experience.

**Evidence:** [Family Values](https://benji.org/family-values), `design-system.md`, `design-migration.md`, and Adrian's direction on 2026-07-14.

## 2026-07-14 — Approve the Warm Stage foundation with single-cue minimalism

**Decision:** Adopt Warm Stage: a flat near-black canvas, graphite content surfaces, warm-white hierarchy, selective dance-style accent, and neutral native Liquid Glass chrome. Reserve warm-white fill for the one primary action. For any state or fact, use one sufficient visible indicator instead of stacking redundant cues.

**Concrete state recipes:**

- Selected option: trailing checkmark only. No “Selected” text, leading notch, surface change, or selection accent.
- Playing row: one style-accent waveform only. No simultaneous rail, filled row, or “Playing” label.
- Local mode: one selected container only. No additional underline or accent.
- Assistive technology receives selection/playback traits and values without requiring more visible indicators.

**Rationale:** Minimalism is not merely fewer objects; it is refusing to communicate the same fact multiple times. The hierarchy remains clear because each semantic role owns a distinct cue, while accessibility semantics carry nonvisual information.

**Evidence:** `design-foundation/proposal.md`, the three approved snapshots, Apple HIG guidance linked there, and Adrian's approval/correction on 2026-07-14.

**Supersedes:** The provisional POC recipe where selected onboarding rows, active library rows, and primary CTAs reused light surfaces or stacked multiple state indicators.

## 2026-07-14 — Dance-style accent is content signal, not app chrome

**Decision:** The global dance style supplies a stable hard-coded accent for identity, progress, playheads, a single playing glyph, compact active controls, and brief completion detail. `All` remains neutral. Native navigation chrome stays neutral.

**Rationale:** This makes style context legible without turning every surface into a color theme or competing with semantic success/warning/destructive colors.

**Evidence:** `design-foundation/proposal.md`, `design-system.md`, and Adrian's approval on 2026-07-14.

## 2026-07-14 — Separate primary action from persistent state

**Decision:** Warm-white fill belongs to the one primary action. Persistent selection, navigation, and playback never reuse the primary-action fill.

**Rationale:** The POC's shared light treatment passed contrast checks but weakened hierarchy by making “chosen,” “current,” and “next” look equally actionable.

**Evidence:** `design-foundation-brief.md`, `design-foundation/proposal.md`, and the approved snapshots.
