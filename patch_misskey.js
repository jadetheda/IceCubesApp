const fs = require('fs');
let code = fs.readFileSync('Packages/NetworkClient/Sources/NetworkClient/Backends/MisskeyBackend.swift', 'utf8');

const regex = /if let visibility = dict\["visibility"\] as\? String \{ params\["visibility"\] = visibility \}/;
const replaceWith = `if let visibility = dict["visibility"] as? String {
                var misskeyVis = visibility
                if visibility == "unlisted" { misskeyVis = "home" }
                else if visibility == "private" { misskeyVis = "followers" }
                else if visibility == "direct" { misskeyVis = "specified" }
                params["visibility"] = misskeyVis
            }
            if let poll = dict["poll"] as? [String: Any] {
                var misskeyPoll: [String: Any] = [:]
                if let options = poll["options"] as? [String] { misskeyPoll["choices"] = options }
                if let multiple = poll["multiple"] as? Bool { misskeyPoll["multiple"] = multiple }
                if let expiresIn = poll["expires_in"] as? Int { misskeyPoll["expiredAfter"] = expiresIn * 1000 }
                params["poll"] = misskeyPoll
            }`;

if (regex.test(code)) {
    code = code.replace(regex, replaceWith);
    fs.writeFileSync('Packages/NetworkClient/Sources/NetworkClient/Backends/MisskeyBackend.swift', code);
    console.log('Patched MisskeyBackend visibility and poll mapping');
} else {
    console.log('Regex failed');
}
