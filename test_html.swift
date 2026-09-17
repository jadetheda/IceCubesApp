import Foundation
import SwiftSoup

let html = "<a href=\"https://iceshrimp.net/tags/test\">#test</a>"
let doc = try! SwiftSoup.parse(html)
let paras = try! doc.select("p:not(.quote-inline)")
print("Paragraphs found: \(paras.array().count)")
