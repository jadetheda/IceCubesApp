//
//  LazyResizableImage.swift
//
//
//  Created by Hugo Saynac on 28/10/2023.
//

import Env
import Nuke
import NukeUI
import SwiftUI

/// A LazyImage (Nuke) with a geometry reader under the hood in order to use a Resize Processor to optimize performances on lists.
/// This views also allows smooth resizing of the images by debouncing the update of the ImageProcessor.
public struct LazyResizableImage<Content: View>: View {
  public init(url: URL?, fallbackUrl: URL? = nil, @ViewBuilder content: @escaping (LazyImageState) -> Content)
  {
    primaryURL = url
    self.fallbackURL = fallbackUrl
    self.content = content
  }

  let primaryURL: URL?
  let fallbackURL: URL?
  @State private var currentURL: URL?
  @State private var hasFailed = false
  @State private var hasTriedFallback = false
  @State private var processorSize: CGSize?
  @State private var debouncedTask: Task<Void, Never>?

  @ViewBuilder
  private var content: (LazyImageState) -> Content

  public var body: some View {
    GeometryReader { proxy in
      let resolvedSize = quantizedProcessorSize(for: processorSize ?? proxy.size)

      LazyImage(url: currentURL ?? primaryURL) { state in
        if let error = state.error {
          if !hasFailed {
            if let fallback = fallbackURL, !hasTriedFallback, currentURL != fallback {
              DispatchQueue.main.async {
                self.currentURL = fallback
                self.hasTriedFallback = true
              }
            } else {
              DispatchQueue.main.async {
                self.hasFailed = true
                ErrorService.shared.handle(
                  title: "Image Load Error",
                  message: "Failed to load \(currentURL?.absoluteString ?? primaryURL?.absoluteString ?? "unknown"). Error: \(error.localizedDescription)",
                  showPopup: false,
                  log: true
                )
              }
            }
          }
        }
        return content(state)
      }
      .processors([.resize(size: resolvedSize)])
      .onChange(of: proxy.size, initial: true) { oldValue, newValue in
        guard newValue.width > 0, newValue.height > 0 else { return }
        let quantized = quantizedProcessorSize(for: newValue)
        if processorSize == nil {
          processorSize = quantized
        } else if oldValue != newValue, processorSize != quantized {
          updateResizing(with: quantized)
        }
      }
      .onChange(of: primaryURL) { _, newValue in
        currentURL = newValue
        hasFailed = false
        hasTriedFallback = false
      }
    }
  }

  private func quantizedProcessorSize(for size: CGSize) -> CGSize {
    guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else {
      return CGSize(width: 320, height: 320)
    }
    let step: CGFloat = 16
    let w = max(step, ceil(size.width / step) * step)
    let h = max(step, ceil(size.height / step) * step)
    return CGSize(width: w, height: h)
  }

  private func updateResizing(with newSize: CGSize) {
    debouncedTask?.cancel()
    debouncedTask = Task {
      do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
      await MainActor.run {
        processorSize = newSize
      }
    }
  }
}
