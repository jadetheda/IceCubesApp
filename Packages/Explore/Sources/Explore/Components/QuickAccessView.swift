import DesignSystem
import Env
import Models
import NetworkClient
import SwiftUI

struct QuickAccessView: View {
  @Environment(Theme.self) private var theme
  @Environment(RouterPath.self) private var routerPath
  @Environment(FediverseClient.self) private var client

  let trendingLinks: [Card]
  let suggestedAccounts: [Account]
  let trendingTags: [Tag]

  var body: some View {
    ScrollView(.horizontal) {
      HStack {
        if client.capabilities.supportsTrendingLinks {
          Button("explore.section.trending.links") {
            routerPath.navigate(to: RouterDestination.trendingLinks(cards: trendingLinks))
          }
          .buttonStyle(.bordered)
        }
        Button("explore.section.trending.posts") {
          routerPath.navigate(to: RouterDestination.trendingTimeline)
        }
        .buttonStyle(.bordered)
        Button("explore.section.suggested-users") {
          routerPath.navigate(
            to: RouterDestination.accountsList(accounts: suggestedAccounts))
        }
        .buttonStyle(.bordered)
        Button("explore.section.trending.tags") {
          routerPath.navigate(to: RouterDestination.tagsList(tags: trendingTags))
        }
        .buttonStyle(.bordered)
      }
      .padding(16)
    }
    .scrollIndicators(.never)
    .listRowInsets(EdgeInsets())
    #if !os(visionOS)
      .listRowBackground(theme.secondaryBackgroundColor)
    #endif
    .listRowSeparator(.hidden)
  }
}
