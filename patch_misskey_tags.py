import re

with open('Packages/NetworkClient/Sources/NetworkClient/DTOs/Misskey/MisskeyNote+Translate.swift', 'r') as f:
    content = f.read()

hashtag_logic = """
        // Hashtag linkification
        let hashtagPattern = "(^|[\\\\s<br>])([#＃][a-zA-Z0-9_]+)"
        if let regex = try? NSRegularExpression(pattern: hashtagPattern) {
            let nsString = html as NSString
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsString.length))
            for match in matches.reversed() {
                let fullMatchRange = match.range
                let prefixRange = match.range(at: 1)
                let tagRange = match.range(at: 2)
                
                let prefix = prefixRange.location != NSNotFound ? nsString.substring(with: prefixRange) : ""
                let tag = nsString.substring(with: tagRange)
                let tagText = String(tag.dropFirst())
                
                let replacement = "\\(prefix)<a href=\\"https://\\(server)/tags/\\(tagText)\\" class=\\"mention hashtag\\" rel=\\"tag\\">\\(tag)</a>"
                
                html = (html as NSString).replacingCharacters(in: fullMatchRange, with: replacement)
            }
        }
"""

marker = "        // Encode the generated HTML as a JSON string so all control characters"
idx = content.find(marker)

if idx != -1:
    content = content[:idx] + hashtag_logic.strip() + "\n\n" + content[idx:]
    with open('Packages/NetworkClient/Sources/NetworkClient/DTOs/Misskey/MisskeyNote+Translate.swift', 'w') as f:
        f.write(content)
    print("Patched MisskeyNote+Translate.swift!")
else:
    print("Could not find marker!")
