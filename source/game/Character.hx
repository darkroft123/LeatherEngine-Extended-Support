package game;

import toolbox.CharacterCreator;
import flxanimate.frames.FlxAnimateFrames;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
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
import shaders.Shaders.RTXEffect;
import flixel.graphics.frames.FlxFrame.FlxFrameAngle;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.FlxBasic;

/**
 * The base character class.
 */
class Character extends ReflectedSprite {
	public var animOffsets:Map<String, Array<Dynamic>> = new Map<String, Array<Dynamic>>();
	public var debugMode:Bool = false;

	public var isPlayer:Bool = false;
	public var curCharacter:String = 'bf';

	public var holdTimer:Float = 0;

	public var animationNotes:Array<Dynamic> = [];

	public var dancesLeftAndRight:Bool = false;

	public var barColor:FlxColor = FlxColor.GREEN;
	public var positioningOffset:Array<Float> = [0, 0];
	public var cameraOffset:Array<Float> = [0, 0];
	public var isCharacterGroup(default, null):Bool = false;
	public var otherCharacters:Array<Character>;
	public var mainCharacterID:Int = 0;
	public var followMainCharacter:Bool = false;

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
	
	public var rtxShader:RTXEffect = new RTXEffect();
	public var singAnimPrefix:String = 'sing';

	public var playFullAnim:Bool = false;
	public var preventDanceForAnim:Bool = false;
	public var ignoreDraw(default, null):Bool = false;
	public var scaleMult:Float = 1.0;
	
	public var lastHitStrumTime:Float = 0;
	public var justHitStrumTime:Float = -5000;
	public var offsetOffset:Array<Float> = [0,0];
	public var parent:FlxTypedGroup<FlxBasic>;

	public function new(x:Float, y:Float, ?character:String = "bf", ?isPlayer:Bool = false, ?isDeathCharacter:Bool = false,scaleMult:Float = 1.0)  
		{
		super(x, y);
		this.scaleMult = scaleMult;
			animOffsets = new Map<String, Array<Dynamic>>();
		curCharacter = character;
		this.isPlayer = isPlayer;
		this.isDeathCharacter = isDeathCharacter;
			deathCharacter = "bf-dead";
		dancesLeftAndRight = false;

		var ilikeyacutg:Bool = false;
		rtxShader.parentSprite = this;
		shader = rtxShader.shader;
		switch (curCharacter.toLowerCase()) {
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

		if (icon == null)
			icon = curCharacter;

		// YOOOOOOOOOO POG MODDING STUFF
		if (character != '')
			loadOffsetFile(curCharacter);

		if (curCharacter != '' && otherCharacters == null && hasAnims()) {
			if (atlasMode) {
				atlas.updateHitbox();
				width = atlas.width;
				height = atlas.height;
				offset = atlas.offset;
				origin = atlas.origin;
			} else {
				updateHitbox();
			}

			if (!debugMode) {
				dance('');

				if (isPlayer) {
					// Doesn't flip for BF, since his are already in the right place???
					if (swapLeftAndRightSingPlayer && !isDeathCharacter) {
						try {
							var oldOffRight = animOffsets.get("singRIGHT");
							var oldOffLeft = animOffsets.get("singLEFT");
							var oldRight:Array<Int> = animation.getByName('singRIGHT').frames;
							animation.getByName('singRIGHT').frames = animation.getByName('singLEFT').frames;
							animation.getByName('singLEFT').frames = oldRight;

							animOffsets.set("singRIGHT", oldOffLeft);
							animOffsets.set("singLEFT", oldOffRight);

							// IF THEY HAVE MISS ANIMATIONS??
							if (animation.getByName('singRIGHTmiss') != null) {
								var oldOffRightMiss = animOffsets.get("singRIGHTmiss");
								var oldOffLeftMiss = animOffsets.get("singLEFTmiss");

								var oldMiss = animation.getByName('singRIGHTmiss').frames;
								animation.getByName('singRIGHTmiss').frames = animation.getByName('singLEFTmiss').frames;
								animation.getByName('singLEFTmiss').frames = oldMiss;

								animOffsets.set("singRIGHTmiss", oldOffLeftMiss);
								animOffsets.set("singLEFTmiss", oldOffRightMiss);
							}
						} catch (e) {
							// trace(e, ERROR);
						}
					}
				}
			}
		} else {
			visible = false;
		}
		#if HSCRIPT_ALLOWED
		if (Assets.exists(Paths.hx("data/character data/" + curCharacter + "/script"))) {
			script?.call("createCharacterPost", [curCharacter]);
		}

		animation.onFinish.add((animName) -> {
			script?.call("onAnimationFinished", [animName]);
		});
		#end
	}

	public function loadNamedConfiguration(characterName:String) {
		if (!Assets.exists((Paths.json("character data/" + characterName)))) {
			if (!Assets.exists(Paths.json("character data/" + characterName + "/config"))) {
				curCharacter = characterName = isPlayer ? "bf" : "dad";
			}
			#if HSCRIPT_ALLOWED
			if(FlxG.state is PlayState){
				if (Assets.exists(Paths.hx("data/character data/" + characterName + "/script"))) {
					script = new HScript(Paths.hx("data/character data/" + characterName + "/script"));

					script.interp.variables.set("character", this);
					PlayState.instance.scripts.set(characterName, script);
					script.call("createCharacter", [curCharacter]);
				}
			}
			#end

			if (Options.getData("optimizedChars") && Assets.exists(Paths.json("character data/optimized_" + characterName + "/config")))
				characterName = "optimized_" + characterName;

			this.config = cast Json.parse(Assets.getText(Paths.json("character data/" + characterName + "/config")).trim());
		} else {
			this.config = parsePsychCharacter(characterName);
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
			if(animation.anim.startsWith("dance")){
				returnCharacter.dancesLeftAndRight = true;
			}
			addOffset(animation.anim, (isPlayer ? -1 : 1) * (animation.offsets[0] ?? 0), animation.offsets[1] ?? 0);
		}
		return returnCharacter;
	}

	public var atlasMode:Bool = false;
	public var atlas:FlxAnimate;

	override public function draw():Void {
		if(ignoreDraw){
			return;
		}
		if (atlasMode && atlas != null && visible) {
			// thanks cne for this shits lol
			atlas.cameras = cameras;
			atlas.scrollFactor = scrollFactor;
			atlas.scale = scale;
			atlas.offset = offset;
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
			rtxShader.update(0);
		} else {
			super.draw();
			rtxShader.update(0);
		}
	}

	override function destroy() {
		FlxDestroyUtil.destroy(coolTrail);
		FlxDestroyUtil.destroy(atlas);
		super.destroy();
	}

	public function loadCharacterConfiguration(config:CharacterConfig) {
		if (config.characters == null || config.characters.length <= 1) {
			if (!isPlayer)
				flipX = config.defaultFlipX;
			else
				flipX = !config.defaultFlipX;
			if (Options.getData("dinnerbone")) {
				flipY = !config.defaultFlipY;
			}

			if (config.offsetsFlipWhenPlayer == null) {
				if (curCharacter.contains("bf"))
					offsetsFlipWhenPlayer = false;
				else
					offsetsFlipWhenPlayer = true;
			} else
				offsetsFlipWhenPlayer = config.offsetsFlipWhenPlayer;

			if (config.offsetsFlipWhenEnemy == null) {
				if (curCharacter.contains("bf"))
					offsetsFlipWhenEnemy = true;
				else
					offsetsFlipWhenEnemy = false;
			} else
				offsetsFlipWhenEnemy = config.offsetsFlipWhenEnemy;

			if((isPlayer && offsetsFlipWhenPlayer) || (!isPlayer && offsetsFlipWhenEnemy))
			{
				rtxShader.flipX = true;
			}

			dancesLeftAndRight = config.dancesLeftAndRight;

			if (Assets.exists(Paths.file("images/characters/" + config.imagePath + "/Animation.json", TEXT))) {
				atlasMode = true;
				atlas = new FlxAnimate(0.0, 0.0, Paths.getTextureAtlas("characters/" + config.imagePath, "shared"));
				atlas.showPivot = false;
			} else {
				frames = Paths.getAtlas(config.imagePath);
			}

			if (config.extraSheets != null) {
				for (sheet in config.extraSheets) {
					cast(frames, FlxAtlasFrames).addAtlas(Paths.getAtlas(sheet)); // multiatlas support.
				}
			}

			var size:Null<Float> = config.graphicSize;

			if (size == null)
				size = config.graphicsSize;

			if (size != null)
				scale.set(size, size);

			if (!atlasMode) {
				for (selected_animation in config.animations) {
					if (selected_animation.indices != null && selected_animation.indices.length > 0) {
						animation.addByIndices(selected_animation.name, selected_animation.animation_name, selected_animation.indices, "",
							selected_animation.fps, selected_animation.looped);
					} else {
						animation.addByPrefix(selected_animation.name, selected_animation.animation_name, selected_animation.fps, selected_animation.looped);
					}
				}
			} else {
				for (selected_animation in config.animations) {
					if (selected_animation.indices != null && selected_animation.indices.length > 0) {
						atlas.anim.addBySymbolIndices(selected_animation.name, selected_animation.animation_name, selected_animation.indices,
							selected_animation.fps, selected_animation.looped);
					} else {
						atlas.anim.addBySymbol(selected_animation.name, selected_animation.animation_name, selected_animation.fps, selected_animation.looped);
					}
				}
			}

			if (isDeathCharacter)
				playAnim("firstDeath");
			else {
				if (dancesLeftAndRight)
					playAnim("danceRight");
				else {
					playAnim("idle");
				}
			}

			if (debugMode)
				flipX = config.defaultFlipX;

			if (config.antialiasing != null)
				antialiasing = config.antialiasing;
			else if (config.antialiased != null)
				antialiasing = config.antialiased;

						scale *= scaleMult;

			if (atlasMode) {
				atlas.updateHitbox();
				width = atlas.width;
				height = atlas.height;
				offset = atlas.offset;
				origin = atlas.origin;
			} else {
				updateHitbox();
			}

			if (config.positionOffset != null)
				positioningOffset = config.positionOffset;

			if (config.trail || FlxG.state is CharacterCreator) {
				coolTrail = new FlxTrail(this, null, config.trailLength ?? 10, config.trailDelay ?? 3, config.trailStalpha ?? 0.4, config.trailDiff ?? 0.05);
				coolTrail.cameras = this.cameras; // seguir la misma cámara que el actor
				
			}


			if (config.swapDirectionSingWhenPlayer != null)
				swapLeftAndRightSingPlayer = config.swapDirectionSingWhenPlayer;
			else if (curCharacter.contains("bf"))
				swapLeftAndRightSingPlayer = false;

			if (config.singDuration != null)
				singDuration = config.singDuration;
		} else {
			otherCharacters = [];
			if (config.mainCharacterID != null) {
				mainCharacterID = config.mainCharacterID;
			}
			if (config.followMainCharacter != null) {
				followMainCharacter = config.followMainCharacter;
			}
			ignoreDraw = isCharacterGroup = true;

			for (characterData in config.characters) {
				var character:Character;

				if (!isPlayer)
					character = new Character(x, y, characterData.name, isPlayer, isDeathCharacter, scaleMult);
				else
					character = new Boyfriend(x, y, characterData.name, isDeathCharacter, scaleMult);

				if (flipX)
					characterData.positionOffset[0] = 0 - characterData.positionOffset[0]*scaleMult;

				character.positioningOffset[0] += characterData.positionOffset[0]*scaleMult;
				character.positioningOffset[1] += characterData.positionOffset[1]*scaleMult;

				otherCharacters.push(character);
			}
		}

		if (config.barColor == null)
			config.barColor = [255, 0, 0];

		barColor = FlxColor.fromRGB(config.barColor[0], config.barColor[1], config.barColor[2]);

		var localKeyCount;
		if (FlxG.state == PlayState.instance) {
			localKeyCount = isPlayer ? PlayState.SONG.playerKeyCount : PlayState.SONG.keyCount;
		} else {
			localKeyCount = 4;
		}

		if (config.cameraOffset != null) {
			if (flipX)
				config.cameraOffset[0] = 0 - config.cameraOffset[0];

			cameraOffset = config.cameraOffset;
		}

		if (config.deathCharacter != null)
			deathCharacter = config.deathCharacter;
		else if (config.deathCharacterName != null)
			deathCharacter = config.deathCharacterName;
		else
			deathCharacter = "bf-dead";

		if (config.healthIcon != null)
			icon = config.healthIcon;
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

	public var shouldDance:Bool = true;
	public var forceAutoDance:Bool = false;

	override function update(elapsed:Float) {
		if (!debugMode && curCharacter != '' && hasAnims()) {
			if (curAnimFinished() && hasAnim(curAnimName() + '-loop')) {
				playAnim(curAnimName() + '-loop');
			} else if (playFullAnim && curAnimFinished()) {
				playFullAnim = false;
				dance('');
			} else if (preventDanceForAnim && curAnimFinished()) {
				preventDanceForAnim = false;
				dance('');
			}
			if (!isPlayer || forceAutoDance) {
				if (curAnimName().startsWith('sing'))
					holdTimer += elapsed * (FlxG.state == PlayState.instance ? PlayState.songMultiplier : 1);

				if (holdTimer >= Conductor.stepCrochet * singDuration * 0.001) {
					dance(mostRecentAlt);
					holdTimer = 0;
				}
			}

			// fix for multi character stuff lmao
			if (hasAnims()) {
				if (curAnimName() == 'hairFall' && curAnimFinished())
					playAnim('danceRight');
			}
		}

		if (atlasMode && atlas != null) {
			atlas.update(elapsed);
		}

				if (FlxG.state == PlayState.instance)
			{
				@:privateAccess
				rtxShader.hue = PlayState.instance.stage.colorSwap.hue;
			}

		super.update(elapsed);
	}

	public var danced:Bool = false;

	public var lastAnim:String = '';

	var mostRecentAlt:String = "";

    public var extraSuffix:String = "";

	public inline function curAnimLooped():Bool {
		@:privateAccess
		return (!atlasMode && animation.curAnim != null && animation.curAnim.looped)
			|| (atlasMode && atlas.anim.loopType == flxanimate.data.AnimationData.Loop.Loop);
	}

	public inline function curAnimFinished():Bool {
		return (!atlasMode && animation.curAnim != null && animation.curAnim.finished) || (atlasMode && atlas.anim.finished);
	}

	public function curAnimName():String {
		if (!atlasMode && animation.curAnim != null) {
			return animation.curAnim.name;
		}

		if (atlasMode) {
			return lastAnim;
		}

		return '';
	}

	public inline function hasAnim(name:String):Bool {
		return (!atlasMode && animation.exists(name)) || (atlasMode && atlas.anim.existsByName(name));
	}

	public inline function hasAnims():Bool {
		return (!atlasMode && animation.curAnim != null) || (atlasMode && atlas != null && atlas.anim != null);
	}

	/**
	 * FOR GF DANCING SHIT
	 */
	public function dance(altAnim:String = '', force:Bool = false) {
		#if HSCRIPT_ALLOWED
		script?.call("dance", [altAnim, force]);
		#end
		if (shouldDance) {
			if (!debugMode && curCharacter != '' && hasAnims() && (force || (!playFullAnim && !preventDanceForAnim))) {
				var alt:String = '';
				color = 0xFFFFFFFF;
				if ((!dancesLeftAndRight && hasAnim("idle" + altAnim))
					|| (dancesLeftAndRight && hasAnim("danceLeft" + altAnim) && hasAnim("danceRight" + altAnim)))
					alt = altAnim;

				mostRecentAlt = alt;

				var alwaysPlayAnimation:Bool = (curAnimName().startsWith('idle')
					|| curAnimName().startsWith('danceLeft')
					|| curAnimName().startsWith('danceRight')
					|| curAnimName().startsWith('sing'));

				if (alwaysPlayAnimation || curAnimFinished() || curAnimLooped()) {
					if (!dancesLeftAndRight)
						playAnim('idle' + alt);
					else if (dancesLeftAndRight) {
						danced = !danced;
						if (danced)
							playAnim('danceRight' + alt);
						else
							playAnim('danceLeft' + alt);
					}
				}
			}
		}
	}

	public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0, ?strumTime:Float):Void {
		lastAnim = AnimName;
		if (playFullAnim || !hasAnim(AnimName))
			return;

		if (singAnimPrefix != 'sing' && AnimName.contains('sing')) {
			var anim:String = AnimName;
			anim = anim.replace('sing', singAnimPrefix);
			if (animation.getByName(anim) != null)
				AnimName = anim;
		}

		AnimName += extraSuffix;

		color = 0xFFFFFFFF;
		if (animation.getByName(AnimName) == null)
		{
			if (AnimName.contains('dodge'))
			{
				color = 0xFF545454;
				preventDanceForAnim = true;
				AnimName = AnimName.replace("dodge", singAnimPrefix);
			}
			else if (AnimName.contains("miss"))
			{
				color = 0xFF380045;
				preventDanceForAnim = true;
				AnimName = AnimName.replace("miss", "");
			}
			else if (AnimName.contains("parry"))
			{
				AnimName = AnimName.replace("parry", singAnimPrefix);
			}
			else if (AnimName.contains("-mic"))
			{
				AnimName = AnimName.replace("-mic", "");
			}
			else if (AnimName.contains("-alt"))
			{
				AnimName = AnimName.replace("-alt", "");
			}
		}

		if (strumTime != null)
		{
			justHitStrumTime = strumTime;
		}
		else
			justHitStrumTime = Conductor.songPosition;

		if (Options.getData("trails")) {
			if (Math.abs(lastHitStrumTime - justHitStrumTime) < 50 && animation.curAnim != null || holdTimer >= Conductor.stepCrochet * singDuration * 0.001)
			{
				var actor = this;
				var Sprite:ReflectedSprite = new ReflectedSprite(actor.x, actor.y);
				Sprite.drawFlipped = this.drawFlipped;
				Sprite.loadGraphicFromSprite(actor);
				Sprite.alpha = 0.8 * actor.alpha;
				Sprite.blend = ADD;
				Sprite.color = barColor;
				Sprite.angle = actor.angle;
				Sprite.offset.x = actor.offset.x;
				Sprite.offset.y = actor.offset.y;
				Sprite.origin.x = actor.origin.x;
				Sprite.origin.y = actor.origin.y;
				Sprite.scale.x = actor.scale.x;
				Sprite.scale.y = actor.scale.y;
				Sprite.active = false;
				Sprite.animation.frameIndex = actor.animation.frameIndex;
				Sprite.flipX = actor.flipX;
				Sprite.flipY = actor.flipY;
				Sprite.shader = rtxShader.copy().shader;
				Sprite.animation.play(animation.curAnim.name, Force, Reversed, Frame);
				Sprite.offset.set(actor.offset.x, actor.offset.y);
				Sprite.cameras = this.cameras;
				(this.parent != null ? this.parent : FlxG.state).insert(FlxG.state.members.indexOf(this)-1, Sprite);

				var props:Dynamic = {alpha: 0};
				switch (AnimName) {
					case 'singLEFT':
						props.x = actor.x - 150;
					case 'singRIGHT':
						props.x = actor.x + 150;
					case 'singUP':
						props.y = actor.y - 150;
					case 'singDOWN':
						props.y = actor.y + 150;
				}

				FlxTween.tween(Sprite, props, Conductor.crochet * 0.0025, {
					ease: FlxEase.elasticInOut,
					onComplete: function(twn:FlxTween) {
						Sprite.destroy();
					}
				});
			}
		}

		lastHitStrumTime = justHitStrumTime;

		if (atlasMode && atlas != null) {
			atlas.anim.play(AnimName, Force, Reversed, Frame);
		} else {
			animation.play(AnimName, Force, Reversed, Frame);
		}

		preventDanceForAnim = false;

		if (AnimName.contains('dodge'))
			preventDanceForAnim = true;

		var daOffset = animOffsets.get(AnimName);

		if (animOffsets.exists(AnimName))
			offset.set((daOffset[0]*scaleMult) + offsetOffset[0], (daOffset[1]*scaleMult) + offsetOffset[1]);
		else
			offset.set(offsetOffset[0], offsetOffset[1]);
	}


	public function addOffset(name:String, x:Float = 0, y:Float = 0)
		{
			if((isPlayer && offsetsFlipWhenPlayer) || (!isPlayer && offsetsFlipWhenEnemy))
			{
				drawFlipped = true;
				x = 0 - x;
			} //

			animOffsets.set(name, [x, y]);
		}
	
	public function getMainCharacter():Character {
		if (isCharacterGroup  && followMainCharacter) {
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
	public var drawFlipped = false;
	public var drawReflection:Bool = false;
	public var reflectionYOffset:Float = 0;
	public var reflectionAlpha:Float = 0.5;
	private var _drawingReflection:Bool = false;
	public var reflectionColor:FlxColor = 0xFF000000;
	public var reflectionScaleY:Float = 0.6;

	public var transform:FlxMatrix = new FlxMatrix();

	override public function draw()
	{
		if (drawReflection)
		{
			_drawingReflection = true;
			var startX = x;
			var startY = y;
			var alp = alpha;
			var col = color;
			var scaleY = scale.y;
			//flip everything
			color = reflectionColor;
			scale.y = -scale.y;
			offset.y = -offset.y;
			alpha *= reflectionAlpha;
			y += height+reflectionYOffset;
			x += width;

			transform.identity();

			//transform.c += 2.0;
			

			super.draw(); //draw reflection
			//reset back to default
			scale.y = scaleY;
			offset.y = -offset.y;
			alpha = alp;
			y = startY;
			x = startX;
			color = col;
			_drawingReflection = false;
		}
		if (drawFlipped)
		{
			flipX = !flipX;
			scale.x = -scale.x;
			super.draw();
			flipX = !flipX;
			scale.x = -scale.x;
		}
		else 
		{
			super.draw(); //draw normal sprite
		}
	}

	override function drawComplex(camera:FlxCamera):Void
	{
		_frame.prepareMatrix(_matrix, FlxFrameAngle.ANGLE_0, checkFlipX(), checkFlipY());

		_matrix.translate(-origin.x, -origin.y);
		_matrix.scale(scale.x, scale.y);
		if (_drawingReflection)
		{
			_matrix.concat(transform);
		}



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


	override public function isOnScreen(?camera:FlxCamera):Bool //stupid shit breaking with negative scaley
	{
		return super.isOnScreen(camera);
	}
	override public function getScreenBounds(?newRect:FlxRect, ?camera:FlxCamera):FlxRect 
	{
		if (drawFlipped) //shoutout to CNE devs
		{
			scale.x = -scale.x;
			var bounds = super.getScreenBounds(newRect, camera);
			scale.x = -scale.x;
			return bounds;
		}
		if (_drawingReflection)
		{
			scale.y = -scale.y;
			var bounds = super.getScreenBounds(newRect, camera);
			scale.y = -scale.y;
			return bounds;
		}
		return super.getScreenBounds(newRect, camera);
	}
}
