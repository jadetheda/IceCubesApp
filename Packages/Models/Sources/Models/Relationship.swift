import Foundation

public struct Relationship: Codable, Equatable, Identifiable {
  public let id: String
  public let following: Bool
  public let showingReblogs: Bool
  public let followedBy: Bool
  public let blocking: Bool
  public let blockedBy: Bool
  public let muting: Bool
  public let mutingNotifications: Bool
  public let requested: Bool
  public let domainBlocking: Bool
  public let endorsed: Bool
  public let note: String
  public let notifying: Bool

  public init(id: String, following: Bool, showingReblogs: Bool, followedBy: Bool, blocking: Bool, blockedBy: Bool, muting: Bool, mutingNotifications: Bool, requested: Bool, domainBlocking: Bool, endorsed: Bool, note: String, notifying: Bool) {
    self.id = id
    self.following = following
    self.showingReblogs = showingReblogs
    self.followedBy = followedBy
    self.blocking = blocking
    self.blockedBy = blockedBy
    self.muting = muting
    self.mutingNotifications = mutingNotifications
    self.requested = requested
    self.domainBlocking = domainBlocking
    self.endorsed = endorsed
    self.note = note
    self.notifying = notifying
  }

  public static func placeholder() -> Relationship {
    .init(
      id: UUID().uuidString,
      following: false,
      showingReblogs: false,
      followedBy: false,
      blocking: false,
      blockedBy: false,
      muting: false,
      mutingNotifications: false,
      requested: false,
      domainBlocking: false,
      endorsed: false,
      note: "",
      notifying: false)
  }
}

extension Relationship {
  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    id = try values.decodeIfPresent(String.self, forKey: .id) ?? ""
    following = try values.decodeIfPresent(Bool.self, forKey: .following) ?? false
    showingReblogs = try values.decodeIfPresent(Bool.self, forKey: .showingReblogs) ?? false
    followedBy = try values.decodeIfPresent(Bool.self, forKey: .followedBy) ?? false
    blocking = try values.decodeIfPresent(Bool.self, forKey: .blocking) ?? false
    blockedBy = try values.decodeIfPresent(Bool.self, forKey: .blockedBy) ?? false
    muting = try values.decodeIfPresent(Bool.self, forKey: .muting) ?? false
    mutingNotifications =
      try values.decodeIfPresent(Bool.self, forKey: .mutingNotifications) ?? false
    requested = try values.decodeIfPresent(Bool.self, forKey: .requested) ?? false
    domainBlocking = try values.decodeIfPresent(Bool.self, forKey: .domainBlocking) ?? false
    endorsed = try values.decodeIfPresent(Bool.self, forKey: .endorsed) ?? false
    note = try values.decodeIfPresent(String.self, forKey: .note) ?? ""
    notifying = try values.decodeIfPresent(Bool.self, forKey: .notifying) ?? false
  }
}

extension Relationship: Sendable {}
