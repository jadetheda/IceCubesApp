import DesignSystem
import Env
import Models
import Nuke
import NukeUI
import SwiftUI

extension StatusEditor {
  @MainActor
  struct CustomEmojisView: View {
    // Isolated pipeline just for custom emojis
    @State private var emojiPipeline: ImagePipeline = {
      var config = ImagePipeline.Configuration.withDataCache
      if !UserPreferences.shared.cacheServerEmotes {
        config.dataCache = nil
        config.imageCache = nil
      }
      return ImagePipeline(configuration: config)
    }()

    @Environment(\.dismiss) private var dismiss
    @Environment(Theme.self) private var theme

    var store: EditorStore

    var body: some View {
      NavigationStack {
        ScrollView {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 40, maximum: 40))], spacing: 9) {
            ForEach(store.customEmojiContainer) { container in
              Section {
                ForEach(container.emojis) { emoji in
                  LazyImage(url: URL(string: emoji.url)) { state in
                    if let image = state.image {
                      image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .accessibilityLabel(
                          emoji.shortcode.replacingOccurrences(of: "_", with: " ")
                        )
                        .accessibilityAddTraits(.isButton)
                    } else if state.isLoading {
                      Rectangle()
                        .fill(Color.gray)
                        .accessibility(hidden: true)
                    }
                  }
                  .pipeline(emojiPipeline)
                  .frame(width: 40, height: 40)
                  .onTapGesture {
                    store.insertStatusText(text: " :\(emoji.shortcode): ")
                  }
                }
              } header: {
                Text(container.categoryName)
                  .font(.scaledHeadline)
                  .bold()
                  .foregroundStyle(Color.secondary)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .padding(.vertical, 8)
              }
            }
          }
          .padding(.horizontal, 16)
        }
        .toolbar {
          CancelToolbarItem()
        }
        .navigationTitle("status.editor.emojis.navigation-title")
        .navigationBarTitleDisplayMode(.inline)
      }
      .presentationDetents([.medium, .large])
    }
  }
}
