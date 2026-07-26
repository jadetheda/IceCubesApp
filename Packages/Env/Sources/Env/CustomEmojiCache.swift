import Models
import NetworkClient
import Foundation

public actor CustomEmojiCache {
  public static let shared = CustomEmojiCache()
  
  private let decoder = JSONDecoder()
  private let encoder = JSONEncoder()
  
  private init() {}
  
  private func fileURL(for client: String) -> URL {
    let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    return directory.appendingPathComponent("CustomEmojis-\(client).json")
  }
  
  public func get(for client: String) async -> [Emoji]? {
    let url = fileURL(for: client)
    do {
      let data = try Data(contentsOf: url)
      return try decoder.decode([Emoji].self, from: data)
    } catch {
      return nil
    }
  }
  
  public func set(emojis: [Emoji], for client: String) async {
    let url = fileURL(for: client)
    do {
      let data = try encoder.encode(emojis)
      try data.write(to: url)
    } catch {}
  }

  public func cachedEmojisCount(for client: String) async -> Int {
    let url = fileURL(for: client)
    do {
      let data = try Data(contentsOf: url)
      let emojis = try decoder.decode([Emoji].self, from: data)
      return emojis.count
    } catch {
      return 0
    }
  }

  public func clearCache(for client: String) async {
    let url = fileURL(for: client)
    try? FileManager.default.removeItem(at: url)
  }

  public func cachedEmojisCount() async -> Int {
    let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    do {
      let content = try FileManager.default.contentsOfDirectory(
        at: directory, includingPropertiesForKeys: nil)
      var total = 0
      for fileURL in content {
        if fileURL.lastPathComponent.hasPrefix("CustomEmojis-") && fileURL.pathExtension == "json" {
          if let data = try? Data(contentsOf: fileURL),
             let emojis = try? decoder.decode([Emoji].self, from: data) {
            total += emojis.count
          }
        }
      }
      return total
    } catch {
      return 0
    }
  }

  public func clearCache() async {
    let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    do {
      let content = try FileManager.default.contentsOfDirectory(
        at: directory, includingPropertiesForKeys: nil)
      for fileURL in content {
        if fileURL.lastPathComponent.hasPrefix("CustomEmojis-") && fileURL.pathExtension == "json" {
          try? FileManager.default.removeItem(at: fileURL)
        }
      }
    } catch {}
  }
}
