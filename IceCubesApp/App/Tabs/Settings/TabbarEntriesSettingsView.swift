import DesignSystem
import Env
import AppAccount
import SwiftUI

@MainActor
struct TabbarEntriesSettingsView: View {
  @Environment(AppAccountsManager.self) private var appAccountsManager
  @Environment(Theme.self) private var theme
  @Environment(UserPreferences.self) private var userPreferences

  @State private var tabs = iOSTabs.shared

  private var availableTabs: [AppTab] {
    AppTab.allCases.filter { tab in
      if tab == .links { return appAccountsManager.currentClient.capabilities.supportsTrendingLinks }
      if tab == .metrics { return appAccountsManager.currentClient.capabilities.supportsAccountMetrics }
      if tab == .followedTags { return appAccountsManager.currentClient.capabilities.supportsFollowedTags }
      if tab == .lists { return !appAccountsManager.currentClient.isPixelfed }
      return true
    }
  }
  
  var body: some View {
    @Bindable var userPreferences = userPreferences
    Form {
      Section {
        Picker("settings.tabs.first-tab", selection: $tabs.firstTab) {
          ForEach(availableTabs) { tab in
            if tab == tabs.firstTab || !tabs.tabs.contains(tab) {
              tab.label.tag(tab)
            }
          }
        }
        Picker("settings.tabs.second-tab", selection: $tabs.secondTab) {
          ForEach(availableTabs) { tab in
            if tab == tabs.secondTab || !tabs.tabs.contains(tab) {
              tab.label.tag(tab)
            }
          }
        }
        Picker("settings.tabs.third-tab", selection: $tabs.thirdTab) {
          ForEach(availableTabs) { tab in
            if tab == tabs.thirdTab || !tabs.tabs.contains(tab) {
              tab.label.tag(tab)
            }
          }
        }
        Picker("settings.tabs.fourth-tab", selection: $tabs.fourthTab) {
          ForEach(availableTabs) { tab in
            if tab == tabs.fourthTab || !tabs.tabs.contains(tab) {
              tab.label.tag(tab)
            }
          }
        }
        Picker("settings.tabs.fifth-tab", selection: $tabs.fifthTab) {
          ForEach(availableTabs) { tab in
            if tab == tabs.fifthTab || !tabs.tabs.contains(tab) {
              tab.label.tag(tab)
            }
          }
        }
      }
      #if !os(visionOS)
        .listRowBackground(theme.primaryBackgroundColor)
      #endif
    }
    .navigationTitle("settings.general.tabbarEntries")
    #if !os(visionOS)
      .scrollContentBackground(.hidden)
      .background(theme.secondaryBackgroundColor)
    #endif
  }
}
