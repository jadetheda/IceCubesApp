import Models
import NukeUI
import SwiftUI

public struct MediaUIAttachmentImageView: View {
  public let url: URL
  public var onSingleTap: (() -> Void)? = nil

  @GestureState private var zoom = 1.0

  public var body: some View {
    MediaUIZoomableContainer(onSingleTap: onSingleTap) {
      LazyImage(url: url) { state in
        if let image = state.image {
          image
            .resizable()
            .scaledToFit()
        } else if state.isLoading {
          ProgressView()
            .progressViewStyle(.circular)
        } else if state.error != nil {
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
  }
}
