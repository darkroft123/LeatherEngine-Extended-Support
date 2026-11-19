package utilities;

import lime.system.CFFI;
#if sys
import sys.FileSystem;
import sys.io.File;
import haxe.crypto.Sha256;
#end

/**
 * Hardened Native Dynamic Library (NDLL) Loader.
 * Protects players against malicious arbitrary native library execution in downloaded mods.
 */
class NdllLoader {
	/**
	 * Whitelist of verified NDLL SHA-256 checksums (lowercase).
	 * Any NDLL not present in this map or failing checksum verification will be rejected.
	 */
	public static var verifiedChecksums:Map<String, String> = [
		// Pre-approved native modules can be registered here:
		// "example_ndll" => "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
	];

	/**
	 * Safety flag: when false (default), arbitrary unverified .ndll loading is strictly prohibited.
	 */
	public static var allowArbitraryNdll:Bool = false;

	/**
	 * Registers an approved NDLL name and its expected SHA-256 hash.
	 */
	public static function registerVerifiedNdll(name:String, sha256Hex:String):Void {
		verifiedChecksums.set(name, sha256Hex.toLowerCase());
	}

	/**
	 * Load a function from a NDLL and return it with cryptographic integrity check.
	 * @param ndll 
	 * @param func 
	 * @param args 
	 * @param lazy 
	 * @return Dynamic
	 */
	public static function load(ndll:String, func:String, args:Int, lazy:Bool = false):Dynamic {
		var path = Paths.getModPath('assets/ndlls/$ndll.ndll');

		#if sys
		if (!FileSystem.exists(path)) {
			trace('[SECURITY] NdllLoader: NDLL not found at $path', WARNING);
			return null;
		}

		if (!allowArbitraryNdll) {
			var expectedHash = verifiedChecksums.get(ndll);
			if (expectedHash == null) {
				trace('[SECURITY ALERT] Blocked unverified NDLL execution: "$ndll" is not whitelisted.', ERROR);
				return null;
			}

			try {
				var fileBytes = File.getBytes(path);
				var calculatedHash = Sha256.encode(fileBytes.toString()).toLowerCase();
				if (calculatedHash != expectedHash) {
					trace('[SECURITY ALERT] Blocked compromised NDLL: "$ndll" hash mismatch! Expected: $expectedHash, got: $calculatedHash', ERROR);
					return null;
				}
			} catch (e:Dynamic) {
				trace('[SECURITY ALERT] Failed to compute NDLL checksum for "$ndll": $e', ERROR);
				return null;
			}
		}
		#end

		return CFFI.load(path, func, args, lazy);
	}
    
    /**
     * Call a function from `load()`
     * @param func 
     * @param args 
     * @return Dynamic
     */
    public static function call(func:Dynamic, args:Array<Dynamic>):Dynamic{
        if (func == null) return null;
        switch(args.length){
            case 0: 
                return func();
            case 1:
                return func(args[0]);
            case 2:
                return func(args[0], args[1]);
            case 3:
                return func(args[0], args[1], args[2]);
            case 4:
                return func(args[0], args[1], args[2], args[3]);
            case 5:
                return func(args[0], args[1], args[2], args[3], args[4]);
            case 6:
                return func(args[0], args[1], args[2], args[3], args[4], args[5]);
            case 7:
                return func(args[0], args[1], args[2], args[3], args[4], args[5], args[6]);
            case 8:
                return func(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7]);
            default:
                throw "Too many arguments";
        }
    }
}
