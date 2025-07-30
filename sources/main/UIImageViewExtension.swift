import Foundation
import os

#if canImport(UIKit)
import UIKit

public enum SetImageOptions {

    /// Discards unless the given condition returns true.
    case discardUnless(condition: () -> Bool)

    /// Resize the image.
    case resize(newSize: CGSize)

    /// Closure to execute when the image is set.
    case onSuccess(action: @MainActor () -> Void)
}

/// Remote image caching functionality.
@MainActor public final class UIImageViewExtension
{
    private var log = Logger(subsystem: "dev.jano", category: "kit")

    public var imageDownloader = ImageDownloader()

    private let base: UIImageView

    public init(_ base: UIImageView) {
        self.base = base
    }

    /**
     Sets an image available at the given URL.
     - Parameter url: URL where the image is available
     - Parameter options: Operations, conditions, or callback to apply to this setImage operation.
     */
    public func setImage(url: URL, options: [SetImageOptions]) {
        Task {
            do {
                guard var image = try await imageDownloader.image(from: url) else {
                    return
                }

                var onSuccess: @MainActor () -> Void = {}

                await Task.detached {
                    for option in options {
                        switch option {
                        case .discardUnless(let condition):
                            if !condition() {
                                return
                            }
                        case .resize(let newSize):
                            image = await self.resize(image: image, newSize: newSize)
                        case .onSuccess(let action):
                            onSuccess = action
                        }
                    }

                    let decodedImage = await image.byPreparingForDisplay()
                    await MainActor.run {
                        self.base.image = decodedImage
                        onSuccess()
                    }
                }.value
            } catch {
                log.error("Failed to set image: \(error.localizedDescription)")
            }
        }
    }

    // - Returns: image resized to a newSize.
    private func resize(image: PlatformImage, newSize: CGSize) async -> PlatformImage {
        guard image.size != newSize else {
            return image
        }
        if let resizedImage = await image.byPreparingThumbnail(ofSize: newSize) {
            return resizedImage
        }
        // Case where the UIImage wasn’t a CGImage.
        return UIGraphicsImageRenderer(size: newSize).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

/// Extends an UIImageView with a namespace that provides memory cache functionality.
public extension UIImageView {
    /// Namespace for cache functionality.
    var ext: UIImageViewExtension {
        UIImageViewExtension(self)
    }
}

#endif
