package substates;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.group.FlxSpriteGroup;

typedef DialogOption = {
	var label:String;
	@:optional var callback:Void->Void;
	@:optional var color:Null<FlxColor>;
	@:optional var selectedColor:Null<FlxColor>;
}

class CustomDialogSubstate extends MusicBeatSubstate
{
	var uiCamera:FlxCamera;
	var bg:FlxSprite;
	var mainGroup:FlxSpriteGroup;
	var panelBox:FlxSprite;
	var outerBorder:FlxSprite;
	var innerBorder:FlxSprite;

	var titleText:FlxText;
	var subtitleText:FlxText;

	var optionTexts:Array<FlxText> = [];
	var optionHighlights:Array<FlxSprite> = [];
	var optionData:Array<DialogOption> = [];
	var curSelected:Int = 0;
	var acceptDelay:Float = 0;
	var isClosing:Bool = false;

	var fontPath:String = "Ethnocentric-Regular.otf";

	public function new(
		title:String,
		subtitle:String = "",
		options:Array<DialogOption> = null,
		defaultSelected:Int = 0
	)
	{
		super();

		uiCamera = new FlxCamera();
		uiCamera.bgColor.alpha = 0;
		FlxG.cameras.add(uiCamera, false);
		cameras = [uiCamera];

		FlxG.mouse.visible = true;

		if (options == null || options.length == 0)
		{
			options = [
				{label: "OK", callback: null}
			];
		}
		this.optionData = options;

		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0;
		add(bg);

		mainGroup = new FlxSpriteGroup();
		add(mainGroup);

		var optionHeight = 50;
		var optionsTotalHeight = optionData.length * optionHeight;
		var hasSubtitle = (subtitle != null && subtitle.trim() != "");

		var panelW:Int = 640;
		var panelH:Int = Std.int(130 + (hasSubtitle ? 45 : 0) + optionsTotalHeight);
		if (panelW > FlxG.width - 80) panelW = FlxG.width - 80;

		var panelX:Float = (FlxG.width - panelW) / 2;
		var panelY:Float = (FlxG.height - panelH) / 2;

		makeBox(panelX, panelY, panelW, panelH);

		var titleY = panelY + 25;
		titleText = new FlxText(panelX, titleY, panelW, title);
		titleText.setFormat(Paths.font(fontPath), 32, 0xFF00FFD2, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		titleText.borderSize = 2.5;
		mainGroup.add(titleText);

		var currentY = titleY + titleText.height + 10;

		if (hasSubtitle)
		{
			subtitleText = new FlxText(panelX + 20, currentY, panelW - 40, subtitle);
			subtitleText.setFormat(Paths.font(fontPath), 18, 0xFFFFB800, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			subtitleText.borderSize = 1.5;
			mainGroup.add(subtitleText);
			currentY += subtitleText.height + 20;
		}
		else
		{
			currentY += 15;
		}

		for (i in 0...optionData.length)
		{
			var opt = optionData[i];

			var highlight = new FlxSprite(panelX + 30, currentY + (i * optionHeight) - 4).makeGraphic(panelW - 60, 42, 0xFF00FFD2);
			highlight.alpha = 0.15;
			highlight.visible = false;
			mainGroup.add(highlight);
			optionHighlights.push(highlight);

			var txt = new FlxText(panelX, currentY + (i * optionHeight), panelW, opt.label);
			txt.setFormat(Paths.font(fontPath), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			txt.borderSize = 2;
			mainGroup.add(txt);
			optionTexts.push(txt);
		}

		mainGroup.y = 30;
		mainGroup.alpha = 0;
		FlxTween.tween(bg, {alpha: 0.85}, 0.3, {ease: FlxEase.quartOut});
		FlxTween.tween(mainGroup, {y: 0, alpha: 1}, 0.4, {ease: FlxEase.backOut});

		changeSelection(defaultSelected);
	}

	function makeBox(x:Float, y:Float, w:Int, h:Int):Void
	{
		outerBorder = new FlxSprite(x - 3, y - 3).makeGraphic(w + 6, h + 6, 0xFF00FFD2);
		outerBorder.alpha = 0.3;
		mainGroup.add(outerBorder);

		innerBorder = new FlxSprite(x - 1, y - 1).makeGraphic(w + 2, h + 2, 0xFF120024);
		innerBorder.alpha = 0.8;
		mainGroup.add(innerBorder);

		panelBox = new FlxSprite(x, y).makeGraphic(w, h, 0xFF0A0A10);
		panelBox.alpha = 0.9;
		mainGroup.add(panelBox);
	}

	public function changeSelection(change:Int = 0):Void
	{
		if (isClosing) return;

		curSelected += change;
		if (curSelected < 0)
			curSelected = optionTexts.length - 1;
		else if (curSelected >= optionTexts.length)
			curSelected = 0;

		for (i in 0...optionTexts.length)
		{
			var isSelected = (i == curSelected);
			var opt = optionData[i];
			var normalCol = opt.color != null ? opt.color : FlxColor.WHITE;
			var selCol = opt.selectedColor != null ? opt.selectedColor : 0xFF00FFD2;

			optionTexts[i].color = isSelected ? selCol : normalCol;
			optionTexts[i].scale.set(isSelected ? 1.08 : 1.0, isSelected ? 1.08 : 1.0);
			optionHighlights[i].visible = isSelected;
		}

		if (change != 0)
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (isClosing) return;

		acceptDelay += elapsed;

		if (controls.UP_P)
			changeSelection(-1);
		if (controls.DOWN_P)
			changeSelection(1);

		for (i in 0...optionTexts.length)
		{
			if (FlxG.mouse.overlaps(optionTexts[i]))
			{
				if (curSelected != i)
					changeSelection(i - curSelected);

				if (FlxG.mouse.justPressed && acceptDelay > 0.1)
				{
					selectOption(i);
					return;
				}
			}
		}

		if (controls.ACCEPT && acceptDelay > 0.1)
		{
			selectOption(curSelected);
		}
		else if (controls.BACK && acceptDelay > 0.1)
		{
			var cancelIndex = -1;
			for (i in 0...optionData.length)
			{
				var labelLower = optionData[i].label.toLowerCase();
				if (labelLower == "cancel" || labelLower == "back" || labelLower == "no")
				{
					cancelIndex = i;
					break;
				}
			}
			if (cancelIndex >= 0)
				selectOption(cancelIndex);
			else
				closeWithTween(null);
		}
	}

	function selectOption(index:Int):Void
	{
		if (index < 0 || index >= optionData.length) return;
		var opt = optionData[index];
		closeWithTween(opt.callback);
	}

	function closeWithTween(onCompleteAction:Void->Void):Void
	{
		if (isClosing) return;
		isClosing = true;

		FlxTween.tween(bg, {alpha: 0}, 0.25, {ease: FlxEase.quartIn});
		FlxTween.tween(mainGroup, {y: 20, alpha: 0}, 0.25, {
			ease: FlxEase.quartIn,
			onComplete: function(t:FlxTween) {
				close();
				if (onCompleteAction != null)
					onCompleteAction();
			}
		});
	}

	override function destroy()
	{
		if (uiCamera != null)
		{
			if (FlxG.cameras != null && FlxG.cameras.list.contains(uiCamera))
			{
				FlxG.cameras.remove(uiCamera, true);
			}
			uiCamera = null;
		}
		super.destroy();
	}
}
