import Foundation

public struct Quote: Codable, Sendable {
  public enum State: String, Codable, Sendable {
    case accepted, pending, rejected, revoked, deleted, unauthorized
  }

  public let state: State?
  public let quotedStatus: Status?
  public let quotedStatusId: String?

  private enum FallbackKeys: String, CodingKey {
    case quoteId = "quote_id"
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    state = try? container.decode(State.self, forKey: .state)
    let fallbackContainer = try? decoder.container(keyedBy: FallbackKeys.self)
    quotedStatusId =
      (try? container.decode(String.self, forKey: .quotedStatusId))
      ?? (try? fallbackContainer?.decode(String.self, forKey: .quoteId))
    quotedStatus = try? container.decode(Status.self, forKey: .quotedStatus)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(state, forKey: .state)
    try container.encodeIfPresent(quotedStatus, forKey: .quotedStatus)
    try container.encodeIfPresent(quotedStatusId, forKey: .quotedStatusId)
  }

  private enum CodingKeys: String, CodingKey {
    case state
    case quotedStatus = "quoted_status"
    case quotedStatusId = "quoted_status_id"
  }
}
