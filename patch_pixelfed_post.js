const fs = require('fs');
let code = fs.readFileSync('Packages/NetworkClient/Sources/NetworkClient/Backends/PixelfedBackend.swift', 'utf8');

code = code.replace(
    `} else if path.hasSuffix("/translate") && path.hasPrefix("statuses/") {
            // Pixelfed doesn't support Mastodon's translation endpoint. 
            // Throw so StatusRowViewModel falls back to DeepL/Apple Translation.
            throw FediverseClient.ClientError.unexpectedRequest
        }`,
    ``
);

const postMethod = `
    public override func post<Entity: Decodable>(endpoint: Endpoint, forceVersion: FediverseClient.Version? = nil) async throws -> Entity {
        let path = endpoint.path()
        if path.hasSuffix("/translate") && path.hasPrefix("statuses/") {
            // Pixelfed doesn't support Mastodon's translation endpoint. 
            // Throw so StatusRowViewModel falls back to DeepL/Apple Translation.
            throw FediverseClient.ClientError.unexpectedRequest
        }
        return try await super.post(endpoint: endpoint, forceVersion: forceVersion)
    }
`;

code = code.replace(
    'return try await super.get(endpoint: endpoint, forceVersion: forceVersion)\n    }',
    `return try await super.get(endpoint: endpoint, forceVersion: forceVersion)\n    }\n${postMethod}`
);

fs.writeFileSync('Packages/NetworkClient/Sources/NetworkClient/Backends/PixelfedBackend.swift', code);
console.log('Patched PixelfedBackend post');
