import Foundation
import Models

public actor PluraldawnCache {
  public static let shared = PluraldawnCache()
  private let maxEntries = 1000
  private var cache: [URL: PluraldawnSystem?] = [:]
  private var keysQueue: [URL] = []
  private var inFlight: [URL: Task<(system: PluraldawnSystem?, shouldCache: Bool), Never>] = [:]

  public func getSystem(for avatarURL: URL) async -> PluraldawnSystem? {
    if let cached = cache[avatarURL] {
      return cached
    }
    if let task = inFlight[avatarURL] {
      return await task.value.system
    }
    let task = Task<(system: PluraldawnSystem?, shouldCache: Bool), Never> {
      await PluraldawnDecoder.decodeWithStatus(from: avatarURL)
    }
    inFlight[avatarURL] = task
    let result = await task.value
    inFlight.removeValue(forKey: avatarURL)
    if result.shouldCache {
      if cache[avatarURL] == nil {
        keysQueue.append(avatarURL)
        if keysQueue.count > maxEntries {
          let evicted = keysQueue.removeFirst()
          cache.removeValue(forKey: evicted)
        }
      }
      cache[avatarURL] = .some(result.system)
    }
    return result.system
  }
}
