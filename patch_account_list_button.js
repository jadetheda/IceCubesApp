const fs = require('fs');
let code = fs.readFileSync('Packages/Account/Sources/Account/Detail/AccountDetailContextMenu.swift', 'utf8');

code = code.replace(
    'if relationship?.following == true {',
    'if relationship?.following == true && !client.isPixelfed {'
);

fs.writeFileSync('Packages/Account/Sources/Account/Detail/AccountDetailContextMenu.swift', code);
console.log('Patched account list button');
