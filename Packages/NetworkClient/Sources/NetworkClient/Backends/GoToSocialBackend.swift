import Foundation
import Models
import Observation

open class GoToSocialBackend: MastodonBackend, @unchecked Sendable {
    open override var capabilities: ServerCapabilities {
        ServerCapabilities(
            supportsAdvancedFilterContexts: false, // GoToSocial does not support advanced filter contexts
            supportsEndorsements: false, // GoToSocial doesn't support endorsements
            supportsLocalTimeline: true,
            supportsPolls: true,
            supportsFollowRequests: true,
            supportsCustomEmojis: true,
            supportsFollowNotifications: false, // GoToSocial does not support follow notifications
            supportsFollowedTags: false, // GoToSocial does not support followed tags
            supportsAccountMetrics: false, // Account metrics are Mastodon specific
            supportsStatusEditing: true, // GoToSocial supports edit
            supportsTrendingLinks: false, // GoToSocial does not support trending links
            supportsNativeMessaging: false
        )
    }
    
    public override func get<Entity: Decodable>(endpoint: Endpoint, forceVersion: FediverseClient.Version?) async throws -> Entity {
        let path = endpoint.path()
        if path == "trends/tags" || path == "trends/links" || path == "trends/statuses" || path == "accounts/familiar_followers" || path == "suggestions" || path == "directory" {
            // GoToSocial doesn't support these endpoints yet, return empty array to prevent UI errors
            let data = "[]".data(using: .utf8)!
            return try JSONDecoder().decode(Entity.self, from: data)
        }
        
        return try await super.get(endpoint: endpoint, forceVersion: forceVersion)
    }

    public override func post<Entity: Decodable>(endpoint: Endpoint, forceVersion: FediverseClient.Version? = nil) async throws -> Entity {
        let path = endpoint.path()
        if path.hasSuffix("/translate") {
            // GoToSocial doesn't support Mastodon's translation endpoint. 
            // Throw so StatusRowViewModel falls back to DeepL/Apple Translation.
            throw FediverseClient.ClientError.unexpectedRequest
        }
        return try await super.post(endpoint: endpoint, forceVersion: forceVersion)
    }
}
