import EmojiText
import Env
import Foundation
import Models
import SwiftUI

@MainActor
public struct EmojiTextApp: View {
  private let markdown: HTMLString
  private let emojis: [any CustomEmoji]
  private let language: String?
  private let append: (@Sendable () -> Text)?
  private let lineLimit: Int?

  public init(
    _ markdown: HTMLString, emojis: [Emoji], language: String? = nil, lineLimit: Int? = nil,
    append: (@Sendable () -> Text)? = nil
  ) {
    self.markdown = markdown
    self.emojis = emojis.compactMap { emoji in
      guard let url = URL(string: emoji.url) else { return nil }
      return RemoteEmoji(shortcode: emoji.shortcode, url: url)
    }
    self.language = language
    self.lineLimit = lineLimit
    self.append = append
  }

  private var layoutDirection: LayoutDirection {
    isRTL() ? .rightToLeft : .leftToRight
  }

  public var body: some View {
    if let append {
      EmojiText(markdown: markdown.asMarkdown, emojis: emojis)
        .animated(UserPreferences.shared.animateEmojis)
        .append(text: append)
        .lineLimit(lineLimit)
        .environment(\.layoutDirection, layoutDirection)
    } else if emojis.isEmpty {
      Text(markdown.asSafeMarkdownAttributedString)
        .lineLimit(lineLimit)
        .environment(\.layoutDirection, layoutDirection)
    } else {
      EmojiText(markdown: markdown.asMarkdown, emojis: emojis)
        .animated(UserPreferences.shared.animateEmojis)
        .lineLimit(lineLimit)
        .environment(\.layoutDirection, layoutDirection)
    }
  }

  private func isRTL() -> Bool {
    guard let language, !language.isEmpty else { return false }
    let prefix = Locale.Language(identifier: language).languageCode?.identifier.lowercased()
      ?? String(language.prefix(2)).lowercased()
    // Arabic, Hebrew, Persian, Urdu, Kurdish, Azeri, Dhivehi, Yiddish, Pashto, Sindhi, Uyghur
    return ["ar", "he", "iw", "fa", "ur", "ku", "ckb", "az", "dv", "yi", "ps", "sd", "ug"].contains(prefix)
  }
}
