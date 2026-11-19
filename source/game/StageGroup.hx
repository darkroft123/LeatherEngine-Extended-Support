package game;

import modding.CharacterConfig;
import openfl.display.BlendMode;
import flixel.util.FlxDestroyUtil;
import modding.scripts.Script;
#if MODDING_ALLOWED
import polymod.backends.PolymodAssets;
#end
#if LUA_ALLOWED
import modding.scripts.languages.LuaScript;
#end
import shaders.ColorSwapHSV;
import modding.scripts.languages.HScript;
import lime.utils.Assets;
import haxe.Json;
import flixel.util.FlxColor;
import flixel.math.FlxPoint;
import states.PlayState;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import game.DancingSprite;
import shaders.Shaders.VortexEffect;


class StageGroup extends FlxGroup {
	public var stage:String = "stage";
	public var camZoom:Float = 1.05;
	private var goodElapse:Float = 0;

	public var player_1_Point:FlxPoint = FlxPoint.get(1000, 800);
	public var player_2_Point:FlxPoint = FlxPoint.get(300, 800);
	public var gf_Point:FlxPoint = FlxPoint.get(600, 750);


	public var p1_Scroll:Float = 1.0;
	public var p2_Scroll:Float = 1.0;
	public var gf_Scroll:Float = 0.95;

	public var p1ZIndex:Int = 0;
	public var p2ZIndex:Int = 0;
	public var gfZIndex:Int = 0;

	public var p1_Scale:Null<Float> = null;
	public var p2_Scale:Null<Float> = null;
	public var gf_Scale:Null<Float> = null;

	public var p1_Cam_Offset:FlxPoint = FlxPoint.get(0, 0);
	public var p2_Cam_Offset:FlxPoint = FlxPoint.get(0, 0);
	public var gf_Cam_Offset:FlxPoint = FlxPoint.get(0, 0);

	public var stageData:StageData;

	public var stageObjects:Array<Array<Dynamic>> = [];

	// other
	public var onBeatHit_Group:FlxTypedGroup<FlxSprite> = new FlxTypedGroup<FlxSprite>();

	public var foregroundSprites:FlxGroup = new FlxGroup();
	public var infrontOfGFSprites:FlxGroup = new FlxGroup();

	public var stageScript:Script = null;

	public var colorSwap:ColorSwapHSV;
	public var vortexShader:VortexEffect = null;
	public var vortexActive:Bool = false;
	public var rgbKeyboardMode:Bool = false;
	public var useAbsolutePositions:Bool = false;
	var lastHue:Float = -999.0;

	/**
	 * Detects if a parsed JSON is in Psych Engine stage format.
	 * Psych format has "boyfriend", "opponent", "girlfriend" keys at top level.
	 * Our format uses "character_Positions" instead.
	 */
	public static function isPsychStage(json:Dynamic):Bool {
		// Psych format is identified by having "boyfriend"/"opponent" as character positions
		// AND NOT having our "character_Positions" key
		var hasPsychChars:Bool = Reflect.hasField(json, "boyfriend") || Reflect.hasField(json, "opponent");
		var hasOurs:Bool = Reflect.hasField(json, "character_Positions");
		return hasPsychChars && !hasOurs;
	}

	/**
	 * Converts a Psych Engine stage JSON into our internal StageData format.
	 */
	public static function parsePsychStage(json:Dynamic):StageData {
		// Character positions: Psych uses separate "boyfriend", "girlfriend", "opponent" arrays
		var bfPos:Array<Float> = json.boyfriend != null ? cast json.boyfriend : [770, 450];
		var gfPos:Array<Float> = json.girlfriend != null ? cast json.girlfriend : [400, 130];
		var dadPos:Array<Float> = json.opponent != null ? cast json.opponent : [100, 100];

		// Our order is [bf, dad, gf]
		var charPositions:Array<Array<Float>> = [
			[bfPos[0], bfPos[1]],
			[dadPos[0], dadPos[1]],
			[gfPos[0], gfPos[1]]
		];

		// Camera offsets: Psych has per-character camera offsets
		var camP1:Array<Float> = json.camera_boyfriend != null ? cast json.camera_boyfriend : [0, 0];
		var camP2:Array<Float> = json.camera_opponent != null ? cast json.camera_opponent : [0, 0];
		var camGf:Array<Float> = json.camera_girlfriend != null ? cast json.camera_girlfriend : [0, 0];

		var cameraOffsets:Array<Array<Float>> = [
			[camP1[0], camP1[1]],
			[camP2[0], camP2[1]],
			[camGf[0], camGf[1]]
		];

		// Convert Psych objects array to our StageObject format
		var objects:Array<StageObject> = [];
		var psychObjects:Array<Dynamic> = json.objects != null ? cast json.objects : [];

		for (po in psychObjects) {
			var pType:String = po.type != null ? po.type : "sprite";

			// Character placeholder types define render order, skip as sprite objects
			if (pType == "gf" || pType == "gfGroup" || pType == "dad" || pType == "dadGroup"
				|| pType == "boyfriend" || pType == "boyfriendGroup") {
				continue;
			}

			var obj:StageObject = {
				position: [0, 0],
				scale: 1,
				scaleY: null,
				antialiased: true,
				scroll_Factor: [1, 1],
				file_Name: "",
				is_Animated: pType == "animatedSprite",
				animations: [],
				start_Animation: "",
				object_Name: null,
				layer: null,
				alpha: 1.0,
				zIndex: null,
				blend: null,
				color: null,
				flipX: false,
				flipY: false,
				angle: 0,
				dances: false,
				updateHitbox: true
			};

			// Position
			obj.position = [po.x != null ? po.x : 0, po.y != null ? po.y : 0];

			// Scale: Psych uses [x, y] array, we use single float + optional scaleY
			if (po.scale != null) {
				if (Std.isOfType(po.scale, Array)) {
					var s:Array<Dynamic> = cast po.scale;
					obj.scale = s[0] != null ? s[0] : 1;
					obj.scaleY = s[1] != null ? s[1] : obj.scale;
				} else {
					obj.scale = po.scale;
					obj.scaleY = po.scale;
				}
			}

			// Scroll factor: Psych uses [x, y] array
			if (po.scroll != null) {
				var sc:Array<Dynamic> = cast po.scroll;
				obj.scroll_Factor = [sc[0] != null ? sc[0] : 1, sc[1] != null ? sc[1] : 1];
			}

			// Image/name
			obj.file_Name = po.image != null ? po.image : (po.name != null ? po.name : "");
			obj.object_Name = po.name != null ? po.name : null;

			// Alpha
			obj.alpha = po.alpha != null ? po.alpha : 1.0;

			// Antialiasing
			obj.antialiased = po.antialiasing != null ? po.antialiasing : true;

			// Flip
			obj.flipX = po.flipX != null ? po.flipX : false;
			obj.flipY = po.flipY != null ? po.flipY : false;

			// Angle
			obj.angle = po.angle != null ? po.angle : 0;

			// Color tint: Psych uses hex string "#FFFFFF"
			if (po.color != null) {
				var colorStr:String = po.color;
				if (colorStr.startsWith("#"))
					colorStr = colorStr.substring(1);
				if (colorStr.length == 6) {
					var r:Int = Std.parseInt("0x" + colorStr.substring(0, 2));
					var g:Int = Std.parseInt("0x" + colorStr.substring(2, 4));
					var b:Int = Std.parseInt("0x" + colorStr.substring(4, 6));
					obj.color = [r, g, b];
				}
			}

			// Blend mode
			obj.blend = po.blend != null ? po.blend : null;

			// Beat dance: Psych uses "danceEvery" float
			if (po.danceEvery != null && po.danceEvery > 0) {
				obj.dances = true;
			}

			// Animations: Psych format has "anim", "name", "fps", "loop", "indices", "offsets"
			if (po.animations != null) {
				var psychAnims:Array<Dynamic> = cast po.animations;
				for (pa in psychAnims) {
					var anim:CharacterAnimation = {
						name: pa.anim != null ? pa.anim : "",
						animation_name: pa.name != null ? pa.name : "",
						fps: pa.fps != null ? pa.fps : 24,
						looped: pa.loop != null ? pa.loop : false,
						indices: pa.indices != null ? cast pa.indices : null
					};
					obj.animations.push(anim);
				}
			}

			// First animation to play
			obj.start_Animation = po.firstAnimation != null ? po.firstAnimation : "";

			// Layer: Psych objects after character placeholders are foreground
			obj.layer = null;

			objects.push(obj);
		}

		// Determine layer placement for objects based on character placeholder order
		// Psych renders objects in array order, with gf/dad/bf placeholders defining render breaks
		// We need to place objects before "gf" as BG, between gf and dad as infrontofgf, after bf as fg
		var charOrder:Array<String> = [];
		for (po in psychObjects) {
			var pType:String = po.type != null ? po.type : "";
			if (pType == "gf" || pType == "gfGroup") charOrder.push("gf");
			else if (pType == "dad" || pType == "dadGroup") charOrder.push("dad");
			else if (pType == "boyfriend" || pType == "boyfriendGroup") charOrder.push("bf");
		}

		// Simple heuristic: if bf comes after gf, objects before gf are BG, after bf are FG
		var gfIdx:Int = charOrder.indexOf("gf");
		var bfIdx:Int = charOrder.indexOf("bf");
		if (gfIdx >= 0 && bfIdx > gfIdx && objects.length > 0) {
			// Objects rendered after the last character placeholder are foreground
			var lastCharIdx:Int = -1;
			var spriteIdx:Int = 0;
			for (po in psychObjects) {
				var pType:String = po.type != null ? po.type : "";
				if (pType == "gf" || pType == "gfGroup" || pType == "dad" || pType == "dadGroup"
					|| pType == "boyfriend" || pType == "boyfriendGroup") {
					lastCharIdx = spriteIdx;
				} else {
					if (lastCharIdx >= 0 && spriteIdx > lastCharIdx) {
						// This sprite is after the last character → foreground
						var objIdx:Int = spriteIdx - (spriteIdx - lastCharIdx - 1) - 1;
						// Count actual sprite objects before this character
					}
				}
				spriteIdx++;
			}
		}

		// Background color
		var bgColor:Null<String> = json.backgroundColor != null ? json.backgroundColor : "#000000";

		return {
			character_Positions: charPositions,
			character_Scrolls: [1, 1, 0.95],
			characterZIndices: [0, 0, 0],
			character_Scales: [null, null, null],
			camera_Zoom: json.defaultZoom != null ? json.defaultZoom : 0.9,
			camera_Offsets: cameraOffsets,
			objects: objects,
			scriptName: null,
			backgroundColor: bgColor,
			imageDirectory: json.directory != null && json.directory != "" ? json.directory : null,
			useAbsolutePositions: false,
			rtxData: null
		};
	}

	public function updateStage(?newStage:String) {
	if (newStage != null)
		stage = newStage;

	var stageXmlPath:String = utilities.PorteadorXml.getStageXmlPath(stage);
	var stageJsonPath:String = Paths.json("stage data/" + stage);
	var defaultStageJsonPath:String = Paths.json("stage data/stage");

	if (stage != "" && stageXmlPath != null) {
		var rawXml:String = #if sys (sys.FileSystem.exists(stageXmlPath) ? sys.io.File.getContent(stageXmlPath) : Assets.getText(stageXmlPath)) #else Assets.getText(stageXmlPath) #end;
		stageData = utilities.PorteadorXml.parseCodenameStage(rawXml, stage);
	} else if (stage != "" && Assets.exists(stageJsonPath)) {
		var rawJson:String = Assets.getText(stageJsonPath).trim();
		var parsedJson:Dynamic = Json.parse(rawJson);

		// Detect Psych Engine format and convert
		if (isPsychStage(parsedJson)) {
			stageData = parsePsychStage(parsedJson);
		} else {
			stageData = cast parsedJson;
		}
	} else {
		if (stage == "") {
			stageData = {
				character_Positions: [[0,0],[0,0],[0,0]],
				character_Scrolls: [1,1,1],
				characterZIndices: [0,0,0],
				camera_Zoom: 1,
				character_Scales: [1,1,1],
				camera_Offsets: [[0,0],[0,0]],
				objects: [],
				scriptName: null,
				backgroundColor: "#000000",
				imageDirectory: null,
				useAbsolutePositions: false,
				rtxData: null
			};
			stage = "blank";

			for (member in members)
			{
				if (member is FlxSprite)
					cast(member, FlxSprite).destroy();
			}
			clear();

		} else {
			stageData = cast Json.parse(Assets.getText(defaultStageJsonPath).trim());
			stage = "stage";
		}
	}
	if (stageObjects != null) {
		for (obj in stageObjects) {
			var spr:FlxSprite = obj[1];
			if (spr != null) spr.destroy();
		}
	}
	clear();
	stageObjects = [];
	onBeatHit_Group.clear();
	foregroundSprites.clear();
	infrontOfGFSprites.clear();

	switch (stage) {
		// incase you want to harcode your stage
		default:
			{
				if (stageData != null) {
					camZoom = stageData.camera_Zoom;
					useAbsolutePositions = (stageData?.useAbsolutePositions) ?? false;

					if (stageData.camera_Offsets != null) {
						p1_Cam_Offset.set(stageData.camera_Offsets[0][0], stageData.camera_Offsets[0][1]);
						p2_Cam_Offset.set(stageData.camera_Offsets[1][0], stageData.camera_Offsets[1][1]);
						if (stageData.camera_Offsets.length > 2 && stageData.camera_Offsets[2] != null) {
							gf_Cam_Offset.set(stageData.camera_Offsets[2][0], stageData.camera_Offsets[2][1]);
						} else {
							gf_Cam_Offset.set(0, 0);
						}
					} else {
						p1_Cam_Offset.set(0, 0);
						p2_Cam_Offset.set(0, 0);
						gf_Cam_Offset.set(0, 0);
					}

					player_1_Point.set(stageData.character_Positions[0][0], stageData.character_Positions[0][1]);
					player_2_Point.set(stageData.character_Positions[1][0], stageData.character_Positions[1][1]);
					gf_Point.set(stageData.character_Positions[2][0], stageData.character_Positions[2][1]);

					if (stageData.character_Scrolls != null) {
						p1_Scroll = stageData.character_Scrolls[0];
						p2_Scroll = stageData.character_Scrolls[1];
						gf_Scroll = stageData.character_Scrolls[2];
					} else {
						p1_Scroll = 1.0;
						p2_Scroll = 1.0;
						gf_Scroll = 0.95;
					}

					if (stageData.characterZIndices != null) {
						p1ZIndex = stageData.characterZIndices[0];
						p2ZIndex = stageData.characterZIndices[1];
						gfZIndex = stageData.characterZIndices[2];
					} else {
						p1ZIndex = 0;
						p2ZIndex = 0;
						gfZIndex = 0;
					}

					if (stageData.character_Scales != null) {
						p1_Scale = stageData.character_Scales[0];
						p2_Scale = stageData.character_Scales[1];
						gf_Scale = stageData.character_Scales[2];
					} else {
						p1_Scale = null;
						p2_Scale = null;
						gf_Scale = null;
					}

					var nullObjectNameLoop:Int = 0;
					var shadersEnabled:Bool = Options.getData("shaders");
					var antialiasingEnabled:Bool = Options.getData("antialiasing");
					var imageDirectory:String = stageData.imageDirectory ?? stage;

					for (object in stageData.objects) {
						var sprite:FlxSprite = object.dances
							? new DancingSprite(object.position[0], object.position[1])
							: new FlxSprite(object.position[0], object.position[1]);

						if (shadersEnabled
							&& colorSwap != null
							&& object.object_Name != "vortex"
							&& sprite.shader == null)
						{
							sprite.shader = colorSwap.shader;
						}

						if (object.color != null && object.color.length >= 3)
							sprite.color = FlxColor.fromRGB(object.color[0], object.color[1], object.color[2]);

						sprite.antialiasing = object.antialiased && antialiasingEnabled;
						sprite.scrollFactor.set(object.scroll_Factor[0], object.scroll_Factor[1]);

						if (object.object_Name != null && object.object_Name != "")
							stageObjects.push([object.object_Name, sprite, object]);
						else {
							stageObjects.push(["undefinedSprite" + nullObjectNameLoop, sprite, object]);
							nullObjectNameLoop++;
						}

						var imgPath:String = object.file_Name;
						if (imageDirectory != null && imageDirectory != "" && !imgPath.startsWith(imageDirectory) && !imgPath.startsWith("#")) {
							imgPath = imageDirectory + "/" + imgPath;
						}

						if (object.object_Name == "vortex")
						{
							if (vortexShader == null)
								vortexShader = new VortexEffect();

							sprite.makeGraphic(1, 1);
							sprite.shader = vortexShader.shader;
							vortexActive = true;
						} else if (object.file_Name.startsWith('#')) {
							sprite.makeGraphic(Std.int(object.scale), Std.int(object.scaleY != null ? object.scaleY : object.scale), FlxColor.fromString(object.file_Name));
						} else {
							var atlasData = utilities.PorteadorXml.resolveStageAtlasPaths(imageDirectory, object.file_Name);
							if (atlasData != null || object.is_Animated) {
								if (atlasData != null) {
									sprite.frames = system.OptimizedAssets.getSparrowAtlas(atlasData.imagePath, atlasData.xmlPath);
								} else {
									sprite.frames = Paths.getSparrowAtlas(imgPath, "stages");
								}

								if (object.animations != null && object.animations.length > 0) {
									for (animation in object.animations) {
										var animName:String = animation.name;

										if (animation.name == "beatHit")
											onBeatHit_Group.add(sprite);

										if (animation.indices == null || animation.indices.length == 0) {
											sprite.animation.addByPrefix(animName, animation.animation_name, animation.fps, animation.looped);
										} else {
											sprite.animation.addByIndices(animName, animation.animation_name, animation.indices, "", animation.fps,
												animation.looped);
										}
									}

									if (object.start_Animation != "" && object.start_Animation != null && object.start_Animation != "null")
										sprite.animation.play(object.start_Animation);
								} else if (atlasData != null) {
									utilities.PorteadorXml.autoPopulateAtlasAnimations(sprite, atlasData.xmlPath, object.dances);
								}

								if (object.dances) {
									onBeatHit_Group.add(sprite);
								}
							} else {
								var gPath = utilities.PorteadorXml.resolveStageGraphicPath(imageDirectory, object.file_Name);
								if (gPath != null) {
									sprite.loadGraphic(system.OptimizedAssets.getGraphic(gPath));
								} else {
									sprite.loadGraphic(Paths.gpuBitmap(imgPath, "stages"));
								}
							}
						}

						if (object.scaleY == null) {
							object.scaleY = object.scale;
						}

						sprite.scale.set(object.scale, object.scaleY);

						if (object.updateHitbox || object.updateHitbox == null)
							sprite.updateHitbox();

						if (object.flipX != null)
							sprite.flipX = object.flipX;

						if (object.flipY != null)
							sprite.flipY = object.flipY;

						if (object.angle != null)
							sprite.angle = object.angle;

						if (object.alpha != null)
							sprite.alpha = object.alpha;

						if (object.blend != null) {
							@:privateAccess
							sprite.blend = BlendMode.fromString(object.blend);
						}

						if (object.zIndex != null)
							sprite.zIndex = object.zIndex;

						if (object.layer != null) {
							switch (object.layer.toLowerCase()) {
								case "foreground" | "fg":
									foregroundSprites.add(sprite);
								case "gf" | "infrontofgf":
									infrontOfGFSprites.add(sprite);
								default:
									add(sprite);
							}
						} else {
							add(sprite);
						}
					}
				}

				if (stageData.scriptName == null || stageData.scriptName == "") {
					stageData.scriptName = stage;
				}

				if (FlxG.state is PlayState) {
					var scriptInfo = utilities.PorteadorXml.getStageScriptPath(stageData.scriptName);
					if (scriptInfo == null && stage != null && stage != "" && stage != stageData.scriptName) {
						scriptInfo = utilities.PorteadorXml.getStageScriptPath(stage);
					}
					if (scriptInfo != null) {
						if (scriptInfo.isLua) {
							#if LUA_ALLOWED
							stageScript = new LuaScript(#if MODDING_ALLOWED PolymodAssets #else Assets #end.getPath(scriptInfo.path));
							stageScript.executeOn = STAGE;
							#end
						} else {
							#if HSCRIPT_ALLOWED
							stageScript = new HScript(scriptInfo.path, STAGE);
							for (object in stageObjects) {
								stageScript.set(object[0], object[1]);
							}
							stageScript.set("BlendMode", {
								ADD: BlendMode.ADD,
								ALPHA: BlendMode.ALPHA,
								DARKEN: BlendMode.DARKEN,
								DIFFERENCE: BlendMode.DIFFERENCE,
								ERASE: BlendMode.ERASE,
								HARDLIGHT: BlendMode.HARDLIGHT,
								INVERT: BlendMode.INVERT,
								LAYER: BlendMode.LAYER,
								LIGHTEN: BlendMode.LIGHTEN,
								MULTIPLY: BlendMode.MULTIPLY,
								NORMAL: BlendMode.NORMAL,
								OVERLAY: BlendMode.OVERLAY,
								SCREEN: BlendMode.SCREEN,
								SHADER: BlendMode.SHADER,
								SUBTRACT: BlendMode.SUBTRACT
							});
							stageScript.set("stage", this);
							#end
						}
					} else {
						#if HSCRIPT_ALLOWED
						if (Assets.exists(Paths.hx('data/stage data/${stageData.scriptName}'))) {
							stageScript = new HScript(Paths.hx('data/stage data/${stageData.scriptName}'), STAGE);
							for (object in stageObjects) {
								stageScript.set(object[0], object[1]);
							}
						}
						#end

						#if LUA_ALLOWED
						if (Assets.exists(Paths.lua("stage data/" + stageData.scriptName))) {
							stageScript = new LuaScript(#if MODDING_ALLOWED PolymodAssets #else Assets #end.getPath(Paths.lua("stage data/"
								+ stageData.scriptName)));
							stageScript.executeOn = STAGE;
						}
						#end
					}
				}
			}
	}
}
var rgbHoldTime:Float = 0;

override function update(elapsed:Float)
{
	super.update(elapsed);

	goodElapse = elapsed;

	var rgbPressed:Bool = FlxG.keys.pressed.R && FlxG.keys.pressed.G && FlxG.keys.pressed.B;

	if (rgbPressed)
	{
		rgbHoldTime += elapsed;
		rgbKeyboardMode = rgbHoldTime > 3;
	}
	else
	{
		rgbHoldTime = 0;
	}

	var cs = colorSwap;

	if (rgbKeyboardMode) {
		cs = ensureColorSwap();
		cs.hue = (Conductor.songPosition * 0.0002) % 1;
	}

	if (vortexActive && vortexShader != null)
	{
		if (cs == null)
			cs = ensureColorSwap();

		vortexShader.hue = cs.hue;
		vortexShader.brightness = cs.brightness;
		vortexShader.saturation = cs.saturation;
		vortexShader.update(elapsed);
	}

	if (colorSwap != null)
	{
		colorSwap.update(elapsed);
		var currentHueShift:Float = (colorSwap.hue == 1.1) ? (Math.sin(colorSwap.iTime * 4.0) * 0.5 + 0.5) : colorSwap.hue;
		if (Math.abs(currentHueShift - lastHue) >= 0.005)
		{
			lastHue = currentHueShift;
			syncCharactersColor();
		}
	}
}

public function setVortexEnabled(value:Bool)
{
	vortexActive = value;
}

inline function resolveScale(stageScale:Null<Float>, char:Character):Float
{
	if (char != null && char.graphicSize > 0 && char.graphicSize != 1)
		return char.graphicSize;

	if (stageScale != null && stageScale > 0)
		return stageScale;

	if (char != null && char.graphicSize > 0)
		return char.graphicSize;

	return 1.0;
}

public function setRTX(char:Character):Void
{
	if (char == null) return;
	if (char.isCharacterGroup && char.otherCharacters != null)
	{
		for (other in char.otherCharacters) if (other != null) setCharacterRTX(other);
	}
	setCharacterRTX(char);
	if (colorSwap != null) syncCharactersColor();
}

public function setCharOffsets(?p1:Character, ?gf:Character, ?p2:Character):Void
{
	p1 ??= PlayState.boyfriend;
	gf ??= PlayState.gf;
	p2 ??= PlayState.dad;

	applyCharPositionAndScale(p1, player_1_Point, p1_Scroll, p1_Scale);
	applyCharPositionAndScale(gf, gf_Point, gf_Scroll, gf_Scale);
	applyCharPositionAndScale(p2, player_2_Point, p2_Scroll, p2_Scale);

	p1.zIndex = p1ZIndex;
	gf.zIndex = gfZIndex;
	p2.zIndex = p2ZIndex;

	setRTX(p1);
	setRTX(gf);
	setRTX(p2);

	if (p2.curCharacter.startsWith("gf") && gf.curCharacter.startsWith("gf")) {
		p2.setPosition(gf.x, gf.y);
		p2.scrollFactor.set(gf_Scroll, gf_Scroll);

		if (p2.visible)
			gf.visible = false;
	}
}

function applyCharPositionAndScale(
	mainChar:Character,
	point:FlxPoint,
	scroll:Float,
	stageScale:Null<Float>
):Void
{
	applySingleCharPositionAndScale(mainChar, point, scroll, stageScale);

	if (mainChar.otherCharacters != null) {
		for (character in mainChar.otherCharacters) {
			applySingleCharPositionAndScale(character, point, scroll, stageScale);
		}
	}
}

inline function applySingleCharPositionAndScale(
	character:Character,
	point:FlxPoint,
	scroll:Float,
	stageScale:Null<Float>
):Void
{
	var charScale = resolveScale(stageScale, character);

	if (useAbsolutePositions)
	{
		character.setPosition(
			point.x + character.positioningOffset[0],
			point.y + character.positioningOffset[1]
		);
	}
	else
	{
		character.setPosition(
			(point.x - (character.width / 2)) + character.positioningOffset[0],
			(point.y - character.height) + character.positioningOffset[1]
		);
	}

	character.scale.set(charScale, charScale);
	character.scrollFactor.set(scroll, scroll);
}

/**
 * Positions a character (and its whole group, if it is one) at `point` with the given
 * `scroll`, without touching the scale. Used by the Character Creator to re-seat a
 * character on the stage while editing. `extra` is kept for call-site compatibility
 * (unused here); `useAbsolute` overrides `useAbsolutePositions`.
 */
public function setPosition(character:Character, point:FlxPoint, scroll:Float, ?extra:Int = 0, ?useAbsolute:Bool = false):Void
{
	if (character == null || point == null)
		return;

	var absolute:Bool = (useAbsolute != null) ? useAbsolute : useAbsolutePositions;

	setSingleCharacterPositionAndScale(character, point, scroll, absolute);

	if (character.otherCharacters != null) {
		for (other in character.otherCharacters) {
			setSingleCharacterPositionAndScale(other, point, scroll, absolute);
		}
	}
}

inline function setSingleCharacterPositionAndScale(character:Character, point:FlxPoint, scroll:Float, absolute:Bool):Void
{
	if (absolute) {
		character.setPosition(
			point.x + character.positioningOffset[0],
			point.y + character.positioningOffset[1]
		);
	} else {
		character.setPosition(
			(point.x - (character.width / 2)) + character.positioningOffset[0],
			(point.y - character.height) + character.positioningOffset[1]
		);
	}

	character.scrollFactor.set(scroll, scroll);
}

public function forEachCharacter(fn:Character->Void):Void
	{
		for (char in [PlayState.boyfriend, PlayState.dad, PlayState.gf])
		{
			if (char == null) continue;
			if (char.isCharacterGroup && char.otherCharacters != null)
			{
				for (other in char.otherCharacters) if (other != null) fn(other);
			}
			fn(char);
		}
	}

	static inline function shiftColor(hex:String, alpha:Float, cs:ColorSwapHSV):FlxColor
	{
		var c = FlxColor.fromString(hex);
		if (cs == null) return c;
		var shift:Float = (cs.hue == 1.1) ? (Math.sin(cs.iTime * 4.0) * 0.5 + 0.5) : cs.hue;
		var h:Float = (c.hue + shift * 360.0) % 360.0;
		var s:Float = Math.max(0.0, Math.min(1.0, c.saturation + cs.saturation));
		var b:Float = Math.max(0.0, Math.min(1.0, c.brightness * (1.0 + cs.brightness)));
		return FlxColor.fromHSB(h < 0 ? h + 360.0 : h, s, b, alpha);
	}

	public static inline function applyColorSwapToColor(color:FlxColor, cs:ColorSwapHSV):FlxColor
	{
		if (cs == null) return color;
		var shift:Float = (cs.hue == 1.1) ? (Math.sin(cs.iTime * 4.0) * 0.5 + 0.5) : cs.hue;
		var h:Float = (color.hue + shift * 360.0) % 360.0;
		var s:Float = Math.max(0.0, Math.min(1.0, color.saturation + cs.saturation));
		var b:Float = Math.max(0.0, Math.min(1.0, color.brightness * (1.0 + cs.brightness)));
		return FlxColor.fromHSB(h < 0 ? h + 360.0 : h, s, b, color.alphaFloat);
	}

	public function syncRTX():Void
	{
		forEachCharacter(setCharacterRTX);
		lastHue = -999.0;
	}

	public function syncCharactersColor():Void
	{
		if (stageData?.rtxData == null) return;
		var r = stageData.rtxData;
		var ov = shiftColor(r.overlay, r.overlayAlpha, colorSwap);
		var shadow = shiftColor(r.inner, r.innerAlpha, colorSwap);
		var sat = shiftColor(r.satin, r.satinAlpha, colorSwap);

		forEachCharacter(function(c:Character)
		{
			if (c.rtxShader == null) return;
			var s = c.rtxShader;
			s.overlay = ov;
			s.shadow = shadow;
			s.satin = sat;
			s.overlayAlpha.value = [r.overlayAlpha];
			s.innerShadowAlpha.value = [r.innerAlpha];
			s.satinAlpha.value = [r.satinAlpha];
		});
	}

	public function updateCharactersHue(h:Float):Void
	{
		if (colorSwap != null) colorSwap.hue = h;
		syncCharactersColor();
	}

	function setCharacterRTX(c:Character):Void
	{
		if (c == null || c.debugMode || c.rtxShader == null) return;
		var s = c.rtxShader;

		if (stageData?.rtxData == null)
		{
			s.overlay = s.satin = s.shadow = FlxColor.TRANSPARENT;
			s.shadowAngle = s.shadowDistance = 0;
			return;
		}

		var r = stageData.rtxData;
		s.overlay = shiftColor(r.overlay, r.overlayAlpha, colorSwap);
		s.shadow = shiftColor(r.inner, r.innerAlpha, colorSwap);
		s.satin = shiftColor(r.satin, r.satinAlpha, colorSwap);
		s.overlayAlpha.value = [r.overlayAlpha];
		s.satinAlpha.value = [r.satinAlpha];
		s.innerShadowAlpha.value = [r.innerAlpha];
		s.shadowAngle = r.innerAngle != null ? r.innerAngle : 0;
		s.shadowDistance = r.innerDistance != null ? r.innerDistance : 0;
	}

public function getCharacterPos(character:Int, char:Character = null):Array<Float>
{
	switch (character) {
		case 0: // bf
			if (char == null)
				char = PlayState.boyfriend;

			return [
				(player_1_Point.x - (char.width / 2)) + char.positioningOffset[0],
				(player_1_Point.y - char.height) + char.positioningOffset[1]
			];

		case 1: // dad
			if (char == null)
				char = PlayState.dad;

			return [
				(player_2_Point.x - (char.width / 2)) + char.positioningOffset[0],
				(player_2_Point.y - char.height) + char.positioningOffset[1]
			];

		case 2: // gf
			if (char == null)
				char = PlayState.gf;

			return [
				(gf_Point.x - (char.width / 2)) + char.positioningOffset[0],
				(gf_Point.y - char.height) + char.positioningOffset[1]
			];
	}

	return [0, 0];
}

override public function new(?stageName:String)
{
	super();
	colorSwap = null;
	stage = stageName;
	updateStage();
}

public inline function ensureColorSwap():ColorSwapHSV
{
	if (colorSwap == null) {
		colorSwap = new ColorSwapHSV();
	}
	return colorSwap;
}

public function disableColorSwap()
{
	if (colorSwap == null)
		return;

	for (obj in stageObjects) {
		var spr:FlxSprite = obj[1];
		if (spr != null && spr.shader == colorSwap.shader) {
			spr.shader = null;
		}
	}

	colorSwap = null;
	lastHue = -999.0;
	syncRTX();
}

public function setStageColorSwapEnabled(value:Bool)
{
	if (value)
	{
		var cs = ensureColorSwap();
		for (obj in stageObjects) {
			var spr:FlxSprite = obj[1];
			if (spr != null) {
				if (vortexActive && vortexShader != null && spr.shader == vortexShader.shader)
					continue;
				spr.shader = cs.shader;
			}
		}
	}
	else
	{
		disableColorSwap();
	}
}

override function destroy()
{
	if (player_1_Point != null) { player_1_Point.put(); player_1_Point = null; }
	if (player_2_Point != null) { player_2_Point.put(); player_2_Point = null; }
	if (gf_Point != null) { gf_Point.put(); gf_Point = null; }
	if (p1_Cam_Offset != null) { p1_Cam_Offset.put(); p1_Cam_Offset = null; }
	if (p2_Cam_Offset != null) { p2_Cam_Offset.put(); p2_Cam_Offset = null; }
	if (gf_Cam_Offset != null) { gf_Cam_Offset.put(); gf_Cam_Offset = null; }

	if (stageObjects != null) {
		for (obj in stageObjects) {
			var spr:FlxSprite = obj[1];
			if (spr != null) spr.destroy();
		}
		stageObjects = [];
	}

	if (onBeatHit_Group != null) {
		onBeatHit_Group.clear();
		onBeatHit_Group = null;
	}

	if (stageScript != null) {
		stageScript.destroy();
		stageScript = null;
	}

	super.destroy();
	FlxDestroyUtil.destroy(infrontOfGFSprites);
	FlxDestroyUtil.destroy(foregroundSprites);
}

public function beatHit()
{
	if (Options.getData("animatedBGs")) {
		for (sprite in onBeatHit_Group) {
			if (sprite != null && sprite.animation != null) {
				if (sprite.animation.getByName("danceLeft") != null && sprite.animation.getByName("danceRight") != null) {
					var cur = sprite.animation.curAnim != null ? sprite.animation.curAnim.name : "";
					if (cur == "danceLeft")
						sprite.animation.play("danceRight", true);
					else
						sprite.animation.play("danceLeft", true);
				} else if (sprite.animation.getByName("idle") != null) {
					sprite.animation.play("idle", true);
				} else if (sprite.animation.getByName("beatHit") != null) {
					sprite.animation.play("beatHit", true);
				} else if (sprite.animation.curAnim != null) {
					sprite.animation.play(sprite.animation.curAnim.name, true);
				}
			}
		}

		for (member in members) {
			if (member is DancingSprite) {
				cast(member, DancingSprite).dance();
			}
		}
	}
}

/**
 * Returns a named sprite from a string, if it exists. 
 * Otherwise, returns `null`.
 * @param prop 
 * @return FlxSprite
 */
public function getNamedProp(prop:String):FlxSprite
{
	for (object in stageObjects) {
		if (object[0] == prop) {
			return object[1];
		}
	}
	return null;
}
}

typedef StageData = {
	var character_Positions:Array<Array<Float>>;
	var character_Scrolls:Array<Float>;
	var characterZIndices:Array<Int>;
	var character_Scales:Array<Null<Float>>;
	var camera_Zoom:Float;
	var camera_Offsets:Array<Array<Float>>;
	var objects:Array<StageObject>;
	var scriptName:Null<String>;
	var backgroundColor:Null<String>;
	var imageDirectory:Null<String>;
	var rtxData:Null<Dynamic>;
	var useAbsolutePositions:Null<Bool>;

}
typedef RTXData = 
{
    var overlay:String;
    var overlayAlpha:Float;
    var satin:String;
    var satinAlpha:Float;
    var inner:String;
    var innerAlpha:Float;
    var innerDistance:Float;
    var innerAngle:Float;

    var ?pointLight:Bool;
    var ?lightX:Float;
    var ?lightY:Float;
}
typedef StageObject = {
	// General sprite object Data //
	var position:Array<Float>;
	var zIndex:Null<Int>;
	var scale:Float;
	var scaleY:Null<Float>;
	var antialiased:Bool;
	var scroll_Factor:Array<Float>;
	var blend:Null<String>;
	var color:Array<Int>;
	var object_Name:Null<String>;
	var layer:Null<String>; // default is bg, but fg is possible
	var alpha:Null<Float>;
	var updateHitbox:Null<Bool>;

	var flipX:Null<Bool>;
	var flipY:Null<Bool>;
	var angle:Null<Float>;

	// Image Info //
	var file_Name:String;
	var is_Animated:Bool;
	// Animations //
	var animations:Array<CharacterAnimation>;
	var start_Animation:String;
	var dances:Null<Bool>;
}

