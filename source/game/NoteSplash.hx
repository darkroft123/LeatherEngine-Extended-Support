package game;

import game.Note;
import game.StrumNote;
import haxe.Json;
import openfl.Assets;
import shaders.NoteColors;
import shaders.ColorSwap;
import utilities.NoteVariables;
import flixel.FlxG;
import flixel.graphics.frames.FlxAtlasFrames;
import states.PlayState;
import flixel.FlxSprite;

class NoteSplash extends FlxSprite {
	public var target:StrumNote;

	public var colorSwap:ColorSwap;
	public var noteColor:Array<Int> = [255, 0, 0];
	public var affectedbycolor:Bool = false;
	public var jsonData:JsonData;

	static var splashAtlasCache:Map<String, FlxAtlasFrames> = new Map();
	static var splashConfigCache:Map<String, JsonData> = new Map();

	public function new(?X:Float = 0, ?Y:Float = 0) {
		super(X, Y);

		colorSwap = new ColorSwap();

		alpha = 0.8;

		var skin = PlayState.SONG.ui_Skin;
		if (splashAtlasCache.exists(skin)) {
			frames = splashAtlasCache.get(skin);
		} else {
			var atlas:FlxAtlasFrames;
			if (Std.parseInt(PlayState.instance.ui_settings[6]) == 1) {
				if (Assets.exists(Paths.image('ui skins/' + skin + "/arrows/Note_Splashes")))
					atlas = Paths.getSparrowAtlas('ui skins/' + skin + "/arrows/Note_Splashes");
				else
					atlas = Paths.getSparrowAtlas("ui skins/default/arrows/Note_Splashes");
			} else {
				atlas = Paths.getSparrowAtlas("ui skins/default/arrows/Note_Splashes");
			}
			splashAtlasCache.set(skin, atlas);
			frames = atlas;
		}

		if (splashConfigCache.exists(skin)) {
			jsonData = splashConfigCache.get(skin);
		} else {
			var configPath = Paths.json("ui skins/" + skin + "/config");
			if (Assets.exists(configPath)) {
				jsonData = Json.parse(Assets.getText(configPath));
				splashConfigCache.set(skin, jsonData);
			}
		}

		if (jsonData != null) {
			for (value in jsonData.values) {
				this.affectedbycolor = value.affectedbycolor;
			}
		}
	}

	public static function clearCache():Void
	{
		splashAtlasCache.clear();
		splashConfigCache.clear();
	}

	public function setup_splash(noteData:Int, target:StrumNote, isPlayer:Bool = false, ?sourceNote:Note = null) {
		var localKeyCount:Int = isPlayer ? PlayState.SONG.playerKeyCount : PlayState.SONG.keyCount;

		this.target = target;
		graphic.destroyOnNoUse = false;

		var animName:String = 'splash_${localKeyCount}_${noteData}';
		if (animation.getByName(animName) == null) {
			animation.addByPrefix(animName, "note splash "
				+ NoteVariables.animationDirections[localKeyCount - 1][noteData] + "0", FlxG.random.int(22, 26), false);
		}
		animation.play(animName, true);

		setGraphicSize(target.width * 2.5);

		antialiasing = target.antialiasing;

		updateHitbox();
		centerOffsets();

		var globalAffected:Bool = (target != null && (target.defaultAffectedByColor || target.affectedbycolor)) || this.affectedbycolor;

		if (globalAffected) {
			if (sourceNote != null && sourceNote.customNoteColor != null) {
				colorSwap.r = sourceNote.customNoteColor[0];
				colorSwap.g = sourceNote.customNoteColor[1];
				colorSwap.b = sourceNote.customNoteColor[2];
				affectedbycolor = true;
			} else if (sourceNote != null && sourceNote.affectedbycolor && sourceNote.colorSwap != null) {
				colorSwap.r = sourceNote.colorSwap.r;
				colorSwap.g = sourceNote.colorSwap.g;
				colorSwap.b = sourceNote.colorSwap.b;
				affectedbycolor = true;
			} else if (target != null && target.colorSwap != null) {
				colorSwap.r = target.colorSwap.r;
				colorSwap.g = target.colorSwap.g;
				colorSwap.b = target.colorSwap.b;
				affectedbycolor = target.affectedbycolor;
			} else {
				noteColor = NoteColors.getNoteColor(NoteVariables.animationDirections[localKeyCount - 1][noteData]);
				if (colorSwap != null && noteColor != null) {
					colorSwap.r = noteColor[0];
					colorSwap.g = noteColor[1];
					colorSwap.b = noteColor[2];
				}
				affectedbycolor = true;
			}
		} else {
			affectedbycolor = false;
		}

		shader = affectedbycolor ? colorSwap.shader : null;
		update(0);
	}

	override function update(elapsed:Float) {
		if (target != null) {
			x = target.x - (target.width / 1.5);
			y = target.y - (target.height / 1.5);
			color = target.color;
			flipX = target.flipX;
			flipY = target.flipY;
			angle = target.angle;
			alpha = target.alpha;
			visible = target.visible;
		}

		super.update(elapsed);
	}
}
