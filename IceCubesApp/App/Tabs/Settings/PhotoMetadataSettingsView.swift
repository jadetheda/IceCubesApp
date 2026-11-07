import SwiftUI
import Env
import DesignSystem

public struct PhotoMetadataSettingsView: View {
  @Environment(UserPreferences.self) private var preferences
  @Environment(Theme.self) private var theme

  public init() {}

  public var body: some View {
    @Bindable var bindablePreferences = preferences
    Form {
      Section {
        Toggle("settings.content.media.embed-post-url", isOn: $bindablePreferences.embedPostUrlInMedia)
        Toggle("settings.content.media.embed-post-text", isOn: $bindablePreferences.embedPostTextInMedia)
        Toggle("settings.content.media.embed-post-tags", isOn: $bindablePreferences.embedPostTagsInMedia)
      } footer: {
        Text("settings.content.media.embed-metadata.footer")
      }
      #if !os(visionOS)
      .listRowBackground(theme.primaryBackgroundColor)
      #endif
    }
    .navigationTitle("settings.content.media.embed-metadata.title")
    .navigationBarTitleDisplayMode(.inline)
    #if !os(visionOS)
    .scrollContentBackground(.hidden)
    .background(theme.secondaryBackgroundColor)
    #endif
  }
}
