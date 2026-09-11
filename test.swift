import Foundation

let d1 = Date().timeIntervalSince1970
let s1 = "\(d1)"

let encoder = JSONEncoder()
let data = try! encoder.encode(d1)

let decoder = JSONDecoder()
let d2 = try! decoder.decode(Double.self, from: data)
let s2 = "\(d2)"

print(s1 == s2)
print("s1: \(s1)")
print("s2: \(s2)")
