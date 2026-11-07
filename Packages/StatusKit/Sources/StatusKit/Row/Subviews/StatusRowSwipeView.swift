import DesignSystem
import Env
import Models
import SwiftUI

@MainActor
struct StatusRowSwipeView: View {
  @Environment(\.openWindow) private var openWindow
  @Environment(Theme.self) private var theme
  @Environment(UserPreferences.self) private var preferences
  @Environment(CurrentAccount.self) private var currentAccount
  @Environment(StatusDataController.self) private var statusDataController

  enum Mode {
    case leading, trailing
  }

  private var targetStatus: Status {
    viewModel.status.reblogAsAsStatus ?? viewModel.status
  }

  func privateBoost() -> Bool {
    viewModel.finalStatus.visibility == .priv
      && viewModel.finalStatus.account.id == currentAccount.account?.id
  }

  var viewModel: StatusRowViewModel
  let mode: Mode

  var body: some View {
    switch mode {
    case .leading:
      leadingSwipeActions
    case .trailing:
      trailingSwipeActions
    }
  }

  private func isBoostDisabled() -> Bool {
    switch viewModel.finalStatus.visibility {
    case .pub:
      return false
    case .priv:
      return viewModel.finalStatus.account.id != currentAccount.account?.id
    case .unlisted, .direct:
      return true
    }
  }

  private func swipeTintColor(for action: StatusAction, outside: Bool) -> Color {
    action.color(
      themeTintColor: theme.tintColor,
      useThemeColor: preferences.swipeActionsUseThemeColor,
      outside: outside,
      actionFavoriteColor: theme.actionFavoriteColor,
      actionLikeColor: theme.actionLikeColor,
      actionBoostColor: theme.actionBoostColor,
      actionBookmarkColor: theme.actionBookmarkColor,
      isLikeAction: theme.actionIsLike
    )
  }

  @ViewBuilder
  private func configuredSwipeButton(action: StatusAction, outside: Bool) -> some View {
    if action != .none {
      if !viewModel.isRemote {
        makeSwipeButton(action: action)
          .tint(swipeTintColor(for: action, outside: outside))
      }
    }
  }

  @ViewBuilder
  private var trailingSwipeActions: some View {
    configuredSwipeButton(action: preferences.swipeActionsStatusTrailingRight, outside: true)
    configuredSwipeButton(action: preferences.swipeActionsStatusTrailingLeft, outside: false)
  }

  @ViewBuilder
  private var leadingSwipeActions: some View {
    configuredSwipeButton(action: preferences.swipeActionsStatusLeadingLeft, outside: true)
    configuredSwipeButton(action: preferences.swipeActionsStatusLeadingRight, outside: false)
  }

  private func isQuoteDisabled() -> Bool {
    let finalStatus = viewModel.finalStatus
    if finalStatus.visibility != .pub { return true }
    if finalStatus.quoteApproval?.currentUser == .denied { return true }
    return false
  }

  @ViewBuilder
  private func makeSwipeButton(action: StatusAction) -> some View {
    switch action {
    case .reply:
      makeSwipeButtonForRouterPath(
        action: action, destination: .replyToStatusEditor(status: targetStatus))
    case .quote:
      makeSwipeButtonForRouterPath(
        action: action, destination: .quoteStatusEditor(status: targetStatus)
      )
      .disabled(isQuoteDisabled())
    case .favorite:
      makeSwipeButtonForTask(action: action) {
        await statusDataController.toggleFavorite(remoteStatus: nil)
      }
    case .boost:
      makeSwipeButtonForTask(action: action, privateBoost: privateBoost()) {
        await statusDataController.toggleReblog(remoteStatus: nil)
      }
      .disabled(isBoostDisabled())
    case .bookmark:
      makeSwipeButtonForTask(action: action) {
        await statusDataController.toggleBookmark(remoteStatus: nil)
      }
    case .none:
      EmptyView()
    }
  }

  @ViewBuilder
  private func makeSwipeButtonForRouterPath(action: StatusAction, destination: SheetDestination)
    -> some View
  {
    Button {
      HapticManager.shared.fireHaptic(.notification(.success))
      #if targetEnvironment(macCatalyst) || os(visionOS)
        switch destination {
        case .replyToStatusEditor(let status):
          openWindow(value: WindowDestinationEditor.replyToStatusEditor(status: status))
        case .quoteStatusEditor(let status):
          openWindow(value: WindowDestinationEditor.quoteStatusEditor(status: status))
        default:
          viewModel.routerPath.presentedSheet = destination
        }
      #else
        viewModel.routerPath.presentedSheet = destination
      #endif
    } label: {
      makeSwipeLabel(action: action, style: preferences.swipeActionsIconStyle)
    }
  }

  @ViewBuilder
  private func makeSwipeButtonForTask(
    action: StatusAction, privateBoost: Bool = false, task: @escaping () async -> Void
  ) -> some View {
    Button {
      Task {
        HapticManager.shared.fireHaptic(.notification(.success))
        await task()
      }
    } label: {
      makeSwipeLabel(
        action: action, style: preferences.swipeActionsIconStyle, privateBoost: privateBoost)
    }
  }

  private func swipeLabelTitle(for action: StatusAction, privateBoost: Bool) -> LocalizedStringKey {
    action.displayName(
      isReblogged: statusDataController.isReblogged,
      isFavorited: statusDataController.isFavorited,
      isBookmarked: statusDataController.isBookmarked,
      privateBoost: privateBoost,
      isLikeAction: theme.actionIsLike
    )
  }

  private func swipeLabelIcon(for action: StatusAction, privateBoost: Bool) -> String {
    action.iconName(
      isReblogged: statusDataController.isReblogged,
      isFavorited: statusDataController.isFavorited,
      isBookmarked: statusDataController.isBookmarked,
      privateBoost: privateBoost,
      isLikeAction: theme.actionIsLike
    )
  }

  @ViewBuilder
  private func makeSwipeLabel(
    action: StatusAction, style: UserPreferences.SwipeActionsIconStyle, privateBoost: Bool = false
  ) -> some View {
    switch style {
    case .iconOnly:
      Label(
        swipeLabelTitle(for: action, privateBoost: privateBoost),
        imageNamed: swipeLabelIcon(for: action, privateBoost: privateBoost)
      )
      .labelStyle(.iconOnly)
      .environment(\.symbolVariants, .none)
    case .iconWithText:
      Label(
        swipeLabelTitle(for: action, privateBoost: privateBoost),
        imageNamed: swipeLabelIcon(for: action, privateBoost: privateBoost)
      )
      .labelStyle(.titleAndIcon)
      .environment(\.symbolVariants, .none)
    }
  }
}
