import DesignSystem
import Env
import SwiftUI

@MainActor
public struct NotificationsContentFilterView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(Theme.self) private var theme

  @State private var filter = NotificationsContentFilter.shared

  public init() {}

  public var body: some View {
    NavigationStack {
      Form {
        Section {
          Toggle(isOn: $filter.showFollow) { Label("notifications.type.follow", systemImage: "person.fill.badge.plus") }
          Toggle(isOn: $filter.showFollowRequest) { Label("notifications.type.follow-request", systemImage: "person.fill.badge.plus") }
          Toggle(isOn: $filter.showMention) { Label("notifications.type.mention", systemImage: "at") }
          Toggle(isOn: $filter.showReblog) { Label("notifications.type.reblog", systemImage: "arrow.2.squarepath") }
          Toggle(isOn: $filter.showStatus) { Label("notifications.type.status", systemImage: "bubble.right") }
          Toggle(isOn: $filter.showFavourite) { Label("notifications.type.favourite", systemImage: "star.fill") }
          Toggle(isOn: $filter.showPoll) { Label("notifications.type.poll", systemImage: "chart.bar") }
          Toggle(isOn: $filter.showUpdate) { Label("notifications.type.update", systemImage: "pencil") }
          Toggle(isOn: $filter.showQuote) { Label("notifications.type.quote", systemImage: "quote.opening") }
          Toggle(isOn: $filter.showQuotedUpdate) { Label("notifications.type.quoted-update", systemImage: "quote.opening") }
        }
      }
      .navigationTitle("notifications.content-filter.title")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("action.done") {
            dismiss()
          }
        }
      }
      #if !os(visionOS)
      .scrollContentBackground(.hidden)
      .background(theme.secondaryBackgroundColor)
      #endif
    }
  }
}
