import Models
import NetworkClient
import Observation
import SwiftUI

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
      let accountId = account.id
      if let allLists: [Models.List] = try? await client.get(endpoint: Lists.lists) {
        var foundLists: [Models.List] = []
        await withTaskGroup(of: (Models.List, Bool).self) { group in
          for list in allLists {
            group.addTask {
              let accounts: [Account]? = try? await client.get(endpoint: Lists.accounts(listId: list.id))
              let contains = accounts?.contains(where: { $0.id == accountId }) ?? false
              return (list, contains)
            }
          }
          for await (list, contains) in group {
            if contains { foundLists.append(list) }
          }
        }
        self.inLists = foundLists
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
    }
  }

  func removeFromList(list: Models.List) async {
    guard let client else { return }
    let response = try? await client.delete(
      endpoint: Lists.updateAccounts(listId: list.id, accounts: [account.id]))
    if response?.statusCode == 200 {
      inLists.removeAll(where: { $0.id == list.id })
    }
  }
}
