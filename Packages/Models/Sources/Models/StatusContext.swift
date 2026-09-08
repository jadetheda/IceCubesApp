import Foundation

public struct StatusContext: Decodable {
  public let ancestors: [Status]
  public let descendants: [Status]

  public init(ancestors: [Status], descendants: [Status]) {
    self.ancestors = ancestors
    self.descendants = descendants
  }

  public static func empty() -> StatusContext {
    .init(ancestors: [], descendants: [])
  }
}

extension StatusContext: Sendable {}
