import Models
import NukeUI
import SwiftUI

public struct MediaUIAttachmentImageView: View {
  public let url: URL
  public let fallbackUrl: URL?
  public var onSingleTap: (() -> Void)? = nil

  @State private var currentURL: URL?
  @State private var hasTriedFallback = false
  @State private var hasFailed = false
  @GestureState private var zoom = 1.0

  public init(url: URL, fallbackUrl: URL? = nil, onSingleTap: (() -> Void)? = nil) {
    self.url = url
    self.fallbackUrl = fallbackUrl
    self.onSingleTap = onSingleTap
  }

  public var body: some View {
    MediaUIZoomableContainer(onSingleTap: onSingleTap) {
      LazyImage(url: currentURL ?? url) { state in
        if (state.error != nil || (!state.isLoading && state.image == nil)) && !hasFailed {
          if let fallback = fallbackUrl, !hasTriedFallback {
            DispatchQueue.main.async {
              self.currentURL = fallback
              self.hasTriedFallback = true
            }
          } else {
            DispatchQueue.main.async {
              self.hasFailed = true
            }
          }
        }

        return Group {
          if let image = state.image {
            image
              .resizable()
              .scaledToFit()
          } else if state.isLoading {
            ProgressView()
              .progressViewStyle(.circular)
          } else if hasFailed {
            VStack(spacing: 16) {
              Image(systemName: "photo.badge.exclamationmark")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .foregroundColor(.gray)
              Link(destination: url) {
                Label("status.action.view-in-browser", systemImage: "safari")
              }
              .buttonStyle(.bordered)
            }
          }
        }
      }
      .draggable(MediaUIImageTransferable(url: url))
      .contextMenu {
        MediaUIShareLink(url: url, type: .image)
        Button {
          Task {
            let transferable = MediaUIImageTransferable(url: url)
            UIPasteboard.general.image = UIImage(data: await transferable.fetchData())
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
    .onChange(of: url) { _, newValue in
      currentURL = newValue
      hasFailed = false
      hasTriedFallback = false
    }
  }
}
