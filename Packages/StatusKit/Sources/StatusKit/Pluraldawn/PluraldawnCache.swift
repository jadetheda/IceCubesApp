import Foundation
import Models

public actor PluraldawnCache {
  public static let shared = PluraldawnCache()
  private var cache: [URL: PluraldawnSystem?] = [:]
  private var inFlight: [URL: Task<PluraldawnSystem?, Never>] = [:]

  public func getSystem(for avatarURL: URL) async -> PluraldawnSystem? {
    if let cached = cache[avatarURL] {
      return cached
    }
    if let task = inFlight[avatarURL] {
      return await task.value
    }
    let task = Task<PluraldawnSystem?, Never> {
      await PluraldawnDecoder.decode(from: avatarURL)
    }
    inFlight[avatarURL] = task
    let system = await task.value
    cache[avatarURL] = .some(system)
    inFlight.removeValue(forKey: avatarURL)
    return system
  }
}
