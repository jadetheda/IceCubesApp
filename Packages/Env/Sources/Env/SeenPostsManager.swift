import Foundation
import Models
import Observation
import SwiftUI

@MainActor
@Observable
public class SeenPostsManager {
  public static let shared = SeenPostsManager()

  private let userDefaultsKey = "seen_posts_ids"
  private let maxSeenPosts = 5000

  public private(set) var seenPosts: Set<String> = []

  private init() {
    load()
  }

  public func isSeen(id: String) -> Bool {
    seenPosts.contains(id)
  }

  public func markAsSeen(id: String) {
    guard !seenPosts.contains(id) else { return }
    seenPosts.insert(id)
    scheduleSave()
  }

  public func markAsSeen(ids: [String]) {
    var hasNew = false
    for id in ids {
      if !seenPosts.contains(id) {
        seenPosts.insert(id)
        hasNew = true
      }
    }
    if hasNew {
      scheduleSave()
    }
  }

  public func clear() {
    seenPosts.removeAll()
    save()
  }

  private var saveTask: Task<Void, Never>?

  private func scheduleSave() {
    saveTask?.cancel()
    saveTask = Task {
      try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds debounce
      guard !Task.isCancelled else { return }
      save()
    }
  }

  private func save() {
    // If the set grows too large, trim it
    var arrayToSave = Array(seenPosts)
    if arrayToSave.count > maxSeenPosts {
      // Just keep the last maxSeenPosts
      arrayToSave = Array(arrayToSave.prefix(maxSeenPosts))
      seenPosts = Set(arrayToSave)
    }
    UserDefaults.standard.set(arrayToSave, forKey: userDefaultsKey)
  }

  private func load() {
    if let saved = UserDefaults.standard.array(forKey: userDefaultsKey) as? [String] {
      seenPosts = Set(saved)
    }
  }
}
