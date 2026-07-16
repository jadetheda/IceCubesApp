import Env
import Models
import NetworkClient
import Observation
import SwiftUI

// Global cache to avoid heavy repetitive API requests for IceShrimp instances.
// The API endpoint for getting lists an account belongs to is broken in some cases.
@MainActor
struct IceShrimpListCache {
  static var lastFetch: Date?
  static var accountLists: [String: [Models.List]] = [:]
}

@MainActor
@Observable class ListAddAccountViewModel {
  let account: Account

  var inLists: [Models.List] = []
  var isLoadingInfo: Bool = true

  var client: MastodonClient?

  init(account: Account) {
    self.account = account
  }

  func fetchInfo() async {
    guard let client else { return }
    isLoadingInfo = true
    do {
      inLists = try await client.get(endpoint: Accounts.lists(id: account.id))
      isLoadingInfo = false
    } catch {
      guard UserPreferences.shared.useIceShrimpWorkarounds else {
        withAnimation { isLoadingInfo = false }
        return
      }
      
      let accountId = account.id
      // Use cached list data if it was fetched within the last 10 minutes (600 seconds)
      if let last = IceShrimpListCache.lastFetch, Date().timeIntervalSince(last) < 600 {
        self.inLists = IceShrimpListCache.accountLists[accountId] ?? []
      } else if let allLists: [Models.List] = try? await client.get(endpoint: Lists.lists) {
        var newAccountLists: [String: [Models.List]] = [:]
        await withTaskGroup(of: (Models.List, [Account]?).self) { group in
          for list in allLists {
            group.addTask {
              let accounts: [Account]? = try? await client.get(endpoint: Lists.accounts(listId: list.id))
              return (list, accounts)
            }
          }
          for await (list, accounts) in group {
            if let accounts = accounts {
              for acc in accounts {
                newAccountLists[acc.id, default: []].append(list)
              }
            }
          }
        }
        IceShrimpListCache.accountLists = newAccountLists
        IceShrimpListCache.lastFetch = Date()
        self.inLists = newAccountLists[accountId] ?? []
      }
      withAnimation {
        isLoadingInfo = false
      }
    }
  }

  func addToList(list: Models.List) async {
    guard let client else { return }
    let response = try? await client.post(
      endpoint: Lists.updateAccounts(listId: list.id, accounts: [account.id]))
    if response?.statusCode == 200 {
      inLists.append(list)
      IceShrimpListCache.accountLists[account.id, default: []].append(list)
    }
  }

  func removeFromList(list: Models.List) async {
    guard let client else { return }
    let response = try? await client.delete(
      endpoint: Lists.updateAccounts(listId: list.id, accounts: [account.id]))
    if response?.statusCode == 200 {
      inLists.removeAll(where: { $0.id == list.id })
      IceShrimpListCache.accountLists[account.id]?.removeAll(where: { $0.id == list.id })
    }
  }
}
