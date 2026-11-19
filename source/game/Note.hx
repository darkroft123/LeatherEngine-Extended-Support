package game;

import openfl.utils.Assets;
import shaders.NoteColors;
import shaders.ColorSwap;
import game.SongLoader.SongData;
import utilities.NoteVariables;
import states.PlayState;
import flixel.FlxG;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFramesCollection;
import flixel.math.FlxMath;
import flixel.math.FlxRect;


class Note extends #if MODCHARTING_TOOLS modcharting.FlxSprite3D #else flixel.addons.effects.FlxSkewedSprite #end {
	public static var fallbackArrowConfigs:Map<String, Array<String>> = new Map();
	public static var fallbackTypeConfigs:Map<String, Array<String>> = new Map();

	public var strumTime:Float = 0;
	public var mustPress:Bool = false;
	public var noteData:Int = 0;
	public var canBeHit:Bool = false;
	public var tooLate:Bool = false;
	public var wasGoodHit:Bool = false;
	public var lowPriority:Bool = false;
	public var prevNote:Note;
	public var prevNoteStrumtime:Float = 0;
	public var prevNoteIsSustainNote:Bool = false;

	public var singAnimPrefix:String = "sing";
	public var singAnimSuffix:String = "";

	public var sustains:Array<Note> = [];
	public var missesSustains:Bool = false;

	public var sustainLength:Float = 0;
	#if !MODCHARTING_TOOLS
	public var isSustainNote:Bool = false;
	#end

	public inline function getParentNote():Note {
		var parent:Note = this;
		var iterations:Int = 0;
		while (parent != null && parent.isSustainNote && parent.prevNote != parent && iterations < 500) {
			parent = parent.prevNote;
			iterations++;
		}
		return parent;
	}

	public static var swagWidth:Float = 160 * 0.7;

	public var sustainScaleY:Float = 1;

	/**
	 * Milliseconds this sustain piece has to cover, measured from the BPM map.
	 *
	 * Set when the chain is built, and it has to be set before `speed` is assigned
	 * because that is what bakes the piece's height. `NaN` falls back to the step at
	 * the note's own time.
	 *
	 * Without this the height came from the live `stepCrochet`, which during
	 * `startSong()` is still the tempo of the *last* section of the chart, so every
	 * sustain in the song was sized against the wrong tempo unless the song happened
	 * to be constant.
	 */
	public var sustainMs:Float = Math.NaN;

	/** This piece's own duration, falling back to the step it starts on. */
	function segmentMs():Float {
		if (!Math.isNaN(sustainMs) && sustainMs > 0) return sustainMs;
		return Conductor.getStepDurationAt(strumTime);
	}

	public var xOffset:Float = 0;
	public var yOffset:Float = 0;

	public var rawNoteData:Int = 0;

	public var modAngle:Float = 0;
	public var localAngle:Float = 0;

	public var character:Int = 0;
	public var characters:Array<Int> = [];

	public var arrow_Type:String;

	public var shouldHit:Bool = true;
	public var hitDamage:Float = 0.0;
	public var missDamage:Float = 0.07;
	public var heldMissDamage:Float = 0.035;
	public var playMissOnMiss:Bool = true;

	public var colorSwap:ColorSwap;
	public var affectedbycolor:Bool = false;
	public var customNoteColor:Array<Float> = null;
	public var noteColor:Array<Float> = null;

	public var hasDefaultAnim:Bool = false;
	public var hasHoldAnim:Bool = false;
	public var hasHoldEndAnim:Bool = false;

	static var sustainFallbackCache:Map<String, FlxAtlasFrames> = new Map();

	public var inEditor:Bool = false;
	public var song:SongData;

	public var speed(default, set):Float = 1;
	public var originalSpeed(default, null):Float;

	public var playedHitSound:Bool = false;

	public var sustainClipRect:FlxRect;

	public var alignmentKey:String;

	#if MODCHARTING_TOOLS
	public var mesh:modcharting.SustainStrip = null;

	public var _meshDiag:Bool = false;
	#else
	public var z:Float = 0;
	#end

	public static final SCALE_MULT:Float = 1.474;

	public static var quantColors:Array<Array<Int>> = [
		[255, 35, 15],
		[19, 75, 255],
		[138, 7, 224],
		[71, 250, 22],
		[214, 0, 211],
		[246, 121, 4],
		[0, 200, 172],
		[38, 168, 41],
		[187, 187, 187],
		[167, 199, 231],
		[128, 128, 0],
	];

	public static final beats:Array<Int> = [4, 8, 12, 16, 24, 32, 48, 64, 96, 128, 192];

	public static var framesCache:Map<String, FlxAtlasFrames> = new Map();
	public static var customNoteDominantColorCache:Map<String, Array<Float>> = new Map();
	
	static function usesPreciseSustains(skin:String, ?note:Note):Bool {
		if (note != null && note.frameWidth > 50) return true;
		var ps = PlayState.instance;
		var uiScale:Float = (ps != null && ps.ui_settings != null && ps.ui_settings.length > 0) ? Std.parseFloat(ps.ui_settings[0]) : 1.0;
		return uiScale < 2.0 && (skin == null ? "" : skin.toLowerCase()) != "pixel";
	}

	/**
	 * Resolves the arrow config path for a type/skin. `customType` picks the
	 * skin-first order, `editorFallback` the order used when there is no PlayState.
	 */
	static function loadArrowConfig(arrow_Type:String, skin:String, customType:Bool, editorFallback:Bool):Array<String> {
		var candidates:Array<String> = editorFallback
			? ['ui skins/$skin/$arrow_Type', 'ui skins/default/$arrow_Type', 'ui skins/default/default']
			: (customType
				? ['ui skins/$skin/$arrow_Type', 'ui skins/default/$arrow_Type', 'ui skins/$skin/default']
				: ['ui skins/default/$arrow_Type', 'ui skins/$skin/default', 'ui skins/default/default']);

		for (i in 0...candidates.length - 1)
			if (Assets.exists(Paths.txt(candidates[i]))) return CoolUtil.coolTextFile(Paths.txt(candidates[i]));

		return CoolUtil.coolTextFile(Paths.txt(candidates[candidates.length - 1]));
	}

	static function loadTypeConfig(arrow_Type:String):Array<String> {
		return CoolUtil.coolTextFile(Paths.txt(Assets.exists(Paths.txt('arrow types/$arrow_Type')) ? 'arrow types/$arrow_Type' : 'arrow types/default'));
	}

	/** Bakes one hold segment's height. Shared by construction and `set_speed`. */
	static function applySustainHeight(note:Note, segMs:Float, speed:Float):Void {
		if (usesPreciseSustains(note.song != null ? note.song.ui_Skin : null, note)) {
			note.scale.y = (0.45 * segMs * Math.abs(speed)) / note.frameHeight;
			note.updateHitbox();
			note.centerOffsets();
			if (note.antialiasing)
				note.scale.y += 1 / note.frameHeight;
		} else {
			note.scale.y = note.scale.x * segMs / 100 * SCALE_MULT * speed;
			note.updateHitbox();
			note.centerOffsets();
		}
	}

	static function framesContainPrefix(atl:FlxFramesCollection, prefix:String):Bool {
		if (atl == null || atl.frames == null) return false;

		for (frame in atl.frames)
			if (frame != null && frame.name != null && StringTools.startsWith(frame.name, prefix))
				return true;

		return false;
	}

	static function getFallbackSustainFrames(note:Note, animationName:String):FlxAtlasFrames {
		var disallowGPU:Bool = true;
		var cacheKey = '${note.arrow_Type}_${note.song.ui_Skin}_$animationName';
		if (sustainFallbackCache.exists(cacheKey)) {
			var cached = sustainFallbackCache.get(cacheKey);
			if (cached != null && cached.parent != null && !cached.parent.isDestroyed)
				return cached;
			sustainFallbackCache.remove(cacheKey);
		}

		var candidates:Array<String> = [
			'ui skins/default/arrows/${note.arrow_Type}',
			'ui skins/${note.song.ui_Skin}/arrows/default',
			'ui skins/default/arrows/default'
		];

		var result:FlxAtlasFrames = null;
		for (path in candidates) {
			if (!Assets.exists(Paths.image(path, 'shared'))) continue;

			var atlas = Paths.getSparrowAtlas(path, 'shared', disallowGPU);
			if (framesContainPrefix(atlas, '$animationName hold0') && framesContainPrefix(atlas, '$animationName hold end0')) {
				result = atlas;
				break;
			}
		}

		if (result != null)
			sustainFallbackCache.set(cacheKey, result);

		return result;
	}

	public function setupNoteAnimations(animationName:String):Void {
		hasDefaultAnim = framesContainPrefix(frames, '${animationName}0');
		hasHoldAnim = framesContainPrefix(frames, '$animationName hold0');
		hasHoldEndAnim = framesContainPrefix(frames, '$animationName hold end0');

		if (isSustainNote && (!hasHoldAnim || !hasHoldEndAnim)) {
			var fallback = getFallbackSustainFrames(this, animationName);
			if (fallback != null && fallback != frames) {
				frames = fallback;
				hasDefaultAnim = framesContainPrefix(frames, '${animationName}0');
				hasHoldAnim = framesContainPrefix(frames, '$animationName hold0');
				hasHoldEndAnim = framesContainPrefix(frames, '$animationName hold end0');
				updateHitbox();
			}
		}

		if (hasDefaultAnim)
			animation.addByPrefix("default", '${animationName}0', 24);
		if (hasHoldAnim)
			animation.addByPrefix("hold", '$animationName hold0', 24);
		if (hasHoldEndAnim)
			animation.addByPrefix("holdend", '$animationName hold end0', 24);
	}

	inline static function getDownscrollBool():Bool {
		var value:Dynamic = Options.getData("downscroll");
		return value == true || value == "true";
	}

	inline static function getConfigFloat(config:Array<String>, index:Int, defaultValue:Float = 0):Float {
		if (config == null || config.length <= index || config[index] == null)
			return defaultValue;

		var parsed = Std.parseFloat(config[index]);
		return Math.isNaN(parsed) ? defaultValue : parsed;
	}

	public static function applyColorQuants(notes:Array<Note>) {
		if (!Options.getData('colorQuantization')) return;

		var col:Array<Int> = [255, 0, 0];

		for (note in notes) {
			if (note.isSustainNote || !note.affectedbycolor) continue;

			var noteBeat:Int = Math.round(Conductor.getBeat(note.strumTime) * 48);

			for (beat in 0...beats.length - 1) {
				if (noteBeat % (192 / beats[beat]) == 0) {
					col = quantColors[beat];
					break;
				}
			}

			var colorKey = Std.string(col);

			if (!ColorSwap.colorSwapCache.exists(colorKey))
				ColorSwap.colorSwapCache.set(colorKey, new ColorSwap());

			var swap = ColorSwap.colorSwapCache.get(colorKey);
			note.colorSwap = swap;

			swap.r = col[0];
			swap.g = col[1];
			swap.b = col[2];

			if (note.affectedbycolor)
				note.shader = swap.isIdentity() ? null : swap.shader;

			for (sustain in note.sustains) {
				sustain.colorSwap = swap;

				if (sustain.affectedbycolor)
					sustain.shader = swap.isIdentity() ? null : swap.shader;
			}
		}
	}

	

	public static function getFrames(note:Note):FlxAtlasFrames {
		var disallowGPU:Bool = true;
		var cacheKey = '${note.arrow_Type}_${note.song.ui_Skin}_$disallowGPU';
		if (framesCache.exists(cacheKey)) {
			var cached = framesCache.get(cacheKey);
			if (cached != null && cached.parent != null && !cached.parent.isDestroyed)
				return cached;
			framesCache.remove(cacheKey);
		}

		var result:FlxAtlasFrames = null;
		var hasCustomType:Bool = (PlayState.instance != null && PlayState.instance.types != null && PlayState.instance.types.contains(note.arrow_Type));

		if (hasCustomType) {
			var basePath = 'ui skins/${note.song.ui_Skin}/arrows/';
			var defaultSkinPath = 'ui skins/default/arrows/';

			if (Assets.exists(Paths.image('$basePath${note.arrow_Type}', 'shared')))
				result = Paths.getSparrowAtlas('$basePath${note.arrow_Type}', 'shared', disallowGPU);
			else if (Assets.exists(Paths.image('$defaultSkinPath${note.arrow_Type}', 'shared')))
				result = Paths.getSparrowAtlas('$defaultSkinPath${note.arrow_Type}', 'shared', disallowGPU);
			else if (Assets.exists(Paths.image('${basePath}default', 'shared')))
				result = Paths.getSparrowAtlas('${basePath}default', 'shared', disallowGPU);
			else
				result = Paths.getSparrowAtlas('${defaultSkinPath}default', 'shared', disallowGPU);
		} else {
			var basePath = 'ui skins/default/arrows/';

			if (Assets.exists(Paths.image('$basePath${note.arrow_Type}', 'shared')))
				result = Paths.getSparrowAtlas('$basePath${note.arrow_Type}', 'shared', disallowGPU);
			else if (Assets.exists(Paths.image('ui skins/${note.song.ui_Skin}/arrows/default', 'shared')))
				result = Paths.getSparrowAtlas('ui skins/${note.song.ui_Skin}/arrows/default', 'shared', disallowGPU);
			else
				result = Paths.getSparrowAtlas('ui skins/default/arrows/default', 'shared', disallowGPU);
		}

		framesCache.set(cacheKey, result);
		return result;
	}

	public static function clearFallbackCaches():Void {
		fallbackArrowConfigs.clear();
		fallbackTypeConfigs.clear();
		sustainFallbackCache.clear();
		customNoteDominantColorCache.clear();
	}

	public var strumlineID:Int = -1;
	public var keyCount:Int = 4;

	public function new(strumTime:Float, noteData:Int, ?prevNote:Note, ?sustainNote:Bool = false, ?character:Int = 0, ?arrowType:String = "default",
			?song:SongData, ?characters:Array<Int>, ?mustPress:Bool = false, ?inEditor:Bool = false, ?strumlineID:Int = -1, ?customKeyCount:Null<Int> = null) {
		super();
		moves = false;

		if (prevNote == null) prevNote = this;

		this.prevNote = prevNote;
		this.inEditor = inEditor;
		this.character = character;
		this.strumTime = strumTime;
		this.arrow_Type = arrowType;
		this.characters = characters;
		this.mustPress = mustPress;
		this.isSustainNote = sustainNote;
		this.strumlineID = strumlineID;

		if (song == null) song = PlayState.SONG;

		this.song = song;
		this.noteData = noteData;
		alignmentKey = '${noteData}_${arrowType}_${sustainNote ? 1 : 0}';

		var localKeyCount:Int = customKeyCount != null ? customKeyCount : (mustPress ? (song != null ? song.playerKeyCount : 4) : (song != null ? song.keyCount : 4));
		this.keyCount = localKeyCount;

		var baseSpeed:Float = song != null ? song.speed : 1.0;
		if (!inEditor && Options.getData("useCustomScrollSpeed"))
			baseSpeed = Options.getData("customScrollSpeed");
		var mult:Float = (!inEditor && PlayState.songMultiplier > 0) ? PlayState.songMultiplier : 1.0;
		speed = baseSpeed / mult;
		originalSpeed = speed;

		x += 100;
		y = -2000;

		frames = Note.getFrames(this);

		var animationName:String = "purple";
		if (NoteVariables.animationDirections != null && (localKeyCount - 1) >= 0 && (localKeyCount - 1) < NoteVariables.animationDirections.length) {
			var animDirs = NoteVariables.animationDirections[localKeyCount - 1];
			if (animDirs != null && animDirs.length > 0) {
				var safeData = (noteData >= 0) ? (noteData % animDirs.length) : 0;
				animationName = animDirs[safeData];
			}
		}

		setupNoteAnimations(animationName);

		var ps = PlayState.instance;
		var noteScale:Float = 1.0;

		if (!inEditor) {
			var uiSettings:Array<String> = ps != null ? ps.ui_settings : null;
			var maniaSize:Array<String> = ps != null ? ps.mania_size : null;

			var uiScale:Float = getConfigFloat(uiSettings, 0, 0.7);
			var uiMult:Float = getConfigFloat(uiSettings, 2, 1.0);
			var mSizeIndex:Int = localKeyCount - 1;
			var mSizeVal:Float = mSizeIndex >= 0 ? getConfigFloat(maniaSize, mSizeIndex, 0.0) : 0.0;

			var isHighResSprite:Bool = frameWidth > 50;
			var isPixelSkin:Bool = uiScale >= 2.0;

			if (isPixelSkin && isHighResSprite) {
				noteScale = 0.7 * (uiMult - mSizeVal);
				antialiasing = Options.getData("antialiasing");
			} else {
				noteScale = uiScale * (uiMult - mSizeVal);
				antialiasing = (uiSettings != null && uiSettings.length > 3 && uiSettings[3] == "true") && Options.getData("antialiasing");
			}

			scale.set(noteScale, noteScale);
			updateHitbox();
		}

		x += swagWidth * noteData;
		if (hasDefaultAnim)
			animation.play("default");

		var arrowConfig:Array<String> = null;
		var typeConfig:Array<String> = null;
		var skin:String = song != null ? song.ui_Skin : "default";

		if (ps != null) {
			if (!ps.arrow_Configs.exists(arrow_Type)) {
				ps.arrow_Configs.set(arrow_Type, loadArrowConfig(arrow_Type, skin, ps.types.contains(arrow_Type), false));
				ps.type_Configs.set(arrow_Type, loadTypeConfig(arrow_Type));
				ps.setupNoteTypeScript(arrow_Type);
			}
			arrowConfig = ps.arrow_Configs.get(arrow_Type);
			typeConfig = ps.type_Configs.get(arrow_Type);
		} else {
			var arrowKey = '$arrow_Type|$skin';
			if (!fallbackArrowConfigs.exists(arrowKey))
				fallbackArrowConfigs.set(arrowKey, loadArrowConfig(arrow_Type, skin, true, true));
			if (!fallbackTypeConfigs.exists(arrow_Type))
				fallbackTypeConfigs.set(arrow_Type, loadTypeConfig(arrow_Type));
			arrowConfig = fallbackArrowConfigs.get(arrowKey);
			typeConfig = fallbackTypeConfigs.get(arrow_Type);
		}

		var downscroll = getDownscrollBool();
		var finalYOffset:Float = getConfigFloat(arrowConfig, 0);

		var noteSaturation:Float = getConfigFloat(arrowConfig, 6, 0);
		var noteBrightness:Float = getConfigFloat(arrowConfig, 7, 0);

		shouldHit = (typeConfig != null && typeConfig.length > 0) ? (typeConfig[0] == "true") : true;
		hitDamage = (typeConfig != null && typeConfig.length > 1) ? Std.parseFloat(typeConfig[1]) : 0.025;
		missDamage = (typeConfig != null && typeConfig.length > 2) ? Std.parseFloat(typeConfig[2]) : 0.0475;
		playMissOnMiss = (typeConfig != null && typeConfig.length > 4 && typeConfig[4] != null) ? (typeConfig[4] == "true") : shouldHit;

		if (typeConfig != null && typeConfig.length > 3 && typeConfig[3] != null)
			heldMissDamage = Std.parseFloat(typeConfig[3]);

		offset.y += finalYOffset * noteScale;

		if (downscroll && sustainNote && !inEditor)
			flipY = true;

		if (isSustainNote && prevNote != null) {
			alpha = 1;

			var parentNoteObj = getParentNote();
			if (parentNoteObj != null) {
				affectedbycolor = parentNoteObj.affectedbycolor;
				colorSwap = affectedbycolor ? parentNoteObj.colorSwap : null;
				shader = colorSwap != null ? colorSwap.shader : null;
				customNoteColor = parentNoteObj.customNoteColor;
				noteColor = parentNoteObj.noteColor;
			}

			prevNoteStrumtime = prevNote.strumTime;
			prevNoteIsSustainNote = prevNote.isSustainNote;

			if (hasHoldEndAnim)
				animation.play("holdend");
			else if (hasHoldAnim)
				animation.play("hold");
			else if (hasDefaultAnim)
				animation.play("default");

			if (prevNote.isSustainNote) {
				if (prevNote.animation != null && prevNote.hasHoldAnim)
					prevNote.animation.play("hold");
				applySustainHeight(prevNote, prevNote.segmentMs(), prevNote.speed);
			}

			updateHitbox();
			centerOffsets();
			sustainScaleY = scale.y;

			offset.y += finalYOffset * noteScale;
		}

		if (!isSustainNote && arrowConfig != null && arrowConfig.length > 5 && arrowConfig[5] != null && arrowConfig[5].trim().toLowerCase() == "true")
			affectedbycolor = true;

		applyNoteColor(animationName, noteSaturation, noteBrightness);
	}

	public function getCustomNoteColor(?animName:String):Array<Float> {
		if (arrow_Type == null || arrow_Type == "" || arrow_Type == "default")
			return null;

		var currentUiSkin:String = (song != null && song.ui_Skin != null) ? song.ui_Skin : "default";
		var directionName:String = animName != null ? animName : (animation != null && animation.curAnim != null ? animation.curAnim.name : "");
		var cacheKey:String = '${arrow_Type}_${currentUiSkin}_$directionName';

		if (customNoteDominantColorCache.exists(cacheKey))
			return customNoteDominantColorCache.get(cacheKey);

		// Method 1: direct dominant color from current frame pixels (like Character Editor)
		try {
			useFramePixels = true;
			if (framePixels != null && frameWidth > 0 && frameHeight > 0) {
				var domInt:Int = utilities.CoolUtil.dominantColorFrame(this);
				if (domInt != 0 && (domInt & 0x00FFFFFF) != 0) {
					var flxCol = flixel.util.FlxColor.fromInt(domInt);
					var colArray:Array<Float> = [flxCol.red, flxCol.green, flxCol.blue];
					customNoteDominantColorCache.set(cacheKey, colArray);
					return colArray;
				}
			}
		} catch (e:Dynamic) {}

		// Method 2: scan through atlas frames to locate colored pixels
		if (frames != null && frames.frames != null && frames.frames.length > 0) {
			if (directionName != "") {
				for (fr in frames.frames) {
					if (fr != null && fr.name != null && fr.name.startsWith(directionName) && fr.parent != null && fr.parent.bitmap != null && fr.frame != null && fr.frame.width > 2 && fr.frame.height > 2) {
						var rect = fr.frame;
						var domInt:Int = utilities.CoolUtil.extractDominantColorFromRect(
							fr.parent.bitmap,
							Std.int(rect.x),
							Std.int(rect.y),
							Std.int(rect.width),
							Std.int(rect.height)
						);
						if (domInt != 0 && (domInt & 0x00FFFFFF) != 0) {
							var flxCol = flixel.util.FlxColor.fromInt(domInt);
							var colArray:Array<Float> = [flxCol.red, flxCol.green, flxCol.blue];
							customNoteDominantColorCache.set(cacheKey, colArray);
							return colArray;
						}
					}
				}
			}
			for (fr in frames.frames) {
				if (fr != null && fr.parent != null && fr.parent.bitmap != null && fr.frame != null && fr.frame.width > 2 && fr.frame.height > 2) {
					var rect = fr.frame;
					var domInt:Int = utilities.CoolUtil.extractDominantColorFromRect(
						fr.parent.bitmap,
						Std.int(rect.x),
						Std.int(rect.y),
						Std.int(rect.width),
						Std.int(rect.height)
					);
					if (domInt != 0 && (domInt & 0x00FFFFFF) != 0) {
						var flxCol = flixel.util.FlxColor.fromInt(domInt);
						var colArray:Array<Float> = [flxCol.red, flxCol.green, flxCol.blue];
						customNoteDominantColorCache.set(cacheKey, colArray);
						return colArray;
					}
				}
			}
		}
		return null;
	}

	function applyNoteColor(animationName:String, noteSaturation:Float, noteBrightness:Float):Void {
		var currentUiSkin:String = (song != null && song.ui_Skin != null) ? song.ui_Skin : "default";
		if (!isSustainNote && Options.getData("forceSkinShader_" + currentUiSkin) == true)
			affectedbycolor = true;

		var customCol:Array<Float> = null;
		if (arrow_Type != null && arrow_Type != "" && arrow_Type != "default") {
			customCol = getCustomNoteColor(animationName);
		}
		this.customNoteColor = customCol;

		var noteColor:Array<Float> = null;
		if (affectedbycolor && customCol != null) {
			noteColor = customCol;
		}
		if (noteColor == null) {
			noteColor = cast NoteColors.getNoteColor(animationName);
		}
		this.noteColor = (customCol != null) ? customCol : noteColor;

		var noteColorKey:String = (affectedbycolor && noteColor != null ? Std.string(noteColor) : "default") + "_" + noteSaturation + "_" + noteBrightness;

		if (!isSustainNote) {
			if (!ColorSwap.colorSwapCache.exists(noteColorKey))
				ColorSwap.colorSwapCache.set(noteColorKey, new ColorSwap());
			colorSwap = ColorSwap.colorSwapCache.get(noteColorKey);
		}

		if (colorSwap != null) {
			if (affectedbycolor && noteColor != null) {
				colorSwap.r = noteColor[0];
				colorSwap.g = noteColor[1];
				colorSwap.b = noteColor[2];
			} else {
				colorSwap.r = 255;
				colorSwap.g = 0;
				colorSwap.b = 0;
			}

			colorSwap.saturation = noteSaturation;
			colorSwap.brightness = noteBrightness;
		}

		shader = (affectedbycolor || noteSaturation != 0 || noteBrightness != 0) && colorSwap != null && !colorSwap.isIdentity() ? colorSwap.shader : null;
	}
	public var correctionOffset:Float = 0;
	@:allow(states.PlayState)
	private var _cachedFrame:Int = -1;

	public inline function calculateY(myStrum:StrumNote):Void {
		var strumY:Float = myStrum.y;
		var posMath:Float = 0.45 * (Conductor.songPosition - strumTime) * FlxMath.roundDecimal(speed, 2);

		if (!getDownscrollBool()) {
			y = strumY - posMath;
			return;
		}

		y = strumY + correctionOffset + posMath;

		if (isSustainNote)
			y -= (frameHeight * scale.y) - Note.swagWidth;
	}

	override function update(elapsed:Float) {
		if (animation != null && animation.curAnim != null && animation.curAnim.numFrames > 1)
			super.update(elapsed);

		var targetAngle:Float = modAngle + localAngle;
		if (angle != targetAngle)
			angle = targetAngle;
		calculateCanBeHit();

		if (!inEditor && tooLate && alpha > 0.3)
			alpha = 0.3;
	}

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
		prevNote = null;
		sustains = null;
		characters = null;
		song = null;
		clipRect = null;
		if (sustainClipRect != null)
		{
			sustainClipRect.put();
			sustainClipRect = null;
		}
		#if MODCHARTING_TOOLS
		if (mesh != null)
		{
			mesh.destroy();
			mesh = null;
		}
		#end
		super.destroy();
	}

	public function calculateCanBeHit() {
		var ps = PlayState.instance;
		if (ps != null && _cachedFrame == ps.noteUpdateFrame) return;
		if (ps != null) _cachedFrame = ps.noteUpdateFrame;

		if (mustPress) {
			if (shouldHit) {
				canBeHit = strumTime > Conductor.songPosition - Conductor.safeZoneOffset
					&& strumTime < Conductor.songPosition + Conductor.safeZoneOffset;
			} else {
				canBeHit = strumTime > Conductor.songPosition - Conductor.safeZoneOffset / 3
					&& strumTime < Conductor.songPosition + Conductor.safeZoneOffset * 0.2;
			}

			if (strumTime < Conductor.songPosition - Conductor.safeZoneOffset && !wasGoodHit)
				tooLate = true;
		} else {
			canBeHit = strumTime <= Conductor.songPosition;
		}
	}

	@:noCompletion
	override function set_clipRect(rect:FlxRect):FlxRect {
		clipRect = rect;
		if (frames != null) frame = frames.frames[animation.frameIndex];
		return rect;
	}

	@:noCompletion
	function set_speed(speed:Float):Float {
		// The `holdend` cap has no successor and keeps its uniform scale (Codename-style),
		// so only the hold bodies are resized to the step height.
		var isHoldEnd:Bool = animation != null && animation.curAnim != null && animation.curAnim.name == "holdend";
		if (isSustainNote && !inEditor && animation != null && !isHoldEnd) {
			applySustainHeight(this, segmentMs(), speed);
			sustainScaleY = scale.y;
		}

		return this.speed = speed;
	}
}

typedef StrumJson = {
	var affectedbycolor:Bool;
}

typedef JsonData = {
	var values:Array<StrumJson>;
}

