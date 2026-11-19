#!/usr/bin/env node

/**
 * ============================================================================
 * Mod Asset Sync & Version Comparison Tool
 * ============================================================================
 * Compares .json, .lua (and optional custom extensions) between the source mod
 * folder and the exported build mod folder to detect desynchronizations,
 * files modified directly in export, and missing assets.
 *
 * Usage:
 *   node tools/check_mod_sync.js [options]
 *
 * Options:
 *   --source=<path>      Source mod directory (default: "mods/Dark's Collection V3.5")
 *   --export=<path>      Export mod directory (default: "export/release/windows/bin/mods/Dark's Collection V3.5")
 *   --ext=<extensions>   Comma-separated extensions to check (default: ".json,.lua")
 *   --all                Check all file extensions, not just .json and .lua
 *   --sync-to-source     Copy files that are newer in export or only in export -> source
 *   --sync-to-export     Copy files that are newer in source or only in source -> export
 *   --sync               Two-way sync: always copy the newer file over the older one
 *   --dry-run            Show what --sync / --sync-to-* would do without modifying disk
 *   --json               Output machine-readable JSON summary
 *   --help               Show this help message
 * ============================================================================
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

// --- ANSI Colors ---
const c = {
    reset: '\x1b[0m',
    bold: '\x1b[1m',
    dim: '\x1b[2m',
    red: '\x1b[31m',
    green: '\x1b[32m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    magenta: '\x1b[35m',
    cyan: '\x1b[36m',
    white: '\x1b[37m',
    gray: '\x1b[90m'
};

// --- Parse CLI Arguments ---
const args = process.argv.slice(2);
let srcDir = path.resolve("mods/Dark's Collection V3.5");
let expDir = path.resolve("export/release/windows/bin/mods/Dark's Collection V3.5");
let allowedExts = ['.json', '.lua'];
let checkAllExts = false;
let syncToSource = false;
let syncToExport = false;
let syncBoth = false;
let dryRun = false;
let outputJson = false;

for (const arg of args) {
    if (arg === '--help' || arg === '-h') {
        printHelp();
        process.exit(0);
    } else if (arg.startsWith('--source=') || arg.startsWith('--src=')) {
        srcDir = path.resolve(arg.split('=')[1]);
    } else if (arg.startsWith('--export=') || arg.startsWith('--exp=')) {
        expDir = path.resolve(arg.split('=')[1]);
    } else if (arg.startsWith('--ext=')) {
        allowedExts = arg.split('=')[1].split(',').map(e => e.trim().toLowerCase()).map(e => e.startsWith('.') ? e : '.' + e);
    } else if (arg === '--all') {
        checkAllExts = true;
    } else if (arg === '--sync-to-source') {
        syncToSource = true;
    } else if (arg === '--sync-to-export') {
        syncToExport = true;
    } else if (arg === '--sync') {
        syncBoth = true;
    } else if (arg === '--dry-run') {
        dryRun = true;
    } else if (arg === '--json') {
        outputJson = true;
    }
}

function printHelp() {
    console.log(`
${c.bold}${c.cyan}Dark's Collection V3.5 - Mod Asset Sync & Comparison Tool${c.reset}

${c.bold}USAGE:${c.reset}
  node tools/check_mod_sync.js [options]

${c.bold}OPTIONS:${c.reset}
  ${c.yellow}--source=<path>${c.reset}     Source mod folder (default: mods/Dark's Collection V3.5)
  ${c.yellow}--export=<path>${c.reset}     Export mod folder (default: export/release/windows/bin/mods/Dark's Collection V3.5)
  ${c.yellow}--ext=<exts>${c.reset}        Comma-separated list of extensions (default: .json,.lua)
  ${c.yellow}--all${c.reset}               Check all file types
  ${c.yellow}--sync-to-source${c.reset}    Copy files that are newer/only in export -> source
  ${c.yellow}--sync-to-export${c.reset}    Copy files that are newer/only in source -> export
  ${c.yellow}--sync${c.reset}              Copy the newest version of each file to the other side
  ${c.yellow}--dry-run${c.reset}           Simulate copy operations without writing to disk
  ${c.yellow}--json${c.reset}              Output pure JSON summary
  ${c.yellow}--help, -h${c.reset}          Display this message
`);
}

function formatBytes(bytes) {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(Math.abs(bytes)) / Math.log(k));
    const val = (bytes / Math.pow(k, i)).toFixed(i === 0 ? 0 : 1);
    return `${val} ${sizes[i]}`;
}

function formatTimeDiff(msDiff) {
    const sec = Math.abs(Math.round(msDiff / 1000));
    if (sec < 60) return `${sec}s`;
    const min = Math.round(sec / 60);
    if (min < 60) return `${min}m`;
    const hrs = Math.round(min / 60);
    if (hrs < 24) return `${hrs}h`;
    const days = Math.round(hrs / 24);
    return `${days}d`;
}

function getFileHash(filePath) {
    const buffer = fs.readFileSync(filePath);
    return crypto.createHash('md5').update(buffer).digest('hex');
}

function scanDir(dir, base = '') {
    let results = [];
    if (!fs.existsSync(dir)) return results;
    let entries;
    try {
        entries = fs.readdirSync(dir, { withFileTypes: true });
    } catch (e) {
        return results;
    }
    for (const entry of entries) {
        const fullPath = path.join(dir, entry.name);
        const relPath = path.join(base, entry.name);
        if (entry.isDirectory()) {
            results = results.concat(scanDir(fullPath, relPath));
        } else if (entry.isFile()) {
            const ext = path.extname(entry.name).toLowerCase();
            if (checkAllExts || allowedExts.includes(ext)) {
                results.push(relPath);
            }
        }
    }
    return results;
}

function ensureDirSync(dirPath) {
    if (!fs.existsSync(dirPath)) {
        fs.mkdirSync(dirPath, { recursive: true });
    }
}

function copyFileSafe(srcFile, destFile) {
    ensureDirSync(path.dirname(destFile));
    fs.copyFileSync(srcFile, destFile);
    // Sync mtime
    const stat = fs.statSync(srcFile);
    fs.utimesSync(destFile, stat.atime, stat.mtime);
}

// --- Validation ---
if (!fs.existsSync(srcDir)) {
    console.error(`${c.red}Error: Source mod directory does not exist:${c.reset} ${srcDir}`);
    process.exit(1);
}
if (!fs.existsSync(expDir)) {
    console.error(`${c.red}Error: Export mod directory does not exist:${c.reset} ${expDir}`);
    process.exit(1);
}

const srcFiles = scanDir(srcDir);
const expFiles = scanDir(expDir);
const allFiles = Array.from(new Set([...srcFiles, ...expFiles])).sort();

const exportNewer = [];
const sourceNewer = [];
const onlyInExport = [];
const onlyInSource = [];
const identical = [];

for (const rel of allFiles) {
    const sPath = path.join(srcDir, rel);
    const ePath = path.join(expDir, rel);
    const sExists = fs.existsSync(sPath);
    const eExists = fs.existsSync(ePath);

    if (sExists && eExists) {
        const sStat = fs.statSync(sPath);
        const eStat = fs.statSync(ePath);
        const sHash = getFileHash(sPath);
        const eHash = getFileHash(ePath);

        if (sHash === eHash) {
            identical.push({ rel, size: sStat.size });
        } else {
            const timeDiff = eStat.mtimeMs - sStat.mtimeMs;
            const sizeDiff = eStat.size - sStat.size;
            if (eStat.mtimeMs > sStat.mtimeMs) {
                exportNewer.push({
                    rel,
                    timeDiff,
                    sizeDiff,
                    srcMtime: sStat.mtime,
                    expMtime: eStat.mtime,
                    srcSize: sStat.size,
                    expSize: eStat.size,
                    sPath,
                    ePath
                });
            } else {
                sourceNewer.push({
                    rel,
                    timeDiff: -timeDiff,
                    sizeDiff: -sizeDiff,
                    srcMtime: sStat.mtime,
                    expMtime: eStat.mtime,
                    srcSize: sStat.size,
                    expSize: eStat.size,
                    sPath,
                    ePath
                });
            }
        }
    } else if (eExists) {
        const eStat = fs.statSync(ePath);
        onlyInExport.push({
            rel,
            size: eStat.size,
            mtime: eStat.mtime,
            sPath,
            ePath
        });
    } else {
        const sStat = fs.statSync(sPath);
        onlyInSource.push({
            rel,
            size: sStat.size,
            mtime: sStat.mtime,
            sPath,
            ePath
        });
    }
}

// --- JSON Output Mode ---
if (outputJson) {
    console.log(JSON.stringify({
        sourceDir: srcDir,
        exportDir: expDir,
        totalChecked: allFiles.length,
        summary: {
            identical: identical.length,
            exportNewer: exportNewer.length,
            sourceNewer: sourceNewer.length,
            onlyInExport: onlyInExport.length,
            onlyInSource: onlyInSource.length
        },
        exportNewer,
        sourceNewer,
        onlyInExport,
        onlyInSource
    }, null, 2));
    process.exit(0);
}

// --- Console Output Mode ---
console.log(`\n${c.bold}${c.cyan}======================================================================${c.reset}`);
console.log(`${c.bold}${c.white}   DARK'S COLLECTION V3.5 - MOD ASSET SYNCHRONIZATION CHECKER${c.reset}`);
console.log(`${c.bold}${c.cyan}======================================================================${c.reset}`);
console.log(`${c.gray}📁 Source : ${srcDir}`);
console.log(`📁 Export : ${expDir}`);
console.log(`🔍 Filters: ${checkAllExts ? 'All files' : allowedExts.join(', ')}`);
console.log(`${c.cyan}----------------------------------------------------------------------${c.reset}\n`);

// 1. Export is Newer (High Priority / Warning)
if (exportNewer.length > 0) {
    console.log(`${c.bold}${c.yellow}⚠️  EXPORT IS NEWER (${exportNewer.length} files modified in export)${c.reset}`);
    console.log(`${c.dim}   (Warning: If you run "lime build/test", these changes will be overwritten by source!)${c.reset}`);
    for (const item of exportNewer) {
        const diffStr = `${c.yellow}+${formatTimeDiff(item.timeDiff)} newer${c.reset}`;
        const sizeStr = item.sizeDiff !== 0 ? ` (${item.sizeDiff > 0 ? '+' : ''}${item.sizeDiff} B)` : '';
        console.log(`   ${c.yellow}•${c.reset} ${c.bold}${item.rel}${c.reset}`);
        console.log(`     ${c.gray}Export : ${item.expMtime.toLocaleString()} [${formatBytes(item.expSize)}]${c.reset}`);
        console.log(`     ${c.gray}Source : ${item.srcMtime.toLocaleString()} [${formatBytes(item.srcSize)}] -> ${diffStr}${sizeStr}`);
    }
    console.log('');
}

// 2. Only in Export
if (onlyInExport.length > 0) {
    console.log(`${c.bold}${c.magenta}➕ ONLY IN EXPORT (${onlyInExport.length} files created in export folder)${c.reset}`);
    for (const item of onlyInExport) {
        console.log(`   ${c.magenta}•${c.reset} ${c.bold}${item.rel}${c.reset} ${c.gray}(${formatBytes(item.size)}, ${item.mtime.toLocaleString()})${c.reset}`);
    }
    console.log('');
}

// 3. Source is Newer
if (sourceNewer.length > 0) {
    console.log(`${c.bold}${c.blue}ℹ️  SOURCE IS NEWER (${sourceNewer.length} files updated in source repo)${c.reset}`);
    for (const item of sourceNewer) {
        const diffStr = `${c.blue}+${formatTimeDiff(item.timeDiff)} newer${c.reset}`;
        const sizeStr = item.sizeDiff !== 0 ? ` (${item.sizeDiff > 0 ? '+' : ''}${item.sizeDiff} B)` : '';
        console.log(`   ${c.blue}•${c.reset} ${c.bold}${item.rel}${c.reset}`);
        console.log(`     ${c.gray}Source : ${item.srcMtime.toLocaleString()} [${formatBytes(item.srcSize)}] -> ${diffStr}${sizeStr}`);
        console.log(`     ${c.gray}Export : ${item.expMtime.toLocaleString()} [${formatBytes(item.expSize)}]${c.reset}`);
    }
    console.log('');
}

// 4. Only in Source
if (onlyInSource.length > 0) {
    console.log(`${c.bold}${c.white}📄 ONLY IN SOURCE (${onlyInSource.length} files not yet copied to export)${c.reset}`);
    for (const item of onlyInSource) {
        console.log(`   ${c.gray}•${c.reset} ${item.rel} ${c.gray}(${formatBytes(item.size)})${c.reset}`);
    }
    console.log('');
}

// 5. Summary Table
console.log(`${c.bold}${c.cyan}============================ SUMMARY =================================${c.reset}`);
console.log(`  Total Files Checked : ${c.bold}${allFiles.length}${c.reset}`);
console.log(`  Identical Files     : ${c.green}${identical.length}${c.reset}`);
console.log(`  Export Newer        : ${exportNewer.length > 0 ? c.bold + c.yellow : c.gray}${exportNewer.length}${c.reset}`);
console.log(`  Only in Export      : ${onlyInExport.length > 0 ? c.bold + c.magenta : c.gray}${onlyInExport.length}${c.reset}`);
console.log(`  Source Newer        : ${sourceNewer.length > 0 ? c.bold + c.blue : c.gray}${sourceNewer.length}${c.reset}`);
console.log(`  Only in Source      : ${onlyInSource.length > 0 ? c.bold + c.white : c.gray}${onlyInSource.length}${c.reset}`);
console.log(`${c.bold}${c.cyan}======================================================================${c.reset}\n`);

// --- Sync Handling ---
const filesToSyncToSource = [...exportNewer, ...onlyInExport];
const filesToSyncToExport = [...sourceNewer, ...onlyInSource];

if (syncToSource || syncBoth) {
    if (filesToSyncToSource.length === 0) {
        console.log(`${c.green}Nothing to sync to source. Source is already up to date!${c.reset}`);
    } else {
        console.log(`${c.bold}${c.yellow}🔄 Syncing ${filesToSyncToSource.length} files from EXPORT -> SOURCE...${c.reset}`);
        for (const f of filesToSyncToSource) {
            console.log(`   ${dryRun ? '[DRY RUN] ' : ''}Copying ${c.bold}${f.rel}${c.reset} -> source`);
            if (!dryRun) {
                copyFileSafe(f.ePath, f.sPath);
            }
        }
        console.log(`${c.green}✔ Successfully synced to source.${dryRun ? ' (DRY RUN - no files changed)' : ''}${c.reset}\n`);
    }
}

if (syncToExport || syncBoth) {
    if (filesToSyncToExport.length === 0) {
        console.log(`${c.green}Nothing to sync to export. Export is already up to date!${c.reset}`);
    } else {
        console.log(`${c.bold}${c.blue}🔄 Syncing ${filesToSyncToExport.length} files from SOURCE -> EXPORT...${c.reset}`);
        for (const f of filesToSyncToExport) {
            console.log(`   ${dryRun ? '[DRY RUN] ' : ''}Copying ${c.bold}${f.rel}${c.reset} -> export`);
            if (!dryRun) {
                copyFileSafe(f.sPath, f.ePath);
            }
        }
        console.log(`${c.green}✔ Successfully synced to export.${dryRun ? ' (DRY RUN - no files changed)' : ''}${c.reset}\n`);
    }
}

if (!syncToSource && !syncToExport && !syncBoth) {
    if (exportNewer.length > 0 || onlyInExport.length > 0) {
        console.log(`${c.yellow}💡 Tip:${c.reset} Run ${c.bold}node tools/check_mod_sync.js --sync-to-source${c.reset} to bring newer export changes into your source repo.`);
    }
    if (sourceNewer.length > 0 || onlyInSource.length > 0) {
        console.log(`${c.blue}💡 Tip:${c.reset} Run ${c.bold}node tools/check_mod_sync.js --sync-to-export${c.reset} to copy source changes to the game export.`);
    }
}
