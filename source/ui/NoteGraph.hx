package ui;

import openfl.geom.Rectangle;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.math.FlxMath;

import game.Replay;
import states.PlayState;

class NoteGraph extends FlxGroup
{
    var judgeArray:Array<Float>;

    static inline var GRAPH_W:Int = 500;
    static inline var GRAPH_H:Int = 332;
    static inline var CENTER_Y:Int = 166;

    public function new(replay:Replay, startX:Float = 0, startY:Float = 0)
    {
        super();

        judgeArray = utilities.Options.getData("judgementTimings");

        var bg = new FlxSprite(startX, startY)
            .makeGraphic(GRAPH_W, GRAPH_H, FlxColor.BLACK);
        bg.alpha = 0.3;
        add(bg);

       	var missLine1 = new FlxSprite(startX, startY).makeGraphic(500, 4, FlxColor.RED); // top line
		missLine1.alpha = 0.5;
		add(missLine1);

		var shitLine1 = new FlxSprite(startX, startY + 166 - judgeArray[3]).makeGraphic(500, 4, FlxColor.MAGENTA);
		shitLine1.alpha = 0.5;
		add(shitLine1);

		var badLine1 = new FlxSprite(startX, startY + 166 - judgeArray[2]).makeGraphic(500, 4, FlxColor.CYAN);
		badLine1.alpha = 0.5;
		add(badLine1);

		var goodLine1 = new FlxSprite(startX, startY + 166 - judgeArray[1]).makeGraphic(500, 4, FlxColor.LIME);
		goodLine1.alpha = 0.5;
		add(goodLine1);

		var sickLine1 = new FlxSprite(startX, startY + 166 - judgeArray[0]).makeGraphic(500, 4, FlxColor.YELLOW);
		sickLine1.alpha = 0.5;
		add(sickLine1);

		var marvLine = new FlxSprite(startX, startY + 166).makeGraphic(500, 4, FlxColor.WHITE); // center line
		marvLine.alpha = 0.5;
		add(marvLine);

		var sickLine2 = new FlxSprite(startX, startY + 166 + judgeArray[0]).makeGraphic(500, 4, FlxColor.YELLOW);
		sickLine2.alpha = 0.5;
		add(sickLine2);

		var goodLine2 = new FlxSprite(startX, startY + 166 + judgeArray[1]).makeGraphic(500, 4, FlxColor.LIME);
		goodLine2.alpha = 0.5;
		add(goodLine2);


		var badLine2 = new FlxSprite(startX, startY + 166 + judgeArray[2]).makeGraphic(500, 4, FlxColor.CYAN);
		badLine2.alpha = 0.5;
		add(badLine2);

		var shitLine2 = new FlxSprite(startX, startY + 166 + judgeArray[3]).makeGraphic(500, 4, FlxColor.MAGENTA);
		shitLine2.alpha = 0.5;
		add(shitLine2);

		var missLine1 = new FlxSprite(startX, startY + 332).makeGraphic(500, 4, FlxColor.RED); // bottom line
		missLine1.alpha = 0.5;
		add(missLine1);

       	var dots:FlxSprite = new FlxSprite(startX, startY).makeGraphic(500, 332);

		dots.graphic.bitmap.lock();
		dots.graphic.bitmap.floodFill(0, 0, 0x00000000);

		for (i in 0...replay.inputs.length) {
			var input = replay.inputs[i];

			var dif = input[1];
			var strumTime = input[0];

			dots.graphic.bitmap.fillRect(new Rectangle(500 * (strumTime / FlxG.sound.music.length), 166 + (dif / PlayState.songMultiplier), 6, 6),
				FlxColor.fromRGB(Math.floor(255 * (Math.abs(dif) / 166)), 255, 0));
		}

		dots.graphic.bitmap.unlock();
		add(dots);

        trace("Replay inputs: " + replay.inputs.length);


    }


    function rgbToInt(r:Int, g:Int, b:Int):Int {
		return (255 << 24) | (r << 16) | (g << 8) | b;
	}

	function colorDiff(difference:Float) {
		if (difference < (judgeArray[0]))
			return FlxColor.WHITE;
		else if (difference < (judgeArray[1]))
			return FlxColor.YELLOW;
		else if (difference < (judgeArray[2]))
			return FlxColor.LIME;
		else if (difference < (judgeArray[3]))
			return FlxColor.CYAN;
		else 
			return FlxColor.MAGENTA;
	}
}
