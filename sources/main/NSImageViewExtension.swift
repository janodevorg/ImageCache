#if canImport(AppKit)
import AppKit
import ObjectiveC
import os

/// Remote image caching functionality.
@MainActor public final class NSImageViewExtension
{
    private var log = Logger(subsystem: "dev.jano", category: "ImageViewExtension")
    private let base: NSImageView

    public init(_ base: NSImageView) {
        self.base = base
    }

    /**
     Sets an image available at the given URL.
     - Parameter url: URL where the image is available
     - Parameter options: Operations, conditions, or callback to apply to this setImage operation.
     */
    public func setImage(url: URL, options: [SetImageOptions]) {
        base.imageCache_currentTask?.cancel()
        base.imageCache_currentURL = url
        base.imageCache_currentTask = Task { [weak self] in
            guard let self else { return }
            do {
                let processor = ImageProcessor()
                let (image, onSuccess) = try await processor.prepareImage(from: url, options: options)
                guard !Task.isCancelled, self.base.imageCache_currentURL == url else { return }
                let decodedImage = await image.byPreparingForDisplay()
                await MainActor.run {
                    guard self.base.imageCache_currentURL == url else { return }
                    self.base.image = decodedImage
                    onSuccess()
                }
            } catch is CancellationError {
                // ignore
            } catch let err as SetImageError {
                self.log.debug("Image set discarded: \(String(describing: err))")
            } catch let err as FetchError {
                self.log.error("Failed to fetch image: \(String(describing: err))")
            } catch {
                self.log.error("Failed to set image: \(error.localizedDescription)")
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

// MARK: - Associated storage for task + URL
@MainActor private var currentTaskKey: UInt8 = 0
@MainActor private var currentURLKey: UInt8 = 0

private extension NSImageView {
    var imageCache_currentTask: Task<Void, Never>? {
        get { objc_getAssociatedObject(self, &currentTaskKey) as? Task<Void, Never> }
        set { objc_setAssociatedObject(self, &currentTaskKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    var imageCache_currentURL: URL? {
        get { objc_getAssociatedObject(self, &currentURLKey) as? URL }
        set { objc_setAssociatedObject(self, &currentURLKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}
#endif
