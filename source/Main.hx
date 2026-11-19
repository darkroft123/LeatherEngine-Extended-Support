package;


import flixel.util.FlxSignal.FlxTypedSignal;
import flixel.FlxG;
import flixel.FlxGame;
import flixel.FlxState;
import flixel.system.debug.log.LogStyle;
import haxe.CallStack;
import haxe.Log;
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
import openfl.display.BitmapData;
import flixel.util.FlxColor;
import openfl.display.Bitmap;
import flixel.util.FlxTimer;
import hxwindowmode.WindowColorMode;
import system.FunkinGame;
import system.ResizeShaders;
import utilities.MusicTransition;
import states.PlayState;
import openfl.utils.Assets;
import Popup.PopupManager;
import system.MemoryManager;



class Main extends Sprite
{
	public static var instance:Main;
	public static var audioDisconnected:Bool = false;
	public static var game:FlxGame;
	public static var display:SimpleInfoDisplay;
	public static var logsOverlay:Logs;
	public static var previousState:FlxState;
	public static var onCrash(default, null):FlxTypedSignal<UncaughtErrorEvent->Void> = new FlxTypedSignal<UncaughtErrorEvent->Void>();
	public static var popupManager:PopupManager;

	public function new()
	{
		super();
		instance = this;

		#if sys
		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, _onUncaughtError);
		#end

		#if cpp
		untyped __global__.__hxcpp_set_critical_error_handler(_onUncaughtError);
		#end

		CoolUtil.haxe_trace = Log.trace;
		Log.trace = CoolUtil.haxe_print;
		OpenFLLog.throwErrors = false;

		Options.init();

		system.FunkinCache.init();
		#if (target.threaded || sys)
		system.OptimizedBitmapData.mainThread = sys.thread.Thread.current();
		#end

		#if MODDING_ALLOWED
		modding.ModList.load();
		modding.PolymodHandler.loadMods();
		#end

		game = new FunkinGame(1280, 720, TitleState, 60, 60, true, false);

		FlxG.signals.preStateSwitch.add(() ->
		{
			previousState = FlxG.state;

			// Clear orphan timers and tweens to prevent memory leaks across states
			flixel.tweens.FlxTween.globalManager.clear();
			flixel.util.FlxTimer.globalManager.clear();

			#if DISCORD_ALLOWED
			utilities.DiscordClient.onError.removeAll();
			utilities.DiscordClient.onDisconnect.removeAll();
			utilities.DiscordClient.onReady.removeAll();
			#end

			if (previousState != null)
				CoolUtil.clearMemory();
		});

		FlxG.signals.postStateSwitch.add(() ->
		{
			if (Options.getData("memoryCleaner"))
				MemoryManager.onPostStateSwitch();
		});

		addChild(game);


		logsOverlay = new Logs();
		logsOverlay.visible = false;
		addChild(logsOverlay);

		ResizeShaders.init();
		MusicTransition.init();
		init();

		LogStyle.WARNING.onLog.add((data, ?pos) -> trace(data, WARNING, pos));
		LogStyle.ERROR.onLog.add((data, ?pos) -> trace(data, ERROR, pos));
		LogStyle.NOTICE.onLog.add((data, ?pos) -> trace(data, LOG, pos));

		#if sys
		if (FlxG.save != null && FlxG.save.data != null && FlxG.save.data.windowColor != null)
			WindowColorMode.setWindowBorderColor(FlxG.save.data.windowColor);
		else
			WindowColorMode.setDarkMode();

		WindowColorMode.redrawWindowHeader();
		#end
	}

	private function init(?E:Event):Void
	{
		if (hasEventListener(Event.ADDED_TO_STAGE))
			removeEventListener(Event.ADDED_TO_STAGE, init);

		setupGame();
	}

	private function setupGame():Void
	{
		#if windows
		DPIFix.apply();
		#end

		#if cpp
		cpp.vm.Gc.enable(true);
		#end

		#if HXCPP_TRACY
		Lib.current.stage.addEventListener(Event.EXIT_FRAME, (_:Event) -> cpp.vm.tracy.TracyProfiler.frameMark());
		cpp.vm.tracy.TracyProfiler.messageAppInfo('Leather Engine Extended Support');
		cpp.vm.tracy.TracyProfiler.setThreadName('main');
		#end

		display = new SimpleInfoDisplay(10, 3, 0xFFFFFF, "_sans");
		addChild(display);

		popupManager = new PopupManager();
		addChild(popupManager);
		
		#if !mobile
		FlxG.mouse.useSystemCursor = true;
		#end
	}

	public static inline function toggleFPS(v:Bool):Void display.infoDisplayed[0] = v;
	public static inline function toggleMem(v:Bool):Void display.infoDisplayed[1] = v;
	public static inline function toggleVers(v:Bool):Void display.infoDisplayed[2] = v;
	public static inline function toggleLogs(v:Bool):Void display.infoDisplayed[3] = v;
	public static inline function toggleCommitHash(v:Bool):Void display.infoDisplayed[4] = v;
	public static inline function toggleDiscord(v:Bool):Void display.infoDisplayed[5] = v;

	public static inline function changeFont(font:String):Void
	{
		var tf = display.defaultTextFormat;
		display.defaultTextFormat = new TextFormat(font, tf.size, display.textColor);
	}

	public function setFPSCap(cap:Float)
	{
		openfl.Lib.current.stage.frameRate = cap;
	}

	public function getFPSCap():Float
	{
		return openfl.Lib.current.stage.frameRate;
	}

	#if sys
	/**
	 * Logs silent errors that are caught by try/catch blocks but otherwise ignored.
	 * Writes to crash/silent-errors.log and shows an in-game notification.
	 * @param error The caught error/exception
	 * @param context Description of where/what was happening
	 * @param pos Optional position info (file, line number)
	 */
	public static function logSilentError(error:Dynamic, context:String, ?pos:haxe.PosInfos):Void {
		if (!Options.getData("logSilentErrors"))
			return;

		var errorMsg:String = Std.string(error);
		var location:String = (pos != null) ? pos.fileName + ":" + pos.lineNumber : "unknown";
		var date:String = Date.now().toString();
		date = StringTools.replace(date, " ", "_");
		date = StringTools.replace(date, ":", "'");

		var logEntry:String = '[$date] $location ($context): $errorMsg\n';

		if (!FileSystem.exists("./crash/")) {
			FileSystem.createDirectory("./crash/");
		}

		var logPath:String = Sys.getCwd() + "crash/silent-errors.log";

		try {
			var existing:String = "";
			if (FileSystem.exists(logPath)) {
				existing = File.getContent(logPath);
			}
			File.saveContent(logPath, existing + logEntry + "---\n");
		} catch (e2:Dynamic) {
			Sys.println("Failed to write silent error log: " + e2);
		}

		Sys.println("[SILENT ERROR] " + location + " (" + context + "): " + errorMsg);

		try {
			CoolUtil.coolError(errorMsg, "Silent Error @ " + context);
		} catch (e3:Dynamic) {}
	}

	/**
	 * Shoutout to @gedehari for making the crash logging code
	 * They make some cool stuff check them out!
	 * @see https://github.com/gedehari/IzzyEngine/blob/master/source/Main.hx
	 * @param e
	 */
	private function _onUncaughtError(e:UncaughtErrorEvent):Void {
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

		// see the docs for e.error to see why we do this
		// since i guess it can sometimes be an issue???
		// /shrug - what-is-a-git 2024
		var errorData:String = "";
		if (e.error is Error) {
			errorData = cast(e.error, Error).message;
		} else if (e.error is ErrorEvent) {
			errorData = cast(e.error, ErrorEvent).text;
		} else {
			errorData = Std.string(e.error);
		}

		error += "\nUncaught Error: " + errorData;

		// Sanitize errorData to prevent path traversal or invalid characters in crash filename
		var sanitizedTag:String = ~/[\r\n\t\\\/:\*\?"<>\|]/g.replace(errorData, "_");
		if (sanitizedTag.length > 60) sanitizedTag = sanitizedTag.substr(0, 60);

		path = Sys.getCwd() + "crash/" + "crash-" + sanitizedTag + '-on-' + date + ".txt";

		if (!FileSystem.exists("./crash/")) {
			FileSystem.createDirectory("./crash/");
		}

		File.saveContent(path, error + "\n");

		Sys.println(error);
		Sys.println("Crash dump saved in " + path);

		var crashPath:String = "Crash" #if linux + '.x86_64' #end#if windows + ".exe" #end;

		if (FileSystem.exists("./" + crashPath)) {
			Sys.println("Found crash dialog: " + crashPath);

			#if linux
			crashPath = "./" + crashPath;
			new Process('chmod', ['+x', crashPath]); // make sure we can run the file lol
			#end
			FlxG.stage.window.visible = false;
			// Sanitize path parameter to prevent argument injection in subprocess execution
			var cleanPath = StringTools.replace(path, '"', '');
			new Process(crashPath, ['--crash_path=' + cleanPath]);
			// trace(process.exitCode());
		} else {
			Sys.println("No crash dialog found! Making a simple alert instead...");
			FlxG.stage.window.alert(error, "Error!");
		}

		Sys.exit(1);
	}
	#end
}
