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
    if let container = state.imageContainer {
      if container.type == .gif {
        if let data = container.data {
          return data
        }
      }
    }
    let targetUrl = activeURL
    if targetUrl.pathExtension.lowercased() == "gif" {
      if let cached = ImagePipeline.shared.cache.cachedData(for: .init(url: targetUrl)) {
        return cached
      }
      if let cached = ImagePipeline.shared.cache.cachedData(for: .init(url: url)) {
        return cached
      }
    }
    if let container = state.imageContainer {
      if container.type == .gif {
        if let cached = ImagePipeline.shared.cache.cachedData(for: .init(url: targetUrl)) {
          return cached
        }
        if let cached = ImagePipeline.shared.cache.cachedData(for: .init(url: url)) {
          return cached
        }
      }
    }
    return nil
  }

  private func evaluateFailure(for state: LazyImageState) {
    if hasFailed {
      return
    }
    let isError = state.error != nil
    var isMissing = false
    if !state.isLoading {
      if state.image == nil {
        isMissing = true
      }
    }
    if isError || isMissing {
      if !hasTriedFallback {
        if let fallback = fallbackUrl {
          DispatchQueue.main.async {
            self.currentURL = fallback
            self.hasTriedFallback = true
          }
          return
        }
      }
      DispatchQueue.main.async {
        self.hasFailed = true
      }
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
      .draggable(MediaUIImageTransferable(url: url))
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
    } else if state.isLoading {
      ProgressView()
        .progressViewStyle(.circular)
    } else if hasFailed {
      failureView
    }
  }

  private func makeGifView(data: Data, state: LazyImageState) -> some View {
    GifView(data: data, forceAnimate: true)
      .aspectRatio(gifAspectRatio(from: state, data: data), contentMode: .fit)
  }

  private func gifAspectRatio(from state: LazyImageState, data: Data) -> CGFloat? {
    if let container = state.imageContainer {
      let size = container.image.size
      if size.width > 0 {
        if size.height > 0 {
          let aspect = size.width / size.height
          if aspect > 0 {
            if aspect.isFinite {
              return aspect
            }
          }
        }
      }
    }
    if data.count >= 10 {
      let start = data.startIndex
      let b0 = data[start]
      let b1 = data[start + 1]
      let b2 = data[start + 2]
      if b0 == 0x47 {
        if b1 == 0x49 {
          if b2 == 0x46 {
            let w = UInt16(data[start + 6]) | (UInt16(data[start + 7]) << 8)
            let h = UInt16(data[start + 8]) | (UInt16(data[start + 9]) << 8)
            if w > 0 {
              if h > 0 {
                let aspect = CGFloat(w) / CGFloat(h)
                if aspect > 0 {
                  if aspect.isFinite {
                    return aspect
                  }
                }
              }
            }
          }
        }
      }
    }
    if let uiImage = UIImage(data: data) {
      let size = uiImage.size
      if size.width > 0 {
        if size.height > 0 {
          let aspect = size.width / size.height
          if aspect > 0 {
            if aspect.isFinite {
              return aspect
            }
          }
        }
      }
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
        SafariView(url: url)
          .ignoresSafeArea()
      }
    }
  }

  @ViewBuilder
  private var contextMenu: some View {
    MediaUIShareLink(url: url, type: .image)
    Button {
      Task {
        let transferable = MediaUIImageTransferable(url: url)
        let data = await transferable.fetchData()
        UIPasteboard.general.image = UIImage(data: data)
      }
    } label: {
      Label("status.media.contextmenu.copy", systemImage: "doc.on.doc")
    }
    Button {
      UIPasteboard.general.url = url
    } label: {
      Label("status.action.copy-link", systemImage: "link")
    }
  }
}
