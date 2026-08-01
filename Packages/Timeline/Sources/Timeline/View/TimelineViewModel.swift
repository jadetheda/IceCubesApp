import Env
import Models
import NetworkClient
import Observation
import StatusKit
import SwiftUI
import Nuke

@MainActor
@Observable class TimelineViewModel {
  var scrollToId: String?
  @ObservationIgnored private var cacheUpdateTask: Task<Void, Never>?
  var statusesState: StatusesState = .loading
  var timeline: TimelineFilter = .home {
    willSet {
      if timeline == .home,
        newValue != .resume,
        newValue != timeline
      {
        saveMarker()
      }
    }
    didSet {
      Task {
        await datasource.setFilterContext(timeline.filterContext)
      }
      timelineTask?.cancel()

      // Stop streaming when leaving streamable timeline
      if isStreamingTimeline && !canStreamTimeline(timeline) {
        isStreamingTimeline = false
      }

      timelineTask = Task {
        await handleLatestOrResume(oldValue)

        if oldValue != timeline {
          Telemetry.signal(
            "timeline.filter.updated",
            parameters: ["timeline": timeline.rawValue])

          await reset()
          pendingStatusesObserver.pendingStatuses = []
          tag = nil
        }

        guard !Task.isCancelled else {
          return
        }

        await fetchNewestStatuses(pullToRefresh: false)
        switch timeline {
        case .hashtag(let tag, _):
          await fetchTag(id: tag)
        default:
          break
        }
      }
    }
  }

  private(set) var timelineTask: Task<Void, Never>?
  private var sessionSeenPosts: Set<String> = []
  private var exemptFromHideSeen: Set<String> = []

  var tag: Tag?

  // Internal source of truth for a timeline.
  @ObservationIgnored
  private(set) var datasource = TimelineDatasource()
  private let statusFetcher: TimelineStatusFetching

  @ObservationIgnored
  private let cache = TimelineCache()

  private enum Constants {
    static let fullTimelineFetchLimit = 800
    static let fullTimelineFetchMaxPages = fullTimelineFetchLimit / 40
    static let initialPageLimit = 50
    static let nextPageLimit = 40
    static let emptyFilterAutoPageLimit = 3
  }

  private var isFullTimelineFetchEnabled: Bool {
    guard UserPreferences.shared.fullTimelineFetch else { return false }
    return true
  }

  private var isCacheEnabled: Bool {
    canFilterTimeline && timeline.supportNewestPagination && client?.isAuth == true
  }

  @ObservationIgnored
  private var visibleStatuses: [Status] = []

  @ObservationIgnored
  private var visibleStatusesCount: [String: Int] = [:]

  private var canStreamEvents: Bool = true {
    didSet {
      if canStreamEvents {
        pendingStatusesObserver.isLoadingNewStatuses = false
      }
    }
  }

  @ObservationIgnored
  var canFilterTimeline: Bool = true

  var isStreamingTimeline: Bool = false {
    didSet {
      if isStreamingTimeline != oldValue {
        updateStreamWatcher()
      }
    }
  }

  var client: MastodonClient? {
    didSet {
      if oldValue != client {
        Task {
          await reset()
        }
      }
    }
  }

  var scrollToTopVisible: Bool = false
  var previousScrollPosition: String? = nil
  var undoTimer: Timer? = nil

  func handleScrollToTopTrigger() -> String? {
    guard UserPreferences.shared.undoScrollToTopEnabled else { return nil }
    if let previous = previousScrollPosition, scrollToTopVisible {
      previousScrollPosition = nil
      undoTimer?.invalidate()
      undoTimer = nil
      return previous
    } else {
      var topVisibleId: String? = nil
      if case .displayWithGaps(let items, _) = statusesState {
          topVisibleId = items.compactMap { $0.status?.id }.first { visibleStatusesCount[$0] != nil }
      } else if case .display(let statuses, _) = statusesState {
          topVisibleId = statuses.map { $0.id }.first { visibleStatusesCount[$0] != nil }
      }
      
      if let first = topVisibleId ?? visibleStatuses.first?.id {
        previousScrollPosition = first
        undoTimer?.invalidate()
        undoTimer = Timer.scheduledTimer(withTimeInterval: UserPreferences.shared.undoScrollToTopTimeout, repeats: false) { [weak self] _ in
          DispatchQueue.main.async {
            self?.previousScrollPosition = nil
          }
        }
      }
      return nil
    }
  }

  var serverName: String {
    client?.server ?? "Error"
  }

  let pendingStatusesObserver: TimelineUnreadStatusesObserver = .init()
  var marker: Marker.Content?

  @ObservationIgnored
  nonisolated(unsafe) private var hideReadPostsObserver: NSObjectProtocol?
  @ObservationIgnored
  nonisolated(unsafe) private var statusUpdatedObserver: NSObjectProtocol?

  init(statusFetcher: TimelineStatusFetching = TimelineStatusFetcher()) {
    self.statusFetcher = statusFetcher
    Task {
      await datasource.setFilterContext(timeline.filterContext)
    }

    // Both the toolbar toggle and the one-off "hide read posts" action post this
    // notification. Without this observer, toggling `TimelineContentFilter.shared.hideReadPosts`
    // (or firing the one-off action) never re-filters `statusesState`, so the button appears to
    // do nothing even for posts that are already marked seen.
    hideReadPostsObserver = NotificationCenter.default.addObserver(
      forName: .hideReadPosts,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      guard let self else { return }
      Task { @MainActor in
        await self.hideReadPosts()
      }
    }
    
    statusUpdatedObserver = NotificationCenter.default.addObserver(
      forName: .statusUpdated,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard let self, let status = notification.object as? Status else { return }
      Task { @MainActor in
        guard let originalIndex = await self.datasource.indexOf(statusId: status.id) else { return }
        if status.favourited == true || status.reblogged == true || status.reblog?.favourited == true || status.reblog?.reblogged == true {
          self.exemptFromHideSeen.insert(status.id)
          if let reblogId = status.reblog?.id {
            self.exemptFromHideSeen.insert(reblogId)
          }
        }
        await self.datasource.replace(status, at: originalIndex)
        await self.cache()
        await self.updateStatusesState()
      }
    }
  }

  deinit {
    if let hideReadPostsObserver {
      NotificationCenter.default.removeObserver(hideReadPostsObserver)
    }
    if let statusUpdatedObserver {
      NotificationCenter.default.removeObserver(statusUpdatedObserver)
    }
  }

  private func fetchTag(id: String) async {
    guard let client else { return }
    do {
      let tag: Tag = try await client.get(endpoint: Tags.tag(id: id))
      withAnimation {
        self.tag = tag
      }
    } catch {}
  }

  func reset() async {
    await datasource.reset()
    visibleStatuses = []
    visibleStatusesCount = [:]
    exemptFromHideSeen = []
  }

  private func handleLatestOrResume(_ oldValue: TimelineFilter) async {
    if timeline == .latest || timeline == .resume {
      await clearCache(filter: oldValue)
      if timeline == .resume, let marker = await fetchMarker() {
        self.marker = marker
      }
      timeline = oldValue
    }
  }
}

// MARK: - Cache

extension TimelineViewModel {
  private func cache() async {
    if let client, isCacheEnabled {
      let items = await datasource.getItems()
      await cache.set(items: items, client: client.id, filter: timeline.id)
    }
  }

  private func getCachedItems() async -> [TimelineItem]? {
    if let client, isCacheEnabled {
      return await cache.getItems(for: client.id, filter: timeline.id)
    }
    return nil
  }

  private func clearCache(filter: TimelineFilter) async {
    if let client, isCacheEnabled {
      await cache.clearCache(for: client.id, filter: filter.id)
      await cache.setLatestSeenStatuses([], for: client, filter: filter.id)
    }
  }
}

// MARK: - StatusesFetcher

extension TimelineViewModel: GapLoadingFetcher {
  func pullToRefresh() async {
    timelineTask?.cancel()

    exemptFromHideSeen = []

    if !timeline.supportNewestPagination {
      await reset()
    }
    await fetchNewestStatuses(pullToRefresh: true)
  }

  func refreshTimeline() {
    timelineTask?.cancel()
    timelineTask = Task {
      await fetchNewestStatuses(pullToRefresh: false)
    }
  }

  func refreshTimelineContentFilter() async {
    timelineTask?.cancel()
    if TimelineContentFilter.shared.hideReadPosts {
      sessionSeenPosts = SeenPostsManager.shared.seenPosts
    }
    await updateStatusesState()
  }

  func fetchStatuses(from: Marker.Content) async throws {
    guard let client else { return }
    statusesState = .loading
    let statuses = try await timeline.fetchStatuses(
      client: client,
      sinceId: nil,
      maxId: from.lastReadId,
      minId: nil,
      offset: 0,
      limit: 40
    )

    await updateDatasourceAndState(statuses: statuses, client: client, replaceExisting: true)
    marker = nil
    await fetchNewestStatuses(pullToRefresh: false)
  }

  func fetchNewestStatuses(pullToRefresh: Bool) async {
    guard let client else { return }
    do {
      if pullToRefresh || sessionSeenPosts.isEmpty {
        sessionSeenPosts = SeenPostsManager.shared.seenPosts
        if UserPreferences.shared.hideSeenPostsEnabled, !UserPreferences.shared.hideSeenPostsIsToggle {
          await datasource.hideReadPosts(seen: sessionSeenPosts, includeBoosts: UserPreferences.shared.hideSeenPostsIncludeBoosts)
        }
      }
      if let marker {
        try await fetchStatuses(from: marker)
      } else if await datasource.isEmpty {
        try await fetchFirstPage(client: client)
      } else if let latest = await datasource.get().first, timeline.supportNewestPagination {
        pendingStatusesObserver.isLoadingNewStatuses = !pullToRefresh
        try await fetchNewPagesFrom(latestStatus: latest.id, client: client)
      }
    } catch {
      if await datasource.isEmpty {
        statusesState = .error(error: .noData)
      }
      canStreamEvents = true
    }
  }

  // Hydrate statuses in the Timeline when statuses are empty.
  private func fetchFirstPage(client: MastodonClient) async throws {
    pendingStatusesObserver.pendingStatuses = []

    let datasourceIsEmpty = await datasource.isEmpty
    if datasourceIsEmpty {
      statusesState = .loading
    }

    // If we get statuses from the cache for the home timeline, we displays those.
    // Else we fetch top most page from the API.
    if timeline.supportNewestPagination,
      let cachedItems = await getCachedItems(),
      !cachedItems.isEmpty
    {
      await datasource.setItems(cachedItems)
      let items = await datasource.getFilteredItems(seen: sessionSeenPosts, exempt: exemptFromHideSeen)
      if let latestSeenId = await cache.getLatestSeenStatus(for: client, filter: timeline.id)?.first
      {
        // Restore cache and scroll to latest seen status.
        scrollToId = latestSeenId
        statusesState = .displayWithGaps(items: items, nextPageState: .hasNextPage)
      } else {
        // Restore cache and scroll to top.
        withAnimation {
          statusesState = .displayWithGaps(items: items, nextPageState: .hasNextPage)
        }
      }
      // And then we fetch statuses again to get newest statuses from there.
      await fetchNewestStatuses(pullToRefresh: false)
    } else {
      let statuses: [Status] = try await statusFetcher.fetchFirstPage(
        client: client,
        timeline: timeline)

      await updateDatasourceAndState(statuses: statuses, client: client, replaceExisting: true)
      let lastCount = await autoFetchNextPageWhileNoVisibleItems(
        lastFetchedCount: statuses.count,
        pageLimit: Constants.initialPageLimit)
      if lastCount != statuses.count {
        await cache()
        await updateStatusesStateWithAnimation()
      }

      // If we got 40 or more statuses, there might be older ones - create a gap
      if lastCount >= Constants.nextPageLimit, !datasourceIsEmpty {
        let allStatuses = await datasource.get()
        if let oldestStatus = allStatuses.last {
          await createGapForOlderStatuses(maxId: oldestStatus.id, at: allStatuses.count)
        }
      }
    }
  }

  // Fetch pages from the top most status of the timeline.
  private func fetchNewPagesFrom(latestStatus: String, client: MastodonClient) async throws {
    canStreamEvents = false
    let initialTimeline = timeline

    // First, fetch the absolute newest statuses (no ID parameters)
    let newestStatuses: [Status] = try await statusFetcher.fetchFirstPage(
      client: client,
      timeline: timeline)

    guard !newestStatuses.isEmpty,
      !Task.isCancelled,
      initialTimeline == timeline
    else {
      canStreamEvents = true
      return
    }

    let currentIds = await datasource.get().map(\.id)
    let actuallyNewStatuses = newestStatuses.filter { status in
      !currentIds.contains(where: { $0 == status.id }) && status.id > latestStatus
    }

    guard !actuallyNewStatuses.isEmpty else {
      canStreamEvents = true
      return
    }

    var statusesToInsert = actuallyNewStatuses

    if isFullTimelineFetchEnabled, statusesToInsert.count < Constants.fullTimelineFetchLimit {
      let additionalStatuses: [Status] = try await statusFetcher.fetchNewPages(
        client: client,
        timeline: timeline,
        minId: latestStatus,
        maxPages: Constants.fullTimelineFetchMaxPages)

      if !additionalStatuses.isEmpty {
        var knownIds = Set(currentIds)
        knownIds.formUnion(statusesToInsert.map(\.id))

        let filteredAdditional = additionalStatuses.filter { status in
          guard status.id > latestStatus else { return false }
          if knownIds.contains(status.id) {
            return false
          }
          knownIds.insert(status.id)
          return true
        }

        if !filteredAdditional.isEmpty {
          let remainingCapacity = max(0, Constants.fullTimelineFetchLimit - statusesToInsert.count)
          if remainingCapacity > 0 {
            statusesToInsert.append(contentsOf: filteredAdditional.prefix(remainingCapacity))
          }
        }
      }
    }

    statusesToInsert.sort { $0.id > $1.id }

    if statusesToInsert.count > Constants.fullTimelineFetchLimit {
      statusesToInsert = Array(statusesToInsert.prefix(Constants.fullTimelineFetchLimit))
    }

    StatusDataControllerProvider.shared.updateDataControllers(
      for: statusesToInsert, client: client)

    // Pass the original count to determine if we need a gap
    await updateTimelineWithNewStatuses(
      statusesToInsert,
      latestStatus: latestStatus,
      fetchedCount: newestStatuses.count,
      shouldCreateGap: !isFullTimelineFetchEnabled
    )
    canStreamEvents = true
  }

  private func updateTimelineWithNewStatuses(
    _ newStatuses: [Status], latestStatus: String, fetchedCount: Int, shouldCreateGap: Bool
  ) async {
    let topStatus = await datasource.getFiltered(seen: sessionSeenPosts, exempt: exemptFromHideSeen).first

    // Insert new statuses at the top
    let filteredNewStatuses = filterSeenStatuses(from: newStatuses)
    await datasource.insert(contentOf: filteredNewStatuses, at: 0)

    // Only create a gap if:
    // 1. We fetched a full page (suggesting there might be more)
    // 2. AND we have a significant number of actually new statuses
    if shouldCreateGap,
      fetchedCount >= 40,
      newStatuses.count >= 40,
      let oldestNewStatus = newStatuses.last
    {
      // Create a gap to load statuses between the oldest new status and our previous top
      let gap = TimelineGap(sinceId: latestStatus, maxId: oldestNewStatus.id)
      // Insert the gap after all the new statuses
      await datasource.insertGap(gap, at: newStatuses.count)
    }

    await cache()
    let prefs = UserPreferences.shared

    let items = await datasource.getFilteredItems(seen: sessionSeenPosts, exempt: exemptFromHideSeen)
    let renderedStatusIds = Set(items.compactMap { item -> String? in
      if case .status(let status) = item { return status.id }
      return nil
    })
    let isGalleryMode = TimelineContentFilter.shared.isGalleryMode

    let newStatusesIDs = newStatuses.filter { status in
      guard renderedStatusIds.contains(status.id) else { return false }
      if isGalleryMode {
        if status.mediaAttachments.isEmpty && (status.reblog?.mediaAttachments.isEmpty ?? true) {
          return false
        }
      }
      guard prefs.hideSeenPostsEnabled else { return true }
      var isSeen = SeenPostsManager.shared.isSeen(id: status.id)
      if !isSeen, prefs.hideSeenPostsIncludeBoosts, let reblog = status.reblog {
        isSeen = SeenPostsManager.shared.isSeen(id: reblog.id)
      }
      if !isSeen, status.account.id == CurrentAccount.shared.account?.id {
        isSeen = true
      }
      if !isSeen, status.reblogged == true || status.favourited == true || status.reblog?.reblogged == true || status.reblog?.favourited == true {
        isSeen = true
      }
      return !isSeen
    }.map(\.id)

    pendingStatusesObserver.pendingStatuses.insert(contentsOf: newStatusesIDs, at: 0)

    if let topStatus = topStatus,
      visibleStatuses.contains(where: { $0.id == topStatus.id }),
      scrollToTopVisible
    {
      scrollToId = topStatus.id
      statusesState = .displayWithGaps(items: items, nextPageState: .hasNextPage)
    } else {
      withAnimation {
        statusesState = .displayWithGaps(items: items, nextPageState: .hasNextPage)
      }
    }
  }

  enum NextPageError: Error {
    case internalError
  }

  func fetchNextPage() async throws {
    let statuses = await datasource.get()
    guard let client, let lastId = statuses.last?.id else { throw NextPageError.internalError }
    let newStatuses: [Status] = try await statusFetcher.fetchNextPage(
      client: client,
      timeline: timeline,
      lastId: lastId,
      offset: statuses.count)

    let visibleCountBefore = await datasource.getFilteredItems(seen: sessionSeenPosts, exempt: exemptFromHideSeen).count
    await datasource.append(contentOf: newStatuses)
    StatusDataControllerProvider.shared.updateDataControllers(for: newStatuses, client: client)

    let lastCount = await autoFetchNextPageWhileNoVisibleItems(
      lastFetchedCount: newStatuses.count,
      pageLimit: Constants.nextPageLimit,
      visibleCountBefore: visibleCountBefore)
    await cache()
    statusesState = await .displayWithGaps(
      items: datasource.getFilteredItems(seen: sessionSeenPosts, exempt: exemptFromHideSeen),
      nextPageState: (newStatuses.isEmpty || lastCount == 0) ? .none : .hasNextPage)
  }

  func statusDidAppear(status: Status) {
    pendingStatusesObserver.removeStatus(status: status)
    
    visibleStatusesCount[status.id, default: 0] += 1
    if !visibleStatuses.contains(where: { $0.id == status.id }) {
      visibleStatuses.insert(status, at: 0)
    }

    if let client, timeline.supportNewestPagination {
      cacheUpdateTask?.cancel()
      cacheUpdateTask = Task {
        try? await Task.sleep(nanoseconds: 500_000_000)
        guard !Task.isCancelled else { return }
        await cache.setLatestSeenStatuses(visibleStatuses, for: client, filter: timeline.id)
      }
    }

    Task {
      let prefs = UserPreferences.shared
      guard prefs.hideSeenPostsEnabled else { return }
      
      let threshold = prefs.hideSeenPostsThreshold
      try? await Task.sleep(nanoseconds: UInt64(threshold * 1_000_000_000))
      if !Task.isCancelled {
        if visibleStatuses.contains(where: { $0.id == status.id }) {
          if prefs.hideSeenPostsRequireMediaLoaded && !status.mediaAttachments.isEmpty {
            // Check if image media is in cache. Wait up to 5 seconds.
            var allCached = false
            for _ in 0..<5 {
              allCached = status.mediaAttachments.allSatisfy { attachment in
                if attachment.supportedType == .image {
                  if let url = attachment.url {
                    return ImagePipeline.shared.cache.cachedImage(for: ImageRequest(url: url)) != nil
                  }
                }
                return true
              }
              if allCached || !visibleStatuses.contains(where: { $0.id == status.id }) { break }
              try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            //
          }
          
          var idToMark = status.id
          if prefs.hideSeenPostsIncludeBoosts, let reblog = status.reblog {
             idToMark = reblog.id
          }
          
          if !prefs.hideSeenPostsLikedOnly || status.favourited == true || (status.reblog?.favourited == true) {
            SeenPostsManager.shared.markAsSeen(id: idToMark)
            if prefs.hideSeenPostsIncludeBoosts {
              SeenPostsManager.shared.markAsSeen(id: status.id)
            }
            pendingStatusesObserver.updateCount()
          }
        }
      }
    }
  }

  func statusDidDisappear(status: Status) {
    if let count = visibleStatusesCount[status.id] {
      let newCount = count - 1
      if newCount <= 0 {
        visibleStatusesCount.removeValue(forKey: status.id)
        visibleStatuses.removeAll(where: { $0.id == status.id })
      } else {
        visibleStatusesCount[status.id] = newCount
      }
    } else {
      visibleStatuses.removeAll(where: { $0.id == status.id })
    }
  }

  @MainActor
  func hideReadPosts() async {
    exemptFromHideSeen = []
    sessionSeenPosts = SeenPostsManager.shared.seenPosts
    
    if UserPreferences.shared.hideSeenPostsEnabled, !UserPreferences.shared.hideSeenPostsIsToggle {
      await datasource.hideReadPosts(seen: sessionSeenPosts, includeBoosts: UserPreferences.shared.hideSeenPostsIncludeBoosts)
    }
    
    var items = await datasource.getFilteredItems(seen: sessionSeenPosts, exempt: exemptFromHideSeen)
    
    if items.count < 10, let client = client, let lastId = await datasource.get().last?.id {
      do {
        let newStatuses: [Status] = try await statusFetcher.fetchNextPage(
          client: client,
          timeline: timeline,
          lastId: lastId,
          offset: await datasource.get().count)
        let filteredNewStatuses = filterSeenStatuses(from: newStatuses)
        await datasource.append(contentOf: filteredNewStatuses)
        StatusDataControllerProvider.shared.updateDataControllers(for: newStatuses, client: client)
        items = await datasource.getFilteredItems(seen: sessionSeenPosts, exempt: exemptFromHideSeen)
      } catch { }
    }
    withAnimation {
      statusesState = .displayWithGaps(items: items, nextPageState: .hasNextPage) // nextPageState is approximate here
    }
  }

  func loadGap(gap: TimelineGap) async {
    guard let client else { return }

    // Update gap loading state
    await datasource.updateGapLoadingState(id: gap.id, isLoading: true)

    // Update UI to show loading state without causing jumps
    await updateStatusesState()

    do {
      // Fetch statuses within the gap
      let statuses = try await timeline.fetchStatuses(
        client: client,
        sinceId: gap.sinceId.isEmpty ? nil : gap.sinceId,
        maxId: gap.maxId,
        minId: nil,
        offset: 0,
        limit: 50
      )

      StatusDataControllerProvider.shared.updateDataControllers(for: statuses, client: client)

      // Get the original gap index before replacing
      let items = await datasource.getItems()
      let gapIndex = items.firstIndex(where: { item in
        if case .gap(let g) = item {
          return g.id == gap.id
        }
        return false
      })

      // Replace the gap with the fetched statuses
      await datasource.replaceGap(id: gap.id, with: statuses)

      // If we fetched 40 or more statuses, there might be more older statuses
      // Lower threshold because some instances might not return exactly 50
      if statuses.count >= 40, let oldestLoadedStatus = statuses.last,
        let originalGapIndex = gapIndex
      {
        // Create a new gap from the original gap's sinceId to the oldest status we just loaded
        await createGapForOlderStatuses(
          sinceId: gap.sinceId.isEmpty ? nil : gap.sinceId,
          maxId: oldestLoadedStatus.id,
          at: originalGapIndex + statuses.count
        )
      }

      // Update the display
      await updateStatusesStateWithAnimation()
    } catch {
      // If loading fails, reset the gap loading state
      await datasource.updateGapLoadingState(id: gap.id, isLoading: false)
      await refreshTimelineContentFilter()
    }
  }

  // MARK: - Helper Methods


  private func filterSeenStatuses(from statuses: [Status]) -> [Status] {
    // Only permanently discard fetched statuses if we are in fire-and-forget mode.
    // If it's a toggle, we MUST keep them in the datasource so they can reappear when toggled off.
    if UserPreferences.shared.hideSeenPostsEnabled, !UserPreferences.shared.hideSeenPostsIsToggle {
       let seen = SeenPostsManager.shared.seenPosts
       let includeBoosts = UserPreferences.shared.hideSeenPostsIncludeBoosts
       return statuses.filter { status in 
           if seen.contains(status.id) { return false }
           if includeBoosts, let reblog = status.reblog, seen.contains(reblog.id) { return false }
           return true
       }
    }
    return statuses
  }

  private func updateDatasourceAndState(
    statuses: [Status], client: MastodonClient, replaceExisting: Bool
  )
    async
  {
    StatusDataControllerProvider.shared.updateDataControllers(for: statuses, client: client)

    let filteredStatuses = filterSeenStatuses(from: statuses)
    if replaceExisting {
      await datasource.set(filteredStatuses)
    } else {
      await datasource.append(contentOf: filteredStatuses)
    }

    await cache()
    await updateStatusesStateWithAnimation()
  }

  private func updateStatusesState() async {
    let items = await datasource.getFilteredItems(seen: sessionSeenPosts, exempt: exemptFromHideSeen)
    statusesState = .displayWithGaps(items: items, nextPageState: .hasNextPage)
  }

  private func updateStatusesStateWithAnimation() async {
    let items = await datasource.getFilteredItems(seen: sessionSeenPosts, exempt: exemptFromHideSeen)
    withAnimation {
      statusesState = .displayWithGaps(items: items, nextPageState: .hasNextPage)
    }
  }

  private func autoFetchNextPageWhileNoVisibleItems(
    lastFetchedCount: Int,
    pageLimit: Int,
    visibleCountBefore: Int = 0
  ) async -> Int {
    guard lastFetchedCount >= pageLimit else { return lastFetchedCount }
    guard await datasource.getFilteredItems(seen: sessionSeenPosts, exempt: exemptFromHideSeen).count <= visibleCountBefore else { return lastFetchedCount }
    guard let client else { return lastFetchedCount }

    var pagesLoaded = 0
    var lastCount = lastFetchedCount

    while pagesLoaded < Constants.emptyFilterAutoPageLimit,
      lastCount >= Constants.nextPageLimit,
      await datasource.getFilteredItems(seen: sessionSeenPosts, exempt: exemptFromHideSeen).count <= visibleCountBefore
    {
      let statuses = await datasource.get()
      guard let lastId = statuses.last?.id else { break }
      let newStatuses: [Status]
      do {
        newStatuses = try await statusFetcher.fetchNextPage(
          client: client,
          timeline: timeline,
          lastId: lastId,
          offset: statuses.count)
      } catch {
        break
      }
      guard !newStatuses.isEmpty else { break }
      let filteredNewStatuses = filterSeenStatuses(from: newStatuses)
      await datasource.append(contentOf: filteredNewStatuses)
      StatusDataControllerProvider.shared.updateDataControllers(for: newStatuses, client: client)
      lastCount = newStatuses.count
      pagesLoaded += 1
    }

    return lastCount
  }

  private func createGapForOlderStatuses(sinceId: String? = nil, maxId: String, at index: Int) async
  {
    guard !isFullTimelineFetchEnabled else { return }
    let gap = TimelineGap(sinceId: sinceId, maxId: maxId)
    await datasource.insertGap(gap, at: index)
  }
}

// MARK: - Marker handling

extension TimelineViewModel {
  func fetchMarker() async -> Marker.Content? {
    guard let client else {
      return nil
    }
    do {
      let data: Marker = try await client.get(endpoint: Markers.markers)
      return data.home
    } catch {
      return nil
    }
  }

  func saveMarker() {
    guard timeline == .home, let client else { return }
    Task {
      guard let id = await cache.getLatestSeenStatus(for: client, filter: timeline.id)?.first else {
        return
      }
      do {
        let _: Marker = try await client.post(endpoint: Markers.markHome(lastReadId: id))
      } catch {}
    }
  }
}

// MARK: - Stream management

extension TimelineViewModel {
  func canStreamTimeline(_ timeline: TimelineFilter) -> Bool {
    switch timeline {
    case .federated, .local:
      return true
    default:
      return false
    }
  }

  private func updateStreamWatcher() {
    guard let client, client.isAuth else { return }

    let watcher = StreamWatcher.shared
    var streams: [StreamWatcher.Stream] = []

    streams.append(.user)
    streams.append(.direct)

    // Add timeline-specific streams
    if isStreamingTimeline {
      switch timeline {
      case .federated:
        streams.append(.federated)
      case .local:
        streams.append(.local)
      default:
        break
      }
    }

    watcher.stopWatching()
    if !streams.isEmpty {
      watcher.watch(streams: streams)
    }
  }
}

// MARK: - Event handling

extension TimelineViewModel {
  func handleEvent(event: any StreamEvent) async {
    guard let client = client, canStreamEvents else { return }

    switch event {
    case let updateEvent as StreamEventUpdate:
      await handleUpdateEvent(updateEvent, client: client)
    case let deleteEvent as StreamEventDelete:
      await handleDeleteEvent(deleteEvent)
    case let statusUpdateEvent as StreamEventStatusUpdate:
      await handleStatusUpdateEvent(statusUpdateEvent, client: client)
    default:
      break
    }
  }

  private func handleUpdateEvent(_ event: StreamEventUpdate, client: MastodonClient) async {
    let shouldStream =
      switch timeline {
      case .home:
        UserPreferences.shared.streamHomeTimeline
      case .federated, .local:
        isStreamingTimeline
      default:
        false
      }

    guard shouldStream,
      await !datasource.contains(statusId: event.status.id),
      let topStatus = await datasource.get().first,
      topStatus.createdAt.asDate < event.status.createdAt.asDate
    else { return }

    let prefs = UserPreferences.shared
    let isSeen: Bool
    if prefs.hideSeenPostsEnabled {
      var _isSeen = SeenPostsManager.shared.isSeen(id: event.status.id)
      if !_isSeen, prefs.hideSeenPostsIncludeBoosts, let reblog = event.status.reblog {
        _isSeen = SeenPostsManager.shared.isSeen(id: reblog.id)
      }
      if !_isSeen, event.status.account.id == CurrentAccount.shared.account?.id {
        _isSeen = true
      }
      isSeen = _isSeen
    } else {
      isSeen = false
    }
    
    if !isSeen {
      let snapshot = await TimelineContentFilter.shared.snapshot()
      let currentAccountId = await CurrentAccount.shared.account?.id
      
      let isHidden = if let filterContext {
        event.status.isHidden(in: filterContext)
      } else {
        event.status.isHidden
      }
      
      let showReplies = snapshot.showReplies
      let showBoosts = snapshot.showBoosts
      let showThreads = snapshot.showThreads
      let showQuotePosts = snapshot.showQuotePosts
      
      let hasQuote = event.status.quote?.quotedStatusId != nil
        || event.status.quote?.quotedStatus != nil
        || event.status.reblog?.quote?.quotedStatusId != nil
        || event.status.reblog?.quote?.quotedStatus != nil
        
      let hasLegacyQuoteLink = !event.status.content.statusesURLs.isEmpty
        || !(event.status.reblog?.content.statusesURLs.isEmpty ?? true)
        
      let isBotAuthored = event.status.reblog?.account.bot ?? event.status.account.bot
      
      var hideDueToLanguage = false
      if !snapshot.hiddenLanguages.isEmpty, let lang = event.status.language ?? event.status.reblog?.language {
        if snapshot.hiddenLanguages.contains(lang) {
          hideDueToLanguage = true
        }
      }
      
      if !hideDueToLanguage && (snapshot.hiddenLanguages.contains("ja") || snapshot.hiddenLanguages.contains("zh")) {
        let isTextOnly = event.status.mediaAttachments.isEmpty && (event.status.reblog?.mediaAttachments.isEmpty ?? true)
        if isTextOnly {
          let text = event.status.reblog?.content.asRawText ?? event.status.content.asRawText
          if snapshot.hiddenLanguages.contains("ja") && text.range(of: "[\\u3040-\\u309F\\u30A0-\\u30FF]", options: .regularExpression) != nil {
            hideDueToLanguage = true
          } else if snapshot.hiddenLanguages.contains("zh") && text.range(of: "[\\u4E00-\\u9FFF]", options: .regularExpression) != nil {
            hideDueToLanguage = true
          }
        }
      }
      
      let willShow = !isHidden
        && !hideDueToLanguage
        && (showReplies || event.status.inReplyToId == nil || event.status.inReplyToAccountId == event.status.account.id)
        && (showBoosts || event.status.reblog == nil)
        && (showThreads || event.status.inReplyToAccountId != event.status.account.id)
        && (showQuotePosts || (!hasQuote && !hasLegacyQuoteLink))
        && (!snapshot.hidePostsWithMedia || (event.status.mediaAttachments.isEmpty && event.status.reblog?.mediaAttachments.isEmpty ?? true))
        && (!snapshot.hidePostsWithoutMedia || (!event.status.mediaAttachments.isEmpty || event.status.reblog?.mediaAttachments.isEmpty == false))
        && !(snapshot.hidePostsFromBots && isBotAuthored)
        
      var willShowInGallery = true
      if snapshot.isGalleryMode {
         if event.status.mediaAttachments.isEmpty && (event.status.reblog?.mediaAttachments.isEmpty ?? true) {
            willShowInGallery = false
         }
      }
        
      if willShow && willShowInGallery {
        pendingStatusesObserver.pendingStatuses.insert(event.status.id, at: 0)
      }
    }
    await datasource.insert(event.status, at: 0)
    await cache()
    StatusDataControllerProvider.shared.updateDataControllers(for: [event.status], client: client)
    await updateStatusesStateWithAnimation()
  }

  private func handleDeleteEvent(_ event: StreamEventDelete) async {
    if await datasource.remove(event.status) != nil {
      await cache()
      await updateStatusesStateWithAnimation()
    }
  }

  private func handleStatusUpdateEvent(_ event: StreamEventStatusUpdate, client: MastodonClient)
    async
  {
    guard let originalIndex = await datasource.indexOf(statusId: event.status.id) else { return }

    StatusDataControllerProvider.shared.updateDataControllers(for: [event.status], client: client)
    await datasource.replace(event.status, at: originalIndex)
    await cache()
    await updateStatusesStateWithAnimation()
  }
}
