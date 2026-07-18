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
}
