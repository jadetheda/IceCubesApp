import Foundation
import Models

// MisskeyBackend translates the Mastodon-shaped API calls from FediverseClient into
// Misskey's POST-body JSON API, mapping responses back into the shared Models types
// so the rest of the app remains completely unaware of the protocol differences.
//
// Endpoints that have no Misskey equivalent return safe stubs (empty arrays, mock
// objects decoded from hardcoded JSON) so the UI never throws on unsupported features.
public final class MisskeyBackend: FediverseBackend, @unchecked Sendable {

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
            supportsCustomEmojis: true,
            supportsAccountMetrics: false,
            supportsStatusEditing: false,
            supportsTrendingLinks: false,
            supportsNativeMessaging: true
        )
    }

    private let connectionsLock = NSLock()
    private var _connections: Set<String> = []

    public init(server: String, version: FediverseClient.Version = .v1, oauthToken: OauthToken? = nil) {
        self.server = server
        self.version = version
        self.oauthToken = oauthToken
        self._connections = [server]
    }

    public func addConnections(_ connections: [String]) {
        connectionsLock.lock()
        _connections.formUnion(connections)
        connectionsLock.unlock()
    }

    public func hasConnection(with url: URL) -> Bool {
        guard let host = url.host else { return false }
        connectionsLock.lock()
        let cons = _connections
        connectionsLock.unlock()
        
        if let rootHost = host.split(separator: ".", maxSplits: 1).last {
            if cons.contains(host) || cons.contains(String(rootHost)) || host == server || String(rootHost) == server { return true }
        } else {
            if cons.contains(host) || host == server { return true }
        }
        
        // Misskey's `instance/peers` equivalent is structurally incompatible with Mastodon's, 
        // frequently requiring auth or returning 403s. To ensure cross-instance @mentions 
        // and #tags still route natively in IceCubes, we optimistically accept them here.
        // If the backend search API fails to resolve them later, the router will fallback to Safari.
        if url.lastPathComponent.first == "@" { return true }
        if url.pathComponents.contains(where: { $0 == "tags" || $0 == "tag" }) { return true }
        
        return false
    }

    // MARK: - MiAuth OAuth flow
    // Misskey uses MiAuth rather than OAuth2. We generate a session UUID, redirect
    // the user to /miauth/<uuid>, then exchange the session for a token on callback.
    nonisolated(unsafe) private static var currentSessionId: String?

    public func oauthURL() async throws -> URL {
        let sessionId = UUID().uuidString
        Self.currentSessionId = sessionId

        let permissions = "read:account,write:account,read:blocks,write:blocks,read:drive,write:drive,read:favorites,write:favorites,read:following,write:following,read:mutes,write:mutes,write:notes,read:notifications,write:notifications,read:reactions,write:reactions,write:votes"
        let appName = "IceCubesApp".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "IceCubesApp"

        // Use a callback URL with a path so ASWebAuthenticationSession can intercept the
        // redirect reliably. A bare scheme ("icecubesapp://") can be missed; adding a
        // path segment ("icecubesapp://misskey-auth") makes the match unambiguous.
        let callbackUrl = "icecubesapp://misskey-auth"
        let callback = callbackUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? callbackUrl

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

        // MiAuth check response: {"ok": true, "token": "...", "user": {...}} on success,
        // or {"ok": false} if the session hasn't been authorized yet.
        struct MiAuthResponse: Decodable {
            let ok: Bool
            let token: String?
        }

        let requestUrl = URL(string: "https://\(server)/api/miauth/\(sessionId)/check")!

        // Retry a few times with a short delay — Misskey's backend may not have
        // processed the authorization by the time ASWebAuthenticationSession returns.
        // Also: the check endpoint requires a JSON body (even if empty) on some instances.
        for attempt in 1...3 {
            if attempt > 1 {
                try? await Task.sleep(for: .seconds(1))
            }

            var request = URLRequest(url: requestUrl)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = "{}".data(using: .utf8)  // some instances require a body

            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

            guard let miAuthResponse = try? JSONDecoder().decode(MiAuthResponse.self, from: data) else {
                let body = String(data: data, encoding: .utf8) ?? ""
                print("[MisskeyBackend] MiAuth check attempt \(attempt) — bad JSON, http=\(statusCode) body=\(body)")
                continue
            }

            if miAuthResponse.ok, let token = miAuthResponse.token {
                Self.currentSessionId = nil
                return OauthToken(accessToken: token, tokenType: "Bearer", scope: "", createdAt: Date().timeIntervalSince1970)
            }

            let body = String(data: data, encoding: .utf8) ?? ""
            print("[MisskeyBackend] MiAuth check attempt \(attempt) — ok=\(miAuthResponse.ok) http=\(statusCode) body=\(body)")
        }

        throw FediverseClient.OauthError.missingApp
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

        request.httpBody = try JSONSerialization.data(withJSONObject: bodyParams)
        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            let apiError = try? JSONDecoder().decode(MisskeyAPIError.self, from: data)
            let fallback = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw FediverseClient.ClientError.serverError(
                statusCode: httpResponse.statusCode,
                code: apiError?.error?.code ?? apiError?.code,
                message: apiError?.error?.message ?? apiError?.message ?? fallback)
        }

        return data
    }

    private struct MisskeyAPIError: Decodable {
        struct ErrorDetails: Decodable {
            let message: String?
            let code: String?
        }
        let error: ErrorDetails?
        let message: String?
        let code: String?
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
            if let status = dict["status"] as? String {
                if !status.isEmpty { params["text"] = status }
            }
            if let visibility = dict["visibility"] as? String {
                var misskeyVis = visibility
                if visibility == "unlisted" { misskeyVis = "home" }
                else if visibility == "private" { misskeyVis = "followers" }
                else if visibility == "direct" { misskeyVis = "specified" }
                params["visibility"] = misskeyVis
            }
            if let poll = dict["poll"] as? [String: Any] {
                var misskeyPoll: [String: Any] = [:]
                if let options = poll["options"] as? [String] { misskeyPoll["choices"] = options }
                if let multiple = poll["multiple"] as? Bool { misskeyPoll["multiple"] = multiple }
                if let expiresIn = poll["expires_in"] as? Int { misskeyPoll["expiredAfter"] = expiresIn * 1000 }
                params["poll"] = misskeyPoll
            }
            if let inReplyToId = dict["inReplyToId"] as? String { params["replyId"] = inReplyToId }
            if let mediaIds = dict["mediaIds"] as? [String], !mediaIds.isEmpty { params["fileIds"] = mediaIds }
            if let cw = dict["spoilerText"] as? String, !cw.isEmpty { params["cw"] = cw }
            if let renoteId = dict["quotedStatusId"] as? String { params["renoteId"] = renoteId }
        }

        if let title = params["title"] {
            params["name"] = title
            params.removeValue(forKey: "title")
        }
        if let repliesPolicy = params["replies_policy"] {
            params["replyCw"] = repliesPolicy
            params.removeValue(forKey: "replies_policy")
        }
        if let exclusive = params["exclusive"] as? String {
            params["isPublic"] = exclusive != "true"
            params.removeValue(forKey: "exclusive")
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

    private func currentUserId() async -> String {
        guard let data = try? await makeMisskeyRequest(path: "i", params: [:]),
              let user = try? JSONDecoder().decode(MisskeyUser.self, from: data)
        else { return "" }
        return user.id
    }

    // MARK: - GET

    public func get<Entity: Decodable>(endpoint: Endpoint, forceVersion: FediverseClient.Version?) async throws -> Entity {
        let path = endpoint.path()
        var params = extractParams(from: endpoint)

        // --- Timeline routes ---
        if path == "timelines/home" {
            let data = try await makeMisskeyRequest(path: "notes/timeline", params: params)
            let notes = try JSONDecoder().decode([MisskeyNote].self, from: data)
            return notes.map { $0.toStatus(server: self.server) } as! Entity

        } else if path == "timelines/public" {
            let isLocal = (params["local"] as? String) == "true"
            let apiPath = isLocal ? "notes/local-timeline" : "notes/global-timeline"
            // `local` is a Mastodon routing flag, not a Misskey API parameter.
            // Sending it to notes/global-timeline makes some Misskey servers
            // reject the federated request instead of returning notes.
            params.removeValue(forKey: "local")
            params["withFiles"] = true
            params["withRenotes"] = true
            params["withReplies"] = false
            let data = try await makeMisskeyRequest(path: apiPath, params: params)
            let notes = try JSONDecoder().decode([MisskeyNote].self, from: data)
            return notes.map { $0.toStatus(server: self.server) } as! Entity

        } else if path.hasPrefix("timelines/list/") {
            let listId = path.replacingOccurrences(of: "timelines/list/", with: "")
            var timelineParams = params
            timelineParams["listId"] = listId
            let data = try await makeMisskeyRequest(
                path: "notes/user-list-timeline",
                params: timelineParams)
            let notes = try JSONDecoder().decode([MisskeyNote].self, from: data)
            return notes.map { $0.toStatus(server: self.server) } as! Entity

        } else if path.hasPrefix("timelines/") {
            // Tag timelines come in as "timelines/tag/:tag" — route to notes/search-by-tag.
            let components = path.components(separatedBy: "/")
            if components.count >= 3 && components[1] == "tag" {
                let tag = components[2]
                if let data = try? await makeMisskeyRequest(path: "notes/search-by-tag", params: ["tag": tag, "limit": params["limit"] ?? 20]),
                   let notes = try? JSONDecoder().decode([MisskeyNote].self, from: data) {
                    return notes.map { $0.toStatus(server: self.server) } as! Entity
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
            var noteParams = params
            noteParams["userId"] = id

            // `users/notes` uses different names for the account-status filters.
            // In particular, boosts are only returned when withRenotes is true.
            if let excludeReplies = noteParams.removeValue(forKey: "exclude_replies") as? String {
                noteParams["withReplies"] = excludeReplies != "true"
            }
            if let excludeReblogs = noteParams.removeValue(forKey: "exclude_reblogs") as? String {
                noteParams["withRenotes"] = excludeReblogs != "true"
            }
            if let onlyMedia = noteParams.removeValue(forKey: "only_media") as? String {
                noteParams["withFiles"] = onlyMedia == "true"
            }

            let data = try await makeMisskeyRequest(path: "users/notes", params: noteParams)
            let notes = try JSONDecoder().decode([MisskeyNote].self, from: data)
            return notes.map { $0.toStatus(server: self.server) } as! Entity

        // --- Search ---
        } else if path == "search" {
            let query = (params["q"] as? String) ?? ""
            let type = params["type"] as? String

            var accounts: [Account] = []
            var statuses: [Status] = []
            
            if query.hasPrefix("http://") || query.hasPrefix("https://") {
                if let data = try? await makeMisskeyRequest(path: "ap/show", params: ["uri": query]),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let apType = json["type"] as? String,
                   let object = json["object"] {
                    if apType == "Note" {
                        let objData = try JSONSerialization.data(withJSONObject: object)
                        if let note = try? JSONDecoder().decode(MisskeyNote.self, from: objData) {
                            statuses = [note.toStatus(server: self.server)]
                        }
                    } else if apType == "User" {
                        let objData = try JSONSerialization.data(withJSONObject: object)
                        if let user = try? JSONDecoder().decode(MisskeyUser.self, from: objData) {
                            accounts = [user.toAccount()]
                        }
                    }
                }
            } else {
                if type == "statuses" || type == nil,
                   let data = try? await makeMisskeyRequest(path: "notes/search", params: ["query": query]),
                   let notes = try? JSONDecoder().decode([MisskeyNote].self, from: data) {
                    statuses = notes.map { $0.toStatus(server: self.server) }
                }
                if type == "accounts" || type == nil {
                    // If looking for a specific user via @username@domain, use users/show to resolve remote users
                    let parts = query.trimmingCharacters(in: CharacterSet(charactersIn: "@ ")).components(separatedBy: "@")
                    var resolved = false
                    if parts.count == 2 {
                        let uri = "https://\(parts[1])/@\(parts[0])"
                        if let data = try? await makeMisskeyRequest(path: "ap/show", params: ["uri": uri]),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let apType = json["type"] as? String, apType == "User",
                           let object = json["object"] {
                            let objData = try JSONSerialization.data(withJSONObject: object)
                            if let user = try? JSONDecoder().decode(MisskeyUser.self, from: objData) {
                                accounts = [user.toAccount(server: self.server)]
                                resolved = true
                            }
                        }
                    } else if parts.count == 1 {
                        if let data = try? await makeMisskeyRequest(path: "users/show", params: ["username": parts[0]]),
                           let user = try? JSONDecoder().decode(MisskeyUser.self, from: data) {
                            accounts = [user.toAccount(server: self.server)]
                            resolved = true
                        }
                    }
                    
                    if !resolved,
                       let data = try? await makeMisskeyRequest(path: "users/search", params: ["query": query]),
                       let users = try? JSONDecoder().decode([MisskeyUser].self, from: data) {
                        accounts = users.map { $0.toAccount(server: self.server) }
                    }
                }
            }
            return SearchResults(accounts: accounts, relationships: [], statuses: statuses, hashtags: []) as! Entity

        // --- Misc content ---
        } else if path == "custom_emojis" {
            return ([Emoji]() as! Entity)

        } else if path == "bookmarks" {
            // Misskey uses i/favorites for bookmarked notes.
            let data = try await makeMisskeyRequest(path: "i/favorites", params: params)
            let favorites = try JSONDecoder().decode([MisskeyFavorite].self, from: data)
            return favorites.map { $0.note.toStatus(server: self.server) } as! Entity

        } else if path == "favourites" {
            // Misskey's likes endpoint returns the same note wrapper shape as
            // i/favorites, but represents reactions rather than bookmarks.
            let data = try await makeMisskeyRequest(path: "i/likes", params: params)
            let likes = try JSONDecoder().decode([MisskeyFavorite].self, from: data)
            return likes.map { $0.note.toStatus(server: self.server) } as! Entity

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
            let data = try await makeMisskeyRequest(path: "users/recommendation", params: [:])
            let users = try JSONDecoder().decode([MisskeyUser].self, from: data)
            return users.map { $0.toAccount() } as! Entity

        } else if path == "conversations" {
            let data = try await makeMisskeyRequest(path: "messaging/history", params: ["limit": 100])
            let messages = try JSONDecoder().decode([MisskeyMessagingMessage].self, from: data)
            let currentUserID = await currentUserId()
            var latestByUser: [String: MisskeyMessagingMessage] = [:]
            for message in messages {
                let other = message.userId == currentUserID
                    ? (message.recipient ?? message.user)
                    : message.user
                if latestByUser[other.id] == nil {
                    latestByUser[other.id] = message
                }
            }
            let conversations = latestByUser.values.map { message in
                let other = message.userId == currentUserID
                    ? (message.recipient ?? message.user)
                    : message.user
                return Conversation(
                    id: other.id,
                    unread: message.isRead == false,
                    lastStatus: message.toStatus(server: self.server),
                    accounts: [other.toAccount()]
                )
            }
            return conversations as! Entity

        } else if path.hasPrefix("conversations/") && path.hasSuffix("/messages") {
            let userId = path
                .replacingOccurrences(of: "conversations/", with: "")
                .replacingOccurrences(of: "/messages", with: "")
            let data = try await makeMisskeyRequest(
                path: "messaging/messages",
                params: ["userId": userId, "limit": 100, "markAsRead": true])
            let messages = try JSONDecoder().decode([MisskeyMessagingMessage].self, from: data)
            return messages.reversed().map { $0.toStatus(server: self.server) } as! Entity

        } else if path == "lists" {
            let data = try await makeMisskeyRequest(path: "users/lists/list", params: [:])
            let lists = try JSONDecoder().decode([MisskeyList].self, from: data)
            return lists.map {
                Models.List(id: $0.id, title: $0.name, repliesPolicy: .list)
            } as! Entity

        } else if path.hasPrefix("lists/") && path.hasSuffix("/accounts") {
            let listId = path
                .replacingOccurrences(of: "lists/", with: "")
                .replacingOccurrences(of: "/accounts", with: "")
            let data = try await makeMisskeyRequest(
                path: "users/lists/show",
                params: ["listId": listId])
            let list = try JSONDecoder().decode(MisskeyList.self, from: data)
            var accounts: [Account] = []
            for userId in list.userIds ?? [] {
                if let userData = try? await makeMisskeyRequest(
                    path: "users/show", params: ["userId": userId]),
                   let user = try? JSONDecoder().decode(MisskeyUser.self, from: userData) {
                    accounts.append(user.toAccount())
                }
            }
            return accounts as! Entity

        } else if path.hasPrefix("lists/") {
            let listId = path.replacingOccurrences(of: "lists/", with: "")
            let data = try await makeMisskeyRequest(
                path: "users/lists/show", params: ["listId": listId])
            let list = try JSONDecoder().decode(MisskeyList.self, from: data)
            return Models.List(id: list.id, title: list.name, repliesPolicy: .list) as! Entity

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
            return note.toStatus(server: self.server) as! Entity

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
                    return notes.map { $0.toStatus(server: self.server) } as! Entity
                }
                return ([Status]() as! Entity)
            } else if path == "trends/tags" {
                let data = try await makeMisskeyRequest(path: "hashtags/trend", params: [:])
                let hashtags = try JSONDecoder().decode([MisskeyTrendingHashtag].self, from: data)
                return hashtags.map {
                    Tag(name: $0.tag, url: "\(server)/tags/\($0.tag)")
                } as! Entity
            } else if path == "trends/links" {
                return ([Card]() as! Entity)
            }

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
            return note.toStatus(server: self.server) as! Entity

        } else if path.hasSuffix("/history") && path.hasPrefix("statuses/") {
            return ([StatusHistory]() as! Entity)

        } else if path.hasSuffix("/favourited_by") && path.hasPrefix("statuses/") {
            let id = path.replacingOccurrences(of: "statuses/", with: "")
                .replacingOccurrences(of: "/favourited_by", with: "")
            let data = try await makeMisskeyRequest(
                path: "notes/reactions",
                params: ["noteId": id, "limit": 100])
            let reactions = try JSONDecoder().decode([MisskeyNoteReaction].self, from: data)
            return reactions.map { $0.user.toAccount() } as! Entity

        } else if path.hasSuffix("/reblogged_by") && path.hasPrefix("statuses/") {
            let id = path.replacingOccurrences(of: "statuses/", with: "")
                .replacingOccurrences(of: "/reblogged_by", with: "")
            let data = try await makeMisskeyRequest(
                path: "notes/renotes",
                params: ["noteId": id, "limit": 100])
            let users = try JSONDecoder().decode([MisskeyUser].self, from: data)
            return users.map { $0.toAccount() } as! Entity

        } else if path.hasSuffix("/quotes") && path.hasPrefix("statuses/") {
            return ([Status]() as! Entity)

        } else if path.hasSuffix("/context") && path.hasPrefix("statuses/") {
            let id = path.replacingOccurrences(of: "statuses/", with: "").replacingOccurrences(of: "/context", with: "")
            params["noteId"] = id

            var ancestors: [Status] = []
            var descendants: [Status] = []

            if let convData = try? await makeMisskeyRequest(path: "notes/conversation", params: params),
               let convNotes = try? JSONDecoder().decode([MisskeyNote].self, from: convData) {
                ancestors = convNotes.map { $0.toStatus(server: self.server) }
            }
            if let childrenData = try? await makeMisskeyRequest(path: "notes/children", params: params),
               let childrenNotes = try? JSONDecoder().decode([MisskeyNote].self, from: childrenData) {
                descendants = childrenNotes.map { $0.toStatus(server: self.server) }
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
            // If decoding fails, surface the raw response as a server error so the
            // user sees something useful instead of a generic "Decoding Error".
            do {
                let response = try JSONDecoder().decode(NoteCreateResponse.self, from: data)
                return response.createdNote.toStatus(server: self.server) as! Entity
            } catch {
                let body = String(data: data, encoding: .utf8) ?? "no body"
                print("[MisskeyBackend] notes/create decode failed: \(error)\nRaw response: \(body)")
                throw FediverseClient.ClientError.serverError(
                    statusCode: 0,
                    code: nil,
                    message: "Post failed. Server response: \(body.prefix(200))")
            }

        } else if path == "markers" {
            // Marker is Codable-only. Decode a null stub so the caller gets the right type.
            let json = "{\"notifications\":null,\"home\":null}"
            if let marker = try? JSONDecoder().decode(Marker.self, from: Data(json.utf8)) {
                return marker as! Entity
            }
            throw FediverseClient.ClientError.unexpectedRequest

        } else if path == "conversations/send" {
            let data = try await makeMisskeyRequest(
                path: "messaging/messages/create",
                params: params)
            let message = try JSONDecoder().decode(MisskeyMessagingMessage.self, from: data)
            return message.toStatus(server: self.server) as! Entity

        } else if path.hasPrefix("conversations/") && path.hasSuffix("/read") {
            let id = path
                .replacingOccurrences(of: "conversations/", with: "")
                .replacingOccurrences(of: "/read", with: "")
            let data = try await makeMisskeyRequest(
                path: "messaging/messages",
                params: ["userId": id, "limit": 1])
            let message = try JSONDecoder().decode([MisskeyMessagingMessage].self, from: data).first
            if let message {
                _ = try await makeMisskeyRequest(
                    path: "messaging/messages/read",
                    params: ["messageId": message.id])
            }
            return Conversation(
                id: id,
                unread: false,
                lastStatus: message?.toStatus(server: self.server),
                accounts: message.map { [$0.user.toAccount()] } ?? []
            ) as! Entity

        } else if path.hasPrefix("polls/") && path.hasSuffix("/votes") {
            let id = path.replacingOccurrences(of: "polls/", with: "").replacingOccurrences(of: "/votes", with: "")
            if let choices = params["choices"] as? [Int], let first = choices.first {
                let _ = try? await makeMisskeyRequest(path: "notes/polls/vote", params: ["noteId": id, "choice": first])
            }
            // Return the note status since Misskey has no separate poll object endpoint.
            let data = try await makeMisskeyRequest(path: "notes/show", params: ["noteId": id])
            let note = try JSONDecoder().decode(MisskeyNote.self, from: data)
            return note.toStatus(server: self.server) as! Entity

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
            let data = try await makeMisskeyRequest(path: "users/lists/create", params: params)
            let list = try JSONDecoder().decode(MisskeyList.self, from: data)
            return Models.List(id: list.id, title: list.name, repliesPolicy: .list) as! Entity

        } else if path.hasPrefix("lists/") && path.hasSuffix("/accounts") {
            let listId = path
                .replacingOccurrences(of: "lists/", with: "")
                .replacingOccurrences(of: "/accounts", with: "")
            for accountId in params["account_ids[]"] as? [String] ?? [] {
                let _ = try await makeMisskeyRequest(
                    path: "users/lists/push",
                    params: ["listId": listId, "userId": accountId])
            }
            return HTTPURLResponse(url: URL(string: "https://\(server)")!, statusCode: 200, httpVersion: nil, headerFields: nil) as! Entity

        } else if path.hasPrefix("follow_requests") {
            return emptyRelationship(id: "") as! Entity

        } else if path.hasPrefix("notifications") {
            return ([Models.Notification]() as! Entity)

        } else if path.hasSuffix("/unfavourite") && path.hasPrefix("statuses/") {
            let id = path.replacingOccurrences(of: "statuses/", with: "").replacingOccurrences(of: "/unfavourite", with: "")
            params["noteId"] = id
            let _ = try? await makeMisskeyRequest(path: "notes/reactions/delete", params: params)
            let data = try await makeMisskeyRequest(path: "notes/show", params: ["noteId": id])
            return try JSONDecoder().decode(MisskeyNote.self, from: data).toStatus(server: self.server) as! Entity

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
            return try JSONDecoder().decode(MisskeyNote.self, from: data).toStatus(server: self.server) as! Entity

        } else if path.hasSuffix("/reblog") && path.hasPrefix("statuses/") {
            let id = path.replacingOccurrences(of: "statuses/", with: "").replacingOccurrences(of: "/reblog", with: "")
            params["renoteId"] = id
            let _ = try? await makeMisskeyRequest(path: "notes/create", params: params)
            // Return the original note with reblogged=true so StatusDataController
            // keeps the boost button highlighted after the action.
            let originalData = try await makeMisskeyRequest(path: "notes/show", params: ["noteId": id])
            return try JSONDecoder().decode(MisskeyNote.self, from: originalData).toStatus(reblogged: true, server: self.server) as! Entity

        } else if path.hasSuffix("/unreblog") && path.hasPrefix("statuses/") {
            let id = path.replacingOccurrences(of: "statuses/", with: "").replacingOccurrences(of: "/unreblog", with: "")
            params["noteId"] = id
            let _ = try? await makeMisskeyRequest(path: "notes/unrenote", params: params)
            let data = try await makeMisskeyRequest(path: "notes/show", params: ["noteId": id])
            return try JSONDecoder().decode(MisskeyNote.self, from: data).toStatus(server: self.server) as! Entity

        } else if path.hasSuffix("/bookmark") && path.hasPrefix("statuses/") {
            let id = path.replacingOccurrences(of: "statuses/", with: "").replacingOccurrences(of: "/bookmark", with: "")
            params["noteId"] = id
            let _ = try? await makeMisskeyRequest(path: "notes/favorites/create", params: params)
            let data = try await makeMisskeyRequest(path: "notes/show", params: ["noteId": id])
            return try JSONDecoder().decode(MisskeyNote.self, from: data).toStatus(server: self.server) as! Entity

        } else if path.hasSuffix("/unbookmark") && path.hasPrefix("statuses/") {
            let id = path.replacingOccurrences(of: "statuses/", with: "").replacingOccurrences(of: "/unbookmark", with: "")
            params["noteId"] = id
            let _ = try? await makeMisskeyRequest(path: "notes/favorites/delete", params: params)
            let data = try await makeMisskeyRequest(path: "notes/show", params: ["noteId": id])
            return try JSONDecoder().decode(MisskeyNote.self, from: data).toStatus(server: self.server) as! Entity

        } else if path.hasSuffix("/pin") && path.hasPrefix("statuses/") {
            let id = path.replacingOccurrences(of: "statuses/", with: "").replacingOccurrences(of: "/pin", with: "")
            params["noteId"] = id
            let _ = try? await makeMisskeyRequest(path: "i/pin", params: params)
            let data = try await makeMisskeyRequest(path: "notes/show", params: ["noteId": id])
            return try JSONDecoder().decode(MisskeyNote.self, from: data).toStatus(server: self.server) as! Entity

        } else if path.hasSuffix("/unpin") && path.hasPrefix("statuses/") {
            let id = path.replacingOccurrences(of: "statuses/", with: "").replacingOccurrences(of: "/unpin", with: "")
            params["noteId"] = id
            let _ = try? await makeMisskeyRequest(path: "i/unpin", params: params)
            let data = try await makeMisskeyRequest(path: "notes/show", params: ["noteId": id])
            return try JSONDecoder().decode(MisskeyNote.self, from: data).toStatus(server: self.server) as! Entity

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
            // Misskey has no Mastodon-compatible translation endpoint. Throw
            // instead of returning an empty success response so StatusRowViewModel
            // can continue to its DeepL or Apple Translation fallback.
            throw FediverseClient.ClientError.unexpectedRequest
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
            throw FediverseClient.ClientError.unexpectedRequest

        } else if path.hasPrefix("lists/") && path.hasSuffix("/accounts") {
            let listId = path
                .replacingOccurrences(of: "lists/", with: "")
                .replacingOccurrences(of: "/accounts", with: "")
            for accountId in params["account_ids[]"] as? [String] ?? [] {
                let _ = try await makeMisskeyRequest(
                    path: "users/lists/push",
                    params: ["listId": listId, "userId": accountId])
            }
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
        let path = endpoint.path()
        guard path.hasPrefix("lists/") else {
            throw FediverseClient.ClientError.unexpectedRequest
        }
        let listId = path.replacingOccurrences(of: "lists/", with: "")
        let data = try await makeMisskeyRequest(
            path: "users/lists/update",
            params: ["listId": listId] .merging(extractParams(from: endpoint)) { _, new in new })
        let list = try JSONDecoder().decode(MisskeyList.self, from: data)
        return Models.List(id: list.id, title: list.name, repliesPolicy: .list) as! Entity
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
            if let name = params["displayName"] as? String { misskeyParams["name"] = name }
            if let note = params["note"] as? String { misskeyParams["description"] = note }
            if let locked = params["locked"] as? Bool { misskeyParams["isLocked"] = locked }
            if let fields = params["fieldsAttributes"] as? [String: Any] {
                misskeyParams["fields"] = fields
                    .keys
                    .sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }
                    .compactMap { key -> [String: String]? in
                        guard let field = fields[key] as? [String: Any] else { return nil }
                        return [
                            "name": field["name"] as? String ?? "",
                            "value": field["value"] as? String ?? ""
                        ]
                    }
            }
            let _ = try await makeMisskeyRequest(path: "i/update", params: misskeyParams)
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
        guard endpoint.path() == "accounts/update_credentials" else { return nil }

        var params = extractParams(from: endpoint)
        var misskeyParams: [String: Any] = [:]
        if let name = params["displayName"] as? String { misskeyParams["name"] = name }
        if let note = params["note"] as? String { misskeyParams["description"] = note }
        if let locked = params["locked"] as? Bool { misskeyParams["isLocked"] = locked }
        if let fields = params["fieldsAttributes"] as? [String: Any] {
            misskeyParams["fields"] = fields
                .keys
                .sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }
                .compactMap { key -> [String: String]? in
                    guard let field = fields[key] as? [String: Any] else { return nil }
                    return [
                        "name": field["name"] as? String ?? "",
                        "value": field["value"] as? String ?? ""
                    ]
                }
        }
        _ = try await makeMisskeyRequest(path: "i/update", params: misskeyParams)
        return HTTPURLResponse(
            url: URL(string: "https://\(server)/api/i/update")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)
    }

    // MARK: - DELETE

    public func delete(endpoint: Endpoint, forceVersion: FediverseClient.Version? = nil) async throws -> HTTPURLResponse? {
        let path = endpoint.path()
        var params = extractParams(from: endpoint)

        if path.hasPrefix("statuses/") && path.components(separatedBy: "/").count == 2 {
            let id = path.replacingOccurrences(of: "statuses/", with: "")
            let _ = try? await makeMisskeyRequest(path: "notes/delete", params: ["noteId": id])
            return HTTPURLResponse(url: URL(string: "https://\(server)")!, statusCode: 200, httpVersion: nil, headerFields: nil)

        } else if path.hasPrefix("conversations/") {
            let userId = path.replacingOccurrences(of: "conversations/", with: "")
            let data = try await makeMisskeyRequest(
                path: "messaging/messages",
                params: ["userId": userId, "limit": 1])
            let message = try JSONDecoder().decode([MisskeyMessagingMessage].self, from: data).first
            if let message {
                _ = try await makeMisskeyRequest(
                    path: "messaging/messages/delete",
                    params: ["messageId": message.id])
            }
            return HTTPURLResponse(url: URL(string: "https://\(server)")!, statusCode: 200, httpVersion: nil, headerFields: nil)

        } else if path.hasPrefix("accounts/") && path.hasSuffix("/unblock") {
            let id = path.replacingOccurrences(of: "accounts/", with: "").replacingOccurrences(of: "/unblock", with: "")
            params["userId"] = id
            let _ = try? await makeMisskeyRequest(path: "blocking/delete", params: params)
            return HTTPURLResponse(url: URL(string: "https://\(server)")!, statusCode: 200, httpVersion: nil, headerFields: nil)

        } else if path.hasPrefix("lists/") && path.hasSuffix("/accounts") {
            let listId = path
                .replacingOccurrences(of: "lists/", with: "")
                .replacingOccurrences(of: "/accounts", with: "")
            for accountId in params["account_ids[]"] as? [String] ?? [] {
                let _ = try? await makeMisskeyRequest(
                    path: "users/lists/pull",
                    params: ["listId": listId, "userId": accountId])
            }

            return HTTPURLResponse(url: URL(string: "https://\(server)")!, statusCode: 200, httpVersion: nil, headerFields: nil)

        } else if path.hasPrefix("lists/") {
            let listId = path.replacingOccurrences(of: "lists/", with: "")
            let _ = try? await makeMisskeyRequest(
                path: "users/lists/delete", params: ["listId": listId])
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
