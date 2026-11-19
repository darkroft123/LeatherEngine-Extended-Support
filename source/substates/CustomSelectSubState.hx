package substates;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxTimer;
import ui.DesingText;

class CustomSelectSubState extends MusicBeatSubstate
{
    var bg:FlxSprite;
    var panel:FlxSprite;
    var titleTxt:FlxText;
    var descTxt:FlxText;

    var options:Array<DesingText> = [];
    var optionLabels:Array<String> = [];
    var curSelected:Int = 0;
    var isClosing:Bool = false;
    var inputDelay:Float = 0.15;

    public var onSelect:Int->Void;
    public var onCancel:Void->Void;

    var desingTextStyle:Dynamic = {
        songFont: "Ethnocentric-Regular.otf",
        outerBorderTop: "#000000",
        outerBorderBot: "#000000",
        midBorderTop: "#a7face",
        midBorderBot: "#32b7a0",
        innerBorderTop: "#393939",
        innerBorderBot: "#2e2d2d",
        outerBorderSize: 4,
        shadowAlpha: 0
    };

    public function new(
        title:String = "OPTIONS",
        message:String = "Select an option:",
        optionLabels:Array<String>,
        ?onSelect:Int->Void,
        ?onCancel:Void->Void
    )
    {
        super();
        this.optionLabels = (optionLabels != null && optionLabels.length > 0) ? optionLabels : ["OK"];
        this.onSelect = onSelect;
        this.onCancel = onCancel;

        FlxG.mouse.visible = true;

        bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        bg.alpha = 0;
        bg.scrollFactor.set();
        add(bg);

        var panelWidth:Int = 760;
        var panelHeight:Int = Std.int(Math.max(340, 200 + (this.optionLabels.length * 65)));
        var panelX:Float = (FlxG.width - panelWidth) / 2;
        var panelY:Float = (FlxG.height - panelHeight) / 2;

        panel = new FlxSprite(panelX, panelY).makeGraphic(panelWidth, panelHeight, 0xFF181818);
        panel.scrollFactor.set();
        panel.alpha = 0;
        panel.scale.set(0.7, 0.7);
        add(panel);

        titleTxt = new FlxText(panelX, panelY + 25, panelWidth, title, 28);
        titleTxt.setFormat(Paths.font("Ethnocentric-Regular.otf"), 28, FlxColor.CYAN, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        titleTxt.borderSize = 2;
        titleTxt.scrollFactor.set();
        titleTxt.alpha = 0;
        add(titleTxt);

        descTxt = new FlxText(panelX + 40, panelY + 75, panelWidth - 80, message, 18);
        descTxt.setFormat(Paths.font("Ethnocentric-Regular.otf"), 18, FlxColor.WHITE, CENTER);
        descTxt.scrollFactor.set();
        descTxt.alpha = 0;
        add(descTxt);

        var startY:Float = panelY + 130;
        var spacingY:Float = 60;

        for (i in 0...this.optionLabels.length)
        {
            var opt:DesingText = DesingText.createSongText(
                panelX,
                startY + (i * spacingY),
                this.optionLabels[i],
                26,
                0,
                desingTextStyle,
                1.0
            );
            opt.screenCenter(X);
            opt.scrollFactor.set();
            opt.alpha = 0;
            add(opt);
            options.push(opt);
        }

        FlxTween.tween(bg, {alpha: 0.75}, 0.35, {ease: FlxEase.quartOut});
        FlxTween.tween(panel, {alpha: 1}, 0.35, {ease: FlxEase.backOut});
        FlxTween.tween(panel.scale, {x: 1.0, y: 1.0}, 0.35, {ease: FlxEase.backOut});
        FlxTween.tween(titleTxt, {alpha: 1}, 0.35, {ease: FlxEase.quartOut, startDelay: 0.1});
        FlxTween.tween(descTxt, {alpha: 1}, 0.35, {ease: FlxEase.quartOut, startDelay: 0.15});

        for (i in 0...options.length)
        {
            FlxTween.tween(options[i], {alpha: 1}, 0.35, {ease: FlxEase.quartOut, startDelay: 0.2 + (i * 0.05)});
        }

        updateSelection();

        cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
    }

    function updateSelection():Void
    {
        for (i in 0...options.length)
        {
            var opt = options[i];
            if (i == curSelected)
            {
                opt.scale.set(1.05, 1.05);
            }
            else
            {
                opt.scale.set(0.8, 0.8);
            }
            opt.updateHitbox();
            opt.screenCenter(X);
        }
    }

    override function update(elapsed:Float):Void
    {
        super.update(elapsed);

        if (isClosing) return;

        if (inputDelay > 0)
        {
            inputDelay -= elapsed;
            return;
        }

        if (controls.UP_P || FlxG.keys.justPressed.W)
        {
            curSelected--;
            if (curSelected < 0) curSelected = options.length - 1;
            FlxG.sound.play(Paths.sound("scrollMenu"), 0.4);
            updateSelection();
        }

        if (controls.DOWN_P || FlxG.keys.justPressed.S)
        {
            curSelected++;
            if (curSelected >= options.length) curSelected = 0;
            FlxG.sound.play(Paths.sound("scrollMenu"), 0.4);
            updateSelection();
        }

        if (controls.ACCEPT || FlxG.keys.justPressed.ENTER)
        {
            selectOption();
        }

        if (controls.BACK || FlxG.keys.justPressed.ESCAPE)
        {
            cancelExit();
        }
    }

    function selectOption():Void
    {
        isClosing = true;
        FlxG.sound.play(Paths.sound("confirmMenu"));

        var chosenIndex = curSelected;
        animateOut(function() {
            close();
            if (onSelect != null) onSelect(chosenIndex);
        });
    }

    function cancelExit():Void
    {
        isClosing = true;
        FlxG.sound.play(Paths.sound("cancelMenu"));
        animateOut(function() {
            close();
            if (onCancel != null) onCancel();
        });
    }

    function animateOut(onComplete:Void->Void):Void
    {
        FlxTween.tween(bg, {alpha: 0}, 0.25, {ease: FlxEase.quartIn});
        FlxTween.tween(panel, {alpha: 0}, 0.25, {ease: FlxEase.quartIn});
        FlxTween.tween(panel.scale, {x: 0.7, y: 0.7}, 0.25, {ease: FlxEase.quartIn});
        FlxTween.tween(titleTxt, {alpha: 0}, 0.2, {ease: FlxEase.quartIn});
        FlxTween.tween(descTxt, {alpha: 0}, 0.2, {ease: FlxEase.quartIn});

        for (opt in options)
        {
            FlxTween.tween(opt, {alpha: 0}, 0.2, {ease: FlxEase.quartIn});
        }

        new FlxTimer().start(0.25, function(_) {
            if (onComplete != null) onComplete();
        });
    }

    override function closeSubState():Void
    {
        FlxG.mouse.visible = false;
        super.close();
    }

}
