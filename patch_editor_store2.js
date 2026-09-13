const fs = require('fs');
let code = fs.readFileSync('Packages/StatusKit/Sources/StatusKit/Editor/EditorStore.swift', 'utf8');

const regex = /case \.unexpectedRequest:\n\s*postingError = "Unexpected request"\n\s*showPostingErrorAlert = true\n\s*\}/;
const replaceWith = `case .unexpectedRequest:
            postingError = "Unexpected request"
            showPostingErrorAlert = true
          }
        } else if let error = error as? DecodingError {
          postingError = "Decoding Error: \\(error.localizedDescription)"
          showPostingErrorAlert = true
        }`;

if (regex.test(code)) {
    code = code.replace(regex, replaceWith);
    fs.writeFileSync('Packages/StatusKit/Sources/StatusKit/Editor/EditorStore.swift', code);
    console.log('Patched EditorStore with DecodingError');
} else {
    console.log('Regex failed');
}
