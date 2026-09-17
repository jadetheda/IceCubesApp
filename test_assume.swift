import Foundation

@MainActor
class Test {
    var item: NSObject?
    
    func setup() {
        NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] notification in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                print(self.item)
            }
        }
    }
}
