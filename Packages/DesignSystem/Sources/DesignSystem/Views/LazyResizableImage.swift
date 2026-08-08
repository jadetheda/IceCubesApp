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
  @State private var resizeProcessor: ImageProcessors.Resize?
  @State private var debouncedTask: Task<Void, Never>?

  @ViewBuilder
  private var content: (LazyImageState) -> Content

  public var body: some View {
    GeometryReader { proxy in
      LazyImage(url: currentURL ?? primaryURL) { state in
        if (state.error != nil || (!state.isLoading && state.image == nil)) && !hasFailed {
          if let fallback = fallbackURL {
            DispatchQueue.main.async {
              self.currentURL = fallback
              self.hasFailed = true
            }
          } else if let error = state.error {
            DispatchQueue.main.async {
              self.hasFailed = true
              ErrorService.shared.handle(
                title: "Image Load Error", 
                message: "Failed to load \(currentURL?.absoluteString ?? primaryURL?.absoluteString ?? "unknown"). Error: \(error.localizedDescription)", 
                showPopup: false, 
                log: true
              )
            }
          } else {
            DispatchQueue.main.async {
              self.hasFailed = true
            }
          }
        }
        return Group {
          if state.isLoading {
            content(state)
          } else if let image = state.image {
            content(state)
          } else if hasFailed || fallbackURL == nil {
            ZStack {
              RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(0.3))
              Image(systemName: "photo.badge.exclamationmark")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .foregroundColor(.gray)
            }
          } else {
            content(state)
          }
        }
      }
      .processors([resizeProcessor == nil ? .resize(size: proxy.size) : resizeProcessor!])
      .onChange(of: proxy.size, initial: true) { oldValue, newValue in
        guard oldValue != newValue else { return }
        updateResizing(with: newValue)
      }
      .onChange(of: primaryURL) { _, newValue in
        currentURL = newValue
        hasFailed = false
      }
    }
  }

  private func updateResizing(with newSize: CGSize) {
    debouncedTask?.cancel()
    debouncedTask = Task {
      do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
      await MainActor.run {
        resizeProcessor = .resize(size: newSize)
      }
    }
  }
}
