import AppAccount
import DesignSystem
import Env
import Explore
import Models
import NetworkClient
import SwiftUI
import SwiftData

@MainActor
struct ExploreTab: View {
  @Environment(Theme.self) private var theme
  @Environment(UserPreferences.self) private var preferences
  @Environment(CurrentAccount.self) private var currentAccount
  @Environment(MastodonClient.self) private var client
  @State private var routerPath = RouterPath()
  
  @Query(sort: \LocalTimeline.creationDate, order: .reverse) var localTimelines: [LocalTimeline]

  var body: some View {
    NavigationStack(path: $routerPath.path) {
      ExploreView()
        .withAppRouter()
        .withSheetDestinations(
          sheetDestinations: $routerPath.presentedSheet,
          routerPath: routerPath
        )
        .toolbar {
          ToolbarTab(routerPath: $routerPath)
          
          // Added Local Timelines menu next to the compose button
          ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
              ForEach(localTimelines) { remoteLocal in
                Button {
                  routerPath.navigate(to: .remoteLocalTimeline(server: remoteLocal.instance))
                } label: {
                  VStack {
                    Label(remoteLocal.instance, systemImage: "dot.radiowaves.right")
                  }
                }
              }
              Button {
                routerPath.presentedSheet = .addRemoteLocalTimeline
              } label: {
                Label("timeline.filter.add-local", systemImage: "badge.plus.radiowaves.right")
              }
            } label: {
              Image(systemName: "dot.radiowaves.right")
            }
            .tint(.label)
          }
        }
    }
    .withSafariRouter()
    .environment(routerPath)
    .onChange(of: client.id) {
      routerPath.path = []
    }
    .onAppear {
      routerPath.client = client
    }
  }
}
