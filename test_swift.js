const fs = require('fs');
async function run() {
  const code = `
import Foundation
let rawTitle = "Hello [iceshrimp_contexts:home,public]"
let regex = try! NSRegularExpression(pattern: "\\\\[iceshrimp_contexts:([a-zA-Z,]*)\\\\]$")
let match = regex.firstMatch(in: rawTitle, range: NSRange(rawTitle.startIndex..., in: rawTitle))
print(match != nil)
  `;
  const res = await fetch("https://godbolt.org/api/compiler/swiftc_5_10/compile", {
    method: "POST",
    headers: { "Content-Type": "application/json", "Accept": "application/json" },
    body: JSON.stringify({
      source: code,
      options: { userArguments: "", executeParameters: { args: [], stdin: "" }, compilerOptions: { executorRequest: true } }
    })
  });
  const data = await res.json();
  console.log(data);
}
run();
