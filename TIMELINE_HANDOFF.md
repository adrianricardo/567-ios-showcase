# Timeline Handoff

## Original Issue

The Moves tab timeline should look and behave like the provided iMovie-style reference:

- The timeline band can span the screen, but the actual segment track should align with the app content below, not hug the device edge.
- Segment pills should be rounded gray blocks.
- Blue should represent playback progress within the currently playing segment only.
- There should be clear whitespace between each segment pill and the divider handle.
- Divider handles should sit centered in the gap between adjacent segment pills.
- Dragging a divider should trim the boundary between adjacent segments without making the overall timeline appear to move, resize, or reflow.
- Tapping/dragging on a segment away from a divider should scrub/select, not accidentally trigger divider trim.

## Files Involved

- `CumbiaMoves/Views/VideoDetail/TrimTrackView.swift`
- `CumbiaMoves/Views/Moves/MovesView.swift`
- `CumbiaMoves/Views/VideoDetail/PlayerHeaderView.swift`

## What Was Tried

1. Removed the play/pause button near the timeline and relied on tapping the video surface for play/pause.
2. Made the timeline visually larger: `52pt` height, `18pt` gap, `8pt` rounded handles.
3. Removed/adjusted horizontal padding several times trying to interpret "edge-to-edge."
4. Added `fillsVisibleRange` so the first visible segment maps to the left of the track and the last visible segment maps to the right.
5. Tried drawing a continuous gray rail behind segments. This made the track read like a progress bar instead of separate segment pills.
6. Tried making the entire current segment blue. User clarified this was wrong: blue should be current-time progress within the segment.
7. Restored blue as current-segment progress and added whitespace around handles.
8. Tightened divider hit radius from `18pt` to `9pt`.
9. Added `32pt` horizontal padding in `MovesView` to better align the track with row/header content.
10. Tried a sequence-based layout where segments and gaps were laid out as `segment, gap, segment`. This caused segment widths and apparent track position to change while dragging, because widths were recomputed from mutable segment durations.
11. Reverted back to fixed visible-span time mapping:
    - `timelineStart = first visible move start`
    - `timelineEnd = last visible move end`
    - `xFor(time)` maps into fixed `trackWidth`
    - segment edges pull inward by `segmentGap / 2`
    - handles stay at `xFor(boundaryTime)`

## Current Problem

The timeline still appears to shift or resize while dragging a divider.

The latest screenshots show that the visible segment pills still do not communicate a stable full-width timeline. The outer SwiftUI frame may technically be full width, but because only the segment pills are visible, the eye reads the first/last pill positions as the track bounds. When segment widths change during trim, it looks like the timeline itself is moving.

This is especially confusing when the first segment is short. The first gray pill is narrow, so most of the left or right side looks visually empty. Even if the math anchors the track, there is no explicit visual object showing the fixed rail.

## Likely Root Cause

The timeline lacks a first-class, stable rail/layout object.

The code currently draws segment pills directly into a `ZStack` and uses their positions as the primary visual. That means changing segment durations changes the visible mass of the timeline, and the user perceives the whole control as unstable.

The track frame and segment rendering need to be separated:

- The track frame should be fixed by layout.
- Segment positions should be mapped inside that fixed frame.
- The fixed frame should remain visually intelligible even when segment sizes change.

## Recommended Next Approach

Build `TrimTrackView` around an explicit fixed rail:

1. Keep the outer track width fixed inside the chosen content inset.
2. Draw a stable rail/background object for the full available track width. It can be subtle, but it must make the timeline bounds clear.
3. Draw segment pills inside that fixed rail using visible-span time mapping.
4. Keep interior gaps centered around each boundary:
   - previous segment ends at `xFor(boundary) - segmentGap / 2`
   - next segment starts at `xFor(boundary) + segmentGap / 2`
   - divider handle is centered at `xFor(boundary)`
5. Clip blue progress inside the current segment’s rounded shape.
6. Keep divider hit testing tied to `xFor(boundary)` with a small radius around the gap/handle only.
7. Consider freezing `timelineStart` and `timelineEnd` during a drag if outer handles are ever added. Today only interior boundaries are editable, so visible-span mapping should be stable as long as first start and last end do not change.

## Important Product Clarification

The desired alignment is not `x = 0` at the device edge. The timeline band can be full width, but the actual segment track should align with the visible content below, approximately the same inset as the date header/text content. Current `MovesView` uses `.padding(.horizontal, 32)` on the track.

## Current State Before Handoff

As of this handoff:

- The project builds.
- `TrimTrackView` uses fixed visible-span mapping, not sequence-width layout.
- `MovesView` applies `.padding(.horizontal, 32)` to the timeline.
- `handleHitRadius` is `9`.
- Blue progress is clipped inside the current segment.

The next agent should not assume the current implementation is correct visually. The next productive step is to add or redesign the fixed rail so the timeline’s bounds are explicit and stable during drag.
