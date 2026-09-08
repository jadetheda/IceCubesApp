import Foundation
import Models

extension MisskeyNote {
    public func toStatus() -> Status {
        let account = self.user.toAccount()
        let createdAtDate = ISO8601DateFormatter().date(from: self.createdAt) ?? Date()
        
        let favouritesCount = self.reactions.values.reduce(0, +)
        let mediaAttachments = self.files.map { $0.toMediaAttachment() }
        let customEmojis = self.emojis?.map { Emoji(shortcode: $0.name, url: URL(string: $0.url)!, staticUrl: URL(string: $0.url)!, visibleInPicker: false) } ?? []
        
        var reblog: ReblogStatus? = nil
        if let renote = self.renote {
            let renoteCreatedAt = ISO8601DateFormatter().date(from: renote.createdAt) ?? Date()
            reblog = ReblogStatus(
                id: renote.id,
                content: HTMLString(stringValue: renote.text ?? ""),
                account: renote.user.toAccount(),
                createdAt: ServerDate(date: renoteCreatedAt),
                editedAt: nil,
                mediaAttachments: renote.files.map { $0.toMediaAttachment() },
                mentions: [],
                repliesCount: renote.repliesCount,
                reblogsCount: renote.renoteCount,
                favouritesCount: renote.reactions.values.reduce(0, +),
                card: nil,
                favourited: false,
                reblogged: false,
                pinned: false,
                bookmarked: false,
                emojis: [],
                url: "https://misskey/\(renote.id)",
                application: nil,
                inReplyToId: renote.replyId,
                inReplyToAccountId: nil,
                visibility: Status.Visibility(rawValue: renote.visibility) ?? .pub,
                poll: nil,
                spoilerText: HTMLString(stringValue: renote.cw ?? ""),
                filtered: [],
                sensitive: renote.files.contains(where: { $0.isSensitive }),
                language: nil,
                tags: [],
                quote: nil,
                quotesCount: nil,
                quoteApproval: nil
            )
        }
        
        return Status(
            id: self.id,
            content: HTMLString(stringValue: self.text ?? ""),
            account: account,
            createdAt: ServerDate(date: createdAtDate),
            editedAt: nil,
            reblog: reblog,
            mediaAttachments: mediaAttachments,
            mentions: [],
            repliesCount: self.repliesCount,
            reblogsCount: self.renoteCount,
            favouritesCount: favouritesCount,
            card: nil,
            favourited: false,
            reblogged: false,
            pinned: false,
            bookmarked: false,
            emojis: customEmojis,
            url: "https://misskey/\(self.id)",
            application: nil,
            inReplyToId: self.replyId,
            inReplyToAccountId: nil,
            visibility: Status.Visibility(rawValue: self.visibility) ?? .pub,
            poll: nil,
            spoilerText: HTMLString(stringValue: self.cw ?? ""),
            filtered: [],
            sensitive: self.files.contains(where: { $0.isSensitive }),
            language: nil,
            tags: [],
            quote: nil,
            quotesCount: nil,
            quoteApproval: nil
        )
    }
}

extension MisskeyUser {
    public func toAccount() -> Account {
        let avatarURL = URL(string: self.avatarUrl ?? "https://placeholder")!
        let acct = self.host != nil ? "\(self.username)@\(self.host!)" : self.username
        
        return Account(
            id: self.id,
            username: self.username,
            displayName: self.name,
            avatar: avatarURL,
            header: avatarURL,
            acct: acct,
            note: HTMLString(stringValue: ""),
            createdAt: ServerDate(),
            followersCount: 0,
            followingCount: 0,
            statusesCount: 0,
            lastStatusAt: nil,
            fields: [],
            locked: false,
            emojis: [],
            url: URL(string: "https://misskey/\(acct)"),
            bot: self.isBot,
            discoverable: true,
        )
    }
}

extension MisskeyFile {
    public func toMediaAttachment() -> MediaAttachment {
        let url = URL(string: self.url)!
        let preview = self.thumbnailUrl != nil ? URL(string: self.thumbnailUrl!) : url
        
        var type = "image"
        if self.type.contains("video") {
            type = "video"
        } else if self.type.contains("audio") {
            type = "audio"
        }
        
        let meta = MediaAttachment.MetaContainer(
            original: MediaAttachment.MetaContainer.Meta(
                width: self.properties.width,
                height: self.properties.height,
                aspect: nil,
                size: nil,
                duration: nil,
                framerate: nil,
                bitrate: nil
            )
        )
        
        return MediaAttachment(
            id: self.id,
            type: type,
            url: url,
            previewUrl: preview,
            description: self.name,
            meta: meta
        )
    }
}
