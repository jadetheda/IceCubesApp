import Foundation

public struct PluraldawnMember: Codable, Equatable {
  public let id: String
  public let name: String
  public let emoji: [String]
  public let avatar: String
  public let font: String

  public var avatarURL: URL? {
    URL(string: avatar)
  }
}

public struct PluraldawnSystem: Codable, Equatable {
  public let members: [PluraldawnMember]
}
import Models

public struct PluraldawnSystemMatcher {
  public static func findMatch(rawText: String, mentions: [Mention], members: [PluraldawnMember]) -> PluraldawnMember? {
    var matchedMembers: [PluraldawnMember] = []
    
    for member in members {
      var matched = false
      for indicator in member.emoji {
        let hasPref = rawText.hasPrefix(indicator)
        let hasSuff = rawText.hasSuffix(indicator)
        if hasPref || hasSuff {
          matched = true
          break
        }
        for mention in mentions {
          var str1 = "@"
          str1.append(mention.acct)
          str1.append(" ")
          str1.append(indicator)
          
          var str2 = "@"
          str2.append(mention.username)
          str2.append(" ")
          str2.append(indicator)
          
          let match1 = rawText.contains(str1)
          let match2 = rawText.contains(str2)
          if match1 || match2 {
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
