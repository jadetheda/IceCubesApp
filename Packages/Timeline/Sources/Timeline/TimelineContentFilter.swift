import Foundation
import SwiftUI
import Env

@MainActor
@Observable public class TimelineContentFilter {
  public struct Snapshot: Sendable {
    public let showBoosts: Bool
    public let showReplies: Bool
    public let showThreads: Bool
    public let showQuotePosts: Bool
    public let hidePostsWithMedia: Bool
    public let hidePostsWithoutMedia: Bool
    public let hidePostsFromBots: Bool
    public let isGalleryMode: Bool
    public let hideReadPosts: Bool
    public let hideOwnPosts: Bool
    public let hiddenLanguages: [String]
    public let hideSeenPostsEnabled: Bool
    public let hideSeenPostsIncludeBoosts: Bool

    public init(
      showBoosts: Bool = true,
      showReplies: Bool = true,
      showThreads: Bool = true,
      showQuotePosts: Bool = true,
      hidePostsWithMedia: Bool = false,
      hidePostsWithoutMedia: Bool = false,
      hidePostsFromBots: Bool = false,
      isGalleryMode: Bool = false,
      hideReadPosts: Bool = false,
      hideOwnPosts: Bool = false,
      hiddenLanguages: [String] = [],
      hideSeenPostsEnabled: Bool = false,
      hideSeenPostsIncludeBoosts: Bool = false
    ) {
      self.showBoosts = showBoosts
      self.showReplies = showReplies
      self.showThreads = showThreads
      self.showQuotePosts = showQuotePosts
      self.hidePostsWithMedia = hidePostsWithMedia
      self.hidePostsWithoutMedia = hidePostsWithoutMedia
      self.hidePostsFromBots = hidePostsFromBots
      self.isGalleryMode = isGalleryMode
      self.hideReadPosts = hideReadPosts
      self.hideOwnPosts = hideOwnPosts
      self.hiddenLanguages = hiddenLanguages
      self.hideSeenPostsEnabled = hideSeenPostsEnabled
      self.hideSeenPostsIncludeBoosts = hideSeenPostsIncludeBoosts
    }
  }

  class Storage {
    @AppStorage("timeline_show_boosts") var showBoosts: Bool = true
    @AppStorage("timeline_show_replies") var showReplies: Bool = true
    @AppStorage("timeline_show_threads") var showThreads: Bool = true
    @AppStorage("timeline_quote_posts") var showQuotePosts: Bool = true
    @AppStorage("timeline_hide_posts_with_media") var hidePostsWithMedia: Bool = false
    @AppStorage("timeline_hide_posts_without_media") var hidePostsWithoutMedia: Bool = false
    @AppStorage("timeline_hide_posts_from_bots") var hidePostsFromBots: Bool = false
    @AppStorage("timeline_gallery_mode") var isGalleryMode: Bool = false
    @AppStorage("timeline_hide_read_posts") var hideReadPosts: Bool = false
    @AppStorage("timeline_hide_own_posts") var hideOwnPosts: Bool = false
    @AppStorage("timeline_hidden_languages") var hiddenLanguages: [String] = []
  }

  public static let shared = TimelineContentFilter()
  private let storage = Storage()

  @ObservationIgnored
  private var _showBoosts: Bool = false
  public var showBoosts: Bool {
    get {
      access(keyPath: \.showBoosts)
      return _showBoosts
    }
    set {
      withMutation(keyPath: \.showBoosts) {
        _showBoosts = newValue
        storage.showBoosts = newValue
      }
    }
  }

  @ObservationIgnored
  private var _showReplies: Bool = false
  public var showReplies: Bool {
    get {
      access(keyPath: \.showReplies)
      return _showReplies
    }
    set {
      withMutation(keyPath: \.showReplies) {
        _showReplies = newValue
        storage.showReplies = newValue
      }
    }
  }

  @ObservationIgnored
  private var _showThreads: Bool = false
  public var showThreads: Bool {
    get {
      access(keyPath: \.showThreads)
      return _showThreads
    }
    set {
      withMutation(keyPath: \.showThreads) {
        _showThreads = newValue
        storage.showThreads = newValue
      }
    }
  }

  @ObservationIgnored
  private var _showQuotePosts: Bool = false
  public var showQuotePosts: Bool {
    get {
      access(keyPath: \.showQuotePosts)
      return _showQuotePosts
    }
    set {
      withMutation(keyPath: \.showQuotePosts) {
        _showQuotePosts = newValue
        storage.showQuotePosts = newValue
      }
    }
  }
  
  @ObservationIgnored
  private var _hidePostsWithMedia: Bool = false
  public var hidePostsWithMedia: Bool {
    get {
      access(keyPath: \.hidePostsWithMedia)
      return _hidePostsWithMedia
    }
    set {
      withMutation(keyPath: \.hidePostsWithMedia) {
        _hidePostsWithMedia = newValue
        storage.hidePostsWithMedia = newValue
      }
    }
  }
  
  @ObservationIgnored
  private var _hidePostsWithoutMedia: Bool = false
  public var hidePostsWithoutMedia: Bool {
    get {
      access(keyPath: \.hidePostsWithoutMedia)
      return _hidePostsWithoutMedia
    }
    set {
      withMutation(keyPath: \.hidePostsWithoutMedia) {
        _hidePostsWithoutMedia = newValue
        storage.hidePostsWithoutMedia = newValue
      }
    }
  }
    
    
  @ObservationIgnored
  private var _isGalleryMode: Bool = false
  public var isGalleryMode: Bool {
    get {
      access(keyPath: \.isGalleryMode)
      return _isGalleryMode
    }
    set {
      withMutation(keyPath: \.isGalleryMode) {
        _isGalleryMode = newValue
        storage.isGalleryMode = newValue
      }
    }
  }
    
  @ObservationIgnored
  private var _hidePostsFromBots: Bool = false
  public var hidePostsFromBots: Bool {
    get {
      access(keyPath: \.hidePostsFromBots)
      return _hidePostsFromBots
    }
    set {
      withMutation(keyPath: \.hidePostsFromBots) {
        _hidePostsFromBots = newValue
        storage.hidePostsFromBots = newValue
      }
    }
  }
    
  @ObservationIgnored
  private var _hideReadPosts: Bool = false
  public var hideReadPosts: Bool {
    get {
      access(keyPath: \.hideReadPosts)
      return _hideReadPosts
    }
    set {
      withMutation(keyPath: \.hideReadPosts) {
        _hideReadPosts = newValue
        storage.hideReadPosts = newValue
      }
    }
  }

  @ObservationIgnored
  private var _hideOwnPosts: Bool = false
  public var hideOwnPosts: Bool {
    get {
      access(keyPath: \.hideOwnPosts)
      return _hideOwnPosts
    }
    set {
      withMutation(keyPath: \.hideOwnPosts) {
        _hideOwnPosts = newValue
        storage.hideOwnPosts = newValue
      }
    }
  }

  
  @ObservationIgnored
  private var _hiddenLanguages: [String] = []
  public var hiddenLanguages: [String] {
    get {
      access(keyPath: \.hiddenLanguages)
      return _hiddenLanguages
    }
    set {
      withMutation(keyPath: \.hiddenLanguages) {
        _hiddenLanguages = newValue
        storage.hiddenLanguages = newValue
      }
    }
  }

  private init() {
    _showBoosts = storage.showBoosts
    _showReplies = storage.showReplies
    _showThreads = storage.showThreads
    _showQuotePosts = storage.showQuotePosts
    _hidePostsWithMedia = storage.hidePostsWithMedia
    _hidePostsWithoutMedia = storage.hidePostsWithoutMedia
    _hidePostsFromBots = storage.hidePostsFromBots
    _isGalleryMode = storage.isGalleryMode
    _hideReadPosts = storage.hideReadPosts
    _hideOwnPosts = storage.hideOwnPosts
    _hiddenLanguages = storage.hiddenLanguages
  }

  public func snapshot() -> Snapshot {
    Snapshot(
      showBoosts: showBoosts,
      showReplies: showReplies,
      showThreads: showThreads,
      showQuotePosts: showQuotePosts,
      hidePostsWithMedia: hidePostsWithMedia,
      hidePostsWithoutMedia: hidePostsWithoutMedia,
      hidePostsFromBots: hidePostsFromBots,
      isGalleryMode: isGalleryMode,
      hideReadPosts: hideReadPosts,
      hideOwnPosts: hideOwnPosts,
      hiddenLanguages: hiddenLanguages,
      hideSeenPostsEnabled: UserPreferences.shared.hideSeenPostsEnabled,
      hideSeenPostsIncludeBoosts: UserPreferences.shared.hideSeenPostsIncludeBoosts
    )
  }
}
