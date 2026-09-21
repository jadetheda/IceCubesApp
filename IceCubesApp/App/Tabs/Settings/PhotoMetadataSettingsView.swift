import SwiftUI
import Env

public struct PhotoMetadataSettingsView: View {
  @Environment(UserPreferences.self) private var preferences

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
    }
    .navigationTitle("settings.content.media.embed-metadata.title")
    .navigationBarTitleDisplayMode(.inline)
  }
}
