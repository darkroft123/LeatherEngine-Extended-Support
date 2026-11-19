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

		panelBg = new FlxSprite(panelX, panelY).makeGraphic(panelW, panelH, 0xFF161616);
		panelBg.alpha = 0;
		panelBg.scrollFactor.set();
		add(panelBg);

		panelBorder = new FlxSprite(panelX - 2, panelY - 2).makeGraphic(panelW + 4, panelH + 4, 0xFFFFFFFF);
		panelBorder.alpha = 0;
		panelBorder.scrollFactor.set();
		insert(members.indexOf(panelBg), panelBorder);

		var titleStr = Localization.getString("switchmod_title", "SWITCH MOD");
		var titleText = new FlxText(panelX, panelY + 18, panelW, titleStr, 30);
		titleText.setFormat(Paths.font("vcr.ttf"), 30, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE_FAST, FlxColor.BLACK);
		titleText.borderSize = 2;
		titleText.alpha = 0;
		titleText.scrollFactor.set();
		add(titleText);

		var subStr = Localization.getString("switchmod_sub", "Select a mod to switch to and restart");
		var subText = new FlxText(panelX, panelY + 54, panelW, subStr, 15);
		subText.setFormat(Paths.font("vcr.ttf"), 15, 0xFFCCCCCC, CENTER, FlxTextBorderStyle.OUTLINE_FAST, FlxColor.BLACK);
		subText.borderSize = 1;
		subText.alpha = 0;
		subText.scrollFactor.set();
		add(subText);

		var footerStr = Localization.getString("switchmod_footer", "ENTER to switch  |  ESC to cancel");
		var footerText = new FlxText(panelX, panelY + panelH - 30, panelW, footerStr, 15);
		footerText.setFormat(Paths.font("vcr.ttf"), 15, 0xFFCCCCCC, CENTER, FlxTextBorderStyle.OUTLINE_FAST, FlxColor.BLACK);
		footerText.borderSize = 1;
		footerText.alpha = 0;
		footerText.scrollFactor.set();
		add(footerText);

		highlightBar = new FlxSprite(panelX + 10, 0).makeGraphic(panelW - 20, 70, 0xFFFFFFFF);
		highlightBar.alpha = 0;
		highlightBar.scrollFactor.set();
		add(highlightBar);

		highlightBorder = new FlxSprite(panelX + 10, 0).makeGraphic(4, 70, 0xFFFFD700);
		highlightBorder.alpha = 0;
		highlightBorder.scrollFactor.set();
		add(highlightBorder);

		super.create();
		page.scrollFactor.set();
		add(page);

		PolymodHandler.loadModMetadata();
		loadMods();

		descriptionText = new FlxText(panelX, panelY + panelH - 62, panelW, "", 15);
		descriptionText.setFormat(Paths.font("vcr.ttf"), 15, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE_FAST, FlxColor.BLACK);
		descriptionText.borderSize = 1;
		descriptionText.alpha = 0;
		descriptionText.scrollFactor.set();
		add(descriptionText);

		// Fade in animation
		FlxTween.tween(bgOverlay, {alpha: 0.7}, 0.25, {ease: FlxEase.quadOut});
		FlxTween.tween(panelBorder, {alpha: 0.6}, 0.25, {ease: FlxEase.quadOut});
		FlxTween.tween(panelBg, {alpha: 0.95}, 0.25, {ease: FlxEase.quadOut});
		FlxTween.tween(titleText, {alpha: 1}, 0.25, {ease: FlxEase.quadOut});
		FlxTween.tween(subText, {alpha: 1}, 0.25, {ease: FlxEase.quadOut});
		FlxTween.tween(footerText, {alpha: 1}, 0.25, {ease: FlxEase.quadOut});
		FlxTween.tween(highlightBar, {alpha: 0.12}, 0.25, {ease: FlxEase.quadOut});
		FlxTween.tween(highlightBorder, {alpha: 0.9}, 0.25, {ease: FlxEase.quadOut});
		FlxTween.tween(descriptionText, {alpha: 1}, 0.25, {ease: FlxEase.quadOut});
		
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
