import SwiftUI

struct TestView: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                HStack(alignment: .top, spacing: 4) {
                    ForEach(0..<3, id: \.self) { _ in
                        LazyVStack {
                            Color.red
                        }
                        .frame(minWidth: 0, maxWidth: .infinity)
                    }
                }
            }
        }
    }
}
