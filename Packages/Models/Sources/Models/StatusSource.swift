import Foundation

public struct StatusSource: Codable, Sendable {
  public let id: String
  public let text: String
  public let spoilerText: String?

  enum CodingKeys: String, CodingKey {
    case id
    case text
    case spoilerText
  }
}
