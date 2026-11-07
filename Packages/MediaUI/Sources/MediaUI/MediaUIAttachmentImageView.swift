import DesignSystem
import Models
import Nuke
import NukeUI
import SwiftUI
import UIKit

public struct MediaUIAttachmentImageView: View {
  public let url: URL
  public let fallbackUrl: URL?
  public var onSingleTap: (() -> Void)? = nil

  @State private var currentURL: URL?
  @State private var hasTriedFallback = false
  @State private var hasFailed = false
  @GestureState private var zoom = 1.0
  @State private var showSafari = false

  public init(url: URL, fallbackUrl: URL? = nil, onSingleTap: (() -> Void)? = nil) {
    self.url = url
    self.fallbackUrl = fallbackUrl
    self.onSingleTap = onSingleTap
  }

  private var activeURL: URL {
    currentURL ?? url
  }

  private func extractGifData(from state: LazyImageState) -> Data? {
    if let container = state.imageContainer, container.type == .gif, let data = container.data {
      return data
    }
    let targetUrl = activeURL
    let isGifContainer = state.imageContainer?.type == .gif
    if isGifContainer || targetUrl.pathExtension.lowercased() == "gif" {
      if let cached = ImagePipeline.shared.cache.cachedData(for: .init(url: targetUrl)) {
        return cached
      }
      if let cached = ImagePipeline.shared.cache.cachedData(for: .init(url: url)) {
        return cached
      }
    }
    return nil
  }

  private func evaluateFailure(for state: LazyImageState) {
    guard !hasFailed, state.error != nil else { return }
    if !hasTriedFallback, let fallback = fallbackUrl, fallback != activeURL {
      DispatchQueue.main.async {
        self.currentURL = fallback
        self.hasTriedFallback = true
      }
      return
    }
    DispatchQueue.main.async {
      self.hasFailed = true
    }
  }

  private func hasError(for state: LazyImageState) -> Bool {
    state.error != nil
  }

  public var body: some View {
    MediaUIZoomableContainer(onSingleTap: onSingleTap) {
      LazyImage(url: activeURL) { state in
        contentView(for: state)
          .onAppear {
            evaluateFailure(for: state)
          }
          .onChange(of: state.isLoading) { _, _ in
            evaluateFailure(for: state)
          }
          .onChange(of: hasError(for: state)) { _, _ in
            evaluateFailure(for: state)
          }
      }
      .draggable(MediaUIImageTransferable(url: activeURL))
      .contextMenu {
        contextMenu
      }
    }
    .onChange(of: url) { _, newValue in
      currentURL = newValue
      hasFailed = false
      hasTriedFallback = false
    }
  }

  @ViewBuilder
  private func contentView(for state: LazyImageState) -> some View {
    if let gifData = extractGifData(from: state) {
      makeGifView(data: gifData, state: state)
    } else if let image = state.image {
      image
        .resizable()
        .scaledToFit()
    } else if hasFailed {
      failureView
    } else {
      ProgressView()
        .progressViewStyle(.circular)
    }
  }

  private func makeGifView(data: Data, state: LazyImageState) -> some View {
    GifView(data: data, forceAnimate: true)
      .aspectRatio(gifAspectRatio(from: state, data: data), contentMode: .fit)
  }

  private func validAspectRatio(width: CGFloat, height: CGFloat) -> CGFloat? {
    guard width > 0, height > 0 else { return nil }
    let aspect = width / height
    return (aspect > 0 && aspect.isFinite) ? aspect : nil
  }

  private func gifAspectRatio(from state: LazyImageState, data: Data) -> CGFloat? {
    if let size = state.imageContainer?.image.size,
       let aspect = validAspectRatio(width: size.width, height: size.height) {
      return aspect
    }
    if data.count >= 10 {
      let start = data.startIndex
      // GIF87a / GIF89a header starts with "GIF" (0x47, 0x49, 0x46) followed by 3 version bytes and 16-bit LE width/height
      if data[start] == 0x47, data[start + 1] == 0x49, data[start + 2] == 0x46 {
        let w = UInt16(data[start + 6]) | (UInt16(data[start + 7]) << 8)
        let h = UInt16(data[start + 8]) | (UInt16(data[start + 9]) << 8)
        if let aspect = validAspectRatio(width: CGFloat(w), height: CGFloat(h)) {
          return aspect
        }
      }
    }
    if let size = UIImage(data: data)?.size,
       let aspect = validAspectRatio(width: size.width, height: size.height) {
      return aspect
    }
    return nil
  }

  @ViewBuilder
  private var failureView: some View {
    VStack(spacing: 16) {
      Image(systemName: "photo.badge.exclamationmark")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 40, height: 40)
        .foregroundColor(.gray)
      Button {
        showSafari = true
      } label: {
        Label("status.action.view-in-browser", systemImage: "safari")
      }
      .buttonStyle(.bordered)
      .sheet(isPresented: $showSafari) {
        SafariView(url: activeURL)
          .ignoresSafeArea()
      }
    }
  }

  @ViewBuilder
  private var contextMenu: some View {
    MediaUIShareLink(url: activeURL, type: .image)
    Button {
      let targetURL = activeURL
      Task {
        let transferable = MediaUIImageTransferable(url: targetURL)
        let data = await transferable.fetchData()
        UIPasteboard.general.image = UIImage(data: data)
      }
    } label: {
      Label("status.media.contextmenu.copy", systemImage: "doc.on.doc")
    }
    Button {
      UIPasteboard.general.url = activeURL
    } label: {
      Label("status.action.copy-link", systemImage: "link")
    }
  }
}
