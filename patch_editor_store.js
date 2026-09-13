const fs = require('fs');
let code = fs.readFileSync('Packages/StatusKit/Sources/StatusKit/Editor/EditorStore.swift', 'utf8');

const regex = /if let error = error as\? Models\.ServerError \{\n\s*postingError = error\.error\n\s*showPostingErrorAlert = true\n\s*\}/;
const replaceWith = `if let error = error as? Models.ServerError {
          postingError = error.error
          showPostingErrorAlert = true
        } else if let error = error as? NetworkClient.FediverseClient.ClientError {
          switch error {
          case .serverError(_, _, let message):
            postingError = message
            showPostingErrorAlert = true
          case .unexpectedRequest:
            postingError = "Unexpected request"
            showPostingErrorAlert = true
          }
        }`;

if (regex.test(code)) {
    code = code.replace(regex, replaceWith);
    fs.writeFileSync('Packages/StatusKit/Sources/StatusKit/Editor/EditorStore.swift', code);
    console.log('Patched EditorStore');
} else {
    console.log('Regex failed');
}
