import os
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
        case inProgress(Task<ImagePayload, Error>)

        /// Image stored in the cache.
        case ready(ImagePayload)
    }

    // NSObject wrapper for an entry so it can be used with NSCache.
    final class CacheEntry: NSObject {
        let entry: Entry
        init(entry: Entry) {
            self.entry = entry
        }
    }

    private let log = Logger(subsystem: "dev.jano", category: "Cache")
    private var cache = NSCache<NSURL, CacheEntry>()
    private let delegate = Delegate()

    public init(countLimit: Int = 200, totalCostLimit: Int = 64 * 1024 * 1024) {
        cache.countLimit = countLimit
        cache.totalCostLimit = totalCostLimit
        delegate.onEvict = { [weak self] evicted in
            self?.log.debug("Evicting cached image entry: \(String(describing: evicted))")
        }
        cache.delegate = delegate
    }
    
    /// - Returns: value previously stored under the given `url`
    public func read(url: URL) -> Entry? {
        cache.object(forKey: url as NSURL)?.entry
    }

    /**
     Store an entry using a URL as key.
     - Parameters:
       - entry: instance to store
       - url: the key to later obtain the instance stored
       - cost: cache eviction cost (in bytes when known)
     */
    public func add(entry: Entry, url: URL, cost: Int = 1) {
        cache.setObject(CacheEntry(entry: entry), forKey: url as NSURL, cost: cost)
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
        if case let .ready(payload) = cache.object(forKey: url as NSURL)?.entry {
            return payload.image
        } else {
            return nil
        }
    }
}

// MARK: - NSCache delegate

private final class Delegate: NSObject, NSCacheDelegate {
    var onEvict: ((AnyObject) -> Void)?
    func cache(_ cache: NSCache<AnyObject, AnyObject>, willEvictObject obj: Any) {
        if let object = obj as AnyObject? {
            onEvict?(object)
        }
    }
}
