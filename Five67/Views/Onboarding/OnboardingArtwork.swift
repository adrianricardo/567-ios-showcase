import SwiftUI

struct Five67BrandMark: View {
    var visibleDigits = 3

    var body: some View {
        ZStack {
            ForEach(Array(["LogoDigit5", "LogoDigit6", "LogoDigit7"].enumerated()), id: \.offset) { index, name in
                Image(name)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .opacity(index < visibleDigits ? 1 : 0)
                    .scaleEffect(index < visibleDigits ? 1 : 0.72)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("567")
    }
}

struct OnboardingBrandHero: View {
    let reduceMotion: Bool
    @State private var settled = false

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Five67BrandMark()
                .frame(width: 148, height: 148)
                .scaleEffect(settled ? 1 : 0.94)

            Text("Your moves, ready when you are")
                .font(.headline.weight(.bold))
                .foregroundStyle(Theme.stagePrimary)

            HStack(spacing: Spacing.sm) {
                productPill("Save", systemImage: "square.and.arrow.down")
                productPill("Name", systemImage: "pencil")
                productPill("Loop", systemImage: "repeat")
            }
        }
        .padding(Spacing.xl2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Theme.stageSurface,
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Theme.stageStroke, lineWidth: 1)
        }
        .onAppear {
            guard !reduceMotion else {
                settled = true
                return
            }
            withAnimation(.smooth(duration: 0.45)) {
                settled = true
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func productPill(_ label: String, systemImage: String) -> some View {
        Label(label, systemImage: systemImage)
            .font(.caption.weight(.bold))
            .foregroundStyle(Theme.stageSecondary)
            .padding(.horizontal, Spacing.smPlus)
            .frame(minHeight: 36)
            .background(Theme.stageRaisedSurface, in: Capsule())
    }
}

struct OnboardingPayoffArtwork: View {
    let reduceMotion: Bool
    @State private var progress: CGFloat = 0.22

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack(spacing: Spacing.sm) {
                workflowStep("1", "Trim", systemImage: "scissors")
                workflowStep("2", "Name", systemImage: "pencil")
                workflowStep("3", "Loop", systemImage: "repeat")
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("One class video")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.stageSecondary)
                    .textCase(.uppercase)
                Text("A move you can find and practice")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.stagePrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.stageRaisedSurface)
                    Capsule()
                        .fill(StyleAccentPalette.salsa.color)
                        .frame(width: max(22, proxy.size.width * progress))
                }
            }
            .frame(height: 8)
            .accessibilityHidden(true)
        }
        .padding(Spacing.xl2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            Theme.stageSurface,
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Theme.stageStroke, lineWidth: 1)
        }
        .onAppear {
            if reduceMotion {
                progress = 0.76
            } else {
                withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                    progress = 0.94
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Trim, name, and loop a class video into a move you can find and practice")
    }

    private func workflowStep(_ number: String, _ label: String, systemImage: String) -> some View {
        VStack(spacing: Spacing.xsPlus) {
            Image(systemName: systemImage)
                .font(.headline.weight(.bold))
            Text("\(number) · \(label)")
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(Theme.stagePrimary)
        .frame(maxWidth: .infinity, minHeight: 72)
        .background(Theme.stageRaisedSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
