import DesignSystem
import Env
import SwiftUI

@MainActor
public struct AppAccountsSelectorView: View {
  @Environment(UserPreferences.self) private var preferences
  @Environment(CurrentAccount.self) private var currentAccount
  @Environment(AppAccountsManager.self) private var appAccounts
  @Environment(Theme.self) private var theme

  var routerPath: RouterPath

  @State private var accountsViewModel: [AppAccountViewModel] = []
  @State private var isPresented: Bool = false

  private let accountCreationEnabled: Bool
  private let avatarConfig: AvatarView.FrameConfig

  private let transition: Namespace.ID

  private var showNotificationBadge: Bool {
    accountsViewModel
      .filter { $0.account?.id != currentAccount.account?.id }
      .compactMap(\.appAccount.oauthToken)
      .map { preferences.notificationsCount[$0] ?? 0 }
      .reduce(0, +) > 0
  }

  private var preferredHeight: CGFloat {
    var baseHeight: CGFloat = 360
    baseHeight += CGFloat(60 * accountsViewModel.count)
    return baseHeight
  }

  public init(
    transition: Namespace.ID,
    routerPath: RouterPath,
    accountCreationEnabled: Bool = true,
    avatarConfig: AvatarView.FrameConfig? = nil
  ) {
    self.transition = transition
    self.routerPath = routerPath
    self.accountCreationEnabled = accountCreationEnabled
    self.avatarConfig = avatarConfig ?? .badge
  }

  public var body: some View {
    Button {
      isPresented.toggle()
      HapticManager.shared.fireHaptic(.buttonPress)
    } label: {
      labelView
        .contentShape(.circle)
    }
    .highPriorityGesture(TapGesture(count: 2).onEnded {
      appAccounts.switchToPreviousAccount()
      HapticManager.shared.fireHaptic(.buttonPress)
    })
    .contextMenu {
      ForEach(accountsViewModel.sorted { $0.acct < $1.acct }, id: \.appAccount.id) {
        viewModel in
        Button {
          appAccounts.currentAccount = viewModel.appAccount
        } label: {
          if appAccounts.currentAccount.id == viewModel.appAccount.id {
            Label(viewModel.appAccount.server, systemImage: "checkmark.circle.fill")
              .foregroundStyle(.primary)
            Text(viewModel.acct)
          } else {
            Text(viewModel.appAccount.server)
            Text(viewModel.acct)
          }
        }
        .tint(.primary)
      }
    }
    .sheet(
      isPresented: $isPresented,
      content: {
        if #available(iOS 26, *) {
          accountsView
            .presentationDetents([.height(preferredHeight), .large])
            .navigationTransition(
              .zoom(sourceID: CurrentAccount.shared.account?.id ?? "", in: transition)
            )
            .onAppear {
              refreshAccounts()
            }
        } else {
          accountsView.presentationDetents([.height(preferredHeight), .large])
            .presentationBackground(.ultraThinMaterial)
            .presentationCornerRadius(16)
            .onAppear {
              refreshAccounts()
            }
        }
      }
    )
    .onChange(of: currentAccount.account?.id) {
      refreshAccounts()
    }
    .onAppear {
      refreshAccounts()
    }
    .accessibilityRepresentation {
      Menu("accessibility.app-account.selector.accounts") {}
        .accessibilityHint("accessibility.app-account.selector.accounts.hint")
        .accessibilityRemoveTraits(.isButton)
    }
  }

  private var shouldShowBadgeDot: Bool {
    accountCreationEnabled && (!currentAccount.followRequests.isEmpty || showNotificationBadge)
  }

  @ViewBuilder
  private var labelView: some View {
    Group {
      if let account = currentAccount.account {
        if !currentAccount.isLoadingAccount {
          AvatarView(account.avatar, config: avatarConfig)
        } else {
          placeholderAvatarView
        }
      } else {
        placeholderAvatarView
      }
    }.overlay(alignment: .topTrailing) {
      if shouldShowBadgeDot {
        Circle()
          .fill(Color.red)
          .frame(width: 9, height: 9)
      }
    }
  }

  private var placeholderAvatarView: some View {
    AvatarView(config: avatarConfig)
      .redacted(reason: .placeholder)
      .allowsHitTesting(false)
  }

  private var accountsView: some View {
    NavigationStack {
      List {
        Section {
          ForEach(accountsViewModel.sorted { $0.acct < $1.acct }, id: \.appAccount.id) {
            viewModel in
            AppAccountView(viewModel: viewModel, isParentPresented: $isPresented)
          }
          sheetNavigationButton("app-account.button.add", systemImage: "person.badge.plus", sheet: .addAccount)
            .foregroundStyle(theme.labelColor)
        }
        #if !os(visionOS)
          .listRowBackground(theme.secondaryBackgroundColor)
        #endif

        if accountCreationEnabled {
          Section {
            sheetNavigationButton("tab.settings", systemImage: "gear", sheet: .settings)
            sheetNavigationButton("settings.app.about", systemImage: "info.circle", sheet: .about)
            sheetNavigationButton("settings.app.support", systemImage: "wand.and.stars", sheet: .support)
          }
          #if os(visionOS)
            .foregroundStyle(theme.labelColor)
          #else
            .foregroundStyle(theme.labelColor)
            .listRowBackground(theme.secondaryBackgroundColor)
          #endif
        }
      }
      .listStyle(.insetGrouped)
      .scrollContentBackground(.hidden)
      .navigationTitle("settings.section.accounts")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          if #available(iOS 26.0, *) {
            Button {
              isPresented.toggle()
            } label: {
              Text("action.done").bold()
            }
            .buttonStyle(.glass)
          } else {
            Button {
              isPresented.toggle()
            } label: {
              Text("action.done").bold()
            }
          }
        }
      }
      .environment(routerPath)
    }
  }

  private func sheetNavigationButton(
    _ title: LocalizedStringKey,
    systemImage: String,
    sheet: SheetDestination
  ) -> some View {
    Button {
      isPresented = false
      HapticManager.shared.fireHaptic(.buttonPress)
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        routerPath.presentedSheet = sheet
      }
    } label: {
      Label(title, systemImage: systemImage)
    }
  }

  private func refreshAccounts() {
    accountsViewModel = appAccounts.availableAccounts.map {
      AppAccountViewModel(appAccount: $0, isInSettings: false, showBadge: true)
    }
  }
}
