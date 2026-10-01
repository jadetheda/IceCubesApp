import SwiftUI

protocol P { }
struct S: P { }

struct Modifier<T: P>: ViewModifier {
    var t: T
    func body(content: Content) -> some View {
        content
    }
}

extension View {
    func test<T: P>(_ t: T) -> some View {
        self.modifier(Modifier(t: t))
    }
}

struct TestView: View {
    let p: any P
    
    var body: some View {
        Text("Hello")
            .test(p)
    }
}
