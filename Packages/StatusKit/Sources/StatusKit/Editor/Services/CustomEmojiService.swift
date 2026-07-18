import Models
import NetworkClient
import Env

extension StatusEditor {
  @MainActor
  struct CustomEmojiService {
    @MainActor
    protocol Client {
      func fetchCustomEmojis() async throws -> [Emoji]
    }

    func buildCategorizedContainers(from emojis: [Emoji]) -> [CategorizedEmojiContainer] {
      let grouped = emojis.reduce(into: [String: [Emoji]]()) { dict, emoji in
        let category = emoji.category ?? "Custom"
        dict[category, default: []].append(emoji)
      }
      return grouped
        .sorted(by: { lhs, rhs in
          if rhs.key == "Custom" {
            false
          } else if lhs.key == "Custom" {
            true
          } else {
            lhs.key < rhs.key
          }
        })
        .map { key, value in
          CategorizedEmojiContainer(categoryName: key, emojis: value)
        }
    }

    func fetchContainers(client: Client) async throws -> [CategorizedEmojiContainer] {
      let emojis = try await client.fetchCustomEmojis()
      return buildCategorizedContainers(from: emojis)
    }
  }
}

@MainActor
extension MastodonClient: StatusEditor.CustomEmojiService.Client {
  public func fetchCustomEmojis() async throws -> [Emoji] {
    if let cached = await CustomEmojiCache.shared.get(for: server) {
      Task {
        if let newEmojis: [Emoji] = try? await get(endpoint: CustomEmojis.customEmojis) {
          await CustomEmojiCache.shared.set(emojis: newEmojis, for: server)
        }
      }
      return cached
    }
    
    let emojis: [Emoji] = try await get(endpoint: CustomEmojis.customEmojis) ?? []
    await CustomEmojiCache.shared.set(emojis: emojis, for: server)
    return emojis
  }
}
