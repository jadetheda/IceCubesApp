const http = require('http');
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const PORT = 3000;

// Helper to get git info
function getGitInfo() {
  try {
    const gitDir = fs.existsSync('ios-workspace') ? 'ios-workspace' : '.';
    const branch = execSync('git rev-parse --abbrev-ref HEAD', { encoding: 'utf8', cwd: gitDir }).trim();
    const hash = execSync('git rev-parse HEAD', { encoding: 'utf8', cwd: gitDir }).trim();
    const shortHash = hash.substring(0, 7);
    const author = execSync('git log -1 --pretty=format:"%an"', { encoding: 'utf8', cwd: gitDir }).trim();
    const relativeTime = execSync('git log -1 --pretty=format:"%ar"', { encoding: 'utf8', cwd: gitDir }).trim();
    const subject = execSync('git log -1 --pretty=format:"%s"', { encoding: 'utf8', cwd: gitDir }).trim();
    
    // Recent commits
    const recentRaw = execSync('git log -5 --pretty=format:"%h|%s|%an|%ar"', { encoding: 'utf8', cwd: gitDir }).trim();
    const recentCommits = recentRaw ? recentRaw.split('\n').map(line => {
      const parts = line.split('|');
      return { hash: parts[0] || '', subject: parts[1] || '', author: parts[2] || '', relativeTime: parts[3] || '' };
    }) : [];

    // Working tree status
    const statusRaw = execSync('git status --porcelain', { encoding: 'utf8', cwd: gitDir }).trim();
    const isClean = statusRaw.length === 0;
    const modifiedCount = isClean ? 0 : statusRaw.split('\n').length;

    return { branch, hash, shortHash, author, relativeTime, subject, recentCommits, isClean, modifiedCount };
  } catch (e) {
    return { branch: 'main', hash: 'Unknown', shortHash: 'Unknown', author: 'Unknown', relativeTime: 'Unknown', subject: 'Error reading git history', recentCommits: [], isClean: true, modifiedCount: 0 };
  }
}

// Helper to get last few entries of activity log from memory.md
function getActivityLog() {
  try {
    let memoryPath = 'memory.md';
    if (!fs.existsSync(memoryPath) && fs.existsSync('ios-workspace/' + memoryPath)) {
      memoryPath = 'ios-workspace/' + memoryPath;
    }
    if (!fs.existsSync(memoryPath)) return [];
    const content = fs.readFileSync(memoryPath, 'utf8');
    const lines = content.split('\n');
    const logSectionStart = lines.findIndex(l => l.includes('## 🪵 Activity Log') || l.includes('## Activity Log'));
    
    if (logSectionStart === -1) return [];
    
    // Grab bullet points below logSectionStart
    const logLines = [];
    let currentBlock = null;
    
    for (let i = logSectionStart + 1; i < lines.length; i++) {
      const line = lines[i];
      if (line.startsWith('## ')) break; // Stop at next H2 section
      
      const mainBulletMatch = line.match(/^-\s+(\d{4}-\d{2}-\d{2}[T\d:\-Z]+)?:\s*\*\*(.*?)\*\*/);
      if (mainBulletMatch) {
        if (currentBlock) logLines.push(currentBlock);
        currentBlock = {
          date: mainBulletMatch[1] || 'Recent',
          title: mainBulletMatch[2],
          details: []
        };
      } else if (currentBlock && line.trim().startsWith('-')) {
        currentBlock.details.push(line.replace(/^\s*-\s*/, '').trim());
      } else if (currentBlock && line.trim().length > 0 && !line.startsWith('---')) {
        currentBlock.details.push(line.trim());
      }
    }
    if (currentBlock) logLines.push(currentBlock);
    
    return logLines.slice(0, 5); // Return last 5 entries
  } catch (e) {
    return [];
  }
}

// Helper to get alternate icons list
function getAlternateIcons() {
  try {
    let dir = 'IceCubesApp/Assets.xcassets';
    if (!fs.existsSync(dir) && fs.existsSync('ios-workspace/' + dir)) {
      dir = 'ios-workspace/' + dir;
    }
    if (!fs.existsSync(dir)) return [];
    const files = fs.readdirSync(dir);
    
    // Filter folders matching AppIconAlternate* and sort numerically
    const appiconsets = files
      .filter(f => f.startsWith('AppIconAlternate') && f.endsWith('.appiconset'))
      .map(f => {
        const idStr = f.replace('AppIconAlternate', '').replace('.appiconset', '');
        return {
          id: parseInt(idStr, 10),
          folder: f,
          name: `Alternate ${idStr}`
        };
      })
      .filter(x => !isNaN(x.id))
      .sort((a, b) => a.id - b.id);
      
    return appiconsets;
  } catch (e) {
    return [];
  }
}

// Find a PNG inside an appiconset folder
function findPngInFolder(folderName) {
  try {
    let baseDir = 'IceCubesApp/Assets.xcassets';
    if (!fs.existsSync(baseDir) && fs.existsSync('ios-workspace/' + baseDir)) {
      baseDir = 'ios-workspace/' + baseDir;
    }
    const folderPath = path.join(baseDir, folderName);
    if (!fs.existsSync(folderPath)) return null;
    
    const files = fs.readdirSync(folderPath);
    const png = files.find(f => f.toLowerCase().endsWith('.png'));
    if (png) return path.join(folderPath, png);
    
    return null;
  } catch (e) {
    return null;
  }
}

const CONFIG_PATH = path.join(__dirname, '../.codemagic.json');

function getCodemagicConfig() {
  let config = {
    appId: '',
    workflowId: 'ios-unsigned-build',
    token: ''
  };
  try {
    if (fs.existsSync(CONFIG_PATH)) {
      config = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));
    }
  } catch (e) {
    console.error('Error reading .codemagic.json:', e);
  }
  // Fallback to CM_API env var if token is missing
  if (!config.token && process.env.CM_API) {
    config.token = process.env.CM_API;
  }
  return config;
}

function saveCodemagicConfig(config) {
  try {
    fs.writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2), 'utf8');
    return true;
  } catch (e) {
    console.error('Error writing .codemagic.json:', e);
    return false;
  }
}

async function triggerCodemagicBuild() {
  const config = getCodemagicConfig();
  if (!config.appId || !config.token) {
    return { success: false, error: 'App ID or API Token is not configured' };
  }
  
  const git = getGitInfo();
  const branch = git.branch || 'main';
  
  try {
    const response = await fetch('https://api.codemagic.io/builds', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-auth-token': config.token
      },
      body: JSON.stringify({
        appId: config.appId,
        workflowId: config.workflowId,
        branch: branch
      })
    });
    
    if (!response.ok) {
      const errText = await response.text();
      return { success: false, error: `Codemagic API error: ${response.status} - ${errText}` };
    }
    
    const data = await response.json();
    return { success: true, data };
  } catch (e) {
    return { success: false, error: e.message };
  }
}

function parseJsonBody(req) {
  return new Promise((resolve, reject) => {
    let body = '';
    req.on('data', chunk => {
      body += chunk.toString();
    });
    req.on('end', () => {
      try {
        resolve(body ? JSON.parse(body) : {});
      } catch (e) {
        reject(e);
      }
    });
    req.on('error', err => reject(err));
  });
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  const pathname = url.pathname;

  // 1. GET /api/icon/:id
  if (pathname.startsWith('/api/icon/')) {
    const id = pathname.replace('/api/icon/', '');
    const folderName = `AppIconAlternate${id}.appiconset`;
    const imagePath = findPngInFolder(folderName);
    
    if (imagePath && fs.existsSync(imagePath)) {
      res.writeHead(200, { 'Content-Type': 'image/png', 'Cache-Control': 'public, max-age=3600' });
      fs.createReadStream(imagePath).pipe(res);
    } else {
      // Fallback placeholder
      res.writeHead(404, { 'Content-Type': 'text/plain' });
      res.end('Icon not found');
    }
    return;
  }

  // 2. POST /api/integrity/update
  if (pathname === '/api/integrity/update' && req.method === 'POST') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'success', message: 'Integrity manifest successfully updated' }));
    return;
  }

  // 3. GET /api/status
  if (pathname === '/api/status') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      git: getGitInfo(),
      activity: getActivityLog(),
      iconsCount: getAlternateIcons().length
    }));
    return;
  }

  // 4. GET /api/codemagic/config
  if (pathname === '/api/codemagic/config' && req.method === 'GET') {
    const config = getCodemagicConfig();
    const sanitizedConfig = {
      appId: config.appId,
      workflowId: config.workflowId,
      hasToken: !!config.token
    };
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(sanitizedConfig));
    return;
  }

  // 5. POST /api/codemagic/config
  if (pathname === '/api/codemagic/config' && req.method === 'POST') {
    parseJsonBody(req).then(body => {
      const config = getCodemagicConfig();
      if (body.appId !== undefined) config.appId = body.appId;
      if (body.workflowId !== undefined) config.workflowId = body.workflowId;
      if (body.token !== undefined) {
        if (body.token !== '********') {
          config.token = body.token;
        }
      }
      
      if (saveCodemagicConfig(config)) {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ status: 'success' }));
      } else {
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ status: 'error', message: 'Failed to write config' }));
      }
    }).catch(err => {
      res.writeHead(400, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ status: 'error', message: err.message }));
    });
    return;
  }

  // 6. POST /api/codemagic/trigger
  if (pathname === '/api/codemagic/trigger' && req.method === 'POST') {
    triggerCodemagicBuild().then(result => {
      res.writeHead(result.success ? 200 : 400, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(result));
    }).catch(err => {
      res.writeHead(500, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ success: false, error: err.message }));
    });
    return;
  }

  // 6a. GET /api/codemagic/builds
  if (pathname === '/api/codemagic/builds' && req.method === 'GET') {
    const config = getCodemagicConfig();
    const token = config.token;
    if (!token) {
      res.writeHead(400, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Codemagic API token not configured' }));
      return;
    }
    
    fetch('https://api.codemagic.io/builds', {
      headers: { 'x-auth-token': token }
    })
    .then(r => r.json())
    .then(data => {
      let builds = data.builds || [];
      if (config.appId) {
        builds = builds.filter(b => b.appId === config.appId);
      }
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ builds }));
    })
    .catch(err => {
      res.writeHead(500, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: err.message }));
    });
    return;
  }

  // 6b. GET /api/codemagic/builds/:buildId/logs
  const buildLogsMatch = pathname.match(/^\/api\/codemagic\/builds\/([a-f0-9]{24})\/logs$/);
  if (buildLogsMatch && req.method === 'GET') {
    const buildId = buildLogsMatch[1];
    const config = getCodemagicConfig();
    const token = config.token;
    if (!token) {
      res.writeHead(400, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Codemagic API token not configured' }));
      return;
    }
    
    fetch(`https://api.codemagic.io/builds/${buildId}`, {
      headers: { 'x-auth-token': token }
    })
    .then(r => r.json())
    .then(async data => {
      if (!data || !data.build) {
        res.writeHead(404, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Build not found on Codemagic' }));
        return;
      }
      
      const build = data.build;
      const failedSteps = [];
      
      if (Array.isArray(build.buildActions)) {
        for (const action of build.buildActions) {
          if (action.status === 'failed') {
            const stepName = action.name || 'Unknown Step';
            const logUrls = [];
            
            if (action.logUrl) {
              logUrls.push(action.logUrl);
            }
            if (Array.isArray(action.subactions)) {
              for (const sub of action.subactions) {
                if (sub.logUrl) {
                  logUrls.push(sub.logUrl);
                }
              }
            }
            
            let logContent = '';
            for (const logUrl of logUrls) {
              try {
                const logRes = await fetch(logUrl, {
                  headers: { 'x-auth-token': token }
                });
                if (logRes.ok) {
                  const logText = await logRes.text();
                  logContent += (logContent ? '\n\n' : '') + logText;
                }
              } catch (logErr) {
                console.error(`Error fetching log from ${logUrl}:`, logErr);
              }
            }
            
            const cleanLog = logContent
              .replace(/<span[^>]*>/g, '')
              .replace(/<\/span>/g, '')
              .replace(/&lt;/g, '<')
              .replace(/&gt;/g, '>')
              .replace(/&amp;/g, '&');
              
            failedSteps.push({
              name: stepName,
              log: cleanLog || 'No log content available.'
            });
          }
        }
      }
      
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        buildId,
        status: build.status,
        index: build.index,
        failedSteps
      }));
    })
    .catch(err => {
      res.writeHead(500, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: err.message }));
    });
    return;
  }

  // 7. GET /
  if (pathname === '/' || pathname === '/index.html') {
    const git = getGitInfo();
    const config = getCodemagicConfig();

    let badgeHtml = '';
    let triggerButtonHtml = '';
    let headerIndicatorHtml = '';

    if (config.appId) {
      const cacheBuster = Date.now();
      badgeHtml = `
        <a href="https://codemagic.io/app/${config.appId}/${config.workflowId}/latest_build" target="_blank" class="shrink-0 flex items-center">
          <img src="https://api.codemagic.io/apps/${config.appId}/${config.workflowId}/status_badge.svg?cachebuster=${cacheBuster}" alt="Codemagic build status" class="h-5" />
        </a>
      `;
      
      triggerButtonHtml = config.token ? `
        <button onclick="triggerBuild()" id="triggerBtn" class="flex items-center gap-1.5 text-xs font-mono font-semibold px-3.5 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-500 active:scale-95 text-white transition-all shadow-md shadow-emerald-900/20">
          <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z"></path><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
          Trigger Build
        </button>
      ` : `
        <a href="https://codemagic.io/app/${config.appId}/${config.workflowId}/latest_build" target="_blank" class="flex items-center gap-1.5 text-xs font-mono font-semibold px-3.5 py-1.5 rounded-lg bg-zinc-800 hover:bg-zinc-700 active:scale-95 text-zinc-200 hover:text-white transition-all">
          View Builds
          <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"></path></svg>
        </a>
      `;

      headerIndicatorHtml = `
        <a href="https://codemagic.io/app/${config.appId}/${config.workflowId}/latest_build" target="_blank" class="flex items-center gap-2 text-xs font-mono px-3 py-1 rounded-full border border-zinc-800 hover:bg-zinc-800/50 transition-colors">
          <img src="https://api.codemagic.io/apps/${config.appId}/${config.workflowId}/status_badge.svg?cachebuster=${cacheBuster}" alt="Codemagic" class="h-3.5" />
        </a>
      `;
    } else {
      badgeHtml = `
        <span class="text-xs font-mono text-zinc-500 bg-zinc-950/40 px-2.5 py-1 rounded-lg border border-zinc-800/40">Not Configured</span>
      `;
      triggerButtonHtml = `
        <button onclick="toggleConfigModal()" class="flex items-center gap-1.5 text-xs font-mono font-semibold px-3.5 py-1.5 rounded-lg bg-blue-600 hover:bg-blue-500 text-white transition-all">
          Configure
        </button>
      `;
      headerIndicatorHtml = `
        <button onclick="toggleConfigModal()" class="flex items-center gap-1.5 text-xs font-mono px-3 py-1 rounded-full border border-zinc-800 hover:bg-zinc-800/50 text-zinc-400 transition-colors">
          <span class="w-2 h-2 rounded-full bg-zinc-600 animate-pulse"></span>
          <span>CI Setup</span>
        </button>
      `;
    }

    const recentCommitsHtml = (git.recentCommits || []).map(c => `
      <div class="flex items-center justify-between py-2 border-b border-zinc-800/40 last:border-0 gap-3">
        <div class="flex items-center gap-2.5 min-w-0">
          <span class="text-emerald-400 font-medium shrink-0 font-mono text-[11px]">${c.hash}</span>
          <span class="text-zinc-300 truncate text-xs">${c.subject}</span>
        </div>
        <span class="text-zinc-500 text-[11px] shrink-0 font-mono">${c.relativeTime}</span>
      </div>
    `).join('') || '<div class="text-zinc-500 text-xs">No commit history available</div>';

    const html = `<!DOCTYPE html>
<html lang="en" class="dark">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Repository State | Ice Cubes</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <style>
    @import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;600&family=Plus+Jakarta+Sans:wght@400;500;600;700&display=swap');
    body {
      font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, sans-serif;
      background-color: #08090c;
      color: #e4e4e7;
    }
    .font-mono {
      font-family: 'JetBrains Mono', monospace;
    }
  </style>
</head>
<body class="min-h-screen bg-[#08090c] text-zinc-200 antialiased selection:bg-zinc-800 selection:text-zinc-100 flex flex-col justify-center items-center px-4 py-8 md:py-12">
  <div class="w-full max-w-2xl space-y-5">
    <!-- Header bar -->
    <div class="flex items-center justify-between px-1">
      <div class="flex items-center gap-2.5">
        <span class="w-2 h-2 bg-emerald-500 rounded-full animate-pulse"></span>
        <span class="text-xs font-semibold text-zinc-400 tracking-wide uppercase">Repository State</span>
      </div>
      <div class="flex items-center gap-3">
        ${headerIndicatorHtml}
        <a href="https://github.com/jadetheda/icecubesapp" target="_blank" class="text-xs text-zinc-400 hover:text-white transition-colors flex items-center gap-1 font-mono">
          GitHub <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"></path></svg>
        </a>
      </div>
    </div>

    <!-- Main Card -->
    <div class="bg-zinc-900/90 rounded-2xl border border-zinc-800/80 p-6 md:p-8 shadow-2xl space-y-6">
      <!-- Active Branch & Status -->
      <div class="flex items-center justify-between border-b border-zinc-800/80 pb-5">
        <div>
          <div class="text-[11px] font-semibold uppercase text-zinc-500 tracking-wider mb-1">Active Branch</div>
          <div class="text-base md:text-lg font-bold text-zinc-100 font-mono flex items-center gap-2">
            <svg class="w-4 h-4 text-emerald-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4"></path></svg>
            ${git.branch}
          </div>
        </div>
        <div class="text-right">
          <span class="inline-flex items-center gap-1.5 text-xs font-mono px-3 py-1 rounded-full border ${git.isClean ? 'bg-emerald-950/50 text-emerald-400 border-emerald-800/50' : 'bg-amber-950/50 text-amber-400 border-amber-800/50'}">
            <span class="w-1.5 h-1.5 rounded-full ${git.isClean ? 'bg-emerald-400' : 'bg-amber-400'}"></span>
            ${git.isClean ? 'Working Tree Clean' : `${git.modifiedCount} Uncommitted Files`}
          </span>
        </div>
      </div>

      <!-- Current Commit Summary -->
      <div class="space-y-3">
        <div class="text-[11px] font-semibold uppercase text-zinc-500 tracking-wider">HEAD Commit</div>
        <h2 class="text-sm md:text-base font-semibold text-zinc-100 leading-snug">${git.subject}</h2>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-3 bg-zinc-950/70 p-3.5 rounded-xl border border-zinc-800/60 font-mono text-xs">
          <div class="min-w-0">
            <div class="text-[10px] text-zinc-500 uppercase tracking-wider mb-0.5">Hash</div>
            <div class="text-zinc-200 select-all font-medium truncate">${git.hash}</div>
          </div>
          <div>
            <div class="text-[10px] text-zinc-500 uppercase tracking-wider mb-0.5">Author</div>
            <div class="text-zinc-300 font-medium truncate">${git.author}</div>
          </div>
          <div>
            <div class="text-[10px] text-zinc-500 uppercase tracking-wider mb-0.5">Timestamp</div>
            <div class="text-zinc-300 font-medium truncate">${git.relativeTime}</div>
          </div>
        </div>
      </div>

      <!-- Continuous Integration (Codemagic) -->
      <div class="border-t border-zinc-800/80 pt-5 space-y-4">
        <div class="flex items-center justify-between">
          <div class="text-[11px] font-semibold uppercase text-zinc-500 tracking-wider">Continuous Integration</div>
          <button onclick="toggleConfigModal()" class="text-xs text-zinc-400 hover:text-white font-mono flex items-center gap-1 transition-colors">
            <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"></path><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path></svg>
            Settings
          </button>
        </div>
        
        <div class="bg-zinc-950/40 rounded-xl border border-zinc-800/50 p-4 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
          <div class="flex items-center gap-3">
            <div class="p-2 bg-blue-950/40 text-blue-400 rounded-lg border border-blue-900/40">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A2 2 0 009 10.172V5L8 4z"></path></svg>
            </div>
            <div>
              <div class="text-xs font-semibold text-zinc-300">Build Workflow: <span class="font-mono text-blue-400">${config.workflowId || 'ios-unsigned-build'}</span></div>
              <div class="text-[11px] text-zinc-500 mt-0.5">Automated building & packaging on Codemagic</div>
            </div>
          </div>
          
          <div class="flex items-center gap-3 w-full sm:w-auto justify-between sm:justify-end">
            <!-- Badge -->
            ${badgeHtml}
            
            <!-- Action Button -->
            ${triggerButtonHtml}
          </div>
        </div>
      </div>

      <!-- Codemagic Build History -->
      ${config.appId ? `
      <div id="buildHistorySection" class="border-t border-zinc-800/80 pt-5 space-y-3">
        <div class="flex items-center justify-between">
          <div class="text-[11px] font-semibold uppercase text-zinc-500 tracking-wider">Recent Builds</div>
          <button onclick="loadBuildHistory()" class="text-[10px] text-zinc-400 hover:text-white font-mono flex items-center gap-1 transition-colors">
            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 1121.21 8H17"></path></svg>
            Refresh
          </button>
        </div>
        
        <div id="buildsContainer" class="space-y-2.5">
          <!-- Loading skeleton -->
          <div class="animate-pulse space-y-2">
            <div class="h-12 bg-zinc-950/40 rounded-xl border border-zinc-800/40"></div>
            <div class="h-12 bg-zinc-950/40 rounded-xl border border-zinc-800/40"></div>
          </div>
        </div>
      </div>
      ` : ''}

      <!-- Recent Commit Log -->
      <div class="pt-1">
        <div class="text-[11px] font-semibold uppercase text-zinc-500 tracking-wider mb-2.5">Recent Commits</div>
        <div class="bg-zinc-950/40 rounded-xl border border-zinc-800/50 p-3 font-mono text-xs space-y-0.5">
          ${recentCommitsHtml}
        </div>
      </div>
    </div>

    <!-- Footer -->
    <div class="text-center text-[11px] text-zinc-600 font-mono">
      Ice Cubes iOS Companion Server &bull; Port 3000
    </div>
  </div>

  <!-- Config Modal -->
  <div id="configModal" class="hidden fixed inset-0 bg-black/70 backdrop-blur-sm flex items-center justify-center p-4 z-50">
    <div class="bg-zinc-900 border border-zinc-800 w-full max-w-md rounded-2xl p-6 shadow-2xl space-y-4">
      <div class="flex items-center justify-between border-b border-zinc-800 pb-3">
        <h3 class="text-sm font-bold text-zinc-100 flex items-center gap-2">
          <svg class="w-4 h-4 text-blue-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"></path><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path></svg>
          Codemagic Settings
        </h3>
        <button onclick="toggleConfigModal()" class="text-zinc-500 hover:text-zinc-300 transition-colors">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>
        </button>
      </div>
      
      <form id="configForm" onsubmit="saveConfig(event)" class="space-y-4 text-xs">
        <div class="space-y-1">
          <label class="block font-semibold text-zinc-400">Application ID</label>
          <input type="text" id="appIdInput" value="${config.appId || ''}" placeholder="e.g. 64b3ef... (from your Codemagic app URL)" class="w-full bg-zinc-950 border border-zinc-800 rounded-lg px-3 py-2 text-zinc-100 focus:outline-none focus:border-blue-500 font-mono" required />
          <span class="text-[10px] text-zinc-500 block">Find this in your browser URL on Codemagic: codemagic.io/app/&lt;app-id&gt;</span>
        </div>
        
        <div class="space-y-1">
          <label class="block font-semibold text-zinc-400">Workflow ID</label>
          <input type="text" id="workflowIdInput" value="${config.workflowId || 'ios-unsigned-build'}" placeholder="e.g. ios-unsigned-build" class="w-full bg-zinc-950 border border-zinc-800 rounded-lg px-3 py-2 text-zinc-100 focus:outline-none focus:border-blue-500 font-mono" required />
          <span class="text-[10px] text-zinc-500 block">The workflow key defined in your codemagic.yaml</span>
        </div>
        
        <div class="space-y-1">
          <label class="block font-semibold text-zinc-400">Personal Access Token (Optional)</label>
          <input type="password" id="tokenInput" value="${config.token ? '********' : ''}" placeholder="${config.token ? 'Keep existing secret token' : 'e.g. cm_pat_...'}" class="w-full bg-zinc-950 border border-zinc-800 rounded-lg px-3 py-2 text-zinc-100 focus:outline-none focus:border-blue-500 font-mono" />
          <span class="text-[10px] text-zinc-500 block">Needed only to trigger builds. Get it in User Settings &gt; Integrations &gt; Codemagic API.</span>
        </div>
        
        <div class="flex items-center justify-end gap-3 pt-2">
          <button type="button" onclick="toggleConfigModal()" class="px-4 py-2 border border-zinc-800 hover:bg-zinc-800 rounded-lg font-medium text-zinc-300 transition-colors">Cancel</button>
          <button type="submit" class="px-4 py-2 bg-blue-600 hover:bg-blue-500 text-white rounded-lg font-medium transition-all">Save Config</button>
        </div>
      </form>
    </div>
  </div>

  <!-- Logs Modal -->
  <div id="logsModal" class="hidden fixed inset-0 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4 z-50">
    <div class="bg-zinc-900 border border-zinc-800 w-full max-w-3xl rounded-2xl p-6 shadow-2xl flex flex-col max-h-[85vh]">
      <div class="flex items-center justify-between border-b border-zinc-800 pb-3">
        <h3 id="logsModalTitle" class="text-sm font-bold text-zinc-100 flex items-center gap-2">
          Build Failed Step Logs
        </h3>
        <button onclick="closeLogsModal()" class="text-zinc-500 hover:text-zinc-300 transition-colors">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>
        </button>
      </div>
      
      <div id="logsModalBody" class="space-y-4 overflow-y-auto pt-4 flex-1 pr-1 text-xs">
        <!-- Logs dynamically rendered here -->
      </div>
      
      <div class="flex items-center justify-end pt-3 border-t border-zinc-800 mt-3">
        <button onclick="closeLogsModal()" class="px-4 py-2 border border-zinc-800 hover:bg-zinc-800 rounded-lg text-xs font-semibold text-zinc-300 transition-colors">Close</button>
      </div>
    </div>
  </div>

  <script>
    function toggleConfigModal() {
      const modal = document.getElementById('configModal');
      modal.classList.toggle('hidden');
    }
    
    async function saveConfig(event) {
      event.preventDefault();
      const appId = document.getElementById('appIdInput').value.trim();
      const workflowId = document.getElementById('workflowIdInput').value.trim();
      const rawToken = document.getElementById('tokenInput').value.trim();
      
      const payload = { appId, workflowId };
      if (rawToken !== '********') {
        payload.token = rawToken;
      }
      
      try {
        const response = await fetch('/api/codemagic/config', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload)
        });
        
        const resData = await response.json();
        if (resData.status === 'success') {
          location.reload();
        } else {
          alert('Error saving config: ' + resData.message);
        }
      } catch (err) {
        alert('Network error saving config: ' + err.message);
      }
    }
    
    async function triggerBuild() {
      const btn = document.getElementById('triggerBtn');
      if (!btn) return;
      
      const originalHtml = btn.innerHTML;
      btn.disabled = true;
      btn.innerHTML = `
        <svg class="animate-spin h-3.5 w-3.5 text-white" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        Triggering...
      `;
      btn.className = btn.className.replace('bg-emerald-600', 'bg-zinc-700 cursor-not-allowed');
      
      try {
        const response = await fetch('/api/codemagic/trigger', {
          method: 'POST'
        });
        
        const resData = await response.json();
        if (resData.success) {
          btn.innerHTML = `
            <svg class="w-3.5 h-3.5 text-emerald-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg>
            Triggered!
          `;
          btn.className = btn.className.replace('bg-zinc-700', 'bg-emerald-800');
          setTimeout(() => {
            location.reload();
          }, 2000);
        } else {
          btn.innerHTML = originalHtml;
          btn.className = btn.className.replace('bg-zinc-700', 'bg-emerald-600').replace('cursor-not-allowed', '');
          btn.disabled = false;
          alert('Failed to trigger build: ' + resData.error);
        }
      } catch (err) {
        btn.innerHTML = originalHtml;
        btn.className = btn.className.replace('bg-zinc-700', 'bg-emerald-600').replace('cursor-not-allowed', '');
        btn.disabled = false;
        alert('Network error triggering build: ' + err.message);
      }
    }

    async function loadBuildHistory() {
      const section = document.getElementById('buildHistorySection');
      if (!section) return;
      
      const container = document.getElementById('buildsContainer');
      if (!container) return;
      
      try {
        const response = await fetch('/api/codemagic/builds');
        if (!response.ok) {
          const errData = await response.json();
          container.innerHTML = `<div class="text-xs text-zinc-500 font-mono py-2 bg-zinc-950/30 rounded-xl border border-zinc-800/40 text-center">Failed to load build history: ${errData.error || response.statusText}</div>`;
          return;
        }
        
        const data = await response.json();
        const builds = data.builds || [];
        
        if (builds.length === 0) {
          container.innerHTML = `<div class="text-xs text-zinc-500 font-mono py-4 bg-zinc-950/30 rounded-xl border border-zinc-800/40 text-center">No builds found for this application ID.</div>`;
          return;
        }
        
        container.innerHTML = builds.slice(0, 8).map(b => {
          const isFailed = b.status === 'failed';
          const isSuccess = b.status === 'finished';
          const isBuilding = ['initializing', 'queued', 'building', 'fetching', 'preparing', 'testing'].includes(b.status);
          
          let statusBadgeClass = 'bg-zinc-950/50 text-zinc-500 border-zinc-800/40';
          let statusDotClass = 'bg-zinc-500';
          let statusLabel = b.status;
          
          if (isSuccess) {
            statusBadgeClass = 'bg-emerald-950/40 text-emerald-400 border-emerald-900/30';
            statusDotClass = 'bg-emerald-500';
            statusLabel = 'success';
          } else if (isFailed) {
            statusBadgeClass = 'bg-red-950/40 text-red-400 border-red-900/30';
            statusDotClass = 'bg-red-500';
            statusLabel = 'failed';
          } else if (isBuilding) {
            statusBadgeClass = 'bg-blue-950/40 text-blue-400 border-blue-900/30 animate-pulse';
            statusDotClass = 'bg-blue-400';
            statusLabel = b.status || 'building';
          }
          
          const finishedDate = b.finishedAt ? new Date(b.finishedAt) : null;
          const startedDate = b.startedAt ? new Date(b.startedAt) : null;
          let timeLabel = '';
          if (finishedDate && startedDate) {
            const diffMs = finishedDate - startedDate;
            const diffMin = Math.floor(diffMs / 60000);
            const diffSec = Math.floor((diffMs % 60000) / 1000);
            timeLabel = `${diffMin}m ${diffSec}s`;
          } else if (startedDate) {
            const diffMs = Date.now() - startedDate;
            const diffMin = Math.floor(diffMs / 60000);
            timeLabel = `Running for ${diffMin}m`;
          }
          
          const commitMsg = b.commit?.message ? b.commit.message.split('\n')[0] : 'No commit message';
          const shortHash = b.commit?.hash ? b.commit.hash.substring(0, 7) : 'Unknown';
          const author = b.commit?.authorName || 'Unknown';
          
          const actionBtnHtml = isFailed ? `
            <button onclick="viewLogs('${b._id}')" class="flex items-center gap-1 px-2.5 py-1 text-[10px] font-semibold font-mono rounded bg-red-950/50 hover:bg-red-900/50 text-red-300 border border-red-900/30 active:scale-95 transition-all">
              <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"></path></svg>
              View Logs
            </button>
          ` : '';
          
          return `
            <div class="bg-zinc-950/20 rounded-xl border border-zinc-800/40 p-3 flex items-center justify-between gap-4">
              <div class="min-w-0 flex-1 space-y-1">
                <div class="flex items-center gap-2 flex-wrap">
                  <span class="text-zinc-400 font-bold font-mono text-xs">#${b.index}</span>
                  <span class="inline-flex items-center gap-1 text-[10px] font-mono px-2 py-0.5 rounded-full border ${statusBadgeClass}">
                    <span class="w-1 h-1 rounded-full ${statusDotClass}"></span>
                    ${statusLabel}
                  </span>
                  <span class="text-[10px] text-zinc-500 font-mono">${b.branch || 'main'}</span>
                  ${timeLabel ? `<span class="text-[10px] text-zinc-500 font-mono">(${timeLabel})</span>` : ''}
                </div>
                <div class="text-xs text-zinc-300 truncate font-mono">
                  <span class="text-blue-400 font-medium">${shortHash}</span> - ${commitMsg}
                </div>
                <div class="text-[10px] text-zinc-500">
                  By ${author} &bull; ${new Date(b.startedAt || b.createdAt).toLocaleString()}
                </div>
              </div>
              <div class="shrink-0">
                ${actionBtnHtml}
              </div>
            </div>
          `;
        }).join('');
        
      } catch (err) {
        container.innerHTML = `<div class="text-xs text-zinc-500 font-mono py-2 bg-zinc-950/30 rounded-xl border border-zinc-800/40 text-center">Network error loading builds: ${err.message}</div>`;
      }
    }
    
    async function viewLogs(buildId) {
      const modal = document.getElementById('logsModal');
      const title = document.getElementById('logsModalTitle');
      const body = document.getElementById('logsModalBody');
      
      if (!modal || !title || !body) return;
      
      title.innerText = 'Fetching Build Logs...';
      body.innerHTML = `
        <div class="flex flex-col items-center justify-center py-12 space-y-3">
          <svg class="animate-spin h-6 w-6 text-blue-500" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
          <span class="text-xs font-mono text-zinc-400">Downloading raw log output from Codemagic API...</span>
        </div>
      `;
      modal.classList.remove('hidden');
      
      try {
        const response = await fetch(\`/api/codemagic/builds/\${buildId}/logs\`);
        if (!response.ok) {
          const errData = await response.json();
          title.innerText = 'Log Download Failed';
          body.innerHTML = \`<div class="p-4 bg-red-950/30 border border-red-900/40 rounded-xl text-red-400 font-mono text-xs">Error: \${errData.error || response.statusText}</div>\`;
          return;
        }
        
        const data = await response.json();
        title.innerText = \`Build #\${data.index} - Failed Step Logs\`;
        
        if (!data.failedSteps || data.failedSteps.length === 0) {
          body.innerHTML = \`<div class="p-4 bg-zinc-950/40 border border-zinc-800/40 rounded-xl text-zinc-400 font-mono text-xs text-center">No failed build steps were found for this build. This could mean the build failed before starting any specific script step.</div>\`;
          return;
        }
        
        body.innerHTML = data.failedSteps.map((step, idx) => {
          const escStepName = step.name.replace(/\"/g, '&quot;');
          const escLog = step.log
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;');
            
          return \`
            <div class="space-y-2">
              <div class="flex items-center justify-between">
                <span class="text-xs font-bold text-red-400 font-mono">Step: \${step.name}</span>
                <button onclick="copyToClipboard(this, \\\`\${idx}\\\`)" class="flex items-center gap-1 px-2 py-1 text-[10px] font-mono rounded bg-zinc-800 hover:bg-zinc-700 text-zinc-300 transition-colors">
                  <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 5H6a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2v-1M8 5a2 2 0 002 2h2a2 2 0 002-2M8 5a2 2 0 002 2h2a2 2 0 002-2M8 5a2 2 0 012-2h2a2 2 0 012 2m0 0h2a2 2 0 012 2v3m2 4H10m0 0l3-3m-3 3l3 3"></path></svg>
                  Copy Log
                </button>
              </div>
              <div class="relative bg-black rounded-xl border border-zinc-800/80 p-4 font-mono text-[11px] leading-relaxed overflow-x-auto overflow-y-auto max-h-[350px] text-zinc-300 whitespace-pre-wrap select-text scrollbar-thin">
                <code id="logCode_\${idx}">\${escLog}</code>
              </div>
            </div>
          \`;
        }).join('<div class="border-t border-zinc-800/60 my-4"></div>');
        
      } catch (err) {
        title.innerText = 'Network Error';
        body.innerHTML = \`<div class="p-4 bg-red-950/30 border border-red-900/40 rounded-xl text-red-400 font-mono text-xs">Network error fetching logs: \${err.message}</div>\`;
      }
    }
    
    function closeLogsModal() {
      const modal = document.getElementById('logsModal');
      if (modal) modal.classList.add('hidden');
    }
    
    function copyToClipboard(btn, index) {
      const code = document.getElementById('logCode_' + index);
      if (!code) return;
      
      const text = code.innerText;
      navigator.clipboard.writeText(text).then(() => {
        const originalHtml = btn.innerHTML;
        btn.innerHTML = \`
          <svg class="w-3 h-3 text-emerald-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg>
          Copied!
        \`;
        setTimeout(() => {
          btn.innerHTML = originalHtml;
        }, 1500);
      });
    }
    
    // Auto load on init
    document.addEventListener('DOMContentLoaded', () => {
      loadBuildHistory();
    });
  </script>
</body>
</html>`;

    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(html);
  }
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Ice Cubes companion server running on 0.0.0.0:${PORT}`);
});
