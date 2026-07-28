import Combine
import Env
import Models
import NetworkClient
import Observation
import SwiftUI

@MainActor
@Observable public class AppAccountsManager {
  @AppStorage("latestCurrentAccountKey", store: UserPreferences.sharedDefault)
  public static var latestCurrentAccountKey: String = ""

  public var currentAccount: AppAccount {
    didSet {
      Self.latestCurrentAccountKey = currentAccount.id
      currentClient = .init(
        server: currentAccount.server,
        oauthToken: currentAccount.oauthToken)
        
      if let isShrimp = currentAccount.isIceShrimp {
        UserPreferences.shared.useIceShrimpWorkarounds = isShrimp
        currentClient.isIceShrimpWorkaroundsEnabled = isShrimp
      }
    }
  }

  public var availableAccounts: [AppAccount]
  public var currentClient: MastodonClient

  public var pushAccounts: [PushAccount] {
    availableAccounts.filter { $0.oauthToken != nil }
      .map { .init(server: $0.server, token: $0.oauthToken!, accountName: $0.accountName) }
  }

  public static var shared = AppAccountsManager()

  init() {
    var defaultAccount = AppAccount(
      server: AppInfo.defaultServer, accountName: nil, oauthToken: nil)
    let keychainAccounts = AppAccount.retrieveAll()
    availableAccounts = keychainAccounts
    if let currentAccount = keychainAccounts.first(where: { $0.id == Self.latestCurrentAccountKey })
    {
      defaultAccount = currentAccount
    } else {
      defaultAccount = keychainAccounts.last ?? defaultAccount
    }
    currentAccount = defaultAccount
    currentClient = .init(server: defaultAccount.server, oauthToken: defaultAccount.oauthToken)
  }

  public func add(account: AppAccount) {
    do {
      try account.save()
      availableAccounts.append(account)
      currentAccount = account
    } catch {}
  }

  public func updateIceShrimpStatus(for account: AppAccount) async {
    if let isShrimp = account.isIceShrimp {
      if currentAccount.id == account.id {
        UserPreferences.shared.useIceShrimpWorkarounds = isShrimp
      }
      return
    }
    
    var isShrimp = false
    do {
      let client = MastodonClient(server: account.server, oauthToken: account.oauthToken)
      if let instance: Models.Instance = try? await client.get(endpoint: Instances.instance, forceVersion: .v2) {
         if instance.version.lowercased().contains("iceshrimp") {
           isShrimp = true
         }
      }
      
      if !isShrimp, let url = URL(string: "https://\(account.server)/nodeinfo/2.0") {
        let (data, _) = try await URLSession.shared.data(from: url)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let software = json["software"] as? [String: Any],
           let name = software["name"] as? String {
           if name.lowercased().contains("iceshrimp") {
             isShrimp = true
           }
        }
      }
    } catch { 
       return // Don't save false if we just failed to fetch due to network
    }
    
    if let index = availableAccounts.firstIndex(where: { $0.id == account.id }) {
      var updatedAccount = availableAccounts[index]
      updatedAccount.isIceShrimp = isShrimp
      try? updatedAccount.save()
      availableAccounts[index] = updatedAccount
      if currentAccount.id == updatedAccount.id {
        currentAccount = updatedAccount
      }
    }
  }

  public func delete(account: AppAccount) {
    availableAccounts.removeAll(where: { $0.id == account.id })
    account.delete()
    if currentAccount.id == account.id {
      currentAccount =
        availableAccounts.first
        ?? AppAccount(
          server: AppInfo.defaultServer,
          accountName: nil,
          oauthToken: nil)
    }
  }
}
