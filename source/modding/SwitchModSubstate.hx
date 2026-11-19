package modding;

import flixel.group.FlxSpriteContainer.FlxTypedSpriteContainer;
#if MODDING_ALLOWED
import substates.MusicBeatSubstate;
import modding.ModList;
import modding.PolymodHandler;
import ui.Option;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import utilities.Localization;

class SwitchModSubstate extends MusicBeatSubstate {
	var curSelected:Int = 0;
	var ui_Skin:Null<String>;

	public var page:FlxTypedSpriteContainer<ChangeModOption> = new FlxTypedSpriteContainer<ChangeModOption>();

	public static var instance:SwitchModSubstate;

	var descriptionText:FlxText;

	var bgOverlay:FlxSprite;
	var panelBg:FlxSprite;
	var panelBorder:FlxSprite;
	var highlightBar:FlxSprite;
	var highlightBorder:FlxSprite;

	override function create() {
		if (ui_Skin == null || ui_Skin == "default")
			ui_Skin = Options.getData("uiSkin");

		instance = this;

		bgOverlay = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF000000);
		bgOverlay.alpha = 0;
		bgOverlay.scrollFactor.set();
		add(bgOverlay);

		var panelX:Float = 240;
		var panelY:Float = 80;
		var panelW:Int = 800;
		var panelH:Int = 560;

		panelBg = new FlxSprite(panelX, panelY).makeGraphic(panelW, panelH, 0xFF0D0D20);
		panelBg.alpha = 0;
		panelBg.scrollFactor.set();
		add(panelBg);

		// We can emulate a border with 4 thin sprites or just draw it, but makeGraphic doesn't do borders out of the box nicely.
		// Wait, a slightly larger background behind it is an easy border.
		panelBorder = new FlxSprite(panelX - 2, panelY - 2).makeGraphic(panelW + 4, panelH + 4, 0xFF6C3FFF);
		panelBorder.alpha = 0;
		panelBorder.scrollFactor.set();
		insert(members.indexOf(panelBg), panelBorder);

		var titleStr = Localization.getString("switchmod_title", "SWITCH MOD");
		var titleText = new FlxText(panelX, panelY + 20, panelW, titleStr, 26);
		titleText.setFormat(Paths.font("Ethnocentric-Regular.otf"), 26, 0xFF9D7EFF, CENTER);
		titleText.alpha = 0;
		titleText.scrollFactor.set();
		add(titleText);

		var subStr = Localization.getString("switchmod_sub", "Select a mod to switch to and restart");
		var subText = new FlxText(panelX, panelY + 55, panelW, subStr, 13);
		subText.setFormat(Paths.font("vcr.ttf"), 13, 0xFF6B6B8A, CENTER);
		subText.alpha = 0;
		subText.scrollFactor.set();
		add(subText);

		var footerStr = Localization.getString("switchmod_footer", "ENTER to switch  |  ESC to cancel");
		var footerText = new FlxText(panelX, panelY + panelH - 30, panelW, footerStr, 13);
		footerText.setFormat(Paths.font("vcr.ttf"), 13, 0xFF6B6B8A, CENTER);
		footerText.alpha = 0;
		footerText.scrollFactor.set();
		add(footerText);

		highlightBar = new FlxSprite(panelX + 10, 0).makeGraphic(panelW - 20, 70, 0xFF1E1E3F);
		highlightBar.alpha = 0;
		highlightBar.scrollFactor.set();
		add(highlightBar);

		highlightBorder = new FlxSprite(panelX + 10, 0).makeGraphic(2, 70, 0xFF9D7EFF);
		highlightBorder.alpha = 0;
		highlightBorder.scrollFactor.set();
		add(highlightBorder);

		super.create();
		page.scrollFactor.set();
		add(page);

		PolymodHandler.loadModMetadata();
		loadMods();

		descriptionText = new FlxText(panelX, panelY + panelH - 60, panelW, "", 14);
		descriptionText.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.WHITE, CENTER);
		descriptionText.alpha = 0;
		descriptionText.scrollFactor.set();
		add(descriptionText);

		// Fade in animation
		FlxTween.tween(bgOverlay, {alpha: 0.88}, 0.3, {ease: FlxEase.quadOut});
		FlxTween.tween(panelBorder, {alpha: 1}, 0.3, {ease: FlxEase.quadOut});
		FlxTween.tween(panelBg, {alpha: 1}, 0.3, {ease: FlxEase.quadOut});
		FlxTween.tween(titleText, {alpha: 1}, 0.3, {ease: FlxEase.quadOut});
		FlxTween.tween(subText, {alpha: 1}, 0.3, {ease: FlxEase.quadOut});
		FlxTween.tween(footerText, {alpha: 1}, 0.3, {ease: FlxEase.quadOut});
		FlxTween.tween(highlightBar, {alpha: 1}, 0.3, {ease: FlxEase.quadOut});
		FlxTween.tween(highlightBorder, {alpha: 1}, 0.3, {ease: FlxEase.quadOut});
		FlxTween.tween(descriptionText, {alpha: 1}, 0.3, {ease: FlxEase.quadOut});
		
		for (x in page.members) {
			x.alpha = 0;
			FlxTween.tween(x, {alpha: 1}, 0.3, {ease: FlxEase.quadOut});
		}
	}

	function loadMods() {
		page.forEachExists(function(option:ChangeModOption) {
			page.remove(option);
			option.kill();
			option.destroy();
		});

		var optionLoopNum:Int = 0;

		for (modId in PolymodHandler.metadataArrays) {
			if (ModList.modList.get(modId) && ModList.modMetadatas.get(modId).metadata.get('canBeSwitchedTo') != 'false') {
				var modOption = new ChangeModOption(ModList.modMetadatas.get(modId).title, modId);
				page.add(modOption);
				optionLoopNum++;
			}
		}
	}

	override function update(elapsed:Float) {
		super.update(elapsed);

		if (-1 * Math.floor(FlxG.mouse.wheel) != 0) {
			curSelected -= 1 * Math.floor(FlxG.mouse.wheel);
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		}

		if (controls.UP_P) {
			curSelected--;
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		}

		if (controls.DOWN_P) {
			curSelected++;
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		}

		if (controls.BACK) {
			close();
		}

		if (curSelected < 0)
			curSelected = page.length - 1;

		if (curSelected >= page.length)
			curSelected = 0;

		var bruh = 0;

		for (x in page.members) {
			x.alphabetText.targetY = bruh - curSelected;

			if (x.alphabetText.targetY == 0) {
				highlightBar.y = x.alphabetText.y - 10;
				highlightBorder.y = highlightBar.y;

				@:privateAccess
				descriptionText.text = ModList.modMetadatas.get(x.optionValue).description + " | v"
					+ ModList.modMetadatas.get(x.optionValue).modVersion;
			}

			bruh++;
		}
	}
}
#end
