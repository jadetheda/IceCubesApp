const fs = require('fs');
let code = fs.readFileSync('scripts/companion_server.js', 'utf8');

code = code.replace(
  "setTimeout(fetchBuilds, 1000);",
  "setTimeout(fetchBuilds, 1500); setTimeout(fetchBuilds, 4000); setTimeout(fetchBuilds, 8000);"
);

fs.writeFileSync('scripts/companion_server.js', code);
console.log('Fixed trigger polling');
