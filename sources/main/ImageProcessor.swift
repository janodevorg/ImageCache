import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import os

public enum SetImageError: Error {
    case discarded
}

@MainActor 
public final class ImageProcessor {
    private var log = Logger(subsystem: "dev.jano", category: "kit")
    public var imageDownloader: any ImageDownloading

    public init(imageDownloader: any ImageDownloading = ImageDownloader.shared) {
        self.imageDownloader = imageDownloader
    }

    public func prepareImage(from url: URL, options: [SetImageOptions]) async throws -> (PlatformImage, @MainActor () -> Void) {
        guard var image = try await imageDownloader.image(from: url) else {
            throw FetchError.badImage
        }

        var onSuccess: @MainActor () -> Void = {}

        for option in options {
            switch option {
            case .discardUnless(let condition):
                if !condition() {
                    throw SetImageError.discarded
                }
            case .resize(let newSize):
                image = await resize(image: image, newSize: newSize)
            case .onSuccess(let action):
                onSuccess = action
            }
        }
        return (image, onSuccess)
    }

    private func resize(image: PlatformImage, newSize: CGSize) async -> PlatformImage {
        guard image.size != newSize else {
            return image
        }
        if let resizedImage = await image.byPreparingThumbnail(ofSize: newSize) {
            return resizedImage
        }
        
        // Fallback for when byPreparingThumbnail fails
        #if canImport(UIKit)
        return UIGraphicsImageRenderer(size: newSize).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        #elseif canImport(AppKit)
        let resizedImage = NSImage(size: newSize)
        resizedImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize), from: .zero, operation: .copy, fraction: 1.0)
        resizedImage.unlockFocus()
        return resizedImage
        #else
        return image // Return original image if no drawing context is available
        #endif
    }
}
