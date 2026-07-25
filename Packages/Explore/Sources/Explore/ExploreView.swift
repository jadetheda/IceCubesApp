import Account
import DesignSystem
import Env
import Models
import NetworkClient
import StatusKit
import SwiftUI

@MainActor
public struct ExploreView: View {
  @Environment(Theme.self) private var theme
  @Environment(UserPreferences.self) private var preferences
  @Environment(MastodonClient.self) private var client
  @Environment(RouterPath.self) private var routerPath

  @State private var searchQuery = ""
  @State private var searchScope: SearchScope = .all
  @State private var isSearchPresented = false
  @State private var isLoaded = false
  @State private var isSearching = false
  @State private var results: [String: SearchResults] = [:]
  @State private var suggestedAccounts: [Account] = []
  @State private var suggestedAccountsRelationShips: [Relationship] = []
  @State private var trendingTags: [Tag] = []
  @State private var trendingStatuses: [Status] = []
  @State private var trendingLinks: [Card] = []
  @State private var scrollToTopVisible = false
  @State private var previousScrollPosition: String?
  @State private var undoTask: Task<Void, Never>?
  @State private var visibleSectionsCount: [String: Int] = [:]
  @State private var scrollToIdAnimated: String?
  @Environment(\.selectedTabScrollToTop) private var selectedTabScrollToTop
  @Environment(\.currentTabId) private var currentTabId

  private var allSectionsEmpty: Bool {
    trendingLinks.isEmpty && trendingTags.isEmpty && trendingStatuses.isEmpty
      && suggestedAccounts.isEmpty
  }

  private func handleScrollToTopTrigger() -> String? {
    guard preferences.undoScrollToTopEnabled else { return nil }
    if let previous = previousScrollPosition, scrollToTopVisible {
      previousScrollPosition = nil
      undoTask?.cancel()
      undoTask = nil
      return previous
    } else {
      let topVisibleId = ["quick_access", "trending_tags", "suggested_accounts", "trending_statuses", "trending_links"].first { (visibleSectionsCount[$0] ?? 0) > 0 }
      
      if let first = topVisibleId {
        previousScrollPosition = first
        undoTask?.cancel()
        undoTask = Task {
          try? await Task.sleep(for: .seconds(preferences.undoScrollToTopTimeout))
          guard !Task.isCancelled else { return }
          previousScrollPosition = nil
        }
      }
      return nil
    }
  }

  public init() {}

  public var body: some View {
    ScrollViewReader { proxy in
      List {
        scrollToTopView
        if !isLoaded {
          if !preferences.useIceShrimpWorkarounds {
            QuickAccessView(
              trendingLinks: trendingLinks,
              suggestedAccounts: suggestedAccounts,
              trendingTags: trendingTags
            )
          }
          loadingView
        } else if !searchQuery.isEmpty {
          if let results = results[searchQuery] {
            if results.isEmpty, !isSearching {
              PlaceholderView(
                iconName: "magnifyingglass",
                title: "explore.search.empty.title",
                message: "explore.search.empty.message"
              )
              .listRowBackground(theme.secondaryBackgroundColor)
              .listRowSeparator(.hidden)
            } else {
              SearchResultsView(
                results: results,
                searchScope: searchScope,
                onNextPage: fetchNextPage
              )
            }
          } else {
            HStack {
              Spacer()
              ProgressView()
              Spacer()
            }
            #if !os(visionOS)
              .listRowBackground(theme.secondaryBackgroundColor)
            #endif
            .listRowSeparator(.hidden)
            .id(UUID())
          }
        } else if allSectionsEmpty {
          PlaceholderView(
            iconName: "magnifyingglass",
            title: "explore.search.title",
            message: "explore.search.message-\(client.server)"
          )
          #if !os(visionOS)
            .listRowBackground(theme.secondaryBackgroundColor)
          #endif
          .listRowSeparator(.hidden)
        } else {
          if !preferences.useIceShrimpWorkarounds {
            QuickAccessView(
              trendingLinks: trendingLinks,
              suggestedAccounts: suggestedAccounts,
              trendingTags: trendingTags
            )
            .padding(.bottom, 4)
          }

          if !trendingTags.isEmpty {
            TrendingTagsSection(trendingTags: trendingTags)
          }
          if !suggestedAccounts.isEmpty {
            SuggestedAccountsSection(
              suggestedAccounts: suggestedAccounts,
              suggestedAccountsRelationShips: suggestedAccountsRelationShips
            )
          }
          if !trendingStatuses.isEmpty {
            TrendingPostsSection(trendingStatuses: trendingStatuses)
          }
          if !trendingLinks.isEmpty {
            TrendingLinksSection(trendingLinks: trendingLinks)
          }
        }
      }
      .environment(\.defaultMinListRowHeight, .scrollToViewHeight)
      .task {
        await fetchTrending()
      }
      .refreshable {
        Task {
          SoundEffectManager.shared.playSound(.pull)
          HapticManager.shared.fireHaptic(.dataRefresh(intensity: 0.3))
          await fetchTrending()
          HapticManager.shared.fireHaptic(.dataRefresh(intensity: 0.7))
          SoundEffectManager.shared.playSound(.refresh)
        }
      }
      .listStyle(.grouped)
      #if !os(visionOS)
        .scrollContentBackground(.hidden)
        .background(theme.secondaryBackgroundColor.edgesIgnoringSafeArea(.all))
      #endif
      .navigationTitle("explore.navigation-title")
      .navigationBarTitleDisplayMode(.inline)
      .searchable(
        text: $searchQuery,
        isPresented: $isSearchPresented,
        placement: .navigationBarDrawer(displayMode: .always),
        prompt: Text("explore.search.prompt")
      )
      .searchScopes($searchScope) {
        ForEach(SearchScope.allCases, id: \.self) { scope in
          Text(scope.localizedString)
        }
      }
      .task(id: searchQuery) {
        await search()
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
    }
  }

  private var loadingView: some View {
    ForEach(Status.placeholders()) { status in
      StatusRowExternalView(
        viewModel: .init(
          status: status,
          client: client,
          routerPath: routerPath,
          filterContext: .pub)
      )
      .padding(.vertical, 8)
      .redacted(reason: .placeholder)
      .allowsHitTesting(false)
      #if !os(visionOS)
        .listRowBackground(theme.primaryBackgroundColor)
      #endif
    }
  }

  private var scrollToTopView: some View {
    ScrollToView()
      .frame(height: .scrollToViewHeight)
      .onAppear {
        scrollToTopVisible = true
      }
      .onDisappear {
        scrollToTopVisible = false
      }
  }
}

extension ExploreView {
  private func fetchTrending() async {
    do {
      let data = await fetchTrendingsData()
      suggestedAccounts = data.suggestedAccounts
      trendingTags = data.trendingTags
      trendingStatuses = data.trendingStatuses
      trendingLinks = data.trendingLinks

      if !suggestedAccounts.isEmpty {
        suggestedAccountsRelationShips = try await client.get(
          endpoint: Accounts.relationships(ids: suggestedAccounts.map(\.id)))
      } else {
        suggestedAccountsRelationShips = []
      }
      withAnimation {
        isLoaded = true
      }
    } catch {
      isLoaded = true
    }
  }

  private struct TrendingData {
    let suggestedAccounts: [Account]
    let trendingTags: [Tag]
    let trendingStatuses: [Status]
    let trendingLinks: [Card]
  }


  private func fetchTrendingStatusesHelper() async throws -> [Status] {
    
    if preferences.trendingAlgorithm == .simpleScore {
      var statuses: [Status] = []
      do {
        statuses = try await client.get(endpoint: Timelines.pub(sinceId: nil, maxId: nil, minId: nil, local: false, limit: preferences.trendingSimpleScoreSearchLimit))
      } catch {
        return []
      }
      
      var scoredStatuses: [(Status, Int)] = []
      for status in statuses {
        guard status.visibility == .pub, status.inReplyToId == nil else { continue }
        let score = status.reblogsCount + status.favouritesCount
        scoredStatuses.append((status, score))
      }
      
      scoredStatuses.sort { $0.1 > $1.1 }
      return scoredStatuses.map { $0.0 }
    }

    if preferences.trendingAlgorithm == .decayingScore {
      var statuses: [Status] = []
      do {
        statuses = try await client.get(endpoint: Timelines.pub(sinceId: nil, maxId: nil, minId: nil, local: false, limit: 40))
      } catch {
        return []
      }
      
      let threshold = Double(preferences.iceShrimpTrendingThreshold)
      let halfLife = preferences.iceShrimpTrendingHalfLife
      
      var scoredStatuses: [(Status, Double)] = []
      let now = Date()
      
      for status in statuses {
        guard status.visibility == .pub, status.inReplyToId == nil else { continue }
        
        let observed = Double(status.reblogsCount + status.favouritesCount)
        let expected = 1.0
        
        var score = 0.0
        if observed >= threshold {
          score = pow(observed - expected, 2) / expected
        }
        
        if score > 0 {
          let hoursSinceCreation = now.timeIntervalSince(status.createdAt.asDate) / 3600.0
          let decay = pow(0.5, hoursSinceCreation / halfLife)
          let decayingScore = score * decay
          scoredStatuses.append((status, decayingScore))
        }
      }
      
      scoredStatuses.sort { $0.1 > $1.1 }
      return scoredStatuses.map { $0.0 }
    }
    
    return try await client.get(endpoint: Trends.statuses(offset: nil))
  }

  /// Fetches suggested accounts with a safe fallback on network or API failure (e.g. on Iceshrimp.NET instances where the suggestions endpoint is not implemented)
  private func fetchSuggestedAccountsSafe() async -> [Account] {
    do {
      return try await client.get(endpoint: Accounts.suggestions)
    } catch {
      return []
    }
  }

  /// Fetches trending tags with a safe fallback on network or API failure (e.g. on Iceshrimp.NET instances where trends endpoints are not implemented)
  private func fetchTrendingTagsSafe() async -> [Tag] {
    do {
      return try await client.get(endpoint: Trends.tags)
    } catch {
      return []
    }
  }

  /// Fetches trending statuses with a safe fallback on network or API failure
  private func fetchTrendingStatusesSafe() async -> [Status] {
    do {
      return try await fetchTrendingStatusesHelper()
    } catch {
      return []
    }
  }

  /// Fetches trending links with a safe fallback on network or API failure (e.g. on Iceshrimp.NET instances where trends endpoints are not implemented)
  private func fetchTrendingLinksSafe() async -> [Card] {
    do {
      return try await client.get(endpoint: Trends.links(offset: nil))
    } catch {
      return []
    }
  }

  private func fetchTrendingsData() async -> TrendingData {
    async let suggestedAccounts: [Account] = fetchSuggestedAccountsSafe()
    async let trendingTags: [Tag] = fetchTrendingTagsSafe()
    async let trendingStatuses: [Status] = fetchTrendingStatusesSafe()
    async let trendingLinks: [Card] = fetchTrendingLinksSafe()
    return await .init(
      suggestedAccounts: suggestedAccounts,
      trendingTags: trendingTags,
      trendingStatuses: trendingStatuses,
      trendingLinks: trendingLinks)
  }

  private func search() async {
    guard !searchQuery.isEmpty else { return }
    isSearching = true
    do {
      try await Task.sleep(for: .milliseconds(250))
      var results: SearchResults = try await client.get(
        endpoint: Search.search(
          query: searchQuery,
          type: nil,
          offset: nil,
          following: nil),
        forceVersion: .v2)
      let relationships: [Relationship] =
        try await client.get(endpoint: Accounts.relationships(ids: results.accounts.map(\.id)))
      results.relationships = relationships
      withAnimation {
        self.results[searchQuery] = results
        isSearching = false
      }
    } catch {
      isSearching = false
    }
  }

  private func fetchNextPage(of type: Search.EntityType) async {
    guard !searchQuery.isEmpty,
      let results = results[searchQuery]
    else { return }
    do {
      let offset =
        switch type {
        case .accounts:
          results.accounts.count
        case .hashtags:
          results.hashtags.count
        case .statuses:
          results.statuses.count
        }

      var newPageResults: SearchResults = try await client.get(
        endpoint: Search.search(
          query: searchQuery,
          type: type,
          offset: offset,
          following: nil),
        forceVersion: .v2)
      if type == .accounts {
        let relationships: [Relationship] =
          try await client.get(
            endpoint: Accounts.relationships(ids: newPageResults.accounts.map(\.id)))
        newPageResults.relationships = relationships
      }

      switch type {
      case .accounts:
        self.results[searchQuery]?.accounts.append(contentsOf: newPageResults.accounts)
        self.results[searchQuery]?.relationships.append(contentsOf: newPageResults.relationships)
      case .hashtags:
        self.results[searchQuery]?.hashtags.append(contentsOf: newPageResults.hashtags)
      case .statuses:
        self.results[searchQuery]?.statuses.append(contentsOf: newPageResults.statuses)
      }
    } catch {}
  }
}
