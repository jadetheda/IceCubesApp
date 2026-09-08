import Foundation
import Models

public final class MisskeyBackend: FediverseBackend {
    public let server: String
    public let version: FediverseClient.Version
    public let oauthToken: OauthToken?
    
    public var isAuth: Bool { oauthToken != nil }
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
    
    
    private static var currentSessionId: String?

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
        return OauthToken(accessToken: response.token, tokenType: "Bearer", scope: nil, createdAt: Int(Date().timeIntervalSince1970))
    }

    
    public func get<Entity: Decodable>(endpoint: Endpoint, forceVersion: FediverseClient.Version?) async throws -> Entity {
        if endpoint.path() == "timelines/home" {
            let url = URL(string: "https://\(server)/api/notes/timeline")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            if let token = oauthToken?.accessToken {
                request.httpBody = try? JSONEncoder().encode(["i": token])
            }
            let (data, _) = try await URLSession.shared.data(for: request)
            let misskeyNotes = try JSONDecoder().decode([MisskeyNote].self, from: data)
            return misskeyNotes.map { $0.toStatus() } as! Entity
        } else if endpoint.path() == "accounts/verify_credentials" {
            let url = URL(string: "https://\(server)/api/i")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            if let token = oauthToken?.accessToken {
                request.httpBody = try? JSONEncoder().encode(["i": token])
            }
            let (data, _) = try await URLSession.shared.data(for: request)
            let misskeyUser = try JSONDecoder().decode(MisskeyUser.self, from: data)
            return misskeyUser.toAccount() as! Entity
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
        throw FediverseClient.ClientError.unexpectedRequest
    }
    
    public func post(endpoint: Endpoint) async throws -> HTTPURLResponse? { nil }
    
    public func put<Entity: Decodable>(endpoint: Endpoint) async throws -> Entity {
        throw FediverseClient.ClientError.unexpectedRequest
    }
    
    public func put(endpoint: Endpoint) async throws -> HTTPURLResponse? { nil }
    
    public func patch<Entity: Decodable>(endpoint: Endpoint) async throws -> Entity {
        throw FediverseClient.ClientError.unexpectedRequest
    }
    
    public func delete(endpoint: Endpoint) async throws -> HTTPURLResponse? { nil }
    
    public func makeWebSocketTask(endpoint: Endpoint, instanceStreamingURL: URL?) throws -> URLSessionWebSocketTask {
        throw FediverseClient.ClientError.unexpectedRequest
    }
    
    public func mediaUpload<Entity: Decodable>(endpoint: Endpoint, version: FediverseClient.Version, method: String, mimeType: String, filename: String, data: Data) async throws -> Entity {
        throw FediverseClient.ClientError.unexpectedRequest
    }
}
