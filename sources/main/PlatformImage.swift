#if canImport(UIKit)
import UIKit
public typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
public typealias PlatformImage = NSImage
#endif

// Cross-platform extensions for image handling
public extension PlatformImage {
    
    #if canImport(AppKit)
    // NSImage already has init(data:) and size property, no need to add them
    
    /// Pre-decode image to a bitmap-backed representation to avoid first-render hitching.
    func byPreparingForDisplay() async -> PlatformImage? {
        guard let cgImage = self.ic_cgImage else {
            // Attempt to create a CGImage via best representation
            let rect = NSRect(origin: .zero, size: self.size)
            guard let rep = self.bestRepresentation(for: rect, context: nil, hints: nil) else {
                return self
            }
            let img = NSImage(size: self.size)
            img.lockFocus()
            rep.draw(in: rect)
            img.unlockFocus()
            return img
        }
        // Draw into a new bitmap context to force decode
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return self
        }
        ctx.interpolationQuality = .high
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        guard let decoded = ctx.makeImage() else { return self }
        return NSImage(cgImage: decoded, size: self.size)
    }
    
    /// Prepare thumbnail preserving aspect ratio (aspect-fit within the target size).
    func byPreparingThumbnail(ofSize targetSize: CGSize) async -> PlatformImage? {
        guard let sourceCG = self.ic_cgImage else {
            // Fallback to focus-based drawing preserving aspect fit
            let image = NSImage(size: targetSize)
            image.lockFocus()
            let drawRect = Self.aspectFitRect(imageSize: self.size, boundingSize: targetSize)
            self.draw(in: drawRect)
            image.unlockFocus()
            return image
        }

        let drawRect = Self.aspectFitRect(imageSize: CGSize(width: sourceCG.width, height: sourceCG.height),
                                          boundingSize: targetSize)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: Int(targetSize.width),
            height: Int(targetSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        ctx.interpolationQuality = .high
        // Fill transparent background
        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0))
        ctx.fill(CGRect(origin: .zero, size: targetSize))
        ctx.draw(sourceCG, in: drawRect)
        guard let thumb = ctx.makeImage() else { return nil }
        return NSImage(cgImage: thumb, size: targetSize)
    }

    var ic_cgImage: CGImage? {
        // Try to obtain a CGImage from NSImage
        var proposedRect = NSRect(origin: .zero, size: self.size)
        return self.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil)
    }
    
    private static func aspectFitRect(imageSize: CGSize, boundingSize: CGSize) -> CGRect {
        let scale = min(boundingSize.width / imageSize.width, boundingSize.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let x = (boundingSize.width - size.width) / 2
        let y = (boundingSize.height - size.height) / 2
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }
    #endif
    
    // UIKit already has these methods, no need to add them
}
