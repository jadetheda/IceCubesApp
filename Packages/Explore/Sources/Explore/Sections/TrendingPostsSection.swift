import DesignSystem
import Env
import Models
import NetworkClient
import StatusKit
import SwiftUI
import Timeline

struct TrendingPostsSection: View {
  @Environment(Theme.self) private var theme
  @Environment(MastodonClient.self) private var client
  @Environment(RouterPath.self) private var routerPath
  
  let trendingStatuses: [Status]
  
  var body: some View {
    Section("explore.section.trending.posts") {
      let contentFilter = TimelineContentFilter.shared
      if contentFilter.isGalleryMode {
        let mediaStatuses = trendingStatuses.compactMap { $0.asMediaStatus }
        let displayedStatuses = Array(mediaStatuses.prefix(6))
        let columns = UserPreferences.shared.galleryColumns
        
        let columnItems: [[MediaStatus]] = {
          var items: [[MediaStatus]] = Array(repeating: [], count: columns)
          var columnHeights: [CGFloat] = Array(repeating: 0, count: columns)
          
          var currentIndex = 0
          for status in displayedStatuses {
            let targetColIndex: Int
            if UserPreferences.shared.galleryOptimizeItemLayout {
              var shortestColIndex = 0
              var shortestHeight = columnHeights[0]
              
              for i in 1..<columns {
                if columnHeights[i] < shortestHeight {
                  shortestHeight = columnHeights[i]
                  shortestColIndex = i
                }
              }
              targetColIndex = shortestColIndex
            } else {
              targetColIndex = currentIndex % columns
            }
            
            items[targetColIndex].append(status)
            
            let isSquare = UserPreferences.shared.galleryCropToSquare
            let aspectRatio = isSquare ? 1.0 : (status.attachment.clampedAspectRatio ?? 1.0)
            columnHeights[targetColIndex] += (1.0 / aspectRatio) + 0.1
            currentIndex += 1
          }
          
          return items
        }()
        
        HStack(alignment: .top, spacing: 4) {
          ForEach(0..<columns, id: \.self) { colIndex in
            LazyVStack(spacing: 4) {
              ForEach(columnItems[colIndex]) { mediaStatus in
                GalleryMediaCell(
                  mediaStatus: mediaStatus,
                  routerPath: routerPath,
                  client: client,
                  isRemote: false,
                  filterContext: .pub
                )
                .id(mediaStatus.status.id)
              }
              Spacer(minLength: 0)
            }
            .frame(minWidth: 0, maxWidth: .infinity)
          }
        }
        .padding(.horizontal, UserPreferences.shared.galleryAddThinMargins ? 4 : 0)
        .listRowInsets(EdgeInsets())
      } else {
        ForEach(
          trendingStatuses
            .prefix(upTo: trendingStatuses.count > 3 ? 3 : trendingStatuses.count)
        ) { status in
          StatusRowExternalView(
            viewModel: .init(
              status: status,
              client: client,
              routerPath: routerPath,
              filterContext: .pub)
          )
          #if !os(visionOS)
            .listRowBackground(theme.primaryBackgroundColor)
          #else
            .listRowBackground(
              RoundedRectangle(cornerRadius: 8)
                .foregroundStyle(.background).hoverEffect()
            )
            .listRowHoverEffectDisabled()
          #endif
          .padding(.vertical, 8)
        }
      }
      
      NavigationLink(value: RouterDestination.trendingTimeline) {
        Text("see-more")
          .foregroundColor(theme.tintColor)
      }
      #if !os(visionOS)
        .listRowBackground(theme.primaryBackgroundColor)
      #else
        .listRowBackground(
          RoundedRectangle(cornerRadius: 8)
            .foregroundStyle(.background).hoverEffect()
        )
        .listRowHoverEffectDisabled()
      #endif
    }
  }
}
