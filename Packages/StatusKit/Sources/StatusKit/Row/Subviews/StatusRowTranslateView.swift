import Foundation
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
    guard let statusLang else { return false }
    guard !statusLang.isEmpty else { return false }
    let userPrefix = Locale.Language(identifier: effectiveUserLang).languageCode?.identifier.lowercased() ?? effectiveUserLang.prefix(2).lowercased()
    let statusPrefix = Locale.Language(identifier: statusLang).languageCode?.identifier.lowercased() ?? statusLang.prefix(2).lowercased()
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
            .environment(
              \.openURL,
              OpenURLAction { url in
                viewModel.routerPath.handleStatus(status: viewModel.finalStatus, url: url)
              })
            .fixedSize(horizontal: false, vertical: true)
          }
        }
      }
    }
    #if canImport(Translation) && !os(visionOS) && !targetEnvironment(macCatalyst)
    .onChange(of: viewModel.triggerAppleInlineTranslation) { _, shouldTrigger in
      handleAppleTranslationTrigger(shouldTrigger)
    }
    .translationTask(translationConfig) { session in
      await performAppleTranslation(session: session)
    }
    #endif
  }

  #if canImport(Translation) && !os(visionOS) && !targetEnvironment(macCatalyst)
  private func normalizedLocaleLanguage(_ code: String) -> Locale.Language {
    let cleaned = code.replacingOccurrences(of: "_", with: "-").trimmingCharacters(in: .whitespacesAndNewlines)
    let lower = cleaned.lowercased()
    if lower == "zh" || lower == "zh-cn" || lower == "zh-sg" || lower.hasPrefix("zh-hans") {
      return Locale.Language(identifier: "zh-Hans")
    }
    if lower == "zh-tw" || lower == "zh-hk" || lower == "zh-mo" || lower.hasPrefix("zh-hant") {
      return Locale.Language(identifier: "zh-Hant")
    }
    return Locale.Language(identifier: cleaned)
  }

  private func handleAppleTranslationTrigger(_ shouldTrigger: Bool) {
    guard shouldTrigger else { return }
    let targetLang = normalizedLocaleLanguage(effectiveUserLang)
    let targetPrefix = targetLang.languageCode?.identifier.lowercased() ?? effectiveUserLang.prefix(2).lowercased()

    var sourceLang: Locale.Language? = nil
    if let rawSource = viewModel.getStatusLang(), !rawSource.isEmpty {
      let candidate = normalizedLocaleLanguage(rawSource)
      let sourcePrefix = candidate.languageCode?.identifier.lowercased() ?? rawSource.prefix(2).lowercased()
      if sourcePrefix != targetPrefix {
        sourceLang = candidate
      }
    }

    if viewModel.isAutoTranslating {
      let resolvedSource = sourceLang
      Task { @MainActor in
        let availability = LanguageAvailability()
        if let resolvedSource {
          let status = await availability.status(from: resolvedSource, to: targetLang)
          guard status == .installed else {
            withAnimation {
              viewModel.isLoadingTranslation = false
              viewModel.triggerAppleInlineTranslation = false
            }
            return
          }
        } else {
          let textSample = viewModel.translationText
          let status = try? await availability.status(for: textSample, to: targetLang)
          guard status == .installed else {
            withAnimation {
              viewModel.isLoadingTranslation = false
              viewModel.triggerAppleInlineTranslation = false
            }
            return
          }
        }
        applyTranslationConfig(source: resolvedSource, target: targetLang)
      }
    } else {
      applyTranslationConfig(source: sourceLang, target: targetLang)
    }
  }

  private func applyTranslationConfig(source: Locale.Language?, target: Locale.Language) {
    if translationConfig == nil {
      translationConfig = .init(source: source, target: target)
    } else if translationConfig?.source == source && translationConfig?.target == target {
      translationConfig?.invalidate()
    } else {
      translationConfig = .init(source: source, target: target)
    }
  }

  private func performAppleTranslation(session: TranslationSession) async {
    let text = viewModel.translationText
    let sourceLang = viewModel.getStatusLang() ?? ""
    let statusId = viewModel.finalStatus.id
    let links = viewModel.translationLinks
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
        provider: "Apple",
        originalLinks: links
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
}
