import Foundation
import Models

// MisskeyBackend translates the Mastodon-shaped API calls from FediverseClient into
// Misskey's POST-body JSON API, mapping responses back into the shared Models types
// so the rest of the app remains completely unaware of the protocol differences.
//
// Endpoints that have no Misskey equivalent return safe stubs (empty arrays, mock
// objects decoded from hardcoded JSON) so the UI never throws on unsupported features.
public final class MisskeyBackend: FediverseBackend {

    // MARK: - NoteCreate response wrapper
    // Misskey's notes/create returns { "createdNote": { ... } } rather than the note directly.
    struct NoteCreateResponse: Decodable {
        let createdNote: MisskeyNote
    }

    // MARK: - FediverseBackend properties
    public let server: String
    public let version: FediverseClient.Version
    public let oauthToken: OauthToken?

    public var isAuth: Bool { oauthToken != nil }
    /// Misskey is never an IceShrimp instance, so workarounds are always disabled.
    public var isIceShrimpWorkaroundsEnabled: Bool { false }
    public var capabilities: ServerCapabilities {
        ServerCapabilities(
            supportsAdvancedFilterContexts: false,
            supportsEndorsements: false,
            supportsLocalTimeline: true,
            supportsPolls: true,
            supportsFollowRequests: true,
            supportsCustomEmojis: true
        )
    }

    public init(server: String, version: FediverseClient.Version = .v1, oauthToken: OauthToken? = nil) {
        self.server = server
        self.version = version
        self.oauthToken = oauthToken
    }

    public func addConnections(_ connections: [String]) {}
    public func hasConnection(with url: URL) -> Bool { false }

    // MARK: - MiAuth OAuth flow
    // Misskey uses MiAuth rather than OAuth2. We generate a session UUID, redirect
    // the user to /miauth/<uuid>, then exchange the session for a token on callback.
    nonisolated(unsafe) private static var currentSessionId: String?

    public func oauthURL() async throws -> URL {
        let sessionId = UUID().uuidString
        Self.currentSessionId = sessionId

        let permissions = "read:account,write:account,read:blocks,write:blocks,read:drive,write:drive,read:favorites,write:favorites,read:following,write:following,read:mutes,write:mutes,write:notes,read:notifications,write:notifications,read:reactions,write:reactions,write:votes"
        let appName = "IceCubesApp".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "IceCubesApp"
        let callback = AppInfo.scheme.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? AppInfo.scheme

        let urlString = "https://\(server)/miauth/\(sessionId)?name=\(appName)&callback=\(callback)&permission=\(permissions)"
        if let url = URL(string: urlString) {
            return url
        }
        throw FediverseClient.OauthError.missingApp
    }

    public func continueOauthFlow(url: URL) async throws -> OauthToken {
        guard let sessionId = Self.currentSessionId else {
            throw FediverseClient.OauthError.missingApp
        }

        let requestUrl = URL(string: "https://\(server)/api/miauth/\(sessionId)/check")!
        var request = URLRequest(url: requestUrl)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, _) = try await URLSession.shared.data(for: request)

        struct MiAuthResponse: Decodable {
            let token: String
        }

        let response = try JSONDecoder().decode(MiAuthResponse.self, from: data)
        return OauthToken(accessToken: response.token, tokenType: "Bearer", scope: "", createdAt: Date().timeIntervalSince1970)
    }

    // MARK: - Misskey request helper
    // All Misskey API calls are POST requests with a JSON body. Authentication is
    // passed as an "i" field in the body rather than a header.
    private func makeMisskeyRequest(path: String, params: [String: Any]) async throws -> Data {
        let url = URL(string: "https://\(server)/api/\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        var bodyParams = params
        if let token = oauthToken?.accessToken {
            bodyParams["i"] = token
        }

        request.httpBody = try? JSONSerialization.data(withJSONObject: bodyParams)
        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            print("[MisskeyBackend] API error \(httpResponse.statusCode): \(String(data: data, encoding: .utf8) ?? "")")
        }

        return data
    }

    // MARK: - Param extraction
    // Converts Mastodon-style query items and JSON bodies into the Misskey param dict.
    private func extractParams(from endpoint: Endpoint) -> [String: Any] {
        var params: [String: Any] = [:]

        if let queryItems = endpoint.queryItems() {
            for item in queryItems {
                if let value = item.value {
                    if item.name == "max_id" { params["untilId"] = value }
                    else if item.name == "since_id" { params["sinceId"] = value }
                    else if item.name == "limit" { params["limit"] = Int(value) ?? 20 }
                    else if item.name.hasSuffix("[]") {
                        var arr = params[item.name] as? [String] ?? []
                        arr.append(value)
                        params[item.name] = arr
                    } else {
                        params[item.name] = value
                    }
                }
            }
        }

        if let jsonValue = endpoint.jsonValue,
           let data = try? JSONEncoder().encode(jsonValue),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // Map common Mastodon post fields to their Misskey equivalents.
            if let status = dict["status"] as? String { params["text"] = status }
            if let visibility = dict["visibility"] as? String { params["visibility"] = visibility }
            if let inReplyToId = dict["inReplyToId"] as? String { params["replyId"] = inReplyToId }
            if let mediaIds = dict["mediaIds"] as? [String] { params["fileIds"] = mediaIds }
            if let cw = dict["spoilerText"] as? String, !cw.isEmpty { params["cw"] = cw }
            if let renoteId = dict["quotedStatusId"] as? String { params["renoteId"] = renoteId }
        }
        return params
    }

    // MARK: - Stubs
    // Several Mastodon types have no public memberwise initializer (they are Codable-only).
    // We decode these from hardcoded JSON stubs so the app never crashes on stub paths.

    private func stubTag(name: String, following: Bool = false) -> Tag? {
        let json = """
        {"name":"\(name)","url":"https://\(server)/tags/\(name)","history":[],"following":\(following)}
        """
        return try? JSONDecoder().decode(Tag.self, from: Data(json.utf8))
    }

    private func stubNotificationsPolicy() -> NotificationsPolicy? {
        let json = """
        {"for_not_following":"accept","for_not_followers":"accept","for_new_accounts":"accept","for_private_mentions":"accept","for_limited_accounts":"accept","summary":{"pending_requests_count":0,"pending_notifications_count":0}}
        """
        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        return try? dec.decode(NotificationsPolicy.self, from: Data(json.utf8))
    }

    private func stubInstance() -> Instance {
        Instance(
            title: "Misskey",
            domain: server,
            description: nil,
            shortDescription: nil,
            version: "1.0",
            apiVersions: nil,
            stats: nil,
            usage: nil,
            languages: [],
            registrations: .init(enabled: true),
            thumbnail: .init(url: nil),
            configuration: .init(
                statuses: .init(maxCharacters: 3000, maxMediaAttachments: 16),
                polls: .init(maxOptions: 10, maxCharactersPerOption: 50, minExpiration: 300, maxExpiration: 2592000),
                urls: nil
            ),
            rules: [],
            urls: nil,
            contact: .init(account: nil, email: "")
        )
    }

    private func emptyRelationship(id: String) -> Relationship {
        Relationship(
            id: id, following: false, showingReblogs: false,
            followedBy: false, blocking: false, blockedBy: false,
            muting: false, mutingNotifications: false, requested: false,
            domainBlocking: false, endorsed: false, note: "", notifying: false
        )
    }

    // MARK: - GET

    public func get<Entity: Decodable>(endpoint: Endpoint, forceVersion: FediverseClient.Version?) async throws -> Entity {
        let path = endpoint.path()
        var params = extractParams(from: endpoint)

        // --- Timeline routes ---
        if path == "timelines/home" {
            let data = try await makeMisskeyRequest(path: "notes/timeline", params: params)
            let notes = try JSONDecoder().decode([MisskeyNote].self, from: data)
            return notes.map { $0.toStatus() } as! Entity

        } else if path == "timelines/public" {
            let isLocal = (params["local"] as? String) == "true"
            let apiPath = isLocal ? "notes/local-timeline" : "notes/global-timeline"
            let data = try await makeMisskeyRequest(path: apiPath, params: params)
            let notes = try JSONDecoder().decode([MisskeyNote].self, from: data)
            return notes.map { $0.toStatus() } as! Entity

        } else if path.hasPrefix("timelines/") {
            // Tag timelines come in as "timelines/tag/:tag" — route to notes/search-by-tag.
            let components = path.components(separatedBy: "/")
            if components.count >= 3 && components[1] == "tag" {
                let tag = components[2]
                if let data = try? await makeMisskeyRequest(path: "notes/search-by-tag", params: ["tag": tag, "limit": params["limit"] ?? 20]),
                   let notes = try? JSONDecoder().decode([MisskeyNote].self, from: data) {
                    return notes.map { $0.toStatus() } as! Entity
                }
            }
            return ([Status]() as! Entity)

        // --- Instance ---
        } else if path == "instance" || path == "v1/instance" || path == "v2/instance" {
            return stubInstance() as! Entity

        } else if path == "instance/peers" {
            return ([String]() as! Entity)

        // --- Push subscriptions ---
        } else if path == "push/subscription" {
            // Misskey has no push subscription API. PushSubscription is Decodable-only (no
            // public memberwise init), so we decode from a minimal JSON stub.
            let json = """
            {"id":1,"endpoint":"https://example.com","server_key":"","alerts":{"follow":false,"favourite":false,"reblog":false,"mention":false,"poll":false,"status":false}}
            """
            let dec = JSONDecoder()
            dec.keyDecodingStrategy = .convertFromSnakeCase
            if let sub = try? dec.decode(PushSubscription.self, from: Data(json.utf8)) {
                return sub as! Entity
            }
            throw FediverseClient.ClientError.unexpectedRequest

        // --- Collections (Mastodon 4.6+) ---
        } else if path.hasPrefix("accounts/") && path.hasSuffix("/collections") {
            // AccountCollectionsResponse has no public memberwise init (Codable only).
            let json = "{\"collections\":[]}"
            let resp = try JSONDecoder().decode(AccountCollectionsResponse.self, from: Data(json.utf8))
            return resp as! Entity

        } else if path.hasPrefix("collections/") {
            // AccountCollection and AccountCollectionResponse have no public memberwise inits.
            let collectionStub = """
            {"id":"1","accountId":"1","uri":"","url":null,"name":"Mock","description":"","language":null,"local":true,"sensitive":false,"discoverable":true,"tag":null,"createdAt":"2024-01-01T00:00:00.000Z","updatedAt":"2024-01-01T00:00:00.000Z","itemCount":0,"items":[]}
            """
            let responseStub = """
            {"collection":\(collectionStub),"accounts":[]}
            """
            let dec = JSONDecoder()
            dec.dateDecodingStrategy = .iso8601
            if let resp = try? dec.decode(AccountCollectionResponse.self, from: Data(responseStub.utf8)) {
                return resp as! Entity
            }
            throw FediverseClient.ClientError.unexpectedRequest

        } else if path.hasPrefix("accounts/") && path.hasSuffix("/in_collections") {
            let json = "{\"collections\":[]}"
            let resp = try JSONDecoder().decode(AccountCollectionsResponse.self, from: Data(json.utf8))
            return resp as! Entity

        // --- Account lookup ---
        } else if path == "accounts/lookup" {
            let data = try await makeMisskeyRequest(path: "users/show", params: ["username": params["acct"] as? String ?? ""])
            let user = try JSONDecoder().decode(MisskeyUser.self, from: data)
            return user.toAccount() as! Entity

        } else if path == "accounts/familiar_followers" {
            return ([FamiliarAccounts]() as! Entity)

        } else if path == "followed_tags" {
            return ([Tag]() as! Entity)

        } else if path.hasPrefix("accounts/") && path.hasSuffix("/note") {
            let id = path.replacingOccurrences(of: "accounts/", with: "").replacingOccurrences(of: "/note", with: "")
            let rel = Relationship(
                id: id, following: false, showingReblogs: false,
                followedBy: false, blocking: false, blockedBy: false,
                muting: false, mutingNotifications: false, requested: false,
                domainBlocking: false, endorsed: false,
                note: (params["comment"] as? String) ?? "", notifying: false
            )
            return rel as! Entity

        } else if path == "accounts/verify_credentials" {
            // Core sign-in path: exchange the MiAuth token for the authenticated user.
            let data = try await makeMisskeyRequest(path: "i", params: params)
            let user = try JSONDecoder().decode(MisskeyUser.self, from: data)
            return user.toAccount() as! Entity

        } else if path == "accounts/relationships" {
            // Use Misskey's users/relation endpoint to get real follow/block/mute state.
            // The Mastodon endpoint takes id[] params; extract them and batch-query Misskey.
            var userIds: [String] = []
            if let ids = params["id[]"] as? [String] {
                userIds = ids
            } else if let id = params["id[]"] as? String {
                userIds = [id]
            }
            if !userIds.isEmpty {
                if let data = try? await makeMisskeyRequest(path: "users/relation", params: ["userId": userIds]),
                   let relations = try? JSONDecoder().decode([MisskeyRelation].self, from: data) {
                    return relations.map { $0.toRelationship() } as! Entity
                }
            }
            return userIds.map { emptyRelationship(id: $0) } as! Entity

        } else if path.hasPrefix("accounts/") && path.components(separatedBy: "/").count == 2 {
            let id = path.replacingOccurrences(of: "accounts/", with: "")
            params["userId"] = id
            let data = try await makeMisskeyRequest(path: "users/show", params: params)
            let user = try JSONDecoder().decode(MisskeyUser.self, from: data)
            return user.toAccount() as! Entity

        } else if path.hasSuffix("/followers") && path.hasPrefix("accounts/") {
            let id = path.replacingOccurrences(of: "accounts/", with: "").replacingOccurrences(of: "/followers", with: "")
            if let data = try? await makeMisskeyRequest(path: "users/followers", params: ["userId": id, "limit": 40]),
               let entries = try? JSONDecoder().decode([MisskeyFollowEntry].self, from: data) {
                return entries.compactMap { $0.follower?.toAccount() } as! Entity
            }
            return ([Account]() as! Entity)

        } else if path.hasSuffix("/following") && path.hasPrefix("accounts/") {
            let id = path.replacingOccurrences(of: "accounts/", with: "").replacingOccurrences(of: "/following", with: "")
            if let data = try? await makeMisskeyRequest(path: "users/following", params: ["userId": id, "limit": 40]),
               let entries = try? JSONDecoder().decode([MisskeyFollowEntry].self, from: data) {
                return entries.compactMap { $0.followee?.toAccount() } as! Entity
            }
            return ([Account]() as! Entity)

        } else if path.hasSuffix("/featured_tags") && path.hasPrefix("accounts/") {
            return ([FeaturedTag]() as! Entity)

        } else if path.hasSuffix("/statuses") && path.hasPrefix("accounts/") {
            let id = path.replacingOccurrences(of: "accounts/", with: "").replacingOccurrences(of: "/statuses", with: "")
            params["userId"] = id
            let data = try await makeMisskeyRequest(path: "users/notes", params: params)
            let notes = try JSONDecoder().decode([MisskeyNote].self, from: data)
            return notes.map { $0.toStatus() } as! Entity

        // --- Search ---
        } else if path == "search" {
            let query = (params["q"] as? String) ?? ""
            let type = params["type"] as? String

            var accounts: [Account] = []
            var statuses: [Status] = []

            if type == "statuses" || type == nil,
               let data = try? await makeMisskeyRequest(path: "notes/search", params: ["query": query]),
               let notes = try? JSONDecoder().decode([MisskeyNote].self, from: data) {
                statuses = notes.map { $0.toStatus() }
            }
            if type == "accounts" || type == nil,
               let data = try? await makeMisskeyRequest(path: "users/search", params: ["query": query]),
               let users = try? JSONDecoder().decode([MisskeyUser].self, from: data) {
                accounts = users.map { $0.toAccount() }
            }
            return SearchResults(accounts: accounts, relationships: [], statuses: statuses, hashtags: []) as! Entity

        // --- Misc content ---
        } else if path == "custom_emojis" {
            return ([Emoji]() as! Entity)

        } else if path == "bookmarks" {
            // Misskey uses i/favorites for bookmarked notes.
            if let data = try? await makeMisskeyRequest(path: "i/favorites", params: params),
               let favorites = try? JSONDecoder().decode([MisskeyFavorite].self, from: data) {
                return favorites.map { $0.note.toStatus() } as! Entity
            }
            return ([Status]() as! Entity)

        } else if path == "favourites" {
            return ([Status]() as! Entity)

        } else if path == "markers" {
            // Marker is Codable-only (no public memberwise init). Decode from a null stub.
            let json = "{\"notifications\":null,\"home\":null}"
            if let marker = try? JSONDecoder().decode(Marker.self, from: Data(json.utf8)) {
                return marker as! Entity
            }
            return ([Models.Notification]() as! Entity)

        } else if path == "blocks" {
            // Misskey's blocking/list returns objects with a nested blockee user.
            if let data = try? await makeMisskeyRequest(path: "blocking/list", params: params),
               let entries = try? JSONDecoder().decode([MisskeyBlockEntry].self, from: data) {
                return entries.compactMap { $0.blockee?.toAccount() } as! Entity
            }
            return ([Account]() as! Entity)

        } else if path == "mutes" {
            // Misskey's mute/list returns objects with a nested mutee user.
            if let data = try? await makeMisskeyRequest(path: "mute/list", params: params),
               let entries = try? JSONDecoder().decode([MisskeyMuteEntry].self, from: data) {
                return entries.compactMap { $0.mutee?.toAccount() } as! Entity
            }
            return ([Account]() as! Entity)

        } else if path == "follow_requests" {
            return ([Account]() as! Entity)

        } else if path == "preferences" {
            let data = "{}".data(using: .utf8)!
            let prefs = try JSONDecoder().decode(ServerPreferences.self, from: data)
            return prefs as! Entity

        // --- Notifications policy ---
        } else if path == "notifications/policy" {
            guard let policy = stubNotificationsPolicy() else {
                throw FediverseClient.ClientError.unexpectedRequest
            }
            return policy as! Entity

        } else if path == "filters" {
            return ([ServerFilter]() as! Entity)

        } else if path == "suggestions" {
            return ([Account]() as! Entity)

        } else if path == "conversations" {
            return ([Conversation]() as! Entity)

        } else if path == "lists" {
            return ([Models.List]() as! Entity)

        // --- Polls ---
        } else if path.hasPrefix("polls/") {
            // Misskey polls are embedded in notes; we fetch the note and return an empty Poll stub.
            let id = path.replacingOccurrences(of: "polls/", with: "").replacingOccurrences(of: "/votes", with: "")
            if path.hasSuffix("/votes") {
                if let choices = params["choices"] as? [Int], let first = choices.first {
                    let _ = try? await makeMisskeyRequest(path: "notes/polls/vote", params: ["noteId": id, "choice": first])
                }
            }
            // Return the note's status (poll data embedded) rather than crashing.
            let data = try await makeMisskeyRequest(path: "notes/show", params: ["noteId": id])
            let note = try JSONDecoder().decode(MisskeyNote.self, from: data)
            return note.toStatus() as! Entity

        // --- Tags ---
        } else if path.hasPrefix("tags/") {
            let isFollow = path.hasSuffix("/follow")
            let isUnfollow = path.hasSuffix("/unfollow")
            let tagName = path
                .replacingOccurrences(of: "tags/", with: "")
                .replacingOccurrences(of: "/follow", with: "")
                .replacingOccurrences(of: "/unfollow", with: "")
            if let tag = stubTag(name: tagName, following: isFollow) {
                return tag as! Entity
            }
            throw FediverseClient.ClientError.unexpectedRequest

        // --- Trends ---
        } else if path.hasPrefix("trends/") {
            if path == "trends/statuses" {
                if let data = try? await makeMisskeyRequest(path: "notes/featured", params: params),
                   let notes = try? JSONDecoder().decode([MisskeyNote].self, from: data) {
                    return notes.map { $0.toStatus() } as! Entity
                }
                return ([Status]() as! Entity)
            } else if path == "trends/tags" {
                return ([Tag]() as! Entity)
            } else if path == "trends/links" {
                return ([Card]() as! Entity)
            }

        // --- Lists ---
        } else if path.hasPrefix("lists/") {
            let list = Models.List(id: "1", title: "Mock List", repliesPolicy: .followed)
            return list as! Entity

        // --- Media ---
        } else if path.hasPrefix("media/") && path.components(separatedBy: "/").count == 2 {
            let id = path.replacingOccurrences(of: "media/", with: "")
            let data = try await makeMisskeyRequest(path: "drive/files/show", params: ["fileId": id])
            let file = try JSONDecoder().decode(MisskeyFile.self, from: data)
            return file.toMediaAttachment() as! Entity

        // --- Statuses ---
        } else if path.hasPrefix("statuses/") && path.components(separatedBy: "/").count == 2 {
            let id = path.replacingOccurrences(of: "statuses/", with: "")
            params["noteId"] = id
            let data = try await makeMisskeyRequest(path: "notes/show", params: params)
            let note = try JSONDecoder().decode(MisskeyNote.self, from: data)
            return note.toStatus() as! Entity

        } else if path.hasSuffix("/history") && path.hasPrefix("statuses/") {
            return ([StatusHistory]() as! Entity)

        } else if path.hasSuffix("/favourited_by") && path.hasPrefix("statuses/") {
            return ([Account]() as! Entity)

        } else if path.hasSuffix("/reblogged_by") && path.hasPrefix("statuses/") {
            return ([Account]() as! Entity)

        } else if path.hasSuffix("/quotes") && path.hasPrefix("statuses/") {
            return ([Status]() as! Entity)

        } else if path.hasSuffix("/context") && path.hasPrefix("statuses/") {
            let id = path.replacingOccurrences(of: "statuses/", with: "").replacingOccurrences(of: "/context", with: "")
            params["noteId"] = id

            var ancestors: [Status] = []
            var descendants: [Status] = []

            if let convData = try? await makeMisskeyRequest(path: "notes/conversation", params: params),
               let convNotes = try? JSONDecoder().decode([MisskeyNote].self, from: convData) {
                ancestors = convNotes.map { $0.toStatus() }
            }
            if let childrenData = try? await makeMisskeyRequest(path: "notes/children", params: params),
               let childrenNotes = try? JSONDecoder().decode([MisskeyNote].self, from: childrenData) {
                descendants = childrenNotes.map { $0.toStatus() }
            }
            return StatusContext(ancestors: ancestors, descendants: descendants) as! Entity

        // --- Notifications ---
        } else if path == "notifications" {
            let data = try await makeMisskeyRequest(path: "i/notifications", params: params)
            let misskeyNotifs = try JSONDecoder().decode([MisskeyNotification].self, from: data)
            return misskeyNotifs.compactMap { $0.toNotification() } as! Entity

        } else if path == "v2/notifications" || path.hasPrefix("v2/notifications") {
            return ([Models.Notification]() as! Entity)

        } else if path == "notifications/requests" {
            return ([Models.Notification]() as! Entity)
        }

        throw FediverseClient.ClientError.unexpectedRequest
    }

    // MARK: - GET with Link header (pagination)

    public func getWithLink<Entity: Decodable>(endpoint: Endpoint) async throws -> (Entity, LinkHandler?) {
        let entity: Entity = try await get(endpoint: endpoint, forceVersion: nil)

        var linkHandler: LinkHandler? = nil
        if let statuses = entity as? [Status], let last = statuses.last {
            let fakeLink = "<https://\(server)/api/notes?untilId=\(last.id)>; rel=\"next\""
            linkHandler = LinkHandler(rawLink: fakeLink)
        }
        return (entity, linkHandler)
    }

    // MARK: - POST (returning entity)

    public func post<Entity: Decodable>(endpoint: Endpoint, forceVersion: FediverseClient.Version? = nil) async throws -> Entity {
        let path = endpoint.path()
        var params = extractParams(from: endpoint)

        if path == "statuses" {
            let data = try await makeMisskeyRequest(path: "notes/create", params: params)
            // notes/create returns { "createdNote": { ... } }
            if let response = try? JSONDecoder().decode(NoteCreateResponse.self, from: data) {
                return response.createdNote.toStatus() as! Entity
            }
            let note = try JSONDecoder().decode(MisskeyNote.self, from: data)
            return note.toStatus() as! Entity

        } else if path == "markers" || (path.hasPrefix("conversations/") && path.hasSuffix("/read")) {
            // Stub a minimal conversation — lastStatus defaults to nil.
            return Conversation(id: "1", unread: false, lastStatus: nil, accounts: []) as! Entity

        } else if path.hasPrefix("polls/") && path.hasSuffix("/votes") {
            let id = path.replacingOccurrences(of: "polls/", with: "").replacingOccurrences(of: "/votes", with: "")
            if let choices = params["choices"] as? [Int], let first = choices.first {
                let _ = try? await makeMisskeyRequest(path: "notes/polls/vote", params: ["noteId": id, "choice": first])
            }
            // Return the note status since Misskey has no separate poll object endpoint.
            let data = try await makeMisskeyRequest(path: "notes/show", params: ["noteId": id])
            let note = try JSONDecoder().decode(MisskeyNote.self, from: data)
            return note.toStatus() as! Entity

        } else if path.hasPrefix("tags/") && (path.hasSuffix("/follow") || path.hasSuffix("/unfollow")) {
            let tagName = path
                .replacingOccurrences(of: "tags/", with: "")
                .replacingOccurrences(of: "/follow", with: "")
                .replacingOccurrences(of: "/unfollow", with: "")
            if let tag = stubTag(name: tagName, following: path.hasSuffix("/follow")) {
                return tag as! Entity
            }
            throw FediverseClient.ClientError.unexpectedRequest

        } else if path == "notifications/policy" {
            guard let policy = stubNotificationsPolicy() else {
                throw FediverseClient.ClientError.unexpectedRequest
            }
            return policy as! Entity

        } else if path == "filters" {
            return ([ServerFilter]() as! Entity)

        } else if path == "lists" {
            let list = Models.List(id: "1", title: "Mock List", repliesPolicy: .followed)
            return list as! Entity

        } else if path.hasPrefix("follow_requests") {
            return emptyRelationship(id: "") as! Entity

        } else if path.hasPrefix("notifications") {
            return ([Models.Notification]() as! Entity)

        } else if path.hasSuffix("/unfavourite") && path.hasPrefix("statuses/") {
            let id = path.replacingOccurrences(of: "statuses/", with: "").replacingOccurrences(of: "/unfavourite", with: "")
            params["noteId"] = id
            let _ = try? await makeMisskeyRequest(path: "notes/reactions/delete", params: params)
            let data = try await makeMisskeyRequest(path: "notes/show", params: ["noteId": id])
            return try JSONDecoder().decode(MisskeyNote.self, from: data).toStatus() as! Entity

        } else if path.hasSuffix("/favourite") && path.hasPrefix("statuses/") {
            let id = path.replacingOccurrences(of: "statuses/", with: "").replacingOccurrences(of: "/favourite", with: "")
            params["noteId"] = id
            // Pick the reaction emoji to match the user's favourite-button style.
            // theme.actionIsLike == true means the button shows a heart, so we send ❤️.
            // Default (star) sends ⭐. We read directly from AppStorage rather than
            // importing DesignSystem into the network layer.
            let actionIsLike = UserDefaults.standard.bool(forKey: "actionIsLike")
            params["reaction"] = actionIsLike ? "❤" : "⭐"
            let _ = try? await makeMisskeyRequest(path: "notes/reactions/create", params: params)
            let data = try await makeMisskeyRequest(path: "notes/show", params: ["noteId": id])
            return try JSONDecoder().decode(MisskeyNote.self, from: data).toStatus() as! Entity

        } else if path.hasSuffix("/reblog") && path.hasPrefix("statuses/") {
            let id = path.replacingOccurrences(of: "statuses/", with: "").replacingOccurrences(of: "/reblog", with: "")
            params["renoteId"] = id
            let data = try await makeMisskeyRequest(path: "notes/create", params: params)
            if let response = try? JSONDecoder().decode(NoteCreateResponse.self, from: data) {
                return response.createdNote.toStatus() as! Entity
            }

        } else if path.hasSuffix("/unreblog") && path.hasPrefix("statuses/") {
            let id = path.replacingOccurrences(of: "statuses/", with: "").replacingOccurrences(of: "/unreblog", with: "")
            params["noteId"] = id
            let _ = try? await makeMisskeyRequest(path: "notes/unrenote", params: params)
            let data = try await makeMisskeyRequest(path: "notes/show", params: ["noteId": id])
            return try JSONDecoder().decode(MisskeyNote.self, from: data).toStatus() as! Entity

        } else if path.hasSuffix("/bookmark") && path.hasPrefix("statuses/") {
            let id = path.replacingOccurrences(of: "statuses/", with: "").replacingOccurrences(of: "/bookmark", with: "")
            params["noteId"] = id
            let _ = try? await makeMisskeyRequest(path: "notes/favorites/create", params: params)
            let data = try await makeMisskeyRequest(path: "notes/show", params: ["noteId": id])
            return try JSONDecoder().decode(MisskeyNote.self, from: data).toStatus() as! Entity

        } else if path.hasSuffix("/unbookmark") && path.hasPrefix("statuses/") {
            let id = path.replacingOccurrences(of: "statuses/", with: "").replacingOccurrences(of: "/unbookmark", with: "")
            params["noteId"] = id
            let _ = try? await makeMisskeyRequest(path: "notes/favorites/delete", params: params)
            let data = try await makeMisskeyRequest(path: "notes/show", params: ["noteId": id])
            return try JSONDecoder().decode(MisskeyNote.self, from: data).toStatus() as! Entity

        } else if path.hasSuffix("/pin") && path.hasPrefix("statuses/") {
            let id = path.replacingOccurrences(of: "statuses/", with: "").replacingOccurrences(of: "/pin", with: "")
            params["noteId"] = id
            let _ = try? await makeMisskeyRequest(path: "i/pin", params: params)
            let data = try await makeMisskeyRequest(path: "notes/show", params: ["noteId": id])
            return try JSONDecoder().decode(MisskeyNote.self, from: data).toStatus() as! Entity

        } else if path.hasSuffix("/unpin") && path.hasPrefix("statuses/") {
            let id = path.replacingOccurrences(of: "statuses/", with: "").replacingOccurrences(of: "/unpin", with: "")
            params["noteId"] = id
            let _ = try? await makeMisskeyRequest(path: "i/unpin", params: params)
            let data = try await makeMisskeyRequest(path: "notes/show", params: ["noteId": id])
            return try JSONDecoder().decode(MisskeyNote.self, from: data).toStatus() as! Entity

        } else if path.hasSuffix("/follow") && path.hasPrefix("accounts/") {
            let id = path.replacingOccurrences(of: "accounts/", with: "").replacingOccurrences(of: "/follow", with: "")
            params["userId"] = id
            let _ = try? await makeMisskeyRequest(path: "following/create", params: params)
            return Relationship(id: id, following: true, showingReblogs: true, followedBy: false, blocking: false, blockedBy: false, muting: false, mutingNotifications: false, requested: false, domainBlocking: false, endorsed: false, note: "", notifying: false) as! Entity

        } else if path.hasSuffix("/unfollow") && path.hasPrefix("accounts/") {
            let id = path.replacingOccurrences(of: "accounts/", with: "").replacingOccurrences(of: "/unfollow", with: "")
            params["userId"] = id
            let _ = try? await makeMisskeyRequest(path: "following/delete", params: params)
            return emptyRelationship(id: id) as! Entity

        } else if path.hasSuffix("/mute") && path.hasPrefix("accounts/") {
            let id = path.replacingOccurrences(of: "accounts/", with: "").replacingOccurrences(of: "/mute", with: "")
            params["userId"] = id
            let _ = try? await makeMisskeyRequest(path: "mute/create", params: params)
            return Relationship(id: id, following: false, showingReblogs: false, followedBy: false, blocking: false, blockedBy: false, muting: true, mutingNotifications: false, requested: false, domainBlocking: false, endorsed: false, note: "", notifying: false) as! Entity

        } else if path.hasSuffix("/unmute") && path.hasPrefix("accounts/") {
            let id = path.replacingOccurrences(of: "accounts/", with: "").replacingOccurrences(of: "/unmute", with: "")
            params["userId"] = id
            let _ = try? await makeMisskeyRequest(path: "mute/delete", params: params)
            return emptyRelationship(id: id) as! Entity

        } else if path.hasSuffix("/block") && path.hasPrefix("accounts/") {
            let id = path.replacingOccurrences(of: "accounts/", with: "").replacingOccurrences(of: "/block", with: "")
            params["userId"] = id
            let _ = try? await makeMisskeyRequest(path: "blocking/create", params: params)
            return Relationship(id: id, following: false, showingReblogs: false, followedBy: false, blocking: true, blockedBy: false, muting: false, mutingNotifications: false, requested: false, domainBlocking: false, endorsed: false, note: "", notifying: false) as! Entity

        } else if path.hasSuffix("/translate") && path.hasPrefix("statuses/") {
            let id = path.replacingOccurrences(of: "statuses/", with: "").replacingOccurrences(of: "/translate", with: "")
            params["noteId"] = id
            if let lang = params["lang"] as? String { params["targetLang"] = lang }
            // Misskey has no translation API; return a stub translation.
            let translation = Translation(content: "", detectedSourceLanguage: "", provider: "")
            return translation as! Entity
        }

        throw FediverseClient.ClientError.unexpectedRequest
    }

    // MARK: - POST (returning HTTP response)

    public func post(endpoint: Endpoint, forceVersion: FediverseClient.Version? = nil) async throws -> HTTPURLResponse? {
        let path = endpoint.path()
        var params = extractParams(from: endpoint)

        if path == "reports" {
            if let userId = params["account_id"] as? String {
                let comment = params["comment"] as? String ?? ""
                // Misskey uses users/report-abuse, not users/report.
                let _ = try? await makeMisskeyRequest(path: "users/report-abuse", params: ["userId": userId, "comment": comment])
            }
            return HTTPURLResponse(url: URL(string: "https://\(server)")!, statusCode: 200, httpVersion: nil, headerFields: nil)

        } else if path.hasPrefix("conversations/") {
            return HTTPURLResponse(url: URL(string: "https://\(server)")!, statusCode: 200, httpVersion: nil, headerFields: nil)

        } else if path.hasPrefix("statuses/") && path.components(separatedBy: "/").count == 2 {
            // Note deletion
            let id = path.replacingOccurrences(of: "statuses/", with: "")
            let _ = try? await makeMisskeyRequest(path: "notes/delete", params: ["noteId": id])
            return HTTPURLResponse(url: URL(string: "https://\(server)")!, statusCode: 200, httpVersion: nil, headerFields: nil)

        } else if path.hasPrefix("notifications/") {
            let _ = try? await makeMisskeyRequest(path: "notifications/mark-all-as-read", params: [:])
            return HTTPURLResponse(url: URL(string: "https://\(server)")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        }

        return nil
    }

    // MARK: - PUT

    public func put<Entity: Decodable>(endpoint: Endpoint, forceVersion: FediverseClient.Version? = nil) async throws -> Entity {
        throw FediverseClient.ClientError.unexpectedRequest
    }

    public func put(endpoint: Endpoint, forceVersion: FediverseClient.Version? = nil) async throws -> HTTPURLResponse? {
        nil
    }

    // MARK: - PATCH

    public func patch<Entity: Decodable>(endpoint: Endpoint, forceVersion: FediverseClient.Version? = nil) async throws -> Entity {
        let path = endpoint.path()
        var params = extractParams(from: endpoint)

        if path == "accounts/update_credentials" {
            // Proxy profile updates to Misskey's i/update endpoint.
            var misskeyParams: [String: Any] = [:]
            if let name = params["display_name"] as? String { misskeyParams["name"] = name }
            if let note = params["note"] as? String { misskeyParams["description"] = note }
            if let locked = params["locked"] as? String { misskeyParams["isLocked"] = locked == "true" }
            let _ = try? await makeMisskeyRequest(path: "i/update", params: misskeyParams)
            // Return the updated account.
            let data = try await makeMisskeyRequest(path: "i", params: [:])
            let user = try JSONDecoder().decode(MisskeyUser.self, from: data)
            return user.toAccount() as! Entity

        } else if path == "notifications/policy" {
            guard let policy = stubNotificationsPolicy() else {
                throw FediverseClient.ClientError.unexpectedRequest
            }
            return policy as! Entity
        }

        throw FediverseClient.ClientError.unexpectedRequest
    }

    public func patch(endpoint: Endpoint, forceVersion: FediverseClient.Version? = nil) async throws -> HTTPURLResponse? {
        nil
    }

    // MARK: - DELETE

    public func delete(endpoint: Endpoint, forceVersion: FediverseClient.Version? = nil) async throws -> HTTPURLResponse? {
        let path = endpoint.path()
        var params = extractParams(from: endpoint)

        if path.hasPrefix("statuses/") && path.components(separatedBy: "/").count == 2 {
            let id = path.replacingOccurrences(of: "statuses/", with: "")
            let _ = try? await makeMisskeyRequest(path: "notes/delete", params: ["noteId": id])
            return HTTPURLResponse(url: URL(string: "https://\(server)")!, statusCode: 200, httpVersion: nil, headerFields: nil)

        } else if path.hasPrefix("accounts/") && path.hasSuffix("/unblock") {
            let id = path.replacingOccurrences(of: "accounts/", with: "").replacingOccurrences(of: "/unblock", with: "")
            params["userId"] = id
            let _ = try? await makeMisskeyRequest(path: "blocking/delete", params: params)
            return HTTPURLResponse(url: URL(string: "https://\(server)")!, statusCode: 200, httpVersion: nil, headerFields: nil)

        } else if path.hasPrefix("filters/") {
            return HTTPURLResponse(url: URL(string: "https://\(server)")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        }

        return nil
    }

    // MARK: - Media upload

    public func mediaUpload<Entity: Decodable>(endpoint: Endpoint, version: FediverseClient.Version, method: String, mimeType: String, filename: String, data: Data) async throws -> Entity {
        // Upload file to Misskey's drive.
        let url = URL(string: "https://\(server)/api/drive/files/create")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        // Auth token field
        if let token = oauthToken?.accessToken {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"i\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(token)\r\n".data(using: .utf8)!)
        }
        // File field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (responseData, _) = try await URLSession.shared.data(for: request)
        let file = try JSONDecoder().decode(MisskeyFile.self, from: responseData)
        return file.toMediaAttachment() as! Entity
    }

    public func mediaUpload(endpoint: Endpoint, version: FediverseClient.Version, method: String, mimeType: String, filename: String, data: Data) async throws -> HTTPURLResponse? {
        nil
    }

    // MARK: - WebSocket (streaming)

    public func makeWebSocketTask(endpoint: Endpoint, instanceStreamingURL: URL?) throws -> URLSessionWebSocketTask {
        // Misskey streaming uses a different protocol; return a task that connects to the
        // Misskey streaming endpoint so it at least doesn't crash.
        let streamingBase = instanceStreamingURL?.absoluteString ?? "wss://\(server)"
        let wsURL = URL(string: "\(streamingBase)/streaming") ?? URL(string: "wss://\(server)/streaming")!
        return URLSession.shared.webSocketTask(with: wsURL)
    }
}
