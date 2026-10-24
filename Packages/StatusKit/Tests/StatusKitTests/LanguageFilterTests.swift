import Foundation
import Models
@testable import StatusKit
import XCTest

@MainActor
final class LanguageFilterTests: XCTestCase {
  func testNormalizeLanguageCode() {
    XCTAssertEqual(normalizeLanguageCode("en"), "en")
    XCTAssertEqual(normalizeLanguageCode("en-US"), "en")
    XCTAssertEqual(normalizeLanguageCode("en-GB"), "en")
    XCTAssertEqual(normalizeLanguageCode("en_US"), "en")
    XCTAssertEqual(normalizeLanguageCode("EN"), "en")
    XCTAssertEqual(normalizeLanguageCode("ja"), "ja")
    XCTAssertEqual(normalizeLanguageCode("zh-Hans"), "zh")
    XCTAssertEqual(normalizeLanguageCode("es-ES"), "es")
    XCTAssertEqual(normalizeLanguageCode("pt-BR"), "pt")
    XCTAssertEqual(normalizeLanguageCode(""), "")
  }

  func testTaggedEnglishStatusIsHidden() {
    let status = makeStatus(language: "en-US", content: "This is a test post.")
    XCTAssertTrue(isStatusHiddenByLanguage(status: status, hiddenLanguages: ["en"]))
  }

  func testTaggedEnglishGBStatusIsHidden() {
    let status = makeStatus(language: "en-GB", content: "This is a test post.")
    XCTAssertTrue(isStatusHiddenByLanguage(status: status, hiddenLanguages: ["en"]))
  }

  func testUntaggedEnglishStatusIsHiddenByLanguageDetection() {
    let status = makeStatus(
      language: nil,
      content: "Good morning everyone! Just having my morning coffee and wanted to check in."
    )
    XCTAssertTrue(isStatusHiddenByLanguage(status: status, hiddenLanguages: ["en"]))
  }

  func testEnglishStatusWithMediaAttachmentIsNotHidden() {
    let media = MediaAttachment.imageWith(url: URL(string: "https://example.com/image.png")!)
    let status = makeStatus(language: "en-US", content: "Look at this photo!", mediaAttachments: [media])
    XCTAssertFalse(isStatusHiddenByLanguage(status: status, hiddenLanguages: ["en"]))
  }

  func testOtherLanguageNotHiddenWhenOnlyEnglishIsHidden() {
    let status = makeStatus(language: "fr", content: "Bonjour à tous!")
    XCTAssertFalse(isStatusHiddenByLanguage(status: status, hiddenLanguages: ["en"]))
  }

  private func makeStatus(
    language: String?,
    content: String,
    mediaAttachments: [MediaAttachment] = []
  ) -> Status {
    let base = Status.placeholder()
    return Status(
      id: UUID().uuidString,
      content: .init(stringValue: content),
      account: base.account,
      createdAt: base.createdAt,
      editedAt: base.editedAt,
      reblog: nil,
      mediaAttachments: mediaAttachments,
      mentions: base.mentions,
      repliesCount: base.repliesCount,
      reblogsCount: base.reblogsCount,
      favouritesCount: base.favouritesCount,
      card: base.card,
      favourited: base.favourited,
      reblogged: base.reblogged,
      pinned: base.pinned,
      bookmarked: base.bookmarked,
      emojis: base.emojis,
      url: base.url,
      application: base.application,
      inReplyToId: base.inReplyToId,
      inReplyToAccountId: base.inReplyToAccountId,
      visibility: base.visibility,
      poll: base.poll,
      spoilerText: base.spoilerText,
      filtered: base.filtered,
      sensitive: base.sensitive,
      language: language,
      tags: base.tags,
      quote: nil,
      quotesCount: nil,
      quoteApproval: nil
    )
  }
}
