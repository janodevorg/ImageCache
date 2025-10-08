import Testing
@testable import ImageCache
import Foundation

@Suite("ImageProcessor Tests")
final class ImageProcessorTests {

    private let mockImageDownloader = MockImageDownloader()
    private let url = URL(string: "https://example.com/image.png")!

    private func createImageProcessor() -> ImageProcessor {
        ImageProcessor(imageDownloader: mockImageDownloader)
    }

    @Test("Prepare image successfully")
    func testPrepareImageSuccess() async throws {
        let image = PlatformImage()
        await mockImageDownloader.setImage(ImagePayload(image: image, data: Data()))
        let imageProcessor = createImageProcessor()

        let (preparedImage, _) = try await imageProcessor.prepareImage(from: url, options: [])
        #expect(preparedImage == image)
    }

    @Test("Prepare image with resize option")
    func testPrepareImageWithResize() async throws {
        let image = PlatformImage()
        await mockImageDownloader.setImage(ImagePayload(image: image, data: Data()))
        let imageProcessor = createImageProcessor()
        let newSize = CGSize(width: 50, height: 50)

        let (preparedImage, _) = try await imageProcessor.prepareImage(from: url, options: [.resize(newSize: newSize)])
        #expect(preparedImage.size == newSize)
    }

    @Test("Prepare image with discard condition")
    func testPrepareImageDiscarded() async {
        let image = PlatformImage()
        await mockImageDownloader.setImage(ImagePayload(image: image, data: Data()))
        let imageProcessor = createImageProcessor()

        await #expect(throws: SetImageError.self) {
            _ = try await imageProcessor.prepareImage(from: self.url, options: [.discardUnless(condition: { false })])
        }
    }
    
    @Test("Prepare image with success action")
    func testPrepareImageOnSuccess() async throws {
        let image = PlatformImage()
        await mockImageDownloader.setImage(ImagePayload(image: image, data: Data()))
        let imageProcessor = createImageProcessor()
        
        @MainActor final class MainFlag { var value = false }
        let flag = MainFlag()
        let (_, onSuccess) = try await imageProcessor.prepareImage(from: url, options: [.onSuccess(action: {
            flag.value = true
        })])
        
        await MainActor.run {
            onSuccess()
            #expect(flag.value)
        }
    }
}

// MARK: - Mock ImageDownloader

actor MockImageDownloader: ImageDownloading {
    private var mockPayload: ImagePayload?
    private var mockError: Error?

    func setImage(_ payload: ImagePayload?) {
        mockPayload = payload
        mockError = nil
    }
    
    func setError(_ error: Error?) {
        mockError = error
        mockPayload = nil
    }

    func image(from url: URL) async throws -> ImagePayload? {
        if let error = mockError {
            throw error
        }
        return mockPayload
    }
    
    func image(from urlString: String) async throws -> ImagePayload? {
        if let error = mockError {
            throw error
        }
        return mockPayload
    }
}
