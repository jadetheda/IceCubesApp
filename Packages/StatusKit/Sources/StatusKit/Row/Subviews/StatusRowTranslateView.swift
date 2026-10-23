import DesignSystem
import Env
import Models
import SwiftUI

@MainActor
struct StatusRowTranslateView: View {
  @Environment(\.isInCaptureMode) private var isInCaptureMode: Bool
  @Environment(\.isCompact) private var isCompact: Bool

  @Environment(UserPreferences.self) private var preferences

  var viewModel: StatusRowViewModel

  private var shouldShowTranslateButton: Bool {
    let statusLang = viewModel.getStatusLang()

    if     let userLang = preferences.serverPreferences?.postLanguage,
    preferences.showTranslateButton,
    !viewModel.finalStatus.content.asRawText.isEmpty,
      viewModel.translation == nil
    {
      return userLang != statusLang
    } else {
      return false
    }
  }

  private func getLocalizedString(langCode: String, provider: String) -> String {
    if let localizedLanguage = Locale.current.localizedString(forLanguageCode: langCode) {
      let format = NSLocalizedString("status.action.translated-label-from-%@-%@", comment: "")
      return String.localizedStringWithFormat(format, localizedLanguage, provider)
    } else {
      return "status.action.translated-label-\(provider)"
    }
  }

  @ViewBuilder
  var translateButton: some View {
    if !isInCaptureMode,
      !isCompact,
      let userLang = preferences.serverPreferences?.postLanguage,
      shouldShowTranslateButton
    {
      Button {
        Task {
          await viewModel.translate(userLang: userLang)
        }
      } label: {
        if viewModel.isLoadingTranslation {
          ProgressView()
        } else {
          Text("status.action.translate")
        }
      }
      .buttonStyle(.borderless)
    }
  }

  @ViewBuilder
  var generalTranslateButton: some View {
    translateButton
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      generalTranslateButton
        .onChange(of: preferences.preferredTranslationType) { _, _ in
          withAnimation {
            viewModel.updatePreferredTranslation()
          }
        }

      if let translation = viewModel.translation {
        if !viewModel.isLoadingTranslation {
          if preferences.preferredTranslationType != .useApple {
            GroupBox {
              VStack(alignment: .leading, spacing: 4) {
                Text(translation.content.asSafeMarkdownAttributedString)
                  .font(.scaledBody)
                HStack {
                  Text(
                    getLocalizedString(
                      langCode: translation.detectedSourceLanguage, provider: translation.provider)
                  )
                  .font(.footnote)
                  .foregroundStyle(.secondary)
                  Spacer()
                  Button {
                    withAnimation {
                      viewModel.dismissTranslation()
                    }
                  } label: {
                    Image(systemName: "xmark")
                      .font(.footnote)
                      .foregroundStyle(.secondary)
                  }
                  .buttonStyle(.borderless)
                  .accessibilityLabel("status.show-less")
                }
              }
            }
            .fixedSize(horizontal: false, vertical: true)
          }
        }
      }
    }
    #if !os(visionOS)
    .onScrollVisibilityChange(threshold: 0.5) { visible in
      if visible {
        triggerAutoTranslate()
      } else {
        viewModel.cancelAutoTranslate()
      }
    }
    #endif
    .onAppear {
      triggerAutoTranslate()
    }
    .onDisappear {
      viewModel.cancelAutoTranslate()
    }
  }

  private func triggerAutoTranslate() {
    if !isInCaptureMode {
      if let userLang = preferences.serverPreferences?.postLanguage {
        viewModel.autoTranslateIfNeeded(userLang: userLang)
      }
    }
  }
}
