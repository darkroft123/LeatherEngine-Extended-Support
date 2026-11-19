package states;

import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import utilities.Options;
import flixel.FlxG;
import flixel.util.FlxColor;
import flixel.text.FlxText;

class FlashingLightsMenu extends MusicBeatState {
	var text:FlxText;

	override public function create() {
		super.create();

		text = new FlxText(0, 0, 0, "Hey! Leather Engine Extended Support has flashing lights\nPress Y to enable them, or anything else to not.\n(Any key closes this menu)",
			32);
		text.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER);
		text.screenCenter();
		text.setBorderStyle(OUTLINE, FlxColor.BLACK, 1.5, 1);
		add(text);
	}

	override function update(elapsed:Float) {
		super.update(elapsed);

		var acceptedY = FlxG.keys.justPressed.Y || (FlxG.gamepads.lastActive != null && FlxG.gamepads.lastActive.justPressed.Y);
		var pressedAny = FlxG.keys.justPressed.ANY || (FlxG.gamepads.lastActive != null && FlxG.gamepads.lastActive.justPressed.ANY);

		if (acceptedY)
			Options.setData(true, "flashingLights");
		else if (!acceptedY && pressedAny)
			Options.setData(false, "flashingLights");

		if (pressedAny) {
			FlxG.sound.play(Paths.sound("confirmMenu"));

			FlxTween.tween(text, {alpha: 0}, 1.0, {
				ease: FlxEase.cubeInOut,
				onComplete: (_) -> FlxG.switchState(() -> new TitleState())
			});
		}
	}
}
