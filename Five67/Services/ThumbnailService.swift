import AVFoundation
import UIKit

actor ThumbnailService {
    static let shared = ThumbnailService()
    private init() {}

    // MARK: Public API

    func thumbnails(
        for url: URL,
        videoID: UUID,
        count: Int,
        height: CGFloat,
        duration: TimeInterval
    ) async -> [UIImage?] {
        guard count > 0, duration > 0 else { return [] }
        var results = [UIImage?](repeating: nil, count: count)
        await withTaskGroup(of: (Int, UIImage?).self) { group in
            for i in 0..<count {
                let t = (Double(i) / Double(max(1, count - 1))) * duration
                group.addTask { [weak self] in
                    let img = await self?.thumbnail(for: url, at: t, videoID: videoID, height: height)
                    return (i, img)
                }
            }
            for await (i, img) in group {
                results[i] = img
            }
        }
        return results
    }

    func thumbnail(
        for url: URL,
        at time: TimeInterval,
        videoID: UUID,
        height: CGFloat
    ) async -> UIImage? {
        let cacheURL = cacheFile(videoID: videoID, time: time, height: height)

        if let cached = UIImage(contentsOfFile: cacheURL.path) {
            return cached
        }

        let asset = AVURLAsset(url: url)
        let gen   = AVAssetImageGenerator(asset: asset)
        gen.requestedTimeToleranceBefore = .zero
        gen.requestedTimeToleranceAfter  = .zero
        let side = Int(height * 2)
        gen.maximumSize = CGSize(width: side * 2, height: side)

        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        guard let (cgImage, _) = try? await gen.image(at: cmTime) else { return nil }
        let image = UIImage(cgImage: cgImage)

        try? FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        if let data = image.jpegData(compressionQuality: 0.7) {
            try? data.write(to: cacheURL)
        }
        return image
    }

    func clearCache(for videoID: UUID) {
        let dir = cacheDir(for: videoID)
        try? FileManager.default.removeItem(at: dir)
    }

    // MARK: Private

    private func cacheDir(for videoID: UUID) -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("thumbs")
            .appendingPathComponent(videoID.uuidString)
    }

    private func cacheFile(videoID: UUID, time: TimeInterval, height: CGFloat) -> URL {
        let key = String(format: "%.1f_h%.0f.jpg", time, height)
        return cacheDir(for: videoID).appendingPathComponent(key)
    }
}
