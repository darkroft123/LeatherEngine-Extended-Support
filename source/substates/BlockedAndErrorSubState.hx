package substates;

import flixel.util.FlxTimer;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.FlxG;
import flixel.FlxSprite;
import ui.BlockedSongComponent;
class BlockedAndErrorSubState extends MusicBeatSubstate {
    var bg:FlxSprite;
    var titleTxt:FlxText;
    var msgTxt:FlxText;
    var closeBtn:FlxButton;
    public var onCloseCallback:Void->Void;

    public function new(message:String, title:String = "Error", ?onClose:Void->Void) {
        super();
        this.onCloseCallback = onClose;

        FlxG.mouse.visible = true;

        bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.fromRGB(0, 0, 0, 200));
        bg.alpha = 0;
        add(bg);

        titleTxt = new FlxText(0, 120, FlxG.width, title);
        titleTxt.setFormat(Paths.font("vcr.ttf"), 36, FlxColor.RED, "center");
        titleTxt.alpha = 0;
        add(titleTxt);

        var lowerMsg = message.toLowerCase();
        var isBlocked:Bool = false;

        for (song in BlockedSongComponent.authoritativeBlockedSongs) {
            if (lowerMsg.contains(song)) {
                isBlocked = true;
                break;
            }
        }

        var finalMessage = message;
        var color = FlxColor.WHITE;

        if (isBlocked) {
            finalMessage = "This song is blocked and cannot be played.";
            titleTxt.text = "???";
            color = FlxColor.CYAN;
        }

        msgTxt = new FlxText(100, 220, FlxG.width - 200, finalMessage);
        msgTxt.setFormat(Paths.font("vcr.ttf"), 22, color, "center");
        msgTxt.alpha = 0;
        add(msgTxt);

        closeBtn = new FlxButton(0, 420, "OK", () -> close());
        closeBtn.setGraphicSize(250, 70);
        closeBtn.updateHitbox();
        closeBtn.screenCenter(X);
        closeBtn.label.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.BLACK, "center");
        closeBtn.alpha = 0;
        add(closeBtn);

   
        FlxTween.tween(bg, {alpha: 0.8}, 0.3, {ease: FlxEase.quadOut});
        FlxTween.tween(titleTxt, {alpha: 1}, 0.4, {ease: FlxEase.quadOut, startDelay: 0.1});
        FlxTween.tween(msgTxt, {alpha: 1}, 0.4, {ease: FlxEase.quadOut, startDelay: 0.2});
        FlxTween.tween(closeBtn, {alpha: 1}, 0.4, {ease: FlxEase.quadOut, startDelay: 0.3});
    }

    override public function close():Void {
        var _this = this;
        FlxTween.tween(bg, {alpha: 0}, 0.3, {ease: FlxEase.quadIn});
        FlxTween.tween(titleTxt, {alpha: 0}, 0.25, {ease: FlxEase.quadIn});
        FlxTween.tween(msgTxt, {alpha: 0}, 0.25, {ease: FlxEase.quadIn});
        FlxTween.tween(closeBtn, {alpha: 0}, 0.25, {ease: FlxEase.quadIn});

        new FlxTimer().start(0.3, function(_) {
            _this.closeSubState();
            if (_this.onCloseCallback != null) {
                _this.onCloseCallback();
            }
        });
    }

    override function closeSubState():Void {
        FlxG.mouse.visible = false;
        super.close();
    }

}
