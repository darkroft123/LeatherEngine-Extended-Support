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

	public function new() {
		#if mobile
		SUtil.uncaughtErrorHandler();
		#end
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

		FlxG.signals.preStateSwitch.add(() -> {
			Main.previousState = FlxG.state;
		});

		FlxG.signals.preStateCreate.add((state) -> {
			CoolUtil.clearMemory();
		});

		@:privateAccess
		game._customSoundTray = ui.FunkinSoundTray;

		addChild(game);

		logsOverlay = new Logs();
		logsOverlay.visible = false;
		addChild(logsOverlay);

		init();

		LogStyle.WARNING.onLog.add((data, ?pos) -> trace(data, WARNING, pos));
		LogStyle.ERROR.onLog.add((data, ?pos) -> trace(data, ERROR, pos));
		LogStyle.NOTICE.onLog.add((data, ?pos) -> trace(data, LOG, pos));

		display = new SimpleInfoDisplay(8, 3, 0xFFFFFF, "_sans");
		addChild(display);

		// fix shaders cuando cambias tamaño
		FlxG.signals.gameResized.add(function(w, h) {
			if (FlxG.cameras != null) {
				for (cam in FlxG.cameras.list) {
					if (cam != null && cam.filters != null) {
						resetSpriteCache(cam.flashSprite);
					}
				}
			}

			if (FlxG.game != null) {
				resetSpriteCache(FlxG.game);
			}
		});
	}

	private function init(?E:Event):Void {
		if (hasEventListener(Event.ADDED_TO_STAGE)) {
			removeEventListener(Event.ADDED_TO_STAGE, init);
		}
		setupGame();
	}

	private function setupGame():Void {
		// Limpieza de cache
		FlxG.signals.preStateSwitch.add(function() {
			@:privateAccess
			for (key in FlxG.bitmap._cache.keys()) {
				var obj = FlxG.bitmap._cache.get(key);
				if (obj != null) {
					lime.utils.Assets.cache.image.remove(key);
					openfl.Assets.cache.removeBitmapData(key);
					FlxG.bitmap._cache.remove(key);
				}
			}

			for (k => f in lime.utils.Assets.cache.font) lime.utils.Assets.cache.font.remove(k);
			for (k => s in lime.utils.Assets.cache.audio) lime.utils.Assets.cache.audio.remove(k);

			lime.utils.Assets.cache.clear();
			openfl.Assets.cache.clear();

			#if polymod
			polymod.Polymod.clearCache();
			#end

			gc();
		});

		FlxG.signals.postStateSwitch.add(function() {
			gc();
		});

		display = new SimpleInfoDisplay(10, 3, 0xFFFFFF, "_sans");
		addChild(display);

		FlxG.signals.gameResized.add(fixCameraShaders);

		#if mobile
		SUtil.uncaughtErrorHandler();
		#end

		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, _onCrash);
	}

	public static inline function resetSpriteCache(sprite:Sprite):Void {
		@:privateAccess {
			sprite.__cacheBitmap = null;
			sprite.__cacheBitmapData = null;
		}
	}


	public static inline function toggleFPS(fpsEnabled:Bool):Void display.infoDisplayed[0] = fpsEnabled;
	public static inline function toggleMem(memEnabled:Bool):Void display.infoDisplayed[1] = memEnabled;
	public static inline function toggleVers(versEnabled:Bool):Void display.infoDisplayed[2] = versEnabled;
	public static inline function toggleLogs(logsEnabled:Bool):Void display.infoDisplayed[3] = logsEnabled;
	public static inline function toggleCommitHash(commitHashEnabled:Bool):Void display.infoDisplayed[4] = commitHashEnabled;
	public static inline function toggleDiscord(discordUser:Bool):Void display.infoDisplayed[5] = discordUser;

	public static inline function changeFont(font:String):Void {
		var tf = display.defaultTextFormat;
		display.defaultTextFormat = new TextFormat(
			font,
			tf.size,
			display.textColor
		);
	}

	// -------- FPS --------
	public function setFPSCap(cap:Float) {
		openfl.Lib.current.stage.frameRate = cap;
	}
	public function getFPSCap():Float {
		return openfl.Lib.current.stage.frameRate;
	}

	// -------- Shaders --------
	public static function fixCameraShaders(w:Int, h:Int) {
		if (FlxG.cameras.list.length > 0) {
			for (cam in FlxG.cameras.list) {
				if (cam.flashSprite != null) {
					@:privateAccess {
						cam.flashSprite.__cacheBitmap = null;
						cam.flashSprite.__cacheBitmapData = null;
					}
				}
			}
		}

		if (FlxG.game != null) {
			@:privateAccess {
				FlxG.game.__cacheBitmap = null;
				FlxG.game.__cacheBitmapData = null;
			}
		}
	}

	// -------- Crash handler --------
	#if sys
	private function _onCrash(e:UncaughtErrorEvent):Void {
			#if desktop
		onCrash.dispatch(e);
		var error:String = "";
		var path:String;
		var callStack:Array<StackItem> = CallStack.exceptionStack(true);
		var date:String = Date.now().toString();

		date = StringTools.replace(date, " ", "_");
		date = StringTools.replace(date, ":", "'");

		for (stackItem in callStack) {
			switch (stackItem) {
				case FilePos(s, file, line, column):
					error += file + ":" + line + "\n";
				default:
					Sys.println(stackItem);
			}
		}

		var errorData:String = "";
		if (e.error is Error) errorData = cast(e.error, Error).message;
		else if (e.error is ErrorEvent) errorData = cast(e.error, ErrorEvent).text;
		else errorData = Std.string(e.error);

		error += "\nUncaught Error: " + errorData;
		path = Sys.getCwd() + "crash/" + "crash-" + errorData + '-on-' + date + ".txt";

		if (!FileSystem.exists("./crash/")) FileSystem.createDirectory("./crash/");
		File.saveContent(path, error + "\n");

		Sys.println(error);
		Sys.println("Crash dump saved in " + Path.normalize(path));

		var crashPath:String = "Crash" #if linux + '.x86_64' #end #if windows + ".exe" #end;
		if (FileSystem.exists("./" + crashPath)) {
			Sys.println("Found crash dialog: " + crashPath);
			#if linux
			crashPath = "./" + crashPath;
			new Process('chmod', ['+x', crashPath]);
			#end
			FlxG.stage.window.visible = false;
			new Process(crashPath, ['--crash_path="' + path + '"']);
		} else {
			Sys.println("No crash dialog found! Making a simple alert instead...");
			FlxG.stage.window.alert(error, "Error!");
		}

		Sys.exit(1);
		#end
	}
	#end

	// -------- Texturas GPU --------
	public static var noGPU:Bool = false;

	public static function loadGPUTexture(key:String, bitmap:BitmapData) {
		var disable:Bool = Options.getData("gpuTextures");
		if (disable || noGPU) return bitmap;

		var tex = FlxG.stage.context3D.createRectangleTexture(bitmap.width, bitmap.height, BGRA, true);
		tex.uploadFromBitmapData(bitmap);
		bitmap.image.data = null;
		bitmap.dispose();
		bitmap.disposeImage();
		bitmap = BitmapData.fromTexture(tex);
		return bitmap;
	}

	// -------- Garbage collector --------
	public static function gc() {
		#if cpp
		cpp.vm.Gc.enable(true);
		#end

		#if sys
		openfl.system.System.gc();	
		#end
	}
}
