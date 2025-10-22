import Foundation
import ImageIO
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import os

public enum SetImageError: Error {
    case discarded
}

public final class ImageProcessor {
    private var log = Logger(subsystem: "dev.jano", category: "ImageProcessor")
    public var imageDownloader: any ImageDownloading

    public init(imageDownloader: any ImageDownloading = ImageDownloader.shared) {
        self.imageDownloader = imageDownloader
    }

    public func prepareImage(from url: URL, options: [SetImageOptions]) async throws -> (PlatformImage, @MainActor () -> Void) {
        guard let payload = try await imageDownloader.image(from: url) else {
            throw FetchError.badImage
        }

        var onSuccess: @MainActor () -> Void = {}
        var contentMode: SetImageOptions.ContentMode = .scaleAspectFit
        var pendingResize: CGSize?

        for option in options {
            switch option {
            case .discardUnless(let condition):
                if !condition() {
                    throw SetImageError.discarded
                }
            case .resize(let newSize):
                pendingResize = newSize
            case .onSuccess(let action):
                let previous = onSuccess
                onSuccess = {
                    previous()
                    action()
                }
            case .contentMode(let mode):
                contentMode = mode
            }
        }
        var image = payload.image
        if let newSize = pendingResize {
            if let data = payload.data, let resized = await resizeUsingImageSource(data: data, originalImage: image, newSize: newSize, mode: contentMode) {
                image = resized
            } else {
                image = await resize(image: image, newSize: newSize, mode: contentMode)
            }
        }
        return (image, onSuccess)
    }

    private func resize(image: PlatformImage, newSize: CGSize, mode: SetImageOptions.ContentMode) async -> PlatformImage {
        guard image.size != newSize else { return image }

        // Try system thumbnail first (preserves aspect)
        if case .scaleToFill = mode {
            // let it stretch; fall through to manual draw below
        } else if let resized = await image.byPreparingThumbnail(ofSize: newSize) {
            return resized
        }

        // Manual CoreGraphics-based resizing off main thread.
        #if canImport(UIKit)
        let sourceCG = image.cgImage ?? image.pngData().flatMap { UIImage(data: $0)?.cgImage }
        #else
        let sourceCG = (image as NSImage).ic_cgImage
        #endif

        guard let cg = sourceCG else { return image }

        let canvas = CGRect(origin: .zero, size: newSize)
        let srcSize = CGSize(width: cg.width, height: cg.height)
        let drawRect: CGRect
        switch mode {
        case .scaleToFill:
            drawRect = canvas
        case .scaleAspectFit:
            let scale = min(newSize.width / srcSize.width, newSize.height / srcSize.height)
            let size = CGSize(width: srcSize.width * scale, height: srcSize.height * scale)
            let origin = CGPoint(x: (newSize.width - size.width) / 2, y: (newSize.height - size.height) / 2)
            drawRect = CGRect(origin: origin, size: size)
        case .scaleAspectFill:
            let scale = max(newSize.width / srcSize.width, newSize.height / srcSize.height)
            let size = CGSize(width: srcSize.width * scale, height: srcSize.height * scale)
            let origin = CGPoint(x: (newSize.width - size.width) / 2, y: (newSize.height - size.height) / 2)
            drawRect = CGRect(origin: origin, size: size)
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: Int(newSize.width),
            height: Int(newSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return image
        }
        ctx.interpolationQuality = .high
        // Transparent background (letterbox area for aspectFit)
        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0))
        ctx.fill(canvas)
        ctx.draw(cg, in: drawRect)
        guard let scaled = ctx.makeImage() else { return image }

        #if canImport(UIKit)
        return UIImage(cgImage: scaled, scale: image.scale, orientation: image.imageOrientation)
        #else
        return NSImage(cgImage: scaled, size: newSize)
        #endif
    }

    // MARK: - Fast thumbnail with CGImageSource
    private func resizeUsingImageSource(data: Data, originalImage: PlatformImage, newSize: CGSize, mode: SetImageOptions.ContentMode) async -> PlatformImage? {
        // Generate a downscaled CGImage quickly from bytes
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        // Choose a conservative max pixel size; we’ll composite into exact canvas afterwards.
        let maxDim = max(Int(newSize.width), Int(newSize.height))
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDim,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary) else { return nil }

        // Composite into target canvas honoring contentMode
        let canvas = CGRect(origin: .zero, size: newSize)
        let srcSize = CGSize(width: cg.width, height: cg.height)
        let drawRect: CGRect
        switch mode {
        case .scaleToFill:
            drawRect = canvas
        case .scaleAspectFit:
            let scale = min(newSize.width / srcSize.width, newSize.height / srcSize.height)
            let size = CGSize(width: srcSize.width * scale, height: srcSize.height * scale)
            let origin = CGPoint(x: (newSize.width - size.width) / 2, y: (newSize.height - size.height) / 2)
            drawRect = CGRect(origin: origin, size: size)
        case .scaleAspectFill:
            let scale = max(newSize.width / srcSize.width, newSize.height / srcSize.height)
            let size = CGSize(width: srcSize.width * scale, height: srcSize.height * scale)
            let origin = CGPoint(x: (newSize.width - size.width) / 2, y: (newSize.height - size.height) / 2)
            drawRect = CGRect(origin: origin, size: size)
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: Int(newSize.width),
            height: Int(newSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        ctx.interpolationQuality = .high
        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0))
        ctx.fill(canvas)
        ctx.draw(cg, in: drawRect)
        guard let result = ctx.makeImage() else { return nil }

        #if canImport(UIKit)
        return UIImage(cgImage: result, scale: originalImage.scale, orientation: originalImage.imageOrientation)
        #else
        return NSImage(cgImage: result, size: newSize)
        #endif
    }
}
