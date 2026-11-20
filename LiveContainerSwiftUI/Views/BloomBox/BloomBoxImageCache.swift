import SwiftUI
import ImageIO
import AVFoundation
import CoreImage

/// All filesystem reads and image decoding happen off the SwiftUI render thread.
enum BloomBoxImageCache {
    private static let cache: NSCache<NSString, UIImage> = {
        let value = NSCache<NSString, UIImage>()
        value.totalCostLimit = 48 * 1024 * 1024
        return value
    }()

    static func downsample(_ url: URL, maxPixelSize: Int) -> UIImage? {
        let side = max(32, min(3072, maxPixelSize))
        // Imported themes may overwrite the same wallpaper path: cache by file
        // version, not only by URL. This metadata read runs on the worker thread.
        let metadata = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        let version = "\(metadata?.contentModificationDate?.timeIntervalSince1970 ?? 0)|\(metadata?.fileSize ?? 0)"
        let key = "\(url.path)|\(side)|\(version)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [
            kCGImageSourceShouldCache: false
        ] as CFDictionary) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: side
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }
        let decoded = UIImage(cgImage: cgImage)
        cache.setObject(decoded, forKey: key, cost: cgImage.bytesPerRow * cgImage.height)
        return decoded
    }

    /// First frame, decoded and blurred once; never blur a playing AVPlayer.
    static func videoPoster(_ url: URL, maxPixelSize: Int, blurRadius: CGFloat) -> UIImage? {
        let key = "poster|\(url.path)|\(maxPixelSize)|\(blurRadius)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let image: CGImage
        if url.pathExtension.lowercased() == "gif" {
            guard let frame = downsample(url, maxPixelSize: maxPixelSize)?.cgImage else { return nil }
            image = frame
        } else {
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: maxPixelSize, height: maxPixelSize)
            guard let frame = try? generator.copyCGImage(at: .zero, actualTime: nil) else { return nil }
            image = frame
        }
        let output: CGImage
        if blurRadius > 0 {
            let original = CIImage(cgImage: image)
            let filter = CIFilter(name: "CIGaussianBlur", parameters: [
                kCIInputImageKey: original, kCIInputRadiusKey: blurRadius
            ])
            guard let blurred = filter?.outputImage?.cropped(to: original.extent),
                  let result = CIContext(options: [.useSoftwareRenderer: false])
                    .createCGImage(blurred, from: original.extent) else { return nil }
            output = result
        } else {
            output = image
        }
        let result = UIImage(cgImage: output)
        cache.setObject(result, forKey: key, cost: output.bytesPerRow * output.height)
        return result
    }
}

struct BloomBoxDownsampledImage: View {
    let url: URL
    let fit: Bool
    let maxPixelSize: Int
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: fit ? .fit : .fill)
            } else {
                Color.clear
            }
        }
        .task(id: "\(url.path)|\(maxPixelSize)") {
            image = nil
            let loaded = await Task.detached(priority: .utility) {
                BloomBoxImageCache.downsample(url, maxPixelSize: maxPixelSize)
            }.value
            guard !Task.isCancelled else { return }
            image = loaded
        }
    }
}

struct BloomBoxStaticVideoPoster: View {
    let url: URL
    let fit: Bool
    let maxPixelSize: Int
    var blurRadius: CGFloat = 0
    var clearBackground = false
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable()
                    .aspectRatio(contentMode: fit ? .fit : .fill)
            } else {
                clearBackground ? Color.clear : Color.black
            }
        }
        .task(id: "\(url.path)|\(maxPixelSize)|\(blurRadius)") {
            image = nil
            let loaded = await Task.detached(priority: .utility) {
                BloomBoxImageCache.videoPoster(url, maxPixelSize: maxPixelSize,
                                               blurRadius: blurRadius)
            }.value
            guard !Task.isCancelled else { return }
            image = loaded
        }
    }
}
