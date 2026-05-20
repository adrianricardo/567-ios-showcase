import SwiftUI

enum CoachTipArrow {
    case up, down, left, right
}

/// Small instructional callout used for first-time progressive coachmarks.
/// Renders a rounded bubble with a triangular arrow pointing at the
/// affordance the tip is teaching.
struct CoachTip: View {
    let text: LocalizedStringKey
    var arrow: CoachTipArrow = .up

    private let bubbleFill = Color.accentColor
    private let bubbleStroke = Color.white.opacity(0.2)
    private let textColor = Color.white

    var body: some View {
        let bubble = Text(text)
            .font(.footnote.weight(.medium))
            .foregroundStyle(textColor)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(bubbleFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(bubbleStroke, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.18), radius: 6, y: 2)

        switch arrow {
        case .up:
            VStack(spacing: -1) {
                ArrowTriangle().fill(bubbleFill).frame(width: 14, height: 7)
                bubble
            }
        case .down:
            VStack(spacing: -1) {
                bubble
                ArrowTriangle().fill(bubbleFill).rotationEffect(.degrees(180)).frame(width: 14, height: 7)
            }
        case .left:
            HStack(spacing: -1) {
                ArrowTriangle().fill(bubbleFill).rotationEffect(.degrees(-90)).frame(width: 7, height: 14)
                bubble
            }
        case .right:
            HStack(spacing: -1) {
                bubble
                ArrowTriangle().fill(bubbleFill).rotationEffect(.degrees(90)).frame(width: 7, height: 14)
            }
        }
    }
}

private struct ArrowTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
