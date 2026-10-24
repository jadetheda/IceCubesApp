import DesignSystem
import Env
import Models
import SwiftUI
#if canImport(Translation) && !os(visionOS) && !targetEnvironment(macCatalyst)
@preconcurrency import Translation

extension TranslationSession: @unchecked @retroactive Sendable {}
#endif

@MainActor
struct StatusRowTranslateView: View {
  @Environment(\.isInCaptureMode) private var isInCaptureMode: Bool
  @Environment(\.isCompact) private var isCompact: Bool

  @Environment(UserPreferences.self) private var preferences

  var viewModel: StatusRowViewModel

  #if canImport(Translation) && !os(visionOS) && !targetEnvironment(macCatalyst)
  @State private var translationConfig: TranslationSession.Configuration?
  #endif

  private var effectiveUserLang: String {
    preferences.serverPreferences?.postLanguage
      ?? Locale.current.language.languageCode?.identifier
      ?? "en"
  }

  private func isLanguageForeign(statusLang: String?) -> Bool {
    guard let statusLang, !statusLang.isEmpty else { return false }
    let userPrefix = Locale.Language(identifier: effectiveUserLang).languageCode?.identifier?.lowercased() ?? effectiveUserLang.prefix(2).lowercased()
    let statusPrefix = Locale.Language(identifier: statusLang).languageCode?.identifier?.lowercased() ?? statusLang.prefix(2).lowercased()
    return userPrefix != statusPrefix
  }

  private var shouldShowTranslateButton: Bool {
    if preferences.showTranslateButton {
      if !viewModel.finalStatus.content.asRawText.isEmpty {
        if viewModel.translation == nil {
          let statusLang = viewModel.getStatusLang()
          return isLanguageForeign(statusLang: statusLang)
        }
      }
    }
    return false
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
    if !isInCaptureMode {
      if !isCompact {
        if shouldShowTranslateButton {
          Button {
            Task {
              await viewModel.translate(userLang: effectiveUserLang)
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

      if preferences.translationDisplayStyle == .card {
        if let translation = viewModel.translation {
          if !viewModel.isLoadingTranslation {
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
    #if canImport(Translation) && !os(visionOS) && !targetEnvironment(macCatalyst)
    .onChange(of: viewModel.triggerAppleInlineTranslation) { _, shouldTrigger in
      if shouldTrigger {
        let targetLang = Locale.Language(identifier: effectiveUserLang)
        let sourceLang = viewModel.getStatusLang().map { Locale.Language(identifier: $0) }
        translationConfig?.invalidate()
        translationConfig = .init(source: sourceLang, target: targetLang)
      }
    }
    .translationTask(translationConfig) { session in
      let text = viewModel.finalStatus.content.asRawText
      let sourceLang = viewModel.getStatusLang() ?? ""
      let statusId = viewModel.finalStatus.id
      guard !text.isEmpty else {
        withAnimation {
          viewModel.isLoadingTranslation = false
          viewModel.triggerAppleInlineTranslation = false
        }
        return
      }
      do {
        let response = try await session.translate(text)
        let detectedLang = response.sourceLanguage.languageCode?.identifier ?? sourceLang
        let translation = Translation(
          content: response.targetText,
          detectedSourceLanguage: detectedLang,
          provider: "Apple"
        )
        withAnimation {
          viewModel.translation = translation
          viewModel.isLoadingTranslation = false
          viewModel.triggerAppleInlineTranslation = false
        }
        StatusTranslationCache.shared.set(statusId: statusId, translation: translation)
      } catch {
        withAnimation {
          viewModel.isLoadingTranslation = false
          viewModel.triggerAppleInlineTranslation = false
        }
      }
    }
    #endif
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
      viewModel.autoTranslateIfNeeded(userLang: effectiveUserLang)
    }
  }
}
