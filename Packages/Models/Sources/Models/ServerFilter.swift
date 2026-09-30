import Foundation

public struct ServerFilter: Codable, Identifiable, Hashable, Sendable {
  public struct Keyword: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let keyword: String
    public let wholeWord: Bool
  }

  public enum Context: String, Codable, CaseIterable, Sendable {
    case home, notifications, `public`, thread, account
  }

  public enum Action: String, Codable, CaseIterable, Sendable {
    case warn, hide
  }

  public let id: String
  public let title: String
  public let keywords: [Keyword]
  public let filterAction: Action
  public let context: [Context]
  public let expiresIn: Int?
  public let expiresAt: ServerDate?

  enum CodingKeys: String, CodingKey {
    case id, title, keywords, filterAction, context, expiresIn, expiresAt
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(String.self, forKey: .id)
    self.keywords = try container.decode([Keyword].self, forKey: .keywords)
    self.filterAction = try container.decode(Action.self, forKey: .filterAction)
    self.expiresIn = try container.decodeIfPresent(Int.self, forKey: .expiresIn)
    self.expiresAt = try container.decodeIfPresent(ServerDate.self, forKey: .expiresAt)

    let rawTitle = try container.decode(String.self, forKey: .title)
    if let regex = try? NSRegularExpression(pattern: "\\[iceshrimp_contexts:([a-zA-Z,]*)\\]$"),
       let match = regex.firstMatch(in: rawTitle, range: NSRange(location: 0, length: rawTitle.utf16.count)),
       let contextRange = Range(match.range(at: 1), in: rawTitle),
       let fullRange = Range(match.range(at: 0), in: rawTitle) {
      
      let contextsString = rawTitle[contextRange]
      self.context = contextsString.split(separator: ",").compactMap { Context(rawValue: String($0)) }
      
      var cleanTitle = rawTitle
      cleanTitle.removeSubrange(fullRange)
      self.title = cleanTitle.trimmingCharacters(in: .whitespaces)
    } else {
      self.title = rawTitle
      self.context = try container.decode([Context].self, forKey: .context)
    }
  }

  public func hasExpiry() -> Bool {
    expiresAt != nil
  }

  public func isExpired() -> Bool {
    if let expiresAtDate = expiresAt?.asDate {
      expiresAtDate < Date()
    } else {
      false
    }
  }
}

extension ServerFilter.Context {
  public var iconName: String {
    switch self {
    case .home:
      "rectangle.stack"
    case .notifications:
      "bell"
    case .public:
      "globe.americas"
    case .thread:
      "bubble.left.and.bubble.right"
    case .account:
      "person.crop.circle"
    }
  }

  public var name: String {
    switch self {
    case .home:
      NSLocalizedString("filter.contexts.home", comment: "")
    case .notifications:
      NSLocalizedString("filter.contexts.notifications", comment: "")
    case .public:
      NSLocalizedString("filter.contexts.public", comment: "")
    case .thread:
      NSLocalizedString("filter.contexts.conversations", comment: "")
    case .account:
      NSLocalizedString("filter.contexts.profiles", comment: "")
    }
  }
}

extension ServerFilter.Action {
  public var label: String {
    switch self {
    case .warn:
      NSLocalizedString("filter.action.warning", comment: "")
    case .hide:
      NSLocalizedString("filter.action.hide", comment: "")
    }
  }
}
