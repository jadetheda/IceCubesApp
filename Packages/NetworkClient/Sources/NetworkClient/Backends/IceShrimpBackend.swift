import Foundation
import Models

private struct PleromaEndpoint: Endpoint, @unchecked Sendable {
    let internalPath: String
    let internalQueryItems: [URLQueryItem]?
    let internalJsonValue: Encodable?

    func path() -> String { internalPath }
    func queryItems() -> [URLQueryItem]? { internalQueryItems }
    var jsonValue: Encodable? { internalJsonValue }
}

open class IceShrimpBackend: MastodonBackend, @unchecked Sendable {
    
    override public var capabilities: ServerCapabilities {
        return ServerCapabilities(
            supportsAdvancedFilterContexts: false,
            supportsEndorsements: false,
            supportsLocalTimeline: true,
            supportsPolls: true,
            supportsFollowRequests: true,
            supportsCustomEmojis: true
        )
    }

    public override init(server: String, version: FediverseClient.Version = .v1, oauthToken: OauthToken? = nil) {
        super.init(server: server, version: version, oauthToken: oauthToken)
    }

    open override func get<Entity: Decodable>(endpoint: Endpoint, forceVersion: FediverseClient.Version? = nil) async throws -> Entity {
        if endpoint is Trends {
            if Entity.self == [Status].self {
                return [] as! Entity
            }
        }
        
        var overridingEndpoint = endpoint
        if let statusesEndpoint = endpoint as? Statuses {
            switch statusesEndpoint {
            case .quotesBy(let id, _):
                overridingEndpoint = PleromaEndpoint(
                    internalPath: "pleroma/statuses/\(id)/quotes",
                    internalQueryItems: statusesEndpoint.queryItems(),
                    internalJsonValue: statusesEndpoint.jsonValue
                )
            default:
                break
            }
        }
        
        let entity: Entity = try await super.get(endpoint: overridingEndpoint, forceVersion: forceVersion)
        
        if let statuses = entity as? [Status] {
            for status in statuses {
                for i in 0..<status.mediaAttachments.count {
                    if status.mediaAttachments[i].url?.pathExtension.lowercased() == "mp4" {
                        status.mediaAttachments[i].type = "video"
                    }
                }
            }
        }
        return entity
    }
    
    open override func post<Entity: Decodable>(endpoint: Endpoint) async throws -> Entity {
        var overridingEndpoint = endpoint
        if let notificationsEndpoint = endpoint as? Notifications {
            switch notificationsEndpoint {
            case .clear:
                overridingEndpoint = PleromaEndpoint(
                    internalPath: "pleroma/notifications/read",
                    internalQueryItems: nil,
                    internalJsonValue: nil
                )
            default:
                break
            }
        }
        return try await super.post(endpoint: overridingEndpoint)
    }
    
    open override func post(endpoint: Endpoint) async throws -> HTTPURLResponse? {
        var overridingEndpoint = endpoint
        if let notificationsEndpoint = endpoint as? Notifications {
            switch notificationsEndpoint {
            case .clear:
                overridingEndpoint = PleromaEndpoint(
                    internalPath: "pleroma/notifications/read",
                    internalQueryItems: nil,
                    internalJsonValue: nil
                )
            default:
                break
            }
        }
        return try await super.post(endpoint: overridingEndpoint)
    }
}
