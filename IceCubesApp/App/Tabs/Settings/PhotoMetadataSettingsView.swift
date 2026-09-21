import SwiftUI
import Env

public struct PhotoMetadataSettingsView: View {
  @Environment(UserPreferences.self) private var preferences

  public init() {}

  public var body: some View {
    Form {
      Section {
        Toggle("settings.content.media.embed-post-url", isOn: Bindable(preferences).embedPostUrlInMedia)
        Toggle("settings.content.media.embed-post-text", isOn: Bindable(preferences).embedPostTextInMedia)
        Toggle("settings.content.media.embed-post-tags", isOn: Bindable(preferences).embedPostTagsInMedia)
      } footer: {
        Text("settings.content.media.embed-metadata.footer")
      }
    }
    .navigationTitle("settings.content.media.embed-metadata.title")
    .navigationBarTitleDisplayMode(.inline)
  }
}
