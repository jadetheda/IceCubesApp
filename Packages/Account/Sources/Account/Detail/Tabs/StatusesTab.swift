import DesignSystem
import Env
import Models
import NetworkClient
import StatusKit
import SwiftUI
import Timeline

struct StatusesTab {
  let id = "statuses"
  let iconName = "bubble.right"
  let accessibilityLabel: LocalizedStringKey = "accessibility.tabs.profile.picker.statuses"
  let isAvailableForCurrentUser = true
  let isAvailableForOtherUsers = true

  func createFetcher(accountId: String, client: MastodonClient, isCurrentUser: Bool) -> any StatusesFetcher
  {
    StatusesTabFetcher(accountId: accountId, client: client, isCurrentUser: isCurrentUser)
  }

  func makeView(
    fetcher: any StatusesFetcher, client: MastodonClient, routerPath: RouterPath, account: Account?
  ) -> some View {
    let isRemote = account?.url?.host?.lowercased() != client.server.lowercased()
    return StatusesTabView(
      fetcher: fetcher as! StatusesTabFetcher, client: client, routerPath: routerPath, isRemote: isRemote)
  }
}

extension StatusesTab: @MainActor AccountTabProtocol {}

@MainActor
@Observable
private class StatusesTabFetcher: AccountTabFetcher {
  var pinned: [Status] = []

  override func fetchNewestStatuses(pullToRefresh: Bool) async {
    do {
      statusesState = .loading
      statuses = try await client.get(
        endpoint: Accounts.statuses(
          id: accountId,
          sinceId: nil,
          tag: nil,
          onlyMedia: false,
          excludeReplies: true,
          excludeReblogs: true,
          pinned: nil
        )
      )

      pinned = try await client.get(
        endpoint: Accounts.statuses(
          id: accountId,
          sinceId: nil,
          tag: nil,
          onlyMedia: false,
          excludeReplies: false,
          excludeReblogs: false,
          pinned: true
        )
      )

      StatusDataControllerProvider.shared.updateDataControllers(for: statuses, client: client)
      StatusDataControllerProvider.shared.updateDataControllers(for: pinned, client: client)

      updateStatusesState(with: statuses, hasMore: statuses.count >= 20)
    } catch {
      statusesState = .error(error: .noData)
    }
  }

  override func fetchNextPage() async throws {
    guard let lastId = statuses.last?.id else { return }

    let newStatuses: [Status] = try await client.get(
      endpoint: Accounts.statuses(
        id: accountId,
        sinceId: lastId,
        tag: nil,
        onlyMedia: false,
        excludeReplies: true,
        excludeReblogs: true,
        pinned: nil
      )
    )

    statuses.append(contentsOf: newStatuses)
    StatusDataControllerProvider.shared.updateDataControllers(for: newStatuses, client: client)
    updateStatusesState(with: statuses, hasMore: newStatuses.count >= 20)
  }

  override func handleEvent(event: any StreamEvent, currentAccount: CurrentAccount) {
    // Handle pinned posts updates in addition to the base implementation
    super.handleEvent(event: event, currentAccount: currentAccount)

    if let event = event as? StreamEventDelete {
      pinned.removeAll(where: { $0.id == event.status })
    } else if let event = event as? StreamEventStatusUpdate {
      if let pinnedIndex = pinned.firstIndex(where: { $0.id == event.status.id }) {
        pinned[pinnedIndex] = event.status
      }
    }
  }
}

private struct StatusesTabView: View {
  let fetcher: StatusesTabFetcher
  let client: MastodonClient
  let routerPath: RouterPath
  let isRemote: Bool

  @Environment(Theme.self) private var theme
  var contentFilter = TimelineContentFilter.shared

  var body: some View {
    Group {
      if case .display = fetcher.statusesState {
        if contentFilter.hidePostsWithMedia || contentFilter.hidePostsWithoutMedia {
          HStack {
            Image(systemName: "line.3.horizontal.decrease.circle")
            Text("Some posts are hidden by your active timeline filters")
            Spacer()
          }
          .font(.caption)
          .foregroundStyle(.secondary)
          .listRowBackground(theme.primaryBackgroundColor)
        }
      }

      if !filteredPinned.isEmpty {
        pinnedPostsView
      }

      AnyStatusesListView(
        fetcher: fetcher,
        client: client,
        routerPath: routerPath,
        isRemote: isRemote,
        isMediaTab: false,
        showFilterWarning: false
      )
    }
  }

  private var filteredPinned: [Status] {
    fetcher.pinned.filter { status in
      if contentFilter.hidePostsWithMedia {
        if !status.mediaAttachments.isEmpty || status.reblog?.mediaAttachments.isEmpty == false { return false }
      }
      if contentFilter.hidePostsWithoutMedia {
        if status.mediaAttachments.isEmpty && status.reblog?.mediaAttachments.isEmpty ?? true { return false }
      }
      return true
    }
  }

  @ViewBuilder
  private var pinnedPostsView: some View {
    Label("account.post.pinned \(fetcher.pinned.count)", systemImage: "pin.fill")
      .accessibilityAddTraits(.isHeader)
      .font(.scaledFootnote)
      .foregroundStyle(.secondary)
      .fontWeight(.semibold)
      .listRowInsets(
        .init(
          top: 0,
          leading: 12,
          bottom: 0,
          trailing: .layoutPadding)
      )
      .listRowSeparator(.hidden)
      #if !os(visionOS)
        .listRowBackground(theme.primaryBackgroundColor)
      #endif

    let contentFilter = TimelineContentFilter.shared
    if contentFilter.isGalleryMode {
      let mediaStatuses = filteredPinned.flatMap { $0.asMediaStatus }
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
                isRemote: isRemote,
                filterContext: .account
              )
              .id(mediaStatus.status.id)
            }
            Spacer(minLength: 0)
          }
          .frame(minWidth: 0, maxWidth: .infinity)
        }
      }
      .padding(.horizontal, UserPreferences.shared.galleryAddThinMargins ? 4 : 0)
      .listRowBackground(theme.primaryBackgroundColor)
      .listRowInsets(EdgeInsets())
    } else {
      ForEach(filteredPinned) { status in
        StatusRowExternalView(
          viewModel: .init(
            status: status,
            client: client,
            routerPath: routerPath,
            filterContext: .account)
        )
      }
    }

    Rectangle()
      #if os(visionOS)
        .fill(Color.clear)
      #else
        .fill(theme.secondaryBackgroundColor)
      #endif
      .frame(height: 12)
      .listRowInsets(.init())
      .listRowSeparator(.hidden)
      .accessibilityHidden(true)
  }
}
