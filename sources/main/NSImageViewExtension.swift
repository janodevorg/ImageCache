#if canImport(AppKit)
import AppKit
import os

/// Remote image caching functionality.
@MainActor public final class NSImageViewExtension
{
    private var log = Logger(subsystem: "dev.jano", category: "kit")
    private let imageProcessor: ImageProcessor
    private let base: NSImageView

    public init(_ base: NSImageView) {
        self.base = base
        self.imageProcessor = ImageProcessor()
    }

    /**
     Sets an image available at the given URL.
     - Parameter url: URL where the image is available
     - Parameter options: Operations, conditions, or callback to apply to this setImage operation.
     */
    public func setImage(url: URL, options: [SetImageOptions]) {
        Task {
            do {
                let (image, onSuccess) = try await imageProcessor.prepareImage(from: url, options: options)
                
                let decodedImage = await image.byPreparingForDisplay()
                await MainActor.run {
                    self.base.image = decodedImage
                    onSuccess()
                }
            } catch {
                log.error("Failed to set image: \(error.localizedDescription)")
            }
        }
    }
}

/// Extends an NSImageView with a namespace that provides memory cache functionality.
public extension NSImageView {
    /// Namespace for cache functionality.
    var ext: NSImageViewExtension {
        NSImageViewExtension(self)
    }
}
#endif
