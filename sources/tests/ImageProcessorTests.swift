import Testing
@testable import ImageCache
import Foundation

@Suite("ImageProcessor Tests")
@MainActor
final class ImageProcessorTests {

    private let mockImageDownloader = MockImageDownloader()
    private let url = URL(string: "https://example.com/image.png")!

    private func createImageProcessor() -> ImageProcessor {
        ImageProcessor(imageDownloader: mockImageDownloader)
    }

    @Test("Prepare image successfully")
    func testPrepareImageSuccess() async throws {
        let image = PlatformImage()
        await mockImageDownloader.setImage(image)
        let imageProcessor = createImageProcessor()

        let (preparedImage, _) = try await imageProcessor.prepareImage(from: url, options: [])
        #expect(preparedImage == image)
    }

    @Test("Prepare image with resize option")
    func testPrepareImageWithResize() async throws {
        let image = PlatformImage()
        await mockImageDownloader.setImage(image)
        let imageProcessor = createImageProcessor()
        let newSize = CGSize(width: 50, height: 50)

        let (preparedImage, _) = try await imageProcessor.prepareImage(from: url, options: [.resize(newSize: newSize)])
        #expect(preparedImage.size == newSize)
    }

    @Test("Prepare image with discard condition")
    func testPrepareImageDiscarded() async {
        let image = PlatformImage()
        await mockImageDownloader.setImage(image)
        let imageProcessor = createImageProcessor()

        await #expect(throws: SetImageError.self) {
            _ = try await imageProcessor.prepareImage(from: self.url, options: [.discardUnless(condition: { false })])
        }
    }
    
    @Test("Prepare image with success action")
    func testPrepareImageOnSuccess() async throws {
        let image = PlatformImage()
        await mockImageDownloader.setImage(image)
        let imageProcessor = createImageProcessor()
        
        var wasOnSuccessCalled = false
        let (_, onSuccess) = try await imageProcessor.prepareImage(from: url, options: [.onSuccess(action: {
            wasOnSuccessCalled = true
        })])
        
        await MainActor.run {
            onSuccess()
        }
        
        #expect(wasOnSuccessCalled)
    }
}

// MARK: - Mock ImageDownloader

actor MockImageDownloader: ImageDownloading {
    private var mockImage: PlatformImage?
    private var mockError: Error?

    func setImage(_ image: PlatformImage?) {
        mockImage = image
        mockError = nil
    }
    
    func setError(_ error: Error?) {
        mockError = error
        mockImage = nil
    }

    func image(from url: URL) async throws -> PlatformImage? {
        if let error = mockError {
            throw error
        }
        return mockImage
    }
    
    func image(from urlString: String) async throws -> PlatformImage? {
        if let error = mockError {
            throw error
        }
        return mockImage
    }
}
