import Foundation

let url = URL(string: "https://misskey.io/api/users/show")!
var request = URLRequest(url: url)
request.httpMethod = "POST"
request.addValue("application/json", forHTTPHeaderField: "Content-Type")
let body: [String: Any] = ["username": "admin"]
request.httpBody = try! JSONSerialization.data(withJSONObject: body)

let group = DispatchGroup()
group.enter()
let task = URLSession.shared.dataTask(with: request) { data, response, error in
    defer { group.leave() }
    if let error = error {
        print("Error:", error)
        return
    }
    guard let data = data else { return }
    print(String(data: data, encoding: .utf8)!)
}
task.resume()
group.wait()
