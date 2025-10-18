package;

import flixel.util.FlxSignal.FlxTypedSignal;
import flixel.FlxG;
import flixel.FlxGame;
import flixel.FlxState;
import flixel.system.debug.log.LogStyle;
import haxe.CallStack;
import haxe.Log;
import haxe.io.Path;
import openfl.Lib;
import openfl.display.Sprite;
import openfl.errors.Error;
import openfl.events.ErrorEvent;
import openfl.events.UncaughtErrorEvent;
import openfl.text.TextFormat;
import openfl.utils._internal.Log as OpenFLLog;
import states.TitleState;
import ui.SimpleInfoDisplay;
import ui.logs.Logs;
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;
import openfl.events.Event;
import lime.system.CFFI;
import polymod.backends.PolymodAssets;
import openfl.display.BitmapData;
import flixel.util.FlxColor;
import openfl.display.Bitmap;

class Main extends Sprite {
	public static var game:FlxGame;
	public static var display:SimpleInfoDisplay;
	public static var logsOverlay:Logs;
	public static var previousState:FlxState;
	public static var onCrash(default, null):FlxTypedSignal<UncaughtErrorEvent->Void> = new FlxTypedSignal<UncaughtErrorEvent->Void>();
	public static var noGPU:Bool = false;

	private var memTimer:Float = 0; // temporizador interno de limpieza

	public function new() {
		super();

		#if sys
		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, _onCrash);
		#end

		#if cpp
		untyped __global__.__hxcpp_set_critical_error_handler(_onCrash);
		#end

		CoolUtil.haxe_trace = Log.trace;
		Log.trace = CoolUtil.haxe_print;
		OpenFLLog.throwErrors = false;

		game = new FlxGame(1280, 720, TitleState, 60, 60, true);
		addChild(game);

		logsOverlay = new Logs();
		logsOverlay.visible = false;
		addChild(logsOverlay);

		display = new SimpleInfoDisplay(8, 3, 0xFFFFFF, "_sans");
		addChild(display);


		FlxG.signals.preStateSwitch.add(() -> {
			Main.previousState = FlxG.state;
			clearCache();
		});

		FlxG.signals.postStateSwitch.add(() -> gc());
		FlxG.signals.gameResized.add(fixCameraShaders);

		LogStyle.WARNING.onLog.add((data, ?pos) -> trace(data, WARNING, pos));
		LogStyle.ERROR.onLog.add((data, ?pos) -> trace(data, ERROR, pos));
		LogStyle.NOTICE.onLog.add((data, ?pos) -> trace(data, LOG, pos));

		addEventListener(Event.ENTER_FRAME, optimizeMemory);
	}
	private function optimizeMemory(e:Event):Void {
		memTimer += FlxG.elapsed;
		if (memTimer >= 30) {
			gc();
			memTimer = 0;
		}
	}

	private function clearCache():Void {
		@:privateAccess
		for (key in FlxG.bitmap._cache.keys()) {
			var obj = FlxG.bitmap._cache.get(key);
			if (obj != null) {
				lime.utils.Assets.cache.image.remove(key);
				openfl.Assets.cache.removeBitmapData(key);
				FlxG.bitmap._cache.remove(key);
			}
		}

		for (k => _ in lime.utils.Assets.cache.font) lime.utils.Assets.cache.font.remove(k);
		for (k => _ in lime.utils.Assets.cache.audio) lime.utils.Assets.cache.audio.remove(k);

		lime.utils.Assets.cache.clear();
		openfl.Assets.cache.clear();

		#if polymod
		polymod.Polymod.clearCache();
		#end
	}

	public static inline function resetSpriteCache(sprite:Sprite):Void {
		@:privateAccess {
			sprite.__cacheBitmap = null;
			sprite.__cacheBitmapData = null;
		}
	}

	// -------- Opciones de display --------
	public static inline function toggleFPS(v:Bool):Void display.infoDisplayed[0] = v;
	public static inline function toggleMem(v:Bool):Void display.infoDisplayed[1] = v;
	public static inline function toggleVers(v:Bool):Void display.infoDisplayed[2] = v;
	public static inline function toggleLogs(v:Bool):Void display.infoDisplayed[3] = v;
	public static inline function toggleCommitHash(v:Bool):Void display.infoDisplayed[4] = v;
	public static inline function toggleDiscord(v:Bool):Void display.infoDisplayed[5] = v;

	public static inline function changeFont(font:String):Void {
		var tf = display.defaultTextFormat;
		display.defaultTextFormat = new TextFormat(font, tf.size, display.textColor);
	}

	// -------- FPS --------
	public function setFPSCap(cap:Float):Void openfl.Lib.current.stage.frameRate = cap;
	public function getFPSCap():Float return openfl.Lib.current.stage.frameRate;

	// -------- Shaders --------
	public static function fixCameraShaders(w:Int, h:Int):Void {
		if (FlxG.cameras != null && FlxG.cameras.list.length > 0) {
			for (cam in FlxG.cameras.list) if (cam.flashSprite != null) resetSpriteCache(cam.flashSprite);
		}
		if (FlxG.game != null) resetSpriteCache(FlxG.game);
	}

	// -------- Crash handler --------
	#if sys
	private function _onCrash(e:UncaughtErrorEvent):Void {
		onCrash.dispatch(e);
		var error:String = "";
		var callStack:Array<StackItem> = CallStack.exceptionStack(true);
		var date:String = StringTools.replace(StringTools.replace(Date.now().toString(), " ", "_"), ":", "'");
		for (stackItem in callStack) switch (stackItem) {
			case FilePos(_, file, line, _): error += file + ":" + line + "\n";
			default: Sys.println(stackItem);
		}

		var errorData:String = if (e.error is Error) cast(e.error, Error).message else if (e.error is ErrorEvent) cast(e.error, ErrorEvent).text else Std.string(e.error);
		error += "\nUncaught Error: " + errorData;

		var path:String = Sys.getCwd() + "crash/crash-" + errorData + "-on-" + date + ".txt";
		if (!FileSystem.exists("./crash/")) FileSystem.createDirectory("./crash/");
		File.saveContent(path, error + "\n");
		Sys.println("Crash dump saved in " + Path.normalize(path));

		var crashPath:String = "Crash" #if linux + ".x86_64" #end #if windows + ".exe" #end;
		if (FileSystem.exists("./" + crashPath)) {
			#if linux new Process('chmod', ['+x', "./" + crashPath]); #end
			FlxG.stage.window.visible = false;
			new Process(crashPath, ['--crash_path="' + path + '"']);
		} else FlxG.stage.window.alert(error, "Error!");
		Sys.exit(1);
	}
	#end

	// -------- Texturas GPU --------
	public static function loadGPUTexture(key:String, bitmap:BitmapData):BitmapData {
		var disable:Bool = Options.getData("gpuTextures");
		if (disable || noGPU || FlxG.stage.context3D == null) return bitmap;

		var tex = FlxG.stage.context3D.createRectangleTexture(bitmap.width, bitmap.height, BGRA, true);
		tex.uploadFromBitmapData(bitmap);
		bitmap.dispose();
		bitmap.disposeImage();
		return BitmapData.fromTexture(tex);
	}

	// -------- Garbage collector --------
	public static function gc():Void {
		#if cpp
		cpp.vm.Gc.enable(true);
		cpp.vm.Gc.run(true);
		#end
		#if sys
		openfl.system.System.gc();
		#end
	}
}
