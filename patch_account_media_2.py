import re

with open('Packages/Account/Sources/Account/Detail/MediaGrid/AccountDetailMediaGridView.swift', 'r') as f:
    amg = f.read()

fetcher_class = """
@MainActor
@Observable
class AccountDetailMediaGridFetcher: StatusesFetcher {
  var statusesState: StatusesState = .loading
  var mediaStatuses: [MediaStatus] = []
  var client: MastodonClient?
  let account: Account

  init(account: Account) {
    self.account = account
  }

  func fetchNewestStatuses(pullToRefresh: Bool) async {
    guard let client = client else { return }
    do {
      if pullToRefresh { statusesState = .loading }
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
    guard let client = client else { return }
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

# Now we need to replace the AccountDetailMediaGridView to use StatusesListView
# We will use Regex or manual replacement for the struct

start_struct = amg.find('public struct AccountDetailMediaGridView: View {')
end_struct = amg.find('class AccountDetailMediaGridFetcher')
if end_struct == -1: end_struct = len(amg)

new_struct = """public struct AccountDetailMediaGridView: View {
  @Environment(Theme.self) private var theme
  @Environment(RouterPath.self) private var routerPath
  @Environment(MastodonClient.self) private var client
  
  let account: Account
  @State private var fetcher: AccountDetailMediaGridFetcher
  @State private var isLoaded = false
  
  private var isRemote: Bool {
    guard let host = account.url?.host else { return false }
    return host.lowercased() != client.server.lowercased()
  }
  
  public init(account: Account, initialMediaStatuses: [MediaStatus]) {
    self.account = account
    let f = AccountDetailMediaGridFetcher(account: account)
    let initialStatuses = initialMediaStatuses.map { $0.status }
    if !initialStatuses.isEmpty {
      f.statusesState = .display(statuses: initialStatuses, nextPageState: initialStatuses.count >= 20 ? .hasNextPage : .none)
      f.mediaStatuses = initialMediaStatuses
    }
    _fetcher = .init(initialValue: f)
  }
  
  public var body: some View {
    List {
      StatusesListView(
        fetcher: fetcher,
        client: client,
        routerPath: routerPath,
        isRemote: isRemote,
        isForceGalleryMode: true
      )
      .listRowInsets(EdgeInsets())
      .listRowBackground(theme.primaryBackgroundColor)
    }
    .listStyle(.plain)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .principal) {
        EmojiTextApp(.init(stringValue: account.safeDisplayName), emojis: account.emojis)
          .font(.headline)
      }
    }
    .onAppear {
      if !isLoaded {
        fetcher.client = client
        if fetcher.mediaStatuses.isEmpty {
          Task { await fetcher.fetchNewestStatuses(pullToRefresh: false) }
        }
        isLoaded = true
      }
    }
    #if !os(visionOS)
      .background(theme.primaryBackgroundColor.ignoresSafeArea())
    #endif
    .refreshable {
      await fetcher.fetchNewestStatuses(pullToRefresh: true)
    }
  }
}
"""

new_amg = amg[:start_struct] + new_struct + amg[end_struct:]
with open('Packages/Account/Sources/Account/Detail/MediaGrid/AccountDetailMediaGridView.swift', 'w') as f:
    f.write(new_amg)

