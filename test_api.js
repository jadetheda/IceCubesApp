const http = require('http');
const fs = require('fs');
const path = require('path');
const CM_CONFIG_PATH = path.join(__dirname, '.codemagic.json');
function getCMConfig() {
  let c = { appId: '6a477de2f87e4742e68d9eaa', workflowId: 'ios-unsigned-build', token: process.env.CM_API || '' };
  try { if (fs.existsSync(CM_CONFIG_PATH)) { const p = JSON.parse(fs.readFileSync(CM_CONFIG_PATH, 'utf8')); if (p.token) c.token = p.token; } } catch(e){}
  return c;
}

async function test() {
  const cm = getCMConfig();
  if (cm.token) {
    try {
      const r = await fetch('https://api.codemagic.io/builds', { headers: { 'x-auth-token': cm.token } });
      const d = await r.json();
      console.log('Codemagic latest builds:');
      console.log((d.builds || []).slice(0, 10).map(b => `${b._id} - ${b.status} - ${b.branch}`));
    } catch(e) {
      console.log(e);
    }
  }
}
test();
