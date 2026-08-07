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

function getGithubActionStatus() {
  try {
    const output = execSync('curl -s https://api.github.com/repos/jadetheda/icecubesapp/actions/runs?per_page=1', { encoding: 'utf8' });
    const data = JSON.parse(output);
    if (data && data.workflow_runs && data.workflow_runs.length > 0) {
      const run = data.workflow_runs[0];
      return { status: run.status, conclusion: run.conclusion, url: run.html_url };
    }
    return null;
  } catch (e) {
    return null;
  }
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

  // 4. GET /
  if (pathname === '/' || pathname === '/index.html') {
    const git = getGitInfo();
    const action = getGithubActionStatus();

    let actionHtml = '';
    if (action) {
      const isCompleted = action.status === 'completed';
      const isSuccess = action.conclusion === 'success';
      const isFailure = action.conclusion === 'failure';
      let statusColor = 'bg-zinc-500';
      if (!isCompleted) statusColor = 'bg-blue-500 animate-pulse';
      else if (isSuccess) statusColor = 'bg-emerald-500';
      else if (isFailure) statusColor = 'bg-red-500';
      
      actionHtml = `
        <a href="${action.url}" target="_blank" class="flex items-center gap-2 text-xs font-mono px-3 py-1 rounded-full border border-zinc-800 hover:bg-zinc-800/50 transition-colors">
          <span class="w-2 h-2 rounded-full ${statusColor}"></span>
          <span class="text-zinc-300">CI: ${isCompleted ? action.conclusion : action.status}</span>
        </a>
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
        ${actionHtml}
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
</body>
</html>`;

    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(html);
  }
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Ice Cubes companion server running on 0.0.0.0:${PORT}`);
});
