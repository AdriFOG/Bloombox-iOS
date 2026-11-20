import Foundation
import AVFoundation
import ImageIO
import CoreGraphics
import CoreVideo

/// Import-time conversion; no per-frame GIF decoding in the launcher render path.
/// The original GIF is kept whenever hardware HEVC/alpha encoding is unavailable.
enum BloomBoxGIFTranscoder {
    static func convert(_ source: URL, to destination: URL, preserveAlpha: Bool) throws {
        guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil),
              CGImageSourceGetType(imageSource) as String? == "com.compuserve.gif" else {
            throw BloomBoxMotionMedia.failure("GIF no válido para convertir.")
        }
        let count = CGImageSourceGetCount(imageSource)
        guard (1...500).contains(count) else {
            throw BloomBoxMotionMedia.failure("El GIF es demasiado largo.")
        }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
              let sourceWidth = properties[kCGImagePropertyPixelWidth] as? Int,
              let sourceHeight = properties[kCGImagePropertyPixelHeight] as? Int,
              sourceWidth > 0, sourceHeight > 0 else {
            throw BloomBoxMotionMedia.failure("No se pudo leer el tamaño del GIF.")
        }

        let scale = min(1.0, 720.0 / Double(max(sourceWidth, sourceHeight)))
        let width = max(2, Int(Double(sourceWidth) * scale) & ~1)
        let height = max(2, Int(Double(sourceHeight) * scale) & ~1)
        let writer = try AVAssetWriter(outputURL: destination, fileType: .mov)
        let settings: [String: Any] = [
            AVVideoCodecKey: preserveAlpha ? AVVideoCodecType.hevcWithAlpha : AVVideoCodecType.hevc,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: max(250_000, min(3_000_000, width * height * 3))
            ]
        ]
        guard writer.canApply(outputSettings: settings, forMediaType: .video) else {
            throw BloomBoxMotionMedia.failure("HEVC no está disponible en este dispositivo.")
        }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        let adapter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input,
                                                           sourcePixelBufferAttributes: attributes)
        writer.add(input)
        var completed = false
        defer {
            if !completed {
                writer.cancelWriting()
                try? FileManager.default.removeItem(at: destination)
            }
        }
        guard writer.startWriting() else {
            throw writer.error ?? BloomBoxMotionMedia.failure("No se pudo iniciar HEVC.")
        }
        writer.startSession(atSourceTime: .zero)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 720,
            kCGImageSourceShouldCacheImmediately: true
        ]
        var elapsed = 0.0
        for index in 0..<count {
            guard let image = CGImageSourceCreateThumbnailAtIndex(imageSource, index, options as CFDictionary),
                  let pool = adapter.pixelBufferPool else {
                throw BloomBoxMotionMedia.failure("No se pudo decodificar un cuadro del GIF.")
            }
            var buffer: CVPixelBuffer?
            guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buffer) == kCVReturnSuccess,
                  let buffer else {
                throw BloomBoxMotionMedia.failure("Sin memoria para convertir GIF.")
            }
            CVPixelBufferLockBaseAddress(buffer, [])
            let pointer = CVPixelBufferGetBaseAddress(buffer)
            let space = CGColorSpaceCreateDeviceRGB()
            let info = CGImageAlphaInfo.premultipliedFirst.rawValue |
                CGBitmapInfo.byteOrder32Little.rawValue
            guard let context = CGContext(data: pointer, width: width, height: height,
                                          bitsPerComponent: 8,
                                          bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                          space: space, bitmapInfo: info) else {
                CVPixelBufferUnlockBaseAddress(buffer, [])
                throw BloomBoxMotionMedia.failure("No se pudo componer el GIF.")
            }
            context.clear(CGRect(x: 0, y: 0, width: width, height: height))
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            CVPixelBufferUnlockBaseAddress(buffer, [])

            var retries = 0
            while !input.isReadyForMoreMediaData && writer.status == .writing && retries < 1000 {
                Thread.sleep(forTimeInterval: 0.005)
                retries += 1
            }
            guard writer.status == .writing, input.isReadyForMoreMediaData,
                  adapter.append(buffer, withPresentationTime:
                    CMTime(seconds: elapsed, preferredTimescale: 600)) else {
                throw writer.error ?? BloomBoxMotionMedia.failure("Fallo al codificar HEVC.")
            }
            let frameProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, index, nil) as? [CFString: Any]
            let gif = frameProperties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let delay = (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double)
                ?? (gif?[kCGImagePropertyGIFDelayTime] as? Double) ?? 0.1
            elapsed += delay.isFinite && delay >= 0.02 ? min(delay, 10.0) : 0.1
        }
        input.markAsFinished()
        writer.endSession(atSourceTime: CMTime(seconds: elapsed, preferredTimescale: 600))
        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting { semaphore.signal() }
        guard semaphore.wait(timeout: .now() + 120) == .success,
              writer.status == .completed else {
            throw writer.error ?? BloomBoxMotionMedia.failure("No terminó la conversión HEVC.")
        }
        completed = true
    }
}
