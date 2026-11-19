package substates;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import states.FreeplayState;
import states.StoryMenuState;
import states.PlayState;

class ExitChartingSubstate extends MusicBeatSubstate
{
	var bg:FlxSprite;
	var titleText:FlxText;
	var promptText:FlxText;
	var curSelected:Int = 0;
	var options:Array<String> = ["Exit to Freeplay", "Exit to Charter Menu", "Cancel"];
	var optionTexts:Array<FlxText> = [];

	public function new(
		title:String = "EXIT CHARTING MODE",
		subtitle:String = "Select destination:",
		?_options:Array<Dynamic> = null
	)
	{
		super();
		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0;
		bg.scrollFactor.set();
		add(bg);
		FlxTween.tween(bg, {alpha: 0.6}, 0.25, {ease: FlxEase.quartOut});

		titleText = new FlxText(0, 180, FlxG.width, title, 36);
		titleText.setFormat(Paths.font("vcr.ttf"), 36, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		titleText.scrollFactor.set();
		add(titleText);

		promptText = new FlxText(0, 240, FlxG.width, subtitle, 22);
		promptText.setFormat(Paths.font("vcr.ttf"), 22, FlxColor.YELLOW, CENTER, OUTLINE, FlxColor.BLACK);
		promptText.scrollFactor.set();
		add(promptText);

		for (i in 0...options.length) {
			var txt = new FlxText(0, 320 + (i * 60), FlxG.width, options[i], 28);
			txt.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
			txt.scrollFactor.set();
			optionTexts.push(txt);
			add(txt);
		}
		changeSelection(0);
	}

	function changeSelection(change:Int = 0) {
		curSelected = flixel.math.FlxMath.wrap(curSelected + change, 0, options.length - 1);
		for (i in 0...optionTexts.length) {
			if (i == curSelected) {
				optionTexts[i].color = FlxColor.CYAN;
				optionTexts[i].scale.set(1.1, 1.1);
			} else {
				optionTexts[i].color = FlxColor.WHITE;
				optionTexts[i].scale.set(1.0, 1.0);
			}
		}
	}

	override function update(elapsed:Float) {
		super.update(elapsed);
		if (controls.UP_P) changeSelection(-1);
		if (controls.DOWN_P) changeSelection(1);
		if (controls.BACK) close();
		if (controls.ACCEPT) {
			switch (curSelected) {
				case 0:
					PlayState.chartingMode = PlayState.modchartingMode = false;
					if (FlxG.sound.music != null) FlxG.sound.music.stop();
					if (PlayState.isStoryMode)
						FlxG.switchState(() -> new StoryMenuState());
					else
						FlxG.switchState(() -> new FreeplayState());
				case 1:
					if (FlxG.sound.music != null) FlxG.sound.music.stop();
					FlxG.switchState(() -> new toolbox.CharterSelectionState());
				case 2:
					close();
			}
		}
	}
}
