const fs = require('fs');
let code = fs.readFileSync('Packages/NetworkClient/Sources/NetworkClient/FediverseClient.swift', 'utf8');

// Add "pixelfed" to detectServerSoftware
if (!code.includes('name.contains("pixelfed")')) {
    code = code.replace(
        'let name = software.lowercased()',
        'let name = software.lowercased()\n      if name.contains("pixelfed") {\n        await serverSoftwareCache.set("pixelfed", for: cacheKey)\n        return "pixelfed"\n      }'
    );
}

// Add PixelfedBackend to init switch
if (!code.includes('case "pixelfed"')) {
    code = code.replace(
        'switch serverSoftware.lowercased() {',
        'switch serverSoftware.lowercased() {\n    case "pixelfed":\n        self.backend = PixelfedBackend(server: server, version: version, oauthToken: oauthToken)'
    );
}

// Add isPixelfed property
if (!code.includes('public var isPixelfed: Bool')) {
    code = code.replace(
        'public var isMisskey: Bool { backend is MisskeyBackend }',
        'public var isMisskey: Bool { backend is MisskeyBackend }\n  public var isPixelfed: Bool { backend is PixelfedBackend }'
    );
}

fs.writeFileSync('Packages/NetworkClient/Sources/NetworkClient/FediverseClient.swift', code);
console.log('Patched FediverseClient.swift');
