import os
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Protocol for image downloading functionality
public protocol ImageDownloading: Actor, Sendable {
    func image(from urlString: String) async throws -> ImagePayload?
    func image(from url: URL) async throws -> ImagePayload?
}

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
public actor ImageDownloader: ImageDownloading
{
    public static let shared = ImageDownloader()

    // Transient store for images.
    private let cache = Cache()
    private let urlSession: URLSession
    private var inProgressCosts: [URL: Int] = [:]
    private let maxInMemoryDataSize: Int

    public init(urlSession: URLSession = .shared, maxInMemoryDataSize: Int = 8 * 1024 * 1024) {
        self.urlSession = urlSession
        self.maxInMemoryDataSize = maxInMemoryDataSize
    }

    /**
     Download an image available at the given URL.

     If the image is cached it is returned immediately from memory.

      - Parameter urlString: URL to download the image
      - Returns: Image or nil if downloading failed.
      - Throws FetchError
    */
    public func image(from urlString: String) async throws -> ImagePayload? {
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
    public func image(from url: URL) async throws -> ImagePayload? {
        // Reject non http(s) schemes for network-only images
        if let scheme = url.scheme?.lowercased(), !(scheme == "http" || scheme == "https") {
            throw FetchError.badURL
        }

        if let cached = cache.read(url: url) {
            // the cache contains images either downloaded or in progress
            switch cached {
                case .ready(let payload):
                    return payload // return immediately
                case .inProgress(let handle):
                    return try await handle.value // await the download and return the image
            }
        }

        // create and store an image in progress
        let handle = Task { [urlSession] () throws -> ImagePayload in
            try Task.checkCancellation()
            let (payload, cost) = try await downloadImage(from: url, urlSession: urlSession)
            self.setCost(cost, for: url)
            return payload
        }
        cache.add(entry: .inProgress(handle), url: url)

        do {
            // await the download, store the image, return the image
            let payload = try await handle.value
            let cost = takeCost(for: url) ?? 1
            cache.add(entry: .ready(payload), url: url, cost: cost)
            return payload
        } catch {
            cache.remove(url: url) // remove the download in progress
            _ = takeCost(for: url)
            throw error
        }
    }

    /**
     Download an image from the given URL.
     
       - Parameter from: URL of the image
       - Returns: image
       - Throws: FetchError
     */
    private func downloadImage(from url: URL, urlSession: URLSession) async throws -> (ImagePayload, Int) {
        let request = URLRequest(url: url)
        let (data, response) = try await urlSession.data(for: request)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw FetchError.badResponse
        }

        if let mime = http.value(forHTTPHeaderField: "Content-Type"), !mime.lowercased().contains("image") {
            throw FetchError.badImage
        }

        guard let image = PlatformImage(data: data) else {
            throw FetchError.badImage
        }
        let includeData = data.count <= maxInMemoryDataSize
        let payload = ImagePayload(image: image, data: includeData ? data : nil)
        return (payload, data.count)
    }

    // MARK: - Cost tracking
    private func setCost(_ cost: Int, for url: URL) {
        inProgressCosts[url] = cost
    }
    private func takeCost(for url: URL) -> Int? {
        defer { inProgressCosts.removeValue(forKey: url) }
        return inProgressCosts[url]
    }
}
