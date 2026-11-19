package substates;

import flixel.math.FlxMath;

@:publicFields
class NoteBGAlphaMenu extends ValueAdjustSubstate
{
	public function new()
	{
		super("Alpha: ", "noteBGAlpha", 0, 0, 1, 0.1);
	}

	override function onValueChange()
	{
		curValue = FlxMath.roundDecimal(curValue, 1);
	}
}
