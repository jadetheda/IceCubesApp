import SwiftUI

public enum SearchScope: String, CaseIterable {
  case all, people, hashtags, posts
  
  public var localizedString: LocalizedStringKey {
    switch self {
    case .all:
      .init("explore.scope.all")
    case .people:
      .init("explore.scope.people")
    case .hashtags:
      .init("explore.scope.hashtags")
    case .posts:
      .init("explore.scope.posts")
    }
  }
}