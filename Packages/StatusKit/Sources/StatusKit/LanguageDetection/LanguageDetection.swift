import Foundation
import Models
import NaturalLanguage

private nonisolated let languageStripRegex: NSRegularExpression? = try? NSRegularExpression(
  pattern: "https?://\\S+|#[\\w]+|:\\w+:|@[\\w.\\-]+",
  options: [.caseInsensitive]
)
private nonisolated let japaneseScriptRegex: NSRegularExpression? = try? NSRegularExpression(
  pattern: "[\\u3040-\\u309F\\u30A0-\\u30FF]"
)
private nonisolated let chineseScriptRegex: NSRegularExpression? = try? NSRegularExpression(
  pattern: "[\\u4E00-\\u9FFF]"
)

private nonisolated func stripToPureLanguage(inText: String) -> String {
  guard let regex = languageStripRegex else {
    return inText.trimmingCharacters(in: .whitespacesAndNewlines)
  }
  let nsRange = NSRange(inText.startIndex..<inText.endIndex, in: inText)
  let stripped = regex.stringByReplacingMatches(in: inText, options: [], range: nsRange, withTemplate: " ")
  return stripped.trimmingCharacters(in: .whitespacesAndNewlines)
}

public nonisolated func detectLanguage(text: String, minConfidence: Double = 0.65) -> String? {
  let recognizer = NLLanguageRecognizer()

  let strippedText = stripToPureLanguage(inText: text)
  guard !strippedText.isEmpty else { return nil }

  recognizer.processString(strippedText)

  let hypotheses = recognizer.languageHypotheses(withMaximum: 1)

  if let (lang, confidence) = hypotheses.first {
    if confidence >= minConfidence {
      return lang.rawValue
    }
  }
  return nil
}

public nonisolated func normalizeLanguageCode(_ code: String) -> String {
  let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  guard !trimmed.isEmpty else { return "" }
  if let langCode = Locale.Language(identifier: trimmed).languageCode?.identifier.lowercased() {
    return langCode
  }
  if let dashIndex = trimmed.firstIndex(where: { $0 == "-" || $0 == "_" }) {
    return String(trimmed[..<dashIndex])
  }
  return trimmed
}

public nonisolated func isStatusHiddenByLanguage(
  status: Status,
  hiddenLanguages: [String]
) -> Bool {
  guard !hiddenLanguages.isEmpty else { return false }

  let targetStatus: any AnyStatus = if let reblog = status.reblog {
    reblog
  } else {
    status
  }

  // Preserve posts with media attachments according to "Language Text Post Filters" specification
  let hasMedia = !status.mediaAttachments.isEmpty || !(targetStatus.mediaAttachments.isEmpty)
  guard !hasMedia else { return false }

  // Normalize hiddenLanguages to lowercase base language codes
  let normalizedHidden = Set(hiddenLanguages.compactMap { code -> String? in
    let normalized = normalizeLanguageCode(code)
    return normalized.isEmpty ? nil : normalized
  })
  guard !normalizedHidden.isEmpty else { return false }

  // 1. Check explicit language tags on target status and wrapper status
  let candidateLangs = [targetStatus.language, status.language].compactMap { $0 }
  for candidate in candidateLangs {
    let baseCode = normalizeLanguageCode(candidate)
    if !baseCode.isEmpty {
      if normalizedHidden.contains(baseCode) {
        return true
      }
    }
  }

  // 2. Untagged post fallback: on-device language analysis
  let text = targetStatus.content.asRawText.isEmpty ? status.content.asRawText : targetStatus.content.asRawText
  if !text.isEmpty {
    let textRange = NSRange(text.startIndex..<text.endIndex, in: text)
    if normalizedHidden.contains("ja"),
       japaneseScriptRegex?.firstMatch(in: text, options: [], range: textRange) != nil {
      return true
    }
    if normalizedHidden.contains("zh"),
       chineseScriptRegex?.firstMatch(in: text, options: [], range: textRange) != nil {
      return true
    }

    if let detected = detectLanguage(text: text) {
      let baseDetected = normalizeLanguageCode(detected)
      if !baseDetected.isEmpty {
        if normalizedHidden.contains(baseDetected) {
          return true
        }
      }
    }
  }

  return false
}
