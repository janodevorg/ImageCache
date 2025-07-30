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
    
    /// Prepare image for display (AppKit equivalent of UIKit's byPreparingForDisplay)
    func byPreparingForDisplay() async -> PlatformImage? {
        return self
    }
    
    /// Prepare thumbnail (AppKit equivalent of UIKit's byPreparingThumbnail)
    func byPreparingThumbnail(ofSize size: CGSize) async -> PlatformImage? {
        let thumbnail = NSImage(size: size)
        thumbnail.lockFocus()
        let rect = NSRect(origin: .zero, size: size) 
        draw(in: rect)
        thumbnail.unlockFocus()
        return thumbnail
    }
    #endif
    
    // UIKit already has these methods, no need to add them
}