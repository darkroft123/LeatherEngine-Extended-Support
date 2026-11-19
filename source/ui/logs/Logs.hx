package ui.logs;

import flixel.system.debug.log.LogStyle;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;
import lime.app.Application;
import openfl.events.Event;
import flixel.util.FlxColor;
import flixel.FlxG;
import openfl.display.Bitmap;
import openfl.display.Sprite;
import openfl.display.BitmapData;

class Logs extends Sprite {
	public var logs:Array<String> = [];
	public var logEntries:Array<{text:String, colorHex:String}> = [];

	public var bg:Bitmap;
	public var divider:Bitmap;
	public var leftHeader:TextField;
	public var rightHeader:TextField;
	public var logText:LogText;
	public var diagText:LogText;

	public static var instance:Logs = null;
	public static var errors(default, null) = 0;

	private var needsUpdate:Bool = false;
	private var diagTimer:Float = 0.0;

	private static var cachedOS:String = null;
	private static var cachedCPU:String = null;
	private static var cachedGPU:String = null;

	public var texts:Map<PrintType, LogPrint> = [
		PrintType.LOG => new LogPrint("LOG", FlxColor.CYAN),
		PrintType.WARNING => new LogPrint("WARN", FlxColor.YELLOW),
		PrintType.ERROR => new LogPrint("ERROR", FlxColor.RED),
		PrintType.DEBUG => new LogPrint("DEBUG", FlxColor.LIME),
	];

	public function new() {
		super();
		instance = this;

		var stageW = Application.current != null ? Application.current.window.width : FlxG.width;
		var stageH = Application.current != null ? Application.current.window.height : FlxG.height;
		var leftW = stageW * 0.7;
		var rightW = stageW * 0.3;
		var topY = 32.0;
		var panelH = stageH - topY - 10.0;

		bg = new Bitmap(new BitmapData(stageW, stageH, true, 0xEE05070D));
		addChild(bg);

		divider = new Bitmap(new BitmapData(2, Std.int(panelH), true, 0x55356BFF));
		divider.x = leftW;
		divider.y = topY;
		addChild(divider);

		var fontName:String = Options.getData("infoDisplayFont");
		if (fontName == null || fontName.length == 0) fontName = "VCR OSD Mono";

		
		var tfLeftHeader = new TextFormat(fontName, 15, 0x00FFFF, true);
		tfLeftHeader.align = LEFT;

		leftHeader = new TextField();
		leftHeader.defaultTextFormat = tfLeftHeader;
		leftHeader.selectable = false;
		leftHeader.x = 10;
		leftHeader.y = 8;
		leftHeader.width = leftW - 20;
		leftHeader.height = 20;
		leftHeader.text = "[CONSOLE LOGS]  (F3: Close | F4: Clear)";
		addChild(leftHeader);

		var tfRightHeader = new TextFormat(fontName, 15, 0xCCFF00, true);
		tfRightHeader.align = LEFT;

		rightHeader = new TextField();
		rightHeader.defaultTextFormat = tfRightHeader;
		rightHeader.selectable = false;
		rightHeader.x = leftW + 10;
		rightHeader.y = 8;
		rightHeader.width = rightW - 20;
		rightHeader.height = 20;
		rightHeader.text = "[SYSTEM AND HARDWARE DIAGNOSTICS]";
		addChild(rightHeader);

		
		logText = new LogText(10, topY + 2, {width: leftW - 20, height: panelH - 4}, "", 15, LEFT);
		addChild(logText);

		diagText = new LogText(leftW + 10, topY + 2, {width: rightW - 20, height: panelH - 4}, "", 14, LEFT);
		addChild(diagText);

		addEventListener(Event.ENTER_FRAME, onFrameUpdate);
		if (FlxG.stage != null && FlxG.stage.window != null)
			FlxG.stage.window.onResize.add(onStageResized);
	}

	public function onFrameUpdate(_):Void {
		if (!Options.getData("developer"))
			return;

		if (FlxG.keys.justPressed.F3) {
			visible = !visible;
			if (visible) {
				updateDiagnostics();
				updateLogDisplay();
			}
		} else if (FlxG.keys.justPressed.F4) {
			logs = [];
			logEntries = [];
			logText.htmlText = '';
			errors = 0;
			leftHeader.text = "[CONSOLE LOGS]  (F3: Close | F4: Clear)";
		}

		if (visible) {
			diagTimer += FlxG.elapsed;
			if (diagTimer >= 0.5) {
				diagTimer = 0.0;
				updateDiagnostics();
			}

			if (needsUpdate) {
				needsUpdate = false;
				updateLogDisplay();
			}

			if (FlxG.mouse.wheel != 0 && FlxG.stage != null) {
				var leftW = Application.current.window.width * 0.7;
				if (FlxG.stage.mouseX < leftW) {
					logText.scrollV -= FlxG.mouse.wheel * 3;
				} else {
					diagText.scrollV -= FlxG.mouse.wheel * 3;
				}
			}

			if (FlxG.keys.pressed.PAGEUP) {
				logText.scrollV -= 4;
				diagText.scrollV -= 4;
			} else if (FlxG.keys.pressed.PAGEDOWN) {
				logText.scrollV += 4;
				diagText.scrollV += 4;
			}
		}
	}

	public static function getStaticDeviceInfo():Void {
		if (cachedOS == null) {
			#if windows
			var envOs = Sys.getEnv("OS");
			var envArch = Sys.getEnv("PROCESSOR_ARCHITECTURE");
			cachedOS = (lime.system.System.platformLabel != null && lime.system.System.platformLabel.length > 0)
				? '${lime.system.System.platformLabel} ${lime.system.System.platformVersion != null ? lime.system.System.platformVersion : ""}'
				: (envOs != null ? '$envOs ($envArch)' : "Windows");
			#else
			cachedOS = lime.system.System.platformLabel != null ? lime.system.System.platformLabel : "Unknown";
			#end
		}

		if (cachedCPU == null) {
			#if windows
			var proc = Sys.getEnv("PROCESSOR_IDENTIFIER");
			var cores = Sys.getEnv("NUMBER_OF_PROCESSORS");
			var coreStr = (cores != null && cores.length > 0) ? ' (${cores} Threads)' : '';
			cachedCPU = (proc != null && proc.length > 0) ? (proc + coreStr) : 'Generic CPU$coreStr';
			#else
			cachedCPU = openfl.system.Capabilities.cpuArchitecture;
			#end
		}

		if (cachedGPU == null || cachedGPU == "Unknown GPU") {
			try {
				@:privateAccess
				if (FlxG.stage != null && FlxG.stage.context3D != null && FlxG.stage.context3D.gl != null) {
					var gl = FlxG.stage.context3D.gl;
					var r = gl.getParameter(gl.RENDERER);
					var v = gl.getParameter(gl.VENDOR);
					var renStr = r != null ? StringTools.trim(Std.string(r)).split("/")[0] : "";
					var venStr = v != null ? StringTools.trim(Std.string(v)) : "";
					if (renStr.length > 0) {
						cachedGPU = renStr + (venStr.length > 0 && renStr.indexOf(venStr) == -1 ? ' ($venStr)' : '');
					} else if (FlxG.stage.context3D.driverInfo != null) {
						cachedGPU = FlxG.stage.context3D.driverInfo;
					} else {
						cachedGPU = "OpenGL GPU";
					}
				}
			} catch (e:Dynamic) {
				cachedGPU = "OpenGL GPU";
			}
		}
	}

	private static function formatBytes(bytes:Float):String {
		if (bytes < 1024)
			return Math.round(bytes) + " B";
		else if (bytes < 1024 * 1024)
			return (Math.round((bytes / 1024) * 10) / 10) + " KB";
		else if (bytes < 1024 * 1024 * 1024)
			return (Math.round((bytes / (1024 * 1024)) * 10) / 10) + " MB";
		else
			return (Math.round((bytes / (1024 * 1024 * 1024)) * 100) / 100) + " GB";
	}

	public function updateDiagnostics():Void {
		getStaticDeviceInfo();

		var curRss = formatBytes(external.memory.Memory.getCurrentUsage());
		var peakRss = formatBytes(external.memory.Memory.getPeakUsage());
		#if cpp
		var gcMem = formatBytes(cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_USAGE));
		#else
		var gcMem = formatBytes(openfl.system.System.totalMemory);
		#end

		var fps = (Main.display != null) ? Main.display.framerate : ((FlxG.stage != null) ? Math.round(FlxG.stage.frameRate) : 60);
		var targetFps = (FlxG.stage != null) ? Math.round(FlxG.stage.frameRate) : FlxG.drawFramerate;
		var curState = FlxG.state != null ? Type.getClassName(Type.getClass(FlxG.state)).split(".").pop() : "None";
		var cachedBmps = FlxG.bitmap != null ? Lambda.count(@:privateAccess FlxG.bitmap._cache) : 0;
		var soundCount = FlxG.sound != null ? FlxG.sound.list.length : 0;
		var cams = FlxG.cameras != null ? FlxG.cameras.list.length : 0;

		var sb = new StringBuf();
		sb.add('<font color="#33FFFF"><b>--- SYSTEM AND HARDWARE ---</b></font><br/>');
		sb.add('<font color="#88CCFF">Operating System: </font>' + StringTools.htmlEscape(cachedOS) + '<br/>');
		sb.add('<font color="#88CCFF">Processor (CPU): </font>' + StringTools.htmlEscape(cachedCPU) + '<br/>');
		sb.add('<font color="#88CCFF">Graphics Card (GPU): </font>' + StringTools.htmlEscape(cachedGPU) + '<br/>');
		sb.add('<br/>');

		sb.add('<font color="#FFFF33"><b>--- MEMORY AND PROCESS ---</b></font><br/>');
		sb.add('<font color="#88CCFF">RAM Usage (Process): </font><b>' + curRss + '</b> / ' + peakRss + ' (Peak)<br/>');
		sb.add('<font color="#88CCFF">Haxe Heap (GC): </font>' + gcMem + '<br/>');
		sb.add('<font color="#88CCFF">Garbage Collector: </font>Active (cpp.vm.Gc)<br/>');
		sb.add('<br/>');

		sb.add('<font color="#33FF66"><b>--- ENGINE AND PERFORMANCE ---</b></font><br/>');
		sb.add('<font color="#88CCFF">Framerate (FPS): </font><b>' + fps + ' FPS</b> (Target: ' + targetFps + ')<br/>');
		sb.add('<font color="#88CCFF">Current State: </font>' + curState + '<br/>');
		sb.add('<font color="#88CCFF">Cached Textures: </font>' + cachedBmps + ' active bitmaps<br/>');
		sb.add('<font color="#88CCFF">Sound Channels: </font>' + soundCount + ' active<br/>');
		sb.add('<font color="#88CCFF">Cameras: </font>' + cams + '<br/>');
		sb.add('<font color="#88CCFF">Versions: </font>Flixel ${FlxG.VERSION}<br/>');
		sb.add('<br/>');

		sb.add('<font color="#FF66CC"><b>--- CONSOLE AND EVENTS ---</b></font><br/>');
		sb.add('<font color="#88CCFF">Log Lines: </font>' + logs.length + '<br/>');
		sb.add('<font color="#88CCFF">Logged Errors: </font>' + errors + '<br/>');

		diagText.htmlText = sb.toString();
	}

	public function updateLogDisplay():Void {
		var sb = new StringBuf();
		for (entry in logEntries) {
			var safeText = StringTools.htmlEscape(entry.text);
			sb.add('<font color="' + entry.colorHex + '">' + safeText + '</font><br/>');
		}
		logText.htmlText = sb.toString();
		logText.scrollV = Std.int(logText.maxScrollV);

		var errStr = errors > 0 ? ' | Errors: ${errors}' : '';
		if (leftHeader != null)
			leftHeader.text = '[CONSOLE LOGS]  (Lines: ${logs.length}${errStr})';
	}

	private function onStageResized(w:Int, h:Int):Void {
		var stageW = Application.current.window.width;
		var stageH = Application.current.window.height;
		var leftW = stageW * 0.7;
		var rightW = stageW * 0.3;
		var topY = 32.0;
		var panelH = stageH - topY - 10.0;

		bg.width = stageW;
		bg.height = stageH;

		divider.x = leftW;
		divider.y = topY;
		divider.height = panelH;

		leftHeader.x = 10;
		leftHeader.y = 8;
		leftHeader.width = leftW - 20;

		rightHeader.x = leftW + 10;
		rightHeader.y = 8;
		rightHeader.width = rightW - 20;

		logText.x = 10;
		logText.y = topY + 2;
		logText.width = leftW - 20;
		logText.height = panelH - 4;

		diagText.x = leftW + 10;
		diagText.y = topY + 2;
		diagText.width = rightW - 20;
		diagText.height = panelH - 4;

		if (visible) {
			updateDiagnostics();
			updateLogDisplay();
		}
	}

	public static inline function log(message:Dynamic) {
		if (Logs.instance != null)
			Logs.instance.addLog(message, PrintType.LOG);
	}

	public static inline function debug(message:Dynamic) {
		if (Logs.instance != null)
			Logs.instance.addLog(message, PrintType.DEBUG);
	}

	public static inline function warn(message:Dynamic) {
		if (Logs.instance != null)
			Logs.instance.addLog(message, PrintType.WARNING);
	}

	public static inline function error(message:Dynamic) {
		if (Logs.instance != null)
			Logs.instance.addLog(message, PrintType.ERROR);
		errors++;
		if (LogStyle.ERROR.throwException) {
			throw message;
		}
	}

	public function addLog(message:Dynamic, type:PrintType):Void {
		if (message == null) return;

		var info:LogPrint = texts.get(type);
		var prefix = (info != null ? info.text + " " : "");
		var colorHex = (info != null ? '#' + StringTools.hex(info.color.rgb, 6) : '#FFFFFF');
		var entryText = prefix + Std.string(message);

		logs.push(entryText);
		if (logs.length > 80)
			logs.shift();

		logEntries.push({text: entryText, colorHex: colorHex});
		if (logEntries.length > 80)
			logEntries.shift();

		needsUpdate = true;
	}
}
