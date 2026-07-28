import SwiftUI
import NukeUI

struct TestView: View {
    @State private var loadedAspectRatio: CGFloat? = nil
    var body: some View {
        LazyImage(url: URL(string: "https://example.com/image.jpg")) { state in
            if let image = state.image {
                image
                    .resizable()
                    .onAppear {
                        if let size = state.imageContainer?.image.size, size.height > 0 {
                            let ratio = size.width / size.height
                            loadedAspectRatio = min(max(ratio, 0.25), 4.0)
                        }
                    }
                    .onChange(of: state.imageContainer?.image.size) { _, newSize in
                        if let size = newSize, size.height > 0 {
                            let ratio = size.width / size.height
                            loadedAspectRatio = min(max(ratio, 0.25), 4.0)
                        }
                    }
            }
        }
    }
}
