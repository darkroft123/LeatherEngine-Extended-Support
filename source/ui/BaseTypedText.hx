package ui;

import flixel.FlxG;
import flixel.text.FlxText;
import flixel.util.FlxTimer;

class BaseTypedText extends FlxText
{
	public var delay:Float = 0.05;
	public var paused:Bool = false;
	public var targetY:Float = 0;
	public var isMenuItem:Bool = false;

	var _finalText:String = "";
	var _curText:String = "";
	var yMulti:Float = 1;
	var splitWords:Array<String> = [];
	var isBold:Bool = false;
	var isTyped:Bool = false;

	public function new(x:Float, y:Float, text:String = "", bold:Bool = false, typed:Bool = false, fontSize:Int = 48)
	{
		super(x, y, FlxG.width, "", fontSize);
		_finalText = text;
		this.text = "";
		isBold = bold;
		isTyped = typed;

		if (text != "")
		{
			if (typed)
				startTypedText();
			else
				addText();
		}
	}

	public function addText()
	{
		text = _finalText;
	}

	public function doSplitWords():Void
	{
		splitWords = [];
		for (i in 0..._finalText.length)
			splitWords.push(_finalText.substr(i, 1));
	}

	public function startTypedText():Void
	{
		doSplitWords();
		text = "";

		for (loopNum in 0..._finalText.length)
		{
			new FlxTimer().start(0.05 + (0.05 * loopNum), function(tmr:FlxTimer)
			{
				if (this != null && this.active && this.visible && this.alpha != 0)
					text += splitWords[loopNum];
			});
		}
	}
}
