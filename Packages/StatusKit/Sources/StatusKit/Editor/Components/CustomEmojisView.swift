import DesignSystem
import Env
import Models
import Nuke
import NukeUI
import SwiftUI

extension StatusEditor {
  @MainActor
  struct CustomEmojisView: View {
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
    @Environment(UserPreferences.self) private var preferences

    var store: EditorStore

    private var recentEmojis: [Emoji] {
      let allEmojis = store.customEmojiContainer.flatMap { $0.emojis }
      return preferences.recentlyUsedCustomEmojis.compactMap { shortcode in
        allEmojis.first(where: { $0.shortcode == shortcode })
      }
    }

    private func addToRecents(_ emoji: Emoji) {
      var recents = preferences.recentlyUsedCustomEmojis
      if let index = recents.firstIndex(of: emoji.shortcode) {
        recents.remove(at: index)
      }
      recents.insert(emoji.shortcode, at: 0)
      if recents.count > 16 {
        recents.removeLast()
      }
      preferences.recentlyUsedCustomEmojis = recents
    }

    private func emojiView(_ emoji: Emoji) -> some View {
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
        addToRecents(emoji)
      }
    }

    var body: some View {
      NavigationStack {
        ScrollViewReader { proxy in
          ScrollView {
            VStack(alignment: .leading, spacing: 0) {
              
              if !recentEmojis.isEmpty {
                Text("status.editor.emojis.recent")
                  .font(.scaledHeadline)
                  .bold()
                  .foregroundStyle(Color.secondary)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .padding(.horizontal, 16)
                  .padding(.top, 16)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 40, maximum: 40))], spacing: 9) {
                  ForEach(recentEmojis) { emoji in
                    emojiView(emoji)
                  }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
              }

              ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                  ForEach(store.customEmojiContainer) { container in
                    Button {
                      withAnimation {
                        proxy.scrollTo(container.id, anchor: .top)
                      }
                    } label: {
                      Text(container.categoryName)
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(theme.secondaryBackgroundColor)
                        .cornerRadius(16)
                        .foregroundStyle(theme.labelColor)
                    }
                  }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
              }
              .padding(.bottom, 8)

              LazyVGrid(columns: [GridItem(.adaptive(minimum: 40, maximum: 40))], spacing: 9) {
                ForEach(store.customEmojiContainer) { container in
                  Section {
                    ForEach(container.emojis) { emoji in
                      emojiView(emoji)
                    }
                  } header: {
                    Text(container.categoryName)
                      .font(.scaledHeadline)
                      .bold()
                      .foregroundStyle(Color.secondary)
                      .frame(maxWidth: .infinity, alignment: .leading)
                      .padding(.horizontal, 16)
                      .id(container.id)
                  }
                }
              }
            }
          }
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