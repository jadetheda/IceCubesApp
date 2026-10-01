import Foundation

public struct PluraldawnMember: Codable, Equatable {
  public let id: String
  public let name: String
  public let emoji: [String]
  public let avatar: String
  public let font: String

  public var avatarURL: URL? {
    URL(string: avatar)
  }
}

public struct PluraldawnSystem: Codable, Equatable {
  public let members: [PluraldawnMember]
}
