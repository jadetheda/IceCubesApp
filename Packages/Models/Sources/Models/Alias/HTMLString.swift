import Foundation
import SwiftSoup
import SwiftUI

private enum CodingKeys: CodingKey {
  case htmlValue, asMarkdown, asRawText, statusesURLs, links, hadTrailingTags
}

public struct HTMLString: Codable, Equatable, Hashable, @unchecked Sendable {
  public var htmlValue: String = ""
  public var asMarkdown: String = ""
  public var asRawText: String = ""
  public var statusesURLs = [URL]()
  public private(set) var links = [Link]()
  public private(set) var hadTrailingTags = false

  public var asSafeMarkdownAttributedString: AttributedString = .init()
  private var main_regex: NSRegularExpression?
  private var underscore_regex: NSRegularExpression?
  public init(from decoder: Decoder) {
    var alreadyDecoded = false
    do {
      let container = try decoder.singleValueContainer()
      htmlValue = try container.decode(String.self)
    } catch {
      do {
        alreadyDecoded = true
        let container = try decoder.container(keyedBy: CodingKeys.self)
        htmlValue = try container.decode(String.self, forKey: .htmlValue)
        asMarkdown = try container.decode(String.self, forKey: .asMarkdown)
        asRawText = try container.decode(String.self, forKey: .asRawText)
        statusesURLs = try container.decode([URL].self, forKey: .statusesURLs)
        links = try container.decode([Link].self, forKey: .links)
        hadTrailingTags = (try? container.decode(Bool.self, forKey: .hadTrailingTags)) ?? false
      } catch {
        htmlValue = ""
      }
    }

    if !alreadyDecoded {
      parseHTML(htmlValue)
    } else {
      do {
        let options = AttributedString.MarkdownParsingOptions(
          allowsExtendedAttributes: true,
          interpretedSyntax: .inlineOnlyPreservingWhitespace)
        asSafeMarkdownAttributedString = try AttributedString(
          markdown: asMarkdown, options: options)
      } catch {
        asSafeMarkdownAttributedString = AttributedString(stringLiteral: htmlValue)
      }
    }
  }

  private mutating func parseHTML(_ html: String) {
    // https://daringfireball.net/projects/markdown/syntax
    // Pre-escape \ ` _ * ~ and [ as these are the only
    // characters the markdown parser uses when it renders
    // to attributed text. Note that ~ for strikethrough is
    // not documented in the syntax docs but is used by
    // AttributedString.
    main_regex = try? NSRegularExpression(
      pattern: "([\\*\\`\\~\\[\\\\])", options: .caseInsensitive)
    // don't escape underscores that are between colons, they are most likely custom emoji
    underscore_regex = try? NSRegularExpression(
      pattern: "(?!\\B:[^:]*)(_)(?![^:]*:\\B)", options: .caseInsensitive)

    asMarkdown = ""
    do {
      let document: SwiftSoup.Document = try SwiftSoup.parse(html)
      var listCounters: [Int] = []
      handleNode(node: document, listCounters: &listCounters)

      document.outputSettings(OutputSettings().prettyPrint(pretty: false))
      try document.select("p.quote-inline").remove()
      try document.select("br").after("\n")
      try document.select("p").after("\n\n")
      let cleanHtml = try document.html()
      var text =
        try SwiftSoup.clean(
          cleanHtml, "", Whitelist.none(), OutputSettings().prettyPrint(pretty: false)) ?? ""
      // Remove the two last line break added after the last paragraph.
      if text.hasSuffix("\n\n") {
        _ = text.removeLast()
        _ = text.removeLast()
      }
      asRawText = (try? Entities.unescape(text)) ?? text

      if asMarkdown.hasPrefix("\n") {
        _ = asMarkdown.removeFirst()
      }

      // Remove trailing hashtags
      removeTrailingTags(doc: document)

      // Autolink any bare URLs that were not wrapped in <a> tags
      let autolinkResult = Self.autolink(text: asMarkdown)
      if autolinkResult.markdown != asMarkdown {
        asMarkdown = autolinkResult.markdown
        for l in autolinkResult.links {
          if !links.contains(where: { $0.url == l.url }) {
            links.append(l)
          }
        }
        for u in autolinkResult.statusesURLs {
          if !statusesURLs.contains(u) {
            statusesURLs.append(u)
          }
        }
      }

      // Regenerate attributed string after extracting tags
      do {
        let options = AttributedString.MarkdownParsingOptions(
          allowsExtendedAttributes: true,
          interpretedSyntax: .inlineOnlyPreservingWhitespace)
        asSafeMarkdownAttributedString = try AttributedString(
          markdown: asMarkdown, options: options)
      } catch {
        asSafeMarkdownAttributedString = AttributedString(stringLiteral: asMarkdown)
      }

    } catch {
      asRawText = html
    }
  }

  public static func autolink(
    text: String,
    originalLinks: [Link] = []
  ) -> (markdown: String, links: [Link], statusesURLs: [URL]) {
    guard !text.isEmpty else {
      return ("", [], [])
    }

    var result = text
    var discoveredLinks: [Link] = []
    var discoveredStatusesURLs: [URL] = []

    func registerStatusURLIfNeeded(_ url: URL) {
      if Int(url.lastPathComponent) != nil {
        if !discoveredStatusesURLs.contains(url) {
          discoveredStatusesURLs.append(url)
        }
      } else if url.host == "www.threads.net" || url.host == "threads.net" {
        if url.pathComponents.count == 4 {
          if url.pathComponents[2] == "post" {
            if !discoveredStatusesURLs.contains(url) {
              discoveredStatusesURLs.append(url)
            }
          }
        }
      }
    }

    // Step 1: Detect existing Markdown links: [display](url)
    var protectedRanges: [Range<String.Index>] = []
    if let mdRegex = try? NSRegularExpression(pattern: #"\[([^\]]+)\]\(([^)]+)\)"#) {
      let nsString = result as NSString
      let matches = mdRegex.matches(in: result, options: [], range: NSRange(location: 0, length: nsString.length))
      for match in matches {
        if let fullRange = Range(match.range, in: result) {
          protectedRanges.append(fullRange)
        }
        let displayStr = nsString.substring(with: match.range(at: 1))
        let urlStr = nsString.substring(with: match.range(at: 2))
        var url = URL(string: urlStr)
        if url == nil {
          url = URL(string: urlStr, encodePath: true)
        }
        if let url {
          let link = Link(url, displayString: displayStr)
          if !discoveredLinks.contains(where: { $0.url == url }) {
            discoveredLinks.append(link)
          }
          registerStatusURLIfNeeded(url)
        }
      }
    }

    // Step 2: Match mentions and hashtags from originalLinks
    for origLink in originalLinks {
      if origLink.type == .mention || origLink.type == .hashtag {
        let target = origLink.displayString
        if !target.isEmpty {
          let escaped = NSRegularExpression.escapedPattern(for: target)
          let pattern = #"(?:^|[\s\(\[\{])("# + escaped + #")(?=$|[\s\)\]\}\.\,\!\?\;\:])"#
          if let regex = try? NSRegularExpression(pattern: pattern) {
            let nsString = result as NSString
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: nsString.length)).reversed()
            for match in matches {
              let targetNSRange = match.range(at: 1)
              guard let targetRange = Range(targetNSRange, in: result) else { continue }
              let overlaps = protectedRanges.contains { protected in
                targetRange.lowerBound < protected.upperBound && targetRange.upperBound > protected.lowerBound
              }
              if !overlaps {
                let replacement = "[\(target)](\(origLink.url.absoluteString))"
                result.replaceSubrange(targetRange, with: replacement)
                if !discoveredLinks.contains(where: { $0.url == origLink.url }) {
                  discoveredLinks.append(origLink)
                }
                registerStatusURLIfNeeded(origLink.url)
              }
            }
            // Re-scan protected ranges
            protectedRanges.removeAll()
            if let mdRegex = try? NSRegularExpression(pattern: #"\[([^\]]+)\]\(([^)]+)\)"#) {
              let rescanned = mdRegex.matches(in: result, options: [], range: NSRange(location: 0, length: (result as NSString).length))
              for m in rescanned {
                if let r = Range(m.range, in: result) {
                  protectedRanges.append(r)
                }
              }
            }
          }
        }
      }
    }

    // Step 3: Autolink bare URLs
    let urlPattern = #"https?://[^\s<>"{}|\\^`]+"#
    if let urlRegex = try? NSRegularExpression(pattern: urlPattern, options: [.caseInsensitive]) {
      let nsString = result as NSString
      let matches = urlRegex.matches(in: result, options: [], range: NSRange(location: 0, length: nsString.length)).reversed()
      for match in matches {
        let matchNSRange = match.range
        guard let matchRange = Range(matchNSRange, in: result) else { continue }
        let overlaps = protectedRanges.contains { protected in
          matchRange.lowerBound < protected.upperBound && matchRange.upperBound > protected.lowerBound
        }
        if overlaps { continue }

        var rawCandidate = String(result[matchRange])
        var didTrim = true
        while didTrim && !rawCandidate.isEmpty {
          didTrim = false
          while let lastChar = rawCandidate.last, ".!?,;:\"'>".contains(lastChar) {
            rawCandidate.removeLast()
            didTrim = true
          }
          while rawCandidate.hasSuffix(")") {
            let openCount = rawCandidate.filter({ $0 == "(" }).count
            let closeCount = rawCandidate.filter({ $0 == ")" }).count
            if closeCount > openCount {
              rawCandidate.removeLast()
              didTrim = true
            } else {
              break
            }
          }
          while rawCandidate.hasSuffix("]") {
            let openCount = rawCandidate.filter({ $0 == "[" }).count
            let closeCount = rawCandidate.filter({ $0 == "]" }).count
            if closeCount > openCount {
              rawCandidate.removeLast()
              didTrim = true
            } else {
              break
            }
          }
        }

        guard !rawCandidate.isEmpty else { continue }
        var validUrl = URL(string: rawCandidate)
        if validUrl == nil {
          validUrl = URL(string: rawCandidate, encodePath: true)
        }
        guard let validUrl, let scheme = validUrl.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
          continue
        }

        let candidateLen = rawCandidate.utf16.count
        let candidateNSRange = NSRange(location: matchNSRange.location, length: candidateLen)
        guard let candidateRange = Range(candidateNSRange, in: result) else { continue }

        let replacement = "[\(rawCandidate)](\(validUrl.absoluteString))"
        result.replaceSubrange(candidateRange, with: replacement)

        let link = Link(validUrl, displayString: rawCandidate)
        if !discoveredLinks.contains(where: { $0.url == validUrl }) {
          discoveredLinks.append(link)
        }
        registerStatusURLIfNeeded(validUrl)
      }
    }

    return (markdown: result, links: discoveredLinks, statusesURLs: discoveredStatusesURLs)
  }

  public init(
    stringValue: String,
    parseMarkdown: Bool = false,
    originalLinks: [Link] = []
  ) {
    htmlValue = stringValue
    asMarkdown = stringValue
    asRawText = stringValue
    statusesURLs = []
    links = []

    if parseMarkdown {
      let hasHTML = stringValue.contains("<p") || stringValue.contains("<a ") || stringValue.contains("<br") || stringValue.contains("<div>")
      if hasHTML {
        parseHTML(stringValue)
      } else {
        let autolinkResult = Self.autolink(text: stringValue, originalLinks: originalLinks)
        asMarkdown = autolinkResult.markdown
        links = autolinkResult.links
        statusesURLs = autolinkResult.statusesURLs
        asRawText = stringValue

        do {
          let options = AttributedString.MarkdownParsingOptions(
            allowsExtendedAttributes: true,
            interpretedSyntax: .inlineOnlyPreservingWhitespace)
          asSafeMarkdownAttributedString = try AttributedString(
            markdown: asMarkdown, options: options)
        } catch {
          asSafeMarkdownAttributedString = AttributedString(stringLiteral: asMarkdown)
        }
      }
    } else {
      asSafeMarkdownAttributedString = AttributedString(stringLiteral: htmlValue)
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(htmlValue, forKey: .htmlValue)
    try container.encode(asMarkdown, forKey: .asMarkdown)
    try container.encode(asRawText, forKey: .asRawText)
    try container.encode(statusesURLs, forKey: .statusesURLs)
    try container.encode(links, forKey: .links)
    try container.encode(hadTrailingTags, forKey: .hadTrailingTags)
  }

  private mutating func removeTrailingTags(doc: SwiftSoup.Document) {
    // Fast bail-outs
    if !asMarkdown.contains("#") && !asMarkdown.contains("＃") && !asMarkdown.contains("/tags/") && !asMarkdown.contains("/tag/") { return }

    guard let body = doc.body() else { return }
    var foundHashtag = false
    
    func isHashtagAnchor(_ node: SwiftSoup.Node) -> Bool {
        let name = node.nodeName()
        if name == "a" {
            let cls = (try? node.attr("class")) ?? ""
            let href = (try? node.attr("href")) ?? ""
            let hasTagInUrl = href.contains("/tags/") || href.contains("/tag/")
            return cls.contains("hashtag") || hasTagInUrl
        }
        if name == "span" {
            for child in node.getChildNodes() {
                if isHashtagAnchor(child) { return true }
            }
        }
        return false
    }
    
    func isRemovable(_ node: SwiftSoup.Node) -> Bool {
        let name = node.nodeName()
        if name == "#text" {
            return node.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if name == "br" || name == "hr" {
            return true
        }
        return isHashtagAnchor(node)
    }
    
    func popTrailingTags(from element: SwiftSoup.Element) -> Bool {
        var didRemove = false
        while let lastChild = element.getChildNodes().last {
            if isRemovable(lastChild) {
                if isHashtagAnchor(lastChild) { foundHashtag = true }
                try? lastChild.remove()
                didRemove = true
            } else if let el = lastChild as? SwiftSoup.Element {
                let removedInside = popTrailingTags(from: el)
                if removedInside {
                    didRemove = true
                    if el.childNodeSize() == 0 {
                        try? el.remove()
                    } else {
                        break
                    }
                } else {
                    break
                }
            } else {
                break
            }
        }
        return didRemove
    }
    
    _ = popTrailingTags(from: body)
    
    if foundHashtag {
        hadTrailingTags = true
        
        let mdRegex = try! NSRegularExpression(pattern: "(?:\\s*\\[[^\\]]*\\]\\([^\\)]*(?:/tags/|/tag/)[^\\)]*\\)|\\s*\\[[#＃][^\\]]*\\]\\([^\\)]+\\))+\\s*$", options: .caseInsensitive)
        let mdRange = NSRange(location: 0, length: asMarkdown.utf16.count)
        asMarkdown = mdRegex.stringByReplacingMatches(in: asMarkdown, options: [], range: mdRange, withTemplate: "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        let rawRegex = try! NSRegularExpression(pattern: "(?:\\s*[#＃]\\S+)+\\s*$", options: .caseInsensitive)
        let rawRange = NSRange(location: 0, length: asRawText.utf16.count)
        asRawText = rawRegex.stringByReplacingMatches(in: asRawText, options: [], range: rawRange, withTemplate: "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
  }

  private mutating func handleNode(
    node: SwiftSoup.Node,
    indent: Int? = 0,
    skipParagraph: Bool = false,
    listCounters: inout [Int]
  ) {
    do {
      if let className = try? node.attr("class") {
        if className == "invisible" {
          // don't display
          return
        }

        if className == "ellipsis" {
          // descend into this one now and
          // append the ellipsis
          for nn in node.getChildNodes() {
            handleNode(node: nn, indent: indent, listCounters: &listCounters)
          }
          asMarkdown += "…"
          return
        }
      }

      if node.nodeName() == "p" {
        if let className = try? node.attr("class"), className == "quote-inline" {
          return
        }
        if asMarkdown.count > 0 && !skipParagraph {
          asMarkdown += "\n\n"
        }
      } else if node.nodeName() == "br" {
        if asMarkdown.count > 0 {  // ignore first opening <br>
          asMarkdown += "\n"
        }
        if (indent ?? 0) > 0 {
          asMarkdown += "\n"
        }
      } else if node.nodeName() == "a" {
        let href = try node.attr("href")
        if href != "" {
          if let url = URL(string: href) {
            if Int(url.lastPathComponent) != nil {
              statusesURLs.append(url)
            } else if url.host() == "www.threads.net" || url.host() == "threads.net",
              url.pathComponents.count == 4,
              url.pathComponents[2] == "post"
            {
              statusesURLs.append(url)
            }
          }
        }
        asMarkdown += "["
        let start = asMarkdown.endIndex
        // descend into this node now so we can wrap the
        // inner part of the link in the right markup
        for nn in node.getChildNodes() {
          handleNode(node: nn, listCounters: &listCounters)
        }
        let finish = asMarkdown.endIndex

        var linkRef = href

        // Try creating a URL from the string. If it fails, try URL encoding
        //   the string first.
        var url = URL(string: href)
        if url == nil {
          url = URL(string: href, encodePath: true)
        }
        if let linkUrl = url {
          linkRef = linkUrl.absoluteString
          let displayString = asMarkdown[start..<finish]
          links.append(Link(linkUrl, displayString: String(displayString)))
        }

        asMarkdown += "]("
        asMarkdown += linkRef
        asMarkdown += ")"

        return
      } else if node.nodeName() == "#text" {
        var txt = node.description

        txt = (try? Entities.unescape(txt)) ?? txt
        let isLineStart = asMarkdown.isEmpty || asMarkdown.hasSuffix("\n")

        if let underscore_regex, let main_regex {
          //  This is the markdown escaper
          txt = main_regex.stringByReplacingMatches(
            in: txt, options: [], range: NSRange(location: 0, length: txt.count),
            withTemplate: "\\\\$1")
          txt = underscore_regex.stringByReplacingMatches(
            in: txt, options: [], range: NSRange(location: 0, length: txt.count),
            withTemplate: "\\\\$1")
        }
        if isLineStart,
          txt.hasPrefix("- ") || txt.hasPrefix("* ") || txt.hasPrefix("+ ")
        {
          txt = "\\" + txt
        }
        // Strip newlines and line separators - they should be being sent as <br>s
        asMarkdown += txt.replacingOccurrences(of: "\n", with: "").replacingOccurrences(
          of: "\u{2028}", with: "")
      } else if node.nodeName() == "blockquote" {
        asMarkdown += "\n\n`"
        for nn in node.getChildNodes() {
          handleNode(node: nn, indent: indent, listCounters: &listCounters)
        }
        asMarkdown += "`"
        return
      } else if node.nodeName() == "strong" || node.nodeName() == "b" {
        asMarkdown += "**"
        for nn in node.getChildNodes() {
          handleNode(node: nn, indent: indent, listCounters: &listCounters)
        }
        asMarkdown += "**"
        return
      } else if node.nodeName() == "em" || node.nodeName() == "i" {
        asMarkdown += "_"
        for nn in node.getChildNodes() {
          handleNode(node: nn, indent: indent, listCounters: &listCounters)
        }
        asMarkdown += "_"
        return
      } else if node.nodeName() == "ul" || node.nodeName() == "ol" {

        if skipParagraph {
          asMarkdown += "\n"
        } else {
          asMarkdown += "\n\n"
        }

        var listCounters = listCounters

        if node.nodeName() == "ol" {
          listCounters.append(1)  // Start numbering for a new ordered list
        }

        for nn in node.getChildNodes() {
          handleNode(node: nn, indent: (indent ?? 0) + 1, listCounters: &listCounters)
        }

        if node.nodeName() == "ol" {
          listCounters.removeLast()
        }

        return
      } else if node.nodeName() == "li" {
        asMarkdown += "   "
        if let indent, indent > 1 {
          for _ in 0..<indent {
            asMarkdown += "   "
          }
          asMarkdown += "- "
        }

        if listCounters.isEmpty {
          asMarkdown += "• "
        } else {
          let currentIndex = listCounters.count - 1
          asMarkdown += "\(listCounters[currentIndex]). "
          listCounters[currentIndex] += 1
        }

        for nn in node.getChildNodes() {
          handleNode(node: nn, indent: indent, skipParagraph: true, listCounters: &listCounters)
        }
        asMarkdown += "\n"
        return
      }

      for n in node.getChildNodes() {
        handleNode(node: n, indent: indent, listCounters: &listCounters)
      }
    } catch {}
  }

  public struct Link: Codable, Hashable, Identifiable, Sendable {
    public var id: Int { hashValue }
    public let url: URL
    public let displayString: String
    public let type: LinkType
    public let title: String

    public init(_ url: URL, displayString: String) {
      self.url = url
      self.displayString = displayString

      switch displayString.first {
      case "@":
        type = .mention
        title = displayString
      case "#":
        type = .hashtag
        title = String(displayString.dropFirst())
      default:
        type = .url
        var hostNameUrl = url.host ?? url.absoluteString
        if hostNameUrl.hasPrefix("www.") {
          hostNameUrl = String(hostNameUrl.dropFirst(4))
        }
        title = hostNameUrl
      }
    }

    public enum LinkType: String, Codable, Sendable {
      case url
      case mention
      case hashtag
    }
  }
}

extension URL {
  // It's common to use non-ASCII characters in URLs even though they're technically
  //   invalid characters. Every modern browser handles this by silently encoding
  //   the invalid characters on the user's behalf. However, trying to create a URL
  //   object with un-encoded characters will result in nil so we need to encode the
  //   invalid characters before creating the URL object. The unencoded version
  //   should still be shown in the displayed status.
  public init?(string: String, encodePath: Bool) {
    var encodedUrlString = ""
    if encodePath,
      string.starts(with: "http://") || string.starts(with: "https://"),
      var startIndex = string.firstIndex(of: "/")
    {
      startIndex = string.index(startIndex, offsetBy: 1)

      // We don't want to encode the host portion of the URL
      if var startIndex = string[startIndex...].firstIndex(of: "/") {
        encodedUrlString = String(string[...startIndex])
        while let endIndex = string[string.index(after: startIndex)...].firstIndex(of: "/") {
          let componentStartIndex = string.index(after: startIndex)
          encodedUrlString =
            encodedUrlString
            + (string[componentStartIndex...endIndex].addingPercentEncoding(
              withAllowedCharacters: .urlPathAllowed) ?? "")
          startIndex = endIndex
        }

        // The last part of the path may have a query string appended to it
        let componentStartIndex = string.index(after: startIndex)
        if let queryStartIndex = string[componentStartIndex...].firstIndex(of: "?") {
          encodedUrlString =
            encodedUrlString
            + (string[componentStartIndex..<queryStartIndex].addingPercentEncoding(
              withAllowedCharacters: .urlPathAllowed) ?? "")
          encodedUrlString =
            encodedUrlString
            + (string[queryStartIndex...].addingPercentEncoding(
              withAllowedCharacters: .urlQueryAllowed) ?? "")
        } else {
          encodedUrlString =
            encodedUrlString
            + (string[componentStartIndex...].addingPercentEncoding(
              withAllowedCharacters: .urlPathAllowed) ?? "")
        }
      }
    }
    if encodedUrlString.isEmpty {
      encodedUrlString = string
    }
    self.init(string: encodedUrlString)
  }
}
