package system;

import openfl.display.Sprite;
import flixel.FlxG;
final class ResizeShaders {
	public static var doResizeFix:Bool = true;
	public static var skipCount:Int = 3;
	static var _lastFixTime:Float = 0;

	public static function init() {
		trace("ResizeShaders: Initializing shader resize listener");
		FlxG.signals.gameResized.add((w:Int, h:Int) -> {
			if (skipCount > 0) {
				skipCount--;
				return;
			}
			var now = haxe.Timer.stamp();
			if (now - _lastFixTime > 0.5) {
				_lastFixTime = now;
				trace("ResizeShaders: Trimming sprite cache dimensions on window resize to " + w + "x" + h);
				fixSpritesShadersSizes();
			}
		});
	}

	public inline static function fixSpritesShadersSizes() {
		if (!doResizeFix) return;

		@:privateAccess {
			if (Main.instance.filters != null && Main.instance.filters.length > 0)
				fixSpriteShaderSize(Main.instance);
		}
		if (FlxG.game != null) {
			@:privateAccess {
				if (FlxG.game.filters != null && FlxG.game.filters.length > 0)
					fixSpriteShaderSize(FlxG.game);
			}
		}

		if (FlxG.cameras == null) return;
		for (cam in FlxG.cameras.list) {
			@:privateAccess
			if (cam != null && (cam.filters != null && cam.filters.length > 0))
				fixSpriteShaderSize(cam.flashSprite);
		}
	}

	public inline static function fixSpriteShaderSize(sprite:Sprite) // Shout out to Ne_Eo for bringing this to my attention
	{
		if (sprite == null) return;

		@:privateAccess {
			sprite.__cacheBitmap = null;
			sprite.__cacheBitmapData = null;
		}
	}
}
