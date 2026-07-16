import SwiftUI

struct SplashView: View {
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visibleDigitCount = 0

    private let popDelays: [Double] = [0.10, 0.25, 0.40]
    private let holdAfterLastPop: Double = 0.55

    var body: some View {
        ZStack {
            Theme.stageBackground.ignoresSafeArea()

            GeometryReader { proxy in
                let side = min(proxy.size.width, proxy.size.height) * 0.62
                Five67BrandMark(visibleDigits: visibleDigitCount)
                .frame(width: side, height: side)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
        }
        .task {
            if reduceMotion {
                visibleDigitCount = 3
                try? await Task.sleep(for: .milliseconds(250))
                onFinished()
                return
            }

            for (index, delay) in popDelays.enumerated() {
                try? await Task.sleep(for: .seconds(delay - (index == 0 ? 0 : popDelays[index - 1])))
                withAnimation(.spring(response: 0.42, dampingFraction: 0.58)) {
                    visibleDigitCount = index + 1
                }
            }
            try? await Task.sleep(for: .seconds(holdAfterLastPop))
            onFinished()
        }
    }
}

#Preview {
    SplashView(onFinished: {})
}
