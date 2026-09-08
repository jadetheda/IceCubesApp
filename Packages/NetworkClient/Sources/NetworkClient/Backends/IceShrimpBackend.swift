import Foundation
import Models

open class IceShrimpBackend: MastodonBackend {
    
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
        self.isIceShrimpWorkaroundsEnabled = true
    }

    open override func get<Entity: Decodable>(endpoint: Endpoint, forceVersion: FediverseClient.Version? = nil) async throws -> Entity {
        if endpoint is Trends {
            if Entity.self == [Status].self {
                return [] as! Entity
            }
        }
        
        let entity: Entity = try await super.get(endpoint: endpoint, forceVersion: forceVersion)
        
        if let statuses = entity as? [Status] {
            for status in statuses {
                for attachment in status.mediaAttachments {
                    if attachment.url?.pathExtension.lowercased() == "mp4" {
                        attachment.type = "video"
                    }
                }
            }
        }
        return entity
    }
}
