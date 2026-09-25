import DesignSystem
import Env
import SwiftUI

@MainActor
struct CustomEmojisLayoutSettingsView: View {
  @Environment(Theme.self) private var theme
  @Environment(UserPreferences.self) private var preferences

  var body: some View {
    @Bindable var preferences = preferences
    Form {
      Section {
        Stepper(String(localized: "settings.display.custom-emojis-layout.portrait-row-limit") + ": \(preferences.customEmojisPortraitRows)", value: $preferences.customEmojisPortraitRows, in: 1...20)
        Stepper(String(localized: "settings.display.custom-emojis-layout.landscape-row-limit") + ": \(preferences.customEmojisLandscapeRows)", value: $preferences.customEmojisLandscapeRows, in: 1...20)
      }
    }
    .navigationTitle("settings.display.custom-emojis-layout")
    #if !os(visionOS)
      .scrollContentBackground(.hidden)
      .background(theme.secondaryBackgroundColor)
    #endif
  }
}
