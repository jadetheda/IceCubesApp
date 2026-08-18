import SwiftUI

struct TestView: View {
    var body: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(maxWidth: .infinity)
                .overlay(Text("A"))
            
            Color.clear
                .frame(width: 40)
                .frame(maxWidth: .infinity)
                .overlay(Text("B"))
            
            Color.clear
                .frame(width: 40)
                .frame(maxWidth: .infinity)
                .overlay(Text("C"))
        }
        .frame(width: 300, height: 100)
    }
}
