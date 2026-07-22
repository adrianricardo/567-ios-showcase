# 567 iOS design system

> **Status: approved foundation (2026-07-14).** This is the implementation contract for future migration. Approval does not mean the existing app already conforms; follow `design-migration.md` and visually review each surface group.

The selected **Warm Stage** direction combines Warm Tempo's tactile hierarchy with Quiet Stage's neutral palette.

## Character

Joyful, premium, simple, minimal, and polished. The product should feel unusually easy while keeping its power close at hand. Joy comes from responsive movement, clear progress, and the dancer's own content—not decoration.

## Product-level interaction principles

1. **Make the next action obvious.** Each state has at most one primary action.
2. **Use one sufficient visible indicator per fact or state.** A checkmark can mean selected; do not add a notch, “Selected” label, surface change, and color change to repeat it. Accessibility traits and values provide nonvisual semantics without adding visual redundancy.
3. **Reveal complexity when it becomes relevant.** Keep frequent paths direct and move secondary choices into native menus, sheets, or detail flows.
4. **Preserve continuity.** Persistent elements stay in place; movement explains where content came from or went.
5. **Apply delight selectively.** Daily practice interactions are subtle and fast. First-value and meaningful completion moments can carry more personality.

## Family Values adaptation

[Family Values](https://benji.org/family-values) is 567's primary experience-craft framework. Adopt its principles heavily, in order—**simplicity, then fluidity, then delight**—while keeping 567's own product model, native iOS conventions, and visual tokens. Do not copy Family's wallet-specific tray system or component styling literally.

### Simplicity through gradual revelation

- Keep the current task and one primary action obvious; reveal advanced choices only when they become relevant.
- Use context-preserving sheets and trays for transient actions such as rename, confirmation, warnings, and focused setup. Use full screens for persistent destinations such as Library and practice.
- A tray owns one piece of information or one primary action, has a clear title and dismissal path, and visually belongs to the context beneath it.
- Preserve expert speed through direct gestures, menus, and shortcuts without exposing every option in the default view.

### Fluidity through continuity

- Treat the app as one physical space. Every transition must explain where content came from, where it went, or what changed.
- Shared content travels when practical: a selected library move should visibly connect to the practice/detail state instead of feeling remounted from nowhere.
- Persistent elements stay persistent. Do not animate a stable header, video, or row out and back in merely because nearby state changed.
- Direction follows navigation: forward/right, back/left, and local mode changes follow their relative order.
- Animate only the changing part of text, progress, and state. Avoid redundant motion just as the visual system avoids redundant state cues.
- Loading and completion feedback resolve where the result lives, not where the action began.

### Delight through selective emphasis

- Match intensity to frequency. Scrolling, selecting, and looping are frequent and get subtle tactile polish; first clip, onboarding completion, and meaningful practice milestones may be more expressive.
- Delight must reinforce comprehension, progress, or emotional reward. Avoid decorative motion, novelty that slows practice, or a mandatory “magic moment” on every screen.
- Empty and first-use states deserve authored guidance, not placeholder copy.
- Polish utility and recovery states to the same standard as hero surfaces.
- Sound and haptics are optional layers for meaningful completion, never required to understand the outcome.

## Foundation

- Flat near-black space with graphite content surfaces and a neutral near-white hierarchy (the foregrounds were de-warmed in 0007 P5).
- No gradients, decorative glows, ornamental glass, or color-washed cards.
- Apple system typography. Use a rounded system face only for major, friendly titles.
- Prefer a few large, legible objects over dense collections of small controls.
- Content cards and primary actions use 16–18pt continuous corners. Capsules and circles are reserved for compact controls, tags, and native chrome.

### Surface hierarchy

| Level | Use | Behavior |
|---|---|---|
| Canvas | App/content background | Flat near-black; never used to signal selection. |
| Surface | Cards, rows, fields | Solid graphite. The fill *is* the boundary; an edge is drawn only under Increase Contrast (0007 P5). |
| Raised | Structural elevation | Darker/lighter graphite for a selected segment container, tray, or elevated group—not a default row-selection signal. |
| Action | One primary action | Pure-white fill with stage-ink foreground. |

### Semantic tokens

The current implementation lives in `Five67/Views/Shared/Theme.swift`. Migration must preserve existing names until each call site moves safely.

| Target token | Role | Migration note |
|---|---|---|
| `stageBackground` | Flat app/content canvas | Keep. |
| `stageSurface` | Graphite card, row, and field | Keep. |
| `stageRaisedSurface` | Structural elevation and selected segment container | Keep; do not use automatically for selected rows. |
| `stagePrimary` | Neutral near-white text (`0xF2F2F2`) | Keep as foreground only after action token split. |
| `stageSecondary` | Supporting text | Keep. |
| `stageActionSurface` | Pure-white primary-action fill (`0xFFFFFF`) | Rename/split from the POC `stageSelectionSurface`. |
| `stageInk` | Near-black foreground on action/accent surfaces | Keep. |
| `stageBoundary(_:)` | The one boundary recipe | **Replaced `stageStroke` in 0007 P5.** Returns `.clear` normally and a visible hairline only when `colorSchemeContrast == .increased`. Do not reintroduce routine strokes. |

Remove `stageSelectionSurface` after its call sites migrate. Selection is a component state, not a light color token.

## Semantic roles

| Role | Purpose and prominence | Color / surface behavior | Single visible indicator |
|---|---|---|---|
| Primary action | Advance or begin the screen's main task; highest emphasis | Pure-white action fill + stage ink. Accent may appear only in a compact icon when it adds meaning. | Verb-first label; directional/play glyph only when it clarifies the action. |
| Selection | Show a saved choice | Ordinary graphite row; never white fill and no automatic surface change. | Checkmark. |
| Playing / current content | Identify the item controlling playback | Ordinary graphite row. | Style-accent waveform. |
| Active navigation | Show current destination or local mode | Native neutral Liquid Glass for app chrome; one raised graphite container for custom local modes. | System selection treatment or the selected container, treated as one atomic cue. |
| Progress | Show position through onboarding, video, or practice | Style accent fills a neutral track or compact current marker. | Use the track for relative position; add time/count only when exact position is independently useful. |
| Success | Confirm a completed outcome | System green in a compact, temporary treatment; then return to neutral. | Checkmark with result text only when the text communicates the outcome, not merely “Success.” |
| Warning | Flag recoverable attention | System orange on a compact icon/edge or neutral warning tray. | Warning glyph with consequence/recovery copy. |
| Destructive | Identify irreversible or hard-to-recover action | System red text/icon in native menus and confirmations; never primary. | Destructive role and explicit object/action label. |

## Component recipes

### Primary action

- One per state, full-width when it anchors a focused mobile flow.
- `stageActionSurface` fill, `stageInk` foreground, 16–18pt continuous corner.
- Use a concise verb label. Do not repeat the current selection beneath the label when it is already visible above.
- Disabled state uses a neutral surface and remains legible without looking actionable.

### Selectable row

- Entire visible row is tappable, minimum 44pt.
- Unselected and selected rows use the same `stageSurface`, typography, and edge.
- Selected state adds one trailing checkmark. The style-color dot may remain as identity metadata, but it must not appear or change because of selection.
- Add `.isSelected` and an appropriate accessibility value; do not add visible “Selected” copy.

### Playing row

- Ordinary row treatment; no selection fill or leading rail.
- One trailing style-accent waveform identifies the item currently controlling playback.
- Expose “Playing” as the accessibility value. Do not also render the word unless the waveform proves unclear in user testing.

### In-content mode selector

- Use a compact neutral container with one raised selected segment.
- Do not add an underline, accent tint, or separate selected label on top of the container.
- Use native `Picker`/segmented behavior when it meets the visual and accessibility requirements.

### Status and destructive actions

- Success, warning, and destructive colors remain semantic system colors and never inherit the dance-style accent.
- Put destructive actions in native menus, swipe actions, or confirmation dialogs. Never style them as the screen's primary action.

## Dance-style accents

The globally selected dance style supplies the content signal color. `All` stays neutral.

| Style | Accent |
|---|---:|
| Salsa | `#FF6B4A` |
| Cumbia | `#FFD166` |
| Bachata | `#FF9EB5` |
| Kizomba | `#B7A0FF` |
| Zouk | `#71D7E8` |
| Merengue | `#B8F05A` |

Custom styles receive a deterministic color from this approved palette using their stable style ID. The result must not change between launches.

Accent is a signal, not a background system. Use it for style identity dots, progress, playheads, a single playing glyph, compact active controls, and brief completion detail. Do not use it for large page backgrounds, body text, every card, global navigation tint, or as a second selection indicator beside a checkmark.

## Context adaptation

### Onboarding

- One decision per beat and one primary action.
- Selection uses a trailing checkmark only.
- Show exact step text when it is useful; do not also add a decorative progress treatment that repeats it.

### Library and content organization

- Optimize for scanning: succinct row names, useful grouping, and quiet metadata.
- Local mode selection uses one selected container.
- Current playback uses one waveform glyph. Browsing selection and playback state are different semantics and must not share a generic light-fill recipe.

### Immersive practice and video detail

- Video may own the upper canvas; supporting content returns to solid Quiet Stage surfaces.
- Playback progress uses the active style accent. Floating playback/navigation controls remain neutral.
- The current clip uses one waveform glyph; the practice CTA uses the one white action fill.

## Liquid Glass

Keep Apple's native tab and navigation chrome. Liquid Glass is reserved for system navigation and truly floating controls. It stays neutral so the dancer's selected style remains the only content signal color. Content cards and fields use solid Quiet Stage surfaces.

Treat a standard native selected-tab treatment as one system-owned cue. Do not layer custom accent, badges, or extra underlines onto it.

## Motion and haptics

- Motion must explain a state or spatial change; it is never an additional state indicator.
- Use short, settled feedback for checkmark insertion, mode changes, and playback activation. Animate only the cue that changes.
- Persistent headers, rows, and controls stay in place. Directional navigation moves consistently with the destination.
- Progress motion is direct and shares one timing curve across the playhead, time, and dependent labels.
- Respect Reduce Motion: remove travel and use an immediate state change or short crossfade while preserving the same single visible cue.
- Haptics confirm selection and meaningful completion, not ordinary scrolling or every tap.
- Review transitions at half speed. Anything that teleports, redundantly remounts, or moves without clarifying the journey must be revised.

## Accessibility

- All interactive targets are at least 44×44pt and retain full-row hit areas.
- Preserve Dynamic Type; reflow before truncating primary labels or shrinking text.
- Every icon-only control has a speakable label. Group row content into a useful VoiceOver stop.
- Expose selection, playback, progress, status, and destructive roles through accessibility traits/values even when the visible design intentionally uses only one cue.
- Do not rely on color alone. Prefer a glyph or shape as the sole visible state cue; style accent can carry identity or temporal progress without becoming the only meaning.
- Respect Reduce Motion, Reduce Transparency, Increase Contrast, and Bold Text.
- Pressed, disabled, and increased-contrast variants must preserve required foreground/background contrast.

## Reference snapshots

The approved representative surfaces are in `design-foundation/`:

- `onboarding-selection.png`
- `library-home.png`
- `practice-video-detail.png`

They demonstrate hierarchy and semantics, not pixel-perfect production layouts.
