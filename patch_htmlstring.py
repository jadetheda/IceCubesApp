import re

with open('Packages/Models/Sources/Models/Alias/HTMLString.swift', 'r') as f:
    content = f.read()

# Replace the child node loop with a recursive one or just add br and span handling
new_loop = """
        func isHashtagOnlyNode(_ node: SwiftSoup.Node) -> Bool {
          let name = node.nodeName()
          if name == "#text" {
            let txt = node.description.trimmingCharacters(in: .whitespacesAndNewlines)
            return txt.isEmpty
          } else if name == "br" {
            return true
          } else if name == "span" {
            for child in node.getChildNodes() {
              if !isHashtagOnlyNode(child) { return false }
            }
            return true
          } else if name == "a" {
            let cls = (try? node.attr("class")) ?? ""
            let href = (try? node.attr("href")) ?? ""
            let element = node as? SwiftSoup.Element
            let anchorText = (try? element?.text()) ?? ""
            let trimmedText = anchorText.trimmingCharacters(in: .whitespacesAndNewlines)
            let textStartsWithHash = trimmedText.hasPrefix("#") || trimmedText.hasPrefix("＃")
            let hasTagInUrl = href.contains("/tags/") || href.contains("/tag/")
            return cls.contains("hashtag") || (hasTagInUrl && textStartsWithHash)
          }
          return false
        }

        var hasAtLeastOneHashtag = false
        var allValid = true
        for child in lastP.getChildNodes() {
          if !isHashtagOnlyNode(child) {
            allValid = false
            break
          }
          if child.nodeName() == "a" || (child.nodeName() == "span" && child.description.contains("href")) {
             hasAtLeastOneHashtag = true
          }
        }
        
        // Ensure we actually found anchors inside spans if they were nested
        if allValid && !hasAtLeastOneHashtag {
           let anchors = try? lastP.select("a")
           if let anchors = anchors, !anchors.isEmpty() {
               hasAtLeastOneHashtag = true
           }
        }
        
        return allValid && hasAtLeastOneHashtag
"""

# Find the loop to replace
start_marker = "var hasAtLeastOneHashtag = false\n        for child in lastP.getChildNodes() {"
end_marker = "return hasAtLeastOneHashtag"
start_idx = content.find(start_marker)

if start_idx != -1:
    end_idx = content.find(end_marker, start_idx) + len(end_marker)
    content = content[:start_idx] + new_loop.strip() + content[end_idx:]
else:
    print("Could not find start marker")

with open('Packages/Models/Sources/Models/Alias/HTMLString.swift', 'w') as f:
    f.write(content)
