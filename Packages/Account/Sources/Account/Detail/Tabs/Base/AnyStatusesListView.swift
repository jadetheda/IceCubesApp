import SwiftUI
import StatusKit
import NetworkClient
import Env
import Models
import DesignSystem
import Timeline

struct AnyStatusesListView: View {
  let fetcher: any StatusesFetcher
  let client: MastodonClient
  let routerPath: RouterPath
  // When false (default for profile tabs), this view does not observe or apply
  // TimelineContentFilter.shared — preventing spurious re-renders from timeline-level
  // toggles like hideReadPosts from affecting the profile media view.
  let useTimelineFilter: Bool

  init(
    fetcher: any StatusesFetcher,
    client: MastodonClient,
    routerPath: RouterPath,
    useTimelineFilter: Bool = false
  ) {
    self.fetcher = fetcher
    self.client = client
    self.routerPath = routerPath
    self.useTimelineFilter = useTimelineFilter
  }
  
  @Environment(Theme.self) private var theme
  
  // Only read the shared filter when we actually need it.
  // Pulling it into a stored property makes this view an @Observable subscriber,
  // which means ANY change to TimelineContentFilter triggers a full re-render — even
  // unrelated fields like hideReadPosts that have no meaning in a profile context.
  private var contentFilter: TimelineContentFilter? {
    useTimelineFilter ? TimelineContentFilter.shared : nil
  }
  
  var body: some View {
    // In profile tabs, Gallery Mode is managed separately (via the shared filter),
    // but we intentionally don't subscribe to it here to avoid spurious re-renders.
    let isGalleryMode = useTimelineFilter && (contentFilter?.isGalleryMode ?? false)
    if isGalleryMode {
      AnyView(unboxedGallery(fetcher))
        .listRowInsets(EdgeInsets())
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
        ForEach(filteredStatuses(statuses)) { status in
          StatusRowExternalView(
            viewModel: .init(
              status: status,
              client: client,
              routerPath: routerPath,
              filterContext: .account)
          )
        }
        
        if nextPageState == .hasNextPage {
          loadMoreView
            .onAppear {
              Task {
                try? await fetcher.fetchNextPage()
              }
            }
        }
      case .error:
        ErrorView(
          title: "status.error.title",
          message: "status.error.loading.message",
          buttonTitle: "action.retry"
        ) {
          Task {
            await fetcher.fetchNewestStatuses(pullToRefresh: false)
          }
        }
        .listRowBackground(theme.primaryBackgroundColor)
        .listRowSeparator(.hidden)
      case .displayWithGaps:
        EmptyView()
      }
    }
  }
  
  private func filteredStatuses(_ statuses: [Status]) -> [Status] {
    // If we are not applying the global timeline filter (profile context),
    // return statuses as-is. The server-side fetch already filtered by media type.
    guard let filter = contentFilter else { return statuses }
    return statuses.filter { status in
      if filter.hidePostsWithMedia {
        if !status.mediaAttachments.isEmpty || status.reblog?.mediaAttachments.isEmpty == false { return false }
      }
      if filter.hidePostsWithoutMedia {
        if status.mediaAttachments.isEmpty && status.reblog?.mediaAttachments.isEmpty ?? true { return false }
      }
      return true
    }
  }
  
  private var loadMoreView: some View {
    HStack {
      Spacer()
      ProgressView()
      Spacer()
    }
    .padding()
    .listRowBackground(theme.primaryBackgroundColor)
  }
  
  @ViewBuilder
  private func unboxedGallery<F: StatusesFetcher>(_ f: F) -> some View {
    GalleryStatusesListView(
      fetcher: f,
      client: client,
      routerPath: routerPath,
      isRemote: false,
      filterContext: .account
    )
  }
}

