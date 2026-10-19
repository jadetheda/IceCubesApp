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

    private let gridColumns = [GridItem(.adaptive(minimum: 40, maximum: 40))]

    @State private var cachedEmojiMap: [String: Emoji] = [:]
    @State private var allEmojis: [Emoji] = []
    @State private var searchText: String = ""
    @State private var isSearchPresented: Bool = false
    @State private var selectedDetent: PresentationDetent = .medium

    private var recentEmojis: [Emoji] {
      if !cachedEmojiMap.isEmpty {
        return preferences.recentlyUsedCustomEmojis.compactMap { cachedEmojiMap[$0] }
      }
      return []
    }

    private var emojisToSearch: [Emoji] {
      if !allEmojis.isEmpty {
        return allEmojis
      }
      var all: [Emoji] = []
      var seen: Set<String> = []
      for container in store.customEmojiContainer {
        for emoji in container.emojis {
          if !seen.contains(emoji.shortcode) {
            seen.insert(emoji.shortcode)
            all.append(emoji)
          }
        }
      }
      return all
    }

    private var filteredEmojis: [Emoji] {
      let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      let stripped = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
      if stripped.isEmpty {
        return []
      }
      let queryWithUnderscores = stripped.replacingOccurrences(of: " ", with: "_")
      return emojisToSearch.filter { emoji in
        let code = emoji.shortcode.lowercased()
        if code.contains(stripped) {
          return true
        }
        if code.contains(queryWithUnderscores) {
          return true
        }
        if let category = emoji.category?.lowercased() {
          if category.contains(stripped) {
            return true
          }
        }
        return false
      }
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
      let rowCount = isLandscape ? preferences.customEmojisLandscapeRows : preferences.customEmojisPortraitRows
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
      VStack(alignment: .leading, spacing: 0) {
        Text(container.categoryName)
          .font(.scaledHeadline)
          .bold()
          .foregroundStyle(Color.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 16)
          .padding(.top, 16)
        LazyVGrid(columns: gridColumns, spacing: 9) {
          ForEach(container.emojis) { emoji in
            emojiView(emoji)
          }
        }
        .padding(.top, 8)
      }
      .id(container.id)
    }

    @State private var scrollProxy: ScrollViewProxy?
    @State private var gridWidth: CGFloat = 390

    @ViewBuilder
    private var searchResultsSection: some View {
      if filteredEmojis.isEmpty {
        VStack(spacing: 12) {
          Image(systemName: "magnifyingglass")
            .font(.system(size: 32))
            .foregroundStyle(Color.secondary)
          Text("status.editor.emojis.no-results")
            .font(.scaledHeadline)
            .foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
      } else {
        VStack(alignment: .leading, spacing: 0) {
          LazyVGrid(columns: gridColumns, spacing: 9) {
            ForEach(filteredEmojis) { emoji in
              emojiView(emoji)
            }
          }
          .padding(.top, 8)
          .padding(.bottom, 16)
        }
      }
    }

    @ViewBuilder
    private func normalContent(proxy: ScrollViewProxy) -> some View {
      VStack(alignment: .leading, spacing: 0) {
        recentEmojisSection(width: gridWidth)
        VStack(spacing: 0) {
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
      .onAppear {
        scrollProxy = proxy
      }
    }

    var body: some View {
      NavigationStack {
        VStack(alignment: .leading, spacing: 0) {
          if searchText.isEmpty {
            if let proxy = scrollProxy {
              categoryPills(proxy: proxy)
            }
          }
          ScrollView {
            ScrollViewReader { (proxy: ScrollViewProxy) in
              if searchText.isEmpty {
                normalContent(proxy: proxy)
              } else {
                searchResultsSection
              }
            }
          }
          .scrollDismissesKeyboard(.interactively)
        }
        .searchable(
          text: $searchText,
          isPresented: $isSearchPresented,
          placement: .navigationBarDrawer(displayMode: .always),
          prompt: Text("status.editor.emojis.search-placeholder")
        )
        .toolbar {
          CancelToolbarItem()
        }
        .navigationTitle("status.editor.emojis.navigation-title")
        .navigationBarTitleDisplayMode(.inline)
      }
      .presentationDetents([.medium, .large], selection: $selectedDetent)
      .onChange(of: isSearchPresented) { _, isSearching in
        if isSearching {
          selectedDetent = .large
        }
      }
      .onChange(of: searchText) { _, newValue in
        if !newValue.isEmpty {
          selectedDetent = .large
        }
      }
      .task(id: store.customEmojiContainer) {
        var map: [String: Emoji] = [:]
        var all: [Emoji] = []
        for container in store.customEmojiContainer {
          for emoji in container.emojis {
            if map[emoji.shortcode] == nil {
              map[emoji.shortcode] = emoji
              all.append(emoji)
            }
          }
        }
        cachedEmojiMap = map
        allEmojis = all
      }
    }
  }
}
