# 0001 — Video Feed Redesign: Top Chrome, Bottom Nav, Style Picker Pane

**Status:** Drafted, not implemented
**Branch (intended):** `feat/immersive-video-feed` (current) or successor
**Author:** Adrian
**Drafted:** 2026-05-26

---

## Goal

Reorganize the immersive video feed's chrome so the top of the frame carries identity + per-video actions, the bottom carries app-wide navigation, and dance styles become user-editable instead of a hardcoded three-case enum.

## Scope summary

| Area | Today | Proposed |
|---|---|---|
| Top chrome | 3-pill `FeedSegmentRail` only | Pills + video title (left) + loop & rename icons (right) |
| Right rail | Vertical column with loop + edit-moves buttons | **Removed entirely** |
| Bottom card | `MoveCard` / `DiscoveryHintCard` above bottom bar | **Removed from feed** |
| Bottom bar | Library\|Feed pill + style chip menu | 4-icon nav: Library · Feed · Add Video · Style Picker |
| Style picker | Inline `Menu` with 3 hardcoded enum cases | **New right-side pane**, user-defined styles, with rename for custom ones |
| `DanceStyle` | Fixed enum (`cumbia`/`salsa`/`bachata`) | Replaced by a `Style` SwiftData model (id, name); enum cases pre-seeded as defaults |

Out of scope: the 3 progress pills at the top of the screenshot (they already exist as `FeedSegmentRail`).

---

## 1. Top chrome

**File:** `Five67/Views/Feed/VideoFeedView.swift` — `topChrome(video:)` (line 445)

Currently renders only `FeedSegmentRail`. Replace with a `VStack`:

1. `FeedSegmentRail` (unchanged) — the 3 progress pills
2. **New row** `HStack`:
   - Left: `Text(video.displayName)` — title styling (heavy, large-ish, white, single line, truncate tail)
   - Spacer
   - Right: glass cluster with two icons:
     - **Loop**: extract `LoopRailButton` behavior from the existing right-rail (`rightRail`, line 326). Same toggle, same icon (or pick a horizontal-friendly variant).
     - **Rename**: SF Symbol `pencil`. Opens existing `RenameSheet` (`Five67/Views/Shared/RenameSheet.swift`).

Style: ride the same liquid-glass treatment used by `rightRail`'s `GlassCluster`, but horizontal.

## 2. Right rail — remove

**File:** `Five67/Views/Feed/VideoFeedView.swift`

Delete:
- `rightRail` property (line 326)
- `rightRailBottomInset` property (line 322)
- The `if let _ = selectedVideo, !isPaneOpen` block in `body` that renders the right-rail container (lines 187–200)

Verify nothing else references `LoopRailButton` outside the feed; if not, move its definition into `topChrome` or keep it as a shared helper used by the new top-right cluster.

The "edit moves" entry point currently on the right rail (`slider.horizontal.3` button calling `openEditor()`) — confirm with Adrian whether `openEditor()` still has an entry point. *(Open question — see below.)*

## 3. Bottom chrome card — remove

**File:** `Five67/Views/Feed/VideoFeedView.swift`

Delete the `bottomChrome(video:)` invocation from `body` (line 163–171) and the `bottomChrome` / `MoveCard` / `DiscoveryHintCard` definitions. The `GlobalBottomBar` then sits flush below the video.

(Leave `MoveCard` / `DiscoveryHintCard` types in place only if they're referenced elsewhere — otherwise delete.)

## 4. New `GlobalBottomBar`

**File:** `Five67/Views/Shared/GlobalBottomBar.swift` — rewrite.

Replace the current "tab pill + style chip" two-part layout with a single horizontal row of 4 icon buttons:

| Order | Icon (SF Symbol) | Action |
|---|---|---|
| 1 | `photo.stack.fill` (or similar list/library glyph) | Open Library pane (left side) — sets `router.selectedTab = .library` |
| 2 | `play.rectangle.fill` | Anchor to feed — sets `router.selectedTab = .feed`, closes any open pane |
| 3 | `plus.circle.fill` | Show Add-Video action sheet: "Record New" / "Choose from Library" (same sheet used by Library's add button) |
| 4 | `slider.horizontal.3` (or `paintpalette.fill`) | Open Style Picker pane (right side) |

All four are icon-only — no labels (per spec). Active state for Library/Feed: tint with `Color.accentColor`. Active state for the Style button: solid foreground (the active-style name lives **inside** the pane, not on the chip).

`StyleStore` binding stays on the bar so it knows when to close the right pane if active style changes externally.

## 5. Add-Video action sheet

The "+" item in the bottom bar must reuse the same sheet the Library pane already presents. Library currently dispatches via `onImportPhotos` / `onImportFiles` callbacks — wire the bottom bar to the same handlers in `VideoFeedView` (`showPhotosPicker` / `showFilesImporter`).

## 6. Style Picker pane (new)

**New file:** `Five67/Views/Style/StylePickerPaneView.swift`

Mirror the `LibraryPaneView` swipe-in pattern, but bound to the **right edge** of the screen.

### Behavior

- Slides in from the right when the bottom bar's Style icon is tapped, or via horizontal swipe (left-from-right-edge).
- Co-equal to the feed, like the Library pane is — feed parallaxes off to the left as it opens.
- Library is on the left edge; both panes cannot be open simultaneously.

### Contents

List of all `Style` rows. Each row:
- Style name
- Checkmark / selected affordance when it's the active style
- Tap → set active, close pane
- If the style is **custom** (not one of the 3 seeded defaults): swipe-action or context-menu → Rename (reuses existing `RenameSheet` pattern)
- Last row: "Add new style" → text-field prompt → creates a new `Style` and selects it

Seeded defaults (Cumbia, Salsa, Bachata) are **not renameable** and **not deletable** in this pass. Delete is out of scope entirely.

### State machinery

Extend `VideoFeedView` with a `stylePaneProgress: CGFloat` parallel to `paneProgress`. The horizontal gesture in `feedAndPaneGesture` needs to disambiguate which edge the drag started from:
- Drag starts near left edge OR pane is already open from left → drive `paneProgress` (Library)
- Drag starts near right edge OR right pane is already open → drive `stylePaneProgress` (Style)

Or — simpler — only allow pane opening via the bottom-bar buttons; restrict the swipe gesture to closing whichever pane is open. *(Open question — see below.)*

## 7. Schema change: `DanceStyle` enum → `Style` model

This is the biggest piece. Touches:

### New model

`Five67/Models/Style.swift` (new):
```swift
@Model final class Style {
    @Attribute(.unique) var id: UUID
    var name: String
    var isDefault: Bool   // true for seeded Cumbia/Salsa/Bachata; gates rename/delete
    var createdAt: Date
    @Relationship(inverse: \Video.style) var videos: [Video]
}
```

### Migration

`Five67/Models/SchemaMigrations.swift` — add a versioned migration:

1. Create three `Style` rows: Cumbia, Salsa, Bachata (with `isDefault = true`, stable UUIDs so seeding is idempotent across launches).
2. For every existing `Video` with a `style: DanceStyle?` value, re-point the relationship to the corresponding seeded `Style`.
3. Drop the `DanceStyle` enum (or keep as a transition shim — see open question).

### Touch points

- `Five67/Models/Video.swift` — `style` becomes `Style?` relationship instead of stored enum value.
- `Five67/Models/DanceStyle.swift` — delete (or shim).
- `Five67/Services/StyleStore.swift` — `activeStyle` becomes `Style?`; persisted by `id` (UUID string) in `UserDefaults` instead of raw enum string. `matches(_:)` compares by `Style.id`.
- `Five67/Views/Feed/VideoFeedView.swift` — `styleTagTargets` confirmation dialog currently iterates `DanceStyle.allCases`; needs to fetch all `Style` rows via `@Query` and iterate those.
- `Five67/Views/Library/LibraryPaneView.swift` — anywhere referencing `DanceStyle` (search & replace).
- Anywhere else `DanceStyle` is referenced — `grep -r "DanceStyle"` and visit each.

## 8. Files modified (summary)

**Modified:**
- `Five67/Views/Feed/VideoFeedView.swift` (top chrome, remove right-rail + bottom card, wire bottom bar callbacks, add right-pane state)
- `Five67/Views/Shared/GlobalBottomBar.swift` (full rewrite to 4-icon layout)
- `Five67/Models/Video.swift` (style relationship)
- `Five67/Services/StyleStore.swift` (Style? instead of DanceStyle?)
- `Five67/Models/SchemaMigrations.swift` (new versioned migration + seed)
- `Five67/Views/Library/LibraryPaneView.swift` (DanceStyle → Style)

**Added:**
- `Five67/Models/Style.swift`
- `Five67/Views/Style/StylePickerPaneView.swift`

**Deleted:**
- `Five67/Models/DanceStyle.swift` (or kept as deprecation shim)

---

## Open questions to resolve before coding

1. **Edit-moves entry point.** The right rail's `slider.horizontal.3` button currently calls `openEditor()` (push to `VideoDetailView`). Once the rail is removed, where does this entry point live? Options: (a) long-press on the title, (b) a third top-right icon, (c) only reachable via Library pane → tap-into-detail. Adrian to decide.

2. **Right-pane gesture model.** Allow swipe-from-right to open the Style pane, or button-only? Library's swipe-from-left is well-established muscle memory; adding symmetric swipe-from-right is nice but doubles the gesture-disambiguation complexity. Recommend button-only for v1.

3. **`DanceStyle` enum removal vs shim.** Clean delete is cleaner but means more concurrent edits. A shim that maps the 3 enum cases to seeded `Style.id`s makes migration easier. Recommend clean delete now that the migration runs at first launch post-update.

4. **Active-style indication on the Style nav icon.** Spec says icon-only, no name. Should the icon get a small dot/accent when a non-default style is active, or stay fully static? Recommend a subtle accent dot.

5. **Pane width.** Library pane is full-width (covers feed). Should Style pane also be full-width, or narrower (e.g. 80%)? A narrower pane gives a peek of the underlying feed and reinforces "this is a quick pick." Recommend full-width for consistency with Library.

---

## Risk notes

- **Migration is the highest-risk piece.** SwiftData migrations that re-point relationships are easy to get wrong in subtle ways. Plan: write the migration, snapshot a copy of the user's pre-migration store from a TestFlight build, run the migration locally against it, verify counts and re-pointing before shipping.
- **Two simultaneous panes** could theoretically race if a user taps Library while Style is open mid-animation. State machinery should treat "open Library" and "open Style" as mutex — opening one snaps the other closed.
- **Right-rail removal** loses a thumb-reachable target for loop. Loop at top-right is a reach on larger phones. If Adrian uses loop frequently, this should be tested in-hand before shipping.

---

## Confirmed decisions (from interview, 2026-05-26)

- Title is **new** (doesn't exist today); add it under the 3 pills.
- Right rail is **fully removed**.
- Bottom `MoveCard`/`DiscoveryHintCard` is **removed from feed**.
- Schema change for user-defined styles happens **in this pass**.
- `Style` model is **name-only** (no color, no emoji).
- Three enum cases are **pre-seeded as defaults**.
- Picker scope is **select + add + rename (custom only)**; no delete.
- Rename icon is **`pencil`**.
- Style pane opens from the **right** (Library is left).
- Add Video reuses the **same action sheet as Library's add button**.
