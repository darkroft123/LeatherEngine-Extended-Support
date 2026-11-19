package ui;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import flixel.group.FlxGroup;
import flixel.util.FlxTimer;

class InfoBanner extends FlxGroup {
    public var bg:FlxSprite;
    public var text:FlxText;
    public var messages:Array<String> = [];
    public var delay:Float = 2.0;
    public var loop:Bool = true;
    var index:Int = 0;

    public var bannerColor:FlxColor = FlxColor.BLACK;
    public var textColor:FlxColor = FlxColor.WHITE;
    public var textSize:Int = 16;
    public var fontPath:String = Paths.font("vcr.ttf");

    public function new(
        ?color:FlxColor = FlxColor.BLACK,
        ?alpha:Float = 0.6,
        ?size:Int = 16,
        ?font:String,
        ?txtColor:FlxColor = FlxColor.WHITE
    ) {
        super();

        bannerColor = color;
        textColor = txtColor;
        textSize = size;
        if (font != null) fontPath = font;

        var height = textSize + 12;
        bg = new FlxSprite(0, FlxG.height - height).makeGraphic(FlxG.width, height, bannerColor);
        bg.alpha = alpha;
        add(bg);

        text = new FlxText(0, bg.y + 5, FlxG.width, "", textSize);
        text.setFormat(fontPath, textSize, textColor, CENTER);
        text.scrollFactor.set();
        add(text);
    }

    public function show(list:Array<String>, ?delaySeconds:Float = 2.0, ?loopTexts:Bool = true) {
        messages = list;
        delay = delaySeconds;
        loop = loopTexts;
        index = 0;
        showNext();
    }

    public function setStyle(?color:FlxColor, ?textColor_:FlxColor, ?font:String, ?size:Int) {
        if (color != null) {
            bannerColor = color;
            bg.makeGraphic(FlxG.width, Std.int(bg.height), bannerColor);
        }
        if (textColor_ != null) textColor = textColor_;
        if (font != null) fontPath = font;
        if (size != null) textSize = size;

        text.setFormat(fontPath, textSize, textColor, CENTER);
    }

    function showNext() {
        if (messages.length == 0) return;

        if (index >= messages.length) {
            if (loop)
                index = 0;
            else
                return;
        }

        text.text = messages[index];
        index++;

        // Start below the background (hidden)
        text.y = FlxG.height + 5;
        text.alpha = 0;

        // Text enters upward
        FlxTween.tween(text, { y: (bg.y + 5), alpha: 1 }, 0.4, { ease: FlxEase.circOut });

        new FlxTimer().start(delay, function(_) {
            // Text leaves downward
            FlxTween.tween(text, { y: FlxG.height + 5, alpha: 0 }, 0.4, {
                ease: FlxEase.circIn,
                onComplete: function(_) showNext()
            });
        });
    }
}
