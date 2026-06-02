# Library Pane + Style Mode

Status: implemented (v1) — 2026-05-22
Last updated: 2026-05-22
Source session: design interview, 2026-05-22

---

## Concept

Replace the modal Library sheet on `VideoFeedView` with a **swipe-in side pane** that consolidates the existing `LibraryView` (Videos list) and the currently-orphaned `MovesView` (Moves grouped by video) into a single peer surface to the feed. Add a **global Style mode** (Cumbia / Salsa / Bachata / All) that scopes both the feed and the pane.

The pane is co-equal to the feed, not modal. The feed remains the home; the pane is the parallel "browse" surface.

## Why this exists

- The current modal Library sheet is a fine v1 entry but feels grafted onto the immersive feed. A side pane is more native to the Reels-style consumption model and supports the dual lens (videos vs moves) that the product needs.
- The orphaned `MovesView` (built but not wired) deserves a home. The pane is that home.
- Multiple dance styles (Cumbia / Salsa / Bachata) introduce a scoping dimension the current IA has nowhere to put. Promoting it to a global mode keeps the feed focused and gives users a clear "I'm in Cumbia practice" mental model.

## Navigation model

- **Home**: `VideoFeedView` (unchanged role)
- **Swipe right** (full-pane swipe, starts anywhere on screen) → Library pane slides in from the left, feed slides off to the right (parallax — consistent with the feed's up/down video transitions)
- **Swipe left** → return to feed
- **Tap a row in pane** → pane animates back (same parallax direction); feed loads/plays the chosen video. For a move tap, feed starts at the move's timestamp.
- **Pane covers 100%** when fully open (no peek). Swipe-back gesture is the only return.
- **Underlying feed video pauses immediately** when the swipe gesture starts.

## Pane structure (top → bottom)

1. **Header**: Import (Photos, Files) + Export icons + mirrored Style chip (`Cumbia ▾`)
2. **Segmented control**: `Moves | Videos` (stacked above search, not inline — iPhone width is too tight to combine)
3. **Search field**: searches across move names + video titles
4. **Filter chips** (Moves view only): `Named | Unnamed | Excluded | All` — reuse existing `MovesFilter` enum and `@AppStorage("movesFilter")` binding
5. **List**:
   - **Moves view**: grouped by video (reuse `moveGroups` computed property from `MovesView`)
   - **Videos view**: flat list, reverse-chronological by `importedAt` (today's `LibraryView` query)
   - **Active item highlighted** — the video/move currently in the feed gets a clear "Now Playing" indicator
   - **Swipe-to-delete** preserved on rows (reuse existing `LibraryView` swipeActions)

**Toggle default**: Moves. Preference is sticky across launches (`@AppStorage`).

**Visual style**: respect iOS system dark/light mode. No immersive override.

**Empty state**: same as feed's empty state ("Drop in a dance video" with import CTAs).

## Feed chrome changes

- **Top-left**: Library button (`square.grid.2x2.fill`) — **moved from top-right**, now adjacent to the pane it opens. Stays as an alternate entry to the swipe gesture (belt and suspenders for discoverability).
- **Top-right**: **Style chip** — shows current style (`Cumbia ▾`). Tap opens picker menu with `Cumbia / Salsa / Bachata / All`.
- **Right-edge rail (new on feed)**: vertical stack of circle buttons. v1 minimum:
  - **Loop** — reuse `LoopRailButton` from `Shared/VideoHeroView.swift`. Always visible, always enabled. When a move is active, loops just the move; when no move active, loops the whole video.
  - **Edit** — opens `VideoDetailView` for the current video (replaces the FeedActionTray "Open Editor" path).
  - Additional rail slots TBD at mockup time.
- **Bottom "Open actions" tray**: **removed entirely**. Edit lives on the rail, Import lives in the pane header. `FeedActionTray` becomes dead code (delete after migration verified).

## Style mode

- **Global scope**: filtering applies to both feed (which videos appear in the immersive stack) and pane (which videos/moves appear in lists). `All` is a valid mode.
- **Attached to Video only** in the data model. All moves within a video inherit their parent video's style. (Per-move override deferred — see Open Questions.)
- **Set at import time**: after a video imports, prompt the user to tag it (`Cumbia / Salsa / Bachata`). No pre-content onboarding pick — style emerges from content.
- **Switcher UI**: top-right chip on feed; mirrored in pane header. Tap → picker menu.
- **Persistence**: per-device UserDefaults for the active mode. iCloud sync of preference not addressed in v1.

## Tap-into-move playback

When user taps a saved move:

1. Pane animates back
2. Feed loads the move's parent video at the move's start timestamp
3. Plays through to the end of the video, then restarts the video
4. If Loop on the rail is toggled while a move is active → only that move loops (reuse `PlaybackController.isLooping` semantics already shared between editor and `MovesView`)

Vertical swipe-up in the feed (after tap-into-move) advances to **next video in the global feed**, not the next saved move. The pane is a launcher, not a parallel feed.

## Code reuse / migration

| Existing | Action |
|---|---|
| `LoopRailButton` (`Shared/VideoHeroView.swift`) | Drop onto feed's new right rail |
| `MovesView` grouping logic (`moveGroups`) + filter | Extract into pane's Moves tab |
| `LibraryView` row + delete logic | Extract into pane's Videos tab |
| `MovesFilter` enum + `@AppStorage("movesFilter")` | Reuse as-is |
| `PlaybackController.isLooping` | No new logic — already shared |
| `FeedActionTray` (`VideoFeedView.swift` ~line 1073) | **Delete** after Edit moves to rail |
| Modal Library sheet (`.sheet(isPresented: $showLibrary)`) | **Replace** with side pane |
| Standalone `LibraryView` and `MovesView` as full screens | **Supersede** — delete or repurpose post-migration |

## v1 scope

- iPhone portrait only (matches TestFlight launch posture)
- One pane, two tabs (Moves / Videos)
- Three styles (Cumbia, Salsa, Bachata) + All
- Style set at import via prompt; editable later via per-video menu (`VideoDetailView` overflow)

## Out of scope (v1)

- iPad / landscape adaptation
- Per-move style override (mixed-style videos)
- iCloud sync of style preference
- Discovery affordance for the swipe gesture (see Open Questions — punted)
- Browse-then-go model where pane stays open after tap
- Social / sharing features
- Accessibility-specific affordances beyond standard SwiftUI defaults

## Decisions log (interview summary)

| Question | Decision |
|---|---|
| Primary unit (Moves vs Videos) | Moves default; sticky toggle preference |
| Re-entry behavior after move tap | Next swipe-up = next video in global feed |
| Library role | Co-equal home (peer surface to feed) |
| Move playback on tap | Start at move → continue to end → restart video; loop button on rail controls move-only or whole-video loop |
| Moves view organization | Grouped by video (reuse existing) |
| Pane dismissal on tap | Animated slide-back (parallax) |
| Import/export location | Top of pane (replaces modal toolbar) |
| Feed playback during swipe | Pause immediately |
| Search within pane | Yes, across moves + videos |
| Tap behavior | Auto-dismiss pane via parallax animation; feed loads and plays |
| Pane width when open | 100%, no peek |
| Pane visual style | Respect iOS dark/light system mode |
| Toggle UI | Segmented control, stacked above search |
| Existing Library button fate | Keep as alternate entry; move to top-left |
| Bottom action tray fate | Remove entirely |
| Empty pane state | Same as feed empty state |
| Loop visibility | Always visible, always enabled |
| Swipe motion | Parallax (feed slides with pane) |
| Active item indicator | Yes, clearly highlighted |
| Delete affordance | Swipe-to-delete preserved on rows |
| Form factor (v1) | iPhone portrait only |
| Style scope | Global app mode |
| Style data attachment | Video only |
| Style switcher placement | Top-right of feed, mirrored in pane header |
| All-styles mode | Yes, valid |
| First-launch style pick | No — tag at import time instead |

## Related

- Supersedes the modal Library sheet pattern documented in `feed-first-ia.md`
- Adds the Style mode dimension that previously had no IA home
- Deferred items added to `open-questions.md` (Library pane + style mode section)
- Backlog entry added to `launch-punch-list.md` (Feature backlog section)
