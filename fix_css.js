const fs = require('fs');
let code = fs.readFileSync('scripts/companion_server.js', 'utf8');

code = code.replace(
  ".badge-progress { background: #3b82f620; color: var(--primary); border: 1px solid #3b82f640; }",
  ".badge-progress { background: #3b82f620; color: var(--primary); border: 1px solid #3b82f640; animation: pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite; }\n    @keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: .6; } }"
);

fs.writeFileSync('scripts/companion_server.js', code);
console.log('Fixed CSS');
