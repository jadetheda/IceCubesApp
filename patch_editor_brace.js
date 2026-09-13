const fs = require('fs');
let code = fs.readFileSync('Packages/StatusKit/Sources/StatusKit/Editor/EditorStore.swift', 'utf8');

code = code.replace(
    /showPostingErrorAlert = true\n\s*\}\n\s*\}\n\s*if let postError = error as\? PostError/,
    `showPostingErrorAlert = true
        }
        if let postError = error as? PostError`
);

fs.writeFileSync('Packages/StatusKit/Sources/StatusKit/Editor/EditorStore.swift', code);
console.log('Fixed EditorStore extra brace');
