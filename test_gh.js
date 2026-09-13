const fs = require('fs');
async function test() {
  const pat = process.env.GITHUB_PAT;
  if (pat) {
    try {
      const r = await fetch('https://api.github.com/repos/jadetheda/IceCubesApp/actions/runs', {
        headers: { 'Accept': 'application/vnd.github+json', 'Authorization': `Bearer ${pat}`, 'X-GitHub-Api-Version': '2022-11-28' }
      });
      const d = await r.json();
      console.log('GH latest builds:');
      console.log((d.workflow_runs || []).slice(0, 5).map(r => `${r.id} - ${r.status} - ${r.conclusion} - ${r.head_branch}`));
    } catch(e) {
      console.log(e);
    }
  }
}
test();
