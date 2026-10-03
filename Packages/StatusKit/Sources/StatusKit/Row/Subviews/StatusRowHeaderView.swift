import DesignSystem
import Env
import Models
import NetworkClient
import SwiftUI
import EmojiText

@MainActor
struct StatusRowHeaderView: View {
  @Environment(\.isInCaptureMode) private var isInCaptureMode
  @Environment(\.isStatusFocused) private var isFocused
  @Environment(\.redactionReasons) private var redactionReasons

  @Environment(Theme.self) private var theme

  let viewModel: StatusRowViewModel
  var body: some View {
    HStack(alignment: theme.avatarPosition == .top ? .center : .top) {
      accountView
        .hoverEffect()
        .accessibilityAddTraits(.isButton)
        .onTapGesture {
          viewModel.navigateToAccountDetail(account: viewModel.finalStatus.account)
        }
      Spacer()
      if !redactionReasons.contains(.placeholder) {
        dateView
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      Text(displayAccessibilityLabel)
    )
    .accessibilityAction {
      viewModel.navigateToAccountDetail(account: viewModel.finalStatus.account)
    }
  }

  @ViewBuilder
  private var accountView: some View {
    HStack(alignment: .center) {
      if theme.avatarPosition == .top {
        AvatarView(viewModel.displayAvatarURL)
          #if targetEnvironment(macCatalyst)
            .accountPopover(viewModel.finalStatus.account)
          #endif
      }
      VStack(alignment: .leading, spacing: 2) {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
          Group {
            EmojiTextApp(
              viewModel.displayDisplayName,
              emojis: viewModel.finalStatus.account.emojis
            )
            .fixedSize(horizontal: false, vertical: true)
            .font(.scaledSubheadline)
            .foregroundColor(theme.labelColor)
            .emojiText.size(Font.scaledSubheadlineFont.emojiSize)
            .emojiText.baselineOffset(Font.scaledSubheadlineFont.emojiBaselineOffset)
            .fontWeight(.semibold)
            .lineLimit(1)
            #if targetEnvironment(macCatalyst)
              .accountPopover(viewModel.finalStatus.account)
            #endif

            if !redactionReasons.contains(.placeholder) {
              if let badge = accountBadgeView {
                badge
                  .fixedSize(horizontal: false, vertical: true)
                  .font(.footnote)
              }
            }
          }
          .layoutPriority(1)
        }
        if !redactionReasons.contains(.placeholder) {
          if shouldShowFullUsername {
            Text(displayHandle)
            .fixedSize(horizontal: false, vertical: true)
            .font(.scaledFootnote)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            #if targetEnvironment(macCatalyst)
              .accountPopover(viewModel.finalStatus.account)
            #endif
          }
        }
      }
    }
  }
  
  private var shouldShowFullUsername: Bool {
    let isLeading = theme.avatarPosition == .leading
    let isTop = theme.avatarPosition == .top
    let showFull = theme.displayFullUsername
    if showFull && isLeading { return true }
    if isTop { return true }
    return false
  }

  private var displayAccessibilityLabel: String {
    var text = viewModel.finalStatus.account.safeDisplayName
    text.append(", ")
    text.append(viewModel.finalStatus.createdAt.relativeFormatted)
    return text
  }

  private var displayHandle: String {
    let handle = theme.displayFullUsername ? viewModel.finalStatus.account.acct : viewModel.finalStatus.account.username
    var text = "@"
    text.append(handle)
    return text
  }

  private var accountBadgeView: Text? {
    let statusToUse = viewModel.status.reblogAsAsStatus ?? viewModel.status
    let isBot = statusToUse.account.bot
    let isLocked = statusToUse.account.locked
    
    if isBot {
      return Text(Image(systemName: "poweroutlet.type.b.fill")) + Text(" ")
    } else if isLocked {
      return Text(Image(systemName: "lock.fill")) + Text(" ")
    }
    return nil
  }

  @ViewBuilder
  private var dateView: some View {
    if isInCaptureMode {
      Text(viewModel.finalStatus.createdAt.relativeFormatted)
        .fixedSize(horizontal: false, vertical: true)
        .font(.scaledFootnote)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    } else {
      HStack(spacing: 4) {
        Image(systemName: viewModel.finalStatus.visibility.iconName)
        Text("⸱")
        Text(viewModel.finalStatus.createdAt.relativeFormatted)
      }
      .fixedSize(horizontal: false, vertical: true)
      .font(.scaledFootnote)
      .foregroundStyle(.secondary)
      .lineLimit(1)
    }
  }
}
