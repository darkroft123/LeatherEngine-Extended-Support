package ui;

import flixel.FlxG;
import flixel.math.FlxMath;
import flixel.text.FlxText.FlxTextBorderStyle;

class FreeplayTxt extends BaseTypedText
{
	public function new(x:Float, y:Float, text:String = "", ?bold:Bool = false, typed:Bool = false)
	{
		var fontSize:Int = bold ? 64 : 48;
		super(x, y, text, bold, typed, fontSize);

		setFormat(Paths.font("EurostileExtendedBlack.ttf"), fontSize, 0xFF000000, "left");
		borderStyle = FlxTextBorderStyle.OUTLINE;
		borderColor = 0xFFFFFFFF;
		borderSize = 2;
	}

	override function update(elapsed:Float)
	{
		if (isMenuItem)
		{
			var scaledY = FlxMath.remapToRange(targetY, 0, 1, 0, 1.3);
			var lerpVal:Float = CoolUtil.boundTo(elapsed * 9.6, 0, 1);
			y = FlxMath.lerp(y, (scaledY * 120) + (FlxG.height * 0.48), lerpVal);
			x = FlxMath.lerp(x, (targetY * 20) + 90, lerpVal);
		}
		super.update(elapsed);
	}
}
