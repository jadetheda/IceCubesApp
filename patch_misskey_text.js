const fs = require('fs');
let code = fs.readFileSync('Packages/NetworkClient/Sources/NetworkClient/Backends/MisskeyBackend.swift', 'utf8');

const regex = /if let status = dict\["status"\] as\? String \{ params\["text"\] = status \}/;
const replaceWith = `if let status = dict["status"] as? String {
                if !status.isEmpty { params["text"] = status }
            }`;

if (regex.test(code)) {
    code = code.replace(regex, replaceWith);
    fs.writeFileSync('Packages/NetworkClient/Sources/NetworkClient/Backends/MisskeyBackend.swift', code);
    console.log('Patched MisskeyBackend text');
} else {
    console.log('Regex failed');
}
