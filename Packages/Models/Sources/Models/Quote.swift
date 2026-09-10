import Foundation

public struct Quote: Codable, Sendable {
  public enum State: String, Codable, Sendable {
    case accepted, pending, rejected, revoked, deleted, unauthorized
  }

  public let state: State?
  public let quotedStatus: Status?
  public let quotedStatusId: String?

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    state = try? container.decode(State.self, forKey: .state)
    quotedStatusId =
      (try? container.decode(String.self, forKey: .quotedStatusId))
      ?? (try? container.decode(String.self, forKey: .quoteId))
    quotedStatus = try? container.decode(Status.self, forKey: .quotedStatus)
  }

  private enum CodingKeys: String, CodingKey {
    case state
    case quotedStatus = "quoted_status"
    case quotedStatusId = "quoted_status_id"
    case quoteId = "quote_id"
  }
}
