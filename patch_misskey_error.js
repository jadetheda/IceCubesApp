const fs = require('fs');
let code = fs.readFileSync('Packages/NetworkClient/Sources/NetworkClient/Backends/MisskeyBackend.swift', 'utf8');

code = code.replace(
    /code: apiError\?\.code,\n\s*message: apiError\?\.message \?\? fallback\)/,
    `code: apiError?.error?.code ?? apiError?.code,\n                message: apiError?.error?.message ?? apiError?.message ?? fallback)`
);

code = code.replace(
    /private struct MisskeyAPIError: Decodable \{\n\s*let message: String\?\n\s*let code: String\?\n\s*\}/,
    `private struct MisskeyAPIError: Decodable {
        struct ErrorDetails: Decodable {
            let message: String?
            let code: String?
        }
        let error: ErrorDetails?
        let message: String?
        let code: String?
    }`
);

fs.writeFileSync('Packages/NetworkClient/Sources/NetworkClient/Backends/MisskeyBackend.swift', code);
console.log('Patched MisskeyAPIError');
