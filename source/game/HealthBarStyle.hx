package game;

import flixel.ui.FlxBar;
import flixel.util.FlxColor;
import flixel.math.FlxMath;

class HealthBarStyle {
	public var style:String = "default";
	public var curR:Float = 0;
	public var curG:Float = 0;
	public var curB:Float = 0;

	public function new() {}

	public function apply(bar:FlxBar, dadColor:FlxColor, bfColor:FlxColor, ?curSection:Int = 0, ?mustHit:Bool = false)
	{
		switch (style) {
			case "gradient":
				CoolUtil.applyBarGradient(bar, dadColor, bfColor);
			case "by type":
				var target:FlxColor = mustHit ? bfColor : dadColor;
				curR = target.redFloat;
				curG = target.greenFloat;
				curB = target.blueFloat;
				CoolUtil.applyBarFill(bar, target, target);
			default:
				CoolUtil.applyBarFill(bar, dadColor, bfColor);
		}
	}

	public function updateByType(bar:FlxBar, elapsed:Float, dadColor:FlxColor, bfColor:FlxColor, mustHit:Bool)
	{
		if (style != "by type") return;

		var target:FlxColor = mustHit ? bfColor : dadColor;
		curR = FlxMath.lerp(curR, target.redFloat, elapsed * 6);
		curG = FlxMath.lerp(curG, target.greenFloat, elapsed * 6);
		curB = FlxMath.lerp(curB, target.blueFloat, elapsed * 6);
		var curColor = FlxColor.fromRGBFloat(curR, curG, curB);
		CoolUtil.applyBarFill(bar, curColor, curColor);
	}

	public function onSectionChange(bar:FlxBar, dadColor:FlxColor, bfColor:FlxColor, mustHit:Bool)
	{
		if (style != "by type") return;

		var target:FlxColor = mustHit ? bfColor : dadColor;
		curR = target.redFloat;
		curG = target.greenFloat;
		curB = target.blueFloat;
	}
}
