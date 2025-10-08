[![Swift](https://github.com/janodevorg/ImageCache/actions/workflows/swift.yml/badge.svg)](https://github.com/janodevorg/ImageCache/actions/workflows/swift.yml)

[Remote downloading and cache of images.](https://janodevorg.github.io/ImageCache/documentation/imagecache/)

This code is similar to the image cache presented by Apple in 
[Protect mutable state with Swift actors](https://developer.apple.com/videos/play/wwdc2021/10133/).

## Platforms

- iOS 18
- macOS 15

## macOS Thumbnail Performance

On macOS, `NSImage` resizing by drawing into a scaled context decodes the full image first and is slow for large assets. This package uses `CGImageSourceCreateThumbnailAtIndex` to downscale from the original bytes at decode time (subsampling), then composites according to `.contentMode` (aspect fit/fill, or fill). iOS continues to use `UIImage.preparingThumbnail(of:)` when appropriate.

For a concise deep‑dive on why and how we do this, see `AGENTS.md`.
