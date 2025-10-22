import Foundation
import SwiftUI
import Observation

@Observable
public final class ImageLoader {
    public enum State {
        case idle
        case loading
        case success(PlatformImage)
        case failure(String)
    }

    public private(set) var state: State = .idle
    private var task: Task<Void, Never>?
    private var currentURL: URL?

    public init() {}

    @MainActor
    public func load(url: URL, resize: CGSize? = nil, contentMode: SetImageOptions.ContentMode = .scaleAspectFit) {
        cancel()
        currentURL = url
        state = .loading

        task = Task { [currentURL] in
            do {
                let processor = ImageProcessor()
                let opts: [SetImageOptions]
                if let size = resize {
                    opts = [.contentMode(contentMode), .resize(newSize: size)]
                } else {
                    opts = []
                }
                let (image, _) = try await processor.prepareImage(from: url, options: opts)
                guard !Task.isCancelled, currentURL == url else { return }
                await MainActor.run { self.state = .success(image) }
            } catch is CancellationError {
                // ignore
            } catch let err as FetchError {
                await MainActor.run { self.state = .failure("Fetch error: \(err)") }
            } catch let err as SetImageError {
                await MainActor.run { self.state = .failure("Discarded: \(err)") }
            } catch {
                await MainActor.run { self.state = .failure(error.localizedDescription) }
            }
        }
    }

    @MainActor
    public func load(urlString: String, resize: CGSize? = nil, contentMode: SetImageOptions.ContentMode = .scaleAspectFit) {
        guard let url = URL(string: urlString) else {
            state = .failure("Bad URL")
            return
        }
        load(url: url, resize: resize, contentMode: contentMode)
    }

    @MainActor
    public func cancel() {
        task?.cancel()
        task = nil
    }
}

public struct RemoteImage: View {
    private let url: URL
    private let resize: CGSize?
    private let contentMode: SetImageOptions.ContentMode

    @State private var loader = ImageLoader()

    public init(url: URL, resize: CGSize? = nil, contentMode: SetImageOptions.ContentMode = .scaleAspectFit) {
        self.url = url
        self.resize = resize
        self.contentMode = contentMode
    }

    public var body: some View {
        Group {
            switch loader.state {
            case .idle, .loading:
                ProgressView()
            case .failure:
                Image(systemName: "photo")
            case .success(let img):
                #if canImport(UIKit)
                Image(uiImage: img)
                #else
                Image(nsImage: img)
                #endif
            }
        }
        .task(id: url) {
            loader.load(url: url, resize: resize, contentMode: contentMode)
        }
        .onDisappear {
            Task { @MainActor in loader.cancel() }
        }
    }
}

