import SwiftUI
@Observable class Test {
    var val = 0
}
struct ContentView: View {
    @Environment(Test.self) var test
    private var b: Binding<Int> {
        Binding(get: { test.val }, set: { test.val = $0 })
    }
    var body: some View {
        Text("Hi")
    }
}
