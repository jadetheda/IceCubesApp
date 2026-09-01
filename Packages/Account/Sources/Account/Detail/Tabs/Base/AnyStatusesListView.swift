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
  let isRemote: Bool
  let isMediaTab: Bool
  // When false (default for profile tabs), this view does not observe or apply
  // TimelineContentFilter.shared — preventing spurious re-renders from timeline-level
  // toggles like hideSeenPosts from affecting the profile media view.
  init(
    fetcher: any StatusesFetcher,
    client: MastodonClient,
    routerPath: RouterPath,
    isRemote: Bool = false,
    isMediaTab: Bool = false
  ) {
    self.fetcher = fetcher
    self.client = client
    self.routerPath = routerPath
    self.isRemote = isRemote
    self.isMediaTab = isMediaTab
  }
  
  @Environment(Theme.self) private var theme
  
  var contentFilter = TimelineContentFilter.shared
  
  var body: some View {
    if isMediaTab && contentFilter.isGalleryMode {
      AnyView(unboxedGallery(fetcher))
        .listRowBackground(theme.primaryBackgroundColor)
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
          .onAppear { fetcher.statusDidAppear(status: status) }
          .onDisappear { fetcher.statusDidDisappear(status: status) }
          .redacted(reason: .placeholder)
          .allowsHitTesting(false)
        }
      case let .display(statuses, nextPageState):
        ForEach(statuses) { status in
          StatusRowExternalView(
            viewModel: .init(
              status: status,
              client: client,
              routerPath: routerPath,
              filterContext: .account)
          )
          .onAppear { fetcher.statusDidAppear(status: status) }
          .onDisappear { fetcher.statusDidDisappear(status: status) }
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
      statusesState: f.statusesState,
      client: client,
      isRemote: isRemote,
      filterContext: .account,
      fetchNextPage: f.fetchNextPage,
      fetchNewestStatuses: { await f.fetchNewestStatuses(pullToRefresh: false) },
      statusDidAppear: f.statusDidAppear,
      statusDidDisappear: f.statusDidDisappear
    )
  }
}

