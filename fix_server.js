const fs = require('fs');
let code = fs.readFileSync('scripts/companion_server.js', 'utf8');

// Fix hash to be 7 chars
code = code.replace(
  "const hash = execSafely('git rev-parse --short HEAD', gitDir) || 'Unknown';",
  "const hash = (execSafely('git rev-parse HEAD', gitDir) || 'Unknown').substring(0, 7);"
);

fs.writeFileSync('scripts/companion_server.js', code);
console.log('Fixed');
