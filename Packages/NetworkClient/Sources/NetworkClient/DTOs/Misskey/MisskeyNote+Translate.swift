import Foundation
import Models

nonisolated(unsafe) private let fediverseDateFormatterWithFraction: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
}()

nonisolated(unsafe) private let fediverseDateFormatterStandard: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
}()

internal func parseFediverseDate(_ string: String?) -> Date {
    guard let string = string else { return Date() }
    if let date = fediverseDateFormatterWithFraction.date(from: string) {
        return date
    }
    if let date = fediverseDateFormatterStandard.date(from: string) {
        return date
    }
    return Date()
}

// MARK: - MisskeyNote → Status

extension MisskeyNote {
    public func toStatus(reblogged: Bool = false, server: String = "misskey") -> Status {
        let account = self.user.toAccount(server: server)
        let createdAtDate = parseFediverseDate(self.createdAt)

        let favouritesCount = self.reactions?.values.reduce(0, +) ?? 0
        let favourited = self.myReaction != nil

        let mediaAttachments = self.files?.map { $0.toMediaAttachment() } ?? []
        let customEmojis = self.emojis?.emojis.map {
            Emoji(shortcode: $0.name, url: $0.url, staticUrl: $0.url, visibleInPicker: false)
        } ?? []

        let noteUrl = self.url ?? self.uri ?? "https://\(server)/notes/\(self.id)"

        // Renote without text = boost (reblog). Renote with text = quote post.
        // Misskey-compatible servers do not all agree on whether an empty
        // renote text is encoded as null or an empty string.
        var reblog: ReblogStatus? = nil
        if let renote = self.renote,
           self.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false
        {
            let renoteUrl = renote.url ?? renote.uri ?? "https://\(server)/notes/\(renote.id)"
            let renoteCreatedAt = parseFediverseDate(renote.createdAt)
            reblog = ReblogStatus(
                id: renote.id,
                content: htmlString(from: renote.text, server: server),
                account: renote.user.toAccount(server: server),
                createdAt: ServerDate(date: renoteCreatedAt),
                editedAt: nil,
                mediaAttachments: renote.files?.map { $0.toMediaAttachment() } ?? [],
                mentions: [],
                repliesCount: renote.repliesCount ?? 0,
                reblogsCount: renote.renoteCount ?? 0,
                favouritesCount: renote.reactions?.values.reduce(0, +) ?? 0,
                card: nil,
                favourited: renote.myReaction != nil,
                reblogged: false, // will be handled by UI layer if it's the current user's reblog
                pinned: false,
                bookmarked: false,
                emojis: renote.emojis?.emojis.map {
                    Emoji(shortcode: $0.name, url: $0.url, staticUrl: $0.url, visibleInPicker: false)
                } ?? [],
                url: renoteUrl,
                application: nil,
                inReplyToId: renote.replyId,
                inReplyToAccountId: nil,
                visibility: mapVisibility(renote.visibility),
                poll: renote.poll?.toPoll(noteId: renote.id),
                spoilerText: HTMLString(stringValue: renote.cw ?? ""),
                filtered: [],
                sensitive: renote.files?.contains(where: { $0.isSensitive == true }) ?? false,
                language: nil,
                tags: [],
                quote: nil,
                quotesCount: nil,
                quoteApproval: nil
            )
        }


        return Status(
            id: self.id,
            content: htmlString(from: self.text, server: server),
            account: account,
            createdAt: ServerDate(date: createdAtDate),
            editedAt: nil,
            reblog: reblog,
            mediaAttachments: mediaAttachments,
            mentions: [],
            repliesCount: self.repliesCount ?? 0,
            reblogsCount: self.renoteCount ?? 0,
            favouritesCount: favouritesCount,
            card: nil,
            favourited: favourited,
            reblogged: reblogged,
            pinned: false,
            bookmarked: false,
            emojis: customEmojis,
            url: noteUrl,
            application: nil,
            inReplyToId: self.replyId,
            inReplyToAccountId: nil,
            visibility: mapVisibility(self.visibility),
            poll: self.poll?.toPoll(noteId: self.id),
            spoilerText: HTMLString(stringValue: self.cw ?? ""),
            filtered: [],
            sensitive: self.files?.contains(where: { $0.isSensitive == true }) ?? false,
            language: nil,
            tags: [],
            quote: nil,
            quotesCount: nil,
            quoteApproval: nil
        )
    }

    // Maps Misskey visibility strings to Mastodon-compatible Visibility enum values.
    private func mapVisibility(_ raw: String?) -> Visibility {
        switch raw ?? "public" {
        case "public":    return .pub
        case "home":      return .unlisted
        case "followers": return .priv
        case "specified": return .direct
        default:          return .pub
        }
    }

    // Converts plain Misskey text to HTML and routes it through HTMLString's
    // Codable init(from:), which runs SwiftSoup to convert <br> to real newlines,
    // linkify URLs, and build the markdown string the UI uses for rendering.
    // HTMLString(stringValue:) treats input as plain text — it does NOT parse HTML.
    // Only init(from: Decoder) triggers the SwiftSoup pipeline, so we JSON-decode.
    private func htmlString(from text: String?, server: String) -> HTMLString {
        guard let text, !text.isEmpty else { return HTMLString(stringValue: "") }

        // Convert bare newlines to <br> for the HTML parser.
        var html = text.replacingOccurrences(of: "\n", with: "<br>")

        // Basic URL linkification so links render as tappable.
        let urlPattern = "(https?://[^\\s<>\"]+)"
        if let regex = try? NSRegularExpression(pattern: urlPattern) {
            html = regex.stringByReplacingMatches(
                in: html,
                range: NSRange(html.startIndex..., in: html),
                withTemplate: "<a href=\"$1\">$1</a>"
            )
        }
        
        // Mention linkification
        let mentionPattern = "(^|[\\s<br>])@([a-zA-Z0-9_]+)(?:@([a-zA-Z0-9_-]+(?:\\.[a-zA-Z0-9_-]+)*))?"
        if let regex = try? NSRegularExpression(pattern: mentionPattern) {
            let nsString = html as NSString
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsString.length))
            for match in matches.reversed() {
                let fullMatchRange = match.range
                let prefixRange = match.range(at: 1)
                let usernameRange = match.range(at: 2)
                let domainRange = match.range(at: 3)
                
                let prefix = prefixRange.location != NSNotFound ? nsString.substring(with: prefixRange) : ""
                let username = nsString.substring(with: usernameRange)
                let domain = domainRange.location != NSNotFound ? nsString.substring(with: domainRange) : server
                
                let displayString = domainRange.location != NSNotFound ? "@\(username)@\(domain)" : "@\(username)"
                let replacement = "\(prefix)<a href=\"https://\(domain)/@\(username)\" class=\"u-url mention\">\(displayString)</a>"
                
                html = (html as NSString).replacingCharacters(in: fullMatchRange, with: replacement)
            }
        }

        // Encode the generated HTML as a JSON string so all control characters
        // in user content are escaped before HTMLString's decoder parses it.
        if let data = try? JSONEncoder().encode(html),
           let parsed = try? JSONDecoder().decode(HTMLString.self, from: data) {
            return parsed
        }
        return HTMLString(stringValue: text)
    }

}

// MARK: - MisskeyPoll → Poll
// Poll is Codable-only (no public memberwise init), so we serialize the
// Misskey poll data to JSON and decode it into the Poll model.
extension MisskeyPoll {
    public func toPoll(noteId: String) -> Poll? {
        let totalVotes = choices.reduce(0) { $0 + $1.votes }
        let ownVotes = choices.enumerated().compactMap { index, choice in
            choice.isVoted == true ? index : nil
        }

        // Build a JSON representation that Poll's Codable decoder can read.
        let optionsJson = choices.map { choice in
            """
            {"title":\(jsonString(choice.text)),"votesCount":\(choice.votes)}
            """
        }.joined(separator: ",")

        let expiresAtJson: String
        if let exp = expiresAt {
            expiresAtJson = "\"\(exp)\""
        } else {
            expiresAtJson = "null"
        }

        let ownVotesJson = ownVotes.map { String($0) }.joined(separator: ",")
        let voted = !ownVotes.isEmpty
        let expired = expiresAt != nil

        let json = """
        {
          "id": \(jsonString(noteId)),
          "expiresAt": \(expiresAtJson),
          "expired": \(expired),
          "multiple": \(multiple),
          "votesCount": \(totalVotes),
          "votersCount": \(totalVotes),
          "voted": \(voted),
          "ownVotes": [\(ownVotesJson)],
          "options": [\(optionsJson)]
        }
        """

        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        return try? dec.decode(Poll.self, from: Data(json.utf8))
    }

    private func jsonString(_ s: String) -> String {
        // Minimal JSON string escaping for the poll stub.
        let escaped = s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }
}

// MARK: - MisskeyUser → Account
extension MisskeyUser {
    public func toAccount(server: String = "misskey") -> Account {
        let safeUsername = self.username ?? "unknown"
        let avatarURL = URL(string: self.avatarUrl ?? "https://\(host ?? server)/placeholder.png")
            ?? URL(string: "https://example.com/placeholder.png")!
        let headerURL = URL(string: self.bannerUrl ?? "") ?? avatarURL
        let acct = self.host != nil ? "\(safeUsername)@\(self.host!)" : safeUsername
        let profileURL = URL(string: "https://\(self.host ?? server)/@\(safeUsername)")

        // Account.Field is Codable-only; build JSON and decode.
        var accountFields: [Account.Field] = []
        if let fields = self.fields, !fields.isEmpty {
            let fieldsJson = fields.map { f in
                """
                {"name":\(jsonString(f.name ?? "")),"value":\(jsonString(f.value ?? "")),"verifiedAt":null}
                """
            }.joined(separator: ",")
            let json = "[\(fieldsJson)]"
            if let data = json.data(using: .utf8),
               let decoded = try? JSONDecoder().decode([Account.Field].self, from: data) {
                accountFields = decoded
            }

        }

        let emojiList = self.emojis?.emojis.map {
            Emoji(shortcode: $0.name, url: $0.url, staticUrl: $0.url, visibleInPicker: false)
        } ?? []

        return Account(
            id: self.id,
            username: safeUsername,
            displayName: self.name,
            avatar: avatarURL,
            header: headerURL,
            acct: acct,
            note: HTMLString(stringValue: self.description ?? ""),
            createdAt: ServerDate(),
            followersCount: self.followersCount ?? 0,
            followingCount: self.followingCount ?? 0,
            statusesCount: self.notesCount ?? 0,
            lastStatusAt: nil,
            fields: accountFields,
            locked: self.isLocked ?? false,
            emojis: emojiList,
            url: profileURL,
            bot: self.isBot ?? false,
            discoverable: true
        )
    }

    private func jsonString(_ s: String) -> String {
        let escaped = s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }
}

// MARK: - MisskeyRelation → Relationship
extension MisskeyRelation {
    public func toRelationship() -> Relationship {
        Relationship(
            id: self.id,
            following: self.isFollowing,
            showingReblogs: true,
            followedBy: self.isFollowed,
            blocking: self.isBlocking,
            blockedBy: self.isBlocked,
            muting: self.isMuted,
            mutingNotifications: false,
            requested: self.hasPendingFollowRequestFromYou,
            domainBlocking: false,
            endorsed: false,
            note: "",
            notifying: false
        )
    }
}

// MARK: - MisskeyFile → MediaAttachment
extension MisskeyFile {
    public func toMediaAttachment() -> MediaAttachment {
        let safeUrlStr = self.url ?? "https://example.com/missing.png"
        let url = URL(string: safeUrlStr) ?? URL(string: "https://example.com/missing.png")!
        let preview = self.thumbnailUrl.flatMap { URL(string: $0) } ?? url

        var type = "image"
        let safeType = self.type ?? "image"
        if safeType.contains("video") || safeType.contains("mp4") || safeType.contains("webm") {
            type = "video"
        } else if safeType.contains("audio") {
            type = "audio"
        } else if safeType.contains("gifv") || safeType.contains("gif") {
            type = "gifv"
        }

        let meta = MediaAttachment.MetaContainer(
            original: MediaAttachment.MetaContainer.Meta(
                width: self.properties?.width,
                height: self.properties?.height,
                aspect: nil,
                duration: nil,
                frameRate: nil
            )
        )

        return MediaAttachment(
            id: self.id,
            type: type,
            url: url,
            previewUrl: preview,
            previewRemoteUrl: nil,
            remoteUrl: nil,
            description: self.comment ?? self.name,
            meta: meta
        )
    }
}

// MARK: - MisskeyNotification → Notification
extension MisskeyNotification {
    public func toNotification(server: String = "misskey") -> Models.Notification? {
        guard let user = self.user else { return nil }

        // Map Misskey notification types to their Mastodon equivalents.
        let mappedType: String
        switch self.type ?? "" {
        case "follow":                   mappedType = "follow"
        case "receiveFollowRequest":     mappedType = "follow_request"
        case "followRequestAccepted":    return nil  // no Mastodon equivalent
        case "mention", "reply":         mappedType = "mention"
        case "renote":                   mappedType = "reblog"
        case "quote":                    mappedType = "mention"  // quote is a special mention
        case "reaction":                 mappedType = "favourite"
        case "pollVote", "pollEnded":    mappedType = "poll"
        default:                         mappedType = "mention"
        }

        let createdAtDate = parseFediverseDate(self.createdAt)

        return Models.Notification(
            id: self.id,
            type: mappedType,
            createdAt: ServerDate(date: createdAtDate),
            account: user.toAccount(server: server),
            status: self.note?.toStatus(server: server),
            groupKey: nil
        )
    }
}

extension MisskeyMessagingMessage {
    func toStatus(server: String = "misskey") -> Status {
        Status(
            id: id,
            content: HTMLString(stringValue: text ?? ""),
            account: user.toAccount(server: server),
            createdAt: ServerDate(date: parseFediverseDate(createdAt)),
            editedAt: nil,
            reblog: nil,
            mediaAttachments: [],
            mentions: [],
            repliesCount: 0,
            reblogsCount: 0,
            favouritesCount: 0,
            card: nil,
            favourited: false,
            reblogged: false,
            pinned: false,
            bookmarked: false,
            emojis: [],
            url: nil,
            application: nil,
            inReplyToId: nil,
            inReplyToAccountId: nil,
            visibility: .direct,
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
