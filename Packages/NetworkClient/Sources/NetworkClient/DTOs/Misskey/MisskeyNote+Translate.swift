import Foundation
import Models

// MARK: - MisskeyNote → Status

extension MisskeyNote {
    public func toStatus() -> Status {
        let account = self.user.toAccount()
        let createdAtDate = ISO8601DateFormatter().date(from: self.createdAt) ?? Date()

        // Sum all reaction counts for the favourites counter.
        let favouritesCount = self.reactions?.values.reduce(0, +) ?? 0

        // favourited is true when the authenticated user has placed any reaction.
        let favourited = self.myReaction != nil

        let mediaAttachments = self.files?.map { $0.toMediaAttachment() } ?? []
        let customEmojis = self.emojis?.emojis.map {
            Emoji(shortcode: $0.name, url: $0.url, staticUrl: $0.url, visibleInPicker: false)
        } ?? []

        // Build the canonical URL for this note. Prefer the explicit url field, then uri,
        // then construct a fallback from the note ID.
        let noteUrl = self.url ?? self.uri ?? "https://misskey/\(self.id)"

        // Renote without text = boost (reblog). Renote with text = quote post.
        var reblog: ReblogStatus? = nil
        if let renote = self.renote, self.text == nil {
            let renoteUrl = renote.url ?? renote.uri ?? "https://misskey/\(renote.id)"
            let renoteCreatedAt = ISO8601DateFormatter().date(from: renote.createdAt) ?? Date()
            reblog = ReblogStatus(
                id: renote.id,
                content: HTMLString(stringValue: renote.text ?? ""),
                account: renote.user.toAccount(),
                createdAt: ServerDate(date: renoteCreatedAt),
                editedAt: nil,
                mediaAttachments: renote.files?.map { $0.toMediaAttachment() } ?? [],
                mentions: [],
                repliesCount: renote.repliesCount ?? 0,
                reblogsCount: renote.renoteCount ?? 0,
                favouritesCount: renote.reactions?.values.reduce(0, +) ?? 0,
                card: nil,
                favourited: renote.myReaction != nil,
                reblogged: false,
                pinned: false,
                bookmarked: false,
                emojis: [],
                url: renoteUrl,
                application: nil,
                inReplyToId: renote.replyId,
                inReplyToAccountId: nil,
                visibility: mapVisibility(renote.visibility),
                poll: nil,
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
            content: HTMLString(stringValue: formatContent(self.text)),
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
            reblogged: false,
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
    private func mapVisibility(_ raw: String) -> Visibility {
        switch raw {
        case "public":    return .pub
        case "home":      return .unlisted
        case "followers": return .priv
        case "specified": return .direct
        default:          return .pub
        }
    }

    // Converts plain Misskey text to basic HTML matching what Mastodon sends.
    // Uses <br> for linebreaks. Does NOT wrap in <p> — the app's HTML renderer
    // handles paragraph spacing and wrapping in <p> causes literal tag text.
    private func formatContent(_ text: String?) -> String {
        guard let text, !text.isEmpty else { return "" }
        var content = text
        // Convert newlines to HTML line breaks.
        content = content.replacingOccurrences(of: "\n", with: "<br>")
        // Basic URL linkification.
        let urlPattern = "(https?://[^\\s<>\"]+)"
        if let regex = try? NSRegularExpression(pattern: urlPattern) {
            content = regex.stringByReplacingMatches(
                in: content,
                range: NSRange(content.startIndex..., in: content),
                withTemplate: "<a href=\"$1\">$1</a>"
            )
        }
        return content
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
    public func toAccount() -> Account {
        let avatarURL = URL(string: self.avatarUrl ?? "https://\(host ?? "example.com")/placeholder.png")
            ?? URL(string: "https://example.com/placeholder.png")!
        let headerURL = URL(string: self.bannerUrl ?? "") ?? avatarURL
        let acct = self.host != nil ? "\(self.username)@\(self.host!)" : self.username
        let profileURL = URL(string: "https://\(self.host ?? "misskey")/\(self.username)")

        // Account.Field is Codable-only; build JSON and decode.
        var accountFields: [Account.Field] = []
        if let fields = self.fields, !fields.isEmpty {
            let fieldsJson = fields.map { f in
                """
                {"name":\(jsonString(f.name)),"value":\(jsonString(f.value)),"verifiedAt":null}
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
            username: self.username,
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
        let url = URL(string: self.url)!
        let preview = self.thumbnailUrl.flatMap { URL(string: $0) } ?? url

        var type = "image"
        if self.type.contains("video") || self.type.contains("mp4") || self.type.contains("webm") {
            type = "video"
        } else if self.type.contains("audio") {
            type = "audio"
        } else if self.type.contains("gifv") || self.type.contains("gif") {
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
    public func toNotification() -> Models.Notification? {
        guard let user = self.user else { return nil }

        // Map Misskey notification types to their Mastodon equivalents.
        let mappedType: String
        switch self.type {
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

        let createdAtDate = ISO8601DateFormatter().date(from: self.createdAt) ?? Date()

        return Models.Notification(
            id: self.id,
            type: mappedType,
            createdAt: ServerDate(date: createdAtDate),
            account: user.toAccount(),
            status: self.note?.toStatus(),
            groupKey: nil
        )
    }
}
