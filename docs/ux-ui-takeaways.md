# UX / UI Takeaways — Cumbia Moves

Portfolio log of the user-facing design and interaction decisions in this app. Each entry is framed as **Problem → Decision → Result** so it's easy to walk through in an interview or case study.

**Stack context:** SwiftUI on iOS 18 / Swift 6, SwiftData, AVFoundation. Single-developer hobby/portfolio app for cataloging dance practice videos and slicing them into reviewable "moves."

---

## 1. TikTok-style player surface

**Commit:** `71187a0` — *Add TikTok-style player UI: custom AVPlayerLayer surface, right-side action rail, timestamp pill*

**Problem.** SwiftUI's `VideoPlayer` ships with Apple's standard chrome (transport bar, AirPlay button, fullscreen toggle). For a dance-practice tool the playback model isn't "watch a movie" — it's "scrub a 30s clip, mark in/out, repeat." The default UI was both visually busy and behaviorally wrong: a tap dropped the user into Apple's overlay instead of toggling play.

**Decision.**
- Replaced `VideoPlayer` with a custom `VideoPlayerSurface` backed by `AVPlayerLayer`, hiding all native chrome.
- Built a vertical **right-side action rail** (Filter / Mute / Loop / Split) — borrowing the TikTok mental model the target audience already speaks.
- Added a floating **timestamp pill** as the only on-video text, so the chrome is glanceable but unobtrusive.
- Made the player **edge-to-edge** with the video rounded and inset 12pt — the rounded card reads as "media object" rather than "page region."
- Tap on the video toggles play. The Play button moved off the video and onto the trim track row, where it's contextual to the scrubber.

**Result.** Playback feels like a tool, not a movie viewer. The action rail puts the four most-used controls within thumb reach without consuming a toolbar row, and the rounded edge-to-edge surface gives the screen a single dominant subject.

**Talking points.**
- Knowing when to *leave* SwiftUI: `VideoPlayer` is great until you need to remove its chrome, at which point `AVPlayerLayer` + `UIViewRepresentable` is the right exit.
- The action-rail pattern is borrowed deliberately. Users who film themselves dancing already know where Mute lives on TikTok; matching that mental model is faster than inventing a novel layout.

---

## 2. Stable trim timeline during interior drags

**Commit:** `3599090` — *Stabilize trim timeline with fixed time mapping*

**Problem.** The trim track shows the full clip with draggable dividers between segments. Originally, segment widths were derived from each segment's *current* duration. The instant a user grabbed a divider, every other segment also re-laid-out, because moving a divider changes neighboring durations. The whole timeline visibly breathed under the finger.

**Decision.** Switched to a **fixed time → x mapping** based on the visible time span (`xFor(t)` is stable for the duration of a drag). Only the dragged boundary moves. Segment-progress fills are suppressed while trimming, so an animating play head doesn't compete with the user's gesture. Segment taps are routed through a single `onTapSegment` so the drag and tap layers don't collide.

**Result.** Trimming now feels like dragging a divider on a *map*, not on a slinky. The gesture stays under the finger and only the affected boundary moves.

**Talking points.**
- This is a classic case of "layout depends on the value the gesture is mutating." The fix isn't to throttle the gesture — it's to break that dependency by introducing a stable coordinate space.
- Suppressing the progress fill during drag is a small but important detail: two animating elements competing for the same pixels during a gesture is a clarity bug, even when each is "correct" in isolation.

---

## 3. Dark top safe area + status bar over player

**File:** `CumbiaMoves/Views/Moves/MovesView.swift`

**Problem.** The Moves screen is video-first — the player owns the top of the screen — but the default navigation chrome leaves a light status-bar area and a light-mode tint that creates a visible seam between "status bar" and "video."

**Decision.**
- `.toolbarColorScheme(.dark, for: .navigationBar)` — keeps the status bar glyphs legible against a dark surface.
- `.background(Color.black.ignoresSafeArea(edges: .top))` on the player container — extends the player surface into the safe area instead of letting the system background bleed through.
- Kept `.statusBarHidden(false)` deliberately — hiding the status bar reads as "I forgot one," and dance practice users glance at the time between takes.

**Result.** The screen reads as a single dark media surface from the notch down to the trim track, without losing the system clock.

**Talking points.** Edge-to-edge media on iPhone is a status-bar problem first and a layout problem second. The "right" answer is almost never `.statusBarHidden` — it's matching the toolbar color scheme to the content underneath it.

---

## 4. Migration failure: explicit recovery instead of silent wipe

**Files:** `CumbiaMoves/App/CumbiaMovesApp.swift`, `CumbiaMoves/Views/Root/MigrationFailureView.swift`

**Problem.** The earlier code path "handled" a SwiftData migration failure by `print()`-ing it and silently wiping the store. That's the worst possible UX: a user with a corrupt library opens the app and their content appears to be gone, with no message and no recovery path.

**Decision.** Replaced the silent fallback with a full error screen:
- Branched `WindowGroup` on `Result<ModelContainer, Error>` and route to `MigrationFailureView` on failure.
- **Three explicit actions, ordered by safety:** Export current data (primary, prominent) → Contact support (neutral) → Reset library (destructive, requires confirmation).
- The error itself is rendered verbatim in a monospaced, **selectable** text block so the user can copy it into a support email.
- "Reset library" is the *only* path that wipes the store. There is no silent reset anywhere else in the codebase.
- The confirmation dialog tells the user that imported video files are **not** touched by the reset — they only live in `Documents/videos/`. Setting that expectation up front prevents the panic of "did I just lose my videos?"

**Result.** A failure mode that used to feel like data loss now feels like a recoverable error. The user always has the option to walk away with their data.

**Talking points.**
- The hierarchy of buttons matters: the safe action is large and tinted, the destructive action is bordered and red — and gated behind a confirmation that names the consequence.
- "Export before destroy" is a pattern worth naming: any destructive action should offer to preserve the thing it's about to destroy, *first*.

---

## 5. Library export entry point: menu, not a top-level icon

**File:** `CumbiaMoves/Views/Library/LibraryView.swift`

**Problem.** Library has one obvious primary action — Import (`+`) — and one rarely-used secondary action — Export. Putting both as toolbar icons gives them equal weight, even though one is used many times a day and the other rarely.

**Decision.**
- Kept Import at `.primaryAction` with the `+` glyph — the universal "add" affordance.
- Tucked Export inside a `Menu` at `.topBarLeading` using `ellipsis.circle`. This is **deliberately under-emphasized** — it leaves headroom to add Import from Files, Diagnostics, etc., without redesigning later.
- While exporting, the menu's icon swaps to a `ProgressView` and the button disables. The work runs off-main via a `@ModelActor`, so the rest of the UI stays interactive.
- Export pipeline: `fileExporter` for the zip destination → on success, present `ExportSummarySheet`. On user cancel, no error alert (filter on `NSUserCancelledError`) — Cancel is not a failure.

**Result.** The toolbar reads correctly at a glance: one obvious action, one "more" menu. The export progress lives inside the trigger, not in a separate banner.

**Talking points.** Toolbar real estate is a hierarchy decision, not a layout decision. If you have to ask "which of these is the primary action," the design hasn't decided yet.

---

## 6. Export summary sheet: success + integrity in one view

**File:** `CumbiaMoves/Views/Library/LibraryView.swift` (`ExportSummarySheet`)

**Problem.** After a backup operation, the user needs to know two things: *did it succeed*, and *was anything weird about my data*. A bare "Export complete" toast answers the first and ignores the second. A pile of warnings answers the second and buries the first.

**Decision.** A single sheet with three sections:
1. **A green seal headline** — `checkmark.seal.fill` + "Export complete." Confidence first.
2. **Contents** — video count, move count. The "what you got" receipt.
3. **Integrity** — missing files, orphan files, orphan moves. When all zeros, it shows "No issues found" in secondary color. When non-zero, it offers a `DisclosureGroup` so the *count* is always visible but the *list* is opt-in.

**Result.** Users who don't care see a green checkmark and dismiss. Users who do care expand the disclosure and see file-level detail. The same view serves both audiences without a mode switch.

**Talking points.** Progressive disclosure isn't about hiding information — it's about ranking it. The headline answers the question "did it work?" The disclosure answers "is anything wrong?" Putting them in the same sheet means the user never has to ask twice.

---

## 7. Small details worth naming

These are individually minor but compound into "feels nice":

- **Haptics on delete.** `Haptics.medium()` after a library deletion — confirms a destructive action through a non-visual channel, which matters on a phone you might be holding to a mirror while practicing.
- **Loop / mute as first-class controls.** Loop and mute live in the action rail, not buried in a settings sheet — because for dance-practice use they're toggled multiple times per session.
- **`String(describing:)` over `localizedDescription` for SwiftData errors.** Localized descriptions of CoreData/SwiftData errors are notoriously empty; the raw `description` is what reviewers and support staff actually need. A small choice, but it's the difference between a useful bug report and a useless one.
- **The `+` icon swaps to a `ProgressView` mid-import.** State-in-place beats a separate spinner row — the user's eye is already on the button they just tapped.
- **`fileExporter(contentType: .zip)` + a custom `FileDocument` wrapping a temp URL.** Lets Files.app, AirDrop, and iCloud Drive all accept the export through the system share sheet, instead of a bespoke "where do you want to save" UI.

---

## Patterns I'd reuse

A few of the decisions above are general enough to take to other projects:

1. **Export-before-destroy.** Any destructive recovery action should offer to preserve the artifact first, and the export path must not depend on the broken subsystem.
2. **Stable coordinate spaces under gesture.** When a drag mutates a value that layout depends on, introduce a fixed mapping. Don't try to dampen the symptom.
3. **One sheet, two audiences.** When success-vs-error isn't binary (success-with-warnings is a real state), put the headline and the details in the same view with progressive disclosure.
4. **Toolbar hierarchy = product hierarchy.** Frequency of use, not symmetry, decides what gets the prominent slot.
5. **Match the user's existing mental model before inventing a new one.** The TikTok action rail wasn't picked because it's trendy — it was picked because the target audience already speaks it fluently.
