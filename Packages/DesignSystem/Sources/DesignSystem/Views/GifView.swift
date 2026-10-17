//
//  GifView.swift
//  DesignSystem
//
//  Created by Robert George on 10/26/25.
//

import Env
import Gifu
import SwiftUI

public struct GifView: UIViewRepresentable {
  @Environment(UserPreferences.self) private var preferences
  @Environment(Theme.self) private var theme

  let animatedView = GIFImageView()
  var data: Data
  var forceAnimate: Bool

  public init(data: Data, forceAnimate: Bool = false) {
    self.data = data
    self.forceAnimate = forceAnimate
  }

  public func makeUIView(context: UIViewRepresentableContext<GifView>) -> UIView {
    let view = UIView()
    view.isUserInteractionEnabled = false

    animatedView.prepareForAnimation(withGIFData: data)
    animatedView.contentMode = .scaleAspectFit
    animatedView.isUserInteractionEnabled = false

    animatedView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(animatedView)

    if forceAnimate {
      animatedView.startAnimatingGIF()
    } else if theme.avatarAnimated {
      animatedView.startAnimatingGIF()
    }

    NSLayoutConstraint.activate([
      animatedView.topAnchor.constraint(equalTo: view.topAnchor),
      animatedView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      animatedView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      animatedView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
    ])

    return view
  }

  public func updateUIView(_ uiView: UIView, context: Context) {

  }

}
