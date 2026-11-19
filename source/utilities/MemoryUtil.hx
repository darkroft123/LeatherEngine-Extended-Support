package utilities;

#if cpp
import cpp.vm.Gc;
#elseif hl
import hl.Gc;
#elseif java
import java.vm.Gc;
#elseif neko
import neko.vm.Gc;
#end
import openfl.system.System;

/**
 * Active garbage collection and memory management helper inspired by Codename Engine.
 */
final class MemoryUtil {
	public static var disableCount:Int = 0;

	public static function askDisable():Void {
		disableCount++;
		if (disableCount > 0)
			disable();
		else
			enable();
	}

	public static function askEnable():Void {
		if (disableCount > 0)
			disableCount--;
		if (disableCount > 0)
			disable();
		else
			enable();
	}

	public static function clearMinor():Void {
		#if (cpp || java || neko)
		Gc.run(false);
		#end
	}

	public static function clearMajor():Void {
		#if cpp
		Gc.run(true);
		Gc.compact();
		#elseif hl
		Gc.major();
		#elseif (java || neko)
		Gc.run(true);
		#end
	}

	public static function enable():Void {
		#if (cpp || hl)
		Gc.enable(true);
		#end
	}

	public static function disable():Void {
		#if (cpp || hl)
		Gc.enable(false);
		#end
	}

	public static inline function currentMemUsage():Float {
		#if cpp
		return cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_USAGE);
		#elseif hl
		return hl.Gc.stats().currentMemory;
		#else
		return System.totalMemoryNumber;
		#end
	}
}
