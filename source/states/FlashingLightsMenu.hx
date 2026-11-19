package states;

import flixel.FlxG;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import ui.Checkbox;
#if DISCORD_ALLOWED
#end

class FlashingLightsMenu extends MusicBeatState {
	var title:FlxText;
	var info:FlxText;

	var flashingText:FlxText;
	var shadersText:FlxText;
	var scriptsText:FlxText;

	var flashingCheck:Checkbox;
	var shadersCheck:Checkbox;
	var scriptsCheck:Checkbox;

	var descFlashing:FlxText;
	var descShaders:FlxText;
	var descScripts:FlxText;

	var continueText:FlxText;
	var canContinue:Bool = true;

	var initialFlashing:Bool;
	var initialShaders:Bool;
	var initialScripts:Bool;

	override public function create() {
		super.create();

		FlxG.mouse.visible = true;

		initialFlashing = Options.getData("flashingLights") ?? true;
		initialShaders = Options.getData("shaders") ?? true;
		initialScripts = Options.getData("disableScripts") ?? false;

		title = new FlxText(0, 60, 0, 'WELCOME TO LEATHER ENGINE EXTENDED SUPPORT', 32);
		title.setFormat(Paths.font("vcr.ttf"), 38, FlxColor.WHITE, CENTER);
		title.screenCenter(X);
		add(title);

		info = new FlxText(
			0,
			135,
			0,
			"Choose your visual options.\nYou can change these later in the settings menu.",
			20
		);
		info.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER);
		info.screenCenter(X);
		add(info);

		var baseX = FlxG.width / 2 - 250;
		var baseY = 240;
		var spacing = 65;

		flashingText = new FlxText(baseX, baseY, 0, "Flashing Lights", 26);
		flashingText.setFormat(Paths.font("vcr.ttf"), 26, FlxColor.CYAN);
		add(flashingText);

		flashingCheck = new Checkbox(flashingText);
		flashingCheck.checked = initialFlashing;
		flashingCheck.setGraphicSize(34, 34);
		flashingCheck.updateHitbox();
		add(flashingCheck);

		shadersText = new FlxText(baseX, baseY + spacing, 0, "Shaders", 26);
		shadersText.setFormat(Paths.font("vcr.ttf"), 26, FlxColor.LIME);
		add(shadersText);

		shadersCheck = new Checkbox(shadersText);
		shadersCheck.checked = initialShaders;
		shadersCheck.setGraphicSize(34, 34);
		shadersCheck.updateHitbox();
		add(shadersCheck);

		scriptsText = new FlxText(baseX, baseY + spacing * 2, 0, "Disable Scripts", 26);
		scriptsText.setFormat(Paths.font("vcr.ttf"), 26, FlxColor.PINK);
		add(scriptsText);

		scriptsCheck = new Checkbox(scriptsText);
		scriptsCheck.checked = initialScripts;
		scriptsCheck.setGraphicSize(34, 34);
		scriptsCheck.updateHitbox();
		add(scriptsCheck);

		var descY = FlxG.height - 210;

		descFlashing = new FlxText(0, descY, FlxG.width,
			"FLASHING LIGHTS : Enables or disables flashing visual effects.", 18);
		descFlashing.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.CYAN, CENTER);
		add(descFlashing);

		descShaders = new FlxText(0, descY + 30, FlxG.width,
			"SHADERS : Toggles post-processing effects like blur and color correction.", 18);
		descShaders.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.LIME, CENTER);
		add(descShaders);

		descScripts = new FlxText(0, descY + 60, FlxG.width,
			"DISABLE SCRIPTS : Turns off scripts with shaders for better performance.", 18);
		descScripts.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.PINK, CENTER);
		add(descScripts);

		continueText = new FlxText(0, FlxG.height - 60, 0, "PRESS ENTER TO CONTINUE", 24);
		continueText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER);
		continueText.screenCenter(X);
		continueText.alpha = 1;
		add(continueText);

		flashingCheck.useDefaultOffset = false;
		shadersCheck.useDefaultOffset = false;
		scriptsCheck.useDefaultOffset = false;
	}

	override function update(elapsed:Float) {
		super.update(elapsed);

		if (flashingCheck.checked != Options.getData("flashingLights")) {
			Options.setData(flashingCheck.checked, "flashingLights");
			updateContinueText("Flashing Lights", flashingCheck.checked);
		}

		if (shadersCheck.checked != Options.getData("shaders")) {
			Options.setData(shadersCheck.checked, "shaders");
			updateContinueText("Shaders", shadersCheck.checked);
		}

		if (scriptsCheck.checked != Options.getData("disableScripts")) {
			Options.setData(scriptsCheck.checked, "disableScripts");
			updateContinueText("Disable Scripts", scriptsCheck.checked);
		}

		if (canContinue) {
			if (
				FlxG.keys.justPressed.ENTER ||
				(FlxG.gamepads.lastActive != null && FlxG.gamepads.lastActive.justPressed.START)
			) {
				FlxG.sound.play(Paths.sound("confirmMenu"));
				FlxG.mouse.visible = false;
				FlxG.switchState(() -> new TitleState());
			}
		}
	}

	function updateContinueText(option:String, state:Bool) {
		if (option == "Flashing Lights") {
			continueText.text = state 
				? "You enabled Flashing Lights - PRESS ENTER TO CONTINUE"
				: "You disabled Flashing Lights - PRESS ENTER TO CONTINUE";
		}

		if (option == "Shaders") {
			continueText.text = state 
				? "You enabled Shaders - PRESS ENTER TO CONTINUE"
				: "You disabled Shaders - PRESS ENTER TO CONTINUE";
		}

		if (option == "Disable Scripts") {
			continueText.text = state 
				? "You disabled Scripts - PRESS ENTER TO CONTINUE"
				: "You enabled Scripts - PRESS ENTER TO CONTINUE";
		}

		continueText.screenCenter(X);
	}

	override function destroy():Void {
		if (continueText != null) flixel.tweens.FlxTween.cancelTweensOf(continueText);
		super.destroy();
	}
}
