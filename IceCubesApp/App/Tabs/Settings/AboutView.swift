import Account
import DesignSystem
import Env
import Models
import NetworkClient
import SwiftUI

@MainActor
struct AboutView: View {
  @Environment(RouterPath.self) private var routerPath
  @Environment(Theme.self) private var theme
  @Environment(MastodonClient.self) private var client

  @State private var dimillianAccount: AccountsListRowViewModel?
  @State private var iceCubesAccount: AccountsListRowViewModel?

  let versionNumber: String

  init() {
    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
      versionNumber = version + " "
    } else {
      versionNumber = ""
    }
  }

  var body: some View {
    List {
      Section {
        #if !targetEnvironment(macCatalyst) && !os(visionOS)
          HStack {
            Spacer()
            Image(uiImage: .init(named: "AppIconAlternate0-image") ?? .init())
              .resizable()
              .frame(width: 50, height: 50)
              .cornerRadius(4)
            Image(uiImage: .init(named: "AppIconAlternate1-image") ?? .init())
              .resizable()
              .frame(width: 50, height: 50)
              .cornerRadius(4)
            Image(uiImage: .init(named: "AppIconAlternate2-image") ?? .init())
              .resizable()
              .frame(width: 50, height: 50)
              .cornerRadius(4)
            Image(uiImage: .init(named: "AppIconAlternate3-image") ?? .init())
              .resizable()
              .frame(width: 50, height: 50)
              .cornerRadius(4)
            Spacer()
          }
        #endif
        Link(
          destination: URL(string: "https://github.com/Dimillian/IceCubesApp/blob/main/PRIVACY.MD")!
        ) {
          Label("settings.support.privacy-policy", systemImage: "lock")
        }

        Link(
          destination: URL(string: "https://github.com/Dimillian/IceCubesApp/blob/main/TERMS.MD")!
        ) {
          Label("settings.support.terms-of-use", systemImage: "checkmark.shield")
        }
      } footer: {
        Text("\(versionNumber)© 2026 Thomas Ricouard")
      }
      #if !os(visionOS)
        .listRowBackground(theme.primaryBackgroundColor)
      #endif

      followAccountsSection

      Section("Telemetry") {
        Link(destination: .init(string: "https://telemetrydeck.com")!) {
          Label("Telemetry by TelemetryDeck", systemImage: "link")
        }
        Link(destination: .init(string: "https://telemetrydeck.com/privacy/")!) {
          Label("Privacy Policy", systemImage: "checkmark.shield")
        }
      }
      #if !os(visionOS)
        .listRowBackground(theme.primaryBackgroundColor)
      #endif

      Section {
        Link("Nuke", destination: URL(string: "https://github.com/kean/Nuke")!)
        Link("EmojiText", destination: URL(string: "https://github.com/divadretlaw/EmojiText")!)
        Link("SwiftUI-Introspect", destination: URL(string: "https://github.com/siteline/SwiftUI-Introspect")!)
        Link("SFSafeSymbols", destination: URL(string: "https://github.com/SFSafeSymbols/SFSafeSymbols")!)
        Link("Bodega", destination: URL(string: "https://github.com/mergesort/Bodega")!)
        Link("KeychainSwift", destination: URL(string: "https://github.com/evgenyneu/keychain-swift")!)
        Link("HTML2Markdown", destination: URL(string: "https://gitlab.com/mflint/HTML2Markdown")!)
        Link("SwiftSoup", destination: URL(string: "https://github.com/scinfu/SwiftSoup.git")!)
        Link("LRUCache", destination: URL(string: "https://github.com/nicklockwood/LRUCache")!)
        Link("ButtonKit", destination: URL(string: "https://github.com/Dean151/ButtonKit")!)
        Link("WrappingHStack", destination: URL(string: "https://github.com/dkk/WrappingHStack")!)
        Link("Gifu", destination: URL(string: "https://github.com/kaishin/Gifu")!)
        Link("Atkinson Hyperlegible", destination: URL(string: "https://github.com/googlefonts/atkinson-hyperlegible")!)
        Link("OpenDyslexic", destination: URL(string: "http://opendyslexic.org")!)
        Link("RevenueCat", destination: URL(string: "https://github.com/RevenueCat/purchases-ios")!)
        Link("TelemetryDeck", destination: URL(string: "https://github.com/TelemetryDeck/SwiftSDK")!)
        Link("WishKit", destination: URL(string: "https://github.com/wishkit/wishkit-ios")!)
      } header: {
        Text("settings.about.built-with")
          .textCase(nil)
      }
      #if !os(visionOS)
        .listRowBackground(theme.primaryBackgroundColor)
      #endif
    }
    .task {
      await fetchAccounts()
    }
    .listStyle(.insetGrouped)
    #if !os(visionOS)
      .scrollContentBackground(.hidden)
      .background(theme.secondaryBackgroundColor)
    #endif
    .navigationTitle(Text("settings.about.title"))
    .navigationBarTitleDisplayMode(.large)
    .environment(
      \.openURL,
      OpenURLAction { url in
        routerPath.handle(url: url)
      })
  }

  @ViewBuilder
  private var followAccountsSection: some View {
    if let iceCubesAccount, let dimillianAccount {
      Section {
        AccountsListRow(viewModel: iceCubesAccount)
        AccountsListRow(viewModel: dimillianAccount)
      }
      #if !os(visionOS)
        .listRowBackground(theme.primaryBackgroundColor)
      #endif
    } else {
      Section {
        ProgressView()
      }
      #if !os(visionOS)
        .listRowBackground(theme.primaryBackgroundColor)
      #endif
    }
  }

  private func fetchAccounts() async {
    await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        let viewModel = try await fetchAccountViewModel(
          client, account: "dimillian@mastodon.social")
        await MainActor.run {
          dimillianAccount = viewModel
        }
      }
      group.addTask {
        let viewModel = try await fetchAccountViewModel(
          client, account: "icecubesapp@mastodon.online")
        await MainActor.run {
          iceCubesAccount = viewModel
        }
      }
    }
  }

  private func fetchAccountViewModel(_ client: MastodonClient, account: String) async throws
    -> AccountsListRowViewModel
  {
    let dimillianAccount: Account = try await client.get(endpoint: Accounts.lookup(name: account))
    let rel: [Relationship] = try await client.get(
      endpoint: Accounts.relationships(ids: [dimillianAccount.id]))
    return .init(account: dimillianAccount, relationShip: rel.first)
  }
}

struct AboutView_Previews: PreviewProvider {
  static var previews: some View {
    AboutView()
      .environment(Theme.shared)
  }
}
