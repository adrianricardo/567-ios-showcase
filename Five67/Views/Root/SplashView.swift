import SwiftUI

struct SplashView: View {
    var onFinished: () -> Void

    @State private var digitVisible: [Bool] = [false, false, false]

    private let popDelays: [Double] = [0.10, 0.25, 0.40]
    private let holdAfterLastPop: Double = 0.55

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { proxy in
                let side = min(proxy.size.width, proxy.size.height) * 0.62
                ZStack {
                    digit("LogoDigit5", index: 0)
                    digit("LogoDigit6", index: 1)
                    digit("LogoDigit7", index: 2)
                }
                .frame(width: side, height: side)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
        }
        .task {
            for (index, delay) in popDelays.enumerated() {
                try? await Task.sleep(for: .seconds(delay - (index == 0 ? 0 : popDelays[index - 1])))
                withAnimation(.spring(response: 0.42, dampingFraction: 0.58)) {
                    digitVisible[index] = true
                }
            }
            try? await Task.sleep(for: .seconds(holdAfterLastPop))
            onFinished()
        }
    }

    private func digit(_ name: String, index: Int) -> some View {
        Image(name)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .scaleEffect(digitVisible[index] ? 1.0 : 0.3)
            .opacity(digitVisible[index] ? 1.0 : 0.0)
    }
}

#Preview {
    SplashView(onFinished: {})
}
