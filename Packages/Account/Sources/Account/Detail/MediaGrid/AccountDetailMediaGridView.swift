import DesignSystem
import EmojiText
import Env
import Foundation
import MediaUI
import Models
import NetworkClient
import NukeUI
import Observation
import StatusKit
import SwiftUI

/// `AccountMediaFetcher` provides a unified `StatusesFetcher` conforming interface for the
/// Profile Media Gallery. This eliminates the fragmentation of having a custom grid layout
/// just for profiles, allowing us to leverage `GalleryStatusesListView` natively.
@MainActor
@Observable
public class AccountMediaFetcher: StatusesFetcher {
  public let accountId: String
  public var client: FediverseClient?

  public var statusesState: StatusesState = .loading
  public var statuses: [Status] = []
  private var isFetchingNextPage = false

  public init(accountId: String, client: FediverseClient? = nil, initialStatuses: [Status] = []) {
    self.accountId = accountId
    self.client = client
    let uniqueStatuses = Self.deduplicateStatuses(initialStatuses)
    if !uniqueStatuses.isEmpty {
      self.statuses = uniqueStatuses
      self.statusesState = .display(
        statuses: uniqueStatuses,
        nextPageState: .hasNextPage
      )
    }
  }

  /// Deduplicates statuses by `id` while preserving chronological order.
  /// Fixes the multi-attachment status duplication bug where `initialMediaStatuses.map { $0.status }`
  /// produced N copies of the same `Status` for a post with N media attachments.
  public static func deduplicateStatuses(_ input: [Status]) -> [Status] {
    var seenIds = Set<String>()
    var unique: [Status] = []
    unique.reserveCapacity(input.count)
    for status in input {
      if seenIds.insert(status.id).inserted {
        unique.append(status)
      }
    }
    return unique
  }

  public func fetchNewestStatuses(pullToRefresh: Bool) async {
    guard let client else { return }
    do {
      statusesState = .loading
      let fetchedStatuses: [Status] = try await client.get(
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

      let uniqueStatuses = Self.deduplicateStatuses(fetchedStatuses)
      statuses = uniqueStatuses
      StatusDataControllerProvider.shared.updateDataControllers(for: uniqueStatuses, client: client)
      statusesState = .display(
        statuses: uniqueStatuses,
        nextPageState: uniqueStatuses.isEmpty ? .none : .hasNextPage
      )
    } catch {
      statusesState = .error(error: .noData)
    }
  }

  public func fetchNextPage() async throws {
    guard let client else { return }
    guard !isFetchingNextPage else { return }
    guard let lastId = statuses.last?.id else { return }
    isFetchingNextPage = true
    defer { isFetchingNextPage = false }

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

    var existingIds = Set(statuses.map { $0.id })
    var uniqueNewStatuses: [Status] = []
    for status in newStatuses {
      if existingIds.insert(status.id).inserted {
        uniqueNewStatuses.append(status)
      }
    }

    statuses.append(contentsOf: uniqueNewStatuses)
    StatusDataControllerProvider.shared.updateDataControllers(for: uniqueNewStatuses, client: client)
    statusesState = .display(
      statuses: statuses,
      nextPageState: uniqueNewStatuses.isEmpty ? .none : .hasNextPage
    )
  }

  public func statusDidAppear(status: Status) {}
  public func statusDidDisappear(status: Status) {}
}

@MainActor
public struct AccountDetailMediaGridView: View {
  @Environment(Theme.self) private var theme
  @Environment(RouterPath.self) private var routerPath
  @Environment(FediverseClient.self) private var client

  let account: Account
  @State private var fetcher: AccountMediaFetcher

  private var isRemote: Bool {
    !client.isAuth
  }

  public init(account: Account, initialMediaStatuses: [MediaStatus]) {
    self.account = account
    let rawStatuses = initialMediaStatuses.map { $0.status }
    let uniqueStatuses = AccountMediaFetcher.deduplicateStatuses(rawStatuses)
    _fetcher = .init(
      initialValue: AccountMediaFetcher(
        accountId: account.id,
        initialStatuses: uniqueStatuses
      )
    )
  }

  public var body: some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        GalleryStatusesListView(
          fetcher: fetcher,
          client: client,
          routerPath: routerPath,
          isRemote: isRemote
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
      if fetcher.client == nil {
        fetcher.client = client
        if fetcher.statuses.isEmpty {
          Task {
            await fetcher.fetchNewestStatuses(pullToRefresh: false)
          }
        } else {
          StatusDataControllerProvider.shared.updateDataControllers(for: fetcher.statuses, client: client)
        }
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
