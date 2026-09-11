import Env
import Models
import NetworkClient
import StatusKit
import SwiftUI

struct BoostsTab {
  let id = "boosts"
  let iconName = "arrow.2.squarepath"
  let accessibilityLabel: LocalizedStringKey = "accessibility.tabs.profile.picker.boosts"
  let isAvailableForCurrentUser = true
  let isAvailableForOtherUsers = true

  func createFetcher(accountId: String, client: FediverseClient, isCurrentUser: Bool)
    -> any StatusesFetcher
  {
    BoostsTabFetcher(accountId: accountId, client: client, isCurrentUser: isCurrentUser)
  }

  func makeView(
    fetcher: any StatusesFetcher, client: FediverseClient, routerPath: RouterPath, account: Account?
  ) -> some View {
    AnyStatusesListView(
      fetcher: fetcher,
      client: client,
      routerPath: routerPath,
      isRemote: account?.url?.host?.lowercased() != client.server.lowercased()
    )
  }
}

extension BoostsTab: @MainActor AccountTabProtocol {}

@MainActor
@Observable
private class BoostsTabFetcher: AccountTabFetcher {
  var boosts: [Status] = []
  private var lastFetchedId: String?

  override func fetchNewestStatuses(pullToRefresh: Bool) async {
    do {
      statusesState = .loading
      var allFetched: [Status] = []
      var currentBoosts: [Status] = []
      var currentLastId: String? = nil
      var hasMore = true
      var fetchCount = 0
      
      while currentBoosts.isEmpty && hasMore && fetchCount < 5 {
        fetchCount += 1
        let fetchedStatuses: [Status] = try await client.get(
          endpoint: Accounts.statuses(
            id: accountId,
            sinceId: currentLastId,
            tag: nil,
            onlyMedia: false,
            excludeReplies: true,
            excludeReblogs: false,
            pinned: nil
          )
        )
        
        allFetched.append(contentsOf: fetchedStatuses)
        currentLastId = fetchedStatuses.last?.id ?? currentLastId
        let newBoosts = fetchedStatuses.filter { $0.reblog != nil }
        currentBoosts.append(contentsOf: newBoosts)
        hasMore = fetchedStatuses.count >= 20
      }

      lastFetchedId = currentLastId
      boosts = currentBoosts
      StatusDataControllerProvider.shared.updateDataControllers(for: allFetched, client: client)
      updateStatusesState(with: boosts, hasMore: hasMore)
    } catch {
      statusesState = .error(error: .noData)
    }
  }

  override func fetchNextPage() async throws {
    guard let lastId = lastFetchedId else { return }

    var allNew: [Status] = []
    var newBoosts: [Status] = []
    var currentLastId: String? = lastId
    var hasMore = true
    var fetchCount = 0
    
    while newBoosts.isEmpty && hasMore && fetchCount < 5 {
      fetchCount += 1
      let newStatuses: [Status] = try await client.get(
        endpoint: Accounts.statuses(
          id: accountId,
          sinceId: currentLastId,
          tag: nil,
          onlyMedia: false,
          excludeReplies: true,
          excludeReblogs: false,
          pinned: nil
        )
      )

      allNew.append(contentsOf: newStatuses)
      currentLastId = newStatuses.last?.id ?? currentLastId
      newBoosts.append(contentsOf: newStatuses.filter { $0.reblog != nil })
      hasMore = newStatuses.count >= 20
    }

    lastFetchedId = currentLastId
    boosts.append(contentsOf: newBoosts)

    StatusDataControllerProvider.shared.updateDataControllers(for: allNew, client: client)
    updateStatusesState(with: boosts, hasMore: hasMore)
  }
}
