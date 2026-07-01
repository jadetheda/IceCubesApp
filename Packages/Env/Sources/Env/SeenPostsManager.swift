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
  private var seenPostsQueue: [String] = []

  private init() {
    load()
  }

  public func isSeen(id: String) -> Bool {
    seenPosts.contains(id)
  }

  public func markAsSeen(id: String) {
    guard !seenPosts.contains(id) else { return }
    seenPosts.insert(id)
    seenPostsQueue.append(id)
    trimIfNeeded()
    scheduleSave()
  }

  public func markAsSeen(ids: [String]) {
    var hasNew = false
    for id in ids {
      if !seenPosts.contains(id) {
        seenPosts.insert(id)
        seenPostsQueue.append(id)
        hasNew = true
      }
    }
    if hasNew {
      trimIfNeeded()
      scheduleSave()
    }
  }

  public func clear() {
    seenPosts.removeAll()
    seenPostsQueue.removeAll()
    save()
  }

  private func trimIfNeeded() {
    if seenPostsQueue.count > maxSeenPosts {
      let excess = seenPostsQueue.count - maxSeenPosts
      let toRemove = seenPostsQueue.prefix(excess)
      seenPostsQueue.removeFirst(excess)
      for id in toRemove {
        seenPosts.remove(id)
      }
    }
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
    UserDefaults.standard.set(seenPostsQueue, forKey: userDefaultsKey)
  }

  private func load() {
    if let saved = UserDefaults.standard.array(forKey: userDefaultsKey) as? [String] {
      seenPostsQueue = saved
      seenPosts = Set(saved)
    }
  }
}
