package substates;

import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import hxwindowmode.WindowColorMode;

@:publicFields
class WindowColorSubstate extends MusicBeatSubstate
{
    var colorVals:Array<Int>;
    var selectedValue:Int = 0;
    var descText:FlxText;
    var resetText:FlxText;

    var holdTimer:Float = 0;
    var repeatDelay:Float = 0.05;

    public function new()
    {
        super();

        if(FlxG.save.data.windowColor == null)
            FlxG.save.data.windowColor = [255, 255, 255];

        colorVals = FlxG.save.data.windowColor.copy();

        var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        bg.alpha = 0;
        bg.scrollFactor.set();
        add(bg);
        FlxTween.tween(bg, {alpha:0.8}, 0.5, {ease:FlxEase.circOut});

        descText = new FlxText(0, 100, FlxG.width, "");
        descText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        add(descText);

        resetText = new FlxText(0, 100, FlxG.width, "Press R to Reset");
        resetText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.YELLOW, CENTER, OUTLINE, FlxColor.BLACK);
        add(resetText);

        updateText();
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        var leftP = controls.LEFT_P;
        var rightP = controls.RIGHT_P;
        var upP = FlxG.keys.pressed.UP || controls.UP_P;
        var downP = FlxG.keys.pressed.DOWN || controls.DOWN_P;
        var accept = controls.ACCEPT;
        var back = controls.BACK;
        var resetKey = FlxG.keys.justPressed.R;

        if(leftP)
        {
            selectedValue--;
            if(selectedValue < 0) selectedValue = 2;
        }

        if(rightP)
        {
            selectedValue++;
            if(selectedValue > 2) selectedValue = 0;
        }

        if(upP || downP)
        {
            holdTimer += elapsed;

            if(holdTimer >= repeatDelay)
            {
                if(upP) colorVals[selectedValue] = (colorVals[selectedValue] + 1) % 256;
                if(downP) colorVals[selectedValue] = (colorVals[selectedValue] - 1 + 256) % 256;
                holdTimer = 0;
            }
        }
        else
        {
            holdTimer = 0;
        }

        if(accept)
        {
            WindowColorMode.setWindowBorderColor(colorVals);
            FlxG.save.data.windowColor = colorVals.copy();
            FlxG.save.flush();
        }

        if(resetKey)
        {
            colorVals = [255, 255, 255];
            WindowColorMode.setWindowBorderColor(colorVals); // Apply immediately on reset
        }

        if(back)
        {
            FlxG.state.closeSubState();
        }

        updateText();
    }

    function updateText()
    {
        var r = Std.string(colorVals[0]);
        var g = Std.string(colorVals[1]);
        var b = Std.string(colorVals[2]);

        switch(selectedValue)
        {
            case 0: r = "> " + r + " <";
            case 1: g = "> " + g + " <";
            case 2: b = "> " + b + " <";
        }

        descText.text = "Use UP/DOWN to change the value of the selected color\nLEFT/RIGHT to select Red, Green or Blue\nENTER to apply color\nBACK to exit\n\nRed: " + r + ", Green: " + g + ", Blue: " + b;

        descText.screenCenter(X);
        descText.y = FlxG.height / 2 - 50;

        resetText.screenCenter(X);
        resetText.y = descText.y + 120;
    }

}