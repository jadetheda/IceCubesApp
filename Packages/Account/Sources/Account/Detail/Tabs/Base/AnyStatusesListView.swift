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
  let showFilterWarning: Bool
  // When false (default for profile tabs), this view does not observe or apply
  // TimelineContentFilter.shared — preventing spurious re-renders from timeline-level
  // toggles like hideSeenPosts from affecting the profile media view.
  init(
    fetcher: any StatusesFetcher,
    client: MastodonClient,
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
        if showFilterWarning && (contentFilter.hidePostsWithMedia || contentFilter.hidePostsWithoutMedia) {
          HStack {
            Image(systemName: "line.3.horizontal.decrease.circle")
            Text("Some posts are hidden by your active timeline filters")
            Spacer()
          }
          .font(.caption)
          .foregroundStyle(.secondary)
          .listRowBackground(theme.primaryBackgroundColor)
        }
        
        ForEach(filteredStatuses(statuses)) { status in
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
    return statuses.filter { status in
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
  private func unboxedGallery<F: StatusesFetcher>(_ f: F) -> some View {
    GalleryStatusesListView(
      fetcher: f,
      client: client,
      routerPath: routerPath,
      isRemote: isRemote,
      filterContext: .account
    )
  }
}

