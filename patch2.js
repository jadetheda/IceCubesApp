const fs = require('fs');
let contents = fs.readFileSync('Packages/NetworkClient/Sources/NetworkClient/FediverseClient.swift', 'utf8');

const target = `      let (data, response) = try await URLSession.shared.data(from: url)
      if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
        await serverSoftwareCache.set("mastodon", for: cacheKey)
        return "mastodon"
      }`;

const replacement = `      let (data, response) = try await URLSession.shared.data(from: url)
      if let httpResponse = response as? HTTPURLResponse {
        if httpResponse.statusCode >= 500 {
            // Server error, do not permanently cache
            return "mastodon"
        } else if httpResponse.statusCode >= 400 {
            await serverSoftwareCache.set("mastodon", for: cacheKey)
            return "mastodon"
        }
      }`;

if (contents.includes(target)) {
    contents = contents.replace(target, replacement);
    fs.writeFileSync('Packages/NetworkClient/Sources/NetworkClient/FediverseClient.swift', contents);
    console.log("Replaced!");
} else {
    console.log("Target not found!");
}
