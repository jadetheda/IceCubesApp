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
  @AppStorage("timeline_hide_posts_without_media") var hidePostsWithoutMedia: Bool = false
  @AppStorage("timeline_hide_posts_with_media") var hidePostsWithMedia: Bool = false
  @AppStorage("timeline_hide_status_text") var hideStatusText: Bool = false
  @AppStorage("timeline_gallery_mode") var isGalleryMode: Bool = false

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
          if UserPreferences.shared.showHidePostsWithoutMediaToggle {
            Menu {
              Button {
                hidePostsWithoutMedia = false
                hidePostsWithMedia = false
                hideStatusText = false
                isGalleryMode = false
              } label: {
                let isActive = !hidePostsWithoutMedia && !hidePostsWithMedia && !hideStatusText && !isGalleryMode
                Label("Show all posts", systemImage: isActive ? "checkmark" : "")
              }
              Button {
                hidePostsWithoutMedia = true
                hidePostsWithMedia = false
                hideStatusText = false
                isGalleryMode = false
              } label: {
                let isActive = hidePostsWithoutMedia && !hideStatusText && !isGalleryMode
                Label("Only posts with media", systemImage: isActive ? "checkmark" : "")
              }
              Button {
                hidePostsWithoutMedia = true
                hidePostsWithMedia = false
                hideStatusText = true
                isGalleryMode = true
              } label: {
                let isActive = isGalleryMode
                Label("Gallery mode", systemImage: isActive ? "checkmark" : "")
              }
              Button {
                hidePostsWithoutMedia = false
                hidePostsWithMedia = true
                hideStatusText = false
                isGalleryMode = false
              } label: {
                let isActive = hidePostsWithMedia
                Label("Only text posts", systemImage: isActive ? "checkmark" : "")
              }
            } label: {
              Label("Display Mode", systemImage: "rectangle.grid.1x2")
            }
          } else {
            Toggle(isOn: $hidePostsWithMedia) {
              Label("timeline.filter.hide-posts-with-media", systemImage: "photo.on.rectangle.angled")
            }
          }
          if UserPreferences.shared.hideSeenPostsEnabled && UserPreferences.shared.hideSeenPostsIsToggle {
            Toggle(isOn: $contentFilter.hideReadPosts) {
              Label("Hide read posts", systemImage: "eye.slash")
            }
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
