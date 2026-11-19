package game;

import game.SongLoader;

import openfl.utils.Assets;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.ui.FlxBar;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
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

		var suffix:String = (Options.getData("botplay") ? " (BOT)" : "") + (Options.getData("noDeath") ? " (NO DEATH)" : "");
		text = new FlxText(0, 0, 0, '${song.song} ~ $difficulty$suffix');
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

		var maxLen:Float = (FlxG.sound.music != null && FlxG.sound.music.length > 0) ? FlxG.sound.music.length : 1;
		bar = new FlxBar(0, bg.y + 4, LEFT_TO_RIGHT, Std.int(bg.width - 8), Std.int(bg.height - 8), this, "time", 0, maxLen);
		bar.numDivisions = divisions;
		bar.screenCenter(X);
		bar.scrollFactor.set();

		gradientEnabled = Options.getData("gradientTimeBar");

		if (gradientEnabled) {
			var bfColor = (PlayState.boyfriend != null) ? PlayState.boyfriend.barColor : flixel.util.FlxColor.BLUE;
			var dadColor = (PlayState.dad != null) ? PlayState.dad.barColor : flixel.util.FlxColor.RED;
			CoolUtil.applyBarGradient(bar, bfColor, dadColor);
		}
		else
			CoolUtil.applyBarFill(bar, barColorLeft, barColorRight);

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
						CoolUtil.applyBarGradient(bar, newLeft, newRight);
						FlxTween.tween(bar, { alpha: oldAlpha }, 0.15);
					}
				});
			} else {
				CoolUtil.applyBarGradient(bar, newLeft, newRight);
			}
		} else {
			if (useTween) {
				var oldAlpha = bar.alpha;
				FlxTween.tween(bar, { alpha: 0 }, 0.15, {
					onComplete: function(_) {
						CoolUtil.applyBarFill(bar, newLeft, newRight);
						FlxTween.tween(bar, { alpha: oldAlpha }, 0.15);
					}
				});
			} else {
				CoolUtil.applyBarFill(bar, newLeft, newRight);
			}
		}
	}

	override public function set_alpha(value:Float):Float {
		super.alpha = value;
		bg.alpha = value;
		bar.alpha = value;
		text.alpha = value;
		if (PlayState.instance != null && PlayState.instance.diedTxt != null) {
			PlayState.instance.diedTxt.alpha = text.alpha;
		}
		return value;
	}

	@:noCompletion
	inline private function set_barColorLeft(value:FlxColor):FlxColor {
		if (!gradientEnabled) CoolUtil.applyBarFill(bar, value, barColorRight);
		return barColorLeft = value;
	}

	@:noCompletion
	inline private function set_barColorRight(value:FlxColor):FlxColor {
		if (!gradientEnabled) CoolUtil.applyBarFill(bar, barColorLeft, value);
		return barColorRight = value;
	}

	@:noCompletion
	inline private function set_divisions(value:Int):Int {
		if (bar != null) bar.numDivisions = value;
		return divisions = value;
	}
}
