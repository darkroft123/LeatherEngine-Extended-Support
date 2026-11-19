package utilities;

import game.StageGroup.StageData;
import game.StageGroup.StageObject;
import modding.CharacterConfig.CharacterAnimation;
import haxe.xml.Access;
import lime.utils.Assets;
#if sys
import sys.FileSystem;
#end


class PorteadorXml {

	public static function isCodenameStageXml(rawXml:String):Bool {
		if (rawXml == null || rawXml.trim() == "") return false;
		var trimmed = rawXml.trim();
		return trimmed.contains("codename-engine-stage") || (trimmed.contains("<stage") && (trimmed.contains("<sprite") || trimmed.contains("<spr") || trimmed.contains("<boyfriend") || trimmed.contains("<dad") || trimmed.contains("<girlfriend")));
	}

	public static function getStageXmlPath(stage:String):String {
		if (stage == null || stage == "") return null;
		var stageLower = stage.toLowerCase().trim();
		var stageDash = stageLower.replace(" ", "-");
		var stageSpace = stageLower.replace("-", " ");

		var candidates:Array<String> = [
			Paths.xml('data/stages/$stageLower'),
			Paths.xml('data/stages/$stage'),
			Paths.xml('data/stages/$stageDash'),
			Paths.xml('stages/$stageLower'),
			Paths.xml('stages/$stage'),
			Paths.xml('stages/$stageDash'),
			Paths.xml('stage data/$stageLower'),
			Paths.xml('stage data/$stage'),
			Paths.xml('stage data/$stageDash'),
			Paths.file('data/stages/$stageLower.xml'),
			Paths.file('data/stages/$stage.xml'),
			Paths.file('stages/$stageLower.xml'),
			Paths.file('stages/$stage.xml')
		];

		for (c in candidates) {
			if (Assets.exists(c)) return c;
		}

		#if (sys && MODDING_ALLOWED)
		var activeMods:Array<String> = modding.ModList.getActiveMods(modding.PolymodHandler.metadataArrays);
		var curMod:String = utilities.Options.getData("curMod");
		if (curMod != null && curMod != "" && !activeMods.contains(curMod)) {
			activeMods.push(curMod);
		}
		for (mod in activeMods) {
			for (s in [stage, stageLower, stageDash, stageSpace]) {
				var paths = [
					'mods/$mod/data/stages/$s.xml',
					'mods/$mod/stages/$s.xml',
					'mods/$mod/data/stage data/$s.xml',
					'mods/$mod/stage data/$s.xml'
				];
				for (p in paths) {
					if (FileSystem.exists(p)) return p;
				}
			}
		}
		#end

		return null;
	}

	public static function cleanStageFolder(folder:String):String {
		if (folder == null) return "";
		var f = folder.trim();
		if (f.startsWith("stages/")) f = f.substr(7);
		if (f.startsWith("images/")) f = f.substr(7);
		if (f.startsWith("stages/images/")) f = f.substr(14);
		if (f.endsWith("/")) f = f.substr(0, f.length - 1);
		return f;
	}

	public static function resolveStageGraphicPath(folder:String, spriteName:String):String {
		if (spriteName == null || spriteName == "" || spriteName.startsWith("#")) return null;
		var cleanF = cleanStageFolder(folder);
		var cleanFLower = cleanF.toLowerCase();
		var sprClean = spriteName.trim();
		if (cleanF != "" && sprClean.startsWith(cleanF + "/")) sprClean = sprClean.substr(cleanF.length + 1);
		if (cleanFLower != "" && sprClean.toLowerCase().startsWith(cleanFLower + "/")) sprClean = sprClean.substr(cleanFLower.length + 1);
		var sprLower = sprClean.toLowerCase();

		var searchPaths:Array<String> = [];
		if (cleanF != "") {
			searchPaths.push('stages:assets/stages/images/$cleanF/$sprClean.png');
			searchPaths.push('stages:assets/stages/images/$cleanFLower/$sprClean.png');
			searchPaths.push('assets/images/stages/$cleanF/$sprClean.png');
			searchPaths.push('assets/images/stages/$cleanFLower/$sprClean.png');
			searchPaths.push('assets/stages/images/$cleanF/$sprClean.png');
			searchPaths.push('assets/stages/images/$cleanFLower/$sprClean.png');
			searchPaths.push('assets/images/$cleanF/$sprClean.png');
			searchPaths.push('assets/images/$cleanFLower/$sprClean.png');
		}
		searchPaths.push('stages:assets/stages/images/$sprClean.png');
		searchPaths.push('assets/images/stages/$sprClean.png');
		searchPaths.push('assets/images/$sprClean.png');

		for (p in searchPaths) {
			if (Assets.exists(p)) return p;
		}

		#if (sys && MODDING_ALLOWED)
		var activeMods:Array<String> = modding.ModList.getActiveMods(modding.PolymodHandler.metadataArrays);
		var curMod:String = utilities.Options.getData("curMod");
		if (curMod != null && curMod != "" && !activeMods.contains(curMod)) {
			activeMods.push(curMod);
		}
		for (mod in activeMods) {
			var modDirs:Array<String> = [];
			if (cleanF != "") {
				modDirs.push('mods/$mod/stages/images/$cleanF');
				modDirs.push('mods/$mod/stages/images/$cleanFLower');
				modDirs.push('mods/$mod/images/stages/$cleanF');
				modDirs.push('mods/$mod/images/stages/$cleanFLower');
				modDirs.push('mods/$mod/images/$cleanF');
				modDirs.push('mods/$mod/images/$cleanFLower');
			}
			modDirs.push('mods/$mod/stages/images');
			modDirs.push('mods/$mod/images/stages');
			modDirs.push('mods/$mod/images');

			for (dir in modDirs) {
				if (FileSystem.exists(dir) && FileSystem.isDirectory(dir)) {
					try {
						var files = FileSystem.readDirectory(dir);
						for (file in files) {
							if (file.toLowerCase() == '$sprLower.png') {
								return '$dir/$file';
							}
						}
					} catch (e:Dynamic) {}
				}
			}
		}
		#end

		return null;
	}

	public static function resolveStageAtlasPaths(folder:String, spriteName:String):{imagePath:String, xmlPath:String} {
		if (spriteName == null || spriteName == "" || spriteName.startsWith("#")) return null;
		var cleanF = cleanStageFolder(folder);
		var cleanFLower = cleanF.toLowerCase();
		var sprClean = spriteName.trim();
		if (cleanF != "" && sprClean.startsWith(cleanF + "/")) sprClean = sprClean.substr(cleanF.length + 1);
		if (cleanFLower != "" && sprClean.toLowerCase().startsWith(cleanFLower + "/")) sprClean = sprClean.substr(cleanFLower.length + 1);
		var sprLower = sprClean.toLowerCase();

		var searchPairs:Array<{imagePath:String, xmlPath:String}> = [];
		if (cleanF != "") {
			searchPairs.push({
				imagePath: 'stages:assets/stages/images/$cleanF/$sprClean.png',
				xmlPath: 'stages:assets/stages/images/$cleanF/$sprClean.xml'
			});
			searchPairs.push({
				imagePath: 'assets/images/stages/$cleanF/$sprClean.png',
				xmlPath: 'assets/images/stages/$cleanF/$sprClean.xml'
			});
			searchPairs.push({
				imagePath: 'assets/stages/images/$cleanF/$sprClean.png',
				xmlPath: 'assets/stages/images/$cleanF/$sprClean.xml'
			});
		}
		searchPairs.push({
			imagePath: 'stages:assets/stages/images/$sprClean.png',
			xmlPath: 'stages:assets/stages/images/$sprClean.xml'
		});
		searchPairs.push({
			imagePath: 'assets/images/$sprClean.png',
			xmlPath: 'assets/images/$sprClean.xml'
		});

		for (pair in searchPairs) {
			if (Assets.exists(pair.xmlPath) && Assets.exists(pair.imagePath)) return pair;
		}

		#if (sys && MODDING_ALLOWED)
		var activeMods:Array<String> = modding.ModList.getActiveMods(modding.PolymodHandler.metadataArrays);
		var curMod:String = utilities.Options.getData("curMod");
		if (curMod != null && curMod != "" && !activeMods.contains(curMod)) {
			activeMods.push(curMod);
		}
		for (mod in activeMods) {
			var modDirs:Array<String> = [];
			if (cleanF != "") {
				modDirs.push('mods/$mod/stages/images/$cleanF');
				modDirs.push('mods/$mod/stages/images/$cleanFLower');
				modDirs.push('mods/$mod/images/stages/$cleanF');
				modDirs.push('mods/$mod/images/stages/$cleanFLower');
				modDirs.push('mods/$mod/images/$cleanF');
			}
			modDirs.push('mods/$mod/stages/images');
			modDirs.push('mods/$mod/images/stages');
			modDirs.push('mods/$mod/images');

			for (dir in modDirs) {
				if (FileSystem.exists(dir) && FileSystem.isDirectory(dir)) {
					try {
						var files = FileSystem.readDirectory(dir);
						var foundImg:String = null;
						var foundXml:String = null;
						for (file in files) {
							if (file.toLowerCase() == '$sprLower.png') foundImg = '$dir/$file';
							if (file.toLowerCase() == '$sprLower.xml') foundXml = '$dir/$file';
						}
						if (foundImg != null && foundXml != null) {
							return {imagePath: foundImg, xmlPath: foundXml};
						}
					} catch (e:Dynamic) {}
				}
			}
		}
		#end

		return null;
	}

	public static function autoPopulateAtlasAnimations(sprite:flixel.FlxSprite, xmlPath:String, isBeat:Bool = false):Void {
		if (sprite == null || xmlPath == null) return;
		try {
			var rawXml:String = null;
			#if sys
			if (FileSystem.exists(xmlPath)) rawXml = sys.io.File.getContent(xmlPath);
			#end
			if (rawXml == null && Assets.exists(xmlPath)) rawXml = Assets.getText(xmlPath);
			if (rawXml == null) return;

			var xml = Xml.parse(rawXml);
			var root = xml.firstElement();
			if (root == null) return;

			var prefixes:Array<String> = [];
			for (node in root.elements()) {
				if (node.nodeName == "SubTexture" && node.exists("name")) {
					var fullName = node.get("name");
					var r = ~/[0-9]+$/;
					var prefix = r.replace(fullName, "");
					if (prefix != "" && !prefixes.contains(prefix)) {
						prefixes.push(prefix);
					}
				}
			}

			var hasLeft = false;
			var hasRight = false;
			var hasIdle = false;

			for (p in prefixes) {
				var pLow = p.toLowerCase();
				var loop = !isBeat;
				sprite.animation.addByPrefix(p, p, 24, loop);
				if (pLow.contains("danceleft") || pLow == "left") {
					sprite.animation.addByPrefix("danceLeft", p, 24, false);
					hasLeft = true;
				} else if (pLow.contains("danceright") || pLow == "right") {
					sprite.animation.addByPrefix("danceRight", p, 24, false);
					hasRight = true;
				} else if (pLow.contains("idle")) {
					sprite.animation.addByPrefix("idle", p, 24, false);
					sprite.animation.addByPrefix("beatHit", p, 24, false);
					hasIdle = true;
				}
			}

			if (hasLeft && hasRight) {
				if (sprite.animation.getByName("danceLeft") != null)
					sprite.animation.play("danceLeft");
			} else {
				if (!hasIdle && prefixes.length > 0) {
					sprite.animation.addByPrefix("idle", prefixes[0], 24, false);
					sprite.animation.addByPrefix("beatHit", prefixes[0], 24, false);
				}
				if (sprite.animation.getByName("idle") != null) {
					sprite.animation.play("idle");
				} else if (prefixes.length > 0) {
					sprite.animation.play(prefixes[0]);
				}
			}
		} catch (e:Dynamic) {
			trace('Error al autocompletar animaciones para atlas: ' + e);
		}
	}

	public static function getStageScriptPath(stage:String):{path:String, isLua:Bool} {
		if (stage == null || stage == "") return null;
		var stageLower = stage.toLowerCase().trim();
		var stageDash = stageLower.replace(" ", "-");
		var stageSpace = stageLower.replace("-", " ");

		#if HSCRIPT_ALLOWED
		var hxCandidates:Array<String> = [
			Paths.hx('data/stages/$stageLower'),
			Paths.hx('data/stages/$stage'),
			Paths.hx('data/stages/$stageDash'),
			Paths.hx('stages/$stageLower'),
			Paths.hx('stages/$stage'),
			Paths.hx('data/stage data/$stageLower'),
			Paths.hx('data/stage data/$stage'),
			Paths.hx('stage data/$stageLower')
		];
		for (c in hxCandidates) {
			if (Assets.exists(c)) return {path: c, isLua: false};
		}
		#end

		#if LUA_ALLOWED
		var luaCandidates:Array<String> = [
			Paths.lua('data/stages/$stageLower'),
			Paths.lua('data/stages/$stage'),
			Paths.lua('stages/$stageLower'),
			Paths.lua('stages/$stage'),
			Paths.lua('data/stage data/$stageLower'),
			Paths.lua('stage data/$stageLower')
		];
		for (c in luaCandidates) {
			if (Assets.exists(c)) return {path: c, isLua: true};
		}
		#end

		#if (sys && MODDING_ALLOWED)
		var activeMods:Array<String> = modding.ModList.getActiveMods(modding.PolymodHandler.metadataArrays);
		var curMod:String = utilities.Options.getData("curMod");
		if (curMod != null && curMod != "" && !activeMods.contains(curMod)) {
			activeMods.push(curMod);
		}
		for (mod in activeMods) {
			for (s in [stage, stageLower, stageDash, stageSpace]) {
				#if HSCRIPT_ALLOWED
				var hxPaths = [
					'mods/$mod/data/stages/$s.hx',
					'mods/$mod/stages/$s.hx',
					'mods/$mod/data/stage data/$s.hx',
					'mods/$mod/stage data/$s.hx'
				];
				for (p in hxPaths) {
					if (FileSystem.exists(p)) return {path: p, isLua: false};
				}
				#end

				#if LUA_ALLOWED
				var luaPaths = [
					'mods/$mod/data/stages/$s.lua',
					'mods/$mod/stages/$s.lua',
					'mods/$mod/data/stage data/$s.lua',
					'mods/$mod/stage data/$s.lua'
				];
				for (p in luaPaths) {
					if (FileSystem.exists(p)) return {path: p, isLua: true};
				}
				#end
			}
		}
		#end

		return null;
	}

	public static function parseCodenameStage(rawXml:String, ?stageName:String):StageData {
		var xmlRoot:Xml = null;
		try {
			var parsed = Xml.parse(rawXml);
			xmlRoot = parsed.firstElement();
			if (xmlRoot == null) {
				for (el in parsed.elements()) {
					if (el.nodeName == "stage") {
						xmlRoot = el;
						break;
					}
				}
			}
		} catch (e:Dynamic) {
			trace('Error al parsear XML del stage "$stageName": ' + e);
			return null;
		}

		if (xmlRoot == null) return null;

		var stageAccess:Access = new Access(xmlRoot);

		var name:String = stageAccess.has.name ? stageAccess.att.name : (stageName != null ? stageName : "stage");
		var zoom:Float = stageAccess.has.zoom ? Std.parseFloat(stageAccess.att.zoom) : 1.05;
		var folder:String = stageAccess.has.folder ? stageAccess.att.folder : "";
		if (folder.endsWith("/")) folder = folder.substr(0, folder.length - 1);
		var scriptName:String = stageAccess.has.script ? stageAccess.att.script : ((stageName != null && stageName != "") ? stageName : name);

		var startCamPosX:Float = stageAccess.has.startCamPosX ? Std.parseFloat(stageAccess.att.startCamPosX) : 0;
		var startCamPosY:Float = stageAccess.has.startCamPosY ? Std.parseFloat(stageAccess.att.startCamPosY) : 0;

		// Default character positions in Codename Engine:
		// Boyfriend: x = 770, y = 100, scroll = 1.0
		// Dad: x = 100, y = 100, scroll = 1.0
		// Girlfriend: x = 400, y = 130, scroll = 0.95
		var bfPos:Array<Float> = [770.0, 100.0];
		var dadPos:Array<Float> = [100.0, 100.0];
		var gfPos:Array<Float> = [400.0, 130.0];

		var bfScroll:Float = 1.0;
		var dadScroll:Float = 1.0;
		var gfScroll:Float = 0.95;

		var bfScale:Null<Float> = null;
		var dadScale:Null<Float> = null;
		var gfScale:Null<Float> = null;

		var stageObjects:Array<StageObject> = [];

		var seenGf:Bool = false;
		var seenOpponent:Bool = false;
		var seenPlayer:Bool = false;

		var objIndex:Int = 0;

		for (node in stageAccess.elements) {
			var nodeName:String = node.name.toLowerCase();

			switch (nodeName) {
				case "girlfriend" | "gf":
					seenGf = true;
					if (node.has.x) gfPos[0] = Std.parseFloat(node.att.x);
					if (node.has.y) gfPos[1] = Std.parseFloat(node.att.y);
					if (node.has.scroll) gfScroll = Std.parseFloat(node.att.scroll);
					else if (node.has.scrollx) gfScroll = Std.parseFloat(node.att.scrollx);
					if (node.has.scale) gfScale = Std.parseFloat(node.att.scale);
					else if (node.has.scalex) gfScale = Std.parseFloat(node.att.scalex);

				case "dad" | "opponent":
					seenOpponent = true;
					if (node.has.x) dadPos[0] = Std.parseFloat(node.att.x);
					if (node.has.y) dadPos[1] = Std.parseFloat(node.att.y);
					if (node.has.scroll) dadScroll = Std.parseFloat(node.att.scroll);
					else if (node.has.scrollx) dadScroll = Std.parseFloat(node.att.scrollx);
					if (node.has.scale) dadScale = Std.parseFloat(node.att.scale);
					else if (node.has.scalex) dadScale = Std.parseFloat(node.att.scalex);

				case "boyfriend" | "bf" | "player":
					seenPlayer = true;
					if (node.has.x) bfPos[0] = Std.parseFloat(node.att.x);
					if (node.has.y) bfPos[1] = Std.parseFloat(node.att.y);
					if (node.has.scroll) bfScroll = Std.parseFloat(node.att.scroll);
					else if (node.has.scrollx) bfScroll = Std.parseFloat(node.att.scrollx);
					if (node.has.scale) bfScale = Std.parseFloat(node.att.scale);
					else if (node.has.scalex) bfScale = Std.parseFloat(node.att.scalex);

				case "sprite" | "spr" | "sparrow":
					var sprName:String = node.has.name ? node.att.name : ('sprite_$objIndex');
					var fileSprite:String = node.has.sprite ? node.att.sprite : sprName;

					var posX:Float = node.has.x ? Std.parseFloat(node.att.x) : 0.0;
					var posY:Float = node.has.y ? Std.parseFloat(node.att.y) : 0.0;

					var scrollX:Float = node.has.scroll ? Std.parseFloat(node.att.scroll) : (node.has.scrollx ? Std.parseFloat(node.att.scrollx) : 1.0);
					var scrollY:Float = node.has.scroll ? Std.parseFloat(node.att.scroll) : (node.has.scrolly ? Std.parseFloat(node.att.scrolly) : 1.0);

					var scaleX:Float = node.has.scale ? Std.parseFloat(node.att.scale) : (node.has.scalex ? Std.parseFloat(node.att.scalex) : 1.0);
					var scaleY:Float = node.has.scale ? Std.parseFloat(node.att.scale) : (node.has.scaley ? Std.parseFloat(node.att.scaley) : 1.0);

					var alpha:Float = node.has.alpha ? Std.parseFloat(node.att.alpha) : 1.0;
					var blend:String = node.has.blend ? node.att.blend.toLowerCase() : null;
					var flipX:Bool = node.has.flipX ? (node.att.flipX == "true") : false;
					var flipY:Bool = node.has.flipY ? (node.att.flipY == "true") : false;
					var antialiasing:Bool = node.has.antialiasing ? (node.att.antialiasing == "true") : true;

					var animType:String = node.has.type ? node.att.type.toLowerCase() : "none";
					var isBeating:Bool = (animType == "beat");

					var layer:String = "bg";
					if (node.has.layer) {
						layer = node.att.layer.toLowerCase();
					}

					var animations:Array<CharacterAnimation> = [];
					var isAnimated:Bool = false;

					for (animNode in node.nodes.anim) {
						isAnimated = true;
						var aName:String = animNode.has.name ? animNode.att.name : "idle";
						var aPrefix:String = animNode.has.anim ? animNode.att.anim : aName;
						var aFps:Int = animNode.has.fps ? Std.parseInt(animNode.att.fps) : 24;
						var aLoop:Bool = animNode.has.loop ? (animNode.att.loop == "true") : false;
						var aIndices:Array<Int> = null;

						if (animNode.has.indices && animNode.att.indices.trim() != "") {
							aIndices = [];
							for (idx in animNode.att.indices.split(",")) {
								var parsedIdx = Std.parseInt(idx.trim());
								if (parsedIdx != null) aIndices.push(parsedIdx);
							}
						}

						animations.push({
							name: aName,
							animation_name: aPrefix,
							fps: aFps,
							looped: aLoop,
							indices: aIndices
						});
					}

					// Full relative file path including folder if present
					var fullFileName:String = fileSprite;
					if (folder != "") {
						fullFileName = folder + "/" + fileSprite;
					}

					var stageObj:StageObject = {
						position: [posX, posY],
						zIndex: objIndex,
						scale: scaleX,
						scaleY: scaleY,
						antialiased: antialiasing,
						scroll_Factor: [scrollX, scrollY],
						blend: blend,
						color: [255, 255, 255],
						object_Name: sprName,
						layer: layer,
						alpha: alpha,
						updateHitbox: true,
						flipX: flipX,
						flipY: flipY,
						angle: node.has.angle ? Std.parseFloat(node.att.angle) : 0.0,
						file_Name: fullFileName,
						is_Animated: isAnimated,
						animations: animations,
						start_Animation: (animations.length > 0) ? animations[0].name : "idle",
						dances: isBeating
					};

					stageObjects.push(stageObj);
					objIndex++;

				case "box" | "solid":
					var boxName:String = node.has.name ? node.att.name : ('solid_$objIndex');
					var posX:Float = node.has.x ? Std.parseFloat(node.att.x) : 0.0;
					var posY:Float = node.has.y ? Std.parseFloat(node.att.y) : 0.0;
					var width:Int = node.has.width ? Std.parseInt(node.att.width) : 100;
					var height:Int = node.has.height ? Std.parseInt(node.att.height) : 100;
					var colorStr:String = node.has.color ? node.att.color : "#000000";
					var alpha:Float = node.has.alpha ? Std.parseFloat(node.att.alpha) : 1.0;
					var scrollX:Float = node.has.scroll ? Std.parseFloat(node.att.scroll) : 1.0;
					var scrollY:Float = node.has.scroll ? Std.parseFloat(node.att.scroll) : 1.0;

					var layer:String = "bg";
					if (node.has.layer) {
						layer = node.att.layer.toLowerCase();
					}

					var solidObj:StageObject = {
						position: [posX, posY],
						zIndex: objIndex,
						scale: width,
						scaleY: height,
						antialiased: false,
						scroll_Factor: [scrollX, scrollY],
						blend: null,
						color: [255, 255, 255],
						object_Name: boxName,
						layer: layer,
						alpha: alpha,
						updateHitbox: false,
						flipX: false,
						flipY: false,
						angle: 0.0,
						file_Name: colorStr.startsWith("#") ? colorStr : ('#' + colorStr),
						is_Animated: false,
						animations: [],
						start_Animation: "",
						dances: false
					};

					stageObjects.push(solidObj);
					objIndex++;

				default:
			}
		}

		var outputData:StageData = {
			character_Positions: [bfPos, dadPos, gfPos],
			character_Scrolls: [bfScroll, dadScroll, gfScroll],
			characterZIndices: [0, 0, 0],
			character_Scales: [bfScale ?? 1.0, dadScale ?? 1.0, gfScale ?? 1.0],
			camera_Zoom: zoom,
			camera_Offsets: [[startCamPosX, startCamPosY], [startCamPosX, startCamPosY]],
			objects: stageObjects,
			scriptName: scriptName,
			backgroundColor: "#000000",
			imageDirectory: folder != "" ? folder : name,
			useAbsolutePositions: true,
			rtxData: null
		};

		return outputData;
	}
}
