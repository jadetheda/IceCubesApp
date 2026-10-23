import Combine
import DesignSystem
import Env
import Models
import NaturalLanguage
import NetworkClient
import Observation
import SwiftUI

@MainActor
@Observable public class StatusRowViewModel {
  let status: Status
  // Whether this status is on a remote local timeline (many actions are unavailable if so)
  let isRemote: Bool
  let showActions: Bool
  let textDisabled: Bool
  var useRemoteMedia: Bool = false
  let finalStatus: AnyStatus
  let filterContext: Filter.Context?

  let client: FediverseClient
  let routerPath: RouterPath

  let userFollowedTag: HTMLString.Link?

  private let theme = Theme.shared
  private let userMentionned: Bool

  var isPinned: Bool
  var embeddedStatus: Status?
  var displaySpoiler: Bool = false
  var isEmbedLoading: Bool = false
  var isFiltered: Bool = false

  var translation: Translation?
  var userDismissedTranslation: Bool = false
  var isLoadingTranslation: Bool = false
  var showDeleteAlert: Bool = false
  var showRedraftAlert: Bool = false
  var showAppleTranslation = false
  var preferredTranslationType = TranslationType.useServerIfPossible {
    didSet {
      if oldValue != preferredTranslationType {
        translation = nil
        showAppleTranslation = false
      }
    }
  }

  var deeplTranslationError = false
  var instanceTranslationError = false

  private(set) var actionsAccountsFetched: Bool = false
  var favoriters: [Account] = []
  var rebloggers: [Account] = []
  var quoters: [Account] = []

  var isLoadingRemoteContent: Bool = false
  var localStatusId: String?
  var localStatus: Status?
  
  var isMediaLoaded: Bool = false
  
  var pluraldawnMember: PluraldawnMember? = nil

  var displayDisplayName: HTMLString {
    let enabled = UserPreferences.shared.pluraldawnSupportEnabled
    if enabled {
      if let member = pluraldawnMember {
        return .init(stringValue: member.name)
      }
    }
    return finalStatus.account.cachedDisplayName
  }
  
  var displayAvatarURL: URL? {
    let enabled = UserPreferences.shared.pluraldawnSupportEnabled
    if enabled {
      if let member = pluraldawnMember {
        if member.avatar == "emoji" {
          for rawIndicator in member.emoji {
            let indicator = rawIndicator.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
            let statusEmoji = finalStatus.emojis.first(where: { $0.shortcode == indicator })
            let accountEmoji = finalStatus.account.emojis.first(where: { $0.shortcode == indicator })
            var chosenEmoji = statusEmoji
            if chosenEmoji == nil {
              chosenEmoji = accountEmoji
            }
            if let emoji = chosenEmoji {
              if let url = URL(string: emoji.url) {
                return url
              }
            }
          }
          return finalStatus.account.avatar
        }
        if let avatarURL = member.avatarURL {
          if avatarURL.scheme != nil {
            return avatarURL
          }
        }
        return finalStatus.account.avatar
      }
    }
    return finalStatus.account.avatar
  }
  
  func markMediaLoaded() {
    isMediaLoaded = true
  }

  private var scrollToId = nil as Binding<String?>?

  // The relationship our user has to the author of this post, if available
  var authorRelationship: Relationship? {
    didSet {
      // if we are newly blocking or muting the author, force collapse post so it goes away
      if let relationship = authorRelationship {
        if relationship.blocking || relationship.muting {
          lineLimit = 0
        }
      }
    }
  }

  // used by the button to expand a collapsed post
  var isCollapsed: Bool = true {
    didSet {
      recalcCollapse()
    }
  }

  // number of lines to show, nil means show the whole post
  var lineLimit: Int?
  // post length determining if the post should be collapsed
  @ObservationIgnored
  let collapseThresholdLength: Int = 750
  // number of text lines to show on a collpased post
  @ObservationIgnored
  let collapsedLines: Int = 8
  // user preference, set in init
  @ObservationIgnored
  var collapseLongPosts: Bool = false

  private func recalcCollapse() {
    let hasContentWarning = !status.spoilerText.asRawText.isEmpty
    let showCollapseButton =
      collapseLongPosts && isCollapsed && !hasContentWarning
      && finalStatus.content.asRawText.unicodeScalars.count > collapseThresholdLength
    let newlineLimit = showCollapseButton && isCollapsed ? collapsedLines : nil
    if newlineLimit != lineLimit {
      lineLimit = newlineLimit
    }
  }

  var filter: Filtered? {
    if let filterContext {
      return finalStatus.filteredEntry(matching: filterContext)
    }
    return finalStatus.filtered?.first
  }

  var isThread: Bool {
    status.reblog?.inReplyToId != nil || status.reblog?.inReplyToAccountId != nil
      || status.inReplyToId != nil || status.inReplyToAccountId != nil
  }

  var url: URL? {
    (status.reblog?.url ?? status.url).flatMap(URL.init(string:))
  }

  var photoExportMetadata: PhotoExportMetadata {
    var urlStr: URL? = nil
    if let stringUrl = finalStatus.url {
      urlStr = URL(string: stringUrl)
    }
    let text: String? = finalStatus.content.asRawText
    
    var tagsList: [String]? = nil
    if !finalStatus.tags.isEmpty {
      var extracted = [String]()
      for tag in finalStatus.tags {
        extracted.append(tag.name)
      }
      tagsList = extracted
    }
    
    return PhotoExportMetadata(postUrl: urlStr, postText: text, postTags: tagsList)
  }

  @ViewBuilder
  var backgroundColor: some View {
    if status.visibility == .direct {
      theme.tintColor.opacity(0.15)
    } else if userMentionned {
      theme.secondaryBackgroundColor
    } else {
      theme.primaryBackgroundColor
    }
  }

  func makeDecorativeGradient(startColor: Color, endColor: Color) -> some View {
    LinearGradient(
      stops: [
        .init(color: startColor.opacity(0.2), location: 0.03),
        .init(color: startColor.opacity(0.1), location: 0.06),
        .init(color: startColor.opacity(0.05), location: 0.09),
        .init(color: startColor.opacity(0.02), location: 0.15),
        .init(color: endColor, location: 0.25),
      ],
      startPoint: .topLeading,
      endPoint: .bottomTrailing)
  }

  public init(
    status: Status,
    client: FediverseClient,
    routerPath: RouterPath,
    isRemote: Bool = false,
    showActions: Bool = true,
    textDisabled: Bool = false,
    scrollToId: Binding<String?>? = nil,
    filterContext: Filter.Context? = nil
  ) {
    self.status = status
    finalStatus = status.reblog ?? status
    self.client = client
    self.routerPath = routerPath
    self.isRemote = isRemote
    self.showActions = showActions
    self.textDisabled = textDisabled
    self.useRemoteMedia = UserPreferences.shared.remoteMediaAlwaysForce
    self.scrollToId = scrollToId
    self.filterContext = filterContext
    if let reblog = status.reblog {
      isPinned = reblog.pinned == true
    } else {
      isPinned = status.pinned == true
    }
    if let cached = StatusTranslationCache.shared.get(statusId: finalStatus.id) {
      translation = cached
    }
    if UserPreferences.shared.autoExpandSpoilers {
      displaySpoiler = false
    } else {
      displaySpoiler = !finalStatus.spoilerText.asRawText.isEmpty
    }

    if status.mentions.first(where: { $0.id == CurrentAccount.shared.account?.id }) != nil {
      userMentionned = true
    } else {
      userMentionned = false
    }

    userFollowedTag = finalStatus.content.links.first(where: { link in
      link.type == .hashtag
        && CurrentAccount.shared.tags.contains(where: {
          $0.name.lowercased() == link.title.lowercased()
        })
    })

    isFiltered = filter != nil

    if let url = embededStatusURL() {
      if let embed = StatusEmbedCache.shared.get(url: url) {
        isEmbedLoading = false
        embeddedStatus = embed
      }
    }
    if embeddedStatus == nil {
      if let quotedStatus = finalStatus.quote?.quotedStatus {
        if finalStatus.quote?.state == .accepted {
          embeddedStatus = quotedStatus
        }
      }
    }
    if embeddedStatus == nil {
      if let id = finalStatus.quote?.quotedStatusId {
        if let embed = StatusEmbedCache.shared.get(id: id) {
          isEmbedLoading = false
          embeddedStatus = embed
        }
      }
    }

    collapseLongPosts = UserPreferences.shared.collapseLongPosts
    recalcCollapse()
  }

  func navigateToDetail() {
    if isRemote {
      if let url = URL(string: finalStatus.url ?? "") {
        routerPath.navigate(to: .remoteStatusDetail(url: url))
        return
      }
    }
    routerPath.navigate(to: .statusDetailWithStatus(status: status.reblogAsAsStatus ?? status))
  }

  func navigateToAccountDetail(account: Account) {
    if isRemote {
      if let url = account.url {
        withAnimation {
          isLoadingRemoteContent = true
        }
        Task {
          await routerPath.navigateToAccountFrom(url: url)
          isLoadingRemoteContent = false
        }
        return
      }
    }
    routerPath.navigate(to: .accountDetailWithAccount(account: account))
  }

  func goToParent() {
    guard let id = status.inReplyToId else { return }
    if scrollToId != nil {
      scrollToId?.wrappedValue = id
    } else {
      routerPath.navigate(to: .statusDetail(id: id))
    }
  }

  func loadAuthorRelationship() async {
    let relationships: [Relationship]? = try? await client.get(
      endpoint: Accounts.relationships(ids: [status.reblog?.account.id ?? status.account.id]))
    authorRelationship = relationships?.first
  }

  private func embededStatusURL() -> URL? {
    guard finalStatus.quote == nil else { return nil }
    guard let url = finalStatus.content.statusesURLs.first else { return nil }
    if !StatusEmbedCache.shared.badStatusesURLs.contains(url) {
      if client.hasConnection(with: url) {
        return url
      }
    }
    return nil
  }

  func loadEmbeddedStatus() async {
    let loaded = await loadStatusById()
    if loaded {
      return
    }

    guard embeddedStatus == nil else { return }
    guard let url = embededStatusURL() else {
      if isEmbedLoading {
        isEmbedLoading = false
      }
      return
    }

    if let embed = StatusEmbedCache.shared.get(url: url) {
      isEmbedLoading = false
      embeddedStatus = embed
      return
    }

    do {
      isEmbedLoading = true
      var embed: Status? = nil
      if url.absoluteString.contains(client.server) {
        if let id = Int(url.lastPathComponent) {
          embed = try await client.get(endpoint: Statuses.status(id: String(id)))
        }
      }
      if embed == nil {
        let results: SearchResults = try await client.get(
          endpoint: Search.search(
            query: url.absoluteString,
            type: .statuses,
            offset: 0,
            following: nil),
          forceVersion: .v2)
        embed = results.statuses.first
      }
      if let embed {
        StatusEmbedCache.shared.set(url: url, status: embed)
      } else {
        StatusEmbedCache.shared.badStatusesURLs.insert(url)
      }
      withAnimation {
        embeddedStatus = embed
        isEmbedLoading = false
      }
    } catch {
      isEmbedLoading = false
      StatusEmbedCache.shared.badStatusesURLs.insert(url)
    }
  }

  private func loadStatusById() async -> Bool {
    if embeddedStatus == nil {
      if let id = finalStatus.quote?.quotedStatusId {
        if finalStatus.quote?.quotedStatus == nil {
          isEmbedLoading = true
          if let embed = StatusEmbedCache.shared.get(id: id) {
            embeddedStatus = embed
            isEmbedLoading = false
            return true
          } else if let embed: Status = try? await client.get(endpoint: Statuses.status(id: id)) {
            StatusEmbedCache.shared.set(id: id, status: embed)
            embeddedStatus = embed
            isEmbedLoading = false
            return true
          }
          return false
        }
      }
    }
    return false
  }

  func pin() async {
    guard client.isAuth else { return }
    isPinned = true
    do {
      let status: Status = try await client.post(endpoint: Statuses.pin(id: finalStatus.id))
      updateFromStatus(status: status)
    } catch {
      isPinned = false
    }
  }

  func unPin() async {
    guard client.isAuth else { return }
    isPinned = false
    do {
      let status: Status = try await client.post(endpoint: Statuses.unpin(id: finalStatus.id))
      updateFromStatus(status: status)
    } catch {
      isPinned = true
    }
  }

  func delete() async throws {
    StreamWatcher.shared.emmitDeleteEvent(for: status.id)
    _ = try await client.delete(endpoint: Statuses.status(id: status.id))
  }

  func fetchPluraldawnSystemIfNeeded() async {
    let enabled = UserPreferences.shared.pluraldawnSupportEnabled
    guard enabled else { return }
    let avatarURL = finalStatus.account.avatar
    
    let system = await PluraldawnCache.shared.getSystem(for: avatarURL)
    if let system = system {
      let contentText = finalStatus.content.asRawText
      let spoiler = finalStatus.spoilerText.asRawText
      
      var matched = PluraldawnSystemMatcher.findMatch(
        rawText: contentText,
        mentions: finalStatus.mentions,
        members: system.members
      )
      if matched == nil {
        if !spoiler.isEmpty {
          matched = PluraldawnSystemMatcher.findMatch(
            rawText: spoiler,
            mentions: finalStatus.mentions,
            members: system.members
          )
        }
      }
      if let matched = matched {
        self.pluraldawnMember = matched
      }
    }
  }

  func fetchActionsAccounts() async {
    guard !actionsAccountsFetched else { return }
    do {
      withAnimation(.smooth) {
        actionsAccountsFetched = true
      }
      let favoriters: [Account] = try await client.get(
        endpoint: Statuses.favoritedBy(id: status.id, maxId: nil))
      let rebloggers: [Account] = try await client.get(
        endpoint: Statuses.rebloggedBy(id: status.id, maxId: nil))
      if (finalStatus.quotesCount ?? 0) > 0 {
        if CurrentAccount.shared.account?.id == status.account.id {
          let statuses: [Status] = try await client.get(
            endpoint: Statuses.quotesBy(id: status.id, maxId: nil))
          quoters = statuses.map { $0.account }
        }
      }
      withAnimation(.smooth) {
        self.favoriters = favoriters
        self.rebloggers = rebloggers
        self.quoters = quoters
      }
    } catch {}
  }

  private func updateFromStatus(status: Status) {
    if let reblog = status.reblog {
      isPinned = reblog.pinned == true
    } else {
      isPinned = status.pinned == true
    }
  }

  func getStatusLang() -> String? {
    finalStatus.language
  }

  func translate(userLang: String) async {
    userDismissedTranslation = false
    updatePreferredTranslation()
    if preferredTranslationType == .useApple {
      showAppleTranslation = true
      return
    }

    if preferredTranslationType != .useDeepl {
      await translateWithInstance(userLang: userLang)

      if translation == nil || translation?.content.asRawText.isEmpty == true {
        translation = nil
        await translateWithDeepL(userLang: userLang)
      }
    } else {
      await translateWithDeepL(userLang: userLang)

      if translation == nil || translation?.content.asRawText.isEmpty == true {
        translation = nil
        await translateWithInstance(userLang: userLang)
      }
    }

    var hasShown = false
    #if canImport(_Translation_SwiftUI)
      if translation == nil {
        if #available(iOS 17.4, *) {
          showAppleTranslation = true
          hasShown = true
        }
      }
    #endif

    if !hasShown {
      if translation == nil {
        if preferredTranslationType == .useDeepl {
          deeplTranslationError = true
        } else {
          instanceTranslationError = true
        }
      }
    }
  }

  func translateWithDeepL(userLang: String) async {
    withAnimation {
      isLoadingTranslation = true
    }

    let deepLClient = getDeepLClient()
    let translation = try? await deepLClient.request(
      target: userLang,
      text: finalStatus.content.asRawText)
    withAnimation {
      self.translation = translation
      isLoadingTranslation = false
    }
    if let translation {
      StatusTranslationCache.shared.set(statusId: finalStatus.id, translation: translation)
    }
  }

  func translateWithInstance(userLang: String) async {
    withAnimation {
      isLoadingTranslation = true
    }

    let translation: Translation? = try? await client.post(
      endpoint: Statuses.translate(
        id: finalStatus.id,
        lang: userLang))

    withAnimation {
      self.translation = translation
      isLoadingTranslation = false
    }
    if let translation {
      StatusTranslationCache.shared.set(statusId: finalStatus.id, translation: translation)
    }
  }

  private var autoTranslateTask: Task<Void, Never>?

  func autoTranslateIfNeeded(userLang: String) {
    guard UserPreferences.shared.autoTranslateForeignPosts else { return }
    guard !userDismissedTranslation else { return }
    updatePreferredTranslation()
    guard preferredTranslationType != .useApple else { return }
    guard let statusLang = getStatusLang(), !statusLang.isEmpty, statusLang != userLang else { return }
    guard translation == nil, !isLoadingTranslation else { return }

    if let cached = StatusTranslationCache.shared.get(statusId: finalStatus.id) {
      self.translation = cached
      return
    }

    autoTranslateTask?.cancel()
    autoTranslateTask = Task { @MainActor [weak self] in
      do {
        try await Task.sleep(nanoseconds: 600_000_000)
        guard !Task.isCancelled else { return }
        guard let self else { return }
        guard self.translation == nil else { return }
        await self.translate(userLang: userLang)
      } catch {
        // Cancelled before dwell elapsed
      }
    }
  }

  func cancelAutoTranslate() {
    autoTranslateTask?.cancel()
    autoTranslateTask = nil
  }

  func dismissTranslation() {
    userDismissedTranslation = true
    translation = nil
  }

  private func getDeepLClient() -> DeepLClient {
    let userAPIfree = UserPreferences.shared.userDeeplAPIFree

    return DeepLClient(userAPIKey: userAPIKey, userAPIFree: userAPIfree)
  }

  private var userAPIKey: String? {
    DeepLUserAPIHandler.readKey()
  }

  func updatePreferredTranslation() {
    if DeepLUserAPIHandler.shouldAlwaysUseDeepl {
      preferredTranslationType = .useDeepl
    } else if UserPreferences.shared.preferredTranslationType == .useApple {
      preferredTranslationType = .useApple
    } else {
      preferredTranslationType = .useServerIfPossible
    }
  }

  func fetchRemoteStatus() async -> Bool {
    guard isRemote else { return false }
    guard let remoteStatusURL = URL(string: finalStatus.url ?? "") else { return false }
    isLoadingRemoteContent = true
    let results: SearchResults? = try? await client.get(
      endpoint: Search.search(
        query: remoteStatusURL.absoluteString,
        type: .statuses,
        offset: nil,
        following: nil),
      forceVersion: .v2)
    if let status = results?.statuses.first {
      localStatusId = status.id
      localStatus = status
      isLoadingRemoteContent = false
      return true
    } else {
      isLoadingRemoteContent = false
      return false
    }
  }
}
