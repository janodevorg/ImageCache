import os
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Errors thrown by the `ImageDownloader`.
public enum FetchError: Error {
    case badResponse
    case badImage
    case badURL
}

/**
 Image cache.

 This is an actor so only one request is alive at a time, even when
 there can be many ongoing but suspended at the suspension points (await).
*/
public actor ImageDownloader
{
    private let log = Logger(subsystem: "dev.jano", category: "ImageDownloader")
    public static let shared = ImageDownloader()

    // Transient store for images.
    private let cache = Cache()

    /**
     Download an image available at the given URL.

     If the image is cached it is returned immediately from memory.

      - Parameter urlString: URL to download the image
      - Returns: Image or nil if downloading failed.
      - Throws FetchError
    */
    public func image(from urlString: String) async throws -> PlatformImage? {
        guard let url = URL(string: urlString) else {
            throw FetchError.badURL
        }
        return try await image(from: url)
    }

    /**
     Download an image available at the given URL.

     If the image is cached it is returned immediately from memory.

      - Parameter url: URL to download the image
      - Returns: Image or nil if downloading failed.
      - Throws: FetchError
    */
    public func image(from url: URL) async throws -> PlatformImage? {

        if let cached = cache.read(url: url) {
            // the cache contains images either downloaded or in progress
            switch cached {
                case .ready(let image):
                    return image // return image immediately
                case .inProgress(let handle):
                    return try await handle.value // await the download and return the image
            }
        }

        // create and store an image in progress
        let handle = Task {
            try await downloadImage(from: url)
        }
        cache.add(entry: .inProgress(handle), url: url)

        do {
            // await the download, store the image, return the image
            let image = try await handle.value
            cache.add(entry: .ready(image), url: url)
            return image
        } catch {
            cache.remove(url: url) // remove the download in progress
            throw error
        }
    }

    /**
     Download an image from the given URL.
     
       - Parameter from: URL of the image
       - Returns: image
       - Throws: FetchError
     */
    private func downloadImage(from url: URL) async throws -> PlatformImage {
        let request = URLRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw FetchError.badResponse
        }
        guard let image = PlatformImage(data: data) else {
            throw FetchError.badImage
        }
        return image
    }
}
