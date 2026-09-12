import Foundation

public struct MisskeyEmoji: Codable {
    public let name: String
    public let url: String
}

public struct MisskeyEmojiContainer: Codable {
    public let emojis: [MisskeyEmoji]

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let arr = try? container.decode([MisskeyEmoji].self) {
            emojis = arr
            return
        }
        if let dict = try? container.decode([String: String].self) {
            emojis = dict.map { MisskeyEmoji(name: $0.key, url: $0.value) }
            return
        }
        emojis = []
    }
}

let json = """
{"emojis": {}}
"""
struct TestObj: Codable {
    let emojis: MisskeyEmojiContainer?
}

do {
    let obj = try JSONDecoder().decode(TestObj.self, from: json.data(using: .utf8)!)
    print("Success: \(obj.emojis?.emojis.count ?? -1)")
} catch {
    print("Error: \(error)")
}
