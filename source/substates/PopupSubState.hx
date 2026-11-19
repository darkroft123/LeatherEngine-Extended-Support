package substates;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxTimer;
import flixel.group.FlxSpriteGroup;

class PopupSubState extends MusicBeatSubstate
{
    var bg:FlxSprite;
    var outerBorder:FlxSprite;
    var innerBorder:FlxSprite;
    var panel:FlxSprite;
    var accentLine:FlxSprite;

    var badgeTxt:FlxText;
    var titleTxt:FlxText;
    var descTxt:FlxText;

    // Interactive button cards
    var yesGroup:FlxSpriteGroup;
    var yesOuter:FlxSprite;
    var yesBox:FlxSprite;
    var yesText:FlxText;
    var yesHint:FlxText;

    var noGroup:FlxSpriteGroup;
    var noOuter:FlxSprite;
    var noBox:FlxSprite;
    var noText:FlxText;
    var noHint:FlxText;

    var selectedOption:Int = 0; // 0 = YES, 1 = NO
    var isClosing:Bool = false;
    var inputDelay:Float = 0.15;

    public var onYes:Void->Void;
    public var onNo:Void->Void;

    public function new(
        title:String = "NOTICE",
        message:String = "Are you sure?",
        yesLabel:String = "YES",
        noLabel:String = "NO",
        ?onYes:Void->Void,
        ?onNo:Void->Void
    )
    {
        super();
        this.onYes = onYes;
        this.onNo = onNo;

        FlxG.mouse.visible = true;

        bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        bg.alpha = 0;
        bg.scrollFactor.set();
        add(bg);

        var panelWidth:Int = 760;
        var panelHeight:Int = 390;
        var panelX:Float = (FlxG.width - panelWidth) / 2;
        var panelY:Float = (FlxG.height - panelHeight) / 2;

        // Cyber layered frames
        outerBorder = new FlxSprite(panelX - 3, panelY - 3).makeGraphic(panelWidth + 6, panelHeight + 6, 0xFF00FFD2);
        outerBorder.scrollFactor.set();
        outerBorder.alpha = 0;
        add(outerBorder);

        innerBorder = new FlxSprite(panelX - 1, panelY - 1).makeGraphic(panelWidth + 2, panelHeight + 2, 0xFF120024);
        innerBorder.scrollFactor.set();
        innerBorder.alpha = 0;
        add(innerBorder);

        panel = new FlxSprite(panelX, panelY).makeGraphic(panelWidth, panelHeight, 0xFF0A0A14);
        panel.scrollFactor.set();
        panel.alpha = 0;
        add(panel);

        var fontPath:String = Paths.font("Ethnocentric-Regular.otf");

        // Top tag badge
        badgeTxt = new FlxText(panelX, panelY + 18, panelWidth, "// PRACTICE RECOMMENDED //", 12);
        badgeTxt.setFormat(fontPath, 12, 0xFF00FFD2, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        badgeTxt.scrollFactor.set();
        badgeTxt.alpha = 0;
        add(badgeTxt);

        // Header Title
        titleTxt = new FlxText(panelX, panelY + 38, panelWidth, title, 26);
        titleTxt.setFormat(fontPath, 26, 0xFFFFF050, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        titleTxt.borderSize = 2;
        titleTxt.scrollFactor.set();
        titleTxt.alpha = 0;
        add(titleTxt);

        // Glowing divider line
        accentLine = new FlxSprite(panelX + 40, panelY + 78).makeGraphic(panelWidth - 80, 2, 0xFF00FFD2);
        accentLine.scrollFactor.set();
        accentLine.alpha = 0;
        add(accentLine);

        // Message text
        descTxt = new FlxText(panelX + 45, panelY + 105, panelWidth - 90, message, 16);
        descTxt.setFormat(fontPath, 16, FlxColor.WHITE, CENTER);
        descTxt.scrollFactor.set();
        descTxt.alpha = 0;
        add(descTxt);

        // --- BUTTONS SETUP ---
        var btnWidth:Int = 280;
        var btnHeight:Int = 64;
        var btnY:Float = panelY + panelHeight - 95;

        // YES BUTTON
        yesGroup = new FlxSpriteGroup(panelX + 65, btnY);
        yesGroup.scrollFactor.set();

        yesOuter = new FlxSprite(-2, -2).makeGraphic(btnWidth + 4, btnHeight + 4, 0xFF00FFD2);
        yesOuter.alpha = 0.5;
        yesGroup.add(yesOuter);

        yesBox = new FlxSprite(0, 0).makeGraphic(btnWidth, btnHeight, 0xFF101C24);
        yesGroup.add(yesBox);

        yesText = new FlxText(0, 10, btnWidth, yesLabel, 16);
        yesText.setFormat(fontPath, 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        yesGroup.add(yesText);

        yesHint = new FlxText(0, 36, btnWidth, "[ ENTER / CLICK ]", 10);
        yesHint.setFormat(fontPath, 10, 0xFF00FFD2, CENTER);
        yesGroup.add(yesHint);

        add(yesGroup);

        // NO BUTTON
        noGroup = new FlxSpriteGroup(panelX + panelWidth - btnWidth - 65, btnY);
        noGroup.scrollFactor.set();

        noOuter = new FlxSprite(-2, -2).makeGraphic(btnWidth + 4, btnHeight + 4, 0xFF4B5563);
        noOuter.alpha = 0.5;
        noGroup.add(noOuter);

        noBox = new FlxSprite(0, 0).makeGraphic(btnWidth, btnHeight, 0xFF181014);
        noGroup.add(noBox);

        noText = new FlxText(0, 10, btnWidth, noLabel, 16);
        noText.setFormat(fontPath, 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        noGroup.add(noText);

        noHint = new FlxText(0, 36, btnWidth, "[ ESC / CLICK ]", 10);
        noHint.setFormat(fontPath, 10, 0xFFEF4444, CENTER);
        noGroup.add(noHint);

        add(noGroup);

        // Entrance Tweens
        FlxTween.tween(bg, {alpha: 0.8}, 0.3, {ease: FlxEase.quartOut});
        FlxTween.tween(outerBorder, {alpha: 0.5}, 0.35, {ease: FlxEase.quartOut});
        FlxTween.tween(innerBorder, {alpha: 0.85}, 0.35, {ease: FlxEase.quartOut});
        FlxTween.tween(panel, {alpha: 0.95}, 0.35, {ease: FlxEase.quartOut});
        FlxTween.tween(badgeTxt, {alpha: 1}, 0.35, {ease: FlxEase.quartOut, startDelay: 0.05});
        FlxTween.tween(titleTxt, {alpha: 1}, 0.35, {ease: FlxEase.quartOut, startDelay: 0.1});
        FlxTween.tween(accentLine, {alpha: 0.6}, 0.35, {ease: FlxEase.quartOut, startDelay: 0.12});
        FlxTween.tween(descTxt, {alpha: 1}, 0.35, {ease: FlxEase.quartOut, startDelay: 0.15});

        yesGroup.alpha = 0;
        noGroup.alpha = 0;
        FlxTween.tween(yesGroup, {alpha: 1}, 0.35, {ease: FlxEase.quartOut, startDelay: 0.2});
        FlxTween.tween(noGroup, {alpha: 1}, 0.35, {ease: FlxEase.quartOut, startDelay: 0.2});

        updateSelection();

        cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
    }

    function updateSelection():Void
    {
        if (selectedOption == 0)
        {
            yesGroup.scale.set(1.05, 1.05);
            noGroup.scale.set(0.95, 0.95);

            yesOuter.color = 0xFF00FFD2;
            yesOuter.alpha = 0.85;
            yesBox.color = 0xFF16323B;
            yesText.color = 0xFF00FFD2;

            noOuter.color = 0xFF4B5563;
            noOuter.alpha = 0.35;
            noBox.color = 0xFF140F12;
            noText.color = 0xFF888899;
        }
        else
        {
            yesGroup.scale.set(0.95, 0.95);
            noGroup.scale.set(1.05, 1.05);

            yesOuter.color = 0xFF4B5563;
            yesOuter.alpha = 0.35;
            yesBox.color = 0xFF101C24;
            yesText.color = 0xFF888899;

            noOuter.color = 0xFFEF4444;
            noOuter.alpha = 0.85;
            noBox.color = 0xFF35151A;
            noText.color = 0xFFEF4444;
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

        // Mouse hover checks
        if (FlxG.mouse.visible)
        {
            if (FlxG.mouse.overlaps(yesGroup))
            {
                if (selectedOption != 0)
                {
                    selectedOption = 0;
                    FlxG.sound.play(Paths.sound("scrollMenu"), 0.4);
                    updateSelection();
                }
                if (FlxG.mouse.justPressed)
                {
                    acceptYes();
                    return;
                }
            }
            else if (FlxG.mouse.overlaps(noGroup))
            {
                if (selectedOption != 1)
                {
                    selectedOption = 1;
                    FlxG.sound.play(Paths.sound("scrollMenu"), 0.4);
                    updateSelection();
                }
                if (FlxG.mouse.justPressed)
                {
                    acceptNo();
                    return;
                }
            }
        }

        // Keyboard navigation
        if (controls.LEFT_P || controls.RIGHT_P || FlxG.keys.justPressed.A || FlxG.keys.justPressed.D)
        {
            selectedOption = (selectedOption == 0) ? 1 : 0;
            FlxG.sound.play(Paths.sound("scrollMenu"), 0.4);
            updateSelection();
        }

        if (controls.ACCEPT || FlxG.keys.justPressed.ENTER)
        {
            if (selectedOption == 0)
                acceptYes();
            else
                acceptNo();
        }

        if (controls.BACK || FlxG.keys.justPressed.ESCAPE)
        {
            acceptNo();
        }
    }

    function acceptYes():Void
    {
        isClosing = true;
        FlxG.sound.play(Paths.sound("confirmMenu"));
        animateOut(function() {
            close();
            if (onYes != null) onYes();
        });
    }

    function acceptNo():Void
    {
        isClosing = true;
        FlxG.sound.play(Paths.sound("cancelMenu"));
        animateOut(function() {
            close();
            if (onNo != null) onNo();
        });
    }

    function animateOut(onComplete:Void->Void):Void
    {
        FlxTween.tween(bg, {alpha: 0}, 0.2, {ease: FlxEase.quartIn});
        FlxTween.tween(outerBorder, {alpha: 0}, 0.2, {ease: FlxEase.quartIn});
        FlxTween.tween(innerBorder, {alpha: 0}, 0.2, {ease: FlxEase.quartIn});
        FlxTween.tween(panel, {alpha: 0}, 0.2, {ease: FlxEase.quartIn});
        FlxTween.tween(badgeTxt, {alpha: 0}, 0.15, {ease: FlxEase.quartIn});
        FlxTween.tween(titleTxt, {alpha: 0}, 0.15, {ease: FlxEase.quartIn});
        FlxTween.tween(accentLine, {alpha: 0}, 0.15, {ease: FlxEase.quartIn});
        FlxTween.tween(descTxt, {alpha: 0}, 0.15, {ease: FlxEase.quartIn});
        FlxTween.tween(yesGroup, {alpha: 0}, 0.15, {ease: FlxEase.quartIn});
        FlxTween.tween(noGroup, {alpha: 0}, 0.15, {ease: FlxEase.quartIn});

        new FlxTimer().start(0.22, function(_) {
            if (onComplete != null) onComplete();
        });
    }

    override function closeSubState():Void
    {
        FlxG.mouse.visible = false;
        super.close();
    }

}
