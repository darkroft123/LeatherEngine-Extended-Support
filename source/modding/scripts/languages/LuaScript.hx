package modding.scripts.languages;

#if LUA_ALLOWED
#if MODCHARTING_TOOLS
import modcharting.ModchartFuncs;
#end
import modding.helpers.FlxTweenUtil;
import flixel.addons.effects.FlxTrail;
import openfl.display.BlendMode;
import flixel.FlxCamera;
import game.DancingSprite;
import game.Boyfriend;
import ui.HealthIcon;
import hxnoise.Perlin;
import utilities.NoteVariables;
import game.Note;
import flixel.math.FlxMath;
import openfl.filters.ShaderFilter;
import openfl.filters.BitmapFilter;
import flixel.math.FlxPoint;
import shaders.custom.CustomShader;
import game.Character;
import flixel.util.FlxColor;
import llua.Convert;
import llua.Lua;
import llua.Lua.Lua_helper;
import llua.State;
import llua.LuaL;
import flixel.FlxBasic;
import flixel.FlxSprite;
import states.PlayState;
import lime.utils.Assets;
import flixel.sound.FlxSound;
#if MODDING_ALLOWED
import polymod.backends.PolymodAssets;
#end
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.FlxG;
import game.Conductor;
import lime.app.Application;
import flixel.text.FlxText;
import haxe.Json;
import flixel.util.FlxStringUtil;
import openfl.display.ShaderParameter;
import modcharting.FlxSprite3D;
import flixel.perspective.PerspectiveSprite;
import flixel.perspective.PerspectiveText;
import shaders.RTXShader;
import openfl.display.BitmapData;
import flixel.addons.display.FlxBackdrop;
import flixel.addons.display.FlxGridOverlay;
import ui.AudioVisualizer;


typedef LuaCamera = {
	var cam:FlxCamera;
	var shaders:Array<BitmapFilter>;
	var shaderNames:Array<String>;
}

class LuaScript extends Script {
	public var lua:State = null;

	public static var lua_Sprites:Map<String, FlxSprite>;
	public static var lua_Characters:Map<String, Character>;
	public static var lua_Sounds:Map<String, FlxSound>;
	public static var lua_Shaders:Map<String, shaders.Shaders.ShaderEffect>;
	public static var lua_Custom_Shaders:Map<String, CustomShader>;
	public static var lua_Cameras:Map<String, LuaCamera>;
	public static var lua_CreatedCameras:Array<FlxCamera>;
	public static var lua_Jsons:Map<String, Dynamic>;
	public static var lua_Tweens:Map<String, FlxTween>;

	public static var lua_AddedCharacters:Map<String, Array<Character>> = new Map();
	public static var lua_CharDuplicates:Array<Dynamic> = [];
	public static var lua_OwnedCharIds:Map<String, Character> = new Map();
	public static var lua_DuplicateCounters:Map<String, Int> = new Map();
	public static var lua_GroupShells:Map<String, Dynamic> = new Map();
	public static var lua_SavedPositions:Map<String, {x:Float, y:Float}> = new Map();

	static var charSyncHooked:Bool = false;
	static var charSyncCallback:Void->Void = null;

	public static function resetAllStaticMaps():Void {
		purgeAddedCharacters();
		if (lua_Sprites != null) { for (k in lua_Sprites.keys()) { var s = lua_Sprites.get(k); if (s != null && k != "boyfriend" && k != "girlfriend" && k != "dad") { s.kill(); s.destroy(); } } lua_Sprites.clear(); }
		if (lua_Characters != null) lua_Characters.clear();
		if (lua_Sounds != null) { for (s in lua_Sounds) { if (s != null) { s.stop(); s.destroy(); } } lua_Sounds.clear(); }
		if (lua_Shaders != null) lua_Shaders.clear();
		if (lua_Custom_Shaders != null) lua_Custom_Shaders.clear();
		if (lua_Cameras != null) lua_Cameras.clear();
		if (lua_CreatedCameras != null) lua_CreatedCameras = [];
		if (lua_Jsons != null) lua_Jsons.clear();
		if (lua_Tweens != null) { for (t in lua_Tweens) { if (t != null) { t.cancel(); t.destroy(); } } lua_Tweens.clear(); }
		if (lua_SavedPositions != null) lua_SavedPositions.clear();
	}

	static function ensureMapsInitialized():Void {
		if (lua_Sprites == null) {
			lua_Sprites = new Map();
			lua_Characters = new Map();
			lua_Sounds = new Map();
			lua_Shaders = new Map();
			lua_Custom_Shaders = new Map();
			lua_Cameras = new Map();
			lua_CreatedCameras = [];
			lua_Jsons = new Map();
			lua_Tweens = new Map();
			lua_SavedPositions = new Map();
		}
	}

	function initDefaultSprites():Void {
		ensureMapsInitialized();
		if (PlayState.boyfriend != null) lua_Sprites.set('boyfriend', PlayState.boyfriend);
		if (PlayState.gf != null) lua_Sprites.set('girlfriend', PlayState.gf);
		if (PlayState.dad != null) lua_Sprites.set('dad', PlayState.dad);
		if (PlayState.boyfriend != null) lua_Characters.set('boyfriend', PlayState.boyfriend);
		if (PlayState.gf != null) lua_Characters.set('girlfriend', PlayState.gf);
		if (PlayState.dad != null) lua_Characters.set('dad', PlayState.dad);
	}
	/// Whether the current song is being played from the opponent side.
	static function getLuaTableVal(props:Dynamic, key:String):Dynamic {
		if (props == null) return null;
		if (Std.isOfType(props, haxe.ds.StringMap)) {
			var map:haxe.ds.StringMap<Dynamic> = cast props;
			return map.get(key);
		}
		if (Reflect.hasField(props, key)) {
			return Reflect.field(props, key);
		}
		try {
			return Reflect.getProperty(props, key);
		} catch (e:Dynamic) { Main.logSilentError(e, "LuaScript: Reflect.getProperty fallback"); }
		return null;
	}

	function resolveCharAlias(id:String):Dynamic {
		return switch(id.toLowerCase().trim()) {
			case 'dad' | 'opponent': PlayState.dad;
			case 'boyfriend' | 'bf': PlayState.boyfriend;
			case 'girlfriend' | 'gf': PlayState.gf;
			default: null;
		};
	}

	function resolveSpriteTarget(id:Dynamic):Dynamic {
		var idStr:String = Std.string(id);
		var char = getCharacterByName(idStr);
		if (char != null && char.otherCharacters != null && char.otherCharacters.length > 0)
			return char.otherCharacters[0];
		return getActorByName(idStr);
	}


	static function charSideFromString(side:String):String {
		return switch ((side == null ? "" : side).toLowerCase().trim()) {
			case "dad" | "opponent" | "player2" | "enemy" | "1": 'dad';
			case "gf" | "girlfriend" | "player3" | "2": 'gf';
			case "player" | "bf" | "boyfriend" | "player1" | "0": 'bf';
			default: 'dad';
		};
	}

	static function getSideMainCharacter(side:String):Character {
		return switch (side) {
			case 'dad': PlayState.dad;
			case 'gf': PlayState.gf;
			default: PlayState.boyfriend;
		};
	}

	static function getSideOriginalCharacters(side:String):Array<Character> {
		var main = getSideMainCharacter(side);
		if (main == null) return [];

		if (main.otherCharacters != null && main.otherCharacters.length > 0) {
			var added = getAddedCharactersOrNull(side);
			var list:Array<Character> = [];

			for (char in main.otherCharacters)
				if (char != null && (added == null || added.indexOf(char) == -1)) list.push(char);

			return list;
		}

		return [main];
	}

	static function getAddedCharactersOrNull(side:String):Array<Character> {
		if (lua_AddedCharacters == null) return null;
		return lua_AddedCharacters.get(side);
	}

	static function getSideGroupAnchor(side:String):Character {
		var main = getSideMainCharacter(side);
		if (main == null) return null;

		if (main.otherCharacters != null && main.otherCharacters.length > 0) {
			var id = (main.mainCharacterID >= 0 && main.mainCharacterID < main.otherCharacters.length) ? main.mainCharacterID : 0;
			return main.otherCharacters[id];
		}

		return main;
	}

	static function getAddedCharacters(side:String):Array<Character> {
		if (lua_AddedCharacters == null) lua_AddedCharacters = new Map();
		if (!lua_AddedCharacters.exists(side)) lua_AddedCharacters.set(side, []);
		return lua_AddedCharacters.get(side);
	}

	static function getSideIdPrefixes(side:String):Array<String> {
		return switch (side) {
			case 'dad': ["dad", "dadCharacter"];
			case 'gf': ["gf", "gfCharacter"];
			default: ["bf", "bfCharacter"];
		};
	}

	static function getSideCharacterIds(side:String):Array<String> {
		var prefixes = getSideIdPrefixes(side);
		var all = getSideOriginalCharacters(side).concat(getAddedCharacters(side));
		var ids:Array<String> = [];

		for (i in 0...all.length) {
			if (all[i] == null) continue;
			ids.push(prefixes[0] + i);
			ids.push(prefixes[1] + i);
		}

		return ids;
	}

	static function unregisterOwnedCharIds(char:Character):Void {
		if (lua_OwnedCharIds == null || char == null) return;

		var toRemove:Array<String> = [];

		for (key => owned in lua_OwnedCharIds)
			if (owned == char) toRemove.push(key);

		for (key in toRemove) {
			lua_OwnedCharIds.remove(key);
			if (lua_Sprites != null && lua_Sprites.get(key) == char) lua_Sprites.remove(key);
			if (lua_Characters != null && lua_Characters.get(key) == char) lua_Characters.remove(key);
		}
	}

	static function registerOwnedCharId(id:String, char:Character):Void {
		if (lua_OwnedCharIds == null) lua_OwnedCharIds = new Map();

		var previous = lua_OwnedCharIds.get(id);
		if (previous != null && previous != char) unregisterOwnedCharIds(previous);

		lua_OwnedCharIds.set(id, char);

		if (lua_Sprites != null) lua_Sprites.set(id, char);
		if (lua_Characters != null) lua_Characters.set(id, char);
	}

	static function refreshSideIds(side:String):Void {
		if (lua_Sprites == null || lua_Characters == null) return;

		var prefixes = getSideIdPrefixes(side);
		var originals = getSideOriginalCharacters(side);
		var all = originals.concat(getAddedCharacters(side));

		for (i in 0...all.length) {
			var char = all[i];
			if (char == null) continue;

			lua_Sprites.set(prefixes[0] + i, char);
			lua_Characters.set(prefixes[0] + i, char);
			lua_Sprites.set(prefixes[1] + i, char);
			lua_Characters.set(prefixes[1] + i, char);
		}

		var stale:Array<String> = [];

		for (key => owned in lua_OwnedCharIds) {
			if (owned == null) {
				stale.push(key);
			} else {
				var charSide = findSideOfCharacter(owned);
				if (charSide != null && charSide == side && all.indexOf(owned) == -1) {
					stale.push(key);
				}
			}
		}

		for (key in stale) {
			var owned = lua_OwnedCharIds.get(key);
			lua_OwnedCharIds.remove(key);
			if (lua_Sprites != null && lua_Sprites.get(key) == owned) lua_Sprites.remove(key);
			if (lua_Characters != null && lua_Characters.get(key) == owned) lua_Characters.remove(key);
		}
	}

	static function findSideOfCharacter(char:Character):String {
		if (char == null || lua_AddedCharacters == null) return null;

		for (side => list in lua_AddedCharacters)
			if (list != null && list.indexOf(char) != -1) return side;

		return null;
	}

	static function findSideOfMainCharacter(char:Character):String {
		if (char == null) return null;

		for (side in ["dad", "bf", "gf"])
			for (member in getSideOriginalCharacters(side))
				if (member == char) return side;

		return null;
	}

	static function uniqueDuplicateId(base:String):String {
		if (lua_DuplicateCounters == null) lua_DuplicateCounters = new Map();

		var count:Int = lua_DuplicateCounters.exists(base) ? lua_DuplicateCounters.get(base) : 0;
		var id = "";

		do {
			count++;
			id = base + "_dup" + count;
		} while ((lua_Characters != null && lua_Characters.exists(id)) || (lua_Sprites != null && lua_Sprites.exists(id)));

		lua_DuplicateCounters.set(base, count);
		return id;
	}

	static function applyActorScale(actor:Dynamic, scaleX:Float, scaleY:Float):Void {
		if (actor == null) return;

		if (!Std.isOfType(actor, Character)) {
			actor.setGraphicSize(actor.width * scaleX, actor.height * scaleY);
			return;
		}

		var c:Character = cast actor;
		var prevScaleX:Float = c.scale.x;
		var prevScaleY:Float = c.scale.y;
		var prevWidth:Float = c.width;
		var prevHeight:Float = c.height;
		var prevOffsetX:Float = c.positioningOffset[0];
		var prevOffsetY:Float = c.positioningOffset[1];

		var baseScale:Float = c.graphicSize;
		var newScaleX:Float = baseScale * scaleX;
		var newScaleY:Float = baseScale * scaleY;


		c.scale.set(newScaleX, newScaleY);

		var ratioX:Float = (prevScaleX != 0) ? newScaleX / prevScaleX : 1.0;
		var ratioY:Float = (prevScaleY != 0) ? newScaleY / prevScaleY : 1.0;
		var offsetX:Float = prevOffsetX * ratioX;
		var offsetY:Float = prevOffsetY * ratioY;

		c.positioningOffset[0] = offsetX;
		c.positioningOffset[1] = offsetY;

		c.x += prevWidth * (1 - ratioX) / 2 + (prevOffsetX - offsetX);
		c.y += prevHeight * (1 - ratioY) + (prevOffsetY - offsetY);

		
		c.updateAnimOffsets();
	}

	
	function insertCharacterIntoPlayState(char:Character, after:Character):Void {
		if (char == null || PlayState.instance == null) return;

		var ps = PlayState.instance;

		if (char.coolTrail != null) {
			ps.remove(char.coolTrail);
			ps.add(char.coolTrail);
		}

		var idx = (after != null) ? ps.members.indexOf(after) : -1;

		if (idx >= 0)
			ps.insert(idx + 1, char);
		else
			ps.add(char);
	}

	static function getDrawableGroups():Array<Dynamic> {
		var groups:Array<Dynamic> = [];
		var ps = PlayState.instance;
		if (ps == null) return groups;

		var stage = ps.stage;
		if (stage != null) {
			groups.push(stage.members);
			if (stage.infrontOfGFSprites != null) groups.push(stage.infrontOfGFSprites.members);
			if (stage.foregroundSprites != null) groups.push(stage.foregroundSprites.members);
		}
		groups.push(ps.members);

		return groups;
	}

	static function setSideMainCharacter(side:String, char:Character):Void {
		if (char == null) return;

		var ps = PlayState.instance;

		switch (side) {
			case 'dad':
				PlayState.dad = char;

				if (ps != null && ps.cameraEventHandler != null) ps.cameraEventHandler.dad = char;

			case 'gf':
				PlayState.gf = char;

			default:
				PlayState.boyfriend = cast char;

				if (ps != null && ps.cameraEventHandler != null) ps.cameraEventHandler.boyfriend = cast char;
		}
	}

	static function syncSideGroupAfterCharacterChange(side:String):Void {
		if (lua_GroupShells == null || !lua_GroupShells.exists(side)) return;
		if (getSideMainCharacter(side) == lua_GroupShells.get(side).shell) return;

		var ps = PlayState.instance;
		var added = getAddedCharactersOrNull(side);

		if (added != null) {
			for (char in added) {
				if (char == null || !char.exists) continue;

				if (ps != null) {
					ps.remove(char);
					detachCharacterFromSideGroup(side, char);
				}

				char.destroy();
			}
		}

		if (lua_AddedCharacters != null) lua_AddedCharacters.remove(side);
		lua_GroupShells.remove(side);

		refreshSideIds(side);
	}

	static function createGroupShell(original:Character, isPlayer:Bool):Character {
		if (original == null) return null;

		var shell:Character = isPlayer
			? new Boyfriend(original.x, original.y, "", false, original.scaleMult)
			: new Character(original.x, original.y, "", false, false, original.scaleMult);

		if (shell == null) return null;

		shell.curCharacter = original.curCharacter;
		shell.icon = original.icon;
		shell.isPlayer = original.isPlayer;
		shell.flipX = original.flipX;
		shell.alpha = original.alpha;
		shell.color = original.color;
		shell.antialiasing = original.antialiasing;
		shell.graphicSize = original.graphicSize;
		shell.dancesLeftAndRight = original.dancesLeftAndRight;
		shell.offsetsFlipWhenEnemy = original.offsetsFlipWhenEnemy;
		shell.offsetsFlipWhenPlayer = original.offsetsFlipWhenPlayer;
		shell.swapLeftAndRightSingPlayer = original.swapLeftAndRightSingPlayer;
		shell.deathCharacter = original.deathCharacter;
		shell.singDuration = original.singDuration;
		shell.holdTime = original.holdTime;
		shell.positioningOffset = [original.positioningOffset[0], original.positioningOffset[1]];
		shell.cameraOffset = [original.cameraOffset[0], original.cameraOffset[1]];
		shell.scrollFactor.set(original.scrollFactor.x, original.scrollFactor.y);
		shell.zIndex = original.zIndex;
		shell.cameras = original.cameras;
		shell.visible = false;

		@:privateAccess shell.ignoreDraw = true;

		return shell;
	}

	static function trackGroupShell(side:String, shell:Character, original:Character):Void {
		if (lua_GroupShells == null) lua_GroupShells = new Map();

		var wasVisible:Bool = original.visible;
		var wasIgnoreDraw:Bool = false;

		@:privateAccess wasIgnoreDraw = original.ignoreDraw;

		lua_GroupShells.set(side, {
			shell: shell,
			original: original,
			visible: wasVisible,
			ignoreDraw: wasIgnoreDraw
		});
	}

	static function attachCharacterToSideGroup(side:String, char:Character, x:Float, y:Float):Character {
		var main = getSideMainCharacter(side);
		if (main == null || char == null) return null;

		var root = main;

		if (main.otherCharacters == null) {
			var shell = createGroupShell(main, side == 'bf');
			if (shell == null) return null;

			@:privateAccess shell.isCharacterGroup = true;
			shell.otherCharacters = [main];
			shell.mainCharacterID = 0;
			shell.activeCharacterID = 0;

			shell.followMainCharacter = true;
			shell.followAllCharacter = false;

			setSideMainCharacter(side, shell);
			trackGroupShell(side, shell, main);
			root = shell;
		}

		var anchor = getSideGroupAnchor(side);

		if (anchor != null) {
			char.positioningOffset[0] = x - anchor.x + anchor.positioningOffset[0];
			char.positioningOffset[1] = y - anchor.y + anchor.positioningOffset[1];
			char.scrollFactor.set(anchor.scrollFactor.x, anchor.scrollFactor.y);
			char.zIndex = anchor.zIndex;
			char.cameras = anchor.cameras;
		}

		char.setPosition(x, y);
		char.updateHitbox();

		root.otherCharacters.push(char);
		return root;
	}

	static function detachCharacterFromSideGroup(side:String, char:Character):Void {
		if (side == null || char == null) return;

		var main = getSideMainCharacter(side);
		if (main == null || main.otherCharacters == null) return;

		main.otherCharacters.remove(char);

		if (main.otherCharacters.length == 0) return;

		if (main.mainCharacterID > main.otherCharacters.length - 1) main.mainCharacterID = 0;
		if (main.activeCharacterID > main.otherCharacters.length - 1) main.activeCharacterID = main.mainCharacterID;

		if (lua_GroupShells != null && lua_GroupShells.exists(side)) {
			var remaining = getAddedCharactersOrNull(side);
			if (remaining == null || remaining.length == 0) restoreSideCharacter(side);
		}
	}

	static function restoreSideCharacter(side:String):Void {
		if (lua_GroupShells == null || !lua_GroupShells.exists(side)) return;

		var info = lua_GroupShells.get(side);
		lua_GroupShells.remove(side);

		var shell:Character = (info != null) ? info.shell : null;
		var original:Character = (info != null) ? info.original : null;

		if (shell != null) {
			if (shell.otherCharacters != null) {
				for (char in shell.otherCharacters.copy())
					if (char != null && char != original) shell.otherCharacters.remove(char);
			}

			shell.otherCharacters = null;
		}

		if (original != null) {
			@:privateAccess original.isCharacterGroup = false;
			@:privateAccess original.ignoreDraw = (info.ignoreDraw == true);
			original.visible = (info.visible == true);
			original.mainCharacterID = 0;
			original.activeCharacterID = 0;
			original.followMainCharacter = false;
			original.followAllCharacter = false;

			setSideMainCharacter(side, original);
		}

		if (shell != null) {
			shell.kill();
			shell.destroy();
		}
	}

	static function linkCharacterMirror(src:Character, dst:Character, mirrorAnim:Bool = true):Void {
		if (src == null || dst == null || src == dst) return;

		if (lua_CharDuplicates == null) lua_CharDuplicates = [];

		for (link in lua_CharDuplicates) {
			if (link.dst == dst) {
				link.src = src;
				link.anim = mirrorAnim;
				ensureCharSyncHook();
				return;
			}
		}

		lua_CharDuplicates.push({ src: src, dst: dst, anim: mirrorAnim });
		ensureCharSyncHook();
	}

	static function ensureCharSyncHook():Void {
		if (charSyncHooked) return;

		charSyncHooked = true;

		if (charSyncCallback == null)
			charSyncCallback = function() {
				syncMirroredCharacters();
			};

		FlxG.signals.postUpdate.add(charSyncCallback);
	}

	static function removeCharSyncHook():Void {
		if (!charSyncHooked) return;

		charSyncHooked = false;

		if (charSyncCallback != null) FlxG.signals.postUpdate.remove(charSyncCallback);
	}

	static function syncMirroredCharacters():Void {
		if (lua_CharDuplicates == null || lua_CharDuplicates.length == 0) return;

		var alive:Array<Dynamic> = [];

		for (link in lua_CharDuplicates) {
			var src:Character = link.src;
			var dst:Character = link.dst;

			if (src == null || dst == null) continue;

			alive.push(link);

			if (!link.anim) continue;

			var animName = src.curAnimName();
			if (animName == null || animName.length == 0) continue;

			//
			if (dst.curAnimName() != animName)
				dst.playAnim(animName, true);
		}

		lua_CharDuplicates = alive;
	}

	function removeRuntimeCharacter(char:Character):Void {
		if (char == null) return;

		var side = findSideOfCharacter(char);

		var owned:Array<Character> = [];
		var kept:Array<Dynamic> = [];

		if (lua_CharDuplicates != null) {
			for (link in lua_CharDuplicates) {
				if (link.src == char && link.dst != null && owned.indexOf(link.dst) == -1) owned.push(link.dst);
				if (link.src != char && link.dst != char) kept.push(link);
			}

			lua_CharDuplicates = kept;
		}

		unregisterOwnedCharIds(char);

		if (side != null) {
			var list = getAddedCharacters(side);
			list.remove(char);

			detachCharacterFromSideGroup(side, char);
			refreshSideIds(side);
		}

		destroyRuntimeCharacter(char);

		for (dup in owned) {
			unregisterOwnedCharIds(dup);
			destroyRuntimeCharacter(dup);
		}
	}

	static function destroyRuntimeCharacter(char:Character):Void {
		if (char == null) return;

		if (PlayState.instance != null) {
			if (char.coolTrail != null) PlayState.instance.remove(char.coolTrail);
			PlayState.instance.remove(char);
		}

		if (char.coolTrail != null) {
			char.coolTrail.kill();
			char.coolTrail.destroy();
		}

		char.kill();
		char.destroy();
	}

	public static function purgeAddedCharacters():Void {
		removeCharSyncHook();

		var chars:Array<Character> = [];

		if (lua_CharDuplicates != null) {
			for (link in lua_CharDuplicates) {
				var dst:Character = link.dst;
				if (dst != null && chars.indexOf(dst) == -1) chars.push(dst);
			}
			lua_CharDuplicates = [];
		}

		if (lua_AddedCharacters != null) {
			for (side => list in lua_AddedCharacters) {
				if (list == null) continue;
				for (char in list) if (char != null && chars.indexOf(char) == -1) chars.push(char);
			}
		}

		for (side in ["dad", "bf", "gf"]) {
			var list = getAddedCharactersOrNull(side);
			if (list != null) for (char in list.copy()) detachCharacterFromSideGroup(side, char);

			restoreSideCharacter(side);
		}

		if (lua_AddedCharacters != null) lua_AddedCharacters.clear();
		if (lua_GroupShells != null) lua_GroupShells.clear();

		if (lua_OwnedCharIds != null) {
			for (key => owned in lua_OwnedCharIds) {
				if (chars.indexOf(owned) == -1) continue;
				if (lua_Sprites != null && lua_Sprites.get(key) == owned) lua_Sprites.remove(key);
				if (lua_Characters != null && lua_Characters.get(key) == owned) lua_Characters.remove(key);
			}
			lua_OwnedCharIds.clear();
		}

		if (lua_DuplicateCounters != null) lua_DuplicateCounters.clear();

		for (char in chars) destroyRuntimeCharacter(char);
	}

	function resolveLuaCharacter(id:String):Character {
		if (id == null || id.length == 0) return null;

		var char = getCharacterByName(id);
		if (!Std.isOfType(char, Character)) char = getActorByName(id);
		if (!Std.isOfType(char, Character)) return null;

		var resolved:Character = cast char;

		var isShell:Bool = false;
		@:privateAccess isShell = resolved.ignoreDraw;

		if (isShell && resolved.otherCharacters != null && resolved.otherCharacters.length > 0)
			resolved = resolved.getMainCharacter();

		return resolved;
	}

	function resolveSideCharacter(side:String):Character {
		return getSideMainCharacter(charSideFromString(side));
	}

	function forEachHudIcon(fn:Dynamic->Void):Void {
		if (PlayState.instance.iconP1 != null)
			for (icon in PlayState.instance.iconP1) if (icon != null) fn(icon);
		if (PlayState.instance.iconP2 != null)
			for (icon in PlayState.instance.iconP2) if (icon != null) fn(icon);
	}

	function copySpriteProperties(src:Dynamic, dst:FlxSprite):Void {
		dst.loadGraphicFromSprite(src);
		dst.alpha = src.alpha;
		dst.angle = src.angle;
		dst.offset.set(src.offset.x, src.offset.y);
		dst.origin.set(src.origin.x, src.origin.y);
		dst.scale.set(src.scale.x, src.scale.y);
		dst.flipX = src.flipX;
		dst.flipY = src.flipY;
		dst.color = src.color;
		dst.antialiasing = src.antialiasing;
		dst.shader = src.shader;
		dst.active = false;
	}

	public function makeBarsHelper(tag:String = "bars", camera:String = "hud", r:Int = 0, g:Int = 0, b:Int = 0):Void {
		if (tag == null || tag.trim() == "") tag = "bars";
		var cam = cameraFromString(camera);
		var colorVal = FlxColor.fromRGB(r, g, b);

		var topTag = tag + "Top";
		var bottomTag = tag + "Bottom";

		var barTop:FlxSprite = lua_Sprites.get(topTag);
		if (barTop == null) {
			barTop = new FlxSprite(0, 0).makeGraphic(1280, 360, colorVal);
			barTop.origin.set(640, 0);
			barTop.cameras = [cam];
			lua_Sprites.set(topTag, barTop);
			lua_Sprites.set(tag, barTop);
			PlayState.instance.add(barTop);
		} else {
			barTop.color = colorVal;
			barTop.cameras = [cam];
		}

		var barBottom:FlxSprite = lua_Sprites.get(bottomTag);
		if (barBottom == null) {
			barBottom = new FlxSprite(0, 360).makeGraphic(1280, 360, colorVal);
			barBottom.origin.set(640, 360);
			barBottom.cameras = [cam];
			lua_Sprites.set(bottomTag, barBottom);
			PlayState.instance.add(barBottom);
		} else {
			barBottom.color = colorVal;
			barBottom.cameras = [cam];
		}

		barTop.scale.y = 0;
		barBottom.scale.y = 0;
	}

	public function setBarEffectHelper(tag:String = "bars", effect:Float = 0, ?angleVal:Null<Float>):Void {
		if (tag == null || tag.trim() == "") tag = "bars";
		var topTag = tag + "Top";
		var bottomTag = tag + "Bottom";

		var barTop:FlxSprite = lua_Sprites.get(topTag);
		var barBottom:FlxSprite = lua_Sprites.get(bottomTag);

		if (barTop == null || barBottom == null) {
			makeBarsHelper(tag, "hud", 0, 0, 0);
			barTop = lua_Sprites.get(topTag);
			barBottom = lua_Sprites.get(bottomTag);
		}

		if (barTop != null && barBottom != null) {
			var scaleY = effect * 2;
			barTop.scale.y = scaleY;
			barBottom.scale.y = scaleY;
			if (angleVal != null) {
				barTop.angle = angleVal;
				barBottom.angle = angleVal;
			}
		}
	}

	public function tweenBarEffectHelper(tag:String = "bars", targetEffect:Float = 0, duration:Float = 1.0, easeStr:String = "linear"):Void {
		if (tag == null || tag.trim() == "") tag = "bars";
		var topTag = tag + "Top";
		var bottomTag = tag + "Bottom";

		var barTop:FlxSprite = lua_Sprites.get(topTag);
		var barBottom:FlxSprite = lua_Sprites.get(bottomTag);

		if (barTop == null || barBottom == null) {
			makeBarsHelper(tag, "hud", 0, 0, 0);
			barTop = lua_Sprites.get(topTag);
			barBottom = lua_Sprites.get(bottomTag);
		}

		if (barTop == null || barBottom == null) return;

		var easeFunc = easeFromString(easeStr);
		if (easeFunc == null) easeFunc = FlxEase.linear;
		var targetScaleY = targetEffect * 2;

		var tweenTopKey = "tween" + topTag + "Scale";
		var tweenBotKey = "tween" + bottomTag + "Scale";

		if (lua_Tweens.exists(tweenTopKey)) {
			var t = lua_Tweens.get(tweenTopKey);
			if (t != null) { t.cancel(); t.destroy(); }
		}
		if (lua_Tweens.exists(tweenBotKey)) {
			var t = lua_Tweens.get(tweenBotKey);
			if (t != null) { t.cancel(); t.destroy(); }
		}

		lua_Tweens.set(tweenTopKey, FlxTween.tween(barTop.scale, {y: targetScaleY}, duration, {ease: easeFunc}));
		lua_Tweens.set(tweenBotKey, FlxTween.tween(barBottom.scale, {y: targetScaleY}, duration, {ease: easeFunc}));
	}

	public function setBarColorHelper(tag:String = "bars", r:Int = 0, g:Int = 0, b:Int = 0):Void {
		if (tag == null || tag.trim() == "") tag = "bars";
		var barTop:FlxSprite = lua_Sprites.get(tag + "Top");
		var barBottom:FlxSprite = lua_Sprites.get(tag + "Bottom");
		var colorVal = FlxColor.fromRGB(r, g, b);
		if (barTop != null) barTop.color = colorVal;
		if (barBottom != null) barBottom.color = colorVal;
	}

	function getActorByName(id:String):Dynamic {
		// Check explicit Lua sprites & characters first so custom sprites (e.g. 'opponent' fade sprite in vc3dNotes) don't collide with char aliases
		if (lua_Sprites.exists(id))
			return lua_Sprites.get(id);
		else if (lua_Characters.exists(id))
			return lua_Characters.get(id);

		var alias = resolveCharAlias(id);
		if (alias != null) return alias;
		else if (lua_Sounds.exists(id))
			return lua_Sounds.get(id);
		else if (lua_Shaders.exists(id))
			return lua_Shaders.get(id);
		else if (lua_Custom_Shaders.exists(id))
			return lua_Custom_Shaders.get(id);
		else if (lua_Cameras.exists(id))
			return lua_Cameras.get(id).cam;
		else if (lua_Jsons.exists(id))
			return lua_Jsons.get(id);

		if (PlayState.instance.stage != null) {
			var stg = PlayState.instance.stage;
			var stageProp = Reflect.getProperty(stg, id);
			if (stageProp != null) return stageProp;
			for (m in stg.members) {
				if (m != null && Reflect.getProperty(m, "name") == id)
					return m;
			}
		}

		if (Reflect.getProperty(PlayState.instance, id) != null)
			return Reflect.getProperty(PlayState.instance, id);
		else if (Reflect.getProperty(PlayState, id) != null)
			return Reflect.getProperty(PlayState, id);

		if (PlayState.strumLineNotes != null && PlayState.strumLineNotes.members != null) {
			if (id.startsWith("defaultStrum")) {
				var sIdx = Std.parseInt(id.substr(12));
				if (sIdx != null && sIdx >= 0 && sIdx < PlayState.strumLineNotes.members.length)
					return PlayState.strumLineNotes.members[sIdx];
			} else if (id.startsWith("strum") && !id.startsWith("strumLine")) {
				var sIdx = Std.parseInt(id.substr(5));
				if (sIdx != null && sIdx >= 0 && sIdx < PlayState.strumLineNotes.members.length)
					return PlayState.strumLineNotes.members[sIdx];
			}
			var num = Std.parseInt(id);
			if (num != null && num >= 0 && num < PlayState.strumLineNotes.members.length)
				return PlayState.strumLineNotes.members[num];
		}

		return null;
	}

	function getCharacterByName(id:String):Dynamic {
		var alias = resolveCharAlias(id);
		if (alias != null) return alias;

		if (lua_Characters.exists(id))
			return lua_Characters.get(id);

		return null;
	}

	function getCameraByName(id:String):LuaCamera {
		if (lua_Cameras.exists(id))
			return lua_Cameras.get(id);

		switch (id.toLowerCase().trim()) {
			case 'camgame' | 'game':
				return lua_Cameras.get("game");
			case 'camhud' | 'hud':
				return lua_Cameras.get("hud");
			case 'camother' | 'other':
				return lua_Cameras.get("other");
			case 'camnotes':
				return lua_Cameras.get("notes");
		}

		return lua_Cameras.get("game");
	}


	public static function killShaders() //dead
    {
        FlxG.game.setFilters([]);
        if (lua_Cameras != null) {
            for (cam in lua_Cameras)
            {
                cam.shaders = [];
                cam.shaderNames = [];
                cam.cam.filters = null;
            }
        }
        if (lua_Shaders != null) lua_Shaders.clear();
    }

	override public function destroy() {
			if (lua != null) {
				purgeAddedCharacters();

				for (cb in trailCallbacks)
					FlxG.signals.postUpdate.remove(cb);
				trailCallbacks.clear();
				trails.clear();

				for (key => sprite in lua_Sprites) {
					if (sprite != null && key != "boyfriend" && key != "girlfriend" && key != "dad") {
						if (PlayState.instance != null)
							PlayState.instance.remove(sprite);
						FlxTween.cancelTweensOf(sprite);
						if (sprite.scale != null) FlxTween.cancelTweensOf(sprite.scale);
						sprite.kill();
						sprite.destroy();
					}
				}
				lua_Sprites.clear();
				lua_Sprites.set('boyfriend', null);
				lua_Sprites.set('girlfriend', null);
				lua_Sprites.set('dad', null);

				for (key => sound in lua_Sounds) {
					if (sound != null && key != "Inst" && key != "Voices" && key.indexOf("Voices") != 0) {
						sound.stop();
						FlxG.sound.list.remove(sound);
						sound.destroy();
					}
				}
				lua_Sounds.clear();

				for (cam in lua_CreatedCameras) {
					if (cam != null) {
						FlxG.cameras.remove(cam, false);
						cam.destroy();
					}
				}
				lua_CreatedCameras = [];
				lua_Cameras.clear();

				lua_Shaders.clear();
				lua_Custom_Shaders.clear();
				lua_Jsons.clear();
				for (tween in lua_Tweens) {
					if (tween != null) {
						tween.cancel();
						tween.destroy();
					}
				}
				lua_Tweens.clear();

				Lua.close(lua);
				lua = null;
			}
			if (otherScripts != null) {
				for (s in otherScripts) {
					if (s != null)
						s.destroy();
				}
				otherScripts = null;
			}
		}

	function getLuaErrorMessage(l) {
		var v:String = Lua.tostring(l, -1);
		Lua.pop(l, 1);

		return v;
	}

	override public function set(name:String, value:Any):Void {
		Convert.toLua(lua, value);
		Lua.setglobal(lua, name);
	}


	public var trails:Map<String, FlxTrail> = [];
	public var trailCallbacks:Map<String, Void->Void> = [];

	public var perlin:Perlin;

	public var checkerBG:FlxBackdrop = null;
	public var checkerSize:Int = 40;

	/**
	 * Easy wrapper for `Lua_helper.add_callback`.
	 * @param name Function name
	 * @param func Function to use
	 */
	inline public function setFunction(names:Dynamic, func:Any):Void {
		if (Std.isOfType(names, Array)) {
			var namesArray:Array<Dynamic> = cast names;
			for (name in namesArray) {
				Lua_helper.add_callback(lua, Std.string(name), func);
			}
		} else {
			Lua_helper.add_callback(lua, Std.string(names), func);
		}
	}

	public function new(path:String, executeOn:ExecuteOn = BOTH) {
		super(path, executeOn);
		lua = LuaL.newstate();
		LuaL.openlibs(lua);

		perlin = new Perlin();

		initDefaultSprites();

		if (!lua_Cameras.exists("game"))
			lua_Cameras.set("game", {cam: PlayState.instance.camGame, shaders: [], shaderNames: []});
		if (!lua_Cameras.exists("hud"))
			lua_Cameras.set("hud", {cam: PlayState.instance.camHUD, shaders: [], shaderNames: []});
		if (!lua_Cameras.exists("other"))
			lua_Cameras.set("other", {cam: PlayState.instance.camOther, shaders: [], shaderNames: []});

		lua_Sounds.set("Inst", FlxG.sound.music);

		lua_Sounds.set("Voices", PlayState.instance.vocals.members[0]);

		for (sound in 0...PlayState.instance.vocals.length) {
			lua_Sounds.set("Voices" + sound, PlayState.instance.vocals.members[sound]);
		}

		// trace("lua version: " + Lua.version());
		// trace("LuaJIT version: " + Lua.versionJIT());

		Lua.init_callbacks(lua);

		var result:Int = LuaL.dofile(lua, path); // execute le file

		if (result != 0) {
			CoolUtil.coolError("Lua ERROR:\n" + Lua.tostring(lua, result), "Leather Engine Modcharts");
			// return;
			// FlxG.switchState(new MainMenuState());
		}

		// get some fukin globals up in here bois
		set("songLower", PlayState.SONG.song.toLowerCase());
		set("difficulty", PlayState.storyDifficultyStr);
		set("bpm", Conductor.bpm);
		set("songBpm", PlayState.SONG.bpm);
		set("keyCount", PlayState.SONG.keyCount);
		set("playerKeyCount", PlayState.SONG.playerKeyCount);
		set("scrollspeed", PlayState.SONG.speed);
		set("fpsCap", Options.getData("maxFPS"));
		set("opponentPlay", PlayState.characterPlayingAs == 1);
		set("bot", Options.getData("botplay"));
		set("noDeath", Options.getData("noDeath"));
		set("downscroll", Options.getData("downscroll") == true ? 1 : 0); // fuck you compatibility
		set("downscrollBool", Options.getData("downscroll"));
		set("middlescroll", Options.getData("middlescroll"));
		set("flashingLights", Options.getData("flashingLights"));
		set("flashing", Options.getData("flashingLights"));
		set("distractions", true);
		set("cameraZooms", Options.getData("cameraZooms"));
		set("shaders", Options.getData("shaders"));

		set("animatedBackgrounds", Options.getData("animatedBGs"));
		set("charsAndBGs", Options.getData("charsAndBGs"));

		set("curStep", 0);
		set("curBeat", 0);
		set("stepCrochet", Conductor.stepCrochet / PlayState.songMultiplier);
		set("crochetUnscaled", Conductor.stepCrochet);
		set("crochet", Conductor.crochet / PlayState.songMultiplier);
		set("safeZoneOffset", Conductor.safeZoneOffset);

		set("hudZoom", PlayState.instance.camHUD.zoom);
		set("cameraZoom", FlxG.camera.zoom);

		set("cameraAngle", FlxG.camera.angle);
		set("camHudAngle", PlayState.instance.camHUD.angle);

		set("followXOffset", 0);
		set("followYOffset", 0);

		set("showOnlyStrums", false);
		set("strumLine1Visible", true);
		set("strumLine2Visible", true);

		// WHY DOES THIS OFFSET CURSTEP BY 500????????
		// WHAT THE FUCK????????????????
		// this is my fucking tf2 coconut
		/*set("screenWidth", FlxG.stage.window.display.currentMode.width);
		set("screenHeight", FlxG.stage.window.display.currentMode.height);*/
		set("windowWidth", FlxG.width);
		set("windowHeight", FlxG.height);

		set("hudWidth", PlayState.instance.camHUD.width);
		set("hudHeight", PlayState.instance.camHUD.height);

		set("mustHit", false);
		set("strumLineX", PlayState.instance.strumLine.x);
		set("strumLineY", PlayState.instance.strumLine.y);

		set("characterPlayingAs", PlayState.characterPlayingAs);
		set("inReplay", false);

		set("player1", PlayState.SONG.player1);
		set("player2", PlayState.SONG.player2);

		set("curStage", PlayState.SONG.stage);

		set("mobile", FlxG.onMobile);

		set("curMod", Options.getData("curMod"));
		set("developer", Options.getData("developer"));

		// other globals

		set('flxColor', {
			TRANSPARENT: 0x00000000,
			WHITE: 0xFFFFFFFF,
			GRAY: 0xFF808080,
			BLACK: 0xFF000000,

			GREEN: 0xFF008000,
			LIME: 0xFF00FF00,
			YELLOW: 0xFFFFFF00,
			ORANGE: 0xFFFFA500,
			RED: 0xFFFF0000,
			PURPLE: 0xFF800080,
			BLUE: 0xFF0000FF,
			BROWN: 0xFF8B4513,
			PINK: 0xFFFFC0CB,
			MAGENTA: 0xFFFF00FF,
			CYAN: 0xFF00FFFF,
		});

		set("conductor", {
			bpm: Conductor.bpm,
			crochet: Conductor.crochet,
			stepCrochet: Conductor.stepCrochet,
			songPosition: Conductor.songPosition,
			offset: Conductor.offset,
			safeFrames: Conductor.safeFrames,
			safeZoneOffset: Conductor.safeZoneOffset,
			bpmChangeMap: Conductor.bpmChangeMap,
			timeScaleChangeMap: Conductor.timeScaleChangeMap,
			timeScale: Conductor.timeScale,
			stepsPerSection: Conductor.stepsPerSection,
		});

		set("flxG", {
			width: FlxG.width,
			height: FlxG.height,
			elapsed: FlxG.elapsed,
		});

		set("flxMath", {
			EPSILON: FlxMath.EPSILON,
			MAX_VALUE_FLOAT: FlxMath.MAX_VALUE_FLOAT,
			MAX_VALUE_INT: FlxMath.MAX_VALUE_INT,
			MIN_VALUE_FLOAT: FlxMath.MIN_VALUE_FLOAT,
			MIN_VALUE_INT: FlxMath.MIN_VALUE_INT,
			SQUARE_ROOT_OF_TWO: FlxMath.SQUARE_ROOT_OF_TWO,
		});

		set("haxeMath", {
			NEGATIVE_INFINITY: Math.NEGATIVE_INFINITY,
			NaN: Math.NaN,
			POSITIVE_INFINITY: Math.NEGATIVE_INFINITY,
		});

		set("lua", {
			version: Lua.version(),
			versionJIT: Lua.versionJIT(),
		});

		set("SONG", PlayState.SONG);

		set("leatherEngine", {
			version: CoolUtil.getCurrentVersion().replace('v', ''),
			path: Sys.programPath(),
			cwd: Sys.getCwd(),
			systemName: Sys.systemName(),
		});

		// callbacks
		setFunction(["trace", "print", "debugPrint"], function(str:Dynamic, printType:String = "LOG") {
			trace(str, printType.toUpperCase());
		});

		setFunction(["stopFlash", "flashCamera", "cameraFlash"], function(camera:String = "", color:String = "#FFFFFF", time:Float = 1, force:Bool = false) {
			if (Options.getData("flashingLights"))
				cameraFromString(camera).flash(FlxColor.fromString(color), time, null, force);
		});

		setFunction(["fadeCamera", "cameraFade"], function(camera:String = "", color:String = "#FFFFFF", time:Float = 1, fadeIn:Bool = false, force:Bool = false) {
			if (Options.getData("flashingLights"))
				cameraFromString(camera).fade(FlxColor.fromString(color), time, fadeIn, null, force);
		});

		setFunction("cameraShake", function(camera:String, intensity:Float, duration:Float) {
			var cam = cameraFromString(camera);
			if (cam != null)
				cam.shake(intensity, duration);
		});

		setFunction("cameraSetTarget", function(target:String) {
			var ps = PlayState.instance;
			if (ps == null) return;
			var char:Character = null;
			switch (target.toLowerCase()) {
				case "dad" | "opponent":
					char = PlayState.dad;
				case "gf" | "girlfriend":
					char = PlayState.gf;
				default:
					char = PlayState.boyfriend;
			}
			if (char != null && ps.cameraSystem != null) {
				ps.cameraSystem.update(char);
			}
		});

		setFunction("triggerEvent", function(event_name:String, argument_1:Dynamic, argument_2:Dynamic) {
			var string_arg_1:String = Std.string(argument_1);
			var string_arg_2:String = Std.string(argument_2);

			if (!PlayState.instance.scripts.exists(event_name.toLowerCase())
				&& Assets.exists(Paths.lua("event data/" + event_name.toLowerCase()))) {
				PlayState.instance.scripts.set(event_name.toLowerCase(),
					new LuaScript(Paths.getModPath(Paths.lua("event data/" + event_name.toLowerCase()))));
			}

			PlayState.instance.processEvent([event_name, Conductor.songPosition, string_arg_1, string_arg_2]);
		});

		setFunction("addCharacterToMap", function(m:String, character:String) {
			var map:Map<String, Dynamic>;

			switch (m.toLowerCase()) {
				case "dad" | "opponent" | "player2" | "1":
					map = PlayState.instance.dadMap;
				case "gf" | "girlfriend" | "player3" | "2":
					map = PlayState.instance.gfMap;
				default:
					map = PlayState.instance.bfMap;
			}
			var funnyCharacter:Character;

			if (map == PlayState.instance.bfMap)
				funnyCharacter = new Boyfriend(100, 100, character);
			else
				funnyCharacter = new Character(100, 100, character);

			funnyCharacter.alpha = 0.00001;
			PlayState.instance.add(funnyCharacter);

			map.set(character, funnyCharacter);

			if (funnyCharacter.otherCharacters != null) {
				for (character in funnyCharacter.otherCharacters) {
					character.alpha = 0.00001;
					PlayState.instance.add(character);
				}
			}
		});

		setFunction(["setCamera", "setObjectCamera"], function(id:String, camera:String = "") {
			var actor:FlxSprite = getActorByName(id);

			if (actor != null)
				Reflect.setProperty(actor, "cameras", [cameraFromString(camera)]);
		});

		setFunction("justPressedDodgeKey", function() {
			return FlxG.keys.justPressed.SPACE;
		});

		setFunction("justPressed", function(key:String = "SPACE") {
			return Reflect.getProperty(FlxG.keys.justPressed, key);
		});

		setFunction("pressed", function(key:String = "SPACE") {
			return Reflect.getProperty(FlxG.keys.pressed, key);
		});

		setFunction("justReleased", function(key:String = "SPACE") {
			return Reflect.getProperty(FlxG.keys.justReleased, key);
		});

		setFunction("setGraphicSize", function(id:String, width:Float = 0, height:Float = 0) {
			var actor:FlxSprite = getActorByName(id);

			if (actor != null)
				actor.setGraphicSize(width, height);
		});

		setFunction("updateHitbox", function(id:String) {
			var actor:FlxSprite = getActorByName(id);

			if (actor != null)
				actor.updateHitbox();
		});

		setFunction("setBlendMode", function(id:String, blend:String = '') {
			var actor:FlxSprite = getActorByName(id);

			if (actor != null)
				actor.blend = blendModeFromString(blend);
		});

		setFunction("getSingDirectionID", function(id:Int) {
			return
				['singLEFT', 'singDOWN', 'singUP', 'singRIGHT'].indexOf(NoteVariables.characterAnimations[PlayState.SONG.playerKeyCount - 1][Std.int(Math.abs(id % PlayState.SONG.playerKeyCount))]);
		});

		// sprites

		// stage

		setFunction("makeStageSprite", function(id:String, filename:String, x:Float, y:Float, size:Float = 1, ?sizeY:Float = null) {
		if (!lua_Sprites.exists(id)) {
			var Sprite:FlxSprite = new FlxSprite(x, y);

			if (filename != null && filename.length > 0)
				Sprite.loadGraphic(Paths.gpuBitmap(PlayState.instance.stage.stage + "/" + filename, "stages"));

			Sprite.scale.set(size, sizeY == null ? size : sizeY);
			Sprite.updateHitbox();
			adjustLuaSpriteScale(Sprite);

			lua_Sprites.set(id, Sprite);
			PlayState.instance.stage.add(Sprite);
		} else
			CoolUtil.coolError("Sprite " + id + " already exists! Choose a different name!", "Leather Engine Modcharts");
	});


		setFunction(["makeBars", "createCinematicBars", "makeLuaBars"], function(tag:String = "bars", camera:String = "hud", r:Int = 0, g:Int = 0, b:Int = 0) {
			makeBarsHelper(tag, camera, r, g, b);
		});

		setFunction("setBarEffect", function(arg1:Dynamic, ?arg2:Dynamic, ?arg3:Dynamic) {
			var tag:String = "bars";
			var effect:Float = 0;
			var angleVal:Null<Float> = null;

			if (Std.isOfType(arg1, String)) {
				tag = cast arg1;
				effect = arg2 != null ? cast arg2 : 0.0;
				if (arg3 != null && Std.isOfType(arg3, Float)) angleVal = cast arg3;
			} else {
				effect = arg1 != null ? cast arg1 : 0.0;
				if (arg2 != null && Std.isOfType(arg2, Float)) angleVal = cast arg2;
			}

			setBarEffectHelper(tag, effect, angleVal);
		});

		setFunction("tweenBarEffect", function(arg1:Dynamic, ?arg2:Dynamic, ?arg3:Dynamic, ?arg4:Dynamic) {
			var tag:String = "bars";
			var targetEffect:Float = 0;
			var duration:Float = 1.0;
			var easeStr:String = "linear";

			if (Std.isOfType(arg1, String)) {
				tag = cast arg1;
				targetEffect = arg2 != null ? cast arg2 : 0.0;
				duration = arg3 != null ? cast arg3 : 1.0;
				if (arg4 != null) easeStr = cast arg4;
			} else {
				targetEffect = arg1 != null ? cast arg1 : 0.0;
				if (arg2 != null) duration = cast arg2;
				if (arg3 != null) easeStr = cast arg3;
			}

			tweenBarEffectHelper(tag, targetEffect, duration, easeStr);
		});

		setFunction("setBarColor", function(arg1:Dynamic, ?arg2:Dynamic, ?arg3:Dynamic, ?arg4:Dynamic) {
			var tag:String = "bars";
			var r:Int = 0;
			var g:Int = 0;
			var b:Int = 0;

			if (Std.isOfType(arg1, String)) {
				tag = cast arg1;
				r = arg2 != null ? cast arg2 : 0;
				g = arg3 != null ? cast arg3 : 0;
				b = arg4 != null ? cast arg4 : 0;
			} else {
				r = arg1 != null ? cast arg1 : 0;
				g = arg2 != null ? cast arg2 : 0;
				b = arg3 != null ? cast arg3 : 0;
			}

			setBarColorHelper(tag, r, g, b);
		});

		setFunction(["tweenBars", "tweenBarProps"], function(tag:String, props:Dynamic, duration:Float = 1.0, ease:String = "linear") {
			var topTag = tag + "Top";
			var bottomTag = tag + "Bottom";

			var barTop:FlxSprite = lua_Sprites.get(topTag);
			var barBottom:FlxSprite = lua_Sprites.get(bottomTag);

			if (barTop == null || barBottom == null) {
				makeBarsHelper(tag, "hud", 0, 0, 0);
				barTop = lua_Sprites.get(topTag);
				barBottom = lua_Sprites.get(bottomTag);
			}

			if (barTop == null || barBottom == null) return;

			var easeFunc = easeFromString(ease);
			if (easeFunc == null) easeFunc = FlxEase.linear;

			var effVal = getLuaTableVal(props, "effect");
			if (effVal != null) {
				var targetEffect:Float = cast effVal;
				tweenBarEffectHelper(tag, targetEffect, duration, ease);
			}

			var angVal = getLuaTableVal(props, "angle1");
			if (angVal == null) angVal = getLuaTableVal(props, "angle");
			if (angVal != null) {
				var targetAngle:Float = cast angVal;
				FlxTween.tween(barTop, {angle: targetAngle}, duration, {ease: easeFunc});
				FlxTween.tween(barBottom, {angle: targetAngle}, duration, {ease: easeFunc});
			}

			var rVal = getLuaTableVal(props, "red"); if (rVal == null) rVal = getLuaTableVal(props, "r");
			var gVal = getLuaTableVal(props, "green"); if (gVal == null) gVal = getLuaTableVal(props, "g");
			var bVal = getLuaTableVal(props, "blue"); if (bVal == null) bVal = getLuaTableVal(props, "b");

			if (rVal != null || gVal != null || bVal != null) {
				var curR:Int = rVal != null ? Std.parseInt(Std.string(rVal)) : 0;
				var curG:Int = gVal != null ? Std.parseInt(Std.string(gVal)) : 0;
				var curB:Int = bVal != null ? Std.parseInt(Std.string(bVal)) : 0;
				var targetCol = FlxColor.fromRGB(curR, curG, curB);

				FlxTween.color(barTop, duration, barTop.color, targetCol, {ease: easeFunc});
				FlxTween.color(barBottom, duration, barBottom.color, targetCol, {ease: easeFunc});
			}
		});

		setFunction(["setBars", "setBarProps"], function(tag:String, props:Dynamic) {
			var effVal = getLuaTableVal(props, "effect");
			var angVal = getLuaTableVal(props, "angle1"); if (angVal == null) angVal = getLuaTableVal(props, "angle");
			if (effVal != null || angVal != null) {
				setBarEffectHelper(tag, effVal != null ? cast effVal : 0.0, angVal != null ? cast angVal : null);
			}

			var rVal = getLuaTableVal(props, "red"); if (rVal == null) rVal = getLuaTableVal(props, "r");
			var gVal = getLuaTableVal(props, "green"); if (gVal == null) gVal = getLuaTableVal(props, "g");
			var bVal = getLuaTableVal(props, "blue"); if (bVal == null) bVal = getLuaTableVal(props, "b");

			if (rVal != null || gVal != null || bVal != null) {
				var curR:Int = rVal != null ? Std.parseInt(Std.string(rVal)) : 0;
				var curG:Int = gVal != null ? Std.parseInt(Std.string(gVal)) : 0;
				var curB:Int = bVal != null ? Std.parseInt(Std.string(bVal)) : 0;
				setBarColorHelper(tag, curR, curG, curB);
			}
		});

		setFunction("makeStageAnimatedSprite", function(id:String, filename:String, x:Float, y:Float, size:Float = 1, ?sizeY:Float = null) {
			if (!lua_Sprites.exists(id)) {
				var Sprite:FlxSprite = new FlxSprite(x, y);

				if (filename != null && filename.length > 0)
					Sprite.frames = Paths.getSparrowAtlas(PlayState.instance.stage.stage + "/" + filename, "stages");

				Sprite.scale.set(size, sizeY == null ? size : sizeY);

				Sprite.updateHitbox();
				adjustLuaSpriteScale(Sprite);

				lua_Sprites.set(id, Sprite);

				PlayState.instance.stage.add(Sprite);
			} else
				CoolUtil.coolError("Sprite " + id + " already exists! Choose a different name!", "Leather Engine Modcharts");
		});

		setFunction("makeStageDancingSprite",
			function(id:String, filename:String, x:Float, y:Float, size:Float = 1, ?oneDanceAnimation:Bool, ?antialiasing:Bool, ?sizeY:Float = null) {
				if (!lua_Sprites.exists(id)) {
					var Sprite:DancingSprite = new DancingSprite(x, y, oneDanceAnimation, antialiasing);

					if (filename != null && filename.length > 0)
						Sprite.frames = Paths.getSparrowAtlas(PlayState.instance.stage.stage + "/" + filename, "stages");

					Sprite.scale.set(size, sizeY == null ? size : sizeY);

					Sprite.updateHitbox();
					adjustLuaSpriteScale(Sprite);

					lua_Sprites.set(id, Sprite);

					PlayState.instance.stage.add(Sprite);
				} else
					CoolUtil.coolError("Sprite " + id + " already exists! Choose a different name!", "Leather Engine Modcharts");
			});

		// regular

		setFunction("makeGraphic", function(id:String, width:Int, height:Int, color:String) {
			var actor = getActorByName(id);
			if (actor != null) {
				if (width > 64 || height > 64) {
					actor.makeGraphic(2, 2, FlxColor.fromString(color));
					actor.scale.set(width / 2, height / 2);
					actor.updateHitbox();
				} else {
					actor.makeGraphic(width, height, FlxColor.fromString(color));
				}
			}
		});

		setFunction("makeGraphicRGB", function(id:String, width:Int, height:Int, color:String) {
			var actor = getActorByName(id);
			if (actor != null) {
				actor.visible = true;
				var colors = color.split(',');
				var red = Std.parseInt(colors[0]);
				var green = Std.parseInt(colors[1]);
				var blue = Std.parseInt(colors[2]);
				var flxColor = FlxColor.fromRGB(red, green, blue);
				if (width > 64 || height > 64) {
					actor.makeGraphic(2, 2, flxColor);
					actor.scale.set(width / 2, height / 2);
					actor.updateHitbox();
				} else {
					actor.makeGraphic(width, height, flxColor);
				}
			}
		});

		setFunction(["exists", "luaSpriteExists"], function(id:String):Bool {
			var actor = getActorByName(id);
			if (actor != null)
				return Reflect.getProperty(actor, 'exists') == true;
			return lua_Sprites.exists(id);
		});

		setFunction(["color", "colorRGB", "colorRGBA"], function(r:Int, g:Int, b:Int, a:Int = 255):Int {
			return FlxColor.fromRGB(r, g, b, a);
		});

		setFunction("colorString", function(color:String):Int {
			return FlxColor.fromString(color);
		});

		setFunction("rgbToHsv", function(r:Int, g:Int, b:Int):Array<Int> {
			return CoolUtil.rgbToHsv(r, g, b);
		});

		setFunction("dominantColor", function(id:String):Int {
			var actor = getActorByName(id);
			return actor != null ? CoolUtil.dominantColor(actor) : 0;
		});

		setFunction("dominantColorFrame", function(id:String):Int {
			var actor = getActorByName(id);
			return actor != null ? CoolUtil.dominantColorFrame(actor) : 0;
		});

		// sprite functions

		setFunction(["screenCenter", "center"], function(id:String, ?direction:String = "xy") {
			var actor = getActorByName(id);
			if (actor != null)
				actor.screenCenter((direction.toLowerCase().contains('x') ? 0x01 : 0x00) + (direction.toLowerCase().contains('y') ? 0x10 : 0x00));
		});

		setFunction("actorScreenCenter", function(id:String) {
			var char = getCharacterByName(id);
			if (char != null && char.otherCharacters != null && char.otherCharacters.length > 0) {
				char.otherCharacters[0].screenCenter();
				return;
			}
			var actor = getActorByName(id);
			if (actor != null)
				actor.screenCenter();
		});

		setFunction("add", function(id:String) {
			FlxG.state.add(getActorByName(id));
		});

		setFunction("remove", function(id:String, splice:Bool = true) {
			FlxG.state.remove(getActorByName(id), splice);
		});

		setFunction("kill", function(id:String) {
			getActorByName(id).kill();
		});

		setFunction("destroy", function(id:String) {
			var actor:Dynamic = getActorByName(id);
			if (actor != null) {
				FlxTween.cancelTweensOf(actor);
				for (k in lua_Tweens.keys()) {
					if (k == id || k.startsWith(id + ".")) {
						var t = lua_Tweens.get(k);
						if (t != null) {
							t.cancel();
							t.destroy();
						}
						lua_Tweens.remove(k);
					}
				}

				if (lua_Sprites.exists(id)) lua_Sprites.remove(id);
				if (lua_Characters.exists(id)) lua_Characters.remove(id);
				
				if (Std.isOfType(actor, FlxBasic)) {
					var basic:FlxBasic = cast actor;
					PlayState.instance.remove(basic, true);
					FlxG.state.remove(basic, true);
					basic.kill();
					basic.destroy();
				}
			}
		});



		setFunction("insert", function(id:String, position:Int) {
			FlxG.state.insert(position, getActorByName(id));
		});

		setFunction("screenShake", function(?intensity:Float = 0.02, ?steps:Int = 4, ?fadeOut:Bool = true, ?camera:String = "both", ?easeStr:String = "quadOut")
		{
			var duration:Float = Conductor.stepCrochet * steps * 0.001;

			var ease = easeFromString(easeStr);
			if (ease == null) ease = FlxEase.quadOut;

			var targetCamera = cameraFromString(camera);
			var cameras:Array<FlxCamera> = [];

				cameras = [targetCamera];

			if (fadeOut)
			{
				for (cam in cameras)
				{
					PlayState.instance.tweenManager.num(intensity, 0, duration, {
						ease: ease,
						onUpdate: function(twn:FlxTween)
						{
							var val = FlxMath.lerp(intensity, 0, ease(twn.percent));
							cam.shake(val, 0.03);
						}
					});
				}
			}
			else
			{
				for (cam in cameras)
					cam.shake(intensity, duration);
			}
		});

		setFunction("screenShakeIn", function(
				?intensity:Float = 0.02,
				?steps:Int = 4,
				?camera:String = "both",
				?easeStr:String = "quadOut"
			)
			{
				var duration:Float = Conductor.stepCrochet * steps * 0.001;

				var ease = easeFromString(easeStr);
				if (ease == null) ease = FlxEase.quadOut;

				var cam:FlxCamera = cameraFromString(camera);

				cam.shake(0.000001, duration);

				PlayState.instance.tweenManager.num(0, intensity, duration, {
					ease: ease,
					onUpdate: function(twn:FlxTween)
					{
						var val = FlxMath.lerp(0, intensity, ease(twn.percent));
						Reflect.setField(cam, "_fxShakeIntensity", val);
					}
				});
			});






		// stage sprite functions

		setFunction(["addStage", "addstage"], function(id:String) {
			var actor = getActorByName(id);
			var stage = PlayState.instance != null ? PlayState.instance.stage : null;
			var ps = PlayState.instance;
			if (actor != null && stage != null) {
				if (ps != null && ps.members.indexOf(actor) != -1)
					ps.remove(actor, true);
				stage.add(actor);
			}
		});

		setFunction("removeStage", function(id:String, splice:Bool = true) {
			PlayState.instance.stage.remove(getActorByName(id), splice);
		});

		setFunction("insertStage", function(id:String, position:Int) {
			PlayState.instance.stage.insert(position, getActorByName(id));
		});

		setFunction("loadStageGraphic", function(id:String, imageName:String) {
		var stage = PlayState.instance.stage;
		if (stage == null) return;

		var spr:FlxSprite = stage.getNamedProp(id);
		if (spr == null) return;
		var dir = stage.stageData.imageDirectory ?? stage.stage;
		spr.loadGraphic(Paths.gpuBitmap(dir + "/" + imageName, "stages"));
		spr.updateHitbox();
		adjustLuaSpriteScale(spr);
	});

		setFunction(["setActorTextColor", "setTextColor"], function(id:String, color:String) {
			var actor = getActorByName(id);
			if (actor != null)
				Reflect.setProperty(actor, "color", FlxColor.fromString(color));
		});

		setFunction(["setActorText", "setTextString"], function(id:String, text:String) {
			var actor = getActorByName(id);
			if (actor != null)
				Reflect.setProperty(actor, "text", text);
		});

		setFunction(["setActorFont", "setTextFont"], function(id:String, font:String) {
			var actor = getActorByName(id);
			if (actor != null)
				Reflect.setProperty(actor, "font", Paths.font(font));
		});

		setFunction(["setActorOutlineColor", "setTextBorder"], function(id:String, arg2:Dynamic, ?arg3:String) {
			var actor = getActorByName(id);
			if (actor != null && Std.isOfType(actor, FlxText)) {
				var txt:FlxText = cast actor;
				if (arg3 != null) { // Psych: (tag, size, color)
					txt.borderSize = Std.parseFloat(Std.string(arg2));
					txt.borderColor = FlxColor.fromString(arg3);
					txt.borderStyle = FlxTextBorderStyle.OUTLINE;
				} else { // Leather: (id, color)
					txt.borderColor = FlxColor.fromString(Std.string(arg2));
				}
			} else if (actor != null) {
				Reflect.setProperty(actor, "borderColor", FlxColor.fromString(arg3 != null ? arg3 : Std.string(arg2)));
			}
		});

		setFunction(["setActorAlignment", "setTextAlignment"], function(id:String, align:String) {
			var actor = getActorByName(id);
			if (actor != null)
				Reflect.setProperty(actor, "alignment", align);
		});

		setFunction(["setTextSize", "setActorTextSize"], function(id:String, size:Int) {
			var actor = getActorByName(id);
			if (actor != null && Std.isOfType(actor, FlxText)) {
				cast(actor, FlxText).size = size;
			}
		});

		setFunction(["setTextWidth", "setActorTextWidth"], function(id:String, width:Float) {
			var actor = getActorByName(id);
			if (actor != null && Std.isOfType(actor, FlxText)) {
				cast(actor, FlxText).fieldWidth = width;
			}
		});

		setFunction(["getTextString", "getActorText"], function(id:String):String {
			var actor = getActorByName(id);
			if (actor != null && Std.isOfType(actor, FlxText)) {
				return cast(actor, FlxText).text;
			}
			return "";
		});

		setFunction("addLuaText", function(id:String) {
			var spr = lua_Sprites.get(id);
			if (spr != null) {
				PlayState.instance.add(spr);
			}
		});

		setFunction("makeLuaText", function(id:String, text:String, width:Float, x:Float, y:Float) {
			if (!lua_Sprites.exists(id)) {
				var leText:FlxText = new FlxText(x, y, width, text, 16);
				leText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
				leText.borderSize = 1;
				lua_Sprites.set(id, leText);
				PlayState.instance.add(leText);
			} else
				CoolUtil.coolError("Sprite " + id + " already exists! Choose a different name!", "Leather Engine Modcharts");
		});

		setFunction("makePerspectiveText", function(id:String, text:String, x:Float, y:Float, size:Int = 32, font:String = "vcr.ttf", fieldWidth:Float = 0) {
			if (!lua_Sprites.exists(id)) {
				var Sprite:PerspectiveText = new PerspectiveText(x, y, fieldWidth, text, size);
				Sprite.setFormat(Paths.font("vcr.ttf"), size, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE_FAST, FlxColor.TRANSPARENT);
				// Sprite.setFormat(Paths.font(font), size);
				Sprite.font = Paths.font(font);

				lua_Sprites.set(id, Sprite);

				PlayState.instance.add(Sprite);
			} else
				CoolUtil.coolError("Sprite " + id + " already exists! Choose a different name!", "Leather Engine Modcharts");
		});
		setFunction("makeText", function(id:String, text:String, x:Float, y:Float, size:Int = 32, font:String = "vcr.ttf", fieldWidth:Float = 0) {
			if (!lua_Sprites.exists(id)) {
				var Sprite:FlxText = new FlxText(x, y, fieldWidth, text, size);
				Sprite.setFormat(Paths.font("vcr.ttf"), size, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE_FAST, FlxColor.TRANSPARENT);
				// Sprite.setFormat(Paths.font(font), size);
				Sprite.font = Paths.font(font);

				lua_Sprites.set(id, Sprite);

				PlayState.instance.add(Sprite);
			} else
				CoolUtil.coolError("Sprite " + id + " already exists! Choose a different name!", "Leather Engine Modcharts");
		});

		setFunction("newText", function(id:String, text:String, x:Float, y:Float, size:Int = 32, font:String = "vcr.ttf", fieldWidth:Float = 0) {
			if (!lua_Sprites.exists(id)) {
				var Sprite:FlxText= new FlxText(x, y, fieldWidth, text, size);
				Sprite.font = Paths.font(font);

				lua_Sprites.set(id, Sprite);
			} else
				CoolUtil.coolError("Sprite " + id + " already exists! Choose a different name!", "Leather Engine Modcharts");
		});


		setFunction("newTextCopy", function(id:String, targetID:String) {
			var actor:Dynamic = getActorByName(targetID);

			if (!lua_Sprites.exists(id) && actor != null && Std.isOfType(actor, FlxText)) {
				var txt:FlxText = cast actor;

				var copy:FlxText = new FlxText(txt.x, txt.y, txt.fieldWidth, txt.text, txt.size);

				copy.setFormat(
					txt.font,
					txt.size,
					txt.color,
					txt.alignment,
					txt.borderStyle,
					txt.borderColor
				);

				copy.alpha = txt.alpha;
				copy.angle = txt.angle;
				copy.offset.x = txt.offset.x;
				copy.offset.y = txt.offset.y;
				copy.origin.x = txt.origin.x;
				copy.origin.y = txt.origin.y;
				copy.scale.x = txt.scale.x;
				copy.scale.y = txt.scale.y;
				copy.flipX = txt.flipX;
				copy.flipY = txt.flipY;
				copy.antialiasing = txt.antialiasing;
				copy.scrollFactor.set(txt.scrollFactor.x, txt.scrollFactor.y);
				copy.cameras = txt.cameras;
				copy.shader = txt.shader;

				lua_Sprites.set(id, copy);
				PlayState.instance.add(copy);
			}
		});

		setFunction("newSprite", function(id:String, filename:String, x:Float, y:Float, size:Float = 1, ?sizeY:Float = null) {
			if (!lua_Sprites.exists(id)) {
				var Sprite:FlxSprite = new FlxSprite(x, y);

				if (filename != null && filename.length > 0)
					Sprite.loadGraphic(Paths.gpuBitmap(filename));

				Sprite.scale.set(size, sizeY == null ? size : sizeY);

				Sprite.updateHitbox();
				adjustLuaSpriteScale(Sprite);

				lua_Sprites.set(id, Sprite);
			} else
				CoolUtil.coolError("Sprite " + id + " already exists! Choose a different name!", "Leather Engine Modcharts");
		});

		setFunction("newSpriteCopy", function(id:String, targetID:String) {
			var actor:FlxSprite = null;
			var char = getCharacterByName(targetID);
			if (char != null && char.otherCharacters != null && char.otherCharacters.length > 0)
				actor = char.otherCharacters[0];
			if (actor == null)
				actor = getActorByName(targetID);

			if (!lua_Sprites.exists(id) && actor != null) {
				var Sprite:FlxSprite = new FlxSprite(actor.x, actor.y);
				copySpriteProperties(actor, Sprite);
				Sprite.active = false;
				Sprite.cameras = actor.cameras;
				lua_Sprites.set(id, Sprite);
			}
		});

		setFunction("newAnimatedSprite", function(id:String, filename:String, x:Float, y:Float, size:Float = 1, ?sizeY:Float = null) {
			if (!lua_Sprites.exists(id)) {
				var Sprite:FlxSprite = new FlxSprite(x, y);

				if (filename != null && filename.length > 0)
					Sprite.frames = Paths.getSparrowAtlas(filename);

				Sprite.scale.set(size, sizeY == null ? size : sizeY);

				Sprite.updateHitbox();
				adjustLuaSpriteScale(Sprite);

				lua_Sprites.set(id, Sprite);
			} else
				CoolUtil.coolError("Sprite " + id + " already exists! Choose a different name!", "Leather Engine Modcharts");
		});

		setFunction("newDancingSprite",
			function(id:String, filename:String, x:Float, y:Float, size:Float = 1, ?oneDanceAnimation:Bool, ?antialiasing:Bool, ?sizeY:Float = null) {
				if (!lua_Sprites.exists(id)) {
					var Sprite:DancingSprite = new DancingSprite(x, y, oneDanceAnimation, antialiasing);

					if (filename != null && filename.length > 0)
						Sprite.frames = Paths.getSparrowAtlas(filename);

					Sprite.scale.set(size, sizeY == null ? size : sizeY);

					Sprite.updateHitbox();
					adjustLuaSpriteScale(Sprite);

					lua_Sprites.set(id, Sprite);
				} else
					CoolUtil.coolError("Sprite " + id + " already exists! Choose a different name!", "Leather Engine Modcharts");
			});
		setFunction("makePerspectiveSprite", function(id:String, filename:String, x:Float, y:Float, size:Float = 1, ?sizeY:Float = null) {
			if (!lua_Sprites.exists(id)) {
				var Sprite:PerspectiveSprite = new PerspectiveSprite(x, y);

				if (filename != null && filename.length > 0)
					Sprite.loadGraphic(Paths.gpuBitmap(filename));

				Sprite.scale.set(size, sizeY == null ? size : sizeY);

				Sprite.updateHitbox();
				adjustLuaSpriteScale(Sprite);

				lua_Sprites.set(id, Sprite);

				PlayState.instance.add(Sprite);
			} else
				CoolUtil.coolError("Sprite " + id + " already exists! Choose a different name!", "Leather Engine Modcharts");
		});

		setFunction(["makeSprite", "makeLuaSprite"], function(id:String, ?filename:String = null, ?x:Float = 0, ?y:Float = 0, size:Float = 1, ?sizeY:Float = null) {
			if (!lua_Sprites.exists(id)) {
				var Sprite:ReflectedSprite = new ReflectedSprite(x, y);

				if (filename != null && filename.length > 0)
					Sprite.loadGraphic(Paths.gpuBitmap(filename));

				Sprite.scale.set(size, sizeY == null ? size : sizeY);

				Sprite.updateHitbox();
				adjustLuaSpriteScale(Sprite);

				lua_Sprites.set(id, Sprite);

				PlayState.instance.add(Sprite);
			} else
				CoolUtil.coolError("Sprite " + id + " already exists! Choose a different name!", "Leather Engine Modcharts");
		});

		setFunction("makeSprite3D", function(id:String, filename:String, x:Float, y:Float, size:Float = 1, ?sizeY:Float = null) {
			if (!lua_Sprites.exists(id)) {
				var Sprite:FlxSprite3D = new FlxSprite3D(x, y);

				if (filename != null && filename.length > 0)
					Sprite.loadGraphic(Paths.gpuBitmap(filename));

				Sprite.scale.set(size, sizeY == null ? size : sizeY);

				Sprite.updateHitbox();
				adjustLuaSpriteScale(Sprite);

				lua_Sprites.set(id, Sprite);

				PlayState.instance.add(Sprite);
			} else
				CoolUtil.coolError("Sprite " + id + " already exists! Choose a different name!", "Leather Engine Modcharts");
		});

		setFunction("makeSpriteCopy", function(id:String, targetID:String) {
			var actor:Dynamic = null;
			var char = getCharacterByName(targetID);
			if (char != null && char.otherCharacters != null && char.otherCharacters.length > 0)
				actor = char.otherCharacters[0];
			else
				actor = char;
			if (actor == null)
				actor = getActorByName(targetID);

			if (!lua_Sprites.exists(id) && actor != null) {
				var Sprite:FlxSprite;

				if (Std.isOfType(actor, ReflectedSprite))
					Sprite = new ReflectedSprite(actor.x, actor.y);
				else
					Sprite = new FlxSprite(actor.x, actor.y);

				copySpriteProperties(actor, Sprite);

				if (actor.animation != null && actor.animation.curAnim != null)
					Sprite.animation.play(actor.animation.curAnim.name);

				if (Std.isOfType(actor, ReflectedSprite)) {
					var ref:ReflectedSprite = cast actor;
					var spr:ReflectedSprite = cast Sprite;
					spr.drawFlipped = ref.drawFlipped;
					spr.drawReflection = ref.drawReflection;
				}

				lua_Sprites.set(id, Sprite);
				PlayState.instance.add(Sprite);

			}
		});

		setFunction("makePerspectiveSpriteCopy", function(id:String, targetID:String) {
			var actor:PerspectiveSprite = null;
			var char = getCharacterByName(targetID);
			if (char != null && char.otherCharacters != null && char.otherCharacters.length > 0)
				actor = char.otherCharacters[0];

			if (actor == null)
				actor = getActorByName(targetID);

			if (!lua_Sprites.exists(id) && actor != null) {
				var Sprite:PerspectiveSprite = new PerspectiveSprite(actor.x, actor.y);

				Sprite.loadGraphicFromSprite(actor);

				Sprite.alpha = actor.alpha;
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
				Sprite.animation.curAnim = actor.animation.curAnim;
				Sprite.color = actor.color;
				Sprite.antialiasing = actor.antialiasing;
				Sprite.cameras = actor.cameras;
				Sprite.angleX = actor.angleX;
				Sprite.angleY = actor.angleY;
				Sprite.z = actor.z;
				Sprite.updateHitbox();
				lua_Sprites.set(id, Sprite);
				PlayState.instance.add(Sprite);
			}
		});

		setFunction(["makeAnimatedSprite", "makeAnimatedLuaSprite"], function(id:String, ?filename:String = null, ?x:Float = 0, ?y:Float = 0, size:Float = 1, ?sizeY:Float = null) {
			if (!lua_Sprites.exists(id)) {
				var Sprite:FlxSprite = new FlxSprite(x, y);

				if (filename != null && filename.length > 0)
					Sprite.frames = Paths.getSparrowAtlas(filename, null, false);

				Sprite.scale.set(size, sizeY == null ? size : sizeY);

				Sprite.updateHitbox();
				adjustLuaSpriteScale(Sprite);

				lua_Sprites.set(id, Sprite);

				PlayState.instance.add(Sprite);
			} else
				CoolUtil.coolError("Sprite " + id + " already exists! Choose a different name!", "Leather Engine Modcharts");
		});

		setFunction("makeAnimatedPerspectiveSprite", function(id:String, filename:String, x:Float, y:Float, size:Float = 1, ?sizeY:Float = null) {
			if (!lua_Sprites.exists(id)) {
				var Sprite:PerspectiveSprite = new PerspectiveSprite(x, y);

				if (filename != null && filename.length > 0)
					Sprite.frames = Paths.getSparrowAtlas(filename, null, false);

				Sprite.scale.set(size, sizeY == null ? size : sizeY);

				Sprite.updateHitbox();
				adjustLuaSpriteScale(Sprite);

				lua_Sprites.set(id, Sprite);

				PlayState.instance.add(Sprite);
			} else
				CoolUtil.coolError("Sprite " + id + " already exists! Choose a different name!", "Leather Engine Modcharts");
		});

		setFunction("makeDancingSprite",
			function(id:String, filename:String, x:Float, y:Float, size:Float = 1, ?oneDanceAnimation:Bool, ?antialiasing:Bool, ?sizeY:Float = null) {
				if (!lua_Sprites.exists(id)) {
					var Sprite:DancingSprite = new DancingSprite(x, y, oneDanceAnimation, antialiasing);

					if (filename != null && filename.length > 0)
						Sprite.frames = Paths.getSparrowAtlas(filename);

					Sprite.scale.set(size, sizeY == null ? size : sizeY);

					Sprite.updateHitbox();
					adjustLuaSpriteScale(Sprite);

					lua_Sprites.set(id, Sprite);

					PlayState.instance.add(Sprite);
				} else
					CoolUtil.coolError("Sprite " + id + " already exists! Choose a different name!", "Leather Engine Modcharts");
			});

		setFunction("addLuaSprite", function(id:String, ?front:Bool = false) {
			var spr = getActorByName(id);
			if (spr != null) {
				if (front) {
					PlayState.instance.add(spr);
				} else {
					var targetDad:Dynamic = PlayState.dad;
					if (targetDad != null && targetDad.otherCharacters != null && targetDad.otherCharacters.length > 0)
						targetDad = targetDad.otherCharacters[0];
					var dadIndex = (targetDad != null) ? PlayState.instance.members.indexOf(targetDad) : -1;
					if (dadIndex != -1)
						PlayState.instance.insert(dadIndex, spr);
					else
						PlayState.instance.add(spr);
				}
			}
		});

		setFunction(["destroySprite", "destroyGhost", "removeGhost", "removeLuaSprite", "removeLuaText"], function(id:String, ?destroy:Bool = true) {
			var sprite:FlxSprite = lua_Sprites.exists(id) ? lua_Sprites.get(id) : getActorByName(id);
			if (sprite == null || sprite == PlayState.dad || sprite == PlayState.boyfriend || sprite == PlayState.gf)
				return false;

			FlxTween.cancelTweensOf(sprite);
			for (k in lua_Tweens.keys()) {
				if (k == id || k.startsWith(id + ".")) {
					var t = lua_Tweens.get(k);
					if (t != null) {
						t.cancel();
						t.destroy();
					}
					lua_Tweens.remove(k);
				}
			}

			lua_Sprites.remove(id);
			lua_Characters.remove(id);

			PlayState.instance.remove(sprite, true);
			FlxG.state.remove(sprite, true);
			sprite.kill();
			sprite.destroy();

			return true;
		});

		setFunction(["getIsColliding", "objectsOverlap"], function(sprite1Name:String, sprite2Name:String) {
			var sprite1 = getActorByName(sprite1Name);

			if (sprite1 != null) {
				var sprite2 = getActorByName(sprite2Name);

				if (sprite2 != null)
					return sprite1.overlaps(sprite2);
			}

			return false;
		});

		setFunction("luaTextExists", function(tag:String):Bool {
			return lua_Sprites.exists(tag);
		});

		setFunction("luaSoundExists", function(tag:String):Bool {
			return lua_Sounds.exists(tag);
		});

		setFunction("addOffset", function(obj:String, anim:String, x:Float, y:Float) {
			var char = getCharacterByName(obj);
			if (char != null && Std.isOfType(char, Character)) {
				cast(char, Character).addOffset(anim, x, y);
			} else {
				var spr = getActorByName(obj);
				if (spr != null && Std.isOfType(spr, Character)) {
					cast(spr, Character).addOffset(anim, x, y);
				}
			}
		});


		setFunction("createCheckerBG", function(size:Int = 40,scale:Float = 4,alpha:Float = 0) {
			
			if (checkerBG != null) return;

			checkerSize = size;

			checkerBG = new FlxBackdrop(
				FlxGridOverlay.createGrid(
					size, size,
					FlxG.width, FlxG.height,
					true,
					FlxColor.BLACK,
					FlxColor.WHITE
				)
			);

			checkerBG.scale.set(scale, scale);
			checkerBG.alpha = alpha;
			checkerBG.blend = BlendMode.ADD;

			PlayState.instance.addBehindGF(checkerBG);
		});

		setFunction("setChecker", function(prop:String,value1:Float,value2:Float = 0) {
			if (checkerBG == null) return;

			switch (prop.toLowerCase()) {
				case "alpha":
					if (value2 <= 0)
						checkerBG.alpha = value1;
					else
						FlxTween.tween(checkerBG, { alpha: value1 }, value2);
				case "scale":
					checkerBG.scale.set(value1, value1);
				case "size":
					checkerSize = Std.int(value1);
					var newGrid = FlxGridOverlay.createGrid(
						checkerSize, checkerSize,
						FlxG.width, FlxG.height,
						true,
						FlxColor.BLACK,
						FlxColor.WHITE
					);

					checkerBG.loadGraphic(newGrid);
				case "speed":
					checkerBG.velocity.set(value1, value2);
				case "angle":
					checkerBG.angle = value1;
			}
		});


		setFunction("removeCheckerBG", function() {
			if (checkerBG == null) return;

			PlayState.instance.remove(checkerBG, true);
			checkerBG.destroy();
			checkerBG = null;
		});

		var doAddTrail = function(id:String, length:Int = 10, delay:Int = 1, alpha:Float = 0.4, diff:Float = 0.04) {
			var spr = getActorByName(id);
			if (spr == null) {
				trace("Trail " + id + " actor is null!!!");
				return;
			}
			if (trails.exists(id)) {
				var oldTrail = trails.get(id);
				PlayState.instance.remove(oldTrail);
				oldTrail.destroy();
				trails.remove(id);

				if (trailCallbacks.exists(id)) {
					FlxG.signals.postUpdate.remove(trailCallbacks.get(id));
					trailCallbacks.remove(id);
				}
			}
			var trail = new FlxTrail(spr, null, length, delay, alpha, diff);
			var idx = PlayState.instance.members.indexOf(spr);
			PlayState.instance.insert(idx > 0 ? idx : 0, trail);
			trail.cameras = spr.cameras;
			trail.scrollFactor.set(spr.scrollFactor.x, spr.scrollFactor.y);
			var cb:Void->Void = function() {
				if (spr != null && trail != null) {
					trail.visible = spr.visible;
					if (trail.alpha != spr.alpha)
						trail.alpha = spr.alpha;
					trail.cameras = spr.cameras;
				}
			};
			FlxG.signals.postUpdate.add(cb);
			trailCallbacks.set(id, cb);
			trails.set(id, trail);
		};

		var doRemoveTrail = function(id:String) {
			if (trails.exists(id)) {
				PlayState.instance.remove(trails.get(id));
				trails.get(id).destroy();
				trails.remove(id);

				if (trailCallbacks.exists(id)) {
					FlxG.signals.postUpdate.remove(trailCallbacks.get(id));
					trailCallbacks.remove(id);
				}
			}
			var char = getCharacterByName(id);
			if (char != null && char.coolTrail != null) {
				char.coolTrail.visible = false;
			}
		};

		setFunction("addActorTrail", doAddTrail);
		setFunction("removeActorTrail", doRemoveTrail);

		setFunction("setActorTrail", function(id:String, ?arg1:Dynamic, ?arg2:Dynamic, ?arg3:Dynamic, ?arg4:Dynamic) {
			if (arg1 != null && Std.isOfType(arg1, Bool)) {
				var enabled:Bool = cast arg1;
				if (enabled) {
					var len:Int = (arg2 != null && Std.isOfType(arg2, Int)) ? cast arg2 : 10;
					var del:Int = (arg3 != null && Std.isOfType(arg3, Int)) ? cast arg3 : 1;
					var alp:Float = (arg4 != null && (Std.isOfType(arg4, Float) || Std.isOfType(arg4, Int))) ? cast arg4 : 0.4;
					doAddTrail(id, len, del, alp, 0.04);
				} else {
					doRemoveTrail(id);
				}
			} else {
				var len:Int = (arg1 != null && Std.isOfType(arg1, Int)) ? cast arg1 : 10;
				var del:Int = (arg2 != null && Std.isOfType(arg2, Int)) ? cast arg2 : 1;
				var alp:Float = (arg3 != null && (Std.isOfType(arg3, Float) || Std.isOfType(arg3, Int))) ? cast arg3 : 0.4;
				var dif:Float = (arg4 != null && (Std.isOfType(arg4, Float) || Std.isOfType(arg4, Int))) ? cast arg4 : 0.04;
				doAddTrail(id, len, del, alp, dif);
			}
		});

		setFunction("makeCharacterGhost", function(tag:String, targetId:String, anim:String = "", offsetX:Float = 0, offsetY:Float = 0, fadeTime:Float = 0, colorStr:String = "") {
			var target:FlxSprite = getActorByName(targetId);
			if (target != null) {
				if (lua_Sprites.exists(tag)) {
					var old = lua_Sprites.get(tag);
					if (old != null) {
						PlayState.instance.remove(old, true);
						old.kill();
						old.destroy();
					}
					lua_Sprites.remove(tag);
				}

				var ghost = new FlxSprite(target.x + offsetX, target.y + offsetY);
				ghost.frames = target.frames;
				ghost.animation.copyFrom(target.animation);
				
				if (anim != "" && anim != null) {
					ghost.animation.play(anim, true);
				} else if (target.animation.curAnim != null) {
					ghost.animation.play(target.animation.curAnim.name, true, false, target.animation.curAnim.curFrame);
				}
				if (ghost.animation.curAnim != null) {
					ghost.animation.curAnim.pause();
				}

				if (Std.isOfType(target, Character)) {
					var char:Character = cast target;
					if (anim != "" && char.animOffsets.exists(anim)) {
						var off = char.animOffsets.get(anim);
						ghost.offset.set(off[0], off[1]);
					} else if (target.animation.curAnim != null && char.animOffsets.exists(target.animation.curAnim.name)) {
						var off = char.animOffsets.get(target.animation.curAnim.name);
						ghost.offset.set(off[0], off[1]);
					}
				}

				ghost.scale.set(target.scale.x, target.scale.y);
				ghost.updateHitbox();
				ghost.flipX = target.flipX;
				ghost.flipY = target.flipY;
				ghost.antialiasing = target.antialiasing;
				ghost.scrollFactor.set(target.scrollFactor.x, target.scrollFactor.y);
				ghost.cameras = target.cameras;
				ghost.alpha = target.alpha;

				if (colorStr != "" && colorStr != null) {
					ghost.color = FlxColor.fromString(colorStr);
				}

				lua_Sprites.set(tag, ghost);
				var targetIdx:Int = PlayState.instance.members.indexOf(target);
				if (targetIdx >= 0)
					PlayState.instance.insert(targetIdx, ghost);
				else
					PlayState.instance.add(ghost);

				if (fadeTime > 0) {
					FlxTween.tween(ghost, {alpha: 0}, fadeTime, {
						onComplete: function(twn:FlxTween) {
							if (lua_Sprites.get(tag) == ghost) lua_Sprites.remove(tag);
							PlayState.instance.remove(ghost, true);
							ghost.kill();
							ghost.destroy();
						}
					});
				}
			}
		});


		setFunction("getActorLayer", function(id:String) {
			var char = getCharacterByName(id);
			if (char != null && char.otherCharacters != null && char.otherCharacters.length > 0)
				return PlayState.instance.members.indexOf(char.otherCharacters[0]);

			var actor = getActorByName(id);
			return actor != null ? PlayState.instance.members.indexOf(actor) : -1;
		});

		setFunction("setActorLayer", function(id:String, layer:Int) {
			if (getCharacterByName(id) != null) {
				var character = getCharacterByName(id);
				if (character.otherCharacters != null && character.otherCharacters.length > 0) {
					PlayState.instance.remove(character.otherCharacters[0]);
					PlayState.instance.insert(layer, character.otherCharacters[0]);
					return;
				}
			}
			var actor = getActorByName(id);

			if (actor != null) {
				var curIdx:Int = PlayState.instance.members.indexOf(actor);
				if (curIdx == layer) return;
				if (trails.exists(id)) {
					PlayState.instance.remove(trails.get(id));
					PlayState.instance.insert(layer - 1, trails.get(id));
				}

				PlayState.instance.remove(actor);
				PlayState.instance.insert(layer, actor);
			}
		});

		setFunction("setActorBehindCharacters", function(id:String) {
			var actor = getActorByName(id);
			if (actor != null) {
				PlayState.instance.remove(actor);
				
				// Try to find the lowest character index in PlayState to insert behind them
				var insertIndex = PlayState.instance.members.length;
				
				var idxGF = PlayState.instance.members.indexOf(PlayState.gf);
				if (idxGF != -1 && idxGF < insertIndex) insertIndex = idxGF;
				
				var idxDad = PlayState.instance.members.indexOf(PlayState.dad);
				if (idxDad != -1 && idxDad < insertIndex) insertIndex = idxDad;
				
				var idxBf = PlayState.instance.members.indexOf(PlayState.boyfriend);
				if (idxBf != -1 && idxBf < insertIndex) insertIndex = idxBf;
				
				PlayState.instance.insert(insertIndex, actor);

			}
		});

	setFunction(["setStageLayer", "setstagelayer", "stagelayer", "stageLayer"], function(id:String, layer:Int) {
			var actor = getActorByName(id);
			var stage = PlayState.instance != null ? PlayState.instance.stage : null;
			var ps = PlayState.instance;
			if (actor != null && stage != null) {
				if (ps != null && ps.members.indexOf(actor) != -1)
					ps.remove(actor, true);
				stage.members.remove(actor);

				if (layer < 0) layer = 0;
				if (layer > stage.members.length) layer = stage.members.length;

				stage.members.insert(layer, actor);
			}
		});


		// health

	setFunction(["setActorBehindObject", "setactorbehindobject", "actorbehindobject", "actorBehindObject"], function(id:String, targetId:String) {
			var actor = getActorByName(id);
			var target = getActorByName(targetId);
			if (actor == null && PlayState.instance != null && PlayState.instance.stage != null)
				actor = PlayState.instance.stage.getNamedProp(id);
			if (target == null && PlayState.instance != null && PlayState.instance.stage != null)
				target = PlayState.instance.stage.getNamedProp(targetId);
			if (actor == null || target == null || actor == target) return;

			var groups = getDrawableGroups();
			if (groups.length == 0) return;

			var targetGroup:Dynamic = null;
			for (group in groups) {
				if (group.indexOf(target) != -1) {
					targetGroup = group;
					break;
				}
			}

			if (targetGroup == null) return;

			for (group in groups)
				group.remove(actor);

			var targetIdx:Int = targetGroup.indexOf(target);
			if (targetIdx == -1) return;

			targetGroup.insert(targetIdx, actor);
			actor.zIndex = target.zIndex - 1;
		});

		setFunction("getObjectOrder", function(id:String) {
			var actor = getActorByName(id);
			if (actor != null) {
				var idx = PlayState.instance.members.indexOf(actor);
				if (idx != -1) return idx;
				var stage = PlayState.instance.stage;
				if (stage != null) {
					idx = stage.members.indexOf(actor);
					if (idx != -1) return idx;
				}
			}
			return -1;
		});

		setFunction("setObjectOrder", function(id:String, order:Int) {
			var actor = getActorByName(id);
			if (actor != null) {
				var ps = PlayState.instance;
				var stage = ps.stage;

				if (stage != null && stage.members.indexOf(actor) != -1) {
					stage.members.remove(actor);
					if (order < 0) order = 0;
					if (order > stage.members.length) order = stage.members.length;
					stage.members.insert(order, actor);
				} else {
					ps.members.remove(actor);
					if (order < 0) order = 0;
					if (order > ps.members.length) order = ps.members.length;
					ps.members.insert(order, actor);
				}
			}
		});

		setFunction("getHealth", function() {
			return PlayState.instance.health;
		});

		setFunction("setHealth", function(heal:Float) {
			PlayState.instance.health = heal;
		});

		setFunction("getMinHealth", function() {
			return PlayState.instance.minHealth;
		});

		setFunction("getMaxHealth", function() {
			return PlayState.instance.maxHealth;
		});

		set('changeHealthRange', function(minHealth:Float, maxHealth:Float) {
			{
				var bar = PlayState.instance.healthBar;
				PlayState.instance.minHealth = minHealth;
				PlayState.instance.maxHealth = maxHealth;
				bar.setRange(minHealth, maxHealth);
			}
		});

		// hud/camera

		setFunction("setHudAngle", function(angle:Float) {

			PlayState.instance.camHUD.angle = angle;
		});

		setFunction("setHudPosition", function(x:Int, y:Int) {

			PlayState.instance.camHUD.x = x;
			PlayState.instance.camHUD.y = y;
		});

		setFunction("getHudX", function() {
			return PlayState.instance.camHUD.x;
		});

		setFunction("getHudY", function() {
			return PlayState.instance.camHUD.y;
		});

		setFunction("makeCamera", function(camStr:String) {
			var newCam:FlxCamera = new FlxCamera();
			newCam.bgColor.alpha = 0;
			PlayState.instance.reorderCameras(newCam);
			lua_Cameras.set(camStr, {cam: newCam, shaders: [], shaderNames: []});
			lua_CreatedCameras.push(newCam);
			PlayState.instance.usedLuaCameras = true;
		});

		setFunction("addCameraAboveHUD", function(camStr:String) {
			var newCam:FlxCamera = new FlxCamera();
			newCam.bgColor.alpha = 0;
			lua_Cameras.set(camStr, {cam: newCam, shaders: [], shaderNames: []});
			lua_CreatedCameras.push(newCam);
			PlayState.instance.usedLuaCameras = true;
			FlxG.cameras.add(newCam, false);
		});

		setFunction("setCamOtherBehindHUD", function()
		{
			var ps = PlayState.instance;

			FlxG.cameras.remove(ps.camOther, false);
			FlxG.cameras.remove(ps.camHUD, false);

			FlxG.cameras.add(ps.camOther, false);
			FlxG.cameras.add(ps.camHUD, false);
		});


		setFunction("setNoteCameras", function(camStr:String) {
			var cameras = camStr.split(',');
			var camList:Array<FlxCamera> = [];
			for (c in cameras) {
				var cam = getCameraByName(c);
				if (cam != null)
					camList.push(cam.cam);
			}
			if (camList.length > 0) {
				PlayState.strumLineNotes.cameras = camList;
				PlayState.instance.notes.cameras = camList;
				PlayState.instance.noteBG.camera = camList[0];
			}
		});

		setFunction("setObjectCameras", function(id:String, camStr:String) {
			var cameras = camStr.split(',');
			var actor:FlxSprite = getActorByName(id);
			var camList:Array<FlxCamera> = [];
			for (c in cameras) {
				var cam = getCameraByName(c);
				if (cam != null)
					camList.push(cam.cam);
			}
			if (camList.length > 0) {
				if (actor != null)
					Reflect.setProperty(actor, "cameras", camList);
			}
		});

		setFunction("getCameraScrollX", function(camStr:String) {
			var cam = getCameraByName(camStr);
			return cam != null ? cam.cam.scroll.x : 0.0;
		});

		setFunction("getCameraScrollY", function(camStr:String) {
			var cam = getCameraByName(camStr);
			return cam != null ? cam.cam.scroll.y : 0.0;
		});

	setFunction("setCamPosition", function(x:Float, y:Float) {

			if (PlayState.instance.cameraEventHandler != null) return;
			PlayState.instance.cameraSystem.setTarget(x, y, false, true);
		});
		setFunction("setCamOffset", function(x:Float, y:Float) {
			var ps = PlayState.instance;
			if (ps != null && ps.cameraSystem != null)
				ps.cameraSystem.camTweenOffset.set(x, y);
		});

		setFunction("tweenCamOffset", function(x:Float, y:Float, step:Float, c:Float, e:String) {

			var ps = PlayState.instance;
			if (ps == null || ps.cameraSystem == null) return;

			var t = step * 0.001 * c;
			var ease = easeFromString(e);

			ps.tweenManager.tween(ps.cameraSystem.camTweenOffset, {x: x, y: y}, t, {
				ease: ease
			});
		});
		setFunction("setCameraOffset", function(x:Float, y:Float) {

			var ps = PlayState.instance;
			if (ps == null) return;

			var cam = FlxG.camera;
			var oldLerp = cam.followLerp;

			cam.followLerp = 0;
			ps.cameraSystem.camTweenOffset.set(x, y);
			cam.followLerp = oldLerp;
		});


		setFunction("getCameraX", function() {
			return PlayState.instance.cameraSystem.camBase.x;
		});

		setFunction("getCameraY", function() {
			return PlayState.instance.cameraSystem.camBase.y;
		});

		setFunction("getCamZoom", function() {
			return FlxG.camera.zoom;
		});

		setFunction("getHudZoom", function() {
			return PlayState.instance.camHUD.zoom;
		});

		setFunction("setCamZoom", function(zoomAmount:Float) {
			if (PlayState.instance.cameraEventHandler != null) return;
			PlayState.instance.defaultCamZoom = zoomAmount;
			FlxG.camera.zoom = zoomAmount;
		});
		setFunction("tweenCamZoom", function(zoom:Float, step:Float, c:Float, e:String) {
			if (PlayState.instance.cameraEventHandler != null) return;

			var cam = FlxG.camera;
			if (cam == null) return;

			var t = step * 0.001 * c;
			var ease = easeFromString(e);

			var startZoom = PlayState.instance.defaultCamZoom;

			PlayState.instance.tweenManager.num(0, 1, t, {
				ease: ease,
				onUpdate: function(v) {
					var p = ease(v.percent);
					var currentZoom = FlxMath.lerp(startZoom, zoom, p);
					PlayState.instance.defaultCamZoom = currentZoom;
					cam.zoom = currentZoom;
				},
				onComplete: function(_) {
					PlayState.instance.defaultCamZoom = zoom;
					cam.zoom = zoom;
				}
			});
		});


		setFunction("setHudZoom", function(zoomAmount:Float) {
			if (PlayState.instance.cameraEventHandler != null) return;
			PlayState.instance.defaultHudCamZoom = zoomAmount;
			PlayState.instance.camHUD.zoom = zoomAmount;
		});

		// strumline

		setFunction("setStrumlineX", function(x:Float, ?dontMove:Bool = false) {
			PlayState.instance.strumLine.x = x;

			if (!dontMove) {
				for (note in PlayState.strumLineNotes) {
					note.x = x;
				}
			}
		});

		setFunction("setStrumlineY", function(y:Float, ?dontMove:Bool = false) {
			PlayState.instance.strumLine.y = y;

			if (!dontMove) {
				for (note in PlayState.strumLineNotes) {
					note.y = y;
				}
			}
		});

		// actors

		setFunction("getNoteProperty", function(note:Note, property:String):Dynamic {
			return Reflect.getProperty(note, property);
		});

		setFunction("makeNoteCopy", function(id:String, noteIdx:Int) {
			var actor:FlxSprite = PlayState.instance.notes.members[noteIdx];

			if (!lua_Sprites.exists(id) && actor != null) {
				var Sprite:FlxSprite = new FlxSprite(actor.x, actor.y);

				Sprite.loadGraphicFromSprite(actor);

				Sprite.alpha = actor.alpha;
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
				Sprite.animation.curAnim = actor.animation.curAnim;
				// trace('made sprite copy');
				lua_Sprites.set(id, Sprite);

				PlayState.instance.add(Sprite);
			}
		});

		setFunction("getUnspawnNotes", function() {
			return PlayState.instance.unspawnNotes.length;
		});

		setFunction(["getUnspawnedNoteType", "getUnspawnedNoteNoteType", "getUnspawnedNoteArrowType"], function(id:Int) {
			return PlayState.instance.unspawnNotes[id].arrow_Type;
		});

		setFunction("getUnspawnedNoteStrumtime", function(id:Int) {
			return PlayState.instance.unspawnNotes[id].strumTime;
		});

		setFunction("getUnspawnedNoteMustPress", function(id:Int) {
			return PlayState.instance.unspawnNotes[id].mustPress;
		});

		setFunction("getUnspawnedNoteSustainNote", function(id:Int) {
			return PlayState.instance.unspawnNotes[id].isSustainNote;
		});

		setFunction(["getUnspawnedNoteNoteData", "getUnspawnedNoteData"], function(id:Int) {
			return PlayState.instance.unspawnNotes[id].noteData;
		});

		setFunction("getUnspawnedNoteScaleX", function(id:Int) {
			return PlayState.instance.unspawnNotes[id].scale.x;
		});

		setFunction("getUnspawnedNoteScaleY", function(id:Int) {
			return PlayState.instance.unspawnNotes[id].scale.y;
		});

		setFunction("getUnspawnedNoteSingAnimPrefix", function(id:Int) {
			return PlayState.instance.unspawnNotes[id].singAnimPrefix;
		});

		setFunction("setUnspawnedNoteSingAnimPrefix", function(id:Int, prefix:String) {
			PlayState.instance.unspawnNotes[id].singAnimPrefix = prefix;
		});

		setFunction("setUnspawnedNoteXOffset", function(id:Int, offset:Float) {
			PlayState.instance.unspawnNotes[id].xOffset = offset;
		});

		setFunction("setUnspawnedNoteYOffset", function(id:Int, offset:Float) {
			PlayState.instance.unspawnNotes[id].yOffset = offset;
		});

		setFunction("setUnspawnedNoteAngle", function(id:Int, offset:Float) {
			PlayState.instance.unspawnNotes[id].localAngle = offset;
		});

		setFunction("getRenderedNotes", function() {
			return PlayState.instance.notes.length;
		});

		setFunction("getRenderedNoteX", function(id:Int) {
			return PlayState.instance.notes.members[id].x;
		});

		setFunction("getRenderedNoteY", function(id:Int) {
			return PlayState.instance.notes.members[id].y;
		});

		setFunction("getRenderedNoteType", function(id:Int) {
			return PlayState.instance.notes.members[id] != null ? PlayState.instance.notes.members[id].noteData : 0;
		});

		setFunction("getRenderedNoteData", function(id:Int) {
			return PlayState.instance.notes.members[id].noteData;
		});

		setFunction("getRenderedNoteArrowType", function(id:Int) {
			return PlayState.instance.notes.members[id].arrow_Type;
		});

		setFunction("getRenderedNoteParentX", function(id:Int) {
			return PlayState.instance.notes.members[id].prevNote.x;
		});

		setFunction("getRenderedNoteParentY", function(id:Int) {
			return PlayState.instance.notes.members[id].prevNote.y;
		});

		setFunction("getRenderedNoteHit", function(id:Int) {
			return PlayState.instance.notes.members[id].mustPress;
		});

		setFunction("getRenderedNoteCalcX", function(id:Int) {
			if (PlayState.instance.notes.members[id].mustPress)
				return PlayState.playerStrums.members[Math.floor(Math.abs(PlayState.instance.notes.members[id].noteData))].x;

			return PlayState.strumLineNotes.members[Math.floor(Math.abs(PlayState.instance.notes.members[id].noteData))].x;
		});

		setFunction("getRenderedNoteStrumtime", function(id:Int) {
			return PlayState.instance.notes.members[id].strumTime;
		});

		setFunction("getRenderedNoteScaleX", function(id:Int) {
			return PlayState.instance.notes.members[id] != null ? PlayState.instance.notes.members[id].scale.x : 1.0;
		});

		setFunction("getRenderedNoteScaleY", function(id:Int) {
			return PlayState.instance.notes.members[id] != null ? PlayState.instance.notes.members[id].scale.y : 1.0;
		});

		setFunction("setRenderedNotePos", function(x:Float, y:Float, id:Int) {
			if (PlayState.instance.notes.members[id] == null)
				throw('error! you cannot set a rendered notes position when it doesnt exist! ID: ' + id);
			else {
				PlayState.instance.notes.members[id].x = x;
				PlayState.instance.notes.members[id].y = y;
			}
		});

		setFunction("setRenderedNoteAlpha", function(alpha:Float, id:Int) {
			PlayState.instance.notes.members[id].alpha = alpha;
		});

		setFunction("setRenderedNoteScale", function(?arg1:Dynamic, ?arg2:Dynamic, ?arg3:Dynamic) {
			if (arg3 != null) {
				var id:Int = (arg3 is Int) ? cast arg3 : Std.parseInt(Std.string(arg3));
				if (PlayState.instance.notes.members[id] != null) {
					var scaleX:Float = (arg1 is Float || arg1 is Int) ? cast arg1 : 1.0;
					var scaleY:Float = (arg2 is Float || arg2 is Int) ? cast arg2 : 1.0;
					PlayState.instance.notes.members[id].setGraphicSize(scaleX, scaleY);
				}
			} else if (arg2 != null) {
				var id:Int = (arg2 is Int) ? cast arg2 : Std.parseInt(Std.string(arg2));
				if (PlayState.instance.notes.members[id] != null) {
					var scale:Float = (arg1 is Float || arg1 is Int) ? cast arg1 : 1.0;
					PlayState.instance.notes.members[id].setGraphicSize(PlayState.instance.notes.members[id].width * scale);
				}
			}
		});
		setFunction("setRenderedNoteScaleX", function(scale:Float, id:Int) {
			if (PlayState.instance.notes.members[id] != null)
				PlayState.instance.notes.members[id].scale.x = scale;
		});

		setFunction("setRenderedNoteScaleY", function(scale:Float, id:Int) {
			if (PlayState.instance.notes.members[id] != null)
				PlayState.instance.notes.members[id].scale.y = scale;
		});

		setFunction("setRenderedNoteScaleXY", function(scaleX:Float, scaleY:Float, id:Int) {
			if (PlayState.instance.notes.members[id] != null)
				PlayState.instance.notes.members[id].scale.set(scaleX, scaleY);
		});

		setFunction("isRenderedNoteSustainEnd", function(id:Int) {
			if (PlayState.instance.notes.members[id].animation.curAnim != null)
				return PlayState.instance.notes.members[id].animation.curAnim.name.endsWith('end');
			return false;
		});

		setFunction("getRenderedNoteSustainScaleY", function(id:Int) {
			return PlayState.instance.notes.members[id].sustainScaleY;
		});

		setFunction("getRenderedNoteOffsetX", function(id:Int) {
			var daNote:Note = PlayState.instance.notes.members[id];
			if (daNote == null) return 0.0;
			var alignMap = daNote.mustPress ? PlayState.instance.prevPlayerXVals : PlayState.instance.prevEnemyXVals;
			if (alignMap != null && alignMap.exists(daNote.alignmentKey))
				return alignMap.get(daNote.alignmentKey) - daNote.xOffset;
			if (daNote.isSustainNote) {
				var strums = daNote.mustPress ? PlayState.playerStrums : PlayState.strumLineNotes;
				var nData = Math.floor(Math.abs(daNote.noteData));
				if (strums != null && strums.members != null && nData < strums.members.length && strums.members[nData] != null) {
					return ((strums.members[nData].width - daNote.width) * 0.5) - daNote.xOffset;
				}
			}
			return -daNote.xOffset;
		});

		setFunction("getRenderedNoteOffsetY", function(id:Int) {
			return PlayState.instance.notes.members[id].yOffset;
		});

		setFunction("getRenderedNoteWidth", function(id:Int) {
			return PlayState.instance.notes.members[id].width;
		});

		setFunction("getRenderedNoteHeight", function(id:Int) {
			return PlayState.instance.notes.members[id].height;
		});

		setFunction("getRenderedNotePrevNoteStrumtime", function(id:Int) {
			return PlayState.instance.notes.members[id].prevNoteStrumtime;
		});

		setFunction("setRenderedNoteAngle", function(angle:Float, id:Int) {
			PlayState.instance.notes.members[id].modAngle = angle;
		});

		setFunction("setRenderedNoteSkewX", function(skew:Float, id:Int) {
			PlayState.instance.notes.members[id].skew.x = skew;
		});

		setFunction("setRenderedNoteSkewY", function(skew:Float, id:Int) {
			PlayState.instance.notes.members[id].skew.y = skew;
		});

		setFunction("getRenderedNoteSkewX", function(id:Int) {
			return PlayState.instance.notes.members[id].skew.x;
		});

		setFunction("getRenderedNoteSkewY", function(id:Int) {
			return PlayState.instance.notes.members[id].skew.y;
		});

		setFunction("isSustain", function(id:Int) {
			return PlayState.instance.notes.members[id].isSustainNote;
		});

		setFunction("isParentSustain", function(id:Int) {
			return PlayState.instance.notes.members[id].prevNote.isSustainNote;
		});

		setFunction("setRenderedNoteColor", function(r:Float, g:Float, b:Float, id:Int) {
			var note:Note = PlayState.instance.notes.members[id];
			note.colorSwap.r = r;
			note.colorSwap.g = g;
			note.colorSwap.b = b;
		});

		setFunction("setUnspawnedNoteColor", function(r:Float, g:Float, b:Float, id:Int) {
			var note:Note = PlayState.instance.unspawnNotes[id];
			note.colorSwap.r = r;
			note.colorSwap.g = g;
			note.colorSwap.b = b;
		});

		setFunction("setRenderedNoteColorForce", function(r:Float, g:Float, b:Float, id:Int) {
			var note:Note = PlayState.instance.notes.members[id];
			note.shader = note.colorSwap.shader;
			note.colorSwap.r = r;
			note.colorSwap.g = g;
			note.colorSwap.b = b;
		});

		setFunction("setUnspawnedNoteColorForce", function(r:Float, g:Float, b:Float, id:Int) {
			var note:Note = PlayState.instance.unspawnNotes[id];
			note.shader = note.colorSwap.shader;
			note.colorSwap.r = r;
			note.colorSwap.g = g;
			note.colorSwap.b = b;
		});

		setFunction("getRenderedNoteColor", function(id:Int):Dynamic {
			var note:Note = PlayState.instance.notes.members[id];
			return {r: note.colorSwap.r, g: note.colorSwap.g, b: note.colorSwap.b};
		});

		setFunction("getUnspawnedNoteColor", function(id:Int):Dynamic {
			var note:Note = PlayState.instance.unspawnNotes[id];
			return {r: note.colorSwap.r, g: note.colorSwap.g, b: note.colorSwap.b};
		});

		setFunction("getRenderedNoteAffectedByColor", function(id:Int):Bool {
			return PlayState.instance.notes.members[id].affectedbycolor;
		});

		setFunction("getUnspawnedNoteAffectedByColor", function(id:Int):Bool {
			return PlayState.instance.notes.members[id].affectedbycolor;
		});

		setFunction("setRenderedNoteSpeed", function(speed:Float, id:Int) {
			PlayState.instance.notes.members[id].speed = speed;
		});

		setFunction("getRenderedNoteSpeed", function(id:Int) {
			return PlayState.instance.notes.members[id].speed;
		});

		setFunction("setUnspawnNoteSpeed", function(speed:Float, id:Int) {
			PlayState.instance.unspawnNotes[id].speed = speed;
		});

		setFunction("getUnspawnNoteSpeed", function(id:Int) {
			return PlayState.instance.unspawnNotes[id].speed;
		});

		setFunction("anyNotes", function() {
			return PlayState.instance.notes.members.length != 0;
		});

		setFunction(["setActorPos", "setObjectPos"], function(arg1:Dynamic, arg2:Dynamic, ?arg3:Dynamic) {
			if (Std.isOfType(arg1, String)) { // Psych: (id, x, y)
				var sprite = resolveSpriteTarget(cast arg1);
				if (sprite != null) {
					sprite.x = arg2 != null ? cast arg2 : 0.0;
					sprite.y = arg3 != null ? cast arg3 : 0.0;
				}
			} else { // Leather: (x, y, id)
				var sprite = resolveSpriteTarget(cast arg3);
				if (sprite != null) {
					sprite.x = cast arg1;
					sprite.y = cast arg2;
				}
			}
		});

		setFunction(["setActorScroll", "setScrollFactor", "setLuaSpriteScrollFactor"], function(arg1:Dynamic, arg2:Dynamic, ?arg3:Dynamic) {
			if (Std.isOfType(arg1, String)) { // Psych: (id, x, y)
				var sprite = resolveSpriteTarget(cast arg1);
				if (sprite != null)
					sprite.scrollFactor.set(arg2 != null ? cast arg2 : 1.0, arg3 != null ? cast arg3 : 1.0);
			} else { // Leather: (x, y, id)
				var sprite = resolveSpriteTarget(cast arg3);
				if (sprite != null)
					sprite.scrollFactor.set(cast arg1, cast arg2);
			}
		});

		setFunction("setActorX", function(x:Float, id:String) {
			var sprite = resolveSpriteTarget(Std.string(id));
			if (sprite != null)
				sprite.x = x;
		});

		setFunction("getOriginalCharX", function(character:Int) {
			return PlayState.instance.stage.getCharacterPos(character)[0];
		});

		setFunction("getOriginalCharY", function(character:Int) {
			return PlayState.instance.stage.getCharacterPos(character)[1];
		});

		setFunction("setActorAccelerationX", function(x:Float, id:String) {
			var actor = getActorByName(id);
			if (actor != null)
				actor.acceleration.x = x;
		});

		setFunction("setActorDragX", function(x:Float, id:String) {
			var actor = getActorByName(id);
			if (actor != null)
				actor.drag.x = x;
		});

		setFunction("setActorVelocityX", function(x:Float, id:String) {
			var actor = getActorByName(id);
			if (actor != null)
				actor.velocity.x = x;
		});

		setFunction("setActorOriginX", function(x:Float, id:String) {
			var sprite = resolveSpriteTarget(id);
			if (sprite != null)
				sprite.origin.x = x;
		});

		setFunction("setActorOriginY", function(x:Float, id:String) {
			var sprite = resolveSpriteTarget(id);
			if (sprite != null)
				sprite.origin.y = x;
		});

		setFunction("setActorAntialiasing", function(antialiasing:Bool, id:String) {
			if (getActorByName(id) != null) {
				getActorByName(id).antialiasing = antialiasing && Options.getData("antialiasing");
			}
		});

		setFunction(["addActorAnimation", "addAnimationByPrefix"], function(id:String, prefix:String, anim:String, fps:Int = 30, looped:Bool = true) {
			if (getActorByName(id) != null) {
				getActorByName(id).animation.addByPrefix(prefix, anim, fps, looped);
			}
		});

		setFunction(["addActorAnimationIndices", "addAnimationByIndices"], function(id:String, arg2:String, arg3:Dynamic, ?arg4:Dynamic, ?arg5:Dynamic, ?arg6:Dynamic) {
			var spr = getActorByName(id);
			if (spr == null) return;

			var animName:String = "";
			var xmlPrefix:String = "";
			var indices:Array<Int> = [];
			var fps:Int = 24;
			var loop:Bool = true;

			// Check if called like Psych: (tag, name, prefix, indices, fps, loop)
			var isPsych = (arg4 != null && (Std.isOfType(arg4, Array) || (Std.isOfType(arg4, String) && Std.string(arg4).indexOf(",") != -1 || Std.parseInt(Std.string(arg4)) != null)));
			if (isPsych) {
				animName = arg2;
				xmlPrefix = Std.string(arg3);
				var rawIndices:Dynamic = arg4;
				if (Std.isOfType(rawIndices, Array)) {
					for (i in (cast rawIndices:Array<Dynamic>)) indices.push(Std.parseInt(Std.string(i)));
				} else {
					for (p in Std.string(rawIndices).split(",")) indices.push(Std.parseInt(StringTools.trim(p)));
				}
				if (arg5 != null) fps = cast arg5;
				if (arg6 != null) loop = cast arg6;
			} else { // Leather: (id, prefix, indiceString, anim, fps, looped)
				animName = Std.string(arg4 != null ? arg4 : arg2);
				xmlPrefix = arg2;
				var rawIndices:Dynamic = arg3;
				if (Std.isOfType(rawIndices, Array)) {
					for (i in (cast rawIndices:Array<Dynamic>)) indices.push(Std.parseInt(Std.string(i)));
				} else if (rawIndices != null) {
					for (p in Std.string(rawIndices).split(",")) indices.push(Std.parseInt(StringTools.trim(p)));
				}
				if (arg5 != null) fps = cast arg5;
				if (arg6 != null) loop = cast arg6;
			}
			spr.animation.addByIndices(animName, xmlPrefix, indices, "", fps, loop);
		});

		setFunction(["playCharAnim", "playCharacterAnimation", "characterPlayAnim"], function(id:String, anim:String, force:Bool = false, reverse:Bool = false, frame:Int = 0) {
			if (getActorByName(id) != null) {
				getActorByName(id).playAnim(anim, force, reverse, frame);
			}
		});

		setFunction(["playAnimation", "playAnim", "objectPlayAnimation"], function(id:String, anim:String, force:Bool = false, reverse:Bool = false, frame:Int = 0) {
			var obj:FlxSprite = getActorByName(id);
			if (obj != null) {
				if (obj is Character)
					cast(obj, Character).playAnim(anim, force, reverse, frame);
				else
					obj.animation.play(anim, force, reverse, frame);
			}
		});

		setFunction(["dance", "playActorDance", "characterDance"], function(id:String, ?altAnim:String = '') {
			if (getActorByName(id) != null) {
				getActorByName(id).dance(altAnim);
			}
		});

		setFunction("playActorAnimation", function(id:String, anim:String, force:Bool = false, reverse:Bool = false, frame:Int = 0) {
			var sprite = resolveSpriteTarget(id);
			if (sprite != null)
				sprite.animation.play(anim, force, reverse, frame);
		});



		setFunction("setCharacterShouldDance", function(id:String, shouldDance:Bool = true) {
			var sprite = resolveSpriteTarget(id);
			if (sprite != null)
				sprite.shouldDance = shouldDance;
		});

		setFunction("setCharacterPlayFullAnim", function(id:String, playFullAnim:Bool = true) {
			var sprite = resolveSpriteTarget(id);
			if (sprite != null)
				sprite.playFullAnim = playFullAnim;
		});

		setFunction("setCharacterSingPrefix", function(id:String, prefix:String) {
			var sprite = resolveSpriteTarget(id);
			if (sprite != null)
				sprite.singAnimPrefix = prefix;
		});

		setFunction("setCharacterPreventDanceForAnim", function(id:String, preventDanceForAnim:Bool = true) {
			var sprite = resolveSpriteTarget(id);
			if (sprite != null)
				sprite.preventDanceForAnim = preventDanceForAnim;
		});

		setFunction("playCharacterDance", function(id:String, ?altAnim:String) {
			var sprite = resolveSpriteTarget(id);
			if (sprite != null)
				sprite.dance(altAnim);
		});

		setFunction("getPlayingActorAnimation", function(id:String) {
			var sprite = resolveSpriteTarget(id);
			if (sprite != null) {
				if (Reflect.getProperty(Reflect.getProperty(sprite, "animation"), "curAnim") != null)
					return Reflect.getProperty(Reflect.getProperty(Reflect.getProperty(sprite, "animation"), "curAnim"), "name");
			}
			return "unknown";
		});

		setFunction("getPlayingActorAnimationFrame", function(id:String) {
			if (getActorByName(id) != null) {
				if (Reflect.getProperty(Reflect.getProperty(getActorByName(id), "animation"), "curAnim") != null)
					return Reflect.getProperty(Reflect.getProperty(Reflect.getProperty(getActorByName(id), "animation"), "curAnim"), "curFrame");
			}

			return 0;
		});

		setFunction("setActorAlpha", function(alpha:Float, id:Dynamic) {
			var sprite = resolveSpriteTarget(id);
			if (sprite != null)
				Reflect.setProperty(sprite, "alpha", alpha);
		});

		setFunction("setActorVisible", function(visible:Bool, id:Dynamic) {
			var sprite = resolveSpriteTarget(id);
			if (sprite != null)
				sprite.visible = visible;
		});

		setFunction("setActorColor", function(id:String, r:Int, g:Int, b:Int, alpha:Int = 255) {
			if (getActorByName(id) != null) {
				Reflect.setProperty(getActorByName(id), "color", FlxColor.fromRGB(r, g, b, alpha));
			}
		});

		setFunction("setActorColorRGB", function(id:String, color:String) {
			var actor:FlxSprite = getActorByName(id);

			var colors = color.split(',');
			var red = Std.parseInt(colors[0]);
			var green = Std.parseInt(colors[1]);
			var blue = Std.parseInt(colors[2]);

			if (actor != null)
				Reflect.setProperty(actor, "color", FlxColor.fromRGB(red, green, blue));
		});


		setFunction("setActorColorTrans", function(id:String, r:Int, g:Int, b:Int) {
			var actor = getActorByName(id);
			if (actor != null) {
				actor.setColorTransform(0, 0, 0, 1, r, g, b, 0);
			}
		});
		setFunction("resetActorColorTrans", function(id:String) {
			var actor = getActorByName(id);
			if (actor != null) {
				actor.setColorTransform(1, 1, 1, 1, 0, 0, 0, 0);
			}
		});

		setFunction("setActorY", function(y:Float, id:String) {
			var sprite = resolveSpriteTarget(id);
			if (sprite != null)
				Reflect.setProperty(sprite, "y", y);
		});

		setFunction(["savePosition", "saveposition", "saveActorPosition"], function(id:String, ?key:String) {
			var actor = resolveSpriteTarget(id);
			if (actor == null) actor = getActorByName(id);
			if (actor != null) {
				var k = (key != null && key != "") ? key : id;
				if (lua_SavedPositions == null) lua_SavedPositions = new Map();
				lua_SavedPositions.set(k, {x: actor.x, y: actor.y});
			}
		});

		setFunction(["loadPosition", "loadposition", "loadActorPosition"], function(id:String, ?key:String) {
			if (lua_SavedPositions == null) return;
			var k = (key != null && key != "") ? key : id;
			if (lua_SavedPositions.exists(k)) {
				var pos = lua_SavedPositions.get(k);
				var actor = resolveSpriteTarget(id);
				if (actor == null) actor = getActorByName(id);
				if (actor != null) {
					actor.x = pos.x;
					actor.y = pos.y;
				}
			}
		});

		setFunction("setActorAccelerationY", function(y:Float, id:String) {
			var actor = getActorByName(id);
			if (actor != null)
				actor.acceleration.y = y;
		});

		setFunction("setActorDragY", function(y:Float, id:String) {
			var actor = getActorByName(id);
			if (actor != null)
				actor.drag.y = y;
		});

		setFunction("setActorVelocityY", function(y:Float, id:String) {
			var actor = getActorByName(id);
			if (actor != null)
				actor.velocity.y = y;
		});

		setFunction("setActorAngle", function(angle:Float, id:String) {
			var sprite = resolveSpriteTarget(id);
			if (sprite != null)
				Reflect.setProperty(sprite, "angle", angle);
		});

		setFunction("setActorModAngle", function(angle:Float, id:String) {
			if (getActorByName(id) != null)
				getActorByName(id).modAngle = angle;
		});

		setFunction("setActorScale", function(scale:Float, id:String) {
			applyActorScale(getActorByName(id), scale, scale);
		});

		setFunction(["setActorScaleXY", "scaleObject", "scaleLuaSprite"], function(arg1:Dynamic, arg2:Dynamic, ?arg3:Dynamic, ?arg4:Dynamic) {
			if (Std.isOfType(arg1, String)) { // Psych: (obj, x, y, ?updateHitbox)
				var actor = getActorByName(cast arg1);
				if (actor != null) {
					var sx:Float = arg2 != null ? cast arg2 : 1.0;
					var sy:Float = arg3 != null ? cast arg3 : sx;
					applyActorScale(actor, sx, sy);
					var updateHitbox:Bool = (arg4 != null && Std.isOfType(arg4, Bool)) ? cast arg4 : true;
					if (updateHitbox) actor.updateHitbox();
				}
			} else { // Leather: (scaleX, scaleY, id)
				var actor = getActorByName(cast arg3);
				if (actor != null) {
					applyActorScale(actor, cast arg1, cast arg2);
				}
			}
		});

		setFunction(["setGraphicSize", "setObjectSize"], function(id:String, width:Int = 0, height:Int = 0, ?updateHitbox:Bool = true) {
			var actor = getActorByName(id);
			if (actor != null) {
				actor.setGraphicSize(width, height);
				if (updateHitbox) actor.updateHitbox();
			}
		});

		setFunction(["updateHitbox", "updateHitBox"], function(id:String) {
			var actor = getActorByName(id);
			if (actor != null) actor.updateHitbox();
		});

		setFunction("setActorScaleX", function(scaleX:Float, id:String) {
			var actor = getActorByName(id);
			if (actor == null) return;

			if (Std.isOfType(actor, Character)) {
				var c:Character = cast actor;
				applyActorScale(c, scaleX, (c.scale.y != 0 && c.graphicSize != 0) ? c.scale.y / c.graphicSize : 1.0);
			}
			else
				actor.setGraphicSize(actor.width * scaleX, actor.height);
		});

		setFunction("setActorScaleY", function(scaleY:Float, id:String) {
			var actor = getActorByName(id);
			if (actor == null) return;

			if (Std.isOfType(actor, Character)) {
				var c:Character = cast actor;
				applyActorScale(c, (c.scale.x != 0 && c.graphicSize != 0) ? c.scale.x / c.graphicSize : 1.0, scaleY);
			}
			else
				actor.setGraphicSize(actor.width, actor.height * scaleY);
		});

		setFunction("getActorScaleX", function(id:String):Float {
			var actor = getActorByName(id);
			if (actor == null) return 1.0;
			if (Std.isOfType(actor, Character)) {
				var c:Character = cast actor;
				return (c.graphicSize != 0) ? c.scale.x / c.graphicSize : 1.0;
			}
			return actor.scale.x;
		});

		setFunction("getActorScaleY", function(id:String):Float {
			var actor = getActorByName(id);
			if (actor == null) return 1.0;
			if (Std.isOfType(actor, Character)) {
				var c:Character = cast actor;
				return (c.graphicSize != 0) ? c.scale.y / c.graphicSize : 1.0;
			}
			return actor.scale.y;
		});

		setFunction("getActorScaleXY", function(id:String) {
			var actor = getActorByName(id);
			if (actor == null) return {x: 1.0, y: 1.0};
			if (Std.isOfType(actor, Character)) {
				var c:Character = cast actor;
				return {
					x: (c.graphicSize != 0) ? c.scale.x / c.graphicSize : 1.0,
					y: (c.graphicSize != 0) ? c.scale.y / c.graphicSize : 1.0
				};
			}
			return {x: actor.scale.x, y: actor.scale.y};
		});


		setFunction("setActorFlipX", function(flip:Bool, id:String) {
			if (getActorByName(id) != null)
				getActorByName(id).flipX = flip;
		});

		setFunction("setActorFlipY", function(flip:Bool, id:String) {
			if (getActorByName(id) != null)
				getActorByName(id).flipY = flip;
		});

		setFunction("getActorFlipX", function(id:String) {
			if (getActorByName(id) != null)
				return getActorByName(id).flipX;
			return false;
		});

		setFunction("getActorFlipY", function(flip:Bool, id:String) {
			if (getActorByName(id) != null)
				return getActorByName(id).flipY;
			return false;
		});

		setFunction("setActorTrailVisible", function(id:String, visibleVal:Bool) {
			var handled = false;
			if (trails.exists(id)) {
				trails.get(id).visible = visibleVal;
				handled = true;
			}
			var char = getCharacterByName(id);
			if (char != null && char.coolTrail != null) {
				char.coolTrail.visible = visibleVal;
				handled = true;
			}
			return handled;
		});

		setFunction("getActorTrailVisible", function(id:String) {
			if (trails.exists(id))
				return trails.get(id).visible;
			var char = getCharacterByName(id);
			if (char != null && char.coolTrail != null)
				return char.coolTrail.visible;
			return false;
		});

		setFunction("getActorWidth", function(id:String) {
			var sprite = resolveSpriteTarget(id);
			return sprite != null ? sprite.width : 0;
		});

		setFunction("getActorHeight", function(id:String) {
			var sprite = resolveSpriteTarget(id);
			return sprite != null ? sprite.height : 0;
		});

		setFunction("getActorAlpha", function(id:String) {
			var sprite = resolveSpriteTarget(id);
			return sprite != null ? sprite.alpha : 0.0;
		});

		setFunction("getActorAngle", function(id:String) {
			var sprite = resolveSpriteTarget(id);
			return sprite != null ? sprite.angle : 0.0;
		});

		setFunction("getActorX", function(id:String) {
			var sprite = resolveSpriteTarget(id);
			return sprite != null ? sprite.x : 0.0;
		});

		setFunction("getActorY", function(id:String) {
			var sprite = resolveSpriteTarget(id);
			return sprite != null ? sprite.y : 0.0;
		});

		setFunction("setActorReflection", function(id:String, r:Bool) {
			var char = getCharacterByName(id);
			if (char != null && char.otherCharacters != null && char.otherCharacters.length > 0) {
				for (i in 0...char.otherCharacters.length)
					char.otherCharacters[i].drawReflection = r;
				return;
			}
			Reflect.setProperty(getActorByName(id), "drawReflection", r);
		});

		setFunction("setActorReflectionYOffset", function(id:String, y:Float) {
			var sprite = resolveSpriteTarget(id);
			if (sprite != null)
				Reflect.setProperty(sprite, "reflectionYOffset", y);
		});

		setFunction("setActorReflectionAlpha", function(id:String, a:Float) {
			var sprite = resolveSpriteTarget(id);
			if (sprite != null)
				Reflect.setProperty(sprite, "reflectionAlpha", a);
		});

		setFunction("setActorReflectionColor", function(id:String, color:String) {
			var sprite = resolveSpriteTarget(id);
			if (sprite != null)
				Reflect.setProperty(sprite, "reflectionColor", FlxColor.fromString(color));
		});

		setFunction("tweenWindowProperty",function(prop:String, value:Float, easeStr:String, time:Float) {
            var window = Application.current.window;
            var ease = easeFromString(easeStr);        

            if(window != null)
            {
                var startVal = Reflect.getProperty(window, prop);

                var last:Int = Std.int(startVal);

                PlayState.instance.tweenManager.num(startVal, value, time, {onUpdate: function(tween:FlxTween){
					var ting = Std.int(FlxMath.lerp(startVal,value, ease(tween.percent)));
                    if (ting != last)
                    {
                        last = ting;
                        Reflect.setProperty(window, prop, ting);
                    }
                    
				}, ease: ease, onComplete: function(tween:FlxTween) {
					Reflect.setProperty(window, prop, value);
				}});
                //trace('set shader prop');
            }

        });

		setFunction("setWindowPos", function(x:Int, y:Int) {
			Application.current.window.move(x, y);
		});

		setFunction("getWindowX", function() {
			return Application.current.window.x;
		});

		setFunction("getWindowY", function() {
			return Application.current.window.y;
		});

		setFunction("getCenteredWindowX", function() {
			return (Application.current.window.display.currentMode.width / 2) - (Application.current.window.width / 2);
		});

		setFunction("getCenteredWindowY", function() {
			return (Application.current.window.display.currentMode.height / 2) - (Application.current.window.height / 2);
		});

		setFunction("resizeWindow", function(Width:Int, Height:Int) {
			Application.current.window.resize(Width, Height);
		});

		setFunction("getScreenWidth", function() {
			return Application.current.window.display.currentMode.width;
		});

		setFunction("getScreenHeight", function() {
			return Application.current.window.display.currentMode.height;
		});

		setFunction("getWindowWidth", function() {
			return Application.current.window.width;
		});

		setFunction("getWindowHeight", function() {
			return Application.current.window.height;
		});

		setFunction("setCanFullscreen", function(can_Fullscreen:Bool) {
			PlayState.instance.canFullscreen = can_Fullscreen;
		});

		setFunction("changeDadCharacter", function(character:String) {
			var oldDad = PlayState.dad;
			PlayState.instance.remove(oldDad);

			var dad = new Character(100, 100, character);
			PlayState.dad = dad;

			if (dad.otherCharacters == null) {
				if (dad.coolTrail != null)
					PlayState.instance.add(dad.coolTrail);

				PlayState.instance.add(dad);
			} else {
				for (character in dad.otherCharacters) {
					if (character.coolTrail != null)
						PlayState.instance.add(character.coolTrail);

					PlayState.instance.add(character);
				}
			}

			lua_Sprites.remove("dad");

			oldDad.kill();
			oldDad.destroy();

			lua_Sprites.set("dad", dad);

			PlayState.instance.refreshIcons(dad, false);

			var bar = PlayState.instance.healthBar;

			bar.createFilledBar(dad.barColor, PlayState.boyfriend.barColor);
			bar.updateFilledBar();

			PlayState.instance.stage.setCharOffsets();
		});

		setFunction("changeBoyfriendCharacter", function(character:String) {
			var oldBF = PlayState.boyfriend;
			PlayState.instance.remove(oldBF);

			var boyfriend = new Boyfriend(770, 450, character);
			PlayState.boyfriend = boyfriend;

			if (boyfriend.otherCharacters == null) {
				if (boyfriend.coolTrail != null)
					PlayState.instance.add(boyfriend.coolTrail);

				PlayState.instance.add(boyfriend);
			} else {
				for (character in boyfriend.otherCharacters) {
					if (character.coolTrail != null)
						PlayState.instance.add(character.coolTrail);

					PlayState.instance.add(character);
				}
			}

			lua_Sprites.remove("boyfriend");

			oldBF.kill();
			oldBF.destroy();

			lua_Sprites.set("boyfriend", boyfriend);

			PlayState.instance.refreshIcons(boyfriend, true);

			var bar = PlayState.instance.healthBar;

			bar.createFilledBar(PlayState.dad.barColor, boyfriend.barColor);
			bar.updateFilledBar();

			PlayState.instance.stage.setCharOffsets();
		});

	
		setFunction("duplicateCharacter", function(sourceId:String, ?offsetX:Float, ?offsetY:Float, ?newId:String) {
			var src = resolveLuaCharacter(sourceId);
			if (src == null) {
				trace("duplicateCharacter: '" + sourceId + "'is not character valid!");
				return null;
			}
			var posX:Float = src.x + (offsetX ?? 0);
			var posY:Float = src.y + (offsetY ?? 0);
			var dup:Character = Std.isOfType(src, Boyfriend)
				? new Boyfriend(posX, posY, src.curCharacter, src.isDeathCharacter, src.scaleMult)
				: new Character(posX, posY, src.curCharacter, src.isPlayer, src.isDeathCharacter, src.scaleMult);
			if (dup == null) {
				trace("duplicateCharacter: cant create a copy of '" + sourceId + "'!");
				return null;
			}
			dup.positioningOffset = [src.positioningOffset[0], src.positioningOffset[1]];
			dup.flipX = src.flipX;
			dup.flipY = src.flipY;
			dup.color = src.color;
			dup.antialiasing = src.antialiasing;
			dup.alpha = src.alpha;
			dup.visible = src.visible;
			dup.cameras = src.cameras;
			dup.scrollFactor.set(src.scrollFactor.x, src.scrollFactor.y);
			dup.scale.set(src.scale.x, src.scale.y);
			dup.updateAnimOffsets();
			var id = (newId != null && newId.length > 0) ? newId : uniqueDuplicateId(sourceId);
			insertCharacterIntoPlayState(dup, src);
			registerOwnedCharId(id, dup);
			linkCharacterMirror(src, dup);

			return id;
		});

		
		setFunction("addCharacter", function(character:String, side:String = "opponent", x:Float = 0, y:Float = 0, ?newId:String, mirror:Bool = false) {
			var key = charSideFromString(side);
			syncSideGroupAfterCharacterChange(key);
			var main = getSideMainCharacter(key);

			if (main == null) {
				trace("addCharacter: no hay personaje en el lado '" + side + "'!");
				return null;
			}

			
			var char:Character = (key == 'bf')
				? new Boyfriend(x, y, character, false, main.scaleMult)
				: new Character(x, y, character, main.isPlayer, false, main.scaleMult);

			if (char == null) {
				trace("addCharacter: cant create '" + character + "'!");
				return null;
			}

			char.updateHitbox();

			
			var root = attachCharacterToSideGroup(key, char, x, y);

			if (root == null) {
				trace("addCharacter: no se pudo añadir '" + character + "' al grupo de '" + side + "'!");
				destroyRuntimeCharacter(char);
				return null;
			}

			insertCharacterIntoPlayState(char, getSideGroupAnchor(key));

			var added = getAddedCharacters(key);
			added.push(char);

			if (mirror) linkCharacterMirror(getSideGroupAnchor(key), char);

			var index = getSideOriginalCharacters(key).length + added.length - 1;
			var id = (newId != null && newId.length > 0) ? newId : (key + index);

			registerOwnedCharId(id, char);
			refreshSideIds(key);

			return id;
		});

		
		setFunction("removeCharacter", function(id:String) {
			var side = findSideOfCharacter(resolveLuaCharacter(id));
			if (side != null) syncSideGroupAfterCharacterChange(side);

			var char = resolveLuaCharacter(id);

			if (char == null) {
				trace("removeCharacter: '" + id + "' no es un personaje valido!");
				return false;
			}

			if (findSideOfMainCharacter(char) != null) {
				trace("removeCharacter: '" + id + "' es un personaje principal y no se puede eliminar!");
				return false;
			}

			removeRuntimeCharacter(char);
			return true;
		});

		
		setFunction("getCharacterGroupIds", function(side:String = "opponent") {
			var key = charSideFromString(side);
			syncSideGroupAfterCharacterChange(key);
			return getSideCharacterIds(key);
		});

		setFunction("hasCharacter", function(id:String) {
			return resolveLuaCharacter(id) != null;
		});

	
		setFunction("setCharacterMirrorAnim", function(id:String, mirror:Bool = true) {
			var char = resolveLuaCharacter(id);
			if (char == null) return false;

			var found = false;

			for (link in lua_CharDuplicates)
				if (link.dst == char) {
					link.anim = mirror;
					found = true;
				}

			return found;
		});

		// scroll speed

		var original_Scroll_Speed = PlayState.SONG.speed;

		setFunction("getBaseScrollSpeed", function() {
			return original_Scroll_Speed;
		});

		setFunction("getScrollSpeed", function() {
			return PlayState.SONG.speed;
		});

		setFunction("setScrollSpeed", function(speed:Float) {
			PlayState.SONG.speed = speed;
		});

		// audio visualizer
		setFunction("createAudioVisualizer", function(id:String, soundId:String, x:Float, y:Float, barCount:Int = 32, width:Float = 400, height:Float = 100) {
			if (lua_Sprites.exists(id)) {
				trace('AudioVisualizer ERROR: Sprite with id $id already exists!');
				return;
			}
			
			var soundIds:Array<String> = soundId.split(",");
			var soundObjs:Array<FlxSound> = [];
			for (sid in soundIds) {
				var s = StringTools.trim(sid);
				if (lua_Sounds.exists(s)) {
					soundObjs.push(lua_Sounds.get(s));
				} else {
				    trace('AudioVisualizer WARNING: Sound $s not found, skipping it.');
				}
			}
			
			if (soundObjs.length == 0) {
				trace('AudioVisualizer ERROR: No valid sounds found for ids: $soundId!');
				return;
			}
			var visualizer = new AudioVisualizer(x, y, soundObjs, barCount, width, height);
			lua_Sprites.set(id, visualizer);

		});

		setFunction("setVisualizerMode", function(id:String, mode:String = "up") {
			if (lua_Sprites.exists(id) && Std.isOfType(lua_Sprites.get(id), AudioVisualizer)) {
				var vis:AudioVisualizer = cast lua_Sprites.get(id);
				vis.setMode(mode);

			} else {
			    trace('AudioVisualizer ERROR: Could not set mode on $id (not found or not a visualizer)');
			}
		});

		setFunction("setVisualizerBars", function(id:String, count:Int) {
			if (lua_Sprites.exists(id) && Std.isOfType(lua_Sprites.get(id), AudioVisualizer)) {
				var vis:AudioVisualizer = cast lua_Sprites.get(id);
				vis.setBars(count);

			} else {
			    trace('AudioVisualizer ERROR: Could not change bars on $id (not found or not a visualizer)');
			}
		});

		setFunction("setVisualizerAudio", function(id:String, soundId:String) {
			if (lua_Sprites.exists(id) && Std.isOfType(lua_Sprites.get(id), AudioVisualizer)) {
				var vis:AudioVisualizer = cast lua_Sprites.get(id);
				
				var soundIds:Array<String> = soundId.split(",");
				var soundObjs:Array<FlxSound> = [];
				for (sid in soundIds) {
					var s = StringTools.trim(sid);
					if (lua_Sounds.exists(s)) {
						soundObjs.push(lua_Sounds.get(s));
					} else {
					    trace('AudioVisualizer WARNING: Sound $s not found when swapping audio.');
					}
				}
				if (soundObjs.length > 0) {
					vis.setSounds(soundObjs);

				} else {
				    trace('AudioVisualizer ERROR: No valid sounds found to change audio for $id');
				}
			} else {
			    trace('AudioVisualizer ERROR: Could not change audio for $id (not found or not a visualizer)');
			}
		});

		setFunction("setVisualizerColors", function(id:String, colorsStr:String) {
			if (lua_Sprites.exists(id) && Std.isOfType(lua_Sprites.get(id), AudioVisualizer)) {
				var vis:AudioVisualizer = cast lua_Sprites.get(id);
				var parsedColors:Array<flixel.util.FlxColor> = [];
				var colorArray = colorsStr.split(",");
				for (c in colorArray) {
					var trimC = StringTools.trim(c);
					if (trimC != "") {
						parsedColors.push(flixel.util.FlxColor.fromString(trimC));
					}
				}
				if (parsedColors.length > 0) {
					vis.setColors(parsedColors);

				} else {
				    trace('AudioVisualizer WARNING: No valid colors found in $colorsStr');
				}
			} else {
			    trace('AudioVisualizer ERROR: Could not change colors on $id (not found or not a visualizer)');
			}
		});

		// sounds

		setFunction("createSound", function(id:String, file_Path:String, library:String, ?looped:Bool = false) {
			if (lua_Sounds.get(id) == null) {
				lua_Sounds.set(id, new FlxSound().loadEmbedded(Paths.sound(file_Path, library), looped));
				FlxG.sound.list.add(lua_Sounds.get(id));
			} else
				trace("Error! Sound " + id + " already exists! Try another sound name!");
		});

		setFunction("removeSound", function(id:String) {
			if (lua_Sounds.get(id) != null) {
				FlxG.sound.list.remove(lua_Sounds.get(id));

				var sound = lua_Sounds.get(id);
				sound.stop();
				sound.kill();
				sound.destroy();

				lua_Sounds.set(id, null);
			}
		});

		setFunction("playSound", function(id:String, ?arg2:Dynamic, ?tag:String) {
			if (lua_Sounds.get(id) != null) {
				var force:Bool = (arg2 != null && Std.isOfType(arg2, Bool)) ? cast arg2 : false;
				lua_Sounds.get(id).play(force);
			} else {
				var vol:Float = (arg2 != null && (Std.isOfType(arg2, Float) || Std.isOfType(arg2, Int))) ? cast arg2 : 1.0;
				var sndPath = Paths.sound(id);
				if (Assets.exists(sndPath)) {
					var snd = FlxG.sound.play(sndPath, vol);
					if (tag != null && tag != "") lua_Sounds.set(tag, snd);
				}
			}
		});

		setFunction("soundFadeIn", function(tag:String, duration:Float, ?fromValue:Float = 0, ?toValue:Float = 1) {
			var snd = (tag == null || tag == "" || tag == "music") ? FlxG.sound.music : lua_Sounds.get(tag);
			if (snd != null) {
				snd.fadeIn(duration, fromValue, toValue);
			}
		});

		setFunction("soundFadeOut", function(tag:String, duration:Float, ?toValue:Float = 0) {
			var snd = (tag == null || tag == "" || tag == "music") ? FlxG.sound.music : lua_Sounds.get(tag);
			if (snd != null) {
				snd.fadeOut(duration, toValue);
			}
		});

		setFunction("stopSound", function(id:String) {
			if (lua_Sounds.get(id) != null)
				lua_Sounds.get(id).stop();
		});

		setFunction("pauseSound", function(id:String) {
			if (lua_Sounds.get(id) != null)
				lua_Sounds.get(id).pause();
		});

		setFunction("resumeSound", function(id:String) {
			if (lua_Sounds.get(id) != null)
				lua_Sounds.get(id).resume();
		});

		setFunction("setSoundVolume", function(id:String, volume:Float) {
			if (lua_Sounds.get(id) != null)
				lua_Sounds.get(id).volume = volume;
		});

		setFunction("getSoundTime", function(id:String) {
			if (lua_Sounds.get(id) != null)
				return lua_Sounds.get(id).time;

			return 0;
		});

		// tweens

		setFunction("tween", function(obj:String, properties:Dynamic, duration:Float, ease:String, ?startDelay:Float = 0.0, ?onComplete:Dynamic) {
			var spr:Dynamic = resolveSpriteTarget(obj);
			if (spr == null) spr = getActorByName(obj);
			if (spr != null) {
				lua_Tweens.set('$obj.$properties', FlxTween.tween(spr, properties, duration, {
					ease: CoolUtil.easeFromString(ease),
					onComplete: function(twn) {
						lua_Tweens.remove('$obj.$properties');
						if (onComplete != null) {
							onComplete();
						}
					},
					startDelay: startDelay,
				}));
			} else {
				trace('Object named $obj doesn\'t exist!', ERROR);
			}
		});

		setFunction(["tweenCancel", "cancelTween"], function(tween:String) {
			var twn:FlxTween = lua_Tweens.get(tween);
			if (twn != null) {
				twn.cancel();
				lua_Tweens.remove(tween);
			} else {
				trace('Tween $tween doesn\'t exist!', ERROR);
			}
		});

		var doGenericTween = function(tag:String, vars:String, values:Dynamic, duration:Float, ?ease:String = 'linear') {
			var obj:Dynamic = resolveSpriteTarget(vars);
			if (obj == null) obj = getActorByName(vars);
			if (obj == null) {
				if (vars == "camGame" || vars == "camera") obj = FlxG.camera;
				else if (vars == "camHUD") obj = PlayState.instance.camHUD;
				else if (vars == "camOther") obj = PlayState.instance.camOther;
			}
			if (obj != null) {
				var existing = lua_Tweens.get(tag);
				if (existing != null) {
					existing.cancel();
					existing.destroy();
					lua_Tweens.remove(tag);
				}
				var twn = FlxTween.tween(obj, values, duration, {
					ease: CoolUtil.easeFromString(ease),
					onComplete: function(t) {
						lua_Tweens.remove(tag);
						call("onTweenCompleted", [tag]);
					}
				});
				lua_Tweens.set(tag, twn);
			}
		};

		setFunction("doTweenX", function(tag:String, vars:String, value:Float, duration:Float, ?ease:String = 'linear') {
			doGenericTween(tag, vars, {x: value}, duration, ease);
		});

		setFunction("doTweenY", function(tag:String, vars:String, value:Float, duration:Float, ?ease:String = 'linear') {
			doGenericTween(tag, vars, {y: value}, duration, ease);
		});

		setFunction("doTweenAngle", function(tag:String, vars:String, value:Float, duration:Float, ?ease:String = 'linear') {
			doGenericTween(tag, vars, {angle: value}, duration, ease);
		});

		setFunction("doTweenAlpha", function(tag:String, vars:String, value:Float, duration:Float, ?ease:String = 'linear') {
			doGenericTween(tag, vars, {alpha: value}, duration, ease);
		});

		setFunction("doTweenZoom", function(tag:String, vars:String, value:Float, duration:Float, ?ease:String = 'linear') {
			if (vars == "camGame" || vars == "camera") {
				var existing = lua_Tweens.get(tag);
				if (existing != null) {
					existing.cancel();
					existing.destroy();
					lua_Tweens.remove(tag);
				}
				var twn = FlxTween.tween(FlxG.camera, {zoom: value}, duration, {
					ease: CoolUtil.easeFromString(ease),
					onComplete: function(t) {
						lua_Tweens.remove(tag);
						call("onTweenCompleted", [tag]);
					}
				});
				lua_Tweens.set(tag, twn);
			} else if (vars == "camHUD") {
				var existing = lua_Tweens.get(tag);
				if (existing != null) {
					existing.cancel();
					existing.destroy();
					lua_Tweens.remove(tag);
				}
				var twn = FlxTween.tween(PlayState.instance.camHUD, {zoom: value}, duration, {
					ease: CoolUtil.easeFromString(ease),
					onComplete: function(t) {
						lua_Tweens.remove(tag);
						call("onTweenCompleted", [tag]);
					}
				});
				lua_Tweens.set(tag, twn);
			} else {
				doGenericTween(tag, vars, {zoom: value}, duration, ease);
			}
		});

		setFunction("doTweenColor", function(tag:String, vars:String, targetColor:Dynamic, duration:Float, ?ease:String = 'linear') {
			var obj:Dynamic = getActorByName(vars);
			if (obj != null) {
				var existing = lua_Tweens.get(tag);
				if (existing != null) {
					existing.cancel();
					existing.destroy();
					lua_Tweens.remove(tag);
				}
				var col:FlxColor = FlxColor.WHITE;
				if (Std.isOfType(targetColor, String)) col = FlxColor.fromString(cast targetColor);
				else if (Std.isOfType(targetColor, Int)) col = cast targetColor;

				var curCol:FlxColor = obj.color;
				var twn = FlxTween.color(obj, duration, curCol, col, {
					ease: CoolUtil.easeFromString(ease),
					onComplete: function(t) {
						lua_Tweens.remove(tag);
						call("onTweenCompleted", [tag]);
					}
				});
				lua_Tweens.set(tag, twn);
			}
		});

		setFunction("tweenPause", function(tween:String) {
			var twn:FlxTween = lua_Tweens.get(tween);
			if (twn != null) {
				FlxTweenUtil.pauseTween(twn);
			} else {
				trace('Tween $tween doesn\'t exist!', ERROR);
			}
		});

		setFunction("tweenResume", function(tween:String) {
			var twn:FlxTween = lua_Tweens.get(tween);
			if (twn != null) {
				FlxTweenUtil.resumeTween(twn);
			} else {
				trace('Tween $tween doesn\'t exist!', ERROR);
			}
		});

		setFunction("cancelTweensOf", function(object:String, ?fieldPaths:Array<String>) {
			var obj:Dynamic = getActorByName(object);
			if (obj != null) {
				FlxTween.cancelTweensOf(obj, fieldPaths);
			} else {
				trace('Object $object doesn\'t exist!', ERROR);
			}
		});

		setFunction("pauseTweensOf", function(object:String, ?fieldPaths:Array<String>) {
			var obj:Dynamic = getActorByName(object);
			if (obj != null) {
				FlxTweenUtil.pauseTweensOf(obj, fieldPaths);
			} else {
				trace('Object $object doesn\'t exist!', ERROR);
			}
		});

		setFunction("resumeTweensOf", function(object:String, ?fieldPaths:Array<String>) {
			var obj:Dynamic = getActorByName(object);
			if (obj != null) {
				FlxTweenUtil.resumeTweensOf(obj, fieldPaths);
			} else {
				trace('Object $object doesn\'t exist!', ERROR);
			}
		});

		var tweenHelper = function(target:Dynamic, values:Dynamic, time:Float, ease:Float->Float, onComplete:String, callbackArg:String) {
			if (target != null) {
				PlayState.instance.tweenManager.tween(target, values, time, {
					ease: ease,
					onComplete: function(flxTween:FlxTween) {
						if (onComplete != '' && onComplete != null) call(onComplete, [callbackArg]);
					}
				});
			}
		};

		setFunction("tweenCameraPos", function(toX:Int, toY:Int, time:Float, onComplete:String = "") {
			tweenHelper(FlxG.camera, {x: toX, y: toY}, time, FlxEase.linear, onComplete, "camera");
		});

		setFunction("tweenCameraAngle", function(toAngle:Float, time:Float, ease:String = "linear", onComplete:String = "") {
			tweenHelper(FlxG.camera, {angle: toAngle}, time, CoolUtil.easeFromString(ease), onComplete, "camera");
		});

		setFunction("tweenCameraZoom", function(toZoom:Float, time:Float, ease:String = "linear", onComplete:String = "") {
			if (PlayState.instance.cameraEventHandler == null)
				tweenHelper(PlayState.instance, {defaultCamZoom: toZoom}, time, CoolUtil.easeFromString(ease), onComplete, "camera");
		});

		setFunction("tweenHudPos", function(toX:Int, toY:Int, time:Float, onComplete:String = "") {
			tweenHelper(PlayState.instance.camHUD, {x: toX, y: toY}, time, FlxEase.linear, onComplete, "camera");
		});

		setFunction("tweenHudAngle", function(toAngle:Float, time:Float, onComplete:String = "") {
			tweenHelper(PlayState.instance.camHUD, {angle: toAngle}, time, FlxEase.linear, onComplete, "camera");
		});

		setFunction("tweenHudZoom", function(toZoom:Float, time:Float, onComplete:String = "") {
			if (PlayState.instance.cameraEventHandler == null)
				tweenHelper(PlayState.instance, {defaultHudCamZoom: toZoom}, time, FlxEase.linear, onComplete, "camera");
		});

		setFunction("hudTween", function(a:Float, step:Float, c:Float, e:String) {
			var t = step * 0.001 * c;
			var ease = easeFromString(e);
			var tweenAlpha = function(obj:FlxSprite) {
				if (obj == null) return;
				var start = obj.alpha;
				PlayState.instance.tweenManager.num(start, a, t, {
					ease: ease,
					onUpdate: function(v) { obj.alpha = FlxMath.lerp(start, a, ease(v.percent)); },
					onComplete: function(_) { obj.alpha = a; }
				});
			};

			for (actor in [
				PlayState.instance.healthBar,
				PlayState.instance.healthBarBG,
				PlayState.instance.scoreTxt,
				PlayState.instance.timeBar,
				PlayState.instance.ratingText
			]) tweenAlpha(actor);

			forEachHudIcon(tweenAlpha);
		});

		setFunction("hudSet", function(a:Float) {
			for (actor in [
				PlayState.instance.healthBar,
				PlayState.instance.healthBarBG,
				PlayState.instance.scoreTxt,
				PlayState.instance.timeBar,
				PlayState.instance.ratingText
			]) {
				if (actor != null)
					actor.alpha = a;
			}

			forEachHudIcon(function(icon) { icon.alpha = a; });
		});

		setFunction("tweenPos", function(id:String, toX:Int, toY:Int, time:Float, ?onComplete:String = "") {
			tweenHelper(getActorByName(id), {x: toX, y: toY}, time, FlxEase.linear, onComplete, id);
		});

		setFunction("tweenPosXAngle", function(id:String, toX:Int, toAngle:Float, time:Float, onComplete:String = "") {
			tweenHelper(getActorByName(id), {x: toX, angle: toAngle}, time, FlxEase.linear, onComplete, id);
		});

		setFunction("tweenPosYAngle", function(id:String, toY:Int, toAngle:Float, time:Float, onComplete:String = "") {
			tweenHelper(getActorByName(id), {y: toY, angle: toAngle}, time, FlxEase.linear, onComplete, id);
		});

		setFunction("tweenAngle", function(id:String, toAngle:Int, time:Float, onComplete:String = "") {
			tweenHelper(getActorByName(id), {angle: toAngle}, time, FlxEase.quintInOut, onComplete, id);
		});

		setFunction("tweenCameraPosOut", function(toX:Int, toY:Int, time:Float, onComplete:String = "") {
			tweenHelper(FlxG.camera, {x: toX, y: toY}, time, FlxEase.cubeOut, onComplete, "camera");
		});

		setFunction("tweenCameraAngleOut", function(toAngle:Float, time:Float, onComplete:String = "") {
			tweenHelper(FlxG.camera, {angle: toAngle}, time, FlxEase.cubeOut, onComplete, "camera");
		});

		setFunction("tweenCameraZoomOut", function(toZoom:Float, time:Float, onComplete:String = "") {
			if (PlayState.instance.cameraEventHandler == null)
				tweenHelper(PlayState.instance, {defaultCamZoom: toZoom}, time, FlxEase.cubeOut, onComplete, "camera");
		});

		setFunction("tweenHudPosOut", function(toX:Int, toY:Int, time:Float, onComplete:String = "") {
			tweenHelper(PlayState.instance.camHUD, {x: toX, y: toY}, time, FlxEase.cubeOut, onComplete, "camera");
		});

		setFunction("tweenHudAngleOut", function(toAngle:Float, time:Float, onComplete:String = "") {
			tweenHelper(PlayState.instance.camHUD, {angle: toAngle}, time, FlxEase.cubeOut, onComplete, "camera");
		});

		setFunction("tweenHudZoomOut", function(toZoom:Float, time:Float, onComplete:String = "") {
			if (PlayState.instance.cameraEventHandler == null)
				tweenHelper(PlayState.instance, {defaultHudCamZoom: toZoom}, time, FlxEase.cubeOut, onComplete, "camera");
		});

		setFunction("tweenPosOut", function(id:String, toX:Int, toY:Int, time:Float, onComplete:String = "") {
			tweenHelper(getActorByName(id), {x: toX, y: toY}, time, FlxEase.cubeOut, onComplete, id);
		});

		setFunction("tweenPosXAngleOut", function(id:String, toX:Int, toAngle:Float, time:Float, onComplete:String = "") {
			tweenHelper(getActorByName(id), {x: toX, angle: toAngle}, time, FlxEase.cubeOut, onComplete, id);
		});

		setFunction("tweenPosYAngleOut", function(id:String, toY:Int, toAngle:Float, time:Float, onComplete:String = "") {
			tweenHelper(getActorByName(id), {y: toY, angle: toAngle}, time, FlxEase.cubeOut, onComplete, id);
		});

		setFunction("tweenAngleOut", function(id:String, toAngle:Int, time:Float, onComplete:String = "") {
			tweenHelper(getActorByName(id), {angle: toAngle}, time, FlxEase.cubeOut, onComplete, id);
		});

		setFunction("tweenCameraPosIn", function(toX:Int, toY:Int, time:Float, onComplete:String = "") {
			tweenHelper(FlxG.camera, {x: toX, y: toY}, time, FlxEase.cubeIn, onComplete, "camera");
		});

		setFunction("tweenCameraAngleIn", function(toAngle:Float, time:Float, onComplete:String = "") {
			tweenHelper(FlxG.camera, {angle: toAngle}, time, FlxEase.cubeIn, onComplete, "camera");
		});

		setFunction("tweenCameraZoomIn", function(toZoom:Float, time:Float, onComplete:String = "") {
			if (PlayState.instance.cameraEventHandler == null)
				tweenHelper(PlayState.instance, {defaultCamZoom: toZoom}, time, FlxEase.quintInOut, onComplete, "camera");
		});

		setFunction("tweenHudPosIn", function(toX:Int, toY:Int, time:Float, onComplete:String = "") {
			tweenHelper(PlayState.instance.camHUD, {x: toX, y: toY}, time, FlxEase.cubeIn, onComplete, "camera");
		});

		setFunction("tweenHudAngleIn", function(toAngle:Float, time:Float, onComplete:String = "") {
			tweenHelper(PlayState.instance.camHUD, {angle: toAngle}, time, FlxEase.cubeIn, onComplete, "camera");
		});

		setFunction("tweenHudZoomIn", function(toZoom:Float, time:Float, onComplete:String = "") {
			if (PlayState.instance.cameraEventHandler == null)
				tweenHelper(PlayState.instance, {defaultHudCamZoom: toZoom}, time, FlxEase.cubeIn, onComplete, "camera");
		});

		setFunction("tweenPosIn", function(id:String, toX:Int, toY:Int, time:Float, onComplete:String = "") {
			tweenHelper(getActorByName(id), {x: toX, y: toY}, time, FlxEase.cubeIn, onComplete, id);
		});

		setFunction("tweenPosXAngleIn", function(id:String, toX:Int, toAngle:Float, time:Float, onComplete:String = "") {
			tweenHelper(getActorByName(id), {x: toX, angle: toAngle}, time, FlxEase.cubeIn, onComplete, id);
		});

		setFunction("tweenPosYAngleIn", function(id:String, toY:Int, toAngle:Float, time:Float, onComplete:String = "") {
			tweenHelper(getActorByName(id), {y: toY, angle: toAngle}, time, FlxEase.cubeIn, onComplete, id);
		});

		setFunction("tweenAngleIn", function(id:String, toAngle:Int, time:Float, onComplete:String = "") {
			tweenHelper(getActorByName(id), {angle: toAngle}, time, FlxEase.cubeIn, onComplete, id);
		});

		setFunction("tweenLetterSpacing", function(id:String, toSpacing:Float, time:Float, easeStr:String = "", onComplete:String = "") {
			var actor = getActorByName(id);
			if (actor != null && Std.isOfType(actor, flixel.text.FlxText)) {
				var txt:flixel.text.FlxText = cast actor;
				var ease = CoolUtil.easeFromString(easeStr);
				
				var rawVal:Dynamic = Reflect.getProperty(txt, "letterSpacing");
				var startVal:Float = (rawVal == null) ? 0.0 : rawVal;

				PlayState.instance.tweenManager.num(startVal, toSpacing, time, {
					ease: ease,
					onUpdate: function(flxTween:FlxTween) {
						var ting = flixel.math.FlxMath.lerp(startVal, toSpacing, ease(flxTween.percent));
						Reflect.setProperty(txt, "letterSpacing", Math.round(ting));
						
						var oldSize:Int = Reflect.getProperty(txt, "size");
						Reflect.setProperty(txt, "size", oldSize + 1);
						Reflect.setProperty(txt, "size", oldSize);
						
						txt.autoSize = false;
						txt.fieldWidth = txt.textField.textWidth + (ting * txt.text.length) + 10;
					},
					onComplete: function(flxTween:FlxTween) {
						Reflect.setProperty(txt, "letterSpacing", Math.round(toSpacing));
						
						var oldSize:Int = Reflect.getProperty(txt, "size");
						Reflect.setProperty(txt, "size", oldSize + 1);
						Reflect.setProperty(txt, "size", oldSize);
						
						txt.autoSize = false;
						txt.fieldWidth = txt.textField.textWidth + (toSpacing * txt.text.length) + 10;
						
						if (onComplete != '' && onComplete != null) {
							call(onComplete, [id]);
						}
					}
				});
			}
		});

		setFunction("tweenFadeIn", function(id:String, toAlpha:Float, time:Float, onComplete:String = "") {
			tweenHelper(getActorByName(id), {alpha: toAlpha}, time, FlxEase.circIn, onComplete, id);
		});

		setFunction("tweenFadeOut", function(id:String, toAlpha:Float, time:Float, onComplete:String = "") {
			tweenHelper(getActorByName(id), {alpha: toAlpha}, time, FlxEase.circOut, onComplete, id);
		});

		setFunction("tweenFadeCubeInOut", function(id:String, toAlpha:Float, time:Float, onComplete:String = "") {
			tweenHelper(getActorByName(id), {alpha: toAlpha}, time, FlxEase.cubeInOut, onComplete, id);
		});

		setFunction(["tweenScaleX", "tweenActorScaleX"], function(id:String, toScale:Float, time:Float, easeStr:String = "", onComplete:String = "") {
			var actor = getActorByName(id);
			tweenHelper(actor != null ? actor.scale : null, {x: toScale}, time, CoolUtil.easeFromString(easeStr), onComplete, id);
		});

		setFunction(["tweenScaleY", "tweenActorScaleY"], function(id:String, toScale:Float, time:Float, easeStr:String = "", onComplete:String = "") {
			var actor = getActorByName(id);
			tweenHelper(actor != null ? actor.scale : null, {y: toScale}, time, CoolUtil.easeFromString(easeStr), onComplete, id);
		});

		setFunction(["tweenScale", "tweenActorScale", "doTweenScale"], function(id:String, toScale:Float, time:Float, easeStr:String = "", onComplete:String = "") {
			var actor = getActorByName(id);
			tweenHelper(actor != null ? actor.scale : null, {x: toScale, y: toScale}, time, CoolUtil.easeFromString(easeStr), onComplete, id);
		});


		setFunction("tweenActorProperty", function(id:Dynamic, prop:String, value:Dynamic, time:Float, easeStr:String = "linear") {
			var actor = getActorByName(Std.string(id));
			var ease = easeFromString(easeStr);

			if (actor != null && Reflect.getProperty(actor, prop) != null) {
				var startVal = Reflect.getProperty(actor, prop);
				PlayState.instance.tweenManager.num(startVal, value, time, {
					onUpdate: function(tween:FlxTween) {
						var ting = FlxMath.lerp(startVal, value, ease(tween.percent));
						Reflect.setProperty(actor, prop, ting);
					},
					ease: ease,
					onComplete: function(tween:FlxTween) {
						Reflect.setProperty(actor, prop, value);
					}
				});
			}
		});

		
		setFunction("setActorRTXShader", function(actorStr:String, shaderName:String) {
			if (!Options.getData("shaders"))
				return;

			var shad = lua_Shaders.get(shaderName);
			var actor = getActorByName(actorStr);

			if(actor != null && shad != null)
			{
				var rtx:RTXShader = cast shad;

				@:privateAccess
				var stage_Data = PlayState.instance.stage.stageData;

				if (stage_Data.rtxData != null)
				{
					var overlay = FlxColor.fromString(stage_Data.rtxData.overlay);
					var satin = FlxColor.fromString(stage_Data.rtxData.satin);
					var inner = FlxColor.fromString(stage_Data.rtxData.inner);

					rtx.overlayColor.value = [overlay.redFloat, overlay.greenFloat, overlay.blueFloat, stage_Data.rtxData.overlayAlpha];
					rtx.satinColor.value = [satin.redFloat, satin.greenFloat, satin.blueFloat, stage_Data.rtxData.satinAlpha];
					rtx.innerShadowColor.value = [inner.redFloat, inner.greenFloat, inner.blueFloat, stage_Data.rtxData.innerAlpha];

					rtx.innerShadowAngle.value = [stage_Data.rtxData.innerAngle];
					rtx.innerShadowDistance.value = [stage_Data.rtxData.innerDistance];

					if (stage_Data.rtxData.pointLight != null)
					{
					//	rtx.pointLight = stage_Data.rtxData.pointLight;
					//	rtx.lightX = stage_Data.rtxData.lightX;
					//	rtx.lightY = stage_Data.rtxData.lightY;
					}
				}

				actor.shader = Reflect.getProperty(shad, 'shader');
			}
		});
			
		setFunction("tweenActorRTXColor", 
			function(character:String, prop:String, value:String, time:Float, easeStr:String = "linear") {
				if (!Options.getData("shaders")) return;

				var ease = easeFromString(easeStr);
				var char:Character = getCharacterByName(character);
				if (char != null) {
					var startVal:FlxColor = Reflect.getProperty(char.rtxShader, prop);
					var endVal:FlxColor = FlxColor.fromString(value);

					PlayState.instance.tweenManager.color(null, time, startVal, endVal, {
						onUpdate: function(tween:FlxTween) {
							var ting = FlxColor.interpolate(startVal, endVal, ease(tween.percent));
							Reflect.setProperty(char.rtxShader, prop, ting);
						},
						ease: ease,
						onComplete: function(_) {
							Reflect.setProperty(char.rtxShader, prop, endVal);
						}
					});
				}
			}
		);

	
		setFunction("getActorRTXColor", 
			function(character:String, prop:String) {
				var char:Character = getCharacterByName(character);
				if (char != null && char.rtxShader != null) {
					var col:FlxColor = Reflect.getProperty(char.rtxShader, prop);
					return col.toHexString();
				}
				return null;
			}
		);

		setFunction("setActorRTXProperty",
			function(character:String, prop:String, value:Dynamic) {

				if (!Options.getData("shaders"))
					return;

				var char:Character = getCharacterByName(character);

				if (char == null)
					return;

				function apply(c:Character) {

					var shader = c.rtxShader;

					if (shader == null)
						return;

					// ===== FLOAT =====
					if (value is Float) {

						Reflect.setProperty(
							shader,
							prop,
							Std.parseFloat(Std.string(value))
						);
					}

					// ===== BOOL =====
					else if (value is Bool) {

						Reflect.setProperty(
							shader,
							prop,
							value
						);
					}

					// ===== ARRAY =====
					else if (value is Array) {

						var arr:Array<Dynamic> = cast value;

						// FLOAT ARRAY
						if (arr.length > 0 && arr[0] is Float) {

							var floatArr:Array<Float> = [];

							for (v in arr) {
								floatArr.push(
									Std.parseFloat(Std.string(v))
								);
							}

							Reflect.setProperty(
								shader,
								prop,
								floatArr
							);
						}

						// BOOL ARRAY
						else if (arr.length > 0 && arr[0] is Bool) {

							Reflect.setProperty(
								shader,
								prop,
								arr
							);
						}

						// INT ARRAY
						else {

							var intArr:Array<Int> = [];

							for (v in arr) {
								intArr.push(
									Std.parseInt(Std.string(v))
								);
							}

							Reflect.setProperty(
								shader,
								prop,
								intArr
							);
						}
					}

					// ===== DEFAULT =====
					else {

						Reflect.setProperty(
							shader,
							prop,
							value
						);
					}
				}

				if (char.otherCharacters != null) {

					for (c in char.otherCharacters) {
						apply(c);
					}

				} else {

					apply(char);
				}
			});
		setFunction("tweenActorRTXProperty",
			function(character:String, prop:String, value:Dynamic, time:Float, easeStr:String = "linear") {

				if (!Options.getData("shaders")) return;

				var ease = easeFromString(easeStr);
				var char:Character = getCharacterByName(character);
				if (char == null) return;

				function tweenProperty(c:Character, startVal:Dynamic, endVal:Dynamic) {

					PlayState.instance.tweenManager.num(0, 1, time, {
						onUpdate: function(tween:FlxTween) {

							var t = ease(tween.percent);

							// ðŸ”¥ ARRAY SUPPORT (vec2/vec3/vec4)
							if (Std.isOfType(startVal, Array) && Std.isOfType(endVal, Array)) {

								var arrStart:Array<Dynamic> = startVal;
								var arrEnd:Array<Dynamic> = endVal;

								var result:Array<Dynamic> = [];
								var len:Int = Std.int(Math.min(arrStart.length, arrEnd.length));

								for (i in 0...len) {
									result.push(
										FlxMath.lerp(
											Std.parseFloat(arrStart[i]),
											Std.parseFloat(arrEnd[i]),
											t
										)
									);
								}

								Reflect.setProperty(c.rtxShader, prop, result);

							} 
							// ðŸ”¥ SCALAR SUPPORT
							else {
								var v = FlxMath.lerp(
									Std.parseFloat(startVal),
									Std.parseFloat(endVal),
									t
								);
								Reflect.setProperty(c.rtxShader, prop, v);
							}
						},

						onComplete: function(_) {
							Reflect.setProperty(c.rtxShader, prop, endVal);
						}
					});
				}

				if (char.otherCharacters != null) {
					for (c in char.otherCharacters) {
						var startVal = Reflect.getProperty(c.rtxShader, prop);
						tweenProperty(c, startVal, value);
					}
				} else {
					var startVal = Reflect.getProperty(char.rtxShader, prop);
					tweenProperty(char, startVal, value);
				}
			});

		setFunction("setActorProperty", function(id:Dynamic, prop:String, value:Dynamic) {
			var actor = getActorByName(Std.string(id));
			if (actor != null && Reflect.getProperty(actor, prop) != null) {
				Reflect.setProperty(actor, prop, value);
			}
		});

		setFunction("tweenActorColor", function(id:String, r1:Int, g1:Int, b1:Int, r2:Int, g2:Int, b2:Int, time:Float, onComplete:String = "") {
			var actor:FlxSprite = getActorByName(id);
			if (actor != null) {
				var currentAlpha:Int = Std.int(actor.alpha * 255);
				FlxTween.color(actor, time, FlxColor.fromRGB(r1, g1, b1, currentAlpha), FlxColor.fromRGB(r2, g2, b2, currentAlpha), {
					ease: FlxEase.circIn,
					onComplete: function(flxTween:FlxTween) {
						if (onComplete != '' && onComplete != null) {
							call(onComplete, [id]);
						}
					}
				});
			}
		});


		setFunction("tweenActorColorTrans", function(id:String, r1:Int, g1:Int, b1:Int, r2:Int, g2:Int, b2:Int, time:Float, onComplete:String = "") {
			var actor = getActorByName(id);

			if (actor != null) {
				FlxTween.num(0, 1, time, {
					ease: FlxEase.circIn,
					onUpdate: function(tween:FlxTween) {
						if (actor == null || !actor.exists || actor.colorTransform == null) {
							tween.cancel();
							return;
						}
						var t = tween.scale;

						var r = Std.int(r1 + (r2 - r1) * t);
						var g = Std.int(g1 + (g2 - g1) * t);
						var b = Std.int(b1 + (b2 - b1) * t);

						actor.setColorTransform(0, 0, 0, 1, r, g, b, 0);
					},
					onComplete: function(tween:FlxTween) {
						if (onComplete != '' && onComplete != null) {
							call(onComplete, [id]);
						}
					}
				});
			}
		});


		// properties

	setFunction("set", function(property:Dynamic, value:Dynamic):Void {
		try {
			var seperated_path:Array<String> = property.split('.');
			var object:Dynamic = getActorByName(seperated_path[0]);
			var property:String = property;

			for (i in 1...seperated_path.length) {
				if (i < seperated_path.length - 1) {
					if (seperated_path[i].contains('[')) {
						var array = seperated_path[i].substr(0, seperated_path[i].indexOf('['));
						object = Reflect.getProperty(object, array)[Std.parseInt(seperated_path[i].split(']')[0].split('[')[1])];
					} else
						object = Reflect.getProperty(object, seperated_path[i]);
				} else
					property = seperated_path[i];
			}

			if (seperated_path.length > 1) {
				if (object != null) {

					var root = getActorByName(seperated_path[0]);
					if (Std.isOfType(root, Character) && seperated_path.length >= 2 && seperated_path[1] == "scale") {
						var c:Character = cast root;
						var num:Null<Float> = (value is Float) ? value : Std.parseFloat(value);

						if (num == null)
							num = (c.graphicSize != 0) ? c.scale.x / c.graphicSize : 1.0;

						var multY:Float = (c.graphicSize != 0) ? c.scale.y / c.graphicSize : 1.0;

						if (seperated_path.length == 2)
							applyActorScale(c, num, num);
						else if (property == 'x')
							applyActorScale(c, num, multY);
						else if (property == 'y')
							applyActorScale(c, (c.graphicSize != 0) ? c.scale.x / c.graphicSize : 1.0, num);
						else
							applyActorScale(c, num, num);
					}
					else
						Reflect.setProperty(object, property, value);
				}
			} else {
				if (Reflect.getProperty(PlayState.instance, property) != null)
					Reflect.setProperty(PlayState.instance, property, value);
				else
					Reflect.setProperty(PlayState, property, value);
			}
			} catch (e:Dynamic) { Main.logSilentError(e, "LuaScript: set property on PlayState"); }
		});

	setFunction("get", function(property:Dynamic):Dynamic {
		try {
			var seperated_path:Array<String> = property.split('.');
			var object:Dynamic = getActorByName(seperated_path[0]);
			var property:String = property;

			for (i in 1...seperated_path.length) {
				if (i < seperated_path.length - 1)
					object = Reflect.getProperty(object, seperated_path[i]);
				else
					property = seperated_path[i];
			}

			if (seperated_path.length > 1) {
				if (object != null)
					return Reflect.getProperty(object, property);
			} else {
				if (Reflect.getProperty(PlayState.instance, property) != null)
					return Reflect.getProperty(PlayState.instance, property);
				else
					return Reflect.getProperty(PlayState, property);
			}
		} catch (e:Dynamic) { Main.logSilentError(e, "LuaScript: get property from PlayState"); }
		return null;
	});

		setFunction("setClass", function(class_name:String, property:Dynamic, value:Dynamic):Void {
			var seperated_path:Array<String> = property.split('.');
			var object:Dynamic = Type.resolveClass(class_name);
			var property:String = property;

			for (i in 1...seperated_path.length) {
				if (i < seperated_path.length - 1) {
					if (seperated_path[i].contains('[')) {
						var array = seperated_path[i].substr(0, seperated_path[i].indexOf('['));
						object = Reflect.getProperty(object, array)[Std.parseInt(seperated_path[i].split(']')[0].split('[')[1])];
					} else
						object = Reflect.getProperty(object, seperated_path[i]);
				} else
					property = seperated_path[i];
			}

			Reflect.setProperty(object != Type.resolveClass(class_name) ? object : Type.resolveClass(class_name), property, value);
		});

		setFunction("getClass", function(class_name:String, property:Dynamic):Dynamic {
			var seperated_path:Array<String> = property.split('.');
			var object:Dynamic = Type.resolveClass(class_name);
			var property:String = property;

			if (seperated_path.length > 1) {
				for (i in 0...seperated_path.length) {
					if (i < seperated_path.length - 1)
						object = Reflect.getProperty(object, seperated_path[i]);
					else
						property = seperated_path[i];
				}
			}

			return Reflect.getProperty(object != Type.resolveClass(class_name) ? object : Type.resolveClass(class_name), property);
		});

		setFunction("setProperty", function(object:String, ?property:Dynamic, ?value:Dynamic) {
			try {
				var targetObj = object;
				var targetProp = property;
				var targetVal = value;

				// Psych compatibility: setProperty('boyfriend.x', 500)
				if (value == null && property != null && object.indexOf('.') != -1) {
					var split = object.split('.');
					targetObj = split[0];
					targetProp = split.slice(1).join('.');
					targetVal = property;
				}

				#if CAMERA_TOOLS
				if (PlayState.instance.cameraEventHandler != null)
				{
					var camObj = Std.string(targetObj).toLowerCase();
					if (camObj == "camgame" || camObj == "camhud" || camObj == "camother") return;
				}
				#end
				if (targetObj != "") {
					var rootObj:Dynamic = Reflect.getProperty(PlayState.instance, targetObj);
					if (rootObj == null) rootObj = Reflect.getProperty(PlayState, targetObj);
					if (rootObj == null) rootObj = getActorByName(targetObj);

					if (rootObj != null) {
						var propStr = Std.string(targetProp);
						if (propStr.indexOf('.') != -1) {
							var parts = propStr.split('.');
							var cur:Dynamic = rootObj;
							for (i in 0...parts.length - 1) {
								if (cur != null) cur = Reflect.getProperty(cur, parts[i]);
							}
							if (cur != null) Reflect.setProperty(cur, parts[parts.length - 1], targetVal);
						} else {
							Reflect.setProperty(rootObj, propStr, targetVal);
						}
					}
				} else {
					if (Reflect.getProperty(PlayState.instance, targetProp) != null)
						Reflect.setProperty(PlayState.instance, targetProp, targetVal);
					else
						Reflect.setProperty(PlayState, targetProp, targetVal);
				}
			} catch (e:Dynamic) { Main.logSilentError(e, "LuaScript: setProperty on PlayState"); }
		});

		setFunction("setProperties", function(properties:Array<Dynamic>) {
			try {
				if (properties != null) {
					for (propData in properties) {
						if (propData != null && propData.length >= 3) {
							var object:String = Std.string(propData[0]);
							var property:String = Std.string(propData[1]);
							var value:Dynamic = propData[2];

							#if CAMERA_TOOLS
							if (PlayState.instance.cameraEventHandler != null)
							{
								var camObj = object.toLowerCase();
								if (camObj == "camgame" || camObj == "camhud" || camObj == "camother") continue;
							}
							#end
							if (object != "") {
								if (Reflect.getProperty(PlayState.instance, object) != null)
									Reflect.setProperty(Reflect.getProperty(PlayState.instance, object), property, value);
								else
									Reflect.setProperty(Reflect.getProperty(PlayState, object), property, value);
							} else {
								if (Reflect.getProperty(PlayState.instance, property) != null)
									Reflect.setProperty(PlayState.instance, property, value);
								else
									Reflect.setProperty(PlayState, property, value);
							}
						}
					}
				}
			} catch (e:Dynamic) { Main.logSilentError(e, "LuaScript: setProperties bulk set"); }
		});

		setFunction("getProperty", function(object:String, ?property:String) {
			try {
				// Psych compatibility: getProperty('boyfriend.x') or getProperty('curStep')
				if (property == null || property == "") {
					if (object.indexOf('.') != -1) {
						var parts = object.split('.');
						var cur:Dynamic = Reflect.getProperty(PlayState.instance, parts[0]);
						if (cur == null) cur = Reflect.getProperty(PlayState, parts[0]);
						if (cur == null) cur = getActorByName(parts[0]);
						for (i in 1...parts.length) {
							if (cur != null) cur = Reflect.getProperty(cur, parts[i]);
						}
						return cur;
					} else {
						var val:Dynamic = Reflect.getProperty(PlayState.instance, object);
						if (val == null) val = Reflect.getProperty(PlayState, object);
						return val;
					}
				}

				if (object != "") {
					var root:Dynamic = Reflect.getProperty(PlayState.instance, object);
					if (root == null) root = Reflect.getProperty(PlayState, object);
					if (root == null) root = getActorByName(object);
					if (root != null)
						return Reflect.getProperty(root, property);
				} else {
					if (Reflect.getProperty(PlayState.instance, property) != null)
						return Reflect.getProperty(PlayState.instance, property);
					else
						return Reflect.getProperty(PlayState, property);
				}
			} catch (e:Dynamic) { Main.logSilentError(e, "LuaScript: getProperty from PlayState"); }
			return null;
		});

		setFunction("getPropertyFromGroup", function(obj:String, index:Int, variable:Dynamic) {
			try {
				var realObject:Dynamic = Reflect.getProperty(PlayState.instance, obj);
				if (realObject == null) realObject = Reflect.getProperty(PlayState, obj);
				if (realObject != null) {
					var member:Dynamic = null;
					var membersList:Dynamic = Reflect.getProperty(realObject, "members");
					if (membersList != null) {
						member = membersList[index];
					} else if (Std.isOfType(realObject, Array)) {
						member = (cast realObject:Array<Dynamic>)[index];
					}
					if (member != null) {
						if (variable == null || Std.string(variable) == "") return member;
						var split = Std.string(variable).split(".");
						var cur:Dynamic = member;
						for (p in split) {
							if (cur != null) cur = Reflect.getProperty(cur, p);
						}
						return cur;
					}
				}
			} catch(e:Dynamic) { Main.logSilentError(e, "LuaScript: getPropertyFromGroup"); }
			return null;
		});

		setFunction("setPropertyFromGroup", function(obj:String, index:Int, variable:Dynamic, value:Dynamic) {
			try {
				var realObject:Dynamic = Reflect.getProperty(PlayState.instance, obj);
				if (realObject == null) realObject = Reflect.getProperty(PlayState, obj);
				if (realObject != null) {
					var member:Dynamic = null;
					var membersList:Dynamic = Reflect.getProperty(realObject, "members");
					if (membersList != null) {
						member = membersList[index];
					} else if (Std.isOfType(realObject, Array)) {
						member = (cast realObject:Array<Dynamic>)[index];
					}
					if (member != null) {
						var split = Std.string(variable).split(".");
						if (split.length == 1) {
							Reflect.setProperty(member, split[0], value);
						} else {
							var cur:Dynamic = member;
							for (i in 0...split.length - 1) {
								if (cur != null) cur = Reflect.getProperty(cur, split[i]);
							}
							if (cur != null) Reflect.setProperty(cur, split[split.length - 1], value);
						}
					}
				}
			} catch(e:Dynamic) { Main.logSilentError(e, "LuaScript: setPropertyFromGroup"); }
		});

		setFunction("getPropertyFromClass", function(className:String, variable:String) {
			{
				var variablePaths = variable.split(".");

				if (variablePaths.length > 1) {
					var selectedVariable:Dynamic = Reflect.getProperty(Type.resolveClass(className), variablePaths[0]);

					for (i in 1...variablePaths.length - 1) {
						selectedVariable = Reflect.getProperty(selectedVariable, variablePaths[i]);
					}

					return Reflect.getProperty(selectedVariable, variablePaths[variablePaths.length - 1]);
				}

				return Reflect.getProperty(Type.resolveClass(className), variable);
			}
		});

		setFunction("setPropertyFromClass", function(className:String, variable:String, value:Dynamic) {
			{
				var variablePaths:Array<String> = variable.split('.');

				if (variablePaths.length > 1) {
					var selectedVariable:Dynamic = Reflect.getProperty(Type.resolveClass(className), variablePaths[0]);

					for (i in 1...variablePaths.length - 1) {
						selectedVariable = Reflect.getProperty(selectedVariable, variablePaths[i]);
					}

					return Reflect.setProperty(selectedVariable, variablePaths[variablePaths.length - 1], value);
				}

				return Reflect.setProperty(Type.resolveClass(className), variable, value);
			}
		});

		// song stuff

		setFunction("setSongPosition", function(position:Float) {
			Conductor.songPosition = position;
			set('songPos', Conductor.songPosition);
		});

		setFunction("getSongPosition", function() {
			return Conductor.songPosition;
		});

		setFunction("stopSong", function() {
			{
				PlayState.instance.paused = true;

				FlxG.sound.music.volume = 0;
				PlayState.instance.vocals.volume = 0;

				PlayState.instance.notes.clear();
				PlayState.instance.remove(PlayState.instance.notes);

				FlxG.sound.music.time = 0;
				PlayState.instance.vocals.time = 0;

				Conductor.songPosition = 0;
				PlayState.songMultiplier = 0;

				Conductor.recalculateStuff(PlayState.songMultiplier);

				FlxG.sound.music.pitch = PlayState.songMultiplier;

				if (PlayState.instance.vocals.playing)
					PlayState.instance.vocals.pitch = PlayState.songMultiplier;

				PlayState.instance.stopSong = true;
			}

			return true;
		});

		setFunction("endSong", function() {
			FlxG.sound.music.time = FlxG.sound.music.length;
			PlayState.instance.vocals.time = FlxG.sound.music.length;

			PlayState.instance.health = 500000;
			PlayState.instance.invincible = true;

			PlayState.instance.stopSong = false;
			PlayState.instance.resyncVocals();
		});

		setFunction(["getCharFromEvent", "charFromEvent"], function(eventId:String) {
			switch (eventId.toLowerCase()) {
				case "girlfriend" | "gf" | "player3" | "2":
					return "girlfriend";
				case "dad" | "opponent" | "player2" | "1":
					return "dad";
				case "bf" | "boyfriend" | "player" | "player1" | "0":
					return "boyfriend";
			}

			return eventId;
		});

		setFunction("tweenStageColorSwap", function(prop:String, value:Dynamic, time:Float, easeStr:String = "linear") {
			var actor = PlayState.instance.stage.colorSwap;
			var ease = easeFromString(easeStr);

			if (actor != null) {
				var startVal = Reflect.getProperty(actor, prop);

				PlayState.instance.tweenManager.num(startVal, value, time, {
					onUpdate: function(tween:FlxTween) {
						var ting = FlxMath.lerp(startVal, value, ease(tween.percent));
						Reflect.setProperty(actor, prop, ting);
					},
					ease: ease,
					onComplete: function(tween:FlxTween) {
						Reflect.setProperty(actor, prop, value);
					}
				});
			}
		});

setFunction("setStageColorSwap", function(prop:String, value:Dynamic) {
    var stage = PlayState.instance.stage;

    var actor = stage.ensureColorSwap(); 
    Reflect.setProperty(actor, prop, value);

    for (obj in stage.stageObjects) {
        var spr:FlxSprite = obj[1];
        if (spr != null) {
            spr.shader = actor.shader;
        }
    }
});

		setFunction("setStageColorSwapEnabled", function(value:Bool) {
			PlayState.instance.stage.setStageColorSwapEnabled(value);
		});


		setFunction("getStrumTimeFromStep", function(step:Float) {
			var beat = step * 0.25;
			var totalTime:Float = 0;
			var curBpm = Conductor.bpm;
			if (PlayState.SONG != null)
				curBpm = PlayState.SONG.bpm;
			for (i in 0...Math.floor(beat)) {
				if (Conductor.bpmChangeMap.length > 0) {
					for (j in 0...Conductor.bpmChangeMap.length) {
						if (totalTime >= Conductor.bpmChangeMap[j].songTime)
							curBpm = Conductor.bpmChangeMap[j].bpm;
					}
				}
				totalTime += (60 / curBpm) * 1000;
			}

			var leftOverBeat = beat - Math.floor(beat);
			totalTime += (60 / curBpm) * 1000 * leftOverBeat;

			return totalTime;
		});

		// shader bullshit

		setFunction("setActor3DShader", function(id:String, ?speed:Float = 3, ?frequency:Float = 10, ?amplitude:Float = 0.25) {
			var actor = getActorByName(id);

			if (actor != null) {
				var funnyShader:shaders.Shaders.ThreeDEffect = shaders.Shaders.newEffect("3d");
				funnyShader.waveSpeed = speed;
				funnyShader.waveFrequency = frequency;
				funnyShader.waveAmplitude = amplitude;
				lua_Shaders.set(id, funnyShader);

				actor.shader = funnyShader.shader;
			}
		});

		setFunction("setActorNoShader", function(id:String) {
			var actor = getActorByName(id);

			if (actor != null) {
				lua_Shaders.remove(id);
				actor.shader = null;
			}
		});

		 setFunction("makeCameraSpriteClone", function(name:String, cam:String)
        {
            var camera = getCameraByName(cam).cam;
            var sprite = new FlxSprite();
            @:privateAccess
            var pixels = camera._flashBitmap.bitmapData;
            sprite.loadGraphic(pixels);
            sprite.cameras = [camera];

            lua_Sprites.set(name, sprite);
            PlayState.instance.add(sprite);
        });

		setFunction("createCustomShader", function(id:String, frag:String, ?vert:String) {
			var vertTarget:String = (vert != null && vert != "") ? vert : frag;
			var _vert:String = null;
			var _frag:String = Assets.exists(Paths.frag(frag)) ? Assets.getText(Paths.frag(frag)) : (sys.FileSystem.exists('mods/' + utilities.Options.getData("curMod") + '/shaders/' + frag + '.frag') ? sys.io.File.getContent('mods/' + utilities.Options.getData("curMod") + '/shaders/' + frag + '.frag') : null);
			if (vertTarget != null) {
				if (Assets.exists(Paths.vert(vertTarget)))
					_vert = Assets.getText(Paths.vert(vertTarget));
				else if (sys.FileSystem.exists('mods/' + utilities.Options.getData("curMod") + '/shaders/' + vertTarget + '.vert'))
					_vert = sys.io.File.getContent('mods/' + utilities.Options.getData("curMod") + '/shaders/' + vertTarget + '.vert');
			}
			if (_frag != null) {
				var cs = new CustomShader(_frag, _vert);
				cs.fragFileName = frag + ".frag";
				cs.vertFileName = vertTarget + ".vert";
				lua_Custom_Shaders.set(id, cs);
			}
		});

		setFunction("setActorCustomShader", function(id:String, actor:String) {
			if (!Options.getData("shaders"))
				return;

			var funnyCustomShader:CustomShader = lua_Custom_Shaders.get(id);
			var char = getCharacterByName(actor);
			if (char != null && char.otherCharacters != null && char.otherCharacters.length > 0) {
				for (c in 0...char.otherCharacters.length)
					char.otherCharacters[c].shader = funnyCustomShader;
				return;
			}
			var spr = getActorByName(actor);
			if (spr != null && funnyCustomShader != null)
				spr.shader = funnyCustomShader;
		});

		setFunction("setActorNoCustomShader", function(actor:String) {
			getActorByName(actor).shader = null;
		});

		setFunction(["setCameraCustomShader", "pushShaderToCamera"], function(id:String, camera:String) {
			if (!Options.getData("shaders"))
				return;

			var cam = lua_Cameras.get(camera);
			var funnyCustomShader:CustomShader = lua_Custom_Shaders.get(id);
			if (cam != null && funnyCustomShader != null) {
				cam.shaders.push(new ShaderFilter(funnyCustomShader));
				cam.shaderNames.push(id);
				cam.cam.filters = cam.shaders;
			}
		});

		setFunction("setCameraNoCustomShader", function(camera:String) {
			if (!Options.getData("shaders"))
				return;
			cameraFromString(camera).filters = null;
		});

		setFunction(["getCustomShaderBool", "getShaderBool"], function(id:String, property:String) {
			var funnyCustomShader:CustomShader = lua_Custom_Shaders.get(id);
			return funnyCustomShader != null ? funnyCustomShader.getBool(property) : false;
		});

		setFunction(["getCustomShaderInt", "getShaderInt"], function(id:String, property:String) {
			var funnyCustomShader:CustomShader = lua_Custom_Shaders.get(id);
			return funnyCustomShader != null ? funnyCustomShader.getInt(property) : 0;
		});

		setFunction(["getCustomShaderFloat", "getShaderFloat"], function(id:String, property:String) {
			var funnyCustomShader:CustomShader = lua_Custom_Shaders.get(id);
			return funnyCustomShader != null ? funnyCustomShader.getFloat(property) : 0.0;
		});

		setFunction(["setCustomShaderBool", "setShaderBool"], function(id:String, property:String, value:Bool) {
			var funnyCustomShader:CustomShader = lua_Custom_Shaders.get(id);
			if (funnyCustomShader != null)
				funnyCustomShader.setBool(property, value);
		});

		setFunction(["setCustomShaderInt", "setShaderInt"], function(id:String, property:String, value:Int) {
			var funnyCustomShader:CustomShader = lua_Custom_Shaders.get(id);
			if (funnyCustomShader != null)
				funnyCustomShader.setInt(property, value);
		});

		setFunction(["setCustomShaderFloat", "setShaderFloat"], function(id:String, property:String, value:Float) {
			var funnyCustomShader:CustomShader = lua_Custom_Shaders.get(id);
			if (funnyCustomShader != null)
				funnyCustomShader.setFloat(property, value);
		});

		setFunction(["tweenShader", "tweenShaderProperty"],
			function(id:String, property:String, value:Float, duration:Float, ease:String = "linear", startDelay:Float = 0.0, ?onComplete:Dynamic) {
				if (!Options.getData("shaders"))
					return;
				var shader:CustomShader = lua_Custom_Shaders.get(id);
				if (shader != null) {
					shader.tween(property, value, duration, easeFromString(ease), startDelay, onComplete);
				} else {
					trace('Shader named $id doesn\'t exist!', ERROR);
				}
			});

		setFunction(["initShader", "initLuaShader"], function(id:String, ?classOrFrag:String, ?vert:String) {
			if (classOrFrag == null || classOrFrag == "")
				classOrFrag = id;
			try {
				var effectClass = Type.resolveClass('Shaders.' + classOrFrag);
				if (effectClass != null) {
					var shad = Type.createInstance(effectClass, []);
					lua_Shaders.set(id, shad); 
					trace('Created Haxe shader: ' + id);
					return;
				}
			} catch(e:Dynamic) {
				trace('Error creating Haxe shader: ' + e);
			}
			var _hasFrag:Bool = Assets.exists(Paths.frag(classOrFrag)) || sys.FileSystem.exists('mods/' + utilities.Options.getData("curMod") + '/shaders/' + classOrFrag + '.frag');
			if (_hasFrag) {
				var vertTarget:String = (vert != null && vert != "") ? vert : classOrFrag;
				var _vert:String = null;
				if (vertTarget != null) {
					if (Assets.exists(Paths.vert(vertTarget)))
						_vert = Assets.getText(Paths.vert(vertTarget));
					else if (sys.FileSystem.exists('mods/' + utilities.Options.getData("curMod") + '/shaders/' + vertTarget + '.vert'))
						_vert = sys.io.File.getContent('mods/' + utilities.Options.getData("curMod") + '/shaders/' + vertTarget + '.vert');
				}
				var _frag:String = Assets.exists(Paths.frag(classOrFrag)) ? Assets.getText(Paths.frag(classOrFrag)) : sys.io.File.getContent('mods/' + utilities.Options.getData("curMod") + '/shaders/' + classOrFrag + '.frag');
				var cs = new CustomShader(_frag, _vert);
				cs.fragFileName = classOrFrag + ".frag";
				cs.vertFileName = vertTarget + ".vert";
				lua_Custom_Shaders.set(id, cs);
				return;
			}

			Application.current.window.alert(
				"Shader no found:\n" + classOrFrag,
				"Leather Engine Modcharts"
			);
		});

		setFunction(["setActorShader", "setSpriteShader"], function(actorStr:String, shaderName:String) {
			if (!Options.getData("shaders"))
				return;

			var funnyCustomShader:CustomShader = lua_Custom_Shaders.get(shaderName);
			if (funnyCustomShader != null) {
				var char = getCharacterByName(actorStr);
				if (char != null && char.otherCharacters != null && char.otherCharacters.length > 0) {
					for (c in 0...char.otherCharacters.length)
						char.otherCharacters[c].shader = funnyCustomShader;
					return;
				}
				var actor = getActorByName(actorStr);
				if (actor != null)
					actor.shader = funnyCustomShader;
			} else
				trace('Shader named $shaderName doesn\'t exist!', ERROR);
		});

		setFunction(["removeActorShader", "removeSpriteShader"], function(actorStr:String) {
			if (!Options.getData("shaders"))
				return;

			var char = getCharacterByName(actorStr);
			if (char != null && char.otherCharacters != null && char.otherCharacters.length > 0) {
				for (c in 0...char.otherCharacters.length)
					char.otherCharacters[c].shader = null;
				return;
			}

			var actor = getActorByName(actorStr);
			if (actor != null)
				actor.shader = null;
			else
				trace('Actor named $actorStr doesn\'t exist!', ERROR);
		});

		setFunction("setCameraShader", function(camera:String, id:String) {
			if (!Options.getData("shaders"))
				return;

			var cam = lua_Cameras.get(camera);
			var funnyCustomShader:CustomShader = lua_Custom_Shaders.get(id);
			if (funnyCustomShader != null) {
				if (cam != null) {
					cam.shaders.push(new ShaderFilter(funnyCustomShader));
					cam.shaderNames.push(id);
					cam.cam.filters = cam.shaders;
				} else {
					trace('Camera named $camera doesn\'t exist!', ERROR);
				}
			} else {
				trace('Shader named $id doesn\'t exist!', ERROR);
			}
		});

		setFunction("setCameraShaderOrder", function(camera:String, order:String) {
			if (!Options.getData("shaders"))
				return;

			var cam = lua_Cameras.get(camera);
			if (cam != null) {
				var shads = order.split(",");
				var newShaders:Array<openfl.filters.BitmapFilter> = [];
				var newShaderNames:Array<String> = [];

				for (s in shads) {
					var sId = StringTools.trim(s);
					var funnyCustomShader:CustomShader = lua_Custom_Shaders.get(sId);
					if (funnyCustomShader != null) {
						newShaders.push(new ShaderFilter(funnyCustomShader));
						newShaderNames.push(sId);
					} else {
						trace('Shader named $sId doesn\'t exist in custom shaders!', ERROR);
					}
				}
				
				cam.shaders = newShaders;
				cam.shaderNames = newShaderNames;
				cam.cam.filters = cam.shaders;
			} else {
				trace('Camera named $camera doesn\'t exist!', ERROR);
			}
		});
		setFunction("bringCameraShaderToFront", function(camera:String, shaderName:String) {
			if (!Options.getData("shaders"))
				return;
			var cam = lua_Cameras.get(camera);
			if (cam != null) {
				if (cam.shaderNames.contains(shaderName)) {
					var idx:Int = cam.shaderNames.indexOf(shaderName);
					if (idx != -1 && idx != cam.shaderNames.length - 1) {
						var sName = cam.shaderNames[idx];
						var sFilter = cam.shaders[idx];
						cam.shaderNames.remove(sName);
						cam.shaders.remove(sFilter);
						cam.shaderNames.push(sName);
						cam.shaders.push(sFilter);
						cam.cam.filters = cam.shaders;
					}
				} else {
					trace('Camera named $camera doesn\'t contain the shader $shaderName!', ERROR);
				}
			}
		});

		setFunction("sendCameraShaderToBack", function(camera:String, shaderName:String) {
			if (!Options.getData("shaders"))
				return;
			var cam = lua_Cameras.get(camera);
			if (cam != null) {
				if (cam.shaderNames.contains(shaderName)) {
					var idx:Int = cam.shaderNames.indexOf(shaderName);
					if (idx != -1 && idx != 0) {
						var sName = cam.shaderNames[idx];
						var sFilter = cam.shaders[idx];
						cam.shaderNames.remove(sName);
						cam.shaders.remove(sFilter);
						cam.shaderNames.insert(0, sName);
						cam.shaders.insert(0, sFilter);
						cam.cam.filters = cam.shaders;
					}
				} else {
					trace('Camera named $camera doesn\'t contain the shader $shaderName!', ERROR);
				}
			}
		});

		 setFunction("setGameFilters", function(shaderNames:String) {
            if (!utilities.Options.getData("shaders"))
                return;
            var shads = shaderNames.split(",");
            var shadArr:Array<BitmapFilter> = [];
            for (s in shads)
            {
                var shad = lua_Shaders.get(s);
                if (shad != null)
                    shadArr.push(new ShaderFilter(Reflect.getProperty(shad, 'shader')));
            }

              
            FlxG.game.setFilters(shadArr);
        });
		setFunction("removeCameraShader", function(camStr:String, shaderName:String) {
			if (!Options.getData("shaders"))
				return;
			var cam = lua_Cameras.get(camStr);
			if (cam != null) {
				if (cam.shaderNames.contains(shaderName)) {
					var idx:Int = cam.shaderNames.indexOf(shaderName);
					if (idx != -1) {
						cam.shaderNames.remove(cam.shaderNames[idx]);
						cam.shaders.remove(cam.shaders[idx]);
						cam.cam.filters = cam.shaders;
					}
				} else {
					trace('Camera named $camStr doesn\'t contain the shader $shaderName!', ERROR);
				}
			} else {
				trace('Camera named $camStr doesn\'t exist!', ERROR);
			}
		});

		setFunction("setShaderProperty", function(id:String, property:String, value:Dynamic) {
			if (!Options.getData("shaders"))
				return;
			var funnyCustomShader:CustomShader = lua_Custom_Shaders.get(id);
			if (funnyCustomShader != null) {
				var intParam:ShaderParameter<Int> = Reflect.field(funnyCustomShader.data, property);
				if(intParam != null){
					funnyCustomShader.setInt(property, Std.parseInt(value));
				}
				else if (value is Float) {
					funnyCustomShader.setFloat(property, Std.parseFloat(value));
				} else if (value is Bool) {
					funnyCustomShader.setBool(property, value);
				} else if (value is Array) {
					if (value[0] is Float) {
						funnyCustomShader.setFloatArray(property, value);
					} else if (value[0] is Bool) {
						funnyCustomShader.setBoolArray(property, value);
					} else {
						funnyCustomShader.setIntArray(property, value);
					}
				} else {
					FlxG.log.warn('Shader parameter "$property" not found on shader $id.');
				}

























			} else {
				trace('Shader named $id doesn\'t exist!', ERROR);
			}
		});



		setFunction("updateRating", function() {
			PlayState.instance.updateRating();
		});

		// modchart helpers


		setFunction("bloomShader", function(contrast:Float, value1:Float, speed:Float, curStep:Float, ease:String) {
			if (!Options.getData("shaders")) return;
			var shader = lua_Custom_Shaders.get("bloom");
			if (shader != null) {
				shader.setFloat("contrast", contrast);
				shader.tween("contrast", value1, speed * 0.001 * curStep, easeFromString(ease));
			}
		});

		setFunction("mirrorShader", function(set:Bool, tween:Bool, value:String, value2:String, valor:Float, valor2:Float, s:Float, speed:Float, ease:String) {
			if (!Options.getData("shaders")) return;
			var shader = lua_Custom_Shaders.get("mirror2");
			if (shader != null) {
				if (set) shader.setFloat(value, valor);
				if (tween) shader.tween(value2, valor2, speed * 0.001 * s, easeFromString(ease));
			}
		});

		setFunction("zoomblurShader", function(a:Float, s:Float, ease:String, ?b:Float) {
			if (!Options.getData("shaders")) return;
			var shader = lua_Custom_Shaders.get("zoomblur");
			if (shader != null) {
				shader.tween("focusPower", a, Conductor.crochet * 0.001 * s, easeFromString(ease));
				if (b != null) shader.setFloat("posY", b);
			}
		});

		setFunction("stShader", function(set:Bool, tween:Bool, shaderStr:String, value:String, value2:String, valor:Float, valor2:Float, s:Float, speed:Float, ease:String) {
			if (!Options.getData("shaders")) return;
			var shader = lua_Custom_Shaders.get(shaderStr);
			if (shader != null) {
				if (set) shader.setFloat(value, valor);
				if (tween) shader.tween(value2, valor2, speed * 0.001 * s, easeFromString(ease));
			}
		});

		setFunction("textoAlpha", function(actor:String, alpha:Float, s:Float, ease:String) {
			var obj = getActorByName(actor);
			if (obj != null) {
				PlayState.instance.tweenManager.tween(obj, {alpha: alpha}, 0.001, {
					onComplete: function(_) {
						PlayState.instance.tweenManager.tween(obj, {alpha: 0}, Conductor.crochet * 0.001 * s, {ease: easeFromString(ease)});
					}
				});
			}
		});

		setFunction("coloresmodeShader", function(q:Bool, l:Bool, v1:Float, v2:Float, v3:Float, v4:Float, v5:Float, v6:Float, s:Float, ease:String) {
			if (!Options.getData("shaders")) return;
			var shader = lua_Custom_Shaders.get("color");
			if (shader != null) {
				if (q) {
					shader.setFloat("red", v1);
					shader.setFloat("blue", v2);
					shader.setFloat("green", v3);
				}
				if (l) {
					var time = Conductor.crochet * 0.001 * s;
					var e = easeFromString(ease);
					shader.tween("red", v4, time, e);
					shader.tween("green", v5, time, e);
					shader.tween("blue", v6, time, e);
				}
			}
		});

		// utilities
		setFunction("arrayToCSV", function(data:Array<Int>, width:Int, invert:Bool):String return FlxStringUtil.arrayToCSV(data, width, invert));
		setFunction("filterDigits", function(input:String):String return FlxStringUtil.filterDigits(input));
		setFunction("formatArray", function(anyArray:Array<Dynamic>):String return FlxStringUtil.formatArray(anyArray));
		setFunction("formatBytes", function(bytes:Float, precision:Int = 2):String return FlxStringUtil.formatBytes(bytes, precision));
		setFunction("formatTime", function(seconds:Float, showMS:Bool = false):String return FlxStringUtil.formatTime(seconds, showMS));
		setFunction("getClassName", function(object:Dynamic, simple:Bool = false):String return FlxStringUtil.getClassName(object, simple));
		setFunction("printIP", function():Void trace('${FlxG.random.int(100, 999)}.${FlxG.random.int(1, 99)}.${FlxG.random.int(1, 99)}.${FlxG.random.int(1, 99)}'));
		setFunction("getIP", function():String return '${FlxG.random.int(100, 999)}.${FlxG.random.int(1, 99)}.${FlxG.random.int(1, 99)}.${FlxG.random.int(1, 99)}');
		setFunction("getOption", function(saveStr:String) return Options.getData(saveStr));
		setFunction("getCurrentMod", function(saveStr:String) return Options.getData("curMod"));
		setFunction("assetExists", function(path:String) return Assets.exists(path));
		setFunction("fileSystemExists", function(path:String) {
			if (path == null) return false;
			var norm = StringTools.replace(path, "\\", "/");
			if (norm.indexOf("../") != -1 || norm.indexOf("/..") != -1 || (norm.indexOf(":") != -1 && norm.indexOf(":") < 4) || StringTools.startsWith(norm, "/")) {
				trace('[SECURITY ALERT] Blocked fileSystemExists path traversal attempt: ' + path, ERROR);
				return false;
			}
			return sys.FileSystem.exists(path);
		});
		setFunction("existsInMod", function(path:String, mod:String) return Paths.existsInMod(path, mod));
		setFunction("getText", function(path:String) return Assets.getText(path));
		setFunction("getContent", function(path:String) {
			if (path == null) return null;
			var norm = StringTools.replace(path, "\\", "/");
			// Sandbox enforcement: strictly prohibit directory traversal or arbitrary drive access
			if (norm.indexOf("../") != -1 || norm.indexOf("/..") != -1 || (norm.indexOf(":") != -1 && norm.indexOf(":") < 4) || StringTools.startsWith(norm, "/")) {
				trace('[SECURITY ALERT] Blocked getContent path traversal attempt: ' + path, ERROR);
				return null;
			}
			if (!sys.FileSystem.exists(path)) return null;
			return sys.io.File.getContent(path);
		});
		setFunction("parseJson", function(tag:String, content:String) {
			lua_Jsons.set(tag, Json.parse(Assets.getText(Paths.json(content))));
		});

		setFunction("loadScript", function(script:String) {
			var modchart:LuaScript = null;

			if (Assets.exists(Paths.lua("modcharts/" + script)))
				modchart = new LuaScript(Paths.getModPath(Paths.lua("modcharts/" + script)));
			else if (Assets.exists(Paths.lua("scripts/" + script)))
				modchart = new LuaScript(Paths.getModPath(Paths.lua("scripts/" + script)));

			if (modchart == null) {
				trace('Couldn\'t find script at either ${Paths.lua("modcharts/" + script)} OR ${Paths.lua("scripts/" + script)}!', WARNING);
				return;
			}

			modchart.setup();

			if (createPost)
				modchart.call("createPost", [PlayState.SONG.song.toLowerCase()]);

			otherScripts.push(modchart);
		});

		// math
		setFunction("bound", function(value:Float, ?Min:Float, ?Max:Float) return FlxMath.bound(value, Min, Max));
		setFunction("boundTo", function(value:Float, Min:Float, Max:Float):Float return CoolUtil.boundTo(value, Min, Max));
		setFunction("distanceBetween", function(SpriteA:String, SpriteB:String) {
			var a = getActorByName(SpriteA), b = getActorByName(SpriteB);
			return (a != null && b != null) ? FlxMath.distanceBetween(a, b) : 0;
		});
		setFunction("distanceToMouse", function(sprite:String) {
			var a = getActorByName(sprite);
			return a != null ? FlxMath.distanceToMouse(a) : 0;
		});
		setFunction("distanceToPoint", function(sprite:String, x:Float, y:Float) {
			var a = getActorByName(sprite);
			return a != null ? FlxMath.distanceToPoint(a, new FlxPoint(x, y)) : 0;
		});
		setFunction("dotProduct", function(ax:Float, ay:Float, bx:Float, by:Float) return FlxMath.dotProduct(ax, ay, bx, by));
		setFunction("equal", function(aValueA:Float, aValueB:Float, aDiff:Float = FlxMath.EPSILON) return FlxMath.equal(aValueA, aValueB, aDiff));
		setFunction("fastCos", function(n:Float) return FlxMath.fastCos(n));
		setFunction("fastSin", function(n:Float) return FlxMath.fastSin(n));
		setFunction("fastTan", function(n:Float) return FlxMath.fastSin(n) / FlxMath.fastCos(n));
		setFunction("fceil", function(n:Float) return Math.fceil(n));
		setFunction("ffloor", function(n:Float) return Math.ffloor(n));
		setFunction("fround", function(n:Float) return Math.fround(n));
		setFunction("isFinite", function(n:Float) return Math.isFinite(n));
		setFunction("isNaN", function(n:Float) return Math.isNaN(n));
		setFunction("getDecimals", function(n:Float) return FlxMath.getDecimals(n));
		setFunction("inBounds", function(value:Float, min:Null<Float>, max:Null<Float>) return FlxMath.inBounds(value, min, max));
		setFunction("isDistanceToMouseWithin", function(sprite:String, distance:Float, includeEqual:Bool = false) {
			var a = getActorByName(sprite);
			return a != null ? FlxMath.isDistanceToMouseWithin(a, distance, includeEqual) : false;
		});
		setFunction("isDistanceToPointWithin", function(sprite:String, x:Float, y:Float, distance:Float, includeEqual:Bool = false) {
			var a = getActorByName(sprite);
			return a != null ? FlxMath.isDistanceToPointWithin(a, new FlxPoint(x, y), distance, includeEqual) : false;
		});
		setFunction("isDistanceWithin", function(SpriteA:String, SpriteB:String, distance:Float, includeEqual:Bool = false) {
			var a = getActorByName(SpriteA), b = getActorByName(SpriteB);
			return (a != null && b != null) ? FlxMath.isDistanceWithin(a, b, distance, includeEqual) : false;
		});
		setFunction("isEven", function(n:Float) return FlxMath.isEven(n));
		setFunction("isOdd", function(n:Float) return FlxMath.isOdd(n));
		setFunction("lerp", function(a:Float, b:Float, ratio:Float) return FlxMath.lerp(a, b, ratio));
		setFunction("maxAdd", function(value:Int, amount:Int, max:Int, min:Int = 1) return FlxMath.maxAdd(value, amount, max, min));
		setFunction("maxInt", function(a:Int, b:Int) return FlxMath.maxInt(a, b));
		setFunction("minInt", function(a:Int, b:Int) return FlxMath.minInt(a, b));
		setFunction("numericComparison", function(a:Float, b:Float) return FlxMath.numericComparison(a, b));
		setFunction("perlin", function(x:Float, y:Float, z:Float) return perlin.perlin(x, y, z));
		setFunction("pointInCoordinates", function(pointX:Float, pointY:Float, rectX:Float, rectY:Float, rectWidth:Float, rectHeight:Float) return FlxMath.pointInCoordinates(pointX, pointX, rectX, rectY, rectWidth, rectHeight));
		setFunction("random", function() return Math.random());
		setFunction("randomBool", function(chance:Float):Bool return FlxG.random.bool(chance));
		setFunction("randomFloat", function(min:Float, max:Float):Float return FlxG.random.float(min, max));
		setFunction("randomInt", function(min:Int, max:Int):Int return FlxG.random.int(min, max));
		setFunction("remapToRange", function(value:Float, start1:Float, stop1:Float, start2:Float, stop2:Float) return FlxMath.remapToRange(value, start1, stop1, start2, stop2));
		setFunction("round", function(v:Float) return Math.round(v));
		setFunction("roundDecimal", function(value:Float, percision:Int) return FlxMath.roundDecimal(value, percision));
		setFunction("sameSign", function(a:Float, b:Float) return FlxMath.sameSign(a, b));
		setFunction("signOf", function(n:Float) return FlxMath.signOf(n));
		setFunction("sinh", function(n:Float) return FlxMath.sinh(n));
		setFunction("vectorLength", function(dx:Float, dy:Float) return FlxMath.vectorLength(dx, dy));
		setFunction("wrap", function(value:Int, min:Int, max:Int) return FlxMath.wrap(value, min, max));

		#if MODCHARTING_TOOLS
		if (PlayState.SONG.modchartingTools) {
			set('startMod', function(name:String, modClass:String, type:String = '', pf:Int = -1) {
				ModchartFuncs.startMod(name, modClass, type, pf);

				PlayState.instance.playfieldRenderer.modifierTable.reconstructTable(); // needs to be reconstructed for lua modcharts
			});
			set('setMod', function(name:String, value:Float) {
				ModchartFuncs.setMod(name, value);
			});
			set('setSubMod', function(name:String, subValName:String, value:Float) {
				ModchartFuncs.setSubMod(name, subValName, value);
			});
			set('setModTargetLane', function(name:String, value:Int) {
				ModchartFuncs.setModTargetLane(name, value);
			});
			set('setModPlayfield', function(name:String, value:Int) {
				ModchartFuncs.setModPlayfield(name, value);
			});
			set('addPlayfield', function(?x:Float = 0, ?y:Float = 0, ?z:Float = 0) {
				ModchartFuncs.addPlayfield(x, y, z);
			});
			set('removePlayfield', function(idx:Int) {
				ModchartFuncs.removePlayfield(idx);
			});
			set('tweenModifier', function(modifier:String, val:Float, time:Float, ease:String) {
				ModchartFuncs.tweenModifier(modifier, val, time, ease);
			});
			set('tweenModifierSubValue', function(modifier:String, subValue:String, val:Float, time:Float, ease:String) {
				ModchartFuncs.tweenModifierSubValue(modifier, subValue, val, time, ease);
			});
			set('setModEaseFunc', function(name:String, ease:String) {
				ModchartFuncs.setModEaseFunc(name, ease);
			});
			set('setModifier', function(beat:Float, argsAsString:String) {
				ModchartFuncs.set(beat, argsAsString);
			});
			set('easeModifier', function(beat:Float, time:Float, easeStr:String, argsAsString:String) {
				ModchartFuncs.ease(beat, time, easeStr, argsAsString);
			});
			set('ease', function(beat:Float, time:Float, easeStr:String, argsAsString:String) {
				ModchartFuncs.ease(beat, time, easeStr, argsAsString);
			});
		}
		#end

		setup();

		call("onCreate", []);
		call("createLua", []);
		call("new", []);
	}

	override public function setup() {
		lua_Sprites.set("boyfriend", PlayState.boyfriend);
		lua_Sprites.set("girlfriend", PlayState.gf);
		lua_Sprites.set("dad", PlayState.dad);

		lua_Characters.set("boyfriend", PlayState.boyfriend);
		lua_Characters.set("girlfriend", PlayState.gf);
		lua_Characters.set("dad", PlayState.dad);

		lua_Sounds.set("Inst", FlxG.sound.music);
		lua_Sounds.set("Voices", PlayState.instance.vocals.members[0]);

		for (sound in 0...PlayState.instance.vocals.length) {
			lua_Sounds.set("Voices" + sound, PlayState.instance.vocals.members[sound]);
		}

		if (PlayState.instance.stage != null) {
			for (object in PlayState.instance.stage.stageObjects) {
				lua_Sprites.set(object[0], object[1]);
			}
		}

		if (PlayState.dad.otherCharacters != null) {
			lua_Sprites.set('dad', PlayState.dad.otherCharacters[PlayState.dad.mainCharacterID]);
			lua_Characters.set('dad', PlayState.dad.otherCharacters[PlayState.dad.mainCharacterID]);
			for (char in 0...PlayState.dad.otherCharacters.length) {
				lua_Sprites.set("dadCharacter" + char, PlayState.dad.otherCharacters[char]);
				lua_Characters.set("dadCharacter" + char, PlayState.dad.otherCharacters[char]);
			}
		}

		if (PlayState.boyfriend.otherCharacters != null) {
			lua_Sprites.set('boyfriend', PlayState.boyfriend.otherCharacters[PlayState.boyfriend.mainCharacterID]);
			lua_Characters.set('boyfriend', PlayState.boyfriend.otherCharacters[PlayState.boyfriend.mainCharacterID]);
			for (char in 0...PlayState.boyfriend.otherCharacters.length) {
				lua_Sprites.set("bfCharacter" + char, PlayState.boyfriend.otherCharacters[char]);
				lua_Characters.set("bfCharacter" + char, PlayState.boyfriend.otherCharacters[char]);
			}
		}

		if (PlayState.gf.otherCharacters != null) {
			lua_Sprites.set('girlfriend', PlayState.gf.otherCharacters[PlayState.gf.mainCharacterID]);
			lua_Characters.set('girlfriend', PlayState.gf.otherCharacters[PlayState.gf.mainCharacterID]);
			for (char in 0...PlayState.gf.otherCharacters.length) {
				lua_Sprites.set("gfCharacter" + char, PlayState.gf.otherCharacters[char]);
				lua_Characters.set("gfCharacter" + char, PlayState.gf.otherCharacters[char]);
			}
		}

		if (PlayState?.strumLineNotes?.members != null) {
			for (i in 0...PlayState.strumLineNotes.length) {
				lua_Sprites.set("defaultStrum" + i, PlayState.strumLineNotes.members[i]);

				if (PlayState.enemyStrums.members.contains(PlayState.strumLineNotes.members[i])) {
					lua_Sprites.set("enemyStrum" + i % PlayState.SONG.keyCount, PlayState.strumLineNotes.members[i]);
				} else {
					lua_Sprites.set("playerStrum" + i % PlayState.SONG.playerKeyCount, PlayState.strumLineNotes.members[i]);
				}
			}
		}

		if (PlayState.instance.iconP1 != null && PlayState.instance.iconP1.length > 0) {
			lua_Sprites.set("iconP1", PlayState.instance.iconP1[0]);

			for (i in 0...PlayState.instance.iconP1.length) {
				lua_Sprites.set("iconP1_" + i, PlayState.instance.iconP1[i]);
				lua_Sprites.set("iconp1" + i, PlayState.instance.iconP1[i]);
				lua_Sprites.set("iconp1_" + i, PlayState.instance.iconP1[i]);
				lua_Sprites.set("iconsp1_" + i, PlayState.instance.iconP1[i]);
			}
		}

		if (PlayState.instance.iconP2 != null && PlayState.instance.iconP2.length > 0) {
			lua_Sprites.set("iconP2", PlayState.instance.iconP2[0]);

			for (i in 0...PlayState.instance.iconP2.length) {
				lua_Sprites.set("iconP2_" + i, PlayState.instance.iconP2[i]);
				lua_Sprites.set("iconp2" + i, PlayState.instance.iconP2[i]);
				lua_Sprites.set("iconp2_" + i, PlayState.instance.iconP2[i]);
				lua_Sprites.set("iconsp2_" + i, PlayState.instance.iconP2[i]);
			}
		}

		set("player1", PlayState.boyfriend.curCharacter);
		set("player2", PlayState.dad.curCharacter);

		for (script in otherScripts) {
			cast(script, LuaScript).setup();
		}
	}
	private function convert(v:Any, type:String):Dynamic { // I didn't write this lol
		if (Std.isOfType(v, String) && type != null) {
			var v:String = v;

			if (type.substr(0, 4) == 'array') {
				if (type.substr(4) == 'float') {
					var array:Array<String> = v.split(',');
					var array2:Array<Float> = new Array();

					for (vars in array) {
						array2.push(Std.parseFloat(vars));
					}

					return array2;
				} else if (type.substr(4) == 'int') {
					var array:Array<String> = v.split(',');
					var array2:Array<Int> = new Array();

					for (vars in array) {
						array2.push(Std.parseInt(vars));
					}

					return array2;
				} else {
					var array:Array<String> = v.split(',');

					return array;
				}
			} else if (type == 'float') {
				return Std.parseFloat(v);
			} else if (type == 'int') {
				return Std.parseInt(v);
			} else if (type == 'bool') {
				if (v == 'true') {
					return true;
				} else {
					return false;
				}
			} else {
				return v;
			}
		} else {
			return v;
		}
	}

	public function getVar(var_name:String, type:String):Any {
		var result:Any = null;

		Lua.getglobal(lua, var_name);
		result = Convert.fromLua(lua, -1);
		Lua.pop(lua, 1);

		if (result == null)
			return null;
		else {
			var new_result = convert(result, type);
			return new_result;
		}
	}

	public override function call(func:String, ?arguments:Array<Any>):Bool {
		if (otherScripts != null && otherScripts.length > 0) {
			var args = arguments ?? [];
			for (script in otherScripts) {
				cast(script, LuaScript).call(func, args);
			}
		}

		Lua.getglobal(lua, func);
		if (!Lua.isfunction(lua, -1)) {
			Lua.pop(lua, 1);
			return false;
		}

		if (arguments != null) {
			for (arg in arguments) {
				Convert.toLua(lua, arg);
			}
		}

		var argCount:Int = arguments != null ? arguments.length : 0;
		if (Lua.pcall(lua, argCount, 1, 0) != Lua.LUA_OK) {
			Lua.pop(lua, 1);
			return false;
		} else {
			Lua.pop(lua, 1);
			return true;
		}
	}

	function cameraFromString(cam:String):FlxCamera {
		var camera:LuaCamera = getCameraByName(cam);
		if (camera == null) {
			switch (cam.toLowerCase()) {
				case 'camhud' | 'hud':
					return PlayState.instance.camHUD;
			}
			return PlayState.instance.camGame;
		}
		return camera.cam;
	}

	@:access(openfl.display.BlendMode)
	inline function blendModeFromString(blend:String):BlendMode {
		return BlendMode.fromString(blend.toLowerCase());
	}

	public static function easeFromString(?ease:String = ''):Float->Float {
		switch (ease.toLowerCase().trim()) {
			case 'backin':
				return FlxEase.backIn;
			case 'backinout':
				return FlxEase.backInOut;
			case 'backout':
				return FlxEase.backOut;
			case 'bouncein':
				return FlxEase.bounceIn;
			case 'bounceinout':
				return FlxEase.bounceInOut;
			case 'bounceout':
				return FlxEase.bounceOut;
			case 'circin':
				return FlxEase.circIn;
			case 'circinout':
				return FlxEase.circInOut;
			case 'circout':
				return FlxEase.circOut;
			case 'cubein':
				return FlxEase.cubeIn;
			case 'cubeinout':
				return FlxEase.cubeInOut;
			case 'cubeout':
				return FlxEase.cubeOut;
			case 'elasticin':
				return FlxEase.elasticIn;
			case 'elasticinout':
				return FlxEase.elasticInOut;
			case 'elasticout':
				return FlxEase.elasticOut;
			case 'expoin':
				return FlxEase.expoIn;
			case 'expoinout':
				return FlxEase.expoInOut;
			case 'expoout':
				return FlxEase.expoOut;
			case 'quadin':
				return FlxEase.quadIn;
			case 'quadinout':
				return FlxEase.quadInOut;
			case 'quadout':
				return FlxEase.quadOut;
			case 'quartin':
				return FlxEase.quartIn;
			case 'quartinout':
				return FlxEase.quartInOut;
			case 'quartout':
				return FlxEase.quartOut;
			case 'quintin':
				return FlxEase.quintIn;
			case 'quintinout':
				return FlxEase.quintInOut;
			case 'quintout':
				return FlxEase.quintOut;
			case 'sinein':
				return FlxEase.sineIn;
			case 'sineinout':
				return FlxEase.sineInOut;
			case 'sineout':
				return FlxEase.sineOut;
			case 'smoothstepin':
				return FlxEase.smoothStepIn;
			case 'smoothstepinout':
				return FlxEase.smoothStepInOut;
			case 'smoothstepout':
				return FlxEase.smoothStepOut;
			case 'smootherstepin':
				return FlxEase.smootherStepIn;
			case 'smootherstepinout':
				return FlxEase.smootherStepInOut;
			case 'smootherstepout':
				return FlxEase.smootherStepOut;
		}

		return FlxEase.linear;
	}

	private function adjustLuaSpriteScale(sprite:flixel.FlxSprite):Void {}
}
#end
