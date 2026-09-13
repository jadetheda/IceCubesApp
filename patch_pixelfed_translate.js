const fs = require('fs');
let code = fs.readFileSync('Packages/NetworkClient/Sources/NetworkClient/Backends/PixelfedBackend.swift', 'utf8');

code = code.replace(
    'return try await super.get(endpoint: endpoint, forceVersion: forceVersion)',
    `if path.hasSuffix("/translate") && path.hasPrefix("statuses/") {
            // Pixelfed doesn't support Mastodon's translation endpoint. 
            // Throw so StatusRowViewModel falls back to DeepL/Apple Translation.
            throw FediverseClient.ClientError.unexpectedRequest
        }
        
        return try await super.get(endpoint: endpoint, forceVersion: forceVersion)`
);

fs.writeFileSync('Packages/NetworkClient/Sources/NetworkClient/Backends/PixelfedBackend.swift', code);
console.log('Patched PixelfedBackend translate');
