import Foundation
import Models

// PleromaEndpoint is a private routing shim that lets IceShrimpBackend intercept specific
// Mastodon API paths and redirect them to Pleroma-compatible endpoints.
//
// The struct is marked @unchecked Sendable because `Encodable?` cannot conditionally satisfy
// the Sendable marker protocol (Swift rejects `as? (any Encodable & Sendable)`). Since this
// struct is created and consumed synchronously within IceShrimpBackend's override methods,
// the @unchecked annotation is safe here.
private struct PleromaEndpoint: Endpoint, @unchecked Sendable {
    let internalPath: String
    let internalQueryItems: [URLQueryItem]?
    // Stored as plain Encodable? — @unchecked Sendable above suppresses the Swift 6
    // strict-concurrency Sendable requirement on stored properties.
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
        // IceShrimp does not support the Trends endpoint, so short-circuit to empty arrays
        // to avoid crashing the UI when the trends tab is shown.
        if endpoint is Trends {
            if Entity.self == [Status].self {
                return [] as! Entity
            }
        }
        
        var overridingEndpoint = endpoint
        if let statusesEndpoint = endpoint as? Statuses {
            switch statusesEndpoint {
            case .quotesBy(let id, _):
                // IceShrimp exposes quotes via the Pleroma-compatible endpoint rather than
                // the standard Mastodon path, so we reroute the request here.
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
        
        // Fix media type misclassification: IceShrimp serves video files as .mp4 attachments
        // but labels them as generic files. Promote them to the correct "video" type so the
        // player UI renders correctly.
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
    
    open override func post<Entity: Decodable>(endpoint: Endpoint, forceVersion: FediverseClient.Version? = nil) async throws -> Entity {
        var overridingEndpoint = endpoint
        if let notificationsEndpoint = endpoint as? Notifications {
            switch notificationsEndpoint {
            case .clear:
                // IceShrimp/Pleroma uses a different path to clear all notifications.
                overridingEndpoint = PleromaEndpoint(
                    internalPath: "pleroma/notifications/read",
                    internalQueryItems: nil,
                    internalJsonValue: nil
                )
            default:
                break
            }
        }
        return try await super.post(endpoint: overridingEndpoint, forceVersion: forceVersion)
    }
    
    open override func post(endpoint: Endpoint, forceVersion: FediverseClient.Version? = nil) async throws -> HTTPURLResponse? {
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
        return try await super.post(endpoint: overridingEndpoint, forceVersion: forceVersion)
    }
}
