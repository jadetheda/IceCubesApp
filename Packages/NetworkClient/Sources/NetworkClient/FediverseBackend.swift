import Foundation
import Models

public struct ServerCapabilities: Sendable {
    public var supportsAdvancedFilterContexts: Bool = true
    public var supportsEndorsements: Bool = true
    public var supportsLocalTimeline: Bool = true
    public var supportsPolls: Bool = true
    public var supportsFollowRequests: Bool = true
    public var supportsCustomEmojis: Bool = true
    public var supportsFollowNotifications: Bool = true
    public var supportsFollowedTags: Bool = true
    public var supportsAccountMetrics: Bool = true
    
    public init(
        supportsAdvancedFilterContexts: Bool = true,
        supportsEndorsements: Bool = true,
        supportsLocalTimeline: Bool = true,
        supportsPolls: Bool = true,
        supportsFollowRequests: Bool = true,
        supportsCustomEmojis: Bool = true,
        supportsFollowNotifications: Bool = true,
        supportsFollowedTags: Bool = true,
        supportsAccountMetrics: Bool = true
    ) {
        self.supportsAdvancedFilterContexts = supportsAdvancedFilterContexts
        self.supportsEndorsements = supportsEndorsements
        self.supportsLocalTimeline = supportsLocalTimeline
        self.supportsPolls = supportsPolls
        self.supportsFollowRequests = supportsFollowRequests
        self.supportsCustomEmojis = supportsCustomEmojis
        self.supportsFollowNotifications = supportsFollowNotifications
        self.supportsFollowedTags = supportsFollowedTags
        self.supportsAccountMetrics = supportsAccountMetrics
    }
}

public protocol FediverseBackend: Sendable {
    var server: String { get }
    var version: FediverseClient.Version { get }
    var oauthToken: OauthToken? { get }
    var isAuth: Bool { get }
    var isIceShrimpWorkaroundsEnabled: Bool { get }
    var capabilities: ServerCapabilities { get }
  func addConnections(_ connections: [String])
  func hasConnection(with url: URL) -> Bool
    
    func oauthURL() async throws -> URL
    func continueOauthFlow(url: URL) async throws -> OauthToken
    
    func get<Entity: Decodable>(endpoint: Endpoint, forceVersion: FediverseClient.Version?) async throws -> Entity
    func getWithLink<Entity: Decodable>(endpoint: Endpoint) async throws -> (Entity, LinkHandler?)
    
    func post<Entity: Decodable>(endpoint: Endpoint, forceVersion: FediverseClient.Version?) async throws -> Entity
    func post(endpoint: Endpoint, forceVersion: FediverseClient.Version?) async throws -> HTTPURLResponse?
    
    func put<Entity: Decodable>(endpoint: Endpoint, forceVersion: FediverseClient.Version?) async throws -> Entity
    func put(endpoint: Endpoint, forceVersion: FediverseClient.Version?) async throws -> HTTPURLResponse?
    
    func patch<Entity: Decodable>(endpoint: Endpoint, forceVersion: FediverseClient.Version?) async throws -> Entity
    func patch(endpoint: Endpoint, forceVersion: FediverseClient.Version?) async throws -> HTTPURLResponse?
    
    func delete(endpoint: Endpoint, forceVersion: FediverseClient.Version?) async throws -> HTTPURLResponse?
    
    func makeWebSocketTask(endpoint: Endpoint, instanceStreamingURL: URL?) throws -> URLSessionWebSocketTask
    
    func mediaUpload<Entity: Decodable>(endpoint: Endpoint, version: FediverseClient.Version, method: String, mimeType: String, filename: String, data: Data) async throws -> Entity
    func mediaUpload(endpoint: Endpoint, version: FediverseClient.Version, method: String, mimeType: String, filename: String, data: Data) async throws -> HTTPURLResponse?
}
