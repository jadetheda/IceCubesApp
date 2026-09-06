import DesignSystem
import Env
import Models
import SwiftData
import SwiftUI
import Timeline

struct TagsGroupSettingView: View {
  @Environment(\.modelContext) private var context

  @Environment(RouterPath.self) private var routerPath
  @Environment(Theme.self) private var theme

  @Query(sort: \TagGroup.creationDate, order: .reverse) var tagGroups: [TagGroup]
  @AppStorage("timeline_pinned_filters") private var pinnedFilters: [TimelineFilter] = []

  var body: some View {
    Form {
      ForEach(tagGroups) { group in
        Label(group.title, systemImage: group.symbolName)
          .onTapGesture {
            routerPath.presentedSheet = .editTagGroup(tagGroup: group, onSaved: nil)
          }
      }
      .onDelete { indexes in
        if let index = indexes.first {
          let group = tagGroups[index]
          pinnedFilters.removeAll { filter in
            if case let .tagGroup(title, _, _) = filter {
              return title == group.title
            }
            return false
          }
          context.delete(group)
        }
      }
      #if !os(visionOS)
        .listRowBackground(theme.primaryBackgroundColor)
      #endif

      Button {
        routerPath.presentedSheet = .addTagGroup
      } label: {
        Label("timeline.filter.add-tag-groups", systemImage: "plus")
      }
      #if !os(visionOS)
        .listRowBackground(theme.primaryBackgroundColor)
      #endif
    }
    .navigationTitle("timeline.filter.tag-groups")
    .scrollContentBackground(.hidden)
    #if !os(visionOS)
      .background(theme.secondaryBackgroundColor)
    #endif
    .toolbar {
      EditButton()
    }
  }
}
