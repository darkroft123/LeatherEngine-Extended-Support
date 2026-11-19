package;

import flixel.FlxObject;
import flixel.FlxSprite;
import openfl.display.BitmapData;
import openfl.display.Bitmap;
import openfl.display.Sprite;
import openfl.Lib;
import openfl.display.FPS;
import flixel.FlxG;
import lime.app.Application;
import openfl.events.Event;
import openfl.system.System;
import openfl.text.TextField;
import openfl.text.TextFormat;
import flixel.math.FlxMath;

class Popup extends Sprite
{
    public var alive:Bool = true;
    public var shouldKill:Bool = false;

    public var popupY:Float = 0;
    public var popupHeight:Float = 90;
    public var popupWidth:Float = 360;

    var timeElapsed:Float = 0;
    var time:Float = 0;

    var screenWidth:Int;

    public function new(time:Float, w:Int = 360, h:Int = 90)
    {
        super();

        this.time = time;
        popupWidth = w;
        popupHeight = h;
        popupY = -h;
        this.y = popupY;

        screenWidth = Lib.application.window.width;
        this.x = screenWidth - w - 20;
        this.alpha = 0;
    }

    public static function getFontName():String
    {
        try {
            var fontPath = Paths.font("Contb___.ttf");
            if (openfl.utils.Assets.exists(fontPath)) {
                var font = openfl.utils.Assets.getFont(fontPath);
                if (font != null) return font.fontName;
            }
        } catch(e:Dynamic) {
            trace("Error loading font: " + e);
        }
        return "_sans";
    }

    public static function createTextField(text:String, size:Int, width:Float, height:Float, color:Int = 0xFFFFFF, bold:Bool = false):TextField
    {
        var tf = new TextField();
        var format = new TextFormat(Popup.getFontName(), size, color);
        format.bold = bold;

        tf.defaultTextFormat = format;
        tf.width = width;
        tf.height = height;
        tf.selectable = false;
        tf.wordWrap = true;
        tf.multiline = true;

        var fontName = Popup.getFontName();
        tf.embedFonts = (fontName != "_sans");

        tf.text = text;
        return tf;
    }

    public function update(deltaTime:Float):Void
    {
        timeElapsed += deltaTime;

        // Dynamically adjust layout for screen width changes
        screenWidth = Lib.application.window.width;
        this.x = screenWidth - popupWidth - 20;

        this.y = popupY;

        if (timeElapsed >= time)
            alive = false;

        shouldKill = (timeElapsed >= time + 1.0); // 1.0s buffer to complete fade out
    }
}

class MessagePopup extends Popup
{
    var titleText:TextField;
    var msgText:TextField;

    public function new(time:Float, w:Int = 320, h:Int = 80, m:String = "", size:Int = 13)
    {
        super(time, w, h);

        // Styling the card background
        this.graphics.clear();
        this.graphics.beginFill(0x0E0E16, 0.85); // glass dark bg
        this.graphics.drawRoundRect(0, 0, w, h, 14, 14);
        this.graphics.endFill();

        // Glowing blue border
        this.graphics.lineStyle(1.5, 0x3B82F6, 0.5);
        this.graphics.drawRoundRect(0, 0, w, h, 14, 14);

        // Left accent bar
        this.graphics.beginFill(0x3B82F6, 0.9);
        this.graphics.drawRoundRect(6, 12, 4, h - 24, 2, 2);
        this.graphics.endFill();

        titleText = Popup.createTextField("SYSTEM MESSAGE", 10, w - 30, 16, 0x60A5FA, true);
        titleText.x = 20;
        titleText.y = 12;
        addChild(titleText);

        msgText = Popup.createTextField(m, size, w - 30, h - 35, 0xFFFFFF, false);
        msgText.x = 20;
        msgText.y = 28;
        addChild(msgText);
    }
}

class PopupManager extends Sprite
{
    var popups:Array<Popup> = [];

    public function new()
    {
        super();

        FlxG.signals.postUpdate.add(function()
        {
            update(FlxG.elapsed);
        });

        FlxG.signals.postStateSwitch.add(function()
        {
            for (popup in popups)
                FlxG.addChildBelowMouse(popup);
        });
    }

    function update(elapsed:Float):Void
    {
        if (popups.length == 0)
            return;

        var currentPopupHeight:Float = 0;

        for (popup in popups)
        {
            var popupPos:Float = -popup.popupHeight;

            if (popup.alive)
            {
                popupPos = currentPopupHeight + 20; // 20px top padding
                currentPopupHeight += popup.popupHeight + 15; // 15px gap between popups
            }

            popup.popupY = FlxMath.lerp(
                popup.popupY,
                popupPos,
                Math.min(elapsed * 8, 1) // slightly faster slide
            );

            // Fade-in when alive, fade-out when dead
            var targetAlpha:Float = popup.alive ? 1.0 : 0.0;
            popup.alpha = FlxMath.lerp(
                popup.alpha,
                targetAlpha,
                Math.min(elapsed * 10, 1)
            );

            popup.update(elapsed);
        }

        for (i in popups.length - 1...-1)
        {
            var popup = popups[i];

            if (popup.shouldKill)
            {
                removeChild(popup);
                FlxG.removeChild(popup);
                popups.splice(i, 1);
            }
        }
    }

    public function addPopup(popup:Popup):Void
    {
        FlxG.addChildBelowMouse(popup);
        popups.push(popup);
    }
}
