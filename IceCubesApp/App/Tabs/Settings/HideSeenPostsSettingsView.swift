import SwiftUI
import Env
import DesignSystem

public struct HideSeenPostsSettingsView: View {
  @Environment(UserPreferences.self) private var preferences
  @Environment(Theme.self) private var theme

  public init() {}

  public var body: some View {
    @Bindable var preferences = preferences
    Form {
      Section {
        Toggle("settings.experimental.hide-seen-posts.enabled", isOn: $preferences.hideSeenPostsEnabled)
        
        if preferences.hideSeenPostsEnabled {
          VStack(alignment: .leading) {
            Text("settings.experimental.hide-seen-posts.threshold \(String(format: "%.1f", preferences.hideSeenPostsThreshold))s")
            Slider(value: $preferences.hideSeenPostsThreshold, in: 0.1...5.0, step: 0.1)
          }
          
          Toggle("settings.experimental.hide-seen-posts.liked-only", isOn: $preferences.hideSeenPostsLikedOnly)
          Toggle("settings.experimental.hide-seen-posts.require-media-loaded", isOn: $preferences.hideSeenPostsRequireMediaLoaded)
          Toggle("settings.experimental.hide-seen-posts.include-boosts", isOn: $preferences.hideSeenPostsIncludeBoosts)
          Toggle("settings.experimental.hide-seen-posts.show-in-header", isOn: $preferences.hideSeenPostsShowInHeader)
          Toggle("settings.experimental.hide-seen-posts.is-toggle", isOn: $preferences.hideSeenPostsIsToggle)
        }
      } header: {
        Text("settings.experimental.hide-seen-posts")
      }
    }
    .navigationTitle("settings.experimental.hide-seen-posts")
    .scrollContentBackground(.hidden)
    #if !os(visionOS)
    .background(theme.secondaryBackgroundColor)
    #endif
  }
}
