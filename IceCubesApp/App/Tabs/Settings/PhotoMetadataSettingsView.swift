import SwiftUI
import Env

public struct PhotoMetadataSettingsView: View {
  @Environment(UserPreferences.self) private var preferences

  public init() {}

  private var masterBinding: Binding<Bool> {
    Binding<Bool>(
      get: {
        preferences.embedPostUrlInMedia || preferences.embedPostTextInMedia || preferences.embedPostTagsInMedia
      },
      set: { newValue in
        withAnimation {
          if newValue {
            if !preferences.embedPostUrlInMedia && !preferences.embedPostTextInMedia && !preferences.embedPostTagsInMedia {
              preferences.embedPostUrlInMedia = true
            }
          } else {
            preferences.embedPostUrlInMedia = false
            preferences.embedPostTextInMedia = false
            preferences.embedPostTagsInMedia = false
          }
        }
      }
    )
  }

  public var body: some View {
    Form {
      Section {
        Toggle("settings.content.media.embed-master", isOn: masterBinding)
        
        if masterBinding.wrappedValue {
          Group {
            Toggle("settings.content.media.embed-post-url", isOn: Bindable(preferences).embedPostUrlInMedia)
            Toggle("settings.content.media.embed-post-text", isOn: Bindable(preferences).embedPostTextInMedia)
            Toggle("settings.content.media.embed-post-tags", isOn: Bindable(preferences).embedPostTagsInMedia)
          }
          .padding(.leading, 16)
        }
      } footer: {
        Text("settings.content.media.embed-metadata.footer")
      }
    }
    .navigationTitle("settings.content.media.embed-metadata.title")
    .navigationBarTitleDisplayMode(.inline)
  }
}
