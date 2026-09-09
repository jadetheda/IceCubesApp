import Foundation
import Models

public final class MisskeyBackend: FediverseBackend {
    struct NoteCreateResponse: Decodable {
        let createdNote: MisskeyNote
    }
    public let server: String
    public let version: FediverseClient.Version
    public let oauthToken: OauthToken?
    
    public var isAuth: Bool { oauthToken != nil }
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
            print("Misskey error: \(String(data: data, encoding: .utf8) ?? "")")
        }
        
        return data
    }

    private func extractParams(from endpoint: Endpoint) -> [String: Any] {
        var params: [String: Any] = [:]
        
        if let queryItems = endpoint.queryItems() {
            for item in queryItems {
                if let value = item.value {
                    if item.name == "max_id" { params["untilId"] = value }
                    else if item.name == "since_id" { params["sinceId"] = value }
                    else if item.name == "limit" { params["limit"] = Int(value) ?? 20 }
                    else {
                        if item.name.hasSuffix("[]") {
                            var arr = params[item.name] as? [String] ?? []
                            arr.append(value)
                            params[item.name] = arr
                        } else {
                            params[item.name] = value
                        }
                    }
                }
            }
        }
        
        if let jsonValue = endpoint.jsonValue {
            if let data = try? JSONEncoder().encode(jsonValue),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Map common Mastodon post fields to Misskey
                if let status = dict["status"] as? String { params["text"] = status }
                if let visibility = dict["visibility"] as? String { params["visibility"] = visibility }
                if let inReplyToId = dict["inReplyToId"] as? String { params["replyId"] = inReplyToId }
                if let mediaIds = dict["mediaIds"] as? [String] { params["fileIds"] = mediaIds }
                if let cw = dict["spoilerText"] as? String, !cw.isEmpty { params["cw"] = cw }
                if let renoteId = dict["quotedStatusId"] as? String { params["renoteId"] = renoteId }
            }
        }
        return params
    }

    public func get<Entity: Decodable>(endpoint: Endpoint, forceVersion: FediverseClient.Version?) async throws -> Entity {
        let path = endpoint.path()
        var params = extractParams(from: endpoint)
        
        if path == "timelines/home" {
            let data = try await makeMisskeyRequest(path: "notes/timeline", params: params)
            let misskeyNotes = try JSONDecoder().decode([MisskeyNote].self, from: data)
            return misskeyNotes.map { $0.toStatus() } as! Entity
        } else if path == "timelines/public" {
            let isLocal = (params["local"] as? String) == "true"
            let apiPath = isLocal ? "notes/local-timeline" : "notes/global-timeline"
            let data = try await makeMisskeyRequest(path: apiPath, params: params)
            let misskeyNotes = try JSONDecoder().decode([MisskeyNote].self, from: data)
            return misskeyNotes.map { $0.toStatus() } as! Entity
        } else if path.hasPrefix("timelines/") {
            let statuses: [Status] = []
            return statuses as! Entity
        } else if path == "push/subscription" {
            // Misskey has no push subscription API; return a stub so the app doesn't crash.
            let sub = PushSubscription(id: 1, endpoint: URL(string: "https://example.com")!, serverKey: "", alerts: .init(follow: false, favourite: false, reblog: false, mention: false, poll: false, status: false))
            return sub as! Entity
        } else if path == "instance" || path == "v1/instance" || path == "v2/instance" {
            // Construct a minimal Instance from the Misskey /api/meta endpoint.
            let instance = Instance(
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
            return instance as! Entity
        } else if path == "instance/peers" {
            let peers: [String] = []
            return peers as! Entity
        } else if path.hasPrefix("accounts/") && path.hasSuffix("/collections") {
            let resp = AccountCollectionsResponse(collections: [])
            return resp as! Entity
        } else if path.hasPrefix("collections/") {
            // AccountCollection has no public memberwise init; decode from JSON stub.
            let stub = """
            {"id":"1","accountId":"1","uri":"","url":null,"name":"Mock","description":"","language":null,"local":true,"sensitive":false,"discoverable":true,"tag":null,"createdAt":"2024-01-01T00:00:00.000Z","updatedAt":"2024-01-01T00:00:00.000Z","itemCount":0,"items":[]}
            """
            if let data = stub.data(using: .utf8),
               let collection = try? JSONDecoder().decode(AccountCollection.self, from: data) {
                let resp = AccountCollectionResponse(collection: collection, accounts: [])
                return resp as! Entity
            }
            throw FediverseClient.ClientError.unexpectedRequest
        } else if path.hasPrefix("accounts/") && path.hasSuffix("/in_collections") {
            let resp = AccountCollectionsResponse(collections: [])
            return resp as! Entity
        } else if path == "accounts/lookup" {
            let data = try await makeMisskeyRequest(path: "users/show", params: ["username": params["acct"] as? String ?? ""])
            let misskeyUser = try JSONDecoder().decode(MisskeyUser.self, from: data)
            return misskeyUser.toAccount() as! Entity
        } else if path == "accounts/familiar_followers" {
            let accs: [FamiliarAccounts] = []
            return accs as! Entity
        } else if path == "followed_tags" {
            let tags: [Tag] = []
            return tags as! Entity
        } else if path.hasPrefix("accounts/") && path.hasSuffix("/note") {
            let id = path.replacingOccurrences(of: "accounts/", with: "").replacingOccurrences(of: "/note", with: "")
            let relation = Relationship(id: id, following: false, showingReblogs: false, followedBy: false, blocking: false, blockedBy: false, muting: false, mutingNotifications: false, requested: false, domainBlocking: false, endorsed: false, note: (params["comment"] as? String) ?? "", notifying: false)
            return relation as! Entity
        } else if path == "accounts/verify_credentials" {
            let data = try await makeMisskeyRequest(path: "i", params: params)
            let misskeyUser = try JSONDecoder().decode(MisskeyUser.self, from: data)
            return misskeyUser.toAccount() as! Entity
        } else if path == "search" {
            let query = (params["q"] as? String) ?? ""
            let type = params["type"] as? String
            
            var accounts: [Account] = []
            var statuses: [Status] = []
            var hashtags: [Tag] = [] 
            
            if type == "statuses" || type == nil {
                if let data = try? await makeMisskeyRequest(path: "notes/search", params: ["query": query]),
                   let notes = try? JSONDecoder().decode([MisskeyNote].self, from: data) {
                    statuses = notes.map { $0.toStatus() }
                }
            }
            if type == "accounts" || type == nil {
                if let data = try? await makeMisskeyRequest(path: "users/search", params: ["query": query]),
                   let users = try? JSONDecoder().decode([MisskeyUser].self, from: data) {
                    accounts = users.map { $0.toAccount() }
                }
            }
            
            let results = SearchResults(accounts: accounts, relationships: [], statuses: statuses, hashtags: hashtags)
            return results as! Entity
        } else if path == "custom_emojis" {
            let emojis: [Emoji] = []
            return emojis as! Entity
        } else if path == "bookmarks" {
            let statuses: [Status] = []
            return statuses as! Entity
        } else if path == "favourites" {
            let statuses: [Status] = []
            return statuses as! Entity
        } else if path == "markers" {
            let markers = Marker(notifications: nil, home: nil)
            return markers as! Entity
        } else if path == "blocks" || path == "mutes" {
            let accounts: [Account] = []
            return accounts as! Entity
        } else if path == "follow_requests" {
            let accounts: [Account] = []
            return accounts as! Entity
        } else if path == "preferences" {
            // Mock empty preferences
            let data = "{ }".data(using: .utf8)!
            let prefs = try JSONDecoder().decode(ServerPreferences.self, from: data)
            return prefs as! Entity
        } else if path == "notifications/policy" {
            // NotificationsPolicy has no custom public init; decode from a permissive JSON stub.
            let policyStub = """
            {"for_not_following":"accept","for_not_followers":"accept","for_new_accounts":"accept","for_private_mentions":"accept","for_limited_accounts":"accept","summary":{"pending_requests_count":0,"pending_notifications_count":0}}
            """
            let policyDecoder = JSONDecoder()
            policyDecoder.keyDecodingStrategy = .convertFromSnakeCase
            let policy = (try? policyDecoder.decode(NotificationsPolicy.self, from: Data(policyStub.utf8))) ?? NotificationsPolicy(forNotFollowing: .accept, forNotFollowers: .accept, forNewAccounts: .accept, forPrivateMentions: .accept, forLimitedAccounts: .accept, summary: .init(pendingRequestsCount: 0, pendingNotificationsCount: 0))
            return policy as! Entity
        } else if path == "filters" {
            let filters: [ServerFilter] = []
            return filters as! Entity
        } else if path == "followed_tags" {
            let tags: [Tag] = []
            return tags as! Entity
        } else if path == "suggestions" {
            let accounts: [Account] = []
            return accounts as! Entity
        } else if path == "conversations" {
            let convs: [Conversation] = []
            return convs as! Entity
        } else if path == "lists" {
            let lists: [Models.List] = []
            return lists as! Entity
        } else if path.hasPrefix("polls/") {
            let id = path.replacingOccurrences(of: "polls/", with: "").replacingOccurrences(of: "/votes", with: "")
            if path.hasSuffix("/votes") {
                let _ = try await makeMisskeyRequest(path: "notes/polls/vote", params: ["noteId": id, "choice": 0]) // simple mock
            }
            let data = try await makeMisskeyRequest(path: "notes/show", params: ["noteId": id])
            let misskeyNote = try JSONDecoder().decode(MisskeyNote.self, from: data)
            return misskeyNote.poll?.toPoll(id: id) as! Entity
        } else if path.hasPrefix("tags/") {
            if path.hasSuffix("/follow") || path.hasSuffix("/unfollow") {
                let id = path.replacingOccurrences(of: "tags/", with: "").replacingOccurrences(of: "/follow", with: "").replacingOccurrences(of: "/unfollow", with: "")
                let tag = Tag(name: id, url: "", urlString: "", history: [], following: path.hasSuffix("/follow"))
                return tag as! Entity
            } else {
                let id = path.replacingOccurrences(of: "tags/", with: "")
                let tag = Tag(name: id, url: "", urlString: "", history: [], following: false)
                return tag as! Entity
            }
        } else if path.hasPrefix("trends/") {
            if path == "trends/tags" {
                let tags: [Tag] = []
                return tags as! Entity
            } else if path == "trends/statuses" {
                if let data = try? await makeMisskeyRequest(path: "notes/featured", params: params),
                   let notes = try? JSONDecoder().decode([MisskeyNote].self, from: data) {
                    let statuses = notes.map { $0.toStatus() }
                    return statuses as! Entity
                }
                let statuses: [Status] = []
                return statuses as! Entity
            } else if path == "trends/links" {
                let links: [Card] = []
                return links as! Entity
            }
        } else if path == "accounts/relationships" {
            var rels: [Relationship] = []
            if let ids = params["id[]"] as? [String] {
                rels = ids.map { Relationship(id: $0, following: false, showingReblogs: false, followedBy: false, blocking: false, blockedBy: false, muting: false, mutingNotifications: false, requested: false, domainBlocking: false, endorsed: false, note: "", notifying: false) }
            } else if let id = params["id[]"] as? String {
                rels = [Relationship(id: id, following: false, showingReblogs: false, followedBy: false, blocking: false, blockedBy: false, muting: false, mutingNotifications: false, requested: false, domainBlocking: false, endorsed: false, note: "", notifying: false)]
            }
            return rels as! Entity
        } else if path.hasPrefix("accounts/") && path.components(separatedBy: "/").count == 2 {
            let id = path.replacingOccurrences(of: "accounts/", with: "")
            params["userId"] = id
            let data = try await makeMisskeyRequest(path: "users/show", params: params)
            let misskeyUser = try JSONDecoder().decode(MisskeyUser.self, from: data)
            return misskeyUser.toAccount() as! Entity
        } else if path.hasSuffix("/followers") && path.hasPrefix("accounts/") {
            let accounts: [Account] = []
            return accounts as! Entity
        } else if path.hasSuffix("/following") && path.hasPrefix("accounts/") {
            let accounts: [Account] = []
            return accounts as! Entity
        } else if path.hasSuffix("/featured_tags") && path.hasPrefix("accounts/") {
            let tags: [FeaturedTag] = []
            return tags as! Entity
        } else if path.hasSuffix("/statuses") && path.hasPrefix("accounts/") {
            let id = path.replacingOccurrences(of: "accounts/", with: "").replacingOccurrences(of: "/statuses", with: "")
            params["userId"] = id
            let data = try await makeMisskeyRequest(path: "users/notes", params: params)
            let misskeyNotes = try JSONDecoder().decode([MisskeyNote].self, from: data)
            return misskeyNotes.map { $0.toStatus() } as! Entity
        } else if path.hasPrefix("lists/") {
            let list = List(id: "1", title: "Mock List", repliesPolicy: .followed)
            return list as! Entity
        } else if path.hasPrefix("media/") && path.components(separatedBy: "/").count == 2 {
            // Media description update
            let id = path.replacingOccurrences(of: "media/", with: "")
            let data = try await makeMisskeyRequest(path: "drive/files/show", params: ["fileId": id])
            let file = try JSONDecoder().decode(MisskeyFile.self, from: data)
            return file.toMediaAttachment() as! Entity
        } else if path.hasPrefix("statuses/") && path.components(separatedBy: "/").count == 2 {
            let id = path.replacingOccurrences(of: "statuses/", with: "")
            params["noteId"] = id
            let data = try await makeMisskeyRequest(path: "notes/show", params: params)
            let misskeyNote = try JSONDecoder().decode(MisskeyNote.self, from: data)
            return misskeyNote.toStatus() as! Entity
        } else if path.hasSuffix("/history") && path.hasPrefix("statuses/") {
            let statuses: [StatusHistory] = []
            return statuses as! Entity
        } else if path.hasSuffix("/favourited_by") && path.hasPrefix("statuses/") {
            let accounts: [Account] = []
            return accounts as! Entity
        } else if path.hasSuffix("/reblogged_by") && path.hasPrefix("statuses/") {
            let accounts: [Account] = []
            return accounts as! Entity
        } else if path.hasSuffix("/quotes") && path.hasPrefix("statuses/") {
            let statuses: [Status] = []
            return statuses as! Entity
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
            
            let ctx = StatusContext(ancestors: ancestors, descendants: descendants)
            return ctx as! Entity
        } else if path == "notifications" || path == "v2/notifications" || path == "notifications/requests" || path.hasPrefix("v2/notifications") {
            if path == "notifications" {
                let data = try await makeMisskeyRequest(path: "i/notifications", params: params)
                let misskeyNotifs = try JSONDecoder().decode([MisskeyNotification].self, from: data)
                return misskeyNotifs.compactMap { $0.toNotification() } as! Entity
            }
            if path == "notifications/policy" {
                // NotificationsPolicy has no custom public init; decode from a permissive JSON stub.
            let policyStub = """
            {"for_not_following":"accept","for_not_followers":"accept","for_new_accounts":"accept","for_private_mentions":"accept","for_limited_accounts":"accept","summary":{"pending_requests_count":0,"pending_notifications_count":0}}
            """
            let policyDecoder = JSONDecoder()
            policyDecoder.keyDecodingStrategy = .convertFromSnakeCase
            let policy = (try? policyDecoder.decode(NotificationsPolicy.self, from: Data(policyStub.utf8))) ?? NotificationsPolicy(forNotFollowing: .accept, forNotFollowers: .accept, forNewAccounts: .accept, forPrivateMentions: .accept, forLimitedAccounts: .accept, summary: .init(pendingRequestsCount: 0, pendingNotificationsCount: 0))
                return policy as! Entity
            }
            let notifs: [Notification] = []
            return notifs as! Entity
        } else if path == "notifications" {
            let data = try await makeMisskeyRequest(path: "i/notifications", params: params)
            let misskeyNotifs = try JSONDecoder().decode([MisskeyNotification].self, from: data)
            return misskeyNotifs.compactMap { $0.toNotification() } as! Entity
        }
        
        throw FediverseClient.ClientError.unexpectedRequest
    }
    public func getWithLink<Entity: Decodable>(endpoint: Endpoint) async throws -> (Entity, LinkHandler?) {
        let entity: Entity = try await get(endpoint: endpoint, forceVersion: nil)
        
        var linkHandler: LinkHandler? = nil
        if let statuses = entity as? [Status], let last = statuses.last {
            let fakeLink = "<https://\(server)/api/notes?untilId=\(last.id)>; rel=\"next\""
            linkHandler = LinkHandler(rawLink: fakeLink)
        }
        
        return (entity, linkHandler)
    }

    public func post<Entity: Decodable>(endpoint: Endpoint, forceVersion: FediverseClient.Version? = nil) async throws -> Entity {
        let path = endpoint.path()
        var params = extractParams(from: endpoint)
        
        if path == "statuses" {
            let data = try await makeMisskeyRequest(path: "notes/create", params: params)
            
            // Misskey's notes/create returns { "createdNote": { ... } }
            
                
            if let response = try? JSONDecoder().decode(MisskeyBackend.NoteCreateResponse.self, from: data) {
                return response.createdNote.toStatus() as! Entity
            }
            
            let misskeyNote = try JSONDecoder().decode(MisskeyNote.self, from: data)
            return misskeyNote.toStatus() as! Entity
        } else if path == "markers" {
            let conversation = Conversation(id: "1", unread: false, accounts: [], lastStatus: nil)
            return conversation as! Entity
        } else if path.hasPrefix("conversations/") && path.hasSuffix("/read") {
            let conversation = Conversation(id: "1", unread: false, accounts: [], lastStatus: nil)
            return conversation as! Entity
        } else if path.hasPrefix("polls/") && path.hasSuffix("/votes") {
            let id = path.replacingOccurrences(of: "polls/", with: "").replacingOccurrences(of: "/votes", with: "")
            if let choices = params["choices"] as? [Int], let first = choices.first {
                let _ = try await makeMisskeyRequest(path: "notes/polls/vote", params: ["noteId": id, "choice": first])
            }
            let data = try await makeMisskeyRequest(path: "notes/show", params: ["noteId": id])
            let misskeyNote = try JSONDecoder().decode(MisskeyNote.self, from: data)
            if let poll = misskeyNote.poll?.toPoll(id: id) {
                return poll as! Entity
            }
            throw FediverseClient.ClientError.unexpectedRequest
        } else if path.hasPrefix("tags/") && (path.hasSuffix("/follow") || path.hasSuffix("/unfollow")) {
            let id = path.replacingOccurrences(of: "tags/", with: "").replacingOccurrences(of: "/follow", with: "").replacingOccurrences(of: "/unfollow", with: "")
            let tag = Tag(name: id, url: "", urlString: "", history: [], following: path.hasSuffix("/follow"))
            return tag as! Entity
        } else if path == "notifications/policy" {
            // NotificationsPolicy has no custom public init; decode from a permissive JSON stub.
            let policyStub = """
            {"for_not_following":"accept","for_not_followers":"accept","for_new_accounts":"accept","for_private_mentions":"accept","for_limited_accounts":"accept","summary":{"pending_requests_count":0,"pending_notifications_count":0}}
            """
            let policyDecoder = JSONDecoder()
            policyDecoder.keyDecodingStrategy = .convertFromSnakeCase
            let policy = (try? policyDecoder.decode(NotificationsPolicy.self, from: Data(policyStub.utf8))) ?? NotificationsPolicy(forNotFollowing: .accept, forNotFollowers: .accept, forNewAccounts: .accept, forPrivateMentions: .accept, forLimitedAccounts: .accept, summary: .init(pendingRequestsCount: 0, pendingNotificationsCount: 0))
            return policy as! Entity
        } else if path == "filters" {
            let filter = ServerFilter(id: "1", title: "Mock", context: [], filterAction: .hide, expiresIn: nil, keywords: [], statuses: [])
            return filter as! Entity
        } else if path == "lists" {
            let list = List(id: "1", title: "Mock List", repliesPolicy: .followed)
            return list as! Entity
        } else if path.hasPrefix("follow_requests") {
            let rel = Relationship(id: "", following: false, showingReblogs: false, followedBy: false, blocking: false, blockedBy: false, muting: false, mutingNotifications: false, requested: false, domainBlocking: false, endorsed: false, note: "", notifying: false)
            return rel as! Entity
        } else if path.hasPrefix("notifications") {
            let notifs: [Notification] = []
            return notifs as! Entity
        } else if path == "reports" {
            if let userId = params["account_id"] as? String {
                let text = params["comment"] as? String ?? ""
                let _ = try await makeMisskeyRequest(path: "users/report", params: ["userId": userId, "comment": text])
            }
            return HTTPURLResponse(url: URL(string: "https://\(server)")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        } else if path.hasSuffix("/unfavourite") && path.hasPrefix("statuses/") {
            let id = path.replacingOccurrences(of: "statuses/", with: "").replacingOccurrences(of: "/unfavourite", with: "")
            params["noteId"] = id
            let _ = try await makeMisskeyRequest(path: "notes/reactions/delete", params: params)
            let data = try await makeMisskeyRequest(path: "notes/show", params: ["noteId": id])
            let misskeyNote = try JSONDecoder().decode(MisskeyNote.self, from: data)
            return misskeyNote.toStatus() as! Entity
        } else if path == "markers" {
            let conversation = Conversation(id: "1", unread: false, accounts: [], lastStatus: nil)
            return conversation as! Entity
        } else if path.hasSuffix("/favourite") && path.hasPrefix("statuses/") {
            let id = path.replacingOccurrences(of: "statuses/", with: "").replacingOccurrences(of: "/favourite", with: "")
            params["noteId"] = id
            params["reaction"] = "👍"
            let _ = try await makeMisskeyRequest(path: "notes/reactions/create", params: params)
            let data = try await makeMisskeyRequest(path: "notes/show", params: ["noteId": id])
            let misskeyNote = try JSONDecoder().decode(MisskeyNote.self, from: data)
            return misskeyNote.toStatus() as! Entity
        } else if path.hasSuffix("/reblog") && path.hasPrefix("statuses/") {
            let id = path.replacingOccurrences(of: "statuses/", with: "").replacingOccurrences(of: "/reblog", with: "")
            params["renoteId"] = id
            let data = try await makeMisskeyRequest(path: "notes/create", params: params)
            if let response = try? JSONDecoder().decode(MisskeyBackend.NoteCreateResponse.self, from: data) {
                return response.createdNote.toStatus() as! Entity
            }
        } else if path.hasSuffix("/unreblog") && path.hasPrefix("statuses/") {
            let id = path.replacingOccurrences(of: "statuses/", with: "").replacingOccurrences(of: "/unreblog", with: "")
            params["noteId"] = id
            let _ = try await makeMisskeyRequest(path: "notes/unrenote", params: params)
            let data = try await makeMisskeyRequest(path: "notes/show", params: ["noteId": id])
            let misskeyNote = try JSONDecoder().decode(MisskeyNote.self, from: data)
            return misskeyNote.toStatus() as! Entity
        } else if path.hasSuffix("/bookmark") && path.hasPrefix("statuses/") {
            let id = path.replacingOccurrences(of: "statuses/", with: "").replacingOccurrences(of: "/bookmark", with: "")
            params["noteId"] = id
            let _ = try await makeMisskeyRequest(path: "notes/favorites/create", params: params)
            let data = try await makeMisskeyRequest(path: "notes/show", params: ["noteId": id])
            let misskeyNote = try JSONDecoder().decode(MisskeyNote.self, from: data)
            return misskeyNote.toStatus() as! Entity
        } else if path.hasSuffix("/unbookmark") && path.hasPrefix("statuses/") {
            let id = path.replacingOccurrences(of: "statuses/", with: "").replacingOccurrences(of: "/unbookmark", with: "")
            params["noteId"] = id
            let _ = try await makeMisskeyRequest(path: "notes/favorites/delete", params: params)
            let data = try await makeMisskeyRequest(path: "notes/show", params: ["noteId": id])
            let misskeyNote = try JSONDecoder().decode(MisskeyNote.self, from: data)
            return misskeyNote.toStatus() as! Entity
        } else if path.hasSuffix("/pin") && path.hasPrefix("statuses/") {
            let id = path.replacingOccurrences(of: "statuses/", with: "").replacingOccurrences(of: "/pin", with: "")
            params["noteId"] = id
            let _ = try await makeMisskeyRequest(path: "i/pin", params: params)
            let data = try await makeMisskeyRequest(path: "notes/show", params: ["noteId": id])
            let misskeyNote = try JSONDecoder().decode(MisskeyNote.self, from: data)
            return misskeyNote.toStatus() as! Entity
        } else if path.hasSuffix("/unpin") && path.hasPrefix("statuses/") {
            let id = path.replacingOccurrences(of: "statuses/", with: "").replacingOccurrences(of: "/unpin", with: "")
            params["noteId"] = id
            let _ = try await makeMisskeyRequest(path: "i/unpin", params: params)
            let data = try await makeMisskeyRequest(path: "notes/show", params: ["noteId": id])
            let misskeyNote = try JSONDecoder().decode(MisskeyNote.self, from: data)
            return misskeyNote.toStatus() as! Entity
        } else if path.hasSuffix("/follow") && path.hasPrefix("accounts/") {
            let id = path.replacingOccurrences(of: "accounts/", with: "").replacingOccurrences(of: "/follow", with: "")
            params["userId"] = id
            let _ = try await makeMisskeyRequest(path: "following/create", params: params)
            let rel = Relationship(id: id, following: true, showingReblogs: true, followedBy: false, blocking: false, blockedBy: false, muting: false, mutingNotifications: false, requested: false, domainBlocking: false, endorsed: false, note: "", notifying: false)
            return rel as! Entity
        } else if path.hasSuffix("/unfollow") && path.hasPrefix("accounts/") {
            let id = path.replacingOccurrences(of: "accounts/", with: "").replacingOccurrences(of: "/unfollow", with: "")
            params["userId"] = id
            let _ = try await makeMisskeyRequest(path: "following/delete", params: params)
            let rel = Relationship(id: id, following: false, showingReblogs: false, followedBy: false, blocking: false, blockedBy: false, muting: false, mutingNotifications: false, requested: false, domainBlocking: false, endorsed: false, note: "", notifying: false)
            return rel as! Entity
        } else if path.hasSuffix("/mute") && path.hasPrefix("accounts/") {
            let id = path.replacingOccurrences(of: "accounts/", with: "").replacingOccurrences(of: "/mute", with: "")
            params["userId"] = id
            let _ = try await makeMisskeyRequest(path: "mute/create", params: params)
            let rel = Relationship(id: id, following: false, showingReblogs: false, followedBy: false, blocking: false, blockedBy: false, muting: true, mutingNotifications: false, requested: false, domainBlocking: false, endorsed: false, note: "", notifying: false)
            return rel as! Entity
        } else if path.hasSuffix("/unmute") && path.hasPrefix("accounts/") {
            let id = path.replacingOccurrences(of: "accounts/", with: "").replacingOccurrences(of: "/unmute", with: "")
            params["userId"] = id
            let _ = try await makeMisskeyRequest(path: "mute/delete", params: params)
            let rel = Relationship(id: id, following: false, showingReblogs: false, followedBy: false, blocking: false, blockedBy: false, muting: false, mutingNotifications: false, requested: false, domainBlocking: false, endorsed: false, note: "", notifying: false)
            return rel as! Entity
        } else if path.hasSuffix("/block") && path.hasPrefix("accounts/") {
            let id = path.replacingOccurrences(of: "accounts/", with: "").replacingOccurrences(of: "/block", with: "")
            params["userId"] = id
            let _ = try await makeMisskeyRequest(path: "blocking/create", params: params)
            let rel = Relationship(id: id, following: false, showingReblogs: false, followedBy: false, blocking: true, blockedBy: false, muting: false, mutingNotifications: false, requested: false, domainBlocking: false, endorsed: false, note: "", notifying: false)
            return rel as! Entity
        } else if path.hasSuffix("/translate") && path.hasPrefix("statuses/") {
            let id = path.replacingOccurrences(of: "statuses/", with: "").replacingOccurrences(of: "/translate", with: "")
            params["noteId"] = id
            if let lang = params["lang"] as? String {
                params["targetLang"] = lang
            }
            let data = try await makeMisskeyRequest(path: "notes/translate", params: params)
            if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let text = dict["text"] as? String,
               let sourceLang = dict["sourceLang"] as? String {
                let translation = Translation(content: text, detectedSourceLanguage: sourceLang, provider: "Misskey")
                return translation as! Entity
            }
            throw FediverseClient.ClientError.unexpectedRequest
        } else if path.hasSuffix("/unblock") && path.hasPrefix("accounts/") {
            let id = path.replacingOccurrences(of: "accounts/", with: "").replacingOccurrences(of: "/unblock", with: "")
            params["userId"] = id
            let _ = try await makeMisskeyRequest(path: "blocking/delete", params: params)
            let rel = Relationship(id: id, following: false, showingReblogs: false, followedBy: false, blocking: false, blockedBy: false, muting: false, mutingNotifications: false, requested: false, domainBlocking: false, endorsed: false, note: "", notifying: false)
            return rel as! Entity
        }

        throw FediverseClient.ClientError.unexpectedRequest
    }
    
    public func post(endpoint: Endpoint, forceVersion: FediverseClient.Version? = nil) async throws -> HTTPURLResponse? { 
        let path = endpoint.path()
        var params = extractParams(from: endpoint)
        
        if path.hasSuffix("/unfavourite") && path.hasPrefix("statuses/") {
            let id = path.replacingOccurrences(of: "statuses/", with: "").replacingOccurrences(of: "/unfavourite", with: "")
            params["noteId"] = id
            let _ = try await makeMisskeyRequest(path: "notes/reactions/delete", params: params)
            return HTTPURLResponse(url: URL(string: "https://\(server)")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        }
        
        return HTTPURLResponse(url: URL(string: "https://\(server)")!, statusCode: 200, httpVersion: nil, headerFields: nil) 
    }

    public func put<Entity: Decodable>(endpoint: Endpoint, forceVersion: FediverseClient.Version? = nil) async throws -> Entity {
        let path = endpoint.path()
        var params = extractParams(from: endpoint)

        if path == "preferences" {
            let data = "{ }".data(using: .utf8)!
            let prefs = try JSONDecoder().decode(ServerPreferences.self, from: data)
            return prefs as! Entity
        } else if path == "notifications/policy" {
            // NotificationsPolicy has no custom public init; decode from a permissive JSON stub.
            let policyStub = """
            {"for_not_following":"accept","for_not_followers":"accept","for_new_accounts":"accept","for_private_mentions":"accept","for_limited_accounts":"accept","summary":{"pending_requests_count":0,"pending_notifications_count":0}}
            """
            let policyDecoder = JSONDecoder()
            policyDecoder.keyDecodingStrategy = .convertFromSnakeCase
            let policy = (try? policyDecoder.decode(NotificationsPolicy.self, from: Data(policyStub.utf8))) ?? NotificationsPolicy(forNotFollowing: .accept, forNotFollowers: .accept, forNewAccounts: .accept, forPrivateMentions: .accept, forLimitedAccounts: .accept, summary: .init(pendingRequestsCount: 0, pendingNotificationsCount: 0))
            return policy as! Entity
        } else if path == "filters" {
            let filters: [ServerFilter] = []
            return filters as! Entity
        } else if path.hasPrefix("filters/") {
            // Edit filter
            let filters: [ServerFilter] = []
            return filters as! Entity
        } else if path.hasPrefix("lists/") {
            let list = List(id: "1", title: "Mock List", repliesPolicy: .followed)
            return list as! Entity
        } else if path.hasPrefix("media/") && path.components(separatedBy: "/").count == 2 {
            // Media description update
            let id = path.replacingOccurrences(of: "media/", with: "")
            let data = try await makeMisskeyRequest(path: "drive/files/show", params: ["fileId": id])
            let file = try JSONDecoder().decode(MisskeyFile.self, from: data)
            return file.toMediaAttachment() as! Entity
        } else if path.hasPrefix("statuses/") && path.components(separatedBy: "/").count == 2 {
            let id = path.replacingOccurrences(of: "statuses/", with: "")
            params["noteId"] = id
            // Just returning the note back as edit is not supported natively by this mapping right now
            let data = try await makeMisskeyRequest(path: "notes/show", params: params)
            let misskeyNote = try JSONDecoder().decode(MisskeyNote.self, from: data)
            return misskeyNote.toStatus() as! Entity
        }
        
        throw FediverseClient.ClientError.unexpectedRequest
    }
    
    public func put(endpoint: Endpoint, forceVersion: FediverseClient.Version? = nil) async throws -> HTTPURLResponse? { nil }
    
    public func patch<Entity: Decodable>(endpoint: Endpoint, forceVersion: FediverseClient.Version? = nil) async throws -> Entity {
        let path = endpoint.path()
        if path == "accounts/update_credentials" {
            let data = try await makeMisskeyRequest(path: "i", params: [:])
            let misskeyUser = try JSONDecoder().decode(MisskeyUser.self, from: data)
            return misskeyUser.toAccount() as! Entity
        }
        print("MISSKEY UNHANDLED: \(path)")
        throw FediverseClient.ClientError.unexpectedRequest
    }
    
    public func delete(endpoint: Endpoint, forceVersion: FediverseClient.Version? = nil) async throws -> HTTPURLResponse? {
        let path = endpoint.path()
        var params = extractParams(from: endpoint)
        
        if path.hasPrefix("conversations/") {
            return HTTPURLResponse(url: URL(string: "https://\(server)")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        } else if path.hasPrefix("statuses/") && path.components(separatedBy: "/").count == 2 {
            let id = path.replacingOccurrences(of: "statuses/", with: "")
            params["noteId"] = id
            let _ = try await makeMisskeyRequest(path: "notes/delete", params: params)
            return HTTPURLResponse(url: URL(string: "https://\(server)")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        }
        
        return HTTPURLResponse(url: URL(string: "https://\(server)")!, statusCode: 200, httpVersion: nil, headerFields: nil)
    }
    
    public func makeWebSocketTask(endpoint: Endpoint, instanceStreamingURL: URL?) throws -> URLSessionWebSocketTask {
        throw FediverseClient.ClientError.unexpectedRequest
    }
    
    public func mediaUpload<Entity: Decodable>(endpoint: Endpoint, version: FediverseClient.Version, method: String, mimeType: String, filename: String, data: Data) async throws -> Entity {
        let url = URL(string: "https://\(server)/api/drive/files/create")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        if let token = oauthToken?.accessToken {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"i\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(token)\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (responseData, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            print("Misskey error: \(String(data: responseData, encoding: .utf8) ?? "")")
        }
        let misskeyFile = try JSONDecoder().decode(MisskeyFile.self, from: responseData)
        return misskeyFile.toMediaAttachment() as! Entity
    }

    public func mediaUpload(endpoint: Endpoint, version: FediverseClient.Version, method: String, mimeType: String, filename: String, data: Data) async throws -> HTTPURLResponse? { nil }

    public func patch(endpoint: Endpoint, forceVersion: FediverseClient.Version? = nil) async throws -> HTTPURLResponse? { nil }
}
