const fs = require('fs');
let code = fs.readFileSync('Packages/NetworkClient/Sources/NetworkClient/Backends/PixelfedBackend.swift', 'utf8');

code = code.replace(
    'if path == "trends/statuses" {',
    `if path == "trends/tags" || path == "trends/links" {
            // Pixelfed doesn't support tags or links trending in the Mastodon format, return empty array to prevent UI errors
            let empty: [String] = [] // The caller expects an array of tags or links, but returning empty array JSON is safe
            let data = try! JSONEncoder().encode(empty)
            return try JSONDecoder().decode(Entity.self, from: data)
        } else if path == "trends/statuses" {`
);

fs.writeFileSync('Packages/NetworkClient/Sources/NetworkClient/Backends/PixelfedBackend.swift', code);
console.log('Patched PixelfedBackend trends');
