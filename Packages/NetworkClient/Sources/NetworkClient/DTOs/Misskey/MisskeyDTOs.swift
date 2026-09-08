import Foundation

public final class MisskeyNote: Codable {
    public let id: String
    public let createdAt: String
    public let userId: String
    public let user: MisskeyUser
    public let text: String?
    public let cw: String?
    public let visibility: String
    public let renoteCount: Int
    public let repliesCount: Int
    public let reactions: [String: Int]
    public let emojis: [MisskeyEmoji]?
    public let fileIds: [String]
    public let files: [MisskeyFile]
    public let replyId: String?
    public let renoteId: String?
    public let renote: MisskeyNote?
}

public struct MisskeyUser: Codable {
    public let id: String
    public let name: String?
    public let username: String
    public let host: String?
    public let avatarUrl: String?
    public let avatarBlurhash: String?
    public let isBot: Bool
    public let isCat: Bool
    public let emojis: [MisskeyEmoji]?
    public let onlineStatus: String?
    public let followersCount: Int?
    public let followingCount: Int?
    public let notesCount: Int?
    public let description: String?
    public let isLocked: Bool?
}

public struct MisskeyFile: Codable {
    public let id: String
    public let createdAt: String
    public let name: String
    public let type: String
    public let md5: String
    public let size: Int
    public let isSensitive: Bool
    public let blurhash: String?
    public let properties: MisskeyFileProperties
    public let url: String
    public let thumbnailUrl: String?
}

public struct MisskeyFileProperties: Codable {
    public let width: Int?
    public let height: Int?
}

public struct MisskeyEmoji: Codable {
    public let name: String
    public let url: String
}

public struct MisskeyNotification: Codable {
    public let id: String
    public let createdAt: String
    public let type: String
    public let user: MisskeyUser?
    public let note: MisskeyNote?
    public let reaction: String?
}
