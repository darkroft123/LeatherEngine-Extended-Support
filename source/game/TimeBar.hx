package game;

import openfl.utils.Assets;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.ui.FlxBar;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import game.SongLoader;
import states.PlayState;

class TimeBar extends FlxSpriteGroup {
	public var bg:FlxSprite = new FlxSprite();
	public var bar:FlxBar;
	public var text:FlxText;
	public var time:Float = 0;

	public var barColorLeft(default, set):FlxColor = FlxColor.BLACK;
	public var barColorRight(default, set):FlxColor = FlxColor.WHITE;
	public var divisions(default, set):Int = 400;
	public var gradientEnabled:Bool = false;

	override public function new(song:SongData, difficulty:String = "NORMAL") {
		super();

		text = new FlxText(0, 0, 0, '${song.song} ~ $difficulty${Options.getData("botplay") ? " (BOT)" : ""}');
		text.setFormat(Paths.font("vcr.ttf"), Options.getData("biggerInfoText") ? 20 : 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE_FAST, FlxColor.BLACK);
		text.screenCenter(X);
		text.scrollFactor.set();

		var healthBarPath:String = Assets.exists(Paths.image('ui skins/${song.ui_Skin}/other/healthBar'))
			? 'ui skins/${song.ui_Skin}/other/healthBar'
			: 'ui skins/default/other/healthBar';

		switch (Options.getData("timeBarStyle").toLowerCase()) {
			default:
				bg.loadGraphic(Paths.gpuBitmap(healthBarPath));
				text.y = bg.y = Options.getData("downscroll") ? FlxG.height - (bg.height + 1) : 1;

			case "psych engine":
				bg.makeGraphic(400, 19, FlxColor.BLACK);
				bg.y = Options.getData("downscroll") ? FlxG.height - 36 : 10;
				@:bypassAccessor divisions = 800;
				text.borderSize = Options.getData("biggerInfoText") ? 2 : 1.5;
				text.size = Options.getData("biggerInfoText") ? 32 : 20;
				text.y = bg.y - (text.height / 4);

			case "old kade engine":
				bg.loadGraphic(Paths.gpuBitmap(healthBarPath));
				@:bypassAccessor {
					barColorLeft = FlxColor.GRAY;
					barColorRight = FlxColor.LIME;
				}
				text.y = bg.y = Options.getData("downscroll") ? FlxG.height * 0.9 + 45 : 10;
		}

		bg.screenCenter(X);
		bg.scrollFactor.set();

		bar = new FlxBar(0, bg.y + 4, LEFT_TO_RIGHT, Std.int(bg.width - 8), Std.int(bg.height - 8), this, "time", 0, FlxG.sound.music.length);
		bar.numDivisions = divisions;
		bar.screenCenter(X);
		bar.scrollFactor.set();

		gradientEnabled = Options.getData("gradientTimeBar");

		if (gradientEnabled)
			bar.createGradientBar([FlxColor.TRANSPARENT], [PlayState.boyfriend.barColor, PlayState.dad.barColor]);
		else
			bar.createFilledBar(barColorLeft, barColorRight);

		add(bg);
		add(bar);
		add(text);
	}

	public function updateColorsDynamic(?useTween:Bool = true) {
		if (PlayState.instance == null) return;

		var newLeft = PlayState.boyfriend.barColor;
		var newRight = PlayState.dad.barColor;

		if (gradientEnabled && Options.getData("gradientTimeBar")) {
			if (useTween) {
				var oldAlpha = bar.alpha;
				FlxTween.tween(bar, { alpha: 0 }, 0.15, {
					onComplete: function(_) {
						bar.createGradientBar([FlxColor.TRANSPARENT], [newLeft, newRight]);
						FlxTween.tween(bar, { alpha: oldAlpha }, 0.15);
					}
				});
			} else {
				bar.createGradientBar([FlxColor.TRANSPARENT], [newLeft, newRight]);
			}
		} else {
			if (useTween) {
				var oldAlpha = bar.alpha;
				FlxTween.tween(bar, { alpha: 0 }, 0.15, {
					onComplete: function(_) {
						bar.createFilledBar(newLeft, newRight);
						FlxTween.tween(bar, { alpha: oldAlpha }, 0.15);
					}
				});
			} else {
				bar.createFilledBar(newLeft, newRight);
			}
		}
	}

	override public function set_alpha(value:Float):Float {
		super.alpha = value;
		bg.alpha = value;
		bar.alpha = value;
		text.alpha = value;
		return value;
	}

	@:noCompletion
	inline private function set_barColorLeft(value:FlxColor):FlxColor {
		if (!gradientEnabled) bar?.createFilledBar(value, barColorRight);
		return barColorLeft = value;
	}

	@:noCompletion
	inline private function set_barColorRight(value:FlxColor):FlxColor {
		if (!gradientEnabled) bar?.createFilledBar(barColorLeft, value);
		return barColorRight = value;
	}

	@:noCompletion
	inline private function set_divisions(value:Int):Int {
		if (bar != null) bar.numDivisions = value;
		return divisions = value;
	}
}
