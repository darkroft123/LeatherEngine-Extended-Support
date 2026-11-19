package substates;

import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.FlxG;

class ConfirmSubstate extends MusicBeatSubstate
{
	var yesText:FlxText;
	var noText:FlxText;

	var bg:FlxSprite;
	var onYes:Void->Void;
	var acceptDelay:Float = 0;
	var curSelected:Int = 0; // 0 = YES, 1 = NO

	public function new(message:String, onYes:Void->Void, bodyText:String = "")
	{
		FlxG.mouse.visible = true;
		super();

		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0;
		bg.scrollFactor.set();
		add(bg);

		FlxTween.tween(bg, {alpha: 0.85}, 0.5, {ease: FlxEase.circOut});

		var isLong = (bodyText.length > 120 || bodyText.indexOf("\n\n") != -1);

		var titleY:Float = isLong ? (FlxG.height * 0.10) : (FlxG.height * 0.25);
		var titleSize:Int = isLong ? 36 : 48;

		var title = new FlxText(0, titleY, FlxG.width, message);
		title.setFormat(Paths.font("vcr.ttf"), titleSize, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		title.borderSize = 2;
		add(title);

		if (bodyText != "") {
			var bodySize:Int = isLong ? 20 : 32;
			var bodyY:Float = title.y + title.height + (isLong ? 15 : 30);
			var body = new FlxText(0, bodyY, FlxG.width * (isLong ? 0.88 : 0.9), bodyText);
			body.setFormat(Paths.font("vcr.ttf"), bodySize, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			body.borderSize = 1.5;
			body.screenCenter(X);
			add(body);
		}

		var btnY:Float = isLong ? (FlxG.height * 0.80) : (FlxG.height * 0.7);

		yesText = new FlxText(0, btnY, 0, "YES");
		yesText.setFormat(Paths.font("vcr.ttf"), 48, FlxColor.LIME, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		yesText.borderSize = 2;
		yesText.screenCenter(X);
		yesText.x -= 150;
		add(yesText);

		noText = new FlxText(0, btnY, 0, "NO");
		noText.setFormat(Paths.font("vcr.ttf"), 48, FlxColor.RED, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		noText.borderSize = 2;
		noText.screenCenter(X);
		noText.x += 150;
		add(noText);

		this.onYes = onYes;
		updateButtonVisuals();
	}

	function updateButtonVisuals():Void
	{
		yesText.alpha = (curSelected == 0) ? 1.0 : 0.5;
		noText.alpha = (curSelected == 1) ? 1.0 : 0.5;
		yesText.scale.set((curSelected == 0) ? 1.15 : 1.0, (curSelected == 0) ? 1.15 : 1.0);
		noText.scale.set((curSelected == 1) ? 1.15 : 1.0, (curSelected == 1) ? 1.15 : 1.0);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		acceptDelay += elapsed;
		if (acceptDelay < 0.1) return;

		// Mouse hover detection
		if (FlxG.mouse.overlaps(yesText))
		{
			if (curSelected != 0) {
				curSelected = 0;
				updateButtonVisuals();
			}
		}
		else if (FlxG.mouse.overlaps(noText))
		{
			if (curSelected != 1) {
				curSelected = 1;
				updateButtonVisuals();
			}
		}

		// Keyboard / Gamepad navigation
		if (controls.LEFT_P || FlxG.keys.justPressed.LEFT || FlxG.keys.justPressed.A)
		{
			curSelected = 0;
			updateButtonVisuals();
		}
		else if (controls.RIGHT_P || FlxG.keys.justPressed.RIGHT || FlxG.keys.justPressed.D)
		{
			curSelected = 1;
			updateButtonVisuals();
		}

		// Accept / Confirm via Keyboard
		if (controls.ACCEPT || FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE)
		{
			if (curSelected == 0)
			{
				if (onYes != null) onYes();
				close();
			}
			else
			{
				close();
			}
			return;
		}

		// Mouse click
		if (FlxG.mouse.justPressed)
		{
			if (FlxG.mouse.overlaps(yesText))
			{
				if (onYes != null) onYes();
				close();
			}
			else if (FlxG.mouse.overlaps(noText))
			{
				close();
			}
			return;
		}

		if (controls.BACK || FlxG.keys.justPressed.ESCAPE)
			close();
	}

	override public function destroy() {
		flixel.tweens.FlxTween.cancelTweensOf(bg);
		super.destroy();
	}
}
