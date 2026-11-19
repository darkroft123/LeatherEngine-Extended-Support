package;

import sys.FileSystem;
import flxanimate.FlxAnimateFrames;
import lime.utils.Assets;
import flixel.FlxG;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.system.FlxAssets.FlxGraphicAsset;
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenFlAssets;
import openfl.display.BitmapData;
import haxe.Json;
import haxe.io.Path;

/**
 * Assets paths helper class
 */
class Paths {
	public static var currentLevel:String = "preload";

	// Encrypted extension mapping
	static var ENC_MAP:Map<String, String> = [
		"png" => "epng",
		"ogg" => "eogg",
		"xml" => "exml"
	];

	static public function setCurrentLevel(name:String)
	{
		currentLevel = name.toLowerCase();
	}


	public static function getPath(file:String, type:AssetType, library:Null<String>):String {
		if (library != null)
			return getLibraryPath(file, library);

		if (currentLevel != null) {
			var levelPath = getLibraryPathForce(file, currentLevel);

			if (existsOrEncrypted(levelPath, type))
				return resolveEncrypted(levelPath);

			levelPath = getLibraryPathForce(file, "shared");

			if (existsOrEncrypted(levelPath, type))
				return resolveEncrypted(levelPath);
		}

		return resolveEncrypted(getPreloadPath(file));
	}

	/**
	 * Checks if a file exists as-is or in its encrypted form (.e{ext}).
	 */
	static function existsOrEncrypted(path:String, ?type:AssetType):Bool {
		if (OpenFlAssets.exists(path, type)) return true;

		// Check encrypted version
		var ext:String = Path.extension(path).toLowerCase();
		var encExt:String = ENC_MAP.get(ext);
		if (encExt == null) return false;

		var encPath:String = Path.join([Path.directory(path), Path.withoutExtension(path) + "." + encExt]);

		// Check filesystem directly (faster than OpenFlAssets for encrypted files)
		if (sys.FileSystem.exists(encPath)) return true;

		// Also check via OpenFlAssets with library prefix
		if (OpenFlAssets.exists(encPath, type)) return true;

		return false;
	}

	/**
	 * Returns the original path if it exists, or the encrypted path if only encrypted exists.
	 */
	static function resolveEncrypted(path:String):String {
		if (OpenFlAssets.exists(path)) return path;

		var ext:String = Path.extension(path).toLowerCase();
		var encExt:String = ENC_MAP.get(ext);
		if (encExt == null) return path;

		var encPath:String = Path.join([Path.directory(path), Path.withoutExtension(path) + "." + encExt]);
		if (sys.FileSystem.exists(encPath) || OpenFlAssets.exists(encPath)) return encPath;

		return path;
	}

	static public function getLibraryPath(file:String, library = "preload"):String
		return if (library == "preload" || library == "default") getPreloadPath(file); else getLibraryPathForce(file, library);

	inline static function getLibraryPathForce(file:String, library:String):String
		return '$library:assets/$library/$file';

	inline static public function getPreloadPath(file:String):String
		return 'assets/$file';

	inline static public function lua(key:String, ?library:String):String
		return getPath('data/$key.lua', TEXT, library);

	inline static public function hx(key:String, ?library:String):String
		return getPath('$key.hx', TEXT, library);

	static public function frag(key:String, ?library:String):String {
		var path = getPath('shaders/$key.frag', TEXT, library);
		return path;
	}

	static public function vert(key:String, ?library:String):String {
		var path = getPath('shaders/$key.vert', TEXT, library);
		return path;
	}

	inline static public function file(file:String, type:AssetType = TEXT, ?library:String):String
		return getPath(file, type, library);

	inline static public function txt(key:String, ?library:String):String
		return getPath('data/$key.txt', TEXT, library);

	inline static public function xml(key:String, ?library:String):String
		return getPath('data/$key.xml', TEXT, library);

	inline static public function ui(key:String, ?library:String):String
		return getPath('ui/$key.xml', TEXT, library);

	inline static public function json(key:String, ?library:String):String
		return getPath('data/$key.json', TEXT, library);

	inline static public function video(key:String, ext:String = "mp4"):String
		return 'assets/videos/$key.$ext';

	inline static public function sound(key:String, ?library:String):String
		return getPath('sounds/$key.ogg', SOUND, library);

	inline static public function soundRandom(key:String, min:Int, max:Int, ?library:String):String
		return sound(key + FlxG.random.int(min, max), library);

	inline static public function music(key:String, ?library:String):String
		return getPath('music/$key.ogg', MUSIC, library);

	inline static public function image(key:String, ?library:String):String {
		return getPath('images/$key.png', IMAGE, library);
	}

	/**
	 * Gets an image in any mod or base asset to the gpu when possible.
	 * @see https://github.com/Ralsin/FNF-MintEngine/blob/1c681b35e081c1b297f47ed06815503f6ed7089a/source/funkin/api/FileManager.hx#L45
	 * @param key The path of the image
	 * @param library The image package. (ex shared). NOTE: Will search through other packages to find the image when possible.
	 * @param avoidGPU Force loading to  of the graphic to the cpu.
	 * @return The image as a `FlxGraphic`. Will retrun the image path if gpu caching is not possible.
	 */
	static public function gpuBitmap(key:String, ?library:String, avoidGPU:Bool = false):FlxGraphicAsset {
		var file:String = image(key, library);
		if (avoidGPU) {
			return file;
		}
		var graphic = system.OptimizedAssets.getGraphic(file, avoidGPU);
		if (graphic != null) {
			return graphic;
		}
		return file;
	}

	inline static public function font(key:String):String
		return 'assets/fonts/$key';

	inline static public function ndll(key:String, ?library:String):String
		return getPath('ndlls/$key.ndll', TEXT, library);
	public static var audioMapCache:Map<String, Dynamic> = new Map();
	static function getAudioMap(song:String):Dynamic {
		if (audioMapCache.exists(song)) {
			return audioMapCache.get(song);
		}
		#if (sys && MODDING_ALLOWED)
		var curMod:String = Options.getData("curMod");
		if (curMod != null && curMod != "") {
			var songLower = song.toLowerCase().trim();
			var songDash = songLower.replace(" ", "-");
			var songSpace = songLower.replace("-", " ");
			for (s in [song, songLower, songDash, songSpace]) {
				var p = 'mods/' + curMod + '/songs/' + s + '/audioMap.json';
				if (FileSystem.exists(p)) {
					try {
						var data = Json.parse(sys.io.File.getContent(p));
						audioMapCache.set(song, data);
						return data;
					} catch(e:Dynamic) {}
				}
			}
		}
		#end
		var path = 'songs:assets/songs/${song.toLowerCase()}/audioMap.json';
		if (!Assets.exists(path)) {
			return null;
		}
		var raw = Assets.getText(path);
		var data = Json.parse(raw);
		audioMapCache.set(song, data);
		return data;
	}

	static function findAudioByDiff(map:Dynamic, prefix:String, diff:String):String {
		if (map == null || diff == null) return null;
		var diffLower = diff.toLowerCase();
		for (key in Reflect.fields(map)) {
			if (!key.toLowerCase().startsWith(prefix.toLowerCase())) continue;
			var diffs:Array<String> = Reflect.field(map, key);
			for (d in diffs) {
				if (d.toLowerCase() == diffLower) return key;
			}
		}
		return null;
	}

	static function findAudioInDir(song:String, prefix:String, ?diff:String):String {
		#if (sys && MODDING_ALLOWED)
		var songLower = song.toLowerCase().trim();
		var songDash = songLower.replace(" ", "-");
		var songSpace = songLower.replace("-", " ");
		var targetDirs:Array<String> = [];

		for (mod in modding.ModList.getActiveMods(modding.PolymodHandler.metadataArrays)) {
			for (s in [song, songLower, songDash, songSpace]) {
				var d = 'mods/$mod/songs/$s';
				if (FileSystem.exists(d) && FileSystem.isDirectory(d)) {
					if (!targetDirs.contains(d)) targetDirs.push(d);
				}
			}
		}
		for (s in [song, songLower, songDash, songSpace]) {
			var d = 'assets/songs/$s';
			if (FileSystem.exists(d) && FileSystem.isDirectory(d)) {
				if (!targetDirs.contains(d)) targetDirs.push(d);
			}
		}

		var prefixLower = prefix.toLowerCase();
		var diffLower = (diff != null && diff != "") ? diff.toLowerCase().trim() : null;

		for (dir in targetDirs) {
			try {
				var makePath = function(sub:String):String {
					if (dir.startsWith("mods/")) {
						return '$dir/$sub';
					}
					var rel = dir.substr(dir.indexOf("songs/"));
					return 'songs:assets/$rel/$sub';
				};

				var files = FileSystem.readDirectory(dir);
				// 0. Try match audioMap if available
				if (diffLower != null && diffLower != "normal") {
					var map = getAudioMap(song);
					var jsonKey = findAudioByDiff(map, prefixLower, diffLower);
					if (jsonKey != null) {
						var jsonKeyLower = jsonKey.toLowerCase();
						for (f in files) {
							if (f.toLowerCase() == jsonKeyLower + '.ogg') {
								return makePath(f);
							}
						}
					}
				}
				// 1. Try match prefix + diff (e.g. Inst-Redemptiion.ogg or Voices-Redemptiion.ogg)
				if (diffLower != null && diffLower != "normal") {
					for (f in files) {
						var fLow = f.toLowerCase();
						if (fLow.startsWith(prefixLower) && fLow.contains(diffLower) && fLow.endsWith(".ogg")) {
							return makePath(f);
						}
					}
				}
				// 2. Try match exact prefix (e.g. Inst.ogg, voices.ogg, Inst-Normal.ogg)
				for (f in files) {
					var fLow = f.toLowerCase();
					if ((fLow == '$prefixLower.ogg' || fLow == '$prefixLower-normal.ogg') && fLow.endsWith(".ogg")) {
						return makePath(f);
					}
				}
				// 3. Try in song/ subfolder (CNE format)
				if (FileSystem.exists('$dir/song') && FileSystem.isDirectory('$dir/song')) {
					var subFiles = FileSystem.readDirectory('$dir/song');
					for (f in subFiles) {
						var fLow = f.toLowerCase();
						if (fLow.startsWith(prefixLower) && fLow.endsWith(".ogg")) {
							return makePath('song/$f');
						}
					}
				}
				// 4. If any prefix file exists, use it as fallback
				if (diffLower == null || prefixLower == "inst") {
					var matching = files.filter(f -> f.toLowerCase().startsWith(prefixLower) && f.toLowerCase().endsWith(".ogg"));
					if (matching.length > 0) {
						return makePath(matching[0]);
					}
				}
			} catch (e:Dynamic) { Main.logSilentError(e, "Paths: song assets directory scan"); }
		}
		#end
		return null;
	}

	static public function voices(song:String, ?difficulty:String, ?character:String, ?mix:String):String {
		var songLower = song.toLowerCase();
		var basePaths:Array<String> = [
			'songs:assets/songs/$songLower/',
			'songs:assets/songs/$song/',
			'songs:assets/songs/${songLower.replace(" ", "-")}/',
			'songs:assets/songs/${songLower.replace("-", " ")}/'
		];

		var map = getAudioMap(song);
		var jsonBase = findAudioByDiff(map, 'voices', difficulty);

		for (basePath in basePaths) {
			var baseName = jsonBase != null ? jsonBase : 'Voices';

			if (character != null && mix != null) {
				if (Assets.exists('$basePath$baseName-$character-$mix.ogg')) return '$basePath$baseName-$character-$mix.ogg';
				if (Assets.exists('$basePath$baseName-$character-${mix.toLowerCase()}.ogg')) return '$basePath$baseName-$character-${mix.toLowerCase()}.ogg';
			}
			if (character != null) {
				if (Assets.exists('$basePath$baseName-$character.ogg')) return '$basePath$baseName-$character.ogg';
				if (Assets.exists('$basePath$baseName-${character.toLowerCase()}.ogg')) return '$basePath$baseName-${character.toLowerCase()}.ogg';
			}
			if (mix != null) {
				if (Assets.exists('$basePath$baseName-$mix.ogg')) return '$basePath$baseName-$mix.ogg';
				if (Assets.exists('$basePath$baseName-${mix.toLowerCase()}.ogg')) return '$basePath$baseName-${mix.toLowerCase()}.ogg';
			}
			if (difficulty != null && difficulty != "") {
				var diffLower = difficulty.toLowerCase();
				if (diffLower == 'nightmare' && Assets.exists('$basePath$baseName-erect.ogg')) return '$basePath$baseName-erect.ogg';
				if (Assets.exists('$basePath$baseName-$difficulty.ogg')) return '$basePath$baseName-$difficulty.ogg';
				if (Assets.exists('$basePath$baseName-$diffLower.ogg')) return '$basePath$baseName-$diffLower.ogg';
				if (Assets.exists('$basePath${baseName.toLowerCase()}-$difficulty.ogg')) return '$basePath${baseName.toLowerCase()}-$difficulty.ogg';
				if (Assets.exists('$basePath${baseName.toLowerCase()}-$diffLower.ogg')) return '$basePath${baseName.toLowerCase()}-$diffLower.ogg';
			}
			if (Assets.exists('$basePath$baseName.ogg')) return '$basePath$baseName.ogg';
			if (Assets.exists('$basePath${baseName.toLowerCase()}.ogg')) return '$basePath${baseName.toLowerCase()}.ogg';

			if (character != null) {
				if (Assets.exists('${basePath}song/$baseName-$character.ogg')) return '${basePath}song/$baseName-$character.ogg';
				if (Assets.exists('${basePath}song/$baseName-${character.toLowerCase()}.ogg')) return '${basePath}song/$baseName-${character.toLowerCase()}.ogg';
			}
			if (mix != null) {
				if (Assets.exists('${basePath}song/$baseName-$mix.ogg')) return '${basePath}song/$baseName-$mix.ogg';
				if (Assets.exists('${basePath}song/$baseName-${mix.toLowerCase()}.ogg')) return '${basePath}song/$baseName-${mix.toLowerCase()}.ogg';
			}
			if (difficulty != null && difficulty != "") {
				var diffLower = difficulty.toLowerCase();
				if (diffLower == 'nightmare' && Assets.exists('${basePath}song/$baseName-erect.ogg')) return '${basePath}song/$baseName-erect.ogg';
				if (Assets.exists('${basePath}song/$baseName-$difficulty.ogg')) return '${basePath}song/$baseName-$difficulty.ogg';
				if (Assets.exists('${basePath}song/$baseName-$diffLower.ogg')) return '${basePath}song/$baseName-$diffLower.ogg';
			}
			if (Assets.exists('${basePath}song/$baseName.ogg')) return '${basePath}song/$baseName.ogg';
			if (Assets.exists('${basePath}song/${baseName.toLowerCase()}.ogg')) return '${basePath}song/${baseName.toLowerCase()}.ogg';
		}

		var dirFound = findAudioInDir(song, 'voices', difficulty);
		if (dirFound != null) return dirFound;

		return null;
	}

	static public function inst(song:String, ?difficulty:String, ?mix:String):String {
		var songLower = song.toLowerCase();
		var basePaths:Array<String> = [
			'songs:assets/songs/$songLower/',
			'songs:assets/songs/$song/',
			'songs:assets/songs/${songLower.replace(" ", "-")}/',
			'songs:assets/songs/${songLower.replace("-", " ")}/'
		];

		var map = getAudioMap(song);

		for (basePath in basePaths) {
			var baseName = 'Inst';
			var jsonKey = findAudioByDiff(map, baseName.toLowerCase(), difficulty);
			if (jsonKey != null && Assets.exists('$basePath$jsonKey.ogg')) return '$basePath$jsonKey.ogg';

			if (mix != null) {
				if (Assets.exists('$basePath$baseName-$mix.ogg')) return '$basePath$baseName-$mix.ogg';
				if (Assets.exists('$basePath$baseName-${mix.toLowerCase()}.ogg')) return '$basePath$baseName-${mix.toLowerCase()}.ogg';
			}

			if (difficulty != null && difficulty != "") {
				var diffLower = difficulty.toLowerCase();
				if (diffLower == 'nightmare' && Assets.exists('$basePath$baseName-erect.ogg')) return '$basePath$baseName-erect.ogg';
				if (Assets.exists('$basePath$baseName-$difficulty.ogg')) return '$basePath$baseName-$difficulty.ogg';
				if (Assets.exists('$basePath$baseName-$diffLower.ogg')) return '$basePath$baseName-$diffLower.ogg';
				if (Assets.exists('$basePath${baseName.toLowerCase()}-$difficulty.ogg')) return '$basePath${baseName.toLowerCase()}-$difficulty.ogg';
				if (Assets.exists('$basePath${baseName.toLowerCase()}-$diffLower.ogg')) return '$basePath${baseName.toLowerCase()}-$diffLower.ogg';
			}
			if (Assets.exists('$basePath$baseName.ogg')) return '$basePath$baseName.ogg';
			if (Assets.exists('$basePath${baseName.toLowerCase()}.ogg')) return '$basePath${baseName.toLowerCase()}.ogg';

			if (difficulty != null && difficulty != "") {
				var diffLower = difficulty.toLowerCase();
				if (diffLower == 'nightmare' && Assets.exists('${basePath}song/$baseName-erect.ogg')) return '${basePath}song/$baseName-erect.ogg';
				if (Assets.exists('${basePath}song/$baseName-$difficulty.ogg')) return '${basePath}song/$baseName-$difficulty.ogg';
				if (Assets.exists('${basePath}song/$baseName-$diffLower.ogg')) return '${basePath}song/$baseName-$diffLower.ogg';
			}
			if (Assets.exists('${basePath}song/$baseName.ogg')) return '${basePath}song/$baseName.ogg';
			if (Assets.exists('${basePath}song/${baseName.toLowerCase()}.ogg')) return '${basePath}song/${baseName.toLowerCase()}.ogg';
		}

		var dirFound = findAudioInDir(song, 'inst', difficulty);
		if (dirFound != null) return dirFound;

		return 'songs:assets/songs/$songLower/Inst.ogg';
	}


	static public function songEvents(song:String, ?difficulty:String):String {
		var songLower = song.toLowerCase().trim();
		var songDash = songLower.replace(" ", "-");
		var songSpace = songLower.replace("-", " ");
		var diffLower = difficulty != null ? difficulty.toLowerCase().trim() : null;

		var folderVariants = [song, songLower, songDash, songSpace];
		var diffVariants:Array<String> = [];
		if (difficulty != null && difficulty != "") {
			diffVariants.push(difficulty);
			if (diffLower != difficulty) diffVariants.push(diffLower);
			if (diffLower == 'nightmare') diffVariants.push('erect');
		}

		for (f in folderVariants) {
			for (d in diffVariants) {
				var p = json('song data/$f/events-$d');
				if (Assets.exists(p)) return p;
			}
			var p = json('song data/$f/events');
			if (Assets.exists(p)) return p;
		}

		#if (sys && MODDING_ALLOWED)
		for (mod in modding.ModList.getActiveMods(modding.PolymodHandler.metadataArrays)) {
			for (f in folderVariants) {
				var dir = 'mods/$mod/data/song data/$f';
				if (FileSystem.exists(dir) && FileSystem.isDirectory(dir)) {
					try {
						var files = FileSystem.readDirectory(dir);
						if (diffLower != null && diffLower != "" && diffLower != "normal") {
							for (file in files) {
								var fileLow = file.toLowerCase();
								if (fileLow.startsWith("events-") && fileLow.contains(diffLower) && fileLow.endsWith(".json")) {
									return json('song data/$f/' + file.substr(0, file.length - 5));
								}
							}
						}
						for (file in files) {
							if (file.toLowerCase() == "events.json") {
								return json('song data/$f/events');
							}
						}
					} catch (e:Dynamic) { Main.logSilentError(e, "Paths: scan for events.json"); }
				}
			}
		}
		#end

		return json('song data/$songLower/events');
	}

	inline static public function getSparrowAtlas(key:String, ?library:String, avoidGPU:Bool = false):FlxAtlasFrames {
		var xmlPath = file('images/$key.xml', library);
		if (Assets.exists(xmlPath)) {
			var imagePath = image(key, library);
			return system.OptimizedAssets.getSparrowAtlas(imagePath, xmlPath, avoidGPU);
		} else {
			var fallbackXml = file('images/Bind_Menu_Assets.xml', "preload");
			var fallbackImage = image("Bind_Menu_Assets", "preload");
			return system.OptimizedAssets.getSparrowAtlas(fallbackImage, fallbackXml, avoidGPU);
		}
	}

	inline static public function getPackerAtlas(key:String, ?library:String, avoidGPU:Bool = false):FlxAtlasFrames {
		var txtPath = file('images/$key.txt', library);
		if (Assets.exists(txtPath)) {
			var imagePath = image(key, library);
			return system.OptimizedAssets.getPackerAtlas(imagePath, txtPath, avoidGPU);
		} else {
			var fallbackXml = file('images/Bind_Menu_Assets.xml', "preload");
			var fallbackImage = image("Bind_Menu_Assets", "preload");
			return system.OptimizedAssets.getSparrowAtlas(fallbackImage, fallbackXml, avoidGPU);
		}
	}

	inline static public function getTextureAtlas(key:String, ?library:String):String {
		return getPath('images/$key', TEXT, library);
	}

	inline static public function getJsonAtlas(key:String, ?library:String):FlxAtlasFrames {
		return FlxAnimateFrames.fromJson(getPath('images/$key.json', TEXT, library));
	}

	inline static public function getEdgeAnimateAtlas(key:String, ?library:String):FlxAtlasFrames {
		return FlxAnimateFrames.fromEdgeAnimate(getPath('images/$key.eas', TEXT, library));
	}

	inline static public function getCocos2DAtlas(key:String, ?library:String):FlxAtlasFrames {
		return FlxAnimateFrames.fromCocos2D(getPath('images/$key.plist', TEXT, library));
	}

	inline static public function getEaselJSAtlas(key:String, ?library:String):FlxAtlasFrames {
		return FlxAnimateFrames.fromEaselJS(getPath('images/$key.js', TEXT, library));
	}

	static public function getAtlas(path:String):FlxAtlasFrames{
		if (Assets.exists(file("images/characters/" + path + ".txt", TEXT))) {
			return getPackerAtlas('characters/' + path);
		}
		else if (Assets.exists(file("images/characters/" + path + ".json", TEXT))){
			return getJsonAtlas('characters/' + path);
		}
		else if (Assets.exists(file("images/characters/" + path + ".plist", TEXT))){
			return getCocos2DAtlas('characters/' + path);
		} 
		else if (Assets.exists(file("images/characters/" + path + ".eas", TEXT))){
			return getEdgeAnimateAtlas('characters/' + path);
		} 
		else if (Assets.exists(file("images/characters/" + path + ".js", TEXT))){
			return getEaselJSAtlas('characters/' + path);
		} 
		return getSparrowAtlas('characters/' + path);
	}

	inline static public function existsInMod(path:String, mod:String):Bool {
		return FileSystem.exists(path.replace('assets', 'mods/$mod'));
	}

	inline static public function getModPath(path:String) {
		#if MODDING_ALLOWED
		return polymod.backends.PolymodAssets.getPath(path);
		#else
		return Assets.getPath(path);
		#end
	}
}

