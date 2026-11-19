package game;

import game.Note.JsonData;
import openfl.Assets;
import haxe.Json;
import utilities.NoteVariables;
import shaders.ColorSwap;
import shaders.NoteColors;
import states.PlayState;
import flixel.addons.effects.FlxSkewedSprite;
import flixel.graphics.frames.FlxAtlasFrames;


/*
	credit to psych engine devs (sorry idk who made this originally, all ik is that srperez modified it for shaggy and then i got it from there)
 */
class StrumNote extends #if MODCHARTING_TOOLS modcharting.FlxSprite3D #else FlxSkewedSprite #end {
	#if !MODCHARTING_TOOLS
	public var z:Float = 0;
	#end
	public var resetAnim:Float = 0;
	private var noteData:Int = 0;

	public var swagWidth:Float = 0;

	public var ui_Skin:String = "default";
	public var ui_settings:Array<String>;
	public var mania_size:Array<String>;
	public var keyCount:Int;

	public var colorSwap:ColorSwap;
	public var defaultAffectedByColor:Bool = false;
	public var noteColor:Array<Int> = [255, 0, 0];
	public var affectedbycolor:Bool = false;

	public var isPlayer:Float;
	public var jsonData:JsonData;

	public static var cachedConfig(default, never):Map<String, JsonData> = new Map();
	public static var strumFramesCache:Map<String, FlxAtlasFrames> = new Map();

	public static function clearCache():Void {
		strumFramesCache.clear();
		cachedConfig.clear();
	}

	public var modAngle:Float = 0;

	public function new(
		x:Float,
		y:Float,
		noteData:Int,
		?ui_Skin:String,
		?ui_settings:Array<String>,
		?mania_size:Array<String>,
		?keyCount:Int,
		?isPlayer:Float
	) {
		super(x, y);

		var strumKey = "strum_" + noteData + "_" + (isPlayer == 1 ? "player" : "opponent");
		if (!ColorSwap.colorSwapCache.exists(strumKey))
			ColorSwap.colorSwapCache.set(strumKey, new ColorSwap());
		colorSwap = ColorSwap.colorSwapCache.get(strumKey);

		var ps = PlayState.instance;
		var song = PlayState.SONG;

		if (ui_Skin == null)
			ui_Skin = (song != null && song.ui_Skin != null) ? song.ui_Skin : "default";

		if (ui_settings == null)
			ui_settings = (ps != null && ps.ui_settings != null) ? ps.ui_settings : null;
		if (ui_settings == null && ui_Skin != null && ui_Skin != "") {
			try {
				if (Assets.exists(Paths.txt("ui skins/" + ui_Skin + "/config")))
					ui_settings = CoolUtil.coolTextFile(Paths.txt("ui skins/" + ui_Skin + "/config"));
			} catch(e:Dynamic) { Main.logSilentError(e, "StrumNote: load UI skin config"); }
		}
		if (ui_settings == null || ui_settings.length < 4) {
			ui_settings = ["0.7", "0.7", "1", "true"];
		}

		if (mania_size == null)
			mania_size = (ps != null && ps.mania_size != null) ? ps.mania_size : null;
		if (mania_size == null && ui_Skin != null && ui_Skin != "") {
			try {
				if (Assets.exists(Paths.txt("ui skins/" + ui_Skin + "/maniasize")))
					mania_size = CoolUtil.coolTextFile(Paths.txt("ui skins/" + ui_Skin + "/maniasize"));
				else if (Assets.exists(Paths.txt("ui skins/mania size")))
					mania_size = CoolUtil.coolTextFile(Paths.txt("ui skins/mania size"));
			} catch(e:Dynamic) { Main.logSilentError(e, "StrumNote: load mania size config"); }
		}
		if (mania_size == null || mania_size.length < 10) {
			mania_size = ["0.0", "0.0", "0.0", "0.0", "0.0", "0.0", "0.0", "0.0", "0.0", "0.0"];
		}

		if (keyCount == null || keyCount <= 0)
			keyCount = (song != null && song.keyCount > 0) ? song.keyCount : 4;

		var hasCustomSkin:Bool = Assets.exists(Paths.image('ui skins/$ui_Skin/arrows/strums', 'shared'))
			|| Assets.exists(Paths.image('ui skins/$ui_Skin/arrows/default', 'shared'))
			|| Assets.exists(Paths.json('ui skins/$ui_Skin/config'));

		if (!hasCustomSkin)
			ui_Skin = "default";

		this.noteData = noteData;
		this.ui_Skin = ui_Skin;
		this.ui_settings = ui_settings;
		this.mania_size = mania_size;
		this.keyCount = keyCount;
		this.isPlayer = isPlayer;

		inline function setValues():Void {
			if (jsonData != null && jsonData.values != null) {
				for (value in jsonData.values) {
					this.affectedbycolor = value.affectedbycolor;
				}
			}
		}

		var configPath:String = Paths.json("ui skins/" + ui_Skin + "/config");

		if (cachedConfig.exists(ui_Skin)) {
			jsonData = cachedConfig.get(ui_Skin);
			setValues();
		} else if (Assets.exists(configPath)) {
			jsonData = Json.parse(Assets.getText(configPath));
			cachedConfig.set(ui_Skin, jsonData);
			setValues();
		}

		var spritesheetPath:String;

		if (Assets.exists(Paths.image('ui skins/$ui_Skin/arrows/strums', 'shared'))) {
			spritesheetPath = 'ui skins/$ui_Skin/arrows/strums';
		} else if (Assets.exists(Paths.image('ui skins/$ui_Skin/arrows/default', 'shared'))) {
			spritesheetPath = 'ui skins/$ui_Skin/arrows/default';
		} else if (Assets.exists(Paths.image('ui skins/default/arrows/strums', 'shared'))) {
			spritesheetPath = 'ui skins/default/arrows/strums';
		} else {
			spritesheetPath = 'ui skins/default/arrows/default';
		}

		var cacheKey = '${spritesheetPath}';
		if (strumFramesCache.exists(cacheKey)) {
			frames = strumFramesCache.get(cacheKey);
		} else {
			var newFrames = Paths.getSparrowAtlas(spritesheetPath, 'shared');
			frames = newFrames;
			strumFramesCache.set(cacheKey, newFrames);
		}

		var direction:String = NoteVariables.animationDirections[keyCount - 1][noteData];
		var animationBaseName:String = NoteVariables.maniaDirections[keyCount - 1][Std.int(Math.abs(noteData))].toLowerCase();

		animation.addByPrefix('static', animationBaseName + " static");
		animation.addByPrefix('pressed', direction + ' press', 24, false);
		animation.addByPrefix('confirm', direction + ' confirm', 24, false);

		antialiasing = ui_settings[3] == "true";

		var scaleMult:Float = Std.parseFloat(ui_settings[0]) * (Std.parseFloat(ui_settings[2]) - Std.parseFloat(mania_size[keyCount - 1]));
		setGraphicSize(width * scaleMult);
		updateHitbox();

		noteColor = NoteColors.getNoteColor(direction);
		if (utilities.Options.getData("forceSkinShader_" + ui_Skin) == true)
			affectedbycolor = true;
		shader = affectedbycolor ? colorSwap.shader : null;

		if (affectedbycolor && ps != null && colorSwap != null && noteColor != null) {
			colorSwap.r = noteColor[0];
			colorSwap.g = noteColor[1];
			colorSwap.b = noteColor[2];
		}

		defaultAffectedByColor = this.affectedbycolor;
		playAnim('static');
	}

	override function update(elapsed:Float) {
		#if MODCHARTING_TOOLS
		angle3D.z = modAngle;
		#else
		angle = modAngle;
		#end

		if (resetAnim > 0) {
			resetAnim -= elapsed;

			if (resetAnim <= 0) {
				playAnim('static');
				resetAnim = 0;
			}
		}

		super.update(elapsed);
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
		super.destroy();
	}

	public function playAnim(anim:String, ?force:Bool = false) {
		animation.play(anim, force);
		// updateHitbox();
		centerOrigin();

		if (affectedbycolor) {
			shader = colorSwap.shader;
			if (anim == "static") {
				colorSwap.r = 255;
				colorSwap.g = 0;
				colorSwap.b = 0;
				swagWidth = width;
				affectedbycolor = defaultAffectedByColor;
			} else {
				if (colorSwap.r == 255 && colorSwap.g == 0 && colorSwap.b == 0 && noteColor != null) {
					colorSwap.r = noteColor[0];
					colorSwap.g = noteColor[1];
					colorSwap.b = noteColor[2];
				}
			}
		} else {
			if (anim != "confirm") {
				shader = null;
				colorSwap.r = 255;
				colorSwap.g = 0;
				colorSwap.b = 0;
			}
		}

		var scale:Float = Std.parseFloat(ui_settings[0]) * (Std.parseFloat(ui_settings[2]) - Std.parseFloat(mania_size[keyCount - 1]));
		centerOffsets();
	}
}