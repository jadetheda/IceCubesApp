import SwiftUI

public struct MediaUIShareLink: View, @unchecked Sendable {
  let url: URL
  let fallbackUrl: URL? = nil
  let type: DisplayType

  public init(url: URL, fallbackUrl: URL? = nil, type: DisplayType) {
    self.url = url
    self.fallbackUrl = fallbackUrl
    self.type = type
  }

  public var body: some View {
    if type == .image {
      let transferable = MediaUIImageTransferable(url: url, fallbackUrl: fallbackUrl)
      ShareLink(
        item: transferable,
        preview: .init(
          "status.media.contextmenu.share",
          image: transferable))
    } else {
      ShareLink(item: fallbackUrl ?? url)
    }
  }
}
