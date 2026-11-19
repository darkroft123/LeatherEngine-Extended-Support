package system;

import haxe.io.Bytes;
import haxe.io.Path;
import haxe.crypto.Sha256;
import sys.FileSystem;
import sys.io.File;
import openfl.display.BitmapData;
import openfl.utils.ByteArray;
import openfl.media.Sound;
import lime.media.AudioBuffer;

/**
 * Anti-Leak Runtime Decryption System
 *
 * Intercepts asset loading to transparently decrypt encrypted files.
 * Supports: .epng → PNG, .eogg → OGG, .exml → XML
 *
 * The encryption key is hardcoded and derived per-file using SHA-256.
 * Same key derivation as the build-time encrypt_assets tool.
 */
class AntiLeak {
    public static inline var DEFAULT_KEY:String = "Drk_C0ll3ct10n_@nt1_l34k_2024_x0r!";
    static var SECRET_KEY(get, never):String;
    static var _cachedSecretKey:String = null;

    public static function setSecretKey(key:String):Void {
        if (key != null && key != "") {
            _cachedSecretKey = key;
        }
    }

    static function get_SECRET_KEY():String {
        if (_cachedSecretKey != null) return _cachedSecretKey;
        #if ANTI_LEAK_KEY
        _cachedSecretKey = haxe.macro.Compiler.getDefine("ANTI_LEAK_KEY");
        #else
        #if sys
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
        #end
        _cachedSecretKey = DEFAULT_KEY;
        #end
        return _cachedSecretKey;
    }

    public static function decryptHex(hex:String, keyPath:String = "secrets.json"):String {
        if (hex == null || hex.length < HEADER_SIZE * 2) return null;
        var bytes = hexToBytes(hex);
        return decryptRawBytes(bytes, keyPath);
    }

    public static function decryptRawBytes(fileBytes:Bytes, keyPath:String = "secrets.json"):String {
        if (fileBytes == null || fileBytes.length < HEADER_SIZE) return null;

        var magic:String = "";
        for (i in 0...4) {
            magic += String.fromCharCode(fileBytes.get(i));
        }
        if (magic != MAGIC) return null;

        var originalSize:Int = (fileBytes.get(8) << 24) |
                               (fileBytes.get(9) << 16) |
                               (fileBytes.get(10) << 8) |
                               fileBytes.get(11);
        if (originalSize <= 0 || originalSize > (fileBytes.length - HEADER_SIZE)) return null;

        var encrypted:Bytes = Bytes.alloc(fileBytes.length - HEADER_SIZE);
        encrypted.blit(0, fileBytes, HEADER_SIZE, fileBytes.length - HEADER_SIZE);

        var fileKey:Bytes = deriveFileKey(keyPath);
        var decrypted:Bytes = xorCrypt(encrypted, fileKey);
        return decrypted.getString(0, originalSize);
    }

    static inline var MAGIC:String = "DARK";
    static inline var HEADER_SIZE:Int = 12;

    // Extension mapping: encrypted → original
    static var EXT_REVERSE:Map<String, String> = [
        "epng" => "png",
        "eogg" => "ogg",
        "exml" => "xml"
    ];

    // Decryption caches to avoid re-decrypting or re-decoding the same file
    static var decryptCache:Map<String, Bytes> = new Map();
    static var soundCache:Map<String, Sound> = new Map();
    static var imageCache:Map<String, BitmapData> = new Map();

    /**
     * Checks if a file path has an encrypted variant (.e{ext}).
     * @param path Original asset path (e.g. "assets/images/character.png")
     * @return The encrypted path if it exists, null otherwise
     */
    public static function getEncryptedPath(path:String):String {
        var ext:String = Path.extension(path).toLowerCase();
        var encryptedExt:String = EXT_REVERSE.get(ext);
        if (encryptedExt == null) return null;

        var encPath:String = Path.join([Path.directory(path), Path.withoutExtension(path) + "." + encryptedExt]);

        // For Lime/OpenFL asset paths like "assets/images/file.png" or "shared:assets/shared/images/file.png"
        if (FileSystem.exists(encPath)) return encPath;

        // Handle library-prefixed paths: "library:assets/library/file.png"
        var colonIdx:Int = path.indexOf(":");
        if (colonIdx != -1) {
            var library:String = path.substring(0, colonIdx);
            var rest:String = path.substring(colonIdx + 1);
            var encRest:String = Path.join([Path.directory(rest), Path.withoutExtension(rest) + "." + encryptedExt]);
            var fullEncPath:String = library + ":" + encRest;

            // Check filesystem for the actual file
            if (FileSystem.exists(encRest)) return fullEncPath;
        }

        return null;
    }

    /**
     * Checks if an encrypted version exists for the given path.
     */
    public static function hasEncryptedVersion(path:String):Bool {
        return getEncryptedPath(path) != null;
    }

    /**
     * Decrypts an encrypted asset file and returns raw bytes.
     * @param encPath Path to the .e{ext} file
     * @return Decrypted bytes in the original format, or null on failure
     */
    public static function decryptFile(encPath:String):Bytes {
        // Check cache first
        if (decryptCache.exists(encPath)) {
            return decryptCache.get(encPath);
        }

        try {
            if (!FileSystem.exists(encPath)) return null;

            var fileBytes:Bytes = File.getBytes(encPath);
            var fileSize:Int = fileBytes.length;

            if (fileSize < HEADER_SIZE) return null;

            // Verify magic header
            var magic:String = "";
            for (i in 0...4) {
                magic += String.fromCharCode(fileBytes.get(i));
            }
            if (magic != MAGIC) return null;

            // Read original size
            var originalSize:Int = (fileBytes.get(8) << 24) |
                                   (fileBytes.get(9) << 16) |
                                   (fileBytes.get(10) << 8) |
                                   fileBytes.get(11);

            if (originalSize <= 0 || originalSize > fileSize * 100) return null;

            // Extract encrypted payload
            var encrypted:Bytes = Bytes.alloc(fileSize - HEADER_SIZE);
            encrypted.blit(0, fileBytes, HEADER_SIZE, fileSize - HEADER_SIZE);

            // Derive the same per-file key used during encryption
            var fileKey:Bytes = deriveFileKey(encPath);

            // XOR decrypt (symmetric)
            var decrypted:Bytes = xorCrypt(encrypted, fileKey);

            // Cache the result
            decryptCache.set(encPath, decrypted);

            return decrypted;
        } catch (e:Dynamic) {
            trace("AntiLeak: Error decrypting " + encPath + " - " + Std.string(e));
            return null;
        }
    }

    /**
     * Loads and decrypts an image file, returning a BitmapData.
     * @param originalPath The original .png path
     * @return BitmapData from decrypted PNG, or null
     */
    public static function loadDecryptedImage(originalPath:String):BitmapData {
        var encPath:String = getEncryptedPath(originalPath);
        if (encPath == null) return null;

        if (imageCache.exists(encPath)) {
            return imageCache.get(encPath);
        }

        var decrypted:Bytes = decryptFile(encPath);
        if (decrypted == null) return null;

        try {
            // Convert haxe.io.Bytes → ByteArray for OpenFL
            var ba:ByteArray = ByteArray.fromBytes(decrypted);
            var bmp:BitmapData = BitmapData.fromBytes(ba);
            if (bmp != null) {
                imageCache.set(encPath, bmp);
            }
            return bmp;
        } catch (e:Dynamic) {
            trace("AntiLeak: Error creating BitmapData from " + encPath + " - " + Std.string(e));
            return null;
        }
    }

    /**
     * Loads and decrypts a sound file, returning a Sound.
     * Uses zero-disk in-memory AudioBuffer decoding for maximum performance.
     * @param originalPath The original .ogg path
     * @return Sound from decrypted OGG, or null
     */
    public static function loadDecryptedSound(originalPath:String):Sound {
        var encPath:String = getEncryptedPath(originalPath);
        if (encPath == null) return null;

        if (soundCache.exists(encPath)) {
            return soundCache.get(encPath);
        }

        var decrypted:Bytes = decryptFile(encPath);
        if (decrypted == null) return null;

        try {
            // Direct in-memory AudioBuffer decoding without disk I/O bottlenecks
            var audioBuffer:lime.media.AudioBuffer = lime.media.AudioBuffer.fromBytes(decrypted);
            if (audioBuffer == null) return null;

            var sound:Sound = new Sound();
            @:privateAccess {
                sound.__buffer = audioBuffer;
            }
            soundCache.set(encPath, sound);
            return sound;
        } catch (e:Dynamic) {
            trace("AntiLeak: Error creating Sound from " + encPath + " - " + Std.string(e));
            return null;
        }
    }

    /**
     * Loads and decrypts an XML file, returning the raw text content.
     * @param originalPath The original .xml path
     * @return XML string content, or null
     */
    public static function loadDecryptedXML(originalPath:String):String {
        var encPath:String = getEncryptedPath(originalPath);
        if (encPath == null) return null;

        var decrypted:Bytes = decryptFile(encPath);
        if (decrypted == null) return null;

        try {
            return decrypted.toString();
        } catch (e:Dynamic) {
            trace("AntiLeak: Error converting XML from " + encPath + " - " + Std.string(e));
            return null;
        }
    }

    /**
     * Generic: loads any encrypted file and returns its decrypted bytes.
     * @param originalPath The original file path
     * @return Decrypted bytes, or null
     */
    public static function loadDecrypted(originalPath:String):Bytes {
        var encPath:String = getEncryptedPath(originalPath);
        if (encPath == null) return null;
        return decryptFile(encPath);
    }

    /**
     * Clears the decryption cache (free memory).
     */
    public static function clearCache():Void {
        decryptCache.clear();
        for (snd in soundCache) {
            if (snd != null) {
                snd.close();
                @:privateAccess {
                    if (snd.__buffer != null) {
                        try { snd.__buffer.dispose(); } catch (e:Dynamic) {}
                        snd.__buffer = null;
                    }
                }
            }
        }
        soundCache.clear();

        for (bmp in imageCache) {
            if (bmp != null) {
                try { bmp.dispose(); } catch (e:Dynamic) {}
            }
        }
        imageCache.clear();
    }

    /**
     * Returns the number of files currently cached.
     */
    public static function cacheSize():Int {
        var count:Int = 0;
        for (_ in decryptCache.keys()) count++;
        return count;
    }

    // ══════════════════════════════════════════════════════
    //  INTERNAL CRYPTO
    // ══════════════════════════════════════════════════════

    /**
     * Derives a per-file XOR key using SHA-256(secret + path).
     * Must match the exact same logic in tools/encrypt_assets.hx
     */
    static function deriveFileKey(filePath:String):Bytes {
        var hash:String = Sha256.encode(SECRET_KEY + "|" + filePath);
        return hexToBytes(hash);
    }

    /**
     * XOR symmetric encryption/decryption with a cycling key.
     */
    static function xorCrypt(data:Bytes, key:Bytes):Bytes {
        var result:Bytes = Bytes.alloc(data.length);
        var keyLen:Int = key.length;
        for (i in 0...data.length) {
            result.set(i, data.get(i) ^ key.get(i % keyLen));
        }
        return result;
    }

    /**
     * Converts a hex string to Bytes.
     */
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
}
