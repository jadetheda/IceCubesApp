import DesignSystem
import Env
import Models
import NetworkClient
import StatusKit
import SwiftUI
import Timeline

@MainActor
struct AnyStatusesListView: View {
  let fetcher: any StatusesFetcher
  let client: FediverseClient
  let routerPath: RouterPath
  let isRemote: Bool
  let isMediaTab: Bool
  let showFilterWarning: Bool

  init(
    fetcher: any StatusesFetcher,
    client: FediverseClient,
    routerPath: RouterPath,
    isRemote: Bool = false,
    isMediaTab: Bool = false,
    showFilterWarning: Bool = true
  ) {
    self.fetcher = fetcher
    self.client = client
    self.routerPath = routerPath
    self.isRemote = isRemote
    self.isMediaTab = isMediaTab
    self.showFilterWarning = showFilterWarning
  }

  @Environment(Theme.self) private var theme

  var contentFilter = TimelineContentFilter.shared
  private var shouldShowFilterWarningBanner: Bool {
    if !showFilterWarning { return false }
    if contentFilter.hidePostsWithMedia { return true }
    if contentFilter.hidePostsWithoutMedia { return true }
    return false
  }

  var body: some View {
    if contentFilter.isGalleryMode {
      if shouldShowFilterWarningBanner {
        filterWarningBanner
      }
      unboxedGallery(fetcher)
        .listRowBackground(theme.primaryBackgroundColor)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
    } else {
      switch fetcher.statusesState {
      case .loading:
        ForEach(Status.placeholders()) { status in
          StatusRowExternalView(
            viewModel: .init(
              status: status,
              client: client,
              routerPath: routerPath,
              filterContext: .account)
          )
          .redacted(reason: .placeholder)
          .allowsHitTesting(false)
        }
      case let .display(statuses, nextPageState):
        if shouldShowFilterWarningBanner {
          filterWarningBanner
        }

        ForEach(filteredStatuses(statuses)) { status in
          StatusRowExternalView(
            viewModel: .init(
              status: status,
              client: client,
              routerPath: routerPath,
              filterContext: .account)
          )
          .trackStatusVisibility(status: status, fetcher: fetcher, requiresMediaToLoad: true)
        }

        if nextPageState == .hasNextPage {
          NextPageView {
            try await fetcher.fetchNextPage()
          }
          .listRowBackground(theme.primaryBackgroundColor)
          .id(statuses.count)
        }
      case .error:
        ErrorView(
          title: "status.error.title",
          message: "status.error.loading.message",
          buttonTitle: "action.retry"
        ) {
          await fetcher.fetchNewestStatuses(pullToRefresh: false)
        }
        .listRowBackground(theme.primaryBackgroundColor)
        .listRowSeparator(.visible, edges: .all)
      case .displayWithGaps:
        EmptyView()
      }
    }
  }

  @ViewBuilder
  private var filterWarningBanner: some View {
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

  private func filteredStatuses(_ statuses: [Status]) -> [Status] {
    return statuses.filter { status in
      if contentFilter.hidePostsWithMedia {
        if !status.mediaAttachments.isEmpty {
          return false
        }
        let reblogEmpty = status.reblog?.mediaAttachments.isEmpty ?? true
        if !reblogEmpty {
          return false
        }
      }
      if contentFilter.hidePostsWithoutMedia {
        if status.mediaAttachments.isEmpty {
          let reblogEmpty = status.reblog?.mediaAttachments.isEmpty ?? true
          if reblogEmpty {
            return false
          }
        }
      }
      return true
    }
  }

  /// Opens the existential `StatusesFetcher` without wrapping `GalleryStatusesListView` in unary
  /// `.background(...)` or `.buttonStyle(...)` modifiers so SwiftUI's `List` forwards multi-row traits
  /// (`ForEach` chunks and `NextPageView`) cleanly instead of collapsing them into one `UICollectionViewCell`.
  private func unboxedGallery<F: StatusesFetcher>(_ f: F) -> AnyView {
    AnyView(
      GalleryStatusesListView(
        fetcher: f,
        client: client,
        routerPath: routerPath,
        isRemote: isRemote,
        filterContext: .account
      )
    )
  }
}
