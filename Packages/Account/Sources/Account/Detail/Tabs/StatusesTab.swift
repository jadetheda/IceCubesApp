import DesignSystem
import Env
import Foundation
import Models
import NetworkClient
import Observation
import StatusKit
import SwiftUI
import Timeline

struct StatusesTab {
  let id = "statuses"
  let iconName = "bubble.right"
  let accessibilityLabel: LocalizedStringKey = "accessibility.tabs.profile.picker.statuses"
  let isAvailableForCurrentUser = true
  let isAvailableForOtherUsers = true

  func createFetcher(accountId: String, client: FediverseClient, isCurrentUser: Bool) -> any StatusesFetcher
  {
    StatusesTabFetcher(accountId: accountId, client: client, isCurrentUser: isCurrentUser)
  }

  func makeView(
    fetcher: any StatusesFetcher, client: FediverseClient, routerPath: RouterPath, account: Account?
  ) -> some View {
    let isRemote = !client.isAuth
    return StatusesTabView(
      fetcher: fetcher as! StatusesTabFetcher, client: client, routerPath: routerPath, isRemote: isRemote)
  }
}

extension StatusesTab: @MainActor AccountTabProtocol {}

@MainActor
@Observable
private class StatusesTabFetcher: AccountTabFetcher {
  var pinned: [Status] = []
  private var isFetchingNextPage = false

  override func fetchNewestStatuses(pullToRefresh: Bool) async {
    do {
      statusesState = .loading
      let fetched: [Status] = try await client.get(
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
      statuses = AccountMediaFetcher.deduplicateStatuses(fetched)

      let fetchedPinned: [Status] = try await client.get(
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
      pinned = AccountMediaFetcher.deduplicateStatuses(fetchedPinned)

      StatusDataControllerProvider.shared.updateDataControllers(for: statuses, client: client)
      StatusDataControllerProvider.shared.updateDataControllers(for: pinned, client: client)

      updateStatusesState(with: statuses, hasMore: !statuses.isEmpty)
    } catch {
      statusesState = .error(error: .noData)
    }
  }

  override func fetchNextPage() async throws {
    guard !isFetchingNextPage else { return }
    guard let lastId = statuses.last?.id else { return }
    isFetchingNextPage = true
    defer { isFetchingNextPage = false }

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

    var existingIds = Set(statuses.map { $0.id })
    var uniqueNewStatuses: [Status] = []
    for status in newStatuses {
      if existingIds.insert(status.id).inserted {
        uniqueNewStatuses.append(status)
      }
    }

    statuses.append(contentsOf: uniqueNewStatuses)
    StatusDataControllerProvider.shared.updateDataControllers(for: uniqueNewStatuses, client: client)
    updateStatusesState(with: statuses, hasMore: !uniqueNewStatuses.isEmpty)
  }

  override func handleEvent(event: any StreamEvent, currentAccount: CurrentAccount) {
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
  let client: FediverseClient
  let routerPath: RouterPath
  let isRemote: Bool

  @Environment(Theme.self) private var theme
  @Environment(UserPreferences.self) private var userPreferences
  var contentFilter = TimelineContentFilter.shared

  private var shouldShowFilterWarning: Bool {
    if contentFilter.hidePostsWithMedia { return true }
    if contentFilter.hidePostsWithoutMedia { return true }
    return false
  }

  private var isGalleryMode: Bool {
    contentFilter.isGalleryMode
  }

  private var galleryColumns: Int {
    max(1, userPreferences.galleryColumns)
  }

  private var isSquareCrop: Bool {
    userPreferences.galleryCropToSquare
  }

  private var optimizeLayout: Bool {
    userPreferences.galleryOptimizeItemLayout
  }

  private var galleryHorizontalPadding: CGFloat {
    userPreferences.galleryAddThinMargins ? 4 : 0
  }

  private var shouldDisplayPinnedSection: Bool {
    if isGalleryMode {
      return !pinnedMediaItems.isEmpty
    }
    return !filteredPinned.isEmpty
  }

  private struct PinnedGalleryItem: Identifiable {
    let id: String
    let mediaStatus: MediaStatus
    let aspectRatio: CGFloat
  }

  private var pinnedMediaItems: [PinnedGalleryItem] {
    var result: [PinnedGalleryItem] = []
    var usedIds = Set<String>()
    let square = isSquareCrop
    for status in filteredPinned {
      for mediaStatus in status.asMediaStatus {
        let baseId = mediaStatus.id
        let uniqueId: String
        if usedIds.insert(baseId).inserted {
          uniqueId = baseId
        } else {
          let compositeId = "\(status.id)-\(baseId)"
          usedIds.insert(compositeId)
          uniqueId = compositeId
        }
        let ratio = mediaStatus.attachment.galleryAspectRatio(isSquare: square)
        result.append(PinnedGalleryItem(id: uniqueId, mediaStatus: mediaStatus, aspectRatio: ratio))
      }
    }
    return result
  }

  var body: some View {
    Group {
      if case .display = fetcher.statusesState {
        if shouldShowFilterWarning {
          HStack {
            Image(systemName: "line.3.horizontal.decrease.circle")
            Text("Some posts are hidden by your \(String(localized: "timeline.content-filter.title"))")
            Spacer()
            Button("Change") {
              routerPath.presentedSheet = .timelineContentFilter
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
          }
          .font(.caption)
          .foregroundStyle(.secondary)
          .listRowBackground(theme.primaryBackgroundColor)
          .listRowSeparator(.visible, edges: .all)
        }
      }

      if shouldDisplayPinnedSection {
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
        if !status.mediaAttachments.isEmpty { return false }
        if status.reblog?.mediaAttachments.isEmpty == false { return false }
      }
      if contentFilter.hidePostsWithoutMedia {
        if status.mediaAttachments.isEmpty {
          let reblogEmpty = status.reblog?.mediaAttachments.isEmpty ?? true
          if reblogEmpty { return false }
        }
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
      .listRowSeparator(.visible, edges: .all)
      #if !os(visionOS)
        .listRowBackground(theme.primaryBackgroundColor)
      #endif

    if isGalleryMode {
      GalleryMasonryLayout(
        columns: galleryColumns,
        spacing: 4,
        optimizeLayout: optimizeLayout
      ) {
        ForEach(pinnedMediaItems) { item in
          GalleryMediaCell(
            mediaStatus: item.mediaStatus,
            routerPath: routerPath,
            client: client,
            isRemote: isRemote,
            filterContext: .account
          )
          .galleryLayoutItemKind(.media(aspectRatio: item.aspectRatio))
        }
      }
      .padding(.horizontal, galleryHorizontalPadding)
      .frame(maxWidth: .infinity)
      .listRowBackground(theme.primaryBackgroundColor)
      .listRowInsets(EdgeInsets())
      .listRowSeparator(.hidden)
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
      .listRowSeparator(.visible, edges: .all)
      .accessibilityHidden(true)
  }
}
