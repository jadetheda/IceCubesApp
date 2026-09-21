import Foundation

public struct PhotoExportMetadata: Hashable, Codable, Sendable {
  public let postUrl: URL?
  public let postText: String?
  public let postTags: [String]?
  
  public init(postUrl: URL?, postText: String?, postTags: [String]?) {
    self.postUrl = postUrl
    self.postText = postText
    self.postTags = postTags
  }
}
