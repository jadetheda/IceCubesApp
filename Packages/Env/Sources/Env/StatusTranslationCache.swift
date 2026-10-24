import Foundation
import Models

@MainActor
public final class StatusTranslationCache {
  public static let shared = StatusTranslationCache()
  private var cache: [String: Translation] = [:]
  private var order: [String] = []
  private let maxCapacity = 500

  private init() {}

  public func get(statusId: String) -> Translation? {
    cache[statusId]
  }

  public func set(statusId: String, translation: Translation) {
    if cache[statusId] == nil {
      order.append(statusId)
      if order.count > maxCapacity {
        let oldest = order.removeFirst()
        cache.removeValue(forKey: oldest)
      }
    }
    cache[statusId] = translation
  }

  public func clear() {
    cache.removeAll()
    order.removeAll()
  }
}
