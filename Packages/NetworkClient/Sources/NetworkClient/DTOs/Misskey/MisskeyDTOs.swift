import Foundation

// MARK: - MisskeyNote
// Mirrors the Misskey note object. All fields that are absent on some servers
// or forks (Firefish, Calckey) are marked optional so decoding never throws.
public final class MisskeyNote: Codable {
    public let id: String
    public let createdAt: String
    public let userId: String
    public let user: MisskeyUser
    public let text: String?
    public let cw: String?
    public let visibility: String
    public let uri: String?         // federation URI (present on remote notes)
    public let url: String?         // web URL for the note
    public let localOnly: Bool?
    public let renoteCount: Int?
    public let repliesCount: Int?
    // reactions is a map of emoji-key → count, e.g. {"👍": 3, ":neocat@.:": 1}
    public let reactions: [String: Int]?
    // reactionEmojis resolves custom emoji shortcodes to image URLs
    public let reactionEmojis: [String: String]?
    // myReaction is set when the authenticated user has reacted to this note
    public let myReaction: String?
    public let emojis: [MisskeyEmoji]?
    public let fileIds: [String]?
    public let files: [MisskeyFile]?
    public let poll: MisskeyPoll?
    public let replyId: String?
    public let renoteId: String?
    public let renote: MisskeyNote?
    // tags is a flat list of hashtag names without the # prefix
    public let tags: [String]?
    // mentions is a list of user IDs mentioned in the note
    public let mentions: [String]?
    public let isHidden: Bool?
}

// MARK: - MisskeyPoll
// Misskey embeds polls directly in the note object.
public struct MisskeyPoll: Codable {
    public let multiple: Bool
    public let expiresAt: String?
    public let choices: [MisskeyPollChoice]
}

public struct MisskeyPollChoice: Codable {
    public let text: String
    public let votes: Int
    public let isVoted: Bool?
}

// MARK: - MisskeyUser
public struct MisskeyUser: Codable {
    public let id: String
    public let name: String?
    public let username: String
    public let host: String?
    public let avatarUrl: String?
    public let avatarBlurhash: String?
    public let bannerUrl: String?
    public let bannerBlurhash: String?
    public let isBot: Bool?
    public let isCat: Bool?
    public let isSuspended: Bool?
    public let isLocked: Bool?
    public let emojis: [MisskeyEmoji]?
    public let onlineStatus: String?
    public let followersCount: Int?
    public let followingCount: Int?
    public let notesCount: Int?
    public let description: String?
    public let fields: [MisskeyField]?
    // Relationship state — present when fetching the authed user's own profile
    // or when using users/relation endpoint
    public let isFollowing: Bool?
    public let isFollowed: Bool?
    public let hasPendingFollowRequestFromYou: Bool?
    public let hasPendingFollowRequestToYou: Bool?
    public let isBlocking: Bool?
    public let isBlocked: Bool?
    public let isMuted: Bool?
}

// MARK: - MisskeyField (profile metadata)
public struct MisskeyField: Codable {
    public let name: String
    public let value: String
}

// MARK: - MisskeyRelation
// Returned by users/relation — gives relationship state for a list of user IDs.
public struct MisskeyRelation: Codable {
    public let id: String
    public let isFollowing: Bool
    public let isFollowed: Bool
    public let hasPendingFollowRequestFromYou: Bool
    public let hasPendingFollowRequestToYou: Bool
    public let isBlocking: Bool
    public let isBlocked: Bool
    public let isMuted: Bool
}

// MARK: - MisskeyFile
public struct MisskeyFile: Codable {
    public let id: String
    public let createdAt: String
    public let name: String?
    public let type: String
    public let md5: String?
    public let size: Int?
    public let isSensitive: Bool?
    public let blurhash: String?
    public let properties: MisskeyFileProperties?
    public let url: String
    public let thumbnailUrl: String?
    public let comment: String?  // alt text / description
}

public struct MisskeyFileProperties: Codable {
    public let width: Int?
    public let height: Int?
}

// MARK: - MisskeyEmoji
public struct MisskeyEmoji: Codable {
    public let name: String
    public let url: String
}

// MARK: - MisskeyFavorite (bookmark)
// Returned by i/favorites — wraps a note.
public struct MisskeyFavorite: Codable {
    public let id: String
    public let note: MisskeyNote
}

// MARK: - MisskeyNotification
public struct MisskeyNotification: Codable {
    public let id: String
    public let createdAt: String
    public let type: String
    public let user: MisskeyUser?
    public let note: MisskeyNote?
    public let reaction: String?
}

// MARK: - MisskeyFollowEntry (users/followers and users/following)
// Both endpoints return objects with a nested user.
public struct MisskeyFollowEntry: Codable {
    public let id: String
    public let follower: MisskeyUser?
    public let followee: MisskeyUser?
}

// MARK: - MisskeyBlockEntry / MisskeyMuteEntry
public struct MisskeyBlockEntry: Codable {
    public let id: String
    public let blockee: MisskeyUser?
}

public struct MisskeyMuteEntry: Codable {
    public let id: String
    public let mutee: MisskeyUser?
}
