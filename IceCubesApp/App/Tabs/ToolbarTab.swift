import AppAccount
import DesignSystem
import Env
import SwiftUI

@MainActor
struct ToolbarTab: ToolbarContent {
  @Environment(\.isSecondaryColumn) private var isSecondaryColumn: Bool
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  @Environment(UserPreferences.self) private var userPreferences

  @Binding var routerPath: RouterPath
  var isListsTab: Bool = false
  
  @Namespace private var transition

  var body: some ToolbarContent {
    if !isSecondaryColumn {
      if isListsTab {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button {
            routerPath.presentedSheet = .listCreate
          } label: {
            Image(systemName: "plus")
              .accessibilityLabel("Add List")
          }
          .tint(.label)
        }
      } else {
        statusEditorToolbarItem(
          routerPath: routerPath,
          visibility: userPreferences.postVisibility)
      }
      if #available(iOS 26.0, *) {
        accountToolbarItem
      } else {
        ToolbarItem(placement: .navigationBarLeading) {
          accountSelector
        }
      }
    }
    if shouldShowSecondaryColumnItem {
      SecondaryColumnToolbarItem()
    }
  }

  private var shouldShowSecondaryColumnItem: Bool {
    let isPad = UIDevice.current.userInterfaceIdiom == .pad
    let isRegular = horizontalSizeClass == .regular
    guard isPad && isRegular else { return false }
    return isSecondaryColumn || !userPreferences.showiPadSecondaryColumn
  }

  @available(iOS 26.0, *)
  private var accountToolbarItem: some ToolbarContent {
    ToolbarItem(placement: .navigationBarLeading) {
      #if targetEnvironment(macCatalyst)
        accountSelector
      #else
        accountSelector
          .offset(x: -12)
      #endif
    }
    .matchedTransitionSource(id: CurrentAccount.shared.account?.id ?? "", in: transition)
    .sharedBackgroundVisibility(.hidden)
  }

  private var accountSelector: some View {
    AppAccountsSelectorView(
      transition: transition,
      routerPath: routerPath,
      avatarConfig: .embed)
      #if targetEnvironment(macCatalyst)
        .buttonStyle(.plain)
      #endif
  }
}
