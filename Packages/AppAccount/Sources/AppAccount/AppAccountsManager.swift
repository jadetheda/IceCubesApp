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
      let software = currentAccount.serverSoftware ?? (currentAccount.isIceShrimp == true ? "iceshrimp" : "mastodon")
      currentClient = .init(
        server: currentAccount.server,
        oauthToken: currentAccount.oauthToken,
        serverSoftware: software)
        
    }
  }

  public var availableAccounts: [AppAccount]
  public var currentClient: FediverseClient

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
    let software = defaultAccount.serverSoftware ?? (defaultAccount.isIceShrimp == true ? "iceshrimp" : "mastodon")
    currentClient = .init(
        server: defaultAccount.server,
        oauthToken: defaultAccount.oauthToken,
        serverSoftware: software
    )
    currentAccount = defaultAccount
  }

  public func add(account: AppAccount) {
    do {
      try account.save()
      availableAccounts.append(account)
      currentAccount = account
    } catch {}
  }

  public func updateServerSoftware(for account: AppAccount) async {
    if account.serverSoftware != nil {
      return
    }
    
    var softwareName = "mastodon"
    var isShrimp = account.isIceShrimp == true
    
    do {
         let client = FediverseClient(server: account.server, oauthToken: account.oauthToken)
         if let instance: Models.Instance = try? await client.get(endpoint: Instances.instance, forceVersion: .v2) {
            let version = instance.version.lowercased()
            if version.contains("iceshrimp") {
              softwareName = "iceshrimp"
              isShrimp = true
            } else if version.contains("misskey") {
              softwareName = "misskey"
            } else if version.contains("peertube") {
              softwareName = "peertube"
            }
         }
         
         if softwareName == "mastodon", let url = URL(string: "https://\(account.server)/nodeinfo/2.0") {
           let (data, _) = try await URLSession.shared.data(from: url)
           if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let software = json["software"] as? [String: Any],
              let name = software["name"] as? String {
              softwareName = name.lowercased()
              if softwareName.contains("iceshrimp") {
                 isShrimp = true
              }
           }
         }
    } catch {
        return // Don't save if we just failed to fetch due to network
    }
    
    if let index = availableAccounts.firstIndex(where: { $0.id == account.id }) {
      var updatedAccount = availableAccounts[index]
      updatedAccount.serverSoftware = softwareName
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
  }
}
