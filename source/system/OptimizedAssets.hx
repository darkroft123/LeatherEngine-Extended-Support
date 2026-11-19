package system;

import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import openfl.media.Sound;
import flixel.FlxG;
import openfl.utils.Assets as OpenFlAssets;
import openfl.utils.AssetType;
import utilities.Options;
#if lime
import lime.utils.Assets as LimeAssets;
#end
#if sys
import sys.FileSystem;
#end

class OptimizedAssets {
	public static var graphicCache:Map<String, FlxGraphic> = new Map();
	public static var atlasCache:Map<String, FlxAtlasFrames> = new Map();
	public static var soundCache:Map<String, Sound> = new Map();

	public static var graphicCache2:Map<String, FlxGraphic> = new Map();
	public static var atlasCache2:Map<String, FlxAtlasFrames> = new Map();
	public static var soundCache2:Map<String, Sound> = new Map();

	static var activeSounds:haxe.ds.ObjectMap<Sound, Bool> = new haxe.ds.ObjectMap();

	static function promoteGraphic(key:String, graphic:FlxGraphic):FlxGraphic {
		if (graphic == null || key == null) return graphic;
		graphic.destroyOnNoUse = false;
		graphicCache2.remove(key);
		graphicCache.set(key, graphic);
		if (FunkinCache.instance != null) {
			FunkinCache.instance.bitmapData2.remove(key);
			if (graphic.bitmap != null) {
				FunkinCache.instance.bitmapData.set(key, graphic.bitmap);
			}
		}
		return graphic;
	}

	public static function sanitizeGraphicFrameCollections(graphic:FlxGraphic):Void {
		if (graphic == null) return;
		@:privateAccess {
			if (graphic.frameCollections != null) {
				for (type in graphic.frameCollectionTypes) {
					var colls = graphic.frameCollections.get(type);
					if (colls != null) {
						var i = colls.length - 1;
						while (i >= 0) {
							var c:flixel.graphics.frames.FlxFramesCollection = colls[i];
							if (c == null || c.border == null || c.parent == null || c.parent.isDestroyed || c.frames == null || c.frames.length == 0) {
								colls.splice(i, 1);
							}
							i--;
						}
					}
				}
			}
		}
	}

	public static function untrackActiveSound(sound:Sound):Void {
		if (sound != null) activeSounds.remove(sound);
	}

	private static function isSoundPersistent(sound:Sound):Bool {
		if (sound == null) return false;
		@:privateAccess {
			if (FlxG.sound.music != null && FlxG.sound.music.persist && FlxG.sound.music._sound == sound) {
				return true;
			}
			for (fs in FlxG.sound.list.members) {
				if (fs != null && fs.persist && fs._sound == sound) {
					return true;
				}
			}
		}
		return false;
	}

	public static function prepareTransition():Void {
		game.Note.framesCache.clear();
		@:privateAccess game.Note.sustainFallbackCache.clear();
		game.StrumNote.clearCache();
		game.NoteSplash.clearCache();

		var tempGraphicCache:Map<String, FlxGraphic> = new Map();
		for (key => val in graphicCache) {
			if (val != null && val.persist) {
				tempGraphicCache.set(key, val);
			} else if (val != null) {
				graphicCache2.set(key, val);
			}
		}
		graphicCache = tempGraphicCache;

		for (key => val in atlasCache) {
			atlasCache2.set(key, val);
		}
		atlasCache.clear();

		var tempSoundCache:Map<String, Sound> = new Map();
		for (key => val in soundCache) {
			if (val != null && isSoundPersistent(val)) {
				tempSoundCache.set(key, val);
			} else if (val != null) {
				soundCache2.set(key, val);
			}
		}
		soundCache = tempSoundCache;
		activeSounds.clear();
	}

	public static function clearUnusedTransitionCaches():Void {
		var atlasKeys = [for (k in atlasCache2.keys()) k];
		for (key in atlasKeys) {
			var atlas = atlasCache2.get(key);
			if (atlas != null) {
				var parent = atlas.parent;
				if (parent != null && !parent.isDestroyed && (parent.persist || parent.useCount > 0)) {
					atlasCache2.remove(key);
					atlasCache.set(key, atlas);
					promoteGraphic(parent.key, parent);
					continue;
				}
				if (parent != null && !parent.isDestroyed) {
					@:privateAccess {
						if (parent.frameCollections != null && parent.frameCollectionTypes != null) {
							for (type in parent.frameCollectionTypes) {
								var colls = parent.frameCollections.get(type);
								if (colls != null) {
									colls.remove(atlas);
								}
							}
						}
					}
				}
				atlas.destroy();
				atlasCache2.remove(key);
			}
		}
		atlasCache2.clear();

		var graphicKeys = [for (k in graphicCache2.keys()) k];
		for (key in graphicKeys) {
			var graphic = graphicCache2.get(key);
			if (graphic != null) {
				if (!graphic.isDestroyed && (graphic.persist || graphic.useCount > 0)) {
					promoteGraphic(key, graphic);
					continue;
				}
				FlxG.bitmap.remove(graphic);
				#if lime
				if (LimeAssets.cache != null)
					LimeAssets.cache.removeImage(key);
				#end
				OpenFlAssets.cache.removeBitmapData(key);
				dropBitmapFromFunkinCache(key);

				if (!graphic.isDestroyed) {
					graphic.destroy();
				}
				graphicCache2.remove(key);
			}
		}
		graphicCache2.clear();

		var soundKeys = [for (k in soundCache2.keys()) k];
		for (key in soundKeys) {
			var snd = soundCache2.get(key);
			if (snd != null) {
				if (isSoundPersistent(snd) || isSoundActive(snd)) {
					soundCache2.remove(key);
					soundCache.set(key, snd);
					continue;
				}
				dropFromFunkinCache(key);
				#if lime
				if (LimeAssets.cache != null && LimeAssets.cache.audio != null)
					LimeAssets.cache.audio.remove(key);
				#end
				snd.close();
				@:privateAccess {
					if (snd.__buffer != null) {
						try { snd.__buffer.dispose(); } catch (e:Dynamic) {}
						snd.__buffer = null;
					}
				}
				soundCache2.remove(key);
			}
		}
		soundCache2.clear();

		OptimizedBitmapData.releaseAllCPUData();

		#if cpp
		cpp.vm.Gc.run(false);
		#end
	}

	static inline function isGraphicUsable(graphic:FlxGraphic, avoidGPU:Bool = false):Bool {
		return graphic != null
			&& !graphic.isDestroyed
			&& graphic.bitmap != null
			&& graphic.bitmap.width > 0
			&& (!avoidGPU || !Std.isOfType(graphic.bitmap, OptimizedBitmapData) || !cast(graphic.bitmap, OptimizedBitmapData).isCPUReleased());
	}

	public static function getGraphic(file:String, avoidGPU:Bool = false):FlxGraphic {
		if (graphicCache.exists(file)) {
			var cached = graphicCache.get(file);
			if (isGraphicUsable(cached, avoidGPU)) {
				return cached;
			}
			graphicCache.remove(file);
		}

		if (graphicCache2.exists(file)) {
			var cached = graphicCache2.get(file);
			if (isGraphicUsable(cached, avoidGPU)) {
				return promoteGraphic(file, cached);
			}
			graphicCache2.remove(file);
		}

		var existing = FlxG.bitmap.get(file);
		if (isGraphicUsable(existing, avoidGPU)) {
			return promoteGraphic(file, existing);
		}
		if (avoidGPU && existing != null && !existing.isDestroyed && Std.isOfType(existing.bitmap, OptimizedBitmapData)) {
			FlxG.bitmap.removeByKey(file);
		}

		var bitmap:BitmapData = null;

		if (AntiLeak.hasEncryptedVersion(file)) {
			try {
				bitmap = AntiLeak.loadDecryptedImage(file);
			} catch (e:Dynamic) {
				Main.logSilentError(e, "OptimizedAssets: decrypt asset");
			}
		}

		var cleanFile = file.indexOf(":") != -1 ? file.substring(file.indexOf(":") + 1) : file;
		if (bitmap == null && !avoidGPU) {
			try {
				var image = LimeAssets.getImage(cleanFile, false);
				if (image != null) {
					bitmap = new OptimizedBitmapData(0, 0, true, 0);
					@:privateAccess bitmap.__fromImage(image);
					if (OptimizedBitmapData.isMainThread() && FlxG.stage != null && FlxG.stage.context3D != null) {
						bitmap.getTexture(FlxG.stage.context3D);
						cast(bitmap, OptimizedBitmapData).releaseCPUData();
					}
				}
			} catch (e:Dynamic) {
				Main.logSilentError(e, "OptimizedAssets: preload GPU texture");
			}
		}

		if (bitmap == null) {
			bitmap = OpenFlAssets.getBitmapData(file);
		}

		if (bitmap != null && !avoidGPU && !Std.isOfType(bitmap, OptimizedBitmapData)) {
			try {
				var rawImg = @:privateAccess bitmap.image;
				if (rawImg != null && rawImg.buffer != null) {
					var optBitmap = new OptimizedBitmapData(0, 0, true, 0);
					@:privateAccess optBitmap.__fromImage(rawImg);
					if (OptimizedBitmapData.isMainThread() && FlxG.stage != null && FlxG.stage.context3D != null) {
						optBitmap.getTexture(FlxG.stage.context3D);
						optBitmap.releaseCPUData();
					}
					OpenFlAssets.cache.removeBitmapData(file);
					#if lime
					LimeAssets.cache.removeImage(file);
					#end
					bitmap = optBitmap;
				}
			} catch (e:Dynamic) {
				Main.logSilentError(e, "OptimizedAssets: convert to GPU texture");
			}
		}

		if (bitmap == null || bitmap.width <= 0 || bitmap.height <= 0) {
			OpenFlAssets.cache.removeBitmapData(file);
			#if (sys && MODDING_ALLOWED)
			var diskFile = file.indexOf(":") != -1 ? file.substring(file.indexOf(":") + 1) : file;
			if (FileSystem.exists(diskFile)) {
				try {
					bitmap = BitmapData.fromFile(diskFile);
				} catch (e:Dynamic) { bitmap = null; }
			}
			#end
			if (bitmap == null || bitmap.width <= 0 || bitmap.height <= 0) {
				try { bitmap = OpenFlAssets.getBitmapData(file, false); } catch (e:Dynamic) { bitmap = null; }
			}
		}

		if (bitmap == null || bitmap.width <= 0 || bitmap.height <= 0) {
			return null;
		}

		var graphic:FlxGraphic = FlxGraphic.fromBitmapData(bitmap, false, file, true);
		return promoteGraphic(file, graphic);
	}

	static function getCachedAtlas(cacheKey:String):FlxAtlasFrames {
		if (atlasCache.exists(cacheKey)) {
			var cached = atlasCache.get(cacheKey);
			if (cached != null && cached.frames != null && cached.frames.length > 0 && isGraphicUsable(cached.parent)) {
				atlasCache2.remove(cacheKey);
				promoteGraphic(cached.parent.key, cached.parent);
				return cached;
			}
			atlasCache.remove(cacheKey);
		}

		if (atlasCache2.exists(cacheKey)) {
			var cached = atlasCache2.get(cacheKey);
			if (cached != null && cached.frames != null && cached.frames.length > 0 && isGraphicUsable(cached.parent)) {
				atlasCache2.remove(cacheKey);
				atlasCache.set(cacheKey, cached);
				promoteGraphic(cached.parent.key, cached.parent);
				return cached;
			}
			atlasCache2.remove(cacheKey);
		}

		return null;
	}

	public static function getSparrowAtlas(imageFile:String, xmlFile:String, avoidGPU:Bool = false):FlxAtlasFrames {
		var cacheKey = 'sparrow_${imageFile}_${xmlFile}_${avoidGPU}';
		var cached = getCachedAtlas(cacheKey);
		if (cached != null) return cached;

		var graphic = getGraphic(imageFile, avoidGPU);
		if (!isGraphicUsable(graphic)) return null;
		sanitizeGraphicFrameCollections(graphic);

		var frames = FlxAtlasFrames.fromSparrow(graphic, xmlFile);
		atlasCache.set(cacheKey, frames);
		return frames;
	}

	public static function getPackerAtlas(imageFile:String, txtFile:String, avoidGPU:Bool = false):FlxAtlasFrames {
		var cacheKey = 'packer_${imageFile}_${txtFile}_${avoidGPU}';
		var cached = getCachedAtlas(cacheKey);
		if (cached != null) return cached;

		var graphic = getGraphic(imageFile, avoidGPU);
		if (!isGraphicUsable(graphic)) return null;
		sanitizeGraphicFrameCollections(graphic);

		var frames = FlxAtlasFrames.fromSpriteSheetPacker(graphic, txtFile);
		atlasCache.set(cacheKey, frames);
		return frames;
	}

	public static function getSound(file:String):Sound {
		if (soundCache.exists(file)) {
			var cached = soundCache.get(file);
			if (isSoundUsable(cached)) return cached;
			soundCache.remove(file);
			dropFromFunkinCache(file);
		}

		if (soundCache2.exists(file)) {
			var cached = soundCache2.get(file);
			if (isSoundUsable(cached)) {
				soundCache2.remove(file);
				soundCache.set(file, cached);

				if (FunkinCache.instance != null) {
					FunkinCache.instance.sound2.remove(file);
					FunkinCache.instance.sound.set(file, cached);
				}

				return cached;
			}
			soundCache2.remove(file);
			dropFromFunkinCache(file);
		}

		if (AntiLeak.hasEncryptedVersion(file)) {
			try {
				var decryptedSound:Sound = AntiLeak.loadDecryptedSound(file);
				if (decryptedSound != null) {
					soundCache.set(file, decryptedSound);
					return decryptedSound;
				}
			} catch (e:Dynamic) {
				Main.logSilentError(e, "OptimizedAssets: decrypt sound");
			}
		}

		var sound:Sound = OpenFlAssets.getSound(file);
		if (sound != null && !isSoundUsable(sound)) {
			dropFromFunkinCache(file);
			sound = OpenFlAssets.getSound(file);
		}
		if (sound != null) {
			soundCache.set(file, sound);
		}
		return sound;
	}

	/**
	 * Makes sure `file` is resolvable as a sound *asset*, not just as a file.
	 *
	 * `FlxSound.loadEmbedded` gates on `Assets.exists(id, SOUND)`, and that goes to
	 * `FunkinCache.hasSound`, which only knows the two maps it owns. Song audio
	 * resolved off the file system — a mod whose instrumental is not named after
	 * the song, so `Paths.inst` falls back to a directory scan and hands back a raw
	 * `mods/...` path — was never registered in either map, so the gate stayed
	 * closed: `loadEmbedded` logged "Could not find a Sound asset", left `_sound`
	 * null and still reported success, and the song played silently. Freeplay
	 * sounded fine because it had already put the id in the cache.
	 *
	 * This decodes the file and registers it in both caches, which is what makes
	 * the later `loadEmbedded` work. Returns false only when there is genuinely
	 * nothing to play.
	 */
	public static function ensureSoundCached(file:String):Bool {
		if (file == null || file == "") return false;

		if (soundCache.exists(file)) {
			var snd = soundCache.get(file);
			if (isSoundUsable(snd)) {
				activeSounds.set(snd, true);
				return true;
			}
			soundCache.remove(file);
		}
		if (soundCache2.exists(file)) {
			var snd = soundCache2.get(file);
			if (isSoundUsable(snd)) {
				soundCache2.remove(file);
				soundCache.set(file, snd);
				if (FunkinCache.instance != null) {
					FunkinCache.instance.sound2.remove(file);
					FunkinCache.instance.sound.set(file, snd);
				}
				activeSounds.set(snd, true);
				return true;
			}
			soundCache2.remove(file);
		}

		if (OpenFlAssets.exists(file, AssetType.SOUND) || OpenFlAssets.exists(file, AssetType.MUSIC)) {
			if (FunkinCache.instance != null) {
				var s = FunkinCache.instance.sound.get(file);
				if (s != null && !isSoundUsable(s)) {
					dropFromFunkinCache(file);
				}
				var s2 = FunkinCache.instance.sound2.get(file);
				if (s2 != null && !isSoundUsable(s2)) {
					dropFromFunkinCache(file);
				}
			}
			var snd = OpenFlAssets.getSound(file);
			if (snd != null && isSoundUsable(snd)) {
				soundCache.set(file, snd);
				activeSounds.set(snd, true);
				return true;
			}
			dropFromFunkinCache(file);
			return true;
		}

		#if (sys && MODDING_ALLOWED)
		// `Paths.inst`/`Paths.voices` can hand back a plain filesystem path, so
		// only that shape is worth trying to decode here.
		if (file.indexOf("mods/") != 0) return false;
		if (!FileSystem.exists(file)) return false;

		var decoded:Sound = decodeSoundFile(file);
		if (decoded == null) return false;

		soundCache.set(file, decoded);

		// `FunkinCache` owns the `Assets.exists` gate that `loadEmbedded` reads, so
		// registering there is what actually unblocks the load. It is also the map
		// `getSound` falls back to, so one write covers both.
		if (FunkinCache.instance != null) {
			FunkinCache.instance.sound.set(file, decoded);
			FunkinCache.instance.sound2.remove(file);
		}

		activeSounds.set(decoded, true);
		return true;
		#else
		return false;
		#end
	}

	#if (sys && MODDING_ALLOWED)
	/** Decodes an audio file straight off disk, bypassing the asset library. */
	static function decodeSoundFile(path:String):Sound {
		try {
			var buffer:lime.media.AudioBuffer = lime.media.AudioBuffer.fromFile(path);
			if (buffer == null) return null;

			var sound:Sound = new Sound();
			@:privateAccess {
				sound.__buffer = buffer;
			}
			return sound;
		} catch (e:Dynamic) {
			Main.logSilentError(e, "OptimizedAssets: decode sound from disk");
			return null;
		}
	}
	#end

	public static function clearCache():Void {
		graphicCache.clear();
		atlasCache.clear();
		for (key => snd in soundCache) {
			if (snd != null) {
				if (isSoundActive(snd)) continue;
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
	}

	public static function isSoundUsable(sound:Sound):Bool {
		if (sound == null) return false;
		@:privateAccess {
			if (sound.__buffer == null) return false;
			#if lime
			if (sound.__buffer.data == null && sound.__buffer.__srcBuffer == null && sound.__buffer.__srcVorbisFile == null) return false;
			#end
		}
		return true;
	}

	public static function dropFromFunkinCache(file:String):Void {
		if (FunkinCache.instance == null) return;
		FunkinCache.instance.sound.remove(file);
		FunkinCache.instance.sound2.remove(file);
		#if lime
		if (LimeAssets.cache != null && LimeAssets.cache.audio != null)
			LimeAssets.cache.audio.remove(file);
		var colon = file.indexOf(":");
		var libName = colon != -1 ? file.substring(0, colon) : "default";
		var symName = colon != -1 ? file.substring(colon + 1) : file;
		var lib = LimeAssets.getLibrary(libName);
		if (lib != null) {
			@:privateAccess if (lib.cachedAudioBuffers != null) lib.cachedAudioBuffers.remove(symName);
		}
		#end
	}

	static function dropBitmapFromFunkinCache(file:String):Void {
		if (FunkinCache.instance == null) return;
		FunkinCache.instance.bitmapData.remove(file);
		FunkinCache.instance.bitmapData2.remove(file);
	}

	public static function isSoundActive(sound:Sound):Bool {
		if (sound == null) return false;
		if (activeSounds.exists(sound)) return true;

		if (FlxG.sound != null) {
			if (FlxG.sound.music != null) {
				@:privateAccess if (FlxG.sound.music._sound == sound) return true;
			}
			if (FlxG.sound.list != null) {
				for (snd in FlxG.sound.list.members) {
					@:privateAccess if (snd != null && snd._sound == sound) return true;
				}
			}
		}
		return false;
	}
}
