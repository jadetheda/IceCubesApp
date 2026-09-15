import Foundation

struct Meta: Codable {
    let duration: Double?
}
struct MetaContainer: Codable {
    let original: Meta?
}
func test() {
    print("test")
}
test()
