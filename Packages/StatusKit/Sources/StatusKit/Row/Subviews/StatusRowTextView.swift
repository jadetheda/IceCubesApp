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

  @ViewBuilder
  private var inlineTranslationHeader: some View {
    if isInlineTranslationActive {
      HStack(spacing: 5) {
        Image(systemName: "translate")
          .font(.footnote)
          .foregroundStyle(.secondary)
        Text(translatedFromText)
          .font(.footnote)
          .foregroundStyle(.secondary)
        Button {
          withAnimation(.easeInOut(duration: 0.15)) {
            viewModel.showOriginalText.toggle()
          }
        } label: {
          Text(viewModel.showOriginalText ? "Show translation" : "Show original")
            .font(.footnote)
            .foregroundStyle(theme.tintColor)
        }
        .buttonStyle(.plain)
        Spacer()
        Button {
          withAnimation {
            viewModel.dismissTranslation()
          }
        } label: {
          Image(systemName: "xmark")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("status.show-less")
      }
      .padding(.bottom, 2)
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      inlineTranslationHeader
      HStack {
        EmojiTextApp(
          displayedContent,
          emojis: viewModel.finalStatus.emojis,
          language: viewModel.finalStatus.language,
          lineLimit: isNotificationsTab
            ? (userPreferences.notificationsTruncateStatusContent ? 2 : nil)
            : (viewModel.textDisabled ? 3 : viewModel.lineLimit)
        )
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
