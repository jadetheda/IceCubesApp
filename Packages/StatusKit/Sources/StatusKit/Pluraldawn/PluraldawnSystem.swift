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
    
    var matchedMembers: [PluraldawnMember] = []
    
    for member in members {
      var matched = false
      for rawIndicator in member.emoji {
        let indicator = rawIndicator
          .replacingOccurrences(of: "\u{FE0F}", with: "")
          .replacingOccurrences(of: "\u{FE0E}", with: "")
          .trimmingCharacters(in: .whitespaces)
        
        guard !indicator.isEmpty else { continue }
        
        // 1. Prefix match
        if cleanText.hasPrefix(indicator) {
          matched = true
          break
        }
        
        // 2. Suffix match
        if cleanText.hasSuffix(indicator) {
          matched = true
          break
        }
        
        let trimmedDashes = cleanText
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
