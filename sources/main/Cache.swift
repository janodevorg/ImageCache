#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// An API to store transient images based upon URL values.
///
/// This uses `NSCache` underneath.
public final class Cache
{
    /// Value to store in the cache.
    public enum Entry {

        /// Download in progress.
        case inProgress(Task<PlatformImage, Error>)

        /// Image stored in the cache.
        case ready(PlatformImage)
    }

    // NSObject wrapper for an entry so it can be used with NSCache.
    private final class CacheEntry: NSObject {
        let entry: Entry
        init(entry: Entry) {
            self.entry = entry
        }
    }

    private var cache = NSCache<NSURL, CacheEntry>()

    public init() {}
    
    /// - Returns: value previously stored under the given `url`
    public func read(url: URL) -> Entry? {
        cache.object(forKey: url as NSURL)?.entry
    }

    /**
     Store an entry using a URL as key.
     - Parameters:
       - Parameter entry: instance to store
       - Parameter url: the key to later obtain the instance stored
     */
    public func add(entry: Entry, url: URL) {
        cache.setObject(CacheEntry(entry: entry), forKey: url as NSURL)
    }

    /**
     Remove the entry previously stored under the given `url`.
     - Parameter url: the key of the instance to remove
     */
    public func remove(url: URL) {
        cache.removeObject(forKey: url as NSURL)
    }

    /**
     Obtain the entry previously stored under the given `url`.
     - Parameter url: the key of the instance to obtain
     */
    public func peek(url: URL) -> PlatformImage? {
        if case let .ready(image) = cache.object(forKey: url as NSURL)?.entry {
            return image
        } else {
            return nil
        }
    }
}
