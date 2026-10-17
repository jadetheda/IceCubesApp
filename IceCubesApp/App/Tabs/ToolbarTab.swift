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
        #if os(iOS) && !targetEnvironment(macCatalyst)
          if #available(iOS 27.1, *) {
            accountToolbarItem
              .axisBehavior(.verticalPreferred)
          } else {
            accountToolbarItem
          }
        #else
          accountToolbarItem
        #endif
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
      #elseif os(iOS)
        if #available(iOS 27.1, *) {
          accountSelector
            .modifier(ToolbarAvatarAlignment())
        } else {
          accountSelector
            .offset(x: -12)
        }
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

#if os(iOS) && !targetEnvironment(macCatalyst)
@available(iOS 27.1, *)
private struct ToolbarAvatarAlignment: ViewModifier {
  @Environment(\.toolbarVerticalEdge) private var toolbarVerticalEdge

  private var xOffset: CGFloat {
    toolbarVerticalEdge == nil ? -12 : 0
  }

  func body(content: Content) -> some View {
    // The horizontal bar's inset correction would shift the avatar off-center in a vertical bar.
    content.offset(x: xOffset)
  }
}
#endif
