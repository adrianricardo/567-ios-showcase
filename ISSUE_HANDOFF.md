# Moves Tab Playback Hang Handoff

## Symptom

In the `Moves` tab, tapping a move from one video works, but tapping a move from a different video can hang playback. The same problematic video plays from the `Videos` tab / `VideoDetailView`, so the copied video file is probably valid.

The hang has been reproduced when switching from:

- `DB49C457-1E4C-4D2B-8146-4A21BABD18DE.mp4`
- to `FECDA61F-FA5F-4B31-90A3-75C8B481852E.mp4`

## Representative Logs

Working first video:

```text
Loaded video: DB49C457-1E4C-4D2B-8146-4A21BABD18DE.mp4, exists=true, readable=true, bytes=19346493
Queued range playback until item is ready. start=19.201857
Player item status unknown
Asset preflight succeeded: DB49C457-1E4C-4D2B-8146-4A21BABD18DE.mp4, playable=true, duration=48.701667, tracks=4
Player item ready
Starting queued range playback. start=19.201857
Seeking to 19.201857
```

Failing second video from `Moves` tab:

```text
Loaded video: FECDA61F-FA5F-4B31-90A3-75C8B481852E.mp4, exists=true, readable=true, bytes=16622676
Queued range playback until item is ready. start=7.085333
```

Sometimes system noise appears after this:

```text
<<<< Async >>>> signalled err=-12785 at <>:3462
includesStylesSubmenu changed value to true from true
<<<< FigApplicationStateMonitor >>>> signalled err=-19431 at <>:474
```

The `FigApplicationStateMonitor` and `includesStylesSubmenu` lines appear unrelated. The important behavior is that the second item does not reach `Player item ready`, and the explicit asset preflight/timeout logs also do not appear in the captured output.

## What Was Changed

### `PlaybackController.swift`

Added AVFoundation diagnostics and guardrails:

- Logs video file existence/readability/byte size on load.
- Creates player items from `AVURLAsset`.
- Uses `AVPlayerItem(asset:automaticallyLoadedAssetKeys:)` for `.duration`, `.tracks`, and `.isPlayable`.
- Observes each new item directly with KVO before assigning it to `AVPlayer`.
- Queues move playback until item status is `.readyToPlay`.
- Logs item status transitions.
- Adds async asset preflight with `asset.load(.duration, .isPlayable, .tracks)`.
- Adds a readiness timeout task intended to log if item status stays `.unknown`.
- Clamps seek times and avoids invalid seeks.
- Uses small seek tolerance instead of exact zero tolerance.

### `VideoDetailView.swift`

Added move range validation:

- Validates move start/end range before activating a move.
- Clamps move ranges to effective video duration.
- Logs invalid persisted move ranges.
- Uses `controller.playRange(start:end:)` rather than immediate `seek` + `play`.

### `MovesView.swift`

Tried to make the Moves tab behave more like the working Videos tab:

- When a move belongs to a different video, pauses the old controller and creates a fresh `PlaybackController(videoURL:)`.
- Keys `playerSection(video:)` and `VideoPlayer` with `.id(video.id)` to force SwiftUI/AVKit to rebuild the player surface when switching videos.
- Separates selection from playback:
  - row tap sets `activeMoveID`, updates `activeVideoMoves`, and sets `pendingAutoplayMoveID`
  - `.task(id: pendingAutoplayMoveID)` calls `playPendingMoveIfNeeded()`
  - `playPendingMoveIfNeeded()` yields once before calling `controller.playRange(start:end:)`

## Validation So Far

After each change:

- Xcode live diagnostics passed.
- Full Xcode build succeeded.

No automated UI/device reproduction test exists yet.

## Current Hypotheses

1. The issue is specific to `MovesView`, not the file itself, because the same video works in `VideoDetailView`.
2. The `MovesView` player surface or SwiftUI state lifecycle may still be interfering with AVFoundation item preparation when changing active videos.
3. The active move lookup may be unstable because `activeMove` is derived only from the paged/filter-specific `moves` array. If the selected move or its related `Video` object changes during refresh/backfill, the player subtree could be recreated unexpectedly.
4. Background metadata work in `MovesView` (`backfillRecordedDates`) and thumbnail work may be doing concurrent `AVURLAsset` reads, though the first video succeeds under similar conditions.
5. `PlaybackController` task ownership may be affected by replacing the `@State` controller instance while async preflight/readiness tasks are still pending.

## Suggested Next Steps

1. Add a dedicated `@State private var activeVideo: Video?` in `MovesView` instead of deriving the player section from `activeMove?.video`.
2. Add a `@State private var activePlayerToken = UUID()` and key the entire top player section by that token whenever a new controller is created.
3. Temporarily disable `backfillRecordedDates()` in `MovesView` to rule out concurrent metadata loading.
4. Add logs at the start/end of `playPendingMoveIfNeeded()` and inside the readiness timeout task before sleeping, so we can confirm whether the task is created.
5. Consider extracting a small `MovesPlayerHostView` that owns its own `@State private var controller = PlaybackController(videoURL:)`, similar to `VideoDetailView`, and receives the selected move/video as input.
6. If the hang persists, replace `VideoPlayer` in `MovesView` with a custom `UIViewControllerRepresentable` wrapper around `AVPlayerViewController` to verify whether SwiftUI `VideoPlayer` reuse is involved.

## Important Files

- `CumbiaMoves/CumbiaMoves/Services/PlaybackController.swift`
- `CumbiaMoves/CumbiaMoves/Views/Moves/MovesView.swift`
- `CumbiaMoves/CumbiaMoves/Views/VideoDetail/VideoDetailView.swift`
- `CumbiaMoves/CumbiaMoves/Views/VideoDetail/PlayerHeaderView.swift`
- `CumbiaMoves/CumbiaMoves/Services/ThumbnailService.swift`
- `CumbiaMoves/CumbiaMoves/Services/VideoMetadata.swift`
