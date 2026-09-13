import AppAccount
import DesignSystem
import Env
import Models
import NetworkClient
import NukeUI
import SwiftUI
import Timeline
import UserNotifications

@MainActor
struct ContentSettingsView: View {
  @Environment(UserPreferences.self) private var userPreferences
  @Environment(Theme.self) private var theme
  @Environment(FediverseClient.self) private var client

  @State private var contentFilter = TimelineContentFilter.shared

  var body: some View {
    @Bindable var userPreferences = userPreferences
    Form {
      Section(header: Text("Language Text Post Filters"), footer: Text("Enabling these filters will hide text-only posts in chosen languages from your timeline, while preserving posts with media attachments.")) {
        Toggle(isOn: $userPreferences.showLanguageFilters) {
          Text("Show language filters in timeline options")
        }
        
      }
      #if !os(visionOS)
        .listRowBackground(theme.primaryBackgroundColor)
      #endif
      
      Section("settings.content.media") {
        Toggle(isOn: $userPreferences.autoPlayVideo) {
          Text("settings.other.autoplay-video")
        }
        Toggle(isOn: $userPreferences.muteVideo) {
          Text("settings.other.mute-video")
        }
        Toggle(isOn: $userPreferences.showAltTextForMedia) {
          Text("settings.content.media.show.alt")
        }
        Toggle(isOn: $userPreferences.animateEmojis) {
            Text("settings.other.animate-emojis")
        }

        Toggle(isOn: $userPreferences.remoteMediaAutoFallback) {
          Label("settings.content.media.remote-fallback.auto", systemImage: "photo.badge.arrow.down")
        }
        if userPreferences.remoteMediaAutoFallback {
          VStack(alignment: .leading) {
            Text(String(format: NSLocalizedString("settings.content.media.remote-fallback.delay", comment: ""), String(format: "%.1f", userPreferences.remoteMediaAutoFallbackDelay)))
            Slider(value: $userPreferences.remoteMediaAutoFallbackDelay, in: 0.1...15.0, step: 0.1)
          }
        }
        Toggle(isOn: $userPreferences.remoteMediaFallbackOnFail) {
          Label("settings.content.media.remote-fallback.on-fail", systemImage: "arrow.triangle.2.circlepath")
        }
        Toggle(isOn: $userPreferences.remoteMediaAlwaysForce) {
          Label("settings.content.media.remote-fallback.force", systemImage: "photo.badge.exclamationmark")
        }
      }

      #if !os(visionOS)
        .listRowBackground(theme.primaryBackgroundColor)
      #endif

      Section("settings.content.sharing") {
        Picker(
          "settings.content.sharing.share-button-behavior",
          selection: $userPreferences.shareButtonBehavior
        ) {
          ForEach(PreferredShareButtonBehavior.allCases, id: \.rawValue) { option in
            Text(option.title)
              .tag(option)
          }
        }
      }
      #if !os(visionOS)
        .listRowBackground(theme.primaryBackgroundColor)
      #endif

      Section("settings.content.instance-settings") {
        Toggle(isOn: $userPreferences.useInstanceContentSettings) {
          Text("settings.content.use-instance-settings")
        }
        .onChange(of: userPreferences.useInstanceContentSettings) { _, newVal in
          if newVal {
            userPreferences.appAutoExpandSpoilers = userPreferences.autoExpandSpoilers
            userPreferences.appAutoExpandMedia = userPreferences.autoExpandMedia
            userPreferences.appDefaultPostsSensitive = userPreferences.postIsSensitive
            userPreferences.appDefaultPostVisibility = userPreferences.postVisibility
            userPreferences.appRequireAltText = userPreferences.appRequireAltText
          }
        }
      }
      #if !os(visionOS)
        .listRowBackground(theme.primaryBackgroundColor)
      #endif

      if client.isIceShrimpWorkaroundsEnabled {
        Section {
          NavigationLink(destination: ExploreAlgorithmSettingsView()) {
            Text("IceShrimp.net explore algorithm")
          }
        }
        #if !os(visionOS)
          .listRowBackground(theme.primaryBackgroundColor)
        #endif
      }

      Section {
        Toggle(isOn: $userPreferences.appAutoExpandSpoilers) {
          Text("settings.content.expand-spoilers")
        }
        .disabled(userPreferences.useInstanceContentSettings)

        Picker("settings.content.expand-media", selection: $userPreferences.appAutoExpandMedia) {
          ForEach(ServerPreferences.AutoExpandMedia.allCases, id: \.rawValue) { media in
            Text(media.description).tag(media)
          }
        }
        .disabled(userPreferences.useInstanceContentSettings)

        Toggle(isOn: $userPreferences.collapseLongPosts) {
          Text("settings.content.collapse-long-posts")
        }
      } header: {
        Text("settings.content.reading")
      } footer: {
        Text("settings.content.collapse-long-posts-hint")
      }
      #if !os(visionOS)
        .listRowBackground(theme.primaryBackgroundColor)
      #endif

      Section("settings.content.posting") {
        Picker(
          "settings.content.default-visibility",
          selection: $userPreferences.appDefaultPostVisibility
        ) {
          ForEach(Visibility.allCases, id: \.rawValue) { vis in
            Text(vis.title).tag(vis)
          }
        }
        .disabled(userPreferences.useInstanceContentSettings)

        Picker(
          "settings.content.default-reply-visibility",
          selection: $userPreferences.appDefaultReplyVisibility
        ) {
          ForEach(Visibility.allCases, id: \.rawValue) { vis in
            if UserPreferences.getIntOfVisibility(vis)
              <= UserPreferences.getIntOfVisibility(userPreferences.postVisibility)
            {
              Text(vis.title).tag(vis)
            }
          }
        }
        .onChange(of: userPreferences.postVisibility) {
          userPreferences.conformReplyVisibilityConstraints()
        }

        Toggle(isOn: $userPreferences.appDefaultPostsSensitive) {
          Text("settings.content.default-sensitive")
        }
        .disabled(userPreferences.useInstanceContentSettings)

        Toggle(isOn: $userPreferences.appRequireAltText) {
          Text("settings.content.require-alt-text")
        }
      }
      #if !os(visionOS)
        .listRowBackground(theme.primaryBackgroundColor)
      #endif

      Section("timeline.content-filter.title") {
        Toggle(isOn: $contentFilter.showBoosts) {
          Label("timeline.filter.show-boosts", systemImage: "arrow.2.squarepath")
        }
        Toggle(isOn: $contentFilter.showReplies) {
          Label("timeline.filter.show-replies", systemImage: "bubble.left.and.bubble.right")
        }
        Toggle(isOn: $contentFilter.showThreads) {
          Label("timeline.filter.show-threads", systemImage: "bubble.left.and.text.bubble.right")
        }
        Toggle(isOn: $contentFilter.showQuotePosts) {
          Label("timeline.filter.show-quote", systemImage: "quote.bubble")
        }
        Toggle(isOn: Binding(
            get: { !contentFilter.hidePostsWithoutMedia },
            set: { contentFilter.hidePostsWithoutMedia = !$0 }
        )) {
          Label("Show text posts", systemImage: "text.alignleft")
        }
        .disabled(contentFilter.isGalleryMode)
        
        Toggle(isOn: Binding(
            get: { !contentFilter.hidePostsWithMedia },
            set: { contentFilter.hidePostsWithMedia = !$0 }
        )) {
          Label("Show media posts", systemImage: "photo")
        }
        
        Toggle(isOn: $contentFilter.isGalleryMode) {
          Label("Gallery mode", systemImage: "rectangle.grid.1x2")
        }
        .onChange(of: contentFilter.isGalleryMode) { _, newValue in 
           if newValue { 
               contentFilter.hidePostsWithMedia = false 
           }
        }
        
        Toggle(isOn: $contentFilter.hidePostsFromBots) {
          Label("timeline.filter.hide-posts-from-bots", systemImage: "poweroutlet.type.b")
        }
      }
      #if !os(visionOS)
        .listRowBackground(theme.primaryBackgroundColor)
      #endif

      Section {
        NavigationLink(destination: HideSeenPostsSettingsView()) {
          Label("settings.experimental.hide-seen-posts", systemImage: "eye.slash")
        }
      } footer: {
        Text("settings.content.hide-seen.footer")
      }
      #if !os(visionOS)
        .listRowBackground(theme.primaryBackgroundColor)
      #endif

      Section("Notifications") {
        Toggle(isOn: $userPreferences.notificationsTruncateStatusContent) {
          Text("Truncate status content")
        }
      }
      #if !os(visionOS)
        .listRowBackground(theme.primaryBackgroundColor)
      #endif
    }
    .navigationTitle("settings.content.navigation-title")
    #if !os(visionOS)
      .scrollContentBackground(.hidden)
      .background(theme.secondaryBackgroundColor)
    #endif
  }
}
