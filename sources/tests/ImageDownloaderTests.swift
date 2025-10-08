import Testing
@testable import ImageCache
import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@Suite("ImageDownloader Tests")
final class ImageDownloaderTests {

    private var imageDownloader: ImageDownloader!
    private let url = URL(string: "https://example.com/image.png")!

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let urlSession = URLSession(configuration: configuration)
        imageDownloader = ImageDownloader(urlSession: urlSession)
    }
    
    private func createTestImageData() -> Data {
        #if canImport(UIKit)
        let size = CGSize(width: 1, height: 1)
        let image = UIGraphicsImageRenderer(size: size).image { _ in
            UIColor.red.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
        }
        return image.pngData() ?? Data()
        #elseif canImport(AppKit)
        let size = NSSize(width: 1, height: 1)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            return Data()
        }
        return pngData
        #else
        return Data()
        #endif
    }

    @Test("Successfully download an image")
    func testImageDownloadSuccess() async throws {
        let mockImageData = createTestImageData()

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: self.url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, mockImageData)
        }

        let payload = try await imageDownloader.image(from: url)
        #expect(payload != nil)
        #expect(payload?.image != nil)
        // For small images, data is kept
        #expect(payload?.data != nil)
    }

    @Test("Fail on bad HTTP response")
    func testImageDownloadBadResponse() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: self.url, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        await #expect(throws: FetchError.self) {
            _ = try await imageDownloader.image(from: self.url)
        }
    }

    @Test("Fail on bad image data")
    func testImageDownloadBadImage() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: self.url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data()) // Empty data
        }

        await #expect(throws: FetchError.self) {
            _ = try await imageDownloader.image(from: self.url)
        }
    }
    
    @Test("Fail on bad URL")
    func testImageDownloadBadURL() async {
        await #expect(throws: FetchError.self) {
            _ = try await imageDownloader.image(from: "invalid url")
        }
    }
}

// MARK: - Mocking URLProtocol

class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            fatalError("Handler is not set.")
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
