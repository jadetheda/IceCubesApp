import Env
import Foundation
import Models

actor TimelineDatasource {
  private var items: [TimelineItem] = []
  private var filterContext: Filter.Context?

  var isEmpty: Bool {
    items.isEmpty
  }

  func get() -> [Status] {
    items.compactMap { item in
      if case .status(let status) = item {
        return status
      }
      return nil
    }
  }

  func getItems() -> [TimelineItem] {
    items
  }

  func getFiltered(seen: Set<String>? = nil, exempt: Set<String>? = nil) async -> [Status] {
    let contentFilter = await TimelineContentFilter.shared
    let snapshot = await contentFilter.snapshot()
    let currentAccountId = await CurrentAccount.shared.account?.id

    let actualSeen: Set<String>? = seen

    var filtered: [Status] = []
    var realIds: Set<String> = []
    for item in items {
      guard case .status(let status) = item else { continue }
      let realId = status.reblog?.id ?? status.id
      if !realIds.contains(realId), shouldShowStatus(status, filter: snapshot, seen: actualSeen, currentAccountId: currentAccountId, exempt: exempt) {
        filtered.append(status)
        realIds.insert(realId)
      }
    }
    return filtered
  }

  func getFilteredItems(seen: Set<String>? = nil, exempt: Set<String>? = nil) async -> [TimelineItem] {
    let contentFilter = await TimelineContentFilter.shared
    let snapshot = await contentFilter.snapshot()
    let currentAccountId = await CurrentAccount.shared.account?.id

    let actualSeen = seen

    var filtered: [TimelineItem] = []
    var realIds: Set<String> = []
    for item in items {
      switch item {
      case .gap:
        filtered.append(item)
      case .status(let status):
        let realId = status.reblog?.id ?? status.id
        if !realIds.contains(realId), shouldShowStatus(status, filter: snapshot, seen: actualSeen, currentAccountId: currentAccountId, exempt: exempt) {
          filtered.append(item)
          realIds.insert(realId)
        }
      }
    }
    return filtered
  }

  func getFiltered(using snapshot: TimelineContentFilter.Snapshot, seen: Set<String>? = nil, exempt: Set<String>? = nil) async -> [Status] {
    let currentAccountId = await CurrentAccount.shared.account?.id
    var filtered: [Status] = []
    var realIds: Set<String> = []
    for item in items {
      guard case .status(let status) = item else { continue }
      let realId = status.reblog?.id ?? status.id
      if !realIds.contains(realId), shouldShowStatus(status, filter: snapshot, seen: seen, currentAccountId: currentAccountId, exempt: exempt) {
        filtered.append(status)
        realIds.insert(realId)
      }
    }
    return filtered
  }

  func count() -> Int {
    items.count
  }

  func reset() {
    items = []
  }

  func setFilterContext(_ context: Filter.Context?) {
    filterContext = context
  }

  // MARK: - Status Finding Helpers

  private func findStatusIndex(id: String) -> Int? {
    items.firstIndex(where: { item in
      if case .status(let status) = item {
        return status.id == id || status.reblog?.id == id
      }
      return false
    })
  }

  private func findGapIndex(id: String) -> Int? {
    items.firstIndex(where: { item in
      if case .gap(let gap) = item {
        return gap.id == id
      }
      return false
    })
  }

  // MARK: - Status Operations

  func hideReadPosts(seen: Set<String>, includeBoosts: Bool) async {
    let currentAccountId = await CurrentAccount.shared.account?.id
    items.removeAll { item in
      if case .status(let status) = item {
        if seen.contains(status.id) {
          return true
        }
        if includeBoosts, let reblog = status.reblog, seen.contains(reblog.id) {
          return true
        }
        if status.account.id == currentAccountId {
          return true
        }
        if status.reblogged == true || status.favourited == true || status.reblog?.reblogged == true || status.reblog?.favourited == true {
          return true
        }
      }
      return false
    }
  }

  func indexOf(statusId: String) -> Int? {
    findStatusIndex(id: statusId)
  }

  func contains(statusId: String) -> Bool {
    findStatusIndex(id: statusId) != nil
  }

  func set(_ statuses: [Status]) {
    self.items = statuses.map { .status($0) }
  }

  func setItems(_ items: [TimelineItem]) {
    self.items = items
  }

  func append(_ status: Status) {
    items.append(.status(status))
  }

  func append(contentOf statuses: [Status]) {
    items.append(contentsOf: statuses.map { .status($0) })
  }

  func insert(_ status: Status, at index: Int) {
    items.insert(.status(status), at: index)
  }

  func insert(contentOf statuses: [Status], at index: Int) {
    items.insert(contentsOf: statuses.map { .status($0) }, at: index)
  }

  func remove(after status: Status, safeOffset: Int) {
    guard let index = findStatusIndex(id: status.id) else { return }
    let safeIndex = index + safeOffset
    if items.count > safeIndex {
      items.removeSubrange(safeIndex..<items.endIndex)
    }
  }

  func replace(_ status: Status, at index: Int) {
    if case .status(let oldStatus) = items[index] {
      if oldStatus.id == status.id {
        items[index] = .status(status)
      } else if let oldReblog = oldStatus.reblog, oldReblog.id == status.id {
        let newReblog = ReblogStatus(
          id: status.id, content: status.content, account: status.account, createdAt: status.createdAt, editedAt: status.editedAt,
          mediaAttachments: status.mediaAttachments, mentions: status.mentions, repliesCount: status.repliesCount, reblogsCount: status.reblogsCount,
          favouritesCount: status.favouritesCount, card: status.card, favourited: status.favourited, reblogged: status.reblogged, pinned: status.pinned,
          bookmarked: status.bookmarked, emojis: status.emojis, url: status.url, application: status.application,
          inReplyToId: status.inReplyToId, inReplyToAccountId: status.inReplyToAccountId, visibility: status.visibility, poll: status.poll,
          spoilerText: status.spoilerText, filtered: status.filtered, sensitive: status.sensitive, language: status.language,
          tags: status.tags, quote: status.quote, quotesCount: status.quotesCount, quoteApproval: status.quoteApproval
        )
        let wrapper = Status(
          id: oldStatus.id, content: oldStatus.content, account: oldStatus.account, createdAt: oldStatus.createdAt, editedAt: oldStatus.editedAt,
          reblog: newReblog, mediaAttachments: oldStatus.mediaAttachments, mentions: oldStatus.mentions,
          repliesCount: oldStatus.repliesCount, reblogsCount: oldStatus.reblogsCount, favouritesCount: oldStatus.favouritesCount, card: oldStatus.card, favourited: oldStatus.favourited,
          reblogged: oldStatus.reblogged, pinned: oldStatus.pinned, bookmarked: oldStatus.bookmarked, emojis: oldStatus.emojis, url: oldStatus.url,
          application: oldStatus.application, inReplyToId: oldStatus.inReplyToId, inReplyToAccountId: oldStatus.inReplyToAccountId,
          visibility: oldStatus.visibility, poll: oldStatus.poll, spoilerText: oldStatus.spoilerText, filtered: oldStatus.filtered,
          sensitive: oldStatus.sensitive, language: oldStatus.language, tags: oldStatus.tags, quote: oldStatus.quote, quotesCount: oldStatus.quotesCount,
          quoteApproval: oldStatus.quoteApproval
        )
        items[index] = .status(wrapper)
      } else {
        items[index] = .status(status)
      }
    } else {
      items[index] = .status(status)
    }
  }

  func remove(_ statusId: String) -> Status? {
    guard let index = findStatusIndex(id: statusId),
      case .status(let status) = items.remove(at: index)
    else {
      return nil
    }
    return status
  }

  // MARK: - Gap Operations

  func insertGap(_ gap: TimelineGap, at index: Int) {
    items.insert(.gap(gap), at: index)
  }

  func replaceGap(id: String, with statuses: [Status]) {
    guard let gapIndex = findGapIndex(id: id) else { return }
    items.remove(at: gapIndex)
    items.insert(contentsOf: statuses.map { .status($0) }, at: gapIndex)
  }

  func updateGapLoadingState(id: String, isLoading: Bool) {
    guard let gapIndex = findGapIndex(id: id),
      case .gap(var gap) = items[gapIndex]
    else { return }
    gap.isLoading = isLoading
    items[gapIndex] = .gap(gap)
  }

  // MARK: - Private Helpers

  private func shouldShowStatus(_ status: Status, filter: TimelineContentFilter.Snapshot, seen: Set<String>? = nil, currentAccountId: String? = nil, exempt: Set<String>? = nil) -> Bool {
    let isHidden = if let filterContext {
      status.isHidden(in: filterContext)
    } else {
      status.isHidden
    }
    let showReplies = filter.showReplies
    let showBoosts = filter.showBoosts
    let showThreads = filter.showThreads
    let showQuotePosts = filter.showQuotePosts
    let hasQuote = status.quote?.quotedStatusId != nil
      || status.quote?.quotedStatus != nil
      || status.reblog?.quote?.quotedStatusId != nil
      || status.reblog?.quote?.quotedStatus != nil
    let hasLegacyQuoteLink = !status.content.statusesURLs.isEmpty
      || !(status.reblog?.content.statusesURLs.isEmpty ?? true)

    let isBotAuthored = status.reblog?.account.bot ?? status.account.bot

    let hideSeenPostsIncludeBoosts = filter.hideSeenPostsIncludeBoosts

    var isSeen = seen?.contains(status.id) ?? false
    if hideSeenPostsIncludeBoosts, let reblog = status.reblog {
      if seen?.contains(reblog.id) == true {
        isSeen = true
      }
    }
    if status.account.id == currentAccountId {
      isSeen = true
    }
    if status.reblogged == true || status.favourited == true || status.reblog?.reblogged == true || status.reblog?.favourited == true {
      if let exempt, exempt.contains(status.id) || (status.reblog.map { exempt.contains($0.id) } ?? false) {
        // Exempt from being treated as seen dynamically in this session
      } else {
        isSeen = true
      }
    }
    
    var hideDueToLanguage = false
    if !filter.hiddenLanguages.isEmpty, let lang = status.language ?? status.reblog?.language {
      if filter.hiddenLanguages.contains(lang) {
        hideDueToLanguage = true
      }
    }
    
    if !hideDueToLanguage && (filter.hiddenLanguages.contains("ja") || filter.hiddenLanguages.contains("zh")) {
      let isTextOnly = status.mediaAttachments.isEmpty && (status.reblog?.mediaAttachments.isEmpty ?? true)
      if isTextOnly {
        let text = status.reblog?.content.asRawText ?? status.content.asRawText
        if filter.hiddenLanguages.contains("ja") && text.range(of: "[\\u3040-\\u309F\\u30A0-\\u30FF]", options: .regularExpression) != nil {
          hideDueToLanguage = true
        } else if filter.hiddenLanguages.contains("zh") && text.range(of: "[\\u4E00-\\u9FFF]", options: .regularExpression) != nil {
          hideDueToLanguage = true
        }
      }
    }
    
    return !isHidden
      && !hideDueToLanguage
      && (showReplies || status.inReplyToId == nil
        || status.inReplyToAccountId == status.account.id)
      && (showBoosts || status.reblog == nil)
      && (showThreads || status.inReplyToAccountId != status.account.id)
      && (showQuotePosts || (!hasQuote && !hasLegacyQuoteLink))
      && (!filter.hidePostsWithMedia || (status.mediaAttachments.isEmpty && status.reblog?.mediaAttachments.isEmpty ?? true))
      && (!filter.hidePostsWithoutMedia || (!status.mediaAttachments.isEmpty || status.reblog?.mediaAttachments.isEmpty == false))
      && !(filter.hidePostsFromBots && isBotAuthored)
      && (!filter.hideReadPosts || !isSeen || filter.isGalleryMode)
  }
}
