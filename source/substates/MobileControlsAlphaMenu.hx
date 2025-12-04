package substates;

import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.input.gamepad.FlxGamepadInputID;
import flixel.input.gamepad.FlxGamepad;
import mobile.flixel.FlxVirtualPad;

class MobileControlsAlphaMenu extends substates.MusicBeatSubstate
{
    var opacityValue:Float = 0.0;
    var offsetText:FlxText = new FlxText(0,0,0,"Alpha: 0",64)
        .setFormat(Paths.font("vcr.ttf"), 64, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
    var vpad:FlxVirtualPad;
    public function new()
    {
        super();

        opacityValue = Options.getData("mobileCAlpha");

        var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        bg.alpha = 0;
        bg.scrollFactor.set();
        add(bg);

        FlxTween.tween(bg, {alpha: 0.5}, 1, {ease: FlxEase.circOut});

        offsetText.text = "Opacity: " + opacityValue;
        offsetText.screenCenter();
        add(offsetText);

        
        vpad = new FlxVirtualPad(LEFT_RIGHT, A);
        add(vpad);
        vpad.scrollFactor.set();

    }

     override function update(elapsed:Float)
    {
        super.update(elapsed);

        var leftP = controls.LEFT_P;
        var rightP = controls.RIGHT_P;
        var back = controls.BACK;

        // VIRTUALPAD INPUT
        if (vpad.buttonLeft.justPressed)
            leftP = true;

        if (vpad.buttonRight.justPressed)
            rightP = true;

        if (vpad.buttonA.justPressed)
            back = true;

        // GAMEPAD
        var gp = FlxG.gamepads.lastActive;
        if (gp != null)
        {
            if (gp.anyJustPressed([FlxGamepadInputID.DPAD_LEFT, FlxGamepadInputID.LEFT_STICK_DIGITAL_LEFT]))
                leftP = true;

            if (gp.anyJustPressed([FlxGamepadInputID.DPAD_RIGHT, FlxGamepadInputID.LEFT_STICK_DIGITAL_RIGHT]))
                rightP = true;

            if (gp.anyJustPressed([FlxGamepadInputID.A, FlxGamepadInputID.B, FlxGamepadInputID.START]))
                back = true;
        }

        if (back)
        {
            Options.setData(opacityValue, "mobileCAlpha");
            states.OptionsMenu.instance.closeSubState();
            return;
        }

        if (leftP)  opacityValue -= 0.1;
        if (rightP) opacityValue += 0.1;

        opacityValue = FlxMath.roundDecimal(opacityValue, 1);
        opacityValue = Math.max(0, Math.min(1, opacityValue));

        offsetText.text = "Opacity: " + opacityValue;
        offsetText.screenCenter();
    }
}
