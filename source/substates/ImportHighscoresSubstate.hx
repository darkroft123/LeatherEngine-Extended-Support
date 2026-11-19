package substates;

import game.Highscore;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.FlxG;

@:publicFields
class ImportHighscoresSubstate extends ConfirmSubstate
{
	var waitingForFile:Bool = false;

	override public function close() {
		if (waitingForFile) return;
		super.close();
	}

	public function new()
	{
		super("IMPORT SCORES?", function() {
			#if desktop
			waitingForFile = true;
			var fileDialog = new lime.ui.FileDialog();
			fileDialog.onSelect.add(function(path:String) {
				try {
					var appData = Sys.getEnv("APPDATA");
					if (appData == null) appData = Sys.getEnv("HOME");
					
					var company = lime.app.Application.current.meta.get("company");
					var file = lime.app.Application.current.meta.get("file");
					
					var destDir = haxe.io.Path.join([appData, company, file, "leather128"]);
					if (!sys.FileSystem.exists(destDir)) {
						sys.FileSystem.createDirectory(destDir);
					}
					
					var destPath = haxe.io.Path.join([destDir, "leathersfunkinengine.sol"]);
					sys.io.File.copy(path, destPath);
					
					Highscore.importOldData();
					
					var fileName = haxe.io.Path.withoutDirectory(path);
					FlxG.sound.play(Paths.sound('confirmMenu'));
					
					var msg = new FlxText(0, FlxG.height - 150, FlxG.width, "Imported scores from: " + fileName);
					msg.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.LIME, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
					msg.scrollFactor.set();
					FlxG.state.add(msg);
					flixel.tweens.FlxTween.tween(msg, {alpha: 0}, 3, {startDelay: 3});
				} catch(e:Dynamic) {
					FlxG.sound.play(Paths.sound('cancelMenu'));
				}
				waitingForFile = false;
				close();
			});
			fileDialog.onCancel.add(function() {
				FlxG.sound.play(Paths.sound('cancelMenu'));
				waitingForFile = false;
				close();
			});
			fileDialog.browse(lime.ui.FileDialogType.OPEN, "sol", null, "Select your old .sol file");
			#else
			Highscore.importOldData();
			#end
		}, "");
		
		var desc = "This will import local highscores from old Engine versions.\n\n"
			+ "HOW IT WORKS:\n"
			+ "- Click YES to open your file explorer.\n"
			+ "- Find and select your old '.sol' save file.\n"
			+ "- The game will automatically read and import those scores.\n\n"
			+ "Are you sure you want to proceed?";

		var infoText = new FlxText(0, FlxG.height * 0.25 + 70, FlxG.width * 0.9, desc);
		infoText.setFormat(Paths.font("vcr.ttf"), 22, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		infoText.screenCenter(X);
		add(infoText);
	}
}
