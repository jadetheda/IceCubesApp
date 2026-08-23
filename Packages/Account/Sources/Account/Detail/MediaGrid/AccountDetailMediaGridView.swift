import DesignSystem
import EmojiText
import Env
import MediaUI
import Models
import NetworkClient
import NukeUI
import SwiftUI
import StatusKit
import Observation

@MainActor
public struct AccountDetailMediaGridView: View {
  @Environment(Theme.self) private var theme
  @Environment(RouterPath.self) private var routerPath
  @Environment(MastodonClient.self) private var client
  
  let account: Account
  @State var mediaStatuses: [MediaStatus]
  @State private var statusesState: StatusesState
  
  private var isRemote: Bool {
    guard let host = account.url?.host else { return false }
    return host.lowercased() != client.server.lowercased()
  }
  
  public init(account: Account, initialMediaStatuses: [MediaStatus]) {
    self.account = account
    mediaStatuses = initialMediaStatuses
    let initialStatuses = initialMediaStatuses.map { $0.status }
    if !initialStatuses.isEmpty {
      _statusesState = .init(initialValue: .display(statuses: initialStatuses, nextPageState: initialStatuses.count >= 20 ? .hasNextPage : .none))
    } else {
      _statusesState = .init(initialValue: .loading)
    }
  }
  
  public var body: some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        GalleryStatusesListView(
          statusesState: statusesState,
          client: client,
          isRemote: isRemote,
          fetchNextPage: fetchNextPage,
          fetchNewestStatuses: fetchNewestStatuses
        )
      }
      .padding(.top, .layoutPadding)
    }
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .principal) {
        EmojiTextApp(.init(stringValue: account.safeDisplayName), emojis: account.emojis)
          .font(.headline)
      }
    }
    .onAppear {
      if mediaStatuses.isEmpty {
        Task {
          await fetchNewestStatuses()
        }
      }
    }
    #if !os(visionOS)
      .background(theme.primaryBackgroundColor.ignoresSafeArea())
    #endif
    .refreshable {
      await fetchNewestStatuses()
    }
  }

  private func fetchNewestStatuses() async {
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
  
  private func fetchNextPage() async throws {
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
}
