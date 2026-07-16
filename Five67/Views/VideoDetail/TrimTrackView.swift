import SwiftUI

struct TrimTrackView: View {
    let controller: PlaybackController
    let videoID: UUID
    let videoURL: URL
    let moves: [Move]
    let allowsMarkerEditing: Bool
    var accentColor: Color = Color.accentColor
    var fillsVisibleRange = false
    var showsPlaceholderWhenEmpty = false
    var onTapSegment: ((Move, TimeInterval) -> Void)? = nil
    var onHandleDragComplete: (() -> Void)? = nil

    @State private var trackWidth: CGFloat = 1
    @State private var dragTarget: DragTarget?
    @State private var hasMoved = false
    @State private var pressLocationX: CGFloat = 0
    @State private var wasAtClamp = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    private enum DragTarget {
        case scrub
        case handle(Int)
    }

    private let trackHeight: CGFloat = 52
    private let segmentGap: CGFloat = 18
    private let handleVisualWidth: CGFloat = 8
    private let handleHitRadius: CGFloat = 9
    private let cornerRadius: CGFloat = 8

    private var dur: TimeInterval {
        let d = controller.duration
        return (d.isFinite && d > 0) ? d : 1
    }

    private var timelineMoves: [Move] {
        moves.sorted { $0.time < $1.time }
    }

    private var timelineStart: TimeInterval {
        guard fillsVisibleRange, let first = timelineMoves.first else { return 0 }
        return max(0, min(first.time, dur))
    }

    private var timelineEnd: TimeInterval {
        guard fillsVisibleRange, let last = timelineMoves.last else { return dur }
        return max(timelineStart, min(last.endTime ?? dur, dur))
    }

    private var timelineDuration: TimeInterval {
        max(0.001, timelineEnd - timelineStart)
    }

    private var trackFill: Color { Color(.systemGray5) }
    private var excludedFill: Color { Color(.systemGray4) }
    private var playedFill: Color { accentColor }
    private var handleFill: Color { Color(.systemGray3) }
    private var handleScrim: Color { Color.black.opacity(0.08) }

    private var railStroke: Color {
        colorSchemeContrast == .increased ? Theme.stageSecondary.opacity(0.65) : Color.clear
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(railStroke, lineWidth: 1)
                .frame(height: trackHeight)

            if timelineMoves.isEmpty, showsPlaceholderWhenEmpty {
                placeholderPill
            } else {
                ForEach(timelineMoves) { move in
                    segmentView(for: move)
                }

                if allowsMarkerEditing {
                    ForEach(Array(timelineMoves.dropLast().enumerated()), id: \.offset) { idx, move in
                        handleView(at: xFor(move.endTime ?? dur), active: isHandleActive(idx))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: trackHeight, maxHeight: trackHeight)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { trackWidth = geo.size.width }
                    .onChange(of: geo.size.width) { _, w in trackWidth = w }
            }
        )
        .contentShape(Rectangle())
        .gesture(dragGesture)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Playback position")
        .accessibilityValue("\(formatTime(controller.currentTime)) of \(formatTime(dur))")
        .accessibilityHint("Swipe up or down to seek")
        .accessibilityAdjustableAction { direction in
            let increment = max(1, min(5, dur / 20))
            switch direction {
            case .increment:
                controller.seek(to: min(dur, controller.currentTime + increment))
            case .decrement:
                controller.seek(to: max(0, controller.currentTime - increment))
            @unknown default:
                break
            }
        }
    }

    private var placeholderPill: some View {
        let progressWidth = trackWidth > 0
            ? trackWidth * CGFloat(min(1, max(0, controller.currentTime / max(0.001, dur))))
            : 0
        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(trackFill)
            if progressWidth > 0 {
                Rectangle()
                    .fill(playedFill)
                    .frame(width: progressWidth)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .frame(height: trackHeight)
    }

    @ViewBuilder
    private func segmentView(for move: Move) -> some View {
        let rawStart = xFor(move.time)
        let rawEnd = xFor(move.endTime ?? dur)
        let isFirst = timelineMoves.first?.id == move.id
        let isLast = timelineMoves.last?.id == move.id
        let segStart = rawStart + (isFirst ? 0 : segmentGap / 2)
        let segEnd = rawEnd - (isLast ? 0 : segmentGap / 2)
        let segWidth = max(0, segEnd - segStart)
        let progressWidth = (isTrimming || !isCurrent(move)) ? 0 : segWidth * progress(in: move)
        let segmentFill = move.isExcluded ? excludedFill : trackFill

        if segWidth > 0 {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(segmentFill)

                if progressWidth > 0 {
                    Rectangle()
                        .fill(playedFill)
                        .frame(width: progressWidth)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .frame(width: segWidth, height: trackHeight)
            .offset(x: segStart)
        }
    }

    @ViewBuilder
    private func handleView(at x: CGFloat, active: Bool) -> some View {
        let w = active ? handleVisualWidth + 2 : handleVisualWidth
        let h = active ? 34.0 : 28.0
        let y = (trackHeight - h) / 2

        Capsule()
            .fill(handleFill)
            .frame(width: w, height: h)
            .offset(x: x - w / 2, y: y)
            .shadow(color: active ? Color.black.opacity(0.18) : handleScrim, radius: active ? 5 : 1, y: 1)
            .animation(
                reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.75),
                value: active
            )
            .allowsHitTesting(false)
    }

    private func xFor(_ t: TimeInterval) -> CGFloat {
        guard t.isFinite, trackWidth.isFinite, trackWidth > 0 else { return 0 }
        let clamped = max(timelineStart, min(t, timelineEnd))
        return CGFloat((clamped - timelineStart) / timelineDuration) * trackWidth
    }

    private func timeFor(_ x: CGFloat) -> TimeInterval {
        guard x.isFinite, trackWidth > 0 else { return timelineStart }
        let progress = TimeInterval(max(0, min(1, x / trackWidth)))
        return timelineStart + progress * timelineDuration
    }

    private func isCurrent(_ move: Move) -> Bool {
        let end = move.endTime ?? dur
        return move.time <= controller.currentTime && controller.currentTime < end
    }

    private func progress(in move: Move) -> CGFloat {
        let end = move.endTime ?? dur
        guard end > move.time else { return 0 }
        let clamped = max(move.time, min(controller.currentTime, end))
        return CGFloat((clamped - move.time) / (end - move.time))
    }

    private func isHandleActive(_ idx: Int) -> Bool {
        if case .handle(let i) = dragTarget { return i == idx }
        return false
    }

    private var isTrimming: Bool {
        if case .handle = dragTarget { return true }
        return false
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged(handleDragChanged)
            .onEnded(handleDragEnded)
    }

    private func handleDragChanged(_ value: DragGesture.Value) {
        if pressLocationX == 0, !hasMoved {
            pressLocationX = value.startLocation.x
        }
        let moved = abs(value.translation.width) > 4 || abs(value.translation.height) > 4
        if moved { hasMoved = true }

        if dragTarget == nil {
            if allowsMarkerEditing, let idx = handleIndex(near: pressLocationX) {
                dragTarget = .handle(idx)
                controller.pause()
                Haptics.medium()
            } else if moved {
                dragTarget = .scrub
                controller.pause()
            }
        }

        switch dragTarget {
        case .scrub:
            controller.seek(to: max(0, min(timeFor(value.location.x), dur)))
        case .handle(let idx):
            performHandleDrag(toX: value.location.x, idx: idx)
        case nil:
            break
        }
    }

    private func handleDragEnded(_ value: DragGesture.Value) {
        if !hasMoved, dragTarget == nil {
            let t = timeFor(value.startLocation.x)
            if let move = moveAt(time: t), let onTap = onTapSegment {
                onTap(move, t)
            } else {
                controller.seek(to: t)
            }
        }

        if case .handle = dragTarget {
            Haptics.light()
            if hasMoved { onHandleDragComplete?() }
        }

        dragTarget = nil
        hasMoved = false
        pressLocationX = 0
        wasAtClamp = false
    }

    private func handleIndex(near x: CGFloat) -> Int? {
        var best: (idx: Int, dist: CGFloat)?
        for (idx, move) in timelineMoves.dropLast().enumerated() {
            let hx = xFor(move.endTime ?? dur)
            let d = abs(x - hx)
            if best == nil || d < best!.dist {
                best = (idx, d)
            }
        }
        if let best, best.dist < handleHitRadius { return best.idx }
        return nil
    }

    private func moveAt(time: TimeInterval) -> Move? {
        timelineMoves.first { $0.time <= time && time < ($0.endTime ?? dur) } ?? timelineMoves.last
    }

    private func performHandleDrag(toX x: CGFloat, idx: Int) {
        let sortedMoves = timelineMoves
        guard idx < sortedMoves.count - 1 else { return }
        let prev = sortedMoves[idx]
        let next = sortedMoves[idx + 1]
        let minT = prev.time + 0.5
        let maxT = (next.endTime ?? dur) - 0.5
        guard minT < maxT else { return }

        let desired = timeFor(x)
        let clamped = max(minT, min(desired, maxT))
        let nowAtClamp = (desired < minT || desired > maxT)
        if nowAtClamp, !wasAtClamp { Haptics.rigid() }
        wasAtClamp = nowAtClamp

        prev.endTime = clamped
        next.time = clamped
        controller.seek(to: clamped)
    }
}
