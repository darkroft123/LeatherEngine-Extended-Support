using StringTools;
/**
 * Dark's Collection V3.5 - Asset Encryption Tool v3.0
 *
 * Full workflow: encrypt, decrypt, incremental sync, status check.
 * Supports: .png, .ogg, .xml (extensible)
 *
 * Modes:
 *   encrypt   - Encrypt files → .e{ext}
 *   decrypt   - Decrypt .e{ext} → original
 *   sync      - Incremental: only encrypt new/changed files
 *   status    - Show encryption status of all assets
 *
 * Format: [MAGIC:4][VERSION:4][SIZE:4][ENCRYPTED_DATA:N]
 */

import sys.FileSystem;
import sys.io.File;
import haxe.io.Bytes;
import haxe.io.Path;
import haxe.crypto.Sha256;

typedef ManifestEntry = {
    var originalSize:Int;
    var hash:String;
    var encryptedAt:String;
}

typedef StatusResult = {
    var originals:Int;
    var encrypted:Int;
    var orphanOriginals:Int;
    var orphanEncrypted:Int;
    var tracked:Int;
}

class EncryptAssets {
    // ── Encryption key loaded from environment / secrets.json with fallback ──
    static var SECRET_KEY(get, never):String;
    static var _cachedSecretKey:String = null;
    static function get_SECRET_KEY():String {
        if (_cachedSecretKey != null) return _cachedSecretKey;
        var envKey = Sys.getEnv("ANTI_LEAK_KEY");
        if (envKey != null && envKey != "") {
            _cachedSecretKey = envKey;
            return _cachedSecretKey;
        }
        if (FileSystem.exists("secrets.json")) {
            try {
                var content = File.getContent("secrets.json");
                var parsed:Dynamic = haxe.Json.parse(content);
                if (parsed != null && parsed.anti_leak_key != null) {
                    _cachedSecretKey = Std.string(parsed.anti_leak_key);
                    return _cachedSecretKey;
                }
            } catch (e:Dynamic) {}
        }
        _cachedSecretKey = "Drk_C0ll3ct10n_@nt1_l34k_2024_x0r!";
        return _cachedSecretKey;
    }
    static inline var MAGIC:String = "DARK";
    static inline var VERSION:Int = 1;
    static inline var HEADER_SIZE:Int = 12;

    // ── Supported file extensions ──
    static var SUPPORTED_EXTENSIONS:Array<String> = ["png", "ogg", "xml", "json"];

    // Extension mapping: original → encrypted
    static var EXT_MAP:Map<String, String> = [
        "png" => "epng",
        "ogg" => "eogg",
        "xml" => "exml",
        "json" => "ejson"
    ];

    // Reverse mapping: encrypted → original
    static var EXT_REVERSE:Map<String, String> = [
        "epng" => "png",
        "eogg" => "ogg",
        "exml" => "xml",
        "ejson" => "json"
    ];

    // Stats
    static var encryptedCount:Int = 0;
    static var decryptedCount:Int = 0;
    static var skippedCount:Int = 0;
    static var errorCount:Int = 0;
    static var totalBytesIn:Float = 0;
    static var totalBytesOut:Float = 0;

    // Options
    static var deleteOriginals:Bool = false;
    static var dryRun:Bool = false;
    static var targetDir:String = null;
    static var verbose:Bool = false;
    static var mode:String = "encrypt";

    // Manifest: maps encrypted path → { originalSize, hash, timestamp }
    static var manifest:Map<String, ManifestEntry> = new Map();
    static inline var MANIFEST_FILE:String = ".encrypt_manifest";



    static function main():Void {
        Sys.println("╔════════════════════════════════════════════════════════╗");
        Sys.println("║  Dark's Collection V3.5 - Asset Encryptor v3.0       ║");
        Sys.println("║  Anti-Leak Encryption System (.png .ogg .xml)        ║");
        Sys.println("╚════════════════════════════════════════════════════════╝");
        Sys.println("");

        parseArgs();
        loadManifest();

        switch (mode) {
            case "encrypt": runEncrypt();
            case "decrypt": runDecrypt();
            case "sync": runSync();
            case "status": runStatus();
            default:
                Sys.println("[ERROR] Unknown mode: " + mode);
                Sys.println("Valid modes: encrypt, decrypt, sync, status");
                Sys.exit(1);
        }

        if (!dryRun && mode != "status") saveManifest();
        printStats();
    }

    // ══════════════════════════════════════════════════════
    //  MODE: ENCRYPT
    // ══════════════════════════════════════════════════════
    static function runEncrypt():Void {
        Sys.println("[MODE] ENCRYPT - Encrypting supported files");
        Sys.println("[EXTS] " + SUPPORTED_EXTENSIONS.join(", "));
        Sys.println("");

        for (dir in getDirectories()) {
            if (!FileSystem.exists(dir)) {
                Sys.println("[WARN] Directory not found: " + dir);
                continue;
            }
            Sys.println("[SCAN] " + dir);
            scanAndProcess(dir, "encrypt");
        }
    }

    // ══════════════════════════════════════════════════════
    //  MODE: DECRYPT (REVERT)
    // ══════════════════════════════════════════════════════
    static function runDecrypt():Void {
        Sys.println("[MODE] DECRYPT - Reverting encrypted files to originals");
        Sys.println("");

        for (dir in getDirectories()) {
            if (!FileSystem.exists(dir)) {
                Sys.println("[WARN] Directory not found: " + dir);
                continue;
            }
            Sys.println("[SCAN] " + dir);
            scanAndProcess(dir, "decrypt");
        }
    }

    // ══════════════════════════════════════════════════════
    //  MODE: SYNC (INCREMENTAL)
    // ══════════════════════════════════════════════════════
    static function runSync():Void {
        Sys.println("[MODE] SYNC - Incremental encryption (only new/changed files)");
        Sys.println("");

        for (dir in getDirectories()) {
            if (!FileSystem.exists(dir)) {
                Sys.println("[WARN] Directory not found: " + dir);
                continue;
            }
            Sys.println("[SCAN] " + dir);
            scanAndProcess(dir, "sync");
        }

        cleanupManifest();
    }

    // ══════════════════════════════════════════════════════
    //  MODE: STATUS
    // ══════════════════════════════════════════════════════
    static function runStatus():Void {
        Sys.println("[MODE] STATUS - Encryption overview");
        Sys.println("");

        var totalOriginals:Int = 0;
        var totalEncrypted:Int = 0;
        var totalOrphanOriginals:Int = 0;
        var totalOrphanEncrypted:Int = 0;
        var totalTracked:Int = 0;

        for (dir in getDirectories()) {
            if (!FileSystem.exists(dir)) continue;
            var r = scanForStatus(dir);
            totalOriginals += r.originals;
            totalEncrypted += r.encrypted;
            totalOrphanOriginals += r.orphanOriginals;
            totalOrphanEncrypted += r.orphanEncrypted;
            totalTracked += r.tracked;
        }

        Sys.println("");
        Sys.println("═══════════════════════════════════════════════════");
        Sys.println("  ENCRYPTION STATUS");
        Sys.println("  Original files (.png/.ogg/.xml): " + totalOriginals);
        Sys.println("  Encrypted files (.epng/.eogg/.exml): " + totalEncrypted);
        Sys.println("  NEED ENCRYPTION (no .e{ext}):  " + totalOrphanOriginals);
        Sys.println("  Orphan .e{ext} (no original):  " + totalOrphanEncrypted);
        Sys.println("  Tracked in manifest:           " + totalTracked);
        Sys.println("═══════════════════════════════════════════════════");

        if (totalOrphanOriginals > 0) {
            Sys.println("");
            Sys.println("  → Run: haxe encrypt_assets.hx sync");
        } else {
            Sys.println("");
            Sys.println("  → All files are encrypted!");
        }
    }

    // ══════════════════════════════════════════════════════
    //  UNIFIED DIRECTORY SCANNER
    // ══════════════════════════════════════════════════════
    static function scanAndProcess(dir:String, opMode:String):Void {
        if (!FileSystem.isDirectory(dir)) return;

        var entries:Array<String> = FileSystem.readDirectory(dir);
        for (entry in entries) {
            var fullPath:String = Path.join([dir, entry]);

            if (FileSystem.isDirectory(fullPath)) {
                if (!entry.startsWith(".") && entry != "export" && entry != "bin" && entry != ".git") {
                    scanAndProcess(fullPath, opMode);
                }
                continue;
            }

            if (opMode == "encrypt" || opMode == "sync") {
                processOriginalForEncrypt(fullPath, dir, entry, opMode);
            } else if (opMode == "decrypt") {
                processEncryptedForDecrypt(fullPath, dir, entry);
            }
        }
    }

    static function processOriginalForEncrypt(fullPath:String, dir:String, fileName:String, opMode:String):Void {
        var ext:String = Path.extension(fileName).toLowerCase();
        if (!SUPPORTED_EXTENSIONS.contains(ext)) return;

        var encryptedExt:String = EXT_MAP.get(ext);
        if (encryptedExt == null) return;

        var baseName:String = Path.withoutExtension(fileName);
        var encPath:String = Path.join([dir, baseName + "." + encryptedExt]);

        if (opMode == "sync" && FileSystem.exists(encPath) && manifest.exists(encPath)) {
            var entry:ManifestEntry = manifest.get(encPath);
            var currentHash:String = hashFile(fullPath);
            if (currentHash == entry.hash) {
                if (verbose) Sys.println("  [OK] " + fullPath);
                skippedCount++;
                return;
            }
            Sys.println("  [CHANGED] " + fullPath);
        } else if (opMode == "encrypt" && FileSystem.exists(encPath) && manifest.exists(encPath)) {
            if (verbose) Sys.println("  [SKIP] " + fullPath);
            skippedCount++;
            return;
        }

        encryptFile(fullPath, dir, fileName);
    }

    static function processEncryptedForDecrypt(fullPath:String, dir:String, fileName:String):Void {
        var ext:String = Path.extension(fileName).toLowerCase();
        var originalExt:String = EXT_REVERSE.get(ext);
        if (originalExt == null) return;

        decryptFile(fullPath, dir, fileName);
    }

    // ══════════════════════════════════════════════════════
    //  ENCRYPT / DECRYPT CORE
    // ══════════════════════════════════════════════════════
    static function encryptFile(fullPath:String, dir:String, fileName:String):Void {
        try {
            var fileBytes:Bytes = File.getBytes(fullPath);
            var fileSize:Int = fileBytes.length;
            totalBytesIn += fileSize;

            if (verbose) Sys.println("  [READ] " + fullPath + " (" + formatSize(fileSize) + ")");

            var fileKey:Bytes = deriveFileKey(fullPath);
            var encrypted:Bytes = xorCrypt(fileBytes, fileKey);

            var header:Bytes = Bytes.alloc(HEADER_SIZE);
            // MAGIC: DARK
            header.set(0, 0x44); header.set(1, 0x41); header.set(2, 0x52); header.set(3, 0x4B);
            // VERSION
            writeInt32BE(header, 4, VERSION);
            // ORIGINAL SIZE
            writeInt32BE(header, 8, fileSize);

            var output:Bytes = Bytes.alloc(HEADER_SIZE + encrypted.length);
            output.blit(0, header, 0, HEADER_SIZE);
            output.blit(HEADER_SIZE, encrypted, 0, encrypted.length);

            var ext:String = Path.extension(fileName).toLowerCase();
            var encryptedExt:String = EXT_MAP.get(ext);
            var encFileName:String = Path.withoutExtension(fileName) + "." + encryptedExt;
            var encPath:String = Path.join([dir, encFileName]);

            if (!dryRun) {
                var out = File.write(encPath, true);
                out.write(output);
                out.close();

                manifest.set(encPath, {
                    originalSize: fileSize,
                    hash: hashFile(fullPath),
                    encryptedAt: Date.now().toString()
                });
            }

            totalBytesOut += output.length;
            if (verbose) Sys.println("  [WRITE] " + encPath + " (" + formatSize(output.length) + ")");

            if (deleteOriginals && !dryRun) {
                FileSystem.deleteFile(fullPath);
                if (verbose) Sys.println("  [DELETE] " + fullPath);
            }

            encryptedCount++;
        } catch (e:Dynamic) {
            Sys.println("  [ERROR] " + fullPath + " - " + Std.string(e));
            errorCount++;
        }
    }

    static function decryptFile(fullPath:String, dir:String, fileName:String):Void {
        try {
            var fileBytes:Bytes = File.getBytes(fullPath);
            var fileSize:Int = fileBytes.length;

            if (fileSize < HEADER_SIZE) {
                Sys.println("  [ERROR] Too small: " + fullPath);
                errorCount++;
                return;
            }

            // Verify magic
            var magic:String = "";
            for (i in 0...4) magic += String.fromCharCode(fileBytes.get(i));
            if (magic != MAGIC) {
                Sys.println("  [ERROR] Invalid header: " + fullPath);
                errorCount++;
                return;
            }

            var originalSize:Int = readInt32BE(fileBytes, 8);
            if (originalSize <= 0 || originalSize > fileSize * 100) {
                Sys.println("  [ERROR] Bad size in header: " + fullPath);
                errorCount++;
                return;
            }

            var encrypted:Bytes = Bytes.alloc(fileSize - HEADER_SIZE);
            encrypted.blit(0, fileBytes, HEADER_SIZE, fileSize - HEADER_SIZE);

            var fileKey:Bytes = deriveFileKey(fullPath);
            var decrypted:Bytes = xorCrypt(encrypted, fileKey);

            // Verify original format magic
            var origExt:String = EXT_REVERSE.get(Path.extension(fileName).toLowerCase());
            if (!verifyFormatMagic(decrypted, origExt)) {
                Sys.println("  [WARN] Decrypted data invalid, key mismatch? " + fullPath);
                errorCount++;
                return;
            }

            var origFileName:String = Path.withoutExtension(fileName) + "." + origExt;
            var origPath:String = Path.join([dir, origFileName]);

            if (!dryRun) {
                var out = File.write(origPath, true);
                out.write(decrypted);
                out.close();
            }

            totalBytesIn += fileSize;
            totalBytesOut += decrypted.length;

            if (verbose) Sys.println("  [WRITE] " + origPath + " (" + formatSize(decrypted.length) + ")");

            if (deleteOriginals && !dryRun) {
                FileSystem.deleteFile(fullPath);
                manifest.remove(fullPath);
                if (verbose) Sys.println("  [DELETE] " + fullPath);
            }

            decryptedCount++;
        } catch (e:Dynamic) {
            Sys.println("  [ERROR] " + fullPath + " - " + Std.string(e));
            errorCount++;
        }
    }

    // ══════════════════════════════════════════════════════
    //  FORMAT VERIFICATION
    // ══════════════════════════════════════════════════════
    static function verifyFormatMagic(data:Bytes, ext:String):Bool {
        if (data.length < 4) return false;

        switch (ext) {
            case "png":
                // PNG: 89 50 4E 47 (‰PNG)
                return data.get(0) == 0x89 && data.get(1) == 0x50 &&
                       data.get(2) == 0x4E && data.get(3) == 0x47;
            case "ogg":
                // OGG: 4F 67 67 53 (OggS)
                return data.get(0) == 0x4F && data.get(1) == 0x67 &&
                       data.get(2) == 0x67 && data.get(3) == 0x53;
            case "xml":
                // XML: starts with < or BOM then <
                if (data.get(0) == 0xEF && data.get(1) == 0xBB && data.get(2) == 0xBF) {
                    return data.get(3) == 0x3C; // BOM + <
                }
                return data.get(0) == 0x3C; // <
        }
        return true;
    }

    // ══════════════════════════════════════════════════════
    //  STATUS SCANNER
    // ══════════════════════════════════════════════════════


    static function scanForStatus(dir:String):StatusResult {
        var r:StatusResult = {originals: 0, encrypted: 0, orphanOriginals: 0, orphanEncrypted: 0, tracked: 0};
        if (!FileSystem.isDirectory(dir)) return r;

        // Collect originals and encrypted per base name
        var originalsByBase:Map<String, Bool> = new Map();
        var encryptedByBase:Map<String, Bool> = new Map();
        var encryptedPaths:Map<String, Bool> = new Map();

        scanStatusCollect(dir, originalsByBase, encryptedByBase, encryptedPaths);

        // Count originals without encrypted counterpart
        for (base in originalsByBase.keys()) {
            r.originals++;
            if (!encryptedByBase.exists(base)) r.orphanOriginals++;
        }

        // Count encrypted without original
        for (base in encryptedByBase.keys()) {
            r.encrypted++;
            if (!originalsByBase.exists(base)) r.orphanEncrypted++;
        }

        // Count tracked
        for (path in encryptedPaths.keys()) {
            if (manifest.exists(path)) r.tracked++;
        }

        return r;
    }

    static function scanStatusCollect(dir:String, originals:Map<String, Bool>, encrypted:Map<String, Bool>, encPaths:Map<String, Bool>):Void {
        if (!FileSystem.isDirectory(dir)) return;

        var entries:Array<String> = FileSystem.readDirectory(dir);
        for (entry in entries) {
            var fullPath:String = Path.join([dir, entry]);
            if (FileSystem.isDirectory(fullPath)) {
                if (!entry.startsWith(".") && entry != "export" && entry != "bin" && entry != ".git") {
                    scanStatusCollect(fullPath, originals, encrypted, encPaths);
                }
                continue;
            }

            var ext:String = Path.extension(entry).toLowerCase();
            var base:String = Path.withoutExtension(entry);

            if (SUPPORTED_EXTENSIONS.contains(ext)) {
                originals.set(base + "." + ext, true);
            } else if (EXT_REVERSE.exists(ext)) {
                encrypted.set(base + "." + EXT_REVERSE.get(ext), true);
                encPaths.set(fullPath, true);
            }
        }
    }

    // ══════════════════════════════════════════════════════
    //  CRYPTO & MANIFEST
    // ══════════════════════════════════════════════════════
    static function deriveFileKey(filePath:String):Bytes {
        var hash:String = Sha256.encode(SECRET_KEY + "|" + filePath);
        return hexToBytes(hash);
    }

    static function xorCrypt(data:Bytes, key:Bytes):Bytes {
        var result:Bytes = Bytes.alloc(data.length);
        var keyLen:Int = key.length;
        for (i in 0...data.length) {
            result.set(i, data.get(i) ^ key.get(i % keyLen));
        }
        return result;
    }

    static function hashFile(filePath:String):String {
        return Sha256.encode(File.getBytes(filePath).toHex());
    }

    static function hexToBytes(hex:String):Bytes {
        var len:Int = Std.int(hex.length / 2);
        var result:Bytes = Bytes.alloc(len);
        var i:Int = 0;
        while (i < len) {
            result.set(i, Std.parseInt("0x" + hex.charAt(i * 2) + hex.charAt(i * 2 + 1)));
            i++;
        }
        return result;
    }

    static function writeInt32BE(buf:Bytes, pos:Int, val:Int):Void {
        buf.set(pos, (val >> 24) & 0xFF);
        buf.set(pos + 1, (val >> 16) & 0xFF);
        buf.set(pos + 2, (val >> 8) & 0xFF);
        buf.set(pos + 3, val & 0xFF);
    }

    static function readInt32BE(buf:Bytes, pos:Int):Int {
        return (buf.get(pos) << 24) | (buf.get(pos + 1) << 16) |
               (buf.get(pos + 2) << 8) | buf.get(pos + 3);
    }

    // ══════════════════════════════════════════════════════
    //  MANIFEST
    // ══════════════════════════════════════════════════════
    static function loadManifest():Void {
        if (!FileSystem.exists(MANIFEST_FILE)) return;
        try {
            var lines:Array<String> = File.getContent(MANIFEST_FILE).split("\n");
            for (line in lines) {
                line = StringTools.trim(line);
                if (line.length == 0 || line.startsWith("#")) continue;
                var parts:Array<String> = line.split("|");
                if (parts.length >= 3) {
                    manifest.set(parts[0], {
                        originalSize: Std.parseInt(parts[1]),
                        hash: parts[2],
                        encryptedAt: parts.length > 3 ? parts[3] : ""
                    });
                }
            }
        } catch (e:Dynamic) {
            Sys.println("[WARN] Could not load manifest: " + Std.string(e));
        }
    }

    static function saveManifest():Void {
        var lines:Array<String> = [
            "# Dark's Collection V3.5 - Encryption Manifest",
            "# Format: encrypted_path|original_size|sha256_hash|timestamp",
            ""
        ];
        for (path in manifest.keys()) {
            var e:ManifestEntry = manifest.get(path);
            lines.push(path + "|" + e.originalSize + "|" + e.hash + "|" + e.encryptedAt);
        }
        if (!dryRun) File.saveContent(MANIFEST_FILE, lines.join("\n"));
    }

    static function cleanupManifest():Void {
        var toRemove:Array<String> = [];
        for (path in manifest.keys()) {
            if (!FileSystem.exists(path)) toRemove.push(path);
        }
        for (path in toRemove) {
            manifest.remove(path);
            if (verbose) Sys.println("  [CLEANUP] " + path);
        }
    }

    // ══════════════════════════════════════════════════════
    //  UTILS
    // ══════════════════════════════════════════════════════
    static function getDirectories():Array<String> {
        if (targetDir != null) return [targetDir];
        return ["assets", "mods"];
    }

    static function formatSize(bytes:Float):String {
        if (bytes < 1024) return Std.string(Std.int(bytes)) + " B";
        if (bytes < 1024 * 1024) return Std.string(Std.int(bytes / 1024 * 10) / 10) + " KB";
        return Std.string(Std.int(bytes / 1024 * 1024 * 10) / 10) + " MB";
    }

    static function parseArgs():Void {
        var args:Array<String> = Sys.args();
        var i:Int = 0;
        while (i < args.length) {
            switch (args[i]) {
                case "encrypt", "decrypt", "sync", "status": mode = args[i];
                case "--delete-originals", "-d": deleteOriginals = true;
                case "--dry-run", "-n": dryRun = true;
                case "--verbose", "-v": verbose = true;
                case "--dir", "-dir": i++; if (i < args.length) targetDir = args[i];
                case "--help", "-h": printUsage(); Sys.exit(0);
            }
            i++;
        }
    }

    static function printUsage():Void {
        Sys.println("Usage: haxe encrypt_assets.hx [MODE] [OPTIONS]");
        Sys.println("");
        Sys.println("Modes:");
        Sys.println("  encrypt   Encrypt .png/.ogg/.xml → .epng/.eogg/.exml");
        Sys.println("  decrypt   Decrypt .epng/.eogg/.exml → originals");
        Sys.println("  sync      Incremental: only new/changed files");
        Sys.println("  status    Show encryption overview");
        Sys.println("");
        Sys.println("Options:");
        Sys.println("  --delete-originals, -d   Delete source after conversion");
        Sys.println("  --dry-run, -n            Preview without changes");
        Sys.println("  --verbose, -v            Show per-file details");
        Sys.println("  --dir <path>             Target only this directory");
        Sys.println("  --help, -h               Show this help");
        Sys.println("");
        Sys.println("Examples:");
        Sys.println("  haxe encrypt_assets.hx sync --verbose");
        Sys.println("  haxe encrypt_assets.hx decrypt --delete-originals");
        Sys.println("  haxe encrypt_assets.hx status");
    }

    static function printStats():Void {
        Sys.println("");
        Sys.println("═══════════════════════════════════════════════════");
        switch (mode) {
            case "encrypt":
                Sys.println("  ENCRYPTION COMPLETE");
                Sys.println("  Encrypted: " + encryptedCount + " | Skipped: " + skippedCount);
            case "decrypt":
                Sys.println("  DECRYPTION COMPLETE");
                Sys.println("  Decrypted: " + decryptedCount + " | Skipped: " + skippedCount);
            case "sync":
                Sys.println("  SYNC COMPLETE");
                Sys.println("  Encrypted: " + encryptedCount + " | Skipped: " + skippedCount + " (up to date)");
        }
        Sys.println("  Errors: " + errorCount);
        Sys.println("  In: " + formatSize(totalBytesIn) + " | Out: " + formatSize(totalBytesOut));
        Sys.println("═══════════════════════════════════════════════════");
    }
}
