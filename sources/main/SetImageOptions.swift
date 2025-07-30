import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public enum SetImageOptions {

    /// Discards unless the given condition returns true.
    case discardUnless(condition: () -> Bool)

    /// Resize the image.
    case resize(newSize: CGSize)

    /// Closure to execute when the image is set.
    case onSuccess(action: @MainActor () -> Void)
}
