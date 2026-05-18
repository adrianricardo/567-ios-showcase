import SwiftUI

struct TrimTrackView: View {
    let controller: PlaybackController
    let videoID: UUID
    let videoURL: URL
    let moves: [Move]

    @State private var trackWidth: CGFloat = 1
    @State private var dragging: DragTarget?

    private enum DragTarget {
        case playhead
        case splitMarker(Int)
    }

    private var dur: TimeInterval { max(1, controller.duration) }

    private func xFor(_ t: TimeInterval) -> CGFloat {
        CGFloat(t / dur) * trackWidth
    }

    private func timeFor(_ x: CGFloat) -> TimeInterval {
        TimeInterval(max(0, min(1, x / trackWidth))) * dur
    }

    private func isMarkerActive(_ idx: Int) -> Bool {
        if case .splitMarker(let i) = dragging { return i == idx }
        return false
    }

    private var isDraggingPlayhead: Bool {
        if case .playhead = dragging { return true }
        return false
    }

    var body: some View {
        let trackH = 36.0

        ZStack(alignment: .topLeading) {
            ThumbnailStripView(
                videoURL: videoURL,
                videoID: videoID,
                duration: controller.duration,
                height: trackH
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Excluded segment dim overlays
            ForEach(moves.filter(\.isExcluded)) { move in
                let x = xFor(move.time)
                let w = xFor(move.endTime ?? dur) - x
                Rectangle()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: max(0, w), height: trackH)
                    .offset(x: x)
                    .allowsHitTesting(false)
            }

            // Split markers (at each segment boundary except first/last)
            ForEach(Array(moves.dropLast().enumerated()), id: \.offset) { idx, move in
                let mx = xFor(move.endTime ?? dur)
                let active = isMarkerActive(idx)
                ZStack {
                    // wider invisible hit area
                    Color.clear.frame(width: 20, height: trackH + 8)
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: active ? 3 : 2, height: trackH + 8)
                }
                .offset(x: mx - 10, y: -4)
                .allowsHitTesting(false)
            }

            // Playhead
            Capsule()
                .fill(Color.white)
                .shadow(radius: isDraggingPlayhead ? 4 : 2)
                .frame(width: isDraggingPlayhead ? 3 : 2, height: trackH + 6)
                .offset(x: xFor(controller.currentTime) - 1, y: -3)
                .animation(.interactiveSpring(response: 0.15), value: isDraggingPlayhead)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, minHeight: trackH, maxHeight: trackH)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear  { trackWidth = geo.size.width }
                    .onChange(of: geo.size.width) { _, w in trackWidth = w }
            }
        )
        .contentShape(Rectangle())
        .gesture(trackGesture)
        .onTapGesture { location in
            controller.seek(to: timeFor(location.x))
        }
    }

    private var trackGesture: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .local)
            .onChanged { value in
                if dragging == nil {
                    let sx = value.startLocation.x
                    var closestMarker: Int? = nil
                    var closestDist: CGFloat = 22
                    for (idx, move) in moves.dropLast().enumerated() {
                        let mx = xFor(move.endTime ?? dur)
                        let d = abs(sx - mx)
                        if d < closestDist {
                            closestDist = d
                            closestMarker = idx
                        }
                    }
                    if let markerIdx = closestMarker {
                        dragging = .splitMarker(markerIdx)
                    } else {
                        dragging = .playhead
                        controller.seek(to: timeFor(sx))
                    }
                    controller.pause()
                }

                let t = timeFor(value.location.x)
                switch dragging! {
                case .playhead:
                    controller.seek(to: max(0, min(t, dur)))
                case .splitMarker(let idx):
                    guard idx < moves.count - 1 else { break }
                    let prev = moves[idx]
                    let next = moves[idx + 1]
                    let minT = prev.time + 0.5
                    let maxT = (next.endTime ?? dur) - 0.5
                    guard minT < maxT else { break }
                    let clamped = max(minT, min(t, maxT))
                    prev.endTime = clamped
                    next.time = clamped
                    controller.seek(to: clamped)
                }
            }
            .onEnded { _ in
                guard dragging != nil else { return }
                dragging = nil
                Haptics.light()
            }
    }
}
