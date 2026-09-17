import re

with open('Packages/Models/Sources/Models/Alias/HTMLString.swift', 'r') as f:
    content = f.read()

new_func = """
  private mutating func removeTrailingTags(doc: SwiftSoup.Document) {
    // Fast bail-outs
    if !asMarkdown.contains("#") && !asMarkdown.contains("＃") { return }

    guard let body = doc.body() else { return }
    var foundHashtag = false
    
    func isHashtagAnchor(_ node: SwiftSoup.Node) -> Bool {
        let name = node.nodeName()
        if name == "a" {
            let cls = (try? node.attr("class")) ?? ""
            let href = (try? node.attr("href")) ?? ""
            let anchorText = (try? (node as? SwiftSoup.Element)?.text()) ?? ""
            let trimmedText = anchorText.trimmingCharacters(in: .whitespacesAndNewlines)
            let textStartsWithHash = trimmedText.hasPrefix("#") || trimmedText.hasPrefix("＃")
            let hasTagInUrl = href.contains("/tags/") || href.contains("/tag/")
            return cls.contains("hashtag") || (hasTagInUrl && textStartsWithHash)
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
        
        let mdRegex = try! NSRegularExpression(pattern: "(?:\\\\s*\\\\[[#＃].*?\\\\]\\\\([^\\\\)]+\\\\))+\\\\s*$", options: .caseInsensitive)
        let mdRange = NSRange(location: 0, length: asMarkdown.utf16.count)
        asMarkdown = mdRegex.stringByReplacingMatches(in: asMarkdown, options: [], range: mdRange, withTemplate: "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        let rawRegex = try! NSRegularExpression(pattern: "(?:\\\\s*[#＃]\\\\S+)+\\\\s*$", options: .caseInsensitive)
        let rawRange = NSRange(location: 0, length: asRawText.utf16.count)
        asRawText = rawRegex.stringByReplacingMatches(in: asRawText, options: [], range: rawRange, withTemplate: "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
  }
"""

start_marker = "private mutating func removeTrailingTags(doc: SwiftSoup.Document) {"
start_idx = content.find(start_marker)

end_marker = "public struct Link: Codable, Hashable, Identifiable {"
end_idx = content.find(end_marker, start_idx)

if start_idx != -1 and end_idx != -1:
    content = content[:start_idx] + new_func.strip() + "\n\n  " + content[end_idx:]
    with open('Packages/Models/Sources/Models/Alias/HTMLString.swift', 'w') as f:
        f.write(content)
    print("Patched!")
else:
    print("Could not find markers")
