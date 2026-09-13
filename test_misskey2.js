const https = require("https");
const data = JSON.stringify({ uri: "https://misskey.io/notes/9y5xix7yq0s9078z" });
const req = https.request({
  hostname: "misskey.io",
  path: "/api/ap/show",
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    "Content-Length": data.length
  }
}, res => {
  let body = "";
  res.on("data", d => body += d);
  res.on("end", () => console.log(body.substring(0, 500)));
});
req.write(data);
req.end();
