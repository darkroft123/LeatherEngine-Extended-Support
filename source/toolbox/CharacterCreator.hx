package toolbox;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.effects.FlxTrail;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUIButton;
import flixel.addons.ui.FlxUICheckBox;
import flixel.addons.ui.FlxUIDropDownMenu;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.FlxUISlider;
import flixel.addons.ui.FlxUITabMenu;
import flixel.group.FlxGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.text.FlxInputText;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import flixel.util.FlxDestroyUtil;
import game.Character;
import game.Conductor;
import game.StageGroup;
import haxe.Json;
import modding.CharacterConfig;
import openfl.display.BlendMode;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.net.FileReference;
import states.MainMenuState;
import states.MusicBeatState;
import states.PlayState;
import toolbox.util.EditorGuides;
import ui.FlxScrollableDropDownMenu;
import ui.HealthIcon;
#if DISCORD_ALLOWED
import utilities.DiscordClient;
#end


@:publicFields
class CharacterCreator extends MusicBeatState {
	/* ------------------------------------------------------------------ */
	/* ------------------------------------------------------------------ */
	var char:Character;
	var ghost:Character;

	var daAnim:String = 'spooky';
	var ghostCharacterName:String = 'spooky';

	var animList:Array<String> = [];
	var ghostAnimList:Array<String> = [];
	var curAnim:Int = 0;

	var charSlot:Int = 1;

	/* ------------------------------------------------------------------ */
	/* HUD / TEXTOS                                                        */
	/* ------------------------------------------------------------------ */
	var animText:FlxText;
	var moveText:FlxText;
	var animTextBG:FlxSprite;
	var moveTextBG:FlxSprite;
	var warningText:FlxText;

	var showFullHelp:Bool = false;
	var uiVisible:Bool = true;

	/* ------------------------------------------------------------------ */
	/* ------------------------------------------------------------------ */
	var camFollow:FlxObject;
	var gridCam:FlxCamera;
	var charCam:FlxCamera;
	var camHUD:FlxCamera;

	var gridBG:FlxSprite;

	/* ------------------------------------------------------------------ */
	/* MUNDO / STAGE                                                       */
	/* ------------------------------------------------------------------ */
	var world:FlxGroup;
	var guides:EditorGuides;

	var stage:StageGroup;
	var stages:Array<String>;
	var stageName:String = 'stage';
	var stageData:StageData;

	var objects:Array<Array<Dynamic>> = [];

	/* ------------------------------------------------------------------ */
	/* UI                                                                  */
	/* ------------------------------------------------------------------ */
	var tabs:FlxUITabMenu;
	var editor:FlxUITabMenu;

	var offsetButton:FlxUIButton;
	var configButton:FlxButton;

	var charDropDown:FlxScrollableDropDownMenu;
	var modDropDown:FlxScrollableDropDownMenu;
	var stageDropdown:FlxScrollableDropDownMenu;
	var slotDropDown:FlxScrollableDropDownMenu;
	var groupDropDown:FlxScrollableDropDownMenu;
	var groupMembers:Array<String> = [];
	var ghostDropDown:FlxScrollableDropDownMenu;
	var ghostAnimDropDown:FlxScrollableDropDownMenu;
	var animDropDown:FlxScrollableDropDownMenu;

	var tabGhost:FlxUI;

	var scaleStepper:FlxUINumericStepper;
	var animationFramerateStepper:FlxUINumericStepper;
	var animationLoopedCheckbox:FlxUICheckBox;
	var removeAnimation:FlxUIButton;
	var addAnimation:FlxUIButton;

	var globalOffsetXStepper:FlxUINumericStepper;
	var globalOffsetYStepper:FlxUINumericStepper;
	var cameraOffsetXStepper:FlxUINumericStepper;
	var cameraOffsetYStepper:FlxUINumericStepper;
	var singDurationStepper:FlxUINumericStepper;

	var ghostAlphaSlider:FlxUISlider;
	var ghostBlendCheck:FlxUICheckBox;
	var ghostFollowCheck:FlxUICheckBox;
	var ghostOriginalOffsetsCheck:FlxUICheckBox;
	var ghostInFrontCheck:FlxUICheckBox;
	var ghostEnabledCheck:FlxUICheckBox;

	var trail:FlxUICheckBox;
	var trailLength:FlxUINumericStepper;
	var trailDelay:FlxUINumericStepper;
	var trailAlpha:FlxUINumericStepper;
	var trailDiff:FlxUINumericStepper;

	var icon:HealthIcon;
	var iconName:FlxInputText;
	var healthBar:FlxSprite;

	var r:FlxInputText;
	var g:FlxInputText;
	var b:FlxInputText;

	var spriteSheetTextInput:FlxInputText;
	var animationInputName:FlxInputText;
	var animationInputAnimationName:FlxInputText;
	var animationIndicesInput:FlxInputText;

	var checkFlipX:FlxUICheckBox;
	var checkAntialiasing:FlxUICheckBox;
	var dancesCheck:FlxUICheckBox;
	var swapSingCheck:FlxUICheckBox;
	var deathCharInput:FlxInputText;
	var deathNameInput:FlxInputText;
	var iconFrameButton:FlxUIButton;
	var iconFrames:Array<String> = ["neutral", "lose", "win"];
	var iconFrame:Int = 0;

	var danceCheck:FlxUICheckBox;
	var cycleCheck:FlxUICheckBox;
	var legendCheck:FlxUICheckBox;

	var danceToBeat:Bool = false;
	var cycleAnimations:Bool = false;
	var showLegend:Bool = true;

	var legend:FlxTypedGroup<FlxSprite>;
	var offsetsFlipWhenPlayer:FlxUICheckBox;
	var offsetsFlipWhenEnemy:FlxUICheckBox;

	/* bloqueo de input mientras se escribe */
	var blockPressWhileTypingOn:Array<FlxInputText> = [];
	var blockPressWhileTypingOnStepper:Array<FlxUINumericStepper> = [];
	var blockPressWhileScrolling:Array<FlxScrollableDropDownMenu> = [];
	var blockInput:Bool = false;

	/* ------------------------------------------------------------------ */
	/* ESTADO DEL EDITOR                                                   */
	/* ------------------------------------------------------------------ */
	var characters:Map<String, Array<String>> = ["default" => ["bf", "gf"]];
	var modList:Array<String> = ["default"];
	var curCharList:Array<String>;

	var _file:FileReference;

	static var lastState:String = "OptionsMenu";

	static inline var TABS_X:Int = 900;
	static inline var TABS_Y:Int = 200;
	static inline var TABS_WIDTH:Int = 340;
	static inline var TABS_HEIGHT:Int = 500;

	static inline var EDITOR_X:Int = 20;
	static inline var EDITOR_Y:Int = 30;
	static inline var EDITOR_WIDTH:Int = 360;
	static inline var EDITOR_HEIGHT:Int = 290;

	/* ghost */
	var ghostEnabled:Bool = false;
	var ghostFollowsCharacter:Bool = true;
	var ghostShowsOriginalOffsets:Bool = true;
	var ghostInFront:Bool = false;

	/* offsets */
	var undoStack:Array<OffsetSnapshot> = [];
	var redoStack:Array<OffsetSnapshot> = [];
	var copiedOffset:Array<Float> = null;
	var unsavedChanges:Bool = false;

	var arrowTimers:Array<Float> = [0, 0, 0, 0];

	/* mouse */
	var draggingOffset:Bool = false;
	var draggingCamera:Bool = false;
	var lastMouseWorld:FlxPoint = FlxPoint.get();
	var dragAccum:FlxPoint = FlxPoint.get();

	var _midpoint:FlxPoint = FlxPoint.get();
	var _camTarget:FlxPoint = FlxPoint.get();

	var escapeTimer:Float = 0;
	var warningTimer:Float = 0;

	function new(daAnim:String = 'spooky', selectedStage:String) {
		super();
		this.daAnim = daAnim;
		this.ghostCharacterName = daAnim;

		stages = CoolUtil.coolTextFile(Paths.txt('stageList'));

		if (selectedStage != null)
			stageName = selectedStage;
	}

	/* ================================================================== */
	/* CREATE                                                              */
	/* ================================================================== */
	override function create() {
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Creating A Character", null, null, true);
		#end

		Main.display.visible = false;
		FlxG.mouse.visible = true;

		gridCam = new FlxCamera();
		charCam = new FlxCamera();
		charCam.bgColor.alpha = 0;
		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;

		FlxG.cameras.reset();
		FlxG.cameras.add(gridCam, false);
		FlxG.cameras.add(charCam, true);
		FlxG.cameras.add(camHUD, false);

		FlxG.cameras.setDefaultDrawTarget(charCam, true);
		FlxG.camera = charCam;

		if (FlxG.sound.music != null && FlxG.sound.music.active)
			FlxG.sound.music.stop();

		gridBG = FlxGridOverlay.create(10, 10);
		gridBG.scrollFactor.set(0, 0);
		gridBG.cameras = [gridCam];
		add(gridBG);

		loadCharacterList();

		world = new FlxGroup();
		add(world);

		char = makeCharacter(daAnim);

		ghost = makeCharacter("");
		ghost.visible = false;
		setupGhostLook();

		guides = new EditorGuides();

		camFollow = new FlxObject(0, 0, 2, 2);
		camFollow.screenCenter();
		add(camFollow);

		reloadStage();

		charCam.follow(camFollow);
		centerCameraOnCharacter(true);

		createHUD();
		createEditorUI();

		refreshAnimList(false);
		refreshGhostAnimList();
		refreshUIFromCharacter();
		playCurrentAnim();

		FlxG.sound.playMusic(Paths.music('breakfast'));
		Conductor.changeBPM(100);

		createLegend();

		super.create();
	}

	function loadCharacterList() {
		var characterData:Array<String> = CoolUtil.coolTextFile(Paths.txt('characterList'));

		for (item in characterData) {
			var characterDataVal:Array<String> = item.split(":");

			var charName:String = characterDataVal[0];
			var charMod:String = characterDataVal[1];

			var charsLmao:Array<String> = [];

			if (characters.exists(charMod))
				charsLmao = characters.get(charMod);
			else
				modList.push(charMod);

			charsLmao.push(charName);
			characters.set(charMod, charsLmao);
		}

		curCharList = characters.get("default");
	}

	function makeCharacter(name:String):Character {
		var newChar:Character = new Character(0, 0, name);
		newChar.debugMode = true;
		return newChar;
	}

	function setupGhostLook() {
		if (ghost == null)
			return;

		ghost.alpha = ghostAlphaSlider != null ? ghostAlphaSlider.value : 0.5;
		ghost.blend = (ghostBlendCheck != null && ghostBlendCheck.checked) ? BlendMode.ADD : BlendMode.NORMAL;

		if (ghost.coolTrail != null)
			ghost.coolTrail.visible = false;

		if (ghostAlphaSlider != null) {
			@:privateAccess
			ghostAlphaSlider._object = ghost;
		}
	}

	/* ================================================================== */
	/* HUD                                                                 */
	/* ================================================================== */
	function createHUD() {
		animTextBG = new FlxSprite(0, 0).makeGraphic(1, 1, FlxColor.WHITE);
		animTextBG.color = FlxColor.BLACK;
		animTextBG.alpha = 0.45;
		animTextBG.scrollFactor.set();
		animTextBG.cameras = [camHUD];
		animTextBG.active = false;
		add(animTextBG);

		animText = new FlxText(10, EDITOR_Y + EDITOR_HEIGHT + 14, 0, "", 15);
		animText.font = Paths.font("vcr.ttf");
		animText.scrollFactor.set();
		animText.color = FlxColor.WHITE;
		animText.borderColor = FlxColor.BLACK;
		animText.borderStyle = OUTLINE;
		animText.borderSize = 1;
		animText.cameras = [camHUD];
		animText.active = false;
		add(animText);

		moveTextBG = new FlxSprite(0, 0).makeGraphic(1, 1, FlxColor.WHITE);
		moveTextBG.color = FlxColor.BLACK;
		moveTextBG.alpha = 0.45;
		moveTextBG.scrollFactor.set();
		moveTextBG.cameras = [camHUD];
		moveTextBG.active = false;
		add(moveTextBG);

		moveText = new FlxText(4, 4, 0, "", 15);
		moveText.font = Paths.font("vcr.ttf");
		moveText.scrollFactor.set();
		moveText.color = FlxColor.WHITE;
		moveText.borderColor = FlxColor.BLACK;
		moveText.borderStyle = OUTLINE;
		moveText.borderSize = 1;
		moveText.alignment = RIGHT;
		moveText.cameras = [camHUD];
		moveText.active = false;
		add(moveText);

		warningText = new FlxText(0, FlxG.height - 42, FlxG.width, "", 18);
		warningText.font = Paths.font("vcr.ttf");
		warningText.alignment = CENTER;
		warningText.color = FlxColor.YELLOW;
		warningText.borderColor = FlxColor.BLACK;
		warningText.borderStyle = OUTLINE;
		warningText.borderSize = 2;
		warningText.scrollFactor.set();
		warningText.cameras = [camHUD];
		warningText.active = false;
		add(warningText);
	}

	function showWarning(message:String, time:Float = 2.5) {
		warningText.text = message;
		warningTimer = time;
	}

	/* ================================================================== */
	/* CAPAS                                                               */
	/* ================================================================== */
	function addCharacterToWorld(character:Character) {
		if (character == null)
			return;

		if (character.otherCharacters == null) {
			if (character.coolTrail != null)
				world.add(character.coolTrail);

			world.add(character);
		} else {
			for (subCharacter in character.otherCharacters) {
				if (subCharacter.coolTrail != null)
					world.add(subCharacter.coolTrail);

				world.add(subCharacter);
			}
		}
	}

	function rebuildWorld() {
		world.clear();

		if (stage != null)
			world.add(stage);

		if (!ghostInFront)
			addCharacterToWorld(ghost);

		addCharacterToWorld(char);

		if (stage != null)
			world.add(stage.infrontOfGFSprites);

		if (ghostInFront)
			addCharacterToWorld(ghost);

		if (stage != null)
			world.add(stage.foregroundSprites);

		if (guides != null)
			world.add(guides);
	}

	function reloadStage() {
		objects = [];

		if (stage != null) {
			world.remove(stage, true);
			stage.clear();
			stage.infrontOfGFSprites.clear();
			stage.foregroundSprites.clear();
		}

		stage = new StageGroup(stageName);
		stageData = stage.stageData;

		rebuildWorld();

		applyCharacterPosition();
		applyGhostPosition();
	}

	/* ================================================================== */
	/* ================================================================== */
	function applyCharacterPosition() {
		positionCharacter(char);
	}

	function applyGhostPosition() {
		positionCharacter(ghost);
	}

	function positionCharacter(character:Character) {
		if (character == null || stage == null)
			return;

		var scroll:Float = switch (charSlot) {
			case 0: stage.p1_Scroll;
			case 2: stage.gf_Scroll;
			default: stage.p2_Scroll;
		}

		stage.setPosition(character, getStagePoint(), scroll, 0, stage.useAbsolutePositions);
	}

	function visibleCharacter():Character {
		if (char == null)
			return null;

		var main:Character = char.getMainCharacter();

		if (main == char && char.isCharacterGroup && char.otherCharacters != null && char.otherCharacters.length > 0)
			main = char.otherCharacters[0];

		return main;
	}

	function getStagePoint():FlxPoint {
		if (stage == null)
			return FlxPoint.weak(0, 0);

		return switch (charSlot) {
			case 0: stage.player_1_Point;
			case 2: stage.gf_Point;
			default: stage.player_2_Point;
		}
	}

	function getCameraTarget():FlxPoint {
		var target:Character = visibleCharacter();

		if (target == null)
			target = char;

		target.getMidpoint(_midpoint);

		if (charSlot == 0) {
			if (stage != null) {
				_midpoint.x += stage.p1_Cam_Offset.x;
				_midpoint.y += stage.p1_Cam_Offset.y;
			}

			_camTarget.set(_midpoint.x - 100 + char.getMainCharacter().cameraOffset[0], _midpoint.y - 100 + char.getMainCharacter().cameraOffset[1]);
		} else {
			if (stage != null) {
				_midpoint.x += stage.p2_Cam_Offset.x;
				_midpoint.y += stage.p2_Cam_Offset.y;
			}

			_camTarget.set(_midpoint.x + 150 + char.getMainCharacter().cameraOffset[0], _midpoint.y - 100 + char.getMainCharacter().cameraOffset[1]);
		}

		return _camTarget;
	}

	function centerCameraOnCharacter(instant:Bool = false) {
		var target:Character = visibleCharacter();

		if (target == null)
			target = char;

		target.getMidpoint(_midpoint);
		camFollow.setPosition(_midpoint.x, _midpoint.y);

		if (instant)
			charCam.focusOn(FlxPoint.weak(camFollow.x, camFollow.y));
	}

	/* ================================================================== */
	/* UI                                                                  */
	/* ================================================================== */
	function createEditorUI() {
		createTabs();
		createEditorMenu();
	}

	function createEditorMenu() {
		editor = new FlxUITabMenu(null, [{name: "Editor", label: "Editor"}, {name: "Ghost", label: "Ghost"}], true);
		editor.resize(EDITOR_WIDTH, EDITOR_HEIGHT);
		editor.x = EDITOR_X;
		editor.y = EDITOR_Y;
		editor.scrollFactor.set();
		editor.cameras = [camHUD];
		add(editor);

		var tabEditor:FlxUI = new FlxUI(null, editor);
		tabEditor.name = "Editor";
		editor.addGroup(tabEditor);

		tabGhost = new FlxUI(null, editor);
		tabGhost.name = "Ghost";
		editor.addGroup(tabGhost);

		/* ---------------- editor tab ---------------- */
		charDropDown = new FlxScrollableDropDownMenu(10, 10, FlxUIDropDownMenu.makeStrIdLabelArray(curCharList, true), function(character:String) {
			var picked:String = curCharList[Std.parseInt(character)];

			if (picked != null && picked != char.curCharacter)
				loadNewCharacter(picked);
		});
		charDropDown.selectedLabel = daAnim;
		charDropDown.scrollFactor.set();

		modDropDown = new FlxScrollableDropDownMenu(10, 45, FlxUIDropDownMenu.makeStrIdLabelArray(modList, true), function(modID:String) {
			var mod:String = modList[Std.parseInt(modID)];

			if (!characters.exists(mod))
				return;

			curCharList = characters.get(mod);

			charDropDown.setData(FlxUIDropDownMenu.makeStrIdLabelArray(curCharList, true));
			charDropDown.selectedLabel = curCharList[0];

			ghostDropDown.setData(FlxUIDropDownMenu.makeStrIdLabelArray(curCharList, true));
			ghostDropDown.selectedLabel = curCharList[0];

			loadNewCharacter(curCharList[0]);
		});
		modDropDown.selectedLabel = "default";
		modDropDown.scrollFactor.set();

		stageDropdown = new FlxScrollableDropDownMenu(10, 80, FlxUIDropDownMenu.makeStrIdLabelArray(stages, true), function(stageID:String) {
			stageName = stages[Std.parseInt(stageID)];
			reloadStage();
			centerCameraOnCharacter();
		});
		stageDropdown.selectedLabel = stageName;
		stageDropdown.scrollFactor.set();

		var slotLabels:Array<String> = ["Player 1 (BF)", "Player 2 (Dad)", "Girlfriend"];

		slotDropDown = new FlxScrollableDropDownMenu(10, 115, FlxUIDropDownMenu.makeStrIdLabelArray(slotLabels, true), function(slotID:String) {
			charSlot = Std.parseInt(slotID);
			applyCharacterPosition();
			applyGhostPosition();
			centerCameraOnCharacter();
		});
		slotDropDown.selectedLabel = slotLabels[charSlot];
		slotDropDown.scrollFactor.set();

		groupDropDown = new FlxScrollableDropDownMenu(10, 155, FlxUIDropDownMenu.makeStrIdLabelArray(["- not a group -"], true), function(memberID:String) {
			var index:Null<Int> = Std.parseInt(memberID);

			if (index == null || index < 0 || index >= groupMembers.length)
				return;

			loadNewCharacter(groupMembers[index]);
		});
		groupDropDown.scrollFactor.set();

		blockPressWhileScrolling.push(groupDropDown);

		tabEditor.add(makeText(150, 15, 0, "Character"));
		tabEditor.add(makeText(150, 50, 0, "Mod"));
		tabEditor.add(makeText(150, 85, 0, "Stage"));
		tabEditor.add(makeText(150, 120, 0, "Position"));
		tabEditor.add(makeText(150, 160, 0, "Group Member"));

		tabEditor.add(groupDropDown);
		tabEditor.add(slotDropDown);
		tabEditor.add(stageDropdown);
		tabEditor.add(modDropDown);
		tabEditor.add(charDropDown);

		blockPressWhileScrolling.push(charDropDown);
		blockPressWhileScrolling.push(modDropDown);
		blockPressWhileScrolling.push(stageDropdown);
		blockPressWhileScrolling.push(slotDropDown);

		/* ---------------- ghost tab ---------------- */
		ghostDropDown = new FlxScrollableDropDownMenu(10, 10, FlxUIDropDownMenu.makeStrIdLabelArray(curCharList, true), function(character:String) {
			var picked:String = curCharList[Std.parseInt(character)];

			if (picked != null)
				loadNewGhost(picked);
		});
		ghostDropDown.selectedLabel = ghostCharacterName;
		ghostDropDown.scrollFactor.set();

		ghostAnimDropDown = new FlxScrollableDropDownMenu(10, 45,
			FlxUIDropDownMenu.makeStrIdLabelArray(ghostAnimList.length > 0 ? ghostAnimList : ["idle"], true), function(animName:String) {
				var picked:String = ghostAnimList[Std.parseInt(animName)];

				if (picked == null || ghost == null)
					return;

				ghostFollowsCharacter = false;
				ghostFollowCheck.checked = false;

				ghost.playAnim(picked, true);
				applyGhostPosition();
			});
		ghostAnimDropDown.scrollFactor.set();

		ghostEnabledCheck = new FlxUICheckBox(10, 80, null, null, "Ghost On (G)");
		styleCheckbox(ghostEnabledCheck);
		ghostEnabledCheck.checked = ghostEnabled;
		ghostEnabledCheck.callback = () -> {
			setGhostEnabled(ghostEnabledCheck.checked);
		}
		tabGhost.add(ghostEnabledCheck);

		ghostFollowCheck = new FlxUICheckBox(190, 80, null, null, "Follow Char");
		styleCheckbox(ghostFollowCheck);
		ghostFollowCheck.checked = ghostFollowsCharacter;
		ghostFollowCheck.callback = () -> {
			ghostFollowsCharacter = ghostFollowCheck.checked;

			if (ghostFollowsCharacter)
				syncGhostToCharacter();
		}
		tabGhost.add(ghostFollowCheck);

		ghostOriginalOffsetsCheck = new FlxUICheckBox(10, 102, null, null, "File Offsets");
		styleCheckbox(ghostOriginalOffsetsCheck);
		ghostOriginalOffsetsCheck.checked = ghostShowsOriginalOffsets;
		ghostOriginalOffsetsCheck.callback = () -> {
			ghostShowsOriginalOffsets = ghostOriginalOffsetsCheck.checked;
			reloadGhostOffsets();
		}
		tabGhost.add(ghostOriginalOffsetsCheck);

		ghostInFrontCheck = new FlxUICheckBox(190, 102, null, null, "In Front");
		styleCheckbox(ghostInFrontCheck);
		ghostInFrontCheck.callback = () -> {
			ghostInFront = ghostInFrontCheck.checked;
			rebuildWorld();
		}
		tabGhost.add(ghostInFrontCheck);

		ghostBlendCheck = new FlxUICheckBox(190, 124, null, null, "Highlight");
		styleCheckbox(ghostBlendCheck);
		ghostBlendCheck.callback = () -> {
			if (ghost != null)
				ghost.blend = ghostBlendCheck.checked ? BlendMode.ADD : BlendMode.NORMAL;
		}
		tabGhost.add(ghostBlendCheck);

		var ghostCopyButton:FlxUIButton = new FlxUIButton(190, 150, "Copy Character (H)", () -> {
			snapshotGhostFromCharacter();
		});
		ghostCopyButton.resize(155, ghostCopyButton.height);
		ghostCopyButton.antialiasing = false;
		ghostCopyButton.autoCenterLabel();
		tabGhost.add(ghostCopyButton);

		ghostAlphaSlider = new FlxUISlider(ghost, "alpha", 10, 155, 0, 1, 150);
		ghostAlphaSlider.nameLabel.text = "Ghost Alpha";
		ghostAlphaSlider.nameLabel.offset.y = -8;
		ghostAlphaSlider.valueLabel.color = FlxColor.BLACK;
		tabGhost.add(ghostAlphaSlider);

		tabGhost.add(makeText(150, 15, 0, "Ghost"));
		tabGhost.add(makeText(150, 50, 0, "Animation"));

		tabGhost.add(ghostAnimDropDown);
		tabGhost.add(ghostDropDown);

		blockPressWhileScrolling.push(ghostDropDown);
		blockPressWhileScrolling.push(ghostAnimDropDown);
	}

	function setGhostEnabled(value:Bool) {
		ghostEnabled = value;

		if (ghostEnabledCheck != null)
			ghostEnabledCheck.checked = value;

		if (value) {
			if (ghost == null || ghost.curCharacter == "")
				snapshotGhostFromCharacter();

			if (ghost != null)
				ghost.visible = true;
		} else {
			destroyCharacter(ghost);

			ghost = makeCharacter("");
			ghost.visible = false;

			setupGhostLook();
			rebuildWorld();
			refreshGhostAnimList();
		}
	}

	function createTabs() {
		tabs = new FlxUITabMenu(null, [
			{name: 'Character', label: 'Character'},
			{name: "Trail", label: "Trail"},
			{name: 'Animations', label: 'Animations'},
			{name: 'Offsets', label: 'Offsets'},
			{name: 'View', label: 'View'}
		], true);
		tabs.resize(TABS_WIDTH, TABS_HEIGHT);
		tabs.x = TABS_X;
		tabs.y = TABS_Y;
		tabs.scrollFactor.set();
		tabs.cameras = [camHUD];
		add(tabs);

		createCharacterTab();
		createTrailTab();
		createAnimationsTab();
		createOffsetsTab();
		createViewTab();
	}

	function createCharacterTab() {
		var tabCharacter:FlxUI = new FlxUI(null, tabs);
		tabCharacter.name = "Character";

		makeHeader(tabCharacter, 10, 8, "Sprite");

		spriteSheetTextInput = new FlxInputText(65, 32, 180, char.config.imagePath);
		spriteSheetTextInput.onTextChange.add((text, change) -> {
			if (text == null || text == "")
				return;

			char.config.imagePath = text;
			char.animation.destroyAnimations();
			char.loadCharacterConfiguration(char.config);
			char.updateHitbox();
			char.centerOrigin();

			refreshAnimList();
			playCurrentAnim();
			markUnsaved();
		});
		tabCharacter.add(spriteSheetTextInput);
		blockPressWhileTypingOn.push(spriteSheetTextInput);

		scaleStepper = new FlxUINumericStepper(65, 62, 0.1, getCharacterScale(), 0.05, 10, 2);
		scaleStepper.name = "scale";
		tabCharacter.add(scaleStepper);
		blockPressWhileTypingOnStepper.push(scaleStepper);

		singDurationStepper = new FlxUINumericStepper(225, 62, 0.1, (char.config.singDuration) ?? 4, 0.1, 30, 2);
		singDurationStepper.name = "singDuration";
		tabCharacter.add(singDurationStepper);
		blockPressWhileTypingOnStepper.push(singDurationStepper);

		makeHeader(tabCharacter, 10, 96, "Flags");

		checkAntialiasing = new FlxUICheckBox(10, 120, null, null, "Antialiasing");
		styleCheckbox(checkAntialiasing);
		checkAntialiasing.checked = char.antialiasing;
		checkAntialiasing.callback = () -> {
			char.config.antialiasing = char.antialiasing = checkAntialiasing.checked;

			if (ghost != null)
				ghost.antialiasing = char.antialiasing;

			markUnsaved();
		}
		tabCharacter.add(checkAntialiasing);

		checkFlipX = new FlxUICheckBox(180, 120, null, null, "Flip X");
		styleCheckbox(checkFlipX);
		checkFlipX.checked = char.config.defaultFlipX;
		checkFlipX.callback = () -> {
			char.config.defaultFlipX = checkFlipX.checked;
			char.flipX = char.isPlayer ? !checkFlipX.checked : checkFlipX.checked;
			applyCharacterPosition();
			markUnsaved();
		}
		tabCharacter.add(checkFlipX);

		dancesCheck = new FlxUICheckBox(10, 144, null, null, "Dance L/R");
		styleCheckbox(dancesCheck);
		dancesCheck.checked = char.config.dancesLeftAndRight;
		dancesCheck.callback = () -> {
			char.config.dancesLeftAndRight = char.dancesLeftAndRight = dancesCheck.checked;
			markUnsaved();
		}
		tabCharacter.add(dancesCheck);

		swapSingCheck = new FlxUICheckBox(180, 144, null, null, "Swap Sing Dirs");
		styleCheckbox(swapSingCheck);
		swapSingCheck.checked = char.swapLeftAndRightSingPlayer;
		swapSingCheck.callback = () -> {
			char.config.swapDirectionSingWhenPlayer = char.swapLeftAndRightSingPlayer = swapSingCheck.checked;
			markUnsaved();
		}
		tabCharacter.add(swapSingCheck);

		deathCharInput = new FlxInputText(95, 172, 110, char.config.deathCharacter ?? "");
		deathCharInput.onFocusChange.add((focused) -> {
			if (!focused) {
				char.config.deathCharacter = deathCharInput.text == "" ? null : deathCharInput.text;
				markUnsaved();
			}
		});
		tabCharacter.add(deathCharInput);
		blockPressWhileTypingOn.push(deathCharInput);

		deathNameInput = new FlxInputText(215, 172, 110, char.config.deathCharacterName ?? "");
		deathNameInput.onFocusChange.add((focused) -> {
			if (!focused) {
				char.config.deathCharacterName = deathNameInput.text == "" ? null : deathNameInput.text;
				markUnsaved();
			}
		});
		tabCharacter.add(deathNameInput);
		blockPressWhileTypingOn.push(deathNameInput);

		makeHeader(tabCharacter, 10, 200, "Position       Camera");

		globalOffsetXStepper = new FlxUINumericStepper(10, 226, 1, char.positioningOffset[0], -9999, 9999);
		globalOffsetXStepper.name = "globalOffsetX";
		tabCharacter.add(globalOffsetXStepper);

		globalOffsetYStepper = new FlxUINumericStepper(85, 226, 1, char.positioningOffset[1], -9999, 9999);
		globalOffsetYStepper.name = "globalOffsetY";
		tabCharacter.add(globalOffsetYStepper);

		cameraOffsetXStepper = new FlxUINumericStepper(180, 226, 1, char.cameraOffset[0], -9999, 9999);
		cameraOffsetXStepper.name = "cameraOffsetX";
		tabCharacter.add(cameraOffsetXStepper);

		cameraOffsetYStepper = new FlxUINumericStepper(255, 226, 1, char.cameraOffset[1], -9999, 9999);
		cameraOffsetYStepper.name = "cameraOffsetY";
		tabCharacter.add(cameraOffsetYStepper);

		blockPressWhileTypingOnStepper.push(globalOffsetXStepper);
		blockPressWhileTypingOnStepper.push(globalOffsetYStepper);
		blockPressWhileTypingOnStepper.push(cameraOffsetXStepper);
		blockPressWhileTypingOnStepper.push(cameraOffsetYStepper);

		makeHeader(tabCharacter, 10, 258, "Health Icon");

		iconName = new FlxInputText(65, 284, 120, char.icon ?? char.curCharacter);
		iconName.onTextChange.add((text, change) -> {
			char.icon = text;
			char.config.healthIcon = text;

			icon.setupIcon(text);
			icon.scale.set(icon.scale.x * 0.47, icon.scale.y * 0.47);
			icon.updateHitbox();

			iconFrame = 0;
			markUnsaved();
		});
		tabCharacter.add(iconName);
		blockPressWhileTypingOn.push(iconName);

		iconFrameButton = new FlxUIButton(200, 282, "Frame: neutral", () -> cycleIconFrame());
		iconFrameButton.resize(125, iconFrameButton.height);
		iconFrameButton.autoCenterLabel();
		iconFrameButton.antialiasing = false;
		tabCharacter.add(iconFrameButton);

		if (char.config.barColor == null)
			char.config.barColor = [255, 0, 0];

		r = new FlxInputText(65, 314, 26, Std.string(char.config.barColor[0]));
		r.onTextChange.add((text, change) -> setBarColor(0, text));
		r.onFocusChange.add((focused) -> {
			if (!focused)
				r.text = Std.string(clampColor(r.text));
		});
		tabCharacter.add(r);

		g = new FlxInputText(r.x + 30, r.y, 26, Std.string(char.config.barColor[1]));
		g.onTextChange.add((text, change) -> setBarColor(1, text));
		g.onFocusChange.add((focused) -> {
			if (!focused)
				g.text = Std.string(clampColor(g.text));
		});
		tabCharacter.add(g);

		b = new FlxInputText(g.x + 30, g.y, 26, Std.string(char.config.barColor[2]));
		b.onTextChange.add((text, change) -> setBarColor(2, text));
		b.onFocusChange.add((focused) -> {
			if (!focused)
				b.text = Std.string(clampColor(b.text));
		});
		tabCharacter.add(b);

		blockPressWhileTypingOn.push(r);
		blockPressWhileTypingOn.push(g);
		blockPressWhileTypingOn.push(b);

		var match:FlxUIButton = new FlxUIButton(200, 312, "Dominant Color", () -> {
			var color:FlxColor = CoolUtil.dominantColor(icon);

			r.text = Std.string(color.red);
			g.text = Std.string(color.green);
			b.text = Std.string(color.blue);

			r.onTextChange.dispatch(r.text, INPUT_ACTION);
			g.onTextChange.dispatch(g.text, INPUT_ACTION);
			b.onTextChange.dispatch(b.text, INPUT_ACTION);
		});
		match.resize(125, match.height);
		match.autoCenterLabel();
		match.antialiasing = false;
		tabCharacter.add(match);

		healthBar = new FlxSprite(10, 368).makeGraphic(TABS_WIDTH - 30, 9, FlxColor.WHITE);
		healthBar.antialiasing = false;
		healthBar.color = char.barColor;
		tabCharacter.add(healthBar);

		icon = new HealthIcon(char.icon);
		icon.scale.set(icon.scale.x * 0.47, icon.scale.y * 0.47);
		icon.updateHitbox();
		icon.x = 10 - icon.width / 2;
		icon.y = 368 - (icon.height / 2);
		tabCharacter.add(icon);

		configButton = new FlxButton(190, 415, "Save Character", function() {
			saveConfig();
		});
		configButton.scrollFactor.set();
		tabCharacter.add(configButton);

		tabCharacter.add(makeText(10, 36, 0, "Image"));
		tabCharacter.add(makeText(10, 66, 0, "Scale"));
		tabCharacter.add(makeText(160, 66, 0, "Sing Dur"));
		tabCharacter.add(makeText(10, 176, 0, "Death char"));
		tabCharacter.add(makeText(10, 288, 0, "Icon"));
		tabCharacter.add(makeText(10, 318, 0, "Bar RGB"));

		tabs.addGroup(tabCharacter);
	}

	function cycleIconFrame() {
		iconFrame = (iconFrame + 1) % iconFrames.length;

		if (icon.animation.getByName(iconFrames[iconFrame]) != null)
			icon.animation.play(iconFrames[iconFrame]);

		iconFrameButton.label.text = "Frame: " + iconFrames[iconFrame];
	}

	function createTrailTab() {
		var tabTrail:FlxUI = new FlxUI(null, tabs);
		tabTrail.name = "Trail";

		makeHeader(tabTrail, 10, 8, "Trail");

		trail = new FlxUICheckBox(10, 34, null, null, "Has Trail");
		styleCheckbox(trail);
		trail.checked = char.config.trail == true;

		if (char.coolTrail != null)
			char.coolTrail.visible = trail.checked;

		trail.callback = () -> {
			char.config.trail = trail.checked;

			if (char.coolTrail != null)
				char.coolTrail.visible = trail.checked;

			markUnsaved();
		}
		tabTrail.add(trail);

		trailLength = new FlxUINumericStepper(10, 68, 1, (char.config.trailLength ?? 10), 1, 100);
		trailLength.name = "trailLength";
		tabTrail.add(trailLength);

		trailDelay = new FlxUINumericStepper(10, 98, 1, (char.config.trailDelay ?? 3), 0, 100);
		trailDelay.name = "trailDelay";
		tabTrail.add(trailDelay);

		trailAlpha = new FlxUINumericStepper(10, 128, 0.1, (char.config.trailStalpha ?? 0.4), 0.1, 1, 2);
		trailAlpha.name = "trailAlpha";
		tabTrail.add(trailAlpha);

		trailDiff = new FlxUINumericStepper(10, 158, 0.01, (char.config.trailDiff ?? 0.05), 0.01, 100, 2);
		trailDiff.name = "trailDiff";
		tabTrail.add(trailDiff);

		blockPressWhileTypingOnStepper.push(trailLength);
		blockPressWhileTypingOnStepper.push(trailDelay);
		blockPressWhileTypingOnStepper.push(trailAlpha);
		blockPressWhileTypingOnStepper.push(trailDiff);

		tabTrail.add(makeText(trailLength.x + trailLength.width + 6, trailLength.y, 0, "Trail Length"));
		tabTrail.add(makeText(trailDelay.x + trailDelay.width + 6, trailDelay.y, 0, "Trail Delay"));
		tabTrail.add(makeText(trailAlpha.x + trailAlpha.width + 6, trailAlpha.y, 0, "Trail Alpha"));
		tabTrail.add(makeText(trailDiff.x + trailDiff.width + 6, trailDiff.y, 0, "Trail Difference"));

		tabTrail.add(makeText(10, 200, TABS_WIDTH - 30,
			"The trail is that ghosting effect some characters leave behind, like Senpai in Thorns.", 10));

		tabs.addGroup(tabTrail);
	}

	function createAnimationsTab() {
		var tabAnimations:FlxUI = new FlxUI(null, tabs);
		tabAnimations.name = "Animations";

		makeHeader(tabAnimations, 10, 8, "Current Animation");

		animationInputName = new FlxInputText(10, 114, 180);
		makeHeader(tabAnimations, 10, 72, "New / Edit");
		tabAnimations.add(makeText(10, 98, 200, "Name (idle, singLEFT...)"));
		tabAnimations.add(animationInputName);

		animationInputAnimationName = new FlxInputText(10, 158, 180);
		tabAnimations.add(makeText(10, 142, 200, "Spritesheet Prefix"));
		tabAnimations.add(animationInputAnimationName);

		animationIndicesInput = new FlxInputText(10, 202, 180);
		tabAnimations.add(makeText(10, 186, 200, "Indices (optional: 0,1,2)"));
		tabAnimations.add(animationIndicesInput);

		blockPressWhileTypingOn.push(animationInputName);
		blockPressWhileTypingOn.push(animationInputAnimationName);
		blockPressWhileTypingOn.push(animationIndicesInput);

		animationFramerateStepper = new FlxUINumericStepper(10, 234, 1, 24, 1, 240);
		animationFramerateStepper.name = "animationFramerate";
		tabAnimations.add(animationFramerateStepper);
		blockPressWhileTypingOnStepper.push(animationFramerateStepper);
		tabAnimations.add(makeText(animationFramerateStepper.x + animationFramerateStepper.width + 6, animationFramerateStepper.y, 0, "FPS"));

		tabAnimations.add(makeText(10, 372, TABS_WIDTH - 30,
			"W and S change the animation, SPACE replays it, P pauses and , . step frame by frame.", 10));

		animationLoopedCheckbox = new FlxUICheckBox(150, 232, null, null, "Loop");
		styleCheckbox(animationLoopedCheckbox);
		tabAnimations.add(animationLoopedCheckbox);

		addAnimation = new FlxUIButton(10, 270, "Add / Update Animation", () -> {
			addOrUpdateAnimation();
		});
		addAnimation.resize(310, addAnimation.height);
		addAnimation.antialiasing = false;
		addAnimation.autoCenterLabel();
		tabAnimations.add(addAnimation);

		removeAnimation = new FlxUIButton(10, 302, "Remove Animation", () -> {
			removeCurrentAnimation();
		});
		removeAnimation.resize(310, removeAnimation.height);
		removeAnimation.antialiasing = false;
		removeAnimation.autoCenterLabel();
		tabAnimations.add(removeAnimation);

		var fillButton:FlxUIButton = new FlxUIButton(10, 334, "Load Current Animation Data", () -> {
			fillAnimationInputs();
		});
		fillButton.resize(310, fillButton.height);
		fillButton.antialiasing = false;
		fillButton.autoCenterLabel();
		tabAnimations.add(fillButton);

		animDropDown = new FlxScrollableDropDownMenu(10, 36, FlxUIDropDownMenu.makeStrIdLabelArray(animList.length > 0 ? animList : ["idle"], true),
			function(animName:String) {
				var index:Null<Int> = Std.parseInt(animName);

				if (index != null && index >= 0 && index < animList.length) {
					curAnim = index;
					playCurrentAnim();
					fillAnimationInputs();
				}
			});
		animDropDown.scrollFactor.set();
		blockPressWhileScrolling.push(animDropDown);
		tabAnimations.add(animDropDown);

		tabs.addGroup(tabAnimations);
	}

	function createOffsetsTab() {
		var tabOffsets:FlxUI = new FlxUI(null, tabs);
		tabOffsets.name = "Offsets";

		makeHeader(tabOffsets, 10, 8, "Flipping");

		offsetsFlipWhenPlayer = new FlxUICheckBox(10, 34, null, null, "Flip On Player");
		styleCheckbox(offsetsFlipWhenPlayer);
		offsetsFlipWhenPlayer.checked = char.offsetsFlipWhenPlayer;
		offsetsFlipWhenPlayer.callback = () -> {
			var wasFlipped:Bool = offsetsAreFlipped();
			char.offsetsFlipWhenPlayer = char.config.offsetsFlipWhenPlayer = offsetsFlipWhenPlayer.checked;
			handleFlipChange(wasFlipped);
		}
		tabOffsets.add(offsetsFlipWhenPlayer);

		offsetsFlipWhenEnemy = new FlxUICheckBox(180, 34, null, null, "Flip On Enemy");
		styleCheckbox(offsetsFlipWhenEnemy);
		offsetsFlipWhenEnemy.checked = char.offsetsFlipWhenEnemy;
		offsetsFlipWhenEnemy.callback = () -> {
			var wasFlipped:Bool = offsetsAreFlipped();
			char.offsetsFlipWhenEnemy = char.config.offsetsFlipWhenEnemy = offsetsFlipWhenEnemy.checked;
			handleFlipChange(wasFlipped);
		}
		tabOffsets.add(offsetsFlipWhenEnemy);

		var resetButton:FlxUIButton = new FlxUIButton(10, 96, "Reset (R)", () -> {
			pushUndo();
			setCurrentOffset(0, 0);
		});
		resetButton.resize(150, resetButton.height);
		resetButton.antialiasing = false;
		resetButton.autoCenterLabel();
		tabOffsets.add(resetButton);

		var copyIdleButton:FlxUIButton = new FlxUIButton(170, 96, "Copy From Idle", () -> {
			copyIdleOffset();
		});
		copyIdleButton.resize(150, copyIdleButton.height);
		copyIdleButton.antialiasing = false;
		copyIdleButton.autoCenterLabel();
		tabOffsets.add(copyIdleButton);

		var applyAllButton:FlxUIButton = new FlxUIButton(10, 128, "Apply This Offset To All", () -> {
			applyOffsetToAll();
		});
		applyAllButton.resize(310, applyAllButton.height);
		applyAllButton.antialiasing = false;
		applyAllButton.autoCenterLabel();
		tabOffsets.add(applyAllButton);

		var autoAlignButton:FlxUIButton = new FlxUIButton(10, 160, "Auto Align To Idle (beta)", () -> {
			autoAlignToIdle();
		});
		autoAlignButton.resize(310, autoAlignButton.height);
		autoAlignButton.antialiasing = false;
		autoAlignButton.autoCenterLabel();
		tabOffsets.add(autoAlignButton);

		var undoButton:FlxUIButton = new FlxUIButton(10, 192, "Undo", () -> {
			undo();
		});
		undoButton.resize(150, undoButton.height);
		undoButton.antialiasing = false;
		undoButton.autoCenterLabel();
		tabOffsets.add(undoButton);

		var redoButton:FlxUIButton = new FlxUIButton(170, 192, "Redo", () -> {
			redo();
		});
		redoButton.resize(150, redoButton.height);
		redoButton.antialiasing = false;
		redoButton.autoCenterLabel();
		tabOffsets.add(redoButton);

		var reloadButton:FlxUIButton = new FlxUIButton(10, 224, "Reload Offsets From File", () -> {
			pushUndo();
			char.animOffsets.clear();
			char.loadOffsetFile(char.curCharacter);
			refreshAnimList();
			playCurrentAnim();
		});
		reloadButton.resize(310, reloadButton.height);
		reloadButton.antialiasing = false;
		reloadButton.autoCenterLabel();
		tabOffsets.add(reloadButton);

		offsetButton = new FlxUIButton(10, 258, "Save Offsets", function() {
			saveOffsets();
		});
		offsetButton.resize(310, offsetButton.height);
		offsetButton.antialiasing = false;
		offsetButton.autoCenterLabel();
		tabOffsets.add(offsetButton);

		makeHeader(tabOffsets, 10, 70, "Tools");
		makeHeader(tabOffsets, 10, 300, "How To Move Them");

		tabOffsets.add(makeText(10, 326, TABS_WIDTH - 30,
			"Arrows: move the offset\nSHIFT: x10\nCTRL: every animation\nALT: move the character position\nLeft click on the character to drag it", 11));

		tabs.addGroup(tabOffsets);
	}

	function createViewTab() {
		var tabView:FlxUI = new FlxUI(null, tabs);
		tabView.name = "View";

		makeHeader(tabView, 10, 8, "Guides");

		var loadBoxCheck:FlxUICheckBox = new FlxUICheckBox(10, 32, null, null, "Load Box");
		styleCheckbox(loadBoxCheck);
		loadBoxCheck.checked = guides.showLoadBox;
		loadBoxCheck.callback = () -> guides.showLoadBox = loadBoxCheck.checked;
		tabView.add(loadBoxCheck);

		var spriteBoxCheck:FlxUICheckBox = new FlxUICheckBox(180, 32, null, null, "Sprite Box");
		styleCheckbox(spriteBoxCheck);
		spriteBoxCheck.checked = guides.showSpriteBox;
		spriteBoxCheck.callback = () -> guides.showSpriteBox = spriteBoxCheck.checked;
		tabView.add(spriteBoxCheck);

		var anchorCheck:FlxUICheckBox = new FlxUICheckBox(10, 56, null, null, "Load Point");
		styleCheckbox(anchorCheck);
		anchorCheck.checked = guides.showAnchor;
		anchorCheck.callback = () -> guides.showAnchor = anchorCheck.checked;
		tabView.add(anchorCheck);

		var offsetLinkCheck:FlxUICheckBox = new FlxUICheckBox(180, 56, null, null, "Offset Line");
		styleCheckbox(offsetLinkCheck);
		offsetLinkCheck.checked = guides.showOffsetLink;
		offsetLinkCheck.callback = () -> guides.showOffsetLink = offsetLinkCheck.checked;
		tabView.add(offsetLinkCheck);

		var cameraCheck:FlxUICheckBox = new FlxUICheckBox(10, 80, null, null, "Game Camera");
		styleCheckbox(cameraCheck);
		cameraCheck.checked = guides.showCamera;
		cameraCheck.callback = () -> guides.showCamera = cameraCheck.checked;
		tabView.add(cameraCheck);

		var ghostBoxCheck:FlxUICheckBox = new FlxUICheckBox(180, 80, null, null, "Ghost Box");
		styleCheckbox(ghostBoxCheck);
		ghostBoxCheck.checked = guides.showGhostBox;
		ghostBoxCheck.callback = () -> guides.showGhostBox = ghostBoxCheck.checked;
		tabView.add(ghostBoxCheck);

		var labelsCheck:FlxUICheckBox = new FlxUICheckBox(10, 104, null, null, "Guide Labels");
		styleCheckbox(labelsCheck);
		labelsCheck.checked = guides.showLabels;
		labelsCheck.callback = () -> guides.showLabels = labelsCheck.checked;
		tabView.add(labelsCheck);

		var gridCheck:FlxUICheckBox = new FlxUICheckBox(180, 104, null, null, "Grid");
		styleCheckbox(gridCheck);
		gridCheck.checked = true;
		gridCheck.callback = () -> gridBG.visible = gridCheck.checked;
		tabView.add(gridCheck);

		var stageCheck:FlxUICheckBox = new FlxUICheckBox(10, 128, null, null, "Stage (Z)");
		styleCheckbox(stageCheck);
		stageCheck.checked = true;
		stageCheck.callback = () -> setStageVisible(stageCheck.checked);
		tabView.add(stageCheck);

		legendCheck = new FlxUICheckBox(180, 128, null, null, "Legend");
		styleCheckbox(legendCheck);
		legendCheck.checked = true;
		legendCheck.callback = () -> showLegend = legendCheck.checked;
		tabView.add(legendCheck);

		makeHeader(tabView, 10, 160, "Preview");

		danceCheck = new FlxUICheckBox(10, 184, null, null, "Dance On Beat");
		styleCheckbox(danceCheck);
		danceCheck.callback = () -> {
			danceToBeat = danceCheck.checked;

			if (!danceToBeat)
				playCurrentAnim();
		}
		tabView.add(danceCheck);

		cycleCheck = new FlxUICheckBox(10, 208, null, null, "Cycle Anims");
		styleCheckbox(cycleCheck);
		cycleCheck.callback = () -> cycleAnimations = cycleCheck.checked;
		tabView.add(cycleCheck);

		tabView.add(makeText(10, 234, TABS_WIDTH - 30,
			"Dance plays the idle on every beat so you can check how it loops. Cycle walks through every animation, one per beat.", 10));

		makeHeader(tabView, 10, 290, "Shortcuts");

		tabView.add(makeText(10, 314, TABS_WIDTH - 30,
			"F1: full controls\nF2: turn the guides on and off\nF3: hide the interface\nHOME: center the camera\nG: ghost   H: ghost = current character", 11));

		tabs.addGroup(tabView);
	}

	/* ================================================================== */
	/* LEYENDA                                                             */
	/* ================================================================== */

	function createLegend() {
		legend = new FlxTypedGroup<FlxSprite>();

		var entries:Array<Array<Dynamic>> = [
			[EditorGuides.ANCHOR_COLOR, "where the stage drops the character"],
			[EditorGuides.LOAD_COLOR, "the box the game positions"],
			[EditorGuides.SPRITE_COLOR, "where the sprite really draws"],
			[EditorGuides.OFFSET_COLOR, "the offset between both"],
			[EditorGuides.CAMERA_COLOR, "what the camera will see"],
			[EditorGuides.GHOST_COLOR, "ghost box"]
		];

		var legendX:Float = EDITOR_X + EDITOR_WIDTH + 40;
		var legendY:Float = FlxG.height - 16 - (entries.length * 19);

		var background:FlxSprite = new FlxSprite(legendX - 8, legendY - 32).makeGraphic(1, 1, FlxColor.WHITE);
		background.color = FlxColor.BLACK;
		background.alpha = 0.45;
		background.origin.set(0, 0);
		background.offset.set(0, 0);
		background.scale.set(300, (entries.length * 19) + 40);
		background.cameras = [camHUD];
		background.scrollFactor.set();
		background.active = false;
		legend.add(background);

		var title:FlxText = makeText(legendX, legendY - 26, 0, "WHAT AM I LOOKING AT", 12);
		title.color = 0xFFFFE23B;
		title.cameras = [camHUD];
		title.scrollFactor.set();
		title.active = false;
		legend.add(title);

		for (i in 0...entries.length) {
			var box:FlxSprite = new FlxSprite(legendX, legendY + (i * 19) + 1).makeGraphic(13, 13, FlxColor.WHITE);
			box.color = entries[i][0];
			box.cameras = [camHUD];
			box.scrollFactor.set();
			box.active = false;
			legend.add(box);

			var label:FlxText = makeText(legendX + 20, legendY + (i * 19), 0, entries[i][1], 12);
			label.cameras = [camHUD];
			label.scrollFactor.set();
			label.active = false;
			legend.add(label);
		}

		add(legend);
	}

	/* ================================================================== */
	/* BEAT                                                                */
	/* ================================================================== */
	override function beatHit() {
		super.beatHit();

		if (blockInput)
			return;

		if (cycleAnimations && animList.length > 0 && curBeat % 2 == 0) {
			curAnim++;

			if (curAnim >= animList.length)
				curAnim = 0;

			playCurrentAnim();
			updateAnimDropDown();
			return;
		}

		if (danceToBeat) {
			char.dance();

			if (ghost != null && ghostEnabled && ghostFollowsCharacter)
				ghost.dance();
		}
	}

	/* ================================================================== */
	/* HELPERS DE UI                                                       */
	/* ================================================================== */
	function makeText(x:Float, y:Float, width:Float, text:String, size:Int = 11):FlxText {
		var label:FlxText = new FlxText(x, y, width, text, size);
		label.setFormat(Paths.font("vcr.ttf"), size, FlxColor.WHITE, LEFT);
		return label;
	}

	function makeHeader(tab:FlxUI, x:Float, y:Float, text:String) {
		var header:FlxText = makeText(x, y, 0, text.toUpperCase(), 12);
		header.color = 0xFFFFE23B;
		tab.add(header);

		var line:FlxSprite = new FlxSprite(x, y + 18).makeGraphic(1, 1, FlxColor.WHITE);
		line.color = 0xFFFFE23B;
		line.alpha = 0.35;
		line.origin.set(0, 0);
		line.offset.set(0, 0);
		line.scale.set(TABS_WIDTH - 30, 1);
		line.active = false;
		tab.add(line);
	}

	function styleCheckbox(check:FlxUICheckBox):FlxUICheckBox {
		check.button.label.color = FlxColor.WHITE;
		check.button.label.borderStyle = FlxTextBorderStyle.NONE;
		return check;
	}

	function clampColor(text:String):Int {
		var parsed:Null<Int> = Std.parseInt(text);

		if (parsed == null)
			parsed = 0;

		return Std.int(Math.max(0, Math.min(parsed, 255)));
	}

	function setBarColor(index:Int, text:String) {
		char.config.barColor[index] = clampColor(text);
		char.barColor = FlxColor.fromRGB(char.config.barColor[0], char.config.barColor[1], char.config.barColor[2]);
		healthBar.color = char.barColor;
		markUnsaved();
	}

	function getCharacterScale():Float {
		var size:Null<Float> = char.config.graphicSize;

		if (size == null)
			size = char.config.graphicsSize;

		if (size == null)
			size = 1;

		return size;
	}

	function setStageVisible(value:Bool) {
		if (stage == null)
			return;

		stage.visible = stage.foregroundSprites.visible = stage.infrontOfGFSprites.visible = value;
	}

	function refreshGroupMembers() {
		if (groupDropDown == null)
			return;

		groupMembers = [];

		if (char.config != null && char.config.characters != null) {
			for (member in char.config.characters) {
				if (member != null && member.name != null)
					groupMembers.push(member.name);
			}
		}

		if (groupMembers.length == 0) {
			groupDropDown.setData(FlxUIDropDownMenu.makeStrIdLabelArray(["- not a group -"], true));
			groupDropDown.selectedLabel = "- not a group -";
			return;
		}

		groupDropDown.setData(FlxUIDropDownMenu.makeStrIdLabelArray(groupMembers, true));
		groupDropDown.selectedLabel = groupMembers[0];
	}

	function refreshUIFromCharacter() {
		if (spriteSheetTextInput == null)
			return;

		refreshGroupMembers();

		spriteSheetTextInput.text = char.config.imagePath ?? "";
		iconName.text = char.icon ?? char.curCharacter;

		if (char.config.barColor == null)
			char.config.barColor = [255, 0, 0];

		r.text = Std.string(char.config.barColor[0]);
		g.text = Std.string(char.config.barColor[1]);
		b.text = Std.string(char.config.barColor[2]);

		healthBar.color = char.barColor;

		icon.setupIcon(char.icon ?? char.curCharacter);
		icon.scale.set(icon.scale.x * 0.47, icon.scale.y * 0.47);
		icon.updateHitbox();

		checkFlipX.checked = char.config.defaultFlipX;
		checkAntialiasing.checked = char.antialiasing;
		dancesCheck.checked = char.dancesLeftAndRight;
		swapSingCheck.checked = char.swapLeftAndRightSingPlayer;

		deathCharInput.text = char.config.deathCharacter ?? "";
		deathNameInput.text = char.config.deathCharacterName ?? "";

		iconFrame = 0;
		iconFrameButton.label.text = "Frame: neutral";

		singDurationStepper.value = char.singDuration;
		scaleStepper.value = getCharacterScale();

		globalOffsetXStepper.value = char.positioningOffset[0];
		globalOffsetYStepper.value = char.positioningOffset[1];

		cameraOffsetXStepper.value = char.cameraOffset[0];
		cameraOffsetYStepper.value = char.cameraOffset[1];

		offsetsFlipWhenPlayer.checked = char.offsetsFlipWhenPlayer;
		offsetsFlipWhenEnemy.checked = char.offsetsFlipWhenEnemy;

		trail.checked = char.config.trail == true;
		trailLength.value = char.config.trailLength ?? 10;
		trailDelay.value = char.config.trailDelay ?? 3;
		trailAlpha.value = char.config.trailStalpha ?? 0.4;
		trailDiff.value = char.config.trailDiff ?? 0.05;

		if (char.coolTrail != null)
			char.coolTrail.visible = trail.checked;

		charDropDown.selectedLabel = char.curCharacter;
	}

	/* ================================================================== */
	/* ================================================================== */
	function destroyCharacter(character:Character) {
		if (character == null)
			return;

		// sprite ya destruido
		if (character.coolTrail != null) {
			world.remove(character.coolTrail, true);
			character.coolTrail.kill();
		}

		world.remove(character, true);
		character.kill();
		character.destroy();
	}

	function loadNewCharacter(name:String) {
		var wasPlayer:Bool = char != null ? char.isPlayer : false;

		destroyCharacter(char);

		daAnim = name;
		char = makeCharacter(name);

		if (wasPlayer)
			setPlayerSide(true, false);

		undoStack = [];
		redoStack = [];
		unsavedChanges = false;
		curAnim = 0;

		rebuildWorld();
		applyCharacterPosition();

		refreshAnimList(false);
		playCurrentAnim();
		refreshUIFromCharacter();

		if (ghostEnabled && ghostFollowsCharacter)
			snapshotGhostFromCharacter();

		centerCameraOnCharacter();
	}

	function loadNewGhost(name:String) {
		destroyCharacter(ghost);

		ghostEnabled = true;

		if (ghostEnabledCheck != null)
			ghostEnabledCheck.checked = true;

		ghostCharacterName = name;
		ghost = makeCharacter(name);
		ghost.visible = true;
		setupGhostLook();

		rebuildWorld();
		reloadGhostOffsets();
		refreshGhostAnimList();
		applyGhostPosition();

		if (ghostFollowsCharacter)
			syncGhostToCharacter();
	}

	function snapshotGhostFromCharacter() {
		destroyCharacter(ghost);

		ghostEnabled = true;

		if (ghostEnabledCheck != null)
			ghostEnabledCheck.checked = true;

		ghostCharacterName = char.curCharacter;
		ghost = makeCharacter(char.curCharacter);
		ghost.visible = true;
		setupGhostLook();

		ghost.flipX = char.flipX;
		ghost.scale.set(char.scale.x, char.scale.y);
		ghost.antialiasing = char.antialiasing;
		ghost.updateHitbox();

		if (ghostDropDown != null)
			ghostDropDown.selectedLabel = ghostCharacterName;

		rebuildWorld();
		reloadGhostOffsets();
		refreshGhostAnimList();
		applyGhostPosition();
		syncGhostToCharacter();
	}

	function reloadGhostOffsets() {
		if (ghost == null || ghost.curCharacter == "")
			return;

		ghost.animOffsets.clear();

		if (ghostShowsOriginalOffsets) {
			ghost.loadOffsetFile(ghost.curCharacter);
		} else {
			for (anim => offsets in char.animOffsets)
				ghost.animOffsets.set(anim, [offsets[0], offsets[1]]);
		}

		if (ghost.hasAnims())
			ghost.playAnim(ghost.curAnimName(), true);
	}

	function syncGhostToCharacter() {
		if (ghost == null || !ghostEnabled || !ghostFollowsCharacter)
			return;

		var animName:String = getCurrentAnimName();

		if (animName != null && ghost.hasAnim(animName))
			ghost.playAnim(animName, true);

		applyGhostPosition();
	}

	function refreshGhostAnimList() {
		ghostAnimList = [];

		if (ghost != null) {
			for (anim => offsets in ghost.animOffsets)
				ghostAnimList.push(anim);
		}

		if (ghostAnimList.length == 0)
			ghostAnimList.push("idle");

		if (ghostAnimDropDown != null)
			ghostAnimDropDown.setData(FlxUIDropDownMenu.makeStrIdLabelArray(ghostAnimList, true));
	}

	/* ================================================================== */
	/* ================================================================== */
	function getIdleName():String {
		return char.dancesLeftAndRight ? "danceRight" : "idle";
	}

	function getCurrentAnimName():String {
		if (animList.length == 0 || curAnim < 0 || curAnim >= animList.length)
			return null;

		return animList[curAnim];
	}

	function playCurrentAnim() {
		var animName:String = getCurrentAnimName();

		if (animName == null) {
			updateAnimText();
			return;
		}

		char.playAnim(animName, true);
		applyCharacterPosition();
		syncGhostToCharacter();
		updateAnimText();
	}

	function refreshAnimList(keepCurrent:Bool = true) {
		var previous:String = keepCurrent ? getCurrentAnimName() : null;

		animList = [];

		if (char.config != null && char.config.animations != null) {
			for (animation in char.config.animations) {
				if (animation != null && animation.name != null && animList.indexOf(animation.name) == -1)
					animList.push(animation.name);
			}
		}

		for (anim => offsets in char.animOffsets) {
			if (animList.indexOf(anim) == -1)
				animList.push(anim);
		}

		for (anim in animList) {
			if (!char.animOffsets.exists(anim))
				char.animOffsets.set(anim, [0, 0]);
		}

		if (previous != null) {
			var index:Int = animList.indexOf(previous);

			if (index != -1)
				curAnim = index;
		}

		if (curAnim >= animList.length)
			curAnim = 0;

		if (curAnim < 0)
			curAnim = 0;

		if (animDropDown != null && animList.length > 0) {
			animDropDown.setData(FlxUIDropDownMenu.makeStrIdLabelArray(animList, true));
			animDropDown.selectedLabel = getCurrentAnimName();
		}

		updateAnimText();
	}

	function genBoyOffsets(pushList:Bool = true):Void {
		if (pushList)
			refreshAnimList();
		else
			updateAnimText();
	}

	function genGhostOffsets(pushList:Bool = true):Void {
		refreshGhostAnimList();
	}

	function fillAnimationInputs() {
		var animName:String = getCurrentAnimName();

		if (animName == null || char.config.animations == null)
			return;

		animationInputName.text = animName;

		for (animation in char.config.animations) {
			if (animation == null || animation.name != animName)
				continue;

			animationInputAnimationName.text = animation.animation_name;
			animationFramerateStepper.value = animation.fps;
			animationLoopedCheckbox.checked = animation.looped;
			animationIndicesInput.text = animation.indices != null ? animation.indices.join(",") : "";
			break;
		}
	}

	function parseIndices(text:String):Array<Int> {
		if (text == null || text.trim() == "")
			return null;

		var indices:Array<Int> = [];

		for (piece in text.split(",")) {
			var value:Null<Int> = Std.parseInt(piece.trim());

			if (value != null)
				indices.push(value);
		}

		return indices.length > 0 ? indices : null;
	}

	function addOrUpdateAnimation() {
		if (animationInputName.text == "" || animationInputAnimationName.text == "") {
			showWarning("Missing the animation name or prefix.");
			return;
		}

		var name:String = animationInputName.text;
		var prefix:String = animationInputAnimationName.text;
		var fps:Int = Std.int(animationFramerateStepper.value);
		var looped:Bool = animationLoopedCheckbox.checked;
		var indices:Array<Int> = parseIndices(animationIndicesInput.text);

		if (char.atlasMode) {
			if (indices != null)
				char.atlas.anim.addBySymbolIndices(name, prefix, indices, fps, looped);
			else
				char.atlas.anim.addBySymbol(name, prefix, fps, looped);
		} else {
			if (indices != null)
				char.animation.addByIndices(name, prefix, indices, "", fps, looped);
			else
				char.animation.addByPrefix(name, prefix, fps, looped);
		}

		if (!char.hasAnim(name))
			showWarning('Could not find "$prefix" in the spritesheet.', 3);

		if (char.config.animations == null)
			char.config.animations = [];

		for (animation in char.config.animations.copy()) {
			if (animation != null && animation.name == name)
				char.config.animations.remove(animation);
		}

		char.config.animations.push({
			name: name,
			animation_name: prefix,
			fps: fps,
			looped: looped,
			indices: indices
		});

		if (!char.animOffsets.exists(name))
			char.addOffset(name, 0, 0);

		refreshAnimList();

		var index:Int = animList.indexOf(name);

		if (index != -1)
			curAnim = index;

		playCurrentAnim();
		markUnsaved();
	}

	function removeCurrentAnimation() {
		var name:String = animationInputName.text != "" ? animationInputName.text : getCurrentAnimName();

		if (name == null)
			return;

		if (!char.atlasMode)
			char.animation.remove(name);

		if (char.config.animations != null) {
			for (animation in char.config.animations.copy()) {
				if (animation != null && animation.name == name)
					char.config.animations.remove(animation);
			}
		}

		char.animOffsets.remove(name);

		refreshAnimList(false);
		playCurrentAnim();
		markUnsaved();
	}

	/* ================================================================== */
	/* OFFSETS                                                             */
	/* ================================================================== */
	function offsetsAreFlipped():Bool {
		return (char.offsetsFlipWhenPlayer && char.isPlayer) || (char.offsetsFlipWhenEnemy && !char.isPlayer);
	}

	function handleFlipChange(wasFlipped:Bool) {
		if (offsetsAreFlipped() != wasFlipped) {
			for (anim => offsets in char.animOffsets)
				offsets[0] = -offsets[0];
		}

		applyCharacterPosition();
		playCurrentAnim();
		markUnsaved();
	}

	function getCurrentOffset():Array<Dynamic> {
		var animName:String = getCurrentAnimName();

		if (animName == null)
			return null;

		if (!char.animOffsets.exists(animName))
			char.animOffsets.set(animName, [0, 0]);

		return char.animOffsets.get(animName);
	}

	function setCurrentOffset(x:Float, y:Float) {
		var offsets:Array<Dynamic> = getCurrentOffset();

		if (offsets == null)
			return;

		offsets[0] = x;
		offsets[1] = y;

		playCurrentAnim();
		markUnsaved();
	}

	function moveOffset(deltaX:Float, deltaY:Float, allAnimations:Bool = false) {
		if (allAnimations) {
			for (anim => offsets in char.animOffsets) {
				offsets[0] += deltaX;
				offsets[1] += deltaY;
			}
		} else {
			var offsets:Array<Dynamic> = getCurrentOffset();

			if (offsets == null)
				return;

			offsets[0] += deltaX;
			offsets[1] += deltaY;
		}

		playCurrentAnim();
		markUnsaved();
	}

	function movePositionOffset(deltaX:Float, deltaY:Float) {
		char.positioningOffset[0] += deltaX;
		char.positioningOffset[1] += deltaY;

		globalOffsetXStepper.value = char.positioningOffset[0];
		globalOffsetYStepper.value = char.positioningOffset[1];

		applyCharacterPosition();
		applyGhostPosition();
		markUnsaved();
	}

	function copyIdleOffset() {
		var idleName:String = getIdleName();

		if (!char.animOffsets.exists(idleName)) {
			showWarning('There is no "$idleName" animation.');
			return;
		}

		var idleOffset:Array<Dynamic> = char.animOffsets.get(idleName);

		pushUndo();
		setCurrentOffset(idleOffset[0], idleOffset[1]);
	}

	function applyOffsetToAll() {
		var offsets:Array<Dynamic> = getCurrentOffset();

		if (offsets == null)
			return;

		var x:Float = offsets[0];
		var y:Float = offsets[1];

		pushUndo();

		for (anim => value in char.animOffsets) {
			value[0] = x;
			value[1] = y;
		}

		playCurrentAnim();
		markUnsaved();
		showWarning("Offset applied to every animation.");
	}

	function autoAlignToIdle() {
		if (char.atlasMode) {
			showWarning("Auto align does not work with texture atlases.");
			return;
		}

		var idleName:String = getIdleName();
		var animName:String = getCurrentAnimName();

		if (animName == null || animName == idleName)
			return;

		try {
			var idleAnim = char.animation.getByName(idleName);
			var currentAnim = char.animation.getByName(animName);

			if (idleAnim == null || currentAnim == null) {
				showWarning("Could not read the animation.");
				return;
			}

			var idleFrame = char.frames.frames[idleAnim.frames[0]];
			var currentFrame = char.frames.frames[currentAnim.frames[0]];

			var idleOffset:Array<Dynamic> = char.animOffsets.get(idleName);

			pushUndo();

			setCurrentOffset(idleOffset[0] + ((currentFrame.offset.x - idleFrame.offset.x) * char.scale.x),
				idleOffset[1] + ((currentFrame.offset.y - idleFrame.offset.y) * char.scale.y));

			showWarning("Aligned with " + idleName + " (CTRL+Z to undo).");
		} catch (e:Dynamic) {
			showWarning("Could not align automatically.");
		}
	}

	/* ------------------------- undo / redo ---------------------------- */
	function takeSnapshot():OffsetSnapshot {
		var offsets:Map<String, Array<Dynamic>> = new Map<String, Array<Dynamic>>();

		for (anim => value in char.animOffsets)
			offsets.set(anim, [value[0], value[1]]);

		return {
			offsets: offsets,
			position: [char.positioningOffset[0], char.positioningOffset[1]]
		};
	}

	function applySnapshot(snapshot:OffsetSnapshot) {
		char.animOffsets.clear();

		for (anim => value in snapshot.offsets)
			char.animOffsets.set(anim, [value[0], value[1]]);

		char.positioningOffset[0] = snapshot.position[0];
		char.positioningOffset[1] = snapshot.position[1];

		globalOffsetXStepper.value = char.positioningOffset[0];
		globalOffsetYStepper.value = char.positioningOffset[1];

		applyCharacterPosition();
		playCurrentAnim();
	}

	function pushUndo() {
		undoStack.push(takeSnapshot());

		if (undoStack.length > 60)
			undoStack.shift();

		redoStack = [];
	}

	function undo() {
		if (undoStack.length == 0) {
			showWarning("Nothing to undo.");
			return;
		}

		redoStack.push(takeSnapshot());
		applySnapshot(undoStack.pop());
		showWarning("Undo", 1);
	}

	function redo() {
		if (redoStack.length == 0) {
			showWarning("Nothing to redo.");
			return;
		}

		undoStack.push(takeSnapshot());
		applySnapshot(redoStack.pop());
		showWarning("Redo", 1);
	}

	function markUnsaved() {
		unsavedChanges = true;
	}

	/* ================================================================== */
	/* LADO / FLIP                                                         */
	/* ================================================================== */
	function setPlayerSide(value:Bool, updateSlot:Bool = true) {
		if (char.isPlayer == value)
			return;

		var wasFlipped:Bool = offsetsAreFlipped();

		char.isPlayer = value;
		char.flipX = !char.flipX;

		char.cameraOffset[0] = -char.cameraOffset[0];

		if (offsetsAreFlipped() != wasFlipped) {
			for (anim => offsets in char.animOffsets)
				offsets[0] = -offsets[0];
		}

		if (updateSlot) {
			charSlot = value ? 0 : 1;

			if (slotDropDown != null)
				slotDropDown.selectedLabel = value ? "Player 1 (BF)" : "Player 2 (Dad)";
		}

		if (cameraOffsetXStepper != null)
			cameraOffsetXStepper.value = char.cameraOffset[0];

		applyCharacterPosition();
		applyGhostPosition();
		playCurrentAnim();
	}

	/* ================================================================== */
	/* UPDATE                                                              */
	/* ================================================================== */
	override function update(elapsed:Float) {
		updateBlockInput();

		if (!blockInput) {
			handleKeyboard(elapsed);
			handleMouse(elapsed);
		}

		if (FlxG.sound.music != null)
			Conductor.songPosition = FlxG.sound.music.time;

		updateGuides();
		updateHUD(elapsed);

		super.update(elapsed);
	}

	function updateBlockInput() {
		blockInput = false;

		for (inputText in blockPressWhileTypingOn) {
			if (inputText != null && inputText.hasFocus) {
				blockInput = true;
				break;
			}
		}

		if (!blockInput) {
			for (stepper in blockPressWhileTypingOnStepper) {
				if (stepper == null)
					continue;

				@:privateAccess
				if (cast(stepper.text_field, flixel.addons.ui.FlxInputText).hasFocus) {
					blockInput = true;
					break;
				}
			}
		}

		if (blockInput) {
			FlxG.sound.muteKeys = [];
			FlxG.sound.volumeDownKeys = [];
			FlxG.sound.volumeUpKeys = [];
			return;
		}

		FlxG.sound.muteKeys = [ZERO, NUMPADZERO];
		FlxG.sound.volumeDownKeys = [MINUS, NUMPADMINUS];
		FlxG.sound.volumeUpKeys = [PLUS, NUMPADPLUS];

		for (dropDownMenu in blockPressWhileScrolling) {
			if (dropDownMenu != null && dropDownMenu.dropPanel.visible) {
				blockInput = true;
				break;
			}
		}
	}

	/* ------------------------- teclado -------------------------------- */
	function handleKeyboard(elapsed:Float) {
		var shift:Bool = FlxG.keys.pressed.SHIFT;
		var ctrl:Bool = FlxG.keys.pressed.CONTROL;
		var alt:Bool = FlxG.keys.pressed.ALT;

		if (ctrl) {
			if (FlxG.keys.justPressed.S) {
				if (shift)
					saveConfig();
				else
					saveOffsets();

				return;
			}

			if (FlxG.keys.justPressed.Z) {
				if (shift)
					redo();
				else
					undo();

				return;
			}

			if (FlxG.keys.justPressed.Y) {
				redo();
				return;
			}

			if (FlxG.keys.justPressed.C) {
				var offsets:Array<Dynamic> = getCurrentOffset();

				if (offsets != null) {
					copiedOffset = [offsets[0], offsets[1]];
					showWarning("Offset copied: " + copiedOffset[0] + ", " + copiedOffset[1], 1.5);
				}

				return;
			}

			if (FlxG.keys.justPressed.V) {
				if (copiedOffset != null) {
					pushUndo();
					setCurrentOffset(copiedOffset[0], copiedOffset[1]);
					showWarning("Offset pasted.", 1.5);
				}

				return;
			}
		}

		/* --- salir --- */
		if (FlxG.keys.justPressed.ESCAPE) {
			if (unsavedChanges && escapeTimer <= 0) {
				escapeTimer = 3;
				showWarning("You have unsaved changes. Press ESC again to leave anyway.", 3);
			} else {
				exitEditor();
			}

			return;
		}

		/* --- zoom / camara --- */
		if (FlxG.keys.pressed.E && charCam.zoom < 2)
			charCam.zoom += elapsed * charCam.zoom * (shift ? 0.1 : 1);

		if (FlxG.keys.pressed.Q && charCam.zoom >= 0.1)
			charCam.zoom -= elapsed * charCam.zoom * (shift ? 0.1 : 1);

		if (FlxG.mouse.wheel != 0)
			charCam.zoom += shift ? FlxG.mouse.wheel / 100.0 : FlxG.mouse.wheel / 10.0;

		charCam.zoom = FlxMath.bound(charCam.zoom, 0.1, 2);

		if (FlxG.keys.justPressed.HOME) {
			charCam.zoom = 1;
			centerCameraOnCharacter(true);
		}

		var camSpeed:Int = shift ? 5 : 1;

		if (FlxG.keys.pressed.I || FlxG.keys.pressed.J || FlxG.keys.pressed.K || FlxG.keys.pressed.L) {
			if (FlxG.keys.pressed.I)
				camFollow.velocity.y = -90 * camSpeed;
			else if (FlxG.keys.pressed.K)
				camFollow.velocity.y = 90 * camSpeed;
			else
				camFollow.velocity.y = 0;

			if (FlxG.keys.pressed.J)
				camFollow.velocity.x = -90 * camSpeed;
			else if (FlxG.keys.pressed.L)
				camFollow.velocity.x = 90 * camSpeed;
			else
				camFollow.velocity.x = 0;
		} else {
			camFollow.velocity.set();
		}

		/* --- vista --- */
		if (FlxG.keys.justPressed.F1)
			showFullHelp = !showFullHelp;

		if (FlxG.keys.justPressed.F2)
			guides.toggleAll(!guides.showLoadBox);

		if (FlxG.keys.justPressed.F3)
			setUIVisible(!uiVisible);

		if (FlxG.keys.justPressed.Z && !ctrl)
			setStageVisible(!stage.visible);

		if (FlxG.keys.justPressed.X)
			setPlayerSide(!char.isPlayer);

		/* --- ghost --- */
		if (FlxG.keys.justPressed.G) {
			setGhostEnabled(!ghostEnabled);
			showWarning(ghostEnabled ? "Ghost on" : "Ghost off", 1);
		}

		if (FlxG.keys.justPressed.H) {
			snapshotGhostFromCharacter();
			showWarning("Ghost copied from the current character.", 1.5);
		}

		if (!ctrl) {
			if (FlxG.keys.justPressed.W) {
				curAnim--;

				if (curAnim < 0)
					curAnim = animList.length - 1;

				playCurrentAnim();
				updateAnimDropDown();
			}

			if (FlxG.keys.justPressed.S) {
				curAnim++;

				if (curAnim >= animList.length)
					curAnim = 0;

				playCurrentAnim();
				updateAnimDropDown();
			}

			if (FlxG.keys.justPressed.SPACE)
				playCurrentAnim();

			if (!char.atlasMode && char.animation.curAnim != null) {
				if (FlxG.keys.justPressed.P) {
					if (char.animation.curAnim.paused)
						char.animation.resume();
					else
						char.animation.pause();
				}

				if (FlxG.keys.justPressed.COMMA)
					stepFrame(-1);

				if (FlxG.keys.justPressed.PERIOD)
					stepFrame(1);
			}

			if (FlxG.keys.justPressed.R) {
				pushUndo();
				setCurrentOffset(0, 0);
			}
		}

		/* --- offsets --- */
		var multiplier:Float = shift ? 10 : 1;

		var up:Bool = checkArrow(0, FlxG.keys.pressed.UP, FlxG.keys.justPressed.UP, elapsed);
		var down:Bool = checkArrow(1, FlxG.keys.pressed.DOWN, FlxG.keys.justPressed.DOWN, elapsed);
		var left:Bool = checkArrow(2, FlxG.keys.pressed.LEFT, FlxG.keys.justPressed.LEFT, elapsed);
		var right:Bool = checkArrow(3, FlxG.keys.pressed.RIGHT, FlxG.keys.justPressed.RIGHT, elapsed);

		if (up || down || left || right) {
			if (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.DOWN || FlxG.keys.justPressed.LEFT || FlxG.keys.justPressed.RIGHT)
				pushUndo();

			var deltaX:Float = ((left ? 1 : 0) - (right ? 1 : 0)) * multiplier;
			var deltaY:Float = ((up ? 1 : 0) - (down ? 1 : 0)) * multiplier;

			if (alt)
				movePositionOffset(-deltaX, -deltaY);
			else
				moveOffset(deltaX, deltaY, ctrl);
		}
	}

	function stepFrame(direction:Int) {
		if (char.atlasMode || char.animation.curAnim == null)
			return;

		var anim = char.animation.curAnim;
		var total:Int = anim.numFrames;

		if (total <= 0)
			return;

		char.animation.pause();
		anim.curFrame = ((anim.curFrame + direction) % total + total) % total;
	}

	function checkArrow(index:Int, pressed:Bool, justPressed:Bool, elapsed:Float):Bool {
		if (!pressed) {
			arrowTimers[index] = 0;
			return false;
		}

		if (justPressed) {
			arrowTimers[index] = 0;
			return true;
		}

		arrowTimers[index] += elapsed;

		if (arrowTimers[index] >= 0.4) {
			arrowTimers[index] -= 0.06;
			return true;
		}

		return false;
	}

	function updateAnimDropDown() {
		if (animDropDown == null)
			return;

		var animName:String = getCurrentAnimName();

		if (animName != null)
			animDropDown.selectedLabel = animName;
	}

	/* --------------------------- mouse -------------------------------- */
	function handleMouse(elapsed:Float) {
		#if FLX_MOUSE
		var mouseWorldX:Float = FlxG.mouse.x;
		var mouseWorldY:Float = FlxG.mouse.y;

		var overUI:Bool = mouseOverUI();

		if (FlxG.mouse.justPressed && !overUI && mouseOverCharacter()) {
			draggingOffset = true;
			dragAccum.set(0, 0);
			pushUndo();
		}

		if (!FlxG.mouse.pressed)
			draggingOffset = false;

		if (draggingOffset) {
			dragAccum.x += mouseWorldX - lastMouseWorld.x;
			dragAccum.y += mouseWorldY - lastMouseWorld.y;

			var stepX:Float = Math.round(dragAccum.x);
			var stepY:Float = Math.round(dragAccum.y);

			if (stepX != 0 || stepY != 0) {
				dragAccum.x -= stepX;
				dragAccum.y -= stepY;

				if (FlxG.keys.pressed.ALT)
					movePositionOffset(stepX, stepY);
				else
					moveOffset(-stepX, -stepY, FlxG.keys.pressed.CONTROL);
			}
		}

		#if FLX_MOUSE_ADVANCED
		if (FlxG.mouse.justPressedRight && !overUI)
			draggingCamera = true;

		if (!FlxG.mouse.pressedRight)
			draggingCamera = false;

		if (draggingCamera) {
			camFollow.velocity.set();
			camFollow.x -= mouseWorldX - lastMouseWorld.x;
			camFollow.y -= mouseWorldY - lastMouseWorld.y;
		}
		#end

		lastMouseWorld.set(mouseWorldX, mouseWorldY);
		#end
	}

	function mouseOverCharacter():Bool {
		var rect:Array<Float> = EditorGuides.getDrawRect(char);

		return FlxG.mouse.x >= rect[0] && FlxG.mouse.x <= rect[0] + rect[2] && FlxG.mouse.y >= rect[1] && FlxG.mouse.y <= rect[1] + rect[3];
	}

	function mouseOverUI():Bool {
		if (!uiVisible)
			return false;

		return pointInBox(FlxG.mouse.screenX, FlxG.mouse.screenY, tabs.x, tabs.y - 20, TABS_WIDTH, TABS_HEIGHT + 20)
			|| pointInBox(FlxG.mouse.screenX, FlxG.mouse.screenY, editor.x, editor.y - 20, EDITOR_WIDTH, EDITOR_HEIGHT + 20);
	}

	function pointInBox(pointX:Float, pointY:Float, boxX:Float, boxY:Float, boxWidth:Float, boxHeight:Float):Bool {
		return pointX >= boxX && pointX <= boxX + boxWidth && pointY >= boxY && pointY <= boxY + boxHeight;
	}

	function setUIVisible(value:Bool) {
		uiVisible = value;

		tabs.visible = editor.visible = value;
		animText.visible = animTextBG.visible = value;
		moveText.visible = moveTextBG.visible = value;
		legend.visible = value && showLegend;
	}

	function updateGuides() {
		if (guides == null || char == null)
			return;

		var target:Character = visibleCharacter();

		guides.updateGuides(target ?? char, getStagePoint(), getCameraTarget(), stageData != null ? stageData.camera_Zoom : 1, charCam.zoom, ghost);
	}

	function updateHUD(elapsed:Float) {
		if (escapeTimer > 0)
			escapeTimer -= elapsed;

		if (warningTimer > 0) {
			warningTimer -= elapsed;

			if (warningTimer <= 0)
				warningText.text = "";
		}

		updateAnimText();

		legend.visible = showLegend && uiVisible;

		moveText.text = getHelpText();

		if (showFullHelp) {
			// dos paneles
			moveText.alignment = LEFT;
			moveText.setPosition(EDITOR_X + EDITOR_WIDTH + 60, 60);
		} else {
			moveText.alignment = RIGHT;
			moveText.setPosition(FlxG.width - moveText.width - 6, 4);
		}

		updateTextBG(animTextBG, animText);
		updateTextBG(moveTextBG, moveText);
	}

	function updateTextBG(bg:FlxSprite, text:FlxText) {
		bg.setPosition(text.x - 4, text.y - 3);
		bg.origin.set(0, 0);
		bg.offset.set(0, 0);
		bg.scale.set(text.width + 8, text.height + 6);
		bg.visible = text.visible && text.text != "";
	}

	function getHelpText():String {
		var zoom:String = Std.string(FlxMath.roundDecimal(charCam.zoom, 2));
		var unsaved:String = unsavedChanges ? "  (*unsaved)" : "";

		if (!showFullHelp)
			return 'Zoom: $zoom$unsaved\nF1: show every control';

		return 'Zoom: $zoom$unsaved'
			+ '\n--- camera ---'
			+ '\nIJKL / right click drag: move'
			+ '\nQ E / wheel: zoom    HOME: center'
			+ '\n--- animation ---'
			+ '\nW S: change    SPACE: replay    P: pause'
			+ '\n, .: previous / next frame'
			+ '\n--- offsets ---'
			+ '\nArrows: move (SHIFT x10)'
			+ '\nCTRL + arrows: every animation'
			+ '\nALT + arrows: character position'
			+ '\nLeft click on the character: drag'
			+ '\nR: reset    CTRL+Z / CTRL+Y: undo / redo'
			+ '\nCTRL+C / CTRL+V: copy and paste offset'
			+ '\n--- other ---'
			+ '\nG: ghost    H: ghost = current character'
			+ '\nX: swap side    Z: stage'
			+ '\nF2: guides    F3: interface'
			+ '\nCTRL+S: save offsets'
			+ '\nCTRL+SHIFT+S: save config';
	}

	function updateAnimText() {
		if (animText == null)
			return;

		var animName:String = getCurrentAnimName();

		var header:String = char.curCharacter
			+ (char.isCharacterGroup ? "  [character group]" : "")
			+ (char.isPlayer ? "  [player]" : "  [enemy]")
			+ (offsetsAreFlipped() ? "  (flipped offsets)" : "")
			+ "\npos "
			+ Std.int(char.x)
			+ ", "
			+ Std.int(char.y)
			+ " | size "
			+ Std.int(char.width)
			+ "x"
			+ Std.int(char.height);

		if (animName != null) {
			var offsets:Array<Dynamic> = char.animOffsets.get(animName);

			header += "\n> " + animName + ": " + (offsets == null ? "[?, ?]" : "[" + offsets[0] + ", " + offsets[1] + "]");

			if (!char.atlasMode && char.animation.curAnim != null)
				header += "   frame " + (char.animation.curAnim.curFrame + 1) + "/" + char.animation.curAnim.numFrames;
		} else if (char.isCharacterGroup) {
			header += "\n> group of "
				+ (char.otherCharacters != null ? char.otherCharacters.length : 0)
				+ ": edit each one on its own"
				+ "\n> only the icon, bar, camera and position are saved here";
		} else {
			header += "\n> this character has no animations";
		}

		var maxShown:Int = 10;
		var start:Int = 0;

		if (animList.length > maxShown) {
			start = curAnim - Std.int(maxShown / 2);

			if (start < 0)
				start = 0;

			if (start + maxShown > animList.length)
				start = animList.length - maxShown;
		}

		var body:String = "\n";

		if (start > 0)
			body += "   ...\n";

		var index:Int = start;

		while (index < animList.length && index < start + maxShown) {
			var name:String = animList[index];
			var value:Array<Dynamic> = char.animOffsets.get(name);

			if (value != null)
				body += (index == curAnim ? " > " : "   ") + name + ": [" + value[0] + ", " + value[1] + "]\n";

			index++;
		}

		if (start + maxShown < animList.length)
			body += "   ...";

		animText.text = header + body;
	}

	/* ================================================================== */
	/* STEPPERS                                                            */
	/* ================================================================== */
	override function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>) {
		if (id != FlxUINumericStepper.CHANGE_EVENT || !(sender is FlxUINumericStepper))
			return;

		var stepper:FlxUINumericStepper = cast sender;

		switch (stepper.name) {
			case "globalOffsetX":
				char.positioningOffset[0] = data;
				applyCharacterPosition();
				applyGhostPosition();
				markUnsaved();

			case "globalOffsetY":
				char.positioningOffset[1] = data;
				applyCharacterPosition();
				applyGhostPosition();
				markUnsaved();

			case "cameraOffsetX":
				char.cameraOffset[0] = data;
				markUnsaved();

			case "cameraOffsetY":
				char.cameraOffset[1] = data;
				markUnsaved();

			case "scale":
				char.config.graphicSize = char.config.graphicsSize = data;
				char.scale.set(data, data);
				char.updateHitbox();
				char.centerOrigin();
				playCurrentAnim();
				markUnsaved();

			case "singDuration":
				char.config.singDuration = char.singDuration = data;
				markUnsaved();

			case "trailLength":
				char.config.trailLength = Std.int(data);
				rebuildTrail();
				markUnsaved();

			case "trailDelay":
				char.config.trailDelay = Std.int(data);

				if (char.coolTrail != null)
					char.coolTrail.delay = Std.int(data);

				markUnsaved();

			case "trailAlpha":
				char.config.trailStalpha = data;

				if (char.coolTrail != null) {
					@:privateAccess
					char.coolTrail._transp = data;
				}

				markUnsaved();

			case "trailDiff":
				char.config.trailDiff = data;

				if (char.coolTrail != null) {
					@:privateAccess
					char.coolTrail._difference = data;
				}

				markUnsaved();
		}
	}

	function rebuildTrail() {
		if (char.coolTrail != null) {
			world.remove(char.coolTrail, true);
			char.coolTrail.kill();
			char.coolTrail.destroy();
		}

		char.coolTrail = new FlxTrail(char, null, char.config.trailLength ?? 10, char.config.trailDelay ?? 3, char.config.trailStalpha ?? 0.4,
			char.config.trailDiff ?? 0.05);
		char.coolTrail.visible = char.config.trail == true;

		rebuildWorld();
	}

	/* ================================================================== */
	/* GUARDADO                                                            */
	/* ================================================================== */
	function cleanNumber(value:Dynamic):Float {
		var number:Float = cast value;

		if (Math.isNaN(number) || !Math.isFinite(number))
			return 0;

		return FlxMath.roundDecimal(number, 4);
	}

	function cleanForJson(value:Dynamic):Dynamic {
		if (value == null)
			return null;

		if (Std.isOfType(value, Bool) || Std.isOfType(value, String))
			return value;

		if (Std.isOfType(value, Float)) {
			return cleanNumber(value);
		}

		if (Std.isOfType(value, Array)) {
			var array:Array<Dynamic> = cast value;
			var cleaned:Array<Dynamic> = [];

			for (item in array)
				cleaned.push(cleanForJson(item));

			return cleaned;
		}

		var cleaned:Dynamic = {};

		for (field in Reflect.fields(value)) {
			var fieldValue:Dynamic = cleanForJson(Reflect.field(value, field));

			if (fieldValue != null)
				Reflect.setField(cleaned, field, fieldValue);
		}

		return cleaned;
	}

	function saveOffsets() {
		var offsetsText:String = "";
		var flipped:Bool = offsetsAreFlipped();

		for (anim in animList) {
			var offsets:Array<Dynamic> = char.animOffsets.get(anim);

			if (offsets == null)
				continue;

			var offsetX:Float = flipped ? -cleanNumber(offsets[0]) : cleanNumber(offsets[0]);
			var offsetY:Float = cleanNumber(offsets[1]);

			offsetsText += anim + " " + offsetX + " " + offsetY + "\n";
		}

		if (offsetsText == "") {
			showWarning("No offsets to save.");
			return;
		}

		if (offsetsText.endsWith("\n"))
			offsetsText = offsetsText.substr(0, offsetsText.length - 1);

		saveFile(offsetsText, "offsets.txt");
	}

	inline function setIfNotNull(target:Dynamic, field:String, value:Dynamic) {
		if (value != null)
			Reflect.setField(target, field, value);
	}

	function buildConfig():CharacterConfig {
		var config:CharacterConfig = char.config;
		var saved:Dynamic = {};

		for (field in Reflect.fields(config))
			Reflect.setField(saved, field, Reflect.field(config, field));

		var cameraOffset:Array<Float> = [char.cameraOffset[0], char.cameraOffset[1]];

		if (char.flipX)
			cameraOffset[0] = -cameraOffset[0];

		setIfNotNull(saved, "barColor", config.barColor);
		setIfNotNull(saved, "healthIcon", char.icon);
		setIfNotNull(saved, "cameraOffset", cameraOffset);
		setIfNotNull(saved, "positionOffset", [char.positioningOffset[0], char.positioningOffset[1]]);
		setIfNotNull(saved, "singDuration", char.singDuration);
		setIfNotNull(saved, "deathCharacter", config.deathCharacter);
		setIfNotNull(saved, "deathCharacterName", config.deathCharacterName);
		setIfNotNull(saved, "characters", config.characters);
		setIfNotNull(saved, "mainCharacterID", config.mainCharacterID);
		setIfNotNull(saved, "followMainCharacter", config.followMainCharacter);

		if (char.isCharacterGroup) {
			return cast saved;
		}

		setIfNotNull(saved, "imagePath", config.imagePath);
		setIfNotNull(saved, "animations", config.animations);
		setIfNotNull(saved, "defaultFlipX", config.defaultFlipX);
		setIfNotNull(saved, "defaultFlipY", config.defaultFlipY);
		setIfNotNull(saved, "dancesLeftAndRight", char.dancesLeftAndRight);
		setIfNotNull(saved, "graphicSize", getCharacterScale());
		setIfNotNull(saved, "graphicsSize", getCharacterScale());
		setIfNotNull(saved, "offsetsFlipWhenPlayer", char.offsetsFlipWhenPlayer);
		setIfNotNull(saved, "offsetsFlipWhenEnemy", char.offsetsFlipWhenEnemy);
		setIfNotNull(saved, "swapDirectionSingWhenPlayer", char.swapLeftAndRightSingPlayer);
		setIfNotNull(saved, "antialiasing", char.antialiasing);
		setIfNotNull(saved, "antialiased", char.antialiasing);
		setIfNotNull(saved, "extraSheets", config.extraSheets);

		setIfNotNull(saved, "trail", config.trail);
		setIfNotNull(saved, "trailLength", config.trailLength);
		setIfNotNull(saved, "trailDelay", config.trailDelay);
		setIfNotNull(saved, "trailStalpha", config.trailStalpha);
		setIfNotNull(saved, "trailDiff", config.trailDiff);

		return cast saved;
	}

	function saveConfig() {
		var data:String = Json.stringify(cleanForJson(buildConfig()), null, "\t");

		if (data == null || data.length == 0) {
			showWarning("Something went wrong building the config.");
			return;
		}

		saveFile(data, "config.json");
	}

	function saveFile(data:String, fileName:String) {
		_file = new FileReference();
		_file.addEventListener(Event.COMPLETE, onSaveComplete);
		_file.addEventListener(Event.CANCEL, onSaveCancel);
		_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);

		_file.save(data, fileName);
	}

	function removeSaveListeners() {
		if (_file == null)
			return;

		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
	}

	function onSaveComplete(_):Void {
		removeSaveListeners();
		unsavedChanges = false;
		showWarning("Saved.");
		FlxG.log.notice("Successfully saved file.");
	}

	function onSaveCancel(_):Void {
		removeSaveListeners();
	}

	function onSaveError(_):Void {
		removeSaveListeners();
		showWarning("Error while saving.", 3);
		trace("Problem saving file", ERROR);
	}

	/* ================================================================== */
	/* SALIR                                                               */
	/* ================================================================== */
	function exitEditor() {
		if (lastState == "OptionsMenu")
			FlxG.switchState(() -> new MainMenuState());
		else
			FlxG.switchState(() -> new PlayState());
	}

	override function destroy() {
		Main.display.visible = true;

		lastMouseWorld = FlxDestroyUtil.put(lastMouseWorld);
		dragAccum = FlxDestroyUtil.put(dragAccum);
		_midpoint = FlxDestroyUtil.put(_midpoint);
		_camTarget = FlxDestroyUtil.put(_camTarget);

		super.destroy();
	}
}

typedef OffsetSnapshot = {
	var offsets:Map<String, Array<Dynamic>>;
	var position:Array<Float>;
}
