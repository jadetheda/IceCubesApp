import SwiftUI
import NukeUI

struct TestView: View {
    var body: some View {
        LazyImage(url: nil) { state in
            if let image = state.image {
                let _ = state.imageContainer?.image.size
                image
            } else {
                EmptyView()
            }
        }
    }
}
