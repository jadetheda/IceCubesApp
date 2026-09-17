import SwiftUI

struct ShareToolbarItem: ToolbarContent, @unchecked Sendable {
  let url: URL
  var fallbackUrl: URL? = nil
  let type: DisplayType

  var body: some ToolbarContent {
    ToolbarItem(placement: .topBarTrailing) {
      MediaUIShareLink(url: url, fallbackUrl: fallbackUrl, type: type)
    }
  }
}
