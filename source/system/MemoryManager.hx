package system;

import flixel.FlxG;
import openfl.Assets;
import lime.utils.Assets as LimeAssets;

class MemoryManager
{
	public static var enabled:Bool = true;
	public static var aggressive:Bool = false;

	static var initialized:Bool = false;
	static var transitionCount:Int = 0;

	public static function init():Void
	{
		if (initialized) return;
		initialized = true;

		FlxG.signals.postStateSwitch.add(onPostStateSwitch);
	}

	public static function destroy():Void
	{
		if (!initialized) return;
		initialized = false;

		FlxG.signals.postStateSwitch.remove(onPostStateSwitch);
	}

	public static function onPostStateSwitch():Void
	{
		if (!enabled) return;

		clearUnusedBitmaps();
		clearUInt8BuffPools();

		transitionCount++;
		if (transitionCount >= 5) {
			transitionCount = 0;
			runGC(true);
		} else {
			runGC(false);
		}
	}

	public static function clearUnusedBitmaps():Void
	{
		if (FlxG.bitmap != null)
			FlxG.bitmap.clearUnused();
	}

	public static function clearUInt8BuffPools():Void
	{
		try {
			openfl.display3D.utils.UInt8Buff.clearPools();
		} catch (e:Dynamic) {}
	}

	public static function clearAllCaches():Void
	{
		if (LimeAssets.cache != null)
			LimeAssets.cache.clear();

		if (Assets.cache != null)
			Assets.cache.clear();

		#if polymod
		polymod.Polymod.clearCache();
		#end
	}

	public static function forceCleanup(?clearCaches:Bool = true):Void
	{
		if (clearCaches)
		{
			clearUnusedBitmaps();

			if (aggressive)
				clearAllCaches();
		}

		runGC(true);
	}

	public static function getImmixBlockSize():Int
	{
		#if cpp
		return untyped __global__.__hxcpp_gc_block_size();
		#else
		return 0;
		#end
	}

	public static function isInGameplay():Bool
	{
		return Std.isOfType(FlxG.state, states.PlayState);
	}

	public static function runGC(forceCompact:Bool = false):Void
	{
		#if cpp
		if (isInGameplay()) return;

		cpp.vm.Gc.run(true);
		if (forceCompact)
			cpp.vm.Gc.compact();

		if (forceCompact) {
			#if windows
			external.memory.Memory.trimWorkingSet();
			#end
		}
		#end

		#if sys
		openfl.system.System.gc();
		#end
	}
}