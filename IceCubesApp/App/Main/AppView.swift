import AVFoundation
import Account
import AppAccount
import DesignSystem
import Env
import KeychainSwift
import MediaUI
import Models
import NetworkClient
import RevenueCat
import StatusKit
import SwiftData
import SwiftUI
import Timeline

@MainActor
struct AppView: View {
  @Environment(\.modelContext) private var context
  @Environment(\.openWindow) var openWindow
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  @Environment(AppAccountsManager.self) private var appAccountsManager
  @Environment(UserPreferences.self) private var userPreferences
  @Environment(Theme.self) private var theme
  @Environment(CurrentAccount.self) private var currentAccount

  @Binding var selectedTab: AppTab
  @Binding var appRouterPath: RouterPath

  @State private var iosTabs = iOSTabs.shared
  @State private var errorService = ErrorService.shared
  @State var selectedTabScrollToTop: Int = -1
  @State var timeline: TimelineFilter = .home

  @AppStorage("timeline_pinned_filters") private var pinnedFilters: [TimelineFilter] = []

  @Query(sort: \LocalTimeline.creationDate, order: .reverse) var localTimelines: [LocalTimeline]
  @Query(sort: \TagGroup.creationDate, order: .reverse) var tagGroups: [TagGroup]

  private func availableTabs(for tabs: [AppTab]) -> [AppTab] {
    tabs.filter { tab in
      if tab == .links { return appAccountsManager.currentClient.capabilities.supportsTrendingLinks }
      if tab == .metrics { return appAccountsManager.currentClient.capabilities.supportsAccountMetrics }
      if tab == .followedTags { return appAccountsManager.currentClient.capabilities.supportsFollowedTags }
      if tab == .lists { return !appAccountsManager.currentClient.isPixelfed }
      return true
    }
  }

  private var showSecondaryColumn: Bool {
    let isRegular = horizontalSizeClass == .regular
    let isPadOrMac = UIDevice.current.userInterfaceIdiom == .pad || UIDevice.current.userInterfaceIdiom == .mac
    return isRegular && isPadOrMac && appAccountsManager.currentClient.isAuth && userPreferences.showiPadSecondaryColumn
  }
  var body: some View {
    HStack(spacing: 0) {
      tabBarView
        .tabViewStyle(.sidebarAdaptable)
      if showSecondaryColumn {
        Divider().edgesIgnoringSafeArea(.all)
        notificationsSecondaryColumn
      }
    }
  }

  var availableSections: [SidebarSections] {
    guard appAccountsManager.currentClient.isAuth else {
      return [SidebarSections.loggedOutTabs]
    }
    if horizontalSizeClass == .compact {
      return [SidebarSections.iosTabs]
    } else if UIDevice.current.userInterfaceIdiom == .vision {
      return [SidebarSections.visionOSTabs]
    }
    var sections = SidebarSections.macOrIpadOSSections
    if !localTimelines.isEmpty {
      sections.append(.localTimeline)
    }
    if !tagGroups.isEmpty {
      sections.append(.tagGroup)
    }
    sections.append(.app)
    return sections
  }

  private var localTimelineTabs: [AppTab] {
    localTimelines.map { timeline in
      AppTab.anyTimelineFilter(filter: .remoteLocal(server: timeline.instance, filter: .local))
    }
  }

  private var tagGroupTabs: [AppTab] {
    tagGroups.map { tagGroup in
      AppTab.anyTimelineFilter(
        filter: TimelineFilter.tagGroup(
          title: tagGroup.title,
          tags: tagGroup.tags,
          symbolName: tagGroup.symbolName))
    }
  }

  private var activeIosTabs: [AppTab] {
    availableTabs(for: iosTabs.tabs)
  }

  private func tabRole(for tab: AppTab, in tabs: [AppTab]) -> TabRole? {
    if tab == .explore {
      if tabs.last == .explore {
        return .search
      }
    }
    return .none
  }

  @ViewBuilder
  var tabBarView: some View {
    TabView(
      selection: .init(
        get: {
          selectedTab
        },
        set: { newTab in
          updateTab(with: newTab)
        })
    ) {
      ForEach(availableSections) { section in
        if section == .iosTabs {
          // Detach Search as a floating action button only if the user placed it last in their tabs.
          // Otherwise, preserve the exact user-configured order without allowing iOS to hijack it to the end.
          ForEach(activeIosTabs) { tab in
            Tab(value: tab, role: tabRole(for: tab, in: activeIosTabs)) {
              makeTabContent(for: tab)
            } label: {
              tab.label.environment(\.symbolVariants, tab == selectedTab ? .fill : .none)
            }
            .badge(badgeFor(tab: tab))
          }
        } else {
          TabSection(section.title) {
            if section == .localTimeline {
              ForEach(localTimelineTabs) { tab in
                Tab(value: tab) {
                  makeTabContent(for: tab)
                } label: {
                  tab.label.environment(\.symbolVariants, tab == selectedTab ? .fill : .none)
                }
                .tabPlacement(tab.tabPlacement)
              }
            } else if section == .tagGroup {
              ForEach(tagGroupTabs) { tab in
                Tab(value: tab) {
                  makeTabContent(for: tab)
                } label: {
                  tab.label.environment(\.symbolVariants, tab == selectedTab ? .fill : .none)
                }
                .tabPlacement(tab.tabPlacement)
              }
            } else {
              ForEach(availableTabs(for: section.tabs)) { tab in
                Tab(value: tab, role: tab == .explore ? .search : .none) {
                  makeTabContent(for: tab)
                } label: {
                  tab.label.environment(\.symbolVariants, tab == selectedTab ? .fill : .none)
                }
                .tabPlacement(tab.tabPlacement)
                .badge(badgeFor(tab: tab))
              }
            }
          }
          .tabPlacement(.sidebarOnly)
        }
      }
    }
    .id(appAccountsManager.currentClient.id)
    .withSheetDestinations(
      sheetDestinations: $appRouterPath.presentedSheet,
      routerPath: appRouterPath
    )
    .environment(\.selectedTabScrollToTop, selectedTabScrollToTop)

    .alert(errorService.currentErrorTitle, isPresented: Bindable(errorService).isErrorDisplayed) {
      Button("alert.button.ok", action: {})
    } message: {
      Text(errorService.currentErrorMessage)
    }
    .onChange(of: errorService.isErrorDisplayed) { _, _ in }

    .onAppear {
      syncTagGroups()
    }
  }

  private func syncTagGroups() {
    for filter in pinnedFilters {
      if case let .tagGroup(title, tags, symbolName) = filter {
        if !tagGroups.contains(where: { $0.title == title }) {
          let newGroup = TagGroup(title: title, symbolName: symbolName ?? "number", tags: tags)
          context.insert(newGroup)
        }
      }
    }
  }

  @ViewBuilder
  private func makeTabContent(for tab: AppTab) -> some View {
    tab.makeContentView(
      homeTimeline: $timeline,
      selectedTab: $selectedTab,
      pinnedFilters: $pinnedFilters
    )
    .overlay(alignment: .top) {
      ToastOverlayView()
    }
    .environment(\.currentTabId, tab.id)
    .environment(\.isTabSelected, tab == selectedTab)
  }

  private func updateTab(with newTab: AppTab) {
    if newTab == .post {
      #if os(visionOS)
        openWindow(
          value: WindowDestinationEditor.newStatusEditor(visibility: userPreferences.postVisibility)
        )
      #else
        appRouterPath.presentedSheet = .newStatusEditor(visibility: userPreferences.postVisibility)
      #endif
      return
    }

    HapticManager.shared.fireHaptic(.tabSelection)
    SoundEffectManager.shared.playSound(.tabSelection)

    if selectedTab == newTab {
      selectedTabScrollToTop = newTab.id
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        selectedTabScrollToTop = -1
      }
    } else {
      selectedTabScrollToTop = -1
    }

    selectedTab = newTab
  }

  private func badgeFor(tab: AppTab) -> Int {
    if tab == .notifications && selectedTab != tab {
      if let token = appAccountsManager.currentAccount.oauthToken {
        return userPreferences.notificationsCount[token] ?? 0
      }
    }
    return 0
  }

  var notificationsSecondaryColumn: some View {
    NotificationsTab(selectedTab: .constant(.notifications), lockedType: nil)
      .environment(\.isSecondaryColumn, true)
      .environment(\.currentTabId, AppTab.notifications.id)
      .frame(maxWidth: .secondaryColumnWidth)
      .id(appAccountsManager.currentAccount.id)
  }
}
