import Foundation
import Models
import Observation

open class PixelfedBackend: MastodonBackend, @unchecked Sendable {
    open override var capabilities: ServerCapabilities {
        ServerCapabilities(
            supportsAdvancedFilterContexts: false, // Pixelfed filter context might differ
            supportsEndorsements: false, // Pixelfed doesn't support endorsements
            supportsLocalTimeline: true,
            supportsPolls: false, // Pixelfed has no polls?
            supportsFollowRequests: true,
            supportsCustomEmojis: true,
            supportsFollowNotifications: true,
            supportsFollowedTags: false, // Pixelfed probably doesn't have followed tags?
            supportsAccountMetrics: false, // Account metrics are Mastodon specific
            supportsStatusEditing: false, // Pixelfed doesn't support edit?
            supportsTrendingLinks: false, // Pixelfed is images only
            supportsNativeMessaging: false
        )
    }

    public override func get<Entity: Decodable>(endpoint: Endpoint, forceVersion: FediverseClient.Version?) async throws -> Entity {
        let path = endpoint.path()
        if path == "trends/tags" || path == "trends/links" {
            // Pixelfed doesn't support tags or links trending in the Mastodon format, return empty array to prevent UI errors
            let empty: [String] = [] // The caller expects an array of tags or links, but returning empty array JSON is safe
            let data = try! JSONEncoder().encode(empty)
            return try JSONDecoder().decode(Entity.self, from: data)
        } else if path == "trends/statuses" {
            // Map trending statuses to Pixelfed's discover endpoint
            let url = URL(string: "https://\(server)/api/pixelfed/v2/discover/posts/trending")!
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            if let oauthToken = self.oauthToken {
                request.setValue("Bearer \(oauthToken.accessToken)", forHTTPHeaderField: "Authorization")
            }
            let (data, _) = try await URLSession.shared.data(for: request)
            return try JSONDecoder().decode(Entity.self, from: data)
        } else if path.hasSuffix("/translate") && path.hasPrefix("statuses/") {
            // Pixelfed doesn't support Mastodon's translation endpoint. 
            // Throw so StatusRowViewModel falls back to DeepL/Apple Translation.
            throw FediverseClient.ClientError.unexpectedRequest
        }
        
        return try await super.get(endpoint: endpoint, forceVersion: forceVersion)
    }
}
