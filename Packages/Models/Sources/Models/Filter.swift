import Foundation

public struct Filtered: Codable, Equatable, Hashable {
  public let filter: Filter
  public let keywordMatches: [String]?

  public init(filter: Filter, keywordMatches: [String]?) {
    self.filter = filter
    self.keywordMatches = keywordMatches
  }
}

public struct Filter: Codable, Identifiable, Equatable, Hashable {
  public enum Action: String, Codable, Equatable {
    case warn, hide
  }

  public enum Context: String, Codable {
    case home, notifications, account, thread
    case pub = "public"
  }

  public let id: String
  public let title: String
  public let context: [String]
  public let filterAction: Action

  public init(id: String, title: String, context: [String], filterAction: Action) {
    self.id = id
    self.title = title
    self.context = context
    self.filterAction = filterAction
  }
}

extension Filtered: Sendable {}
extension Filter: Sendable {}
extension Filter.Action: Sendable {}
extension Filter.Context: Sendable {}
