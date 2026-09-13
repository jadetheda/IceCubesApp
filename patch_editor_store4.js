const fs = require('fs');
let code = fs.readFileSync('Packages/StatusKit/Sources/StatusKit/Editor/EditorStore.swift', 'utf8');

code = code.replace(/NetworkClient\.FediverseClient\.ClientError/g, 'FediverseClient.ClientError');
fs.writeFileSync('Packages/StatusKit/Sources/StatusKit/Editor/EditorStore.swift', code);
