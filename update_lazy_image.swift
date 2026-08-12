import Foundation

let path = "Packages/DesignSystem/Sources/DesignSystem/Views/LazyResizableImage.swift"
var content = try String(contentsOfFile: path, encoding: .utf8)

content = content.replacingOccurrences(of: "@State private var hasFailed = false", with: "@State private var hasFailed = false\n  @State private var hasTriedFallback = false")

let oldLogic = """
        if (state.error != nil || (!state.isLoading && state.image == nil)) && !hasFailed {
          if let fallback = fallbackURL {
            DispatchQueue.main.async {
              self.currentURL = fallback
              self.hasFailed = true
            }
          } else if let error = state.error {
"""

let newLogic = """
        if (state.error != nil || (!state.isLoading && state.image == nil)) && !hasFailed {
          if let fallback = fallbackURL, !hasTriedFallback {
            DispatchQueue.main.async {
              self.currentURL = fallback
              self.hasTriedFallback = true
            }
          } else if let error = state.error {
"""

content = content.replacingOccurrences(of: oldLogic, with: newLogic)
try content.write(toFile: path, atomically: true, encoding: .utf8)
