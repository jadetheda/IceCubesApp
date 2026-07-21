import DesignSystem
import Env
import Models
import NetworkClient
import SwiftUI

@MainActor
public struct NotificationsListView: View {
  @Environment(\.scenePhase) private var scenePhase

  @Environment(Theme.self) private var theme
  @Environment(StreamWatcher.self) private var watcher
  @Environment(MastodonClient.self) private var client
  @Environment(RouterPath.self) private var routerPath
  @Environment(CurrentAccount.self) private var account
  @Environment(CurrentInstance.self) private var currentInstance

  @State private var dataSource = NotificationsListDataSource()
  @State private var viewState: NotificationsListState = .loading
  @State private var selectedType: Models.Notification.NotificationType?
  @State private var policy: Models.NotificationsPolicy?
  @State private var isNotificationsPolicyPresented: Bool = false
  @State private var isNotificationsContentFilterPresented: Bool = false
  @State private var filter = NotificationsContentFilter.shared
  
  @Environment(\.selectedTabScrollToTop) private var selectedTabScrollToTop
  @Environment(\.currentTabId) private var currentTabId
  @State private var scrollToTopVisible = false
  @State private var previousScrollPosition: String?
  @State private var undoTask: Task<Void, Never>?
  @State private var visibleNotificationsCount: [String: Int] = [:]
  @State private var scrollToIdAnimated: String?

  let lockedType: Models.Notification.NotificationType?
  let lockedAccountId: String?
  let isLockedType: Bool

  public init(
    lockedType: Models.Notification.NotificationType? = nil,
    lockedAccountId: String? = nil
  ) {
    self.lockedType = lockedType
    self.lockedAccountId = lockedAccountId
    self.isLockedType = lockedType != nil
  }

  public var body: some View {
    listWithFilterObservers
      .refreshable {
        SoundEffectManager.shared.playSound(.pull)
        HapticManager.shared.fireHaptic(.dataRefresh(intensity: 0.3))
        await fetchNotifications()
        policy = await dataSource.fetchPolicy(client: client)
        HapticManager.shared.fireHaptic(.dataRefresh(intensity: 0.7))
        SoundEffectManager.shared.playSound(.refresh)
      }
      .onChange(of: watcher.latestEvent?.id) { _, _ in
        if let latestEvent = watcher.latestEvent {
          Task {
            await handleStreamEvent(latestEvent)
          }
        }
      }
      .onChange(of: scenePhase) { _, newValue in
        switch newValue {
        case .active:
          Task {
            await fetchNotifications()
          }
        default:
          break
        }
      }
      .onChange(of: client) { oldValue, newValue in
        guard oldValue.id != newValue.id else { return }
        dataSource.reset()
        viewState = .loading
        Task {
          await fetchNotifications()
          policy = await dataSource.fetchPolicy(client: client)
        }
      }
  }

  private var listWithFilterObservers: some View {
    notificationsList
      .onChange(of: filter.showUpdate) { _, _ in refreshFiltered() }
      .onChange(of: filter.showStatus) { _, _ in refreshFiltered() }
      .onChange(of: filter.showMention) { _, _ in refreshFiltered() }
      .onChange(of: filter.showReblog) { _, _ in refreshFiltered() }
      .onChange(of: filter.showFollow) { _, _ in refreshFiltered() }
      .onChange(of: filter.showFollowRequest) { _, _ in refreshFiltered() }
      .onChange(of: filter.showFavourite) { _, _ in refreshFiltered() }
      .onChange(of: filter.showPoll) { _, _ in refreshFiltered() }
      .onChange(of: filter.showQuote) { _, _ in refreshFiltered() }
      .onChange(of: filter.showQuotedUpdate) { _, _ in refreshFiltered() }
      .onChange(of: isNotificationsPolicyPresented) { _, isPresented in
        guard !isPresented else { return }
        Task {
          policy = await dataSource.fetchPolicy(client: client)
          await fetchNotifications()
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      #if !os(visionOS)
        .scrollContentBackground(.hidden)
        .background(theme.primaryBackgroundColor)
      #endif
      .task {
        if let lockedType {
          selectedType = lockedType
        }
        await fetchNotifications()
        policy = await dataSource.fetchPolicy(client: client)
      }
  }

  private func handleScrollToTopTrigger() -> String? {
    guard UserPreferences.shared.undoScrollToTopEnabled else { return nil }
    if let previous = previousScrollPosition, scrollToTopVisible {
      previousScrollPosition = nil
      undoTask?.cancel()
      undoTask = nil
      return previous
    } else {
      var topVisibleId: String? = nil
      if case .display(let notifications, _) = viewState {
        topVisibleId = notifications.first { (visibleNotificationsCount[$0.id] ?? 0) > 0 }?.id
      }
      if let first = topVisibleId {
        previousScrollPosition = first
        undoTask?.cancel()
        undoTask = Task {
          try? await Task.sleep(for: .seconds(UserPreferences.shared.undoScrollToTopTimeout))
          guard !Task.isCancelled else { return }
          previousScrollPosition = nil
        }
      }
      return nil
    }
  }

  private var notificationsList: some View {
    ScrollViewReader { proxy in
      List {
        ScrollToView()
          .frame(height: .layoutPadding)
          .onAppear {
            scrollToTopVisible = true
          }
          .onDisappear {
            scrollToTopVisible = false
          }
          
        if lockedAccountId == nil, let summary = policy?.summary {
        NotificationsHeaderFilteredView(filteredNotifications: summary)
      }
      notificationsView
        .listSectionSeparator(.hidden, edges: .top)
    }
    .id(account.account?.id)
    .environment(\.defaultMinListRowHeight, 1)
    .listStyle(.plain)
    .toolbar {
      ToolbarItem(placement: .principal) {
        let title =
          lockedType?.menuTitle() ?? selectedType?.menuTitle()
          ?? "notifications.navigation-title"
        if lockedType == nil {
          Text(title)
            .font(.headline)
            .accessibilityRepresentation {
              Menu(title) {}
            }
            .accessibilityAddTraits(.isHeader)
            .accessibilityRemoveTraits(.isButton)
            .accessibilityRespondsToUserInteraction(true)
        } else {
          Text(title)
            .font(.headline)
            .accessibilityAddTraits(.isHeader)
        }
      }
    }
    .onChange(of: scrollToIdAnimated) { _, newValue in
      if let newValue {
        withAnimation {
          proxy.scrollTo(newValue, anchor: .top)
          scrollToIdAnimated = nil
        }
      }
    }
    .onChange(of: selectedTabScrollToTop) { _, newValue in
      if let currentTabId, newValue == currentTabId, routerPath.path.isEmpty {
        if let previous = handleScrollToTopTrigger() {
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            scrollToIdAnimated = previous
          }
        } else {
          withAnimation {
            proxy.scrollTo(ScrollToView.Constants.scrollToTop, anchor: .top)
          }
        }
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: .statusBarTapped)) { _ in
      if let previous = handleScrollToTopTrigger() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          scrollToIdAnimated = previous
        }
      }
    }
    .toolbar {
      if lockedType == nil && lockedAccountId == nil {
        ToolbarTitleMenu {
          Button {
            applyFilter(type: nil)
          } label: {
            Label("notifications.navigation-title", systemImage: "bell.fill")
              .tint(theme.labelColor)
          }
          Divider()
          ForEach(Notification.NotificationType.allCases, id: \.self) { type in
            Button {
              applyFilter(type: type)
            } label: {
              Label {
                Text(type.menuTitle())
              } icon: {
                type.icon(isPrivate: false)
              }
            }
            .tint(theme.labelColor)
          }
          if currentInstance.isNotificationsFilterSupported {
            Divider()
            Button {
              isNotificationsPolicyPresented = true
            } label: {
              Label("notifications.content-filter.title", systemImage: "line.3.horizontal.decrease.circle")
            }
            .tint(theme.labelColor)
          }
          Divider()
          Button {
            routerPath.navigate(to: .conversations)
          } label: {
            Label("Direct Messages", systemImage: "message")
          }
          .tint(theme.labelColor)
          Divider()
          Button {
            isNotificationsContentFilterPresented = true
          } label: {
            Label("Content Filter", systemImage: "line.3.horizontal.decrease")
          }
          .tint(theme.labelColor)
        }
      }
    }
    .sheet(isPresented: $isNotificationsPolicyPresented) {
      NotificationsPolicyView()
        .environment(client)
        .environment(theme)
    }
    .sheet(isPresented: $isNotificationsContentFilterPresented) {
      NotificationsContentFilterView()
        .environment(theme)
    }
    }
  }

  @ViewBuilder
  private var notificationsView: some View {
    switch viewState {
    case .loading:
      ForEach(ConsolidatedNotification.placeholders()) { notification in
        NotificationRowView(
          notification: notification,
          client: client,
          routerPath: routerPath,
          followRequests: account.followRequests
        )
        .listRowInsets(
          .init(
            top: 12,
            leading: .layoutPadding + 4,
            bottom: 0,
            trailing: .layoutPadding)
        )
        #if os(visionOS)
          .listRowBackground(
            RoundedRectangle(cornerRadius: 8)
              .foregroundStyle(.background))
        #else
          .listRowBackground(theme.primaryBackgroundColor)
        #endif
        .redacted(reason: .placeholder)
        .allowsHitTesting(false)
      }

    case .display(let notifications, let nextPageState):
      if notifications.isEmpty {
        PlaceholderView(
          iconName: "bell.slash",
          title: "notifications.empty.title",
          message: "notifications.empty.message"
        )
        #if !os(visionOS)
          .listRowBackground(theme.primaryBackgroundColor)
        #endif
        .listSectionSeparator(.hidden)
      } else {
        ForEach(notifications) { notification in
          NotificationRowView(
            notification: notification,
            client: client,
            routerPath: routerPath,
            followRequests: account.followRequests
          )
          .id(notification.id)
          .onAppear {
            visibleNotificationsCount[notification.id, default: 0] += 1
          }
          .onDisappear {
            visibleNotificationsCount[notification.id, default: 0] -= 1
          }
          .listRowInsets(
            .init(
              top: 12,
              leading: .layoutPadding + 4,
              bottom: 6,
              trailing: .layoutPadding)
          )
          #if os(visionOS)
            .listRowBackground(
              RoundedRectangle(cornerRadius: 8)
                .foregroundStyle(
                  notification.type == .mention && lockedType != .mention
                    ? Material.thick : Material.regular
                ).hoverEffect()
            )
            .listRowHoverEffectDisabled()
          #else
            .listRowBackground(
              notification.type == .mention && lockedType != .mention
                ? theme.secondaryBackgroundColor : theme.primaryBackgroundColor)
          #endif
          .id(notification.id)
        }

        switch nextPageState {
        case .none:
          EmptyView()
        case .hasNextPage:
          NextPageView {
            await fetchNextPage()
          }
          .listRowInsets(
            .init(
              top: .layoutPadding,
              leading: .layoutPadding + 4,
              bottom: .layoutPadding,
              trailing: .layoutPadding)
          )
          #if !os(visionOS)
            .listRowBackground(theme.primaryBackgroundColor)
          #endif
        }
      }

    case .error:
      ErrorView(
        title: "notifications.error.title",
        message: "notifications.error.message",
        buttonTitle: "action.retry"
      ) {
        await fetchNotifications()
      }
      #if !os(visionOS)
        .listRowBackground(theme.primaryBackgroundColor)
      #endif
      .listSectionSeparator(.hidden)
    }
  }
}

extension NotificationsListView {
  private func refreshFiltered() {
    dataSource.reset()
    viewState = .loading
    Task {
      await fetchNotifications()
    }
  }

  private func applyFilter(type: Models.Notification.NotificationType?) {
    selectedType = type
    dataSource.reset()
    viewState = .loading

    Task {
      await fetchNotifications()
    }
  }

  private func fetchNotifications() async {
    do {
      let result = try await dataSource.fetchNotifications(
        client: client,
        selectedType: selectedType,
        lockedAccountId: lockedAccountId
      )

      withAnimation {
        viewState = .display(
          notifications: result.notifications,
          nextPageState: result.nextPageState
        )
      }

      if result.containsFollowRequests {
        await account.fetchFollowerRequests()
      }
    } catch {
      if !Task.isCancelled {
        viewState = .error(error: error)
      }
    }
  }

  private func fetchNextPage() async {
    do {
      let result = try await dataSource.fetchNextPage(
        client: client,
        selectedType: selectedType,
        lockedAccountId: lockedAccountId
      )

      viewState = .display(
        notifications: result.notifications,
        nextPageState: result.nextPageState
      )

      if result.containsFollowRequests {
        await account.fetchFollowerRequests()
      }
    } catch {}
  }

  private func handleStreamEvent(_ event: any StreamEvent) async {
    if let result = await dataSource.handleStreamEvent(
      event: event,
      selectedType: selectedType,
      lockedAccountId: lockedAccountId
    ) {
      withAnimation {
        viewState = .display(
          notifications: result.notifications,
          nextPageState: .hasNextPage
        )
      }

      if result.containsFollowRequests {
        await account.fetchFollowerRequests()
      }
    }
  }
}
