# 567 iOS design decisions

Newest decisions first. These are approved iOS experience decisions; product-level principles also live in the shared product brain.

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
