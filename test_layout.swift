import SwiftUI

struct MyTest: View {
    var body: some View {
        GeometryReader { proxy in
            let columns = 3
            let spacing: CGFloat = 4
            let columnWidth = (proxy.size.width - (CGFloat(columns - 1) * spacing)) / CGFloat(columns)
            
            HStack(alignment: .top, spacing: spacing) {
                ForEach(0..<columns, id: \.self) { i in
                    LazyVStack {
                        Text("Col \(i)")
                    }
                    .frame(width: max(0, columnWidth))
                }
            }
        }
    }
}
