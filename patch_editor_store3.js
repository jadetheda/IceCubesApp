const fs = require('fs');
let code = fs.readFileSync('Packages/StatusKit/Sources/StatusKit/Editor/EditorStore.swift', 'utf8');

const regex = /\} else if let error = error as\? DecodingError \{\n\s*postingError = "Decoding Error: \\\(error\.localizedDescription\)"\n\s*showPostingErrorAlert = true\n\s*\}/;
const replaceWith = `} else if let error = error as? DecodingError {
          postingError = "Decoding Error: \\(error.localizedDescription)"
          showPostingErrorAlert = true
        } else {
          postingError = "Error: \\(error.localizedDescription)"
          showPostingErrorAlert = true
        }`;

if (regex.test(code)) {
    code = code.replace(regex, replaceWith);
    fs.writeFileSync('Packages/StatusKit/Sources/StatusKit/Editor/EditorStore.swift', code);
    console.log('Patched EditorStore with fallback error');
} else {
    console.log('Regex failed');
}
