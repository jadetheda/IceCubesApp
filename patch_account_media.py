import re

with open('Packages/Account/Sources/Account/Detail/MediaGrid/AccountDetailMediaGridView.swift', 'r') as f:
    amg = f.read()

# We will add AccountDetailMediaGridFetcher class at the bottom
fetcher_class = """
@MainActor
@Observable
class AccountDetailMediaGridFetcher: StatusesFetcher {
  var statusesState: StatusesState
  var mediaStatuses: [MediaStatus] = []
  var client: MastodonClient
  let account: Account

  init(account: Account, client: MastodonClient, initialStatusesState: StatusesState, initialMediaStatuses: [MediaStatus]) {
    self.account = account
    self.client = client
    self.statusesState = initialStatusesState
    self.mediaStatuses = initialMediaStatuses
  }

  func fetchNewestStatuses(pullToRefresh: Bool) async {
    do {
      statusesState = .loading
      let newStatuses: [Status] = try await client.get(
        endpoint: Accounts.statuses(
          id: account.id,
          sinceId: nil,
          tag: nil,
          onlyMedia: true,
          excludeReplies: true,
          excludeReblogs: true,
          pinned: nil
        )
      )
      mediaStatuses = newStatuses.flatMap { $0.asMediaStatus }
      StatusDataControllerProvider.shared.updateDataControllers(for: newStatuses, client: client)
      statusesState = .display(statuses: newStatuses, nextPageState: newStatuses.isEmpty ? .none : .hasNextPage)
    } catch {
      statusesState = .error(error: .noData)
    }
  }

  func fetchNextPage() async throws {
    let newStatuses: [Status] = try await client.get(
      endpoint: Accounts.statuses(
        id: account.id,
        sinceId: mediaStatuses.last?.id,
        tag: nil,
        onlyMedia: true,
        excludeReplies: true,
        excludeReblogs: true,
        pinned: nil
      )
    )
    mediaStatuses.append(contentsOf: newStatuses.flatMap { $0.asMediaStatus })
    let allStatuses = mediaStatuses.map { $0.status }
    StatusDataControllerProvider.shared.updateDataControllers(for: newStatuses, client: client)
    statusesState = .display(statuses: allStatuses, nextPageState: newStatuses.isEmpty ? .none : .hasNextPage)
  }

  func statusDidAppear(status: Status) {}
  func statusDidDisappear(status: Status) {}
}
"""

if "class AccountDetailMediaGridFetcher" not in amg:
    amg += fetcher_class

# Now inside AccountDetailMediaGridView, we need to replace the state variables and init
# Currently:
#   @State var mediaStatuses: [MediaStatus]
#   @State private var statusesState: StatusesState
# We will replace them with `@State private var fetcher: AccountDetailMediaGridFetcher?`
# But wait! We need `client` in `init`? No, client is an Environment variable, so we can't initialize `fetcher` in `init`.
# We can do it in `.onAppear` just like we did for AccountStatusesListView?

# Actually, the easiest way is:
# let's just use `fetcher` in `body`. 

