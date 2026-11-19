package game;

import toolbox.CharacterCreator;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.effects.FlxTrail;
import flixel.util.FlxColor;
import flixel.util.FlxDestroyUtil;
import flxanimate.FlxAnimate;
import haxe.Json;
import lime.utils.Assets;
import modding.CharacterConfig;
import modding.scripts.languages.HScript;
import states.PlayState;
import flixel.math.FlxMatrix;
import flixel.FlxCamera;
import flixel.math.FlxRect;
import shaders.RTXShader;
import flixel.graphics.frames.FlxFrame.FlxFrameAngle;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.FlxBasic;
import flixel.math.FlxMath;
/**
 * The base character class.
 */
class Character extends ReflectedSprite {
	public static var configCache:Map<String, CharacterConfig> = new Map();
	public var animOffsets:Map<String, Array<Dynamic>> = new Map<String, Array<Dynamic>>();
	public var debugMode:Bool = false;

	public var isPlayer:Bool = false;
	public var curCharacter:String = 'bf';

	public var holdTimer:Float = 0;
	public var isHoldingNote:Bool = false;

	public var lastAnimContext:String = "none";
	public var lastHit:Float = Math.NEGATIVE_INFINITY;
	public var holdTime:Float = 4;
	public var __lockAnimThisFrame:Bool = false;

	public var animationNotes:Array<Dynamic> = [];

	public var dancesLeftAndRight:Bool = false;

	public var barColor:FlxColor = FlxColor.GREEN;
	public var positioningOffset:Array<Float> = [0, 0];
	public var cameraOffset:Array<Float> = [0, 0];
	public var isCharacterGroup(default, null):Bool = false;
	public var otherCharacters:Array<Character>;
	public var mainCharacterID:Int = 0;
	public var followMainCharacter:Bool = false;
	public var followAllCharacter:Bool = false;
	public var activeCharacterID:Int = 0;

	public var offsetsFlipWhenPlayer:Bool = true;
	public var offsetsFlipWhenEnemy:Bool = false;

	public var coolTrail:FlxTrail;

	public var deathCharacter:String = "bf-dead";

	public var swapLeftAndRightSingPlayer:Bool = true;

	public var icon:String;

	public var isDeathCharacter:Bool = false;

	public var config:CharacterConfig;

	public var singDuration:Float = 4.0;

	#if HSCRIPT_ALLOWED
	public var script:HScript;
	#end
	
	public var rtxShader(default, null):RTXShader;
	public var singAnimPrefix:String = 'sing';

	public var playFullAnim:Bool = false;
	public var preventDanceForAnim:Bool = false;
	public var ignoreDraw(default, null):Bool = false;
	public var scaleMult:Float = 1.0;
	
	public var lastHitStrumTime:Float = 0;
	public var justHitStrumTime:Float = -5000;
	public var offsetOffset:Array<Float> = [0,0];
	public var parent:FlxTypedGroup<FlxBasic>;
	public var graphicSize:Float = 1;
	//trails
	public var usingFlashColor:Bool = false;
	public var flashR:Float = 0;
	public var flashG:Float = 0;
	public var flashB:Float = 0;
	public var flashStrength:Float = 0;
	
	
	public function new(x:Float, y:Float, ?character:String = "bf", ?isPlayer:Bool = false, ?isDeathCharacter:Bool = false, scaleMult:Float = 1.0)
	{
		super(x, y);

		this.scaleMult = scaleMult;
		curCharacter = character;
		this.isPlayer = isPlayer;
		this.isDeathCharacter = isDeathCharacter;
		deathCharacter = "bf-dead";
		dancesLeftAndRight = false;

		var ilikeyacutg:Bool = false;
		switch (curCharacter.toLowerCase())
		{
			case '' | 'none' | 'empty' | 'nogf':
				ignoreDraw = true;

			default:
				if (isPlayer)
					flipX = !flipX;

				ilikeyacutg = true;
				loadNamedConfiguration(curCharacter);
		}

		if (isPlayer && !ilikeyacutg)
			flipX = !flipX;

		if (icon == null) {
			switch (curCharacter.toLowerCase()) {
				case '' | 'none' | 'empty' | 'nogf':
					icon = 'placeholder';
				default:
					icon = curCharacter;
			}
		}

		if (character != '')
			loadOffsetFile(curCharacter);

		if (curCharacter != '' && otherCharacters == null && hasAnims())
		{
			if (atlasMode)
			{
				atlas.updateHitbox();
				width = atlas.width;
				height = atlas.height;
				offset = atlas.offset;
				origin = atlas.origin;
			}
			else
			{
				updateHitbox();
			}

			if (!debugMode)
			{
				dance('');

				if (isPlayer && swapLeftAndRightSingPlayer && !isDeathCharacter)
				{
					try
					{
						var singRight = animation.getByName("singRIGHT");
						var singLeft = animation.getByName("singLEFT");

						if (singRight != null && singLeft != null)
						{
							var oldOffRight = animOffsets.get("singRIGHT");
							var oldOffLeft = animOffsets.get("singLEFT");

							var oldRight:Array<Int> = singRight.frames;
							singRight.frames = singLeft.frames;
							singLeft.frames = oldRight;

							animOffsets.set("singRIGHT", oldOffLeft);
							animOffsets.set("singLEFT", oldOffRight);
						}

						var singRightMiss = animation.getByName("singRIGHTmiss");
						var singLeftMiss = animation.getByName("singLEFTmiss");

						if (singRightMiss != null && singLeftMiss != null)
						{
							var oldOffRightMiss = animOffsets.get("singRIGHTmiss");
							var oldOffLeftMiss = animOffsets.get("singLEFTmiss");

							var oldMiss:Array<Int> = singRightMiss.frames;
							singRightMiss.frames = singLeftMiss.frames;
							singLeftMiss.frames = oldMiss;

							animOffsets.set("singRIGHTmiss", oldOffLeftMiss);
							animOffsets.set("singLEFTmiss", oldOffRightMiss);
						}
					}
					catch (e)
					{
						// trace(e, ERROR);
					}
				}
			}
		}
		else
		{
			visible = false;
		}

		#if HSCRIPT_ALLOWED
		var scriptPath = Paths.hx("data/character data/" + curCharacter + "/script");

		if (Assets.exists(scriptPath))
		{
			script?.call("createCharacterPost", [curCharacter]);
		}

		animation.onFinish.add((animName) -> {
			script?.call("onAnimationFinished", [animName]);
		});
		#end

		if (Options.getData("shaders"))
		{
			rtxShader = new RTXShader();
			shader = rtxShader;

			animation.onFrameChange.add((name, frameNumber, frameIndex) -> {
				rtxShader.rotated = frame.angle != 0;
			});
		}
	}

	public function loadNamedConfiguration(characterName:String)
	{
		var charDataPath = "character data/" + characterName;
		var psychJsonPath = Paths.json(charDataPath);
		var configJsonPath = Paths.json(charDataPath + "/config");
		var scriptPath = Paths.hx("data/character data/" + characterName + "/script");

		var hasPsychJson = Assets.exists(psychJsonPath);
		var hasConfigJson = Assets.exists(configJsonPath);

		if (!hasPsychJson)
		{
			if (!hasConfigJson)
			{
				curCharacter = characterName = isPlayer ? "bf" : "dad";

				charDataPath = "character data/" + characterName;
				configJsonPath = Paths.json(charDataPath + "/config");
				scriptPath = Paths.hx("data/character data/" + characterName + "/script");
			}

			#if HSCRIPT_ALLOWED
			if (FlxG.state is PlayState)
			{
				if (Assets.exists(scriptPath))
				{
					script = new HScript(scriptPath);
					script.interp.variables.set("character", this);
					PlayState.instance.scripts.set(characterName, script);
					script.call("createCharacter", [curCharacter]);
				}
			}
			#end

			var optimizedName = "optimized_" + characterName;
			var optimizedConfigPath = Paths.json("character data/" + optimizedName + "/config");

			if (Options.getData("optimizedChars") && Assets.exists(optimizedConfigPath))
			{
				characterName = optimizedName;
				configJsonPath = optimizedConfigPath;
			}

			if (configCache.exists(characterName)) {
				this.config = configCache.get(characterName);
			} else {
				this.config = cast Json.parse(Assets.getText(configJsonPath).trim());
				configCache.set(characterName, this.config);
			}
		}
		else
		{
			if (configCache.exists(characterName)) {
				this.config = configCache.get(characterName);
			} else {
				this.config = parsePsychCharacter(characterName);
				configCache.set(characterName, this.config);
			}
		}

		loadCharacterConfiguration(this.config);
	}
	public function parsePsychCharacter(characterName:String):CharacterConfig {
		var psychCharacter:PsychCharacterFile = cast Json.parse(Assets.getText(Paths.json("character data/" + characterName)).trim());
		var returnCharacter:CharacterConfig = cast {
			imagePath: psychCharacter.image.replace("characters/", ""),
			graphicSize: psychCharacter.scale,
			singDuration: psychCharacter.sing_duration,
			healthIcon: psychCharacter.healthicon,
			antialiasing: !psychCharacter.no_antialiasing,
			barColor: psychCharacter.healthbar_colors,
			defaultFlipX: psychCharacter.flip_x,
			positionOffset: psychCharacter.position,
			cameraOffset: psychCharacter.camera_position,
			offsetsFlipWhenPlayer: true,
			offsetsFlipWhenEnemy: false,
			animations: []
		};
		for (animation in psychCharacter.animations) {
			returnCharacter.animations.push(cast {
				name: animation.anim,
				animation_name: animation.name,
				fps: animation.fps,
				looped: animation.loop,
				indices: animation.indices
			});
			if (animation.anim.startsWith("dance")) {
				returnCharacter.dancesLeftAndRight = true;
			}
			addOffset(animation.anim, animation.offsets[0] ?? 0, animation.offsets[1] ?? 0);
		}
		return returnCharacter;
	}

	public var atlasMode:Bool = false;
	public var atlas:FlxAnimate;

		override public function draw():Void {
		if (ignoreDraw) {
			return;
		}
		if (atlasMode && atlas != null && visible) {
			atlas.cameras = cameras;
			atlas.scrollFactor.set(scrollFactor.x, scrollFactor.y);
			atlas.scale.set(scale.x, scale.y);
			atlas.offset.set(offset.x, offset.y);
			atlas.origin.set(origin.x, origin.y);
			atlas.x = x;
			atlas.y = y;
			atlas.angle = angle;
			atlas.alpha = alpha;
			atlas.visible = visible;
			atlas.flipX = flipX;
			atlas.flipY = flipY;
			atlas.shader = shader;
			atlas.antialiasing = antialiasing;
			atlas.color = color;
			atlas.colorTransform = colorTransform;
			atlas.blend = blend;
			atlas.draw();
		} else {
			super.draw();
		}
	}


	override function destroy()
	{
		if (otherCharacters != null)
		{
			for (char in otherCharacters)
			{
				if (char != null)
					char.destroy();
			}
			otherCharacters = null;
		}

		if (animOffsets != null)
		{
			animOffsets.clear();
			animOffsets = null;
		}

		if (animationNotes != null)
		{
			animationNotes = null;
		}

		#if HSCRIPT_ALLOWED
		if (script != null)
		{
			script.destroy();
			script = null;
		}
		#end

		FlxDestroyUtil.destroy(coolTrail);
		FlxDestroyUtil.destroy(atlas);
		rtxShader = null;
		super.destroy();
	}

	public function loadCharacterConfiguration(config:CharacterConfig)
	{
		if (config.characters == null || config.characters.length <= 1)
		{
			flipX = !isPlayer ? config.defaultFlipX : !config.defaultFlipX;

			if (Options.getData("dinnerbone"))
				flipY = !config.defaultFlipY;

			var isBF:Bool = curCharacter.contains("bf");

			if (config.offsetsFlipWhenPlayer == null)
				offsetsFlipWhenPlayer = !isBF;
			else
				offsetsFlipWhenPlayer = config.offsetsFlipWhenPlayer;

			if (config.offsetsFlipWhenEnemy == null)
				offsetsFlipWhenEnemy = isBF;
			else
				offsetsFlipWhenEnemy = config.offsetsFlipWhenEnemy;

			drawFlipped = (isPlayer && offsetsFlipWhenPlayer) || (!isPlayer && offsetsFlipWhenEnemy);

			dancesLeftAndRight = config.dancesLeftAndRight;

			var animJsonPath = Paths.file("images/characters/" + config.imagePath + "/Animation.json", TEXT);
			atlasMode = Assets.exists(animJsonPath);

			if (atlasMode)
			{
				atlas = new FlxAnimate(0.0, 0.0, Paths.getTextureAtlas("characters/" + config.imagePath, "shared"));
				atlas.showPivot = false;
			}
			else
			{
				frames = Paths.getAtlas(config.imagePath);
			}

			if (config.extraSheets != null && frames != null)
			{
				var atlasFrames:FlxAtlasFrames = cast frames;
				for (sheet in config.extraSheets)
				{
					atlasFrames.addAtlas(Paths.getAtlas(sheet));
				}
			}

			var size:Null<Float> = config.graphicSize;
			if (size == null)
				size = config.graphicsSize;

			if (size != null)
			{
				graphicSize = size;
				scale.set(size, size);
			}
			else
			{
				graphicSize = 1;
			}

			for (selected_animation in config.animations)
			{
				var hasIndices = selected_animation.indices != null && selected_animation.indices.length > 0;
				var isSingAnim = selected_animation.name.startsWith('sing');
				var shouldLoop = selected_animation.looped || isSingAnim;

				if (!atlasMode)
				{
					if (hasIndices)
					{
						animation.addByIndices(
							selected_animation.name,
							selected_animation.animation_name,
							selected_animation.indices,
							"",
							selected_animation.fps,
							shouldLoop
						);
					}
					else
					{
						animation.addByPrefix(
							selected_animation.name,
							selected_animation.animation_name,
							selected_animation.fps,
							shouldLoop
						);
					}
				}
				else
				{
					if (hasIndices)
					{
						atlas.anim.addBySymbolIndices(
							selected_animation.name,
							selected_animation.animation_name,
							selected_animation.indices,
							selected_animation.fps,
							shouldLoop
						);
					}
					else
					{
						atlas.anim.addBySymbol(
							selected_animation.name,
							selected_animation.animation_name,
							selected_animation.fps,
							shouldLoop
						);
					}
				}
			}

			if (isDeathCharacter)
				playAnim("firstDeath");
			else if (dancesLeftAndRight)
				playAnim("danceRight");
			else
				playAnim("idle");

			if (debugMode)
				flipX = config.defaultFlipX;

			if (config.antialiasing != null)
				antialiasing = config.antialiasing;
			else if (config.antialiased != null)
				antialiasing = config.antialiased;

			scale *= scaleMult;

			if (atlasMode)
			{
				atlas.updateHitbox();
				width = atlas.width;
				height = atlas.height;
				offset = atlas.offset;
				origin = atlas.origin;
			}
			else
			{
				updateHitbox();
			}

			if (config.positionOffset != null)
				positioningOffset = [config.positionOffset[0], config.positionOffset[1]];

			if (config.trail || FlxG.state is CharacterCreator)
			{
				coolTrail = new FlxTrail(this,null,config.trailLength ?? 10,config.trailDelay ?? 3,config.trailStalpha ?? 0.4,config.trailDiff ?? 0.05);
				coolTrail.cameras = this.cameras;
			}

			if (config.swapDirectionSingWhenPlayer != null)
				swapLeftAndRightSingPlayer = config.swapDirectionSingWhenPlayer;
			else if (isBF)
				swapLeftAndRightSingPlayer = false;

		if (config.singDuration != null)
			{
				singDuration = config.singDuration;
				holdTime = config.singDuration;
			}
		}
		else
		{
			otherCharacters = [];

			if (config.mainCharacterID != null)
				mainCharacterID = config.mainCharacterID;

			if (config.followAllCharacter != null)
				followAllCharacter = config.followAllCharacter;

			if (config.followMainCharacter != null)
				followMainCharacter = config.followMainCharacter;

			ignoreDraw = true;
			isCharacterGroup = true;

			for (characterData in config.characters)
			{
				var character:Character;

				if (!isPlayer)
					character = new Character(x, y, characterData.name, isPlayer, isDeathCharacter, scaleMult);
				else
					character = new Boyfriend(x, y, characterData.name, isDeathCharacter, scaleMult);

				var posX = characterData.positionOffset[0];
				var posY = characterData.positionOffset[1];

				if (flipX)
					posX = -posX * scaleMult;
				else
					posX *= scaleMult;

				posY *= scaleMult;

				character.zIndex = characterData.layer != null ? characterData.layer : 0;
				character.alpha = characterData.alpha != null ? characterData.alpha : 1;

				character.positioningOffset[0] += posX;
				character.positioningOffset[1] += posY;

				otherCharacters.push(character);
			}
		}

		if (config.barColor == null)
			config.barColor = [255, 0, 0];

		barColor = FlxColor.fromRGB(config.barColor[0], config.barColor[1], config.barColor[2]);

		var localKeyCount = 4;
		if (FlxG.state == PlayState.instance)
			localKeyCount = isPlayer ? PlayState.SONG.playerKeyCount : PlayState.SONG.keyCount;

		if (config.cameraOffset != null)
		{
			cameraOffset = [config.cameraOffset[0], config.cameraOffset[1]];

			if (flipX)
				cameraOffset[0] = -cameraOffset[0];
		}

		if (config.deathCharacter != null)
			deathCharacter = config.deathCharacter;
		else if (config.deathCharacterName != null)
			deathCharacter = config.deathCharacterName;
		else
			deathCharacter = "bf-dead";

		if (config.healthIcon != null)
		{
			if (Std.isOfType(config.healthIcon, Array))
			{
				var arr:Array<String> = cast config.healthIcon;
				if (arr.length > 0)
					icon = arr[0];
			}
			else
			{
				icon = cast config.healthIcon;
			}
		}
	}

	public function loadOffsetFile(characterName:String) {
		if (!Assets.exists(Paths.txt("character data/" + characterName + "/" + "offsets"))) {
			return;
		}

		var offsets:Array<String> = CoolUtil.coolTextFile(Paths.txt("character data/" + characterName + "/" + "offsets"));

		for (x in 0...offsets.length) {
			var selectedOffset = offsets[x];
			var arrayOffset:Array<String>;
			arrayOffset = selectedOffset.split(" ");

			addOffset(arrayOffset[0], Std.parseInt(arrayOffset[1]), Std.parseInt(arrayOffset[2]));
		}
	}

	public function quickAnimAdd(animName:String, animPrefix:String)
	{
		animation.addByPrefix(animName, animPrefix, 24, false);
	}

	public function tryDance() {
		#if HSCRIPT_ALLOWED
		script?.call("onTryDance", []);
		#end

		if (lastAnimContext == "sing" || lastAnimContext == "miss") {
			if (lastHit + (Conductor.stepCrochet * holdTime) < Conductor.songPosition)
				dance();
		} else if (lastAnimContext == "dance") {
			dance();
		} else if (lastAnimContext == "lock") {
			if (curAnimName() == null)
				dance();
		} else {
			if (curAnimName() == null || curAnimFinished())
				dance();
		}
	}

	public inline function updateHoldTimer(animName:String, elapsed:Float):Void
	{
		if (animName != null && animName.startsWith('sing'))
		{
			var songMult = (FlxG.state == PlayState.instance) ? PlayState.songMultiplier : 1.0;
			holdTimer += elapsed * songMult;
		}
		else
		{
			holdTimer = 0;
		}
	}

	public var shouldDance:Bool = true;
	public var forceAutoDance:Bool = false;

	override function update(elapsed:Float) {
	if (!debugMode && curCharacter != '' && hasAnims()) {
		var animName = curAnimName();
		var animFinished = curAnimFinished();

		if (playFullAnim && animFinished)
		{
			playFullAnim = false;
			dance('');
		}
		else if (preventDanceForAnim && animFinished)
		{
			preventDanceForAnim = false;
			dance('');
		}

		if (!__lockAnimThisFrame && lastAnimContext != "dance")
			tryDance();

		__lockAnimThisFrame = false;

		if (animName == 'hairFall' && animFinished)
			playAnim('danceRight');
	}

	if (atlasMode && atlas != null)
		atlas.update(elapsed);

	super.update(elapsed);

	if (flashStrength < 0.01)
		flashStrength = 0;

	if (flashStrength > 0)
		{
			usingFlashColor = true;

			setColorTransform(
				color.redFloat, color.greenFloat, color.blueFloat, alpha,
				flashR * flashStrength,
				flashG * flashStrength,
				flashB * flashStrength,
				0
			);

			flashStrength = FlxMath.lerp(flashStrength,0,elapsed*3);

			if (flashStrength < 0.01)
			{
				flashStrength = 0;
				usingFlashColor = false;

				setColorTransform(color.redFloat, color.greenFloat, color.blueFloat, alpha, 0, 0, 0, 0);
			}
		}
		else if (usingFlashColor)
		{
			usingFlashColor = false;
			setColorTransform(color.redFloat, color.greenFloat, color.blueFloat, alpha, 0, 0, 0, 0);
		}
	}

	public var danced:Bool = false;

	public var lastAnim:String = '';

	var mostRecentAlt:String = "";

    public var extraSuffix:String = "";

	public inline function curAnimLooped():Bool {
		@:privateAccess
		return (!atlasMode && animation != null && animation.curAnim != null && animation.curAnim.looped)
			|| (atlasMode && atlas != null && atlas.anim != null && atlas.anim.loopType == 0);
	}

	public inline function curAnimFinished():Bool {
		return (!atlasMode && animation != null && animation.curAnim != null && animation.curAnim.finished)
			|| (atlasMode && atlas != null && atlas.anim != null && atlas.anim.finished);
	}

	public function curAnimName():String {
		if (!atlasMode && animation != null && animation.curAnim != null) {
			return animation.curAnim.name;
		}

		if (atlasMode && atlas != null && atlas.anim != null) {
			return lastAnim;
		}

		return '';
	}

	public inline function hasAnim(name:String):Bool {
		return (!atlasMode && animation != null && animation.exists(name))
			|| (atlasMode && atlas != null && atlas.anim != null && atlas.anim.existsByName(name));
	}

	public inline function hasAnims():Bool {
		return (!atlasMode && animation != null && animation.curAnim != null)
			|| (atlasMode && atlas != null && atlas.anim != null);
	}

	/**
 * FOR GF DANCING SHIT
 */
public function dance(altAnim:String = '', force:Bool = false)
{
	#if HSCRIPT_ALLOWED
	script?.call("dance", [altAnim, force]);
	#end

	if (!shouldDance || (!atlasMode && animation == null))
		return;

	if (debugMode || curCharacter == '' || !hasAnims() || (!force && (playFullAnim || preventDanceForAnim)))
		return;

	var idleName = "idle" + altAnim;
	var danceLeftName = "danceLeft" + altAnim;
	var danceRightName = "danceRight" + altAnim;

	var alt:String = '';
	var canUseAlt = (!dancesLeftAndRight && hasAnim(idleName))
		|| (dancesLeftAndRight && hasAnim(danceLeftName) && hasAnim(danceRightName));

	if (canUseAlt)
		alt = altAnim;

	mostRecentAlt = alt;

	var animName = curAnimName();
	var alwaysPlayAnimation:Bool = animName.startsWith('idle')
		|| animName.startsWith('danceLeft')
		|| animName.startsWith('danceRight')
		|| animName.startsWith('sing');

	if (alwaysPlayAnimation || curAnimFinished() || curAnimLooped())
	{
		if (!dancesLeftAndRight)
		{
			playAnim('idle' + alt);
		}
		else
		{
			danced = !danced;
			if (danced)
				playAnim('danceRight' + alt);
			else
				playAnim('danceLeft' + alt);
		}
	}
}

inline function triggerColorFlash(r:Int, g:Int, b:Int, strength:Float = 1):Void
{
	flashR = r;
	flashG = g;
	flashB = b;
	flashStrength = strength;
}

public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0, ?strumTime:Float):Void
{
	lastAnim = AnimName;

	if (playFullAnim)
		return;

	if (singAnimPrefix != 'sing' && AnimName.contains('sing'))
	{
		var replacedAnim = AnimName.replace('sing', singAnimPrefix);
		if (hasAnim(replacedAnim))
			AnimName = replacedAnim;
	}

	AnimName += extraSuffix;

	var originalAnim = AnimName;
	var finalAnim = AnimName;

	var isMiss = originalAnim.contains("miss");
	var isDodge = originalAnim.contains("dodge");
	var isParry = originalAnim.contains("parry");
	var isAlt = originalAnim.contains("-alt");
	var isSpecialAnim = isMiss || isDodge || isParry || isAlt;

	preventDanceForAnim = false;

	var animExists = hasAnim(finalAnim);
	var usedFallback = false;

	if (!animExists && isSpecialAnim)
	{
		var fallbackAnim = isMiss
			? originalAnim.replace("miss", "")
			: originalAnim;

		if (isAlt)
			fallbackAnim = fallbackAnim.replace("-alt", "");

		if (!isMiss && !isAlt)
		{
			var key = isDodge ? "dodge" : "parry";
			var keyIndex = originalAnim.indexOf(key);

			if (keyIndex != -1)
				fallbackAnim = singAnimPrefix + originalAnim.substr(keyIndex + key.length);
		}

		if (hasAnim(fallbackAnim))
		{
			finalAnim = fallbackAnim;
			animExists = true;
			usedFallback = true;
			if (isMiss || isDodge || isParry)
				preventDanceForAnim = true;
		}
	}

	if (!animExists)
		return;

	if (usedFallback)
	{
		if (isMiss)
		{
			triggerColorFlash(56, 0, 69, 1);
		}
		else if (isDodge || isParry)
		{
			triggerColorFlash(config.barColor[0],config.barColor[1],config.barColor[2],1);
		}
	}

	if (strumTime != null)
		{
			justHitStrumTime = strumTime;
		}
		else
			justHitStrumTime = Conductor.songPosition;

		if (Options.getData("trails")) {
			if (animation.curAnim != null && animation.curAnim.name != "idle" && Math.abs(lastHitStrumTime - justHitStrumTime) < 10.0) {
				var actor = this;
				var Sprite:FlxSprite = new FlxSprite(actor.x, actor.y);
				Sprite.loadGraphicFromSprite(actor);
				
				Sprite.active = true; 
				if (actor.animation.curAnim != null) {
					var curAnim = actor.animation.curAnim;
					Sprite.animation.add(curAnim.name, curAnim.frames, curAnim.frameRate, curAnim.looped, curAnim.flipX, curAnim.flipY);
					Sprite.animation.play(curAnim.name, true, false, curAnim.curFrame);
				}
				
				Sprite.alpha = 0.8 * actor.alpha;
				Sprite.angle = actor.angle;
				Sprite.flipX = actor.flipX;
				Sprite.flipY = actor.flipY;
				Sprite.scale.set(actor.scale.x, actor.scale.y);
				Sprite.offset.set(actor.offset.x, actor.offset.y);
				Sprite.origin.set(actor.origin.x, actor.origin.y);
				Sprite.shader = rtxShader;
				Sprite.color = FlxColor.fromRGB(config.barColor[0],config.barColor[1],config.barColor[2]);
				Sprite.cameras = this.cameras;

				(this.parent != null ? this.parent : FlxG.state).insert(FlxG.state.members.indexOf(this)-1, Sprite);

				FlxTween.tween(Sprite, {alpha: 0}, Conductor.crochet * 0.001, {
					ease: FlxEase.expoIn,
					onComplete: function(twn:FlxTween) {
						Sprite.destroy();
					}
				});
			}
		}
		lastHitStrumTime = justHitStrumTime;

		if (finalAnim.contains("sing") || finalAnim.startsWith("sing")) {
			lastAnimContext = "sing";
			lastHit = Conductor.songPosition;
		}
		else if (finalAnim.contains("miss")) {
			lastAnimContext = "miss";
			lastHit = Conductor.songPosition;
		}
		else if (finalAnim == "idle" || finalAnim.startsWith("danceLeft") || finalAnim.startsWith("danceRight")) {
			lastAnimContext = "dance";
		}
		else {
			lastAnimContext = "lock";
		}

	if (atlasMode && atlas != null)
		atlas.anim.play(finalAnim, Force, Reversed, Frame);
	else
		animation.play(finalAnim, Force, Reversed, Frame);

	updateAnimOffsets();
}

public function updateAnimOffsets():Void
{
	var finalAnim:String = curAnimName() ?? "";

	var daOffset = animOffsets.get(finalAnim);
	var offsetX = offsetOffset[0];
	var offsetY = offsetOffset[1];

	if (daOffset != null)
	{
		var appliedX:Float = daOffset[0];
		var appliedY:Float = daOffset[1];

		if (drawFlipped)
			appliedX = -appliedX;

		offsetX += appliedX * Math.abs(scale.x);
		offsetY += appliedY * Math.abs(scale.y);
	}

	offset.set(offsetX, offsetY);
}
public function addOffset(name:String, x:Float = 0, y:Float = 0)
{
	animOffsets.set(name, [x, y]);
}

override function set_flipX(Value:Bool):Bool
{
	if (flipX != Value && !_drawingFlipped)
	{
		drawFlipped = !drawFlipped;
		var curAnim = curAnimName();
		if (curAnim != "")
			playAnim(curAnim, true);
	}
	return super.set_flipX(Value);
}

	public function getMainCharacter():Character {
		if (isCharacterGroup  && followMainCharacter) {
			return otherCharacters[mainCharacterID];
		}
		return this;
	}

	public function getCameraCharacter():Character {
			if (isCharacterGroup) {
				if (followAllCharacter)
					return otherCharacters[activeCharacterID];
				else if (followMainCharacter)
					return otherCharacters[mainCharacterID];
			}
			return this;
		}
}

typedef PsychCharacterFile = {
	var animations:Array<PsychAnimArray>;
	var image:String;
	var scale:Float;
	var sing_duration:Float;
	var healthicon:String;

	var position:Array<Float>;
	var camera_position:Array<Float>;

	var flip_x:Bool;
	var no_antialiasing:Bool;
	var healthbar_colors:Array<Int>;
	var vocals_file:String;
	@:optional var _editor_isPlayer:Null<Bool>;
}

typedef PsychAnimArray = {
	var anim:String;
	var name:String;
	var fps:Int;
	var loop:Bool;
	var indices:Array<Int>;
	var offsets:Array<Int>;
}

class ReflectedSprite extends FlxSprite
{
	@:noCompletion
	override function set_angle(Value:Float):Float
	{
		if (animation == null)
		{
			angle = Value;
			return Value;
		}
		return super.set_angle(Value);
	}

	override function destroy()
	{
		flixel.tweens.FlxTween.cancelTweensOf(this);
		if (PlayState.instance != null && PlayState.instance.tweenManager != null)
			PlayState.instance.tweenManager.cancelTweensOf(this);
		super.destroy();
	}

	public var drawFlipped:Bool = false;
	public var drawReflection:Bool = false;
	public var reflectionYOffset:Float = 0;
	public var reflectionAlpha:Float = 0.5;
	private var _drawingReflection:Bool = false;
	public var reflectionColor:FlxColor = 0xFF000000;
	public var reflectionScaleY:Float = 0.6;

	public var transform:FlxMatrix = new FlxMatrix();

	override public function draw():Void
	{
		if (drawReflection)
			drawReflectionSprite();

		if (drawFlipped)
			drawFlippedSprite();
		else
			super.draw();
	}

	private var _drawingFlipped:Bool = false;

	private function drawFlippedSprite():Void
	{
		_drawingFlipped = true;
		flipX = !flipX;
		scale.x = -scale.x;

		super.draw();

		flipX = !flipX;
		scale.x = -scale.x;
		_drawingFlipped = false;
	}

	private function drawReflectionSprite():Void
	{
		_drawingReflection = true;

		var oldX = x;
		var oldY = y;
		var oldAlpha = alpha;
		var oldColor = color;
		var oldScaleY = scale.y;
		var oldOffsetY = offset.y;

		color = reflectionColor;
		scale.y = -scale.y;
		offset.y = -offset.y;
		alpha *= reflectionAlpha;
		y += height + reflectionYOffset;
		

		transform.identity();

		super.draw();

		scale.y = oldScaleY;
		offset.y = oldOffsetY;
		alpha = oldAlpha;
		y = oldY;
		x = oldX;
		color = oldColor;

		_drawingReflection = false;
	}

	override function drawComplex(camera:FlxCamera):Void
	{
		_frame.prepareMatrix(_matrix, FlxFrameAngle.ANGLE_0, checkFlipX(), checkFlipY());

		_matrix.translate(-origin.x, -origin.y);
		_matrix.scale(scale.x, scale.y);

		if (_drawingReflection)
			_matrix.concat(transform);

		if (bakedRotationAngle <= 0)
		{
			updateTrig();

			if (angle != 0)
				_matrix.rotateWithTrig(_cosAngle, _sinAngle);
		}

		getScreenPosition(_point, camera).subtractPoint(offset);
		_point.add(origin.x, origin.y);
		_matrix.translate(_point.x, _point.y);

		if (isPixelPerfectRender(camera))
		{
			_matrix.tx = Math.floor(_matrix.tx);
			_matrix.ty = Math.floor(_matrix.ty);
		}

		camera.drawPixels(_frame, framePixels, _matrix, colorTransform, blend, antialiasing, shader);
	}

	override public function isOnScreen(?camera:FlxCamera):Bool
	{
		return super.isOnScreen(camera);
	}

	override public function getScreenBounds(?newRect:FlxRect, ?camera:FlxCamera):FlxRect
	{
		if (drawFlipped)
			return getFlippedScreenBounds(newRect, camera);

		if (_drawingReflection)
			return getReflectedScreenBounds(newRect, camera);

		return super.getScreenBounds(newRect, camera);
	}

	private  function getFlippedScreenBounds(?newRect:FlxRect, ?camera:FlxCamera):FlxRect
	{
		scale.x = -scale.x;
		var bounds = super.getScreenBounds(newRect, camera);
		scale.x = -scale.x;
		return bounds;
	}

	private  function getReflectedScreenBounds(?newRect:FlxRect, ?camera:FlxCamera):FlxRect
	{
		scale.y = -scale.y;
		var bounds = super.getScreenBounds(newRect, camera);
		scale.y = -scale.y;
		return bounds;
	}
}
