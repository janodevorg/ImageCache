ImageCache — Agents Guide

Scope
- Targets iOS 18 and macOS 15.
- Explains why macOS uses a different, faster thumbnail path and how to work within this design.

Why macOS uses a different approach
- iOS has fast, built-in downscaling: `UIImage.preparingThumbnail(of:)` performs decode-time scaling and is highly optimized.
- macOS lacks an equivalent on `NSImage`. Naive approaches (e.g., drawing `NSImage` into a resized context) first fully decode the image and then scale, which is significantly slower for large assets (JPEG/HEIC), often by an order of magnitude.
- Using `CGImageSourceCreateThumbnailAtIndex` on macOS lets us downscale from the original bytes at decode time (subsampling), avoiding a full-resolution decode and drastically improving latency. This technique is also beneficial on iOS for some formats and aligns the platforms’ performance characteristics.

How it’s implemented here
- Downloader returns an `ImagePayload` that carries both the `PlatformImage` and optionally the original `Data` bytes when the response is not too large. See:
  - `Sources/Main/ImagePayload.swift`
  - `Sources/Main/ImageDownloader.swift`
- Image processing prefers a fast, data-backed path when resizing:
  1) If `payload.data` is available and a resize is requested, create a `CGImageSource` from the bytes and call `CGImageSourceCreateThumbnailAtIndex` with:
     - `kCGImageSourceCreateThumbnailFromImageAlways: true`
     - `kCGImageSourceThumbnailMaxPixelSize: max(targetWidth, targetHeight)`
     - `kCGImageSourceCreateThumbnailWithTransform: true`
  2) Composite the generated CGImage into a canvas of the exact target size honoring `.contentMode(.scaleAspectFit | .scaleAspectFill | .scaleToFill)`.
  3) If bytes are not available, fall back to system thumbnailing (iOS) or CoreGraphics scaling.
  - Code: `Sources/Main/ImageProcessor.swift`
- Pre-decoding for first-render smoothness:
  - iOS relies on system APIs.
  - macOS forces a decoded bitmap by drawing into a `CGContext` and wrapping as `NSImage`.
  - Code: `Sources/Main/PlatformImage.swift`

Concurrency and UI safety
- View extensions track and cancel the current task per view and gate final image assignment by URL to avoid cell reuse races:
  - `Sources/Main/UIImageViewExtension.swift`
  - `Sources/Main/NSImageViewExtension.swift`
- Only perform the final `image` assignment on the main actor. Scaling/thumbnail generation uses CoreGraphics and can happen off-main.

Caching and memory
- `NSCache` has `countLimit` and `totalCostLimit`. We compute cost using `data.count` when available and log evictions.
- To avoid excessive memory, the downloader only stores original bytes up to a size threshold; larger images store just the decoded image.
- Code: `Sources/Main/Cache.swift`, `Sources/Main/ImageDownloader.swift`

Contributor guidance
- Do not revert macOS resizing to naive `NSImage` drawing; prefer `CGImageSource` when bytes are available.
- Keep heavy image work off-main; only UI assignment should touch the main actor.
- Preserve `.contentMode` semantics across platforms. When changing resize logic, ensure aspect-fit/fill behavior remains consistent.
- If adjusting memory thresholds or cache limits, pass accurate byte costs and consider test updates.
- When adding options, compose them like the existing pipeline (e.g., chain multiple `.onSuccess`).

Quick pointers
- Resize and fast thumbnail path: `Sources/Main/ImageProcessor.swift`
- macOS pre-decode + aspect-fit thumbnail: `Sources/Main/PlatformImage.swift`
- Downloader (2xx + MIME checks, payload, costs): `Sources/Main/ImageDownloader.swift`
- Options (`.resize`, `.contentMode`, `.onSuccess`): `Sources/Main/SetImageOptions.swift`

Related article:
- https://macguru.dev/fast-thumbnails-with-cgimagesource/
