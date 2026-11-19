package system;

import lime.graphics.Image;
import openfl.display.BitmapData;
import openfl.geom.Rectangle;
import flixel.FlxG;

class OptimizedBitmapData extends BitmapData {
	static var allInstances:Array<OptimizedBitmapData> = [];
	static inline var MAX_INSTANCES:Int = 512;

	#if (target.threaded || sys)
	public static var mainThread:sys.thread.Thread = sys.thread.Thread.current();

	public static inline function isMainThread():Bool {
		return mainThread == null || sys.thread.Thread.current() == mainThread;
	}
	#else
	public static inline function isMainThread():Bool return true;
	#end

	@SuppressWarnings("checkstyle:Dynamic")
	@:noCompletion private override function __fromImage(image:#if lime Image #else Dynamic #end):Void {
		#if lime
		if (image != null && image.buffer != null) {
			this.image = image;

			width = image.width;
			height = image.height;
			rect = new Rectangle(0, 0, image.width, image.height);

			__textureWidth = width;
			__textureHeight = height;

			#if sys
			image.format = BGRA32;
			image.premultiplied = true;
			#end

			__isValid = true;
			readable = true;

			if (isMainThread() && FlxG.stage != null && FlxG.stage.context3D != null && allInstances.length < MAX_INSTANCES) {
				lock();
				getTexture(FlxG.stage.context3D);
				releaseCPUData();
			} else {
				allInstances.push(this);
			}
		}
		#end
	}

	public function releaseCPUData():Bool {
		if (!__isValid) return false;

		if (__texture == null && isMainThread() && FlxG.stage != null && FlxG.stage.context3D != null && image != null) {
			getTexture(FlxG.stage.context3D);
		}

		if (__texture == null) return false;

		var released:Bool = false;
		#if lime
		if (image != null) {
			if (image.buffer != null) {
				image.buffer.data = null;
			}
			image = null;
			released = true;
		}
		if (__surface != null) {
			__surface = null;
			released = true;
		}
		#else
		if (image != null) {
			image = null;
			released = true;
		}
		#end
		readable = false;
		return released;
	}

	public inline function isCPUReleased():Bool {
		return image == null;
	}

	public static function releaseAllCPUData():Void {
		var i = allInstances.length;
		while (i-- > 0) {
			var inst = allInstances[i];
			if (inst == null || !inst.__isValid || inst.image == null || inst.releaseCPUData()) {
				allInstances.splice(i, 1);
			}
		}
	}

	public override function clone():BitmapData {
		#if lime
		if (image == null) {
			return new BitmapData(width, height, transparent, 0x00000000);
		}
		#end
		return super.clone();
	}

	public override function dispose():Void {
		allInstances.remove(this);
		#if lime
		if (image != null && image.buffer != null) {
			image.buffer.data = null;
		}
		#end
		super.dispose();
	}
}
