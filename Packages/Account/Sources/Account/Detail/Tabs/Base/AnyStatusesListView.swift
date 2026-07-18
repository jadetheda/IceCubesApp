import SwiftUI
import StatusKit
import NetworkClient
import Env
import Models
import DesignSystem
import Timeline

struct AnyStatusesListView<Fetcher: StatusesFetcher>: View {
  let fetcher: Fetcher
  let client: MastodonClient
  let routerPath: RouterPath
  
  @Environment(Theme.self) private var theme
  
  // Directly access the shared TimelineContentFilter for synced visual state.
  var contentFilter = TimelineContentFilter.shared
  
  var body: some View {
    if contentFilter.isGalleryMode {
      GalleryStatusesListView(
        fetcher: fetcher,
        client: client,
        routerPath: routerPath,
        isRemote: false,
        filterContext: .account
      )
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
    statuses.filter { status in
      if contentFilter.hidePostsWithMedia {
        if !status.mediaAttachments.isEmpty || status.reblog?.mediaAttachments.isEmpty == false { return false }
      }
      if contentFilter.hidePostsWithoutMedia {
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
}
