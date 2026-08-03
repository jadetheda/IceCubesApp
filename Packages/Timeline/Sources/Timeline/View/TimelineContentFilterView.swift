import DesignSystem
import Env
import SwiftUI

@MainActor
public struct TimelineContentFilterView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(Theme.self) private var theme
  @Environment(CurrentInstance.self) private var currentInstance
  @Environment(RouterPath.self) private var routerPath

  @State private var contentFilter = TimelineContentFilter.shared
  @State private var isEditingFilters = false

  public init() {}

  public var body: some View {
    NavigationStack {
      Form {
        Section {
          Toggle(isOn: $contentFilter.showBoosts) {
            Label("timeline.filter.show-boosts", systemImage: "arrow.2.squarepath")
          }
          Toggle(isOn: $contentFilter.showReplies) {
            Label("timeline.filter.show-replies", systemImage: "bubble.left.and.bubble.right")
          }
          Toggle(isOn: $contentFilter.showThreads) {
            Label("timeline.filter.show-threads", systemImage: "bubble.left.and.text.bubble.right")
          }
          Toggle(isOn: $contentFilter.showQuotePosts) {
            Label("timeline.filter.show-quote", systemImage: "quote.bubble")
          }
        }
        if UserPreferences.shared.showLanguageFilters {
          Section("Language Text Post Filters") {
            NavigationLink(destination: TimelineLanguageFilterView()) {
              Label("Filtered Languages (Text Posts)", systemImage: "globe")
            }
          }
        }
        
        Section("Display Mode") {
            Toggle(isOn: Binding(
                get: { !contentFilter.hidePostsWithoutMedia },
                set: { contentFilter.hidePostsWithoutMedia = !$0 }
            )) {
              Label("Text posts", systemImage: "text.alignleft")
            }
            .disabled(contentFilter.isGalleryMode)
            Toggle(isOn: Binding(
                get: { !contentFilter.hidePostsWithMedia },
                set: { contentFilter.hidePostsWithMedia = !$0 }
            )) {
              Label("Media posts", systemImage: "photo")
            }
            Toggle(isOn: $contentFilter.isGalleryMode) {
              Label("Gallery mode", systemImage: "rectangle.grid.1x2")
            }
            .onChange(of: contentFilter.isGalleryMode) { _, newValue in
               if newValue {
                   contentFilter.hidePostsWithMedia = false
               }
            }
          }
        Section {
          if UserPreferences.shared.hideSeenPostsEnabled && UserPreferences.shared.hideSeenPostsIsToggle {
            Toggle(isOn: $contentFilter.hideReadPosts) {
              Label("Hide read posts", systemImage: "eye.slash")
            }
          }
          Toggle(isOn: $contentFilter.hideOwnPosts) {
            Label("Hide my own posts", systemImage: "person.crop.circle.badge.minus")
          }
        }

        Section {
          if currentInstance.isFiltersSupported {
            Button {
              routerPath.presentedSheet = .accountFiltersList
            } label: {
              Label("account.action.edit-filters", systemImage: "line.3.horizontal.decrease.circle")
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
          }
        }
      }
      .navigationTitle("timeline.content-filter.title")
      .navigationBarTitleDisplayMode(.inline)
      .scrollContentBackground(.hidden)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button {
            dismiss()
          } label: {
            Text("action.done").bold()
          }
        }
      }
    }
    .presentationDetents([.medium])
  }
}
