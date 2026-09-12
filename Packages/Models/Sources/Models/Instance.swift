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
      
      enum CodingKeys: String, CodingKey {
        case streaming, status
      }
      
      public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let streamingString = try? container.decodeIfPresent(String.self, forKey: .streaming)
        self.streaming = URL(string: streamingString ?? "")
        let statusString = try? container.decodeIfPresent(String.self, forKey: .status)
        self.status = URL(string: statusString ?? "")
      }
    }
    public let urls: URLs?
    
    public init(statuses: Statuses, polls: Polls, urls: URLs?) {
      self.statuses = statuses; self.polls = polls; self.urls = urls
    }
    
    enum CodingKeys: String, CodingKey {
      case statuses, polls, urls
    }
    
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.statuses = (try? container.decodeIfPresent(Statuses.self, forKey: .statuses)) ?? Statuses(maxCharacters: 500, maxMediaAttachments: 4)
      self.polls = (try? container.decodeIfPresent(Polls.self, forKey: .polls)) ?? Polls(maxOptions: 4, maxCharactersPerOption: 50, minExpiration: 300, maxExpiration: 2629746)
      self.urls = try? container.decodeIfPresent(URLs.self, forKey: .urls)
    }
  }

  public struct Rule: Codable, Identifiable, Sendable {
    public let id: String
    public let text: String
  }

  public struct URLs: Codable, Sendable {
    public let streamingApi: URL?
    
    enum CodingKeys: String, CodingKey {
      case streamingApi
    }
    
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      let streamingString = try? container.decodeIfPresent(String.self, forKey: .streamingApi)
      self.streamingApi = URL(string: streamingString ?? "")
    }
  }

  public struct APIVersions: Codable, Sendable {
    public let mastodon: Int?
  }

  public struct Contact: Codable, Sendable {
    public let account: Account?
    public let email: String
    public init(account: Account?, email: String) { self.account = account; self.email = email }
    
    enum CodingKeys: String, CodingKey {
      case account, email
    }
    
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.account = try? container.decodeIfPresent(Account.self, forKey: .account)
      self.email = (try? container.decodeIfPresent(String.self, forKey: .email)) ?? ""
    }
  }

  public struct Registrations: Codable, Sendable {
    public let enabled: Bool
    public init(enabled: Bool) { self.enabled = enabled }
  }

  public struct Thumbnail: Codable, Sendable {
    public let url: URL?
    public init(url: URL?) { self.url = url }
    
    enum CodingKeys: String, CodingKey {
      case url
    }
    
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      let urlString = try? container.decodeIfPresent(String.self, forKey: .url)
      self.url = URL(string: urlString ?? "")
    }
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
  
  enum CodingKeys: String, CodingKey {
    case title, domain, description, shortDescription, version, apiVersions, stats, usage, languages, registrations, thumbnail, configuration, rules, urls, contact
  }
  
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.title = (try? container.decodeIfPresent(String.self, forKey: .title)) ?? ""
    self.domain = (try? container.decodeIfPresent(String.self, forKey: .domain)) ?? ""
    self.description = try? container.decodeIfPresent(String.self, forKey: .description)
    self.shortDescription = try? container.decodeIfPresent(String.self, forKey: .shortDescription)
    self.version = (try? container.decodeIfPresent(String.self, forKey: .version)) ?? ""
    self.apiVersions = try? container.decodeIfPresent(APIVersions.self, forKey: .apiVersions)
    self.stats = try? container.decodeIfPresent(Stats.self, forKey: .stats)
    self.usage = try? container.decodeIfPresent(Usage.self, forKey: .usage)
    self.languages = try? container.decodeIfPresent([String].self, forKey: .languages)
    self.registrations = (try? container.decodeIfPresent(Registrations.self, forKey: .registrations)) ?? Registrations(enabled: false)
    self.thumbnail = (try? container.decodeIfPresent(Thumbnail.self, forKey: .thumbnail)) ?? Thumbnail(url: nil)
    self.configuration = try? container.decodeIfPresent(Configuration.self, forKey: .configuration)
    self.rules = try? container.decodeIfPresent([Rule].self, forKey: .rules)
    self.urls = try? container.decodeIfPresent(URLs.self, forKey: .urls)
    self.contact = (try? container.decodeIfPresent(Contact.self, forKey: .contact)) ?? Contact(account: nil, email: "")
  }
}
