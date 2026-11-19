package system;

import openfl.display.BitmapData;
import openfl.media.Sound;
import openfl.text.Font;
import openfl.utils.AssetCache;
import flixel.FlxG;
#if lime
import lime.utils.Assets as LimeAssets;
#end

class FunkinCache extends AssetCache {
	public static var instance:FunkinCache;

	public var bitmapData2:Map<String, BitmapData>;
	public var font2:Map<String, Font>;
	public var sound2:Map<String, Sound>;

	public function new() {
		super();
		bitmapData2 = new Map();
		font2 = new Map();
		sound2 = new Map();
		instance = this;
	}

	public static function init() {
		openfl.utils.Assets.cache = new FunkinCache();

		FlxG.signals.preStateSwitch.add(function() {
			if (instance != null) {
				instance.moveToSecondLayer();
			}
			OptimizedAssets.prepareTransition();
		});

		FlxG.signals.postStateSwitch.add(function() {
			OptimizedAssets.clearUnusedTransitionCaches();
			if (instance != null) {
				instance.clearSecondLayer();
			}
			system.OptimizedBitmapData.releaseAllCPUData();
		});
	}

	public function moveToSecondLayer() {
		bitmapData2 = bitmapData;
		font2 = font;
		sound2 = sound;
		bitmapData = new Map();
		font = new Map();
		sound = new Map();
	}

	public function clearSecondLayer() {
		var freedBitmaps:Int = 0;
		var freedSounds:Int = 0;
		for (k => b in bitmapData2) {
			if (k == "flixel/images/logo/default.png" || OptimizedAssets.graphicCache.exists(k)) {
				if (b != null) bitmapData.set(k, b);
				continue;
			}
			var graphic = FlxG.bitmap.get(k);
			if (graphic != null && (graphic.persist || graphic.useCount > 0)) {
				if (b != null) bitmapData.set(k, b);
				continue;
			}

			FlxG.bitmap.removeByKey(k);
			#if lime
			LimeAssets.cache.removeImage(k);
			#end
			if (b != null) {
				try {
					b.dispose();
				} catch (e:Dynamic) {}
				freedBitmaps++;
			}
		}
		for (k => f in font2) {
			#if lime
			LimeAssets.cache.font.remove(k);
			#end
		}
		for (k => s in sound2) {
			if (s != null && OptimizedAssets.isSoundActive(s)) {
				sound.set(k, s);
				continue;
			}

			OptimizedAssets.dropFromFunkinCache(k);
			if (s != null) {
				s.close();
				@:privateAccess {
					if (s.__buffer != null) {
						try { s.__buffer.dispose(); } catch (e:Dynamic) {}
						s.__buffer = null;
					}
				}
				freedSounds++;
			}
		}

		bitmapData2.clear();
		font2.clear();
		sound2.clear();

		if (freedBitmaps > 0 || freedSounds > 0)
			trace('[FunkinCache] Second layer freed: $freedBitmaps bitmaps, $freedSounds sounds.');
	}

	public override function getBitmapData(id:String):BitmapData {
		var s = bitmapData.get(id);
		if (s != null)
			return s;
		var s2 = bitmapData2.get(id);
		if (s2 != null) {
			bitmapData2.remove(id);
			bitmapData.set(id, s2);
		}
		return s2;
	}

	public override function getFont(id:String):Font {
		var s = font.get(id);
		if (s != null)
			return s;
		var s2 = font2.get(id);
		if (s2 != null) {
			font2.remove(id);
			font.set(id, s2);
		}
		return s2;
	}

	public override function getSound(id:String):Sound {
		var s = sound.get(id);
		if (s != null) {
			if (!OptimizedAssets.isSoundUsable(s)) {
				sound.remove(id);
				return null;
			}
			return s;
		}
		var s2 = sound2.get(id);
		if (s2 != null) {
			sound2.remove(id);
			if (!OptimizedAssets.isSoundUsable(s2)) {
				return null;
			}
			sound.set(id, s2);
			return s2;
		}
		return null;
	}

	public override function hasBitmapData(id:String):Bool {
		return bitmapData.exists(id) || bitmapData2.exists(id);
	}

	public override function hasFont(id:String):Bool {
		return font.exists(id) || font2.exists(id);
	}

	public override function hasSound(id:String):Bool {
		if (sound.exists(id)) {
			var s = sound.get(id);
			if (s != null && !OptimizedAssets.isSoundUsable(s)) {
				sound.remove(id);
				return false;
			}
			return true;
		}
		if (sound2.exists(id)) {
			var s2 = sound2.get(id);
			if (s2 != null && !OptimizedAssets.isSoundUsable(s2)) {
				sound2.remove(id);
				return false;
			}
			return true;
		}
		return false;
	}

	public override function removeBitmapData(id:String):Bool {
		#if lime
		LimeAssets.cache.removeImage(id);
		#end
		return bitmapData.remove(id) || bitmapData2.remove(id);
	}

	public override function removeFont(id:String):Bool {
		#if lime
		LimeAssets.cache.font.remove(id);
		#end
		return font.remove(id) || font2.remove(id);
	}

	public override function removeSound(id:String):Bool {
		#if lime
		LimeAssets.cache.audio.remove(id);
		#end
		return sound.remove(id) || sound2.remove(id);
	}
}
