import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct ImagePayload: Sendable {
    public let image: PlatformImage
    public let data: Data?

    public init(image: PlatformImage, data: Data?) {
        self.image = image
        self.data = data
    }
}
