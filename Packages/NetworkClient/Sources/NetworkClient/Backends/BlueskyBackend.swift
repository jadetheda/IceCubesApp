import Foundation
import Models

public final class BlueskyBackend: FediverseBackend {
    public let server: String
    public let version: FediverseClient.Version
    public let oauthToken: OauthToken?
    
    public var isAuth: Bool { oauthToken != nil }
    public var capabilities: ServerCapabilities {
        ServerCapabilities(
            supportsAdvancedFilterContexts: false,
            supportsEndorsements: false,
            supportsLocalTimeline: false,
            supportsPolls: false,
            supportsFollowRequests: false,
            supportsCustomEmojis: false
        )
    }
    
    public init(server: String, version: FediverseClient.Version = .v1, oauthToken: OauthToken? = nil) {
        self.server = server
        self.version = version
        self.oauthToken = oauthToken
    }
    
    public func addConnections(_ connections: [String]) {}
    public func hasConnection(with url: URL) -> Bool { false }
    
    public func oauthURL() async throws -> URL {
        throw FediverseClient.OauthError.requiresNativeLogin
    }
    
    public func continueOauthFlow(url: URL) async throws -> OauthToken {
        throw FediverseClient.OauthError.missingApp
    }
    
    public func get<Entity: Decodable>(endpoint: Endpoint, forceVersion: FediverseClient.Version?) async throws -> Entity {
        if endpoint.path() == "timelines/home" {
            let url = URL(string: "https://bsky.social/xrpc/app.bsky.feed.getTimeline")!
            var request = URLRequest(url: url)
            if let token = oauthToken?.accessToken {
                request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            let (data, _) = try await URLSession.shared.data(for: request)
            // Mocked since ATProtoKit isnt fully mapped
            return [] as! Entity
        }
        throw FediverseClient.ClientError.unexpectedRequest
    }
    
    public func getWithLink<Entity: Decodable>(endpoint: Endpoint) async throws -> (Entity, LinkHandler?) {
        let entity: Entity = try await get(endpoint: endpoint, forceVersion: nil)
        return (entity, nil)
    }
    
    public func post<Entity: Decodable>(endpoint: Endpoint) async throws -> Entity {
        throw FediverseClient.ClientError.unexpectedRequest
    }
    
    public func post(endpoint: Endpoint) async throws -> HTTPURLResponse? { nil }
    
    public func put<Entity: Decodable>(endpoint: Endpoint, forceVersion: FediverseClient.Version? = nil) async throws -> Entity {
        throw FediverseClient.ClientError.unexpectedRequest
    }
    
    public func put(endpoint: Endpoint, forceVersion: FediverseClient.Version? = nil) async throws -> HTTPURLResponse? { nil }
    
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
