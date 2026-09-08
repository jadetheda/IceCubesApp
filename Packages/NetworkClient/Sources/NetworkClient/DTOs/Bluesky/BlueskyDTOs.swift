import Foundation

// Dummy structures to represent ATProtoKit models for translation compilation

public struct FeedViewPost {
    public let post: PostView
}

public struct PostView {
    public let cid: String
    public let uri: String
    public let author: ProfileViewBasic
    public let record: PostRecord
    public let replyCount: Int?
    public let repostCount: Int?
    public let likeCount: Int?
    public let indexedAt: String
}

public struct ProfileViewBasic {
    public let did: String
    public let handle: String
    public let displayName: String?
    public let avatar: String?
}

public struct PostRecord {
    public let text: String
    public let createdAt: String
}
