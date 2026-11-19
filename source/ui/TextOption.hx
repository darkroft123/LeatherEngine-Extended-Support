package ui;

import flixel.FlxG;
import flixel.math.FlxMath;

class TextOption extends BaseTypedText
{
	public var lerpSpeed:Float = 14;
	public var lerpY:Bool = true;

	public function new(x:Float, y:Float, text:String = "", ?bold:Bool = false, typed:Bool = false, ?color:Int = 0xFFFFFFFF)
	{
		var fontSize:Int = 34;
		super(x, y, text, bold, typed, fontSize);

		setFormat(Paths.font("Ethnocentric-Regular.otf"), fontSize, color, "center");
	}

	override function update(elapsed:Float)
	{
		if (isMenuItem)
		{
			var spacing:Int = 90;
			var startY:Float = FlxG.height * 0.2;
			var targetYPos:Float = startY + (targetY * spacing);
			if (lerpY)
				y = FlxMath.lerp(y, targetYPos, FlxMath.bound(elapsed * lerpSpeed, 0, 1));
			else
				y = targetYPos;
			x = (FlxG.width - width) / 2;
		}
		super.update(elapsed);
	}
}
