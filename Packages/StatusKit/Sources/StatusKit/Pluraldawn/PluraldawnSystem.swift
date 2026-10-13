import Foundation
import Models

public struct PluraldawnMember: Codable, Equatable, Sendable {
  public let id: String
  public let name: String
  public let emoji: [String]
  public let avatar: String
  public let font: String

  public var avatarURL: URL? {
    URL(string: avatar)
  }
}

public struct PluraldawnSystem: Codable, Equatable, Sendable {
  public let members: [PluraldawnMember]
}

public struct PluraldawnSystemMatcher: Sendable {
  public static func findMatch(rawText: String, mentions: [Mention], members: [PluraldawnMember]) -> PluraldawnMember? {
    let cleanText = rawText
      .replacingOccurrences(of: "\u{FE0F}", with: "")
      .replacingOccurrences(of: "\u{FE0E}", with: "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    
    guard !cleanText.isEmpty else { return nil }
    
    // Strip leading mentions for replies across Misskey, IceShrimp, and Mastodon (e.g. @alice @bob: ...)
    var textWithoutMentions = cleanText
    while textWithoutMentions.hasPrefix("@") {
      if let firstSpace = textWithoutMentions.firstIndex(where: { $0.isWhitespace }) {
        textWithoutMentions = String(textWithoutMentions[textWithoutMentions.index(after: firstSpace)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if textWithoutMentions.hasPrefix(":") {
          textWithoutMentions = String(textWithoutMentions.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
      } else {
        break
      }
    }
    
    // Strip leading MFM tags for Misskey and IceShrimp (e.g. $[x2 ...)
    var mfmCleanedStart = textWithoutMentions
    while mfmCleanedStart.hasPrefix("$[") {
      if let firstSpace = mfmCleanedStart.firstIndex(of: " ") {
        mfmCleanedStart = String(mfmCleanedStart[mfmCleanedStart.index(after: firstSpace)...]).trimmingCharacters(in: .whitespaces)
      } else {
        break
      }
    }
    
    // Strip trailing MFM tags/brackets (e.g. ...])
    var mfmCleanedEnd = cleanText
    while mfmCleanedEnd.hasSuffix("]") {
      mfmCleanedEnd = String(mfmCleanedEnd.dropLast()).trimmingCharacters(in: .whitespaces)
    }
    
    var matchedMembers: [PluraldawnMember] = []
    
    for member in members {
      var matched = false
      for rawIndicator in member.emoji {
        let indicator = rawIndicator
          .replacingOccurrences(of: "\u{FE0F}", with: "")
          .replacingOccurrences(of: "\u{FE0E}", with: "")
          .trimmingCharacters(in: .whitespaces)
        
        guard !indicator.isEmpty else { continue }
        
        // 1. Prefix match (standard, reply after mentions, or MFM-wrapped)
        if cleanText.hasPrefix(indicator) || textWithoutMentions.hasPrefix(indicator) || mfmCleanedStart.hasPrefix(indicator) {
          matched = true
          break
        }
        
        // 2. Suffix match (standard or MFM-wrapped)
        if cleanText.hasSuffix(indicator) || mfmCleanedEnd.hasSuffix(indicator) {
          matched = true
          break
        }
        
        let trimmedDashes = mfmCleanedEnd
          .trimmingCharacters(in: CharacterSet(charactersIn: "-–— \t\n\r"))
        if trimmedDashes.hasSuffix(indicator) {
          matched = true
          break
        }
        
        // 3. Mention in reply
        for mention in mentions {
          let pat1 = "@\(mention.acct) \(indicator)"
          let pat2 = "@\(mention.username) \(indicator)"
          let pat3 = "@\(mention.acct): \(indicator)"
          let pat4 = "@\(mention.username): \(indicator)"
          if cleanText.contains(pat1) || cleanText.contains(pat2) || cleanText.contains(pat3) || cleanText.contains(pat4) {
            matched = true
            break
          }
        }
        if matched { break }
      }
      
      if matched {
        matchedMembers.append(member)
      }
    }
    
    if matchedMembers.count == 1 {
      return matchedMembers.first
    }
    return nil
  }
}
