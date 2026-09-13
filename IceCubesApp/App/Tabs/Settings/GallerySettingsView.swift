import SwiftUI
import Env
import DesignSystem

@MainActor
struct GallerySettingsView: View {
  @Environment(UserPreferences.self) private var userPreferences
  @Environment(Theme.self) private var theme

  var body: some View {
    @Bindable var userPreferences = userPreferences
    Form {
      Section("settings.display.gallery.title") {
        Stepper(String(format: NSLocalizedString("settings.display.gallery.columns", comment: ""), userPreferences.galleryColumns), value: $userPreferences.galleryColumns, in: 2...4)
        Toggle(isOn: $userPreferences.galleryCropToSquare) {
          Label("settings.display.gallery.crop-square", systemImage: "crop")
        }
        Toggle(isOn: $userPreferences.galleryOptimizeItemLayout) {
          Label("settings.display.gallery.optimize-layout", systemImage: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
        }
        Toggle(isOn: $userPreferences.galleryRoundCorners) {
          Label("settings.display.gallery.round-corners", systemImage: "squareshape")
        }
        Toggle(isOn: $userPreferences.galleryAddThinMargins) {
          Label("settings.display.gallery.add-margins", systemImage: "arrow.left.and.right")
        }
      }
      #if !os(visionOS)
      .listRowBackground(theme.primaryBackgroundColor)
      #endif
    }
    .navigationTitle("settings.display.gallery.title")
    #if !os(visionOS)
    .scrollContentBackground(.hidden)
    .background(theme.secondaryBackgroundColor)
    #endif
  }
}
