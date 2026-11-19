package game;

import modding.scripts.languages.LuaScript;
import utilities.NoteVariables;
import game.TimeBar;
import flixel.tweens.FlxTween;
import flixel.FlxCamera;
import states.PlayState;
import flixel.FlxG;
import game.Conductor;
import game.StageGroup;
import game.Character;
import game.CharacterPlayingAs;
import flixel.util.FlxColor;
import shaders.ColorSwap;
import shaders.NoteColors;
import openfl.Assets;
class EventHandler {
	static function getEase(ease:String, dir:String):Float->Float {
		var e = ease != null ? ease.toLowerCase().trim() : "linear";
		var d = dir != null ? dir.toLowerCase().trim() : "out";
		switch (e) {
			case "classic" | "smooth": e = "sine";
			case "smoother": e = "smootherstep";
		}
		return CoolUtil.easeFromString(e + d);
	}

static function applyCameraZoom(game:PlayState, zoomStr:String, extraStr:String) {
	if (game != null && game.cameraEventHandler != null) return;
	var targetZoom:Float = Std.parseFloat(zoomStr);
	if (Math.isNaN(targetZoom)) targetZoom = game.defaultCamZoom;

	var parts = extraStr != null ? extraStr.split(",") : [];
	for (i in 0...parts.length) {
		parts[i] = StringTools.trim(parts[i]);
	}
	if (parts.length > 1 && !Math.isNaN(Std.parseFloat(parts[0]))) {
		var steps:Float = Std.parseFloat(parts[0]);
		var easeName:String = parts[1];
		var easeDir:String = parts.length > 2 ? parts[2] : "In";
		var camName:String = parts.length > 3 ? parts[3].toLowerCase() : "camgame";
		var targetCam = (camName == "camhud") ? game.camHUD : game.camGame;

		var duration:Float = steps * (Conductor.stepCrochet / 1000);
		if (duration > 0) {
			if (targetCam == game.camGame) {
				FlxTween.cancelTweensOf(game, ["defaultCamZoom"]);
				FlxTween.tween(game, {defaultCamZoom: targetZoom}, duration, {ease: getEase(easeName, easeDir)});
			} else if (targetCam == game.camHUD) {
				FlxTween.cancelTweensOf(game, ["defaultHudCamZoom"]);
				FlxTween.tween(game, {defaultHudCamZoom: targetZoom}, duration, {ease: getEase(easeName, easeDir)});
			}
			FlxTween.cancelTweensOf(targetCam, ["zoom"]);
			FlxTween.tween(targetCam, {zoom: targetZoom}, duration, {ease: getEase(easeName, easeDir)});
		} else {
			targetCam.zoom = targetZoom;
			if (targetCam == game.camGame)
				game.defaultCamZoom = targetZoom;
			if (targetCam == game.camHUD)
				game.defaultHudCamZoom = targetZoom;
		}
	} else {
		var hudZoom:Float = Std.parseFloat(extraStr);
		if (Math.isNaN(hudZoom)) hudZoom = 1;
		hudZoom = Math.min(Math.max(hudZoom, 0.7), 1.35);
		game.defaultCamZoom = targetZoom;
		game.defaultHudCamZoom = hudZoom;
	}
}


	static function applyCameraFocus(game:PlayState, targetStr:String, extraStr:String) {
	if (game != null && game.cameraEventHandler != null) return;
    var parts = extraStr != null ? extraStr.split(",") : [];
    var c = targetStr != null ? targetStr.toLowerCase().trim() : "";

    var targetX:Float = 0;
    var targetY:Float = 0;
    var steps:Float = 4;
    var easeName:String = "CLASSIC";
    var easeDir:String = "In";
    var doTween:Bool = true;

    if (c == "1" || c == "bf" || c == "boyfriend" || c == "player" || c == "player1") {
        game.lastTurn = "bf";
        game.centerCamera = false;
        if (Options.getData("timeBarStyle").toLowerCase() == "leather engine")
            FlxTween.color(game.timeBar.bar, Conductor.crochet * 0.002, game.timeBar.bar.color, PlayState.boyfriend.barColor);
        steps = parts.length > 0 ? Std.parseFloat(parts[0]) : 4;
        easeName = parts.length > 1 ? parts[1] : "CLASSIC";
        easeDir = parts.length > 2 ? parts[2] : "In";
        var offX = parts.length > 3 ? Std.parseFloat(parts[3]) : 0;
        var offY = parts.length > 4 ? Std.parseFloat(parts[4]) : 0;
        doTween = parts.length > 5 ? (parts[5] == "true" || parts[5] == "1") : true;

        var camTarget = PlayState.boyfriend != null ? PlayState.boyfriend.getCameraCharacter() : null;
        if (camTarget != null) {
            var midPos = camTarget.getMidpoint();
            var stOff = game.stage != null ? game.stage.p1_Cam_Offset : null;
            var stX = stOff != null ? stOff.x : 0;
            var stY = stOff != null ? stOff.y : 0;
            targetX = midPos.x - 100 + camTarget.cameraOffset[0] + stX + ((Math.isNaN(offX)) ? offX : 0);
            targetY = midPos.y - 100 + camTarget.cameraOffset[1] + stY + ((Math.isNaN(offY)) ? offY : 0);
            midPos.put();
        }
        game.call("playerOneTurn", []);
        game.call("onCameraMove", ["bf"]);
    } else if (c == "0" || c == "dad" || c == "opponent" || c == "player2") {
       game.lastTurn = "dad";
        game.centerCamera = false;
        if (Options.getData("timeBarStyle").toLowerCase() == "leather engine")
            FlxTween.color(game.timeBar.bar, Conductor.crochet * 0.002, game.timeBar.bar.color, PlayState.dad.barColor);
        steps = parts.length > 0 ? Std.parseFloat(parts[0]) : 4;
        easeName = parts.length > 1 ? parts[1] : "CLASSIC";
        easeDir = parts.length > 2 ? parts[2] : "In";
        var offX = parts.length > 3 ? Std.parseFloat(parts[3]) : 0;
        var offY = parts.length > 4 ? Std.parseFloat(parts[4]) : 0;
        doTween = parts.length > 5 ? (parts[5] == "true" || parts[5] == "1") : true;

		var camTarget = PlayState.dad != null ? PlayState.dad.getCameraCharacter() : null;
		if (camTarget != null) {
			var midPos = camTarget.getMidpoint();
			var stOff = game.stage != null ? game.stage.p2_Cam_Offset : null;
			var stX = stOff != null ? stOff.x : 0;
			var stY = stOff != null ? stOff.y : 0;
			targetX = midPos.x + 150 + camTarget.cameraOffset[0] + stX + (!Math.isNaN(offX) ? offX : 0);
			targetY = midPos.y - 100 + camTarget.cameraOffset[1] + stY + (!Math.isNaN(offY) ? offY : 0);
			midPos.put();
		}
		game.call("playerTwoTurn", []);
		game.call("onCameraMove", ["dad"]);
} else if (c == "2" || c == "gf" || c == "girlfriend" || c == "player3") {
    game.lastTurn = "gf";
    game.centerCamera = false;
    steps = parts.length > 0 ? Std.parseFloat(parts[0]) : 4;
    easeName = parts.length > 1 ? parts[1] : "CLASSIC";
    easeDir = parts.length > 2 ? parts[2] : "In";
    var offX = parts.length > 3 ? Std.parseFloat(parts[3]) : 0;
    var offY = parts.length > 4 ? Std.parseFloat(parts[4]) : 0;
    doTween = parts.length > 5 ? (parts[5] == "true" || parts[5] == "1") : true;

    var camTarget = PlayState.gf != null ? PlayState.gf.getCameraCharacter() : null;
    if (camTarget != null) {
        var midPos = camTarget.getMidpoint();
        var stOff = (game.stage != null && game.stage.gf_Cam_Offset != null) ? game.stage.gf_Cam_Offset : null;
        var stX = stOff != null ? stOff.x : 0;
        var stY = stOff != null ? stOff.y : 0;
        targetX = midPos.x + camTarget.cameraOffset[0] + stX + (!Math.isNaN(offX) ? offX : 0);
        targetY = midPos.y + camTarget.cameraOffset[1] + stY + (!Math.isNaN(offY) ? offY : 0);
        midPos.put();
    }
    game.call("onCameraMove", ["gf"]);
} else if (c == "3" || c == "center" || c == "middle" || c == "stage" || c == "both" || c == "") {
    game.lastTurn = "center";
    game.centerCamera = true;
    steps = parts.length > 0 ? Std.parseFloat(parts[0]) : 4;
    easeName = parts.length > 1 ? parts[1] : "CLASSIC";
    easeDir = parts.length > 2 ? parts[2] : "In";
    var offX = parts.length > 3 ? Std.parseFloat(parts[3]) : 0;
    var offY = parts.length > 4 ? Std.parseFloat(parts[4]) : 0;
    doTween = parts.length > 5 ? (parts[5] == "true" || parts[5] == "1") : true;

    var bfTarget = PlayState.boyfriend != null ? PlayState.boyfriend.getCameraCharacter() : null;
    var dadTarget = PlayState.dad != null ? PlayState.dad.getCameraCharacter() : null;
    var bfMidPos = bfTarget != null ? bfTarget.getMidpoint() : null;
    var dadMidPos = dadTarget != null ? dadTarget.getMidpoint() : null;
    var p1X = (bfMidPos != null && bfTarget != null) ? (bfMidPos.x - 100 + bfTarget.cameraOffset[0] + (game.stage != null && game.stage.p1_Cam_Offset != null ? game.stage.p1_Cam_Offset.x : 0)) : 0;
    var p1Y = (bfMidPos != null && bfTarget != null) ? (bfMidPos.y - 100 + bfTarget.cameraOffset[1] + (game.stage != null && game.stage.p1_Cam_Offset != null ? game.stage.p1_Cam_Offset.y : 0)) : 0;
    var p2X = (dadMidPos != null && dadTarget != null) ? (dadMidPos.x + 150 + dadTarget.cameraOffset[0] + (game.stage != null && game.stage.p2_Cam_Offset != null ? game.stage.p2_Cam_Offset.x : 0)) : 0;
    var p2Y = (dadMidPos != null && dadTarget != null) ? (dadMidPos.y - 100 + dadTarget.cameraOffset[1] + (game.stage != null && game.stage.p2_Cam_Offset != null ? game.stage.p2_Cam_Offset.y : 0)) : 0;
    if (bfMidPos != null) bfMidPos.put();
    if (dadMidPos != null) dadMidPos.put();

    targetX = (p1X + p2X) * 0.5 + (!Math.isNaN(offX) ? offX : 0);
    targetY = (p1Y + p2Y) * 0.5 + (!Math.isNaN(offY) ? offY : 0);
    game.call("onCameraMove", ["center"]);
} else {
    var posX = Std.parseFloat(targetStr);
    var posY = parts.length > 0 ? Std.parseFloat(parts[0]) : 0;
    if (Math.isNaN(posX) || Math.isNaN(posY)) return;
    steps = parts.length > 1 ? Std.parseFloat(parts[1]) : 4;
    easeName = parts.length > 2 ? parts[2] : "CLASSIC";
    easeDir = parts.length > 3 ? parts[3] : "In";
    doTween = parts.length > 4 ? (parts[4] == "true" || parts[4] == "1") : true;
    var isOffset = parts.length > 5 ? (parts[5] == "true" || parts[5] == "1") : false;
    targetX = isOffset ? (game.camFollow.x + posX) : posX;
    targetY = isOffset ? (game.camFollow.y + posY) : posY;
}

if (!doTween) {
    if (game.cameraSystem != null) game.cameraSystem.setTarget(targetX, targetY, false, true);
    game.camFollow.setPosition(targetX, targetY);
} else if (easeName.toUpperCase() != "CLASSIC" && steps > 0) {
    var duration = steps * (Conductor.stepCrochet / 1000);
    if (duration > 0 && game.cameraSystem != null) {
        game.cameraSystem.tweenTo(targetX, targetY, duration, getEase(easeName, easeDir));
    } else {
        if (game.cameraSystem != null) game.cameraSystem.setTarget(targetX, targetY, Options.getData("vsliceCamera"));
        game.camFollow.setPosition(targetX, targetY);
    }
} else {
    if (game.cameraSystem != null) game.cameraSystem.setTarget(targetX, targetY, false);
    game.camFollow.setPosition(targetX, targetY);
}
}



	public static function processEvent(game:PlayState, event:Array<Dynamic>) {
		switch (event[0].toLowerCase()) {
		
			case "hey!":
				var charString:String = event[2].toLowerCase();

				var char:Int = 0;

				if (charString == "bf" || charString == "boyfriend" || charString == "player" || charString == "player1")
					char = 1;

				if (charString == "gf" || charString == "girlfriend" || charString == "player3")
					char = 2;

				switch (char) {
					case 0:
						PlayState.boyfriend.playAnim("hey", true);
						PlayState.gf.playAnim("cheer", true);
					case 1:
						PlayState.boyfriend.playAnim("hey", true);
					case 2:
						PlayState.gf.playAnim("cheer", true);
				}
			case "set gf speed":
				if (Std.parseInt(event[2]) != null)
					game.gfSpeed = Std.parseInt(event[2]);
			case "character will idle":
				var char = PlayState.getCharFromEvent(event[2]);

				var funny = Std.string(event[3]).toLowerCase() == "true";

				char.shouldDance = funny;
			case "set camera zoom" | "camera zoom" | "zoomcamera":
				applyCameraZoom(game, event[2], event[3]);
			case "change character alpha":
				var char = PlayState.getCharFromEvent(event[2]);

				var alphaVal:Float = Std.parseFloat(event[3]);

				if (Math.isNaN(alphaVal))
					alphaVal = 0.5;

				char.alpha = alphaVal;
			case "play character animation":
				var character:Character = PlayState.getCharFromEvent(event[2]);

				var anim:String = "idle";

				if (event[3] != "")
					anim = event[3];

				character.playAnim(anim, true);
			case "camera flash":
				var time = Std.parseFloat(event[3]);

				if (Math.isNaN(time))
					time = 1;

				if (Options.getData("flashingLights"))
					game.camGame.flash(FlxColor.fromString(event[2].toLowerCase()), time, () -> {}, true);
				case "set camera position" | "camera position" | "focuscamera" | "camera movement":
					applyCameraFocus(game, Std.string(event[2]), Std.string(event[3]));
				case "camera follow pos":
					if ((event[2] == null || event[2] == "") && (event[3] == null || event[3] == "")) {
						game.turnChange(game.lastTurn != "" ? game.lastTurn : "dad");
					} else {
						applyCameraFocus(game, Std.string(event[2]), Std.string(event[3]));
					}
				case "center camera" | "camera center" | "center_camera":
					var val = Std.string(event[2]).toLowerCase().trim();
					var enable = (val == "" || val == "true" || val == "1" || val == "on");
					game.centerCamera = enable;
					if (enable) {
						applyCameraFocus(game, "center", Std.string(event[3]));
					} else {
						game.turnChange(game.lastTurn != "" ? game.lastTurn : "dad");
					}
				case "health drain":
					var drain:Float = Std.parseFloat(event[2]);
					if (!Math.isNaN(drain)) {
						game.healthDrainAmount = drain;
					}
			case "camera fade":
				var time = Std.parseFloat(event[3]);

				if (Math.isNaN(time))
					time = 1;

				if (Options.getData("flashingLights"))
					game.camGame.fade(FlxColor.fromString(event[2].toLowerCase()), time, false, () -> {}, true);
			
			case "add camera zoom":
				if (game.cameraEventHandler != null) return;
				if (game.cameraZooms && ((FlxG.camera.zoom < 1.35 && game.camZooming) || !game.camZooming)) {
					var addGame:Float = Std.parseFloat(event[2]);
					var addHUD:Float = Std.parseFloat(event[3]);

					if (Math.isNaN(addGame))
						addGame = 0.015;

					if (Math.isNaN(addHUD))
						addHUD = 0.03;

					FlxG.camera.zoom = Math.min(FlxG.camera.zoom + addGame * game.cameraZoomStrength, 1.35);
					game.camHUD.zoom = Math.min(Math.max(game.camHUD.zoom + addHUD * game.cameraZoomStrength, 0.7), 1.35);
				}
			case "screen shake":
				if (Options.getData("screenShakes")) {
					var valuesArray:Array<String> = [event[2], event[3]];
					var targetsArray:Array<FlxCamera> = [game.camGame, game.camHUD];

					for (i in 0...targetsArray.length) {
						var split:Array<String> = valuesArray[i].split(',');
						var duration:Float = 0;
						var intensity:Float = 0;

						if (split[0] != null)
							duration = Std.parseFloat(split[0].trim());
						if (split[1] != null)
							intensity = Std.parseFloat(split[1].trim());
						if (Math.isNaN(duration))
							duration = 0;
						if (Math.isNaN(intensity))
							intensity = 0;

						if (duration > 0 && intensity != 0)
							targetsArray[i].shake(intensity, duration);
					}
				}
			case "change scroll speed":
				var duration:Float = Std.parseFloat(event[3]);

				if (Math.isNaN(duration))
					duration = 0;

				var funnySpeed = Std.parseFloat(event[2]);

				if (!Math.isNaN(funnySpeed)) {
					if (duration > 0)
						FlxTween.tween(game, {speed: funnySpeed}, duration);
					else
						game.speed = funnySpeed;
				}
			case "change camera speed":
				if (game.cameraEventHandler != null) return;
				var speed:Float = Std.parseFloat(event[2]);
				if (Math.isNaN(speed))
					speed = 1;
				game.cameraSpeed = speed;
			case "change camera zoom speed":
				if (game.cameraEventHandler != null) return;
				var speed:Float = Std.parseFloat(event[2]);
				if (Math.isNaN(speed))
					speed = 1;
				game.cameraZoomSpeed = speed;
			case "change camera zoom strength":
				if (game.cameraEventHandler != null) return;
				var strength:Float = Std.parseFloat(event[2]);
				if (Math.isNaN(strength))
					strength = 1;
				game.cameraZoomStrength = strength;
				var rate:Float = Std.parseFloat(event[3]);
				if (Math.isNaN(rate))
					rate = 1;
				game.cameraZoomRate = rate;
			case "character will idle?":
				var char = PlayState.getCharFromEvent(event[2]);

				var funny = Std.string(event[3]).toLowerCase() == "true";

				char.shouldDance = funny;
			case "change character":
				if (Options.getData("charsAndBGs"))
					game.cacheEventCharacter(event);
			case "change stage":
				if (Options.getData("charsAndBGs")) {
					game.removeBgStuff();

					if (game.scripts.exists(game.stage.stage)) {
						game.scripts.get(game.stage.stage).call("onDestroy", []);
						game.scripts.remove(game.stage.stage);
					}

					game.stage.active = false;

					game.stage.visible = false;
					game.stage.foregroundSprites.visible = false;
					game.stage.infrontOfGFSprites.visible = false;

					game.stage = game.stageMap.get(event[2]);
					#if CAMERA_TOOLS
					if (game.cameraEventHandler != null)
						game.cameraEventHandler.stage = game.stage;
					#end

					if (game.stage.stageScript != null) {
						game.stage.stageScript.executeOn = STAGE;
						game.scripts.set(game.stage.stage, game.stage.stageScript);
					}

					game.stage.visible = true;
					game.stage.foregroundSprites.visible = true;
					game.stage.infrontOfGFSprites.visible = true;
					game.stage.active = true;

					game.defaultCamZoom = game.stage.camZoom;

					game.camGame.bgColor = FlxColor.fromString(game.stage.stageData.backgroundColor ?? "#000000");

					game.call("create", [game.stage.stage], STAGE);
					game.call("createStage", [game.stage.stage]);

					#if LUA_ALLOWED
					if (game.stage.stageScript != null) {
						if (game.stage.stageScript is LuaScript)
							game.stage.stageScript.setup();
					}
					#end

					game.call("start", [game.stage.stage], STAGE);

					game.addBgStuff();
				}
			case "change keycount" | "change mania" | "change keys":
				var pkStr:String = (event.length > 2) ? StringTools.trim(Std.string(event[2])) : "";
				var kStr:String = (event.length > 3) ? StringTools.trim(Std.string(event[3])) : "";
				var newPlayerKeyCount:Null<Int> = Std.parseInt(pkStr);
				var newKeyCount:Null<Int> = Std.parseInt(kStr);
				if (newPlayerKeyCount == null || newPlayerKeyCount < 1)
					newPlayerKeyCount = (newKeyCount != null && newKeyCount >= 1) ? newKeyCount : PlayState.SONG.playerKeyCount;
				if (newKeyCount == null || newKeyCount < 1)
					newKeyCount = newPlayerKeyCount;

				PlayState.SONG.keyCount = newKeyCount;
				PlayState.SONG.playerKeyCount = newPlayerKeyCount;
				PlayState.playerStrums.clear();
				PlayState.enemyStrums.clear();
				PlayState.strumLineNotes.clear();

				game.splash_group.clear();
				var allBinds = Options.getData("binds", "binds");
				var pkIdx:Int = PlayState.SONG.playerKeyCount - 1;
				if (allBinds != null && pkIdx >= 0 && pkIdx < allBinds.length && allBinds[pkIdx] != null) {
					game.binds = allBinds[pkIdx];
				}
				game.cachedFlxKeys = [for (b in game.binds) flixel.input.keyboard.FlxKey.fromString(b)];
				game.justPressedArray = [];
				game.heldArray = [];
				game.justReleasedArray = [];
				game.releasedArray = [];
				if (Options.getData("middlescroll")) {
					game.generateStaticArrows(50, false);
					game.generateStaticArrows(0.5, true);
				} else {
					if (PlayState.characterPlayingAs == BF) {
						game.generateStaticArrows(0, false);
						game.generateStaticArrows(1, true);
					} else {
						game.generateStaticArrows(1, false);
						game.generateStaticArrows(0, true);
					}
				}
				#if MODCHARTING_TOOLS
				modcharting.NoteMovement.getDefaultStrumPos(game);
				if (game.playfieldRenderer != null) {
					game.playfieldRenderer.modifierTable.reconstructTable();
				}
				#end
				for (i in 0...PlayState.strumLineNotes.length) {
					var babyArrow = PlayState.strumLineNotes.members[i];
					if (babyArrow != null) {
						var isPlayerArrow:Bool = PlayState.playerStrums.members.contains(babyArrow);
						var targetAlpha:Float = (Options.getData("middlescroll") && !isPlayerArrow) ? 0.35 : 1.0;
						var targetY:Float = babyArrow.y;
						babyArrow.y = targetY - 10;
						babyArrow.alpha = 0;
						flixel.tweens.FlxTween.tween(babyArrow, {y: targetY, alpha: targetAlpha}, 0.6, {
							ease: flixel.tweens.FlxEase.circOut,
							startDelay: 0.05 * (babyArrow.ID % (isPlayerArrow ? newPlayerKeyCount : newKeyCount))
						});
					}
				}
				if (game.camHUD != null) {
					game.camHUD.zoom += 0.035;
				}
				#if LUA_ALLOWED
				game.set("playerKeyCount", newPlayerKeyCount);
				game.set("keyCount", newKeyCount);
				for (i in 0...PlayState.strumLineNotes.length) {
					var member = PlayState.strumLineNotes.members[i];

					game.set("defaultStrum" + i + "X", member.x);
					game.set("defaultStrum" + i + "Y", member.y);
					game.set("defaultStrum" + i + "Angle", member.angle);

					game.set("defaultStrum" + i, {
						x: member.x,
						y: member.y,
						angle: member.angle,
					});

					if (PlayState.enemyStrums.members.contains(member)) {
						game.set("enemyStrum" + i % PlayState.SONG.keyCount, {
							x: member.x,
							y: member.y,
							angle: member.angle,
						});
					} else {
						game.set("playerStrum" + i % PlayState.SONG.playerKeyCount, {
							x: member.x,
							y: member.y,
							angle: member.angle,
						});
					}
				}
				#end
			case "change ui skin":
				var noteskin:String = Std.string(event[2]);
				PlayState.SONG.ui_Skin = noteskin;
				game.setupUISkinConfigs(noteskin);

				game.arrow_Configs.clear();
				game.type_Configs.clear();

				var oldTimeBar = game.timeBar;
				game.timeBar = new TimeBar(PlayState.SONG, PlayState.storyDifficultyStr);
				game.timeBar.cameras = oldTimeBar.cameras;
				game.timeBar.x = oldTimeBar.x;
				game.timeBar.y = oldTimeBar.y;
				game.timeBar.alpha = oldTimeBar.alpha;
				game.insert(game.members.indexOf(oldTimeBar), game.timeBar);
				game.remove(oldTimeBar, true);
				oldTimeBar.destroy();

				PlayState.playerStrums.clear();
				PlayState.enemyStrums.clear();
				PlayState.strumLineNotes.clear();
				game.splash_group.clear();
				if (Options.getData("middlescroll")) {
					game.generateStaticArrows(50, false, false);
					game.generateStaticArrows(0.5, true, false);
				} else {
					if (PlayState.characterPlayingAs == BF) {
						game.generateStaticArrows(0, false, false);
						game.generateStaticArrows(1, true, false);
					} else {
						game.generateStaticArrows(1, false, false);
						game.generateStaticArrows(0, true, false);
					}
				}

				for (note in game.notes.members)
					refreshNoteSkin(note, game);
				for (note in game.unspawnNotes)
					refreshNoteSkin(note, game);
				game.set_speed(game.speed);
			// FNFC stuff
			case 'hscript call':
				var funcName:String = event[2];
				var funcArgs:String = event[3];
				var argsArray:Array<Dynamic> = (funcArgs != null && funcArgs != "") ? funcArgs.split(',') : [];
				game.call(funcName, argsArray);
			case 'playanimation':
				var character:Character = PlayState.getCharFromEvent(event[2]);

				var anim:String = "idle";

				var splitShit:Array<String> = event[3].split(',');

				if (splitShit[0] != "")
					anim = splitShit[0];

				character.playAnim(anim, splitShit[1] == "true");
			case 'bpm change':
				// Codename charts store tempo changes as time based events, so a
				// change can land in the middle of a section. Registering it on
				// the map keeps step / beat maths correct from that point on,
				// instead of only snapping on section borders.
				var newBpm:Float = Std.parseFloat(Std.string(event[2]));
				var changeTime:Float = event[1] != null ? Std.parseFloat(Std.string(event[1])) : Conductor.songPosition;
				if (Math.isNaN(changeTime)) changeTime = Conductor.songPosition;
				if (event[2] != null && event[2] != "" && !Math.isNaN(newBpm) && newBpm > 0)
					Conductor.addBPMChangeAtTime(changeTime, newBpm);
			case 'continuous bpm change':
				var rampParts:Array<String> = event[2] != null ? Std.string(event[2]).split(',') : [];
				var rampBpm:Float = rampParts.length > 0 ? Std.parseFloat(rampParts[0]) : Math.NaN;
				var rampSteps:Float = rampParts.length > 1 ? Std.parseFloat(rampParts[1]) : Math.NaN;
				var rampTime:Float = event[1] != null ? Std.parseFloat(Std.string(event[1])) : Conductor.songPosition;
				if (Math.isNaN(rampTime)) rampTime = Conductor.songPosition;
				if (!Math.isNaN(rampBpm) && rampBpm > 0) {
					if (Math.isNaN(rampSteps) || rampSteps < 0) rampSteps = 0;
					Conductor.registerContinuousBPMChange(rampTime, rampBpm, rampSteps);
				}
			case 'scrollspeed':
				var splitValue1:Array<String> = event[2].split(',');
				var splitValue2:Array<String> = event[3] != null ? event[3].split(',') : [];
				var duration:Float = Std.parseFloat(splitValue1[0]);

				if (Math.isNaN(duration))
					duration = 0;

				var speed:Float = splitValue1.length > 1 ? Std.parseFloat(splitValue1[1]) : game.speed;
				if (Math.isNaN(speed))
					speed = game.speed;

				var absolute:Bool = splitValue2.length > 2 && (splitValue2[2] == "true" || splitValue2[2] == "1");

				var targetSpeed:Float = absolute ? speed : game.speed * speed;

				if (duration > 0)
					FlxTween.tween(game, {speed: targetSpeed}, duration, {ease: CoolUtil.easeFromString(splitValue2.length > 1 ? splitValue2[1] : "linear")});

				for (notes in [game.notes.members, game.unspawnNotes]) {
					for (note in notes) {
						if (!absolute) {
							FlxTween.tween(note, {speed: note.originalSpeed * speed}, duration, {ease: CoolUtil.easeFromString(splitValue2.length > 1 ? splitValue2[1] : "linear")});
						} else {
							FlxTween.tween(note, {speed: speed}, duration, {ease: CoolUtil.easeFromString(splitValue2.length > 1 ? splitValue2[1] : "linear")});
						}
					}
				}
		}
	}

	static function refreshNoteSkin(note:Note, game:PlayState):Void {
		var oldAnim:String = note.animation.curAnim != null ? note.animation.curAnim.name : "default";
		note.frames = Note.getFrames(note);

		var localKeyCount:Int = note.mustPress ? note.song.playerKeyCount : note.song.keyCount;

		note.setupNoteAnimations(NoteVariables.animationDirections[localKeyCount - 1][note.noteData]);

		if (!game.arrow_Configs.exists(note.arrow_Type)) {
			var newSkin:String = PlayState.SONG.ui_Skin;
			if (game.types != null && game.types.contains(note.arrow_Type)) {
				if (Assets.exists(Paths.txt("ui skins/" + newSkin + "/" + note.arrow_Type)))
					game.arrow_Configs.set(note.arrow_Type, CoolUtil.coolTextFile(Paths.txt("ui skins/" + newSkin + "/" + note.arrow_Type)));
				else if (Assets.exists(Paths.txt("ui skins/default/" + note.arrow_Type)))
					game.arrow_Configs.set(note.arrow_Type, CoolUtil.coolTextFile(Paths.txt("ui skins/default/" + note.arrow_Type)));
				else
					game.arrow_Configs.set(note.arrow_Type, CoolUtil.coolTextFile(Paths.txt("ui skins/" + newSkin + "/default")));
			} else {
				if (Assets.exists(Paths.txt("ui skins/default/" + note.arrow_Type)))
					game.arrow_Configs.set(note.arrow_Type, CoolUtil.coolTextFile(Paths.txt("ui skins/default/" + note.arrow_Type)));
				else if (Assets.exists(Paths.txt("ui skins/" + newSkin + "/default")))
					game.arrow_Configs.set(note.arrow_Type, CoolUtil.coolTextFile(Paths.txt("ui skins/" + newSkin + "/default")));
				else
					game.arrow_Configs.set(note.arrow_Type, CoolUtil.coolTextFile(Paths.txt("ui skins/default/default")));
			}
			game.type_Configs.set(note.arrow_Type,
				Assets.exists(Paths.txt("arrow types/" + note.arrow_Type))
					? CoolUtil.coolTextFile(Paths.txt("arrow types/" + note.arrow_Type))
					: CoolUtil.coolTextFile(Paths.txt("arrow types/default")));
		}

		var uiScale = Std.parseFloat(game.ui_settings[0]);
		var uiMult = Std.parseFloat(game.ui_settings[2]);
		var mSizeVal = Std.parseFloat(game.mania_size[localKeyCount - 1]);
		var isPixelSkin:Bool = uiScale >= 2.0;
		var isHighResSprite:Bool = note.frameWidth > 50;
		var lmaoStuff:Float = (isPixelSkin && isHighResSprite) ? 0.7 * (uiMult - mSizeVal) : uiScale * (uiMult - mSizeVal);

		if (note.isSustainNote) {
			note.scale.set(lmaoStuff, lmaoStuff);
			note.updateHitbox();
			note.centerOffsets();
		} else {
			note.scale.set(lmaoStuff, lmaoStuff);
			note.updateHitbox();
		}

		note.antialiasing = ((isPixelSkin && isHighResSprite) || (game.ui_settings[3] == "true")) && Options.getData("antialiasing");

		var arrowConfig = game.arrow_Configs.get(note.arrow_Type);
		note.affectedbycolor = false;
		if (arrowConfig != null && arrowConfig.length > 5 && arrowConfig[5] != null && arrowConfig[5].trim().toLowerCase() == "true")
			note.affectedbycolor = true;

		var noteSaturation:Float = 0;
		var noteBrightness:Float = 0;
		if (arrowConfig != null) {
			if (arrowConfig.length > 6 && arrowConfig[6] != null) {
				var v = Std.parseFloat(arrowConfig[6]);
				if (!Math.isNaN(v)) noteSaturation = v;
			}
			if (arrowConfig.length > 7 && arrowConfig[7] != null) {
				var v = Std.parseFloat(arrowConfig[7]);
				if (!Math.isNaN(v)) noteBrightness = v;
			}
		}

		var animationName = NoteVariables.animationDirections[localKeyCount - 1][note.noteData];
		var noteColor:Array<Float> = cast NoteColors.getNoteColor(animationName);
		var noteColorKey = (note.affectedbycolor && noteColor != null ? Std.string(noteColor) : "default") + "_" + noteSaturation + "_" + noteBrightness;

		if (!ColorSwap.colorSwapCache.exists(noteColorKey))
			ColorSwap.colorSwapCache.set(noteColorKey, new ColorSwap());

		note.colorSwap = ColorSwap.colorSwapCache.get(noteColorKey);

		var useShader:Bool = note.affectedbycolor || noteSaturation != 0 || noteBrightness != 0;
		if (useShader)
			note.shader = note.colorSwap.shader;
		else
			note.shader = null;

		if (note.colorSwap != null) {
			if (note.affectedbycolor && noteColor != null) {
				note.colorSwap.r = noteColor[0];
				note.colorSwap.g = noteColor[1];
				note.colorSwap.b = noteColor[2];
			} else {
				note.colorSwap.r = 255;
				note.colorSwap.g = 0;
				note.colorSwap.b = 0;
			}
			note.colorSwap.saturation = noteSaturation;
			note.colorSwap.brightness = noteBrightness;
		}

		if (note.animation.getByName(oldAnim) != null)
			note.animation.play(oldAnim);
	}
}