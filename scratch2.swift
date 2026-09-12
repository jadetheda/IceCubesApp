import Foundation

let str = "2021-09-08T00:54:33.456Z"

let formatter1 = ISO8601DateFormatter()
let date1 = formatter1.date(from: str)
print("Default formatter: \(String(describing: date1))")

let formatter2 = ISO8601DateFormatter()
formatter2.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
let date2 = formatter2.date(from: str)
print("Fractional formatter: \(String(describing: date2))")
