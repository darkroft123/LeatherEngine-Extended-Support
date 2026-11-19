package ui;

import game.Cutscene;
import game.Cutscene.DialogueSection;
import flixel.sound.FlxSound;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.text.FlxTypeText;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.util.FlxSignal;
import flixel.tweens.FlxTween;
import lime.utils.Assets;
import flixel.math.FlxMath;


class DialogueBox extends FlxSpriteGroup
{
	public var cutsceneData:Cutscene;
	public var current_Section:DialogueSection;
	public var sectionIndex:Int = 0;

	public var box:FlxSprite;
	public var boxLeft:FlxSprite;
	public var boxRight:FlxSprite;
	var activeBox:FlxSprite = null;
	public var rightPortrait:DialoguePortrait;
	public var leftPortrait:DialoguePortrait;

	public var dialogue:FlxTypeText;
	public var dialogueShadow:FlxText;

	public var alphabet:Alphabet;

	public var exiting:Bool = false;
	public var starting:Bool = true;

	public var bgFade:FlxSprite;

	public var hand:FlxSprite;

	public var music:FlxSound;

	public var onDialogueFinish:FlxSignal;

	var animating:Bool = false;
	var lerpSpeed:Float = 0.015;

	var animatedObjects:Array<FlxSprite> = [];
	var targetPos:Map<FlxSprite, Float> = new Map();
	var textDone:Bool = false;

	public function new(cutscene:Cutscene)
	{
		cutsceneData = cutscene;
		super();

		onDialogueFinish = new FlxSignal();

		if (cutsceneData.introSound != null)
			FlxG.sound.play(Paths.sound(cutsceneData.introSound, "shared"));

		if (cutsceneData.bgFade != false)
		{
			var color:FlxColor = FlxColor.WHITE;

			if (cutsceneData.bgColor != null)
				color = FlxColor.fromString(cutsceneData.bgColor);

			bgFade = new FlxSprite(-200, -200).makeGraphic(
				Std.int(FlxG.width * 1.3),
				Std.int(FlxG.height * 1.3),
				color
			);

			bgFade.scrollFactor.set();
			bgFade.alpha = 0;
			add(bgFade);

			var fadeTime:Float = 0.8;
			if (cutsceneData.bgFadeTime != null)
				fadeTime = cutsceneData.bgFadeTime;

			FlxTween.tween(bgFade, { alpha: 0.7 }, fadeTime);
		}

		loadAssets();

		if (cutsceneData.dialogueMusic != null)
		{
			music = FlxG.sound.load(Paths.music(cutsceneData.dialogueMusic, "shared"), 1, true);
			music.play();
			music.fadeIn(1, 0, 0.8);
		}
	}

	function registerLerp(obj:FlxSprite, fromX:Float, toX:Float)
	{
		if (obj == null) return;

		if (!cutsceneData.animations)
		{
			obj.x = toX;
			obj.alpha = 1;
			return;
		}

		obj.x = fromX;
		obj.alpha = 0;

		animatedObjects.push(obj);
		targetPos.set(obj, toX);
		animating = true;
	}


	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (dialogueShadow != null && dialogue != null)
			dialogueShadow.text = dialogue.text;

		if (animating)
		{
			var done = true;

			for (obj in animatedObjects)
			{
				var tx = targetPos.get(obj);
				obj.x = FlxMath.lerp(obj.x, tx, lerpSpeed);
				obj.alpha = FlxMath.lerp(obj.alpha, 1, lerpSpeed);

				if (Math.abs(obj.x - tx) > 1)
					done = false;
			}

			if (done)
			{
				for (obj in animatedObjects)
				{
					obj.x = targetPos.get(obj);
					obj.alpha = 1;
				}
				animating = false;
			}
		}

		if (FlxG.keys.justPressed.ENTER && !animating)
		{
			if (dialogue != null && !textDone)
			{
				dialogue.skip();
				textDone = true;
			}

			var clickPath = Paths.sound('clickText');

			if (Assets.exists(clickPath))
			{
				FlxG.sound.play(clickPath, 0.8);
			}


			sectionIndex++;

			if (sectionIndex < cutsceneData.dialogueSections.length)
			{
				loadAssets();
			}
			else if (!exiting)
			{
				exiting = true;

				if (music != null)
					music.fadeOut(2.2, 0, function(_) {
						if (music != null)
							music.stop();
					});

				new FlxTimer().start(0.2, function(tmr:FlxTimer)
				{
					var step = 1 / 5;

					if (leftPortrait != null) leftPortrait.alpha -= step;
					if (rightPortrait != null) rightPortrait.alpha -= step;

					if (box != null) box.alpha -= step;
					if (boxLeft != null) boxLeft.alpha -= step;
					if (boxRight != null) boxRight.alpha -= step;

					if (bgFade != null) bgFade.alpha -= step * 0.7;

					if (dialogue != null) dialogue.alpha -= step;
					if (dialogueShadow != null) dialogueShadow.alpha = dialogue.alpha;
					if (alphabet != null) alphabet.alpha -= step;
					if (hand != null) hand.alpha -= step;
				}, 5);

				new FlxTimer().start(1.2, function(tmr:FlxTimer)
				{
					onDialogueFinish.dispatch();
				});
			}
		}
	

}

	private function createBox(path:String):FlxSprite
	{
		var b:FlxSprite;

		if (Assets.exists(Paths.image("cutscenes/" + path, "shared")))
		{
			b = new FlxSprite();
			b.loadGraphic(Paths.gpuBitmap("cutscenes/" + path, "shared"));
		}
		else
		{
			b = new FlxSprite();
			b.frames = Paths.getSparrowAtlas("cutscenes/" + path, "shared");
		}

		b.scrollFactor.set(0, 0);
		b.updateHitbox();
		add(b);
		return b;
	}
	public function loadAssets(?new_Cutscene:Cutscene)
	{
		animatedObjects.resize(0);
		targetPos.clear();

		current_Section = cutsceneData.dialogueSections[sectionIndex];

		if (dialogueShadow != null)
		{
			remove(dialogueShadow);
			dialogueShadow.destroy();
			dialogueShadow = null;
		}

		if (dialogue != null)
		{
			remove(dialogue);
			dialogue.destroy();
			dialogue = null;
		}

		if (alphabet != null)
		{
			remove(alphabet);
			alphabet.destroy();
			alphabet = null;
		}

		if (Assets.exists(Paths.image("cutscenes/" + cutsceneData.dialogueBox, "shared")))
		{
			box = new FlxSprite();
			box.loadGraphic(Paths.gpuBitmap("cutscenes/" + cutsceneData.dialogueBox, "shared"));
		}
		else
		{
			box = new FlxSprite();
			box.frames = Paths.getSparrowAtlas("cutscenes/" + cutsceneData.dialogueBox, "shared");
		}

		box.scrollFactor.set(0, 0);
		box.setGraphicSize(box.width * (cutsceneData.dialogueBoxSize != null ? cutsceneData.dialogueBoxSize : 1));
		box.updateHitbox();
		box.screenCenter(X);
		box.y = FlxG.height - box.height;

		if (current_Section.side == "left" && current_Section.dialogueBoxLeft != null)
		{
			if (boxLeft == null)
				boxLeft = createBox(current_Section.dialogueBoxLeft);

			activeBox = boxLeft;
			boxLeft.visible = true;
			if (boxRight != null) boxRight.visible = false;

			if (current_Section.box_OffsetLeft != null)
			{
				boxLeft.x = current_Section.box_OffsetLeft[0];
				boxLeft.y = current_Section.box_OffsetLeft[1];
			}

			registerLerp(boxLeft, boxLeft.x -125, boxLeft.x);
		}
		else if (current_Section.side == "right" && current_Section.dialogueBoxRight != null)
		{
			if (boxRight == null)
				boxRight = createBox(current_Section.dialogueBoxRight);

			activeBox = boxRight;
			boxRight.visible = true;
			if (boxLeft != null) boxLeft.visible = false;

			if (current_Section.box_OffsetRight != null)
			{
				boxRight.x = current_Section.box_OffsetRight[0];
				boxRight.y = current_Section.box_OffsetRight[1];
			}

			registerLerp(boxRight, boxRight.x +125, boxRight.x);
		}
		else
		{
			activeBox = box;
			box.visible = true;
			if (boxLeft != null) boxLeft.visible = false;
			if (boxRight != null) boxRight.visible = false;

			registerLerp(box, box.x, box.x);
		}

		if (current_Section.leftPortrait != null)
		{
			if (leftPortrait == null)
			{
				leftPortrait = new DialoguePortrait();
				add(leftPortrait);
			}

			leftPortrait.loadPortrait(current_Section.leftPortrait);
			leftPortrait.visible = true;
			leftPortrait.alpha = 0;
			leftPortrait.x = current_Section.leftPortrait.x;
			leftPortrait.y = current_Section.leftPortrait.y;

			registerLerp(leftPortrait, leftPortrait.x -125, leftPortrait.x);
		}
		else if (leftPortrait != null)
		{
			leftPortrait.visible = false;
		}

		if (current_Section.rightPortrait != null)
		{
			if (rightPortrait == null)
			{
				rightPortrait = new DialoguePortrait();
				add(rightPortrait);
			}

			rightPortrait.loadPortrait(current_Section.rightPortrait);
			rightPortrait.visible = true;
			rightPortrait.alpha = 0;
			rightPortrait.x = current_Section.rightPortrait.x;
			rightPortrait.y = current_Section.rightPortrait.y;

			registerLerp(rightPortrait, rightPortrait.x +125, rightPortrait.x);
		}
		else if (rightPortrait != null)
		{
			rightPortrait.visible = false;
		}

		add(activeBox);

		var alignment:String = current_Section.dialogue.alignment != null ? current_Section.dialogue.alignment : "center";
		var textOffset:Array<Float> = current_Section.dialogue.offset ?? [0, 0];

		var baseTextX = activeBox.x + activeBox.width * 0.5;
		var baseTextY = activeBox.y + activeBox.height * 0.5;

		if (!current_Section.dialogue.alphabet)
		{
			if (current_Section.dialogue.hasShadow)
			{
				dialogueShadow = new FlxText(
					baseTextX + textOffset[0] + current_Section.dialogue.shadowOffset,
					baseTextY + textOffset[1] + current_Section.dialogue.shadowOffset,
					current_Section.dialogue.textWidth != null ? current_Section.dialogue.textWidth : Std.int(activeBox.width * 0.8),
					"",
					current_Section.dialogue.size
				);

				dialogueShadow.font = Paths.font(current_Section.dialogue.font);
				dialogueShadow.color = FlxColor.fromString(current_Section.dialogue.shadowColor);
				dialogueShadow.alignment = alignment;
				dialogueShadow.x -= dialogueShadow.width * 0.5;
				dialogueShadow.y -= dialogueShadow.height * 0.5;

				add(dialogueShadow);
			}

			dialogue = new FlxTypeText(
				baseTextX + textOffset[0],
				baseTextY + textOffset[1],
				current_Section.dialogue.textWidth != null ? current_Section.dialogue.textWidth : Std.int(activeBox.width * 0.8),
				"",
				current_Section.dialogue.size
			);

			dialogue.font = Paths.font(current_Section.dialogue.font);
			dialogue.color = FlxColor.fromString(current_Section.dialogue.color);
			dialogue.alignment = alignment;
			dialogue.x -= dialogue.width * 0.5;
			dialogue.y -= dialogue.height * 0.5;

			if (current_Section.dialogue.sound != null)
			{
				dialogue.sounds = [
					FlxG.sound.load(Paths.sound(current_Section.dialogue.sound, "shared"), 0.6)
				];
			}

			dialogue.resetText(current_Section.dialogue.text);
			dialogue.start(current_Section.dialogue.text_Delay != null ? current_Section.dialogue.text_Delay : 0.04, true);
			textDone = false;

			add(dialogue);

			if (cutsceneData.animations)
			{
				var fromX = dialogue.x + (current_Section.side == "left" ? -100 : 100);
				registerLerp(dialogue, fromX, dialogue.x);

				if (dialogueShadow != null)
					registerLerp(dialogueShadow, fromX, dialogueShadow.x);
			}

		}
		else
		{
			alphabet = new Alphabet(
				baseTextX + textOffset[0],
				baseTextY + textOffset[1],
				current_Section.dialogue.text,
				current_Section.dialogue.bold,
				true
			);

			alphabet.x -= alphabet.width * 0.5;
			alphabet.y -= alphabet.height * 0.5;

			add(alphabet);

			if (cutsceneData.animations)
			{
				var fromX = alphabet.x + (current_Section.side == "left" ? -100 : 100);
				registerLerp(alphabet, fromX, alphabet.x);
			}

		}
	}

	override public function destroy()
	{
		if (music != null)
		{
			music.stop();
			music.destroy();
			music = null;
		}

		if (onDialogueFinish != null)
		{
			onDialogueFinish.removeAll();
			onDialogueFinish = null;
		}

		animatedObjects.resize(0);
		targetPos.clear();

		super.destroy();
	}
}




class DialoguePortrait extends FlxSprite
{
	public var animated:Bool = false;
	public var animName:String = "";
	public var animFPS:Float = 24;

	public function new(x:Float = 0, y:Float = 0)
	{
		super(x, y);
		scrollFactor.set(0,0);
	}

	public function loadPortrait(data:DialogueObject)
	{
		animated = data.animated;
		animName = data.anim_Name;
		animFPS = data.fps != null ? data.fps : 24;

		if(animated)
		{
			frames = Paths.getSparrowAtlas("cutscenes/" + data.sprite, "shared");
			if(animName != null && animName != "")
				animation.addByPrefix("play", animName, animFPS, true);
			animation.play("play");
		}
		else
		{
			loadGraphic(Paths.gpuBitmap("cutscenes/" + data.sprite, "shared"));
		}
	}
}
