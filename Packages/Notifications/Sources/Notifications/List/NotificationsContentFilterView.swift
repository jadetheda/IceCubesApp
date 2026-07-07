import DesignSystem
import Env
import Models
import SwiftUI

@MainActor
public struct NotificationsContentFilterView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(Theme.self) private var theme

  @State private var filter = NotificationsContentFilter.shared

  public init() {}

  private func binding(for type: Models.Notification.NotificationType) -> Binding<Bool> {
    switch type {
    case .follow: return $filter.showFollow
    case .follow_request: return $filter.showFollowRequest
    case .mention: return $filter.showMention
    case .reblog: return $filter.showReblog
    case .status: return $filter.showStatus
    case .favourite: return $filter.showFavourite
    case .poll: return $filter.showPoll
    case .update: return $filter.showUpdate
    case .quote: return $filter.showQuote
    case .quoted_update: return $filter.showQuotedUpdate
    }
  }

  public var body: some View {
    NavigationStack {
      Form {
        Section {
          ForEach(Models.Notification.NotificationType.allCases, id: \.self) { type in
            Toggle(isOn: binding(for: type)) {
              Label {
                Text(type.menuTitle())
              } icon: {
                type.icon(isPrivate: false)
              }
            }
          }
        }
      }
      .navigationTitle("notifications.content-filter.title")
      .navigationBarTitleDisplayMode(.inline)
      .scrollContentBackground(.hidden)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("action.done") {
            dismiss()
          }
        }
      }
    }
    .presentationDetents([.medium, .large])
  }
}
