import SwiftUI

public enum StatusAction: String, CaseIterable, Identifiable {
  public var id: String {
    "\(rawValue)"
  }

  case none, reply, boost, favorite, bookmark, quote

  public func displayName(
    isReblogged: Bool = false, isFavorited: Bool = false, isBookmarked: Bool = false,
    privateBoost: Bool = false, isLikeAction: Bool = false
  ) -> LocalizedStringKey {
    switch self {
    case .none:
      return "settings.swipeactions.status.action.none"
    case .reply:
      return "settings.swipeactions.status.action.reply"
    case .quote:
      return "settings.swipeactions.status.action.quote"
    case .boost:
      if privateBoost {
        return isReblogged ? "status.action.unboost" : "status.action.boost-to-followers"
      }

      return isReblogged ? "status.action.unboost" : "settings.swipeactions.status.action.boost"
    case .favorite:
      if isLikeAction {
        return isFavorited ? "Unlike" : "Like"
      }
      return isFavorited
        ? "status.action.unfavorite" : "settings.swipeactions.status.action.favorite"
    case .bookmark:
      return isBookmarked
        ? "status.action.unbookmark" : "settings.swipeactions.status.action.bookmark"
    }
  }

  public func iconName(
    isReblogged: Bool = false, isFavorited: Bool = false, isBookmarked: Bool = false,
    privateBoost: Bool = false, isLikeAction: Bool = false
  ) -> String {
    switch self {
    case .none:
      return "slash.circle"
    case .reply:
      return "arrowshape.turn.up.left"
    case .quote:
      return "quote.bubble"
    case .boost:
      if privateBoost {
        return isReblogged ? "Rocket.Fill" : "lock.rotation"
      }

      return isReblogged ? "Rocket.Fill" : "Rocket"
    case .favorite:
      if isLikeAction {
        return isFavorited ? "heart.fill" : "heart"
      }
      return isFavorited ? "star.fill" : "star"
    case .bookmark:
      return isBookmarked ? "bookmark.fill" : "bookmark"
    }
  }

  public func color(themeTintColor: Color, useThemeColor: Bool, outside: Bool, actionFavoriteColor: Color = .yellow, actionBoostColor: Color = .green, actionBookmarkColor: Color = .pink) -> Color {
    if useThemeColor {
      return outside ? themeTintColor : .gray
    }

    switch self {
    case .none:
      return .gray
    case .reply:
      return outside ? .gray : Color(white: 0.45)
    case .quote:
      return outside ? .gray : Color(white: 0.45)
    case .boost:
      return actionBoostColor
    case .favorite:
      return actionFavoriteColor
    case .bookmark:
      return actionBookmarkColor
    }
  }
}
