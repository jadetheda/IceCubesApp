const fs = require('fs');
let contents = fs.readFileSync('Packages/NetworkClient/Sources/NetworkClient/FediverseClient.swift', 'utf8');

const replacement = `  private actor ServerSoftwareCache {
    private var values: [String: String] = [:]
    init() {
      if let data = UserDefaults.standard.data(forKey: "serverSoftwareCache"),
         let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
         self.values = decoded
      }
    }
    func value(for server: String) -> String? {
      values[server]
    }
    func set(_ software: String, for server: String) {
      values[server] = software
      if let data = try? JSONEncoder().encode(values) {
        UserDefaults.standard.set(data, forKey: "serverSoftwareCache")
      }
    }
  }`;

contents = contents.replace(/private actor ServerSoftwareCache \{[\s\S]*?\n  \}/, replacement);
fs.writeFileSync('Packages/NetworkClient/Sources/NetworkClient/FediverseClient.swift', contents);
console.log("Replaced!");
