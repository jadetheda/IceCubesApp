import SwiftUI
import Observation

@Observable
class UserPrefs {
    var val: Int = 0
}

struct TestView: View {
    @Environment(UserPrefs.self) private var prefs
    
    var body: some View {
        @Bindable var prefs = prefs
        Text("Hello")
            .onAppear {
                prefs.val = 1
            }
    }
}
