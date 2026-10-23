import Foundation
import Models

@MainActor
public final class StatusTranslationCache {
  public static let shared = StatusTranslationCache()
  private var cache: [String: Translation] = [:]

  private init() {}

  public func get(statusId: String) -> Translation? {
    cache[statusId]
  }

  public func set(statusId: String, translation: Translation) {
    cache[statusId] = translation
  }

  public func clear() {
    cache.removeAll()
  }
}
