import DesignSystem
import Env
import Models
import Nuke
import NukeUI
import SwiftUI
import Foundation

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
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(Theme.self) private var theme
    @Environment(UserPreferences.self) private var preferences

    var store: EditorStore

    private let gridColumns = [GridItem(.adaptive(minimum: 40, maximum: 40), spacing: 9)]

    @State private var cachedEmojiMap: [String: Emoji] = [:]

    private var recentEmojis: [Emoji] {
      if !cachedEmojiMap.isEmpty {
        return preferences.recentlyUsedCustomEmojis.compactMap { cachedEmojiMap[$0] }
      }
      return []
    }

    private func addToRecents(_ emoji: Emoji) {
      var recents = preferences.recentlyUsedCustomEmojis
      if let index = recents.firstIndex(of: emoji.shortcode) {
        recents.remove(at: index)
      }
      recents.insert(emoji.shortcode, at: 0)
      if recents.count > 100 {
        recents.removeLast()
      }
      preferences.recentlyUsedCustomEmojis = recents
    }

    private func emojiView(_ emoji: Emoji) -> some View {
      let url = URL(string: emoji.url)
      return LazyImage(url: url) { (state: NukeUI.LazyImageState) in
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

    @ViewBuilder
    private func categoryPills(proxy: ScrollViewProxy) -> some View {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(store.customEmojiContainer) { (container: CategorizedEmojiContainer) in
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
    }

    private func recentEmojisSection(width: CGFloat) -> some View {
      let recents = recentEmojis
      let isLandscape = verticalSizeClass == .compact
      let rowCount = isLandscape ? 3 : 4
      let columns = max(1, Int((width + 9) / 49))
      let maxItems = columns * rowCount
      let displayRecents = Array(recents.prefix(maxItems))

      return Group {
        if !displayRecents.isEmpty {
          VStack(alignment: .leading, spacing: 0) {
            Text("status.editor.emojis.recent")
              .font(.scaledHeadline)
              .bold()
              .foregroundStyle(Color.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.horizontal, 16)
              .padding(.top, 16)

            LazyVGrid(columns: gridColumns, spacing: 9) {
              ForEach(displayRecents) { emoji in
                emojiView(emoji)
              }
            }
            .padding(.top, 8)
            .padding(.bottom, 16)
          }
        }
      }
    }

    @ViewBuilder
    private func containerSection(for container: CategorizedEmojiContainer) -> some View {
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
      }
    }

    @State private var gridWidth: CGFloat = 390

    var body: some View {
      NavigationStack {
        ScrollViewReader { (proxy: ScrollViewProxy) in
          ScrollView {
            VStack(alignment: .leading, spacing: 0) {
              recentEmojisSection(width: gridWidth)
              categoryPills(proxy: proxy)
              LazyVGrid(columns: gridColumns, spacing: 9) {
                ForEach(store.customEmojiContainer) { (container: CategorizedEmojiContainer) in
                  containerSection(for: container)
                }
              }
            }
            .background(
              GeometryReader { (geometry: GeometryProxy) in
                Color.clear.task(id: geometry.size.width) {
                  gridWidth = geometry.size.width
                }
              }
            )
          }
        }
        .toolbar {
          CancelToolbarItem()
        }
        .navigationTitle("status.editor.emojis.navigation-title")
        .navigationBarTitleDisplayMode(.inline)
      }
      .presentationDetents([.medium, .large])
      .task(id: store.customEmojiContainer) {
        var map: [String: Emoji] = [:]
        for container in store.customEmojiContainer {
          for emoji in container.emojis {
            if map[emoji.shortcode] == nil {
              map[emoji.shortcode] = emoji
            }
          }
        }
        cachedEmojiMap = map
      }
    }
  }
}
