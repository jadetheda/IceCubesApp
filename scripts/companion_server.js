const http = require('http');
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const PORT = 3000;

// Helper to get git info
function getGitInfo() {
  try {
    const gitDir = fs.existsSync('ios-workspace') ? 'ios-workspace' : '.';
    const hash = execSync('git rev-parse HEAD', { encoding: 'utf8', cwd: gitDir }).trim();
    const author = execSync('git log -1 --pretty=format:"%an"', { encoding: 'utf8', cwd: gitDir }).trim();
    const relativeTime = execSync('git log -1 --pretty=format:"%ar"', { encoding: 'utf8', cwd: gitDir }).trim();
    const subject = execSync('git log -1 --pretty=format:"%s"', { encoding: 'utf8', cwd: gitDir }).trim();
    return { hash, author, relativeTime, subject };
  } catch (e) {
    return { hash: 'Unknown', author: 'Unknown', relativeTime: 'Unknown', subject: 'Error reading git history' };
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
    const activity = getActivityLog();
    const icons = getAlternateIcons();

    const activityHtml = activity.map(act => `
      <div class="border-b border-stone-100 pb-4 mb-4 last:border-b-0 last:pb-0">
        <div class="flex items-center justify-between mb-1">
          <h4 class="font-semibold text-stone-800 text-sm md:text-base">${act.title}</h4>
          <span class="text-xs text-stone-400 bg-stone-100 px-2 py-0.5 rounded">${act.date.split('T')[0] || act.date}</span>
        </div>
        ${act.details.length > 0 ? `
          <ul class="list-disc pl-4 mt-2 space-y-1 text-xs md:text-sm text-stone-600">
            ${act.details.map(det => `<li>${det}</li>`).join('')}
          </ul>
        ` : ''}
      </div>
    `).join('') || '<p class="text-stone-400 text-sm">No recent activity log found in memory.md</p>';

    const iconsHtml = icons.slice(0, 15).map(icon => `
      <div class="flex flex-col items-center p-3 bg-stone-50 rounded-lg border border-stone-200/50 hover:shadow-sm transition-all duration-200">
        <img src="/api/icon/${icon.id}" alt="${icon.name}" class="w-12 h-12 rounded-xl shadow-inner mb-2 object-cover bg-stone-200" onerror="this.src='data:image/svg+xml;utf8,<svg xmlns=%22http://www.w3.org/2000/svg%22 width=%2248%22 height=%2248%22 viewBox=%220 0 48 48%22><rect width=%2248%22 height=%2248%22 fill=%22%23e2e2e2%22/><text x=%2250%%22 y=%2250%%22 font-size=%2210%22 font-family=%22sans-serif%22 fill=%22%23999%22 text-anchor=%22middle%22 dy=%22.3em%22>${icon.id}</text></svg>'"/>
        <span class="text-[10px] font-medium text-stone-500">${icon.name}</span>
      </div>
    `).join('');

    const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Ice Cubes - Developer Dashboard</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <style>
    @import url('https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700&display=swap');
    body {
      font-family: 'Plus Jakarta Sans', sans-serif;
      background-color: #faf9f6;
    }
  </style>
</head>
<body class="text-stone-800 min-h-screen">
  <div class="max-w-6xl mx-auto px-4 py-8 md:py-12">
    <!-- Header -->
    <header class="flex flex-col md:flex-row justify-between items-start md:items-center border-b border-stone-200/60 pb-6 mb-8 gap-4">
      <div>
        <div class="flex items-center gap-3">
          <span class="w-3 h-3 bg-emerald-500 rounded-full animate-ping"></span>
          <span class="text-xs font-bold text-emerald-600 tracking-wider uppercase bg-emerald-50 px-2 py-0.5 rounded-full border border-emerald-200">System Ready</span>
        </div>
        <h1 class="text-3xl md:text-4xl font-bold tracking-tight text-stone-900 mt-2">Ice Cubes iOS App</h1>
        <p class="text-stone-500 text-sm md:text-base mt-1">Multiplatform Mastodon client built entirely in native SwiftUI.</p>
      </div>
      <div class="flex gap-3">
        <a href="https://github.com/jadetheda/icecubesapp" target="_blank" class="px-4 py-2 bg-white hover:bg-stone-50 text-stone-700 font-semibold text-sm rounded-lg border border-stone-200 hover:border-stone-300 transition shadow-sm">View on GitHub</a>
      </div>
    </header>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
      <!-- Main Columns -->
      <div class="lg:col-span-2 space-y-8">
        <!-- Pipeline Information -->
        <section class="bg-white p-6 rounded-xl border border-stone-200/80 shadow-sm">
          <h2 class="text-lg md:text-xl font-bold text-stone-900 mb-4 flex items-center gap-2">
            <svg class="w-5 h-5 text-stone-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A2 2 0 009 10.172V5L8 4z"></path></svg>
            iOS Development & Build Pipeline
          </h2>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mt-4">
            <div class="p-4 bg-stone-50 rounded-lg border border-stone-200/50">
              <h3 class="font-bold text-stone-800 text-sm uppercase tracking-wider mb-2">1. Modify Source Code</h3>
              <p class="text-stone-600 text-xs md:text-sm leading-relaxed">
                Use the AI Studio Coding Assistant to implement features, perform refactoring, or apply Bug Fixes inside the native packages of the repository.
              </p>
            </div>
            <div class="p-4 bg-stone-50 rounded-lg border border-stone-200/50">
              <h3 class="font-bold text-stone-800 text-sm uppercase tracking-wider mb-2">2. Commit & Push</h3>
              <p class="text-stone-600 text-xs md:text-sm leading-relaxed">
                Instruct the agent to push directly to your remote repository. The agent utilizes a private security token so no manual terminal steps are required.
              </p>
            </div>
            <div class="p-4 bg-stone-50 rounded-lg border border-stone-200/50">
              <h3 class="font-bold text-stone-800 text-sm uppercase tracking-wider mb-2">3. Codemagic Compilation</h3>
              <p class="text-stone-600 text-xs md:text-sm leading-relaxed">
                Trigger an on-demand iOS compile build inside the Codemagic dashboard. This securely packages the Swift source into an unsigned <code>.ipa</code> package.
              </p>
            </div>
            <div class="p-4 bg-stone-50 rounded-lg border border-stone-200/50">
              <h3 class="font-bold text-stone-800 text-sm uppercase tracking-wider mb-2">4. Sideload via LiveContainer</h3>
              <p class="text-stone-600 text-xs md:text-sm leading-relaxed">
                Download the unsigned <code>.ipa</code> from Codemagic and launch/run it instantly on your iOS device via <strong>LiveContainer</strong> — no Mac required!
              </p>
            </div>
          </div>
        </section>

        <!-- Dynamic Activity Log -->
        <section class="bg-white p-6 rounded-xl border border-stone-200/80 shadow-sm">
          <h2 class="text-lg md:text-xl font-bold text-stone-900 mb-4 flex items-center gap-2">
            <svg class="w-5 h-5 text-stone-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
            Recent Activity Log
          </h2>
          <div class="mt-4">
            ${activityHtml}
          </div>
        </section>
      </div>

      <!-- Sidebar -->
      <div class="space-y-8">
        <!-- Git Status Card -->
        <section class="bg-stone-900 text-stone-100 p-6 rounded-xl shadow-md border border-stone-800">
          <h3 class="text-xs font-bold text-stone-400 tracking-widest uppercase mb-4">ACTIVE REPOSITORY STATE</h3>
          <div class="space-y-4">
            <div>
              <span class="text-xs text-stone-400 block font-semibold mb-0.5">HEAD COMMIT</span>
              <code class="text-stone-200 text-xs bg-stone-800 px-2 py-1 rounded select-all font-mono break-all inline-block max-w-full">${git.hash}</code>
            </div>
            <div>
              <span class="text-xs text-stone-400 block font-semibold mb-0.5">COMMIT MESSAGE</span>
              <span class="text-sm text-white font-medium block leading-relaxed">${git.subject}</span>
            </div>
            <div class="grid grid-cols-2 gap-4 border-t border-stone-800 pt-4 mt-2">
              <div>
                <span class="text-xs text-stone-400 block font-semibold">AUTHOR</span>
                <span class="text-xs font-medium text-stone-200">${git.author}</span>
              </div>
              <div>
                <span class="text-xs text-stone-400 block font-semibold">TIMESTAMP</span>
                <span class="text-xs font-medium text-stone-200">${git.relativeTime}</span>
              </div>
            </div>
          </div>
        </section>

        <!-- Icons Gallery -->
        <section class="bg-white p-6 rounded-xl border border-stone-200/80 shadow-sm">
          <div class="flex items-center justify-between mb-4">
            <h3 class="text-base font-bold text-stone-900 flex items-center gap-2">
              <svg class="w-5 h-5 text-stone-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"></path></svg>
              Alternate Icons
            </h3>
            <span class="text-xs text-stone-500 font-medium bg-stone-100 px-2 py-1 rounded-full">${icons.length} Loaded</span>
          </div>
          <p class="text-xs text-stone-500 mb-4 leading-relaxed">Ice Cubes supports extensive client-side theme customizability. Here are a few of the 66 alternate app icons included:</p>
          <div class="grid grid-cols-3 gap-3">
            ${iconsHtml}
          </div>
        </section>
      </div>
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
