import SwiftUI

struct TestView: View {
    var text: Text? { return Text("Hello") }
    var body: some View {
        VStack {
            text
                .fixedSize()
        }
    }
}
