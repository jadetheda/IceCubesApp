const http = require('http');
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const PORT = 3000;

function execSafely(cmd, cwd) {
  try {
    return execSync(cmd, { encoding: 'utf8', cwd: cwd || '.' }).trim();
  } catch (e) {
    return '';
  }
}

const CM_CONFIG_PATH = path.join(__dirname, '../.codemagic.json');
function getCMConfig() {
  let c = { appId: '6a477de2f87e4742e68d9eaa', workflowId: 'ios-unsigned-build', token: process.env.CM_API || '' };
  try { if (fs.existsSync(CM_CONFIG_PATH)) { const p = JSON.parse(fs.readFileSync(CM_CONFIG_PATH, 'utf8')); if (p.token) c.token = p.token; } } catch(e){}
  return c;
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  const pathname = url.pathname;
  
  if (pathname === '/api/integrity/update' && req.method === 'POST') {
    res.writeHead(200, {'Content-Type': 'application/json'});
    res.end(JSON.stringify({status: 'success'}));
    return;
  }
  
  if (pathname === '/api/repo/sync' && req.method === 'POST') {
    const gitDir = fs.existsSync('ios-workspace') ? 'ios-workspace' : '.';
    const branch = execSafely('git rev-parse --abbrev-ref HEAD', gitDir) || 'main';
    execSafely(`git fetch origin && git reset --hard origin/${branch}`, gitDir);
    const heal = path.join(gitDir, 'heal_pngs.sh');
    if (fs.existsSync(heal)) execSafely('bash ' + heal, gitDir);
    res.writeHead(200, {'Content-Type': 'application/json'});
    res.end(JSON.stringify({success: true, branch}));
    return;
  }
  
  if (pathname === '/api/codemagic/trigger' && req.method === 'POST') {
    const c = getCMConfig();
    const branch = execSafely('git rev-parse --abbrev-ref HEAD', fs.existsSync('ios-workspace') ? 'ios-workspace' : '.') || 'main';
    try {
      const r = await fetch('https://api.codemagic.io/builds', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'x-auth-token': c.token },
        body: JSON.stringify({ appId: c.appId, workflowId: c.workflowId, branch })
      });
      res.writeHead(r.ok ? 200 : 400, {'Content-Type': 'application/json'});
      res.end(JSON.stringify({success: r.ok, error: r.ok ? null : await r.text()}));
    } catch (e) {
      res.writeHead(500, {'Content-Type': 'application/json'});
      res.end(JSON.stringify({success: false, error: e.message}));
    }
    return;
  }
  
  if (pathname === '/api/github/trigger' && req.method === 'POST') {
    const branch = execSafely('git rev-parse --abbrev-ref HEAD', fs.existsSync('ios-workspace') ? 'ios-workspace' : '.') || 'main';
    const pat = process.env.GITHUB_PAT;
    if (!pat) {
      res.writeHead(400, {'Content-Type': 'application/json'});
      res.end(JSON.stringify({success: false, error: 'GITHUB_PAT not set in environment'}));
      return;
    }
    try {
      const r = await fetch('https://api.github.com/repos/jadetheda/IceCubesApp/actions/workflows/multi-spec.yml/dispatches', {
        method: 'POST',
        headers: { 'Accept': 'application/vnd.github+json', 'Authorization': `Bearer ${pat}`, 'X-GitHub-Api-Version': '2022-11-28' },
        body: JSON.stringify({ ref: branch })
      });
      res.writeHead(r.ok ? 200 : 400, {'Content-Type': 'application/json'});
      res.end(JSON.stringify({success: r.ok, error: r.ok ? null : await r.text()}));
    } catch (e) {
      res.writeHead(500, {'Content-Type': 'application/json'});
      res.end(JSON.stringify({success: false, error: e.message}));
    }
    return;
  }
  
  if (pathname === '/api/builds') {
    const cm = getCMConfig();
    const pat = process.env.GITHUB_PAT;
    let cmBuilds = [], ghBuilds = [];
    
    if (cm.token) {
      try {
        const r = await fetch('https://api.codemagic.io/builds', { headers: { 'x-auth-token': cm.token } });
        if (r.ok) {
          const d = await r.json();
          cmBuilds = (d.builds || []).filter(b => b.appId === cm.appId).map(b => ({
            id: b._id,
            status: b.status,
            branch: b.branch,
            time: b.startedAt || b.createdAt,
            commit: b.commit ? (b.commit.hash || '').substring(0, 7) : '?',
            url: `https://codemagic.io/app/${cm.appId}/${cm.workflowId}/build/${b._id}`
          })).slice(0, 5);
        }
      } catch(e){}
    }
    
    if (pat) {
      try {
        const r = await fetch('https://api.github.com/repos/jadetheda/IceCubesApp/actions/runs', {
          headers: { 'Accept': 'application/vnd.github+json', 'Authorization': `Bearer ${pat}`, 'X-GitHub-Api-Version': '2022-11-28' }
        });
        if (r.ok) {
          const d = await r.json();
          ghBuilds = (d.workflow_runs || []).map(r => ({
            id: r.id,
            status: r.status === 'completed' ? r.conclusion : r.status,
            branch: r.head_branch,
            time: r.created_at,
            commit: r.head_sha.substring(0, 7),
            url: r.html_url
          })).slice(0, 5);
        }
      } catch(e){}
    }
    
    res.writeHead(200, {'Content-Type': 'application/json'});
    res.end(JSON.stringify({ codemagic: cmBuilds, github: ghBuilds, cmConfigured: !!cm.token, ghConfigured: !!pat }));
    return;
  }

  if (pathname === '/' || pathname === '/index.html') {
    const gitDir = fs.existsSync('ios-workspace') ? 'ios-workspace' : '.';
    
    let isCorrupt = false;
    let gitError = '';
    try {
      require('child_process').execSync('git status', { encoding: 'utf8', cwd: gitDir, stdio: 'pipe' });
    } catch (e) {
      isCorrupt = true;
      gitError = (e.stderr || e.message || 'Unknown Error').toString().split('\n')[0].replace(/</g, '&lt;').replace(/>/g, '&gt;');
    }
    
    const branch = execSafely('git rev-parse --abbrev-ref HEAD', gitDir) || 'Unknown';
    const hash = execSafely('git rev-parse --short HEAD', gitDir) || 'Unknown';
    const clean = isCorrupt ? false : execSafely('git status --porcelain', gitDir).length === 0;
    const commitMsg = isCorrupt ? 'Unknown' : execSafely('git log -1 --pretty=format:"%s"', gitDir) || 'No commits';
    const escapedMsg = commitMsg.replace(/</g, '&lt;').replace(/>/g, '&gt;');

    const html = `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
  <title>CI Dashboard</title>
  <style>
    :root { --bg: #09090b; --surface: #18181b; --border: #27272a; --text: #e4e4e7; --muted: #a1a1aa; --primary: #3b82f6; --success: #10b981; --danger: #ef4444; --warning: #f59e0b; }
    * { box-sizing: border-box; }
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; background: var(--bg); color: var(--text); margin: 0; padding: 16px; font-size: 14px; line-height: 1.5; -webkit-font-smoothing: antialiased; }
    header { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 20px; padding-bottom: 12px; border-bottom: 1px solid var(--border); }
    h1 { font-size: 18px; margin: 0; }
    .git-info { font-family: ui-monospace, monospace; font-size: 12px; color: var(--muted); }
    .grid { display: grid; grid-template-columns: 1fr; gap: 16px; }
    @media(min-width: 768px) { .grid { grid-template-columns: 1fr 1fr; } }
    .card { background: var(--surface); border: 1px solid var(--border); border-radius: 12px; padding: 16px; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.1); }
    .card-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
    .card-title { font-size: 16px; font-weight: 600; margin: 0; }
    button { background: var(--surface); border: 1px solid var(--border); color: var(--text); padding: 8px 12px; border-radius: 8px; font-size: 13px; font-weight: 500; cursor: pointer; transition: background 0.2s; }
    button:active { background: #3f3f46; transform: scale(0.98); }
    .btn-primary { background: var(--primary); border-color: var(--primary); color: #fff; }
    .btn-primary:active { background: #2563eb; }
    .build-list { display: flex; flex-direction: column; gap: 8px; }
    .build-item { display: flex; justify-content: space-between; align-items: center; padding: 10px; background: #27272a50; border: 1px solid var(--border); border-radius: 8px; text-decoration: none; color: inherit; }
    .build-item:active { background: #27272a; }
    .build-meta { display: flex; flex-direction: column; gap: 4px; }
    .build-hash { font-family: ui-monospace, monospace; font-size: 12px; font-weight: 600; }
    .build-branch { font-size: 11px; color: var(--muted); }
    .badge { padding: 2px 8px; border-radius: 999px; font-size: 11px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px; }
    .badge-success { background: #10b98120; color: var(--success); border: 1px solid #10b98140; }
    .badge-failure { background: #ef444420; color: var(--danger); border: 1px solid #ef444440; }
    .badge-progress { background: #3b82f620; color: var(--primary); border: 1px solid #3b82f640; }
    .badge-queued { background: #f59e0b20; color: var(--warning); border: 1px solid #f59e0b40; }
    .empty { text-align: center; color: var(--muted); padding: 20px 0; font-size: 13px; }
    .corrupt-banner { background: #7f1d1d; border: 1px solid #dc2626; color: #fca5a5; padding: 12px; border-radius: 8px; margin-bottom: 16px; font-weight: 500; font-size: 13px; text-align: center; line-height: 1.4; }
  </style>
</head>
<body>
  <header>
    <div style="flex: 1; min-width: 0; padding-right: 12px;">
      <h1>IceCubes CI Dashboard</h1>
      <div class="git-info" style="margin-top: 6px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">
        <span style="color: var(--text); font-weight: 600;">${hash}</span>${clean ? '' : '<span style="color:var(--warning);">*</span>'} &mdash; ${escapedMsg}
      </div>
    </div>
    <div style="display: flex; flex-direction: column; align-items: flex-end; gap: 8px; flex-shrink: 0;">
      <span class="badge badge-queued" style="font-family: monospace;">${branch}</span>
      <button onclick="syncRepo()" style="padding: 4px 10px; font-size: 11px;">Sync Repo</button>
    </div>
  </header>
  
  ${isCorrupt ? `<div class="corrupt-banner">⚠️ <strong>Git Repository Corrupt</strong>: Please instruct the AI to run the Git Recovery Protocol.<br/><span style="opacity: 0.8; font-size: 11px; font-family: monospace;">${gitError}</span></div>` : ''}
  
  <div class="grid">
    <div class="card">
      <div class="card-header">
        <h2 class="card-title">GitHub Actions</h2>
        <button id="gh-trigger" class="btn-primary" onclick="triggerBuild('github', 'gh-trigger')">Run Workflow</button>
      </div>
      <div id="gh-builds" class="build-list"><div class="empty">Loading...</div></div>
    </div>
    
    <div class="card">
      <div class="card-header">
        <h2 class="card-title">Codemagic</h2>
        <button id="cm-trigger" class="btn-primary" onclick="triggerBuild('codemagic', 'cm-trigger')">Start Build</button>
      </div>
      <div id="cm-builds" class="build-list"><div class="empty">Loading...</div></div>
    </div>
  </div>

  <script>
    const currentHash = '${hash}';

    async function syncRepo() {
      if(!confirm('Force sync workspace with origin (this will reset local changes)?')) return;
      try {
        await fetch('/api/repo/sync', { method: 'POST' });
        window.location.reload();
      } catch (e) { alert('Sync error: ' + e.message); }
    }
    
    async function triggerBuild(provider, btnId) {
      const btn = document.getElementById(btnId);
      const originalText = btn ? btn.textContent : '';
      if (btn) {
        btn.disabled = true;
        btn.textContent = 'Triggering...';
        btn.style.opacity = '0.7';
      }

      try {
        const res = await fetch('/api/' + provider + '/trigger', { method: 'POST' });
        const d = await res.json();
        if (d.success) { 
          if (btn) btn.textContent = 'Triggered!';
          setTimeout(fetchBuilds, 1500); setTimeout(fetchBuilds, 4000); setTimeout(fetchBuilds, 8000); 
        } else { 
          alert('Trigger failed: ' + (d.error || 'Unknown error')); 
          if (btn) { btn.disabled = false; btn.textContent = originalText; btn.style.opacity = '1'; }
        }
      } catch (e) { 
        alert('Request failed: ' + e.message); 
        if (btn) { btn.disabled = false; btn.textContent = originalText; btn.style.opacity = '1'; }
      }
    }
    
    function formatStatus(status) {
      if (!status) return 'unknown';
      let clean = status.toLowerCase();
      let css = 'badge-queued';
      if (['success', 'finished'].includes(clean)) css = 'badge-success';
      if (['failure', 'failed', 'canceled', 'cancelled', 'timeout'].includes(clean)) css = 'badge-failure';
      if (['in_progress', 'building', 'fetching', 'publishing', 'preparing'].includes(clean)) css = 'badge-progress';
      return '<span class="badge ' + css + '">' + status + '</span>';
    }
    
    function renderBuilds(builds, configured, providerName) {
      if (!configured) return '<div class="empty">' + providerName + ' credentials not configured in environment.</div>';
      if (!builds || builds.length === 0) return '<div class="empty">No recent builds found.</div>';
      
      return builds.map(function(b) {
        return '<a href="' + b.url + '" target="_blank" class="build-item">' +
          '<div class="build-meta">' +
            '<span class="build-hash">' + b.commit + '</span>' +
            '<span class="build-branch">' + b.branch + '</span>' +
          '</div>' +
          formatStatus(b.status) +
        '</a>';
      }).join('');
    }

    function updateTriggerButton(btnId, builds, configured) {
      const btn = document.getElementById(btnId);
      if (!btn) return;
      if (!configured) {
        btn.disabled = true;
        btn.style.opacity = '0.5';
        btn.style.cursor = 'not-allowed';
        btn.textContent = 'Not Configured';
        return;
      }
      if (builds && builds.length > 0) {
        const latest = builds[0];
        if (latest.commit === currentHash) {
          btn.disabled = true;
          btn.style.opacity = '0.5';
          btn.style.cursor = 'not-allowed';
          
          let clean = latest.status.toLowerCase();
          if (['success', 'finished'].includes(clean)) btn.textContent = 'Already Built';
          else if (['failure', 'failed', 'canceled', 'cancelled', 'timeout'].includes(clean)) btn.textContent = 'Build Failed';
          else btn.textContent = 'Building...';
          return;
        }
      }
      btn.disabled = false;
      btn.style.opacity = '1';
      btn.style.cursor = 'pointer';
      btn.textContent = btnId === 'gh-trigger' ? 'Run Workflow' : 'Start Build';
    }
    
    async function fetchBuilds() {
      try {
        const r = await fetch('/api/builds');
        const d = await r.json();
        
        document.getElementById('gh-builds').innerHTML = renderBuilds(d.github, d.ghConfigured, 'GitHub Actions');
        document.getElementById('cm-builds').innerHTML = renderBuilds(d.codemagic, d.cmConfigured, 'Codemagic');

        updateTriggerButton('gh-trigger', d.github, d.ghConfigured);
        updateTriggerButton('cm-trigger', d.codemagic, d.cmConfigured);

      } catch (e) {
        document.getElementById('gh-builds').innerHTML = '<div class="empty text-danger">Error fetching data</div>';
        document.getElementById('cm-builds').innerHTML = '<div class="empty text-danger">Error fetching data</div>';
      }
    }
    
    fetchBuilds();
    // Poll every 15 seconds instead of heavy UI renders
    setInterval(fetchBuilds, 15000);
  </script>
</body>
</html>`;
    res.writeHead(200, {'Content-Type': 'text/html'});
    res.end(html);
    return;
  }
  
  res.writeHead(404);
  res.end('Not Found');
});

server.listen(PORT, '0.0.0.0', () => {
  console.log('Lightweight companion server running on 0.0.0.0:' + PORT);
});
