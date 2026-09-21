import SwiftUI
import Env

public struct PhotoMetadataSettingsView: View {
  @Environment(UserPreferences.self) private var preferences

  public init() {}

  public var body: some View {
    @Bindable var bindablePreferences = preferences
    
    let isMasterEnabled = preferences.embedPostUrlInMedia || preferences.embedPostTextInMedia || preferences.embedPostTagsInMedia
    
    let masterBinding = Binding<Bool>(
      get: { isMasterEnabled },
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

    Form {
      Section {
        Toggle("settings.content.media.embed-master", isOn: masterBinding)
        
        if isMasterEnabled {
          Group {
            Toggle("settings.content.media.embed-post-url", isOn: $bindablePreferences.embedPostUrlInMedia)
            Toggle("settings.content.media.embed-post-text", isOn: $bindablePreferences.embedPostTextInMedia)
            Toggle("settings.content.media.embed-post-tags", isOn: $bindablePreferences.embedPostTagsInMedia)
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
