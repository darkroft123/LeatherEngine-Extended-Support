package toolbox;

import openfl.display.BlendMode;
import flixel.addons.ui.U;
import ui.Popup;
import flixel.text.FlxInputText;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.FlxUITabMenu;
import openfl.events.IOErrorEvent;
import openfl.events.Event;
import openfl.net.FileReference;
import flixel.FlxSprite;
import flixel.FlxObject;
import game.Conductor;
import flixel.math.FlxMath;
import game.Character;
import ui.FlxScrollableDropDownMenu;
import states.MusicBeatState;
import game.StageGroup;
import flixel.util.FlxColor;
import flixel.text.FlxText;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.addons.ui.FlxUIDropDownMenu;
import flixel.ui.FlxButton;
import haxe.Json;


@:publicFields
class StageMakingState extends MusicBeatState {
	var _file:FileReference;

	/* STAGE STUFF */
	var stages:Array<String>;

	var stageName:String = 'stage';

	var stage:StageGroup;

	var stageObjectPos:Array<FlxSprite> = [];

	var stageData:StageData;

	var bfChar:String = "bf";
	var gfChar:String = "gf";
	var dadChar:String = "dad";

	var bf:Character;
	var gf:Character;
	var dad:Character;

	var bfPos:FlxSprite;
	var gfPos:FlxSprite;
	var dadPos:FlxSprite;

	var selectedThing:Bool = false;
	var selected:Dynamic;

	var objects:Array<Array<Dynamic>> = [];
	var selectedObject:Int = 0;

	/* UI */
	var jsonButton:FlxButton;
	var stageDropdown:FlxScrollableDropDownMenu;
	var objectDropdown:FlxScrollableDropDownMenu;
	var stageZoom:FlxUINumericStepper;
	var zoomLabel:FlxText;
	var camZoom:FlxText;

	var blendDropDown:FlxScrollableDropDownMenu;
	var blendLabel:FlxText;

	var stageLabel:FlxText;
	var spriteLabel:FlxText;

	var xStepper:FlxUINumericStepper;
	var xLabel:FlxText;

	var yStepper:FlxUINumericStepper;
	var yLabel:FlxText;

	var charDropDown:FlxScrollableDropDownMenu;

	var scaleStepper:FlxUINumericStepper;
	var scaleLabel:FlxText;
	var scaleStepperY:FlxUINumericStepper;

	var alphaStepper:FlxUINumericStepper;
	var alphaLabel:FlxText;

	var fileInput:FlxInputText;
	var fileLabel:FlxText;

	var scrollStepperX:FlxUINumericStepper;
	var scrollStepperY:FlxUINumericStepper;
	var scrollLabel:FlxText;

	var UI_box:FlxUITabMenu;

	var startY:Int = 50;
	var zoom:Float;

	/* CAMERA */
	var stageCam:FlxCamera;
	var camHUD:FlxCamera;

	var camFollow:FlxObject;

	var canPopup:Bool = true;

	var cameraPreview:FlxSprite;

	var blendModes:Array<String> = ["normal", "add", "darken", "lighten", "multiply", "screen", "subtract"];

	function new(selectedStage:String) {
		super();

		stages = CoolUtil.coolTextFile(Paths.txt('stageList'));

		if (selectedStage != null)
			stageName = selectedStage;
	}

	override function create() {
		hasTransitions = false;
		FlxG.mouse.visible = true;

		stageCam = new FlxCamera();
		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;

		FlxG.cameras.reset(stageCam);
		FlxG.cameras.add(camHUD, false);

		FlxG.cameras.setDefaultDrawTarget(stageCam, true);

		FlxG.camera = stageCam;

		stage = new StageGroup(stageName);

		bf = new Character(0, 0, bfChar, true);

		gf = new Character(0, 0, gfChar);
		gf.scrollFactor.set(0.95, 0.95);

		dad = new Character(0, 0, dadChar);

		var tabs = [{name: 'Editor', label: 'Editor'}, {name: 'object', label: 'object'}];

		UI_box = new FlxUITabMenu(null, /*tabs*/ [], false);

		UI_box.resize(300, 400);
		UI_box.x = 10;
		UI_box.y = startY;
		UI_box.scrollFactor.set();
		UI_box.cameras = [camHUD];

		stageLabel = new FlxText(20, startY + 10, 0, "Stage Settings", 12);
		stageLabel.scrollFactor.set();
		stageLabel.cameras = [camHUD];
		stageDropdown = new FlxScrollableDropDownMenu(20, stageLabel.y + stageLabel.height + 4, FlxUIDropDownMenu.makeStrIdLabelArray(stages, true),
			function(stageID:String) {
				if (canPopup) {
					var popup:Popup = null;
					popup = new Popup(BOOL, [
						() -> {
							stageName = stages[Std.parseInt(stageID)];
							reloadStage();
							remove(popup);
							canPopup = true;
						},
						() -> {
							remove(popup);
							canPopup = true;
						}
					], "This will clear all progress. Continue?");
					popup.cameras = [camHUD];
					add(popup);
					canPopup = false;
				}
			});

		stageDropdown.selectedLabel = stageName;
		stageDropdown.scrollFactor.set();
		stageDropdown.cameras = [camHUD];

		camZoom = new FlxText(10, 0, 0, "Camera Zoom: " + stageCam.zoom, 24);
		camZoom.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE_FAST, FlxColor.BLACK);
		camZoom.scrollFactor.set();
		camZoom.cameras = [camHUD];

		jsonButton = new FlxButton(stageDropdown.x + stageDropdown.width + 4, stageDropdown.y, "Save JSON", saveLevel);
		jsonButton.scrollFactor.set();
		jsonButton.cameras = [camHUD];

		stageZoom = new FlxUINumericStepper(jsonButton.x + jsonButton.width + 4, jsonButton.y + 4, 0.05, stageData?.camera_Zoom ?? 1, 0.1, 10, 2);
		stageZoom.scrollFactor.set();
		stageZoom.cameras = [camHUD];
		stageZoom.name = "stage_zoom";

		zoomLabel = new FlxText(stageZoom.x, stageZoom.y - stageZoom.height - 2, 0, "Stage Zoom", 10);
		zoomLabel.scrollFactor.set();
		zoomLabel.cameras = [camHUD];

		spriteLabel = new FlxText(20, jsonButton.y + jsonButton.height + 4, 0, "Sprite Settings", 12);
		spriteLabel.scrollFactor.set();
		spriteLabel.cameras = [camHUD];

		xStepper = new FlxUINumericStepper(20, spriteLabel.y + spriteLabel.height + 4, 1, 0, -100000, 100000, 1);
		xStepper.value = 0;
		xStepper.name = "x_stepper";
		xStepper.scrollFactor.set();
		xStepper.cameras = [camHUD];

		xLabel = new FlxText(xStepper.x + xStepper.width + 2, xStepper.y - 2, 0, "X", 10);
		xLabel.scrollFactor.set();
		xLabel.cameras = [camHUD];

		yStepper = new FlxUINumericStepper(xLabel.x + xLabel.width + 2, xStepper.y, 1, 0, -100000, 100000, 1);
		yStepper.value = 0;
		yStepper.name = "y_stepper";
		yStepper.scrollFactor.set();
		yStepper.cameras = [camHUD];

		yLabel = new FlxText(yStepper.x + yStepper.width + 2, yStepper.y - 2, 0, "Y", 10);
		yLabel.scrollFactor.set();
		yLabel.cameras = [camHUD];

		scaleStepper = new FlxUINumericStepper(20, yLabel.y + yLabel.height + 4 + 10, 0.05, 0, 0.1, 999, 2);
		scaleStepper.value = 0;
		scaleStepper.name = "scale_stepper_x";
		scaleStepper.scrollFactor.set();
		scaleStepper.cameras = [camHUD];

		scaleStepperY = new FlxUINumericStepper(scaleStepper.x + scaleStepper.width + 4, scaleStepper.y, 0.05, 1, 0.1, 999, 2);
		scaleStepperY.value = 1;
		scaleStepperY.name = "scale_stepper_y";
		scaleStepperY.scrollFactor.set();
		scaleStepperY.cameras = [camHUD];

		scaleLabel = new FlxText(scaleStepper.x, scaleStepper.y - 15, 0, "Scale X / Y", 10);
		scaleLabel.scrollFactor.set();
		scaleLabel.cameras = [camHUD];

		alphaStepper = new FlxUINumericStepper(scaleLabel.x + scaleLabel.width + 70, scaleStepper.y, 0.05, 0, 0, 1, 2);
		alphaStepper.value = 0;
		alphaStepper.name = "alpha_stepper";
		alphaStepper.scrollFactor.set();
		alphaStepper.cameras = [camHUD];

		alphaLabel = new FlxText(alphaStepper.x + alphaStepper.width + 2, alphaStepper.y - 2, 0, "Alpha", 10);
		alphaLabel.scrollFactor.set();
		alphaLabel.cameras = [camHUD];

		fileInput = new FlxInputText(20, scaleStepper.y + scaleStepper.height + 2, 70, "", 8);
		fileInput.scrollFactor.set();
		fileInput.cameras = [camHUD];

		fileLabel = new FlxText(fileInput.x + fileInput.width + 2, fileInput.y - 2, 0, "File Name", 10);
		fileLabel.scrollFactor.set();
		fileLabel.cameras = [camHUD];

		scrollStepperX = new FlxUINumericStepper(fileInput.x, fileInput.y + fileInput.height + 2 + 15, 0.05, 1, 0, 10, 2);
		scrollStepperX.value = 1;
		scrollStepperX.name = "scroll_stepper_x";
		scrollStepperX.scrollFactor.set();
		scrollStepperX.cameras = [camHUD];

		scrollStepperY = new FlxUINumericStepper(scrollStepperX.x + scrollStepperX.width + 4, scrollStepperX.y, 0.05, 1, 0, 10, 2);
		scrollStepperY.value = 1;
		scrollStepperY.name = "scroll_stepper_y";
		scrollStepperY.scrollFactor.set();
		scrollStepperY.cameras = [camHUD];

		scrollLabel = new FlxText(scrollStepperX.x, scrollStepperX.y - 12 - 6, 0, "Scroll Factor (X/Y)", 10);
		scrollLabel.scrollFactor.set();
		scrollLabel.cameras = [camHUD];

		blendDropDown = new FlxScrollableDropDownMenu(scrollStepperX.x, scrollStepperX.y + scrollStepperX.height + 2,
			FlxUIDropDownMenu.makeStrIdLabelArray(blendModes, true), function(blend:String) {
				try {
					@:privateAccess
					var blendMode = BlendMode.fromString(blendModes[Std.parseInt(blend)]);
					var sprite:Dynamic = objects[selectedObject - 1][1];
					if (!(sprite is Character)) {
						sprite.blend = blendMode;
						stageData.objects[selectedObject - 1].blend = blendMode;
					}
				} catch (e) {}
		});

		blendDropDown.selectedLabel = stageName;
		blendDropDown.scrollFactor.set();
		blendDropDown.cameras = [camHUD];

		blendLabel = new FlxText(blendDropDown.x + blendDropDown.width + 2, blendDropDown.y, 0, "Blend Mode", 10);
		blendLabel.scrollFactor.set();
		blendLabel.cameras = [camHUD];

		var characterData:Array<String> = CoolUtil.coolTextFile(Paths.txt('characterList'));

		var chars:Array<String> = ["bf", "gf", ""];

		for (item in characterData) {
			var characterDataVal:Array<String> = item.split(":");
			var charName:String = characterDataVal[0];
			chars.push(charName);
		}

		charDropDown = new FlxScrollableDropDownMenu(yLabel.x + yLabel.width + 2, yStepper.y - 2, FlxUIDropDownMenu.makeStrIdLabelArray(chars, true),
			function(character:String) {
				var daChar = chars[Std.parseInt(character)];

				if (selected == bfPos) {
					remove(bf);
					bf.kill();
					bf.destroy();

					bf = new Character(0, 0, daChar, true);

					if (bf.otherCharacters == null) {
						if (bf.coolTrail != null)
							add(bf.coolTrail);

						add(bf);
					} else {
						for (character in bf.otherCharacters) {
							if (character.coolTrail != null)
								add(character.coolTrail);

							add(character);
						}
					}

					stage.setCharOffsets(bf, gf, dad);
				} else if (selected == gfPos) {
					remove(gf);
					gf.kill();
					gf.destroy();

					gf = new Character(0, 0, daChar, false);

					if (gf.otherCharacters == null) {
						if (gf.coolTrail != null)
							add(gf.coolTrail);

						add(gf);
					} else {
						for (character in gf.otherCharacters) {
							if (character.coolTrail != null)
								add(character.coolTrail);

							add(character);
						}
					}

					stage.setCharOffsets(bf, gf, dad);
				} else if (selected == dadPos) {
					remove(dad);
					dad.kill();
					dad.destroy();

					dad = new Character(0, 0, daChar, false);

					if (dad.otherCharacters == null) {
						if (dad.coolTrail != null)
							add(dad.coolTrail);

						add(dad);
					} else {
						for (character in dad.otherCharacters) {
							if (character.coolTrail != null)
								add(character.coolTrail);

							add(character);
						}
					}

					stage.setCharOffsets(bf, gf, dad);
				}
			});

		charDropDown.scrollFactor.set();
		charDropDown.cameras = [camHUD];

		camFollow = new FlxObject(0, 0, 2, 2);
		camFollow.screenCenter();

		FlxG.camera.follow(camFollow);

		bfPos = new FlxSprite(stage.player_1_Point.x, stage.player_1_Point.y);
		bfPos.makeGraphic(32, 32, FlxColor.RED);
		bfPos.updateHitbox();

		gfPos = new FlxSprite(stage.gf_Point.x, stage.gf_Point.y);
		gfPos.makeGraphic(32, 32, FlxColor.RED);
		gfPos.updateHitbox();

		dadPos = new FlxSprite(stage.player_2_Point.x, stage.player_2_Point.y);
		dadPos.makeGraphic(32, 32, FlxColor.RED);
		dadPos.updateHitbox();

		reloadStage();
	}

	function updateCharPositionFromSelected():Void {
		if (selected == bfPos) {
			stage.player_1_Point.x = selected.x;
			stage.player_1_Point.y = selected.y;
			if (stageData != null)
				stageData.character_Positions[0] = [stage.player_1_Point.x, stage.player_1_Point.y];
		} else if (selected == gfPos) {
			stage.gf_Point.x = selected.x;
			stage.gf_Point.y = selected.y;
			if (stageData != null)
				stageData.character_Positions[2] = [stage.gf_Point.x, stage.gf_Point.y];
		} else if (selected == dadPos) {
			stage.player_2_Point.x = selected.x;
			stage.player_2_Point.y = selected.y;
			if (stageData != null)
				stageData.character_Positions[1] = [stage.player_2_Point.x, stage.player_2_Point.y];
		}
		stage.setCharOffsets(bf, gf, dad);
	}

	override function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>) {
		if (id == FlxUINumericStepper.CHANGE_EVENT && (sender is FlxUINumericStepper)) {
			var nums:FlxUINumericStepper = cast sender;
			var wname = nums.name;

			switch (wname) {
				case 'stage_zoom':
					stageData.camera_Zoom = nums.value;
				case 'x_stepper' | 'y_stepper':
					if (selectedObject != 0 || selected == bfPos || selected == dadPos || selected == gfPos) {
						if (wname == 'x_stepper') selected.x = nums.value;
						else selected.y = nums.value;

						if (selected == bfPos || selected == dadPos || selected == gfPos) {
							updateCharPositionFromSelected();
						} else {
							if (stageData != null)
								stageData.objects[selectedObject - 1].position = [selected.x, selected.y];
						}
					}
				case 'scale_stepper_x':
					if (selectedObject != 0 && !(selected == bfPos || selected == dadPos || selected == gfPos)) {
						var object:StageObject = stageData.objects[selectedObject - 1];
						var sprite:Dynamic = objects[selectedObject - 1][1];

						object.scale = nums.value;
						sprite.scale.x = nums.value;
						sprite.scale.y = (object.scaleY != null ? object.scaleY : object.scale);

						if (object.updateHitbox || object.updateHitbox == null)
							sprite.updateHitbox();
					}

				case 'scale_stepper_y':
					if (selectedObject != 0 && !(selected == bfPos || selected == dadPos || selected == gfPos)) {
						var object:StageObject = stageData.objects[selectedObject - 1];
						var sprite:Dynamic = objects[selectedObject - 1][1];

						object.scaleY = nums.value;
						sprite.scale.x = object.scale;
						sprite.scale.y = nums.value;

						if (object.updateHitbox || object.updateHitbox == null)
							sprite.updateHitbox();
					}
				case 'alpha_stepper':
					if (selectedObject != 0 || selected == bfPos || selected == dadPos || selected == gfPos) {
						if (!(selected == bfPos || selected == dadPos || selected == gfPos))
							Reflect.setProperty(stage.stageObjects[selectedObject - 1][1], "alpha", nums.value);
						else {
							if (selected == bfPos)
								bf.alpha = nums.value;
							else if (selected == gfPos)
								gf.alpha = nums.value;
							else if (selected == dadPos)
								dad.alpha = nums.value;
						}

						if (!(selected == bfPos || selected == dadPos || selected == gfPos))
							stageData.objects[selectedObject - 1].alpha = nums.value;
					}
				case 'scroll_stepper_x' | 'scroll_stepper_y':
					if (selectedObject != 0 && !(selected == bfPos || selected == dadPos || selected == gfPos)) {
						var obj:StageObject = stageData.objects[selectedObject - 1];
						var sprite:Dynamic = stage.stageObjects[selectedObject - 1][1];
						var isX = wname == 'scroll_stepper_x';

						obj.scroll_Factor = [
							isX ? nums.value : ((obj.scroll_Factor != null && obj.scroll_Factor.length > 0) ? obj.scroll_Factor[0] : nums.value),
							isX ? ((obj.scroll_Factor != null && obj.scroll_Factor.length > 1) ? obj.scroll_Factor[1] : nums.value) : nums.value
						];

						sprite.scrollFactor.set(obj.scroll_Factor[0], obj.scroll_Factor[1]);
					}
					else if (selected == bfPos || selected == dadPos || selected == gfPos) {
						if (stageData.character_Scrolls == null)
							stageData.character_Scrolls = [1, 1, 0.95];

						if (selected == bfPos) {
							stageData.character_Scrolls[0] = nums.value;
							stage.p1_Scroll = nums.value;
							bf.scrollFactor.set(nums.value, nums.value);
						} else if (selected == dadPos) {
							stageData.character_Scrolls[1] = nums.value;
							stage.p2_Scroll = nums.value;
							dad.scrollFactor.set(nums.value, nums.value);
						} else if (selected == gfPos) {
							stageData.character_Scrolls[2] = nums.value;
							stage.gf_Scroll = nums.value;
							gf.scrollFactor.set(nums.value, nums.value);
						}
					}
			}
		}
	}

	var prevFileName:String = "";

	override function update(elapsed:Float) {
		super.update(elapsed);

		if (selectedObject != 0) {
			if (prevFileName != fileInput.text) {
				stageData.objects[selectedObject - 1].file_Name = fileInput.text;

				if (selectedObject != 0 && !(selected == bfPos || selected == dadPos || selected == gfPos)) {
					var object:StageObject = stageData.objects[selectedObject - 1];
					var sprite:Dynamic = objects[selectedObject - 1][1];

					var scaleY:Float = (object.scaleY != null ? object.scaleY : object.scale);
					sprite.scale.set(object.scale, scaleY);
					if (object.updateHitbox || object.updateHitbox == null)
						sprite.updateHitbox();

					if (object.is_Animated) {
						sprite.frames = Paths.getSparrowAtlas(stageName + "/" + fileInput.text, "stages");

						for (Animation in object.animations) {
							var Anim_Name = Animation.name;
							@:Access
							if (Animation.name == "beatHit")
								stage.onBeatHit_Group.add(sprite);

							sprite.animation.addByPrefix(Anim_Name, Animation.animation_name, Animation.fps, Animation.looped);
						}

						if (object.start_Animation != "" && object.start_Animation != null && object.start_Animation != "null")
							sprite.animation.play(object.start_Animation);
					} else {
						sprite.loadGraphic(Paths.gpuBitmap(stageName + "/" + fileInput.text, "stages"));
					}

					if (object.updateHitbox || object.updateHitbox == null)
						sprite.updateHitbox();

						var scaleY:Float = (object.scaleY != null ? object.scaleY : object.scale);
						sprite.scale.set(object.scale, scaleY);
					if (object.updateHitbox || object.updateHitbox == null)
						sprite.updateHitbox();
				}
			}
		}

		prevFileName = fileInput.text;

		if (FlxG.mouse.overlaps(bfPos) && FlxG.mouse.pressed && !selectedThing) {
			selectedThing = true;
			selected = bfPos;

			xStepper.value = selected.x;
			yStepper.value = selected.y;
			alphaStepper.value = bf.alpha;
			scrollStepperX.value = bf.scrollFactor.x;
			scrollStepperY.value = bf.scrollFactor.y;
			selectedObject = 0;
		} else if (FlxG.mouse.overlaps(gfPos) && FlxG.mouse.pressed && !selectedThing) {
			selectedThing = true;
			selected = gfPos;

			xStepper.value = selected.x;
			yStepper.value = selected.y;
			alphaStepper.value = gf.alpha;
			scrollStepperX.value = gf.scrollFactor.x;
			scrollStepperY.value = gf.scrollFactor.y;

			selectedObject = 0;
		} else if (FlxG.mouse.overlaps(dadPos) && FlxG.mouse.pressed && !selectedThing) {
			selectedThing = true;
			selected = dadPos;

			xStepper.value = selected.x;
			yStepper.value = selected.y;
			alphaStepper.value = dad.alpha;
			scrollStepperX.value = dad.scrollFactor.x;
			scrollStepperY.value = dad.scrollFactor.y;

			selectedObject = 0;
		} else if (FlxG.mouse.pressed && !selectedThing) {
			for (spriteIndex in 0...stageObjectPos.length) {
				var sprite = stageObjectPos[spriteIndex];

				if (FlxG.mouse.overlaps(sprite) && FlxG.mouse.pressed && !selectedThing) {
					try {
						selectedObject = spriteIndex + 1;

						selectedThing = true;
						selected = sprite;

						xStepper.value = selected.x;
						yStepper.value = selected.y;

						var cool:FlxSprite = objects[spriteIndex][1];

						alphaStepper.value = cool.alpha;
						scrollStepperX.value = cool.scrollFactor.x;
						scrollStepperY.value = cool.scrollFactor.y;

						blendDropDown.selectedLabel = Std.string(cool.blend) == "null" ? "normal" : Std.string(cool.blend);
					} catch (e) {
						trace(e.details(), ERROR);
					}
				}
			}
		} else if (!FlxG.mouse.pressed)
			selectedThing = false;

		if (FlxG.mouse.pressed && selectedThing) {
			selected.x = FlxG.mouse.x - selected.frameWidth / 2;
			selected.y = FlxG.mouse.y - selected.frameHeight / 2;

			xStepper.value = selected.x;
			yStepper.value = selected.y;

			alphaStepper.value = selected.alpha;
			scrollStepperX.value = selected.scrollFactor.x;
			scrollStepperY.value = selected.scrollFactor.y;

			if (selected == bfPos) {
				stage.player_1_Point.x = selected.x;
				stage.player_1_Point.y = selected.y;

				if (stageData != null)
					stageData.character_Positions[0] = [stage.player_1_Point.x, stage.player_1_Point.y];

				stage.setCharOffsets(bf, gf, dad);
			} else if (selected == gfPos) {
				stage.gf_Point.x = selected.x;
				stage.gf_Point.y = selected.y;

				if (stageData != null)
					stageData.character_Positions[2] = [stage.gf_Point.x, stage.gf_Point.y];

				stage.setCharOffsets(bf, gf, dad);
			} else if (selected == dadPos) {
				stage.player_2_Point.x = selected.x;
				stage.player_2_Point.y = selected.y;

				if (stageData != null)
					stageData.character_Positions[1] = [stage.player_2_Point.x, stage.player_2_Point.y];

				stage.setCharOffsets(bf, gf, dad);
			} else {
				if (stageData != null) {
					stageData.objects[selectedObject - 1].position = [selected.x, selected.y];

					var coolMan:Dynamic = objects[selectedObject - 1][1];

					coolMan.setPosition(selected.x, selected.y);

					alphaStepper.value = coolMan.alpha;

					scaleStepper.value = stageData.objects[selectedObject - 1].scale;

					if (stageData.objects[selectedObject - 1].scaleY != null)
						scaleStepperY.value = stageData.objects[selectedObject - 1].scaleY;
					else
						scaleStepperY.value = stageData.objects[selectedObject - 1].scale;

					if (stageData.objects[selectedObject - 1].scroll_Factor != null) {
						scrollStepperX.value = stageData.objects[selectedObject - 1].scroll_Factor[0];
						scrollStepperY.value = stageData.objects[selectedObject - 1].scroll_Factor[1];
					} else {
						scrollStepperX.value = coolMan.scrollFactor.x;
						scrollStepperY.value = coolMan.scrollFactor.y;
					}
					fileInput.text = stageData.objects[selectedObject - 1].file_Name;
				}
			}
		}

		for (spriteIndex in 0...stageObjectPos.length) {
			var sprite = stageObjectPos[spriteIndex];

			if (stageData.objects[spriteIndex].scroll_Factor != null)
				sprite.scrollFactor.set(stageData.objects[spriteIndex].scroll_Factor[0], stageData.objects[spriteIndex].scroll_Factor[1]);
		}

		bfPos.setPosition(stage.player_1_Point.x, stage.player_1_Point.y);
		gfPos.setPosition(stage.gf_Point.x, stage.gf_Point.y);
		dadPos.setPosition(stage.player_2_Point.x, stage.player_2_Point.y);

		if (bf != null)
			bfPos.scrollFactor.set(bf.scrollFactor.x, bf.scrollFactor.y);

		if (gf != null)
			gfPos.scrollFactor.set(gf.scrollFactor.x, gf.scrollFactor.y);

		if (dad != null)
			dadPos.scrollFactor.set(dad.scrollFactor.x, dad.scrollFactor.y);

		var shiftThing:Int = FlxG.keys.pressed.SHIFT ? 5 : 1;

		if (!fileInput.hasFocus) {
			if (FlxG.keys.pressed.I || FlxG.keys.pressed.J || FlxG.keys.pressed.K || FlxG.keys.pressed.L) {
				if (FlxG.keys.pressed.I)
					camFollow.velocity.y = -90 * shiftThing;
				else if (FlxG.keys.pressed.K)
					camFollow.velocity.y = 90 * shiftThing;
				else
					camFollow.velocity.y = 0;

				if (FlxG.keys.pressed.J)
					camFollow.velocity.x = -90 * shiftThing;
				else if (FlxG.keys.pressed.L)
					camFollow.velocity.x = 90 * shiftThing;
				else
					camFollow.velocity.x = 0;
			} else {
				camFollow.velocity.set();
			}
		}

		if (FlxG.sound.music != null)
			Conductor.songPosition = FlxG.sound.music.time;

		// camera movement zoom
		if (!fileInput.hasFocus) {
			if (FlxG.keys.pressed.E && stageCam.zoom < 2)
				stageCam.zoom += elapsed * stageCam.zoom * (FlxG.keys.pressed.SHIFT ? 1 : 0.1);
			if (FlxG.keys.pressed.Q && stageCam.zoom >= 0.1)
				stageCam.zoom -= elapsed * stageCam.zoom * (FlxG.keys.pressed.SHIFT ? 1 : 0.1);
			if (FlxG.mouse.wheel != 0 && stageCam.zoom >= 0.1 && stageCam.zoom <= 2)
				stageCam.zoom += FlxG.keys.pressed.SHIFT ? FlxG.mouse.wheel / 100.0 : FlxG.mouse.wheel / 10.0;

			if (stageCam.zoom > 2)
				stageCam.zoom = 2;
			if (stageCam.zoom < 0.1)
				stageCam.zoom = 0.1;

			if (FlxG.keys.justPressed.ESCAPE)
				FlxG.switchState(() -> new ToolboxState("Categories", 0xFF00FF6A));
		}

		// zoom lock
		if (stageCam.zoom < 0.1)
			stageCam.zoom = 0.1;

		// da math
		zoom = FlxMath.roundDecimal(stageCam.zoom, 2);

		camZoom.text = 'Camera Zoom: $zoom\nIJKL to move camera\nE and Q to zoom\nSHIFT for faster camera\n';
		camZoom.x = FlxG.width - camZoom.width - 2;
		cameraPreview.scale.x = cameraPreview.scale.y = 1 / stageData.camera_Zoom;
		cameraPreview.x = (FlxG.width / 2) + stageCam.x - (cameraPreview.width / 2);
	}

	function removeCharacter(char:Character) {
		if (!char.isCharacterGroup) {
			if (char.coolTrail != null)
				remove(char.coolTrail);

			remove(char);
			add(char);
		} else {
			for (character in char.otherCharacters) {
				removeCharacter(character);
			}
		}
	}

	function danceCharacter(char:Character) {
		if (!char.isCharacterGroup)
			char.dance();
		else {
			for (character in char.otherCharacters) {
				character.dance();
			}
		}
	}

	function reloadStage() {
		for (pos in stageObjectPos) {
			remove(pos);
		}
		U.clearArray(objects);
		U.clearArray(stageObjectPos);
		selectedObject = 0;

		stage.clear();
		remove(stage);
		stage.infrontOfGFSprites.clear();
		remove(stage.infrontOfGFSprites);
		stage.foregroundSprites.clear();
		remove(stage.foregroundSprites);
		add(camFollow);

		stage = new StageGroup(stageName);
		add(stage);

		stageData = stage.stageData;

		stageZoom.value = stageData.camera_Zoom;

		stage.setCharOffsets(bf, gf, dad);

		removeCharacter(gf);

		add(stage.infrontOfGFSprites);

		removeCharacter(dad);
		removeCharacter(bf);

		add(stage.foregroundSprites);

		remove(cameraPreview);
		cameraPreview = new FlxSprite(0, 0);
		cameraPreview.loadGraphic(Paths.gpuBitmap("cam outline"));
		cameraPreview.antialiasing = false;
		cameraPreview.scrollFactor.set();
		cameraPreview.x = ((FlxG.width - 300) / 2) - (cameraPreview.width / 2);
		cameraPreview.alpha = 0.5;
		add(cameraPreview);

		add(bfPos);
		add(gfPos);
		add(dadPos);

		for (objectArray in stage.stageObjects) {
			objects.push([objectArray[0], objectArray[1]]);

			var sprite = objectArray[1];

			var pos = new FlxSprite(sprite.x, sprite.y);
			pos.makeGraphic(32, 32, FlxColor.RED);
			add(pos);

			stageObjectPos.push(pos);
		}

		add(UI_box);

		add(stageLabel);

		add(camZoom);
		add(jsonButton);
		add(stageZoom);
		add(zoomLabel);

		add(spriteLabel);

		add(xStepper);
		add(xLabel);

		add(yStepper);
		add(yLabel);

		add(scaleStepper);
		add(scaleLabel);
		add(scaleStepperY);

		add(alphaStepper);
		add(alphaLabel);

		add(fileInput);
		add(fileLabel);

		add(scrollStepperX);
		add(scrollStepperY);
		add(scrollLabel);

		add(blendDropDown);
		add(blendLabel);
		blendDropDown.selectedLabel = blendModes[0];

		add(charDropDown);
		add(stageDropdown);
	}

	override function beatHit() {
		super.beatHit();

		stage.beatHit();

		danceCharacter(bf);
		danceCharacter(dad);
		danceCharacter(gf);
	}

	function saveLevel() {
		var data:String = Json.stringify(stageData, null, "\t");

		if ((data != null) && (data.length > 0)) {
			_file = new FileReference();
			_file.addEventListener(Event.COMPLETE, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);

			_file.save(data.trim(), stageName + ".json");
		}
	}

	function onSaveComplete(_):Void {
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.notice("Successfully saved LEVEL DATA.");
	}

	/**
	 * Called when the save file dialog is cancelled.
	 */
	function onSaveCancel(_):Void {
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
	}

	/**
	 * Called if there is an error while saving the gameplay recording.
	 */
	function onSaveError(_):Void {
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.error("Problem saving Level data");
	}
}
