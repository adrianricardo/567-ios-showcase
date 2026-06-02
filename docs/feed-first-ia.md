# Feed-First IA & Journey

Five67's root surface inverted from **Library-as-home** (drill-down list) to **Feed-as-home** (`RootView` is just `VideoFeedView`, no tab bar). This doc captures the mental model, the IA decisions that follow, and the ordered fixes that landed in code on 2026-05-21.

Last updated: 2026-05-21
Source session: in-conversation `/journey` + `/organize` pass with Adrian.

---

## Mental model

**Stories nested in a feed**, not "TikTok." TikTok is single-axis; Five67 has two:

- **Vertical swipe** = change the *story* → next/previous **video** (`Video`)
- **Segment rail + edge taps** = move through the chapters of the current story → **moves** (`Move`)

Calling it Stories-in-feed (Instagram/WhatsApp pattern) sets the right inheritance: a chip rail at the top is already known to mean "chapters within this author"; tap-to-advance and swipe-to-change-author are already learned. The novel-to-TikTok-muscle-memory beat is just "swipe = new video, not new chapter" — exactly one thing.

---

## Locked decisions

1. **Content axis: as built.** Vertical swipe between videos; rail + edge taps between moves within a video. Not flattening to a one-axis pure-TikTok stream.
2. **Capture lives in the editor.** The feed is review/playback only. Creating a new move is a deliberate trip into `VideoDetailView` via the action tray.
3. **Onboarding: light.** One coach beat the first time content exists. No multi-screen tour.

---

## /organize — IA decisions

### Vocabulary collapse: pick the data-model nouns

The same concept was named three ways across the UI. Locked to the model's own nouns:

| Concept | Model | User-facing word |
|---|---|---|
| Timed range inside a video | `Move` | **move** (was: moment, movement) |
| Imported clip | `Video` | **video** (was: source, "NOW BROWSING") |

"Move" is the domain noun — the *dance move* the app exists to catalog — and matches the data layer. "Source" stays only in the data layer (`sourceAssetID`) where it means the Photos asset, not a user concept.

### Drop redundant paths

For an immersive surface, every duplicate affordance is competing chrome:

- **Move nav had three affordances** (rail-chip tap, edge tap zones, bottom Prev/Next pills) → kept rail + edge taps, dropped the pills. The unique action ("Open actions") now owns the bottom row.
- **Library had two entry points** (top-chrome grid icon + tray "Library" tile) → kept the top-chrome icon, dropped the tile.
- **Editor has two parents** (feed push + library push) — that's fine; `VideoDetailView` owns its own back chrome and back returns where you came from.

### Unified ordering

Feed and Library now share a single `@Query` sort: `importedAt` desc. Position N in the feed = row N in the library. `recordedAt` is optional (nil for Files imports), so sorting on it alone produces an unstable order — `importedAt` is always present and "what I just added is at the top" is the dancer's expectation.

### Target IA

```
Feed (home, immersive)
├─ vertical swipe → switch video
├─ rail / edge taps → switch move within video
├─ long-press → Action tray
│     ├─ Edit moves       → Editor (push)
│     └─ Import (Photos / Files)
├─ top-chrome grid → Library (sheet)
│     └─ row tap → Editor (push)
└─ Editor (VideoDetailView) — the only place moves are created/trimmed
```

---

## /journey — Protagonist arc

### Marisol, intermediate salsa dancer
Films herself in class and at home, ends the week with 6–8 unwatched clips, wants to find the three seconds where the cross-body lead fell apart and drill it. Phone often propped against a mirror. Single coherent arc — solo personal-catalog app, no competing user paths to smooth over.

### Arc

1. **First run (empty).** Empty state shows pulsing icon + two import buttons. No coaching here — nothing to point at.
2. **First import → coach beats.** Two sequential one-time beats, each persisted independently:
   - **Beat 1 — Swipe.** Teaches `swipe = next video`. Dismisses on first successful vertical swipe or "Got it." Flag: `@AppStorage("hasSeenFeedSwipeCoach")`.
   - **Beat 2 — Tap zones.** Fires once Beat 1 is done. Highlights the left/right thirds of the screen with "Previous move" / "Next move" labels (the chip rail is just visualization — the side taps are the control). Dismisses on first side tap or "Got it." Flag: `@AppStorage("hasSeenFeedTapCoach")`.
   - The beats are mutually exclusive in the view layer (Beat 2 only renders once Beat 1 is gone) and never overlap.
3. **Steady state — the review loop.** Open to most recent clip autoplaying. Read the rail (how many moves marked last time). Tap a chip → land on the move. Edge-tap to replay. Swipe up → next clip. This is the payoff Photos-app scrubbing never delivered.
4. **Turning point — "I need to fix this spot."** Long-press → tray → "Edit moves" → Editor. **Designed as a handoff, not a teleport:** the editor opens at the playback time the user left the feed at, and the feed's player pauses so the two surfaces don't talk over each other. On return the feed resumes where it stopped.
5. **Resolution.** Marked move persists as a chip. Next session it's waiting. The catalog gets *more useful every session* — the opposite of a camera roll that gets more daunting.
6. **Re-entry.** No save/resume UI needed — content *is* the state. Feed reopens at index 0 (most recent), which is now consistent with Library after the ordering unification.

---

## Recommendations → what shipped (2026-05-21)

| # | Recommendation | Status | Where |
|---|---|---|---|
| 1 | Watch→edit timestamp handoff | ✅ shipped | `VideoFeedView` captures `activeController?.currentTime` into `editorStartTime`, pauses feed player on push; `VideoDetailView.init(video:startTime:)` + guarded `.onAppear` seek; feed resumes on dismiss |
| 2 | Vocabulary collapse (`move`/`video` user-facing) | ✅ shipped | `VideoFeedView` strings, `MomentCard`→`MoveCard`, `SourcePeekIndicator`→`VideoPeekIndicator`, `jumpTo…Moment`→`jumpTo…Move`, tray title "Actions" |
| 3 | Drop Prev/Next pills + tray Library tile | ✅ shipped | `bottomChrome` is single full-width CTA; `FeedActionTray` no longer carries `onShowLibrary` |
| 4 | Unified Feed/Library ordering | ✅ shipped | Both `@Query` declarations sort on `importedAt` desc with a comment explaining why |
| 5 | Two-beat coach (swipe, then tap-zones) | ✅ shipped | `@AppStorage("hasSeenFeedSwipeCoach"/"hasSeenFeedTapCoach")` + `swipeCoachOverlay` / `tapCoachOverlay`; Beat 1 fires when content first exists; Beat 2 hands off via `maybeAdvanceCoach()` after Beat 1 closes; each dismisses on the gesture it teaches OR "Got it" |

---

## Explicitly out of scope (this pass)

- Visual design / layout of the rail and cards.
- Editor's internal flow (trim timeline, marker editing) — only its entry/exit were touched.
- Community / sharing — v1 is on-device-only per decision log.
- Accessibility audit — edge tap zones still have no a11y action; worth a real `/include` pass before App Store, not before TestFlight.
- LibraryView ordering implications for any user who already had a mix of `recordedAt`-rich Photos imports + `recordedAt`-nil Files imports — the new ordering may shuffle their list once. Acceptable for a TestFlight-stage personal app.
