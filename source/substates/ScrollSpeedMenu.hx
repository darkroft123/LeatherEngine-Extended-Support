package substates;

import flixel.math.FlxMath;

class ScrollSpeedMenu extends ValueAdjustSubstate
{
	public function new()
	{
		super("Scrollspeed: ", "customScrollSpeed", 1, 0.1, 10, 0.1);
	}

	override function onValueChange()
	{
		curValue = FlxMath.roundDecimal(curValue, 1);
	}
}
