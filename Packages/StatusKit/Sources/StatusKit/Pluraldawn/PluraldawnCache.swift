import Foundation
import Models

@globalActor public actor PluraldawnCache {
  public static let shared = PluraldawnCache()
  private var cache: [URL: PluraldawnSystem?] = [:]

  public func getSystem(for avatarURL: URL) async -> PluraldawnSystem? {
    if let cached = cache[avatarURL] {
      return cached
    }
    let system = await PluraldawnDecoder.decode(from: avatarURL)
    cache[avatarURL] = system
    return system
  }
}
