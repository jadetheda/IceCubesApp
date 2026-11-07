import DesignSystem
import Env
import Models
import NetworkClient
import StatusKit
import SwiftUI
import Timeline

struct TrendingPostsSection: View {
  @Environment(Theme.self) private var theme
  @Environment(FediverseClient.self) private var client
  @Environment(RouterPath.self) private var routerPath
  
  let trendingStatuses: [Status]
  
  private var isGalleryMode: Bool {
    TimelineContentFilter.shared.isGalleryMode
  }

  private var displayedMediaStatuses: [MediaStatus] {
    Array(trendingStatuses.flatMap(\.asMediaStatus).prefix(6))
  }

  var body: some View {
    Section("explore.section.trending.posts") {
      if isGalleryMode {
        galleryPreviewGrid
      } else {
        ForEach(trendingStatuses.prefix(3)) { status in
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

  private var galleryPreviewGrid: some View {
    let prefs = UserPreferences.shared
    return GalleryMasonryLayout(
      columns: max(1, prefs.galleryColumns),
      spacing: 4,
      optimizeLayout: prefs.galleryOptimizeItemLayout,
      cropToSquare: prefs.galleryCropToSquare
    ) {
      ForEach(displayedMediaStatuses) { mediaStatus in
        GalleryMediaCell(
          mediaStatus: mediaStatus,
          routerPath: routerPath,
          client: client,
          isRemote: !client.isAuth,
          filterContext: .pub
        )
        .id(mediaStatus.id)
      }
    }
    .padding(.horizontal, prefs.galleryAddThinMargins ? 4 : 0)
    .listRowBackground(theme.primaryBackgroundColor)
    .listRowInsets(EdgeInsets())
  }
}
