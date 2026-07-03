import Foundation
import SwiftUI
import Observation
import Models

@MainActor
@Observable public class NotificationsContentFilter {
  public static let shared = NotificationsContentFilter()

  class Storage {
    @AppStorage("notifications_show_follow") var showFollow: Bool = true
    @AppStorage("notifications_show_followrequest") var showFollowRequest: Bool = true
    @AppStorage("notifications_show_mention") var showMention: Bool = true
    @AppStorage("notifications_show_reblog") var showReblog: Bool = true
    @AppStorage("notifications_show_status") var showStatus: Bool = true
    @AppStorage("notifications_show_favourite") var showFavourite: Bool = true
    @AppStorage("notifications_show_poll") var showPoll: Bool = true
    @AppStorage("notifications_show_update") var showUpdate: Bool = true
    @AppStorage("notifications_show_quote") var showQuote: Bool = true
    @AppStorage("notifications_show_quotedupdate") var showQuotedUpdate: Bool = true
  }

  private let storage = Storage()

  @ObservationIgnored
  private var _showFollow: Bool = true
  public var showFollow: Bool {
    get {
      access(keyPath: \.showFollow)
      return _showFollow
    }
    set {
      withMutation(keyPath: \.showFollow) {
        _showFollow = newValue
        storage.showFollow = newValue
      }
    }
  }
  @ObservationIgnored
  private var _showFollowRequest: Bool = true
  public var showFollowRequest: Bool {
    get {
      access(keyPath: \.showFollowRequest)
      return _showFollowRequest
    }
    set {
      withMutation(keyPath: \.showFollowRequest) {
        _showFollowRequest = newValue
        storage.showFollowRequest = newValue
      }
    }
  }
  @ObservationIgnored
  private var _showMention: Bool = true
  public var showMention: Bool {
    get {
      access(keyPath: \.showMention)
      return _showMention
    }
    set {
      withMutation(keyPath: \.showMention) {
        _showMention = newValue
        storage.showMention = newValue
      }
    }
  }
  @ObservationIgnored
  private var _showReblog: Bool = true
  public var showReblog: Bool {
    get {
      access(keyPath: \.showReblog)
      return _showReblog
    }
    set {
      withMutation(keyPath: \.showReblog) {
        _showReblog = newValue
        storage.showReblog = newValue
      }
    }
  }
  @ObservationIgnored
  private var _showStatus: Bool = true
  public var showStatus: Bool {
    get {
      access(keyPath: \.showStatus)
      return _showStatus
    }
    set {
      withMutation(keyPath: \.showStatus) {
        _showStatus = newValue
        storage.showStatus = newValue
      }
    }
  }
  @ObservationIgnored
  private var _showFavourite: Bool = true
  public var showFavourite: Bool {
    get {
      access(keyPath: \.showFavourite)
      return _showFavourite
    }
    set {
      withMutation(keyPath: \.showFavourite) {
        _showFavourite = newValue
        storage.showFavourite = newValue
      }
    }
  }
  @ObservationIgnored
  private var _showPoll: Bool = true
  public var showPoll: Bool {
    get {
      access(keyPath: \.showPoll)
      return _showPoll
    }
    set {
      withMutation(keyPath: \.showPoll) {
        _showPoll = newValue
        storage.showPoll = newValue
      }
    }
  }
  @ObservationIgnored
  private var _showUpdate: Bool = true
  public var showUpdate: Bool {
    get {
      access(keyPath: \.showUpdate)
      return _showUpdate
    }
    set {
      withMutation(keyPath: \.showUpdate) {
        _showUpdate = newValue
        storage.showUpdate = newValue
      }
    }
  }
  @ObservationIgnored
  private var _showQuote: Bool = true
  public var showQuote: Bool {
    get {
      access(keyPath: \.showQuote)
      return _showQuote
    }
    set {
      withMutation(keyPath: \.showQuote) {
        _showQuote = newValue
        storage.showQuote = newValue
      }
    }
  }
  @ObservationIgnored
  private var _showQuotedUpdate: Bool = true
  public var showQuotedUpdate: Bool {
    get {
      access(keyPath: \.showQuotedUpdate)
      return _showQuotedUpdate
    }
    set {
      withMutation(keyPath: \.showQuotedUpdate) {
        _showQuotedUpdate = newValue
        storage.showQuotedUpdate = newValue
      }
    }
  }

  private init() {
    _showFollow = storage.showFollow
    _showFollowRequest = storage.showFollowRequest
    _showMention = storage.showMention
    _showReblog = storage.showReblog
    _showStatus = storage.showStatus
    _showFavourite = storage.showFavourite
    _showPoll = storage.showPoll
    _showUpdate = storage.showUpdate
    _showQuote = storage.showQuote
    _showQuotedUpdate = storage.showQuotedUpdate
  }

  public func isTypeEnabled(_ type: Models.Notification.NotificationType?) -> Bool {
    guard let type = type else { return true }
    switch type {
    case .follow: return showFollow
    case .follow_request: return showFollowRequest
    case .mention: return showMention
    case .reblog: return showReblog
    case .status: return showStatus
    case .favourite: return showFavourite
    case .poll: return showPoll
    case .update: return showUpdate
    case .quote: return showQuote
    case .quoted_update: return showQuotedUpdate
    }
  }
}
