import SwiftUI

struct MyTest: View {
    var body: some View {
        ScrollView {
            LazyVStack {
                HStack(alignment: .top, spacing: 4) {
                    ForEach(0..<3, id: \.self) { i in
                        LazyVStack {
                            GeometryReader { proxy in
                                Color.red
                            }
                            .aspectRatio(1, contentMode: .fit)
                        }
                        .frame(minWidth: 0, maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity) // IF WE ADD THIS
            }
        }
    }
}
