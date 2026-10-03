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

  func privateBoost() -> Bool {
    viewModel.status.visibility == .priv
      && viewModel.status.account.id == currentAccount.account?.id
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
    if viewModel.status.visibility == .direct { return true }
    if viewModel.status.visibility == .priv && viewModel.status.account.id != currentAccount.account?.id { return true }
    return false
  }

  @ViewBuilder
  private var trailingSwipeActions: some View {
    if preferences.swipeActionsStatusTrailingRight != StatusAction.none {
      if !viewModel.isRemote {
      makeSwipeButton(action: preferences.swipeActionsStatusTrailingRight)
        .tint(
          preferences.swipeActionsStatusTrailingRight.color(
            themeTintColor: theme.tintColor, useThemeColor: preferences.swipeActionsUseThemeColor,
            outside: true, actionFavoriteColor: theme.actionFavoriteColor, actionLikeColor: theme.actionLikeColor, actionBoostColor: theme.actionBoostColor, actionBookmarkColor: theme.actionBookmarkColor, isLikeAction: theme.actionIsLike))
      }
    }
    if preferences.swipeActionsStatusTrailingLeft != StatusAction.none {
      if !viewModel.isRemote {
      makeSwipeButton(action: preferences.swipeActionsStatusTrailingLeft)
        .tint(
          preferences.swipeActionsStatusTrailingLeft.color(
            themeTintColor: theme.tintColor, useThemeColor: preferences.swipeActionsUseThemeColor,
            outside: false, actionFavoriteColor: theme.actionFavoriteColor, actionLikeColor: theme.actionLikeColor, actionBoostColor: theme.actionBoostColor, actionBookmarkColor: theme.actionBookmarkColor, isLikeAction: theme.actionIsLike))
      }
    }
  }

  @ViewBuilder
  private var leadingSwipeActions: some View {
    if preferences.swipeActionsStatusLeadingLeft != StatusAction.none {
      if !viewModel.isRemote {
      makeSwipeButton(action: preferences.swipeActionsStatusLeadingLeft)
        .tint(
          preferences.swipeActionsStatusLeadingLeft.color(
            themeTintColor: theme.tintColor, useThemeColor: preferences.swipeActionsUseThemeColor,
            outside: true, actionFavoriteColor: theme.actionFavoriteColor, actionLikeColor: theme.actionLikeColor, actionBoostColor: theme.actionBoostColor, actionBookmarkColor: theme.actionBookmarkColor, isLikeAction: theme.actionIsLike))
      }
    }
    if preferences.swipeActionsStatusLeadingRight != StatusAction.none {
      if !viewModel.isRemote {
      makeSwipeButton(action: preferences.swipeActionsStatusLeadingRight)
        .tint(
          preferences.swipeActionsStatusLeadingRight.color(
            themeTintColor: theme.tintColor, useThemeColor: preferences.swipeActionsUseThemeColor,
            outside: false, actionFavoriteColor: theme.actionFavoriteColor, actionLikeColor: theme.actionLikeColor, actionBoostColor: theme.actionBoostColor, actionBookmarkColor: theme.actionBookmarkColor, isLikeAction: theme.actionIsLike))
      }
    }
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
        action: action, destination: .replyToStatusEditor(status: viewModel.status))
    case .quote:
      makeSwipeButtonForRouterPath(
        action: action, destination: .quoteStatusEditor(status: viewModel.status)
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

  @ViewBuilder
  private func makeSwipeLabel(
    action: StatusAction, style: UserPreferences.SwipeActionsIconStyle, privateBoost: Bool = false
  ) -> some View {
    switch style {
    case .iconOnly:
      Label(
        action.displayName(
          isReblogged: statusDataController.isReblogged,
          isFavorited: statusDataController.isFavorited,
          isBookmarked: statusDataController.isBookmarked,
          privateBoost: privateBoost, isLikeAction: theme.actionIsLike),
        imageNamed: action.iconName(
          isReblogged: statusDataController.isReblogged,
          isFavorited: statusDataController.isFavorited,
          isBookmarked: statusDataController.isBookmarked,
          privateBoost: privateBoost, isLikeAction: theme.actionIsLike)
      )
      .labelStyle(.iconOnly)
      .environment(\.symbolVariants, .none)
    case .iconWithText:
      Label(
        action.displayName(
          isReblogged: statusDataController.isReblogged,
          isFavorited: statusDataController.isFavorited,
          isBookmarked: statusDataController.isBookmarked,
          privateBoost: privateBoost, isLikeAction: theme.actionIsLike),
        imageNamed: action.iconName(
          isReblogged: statusDataController.isReblogged,
          isFavorited: statusDataController.isFavorited,
          isBookmarked: statusDataController.isBookmarked,
          privateBoost: privateBoost, isLikeAction: theme.actionIsLike)
      )
      .labelStyle(.titleAndIcon)
      .environment(\.symbolVariants, .none)
    }
  }
}
