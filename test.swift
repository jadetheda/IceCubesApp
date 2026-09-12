import Foundation

class MockClient {
    let server = "oekakiskey.com"
    var _connections = Set<String>()
    
    func hasConnection(with url: URL) -> Bool {
        guard let host = url.host else { return false }
        let cons = _connections
        
        if let rootHost = host.split(separator: ".", maxSplits: 1).last {
            if cons.contains(host) || cons.contains(String(rootHost)) || host == server || String(rootHost) == server { return true }
        } else {
            if cons.contains(host) || host == server { return true }
        }
        
        if url.lastPathComponent.first == "@" { return true }
        if url.pathComponents.contains(where: { $0 == "tags" || $0 == "tag" }) { return true }
        
        return false
    }
}

let c = MockClient()
print(c.hasConnection(with: URL(string: "https://oekakiskey.com/@jadetheda")!))
