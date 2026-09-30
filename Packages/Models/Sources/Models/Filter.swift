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

  enum CodingKeys: String, CodingKey {
    case id, title, context, filterAction
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(String.self, forKey: .id)
    self.filterAction = try container.decode(Action.self, forKey: .filterAction)

    let rawTitle = try container.decode(String.self, forKey: .title)
    if let regex = try? NSRegularExpression(pattern: "\\[iceshrimp_contexts:([a-zA-Z,]*)\\]$"),
       let match = regex.firstMatch(in: rawTitle, range: NSRange(location: 0, length: rawTitle.utf16.count)),
       let contextRange = Range(match.range(at: 1), in: rawTitle),
       let fullRange = Range(match.range(at: 0), in: rawTitle) {
      
      let contextsString = rawTitle[contextRange]
      self.context = contextsString.split(separator: ",").map { String($0) }
      
      var cleanTitle = rawTitle
      cleanTitle.removeSubrange(fullRange)
      self.title = cleanTitle.trimmingCharacters(in: .whitespaces)
    } else {
      self.title = rawTitle
      self.context = try container.decode([String].self, forKey: .context)
    }
  }
}

extension Filtered: Sendable {}
extension Filter: Sendable {}
extension Filter.Action: Sendable {}
extension Filter.Context: Sendable {}
