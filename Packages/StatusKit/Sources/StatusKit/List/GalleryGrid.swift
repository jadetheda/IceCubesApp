import DesignSystem
import Env
import Models
import NetworkClient
import SwiftUI

@MainActor
public struct GalleryGrid: View {
  let mediaStatuses: [MediaStatus]
  let routerPath: RouterPath
  let client: MastodonClient
  let isRemote: Bool
  let filterContext: Filter.Context?

  public init(
    mediaStatuses: [MediaStatus],
    routerPath: RouterPath,
    client: MastodonClient,
    isRemote: Bool = false,
    filterContext: Filter.Context? = nil
  ) {
    self.mediaStatuses = mediaStatuses
    self.routerPath = routerPath
    self.client = client
    self.isRemote = isRemote
    self.filterContext = filterContext
  }

  public var body: some View {
    let columns = UserPreferences.shared.galleryColumns
    
    let columnItems: [[MediaStatus]] = {
      var items: [[MediaStatus]] = Array(repeating: [], count: columns)
      for (index, status) in mediaStatuses.enumerated() {
          items[index % columns].append(status)
      }
      return items
    }()
        
    HStack(alignment: .top, spacing: 4) {
      ForEach(0..<columns, id: \.self) { colIndex in
        LazyVStack(spacing: 4) {
          ForEach(columnItems[colIndex]) { status in
            GalleryMediaCell(
              mediaStatus: status,
              routerPath: routerPath,
              client: client,
              isRemote: isRemote,
              filterContext: filterContext
            )
          }
        }
      }
    }
  }
}
