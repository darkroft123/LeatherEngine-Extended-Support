package substates;

import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.FlxG;
import flixel.FlxSprite;

class ValueAdjustSubstate extends MusicBeatSubstate
{
	var bg:FlxSprite;
	var offsetText:FlxText;
	var displayFormat:String;
	var saveKey:String;
	var minVal:Float;
	var maxVal:Float;
	var step:Float;
	var useContinuous:Bool;

	public var curValue:Float;

	public function new(displayFormat:String, saveKey:String, defaultValue:Float, minVal:Float = 0, maxVal:Float = 99999, step:Float = 1, useContinuous:Bool = false)
	{
		super();

		this.displayFormat = displayFormat;
		this.saveKey = saveKey;
		this.minVal = minVal;
		this.maxVal = maxVal;
		this.step = step;
		this.useContinuous = useContinuous;

		curValue = Options.getData(saveKey);

		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0;
		bg.scrollFactor.set();
		add(bg);

		FlxTween.tween(bg, {alpha: 0.5}, 1, {ease: FlxEase.circOut});

		offsetText = new FlxText(0, 0, 0, "", 64).setFormat(Paths.font("vcr.ttf"), 64, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		updateText();
		offsetText.screenCenter();
		add(offsetText);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		var leftP = controls.LEFT_P;
		var rightP = controls.RIGHT_P;
		var back = controls.BACK;

		var changed = false;

		if (useContinuous)
		{
			if (controls.LEFT && !FlxG.keys.pressed.SHIFT) { curValue -= step; changed = true; }
			if (controls.RIGHT && !FlxG.keys.pressed.SHIFT) { curValue += step; changed = true; }
			if (leftP && FlxG.keys.pressed.SHIFT) { curValue -= step; changed = true; }
			if (rightP && FlxG.keys.pressed.SHIFT) { curValue += step; changed = true; }
		}
		else
		{
			if (leftP) { curValue -= step; changed = true; }
			if (rightP) { curValue += step; changed = true; }
		}

		curValue = Math.max(minVal, Math.min(maxVal, curValue));

		if (changed) onValueChange();

		if (back)
		{
			onSave();
			Options.setData(curValue, saveKey);
			FlxG.state.closeSubState();
		}

		updateText();
	}

	function updateText()
	{
		offsetText.text = displayFormat + curValue;
		offsetText.screenCenter();
	}

	function onValueChange() {}
	function onSave() {}

}
