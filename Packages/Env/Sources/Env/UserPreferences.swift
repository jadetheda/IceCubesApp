import Combine
import Foundation
import Models
import NetworkClient
import SwiftUI

@MainActor
@Observable public class UserPreferences {
  class Storage {
    @AppStorage("preferred_browser") public var preferredBrowser: PreferredBrowser = .inAppSafari
    @AppStorage("show_translate_button_inline") public var showTranslateButton: Bool = true
    @AppStorage("show_pending_at_bottom") public var pendingShownAtBottom: Bool = false
    @AppStorage("show_pending_left") public var pendingShownLeft: Bool = false

    @AppStorage("recently_used_languages") public var recentlyUsedLanguages: [String] = []
    @AppStorage("social_keyboard_composer") public var isSocialKeyboardEnabled: Bool = false
    @AppStorage("show_language_filters") public var showLanguageFilters: Bool = false

    @AppStorage("use_instance_content_settings") public var useInstanceContentSettings: Bool = true
    @AppStorage("app_auto_expand_spoilers") public var appAutoExpandSpoilers = false
    @AppStorage("app_auto_expand_media") public var appAutoExpandMedia:
      ServerPreferences.AutoExpandMedia = .hideSensitive
    @AppStorage("app_default_post_visibility") public var appDefaultPostVisibility:
      Models.Visibility = .pub
    @AppStorage("app_default_reply_visibility") public var appDefaultReplyVisibility:
      Models.Visibility = .pub
    @AppStorage("app_default_posts_sensitive") public var appDefaultPostsSensitive = false
    @AppStorage("app_require_alt_text") public var appRequireAltText = false
    @AppStorage("autoplay_video") public var autoPlayVideo = true
    @AppStorage("animate_emojis") public var animateEmojis = true
    @AppStorage("cache_server_emotes") public var cacheServerEmotes = true
    @AppStorage("mute_video") public var muteVideo = true
    @AppStorage("preferred_translation_type") public var preferredTranslationType = TranslationType
      .useServerIfPossible
    @AppStorage("user_deepl_api_free") public var userDeeplAPIFree = true
    @AppStorage("auto_detect_post_language") public var autoDetectPostLanguage = true

    @AppStorage("show_interaction_buttons") public var showInteractionButtons = true
    @AppStorage("inAppBrowserReaderView") public var inAppBrowserReaderView = false
    @AppStorage("gallery_columns") public var galleryColumns: Int = 2
    @AppStorage("gallery_crop_to_square") public var galleryCropToSquare: Bool = false
    @AppStorage("gallery_add_thin_margins") public var galleryAddThinMargins: Bool = false
    @AppStorage("gallery_optimize_item_layout") public var galleryOptimizeItemLayout: Bool = true
    @AppStorage("gallery_round_corners") public var galleryRoundCorners: Bool = true
    @AppStorage("status_media_grid_mode") public var statusMediaGridMode: Bool = true
    @AppStorage("crop_status_media_on_timeline") public var cropStatusMediaOnTimeline: Bool = false
    @AppStorage("undo_scroll_to_top_enabled") public var undoScrollToTopEnabled: Bool = true
    @AppStorage("undo_scroll_to_top_timeout") public var undoScrollToTopTimeout: Double = 10.0

    @AppStorage("haptic_tab") public var hapticTabSelectionEnabled = true
    @AppStorage("haptic_timeline") public var hapticTimelineEnabled = true
    @AppStorage("haptic_button_press") public var hapticButtonPressEnabled = true
    @AppStorage("sound_effect_enabled") public var soundEffectEnabled = true

    @AppStorage("show_alt_text_for_media") public var showAltTextForMedia = true

    @AppStorage("show_second_column_ipad") public var showiPadSecondaryColumn = true

    @AppStorage("swipeactions-status-trailing-right") public var swipeActionsStatusTrailingRight =
      StatusAction.favorite
    @AppStorage("swipeactions-status-trailing-left") public var swipeActionsStatusTrailingLeft =
      StatusAction.boost
    @AppStorage("swipeactions-status-leading-left") public var swipeActionsStatusLeadingLeft =
      StatusAction.reply
    @AppStorage("swipeactions-status-leading-right") public var swipeActionsStatusLeadingRight =
      StatusAction.none
    @AppStorage("swipeactions-use-theme-color") public var swipeActionsUseThemeColor = false
    @AppStorage("swipeactions-icon-style") public var swipeActionsIconStyle: SwipeActionsIconStyle =
      .iconWithText

    @AppStorage("requested_review") public var requestedReview = false

    @AppStorage("collapse-long-posts") public var collapseLongPosts = true

    @AppStorage("share-button-behavior") public var shareButtonBehavior:
      PreferredShareButtonBehavior = .linkOnly

    @AppStorage("boost-button-behavior") public var boostButtonBehavior:
      PreferredBoostButtonBehavior = .both

    @AppStorage("max_reply_indentation") public var maxReplyIndentation: UInt = 7
    @AppStorage("show_reply_indentation") public var showReplyIndentation: Bool = true

    @AppStorage("show_account_popover") public var showAccountPopover: Bool = true

    @AppStorage("sidebar_expanded") public var isSidebarExpanded: Bool = false
    
    @AppStorage("stream_home_timeline") public var streamHomeTimeline: Bool = false
    @AppStorage("full_timeline_fetch") public var fullTimelineFetch: Bool = false

    // Notifications
    @AppStorage("notifications-truncate-status-content")
    public var notificationsTruncateStatusContent: Bool = true

    // Hide Seen Posts (Experimental)
    @AppStorage("hide_seen_posts_enabled") public var hideSeenPostsEnabled: Bool = false
    @AppStorage("hide_seen_posts_threshold") public var hideSeenPostsThreshold: Double = 1.0
    @AppStorage("hide_seen_posts_liked_only") public var hideSeenPostsLikedOnly: Bool = false
    @AppStorage("hide_seen_posts_show_in_header") public var hideSeenPostsShowInHeader: Bool = false
    @AppStorage("hide_seen_posts_require_media_loaded") public var hideSeenPostsRequireMediaLoaded: Bool = true
    @AppStorage("hide_seen_posts_include_boosts") public var hideSeenPostsIncludeBoosts: Bool = true
    @AppStorage("hide_seen_posts_is_toggle") public var hideSeenPostsIsToggle: Bool = true

    @AppStorage("show_hide_posts_without_media_toggle") public var showHidePostsWithoutMediaToggle: Bool = false

    @AppStorage("remote_media_auto_fallback") public var remoteMediaAutoFallback: Bool = true
    @AppStorage("remote_media_auto_fallback_delay") public var remoteMediaAutoFallbackDelay: Double = 10.0
    @AppStorage("remote_media_fallback_on_fail") public var remoteMediaFallbackOnFail: Bool = true
    @AppStorage("remote_media_always_force") public var remoteMediaAlwaysForce: Bool = false
    @AppStorage("show_timeline_hide_pinned_toggle") public var showTimelineHidePinnedToggle: Bool = false
    @AppStorage("timeline_pinned_hidden") public var timelinePinnedHidden: Bool = false
    @AppStorage("show_pinned_items_symbol") public var showPinnedItemsSymbol: Bool = true
    @AppStorage("use_iceshrimp_workarounds") public var useIceShrimpWorkarounds: Bool = false
    @AppStorage("iceshrimp_show_boosts_button") public var iceShrimpShowBoostsButton: Bool = false
    @AppStorage("iceshrimp_show_incompatible_buttons") public var iceShrimpShowIncompatibleButtons: Bool = false
    @AppStorage("never_load_video") public var neverLoadVideo: Bool = false
    
    @AppStorage("trending_algorithm") public var trendingAlgorithm: TrendingAlgorithm = .mastodon
    @AppStorage("trending_simple_score_search_limit") public var trendingSimpleScoreSearchLimit: Int = 40

    @AppStorage("iceshrimp_trending") public var iceShrimpTrending: Bool = false
    @AppStorage("iceshrimp_trending_threshold") public var iceShrimpTrendingThreshold: Int = 5
    @AppStorage("iceshrimp_trending_halflife") public var iceShrimpTrendingHalfLife: Double = 1.0

    @AppStorage("tag_groups_client_side_merge") public var tagGroupsClientSideMergeEnabled: Bool = false

    init() {
      prepareTranslationType()
    }

    private func prepareTranslationType() {
      let sharedDefault = UserDefaults.standard
      if let alwaysUseDeepl = (sharedDefault.object(forKey: "always_use_deepl") as? Bool) {
        if alwaysUseDeepl {
          preferredTranslationType = .useDeepl
        }
        sharedDefault.removeObject(forKey: "always_use_deepl")
      }
      #if canImport(_Translation_SwiftUI)
        if #unavailable(iOS 17.4),
          preferredTranslationType == .useApple
        {
          preferredTranslationType = .useServerIfPossible
        }
      #else
        if preferredTranslationType == .useApple {
          preferredTranslationType = .useServerIfPossible
        }
      #endif
    }
  }

  public static let sharedDefault = UserDefaults(suiteName: "group.com.thomasricouard.IceCubesApp")
  public static let shared = UserPreferences()
  private let storage = Storage()

  private var client: MastodonClient?

  public var preferredBrowser: PreferredBrowser {
    didSet {
      storage.preferredBrowser = preferredBrowser
    }
  }

  public var showTranslateButton: Bool {
    didSet {
      storage.showTranslateButton = showTranslateButton
    }
  }

  public var pendingShownAtBottom: Bool {
    didSet {
      storage.pendingShownAtBottom = pendingShownAtBottom
    }
  }

  public var pendingShownLeft: Bool {
    didSet {
      storage.pendingShownLeft = pendingShownLeft
    }
  }

  public var pendingLocation: Alignment {
    let fromLeft =
      Locale.current.language.characterDirection == .leftToRight
      ? pendingShownLeft : !pendingShownLeft
    if pendingShownAtBottom {
      if fromLeft {
        return .bottomLeading
      } else {
        return .bottomTrailing
      }
    } else {
      if fromLeft {
        return .topLeading
      } else {
        return .topTrailing
      }
    }
  }

  public var recentlyUsedLanguages: [String] {
    didSet {
      storage.recentlyUsedLanguages = recentlyUsedLanguages
    }
  }

  public var showLanguageFilters: Bool {
    get {
      access(keyPath: \.showLanguageFilters)
      return _showLanguageFilters
    }
    set {
      withMutation(keyPath: \.showLanguageFilters) {
        _showLanguageFilters = newValue
        storage.showLanguageFilters = newValue
      }
    }
  }

  @ObservationIgnored
  private var _showLanguageFilters: Bool = false
  
  public var isSocialKeyboardEnabled: Bool {
    didSet {
      storage.isSocialKeyboardEnabled = isSocialKeyboardEnabled
    }
  }

  public var useInstanceContentSettings: Bool {
    didSet {
      storage.useInstanceContentSettings = useInstanceContentSettings
    }
  }

  public var appAutoExpandSpoilers: Bool {
    didSet {
      storage.appAutoExpandSpoilers = appAutoExpandSpoilers
    }
  }

  public var appAutoExpandMedia: ServerPreferences.AutoExpandMedia {
    didSet {
      storage.appAutoExpandMedia = appAutoExpandMedia
    }
  }

  public var appDefaultPostVisibility: Models.Visibility {
    didSet {
      storage.appDefaultPostVisibility = appDefaultPostVisibility
    }
  }

  public var appDefaultReplyVisibility: Models.Visibility {
    didSet {
      storage.appDefaultReplyVisibility = appDefaultReplyVisibility
    }
  }

  public var appDefaultPostsSensitive: Bool {
    didSet {
      storage.appDefaultPostsSensitive = appDefaultPostsSensitive
    }
  }

  public var appRequireAltText: Bool {
    didSet {
      storage.appRequireAltText = appRequireAltText
    }
  }

  public var autoPlayVideo: Bool {
    didSet {
      storage.autoPlayVideo = autoPlayVideo
    }
  }
    
  public var animateEmojis: Bool {
    didSet {
      storage.animateEmojis = animateEmojis
    }
  }

  public var cacheServerEmotes: Bool {
    didSet {
      storage.cacheServerEmotes = cacheServerEmotes
    }
  }

  public var muteVideo: Bool {
    didSet {
      storage.muteVideo = muteVideo
    }
  }

  public var preferredTranslationType: TranslationType {
    didSet {
      storage.preferredTranslationType = preferredTranslationType
    }
  }

  public var userDeeplAPIFree: Bool {
    didSet {
      storage.userDeeplAPIFree = userDeeplAPIFree
    }
  }

  public var autoDetectPostLanguage: Bool {
    didSet {
      storage.autoDetectPostLanguage = autoDetectPostLanguage
    }
  }

  public var galleryColumns: Int {
    didSet {
      storage.galleryColumns = galleryColumns
    }
  }

  public var undoScrollToTopEnabled: Bool {
    didSet { storage.undoScrollToTopEnabled = undoScrollToTopEnabled }
  }
  public var undoScrollToTopTimeout: Double {
    didSet { storage.undoScrollToTopTimeout = undoScrollToTopTimeout }
  }
  public var galleryCropToSquare: Bool {
    didSet {
      storage.galleryCropToSquare = galleryCropToSquare
    }
  }
  public var galleryAddThinMargins: Bool {
    didSet {
      storage.galleryAddThinMargins = galleryAddThinMargins
    }
  }
  public var galleryOptimizeItemLayout: Bool {
    didSet {
      storage.galleryOptimizeItemLayout = galleryOptimizeItemLayout
    }
  }
  public var galleryRoundCorners: Bool {
    didSet {
      storage.galleryRoundCorners = galleryRoundCorners
    }
  }
  public var cropStatusMediaOnTimeline: Bool {
    didSet {
      storage.cropStatusMediaOnTimeline = cropStatusMediaOnTimeline
    }
  }
  public var statusMediaGridMode: Bool {
    didSet {
      storage.statusMediaGridMode = statusMediaGridMode
    }
  }
  public var showInteractionButtons: Bool {
    didSet {
      storage.showInteractionButtons = showInteractionButtons
    }
  }

  public var inAppBrowserReaderView: Bool {
    didSet {
      storage.inAppBrowserReaderView = inAppBrowserReaderView
    }
  }

  public var hapticTabSelectionEnabled: Bool {
    didSet {
      storage.hapticTabSelectionEnabled = hapticTabSelectionEnabled
    }
  }

  public var hapticTimelineEnabled: Bool {
    didSet {
      storage.hapticTimelineEnabled = hapticTimelineEnabled
    }
  }

  public var hapticButtonPressEnabled: Bool {
    didSet {
      storage.hapticButtonPressEnabled = hapticButtonPressEnabled
    }
  }

  public var soundEffectEnabled: Bool {
    didSet {
      storage.soundEffectEnabled = soundEffectEnabled
    }
  }

  public var showAltTextForMedia: Bool {
    didSet {
      storage.showAltTextForMedia = showAltTextForMedia
    }
  }

  public var showiPadSecondaryColumn: Bool {
    didSet {
      storage.showiPadSecondaryColumn = showiPadSecondaryColumn
    }
  }

  public var swipeActionsStatusTrailingRight: StatusAction {
    didSet {
      storage.swipeActionsStatusTrailingRight = swipeActionsStatusTrailingRight
    }
  }

  public var swipeActionsStatusTrailingLeft: StatusAction {
    didSet {
      storage.swipeActionsStatusTrailingLeft = swipeActionsStatusTrailingLeft
    }
  }

  public var swipeActionsStatusLeadingLeft: StatusAction {
    didSet {
      storage.swipeActionsStatusLeadingLeft = swipeActionsStatusLeadingLeft
    }
  }

  public var swipeActionsStatusLeadingRight: StatusAction {
    didSet {
      storage.swipeActionsStatusLeadingRight = swipeActionsStatusLeadingRight
    }
  }

  public var swipeActionsUseThemeColor: Bool {
    didSet {
      storage.swipeActionsUseThemeColor = swipeActionsUseThemeColor
    }
  }

  public var swipeActionsIconStyle: SwipeActionsIconStyle {
    didSet {
      storage.swipeActionsIconStyle = swipeActionsIconStyle
    }
  }

  public var requestedReview: Bool {
    didSet {
      storage.requestedReview = requestedReview
    }
  }

  public var collapseLongPosts: Bool {
    didSet {
      storage.collapseLongPosts = collapseLongPosts
    }
  }

  public var shareButtonBehavior: PreferredShareButtonBehavior {
    didSet {
      storage.shareButtonBehavior = shareButtonBehavior
    }
  }

  public var boostButtonBehavior: PreferredBoostButtonBehavior {
    didSet {
      storage.boostButtonBehavior = boostButtonBehavior
    }
  }

  public var maxReplyIndentation: UInt {
    didSet {
      storage.maxReplyIndentation = maxReplyIndentation
    }
  }

  public var showReplyIndentation: Bool {
    didSet {
      storage.showReplyIndentation = showReplyIndentation
    }
  }

  public var showAccountPopover: Bool {
    didSet {
      storage.showAccountPopover = showAccountPopover
    }
  }

  public var isSidebarExpanded: Bool {
    didSet {
      storage.isSidebarExpanded = isSidebarExpanded
    }
  }
  
  public var streamHomeTimeline: Bool {
    didSet {
      storage.streamHomeTimeline = streamHomeTimeline
    }
  }

  // Hide Seen Posts
  public var hideSeenPostsEnabled: Bool {
    didSet {
      storage.hideSeenPostsEnabled = hideSeenPostsEnabled
    }
  }

  public var hideSeenPostsThreshold: Double {
    didSet {
      storage.hideSeenPostsThreshold = hideSeenPostsThreshold
    }
  }

  public var hideSeenPostsLikedOnly: Bool {
    didSet {
      storage.hideSeenPostsLikedOnly = hideSeenPostsLikedOnly
    }
  }

  public var hideSeenPostsShowInHeader: Bool {
    didSet {
      storage.hideSeenPostsShowInHeader = hideSeenPostsShowInHeader
    }
  }

  public var hideSeenPostsRequireMediaLoaded: Bool {
    didSet {
      storage.hideSeenPostsRequireMediaLoaded = hideSeenPostsRequireMediaLoaded
    }
  }

  public var hideSeenPostsIncludeBoosts: Bool {
    didSet {
      storage.hideSeenPostsIncludeBoosts = hideSeenPostsIncludeBoosts
    }
  }


  public var remoteMediaAutoFallback: Bool {
    didSet {
      storage.remoteMediaAutoFallback = remoteMediaAutoFallback
    }
  }
  public var remoteMediaAutoFallbackDelay: Double {
    didSet {
      storage.remoteMediaAutoFallbackDelay = remoteMediaAutoFallbackDelay
    }
  }
  public var remoteMediaFallbackOnFail: Bool {
    didSet {
      storage.remoteMediaFallbackOnFail = remoteMediaFallbackOnFail
    }
  }
  public var useIceShrimpWorkarounds: Bool {
    didSet {
      storage.useIceShrimpWorkarounds = useIceShrimpWorkarounds
    }
  }
  public var iceShrimpShowBoostsButton: Bool {
    didSet {
      storage.iceShrimpShowBoostsButton = iceShrimpShowBoostsButton
    }
  }
  public var iceShrimpShowIncompatibleButtons: Bool {
    didSet {
      storage.iceShrimpShowIncompatibleButtons = iceShrimpShowIncompatibleButtons
    }
  }
  public var neverLoadVideo: Bool {
    didSet {
      storage.neverLoadVideo = neverLoadVideo
    }
  }
  
  public var trendingAlgorithm: TrendingAlgorithm {
    didSet { storage.trendingAlgorithm = trendingAlgorithm }
  }
  public var trendingSimpleScoreSearchLimit: Int {
    didSet { storage.trendingSimpleScoreSearchLimit = trendingSimpleScoreSearchLimit }
  }

  public var iceShrimpTrending: Bool {
    didSet {
      storage.iceShrimpTrending = iceShrimpTrending
    }
  }
  public var iceShrimpTrendingThreshold: Int {
    didSet {
      storage.iceShrimpTrendingThreshold = iceShrimpTrendingThreshold
    }
  }
  public var iceShrimpTrendingHalfLife: Double {
    didSet {
      storage.iceShrimpTrendingHalfLife = iceShrimpTrendingHalfLife
    }
  }

  public var remoteMediaAlwaysForce: Bool {
    didSet {
      storage.remoteMediaAlwaysForce = remoteMediaAlwaysForce
    }
  }

  public var showTimelineHidePinnedToggle: Bool {
    didSet {
      storage.showTimelineHidePinnedToggle = showTimelineHidePinnedToggle
    }
  }

  public var timelinePinnedHidden: Bool {
    didSet {
      storage.timelinePinnedHidden = timelinePinnedHidden
    }
  }

  public var showPinnedItemsSymbol: Bool {
    didSet {
      storage.showPinnedItemsSymbol = showPinnedItemsSymbol
    }
  }

  public var tagGroupsClientSideMergeEnabled: Bool {
    didSet {
      storage.tagGroupsClientSideMergeEnabled = tagGroupsClientSideMergeEnabled
    }
  }

  public var hideSeenPostsIsToggle: Bool {
    didSet {
      storage.hideSeenPostsIsToggle = hideSeenPostsIsToggle
    }
  }

  public var showHidePostsWithoutMediaToggle: Bool {
    didSet {
      storage.showHidePostsWithoutMediaToggle = showHidePostsWithoutMediaToggle
    }
  }

  public var fullTimelineFetch: Bool {
    didSet {
      storage.fullTimelineFetch = fullTimelineFetch
    }
  }

  // Notifications
  public var notificationsTruncateStatusContent: Bool {
    didSet {
      storage.notificationsTruncateStatusContent = notificationsTruncateStatusContent
    }
  }

  public func getRealMaxIndent() -> UInt {
    showReplyIndentation ? maxReplyIndentation : 0
  }

  
  public enum TrendingAlgorithm: String, CaseIterable, Identifiable {
    case mastodon
    case simpleScore
    case decayingScore
    
    public var id: String { rawValue }
    
    public var description: String {
      switch self {
      case .mastodon:
        return "Mastodon (Default)"
      case .simpleScore:
        return "Simple Score"
      case .decayingScore:
        return "Decaying Score (IceShrimp fallback)"
      }
    }
  }

  public enum SwipeActionsIconStyle: String, CaseIterable {
    case iconWithText, iconOnly

    public var description: LocalizedStringKey {
      switch self {
      case .iconWithText:
        "enum.swipeactions.icon-with-text"
      case .iconOnly:
        "enum.swipeactions.icon-only"
      }
    }

    // Have to implement this manually here due to compiler not implicitly
    // inserting `nonisolated`, which leads to a warning:
    //
    //     Main actor-isolated static property 'allCases' cannot be used to
    //     satisfy nonisolated protocol requirement
    //
    public nonisolated static var allCases: [Self] {
      [.iconWithText, .iconOnly]
    }
  }

  public var postVisibility: Models.Visibility {
    if useInstanceContentSettings {
      serverPreferences?.postVisibility ?? .pub
    } else {
      appDefaultPostVisibility
    }
  }

  public func conformReplyVisibilityConstraints() {
    appDefaultReplyVisibility = getReplyVisibility()
  }

  private func getReplyVisibility() -> Models.Visibility {
    getMinVisibility(postVisibility, appDefaultReplyVisibility)
  }

  public func getReplyVisibility(of status: Status) -> Models.Visibility {
    getMinVisibility(getReplyVisibility(), status.visibility)
  }

  private func getMinVisibility(_ vis1: Models.Visibility, _ vis2: Models.Visibility)
    -> Models.Visibility
  {
    let no1 = Self.getIntOfVisibility(vis1)
    let no2 = Self.getIntOfVisibility(vis2)

    return no1 < no2 ? vis1 : vis2
  }

  public var postIsSensitive: Bool {
    if useInstanceContentSettings {
      serverPreferences?.postIsSensitive ?? false
    } else {
      appDefaultPostsSensitive
    }
  }

  public var autoExpandSpoilers: Bool {
    if useInstanceContentSettings {
      serverPreferences?.autoExpandSpoilers ?? true
    } else {
      appAutoExpandSpoilers
    }
  }

  public var autoExpandMedia: ServerPreferences.AutoExpandMedia {
    if useInstanceContentSettings {
      serverPreferences?.autoExpandMedia ?? .hideSensitive
    } else {
      appAutoExpandMedia
    }
  }

  public var notificationsCount: [OauthToken: Int] = [:] {
    didSet {
      for (key, value) in notificationsCount {
        Self.sharedDefault?.set(value, forKey: "push_notifications_count_\(key.createdAt)")
      }
    }
  }

  public var totalNotificationsCount: Int {
    notificationsCount.compactMap { $0.value }.reduce(0, +)
  }

  public func reloadNotificationsCount(tokens: [OauthToken]) {
    notificationsCount = [:]
    for token in tokens {
      notificationsCount[token] =
        Self.sharedDefault?.integer(forKey: "push_notifications_count_\(token.createdAt)") ?? 0
    }
  }

  public var serverPreferences: ServerPreferences?

  public func setClient(client: MastodonClient) {
    self.client = client
    Task {
      await refreshServerPreferences()
    }
  }

  public func refreshServerPreferences() async {
    guard let client, client.isAuth else { return }
    serverPreferences = try? await client.get(endpoint: Accounts.preferences)
  }

  public func markLanguageAsSelected(isoCode: String) {
    var copy = recentlyUsedLanguages
    if let index = copy.firstIndex(of: isoCode) {
      copy.remove(at: index)
    }
    copy.insert(isoCode, at: 0)
    recentlyUsedLanguages = Array(copy.prefix(3))
  }

  public static func getIntOfVisibility(_ vis: Models.Visibility) -> Int {
    switch vis {
    case .direct:
      0
    case .priv:
      1
    case .unlisted:
      2
    case .pub:
      3
    }
  }

  private init() {
    preferredBrowser = storage.preferredBrowser
    showTranslateButton = storage.showTranslateButton
    recentlyUsedLanguages = storage.recentlyUsedLanguages
    isSocialKeyboardEnabled = storage.isSocialKeyboardEnabled
    _showLanguageFilters = storage.showLanguageFilters
    useInstanceContentSettings = storage.useInstanceContentSettings
    appAutoExpandSpoilers = storage.appAutoExpandSpoilers
    appAutoExpandMedia = storage.appAutoExpandMedia
    appDefaultPostVisibility = storage.appDefaultPostVisibility
    appDefaultReplyVisibility = storage.appDefaultReplyVisibility
    appDefaultPostsSensitive = storage.appDefaultPostsSensitive
    appRequireAltText = storage.appRequireAltText
    autoPlayVideo = storage.autoPlayVideo
    animateEmojis = storage.animateEmojis
    cacheServerEmotes = storage.cacheServerEmotes
    preferredTranslationType = storage.preferredTranslationType
    userDeeplAPIFree = storage.userDeeplAPIFree
    autoDetectPostLanguage = storage.autoDetectPostLanguage
    galleryColumns = storage.galleryColumns
    galleryCropToSquare = storage.galleryCropToSquare
    galleryAddThinMargins = storage.galleryAddThinMargins
    galleryOptimizeItemLayout = storage.galleryOptimizeItemLayout
    galleryRoundCorners = storage.galleryRoundCorners
    cropStatusMediaOnTimeline = storage.cropStatusMediaOnTimeline
    statusMediaGridMode = storage.statusMediaGridMode
    undoScrollToTopEnabled = storage.undoScrollToTopEnabled
    undoScrollToTopTimeout = storage.undoScrollToTopTimeout
    showInteractionButtons = storage.showInteractionButtons
    inAppBrowserReaderView = storage.inAppBrowserReaderView
    hapticTabSelectionEnabled = storage.hapticTabSelectionEnabled
    hapticTimelineEnabled = storage.hapticTimelineEnabled
    hapticButtonPressEnabled = storage.hapticButtonPressEnabled
    soundEffectEnabled = storage.soundEffectEnabled
    showAltTextForMedia = storage.showAltTextForMedia
    showiPadSecondaryColumn = storage.showiPadSecondaryColumn
    swipeActionsStatusTrailingRight = storage.swipeActionsStatusTrailingRight
    swipeActionsStatusTrailingLeft = storage.swipeActionsStatusTrailingLeft
    swipeActionsStatusLeadingLeft = storage.swipeActionsStatusLeadingLeft
    swipeActionsStatusLeadingRight = storage.swipeActionsStatusLeadingRight
    swipeActionsUseThemeColor = storage.swipeActionsUseThemeColor
    swipeActionsIconStyle = storage.swipeActionsIconStyle
    requestedReview = storage.requestedReview
    collapseLongPosts = storage.collapseLongPosts
    shareButtonBehavior = storage.shareButtonBehavior
    boostButtonBehavior = storage.boostButtonBehavior
    pendingShownAtBottom = storage.pendingShownAtBottom
    pendingShownLeft = storage.pendingShownLeft
    maxReplyIndentation = storage.maxReplyIndentation
    showReplyIndentation = storage.showReplyIndentation
    showAccountPopover = storage.showAccountPopover
    muteVideo = storage.muteVideo
    isSidebarExpanded = storage.isSidebarExpanded
    notificationsTruncateStatusContent = storage.notificationsTruncateStatusContent
    streamHomeTimeline = storage.streamHomeTimeline
    fullTimelineFetch = storage.fullTimelineFetch
    hideSeenPostsEnabled = storage.hideSeenPostsEnabled
    hideSeenPostsThreshold = storage.hideSeenPostsThreshold
    hideSeenPostsLikedOnly = storage.hideSeenPostsLikedOnly
    hideSeenPostsShowInHeader = storage.hideSeenPostsShowInHeader
    hideSeenPostsRequireMediaLoaded = storage.hideSeenPostsRequireMediaLoaded
    hideSeenPostsIncludeBoosts = storage.hideSeenPostsIncludeBoosts
    hideSeenPostsIsToggle = storage.hideSeenPostsIsToggle
    remoteMediaAutoFallback = storage.remoteMediaAutoFallback
    remoteMediaAutoFallbackDelay = storage.remoteMediaAutoFallbackDelay
    remoteMediaFallbackOnFail = storage.remoteMediaFallbackOnFail
    useIceShrimpWorkarounds = storage.useIceShrimpWorkarounds
    iceShrimpShowBoostsButton = storage.iceShrimpShowBoostsButton
    iceShrimpShowIncompatibleButtons = storage.iceShrimpShowIncompatibleButtons
    neverLoadVideo = storage.neverLoadVideo
    
    trendingAlgorithm = storage.trendingAlgorithm
    trendingSimpleScoreSearchLimit = storage.trendingSimpleScoreSearchLimit

    iceShrimpTrending = storage.iceShrimpTrending
    iceShrimpTrendingThreshold = storage.iceShrimpTrendingThreshold
    iceShrimpTrendingHalfLife = storage.iceShrimpTrendingHalfLife

    remoteMediaAlwaysForce = storage.remoteMediaAlwaysForce
    showTimelineHidePinnedToggle = storage.showTimelineHidePinnedToggle
    timelinePinnedHidden = storage.timelinePinnedHidden
    showPinnedItemsSymbol = storage.showPinnedItemsSymbol
    tagGroupsClientSideMergeEnabled = storage.tagGroupsClientSideMergeEnabled
    showHidePostsWithoutMediaToggle = storage.showHidePostsWithoutMediaToggle
  }
}

extension UInt: @retroactive RawRepresentable {
  public var rawValue: Int {
    Int(self)
  }

  public init?(rawValue: Int) {
    if rawValue >= 0 {
      self.init(rawValue)
    } else {
      return nil
    }
  }
}
