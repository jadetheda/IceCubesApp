import DesignSystem
import Env
import MediaUI
import Models
import NetworkClient
import NukeUI
import SwiftUI
import StatusKit
import Observation

/// `AccountMediaFetcher` provides a unified `StatusesFetcher` conforming interface for the 
/// Profile Media Gallery. This eliminates the fragmentation of having a custom grid layout 
/// just for profiles, allowing us to leverage `GalleryStatusesListView` natively.
@MainActor
@Observable
public class AccountMediaFetcher: StatusesFetcher {
  public let accountId: String
  public var client: MastodonClient?
  
  public var statusesState: StatusesState = .loading
  public var statuses: [Status] = []
  
  public init(accountId: String, client: MastodonClient? = nil, initialStatuses: [Status] = []) {
    self.accountId = accountId
    self.client = client
    if !initialStatuses.isEmpty {
      self.statuses = initialStatuses
      // Standardize the next page state based on the provided items
      self.statusesState = .display(statuses: initialStatuses, nextPageState: initialStatuses.count >= 20 ? .hasNextPage : .none)
    }
  }
  
  public func fetchNewestStatuses(pullToRefresh: Bool) async {
    guard let client else { return }
    do {
      statusesState = .loading
      let newStatuses: [Status] = try await client.get(
        endpoint: Accounts.statuses(
          id: accountId,
          sinceId: nil,
          tag: nil,
          onlyMedia: true,
          excludeReplies: true,
          excludeReblogs: true,
          pinned: nil
        )
      )
      
      statuses = newStatuses
      StatusDataControllerProvider.shared.updateDataControllers(for: newStatuses, client: client)
      // Check for empty to determine pagination end safely
      statusesState = .display(statuses: newStatuses, nextPageState: newStatuses.isEmpty ? .none : .hasNextPage)
    } catch {
      statusesState = .error(error: .noData)
    }
  }
  
  public func fetchNextPage() async throws {
    guard let client, let lastId = statuses.last?.id else { return }
    
    let newStatuses: [Status] = try await client.get(
      endpoint: Accounts.statuses(
        id: accountId,
        sinceId: lastId,
        tag: nil,
        onlyMedia: true,
        excludeReplies: true,
        excludeReblogs: true,
        pinned: nil
      )
    )
    
    statuses.append(contentsOf: newStatuses)
    StatusDataControllerProvider.shared.updateDataControllers(for: newStatuses, client: client)
    // Safely check if we're out of remote pages
    statusesState = .display(statuses: statuses, nextPageState: newStatuses.isEmpty ? .none : .hasNextPage)
  }
  
  public func statusDidAppear(status: Status) {}
  public func statusDidDisappear(status: Status) {}
}

@MainActor
public struct AccountDetailMediaGridView: View {
  @Environment(Theme.self) private var theme
  @Environment(RouterPath.self) private var routerPath
  @Environment(MastodonClient.self) private var client
  
  let account: Account
  @State private var fetcher: AccountMediaFetcher
  
  public init(account: Account, initialMediaStatuses: [MediaStatus]) {
    self.account = account
    let initialStatuses = initialMediaStatuses.map { $0.status }
    _fetcher = .init(initialValue: AccountMediaFetcher(accountId: account.id, initialStatuses: initialStatuses))
  }
  
  public var body: some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        // Reuse the exact same masonry gallery implementation from the Timeline
        // This eliminates layout bugs and standardizes remote-media behavior.
        GalleryStatusesListView(
          fetcher: fetcher,
          client: client,
          routerPath: routerPath
        )
      }
      .padding(.top, .layoutPadding)
    }
    .navigationTitle(account.displayName ?? "")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
      if fetcher.client == nil {
        fetcher.client = client
        if fetcher.statuses.isEmpty {
          Task {
            await fetcher.fetchNewestStatuses(pullToRefresh: false)
          }
        }
      }
    }
    #if !os(visionOS)
      .background(theme.primaryBackgroundColor)
    #endif
    .refreshable {
      await fetcher.fetchNewestStatuses(pullToRefresh: true)
    }
  }
}
