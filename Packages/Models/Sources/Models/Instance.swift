import Foundation

public struct Instance: Codable, Sendable, Hashable {
  public static func == (lhs: Instance, rhs: Instance) -> Bool {
    lhs.title == rhs.title && lhs.domain == rhs.domain
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(title)
    hasher.combine(domain)
  }

  public struct Stats: Codable, Sendable {
    public let userCount: Int?
    public let statusCount: Int?
    public let domainCount: Int?
  }

  public struct Usage: Codable, Sendable {
    public struct Users: Codable, Sendable {
      public let activeMonth: Int?
    }
    public let users: Users?
  }

  public struct Configuration: Codable, Sendable {
    public struct Statuses: Codable, Sendable {
      public let maxCharacters: Int
      public let maxMediaAttachments: Int
      public init(maxCharacters: Int, maxMediaAttachments: Int) { self.maxCharacters = maxCharacters; self.maxMediaAttachments = maxMediaAttachments }
    }

    public struct Polls: Codable, Sendable {
      public let maxOptions: Int
      public let maxCharactersPerOption: Int
      public let minExpiration: Int
      public let maxExpiration: Int
      public init(maxOptions: Int, maxCharactersPerOption: Int, minExpiration: Int, maxExpiration: Int) { self.maxOptions = maxOptions; self.maxCharactersPerOption = maxCharactersPerOption; self.minExpiration = minExpiration; self.maxExpiration = maxExpiration }
    }

    public let statuses: Statuses
    public let polls: Polls
    public struct URLs: Codable, Sendable {
      public let streaming: URL?
      public let status: URL?
      public init(streaming: URL?, status: URL?) { self.streaming = streaming; self.status = status }
    }
    public let urls: URLs?
    
    public init(statuses: Statuses, polls: Polls, urls: URLs?) {
      self.statuses = statuses; self.polls = polls; self.urls = urls
    }
  }

  public struct Rule: Codable, Identifiable, Sendable {
    public let id: String
    public let text: String
  }

  public struct URLs: Codable, Sendable {
    public let streamingApi: URL?
  }

  public struct APIVersions: Codable, Sendable {
    public let mastodon: Int?
  }

  public struct Contact: Codable, Sendable {
    public let account: Account?
    public let email: String
    public init(account: Account?, email: String) { self.account = account; self.email = email }
  }

  public struct Registrations: Codable, Sendable {
    public let enabled: Bool
    public init(enabled: Bool) { self.enabled = enabled }
  }

  public struct Thumbnail: Codable, Sendable {
    public let url: URL?
    public init(url: URL?) { self.url = url }
  }

  public let title: String
  public let domain: String
  public let description: String?
  public let shortDescription: String?
  public let version: String
  public let apiVersions: APIVersions?
  public let stats: Stats?
  public let usage: Usage?
  public let languages: [String]?
  public let registrations: Registrations
  public let thumbnail: Thumbnail
  public let configuration: Configuration?
  public let rules: [Rule]?
  public let urls: URLs?
  public let contact: Contact
  
  public init(title: String, domain: String, description: String?, shortDescription: String?, version: String, apiVersions: APIVersions?, stats: Stats?, usage: Usage?, languages: [String]?, registrations: Registrations, thumbnail: Thumbnail, configuration: Configuration?, rules: [Rule]?, urls: URLs?, contact: Contact) {
    self.title = title
    self.domain = domain
    self.description = description
    self.shortDescription = shortDescription
    self.version = version
    self.apiVersions = apiVersions
    self.stats = stats
    self.usage = usage
    self.languages = languages
    self.registrations = registrations
    self.thumbnail = thumbnail
    self.configuration = configuration
    self.rules = rules
    self.urls = urls
    self.contact = contact
  }
}
