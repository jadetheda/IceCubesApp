const fs = require('fs');
let code = fs.readFileSync('Packages/StatusKit/Sources/StatusKit/Editor/EditorView.swift', 'utf8');

code = code.replace(
    /private var pollButton: some View \{\n\s*Button \{\n\s*withAnimation/g,
    `@ViewBuilder\n    private var pollButton: some View {\n      if client.capabilities.supportsPolls {\n      Button {\n        withAnimation`
);

code = code.replace(
    /\.disabled\(store\.shouldDisablePollButton\)\n\s*\}/g,
    `.disabled(store.shouldDisablePollButton)\n      }\n    }`
);

fs.writeFileSync('Packages/StatusKit/Sources/StatusKit/Editor/EditorView.swift', code);
console.log('Patched poll button');
