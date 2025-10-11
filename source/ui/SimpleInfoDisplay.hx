package ui;

import macros.GithubCommitHash;
import flixel.util.FlxStringUtil;
import flixel.FlxG;
import openfl.utils.Assets;
import openfl.text.TextField;
import openfl.text.TextFormat;
import external.memory.Memory;
import macros.GithubCommitHash;
import haxe.macro.Compiler;
#if DISCORD_ALLOWED
import hxdiscord_rpc.Discord;
import hxdiscord_rpc.Types;
#end
import cpp.RawConstPointer;
import cpp.ConstCharStar;
import ui.logs.Logs;

/**
 * Shows basic info about the game.
 */
class SimpleInfoDisplay extends TextField {//like codename
    //                                      fps    mem   version console info , discord
    public var infoDisplayed:Array<Bool> = [false, false, false, false, false, false]; 
    public var framerate:Int = 0;
    private var framerateTimer:Float = 0.0;
    private var framesCounted:Int = 0;
    public var version:String = CoolUtil.getCurrentVersion();
    public var discordUserName:String = ""; 

    // tamaños fijos
    public var fpsSize:Int = 24;
    public var smallSize:Int = 12;

    public function new(x:Float = 10.0, y:Float = 10.0, color:Int = 0xFFFFFF, ?font:String) {
		super();
		this.x = x;
		this.y = y;
		selectable = false;

		defaultTextFormat = new TextFormat(
			font ?? Assets.getFont(Paths.font("consola.ttf")).fontName,
			smallSize,
			color
		);

		FlxG.signals.postDraw.add(update);

		width = FlxG.width;
		height = FlxG.height;
	}

	public function update():Void {
		framerateTimer += FlxG.elapsed;
		if (framerateTimer >= 1) {
			framerateTimer = 0;
			framerate = framesCounted;
			framesCounted = 0;
		}
		framesCounted++;

		if (!visible) return;

		var fpsStr = Std.string(framerate);
		var memUsed = FlxStringUtil.formatBytes(Memory.getCurrentUsage());
		var memPeak = FlxStringUtil.formatBytes(Memory.getPeakUsage());

		text = '';
		if (infoDisplayed[0]) text += fpsStr + " FPS\n";
		if (infoDisplayed[1]) text += memUsed + " / " + memPeak + "\n";
		if (infoDisplayed[2]) text += "Leather Engine Plus " + version + "\n";
		if (infoDisplayed[3] && (Main.logsOverlay.logs.length > 0 || Logs.errors > 0)) {
				var logInfo = '';
				if (Main.logsOverlay.logs.length > 0) {
					logInfo += '${Main.logsOverlay.logs.length} traced lines';
				}
				if (Logs.errors > 0) {
					if (logInfo.length > 0) logInfo += ' | ';
					logInfo += '${Logs.errors} errors';
				}
				if (Main.logsOverlay.logs.length > 0) {
					logInfo += '. F3 to view.';
				}
				text += logInfo + '\n';
			}


		if (infoDisplayed[4]) text += 'Commit   (${GithubCommitHash.getGitCommitHash().substring(0, 7)})\n';
		if (infoDisplayed[5]) text += 'Discord: ${discordUserName}\n';

		setTextFormat(new TextFormat(defaultTextFormat.font, smallSize, 0xFFFFFF), 0, text.length);

		// --- FPS ---
		var fpsIndex = text.indexOf(fpsStr);
		if (fpsIndex != -1) {
			setTextFormat(new TextFormat(defaultTextFormat.font, fpsSize, 0xFFFFFF),
				fpsIndex, fpsIndex + fpsStr.length);
			setTextFormat(new TextFormat(defaultTextFormat.font, smallSize, 0xFFFFFF),
				fpsIndex + fpsStr.length, fpsIndex + fpsStr.length + 4);
		}

		// --- Memory ---
		if (infoDisplayed[1]) {
			var memIndex = text.indexOf(memUsed);
			if (memIndex != -1) {
				
				setTextFormat(new TextFormat(defaultTextFormat.font, smallSize, 0xFFFFFF),
					memIndex, memIndex + memUsed.length);
				// " / "
				var grayStart = memIndex + memUsed.length;
				setTextFormat(new TextFormat(defaultTextFormat.font, smallSize, 0xAAAAAA),
					grayStart, grayStart + 3 + memPeak.length);
			}
		}
	}


}
