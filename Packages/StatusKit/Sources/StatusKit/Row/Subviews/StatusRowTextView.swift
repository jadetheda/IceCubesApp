import DesignSystem
import Env
import Models
import SwiftUI

@MainActor
struct StatusRowTextView: View {
  @Environment(Theme.self) private var theme
  @Environment(\.isStatusFocused) private var isFocused
  @Environment(UserPreferences.self) private var userPreferences
  @Environment(\.isNotificationsTab) private var isNotificationsTab

  @Environment(StatusDataController.self) private var statusDataController

  var viewModel: StatusRowViewModel

  private var isInlineTranslationActive: Bool {
    if userPreferences.translationDisplayStyle == .inline {
      if viewModel.translation != nil {
        if !viewModel.isLoadingTranslation {
          return true
        }
      }
    }
    return false
  }

  private var displayedContent: HTMLString {
    if isInlineTranslationActive {
      if !viewModel.showOriginalText {
        if let translatedContent = viewModel.translation?.content {
          return translatedContent
        }
      }
    }
    return statusDataController.content
  }

  private var displayedLanguage: String? {
    if isInlineTranslationActive {
      if !viewModel.showOriginalText {
        if let targetLang = userPreferences.serverPreferences?.postLanguage {
          return targetLang
        }
        return Locale.current.language.languageCode?.identifier
      }
    }
    return viewModel.finalStatus.language
  }

  private var translatedFromText: String {
    guard let translation = viewModel.translation else { return "" }
    let rawLang = translation.detectedSourceLanguage.isEmpty ? (viewModel.getStatusLang() ?? "") : translation.detectedSourceLanguage
    if let localizedName = Locale.current.localizedString(forLanguageCode: rawLang) {
      let format = NSLocalizedString("status.action.translated-from-%@", comment: "")
      if format != "status.action.translated-from-%@" {
        return String.localizedStringWithFormat(format, localizedName)
      } else {
        return "Translated from \(localizedName)"
      }
    } else if !rawLang.isEmpty {
      return "Translated from \(rawLang)"
    } else {
      return "Translated"
    }
  }

  private var showOriginalToggleTitle: String {
    if viewModel.showOriginalText {
      let localized = NSLocalizedString("status.action.show-translation", comment: "")
      if localized != "status.action.show-translation" {
        return localized
      }
      return "Show translation"
    } else {
      let localized = NSLocalizedString("status.action.show-original", comment: "")
      if localized != "status.action.show-original" {
        return localized
      }
      return "Show original"
    }
  }

  @ViewBuilder
  private var inlineTranslationHeader: some View {
    if isInlineTranslationActive {
      HStack(alignment: .center, spacing: 5) {
        Image(systemName: "translate")
          .font(.footnote)
          .foregroundStyle(.secondary)
        Text(translatedFromText)
          .font(.footnote)
          .foregroundStyle(.secondary)
          .lineLimit(1)
        Button {
          withAnimation(.easeInOut(duration: 0.15)) {
            viewModel.showOriginalText.toggle()
          }
        } label: {
          Text(showOriginalToggleTitle)
            .font(.footnote)
            .foregroundStyle(theme.tintColor)
        }
        .buttonStyle(.plain)
        .layoutPriority(1)
        .fixedSize(horizontal: true, vertical: false)
        Spacer()
      }
      .padding(.bottom, 2)
      .accessibilityElement(children: .combine)
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      inlineTranslationHeader
      HStack {
        EmojiTextApp(
          displayedContent,
          emojis: viewModel.finalStatus.emojis,
          language: displayedLanguage,
          lineLimit: isNotificationsTab
            ? (userPreferences.notificationsTruncateStatusContent ? 2 : nil)
            : (viewModel.textDisabled ? 3 : viewModel.lineLimit)
        )
        .contentTransition(.opacity)
        .animation(.easeInOut(duration: 0.15), value: viewModel.showOriginalText)
        .fixedSize(horizontal: false, vertical: true)
        .font(isFocused ? .scaledBodyFocused : .scaledBody)
        .lineSpacing(CGFloat(theme.lineSpacing))
        .foregroundColor(viewModel.textDisabled ? .gray : theme.labelColor)
        .emojiText.size(
          isFocused ? Font.scaledBodyFocusedFont.emojiSize : Font.scaledBodyFont.emojiSize
        )
        .emojiText.baselineOffset(
          isFocused
            ? Font.scaledBodyFocusedFont.emojiBaselineOffset
            : Font.scaledBodyFont.emojiBaselineOffset
        )
        .environment(
          \.openURL,
          OpenURLAction { url in
            viewModel.routerPath.handleStatus(status: viewModel.finalStatus, url: url)
          })
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      makeCollapseButton()
    }
  }

  @ViewBuilder
  func makeCollapseButton() -> some View {
    if viewModel.lineLimit != nil {
      HStack(alignment: .top) {
        Text("status.show-full-post")
          .font(.system(.subheadline, weight: .bold))
          .foregroundColor(.secondary)
        Spacer()
        Button {
          withAnimation {
            viewModel.isCollapsed.toggle()
          }
        } label: {
          Image(systemName: "chevron.down")
        }
        .buttonStyle(.bordered)
        .accessibility(label: Text("status.show-full-post"))
        .accessibilityHidden(true)
      }
      .contentShape(Rectangle())
      .onTapGesture {  // make whole row tapable to make up for smaller button size
        withAnimation {
          viewModel.isCollapsed.toggle()
        }
      }
    }
  }
}
