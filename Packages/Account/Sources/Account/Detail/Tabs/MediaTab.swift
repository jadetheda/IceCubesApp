import DesignSystem
import Env
import Foundation
import Models
import NetworkClient
import Observation
import StatusKit
import SwiftUI

struct MediaTab {
  let id = "media"
  let iconName = "photo.on.rectangle.angled"
  let accessibilityLabel: LocalizedStringKey = "accessibility.tabs.profile.picker.media"
  let isAvailableForCurrentUser = false
  let isAvailableForOtherUsers = true

  func createFetcher(accountId: String, client: FediverseClient, isCurrentUser: Bool) -> any StatusesFetcher
  {
    MediaTabFetcher(accountId: accountId, client: client, isCurrentUser: isCurrentUser)
  }

  func makeView(
    fetcher: any StatusesFetcher, client: FediverseClient, routerPath: RouterPath, account: Account?
  ) -> some View {
    MediaTabView(
      fetcher: fetcher as! MediaTabFetcher, client: client, routerPath: routerPath, account: account
    )
  }
}

extension MediaTab: @MainActor AccountTabProtocol {}

@MainActor
@Observable
private class MediaTabFetcher: AccountTabFetcher {
  var statusesMedias: [MediaStatus] {
    statuses.filter { !$0.mediaAttachments.isEmpty }.flatMap { $0.asMediaStatus }
  }

  override func fetchNewestStatuses(pullToRefresh: Bool) async {
    do {
      statusesState = .loading
      let fetched: [Status] = try await client.get(
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

      statuses = AccountMediaFetcher.deduplicateStatuses(fetched)
      StatusDataControllerProvider.shared.updateDataControllers(for: statuses, client: client)
      updateStatusesState(with: statuses, hasMore: !statuses.isEmpty)
    } catch {
      statusesState = .error(error: .noData)
    }
  }

  override func fetchNextPage() async throws {
    guard let lastId = statuses.last?.id else { return }

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
    updateStatusesState(with: statuses, hasMore: !uniqueNewStatuses.isEmpty)
  }
}

private struct MediaTabView: View {
  let fetcher: MediaTabFetcher
  let client: FediverseClient
  let routerPath: RouterPath
  let account: Account?

  @Environment(Theme.self) private var theme

  private var isRemoteAccount: Bool {
    account?.url?.host?.lowercased() != client.server.lowercased()
  }

  var body: some View {
    Group {
      Button {
        if let account {
          routerPath.navigate(
            to: .accountMediaGridView(
              account: account,
              initialMediaStatuses: fetcher.statusesMedias
            )
          )
        }
      } label: {
        HStack {
          Label("account.media.fullscreen", systemImage: "square.grid.2x2")
          Spacer()
          Image(systemName: "chevron.right")
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      #if !os(visionOS)
        .listRowBackground(theme.primaryBackgroundColor)
      #endif

      AnyStatusesListView(
        fetcher: fetcher,
        client: client,
        routerPath: routerPath,
        isRemote: isRemoteAccount,
        isMediaTab: true
      )
    }
  }
}
