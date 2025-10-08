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

## SwiftUI Adapter (Optional)

For SwiftUI clients, this package includes an optional adapter you can use if desired:

- `ImageLoader` (@Observable): loads and exposes `state` (idle/loading/success/failure)
- `RemoteImage` view: simple view that loads and displays a remote image

Example

```swift
import SwiftUI
import ImageCache

struct Avatar: View {
    let url = URL(string: "https://example.com/avatar.jpg")!

    var body: some View {
        RemoteImage(
            url: url,
            resize: CGSize(width: 120, height: 120),
            contentMode: .scaleAspectFill
        )
        .resizable()
        .frame(width: 120, height: 120)
        .clipped()
    }
}
```

Notes
- Resizing/contentMode are optional; omit `resize` to display the original size.
- Internally uses the same downloader + processor and macOS CGImageSource fast path.
