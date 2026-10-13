import Foundation
import Models
@testable import StatusKit
import XCTest

@MainActor
final class PluraldawnTests: XCTestCase {
  func testResolveOriginalAvatarURLProxyUnpack() {
    let proxyURL = URL(string: "https://misskey.example/proxy/avatar.webp?url=https%3A%2F%2Fmastodon.social%2Faccounts%2Favatars%2F123%2Fsmall%2Favatar.webp")!
    let resolved = PluraldawnDecoder.resolveOriginalAvatarURL(proxyURL)
    XCTAssertEqual(
      resolved.absoluteString,
      "https://mastodon.social/accounts/avatars/123/original/avatar.png"
    )
  }

  func testResolveOriginalAvatarURLPathReplacements() {
    let webpProxy = URL(string: "https://misskey.example/proxy/avatar.webp")!
    XCTAssertEqual(
      PluraldawnDecoder.resolveOriginalAvatarURL(webpProxy).absoluteString,
      "https://misskey.example/proxy/avatar.png"
    )

    let avatarWebp = URL(string: "https://remote.example/avatar.webp")!
    XCTAssertEqual(
      PluraldawnDecoder.resolveOriginalAvatarURL(avatarWebp).absoluteString,
      "https://remote.example/avatar.png"
    )

    let proxyImageWebp = URL(string: "https://sharkey.example/proxy/image.webp")!
    XCTAssertEqual(
      PluraldawnDecoder.resolveOriginalAvatarURL(proxyImageWebp).absoluteString,
      "https://sharkey.example/proxy/image.png"
    )

    let imageWebp = URL(string: "https://sharkey.example/image.webp")!
    XCTAssertEqual(
      PluraldawnDecoder.resolveOriginalAvatarURL(imageWebp).absoluteString,
      "https://sharkey.example/image.png"
    )

    let attachmentSmall = URL(string: "https://gts.example/attachment/small/avatar.webp")!
    XCTAssertEqual(
      PluraldawnDecoder.resolveOriginalAvatarURL(attachmentSmall).absoluteString,
      "https://gts.example/attachment/original/avatar.png"
    )

    let attachmentOriginalWebp = URL(string: "https://gts.example/attachment/original/avatar.webp")!
    XCTAssertEqual(
      PluraldawnDecoder.resolveOriginalAvatarURL(attachmentOriginalWebp).absoluteString,
      "https://gts.example/attachment/original/avatar.png"
    )

    let mastodonSmallPng = URL(string: "https://mastodon.example/accounts/avatars/000/001/small.png")!
    XCTAssertEqual(
      PluraldawnDecoder.resolveOriginalAvatarURL(mastodonSmallPng).absoluteString,
      "https://mastodon.example/accounts/avatars/000/001/original.png"
    )

    let mastodonSmallWebp = URL(string: "https://mastodon.example/accounts/avatars/000/001/small.webp")!
    XCTAssertEqual(
      PluraldawnDecoder.resolveOriginalAvatarURL(mastodonSmallWebp).absoluteString,
      "https://mastodon.example/accounts/avatars/000/001/original.png"
    )

    let mastodonCache = URL(string: "https://mastodon.example/api/v2/cache/avatar/123")!
    XCTAssertEqual(
      PluraldawnDecoder.resolveOriginalAvatarURL(mastodonCache).absoluteString,
      "https://mastodon.example/api/v2/cache/avatar/123?format=original"
    )
  }

  func testMatcherPrefixAndSuffix() {
    let alice = PluraldawnMember(
      id: "alice",
      name: "Alice",
      emoji: ["🌸", "[Alice]"],
      avatar: "emoji",
      font: "normal"
    )
    let bob = PluraldawnMember(
      id: "bob",
      name: "Bob",
      emoji: ["🦊"],
      avatar: "https://files.y2k.diy/bob.png",
      font: "normal"
    )
    let members = [alice, bob]

    // Prefix match
    let m1 = PluraldawnSystemMatcher.findMatch(rawText: "🌸 Hello world", mentions: [], members: members)
    XCTAssertEqual(m1?.id, "alice")

    // Suffix match
    let m2 = PluraldawnSystemMatcher.findMatch(rawText: "Hello world 🦊", mentions: [], members: members)
    XCTAssertEqual(m2?.id, "bob")

    // Suffix with dashes
    let m3 = PluraldawnSystemMatcher.findMatch(rawText: "Hello world 🌸 --", mentions: [], members: members)
    XCTAssertEqual(m3?.id, "alice")

    // Leading dashes
    let m4 = PluraldawnSystemMatcher.findMatch(rawText: "-- 🦊 Hello world", mentions: [], members: members)
    XCTAssertEqual(m4?.id, "bob")

    // Bracketed indicator suffix without dashes
    let m5 = PluraldawnSystemMatcher.findMatch(rawText: "Hello from [Alice]", mentions: [], members: members)
    XCTAssertEqual(m5?.id, "alice")
  }

  func testMatcherReplyMentionsAndMFM() {
    let alice = PluraldawnMember(
      id: "alice",
      name: "Alice",
      emoji: ["🌸", "[Alice]"],
      avatar: "emoji",
      font: "normal"
    )
    let members = [alice]

    // Reply with leading mentions
    let m1 = PluraldawnSystemMatcher.findMatch(
      rawText: "@user @other: 🌸 Good morning",
      mentions: [],
      members: members
    )
    XCTAssertEqual(m1?.id, "alice")

    // MFM tag wrapping prefix
    let m2 = PluraldawnSystemMatcher.findMatch(
      rawText: "$[x2 🌸 Big greeting]",
      mentions: [],
      members: members
    )
    XCTAssertEqual(m2?.id, "alice")

    // MFM tag wrapping suffix with bracketed indicator
    let m3 = PluraldawnSystemMatcher.findMatch(
      rawText: "$[x2 Hello [Alice]]",
      mentions: [],
      members: members
    )
    XCTAssertEqual(m3?.id, "alice")

    // Mention in reply list
    let mention = Mention(id: "1", username: "user", url: URL(string: "https://example.com/@user")!, acct: "user@domain.com")
    let m4 = PluraldawnSystemMatcher.findMatch(
      rawText: "Thanks @user 🌸",
      mentions: [mention],
      members: members
    )
    XCTAssertEqual(m4?.id, "alice")
  }

  func testMatcherDisambiguation() {
    let alice = PluraldawnMember(
      id: "alice",
      name: "Alice",
      emoji: ["🌸"],
      avatar: "emoji",
      font: "normal"
    )
    let bob = PluraldawnMember(
      id: "bob",
      name: "Bob",
      emoji: ["🌸"],
      avatar: "emoji",
      font: "normal"
    )
    let members = [alice, bob]

    // Both match -> ambiguous -> returns nil
    let match = PluraldawnSystemMatcher.findMatch(rawText: "🌸 Hello", mentions: [], members: members)
    XCTAssertNil(match)
  }
}
