package ui;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;

class Checkbox extends FlxSprite
{
    public var checked:Bool = false;

   
    public var useDefaultOffset:Bool = true;

    public var manualOffsetX:Float = 0;
    public var manualOffsetY:Float = 0;

    var spriteTracker:FlxSprite;
    var textTracker:FlxText;

    public function new(tracking:FlxSprite)
    {
        super();

        var imgPath = Paths.getPath('images/options menu/checkbox.png', IMAGE, null);
        var xmlPath = Paths.getPath('images/options menu/checkbox.xml', TEXT, null);
        var bitmap = openfl.Assets.getBitmapData(imgPath);
        if (bitmap != null)
        {
            var graphic = flixel.graphics.FlxGraphic.fromBitmapData(bitmap, false);
            var xmlStr = openfl.Assets.getText(xmlPath);
            if (xmlStr != null)
                frames = flixel.graphics.frames.FlxAtlasFrames.fromSparrow(graphic, xmlStr);
        }

        animation.addByIndices("checkOn", "CheckBox",
            [0,1,2,3,4,5,6,7,8,9,10,11], "", 24, false);

        animation.addByIndices("checkOff", "CheckBox",
            [12,13,14,15,16,17,18,19,20], "", 24, false);

        animation.play("checkOff");

        animation.finishCallback = function(name:String)
        {
            animation.curAnim.pause();
        };

        scrollFactor.set();
        updateHitbox();

        if (Std.isOfType(tracking, FlxText))
            textTracker = cast tracking;
        else
            spriteTracker = tracking;
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        if (textTracker != null)
        {
            if (useDefaultOffset)
                x = textTracker.x + textTracker.width - 270 + manualOffsetX;
            else
                x = textTracker.x + textTracker.width + 10 + manualOffsetX;

            y = textTracker.y + (textTracker.height - height) / 2 + manualOffsetY;
        }
        else if (spriteTracker != null)
        {
            if (useDefaultOffset)
                x = spriteTracker.x + spriteTracker.width - 270 + manualOffsetX;
            else
                x = spriteTracker.x + spriteTracker.width + 10 + manualOffsetX;

            y = spriteTracker.y + (spriteTracker.height - height) / 2 + manualOffsetY;
        }

        if (FlxG.mouse.justPressed && visible && overlapsPoint(FlxG.mouse.getScreenPosition()))
        {
            checked = !checked;
            FlxG.sound.play(Paths.sound("scrollMenu"), 0.5);
        }

        if (checked && (animation.curAnim == null || animation.curAnim.name != "checkOn"))
            animation.play("checkOn", true);
        else if (!checked && (animation.curAnim == null || animation.curAnim.name != "checkOff"))
            animation.play("checkOff", true);

    }
}