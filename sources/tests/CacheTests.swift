import Testing
@testable import ImageCache
import Foundation

@Suite("Cache Tests")
final class CacheTests {

    private var cache: Cache!
    private let url = URL(string: "https://example.com/image.png")!

    init() {
        // This will be called before each test.
        cache = Cache()
    }

    @Test("Add and Read Entry")
    func testAddAndReadEntry() {
        let image = PlatformImage()
        let payload = ImagePayload(image: image, data: nil)
        let entry = Cache.Entry.ready(payload)
        cache.add(entry: entry, url: url)
        
        let cachedEntry = cache.read(url: url)
        #expect(cachedEntry != nil)
        
        guard case let .ready(cachedPayload) = cachedEntry else {
            Issue.record("Expected .ready entry, but got \(String(describing: cachedEntry))")
            return
        }
        #expect(cachedPayload.image == image)
    }

    @Test("Remove Entry")
    func testRemoveEntry() {
        let image = PlatformImage()
        let entry = Cache.Entry.ready(ImagePayload(image: image, data: nil))
        cache.add(entry: entry, url: url)
        
        cache.remove(url: url)
        
        let cachedEntry = cache.read(url: url)
        #expect(cachedEntry == nil)
    }

    @Test("Peek Image")
    func testPeekImage() {
        let image = PlatformImage()
        let entry = Cache.Entry.ready(ImagePayload(image: image, data: nil))
        cache.add(entry: entry, url: url)
        
        let peekedImage = cache.peek(url: url)
        #expect(peekedImage != nil)
        #expect(peekedImage == image)
    }

    @Test("Peek Image In Progress")
    func testPeekImageInProgress() {
        let task = Task<ImagePayload, Error> {
            // Simulate a network delay
            try await Task.sleep(nanoseconds: 100_000_000)
            return ImagePayload(image: PlatformImage(), data: nil)
        }
        let entry = Cache.Entry.inProgress(task)
        cache.add(entry: entry, url: url)
        
        let peekedImage = cache.peek(url: url)
        #expect(peekedImage == nil)
    }

    @Test("Read In Progress Entry")
    func testReadInProgressEntry() {
        let task = Task<ImagePayload, Error> {
            return ImagePayload(image: PlatformImage(), data: nil)
        }
        let entry = Cache.Entry.inProgress(task)
        cache.add(entry: entry, url: url)
        
        let cachedEntry = cache.read(url: url)
        #expect(cachedEntry != nil)
        
        guard case .inProgress = cachedEntry else {
            Issue.record("Expected .inProgress entry, but got \(String(describing: cachedEntry))")
            return
        }
    }
}
