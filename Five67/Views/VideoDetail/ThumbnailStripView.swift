import SwiftUI

struct ThumbnailStripView: View {
    let videoURL: URL
    let videoID: UUID
    let duration: TimeInterval
    let height: CGFloat

    @State private var images: [UIImage?] = []
    @State private var loadTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geo in
            let count = max(2, Int(geo.size.width / height))
            ZStack {
                // Placeholder base
                Rectangle()
                    .fill(Color(.systemGray5))

                // Thumbnails
                HStack(spacing: Spacing.none) {
                    ForEach(0..<images.count, id: \.self) { i in
                        Group {
                            if let img = images[i] {
                                Image(uiImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                Rectangle()
                                    .fill(Color(.systemGray5))
                            }
                        }
                        .frame(width: geo.size.width / CGFloat(images.count), height: height)
                        .clipped()
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .onChange(of: count) { _, newCount in reload(count: newCount) }
            .onChange(of: height)  { _, _ in reload(count: count) }
            .onAppear  { reload(count: count) }
            .onDisappear { loadTask?.cancel() }
        }
        .frame(height: height)
    }

    private func reload(count: Int) {
        loadTask?.cancel()
        images = [UIImage?](repeating: nil, count: count)
        loadTask = Task(priority: .userInitiated) {
            let loaded = await ThumbnailService.shared.thumbnails(
                for: videoURL,
                videoID: videoID,
                count: count,
                height: height,
                duration: duration
            )
            guard !Task.isCancelled else { return }
            await MainActor.run { images = loaded }
        }
    }
}
