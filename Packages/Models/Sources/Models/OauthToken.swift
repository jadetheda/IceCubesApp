import Foundation

// OauthToken covers both Mastodon's token format (which includes created_at as a Unix
// timestamp) and Laravel Passport's format used by Pixelfed (which omits created_at
// but includes expires_in). We make createdAt optional and fall back to the current
// time so both token shapes decode cleanly.
public struct OauthToken: Codable, Hashable, Sendable {
  public let accessToken: String
  public let tokenType: String
  public let scope: String
  public let createdAt: Double

  public init(accessToken: String, tokenType: String, scope: String, createdAt: Double) {
    self.accessToken = accessToken
    self.tokenType = tokenType
    self.scope = scope
    self.createdAt = createdAt
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    accessToken = try container.decode(String.self, forKey: .accessToken)
    tokenType = try container.decode(String.self, forKey: .tokenType)
    // Pixelfed (Laravel Passport) omits scope; Mastodon always includes it.
    scope = (try? container.decode(String.self, forKey: .scope)) ?? ""
    // Pixelfed omits created_at; Mastodon sends it as a Unix timestamp integer.
    // Fall back to current time if missing so the token is still usable.
    createdAt = (try? container.decode(Double.self, forKey: .createdAt)) ?? Date().timeIntervalSince1970
  }

  private enum CodingKeys: String, CodingKey {
    case accessToken, tokenType, scope, createdAt
  }
}
