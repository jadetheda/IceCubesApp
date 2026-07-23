import Account
import DesignSystem
import Env
import Models
import NetworkClient
import StatusKit
import SwiftUI
import Timeline

struct SearchResultsView: View {
  @Environment(Theme.self) private var theme
  @Environment(MastodonClient.self) private var client
  @Environment(RouterPath.self) private var routerPath
  
  let results: SearchResults
  let searchScope: SearchScope
  let onNextPage: (Search.EntityType) async -> Void
  
  var body: some View {
    Group {
      if !results.accounts.isEmpty, searchScope == .all || searchScope == .people {
        Section("explore.section.users") {
          ForEach(results.accounts) { account in
            if let relationship = results.relationships.first(where: { $0.id == account.id }) {
              AccountsListRow(viewModel: .init(account: account, relationShip: relationship))
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
          if searchScope == .people {
            NextPageView {
              await onNextPage(.accounts)
            }
            .padding(.horizontal, .layoutPadding)
            #if !os(visionOS)
              .listRowBackground(theme.primaryBackgroundColor)
            #endif
          }
        }
      }
      
      if !results.hashtags.isEmpty,
        searchScope == .all || searchScope == .hashtags
      {
        Section("explore.section.tags") {
          ForEach(results.hashtags) { tag in
            TagRowView(tag: tag)
              #if !os(visionOS)
                .listRowBackground(theme.primaryBackgroundColor)
              #else
                .listRowBackground(
                  RoundedRectangle(cornerRadius: 8)
                    .foregroundStyle(.background).hoverEffect()
                )
                .listRowHoverEffectDisabled()
              #endif
              .padding(.vertical, 4)
          }
          if searchScope == .hashtags {
            NextPageView {
              await onNextPage(.hashtags)
            }
            .padding(.horizontal, .layoutPadding)
            #if !os(visionOS)
              .listRowBackground(theme.primaryBackgroundColor)
            #endif
          }
        }
      }
      
      if !results.statuses.isEmpty, searchScope == .all || searchScope == .posts {
        Section("explore.section.posts") {
          let contentFilter = TimelineContentFilter.shared
          if contentFilter.isGalleryMode {
            let mediaStatuses = results.statuses.flatMap { $0.asMediaStatus }
            let columns = UserPreferences.shared.galleryColumns
            
            let columnItems: [[MediaStatus]] = {
              var items: [[MediaStatus]] = Array(repeating: [], count: columns)
              var columnHeights: [CGFloat] = Array(repeating: 0, count: columns)
              
              var currentIndex = 0
              for status in mediaStatuses {
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
            ForEach(results.statuses) { status in
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
          if searchScope == .posts {
            NextPageView {
              await onNextPage(.statuses)
            }
            .padding(.horizontal, .layoutPadding)
            #if !os(visionOS)
              .listRowBackground(theme.primaryBackgroundColor)
            #endif
          }
        }
      }
    }
  }
}
