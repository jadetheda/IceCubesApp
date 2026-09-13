import Foundation

struct StatusData: Encodable {
    let status: String
    let visibility: String
}

var jsonValue: Encodable? = StatusData(status: "hello", visibility: "public")

if let j = jsonValue {
    let data = try? JSONEncoder().encode(j)
    if let data = data {
        print("Encoded!")
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            print(dict)
        }
    } else {
        print("Failed to encode!")
    }
}
