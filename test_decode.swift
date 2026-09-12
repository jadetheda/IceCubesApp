import Foundation

public struct MisskeyField: Codable {
    public let name: String?
    public let value: String?
}

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

public struct MisskeyUser: Codable {
    public let id: String
    public let name: String?
    public let username: String?
    public let host: String?
    public let avatarUrl: String?
    public let avatarBlurhash: String?
    public let bannerUrl: String?
    public let bannerBlurhash: String?
    public let isBot: Bool?
    public let isCat: Bool?
    public let isSuspended: Bool?
    public let isLocked: Bool?
    public let emojis: MisskeyEmojiContainer?
    public let onlineStatus: String?
    public let followersCount: Int?
    public let followingCount: Int?
    public let notesCount: Int?
    public let description: String?
    public let fields: [MisskeyField]?
    public let isFollowing: Bool?
    public let isFollowed: Bool?
    public let hasPendingFollowRequestFromYou: Bool?
    public let hasPendingFollowRequestToYou: Bool?
    public let isBlocking: Bool?
    public let isBlocked: Bool?
    public let isMuted: Bool?
}

let json = """
{"id":"7rkr2cvs0v","name":"Misskey.io","username":"admin","host":null,"avatarUrl":"https://proxy.misskeyusercontent.jp/avatar.webp?url=https%3A%2F%2Fmedia.misskeyusercontent.jp%2Fmisskey%2Fpdg1%2F2b35a75c-0a71-4085-b16f-3cd441eddf1b.png&avatar=1","avatarBlurhash":null,"avatarDecorations":[],"isBot":false,"isCat":false,"emojis":{},"onlineStatus":"unknown","badgeRoles":[{"name":"Verified","iconUrl":"https://media.misskeyusercontent.jp/misskey/8df80984-86f9-4cc5-a289-1f6ab59c74b8.png","displayOrder":1000}],"url":null,"uri":null,"movedTo":null,"alsoKnownAs":null,"createdAt":"2019-04-14T17:10:54.904Z","updatedAt":"2023-04-16T19:53:45.684Z","lastFetchedAt":null,"bannerUrl":"https://media.misskeyusercontent.jp/misskey/pdg1/ed65e0b7-5520-45f0-9b7d-1adaec64c8f3.png","bannerBlurhash":null,"isLocked":false,"isSilenced":false,"isLimited":false,"isSuspended":false,"description":null,"location":null,"birthday":null,"lang":null,"fields":[],"verifiedLinks":[],"mutualLinkSections":[],"followersCount":379,"followingCount":4,"notesCount":13,"pinnedNoteIds":[],"pinnedNotes":[],"pinnedPageId":null,"pinnedPage":null,"publicReactions":false,"followersVisibility":"public","followingVisibility":"public","chatScope":"mutual","canChat":false,"roles":[{"id":"9bfaar72jh","name":"Verified","color":"#1B9CFC","iconUrl":"https://media.misskeyusercontent.jp/misskey/8df80984-86f9-4cc5-a289-1f6ab59c74b8.png","description":"運営によって公式の可能性が高いと判断されたアカウント","isModerator":false,"isAdministrator":false,"displayOrder":1000},{"id":"al7u4u428j9803hn","name":"8年生","color":null,"iconUrl":null,"description":"Misskey.ioを使い始めて7年経過\\nドライブの容量が34GBに","isModerator":false,"isAdministrator":false,"displayOrder":0}],"memo":null}
"""

do {
    let user = try JSONDecoder().decode(MisskeyUser.self, from: json.data(using: .utf8)!)
    print("Success: \(user.id)")
} catch {
    print("Error:", error)
}
