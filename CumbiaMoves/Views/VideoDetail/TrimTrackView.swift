import SwiftUI
import UIKit

struct TrimTrackView: View {
    let controller: PlaybackController
    let videoID: UUID
    let videoURL: URL
    let moves: [Move]
    let allowsMarkerEditing: Bool

    @State private var trackWidth: CGFloat = 1

    @State private var dragTarget: DragTarget?
    @State private var hasMoved = false
    @State private var pressLocationX: CGFloat = 0

    @State private var armedMarkerIdx: Int?
    @State private var armedOriginalTime: TimeInterval = 0
    @State private var armedStartPlayhead: TimeInterval = 0
    @State private var prevDragTime: TimeInterval = 0
    @State private var wasAtClamp = false
    @State private var selectionGen: UISelectionFeedbackGenerator?

    private enum DragTarget {
        case playhead
        case marker(Int)
    }

    private var dur: TimeInterval { max(1, controller.duration) }

    private func xFor(_ t: TimeInterval) -> CGFloat {
        CGFloat(t / dur) * trackWidth
    }

    private func timeFor(_ x: CGFloat) -> TimeInterval {
        TimeInterval(max(0, min(1, x / trackWidth))) * dur
    }

    private func isMarkerActive(_ idx: Int) -> Bool {
        if case .marker(let i) = dragTarget { return i == idx }
        return false
    }

    private var isDraggingPlayhead: Bool {
        if case .playhead = dragTarget { return true }
        return false
    }

    var body: some View {
        let trackH = 44.0

        ZStack(alignment: .topLeading) {
            ThumbnailStripView(
                videoURL: videoURL,
                videoID: videoID,
                duration: controller.duration,
                height: trackH
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
            }

            ForEach(moves.filter(\.isExcluded)) { move in
                let x = xFor(move.time)
                let w = xFor(move.endTime ?? dur) - x
                Rectangle()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: max(0, w), height: trackH)
                    .offset(x: x)
                    .allowsHitTesting(false)
            }

            ForEach(Array(moves.dropLast().enumerated()), id: \.offset) { idx, move in
                let mx = xFor(move.endTime ?? dur)
                let active = isMarkerActive(idx)
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: active ? 6 : 2, height: trackH + 8)
                    .shadow(color: active ? Color.accentColor.opacity(0.6) : .clear,
                            radius: active ? 6 : 0)
                    .offset(x: mx - (active ? 3 : 1), y: -4)
                    .animation(.spring(response: 0.28, dampingFraction: 0.7), value: active)
                    .allowsHitTesting(false)
            }

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
        .gesture(combinedGesture)
    }

    private var combinedGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged(handleDragChanged)
            .onEnded(handleDragEnded)
            .simultaneously(with:
                LongPressGesture(minimumDuration: 0.5, maximumDistance: 10)
                    .onEnded { _ in handleLongPress() }
            )
    }

    private func handleDragChanged(_ value: DragGesture.Value) {
        if pressLocationX == 0, !hasMoved {
            pressLocationX = value.startLocation.x
        }

        let moved = abs(value.translation.width) > 4 || abs(value.translation.height) > 4
        if moved { hasMoved = true }

        if dragTarget == nil, moved, armedMarkerIdx == nil {
            dragTarget = .playhead
            controller.pause()
        }

        switch dragTarget {
        case .playhead:
            controller.seek(to: max(0, min(timeFor(value.location.x), dur)))
        case .marker(let idx):
            handleMarkerDrag(toX: value.location.x, idx: idx)
        case nil:
            break
        }
    }

    private func handleDragEnded(_ value: DragGesture.Value) {
        if !hasMoved, dragTarget == nil {
            controller.seek(to: timeFor(value.startLocation.x))
        }

        if case .marker = dragTarget {
            Haptics.light()
        }

        dragTarget = nil
        armedMarkerIdx = nil
        hasMoved = false
        pressLocationX = 0
        wasAtClamp = false
        selectionGen = nil
    }

    private func handleLongPress() {
        guard allowsMarkerEditing else { return }
        guard !hasMoved else { return }
        guard dragTarget == nil else { return }

        let pressX = pressLocationX
        var pick: (idx: Int, dist: CGFloat)?
        for (idx, move) in moves.dropLast().enumerated() {
            let mx = xFor(move.endTime ?? dur)
            let d = abs(pressX - mx)
            if pick == nil || d < pick!.dist {
                pick = (idx, d)
            }
        }

        guard let chosen = pick, chosen.dist < 22 else { return }
        guard chosen.idx < moves.count - 1 else { return }

        let originalTime = moves[chosen.idx].endTime ?? dur
        armedMarkerIdx = chosen.idx
        armedOriginalTime = originalTime
        armedStartPlayhead = controller.currentTime
        prevDragTime = originalTime
        wasAtClamp = false

        let gen = UISelectionFeedbackGenerator()
        gen.prepare()
        selectionGen = gen

        controller.pause()
        Haptics.medium()
        dragTarget = .marker(chosen.idx)
    }

    private func handleMarkerDrag(toX x: CGFloat, idx: Int) {
        guard idx < moves.count - 1 else { return }
        let prev = moves[idx]
        let next = moves[idx + 1]
        let minT = prev.time + 0.5
        let maxT = (next.endTime ?? dur) - 0.5
        guard minT < maxT else { return }

        let desired = timeFor(x)
        let clamped = max(minT, min(desired, maxT))

        let nowAtClamp = (desired < minT || desired > maxT)
        if nowAtClamp, !wasAtClamp {
            Haptics.rigid()
        }
        wasAtClamp = nowAtClamp

        if crossed(prev: prevDragTime, curr: clamped, threshold: armedOriginalTime) {
            selectionGen?.selectionChanged()
            selectionGen?.prepare()
        } else if crossed(prev: prevDragTime, curr: clamped, threshold: armedStartPlayhead) {
            selectionGen?.selectionChanged()
            selectionGen?.prepare()
        }

        prevDragTime = clamped

        prev.endTime = clamped
        next.time = clamped
        controller.seek(to: clamped)
    }

    private func crossed(prev: TimeInterval, curr: TimeInterval, threshold: TimeInterval) -> Bool {
        (prev < threshold && curr >= threshold) || (prev > threshold && curr <= threshold)
    }
}
