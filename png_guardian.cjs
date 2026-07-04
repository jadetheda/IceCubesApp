const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const WORKSPACE = __dirname;
const BACKUP_FILE = path.join(__dirname, 'png_backup.json.gz');

function findPngs(dir) {
    let results = [];
    const list = fs.readdirSync(dir);
    list.forEach(file => {
        const fullPath = path.join(dir, file);
        const stat = fs.statSync(fullPath);
        if (stat && stat.isDirectory()) {
            if (!fullPath.includes('.git') && !fullPath.includes('node_modules')) {
                results = results.concat(findPngs(fullPath));
            }
        } else if (file.toLowerCase().endsWith('.png')) {
            results.push(fullPath);
        }
    });
    return results;
}

const command = process.argv[2];

if (command === 'backup') {
    const pngs = findPngs(WORKSPACE);
    const backup = {};
    let count = 0;
    for (const p of pngs) {
        const relativePath = path.relative(WORKSPACE, p);
        const data = fs.readFileSync(p, 'base64');
        backup[relativePath] = data;
        count++;
    }
    const jsonStr = JSON.stringify(backup);
    const compressed = zlib.gzipSync(Buffer.from(jsonStr, 'utf8'));
    fs.writeFileSync(BACKUP_FILE, compressed);
    console.log(`Backed up ${count} PNGs to png_backup.json.gz.`);
} else if (command === 'restore') {
    if (!fs.existsSync(BACKUP_FILE)) {
        console.error("No backup found at png_backup.json.gz!");
        process.exit(1);
    }
    const compressed = fs.readFileSync(BACKUP_FILE);
    const jsonStr = zlib.gunzipSync(compressed).toString('utf8');
    const backup = JSON.parse(jsonStr);
    let count = 0;
    for (const [relPath, base64Data] of Object.entries(backup)) {
        const fullPath = path.join(WORKSPACE, relPath);
        const dir = path.dirname(fullPath);
        if (!fs.existsSync(dir)) {
            fs.mkdirSync(dir, { recursive: true });
        }
        fs.writeFileSync(fullPath, base64Data, 'base64');
        count++;
    }
    console.log(`Restored ${count} PNGs from png_backup.json.gz.`);
} else {
    console.log("Usage: node png_guardian.cjs <backup|restore>");
}
