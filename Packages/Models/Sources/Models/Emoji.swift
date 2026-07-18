import Foundation

public struct Emoji: Codable, Hashable, Identifiable, Equatable, Sendable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(shortcode)
  }

  public var id: String {
    shortcode
  }

  public let shortcode: String
  public let url: String
  public let staticUrl: String
  public let visibleInPicker: Bool
  public let category: String?
}
