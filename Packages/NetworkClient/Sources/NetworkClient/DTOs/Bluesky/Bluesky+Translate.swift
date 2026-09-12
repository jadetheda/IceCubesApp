import Foundation
import Models

extension FeedViewPost {
    public func toStatus() -> Status {
        let createdAtDate = parseFediverseDate(self.post.indexedAt)
        
        return Status(
            id: self.post.cid,
            content: HTMLString(stringValue: self.post.record.text, parseMarkdown: true),
            account: self.post.author.toAccount(),
            createdAt: ServerDate(date: createdAtDate),
            editedAt: nil,
            reblog: nil,
            mediaAttachments: [],
            mentions: [],
            repliesCount: self.post.replyCount ?? 0,
            reblogsCount: self.post.repostCount ?? 0,
            favouritesCount: self.post.likeCount ?? 0,
            card: nil,
            favourited: false,
            reblogged: false,
            pinned: false,
            bookmarked: false,
            emojis: [],
            url: "https://bsky.app/profile/\(self.post.author.handle)/post/\(self.post.cid.prefix(10))",
            application: nil,
            inReplyToId: nil,
            inReplyToAccountId: nil,
            visibility: .pub,
            poll: nil,
            spoilerText: HTMLString(stringValue: ""),
            filtered: [],
            sensitive: false,
            language: nil,
            tags: [],
            quote: nil,
            quotesCount: nil,
            quoteApproval: nil
        )
    }
}

extension ProfileViewBasic {
    public func toAccount() -> Account {
        let avatarURL = URL(string: self.avatar ?? "https://placeholder")!
        
        return Account(
            id: self.did,
            username: self.handle,
            displayName: self.displayName ?? self.handle,
            avatar: avatarURL,
            header: avatarURL,
            acct: self.handle,
            note: HTMLString(stringValue: ""),
            createdAt: ServerDate(),
            followersCount: 0,
            followingCount: 0,
            statusesCount: 0,
            lastStatusAt: nil,
            fields: [],
            locked: false,
            emojis: [],
            url: URL(string: "https://bsky.app/profile/\(self.handle)"),
            bot: false,
            discoverable: true
        )
    }
}
