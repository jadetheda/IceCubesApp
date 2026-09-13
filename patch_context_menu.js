const fs = require('fs');
let code = fs.readFileSync('Packages/StatusKit/Sources/StatusKit/Row/Subviews/StatusRowContextMenu.swift', 'utf8');

if (code.includes('} else if client.isMisskey {')) {
    code = code.replace(
        '} else if client.isMisskey {',
        '} else if client.isMisskey || client.isPixelfed {'
    );
    fs.writeFileSync('Packages/StatusKit/Sources/StatusKit/Row/Subviews/StatusRowContextMenu.swift', code);
    console.log('Patched StatusRowContextMenu');
} else {
    console.log('Could not find client.isMisskey in StatusRowContextMenu.swift');
}
