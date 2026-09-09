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
        } else if path == "conversations" {
            let convs: [Conversation] = []
            return convs as! Entity
        } else if path == "lists" {
            let lists: [Models.List] = []
            return lists as! Entity
        } else if path.hasPrefix("trends/") {
            if path == "trends/tags" {
                let tags: [Tag] = []
                return tags as! Entity
            } else if path == "trends/statuses" {
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
        } else if path.hasSuffix("/statuses") && path.hasPrefix("accounts/") {
            let id = path.replacingOccurrences(of: "accounts/", with: "").replacingOccurrences(of: "/statuses", with: "")
            params["userId"] = id
            let data = try await makeMisskeyRequest(path: "users/notes", params: params)
            let misskeyNotes = try JSONDecoder().decode([MisskeyNote].self, from: data)
            return misskeyNotes.map { $0.toStatus() } as! Entity
        } else if path.hasPrefix("statuses/") && path.components(separatedBy: "/").count == 2 {
            let id = path.replacingOccurrences(of: "statuses/", with: "")
            params["noteId"] = id
            let data = try await makeMisskeyRequest(path: "notes/show", params: params)
            let misskeyNote = try JSONDecoder().decode(MisskeyNote.self, from: data)
            return misskeyNote.toStatus() as! Entity
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

    public func post<Entity: Decodable>(endpoint: Endpoint) async throws -> Entity {
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
        } else if path.hasSuffix("/context") && path.hasPrefix("statuses/") {
            let id = path.replacingOccurrences(of: "statuses/", with: "").replacingOccurrences(of: "/context", with: "")
            params["noteId"] = id
            
            var ancestors: [Status] = []
            var descendants: [Status] = []
            
            // Misskey /notes/children and /notes/conversation
            if let convData = try? await makeMisskeyRequest(path: "notes/conversation", params: params),
               let convNotes = try? JSONDecoder().decode([MisskeyNote].self, from: convData) {
                ancestors = convNotes.map { $0.toStatus() }
            }
            if let childrenData = try? await makeMisskeyRequest(path: "notes/children", params: params),
               let childrenNotes = try? JSONDecoder().decode([MisskeyNote].self, from: childrenData) {
                descendants = childrenNotes.map { $0.toStatus() }
            }
            
            // StatusContext
            let ctx = StatusContext(ancestors: ancestors, descendants: descendants)
            return ctx as! Entity
        } else if path == "notifications" {
            let data = try await makeMisskeyRequest(path: "i/notifications", params: params)
            let misskeyNotifs = try JSONDecoder().decode([MisskeyNotification].self, from: data)
            return misskeyNotifs.compactMap { $0.toNotification() } as! Entity
        } else if path.hasSuffix("/favourite") && path.hasPrefix("statuses/") {
            let id = path.replacingOccurrences(of: "statuses/", with: "").replacingOccurrences(of: "/favourite", with: "")
            params["noteId"] = id
            params["reaction"] = "👍"
            let _ = try await makeMisskeyRequest(path: "notes/reactions/create", params: params)
            // Mastodon expects the status back.
            let data = try await makeMisskeyRequest(path: "notes/show", params: ["noteId": id])
            let misskeyNote = try JSONDecoder().decode(MisskeyNote.self, from: data)
            return misskeyNote.toStatus() as! Entity
        } else if path.hasSuffix("/context") && path.hasPrefix("statuses/") {
            let id = path.replacingOccurrences(of: "statuses/", with: "").replacingOccurrences(of: "/context", with: "")
            params["noteId"] = id
            
            var ancestors: [Status] = []
            var descendants: [Status] = []
            
            // Misskey /notes/children and /notes/conversation
            if let convData = try? await makeMisskeyRequest(path: "notes/conversation", params: params),
               let convNotes = try? JSONDecoder().decode([MisskeyNote].self, from: convData) {
                ancestors = convNotes.map { $0.toStatus() }
            }
            if let childrenData = try? await makeMisskeyRequest(path: "notes/children", params: params),
               let childrenNotes = try? JSONDecoder().decode([MisskeyNote].self, from: childrenData) {
                descendants = childrenNotes.map { $0.toStatus() }
            }
            
            // StatusContext
            let ctx = StatusContext(ancestors: ancestors, descendants: descendants)
            return ctx as! Entity
        } else if path == "notifications" {
            let data = try await makeMisskeyRequest(path: "i/notifications", params: params)
            let misskeyNotifs = try JSONDecoder().decode([MisskeyNotification].self, from: data)
            return misskeyNotifs.compactMap { $0.toNotification() } as! Entity
        } else if path.hasSuffix("/reblog") && path.hasPrefix("statuses/") {
            let id = path.replacingOccurrences(of: "statuses/", with: "").replacingOccurrences(of: "/reblog", with: "")
            params["renoteId"] = id
            let data = try await makeMisskeyRequest(path: "notes/create", params: params)
            
            
                
            if let response = try? JSONDecoder().decode(MisskeyBackend.NoteCreateResponse.self, from: data) {
                return response.createdNote.toStatus() as! Entity
            }
        } else if path.hasSuffix("/follow") && path.hasPrefix("accounts/") {
            let id = path.replacingOccurrences(of: "accounts/", with: "").replacingOccurrences(of: "/follow", with: "")
            params["userId"] = id
            let _ = try await makeMisskeyRequest(path: "following/create", params: params)
            // Fetch relationship mock
            let rel = Relationship(id: id, following: true, showingReblogs: true, followedBy: false, blocking: false, blockedBy: false, muting: false, mutingNotifications: false, requested: false, domainBlocking: false, endorsed: false, note: "", notifying: false)
            return rel as! Entity
        } else if path.hasSuffix("/unreblog") && path.hasPrefix("statuses/") {
            let id = path.replacingOccurrences(of: "statuses/", with: "").replacingOccurrences(of: "/unreblog", with: "")
            params["noteId"] = id
            let _ = try await makeMisskeyRequest(path: "notes/unrenote", params: params)
            let data = try await makeMisskeyRequest(path: "notes/show", params: ["noteId": id])
            let misskeyNote = try JSONDecoder().decode(MisskeyNote.self, from: data)
            return misskeyNote.toStatus() as! Entity
        } else if path.hasSuffix("/unfollow") && path.hasPrefix("accounts/") {
            let id = path.replacingOccurrences(of: "accounts/", with: "").replacingOccurrences(of: "/unfollow", with: "")
            params["userId"] = id
            let _ = try await makeMisskeyRequest(path: "following/delete", params: params)
            let rel = Relationship(id: id, following: false, showingReblogs: false, followedBy: false, blocking: false, blockedBy: false, muting: false, mutingNotifications: false, requested: false, domainBlocking: false, endorsed: false, note: "", notifying: false)
            return rel as! Entity
        } else if path.hasSuffix("/unreblog") && path.hasPrefix("statuses/") {
            let id = path.replacingOccurrences(of: "statuses/", with: "").replacingOccurrences(of: "/unreblog", with: "")
            params["noteId"] = id
            let _ = try await makeMisskeyRequest(path: "notes/unrenote", params: params)
            let data = try await makeMisskeyRequest(path: "notes/show", params: ["noteId": id])
            let misskeyNote = try JSONDecoder().decode(MisskeyNote.self, from: data)
            return misskeyNote.toStatus() as! Entity
        }
        
        throw FediverseClient.ClientError.unexpectedRequest
    }
    
    public func post(endpoint: Endpoint) async throws -> HTTPURLResponse? { 
        let path = endpoint.path()
        var params = extractParams(from: endpoint)
        
        if path.hasSuffix("/unfavourite") && path.hasPrefix("statuses/") {
            let id = path.replacingOccurrences(of: "statuses/", with: "").replacingOccurrences(of: "/unfavourite", with: "")
            params["noteId"] = id
            let _ = try await makeMisskeyRequest(path: "notes/reactions/delete", params: params)
            return HTTPURLResponse(url: URL(string: "https://\(server)")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        }
        
        return nil 
    }

    public func put<Entity: Decodable>(endpoint: Endpoint, forceVersion: FediverseClient.Version? = nil) async throws -> Entity {
        throw FediverseClient.ClientError.unexpectedRequest
    }
    
    public func put(endpoint: Endpoint, forceVersion: FediverseClient.Version? = nil) async throws -> HTTPURLResponse? { nil }
    
    public func patch<Entity: Decodable>(endpoint: Endpoint) async throws -> Entity {
        throw FediverseClient.ClientError.unexpectedRequest
    }
    
    public func delete(endpoint: Endpoint) async throws -> HTTPURLResponse? {
        let path = endpoint.path()
        var params = extractParams(from: endpoint)
        
        if path.hasPrefix("statuses/") && path.components(separatedBy: "/").count == 2 {
            let id = path.replacingOccurrences(of: "statuses/", with: "")
            params["noteId"] = id
            let _ = try await makeMisskeyRequest(path: "notes/delete", params: params)
            return HTTPURLResponse(url: URL(string: "https://\(server)")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        }
        
        return nil
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
}
