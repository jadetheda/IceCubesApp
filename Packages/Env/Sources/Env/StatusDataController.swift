import Foundation
import Models
import NetworkClient
import Observation
import SwiftUI

@MainActor
public protocol StatusDataControlling {
  var isReblogged: Bool { get set }
  var isBookmarked: Bool { get set }
  var isFavorited: Bool { get set }

  var favoritesCount: Int { get set }
  var reblogsCount: Int { get set }
  var repliesCount: Int { get set }

  func toggleBookmark(remoteStatus: String?) async
  func toggleReblog(remoteStatus: String?) async
  func toggleFavorite(remoteStatus: String?) async
}

@MainActor
public final class StatusDataControllerProvider {
  public static let shared = StatusDataControllerProvider()

  private var cache: [CacheKey: StatusDataController] = [:]

  private struct CacheKey: Hashable {
    let statusId: String
    let client: MastodonClient
  }

  // Persistent storage tracking
  private var favoritedStatuses: Set<String> = []
  private var rebloggedStatuses: Set<String> = []
  private var bookmarkedStatuses: Set<String> = []

  private init() {
    favoritedStatuses = Set(UserDefaults.standard.stringArray(forKey: "user_favorited_statuses_v1") ?? [])
    rebloggedStatuses = Set(UserDefaults.standard.stringArray(forKey: "user_reblogged_statuses_v1") ?? [])
    bookmarkedStatuses = Set(UserDefaults.standard.stringArray(forKey: "user_bookmarked_statuses_v1") ?? [])
  }

  private func saveFavorites() {
    UserDefaults.standard.set(Array(favoritedStatuses), forKey: "user_favorited_statuses_v1")
  }

  private func saveReblogs() {
    UserDefaults.standard.set(Array(rebloggedStatuses), forKey: "user_reblogged_statuses_v1")
  }

  private func saveBookmarks() {
    UserDefaults.standard.set(Array(bookmarkedStatuses), forKey: "user_bookmarked_statuses_v1")
  }

  public func isFavorited(statusId: String) -> Bool {
    favoritedStatuses.contains(statusId)
  }

  public func isReblogged(statusId: String) -> Bool {
    rebloggedStatuses.contains(statusId)
  }

  public func isBookmarked(statusId: String) -> Bool {
    bookmarkedStatuses.contains(statusId)
  }

  public func setFavorited(statusId: String, favorited: Bool) {
    if favorited {
      favoritedStatuses.insert(statusId)
    } else {
      favoritedStatuses.remove(statusId)
    }
    saveFavorites()
  }

  public func setReblogged(statusId: String, reblogged: Bool) {
    if reblogged {
      rebloggedStatuses.insert(statusId)
    } else {
      rebloggedStatuses.remove(statusId)
    }
    saveReblogs()
  }

  public func setBookmarked(statusId: String, bookmarked: Bool) {
    if bookmarked {
      bookmarkedStatuses.insert(statusId)
    } else {
      bookmarkedStatuses.remove(statusId)
    }
    saveBookmarks()
  }

  public func dataController(for status: any AnyStatus, client: MastodonClient)
    -> StatusDataController
  {
    let key = CacheKey(statusId: status.id, client: client)
    if let controller = cache[key] {
      return controller
    }
    let controller = StatusDataController(status: status, client: client)
    cache[key] = controller
    return controller
  }

  public func updateDataControllers(for statuses: [Status], client: MastodonClient) {
    for status in statuses {
      let realStatus: AnyStatus = status.reblog ?? status
      let controller = dataController(for: realStatus, client: client)
      controller.updateFrom(status: realStatus)
    }
  }
}

@MainActor
@Observable public final class StatusDataController: StatusDataControlling {
  private let status: AnyStatus
  private let client: MastodonClient

  public var isReblogged: Bool
  public var isBookmarked: Bool
  public var isFavorited: Bool
  public var content: HTMLString

  public var favoritesCount: Int
  public var reblogsCount: Int
  public var repliesCount: Int
  public var quotesCount: Int

  init(status: AnyStatus, client: MastodonClient) {
    self.status = status
    self.client = client

    let provider = StatusDataControllerProvider.shared
    if let favourited = status.favourited {
      provider.setFavorited(statusId: status.id, favorited: favourited)
      isFavorited = favourited
    } else {
      isFavorited = provider.isFavorited(statusId: status.id)
    }

    if let reblogged = status.reblogged {
      provider.setReblogged(statusId: status.id, reblogged: reblogged)
      isReblogged = reblogged
    } else {
      isReblogged = provider.isReblogged(statusId: status.id)
    }

    if let bookmarked = status.bookmarked {
      provider.setBookmarked(statusId: status.id, bookmarked: bookmarked)
      isBookmarked = bookmarked
    } else {
      isBookmarked = provider.isBookmarked(statusId: status.id)
    }

    reblogsCount = status.reblogsCount
    repliesCount = status.repliesCount
    favoritesCount = status.favouritesCount
    quotesCount = status.quotesCount ?? 0
    content = status.content
  }

  public func updateFrom(status: AnyStatus) {
    let provider = StatusDataControllerProvider.shared
    if let favourited = status.favourited {
      provider.setFavorited(statusId: status.id, favorited: favourited)
      isFavorited = favourited
    } else {
      isFavorited = provider.isFavorited(statusId: status.id)
    }

    if let reblogged = status.reblogged {
      provider.setReblogged(statusId: status.id, reblogged: reblogged)
      isReblogged = reblogged
    } else {
      isReblogged = provider.isReblogged(statusId: status.id)
    }

    if let bookmarked = status.bookmarked {
      provider.setBookmarked(statusId: status.id, bookmarked: bookmarked)
      isBookmarked = bookmarked
    } else {
      isBookmarked = provider.isBookmarked(statusId: status.id)
    }

    reblogsCount = status.reblogsCount
    repliesCount = status.repliesCount
    favoritesCount = status.favouritesCount
    quotesCount = status.quotesCount ?? 0
    content = status.content
  }

  public func toggleFavorite(remoteStatus: String?) async {
    guard client.isAuth else { return }
    isFavorited.toggle()
    let provider = StatusDataControllerProvider.shared
    let id = remoteStatus ?? status.id
    provider.setFavorited(statusId: id, favorited: isFavorited)
    let endpoint = isFavorited ? Statuses.favorite(id: id) : Statuses.unfavorite(id: id)
    withAnimation(.default) {
      favoritesCount += isFavorited ? 1 : -1
    }
    do {
      let status: Status = try await client.post(endpoint: endpoint)
      updateFrom(status: status)
      NotificationCenter.default.post(name: .statusUpdated, object: status)
    } catch {
      isFavorited.toggle()
      provider.setFavorited(statusId: id, favorited: isFavorited)
      favoritesCount += isFavorited ? -1 : 1
    }
  }

  public func toggleReblog(remoteStatus: String?) async {
    guard client.isAuth else { return }
    isReblogged.toggle()
    let provider = StatusDataControllerProvider.shared
    let id = remoteStatus ?? status.id
    provider.setReblogged(statusId: id, reblogged: isReblogged)
    let endpoint = isReblogged ? Statuses.reblog(id: id) : Statuses.unreblog(id: id)
    withAnimation(.default) {
      reblogsCount += isReblogged ? 1 : -1
    }
    do {
      let status: Status = try await client.post(endpoint: endpoint)
      updateFrom(status: status.reblog ?? status)
      NotificationCenter.default.post(name: .statusUpdated, object: status.reblog ?? status)
    } catch {
      isReblogged.toggle()
      provider.setReblogged(statusId: id, reblogged: isReblogged)
      reblogsCount += isReblogged ? -1 : 1
    }
  }

  public func toggleBookmark(remoteStatus: String?) async {
    guard client.isAuth else { return }
    isBookmarked.toggle()
    let provider = StatusDataControllerProvider.shared
    let id = remoteStatus ?? status.id
    provider.setBookmarked(statusId: id, bookmarked: isBookmarked)
    let endpoint = isBookmarked ? Statuses.bookmark(id: id) : Statuses.unbookmark(id: id)
    do {
      let status: Status = try await client.post(endpoint: endpoint)
      updateFrom(status: status)
      NotificationCenter.default.post(name: .statusUpdated, object: status)
    } catch {
      isBookmarked.toggle()
      provider.setBookmarked(statusId: id, bookmarked: isBookmarked)
    }
  }
}
