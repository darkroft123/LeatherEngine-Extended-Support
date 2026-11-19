package toolbox;

#if sys
import sys.io.File;
#end
import lime.ui.FileDialog;
import game.SoundGroup;
import flixel.util.FlxTimer;
import flixel.FlxObject;
import game.EventSprite;
import utilities.NoteVariables;
import modding.CharacterConfig;
import ui.FlxScrollableDropDownMenu;
import game.SongLoader;
import states.LoadingState;
import game.Conductor;
import states.PlayState;
import states.FreeplayState;
import states.StoryMenuState;
import states.MusicBeatState;
import ui.HealthIcon;
import game.Note;
import game.SongLoader.SongData;
import flixel.FlxG;
import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUICheckBox;
import flixel.text.FlxInputText;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.FlxUITabMenu;
import flixel.addons.ui.FlxUISlider;
import flixel.group.FlxGroup;
import flixel.math.FlxMath;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import haxe.Json;
import lime.utils.Assets;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.net.FileReference;

using utilities.BackgroundUtil;
using utilities.MusicUtilities;

typedef PatternNote = {
	var offset:Float;
	var dir:Int;
	@:optional var sus:Float;
};

typedef UndoAction = {
	var type:String;
	var data:Dynamic;
};

typedef ClipboardNote = {
	var strumTime:Float;
	var noteData:Int;
	var sustainLen:Float;
	var noteType:String;
	var section:Int;
};

enum abstract WaveformTarget(String) to String from String {
	var INST = 'inst';
	var PLAYER = 'voc';
	var OPPONENT = 'opp';
}

@:publicFields
class ChartingState extends MusicBeatState {
	public static var instance:ChartingState = null;
	var fileDialogue:FileReference;

	var UI_box:FlxUITabMenu;

	/**
	 * Array of notes showing when each section STARTS in STEPS
	 * Usually rounded up??
	 */
	var curSection:Int = 0;

	var bpmTxt:FlxText;

	var strumLine:FlxSprite;

	static var GRID_SIZE:Int = 40;
	static inline final GRID_SIZE_DEFAULT:Int = 40;
	static inline final GRID_SIZE_MIN:Int = 20;
	static inline final GRID_SIZE_MAX:Int = 80;
	var gridAlpha:Float = 1.0;
	static inline final GRID_ALPHA_DEFAULT:Float = 1.0;
	static inline final GRID_ALPHA_MIN:Float = 0.1;
	static inline final GRID_ALPHA_MAX:Float = 1.0;

	var dummyArrow:FlxSprite;

	var curRenderedNotes:FlxTypedGroup<Note>;
	var curRenderedIds:FlxTypedGroup<FlxSprite>;
	var curRenderedEvents:FlxTypedGroup<EventSprite>;

	var gridBG:FlxSprite;
	var gridBGNext:FlxSprite;

	var _song:SongData;

	var strumlineReceptors:FlxTypedGroup<FlxSprite>;
	var gridEventReceptors:FlxTypedGroup<FlxSprite>;

	var difficulty:String = 'normal';

	var typingShit:FlxInputText;
	var swagShit:FlxInputText;
	var modchart_Input:FlxInputText;
	var cutscene_Input:FlxInputText;
	var endCutscene_Input:FlxInputText;
	var characterGroup_Input:FlxInputText;

	/*
	 * WILL BE THE CURRENT / LAST PLACED NOTE
	**/
	var curSelectedNote:Array<Dynamic>;
	var curSelectedEvent:Array<Dynamic>;

	var tempBpm:Float = 0;

	var vocals:SoundGroup;

	var leftIcons:Array<HealthIcon>;
	var rightIcons:Array<HealthIcon>;
	var leftIconLabel:FlxText;
	var rightIconLabel:FlxText;
	var extraHeaderIcons:Array<Array<HealthIcon>> = [];
	var extraHeaderLabels:Array<FlxText> = [];

	var characters:Map<String, Array<String>> = new Map<String, Array<String>>();
	var arrayCharacters:Array<String> = ["bf", "gf", ""];

	var waveformSprite:FlxSprite;
	var waveformEnabled:Bool = false;
	var waveformTarget:WaveformTarget = INST;
	var waveformTimer:FlxTimer;
	var waveformAnalyzer:system.AudioAnalyzer;

	var patternModeEnabled:Bool = false;
	var patternUndoHistory:Array<Array<Array<Dynamic>>> = [];
	var patternDefinitions:Map<String, Array<PatternNote>> = new Map<String, Array<PatternNote>>();
	var arrow_Configs:Map<String, Array<String>> = new Map<String, Array<String>>();
	var gridBlackLine:FlxSprite;
	var gridEventBlackLine:FlxSprite;
	var gridSeparators:FlxTypedGroup<FlxSprite>;

	var selected_mod:String = "default";

	var stepperSusLength:FlxUINumericStepper;
	var stepperCharLength:FlxUINumericStepper;

	var current_Note_Character:Int = 0;

	static var playerHitsounds:Bool = false;
	static var enemyHitsounds:Bool = false;

	var eventList:Array<String> = [];
	var eventListData:Array<Array<String>> = [];

	var zoomLevel:Float = 1;
	var prevZoomLevel:Float = 1;

	var MIN_ZOOM:Float = 0.25;
	var MAX_ZOOM:Float = 4.0;

	var showDuplicateBoxes:Bool = false;
	var duplicateBoxes:FlxTypedGroup<FlxSprite>;
	var duplicateCountText:FlxText;

	var menuBG:FlxSprite;

	var colorQuantization:Bool;

	static var globalSecton:Int = 0;

	var lastInstAssetPath:String;
	var lastVoicesAssetPaths:Array<String>;

	var hasUnsavedChanges:Bool = false;
	var autosaveText:FlxText;
	var escConfirmActive:Bool = false;

	// Codename-style UI elements
	var noteHoverer:FlxSprite;
	var topMenuBar:FlxSprite;
	var topMenuItems:Array<FlxText>;
	var topMenuHighlight:FlxSprite;
	var prevHoveredMenuIndex:Int = -1;
	var activeSubmenuIndex:Int = -1;
	var topInfoTxt:FlxText;
	var contextMenuGroup:flixel.group.FlxGroup;
	var contextMenuBG:FlxSprite;
	var contextMenuItems:Array<FlxText>;
	var contextMenuVisible:Bool = false;
	var contextMenuActions:Array<String> = [];

	var headerInfoBox:FlxSprite;
	var headerInfoBorder:FlxSprite;
	var headerInfoTitle:FlxText;
	var headerInfoDesc:FlxText;
	var headerInfoTargetX:Float = 1300;
	var menuDescriptions:Map<String, String>;

	var showStagePreview:Bool = false;
	var stageGroupPreview:game.StageGroup;
	var charPreviewP1:game.Character;
	var charPreviewP2:game.Character;
	var charPreviewGF:game.Character;
	var camStagePreview:FlxCamera;
	var camUI:FlxCamera;
	var scrollBarThumb:FlxSprite;
	var scrollBarBG:FlxSprite;
	var sectionInfoText:FlxText;
	var quantText:FlxText;
	/** Numeric readout shown under the "Speed" line. **/
	var sideInfoTxt:FlxText;
	var quantBox:FlxUICheckBox;
	var playbackSlider:FlxSprite;

	// Grid scroll elements
	var isDraggingGrid:Bool = false;
	var lastDragMouseX:Float = 0;
	var isDraggingScrollBar:Bool = false;

	// Multi-selection system (Codename-style)
	var selectedNotes:Array<{strumTime:Float, noteData:Int, section:Int}> = [];
	var selectionBox:FlxSprite;
	var isBoxSelecting:Bool = false;
	var boxSelectStartX:Float = 0;
	var boxSelectStartY:Float = 0;

	// Clipboard
	var clipboardNotes:Array<{strumTime:Float, noteData:Int, sustainLen:Float, noteType:String, section:Int}> = [];
	var clipboardEvents:Array<Array<Dynamic>> = [];

	// Undo/Redo system
	var undoList:Array<UndoAction> = [];
	var redoList:Array<UndoAction> = [];
	var maxUndoSteps:Int = 100;

	// Note dragging
	var isDraggingNotes:Bool = false;
	var dragStartX:Float = 0;
	var dragStartY:Float = 0;
	var dragOffsets:Array<{noteIndex:Int, section:Int, origTime:Float, origData:Int}> = [];

	// Sustain drag
	var isDraggingSustain:Bool = false;
	var draggedNoteIndex:Int = -1;

	function definePatterns() {
		patternDefinitions.set("stream", [
			{offset: 0, dir: 0},
			{offset: 1, dir: 1},
			{offset: 2, dir: 2},
			{offset: 3, dir: 3}
		]);
		patternDefinitions.set("staircase", [
			{offset: 0, dir: 0}, {offset: 1, dir: 1}, {offset: 2, dir: 2}, {offset: 3, dir: 3},
			{offset: 4, dir: 3}, {offset: 5, dir: 2}, {offset: 6, dir: 1}, {offset: 7, dir: 0}
		]);
		patternDefinitions.set("jack", [
			{offset: 0, dir: -1}, {offset: 1, dir: -1}, {offset: 2, dir: -1}, {offset: 3, dir: -1}
		]);
		patternDefinitions.set("trill", [
			{offset: 0, dir: 0}, {offset: 1, dir: 1}, {offset: 2, dir: 0}, {offset: 3, dir: 1}
		]);
	}

	override function create() {
		instance = this;
		GRID_SIZE = GRID_SIZE_DEFAULT;

		definePatterns();
		#if NO_PRELOAD_ALL
		// FOR WHEN COMING IN FROM THE TOOLS PAGE LOL
		if (Assets.getLibrary("shared") == null)
			Assets.loadLibrary("shared").onComplete(function(_) {});
		#end

		camStagePreview = new FlxCamera(0, 0, FlxG.width, FlxG.height);
		camStagePreview.bgColor = 0xFF181818;
		camStagePreview.visible = false;
		FlxG.cameras.insert(camStagePreview, 0);

		camUI = new FlxCamera(0, 0, FlxG.width, FlxG.height);
		camUI.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(camUI, false);

		@:privateAccess FlxCamera._defaultCameras = [FlxG.camera];

		menuBG = new FlxSprite().makeBackground(0xFF181818);

		menuBG.updateHitbox();
		menuBG.screenCenter();
		menuBG.scrollFactor.set();
		add(menuBG);

		// preload hitsounds
		FlxG.sound.cache(Paths.sound('CLAP'));
		FlxG.sound.cache(Paths.sound('SNAP'));

		var characterList = CoolUtil.coolTextFile(Paths.txt('characterList'));

		for (text in characterList) {
			var properties = text.split(":");

			var name = properties[0];
			var mod = properties[1];

			var base_array;

			if (characters.exists(mod))
				base_array = characters.get(mod);
			else
				base_array = [];

			base_array.push(name);
			characters.set(mod, base_array);
		}

		arrayCharacters = ["bf", "gf", ""];
		var defaultChars = characters.get("default");
		if (defaultChars != null) {
			for (item in defaultChars) {
				if (!arrayCharacters.contains(item))
					arrayCharacters.push(item);
			}
		}

		var totalInitCols:Int = 8 + 1;
		var initGridW:Int = GRID_SIZE * totalInitCols;
		var initGridH:Int = GRID_SIZE * 16;
		var initGridX:Float = 240;

		gridBG = new FlxSprite().makeGraphic(initGridW, initGridH, 0xFF272727);
		var initTex = gridBG.pixels;
		var initRect:openfl.geom.Rectangle = new openfl.geom.Rectangle();
		for (cy in 0...16) {
			for (cx in 0...totalInitCols) {
				var col:FlxColor = ((cx + cy) % 2 == 0) ? 0xFF545454 : 0xFF272727;
				initRect.setTo(cx * GRID_SIZE, cy * GRID_SIZE, GRID_SIZE, GRID_SIZE);
				initTex.fillRect(initRect, col);
			}
		}
		gridBG.x = initGridX;
		gridBG.y = 50;
		add(gridBG);

		var gridBGNextW:Int = GRID_SIZE * totalInitCols;
		var gridBGNextH:Int = GRID_SIZE * 16;
		gridBGNext = new FlxSprite().makeGraphic(gridBGNextW, gridBGNextH, 0xFF1A1A1A);
		var initTex2 = gridBGNext.pixels;
		for (cy in 0...16) {
			for (cx in 0...totalInitCols) {
				var col:FlxColor = ((cx + cy) % 2 == 0) ? 0xFF3A3A3A : 0xFF1A1A1A;
				initRect.setTo(cx * GRID_SIZE, cy * GRID_SIZE, GRID_SIZE, GRID_SIZE);
				initTex2.fillRect(initRect, col);
			}
		}
		gridBGNext.x = initGridX;
		gridBGNext.y = gridBG.y + gridBG.height;
		add(gridBGNext);

		waveformSprite = new FlxSprite(gridBG.x, gridBG.y).makeGraphic(1, 1, FlxColor.TRANSPARENT);
		waveformSprite.alpha = 0.5;
		add(waveformSprite);

		leftIcons = [];
		rightIcons = [];

		leftIconLabel = new FlxText(0, 0, 0, "", 12);
		leftIconLabel.setBorderStyle(OUTLINE, FlxColor.BLACK, 1.5);
		rightIconLabel = new FlxText(0, 0, 0, "", 12);
		rightIconLabel.setBorderStyle(OUTLINE, FlxColor.BLACK, 1.5);
		add(leftIconLabel);
		add(rightIconLabel);

		curRenderedNotes = new FlxTypedGroup<Note>();
		curRenderedEvents = new FlxTypedGroup<EventSprite>();
		curRenderedIds = new FlxTypedGroup<FlxSprite>();

		duplicateBoxes = new FlxTypedGroup<FlxSprite>();

		if (PlayState.SONG != null)
			_song = PlayState.SONG;
		else
			_song = SongLoader.loadFromJson("normal", "tutorial");

		if (PlayState.instance == null) {
			PlayState.instance = new PlayState();
		}

		var skinName:String = (_song != null && _song.ui_Skin != null && _song.ui_Skin != "") ? _song.ui_Skin : "default";
		PlayState.instance.setupUISkinConfigs(skinName);

		if (PlayState.instance.arrow_Configs != null) {
			for (k in PlayState.instance.arrow_Configs.keys()) {
				arrow_Configs.set(k, PlayState.instance.arrow_Configs.get(k));
			}
		}

		uiSettings = (PlayState.instance != null && PlayState.instance.ui_settings != null && PlayState.instance.ui_settings.length >= 4)
			? PlayState.instance.ui_settings
			: (Assets.exists(Paths.txt("ui skins/" + skinName + "/config")) ? CoolUtil.coolTextFile(Paths.txt("ui skins/" + skinName + "/config")) : ["0.7", "0", "1.0", "true"]);

		MusicBeatState.windowNameSuffix = " - " + (_song?.song ?? "Unknown Song") + " (Chart Editor)";

		if (PlayState.instance != null && PlayState.instance.baseEvents != null && PlayState.instance.baseEvents.length > 0) {
			for (event in PlayState.instance.baseEvents) {
				events.push(event);
			}
		} else {
			if (_song.events != null) {
				for (event in _song.events) {
					events.push(event);
				}
			}
			
			// Load legacy events if they exist
			if (PlayState.storyDifficultyStr != null && PlayState.storyDifficultyStr != "") {
				difficulty = PlayState.storyDifficultyStr.toLowerCase();
			}
			var diff = difficulty.toLowerCase();
			if (Assets.exists(Paths.songEvents(_song.song.toLowerCase(), diff))) {
				var eventFunnies:Array<Array<Dynamic>> = SongLoader.parseLegacy(
					haxe.Json.parse(Assets.getText(Paths.songEvents(
						_song.song.toLowerCase(),
						diff
					))),
					_song.song
				).events;

				if (eventFunnies != null) {
					for (event in eventFunnies) {
						events.push(event);
					}
				}
			}
		}

		_song.events = [];

		if (PlayState.songMultiplier != 1)
			_song.speed = PlayState.previousScrollSpeed;

		FlxG.mouse.visible = true;

		if (_song != null) {
			if (_song.bpm <= 1.0 || Math.isNaN(_song.bpm)) _song.bpm = 100.0;
			tempBpm = _song.bpm;

			if (_song.notes == null || _song.notes.length == 0) {
				_song.notes = [];
				addSection();
			} else {
				for (sec in _song.notes) {
					if (sec != null && (sec.bpm <= 1.0 || Math.isNaN(sec.bpm))) {
						sec.bpm = _song.bpm;
					}
				}
			}
		} else {
			tempBpm = 100.0;
		}

		loadSong(_song.song);

		Conductor.timeScale = _song.timescale;
		Conductor.changeBPM(_song.bpm);
		Conductor.mapBPMChanges(_song);

		bpmTxt = new FlxText(1000, 50, 0, "", 16);
		bpmTxt.scrollFactor.set();
		bpmTxt.visible = false;
		add(bpmTxt);

		strumLine = new FlxSprite(0, 50).makeGraphic(Std.int(gridBG.width), 4);
		add(strumLine);

		dummyArrow = new FlxSprite().makeGraphic(GRID_SIZE, GRID_SIZE);
		add(dummyArrow);

		// Codename-style note hoverer (ghost note)
		noteHoverer = new FlxSprite().makeGraphic(GRID_SIZE - 4, GRID_SIZE - 4, 0xFFFFFFFF);
		noteHoverer.color = 0xFF994BC2;
		noteHoverer.alpha = 0.4;
		noteHoverer.scrollFactor.set(1, 1);
		add(noteHoverer);

		gridEventReceptors = new FlxTypedGroup<FlxSprite>();
		add(gridEventReceptors);

		add(curRenderedNotes);
		add(curRenderedIds);
		add(duplicateBoxes);
		add(curRenderedEvents);

		var tabs = [
			{name: "Art", label: 'Art'},
			{name: "Chart", label: 'Chart'},
			{name: "Events", label: "Events"},
			{name: "Song", label: 'Song'}
		];

		for (event in CoolUtil.coolTextFile(Paths.txt("eventList"))) {
			if (event == null || StringTools.trim(event) == "") continue;
			var eventData = event.split("~");
			while (eventData.length < 3) eventData.push("");

			eventListData.push(eventData);
			eventList.push(eventData[0]);
		}

		UI_box = new FlxUITabMenu(null, tabs, true);

		UI_box.resize(280, 520);
		UI_box.x = 10;
		UI_box.y = 52;
		UI_box.scrollFactor.set(0, 0);
		add(UI_box);

		beatSnap = 4;

		if (NoteVariables.beats.indexOf(beatSnap) == -1) // error handling i guess
			beatSnap = 4;

		addSongUI();
		addSectionUI();
		addNoteUI();
		addEventUI();
		updateGrid();
		updateHeads();

		changeSection(globalSecton);

		new FlxTimer().start(Options.getData("backupDuration") * 60, _backup, 0);

		autosaveText = new FlxText(10, FlxG.height - 20, 0, "", 12);
		autosaveText.scrollFactor.set();
		autosaveText.setBorderStyle(OUTLINE, FlxColor.BLACK, 1.5);
		add(autosaveText);

		// Codename-style top menu bar (40px height)
		topMenuBar = new FlxSprite(0, 0).makeGraphic(FlxG.width, 48, 0xFF2A2A2A);
		topMenuBar.scrollFactor.set(0, 0);
		topMenuBar.cameras = [camUI];
		add(topMenuBar);

		topMenuHighlight = new FlxSprite(0, 0).makeGraphic(1, 48, FlxColor.WHITE);
		topMenuHighlight.scrollFactor.set(0, 0);
		topMenuHighlight.visible = false;
		topMenuHighlight.cameras = [camUI];
		add(topMenuHighlight);

		var menuLabels:Array<String> = ["File", "Edit", "Chart", "View", "Song", "Note", "Snap", "Playback"];
		topMenuItems = [];
		var mx:Float = 210;
		for (i in 0...menuLabels.length) {
			var lbl = new FlxText(mx, 14, 0, menuLabels[i], 14);
			lbl.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
			lbl.scrollFactor.set(0, 0);
			lbl.borderSize = 1;
			lbl.cameras = [camUI];
			lbl.drawFrame(true);
			var itemWidth:Float = Math.max(lbl.width, menuLabels[i].length * 9.0 + 8);
			lbl.fieldWidth = Std.int(itemWidth);
			lbl.updateHitbox();
			add(lbl);
			topMenuItems.push(lbl);
			mx += itemWidth + 14;
		}

		topInfoTxt = new FlxText(mx + 10, 12, FlxG.width - mx - 20, "", 16);
		topInfoTxt.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, RIGHT, OUTLINE, FlxColor.BLACK);
		topInfoTxt.scrollFactor.set(0, 0);
		topInfoTxt.cameras = [camUI];
		add(topInfoTxt);

		// Numeric readout, sitting directly under the "Speed" line of `topInfoTxt`.
		sideInfoTxt = new FlxText(FlxG.width - 320, 54, 290, "", 18);
		sideInfoTxt.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, RIGHT, OUTLINE, FlxColor.BLACK);
		sideInfoTxt.borderSize = 1.2;
		sideInfoTxt.scrollFactor.set(0, 0);
		sideInfoTxt.cameras = [camUI];
		add(sideInfoTxt);

		// Quant indicator text (hidden to avoid overlapping topInfoTxt)
		quantText = new FlxText(FlxG.width - 200, 7, 0, "", 11);
		quantText.setFormat(Paths.font("vcr.ttf"), 11, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		quantText.scrollFactor.set(0, 0);
		quantText.cameras = [camUI];
		quantText.visible = false;
		add(quantText);

		// Section info text (bottom-right - hidden per user request)
		sectionInfoText = new FlxText(FlxG.width - 300, FlxG.height - 60, 300, "", 11);
		sectionInfoText.setFormat(Paths.font("vcr.ttf"), 11, FlxColor.WHITE, RIGHT, OUTLINE, FlxColor.BLACK);
		sectionInfoText.scrollFactor.set(0, 0);
		sectionInfoText.cameras = [camUI];
		sectionInfoText.visible = false;
		add(sectionInfoText);

		// Scrollbar (right side)
		scrollBarBG = new FlxSprite(FlxG.width - 16, 48).makeGraphic(16, FlxG.height - 48, 0xFF1A1A1A);
		scrollBarBG.scrollFactor.set(0, 0);
		scrollBarBG.alpha = 0.7;
		scrollBarBG.cameras = [camUI];
		add(scrollBarBG);

		scrollBarThumb = new FlxSprite(FlxG.width - 16, 48).makeGraphic(16, 60, 0xFF545454);
		scrollBarThumb.scrollFactor.set(0, 0);
		scrollBarThumb.cameras = [camUI];
		add(scrollBarThumb);

		// Context menu (hidden by default)
		contextMenuGroup = new flixel.group.FlxGroup();
		if (camUI != null) contextMenuGroup.cameras = [camUI];
		add(contextMenuGroup);

		contextMenuBG = new FlxSprite(0, 0).makeGraphic(180, 100, 0xFF1A1A1A);
		contextMenuBG.scrollFactor.set(0, 0);
		contextMenuBG.alpha = 0.95;
		contextMenuBG.visible = false;
		if (camUI != null) contextMenuBG.cameras = [camUI];
		contextMenuGroup.add(contextMenuBG);

		contextMenuItems = [];
		contextMenuActions = [];
		for (i in 0...8) {
			var item = new FlxText(8, 4 + i * 20, 165, "", 11);
			item.setFormat(Paths.font("vcr.ttf"), 11, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
			item.scrollFactor.set(0, 0);
			if (camUI != null) item.cameras = [camUI];
			item.visible = false;
			contextMenuGroup.add(item);
			contextMenuItems.push(item);
			contextMenuActions.push("");
		}

		// Right-side animated Info Box for header descriptions
		var boxW:Int = 400;
		var boxH:Int = 210;
		var boxY:Float = (FlxG.height - boxH) / 2;
		headerInfoTargetX = FlxG.width + 20;

		headerInfoBorder = new FlxSprite(headerInfoTargetX - 2, boxY - 2).makeGraphic(boxW + 4, boxH + 4, 0xFFFFFF00);
		headerInfoBorder.scrollFactor.set(0, 0);
		headerInfoBorder.cameras = [camUI];
		headerInfoBorder.visible = false;
		add(headerInfoBorder);

		headerInfoBox = new FlxSprite(headerInfoTargetX, boxY).makeGraphic(boxW, boxH, 0xEE141414);
		headerInfoBox.scrollFactor.set(0, 0);
		headerInfoBox.cameras = [camUI];
		headerInfoBox.visible = false;
		add(headerInfoBox);

		headerInfoTitle = new FlxText(headerInfoTargetX + 12, boxY + 12, boxW - 24, "", 18);
		headerInfoTitle.setFormat(Paths.font("vcr.ttf"), 18, 0xFFFFFF00, LEFT, OUTLINE, FlxColor.BLACK);
		headerInfoTitle.scrollFactor.set(0, 0);
		headerInfoTitle.cameras = [camUI];
		headerInfoTitle.visible = false;
		add(headerInfoTitle);

		headerInfoDesc = new FlxText(headerInfoTargetX + 12, boxY + 44, boxW - 24, "", 15);
		headerInfoDesc.setFormat(Paths.font("vcr.ttf"), 15, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		headerInfoDesc.scrollFactor.set(0, 0);
		headerInfoDesc.cameras = [camUI];
		headerInfoDesc.visible = false;
		add(headerInfoDesc);

		initMenuDescriptions();

		// Selection box for box selection (Shift+drag)
		selectionBox = new FlxSprite(0, 0).makeGraphic(1, 1, FlxColor.WHITE);
		selectionBox.alpha = 0.2;
		selectionBox.scrollFactor.set(1, 1);
		selectionBox.visible = false;
		add(selectionBox);

		super.create();
		unfocusAllInputs();
	}

	private function _backup(_) {
		backupChart();
		backupEvents();
	}

	#if sys
	private function saveToBackups(data:String, namePrefix:String):Void {
		if (data == null || data.length == 0) return;
		var date:String = StringTools.replace(StringTools.replace(Date.now().toString(), " ", "_"), ":", "'");
		var gamingName = namePrefix + _song.song.toLowerCase();
		if (difficulty.toLowerCase() != 'normal')
			gamingName += '-' + difficulty.toLowerCase();
		var path = "./backups/backup-" + gamingName + '-on-' + date + ".json";
		if (!sys.FileSystem.exists("./backups/"))
			sys.FileSystem.createDirectory("./backups/");
		sys.io.File.saveContent(path, data.trim());
	}

	private function saveToModFolder(data:String, filename:String):Void {
		if (data == null || data.length == 0) return;
		var song:String = _song.song.toLowerCase();
		var diff:String = difficulty.toLowerCase();
		var curMod:String = Options.getData("curMod");
		var folder:String = 'mods/$curMod/data/song data/$song/';
		if (!sys.FileSystem.exists(folder))
			sys.FileSystem.createDirectory(folder);
		sys.io.File.saveContent(folder + filename, data.trim());
	}
	#end

	private function backupChart():Void {
		var json:Dynamic = {"song": _song};
		json.song.events = [];
		#if sys saveToBackups(Json.stringify(json), ""); #end
	}

	private function backupEvents():Void {
		var json:Dynamic = {"song": {"events": []}};
		json.song.events = events;
		#if sys saveToBackups(Json.stringify(json), "events-"); #end
	}

	private function autoSaveChart():Void {
		if (_song != null && (_song.chartType == CODENAME || _song.strumLines != null)) {
			exportCodename();
			return;
		}
		var json:Dynamic = {"song": _song};
		json.song.events = [];
		var data:String = Json.stringify(json);
		var diff:String = difficulty.toLowerCase();
		#if sys saveToModFolder(data, _song.song.toLowerCase() + (diff != 'normal' ? '-$diff' : '') + '.json'); #end
	}

	private function autoSaveEvents():Void {
		var json:Dynamic = {"song": {"events": []}};
		json.song.events = events;
		var data:String = Json.stringify(json);
		var diff:String = difficulty.toLowerCase();
		#if sys saveToModFolder(data, 'events' + (diff != 'normal' ? '-$diff' : '') + '.json'); #end
	}

	function addSongUI():Void {
		// base ui thingy :D
		var tab_group_song:FlxUI = new FlxUI(null, UI_box);
		tab_group_song.name = "Song";

		// interactive

		// inputs
		var UI_songTitle:FlxInputText = new FlxInputText(10, 30, 70, _song.song, 8);
		typingShit = UI_songTitle;
		blockPressWhileTypingOn.push(typingShit);

		var UI_songDiff:FlxInputText = new FlxInputText(10, UI_songTitle.y + UI_songTitle.height + 2, 70, PlayState.storyDifficultyStr, 8);
		swagShit = UI_songDiff;
		blockPressWhileTypingOn.push(swagShit);

		var check_voices:FlxUICheckBox = new FlxUICheckBox(10, UI_songDiff.y + UI_songDiff.height + 1, null, null, "Has voice track", 100);
		check_voices.checked = _song.needsVoices;

		check_voices.callback = function() {
			_song.needsVoices = check_voices.checked;
		};

		var playerHitsoundsBox:FlxUICheckBox = new FlxUICheckBox(check_voices.x + check_voices.width, check_voices.y, null, null, "Player\nHitsounds", 100);
		playerHitsoundsBox.checked = playerHitsounds;

		playerHitsoundsBox.callback = function() {
			playerHitsounds = playerHitsoundsBox.checked;
		};

		var enemyHitsoundsBox:FlxUICheckBox = new FlxUICheckBox(playerHitsoundsBox.x, playerHitsoundsBox.y + playerHitsoundsBox.height + 2, null, null,
			"Enemy\nHitsounds", 100);
		enemyHitsoundsBox.checked = enemyHitsounds;

		enemyHitsoundsBox.callback = function() {
			enemyHitsounds = enemyHitsoundsBox.checked;
		};

		quantBox = new FlxUICheckBox(enemyHitsoundsBox.x + 25, enemyHitsoundsBox.y + enemyHitsoundsBox.height + 2, null, null,
			"Color Quants", 100);
		colorQuantization = quantBox.checked = Options.getData("colorQuantization");

		quantBox.callback = function() {
			colorQuantization = quantBox.checked;
			Options.setData(colorQuantization, "colorQuantization");
			updateGrid();
		};

		var stepperBPM:FlxUINumericStepper = new FlxUINumericStepper(10, check_voices.y + check_voices.height + 5, 0.1, 1, 0.1, 1000, 1);
		stepperBPM.value = Conductor.bpm;
		stepperBPM.name = 'song_bpm';

		var stepperSpeed:FlxUINumericStepper = new FlxUINumericStepper(10, stepperBPM.y + stepperBPM.height, 0.1, 1, 0.1, 10, 1);
		stepperSpeed.value = _song.speed;
		stepperSpeed.name = 'song_speed';

		var stepperKeyCount:FlxUINumericStepper = new FlxUINumericStepper(10, stepperSpeed.y + stepperSpeed.height, 1, 4, 1,
			NoteVariables.maniaDirections.length);
		stepperKeyCount.value = _song.keyCount;
		stepperKeyCount.name = 'song_keycount';

		var stepperPlayerKeyCount:FlxUINumericStepper = new FlxUINumericStepper(stepperKeyCount.x + (stepperKeyCount.width * 2) + 2, stepperKeyCount.y, 1, 4,
			1, NoteVariables.maniaDirections.length);
		stepperPlayerKeyCount.value = _song.playerKeyCount;
		stepperPlayerKeyCount.name = 'song_playerkeycount';

		blockPressWhileTypingOnStepper.push(stepperBPM);
		blockPressWhileTypingOnStepper.push(stepperSpeed);
		blockPressWhileTypingOnStepper.push(stepperKeyCount);
		blockPressWhileTypingOnStepper.push(stepperPlayerKeyCount);

		var check_mute_inst:FlxUICheckBox = new FlxUICheckBox(10, stepperKeyCount.y + stepperKeyCount.height + 10, null, null, "Mute Inst", 55);
		check_mute_inst.checked = muteInstShit;
		check_mute_inst.callback = function() {
			FlxG.sound.music.volume = check_mute_inst.checked ? 0 : 1;
			muteInstShit = check_mute_inst.checked;
		};
		check_mute_inst.callback();

		var check_mute_vocals:FlxUICheckBox = new FlxUICheckBox(check_mute_inst.x + check_mute_inst.width + 4, check_mute_inst.y, null, null, "Mute Vocals",
			65);
		check_mute_vocals.checked = muteVocalShit;
		check_mute_vocals.callback = function() {
			vocals.volume = check_mute_vocals.checked ? 0 : 1;
			muteVocalShit = check_mute_vocals.checked;
		};
		check_mute_vocals.callback();

		#if FLX_PITCH
		slider_playback_speed = new FlxUISlider(this, 'playbackSpeed', 150, 15, 0.1, 2);
		slider_playback_speed.nameLabel.text = 'Playback Speed';
		slider_playback_speed.valueLabel.color = FlxColor.BLACK;
		#end

		var check_char_ids:FlxUICheckBox = new FlxUICheckBox(check_mute_vocals.x + check_mute_vocals.width + 4, check_mute_vocals.y, null, null,
			"Character Ids On Notes", 100);
		check_char_ids.checked = doFunnyNumbers;
		check_char_ids.callback = function() {
			doFunnyNumbers = check_char_ids.checked;
			updateGrid();
		};

		modchart_Input = new FlxInputText(10, check_mute_inst.y + check_mute_inst.height + 2, 70, _song.modchartPath, 8);

		var check_modchart_tools:FlxUICheckBox = new FlxUICheckBox(modchart_Input.x + (modchart_Input.width * 2) + 20, modchart_Input.y, null, null,
			"Modcharting Tools", 100);
		check_modchart_tools.checked = _song.modchartingTools;

		check_modchart_tools.callback = function() {
			_song.modchartingTools = check_modchart_tools.checked;
		};

		cutscene_Input = new FlxInputText(modchart_Input.x, modchart_Input.y + modchart_Input.height + 2, 70, _song.cutscene, 8);
		endCutscene_Input = new FlxInputText(cutscene_Input.x, cutscene_Input.y + cutscene_Input.height + 2, 70, _song.endCutscene, 8);

		blockPressWhileTypingOn.push(modchart_Input);
		blockPressWhileTypingOn.push(cutscene_Input);
		blockPressWhileTypingOn.push(endCutscene_Input);

		var saveButton:FlxButton = new FlxButton(10, 240, "Save", function() {
			saveLevel();
		});

		var saveEventsButton:FlxButton = new FlxButton(saveButton.x + saveButton.width + 10, saveButton.y, "Save Events", function() {
			saveLevel(true);
		});

		var autoSaveChartBtn:FlxButton = new FlxButton(10, saveButton.y + saveButton.height + 2, "Direct Chart", function() {
			autoSaveChart();
			hasUnsavedChanges = false;
			autosaveText.text = "Chart saved!";
			autosaveText.color = FlxColor.LIME;
			new FlxTimer().start(2, function(_) { autosaveText.text = ""; });
		});

		var autoSaveEventsBtn:FlxButton = new FlxButton(autoSaveChartBtn.x + autoSaveChartBtn.width + 10, autoSaveChartBtn.y, "Direct Events", function() {
			autoSaveEvents();
			hasUnsavedChanges = false;
			autosaveText.text = "Events saved!";
			autosaveText.color = FlxColor.LIME;
			new FlxTimer().start(2, function(_) { autosaveText.text = ""; });
		});

		var exportPsychBtn:FlxButton = new FlxButton(10, autoSaveChartBtn.y + autoSaveChartBtn.height + 2, "Export Psych", function() {
			exportPsych();
		});

		var exportCodenameBtn:FlxButton = new FlxButton(exportPsychBtn.x + exportPsychBtn.width + 10, exportPsychBtn.y, "Export CNE", function() {
			exportCodename();
		});

		var reloadSong:FlxButton = new FlxButton(saveButton.x, exportPsychBtn.y + exportPsychBtn.height + 6, "Reload Audio", function() {
			loadSong(_song.song);
		});

		var reloadSongJson:FlxButton = new FlxButton(reloadSong.x + reloadSong.width + 10, reloadSong.y, "Reload JSON", function() {
			loadJson(_song.song.toLowerCase(), difficulty.toLowerCase());
		});

		var loadChartBtn:FlxButton = new FlxButton(reloadSong.x, reloadSong.y + reloadSong.height + 6, 'Load Chart', loadChart);

		var restart = new FlxButton(loadChartBtn.x + loadChartBtn.width + 10, loadChartBtn.y, "Reset Chart", function() {
			for (ii in 0..._song.notes.length) {
				for (i in 0..._song.notes[ii].sectionNotes.length) {
					_song.notes[ii].sectionNotes = [];
				}
			}

			hasUnsavedChanges = true;
			resetSection(true);
		});

		var resetEvents = new FlxButton(loadChartBtn.x, restart.y + restart.height + 6, "Reset Events", function() {
			events = [];
			hasUnsavedChanges = true;
			updateGrid();
		});

		// labels

		var songNameLabel = new FlxText(UI_songTitle.x + UI_songTitle.width + 1, UI_songTitle.y, 0, "Song Name", 9);
		var diffLabel = new FlxText(UI_songDiff.x + UI_songDiff.width + 1, UI_songDiff.y, 0, "Difficulty", 9);

		var bpmLabel = new FlxText(stepperBPM.x + stepperBPM.width + 1, stepperBPM.y, 0, "BPM", 9);
		var speedLabel = new FlxText(stepperSpeed.x + stepperSpeed.width + 1, stepperSpeed.y, 0, "Scroll Speed", 9);
		var keyCountLabel = new FlxText(stepperKeyCount.x + stepperKeyCount.width + 1, stepperKeyCount.y, 0, "Key Count", 9);

		var modChartLabel = new FlxText(modchart_Input.x + modchart_Input.width + 1, modchart_Input.y, 0, "Modchart Path", 9);
		var cutsceneLabel = new FlxText(cutscene_Input.x + cutscene_Input.width + 1, cutscene_Input.y, 0, "Cutscene JSON Name", 9);
		var endCutsceneLabel = new FlxText(endCutscene_Input.x + endCutscene_Input.width + 1, endCutscene_Input.y, 0, "End Cutscene JSON Name", 9);

		var settingsLabel = new FlxText(10, 10, 0, "Setings", 9);
		var actionsLabel = new FlxText(10, 220, 0, "Actions", 9);

		// adding things
		tab_group_song.add(songNameLabel);
		tab_group_song.add(diffLabel);

		tab_group_song.add(bpmLabel);
		tab_group_song.add(speedLabel);
		tab_group_song.add(keyCountLabel);

		tab_group_song.add(modChartLabel);
		tab_group_song.add(cutsceneLabel);
		tab_group_song.add(endCutsceneLabel);

		tab_group_song.add(settingsLabel);
		tab_group_song.add(actionsLabel);

		tab_group_song.add(UI_songTitle);
		tab_group_song.add(UI_songDiff);
		tab_group_song.add(check_voices);
		tab_group_song.add(playerHitsoundsBox);
		tab_group_song.add(enemyHitsoundsBox);
		tab_group_song.add(quantBox);
		tab_group_song.add(check_mute_inst);
		tab_group_song.add(check_mute_vocals);
		tab_group_song.add(check_char_ids);
		tab_group_song.add(modchart_Input);
		tab_group_song.add(check_modchart_tools);
		tab_group_song.add(cutscene_Input);
		tab_group_song.add(endCutscene_Input);
		tab_group_song.add(saveButton);
		tab_group_song.add(saveEventsButton);
		tab_group_song.add(autoSaveChartBtn);
		tab_group_song.add(autoSaveEventsBtn);
		tab_group_song.add(exportPsychBtn);
		tab_group_song.add(exportCodenameBtn);
		tab_group_song.add(reloadSong);
		tab_group_song.add(reloadSongJson);
		tab_group_song.add(loadChartBtn);
		tab_group_song.add(restart);
		tab_group_song.add(resetEvents);
		tab_group_song.add(stepperBPM);
		tab_group_song.add(stepperSpeed);
		tab_group_song.add(stepperKeyCount);
		tab_group_song.add(stepperPlayerKeyCount);
		#if FLX_PITCH
		tab_group_song.add(slider_playback_speed);
		#end

		// final addings
		UI_box.addGroup(tab_group_song);
		UI_box.scrollFactor.set();

		// also this, idk what it does but ehhhh who cares \_(:/)_/
		FlxG.camera.follow(cameraShitThing);
	}

	static var muteInstShit:Bool = false;
	static var muteVocalShit:Bool = false;

	var cameraShitThing:FlxObject = new FlxObject(0, 0, Std.int(FlxG.width / 2), 4);

	var value1:FlxInputText;
	var value2:FlxInputText;

	var valueDescriptions:FlxText;

	var curEvent:Int = 0;

	var eventDropDown:FlxScrollableDropDownMenu;

	function addEventUI():Void {
		// base ui thingy :D
		var tab_group_event = new FlxUI(null, UI_box);
		tab_group_event.name = "Events";

		// interactive

		// dropdown
		eventDropDown = new FlxScrollableDropDownMenu(10, 30, FlxScrollableDropDownMenu.makeStrIdLabelArray(eventList, true), function(event:String) {
			curEvent = Std.parseInt(event);
			eventName = eventList[Std.parseInt(event)];

			if (curSelectedEvent != null) {
				curSelectedEvent[0] = eventName;
				updateGrid();
			}

			valueDescriptions.text = "Value 1 - " + eventListData[curEvent][1] + "\nValue 2 - " + eventListData[curEvent][2] + "\n";
		});

		blockPressWhileScrolling.push(eventDropDown);

		// inputs
		value1 = new FlxInputText(10, 60, 70, eventValue1, 8);
		value2 = new FlxInputText(value1.x + value1.width + 2, value1.y, 70, eventValue2, 8);

		blockPressWhileTypingOn.push(value1);
		blockPressWhileTypingOn.push(value2);

		// labels

		var eventNameLabel = new FlxText(eventDropDown.x + eventDropDown.width + 1, eventDropDown.y, 0, "Event Name", 9);

		valueDescriptions = new FlxText(value1.x, value1.y
			+ value1.height
			+ 2, 290,
			"Value 1 - "
			+ eventListData[curEvent][1] + "\nValue 2 - " + eventListData[curEvent][2] + "\n", 9);

		// adding things
		tab_group_event.add(value1);
		tab_group_event.add(value2);
		tab_group_event.add(valueDescriptions);

		tab_group_event.add(eventDropDown);
		tab_group_event.add(eventNameLabel);

		// final addings
		UI_box.addGroup(tab_group_event);
		UI_box.scrollFactor.set();
	}

	var check_mustHitSection:FlxUICheckBox;
	var check_changeBPM:FlxUICheckBox;
	var stepperSectionBPM:FlxUINumericStepper;
	var check_altAnim:FlxUICheckBox;
	var check_changeTimeScale:FlxUICheckBox;

	var cur_Note_Type:String = "default";

	var copiedSection:Int = 0;

	var arrowTypes:Array<String> = CoolUtil.coolTextFile(Paths.txt("arrowTypes"));

	function addSectionUI():Void {
		// SECTION CREATION
		var tab_group_section = new FlxUI(null, UI_box);
		tab_group_section.name = 'Chart';

		// Section Titles
		var sectionText = new FlxText(10, 10, 0, "Section Options", 9);

		duplicateCountText = new FlxText(10, FlxG.height - 60, 0, "", 9);
		duplicateCountText.color = FlxColor.RED;
		duplicateCountText.scrollFactor.set();

		var detectDuplicatesButton:FlxButton = new FlxButton(10, FlxG.height - 40, "Detect Dups", function() {
			var count = 0;
			var seenKeys:Map<String, Bool> = new Map();
			for (section in _song.notes) {
				if (section == null || section.sectionNotes == null) continue;
				for (note in section.sectionNotes) {
					var key:String = '${note[0]}_${note[1]}';
					if (seenKeys.exists(key)) count++;
					else seenKeys.set(key, true);
				}
			}
			duplicateCountText.text = '${count} dups';
			if (count > 0) {
				showDuplicateBoxes = true;
			}
			updateDuplicateBoxes();
		});

		var deleteDuplicatesButton:FlxButton = new FlxButton(detectDuplicatesButton.x + detectDuplicatesButton.width + 4, FlxG.height - 40, "Del Dups", function() {
			deleteAllDuplicates();
			duplicateCountText.text = '0 dups';
			updateDuplicateBoxes();
		});

		var checkShowDuplicates:FlxUICheckBox = new FlxUICheckBox(deleteDuplicatesButton.x + deleteDuplicatesButton.width + 10, FlxG.height - 40, null, null, "Show", 60);
		checkShowDuplicates.checked = showDuplicateBoxes;
		checkShowDuplicates.callback = function() {
			showDuplicateBoxes = checkShowDuplicates.checked;
			updateDuplicateBoxes();
		};
		checkShowDuplicates.scrollFactor.set();
		detectDuplicatesButton.scrollFactor.set();
		deleteDuplicatesButton.scrollFactor.set();

		// Interactive Stuff

		// Section Section (lol) //

		// numbers
		stepperSectionBPM = new FlxUINumericStepper(10, 100, 0.1, Conductor.bpm, 0.1, 1000, 1);
		stepperSectionBPM.value = Conductor.bpm;
		stepperSectionBPM.name = 'section_bpm';

		var copySectionCount:FlxUINumericStepper = new FlxUINumericStepper(110, 130, 1, 1, -999, 999, 0);

		blockPressWhileTypingOnStepper.push(stepperSectionBPM);
		blockPressWhileTypingOnStepper.push(copySectionCount);

		var copyButton:FlxButton = new FlxButton(10, 130, "Copy last", function() {
				hasUnsavedChanges = true;
			copySection(Std.int(copySectionCount.value));
		});

		var clearSectionButton:FlxButton = new FlxButton(10, 150, "Clear", function() {
			clearSection();
			hasUnsavedChanges = true;
		});

		var clearLeftSectionButton:FlxButton = new FlxButton(clearSectionButton.x + clearSectionButton.width + 2, 150, "Clear Left", function() {
			clearSectionSide(0);
		});

		var clearRightSectionButton:FlxButton = new FlxButton(clearSectionButton.x + clearSectionButton.width + 2, 170, "Clear Right", function() {
			clearSectionSide(1);
		});

		var swapSectionButton:FlxButton = new FlxButton(10, 170, "Swap section", function() {
			var kCounts = getKeyCountsAtSection(curSection);
			var totalK = kCounts.keyCount + kCounts.playerKeyCount;
			for (i in 0..._song.notes[curSection].sectionNotes.length) {
				_song.notes[curSection].sectionNotes[i][1] += kCounts.keyCount;
				_song.notes[curSection].sectionNotes[i][1] %= totalK;
				_song.notes[curSection].sectionNotes[i][5] = getStrumlineIDFromColumn(Std.int(_song.notes[curSection].sectionNotes[i][1]));
			}
			hasUnsavedChanges = true;
			updateGrid();
		});

		var duetSectionButton:FlxButton = new FlxButton(120, 170, "Duet section", function() {
			var side:Int = -1;
			var sectionNotes = _song.notes[curSection].sectionNotes;
			var kCounts = getKeyCountsAtSection(curSection);
			for (i in 0...sectionNotes.length) {
				var noteSide = (sectionNotes[i][1] < kCounts.keyCount) ? 0 : 1;
				if (side > -1 && noteSide != side) {
					return;
				}
				side = noteSide;
			}
			
			if (side > -1) {
				var newNotes = [];
				for (i in 0...sectionNotes.length) {
					var noteCopy:Array<Dynamic> = sectionNotes[i].copy();
					if (side == 0) {
						noteCopy[1] += kCounts.keyCount;
					} else {
						noteCopy[1] -= kCounts.playerKeyCount;
					}
					noteCopy[5] = getStrumlineIDFromColumn(Std.int(noteCopy[1]));
					newNotes.push(noteCopy);
				}
				
				for (n in newNotes) {
					sectionNotes.push(n);
				}
				
				updateGrid();
				hasUnsavedChanges = true;
			}
		});

		// checkboxes
		check_mustHitSection = new FlxUICheckBox(10, 50, null, null, "Camera points at P1", 100);
		check_mustHitSection.name = 'check_mustHit';
		check_mustHitSection.checked = true;

		check_altAnim = new FlxUICheckBox(10, 195, null, null, "Enemy Alt Animation", 100);
		check_altAnim.name = 'check_altAnim';

		check_changeBPM = new FlxUICheckBox(10, 80, null, null, 'Change BPM?', 100);
		check_changeBPM.name = 'check_changeBPM';

		check_changeTimeScale = new FlxUICheckBox(check_mustHitSection.x + check_mustHitSection.width, 50, null, null, 'Change Time Signature?', 100);
		check_changeTimeScale.name = 'check_changeTimeScale';
		check_changeTimeScale.visible = false;
		check_changeTimeScale.alpha = 0;
		check_changeTimeScale.x = 5000000;
		check_changeTimeScale.y = 5000000;

		var stepperSectionTimeScale1 = new FlxUINumericStepper(10, 30, 1, Conductor.timeScale[0], 1, 1000);
		stepperSectionTimeScale1.value = Conductor.timeScale[0];
		stepperSectionTimeScale1.name = 'section_timescale1';

		var stepperSectionTimeScale2 = new FlxUINumericStepper(stepperSectionTimeScale1.x + stepperSectionTimeScale1.width + 2, stepperSectionTimeScale1.y, 1,
			Conductor.timeScale[1], 1, 1000);
		stepperSectionTimeScale2.value = Conductor.timeScale[1];
		stepperSectionTimeScale2.name = 'section_timescale2';

		blockPressWhileTypingOnStepper.push(stepperSectionTimeScale1);
		blockPressWhileTypingOnStepper.push(stepperSectionTimeScale2);

		var copySectionButton:FlxButton = new FlxButton(check_altAnim.x, check_altAnim.y + check_altAnim.height + 6, "Copy Section", function() {
			copiedSection = curSection;
			updateGrid();
		});

		var pasteSectionButton:FlxButton = new FlxButton(copySectionButton.x + copySectionButton.width + 2, copySectionButton.y, "Paste Section", function() {
			pasteSection();
		});

		var copyEventsButton:FlxButton = new FlxButton(copySectionButton.x, copySectionButton.y + copySectionButton.height + 2, "Copy Events", function() {
			copiedEventsSection = curSection;
			copyEvents(curSection);
		});

		var pasteEventsButton:FlxButton = new FlxButton(copyEventsButton.x + copyEventsButton.width + 2, copyEventsButton.y, "Paste Events", function() {
			pasteEvents();
		});

		// Labels for Interactive Stuff
		var noteText = new FlxText(10, 240 + copySectionButton.height + 2, 0, "Note Options", 9);
		var stepperText:FlxText = new FlxText(110 + copySectionCount.width, 130, 0, "Sections back", 9);
		var bpmText:FlxText = new FlxText(12 + stepperSectionBPM.width, 100, 0, "New BPM", 9);

		// end of section section //

		// NOTE SECTION //

		// numbers
		stepperSusLength = new FlxUINumericStepper(10, 260 + copySectionButton.height + 2, Conductor.stepCrochet / 2, 0, 0, 9999);
		stepperSusLength.value = 0;
		stepperSusLength.name = 'note_susLength';

		stepperCharLength = new FlxUINumericStepper(stepperSusLength.x, stepperSusLength.y + stepperSusLength.height + 1, 1, 0, 0, 1000);
		stepperCharLength.value = 0;
		stepperCharLength.name = 'note_char';

		blockPressWhileTypingOnStepper.push(stepperSusLength);
		blockPressWhileTypingOnStepper.push(stepperCharLength);

		// Adding everything in

		var setCharacterLeftSide:FlxButton = new FlxButton(stepperCharLength.x, stepperCharLength.y + stepperCharLength.height + 1, "Char To Left",
			function() {
				characterSectionSide(0, Std.int(stepperCharLength.value));
			});

		var setCharacterRightSide:FlxButton = new FlxButton(setCharacterLeftSide.x + setCharacterLeftSide.width + 2, setCharacterLeftSide.y, "Char To Right",
			function() {
				characterSectionSide(1, Std.int(stepperCharLength.value));
			});

		// dropdown lmao
		var typeDropDown:FlxScrollableDropDownMenu = new FlxScrollableDropDownMenu(setCharacterLeftSide.x, setCharacterLeftSide.y + 40,
			FlxScrollableDropDownMenu.makeStrIdLabelArray(arrowTypes, true), function(type:String) {
				cur_Note_Type = arrowTypes[Std.parseInt(type)];
		});

		characterGroup_Input = new FlxInputText(typeDropDown.x, setCharacterLeftSide.y + 22, 70, "", 8);

		typeDropDown.selectedLabel = cur_Note_Type;

		blockPressWhileScrolling.push(typeDropDown);

		// funny input box

		blockPressWhileTypingOn.push(characterGroup_Input);

		// labels
		var susText = new FlxText(stepperSusLength.x + stepperSusLength.width + 1, stepperSusLength.y, 0, "Sustain note length", 9);
		var charText = new FlxText(stepperCharLength.x + stepperCharLength.width + 1, stepperCharLength.y, 0, "Character", 9);

		var charGroupText = new FlxText(characterGroup_Input.x + characterGroup_Input.width + 1, setCharacterLeftSide.y + setCharacterLeftSide.height, 0,
			"Character Group (seperated by ',')", 9);

		// note stuff
		tab_group_section.add(noteText);

		tab_group_section.add(stepperSusLength);
		tab_group_section.add(susText);

		tab_group_section.add(stepperCharLength);
		tab_group_section.add(charText);

		tab_group_section.add(typeDropDown);

		tab_group_section.add(setCharacterLeftSide);
		tab_group_section.add(setCharacterRightSide);

		tab_group_section.add(characterGroup_Input);
		tab_group_section.add(charGroupText);

		// section stuff
		tab_group_section.add(sectionText);

		tab_group_section.add(bpmText);
		tab_group_section.add(stepperSectionBPM);
		tab_group_section.add(copySectionCount);
		tab_group_section.add(stepperText);
		tab_group_section.add(check_mustHitSection);
		tab_group_section.add(check_altAnim);
		tab_group_section.add(check_changeBPM);
		tab_group_section.add(copyButton);
		tab_group_section.add(clearSectionButton);
		tab_group_section.add(clearLeftSectionButton);
		tab_group_section.add(clearRightSectionButton);
		tab_group_section.add(swapSectionButton);
		tab_group_section.add(duetSectionButton);
		tab_group_section.add(check_changeTimeScale);
		tab_group_section.add(stepperSectionTimeScale1);
		tab_group_section.add(stepperSectionTimeScale2);

		tab_group_section.add(copySectionButton);
		tab_group_section.add(pasteSectionButton);

		tab_group_section.add(copyEventsButton);
		tab_group_section.add(pasteEventsButton);

		// final addition
		UI_box.addGroup(tab_group_section);
	}

	function addNoteUI():Void {
		var tab_group_note = new FlxUI(null, UI_box);
		tab_group_note.name = 'Art';

		// CHARS
		var player1DropDown = new FlxScrollableDropDownMenu(10, 30, FlxScrollableDropDownMenu.makeStrIdLabelArray(arrayCharacters, true),
			function(character:String) {
				_song.player1 = arrayCharacters[Std.parseInt(character)];
				updateHeads();
				if (showStagePreview) reloadStagePreview();
			});

		player1DropDown.selectedLabel = _song.player1;

		var gfDropDown = new FlxScrollableDropDownMenu(10, 50, FlxScrollableDropDownMenu.makeStrIdLabelArray(arrayCharacters, true),
			function(character:String) {
				var charName:String = arrayCharacters[Std.parseInt(character)];
				_song.gf = charName;
				_song.gfVersion = charName;
				_song.player3 = charName;
				if (showStagePreview) reloadStagePreview();
			});

		gfDropDown.selectedLabel = (_song.gf != null && _song.gf != "") ? _song.gf : ((_song.gfVersion != null && _song.gfVersion != "") ? _song.gfVersion : _song.player3);

		var player2DropDown = new FlxScrollableDropDownMenu(10, 70, FlxScrollableDropDownMenu.makeStrIdLabelArray(arrayCharacters, true),
			function(character:String) {
				_song.player2 = arrayCharacters[Std.parseInt(character)];
				updateHeads();
				if (showStagePreview) reloadStagePreview();
			});

		player2DropDown.selectedLabel = _song.player2;

		blockPressWhileScrolling.push(player1DropDown);
		blockPressWhileScrolling.push(gfDropDown);
		blockPressWhileScrolling.push(player2DropDown);

		// OTHER
		var stages:Array<String> = CoolUtil.coolTextFile(Paths.txt('stageList'));

		var stageDropDown = new FlxScrollableDropDownMenu(10, 120, FlxScrollableDropDownMenu.makeStrIdLabelArray(stages, true), function(stage:String) {
			_song.stage = stages[Std.parseInt(stage)];
			if (showStagePreview) reloadStagePreview();
		});

		stageDropDown.selectedLabel = _song.stage;

		blockPressWhileScrolling.push(stageDropDown);

		var uiSkins:Array<String> = CoolUtil.coolTextFile(Paths.txt('uiSkinList'));

		var uiSkinDropDown = new FlxScrollableDropDownMenu(10, stageDropDown.y + 20, FlxScrollableDropDownMenu.makeStrIdLabelArray(uiSkins, true),
			function(uiSkin:String) {
				_song.ui_Skin = uiSkins[Std.parseInt(uiSkin)];
				if (PlayState.instance == null) PlayState.instance = new PlayState();
				PlayState.instance.setupUISkinConfigs(_song.ui_Skin);
				uiSettings = PlayState.instance.ui_settings;
				while (curRenderedNotes.members.length > 0) {
					curRenderedNotes.remove(curRenderedNotes.members[0], true);
				}

				while (curRenderedEvents.members.length > 0) {
					curRenderedEvents.remove(curRenderedEvents.members[0], true);
				}

				updateGrid();
			});

		uiSkinDropDown.selectedLabel = _song.ui_Skin;

		blockPressWhileScrolling.push(uiSkinDropDown);

		var mods:Array<String> = [];

		var iterator = characters.keys();

		for (i in iterator) {
			mods.push(i);
		}

		var modDropDown = new FlxScrollableDropDownMenu(uiSkinDropDown.x, uiSkinDropDown.y + 20, FlxScrollableDropDownMenu.makeStrIdLabelArray(mods, true),
			function(mod:String) {
				selected_mod = mods[Std.parseInt(mod)];

				arrayCharacters = ["bf", "gf", ""];
				var tempCharacters = characters.get(selected_mod);

				if (tempCharacters != null) {
					for (Item in tempCharacters) {
						arrayCharacters.push(Item);
					}
				}

				var character_Data_List = FlxScrollableDropDownMenu.makeStrIdLabelArray(arrayCharacters, true);

				player1DropDown.setData(character_Data_List);
				gfDropDown.setData(character_Data_List);
				player2DropDown.setData(character_Data_List);

				player1DropDown.selectedLabel = _song.player1;
				gfDropDown.selectedLabel = _song.gf;
				player2DropDown.selectedLabel = _song.player2;
			});

		modDropDown.selectedLabel = selected_mod;

		blockPressWhileScrolling.push(modDropDown);

		// LABELS
		var characterLabel = new FlxText(10, 10, 0, "Characters", 9);
		var otherLabel = new FlxText(10, 100, 0, "Other", 9);

		var p1Label = new FlxText(12 + player1DropDown.width, player1DropDown.y, 0, "Player 1", 9);
		var gfLabel = new FlxText(12 + gfDropDown.width, gfDropDown.y, 0, "Girlfriend", 9);
		var p2Label = new FlxText(12 + player2DropDown.width, player2DropDown.y, 0, "Player 2", 9);
		var stageLabel = new FlxText(12 + stageDropDown.width, stageDropDown.y, 0, "Stage", 9);
		var uiSkinLabel = new FlxText(12 + uiSkinDropDown.width, uiSkinDropDown.y, 0, "UI Skin", 9);
		var modLabel = new FlxText(12 + modDropDown.width, modDropDown.y, 0, "Current Character Group", 9);

		// adding labels
		tab_group_note.add(characterLabel);
		tab_group_note.add(otherLabel);

		tab_group_note.add(p1Label);
		tab_group_note.add(gfLabel);
		tab_group_note.add(p2Label);
		tab_group_note.add(stageLabel);
		tab_group_note.add(uiSkinLabel);
		tab_group_note.add(modLabel);

		// adding main dropdowns
		tab_group_note.add(modDropDown);
		tab_group_note.add(uiSkinDropDown);
		tab_group_note.add(stageDropDown);
		tab_group_note.add(player2DropDown);
		tab_group_note.add(gfDropDown);
		tab_group_note.add(player1DropDown);

		// final add
		UI_box.addGroup(tab_group_note);
	}

	var addedVocals:Array<String> = [];

	function loadSong(daSong:String):Void {
		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();

		if (vocals != null) {
			while (vocals.members.length > 0) {
				vocals.members[0].destroy();
				vocals.remove(vocals.members[0]);
			}
		}

		addedVocals.resize(0);
		lastVoicesAssetPaths = [];

		var difficulty_name:String = _song.specialAudioName == null ? difficulty.toLowerCase() : _song.specialAudioName;

		if (openfl.Assets.cache.hasSound(Paths.inst(daSong, difficulty_name)))
			openfl.Assets.cache.removeSound(Paths.inst(daSong, difficulty_name));

		if (openfl.Assets.cache.hasSound(Paths.voices(daSong, difficulty_name)))
			openfl.Assets.cache.removeSound(Paths.voices(daSong, difficulty_name));

		
		lastInstAssetPath = Paths.inst(daSong, _song.specialAudioName ?? difficulty_name, _song.player1);
		if (lastInstAssetPath == null || !openfl.utils.Assets.exists(lastInstAssetPath)) {
			var fallbackInst:String = Paths.inst(daSong, difficulty.toLowerCase());
			if (fallbackInst != null && openfl.utils.Assets.exists(fallbackInst)) {
				lastInstAssetPath = fallbackInst;
			} else {
				fallbackInst = Paths.inst(daSong);
				if (fallbackInst != null && openfl.utils.Assets.exists(fallbackInst)) {
					lastInstAssetPath = fallbackInst;
				}
			}
		}
		// The removes above drop the id on purpose so the editor re-reads the file,
		// which means the cache has to be refilled before `loadEmbedded`, or the
		// preview comes up silent.
		system.OptimizedAssets.ensureSoundCached(lastInstAssetPath);
		FlxG.sound.music = new FlxSound().loadEmbedded(lastInstAssetPath);
		FlxG.sound.music.persist = true;

		vocals = new SoundGroup(2);
		if (_song.needsVoices) {
			for (character in ['player', 'opponent', _song.player1, _song.player2]) {
				var soundPath:String = Paths.voices(daSong, _song.specialAudioName ?? difficulty_name, character, _song.player1);
				if (soundPath != null && openfl.utils.Assets.exists(soundPath) && !addedVocals.contains(soundPath)) {
					system.OptimizedAssets.ensureSoundCached(soundPath);
					vocals.add(FlxG.sound.list.add(new FlxSound().loadEmbedded(soundPath)));
					lastVoicesAssetPaths.push(soundPath);
					addedVocals.push(soundPath);
				}
			}
			if (addedVocals.length == 0) {
				var soundPath:String = Paths.voices(daSong, _song.specialAudioName ?? difficulty_name);
				if (soundPath == null || !openfl.utils.Assets.exists(soundPath)) {
					soundPath = Paths.voices(daSong, difficulty.toLowerCase());
				}
				if (soundPath == null || !openfl.utils.Assets.exists(soundPath)) {
					soundPath = Paths.voices(daSong);
				}
				if (soundPath != null && openfl.utils.Assets.exists(soundPath) && !addedVocals.contains(soundPath)) {
					system.OptimizedAssets.ensureSoundCached(soundPath);
					vocals.add(FlxG.sound.list.add(new FlxSound().loadEmbedded(soundPath)));
					lastVoicesAssetPaths.push(soundPath);
					addedVocals.push(soundPath);
				}
			}
		}

		FlxG.sound.music.pause();
		vocals.pause();

		FlxG.sound.music.onComplete = function() {
			try {
				if (vocals != null) vocals.pause();
		} catch (e:Dynamic) { Main.logSilentError(e, "ChartingState: pause vocals on song end"); }
		Conductor.songPosition = 0;
		if (FlxG.sound.music != null) FlxG.sound.music.time = 0;
		try {
			changeSection(0, true);
		} catch (e:Dynamic) { Main.logSilentError(e, "ChartingState: changeSection on song end"); }
		};
	}

	#if FLX_PITCH
	var slider_playback_speed:FlxUISlider;

	/**
	 * The playback speed of the current chart.
	 */
	var playbackSpeed:Float = 1;
	#end

	override function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>) {
		if (id == FlxUICheckBox.CLICK_EVENT) {
			var check:FlxUICheckBox = cast sender;
			var label = (check != null && check.getLabel() != null) ? check.getLabel().text : "";

			if (check == check_mustHitSection || check.name == 'check_mustHit' || label == 'Camera points at P1' || label == 'Must Hit Section') {
				if (_song.notes[curSection].mustHitSection != check.checked) {
					var oldMustHit:Bool = _song.notes[curSection].mustHitSection;
					var newMustHit:Bool = check.checked;
					_song.notes[curSection].mustHitSection = newMustHit;
					if (_song.notes[curSection].sectionNotes != null) {
						var kCounts = getKeyCountsAtSection(curSection);
						var kCount:Int = (kCounts.keyCount > 0) ? kCounts.keyCount : 4;
						var pkCount:Int = (kCounts.playerKeyCount > 0) ? kCounts.playerKeyCount : 4;
						for (n in _song.notes[curSection].sectionNotes) {
							var oldData:Int = Std.int(n[1]);
							var newData:Int;
							if (!oldMustHit && newMustHit) {
								// false→true: opp(0..kC-1) shifts +pKC, player(kC..total-1) shifts -kC
								newData = (oldData < kCount) ? (oldData + pkCount) : (oldData - kCount);
							} else if (oldMustHit && !newMustHit) {
								// true→false: opp(pKC..total-1) shifts -pKC, player(0..pKC-1) shifts +kC
								newData = (oldData >= pkCount) ? (oldData - pkCount) : (oldData + kCount);
							} else {
								newData = oldData;
							}
							var totalCols:Int = kCount + pkCount;
							n[1] = ((newData % totalCols) + totalCols) % totalCols;
						}
					}
					hasUnsavedChanges = true;
					updateHeads();
					updateGrid();
					updateStagePreviewCamera(0.0);
				}
			} else if (check == check_changeBPM || check.name == 'check_changeBPM' || label == 'Change BPM?') {
				if (_song.notes[curSection].bpm < 0.1)
					_song.notes[curSection].bpm = 0.1;

				_song.notes[curSection].changeBPM = check.checked;
				hasUnsavedChanges = true;

				Conductor.mapBPMChanges(_song);

				if (_song.notes[curSection].changeBPM)
					Conductor.changeBPM(_song.notes[curSection].bpm);

				updateGrid();
			} else if (check == check_changeTimeScale || check.name == 'check_changeTimeScale' || label == 'Change Time Signature?') {
				if (_song.notes[curSection].timeScale == null)
					_song.notes[curSection].timeScale = Conductor.timeScale;

				if (_song.notes[curSection].timeScale[0] < 1)
					_song.notes[curSection].timeScale[0] = 1;

				if (_song.notes[curSection].timeScale[1] < 1)
					_song.notes[curSection].timeScale[1] = 1;

				_song.notes[curSection].changeTimeScale = check.checked;
				hasUnsavedChanges = true;

				Conductor.mapBPMChanges(_song);

				if (_song.notes[curSection].changeTimeScale)
					Conductor.timeScale = _song.notes[curSection].timeScale;

				updateGrid();
			} else if (check == check_altAnim || check.name == 'check_altAnim' || label == "Enemy Alt Animation") {
				_song.notes[curSection].altAnim = check.checked;
				hasUnsavedChanges = true;
			}
		} else if (id == FlxUINumericStepper.CHANGE_EVENT && (sender is FlxUINumericStepper)) {
			var nums:FlxUINumericStepper = cast sender;
			var wname = nums.name;
			FlxG.log.add(wname);

			switch (wname) {
				case 'section_length':
					_song.notes[curSection].lengthInSteps = Std.int(nums.value);
					Conductor.mapBPMChanges(_song);
					Conductor.syncBPM(sectionStartTime(curSection));
					updateGrid();
				case 'song_speed':
					_song.speed = nums.value;
				case 'song_keycount':
					_song.keyCount = Std.int(nums.value);
					refreshCursorSprites();
					updateGrid();
					updateHeads();
				case 'song_playerkeycount':
					_song.playerKeyCount = Std.int(nums.value);
					refreshCursorSprites();
					updateGrid();
					updateHeads();
				case 'song_bpm':
					if (nums.value < 0.1)
						nums.value = 0.1;

					tempBpm = nums.value;
					Conductor.mapBPMChanges(_song);
					Conductor.changeBPM(nums.value);
				case 'note_susLength':
					curSelectedNote[2] = nums.value;
					updateGrid();
				case 'note_char':
					current_Note_Character = Std.int(nums.value);
				case 'section_bpm':
					if (nums.value < 0.1)
						nums.value = 0.1;

					_song.notes[curSection].bpm = nums.value;

					// typing a new tempo here has to flag the section, otherwise the
					// value is stored but never applied to the timeline
					_song.notes[curSection].changeBPM = true;

					Conductor.mapBPMChanges(_song);
					Conductor.changeBPM(nums.value);
					Conductor.syncBPM(sectionStartTime(curSection));

					updateSectionUI();
					updateGrid();
				case 'section_timescale1':
					var val = Std.int(nums.value);

					if (val < 1)
						val = 1;

					// _song.notes[curSection].timeScale[0] = val;
					_song.timescale[0] = val;
					Conductor.timeScale = _song.timescale;

					Conductor.mapBPMChanges(_song);

					updateGrid();
				case 'section_timescale2':
					var val = Std.int(nums.value);

					if (val < 1)
						val = 1;

					// _song.notes[curSection].timeScale[1] = val;
					_song.timescale[1] = val;
					Conductor.timeScale = _song.timescale;

					Conductor.mapBPMChanges(_song);

					updateGrid();
			}
		} else if (id == FlxUISlider.CHANGE_EVENT && (sender is FlxUISlider)) {
			playbackSpeed = #if FLX_PITCH Std.int(slider_playback_speed.value) #else 1.0 #end;
		}
	}

	var updatedSection:Bool = false;

	function openTopSubmenu(category:String, mx:Float, my:Float):Void {
		var items:Array<String> = [];
		var actions:Array<String> = [];

		switch (category) {
			case "File":
				items = [
					"Save (Ctrl+S)",
					"Save As (Ctrl+Shift+S)",
					"Save Global Events (Ctrl+B+S)",
					"Save Metadata (Ctrl+M+S)",
					"---",
					"Export Codename CNE",
					"Export Psych",
					"Export FNF Legacy",
					"Export Lua to Psych Format",
					"---",
					"Exit"
				];
				actions = [
					"save", "save_as", "save_events", "save_meta",
					"none",
					"export_cne", "export_psych", "export_legacy", "export_lua_psych",
					"none",
					"exit"
				];

			case "Edit":
				items = [
					"Undo (Ctrl+Z)",
					"Redo (Ctrl+Y)",
					"---",
					"Copy Section (Ctrl+C)",
					"Paste Section (Ctrl+V)",
					"Cut Section (Ctrl+X)",
					"Delete Note (Delete)",
					"Delete Stacked Notes (Shift+Delete)",
					"---",
					"Select All Notes (Ctrl+A)",
					"Clear Current Section",
					"Clear Entire Chart",
					"Remove Duplicates"
				];
				actions = [
					"undo", "redo", "none",
					"copy", "paste", "cut", "delete", "delete_stacked",
					"none",
					"select_all", "clear_section", "clear_all_notes", "remove_duplicates"
				];

			case "Chart":
				items = [
					"Playtest (Enter)",
					"Playtest Here (Shift+Enter)",
					"Playtest Preview SubState",
					"Playtest Preview Here SubState",
					"Playtest Opponent (Ctrl+Enter)",
					"Playtest Opponent Here (Ctrl+Shift+Enter)",
					"---",
					"Edit Song Data (Song Tab)",
					"Edit Section Data (Section Tab)",
					"Edit Events (Events Tab)"
				];
				actions = [
					"playtest", "playtest_here", "playtest_preview", "playtest_preview_here",
					"playtest_opponent", "playtest_opponent_here",
					"none",
					"edit_song_data", "edit_section_data", "edit_events_data"
				];

			case "View":
				items = [
					"Zoom In (Ctrl++)",
					"Zoom Out (Ctrl+-)",
					"Reset Zoom (Ctrl+0)",
					"---",
					"Grid Size + (Ctrl+Shift++)",
					"Grid Size - (Ctrl+Shift+-)",
					"Reset Grid Size (Ctrl+Shift+0)",
					"---",
					"Grid Alpha +",
					"Grid Alpha -",
					"Reset Grid Alpha",
					"---",
					"Toggle Gameplay/Stage Preview",
					"Toggle Color Quants",
					"Toggle Duplicate Boxes",
					"Toggle Waveforms",
					"---",
					"Scroll Left (Shift+Left)",
					"Scroll Right (Shift+Right)",
					"Scroll Reset (Shift+Down)"
				];
				actions = [
					"zoom_in", "zoom_out", "zoom_reset",
					"none",
					"grid_size_up", "grid_size_down", "grid_size_reset",
					"none",
					"grid_alpha_up", "grid_alpha_down", "grid_alpha_reset",
					"none",
					"toggle_stage_preview",
					"toggle_quantization",
					"toggle_duplicates", "toggle_waveforms",
					"none",
					"scroll_left", "scroll_right", "scroll_reset"
				];

			case "Song":
				items = [
					"Toggle Vocals Mute",
					"Toggle Inst Mute",
					"---",
					"Playback 0.25x",
					"Playback 0.5x",
					"Playback 0.75x",
					"Playback 1.0x (Normal)",
					"Playback 1.25x",
					"Playback 1.5x",
					"Playback 2.0x",
					"---",
					"Player Hitsounds (" + (playerHitsounds ? "ON" : "OFF") + ")",
					"Opponent Hitsounds (" + (enemyHitsounds ? "ON" : "OFF") + ")"
				];
				actions = [
					"mute_vocals", "mute_inst", "none",
					"speed_025", "speed_05", "speed_075", "speed_10", "speed_125", "speed_15", "speed_20",
					"none",
					"toggle_player_hitsounds", "toggle_enemy_hitsounds"
				];

			case "Note":
				items = [
					"Default Note",
					"Alt Animation Note",
					"Hurt Note",
					"Hey Note"
				];
				actions = [
					"note_default", "note_alt", "note_hurt", "note_hey"
				];

			case "Snap":
				items = [
					"1/4 (4)", "1/8 (8)", "1/12 (12)", "1/16 (16)",
					"1/20 (20)", "1/24 (24)", "1/32 (32)", "1/48 (48)", "1/64 (64)", "1/192 (192)"
				];
				actions = [
					"snap_4", "snap_8", "snap_12", "snap_16",
					"snap_20", "snap_24", "snap_32", "snap_48", "snap_64", "snap_192"
				];

			case "Playback":
				items = [
					"Play / Pause (Space)",
					"Speed Up (.)",
					"Reset Speed",
					"Slow Down (,)",
					"---",
					"Section Back (A)",
					"Section Forward (D)",
					"Step Back (W)",
					"Step Forward (S)"
				];
				actions = [
					"playback_play", "playback_speed_up", "playback_speed_reset", "playback_speed_down",
					"none",
					"section_back", "section_forward", "step_back", "step_forward"
				];
		}

		showDropdownMenu(mx, my, items, actions);
	}

	function showContextMenu(mx:Float, my:Float):Void {
		var onGrid:Bool = mx >= gridBG.x && mx < gridBG.x + gridBG.width && my >= gridBG.y;

		var items:Array<String> = [];
		var actions:Array<String> = [];
		if (onGrid) {
			items.push("Add Note");
			actions.push("add_note");
			items.push("Add Event");
			actions.push("add_event");
			items.push("Delete Note");
			actions.push("delete_note");
		} else {
			items.push("Add Event Here");
			actions.push("add_event");
		}
		items.push("---");
		actions.push("none");
		items.push("Select All");
		actions.push("select_all");
		items.push("Clear Section");
		actions.push("clear_section");
		items.push("---");
		actions.push("none");
		items.push("Change BPM Here");
		actions.push("change_bpm");

		for (ev in eventList) {
			items.push(ev);
			actions.push('event:$ev');
		}

		showDropdownMenu(mx, my, items, actions);
	}

	function showDropdownMenu(mx:Float, my:Float, items:Array<String>, actions:Array<String>):Void {
		contextMenuVisible = true;
		contextMenuBG.visible = true;

		var totalItems:Int = items.length;

		// Dynamically measure the maximum text width so strings never wrap or overflow
		var dummy = new FlxText(0, 0, 0, "");
		dummy.setFormat(Paths.font("vcr.ttf"), 12);
		var maxW:Float = 260;
		for (str in items) {
			if (str == "---") continue;
			dummy.text = str;
			var w:Float = dummy.textField.textWidth + 36;
			if (w > maxW)
				maxW = w;
		}
		dummy.destroy();

		var totalH:Float = totalItems * 22 + 8;

		// Clamp within screen boundaries so the dropdown never spills off-screen
		if (mx + maxW > FlxG.width - 8)
			mx = FlxG.width - maxW - 8;
		if (mx < 8)
			mx = 8;

		if (my + totalH > FlxG.height - 8)
			my = FlxG.height - totalH - 8;
		if (my < 8)
			my = 8;

		contextMenuBG.x = mx;
		contextMenuBG.y = my;
		if (camUI != null) contextMenuBG.cameras = [camUI];

		contextMenuBG.makeGraphic(Std.int(maxW), Std.int(totalH), 0xFF1A1A1A, true);

		while (contextMenuItems.length < totalItems) {
			var item = new FlxText(0, 0, Std.int(maxW - 16), "", 12);
			item.setFormat(Paths.font("vcr.ttf"), 12, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
			item.scrollFactor.set(0, 0);
			if (camUI != null) item.cameras = [camUI];
			if (contextMenuGroup != null) contextMenuGroup.add(item);
			contextMenuItems.push(item);
			contextMenuActions.push("");
		}

		// Ensure the entire context menu layer is in front of all other UI layers
		if (contextMenuGroup != null) {
			remove(contextMenuGroup);
			add(contextMenuGroup);
		}

		for (i in 0...contextMenuItems.length) {
			if (i < totalItems) {
				contextMenuItems[i].wordWrap = false;
				contextMenuItems[i].autoSize = false;
				contextMenuItems[i].fieldWidth = maxW - 16;
				contextMenuItems[i].text = items[i];
				contextMenuItems[i].x = mx + 8;
				contextMenuItems[i].y = my + 4 + i * 22;
				contextMenuItems[i].visible = true;
				contextMenuItems[i].color = (items[i] == "---") ? 0xFF888888 : FlxColor.WHITE;
				if (camUI != null) contextMenuItems[i].cameras = [camUI];
				contextMenuActions[i] = actions[i];
			} else {
				contextMenuItems[i].visible = false;
				contextMenuActions[i] = "";
			}
		}
	}

	function hideContextMenu():Void {
		contextMenuVisible = false;
		if (contextMenuBG != null) contextMenuBG.visible = false;
		if (contextMenuItems != null) {
			for (item in contextMenuItems) {
				if (item != null) item.visible = false;
			}
		}
	}

	function handleContextMenuClick(mx:Float, my:Float):Void {
		if (contextMenuItems == null || contextMenuBG == null) {
			hideContextMenu();
			return;
		}
		var bgX:Float = contextMenuBG.x;
		var bgY:Float = contextMenuBG.y;
		var bgW:Float = contextMenuBG.width;
		var bgH:Float = contextMenuBG.height;

		if (mx >= bgX && mx <= bgX + bgW && my >= bgY && my <= bgY + bgH) {
			for (i in 0...contextMenuItems.length) {
				var item = contextMenuItems[i];
				if (!item.visible || item.text == "---") continue;
				if (my >= item.y - 3 && my <= item.y + 19) {
					var action = contextMenuActions[i];
					hideContextMenu();
					if (action != "none" && action != "") {
						executeContextMenuAction(action);
					}
					return;
				}
			}
		}
		hideContextMenu();
	}

	function executeContextMenuAction(action:String):Void {
		switch (action) {
			case "save":
				saveLevel(false);
			case "save_as":
				exportCodename();
			case "save_events":
				saveLevel(true);
			case "save_meta":
				saveLevel(false);
			case "export_cne":
				exportCodename();
			case "export_psych":
				exportPsych();
			case "export_legacy":
				exportPsych();
			case "export_lua_psych":
				openSubState(new substates.LuaPsychConverterSubstate(_song != null ? _song.song : ""));
			case "exit":
				FlxG.sound.music.stop();
				if (vocals != null) vocals.stop();
				FlxG.switchState(() -> new toolbox.CharterSelectionState());

			case "undo":
				performUndo();
			case "redo":
				performRedo();
			case "copy":
				copySection();
			case "paste":
				pasteSection();
			case "cut":
				copySection();
				clearSection();
			case "delete":
				if (curSelectedNote != null) {
					for (i in _song.notes[curSection].sectionNotes) {
						if (i == curSelectedNote) {
							_song.notes[curSection].sectionNotes.remove(i);
							break;
						}
					}
					curSelectedNote = null;
					hasUnsavedChanges = true;
					updateGrid();
				}
			case "delete_stacked":
				deleteAllDuplicates();
			case "select_all":
				selectAll();
			case "clear_section":
				clearSection();
			case "clear_all_notes":
				for (sec in _song.notes) sec.sectionNotes = [];
				hasUnsavedChanges = true;
				updateGrid();
			case "remove_duplicates":
				deleteAllDuplicates();

			case "playtest":
				playtestChart(0, false);
			case "playtest_here":
				playtestChart(1, false);
			case "playtest_preview":
				playtestChart(0, false);
			case "playtest_preview_here":
				playtestChart(1, false);
			case "playtest_opponent":
				playtestChart(0, true);
			case "playtest_opponent_here":
				playtestChart(1, true);
			case "edit_song_data":
				UI_box.selected_tab = 0;
			case "edit_section_data":
				UI_box.selected_tab = 1;
			case "edit_events_data":
				openEventEditor(Conductor.songPosition);
			case "edit_metadata":
				UI_box.selected_tab = 0;

			case "zoom_in":
				zoomLevel = Math.min(MAX_ZOOM, zoomLevel + 0.25);
				updateGrid();
			case "zoom_out":
				zoomLevel = Math.max(MIN_ZOOM, zoomLevel - 0.25);
				updateGrid();
			case "zoom_reset":
				zoomLevel = 1.0;
				updateGrid();
			case "grid_size_up":
				GRID_SIZE = Std.int(Math.min(GRID_SIZE_MAX, GRID_SIZE + 5));
				refreshCursorSprites();
				updateGrid();
				updateHeads();
			case "grid_size_down":
				GRID_SIZE = Std.int(Math.max(GRID_SIZE_MIN, GRID_SIZE - 5));
				refreshCursorSprites();
				updateGrid();
				updateHeads();
			case "grid_size_reset":
				GRID_SIZE = GRID_SIZE_DEFAULT;
				refreshCursorSprites();
				updateGrid();
				updateHeads();
			case "grid_alpha_up":
				gridAlpha = Math.min(GRID_ALPHA_MAX, gridAlpha + 0.1);
				applyGridAlpha(gridAlpha);
			case "grid_alpha_down":
				gridAlpha = Math.max(GRID_ALPHA_MIN, gridAlpha - 0.1);
				applyGridAlpha(gridAlpha);
			case "grid_alpha_reset":
				gridAlpha = GRID_ALPHA_DEFAULT;
				applyGridAlpha(gridAlpha);
			case "toggle_stage_preview":
				toggleStagePreview();
			case "toggle_quantization":
				colorQuantization = !colorQuantization;
				Options.setData(colorQuantization, "colorQuantization");
				if (quantBox != null) quantBox.checked = colorQuantization;
				updateGrid();
			case "toggle_duplicates":
				showDuplicateBoxes = !showDuplicateBoxes;
				updateDuplicateBoxes();
			case "toggle_waveforms":
				waveformEnabled = !waveformEnabled;
				updateWaveform();
			case "scroll_left":
				gridBG.x = Math.max(10, gridBG.x - 30);
				updateGrid();
			case "scroll_right":
				gridBG.x = Math.min(FlxG.width - gridBG.width - 10, gridBG.x + 30);
				updateGrid();
			case "scroll_reset":
				gridBG.screenCenter(X);
				updateGrid();

			case "mute_vocals":
				if (vocals != null) vocals.volume = (vocals.volume > 0 ? 0 : 1);
			case "mute_inst":
				if (FlxG.sound.music != null) FlxG.sound.music.volume = (FlxG.sound.music.volume > 0 ? 0 : 1);
			case "speed_025": setSongSpeed(0.25);
			case "speed_05": setSongSpeed(0.5);
			case "speed_075": setSongSpeed(0.75);
			case "speed_10": setSongSpeed(1.0);
			case "speed_125": setSongSpeed(1.25);
			case "speed_15": setSongSpeed(1.5);
			case "speed_20": setSongSpeed(2.0);
			case "toggle_player_hitsounds":
				playerHitsounds = !playerHitsounds;
			case "toggle_enemy_hitsounds":
				enemyHitsounds = !enemyHitsounds;

			case "note_default":
				cur_Note_Type = "default";
			case "note_alt":
				cur_Note_Type = "alt-anim";
			case "note_hurt":
				cur_Note_Type = "hurt";
			case "note_hey":
				cur_Note_Type = "hey";

			case "snap_4":
				beatSnap = 4; if (quantText != null) quantText.text = "Snap: 1/4"; updateGrid();
			case "snap_8":
				beatSnap = 8; if (quantText != null) quantText.text = "Snap: 1/8"; updateGrid();
			case "snap_12":
				beatSnap = 12; if (quantText != null) quantText.text = "Snap: 1/12"; updateGrid();
			case "snap_16":
				beatSnap = 16; if (quantText != null) quantText.text = "Snap: 1/16"; updateGrid();
			case "snap_20":
				beatSnap = 20; if (quantText != null) quantText.text = "Snap: 1/20"; updateGrid();
			case "snap_24":
				beatSnap = 24; if (quantText != null) quantText.text = "Snap: 1/24"; updateGrid();
			case "snap_32":
				beatSnap = 32; if (quantText != null) quantText.text = "Snap: 1/32"; updateGrid();
			case "snap_48":
				beatSnap = 48; if (quantText != null) quantText.text = "Snap: 1/48"; updateGrid();
			case "snap_64":
				beatSnap = 64; if (quantText != null) quantText.text = "Snap: 1/64"; updateGrid();
			case "snap_192":
				beatSnap = 192; if (quantText != null) quantText.text = "Snap: 1/192"; updateGrid();

			case "playback_play":
				togglePlayback();
			case "playback_speed_up":
				var newP = FlxMath.roundDecimal(Math.min(3.0, FlxG.sound.music.pitch + 0.25), 2);
				FlxG.sound.music.pitch = newP;
				if (vocals != null) vocals.pitch = newP;
			case "playback_speed_reset":
				FlxG.sound.music.pitch = 1.0;
				if (vocals != null) vocals.pitch = 1.0;
			case "playback_speed_down":
				var newP = FlxMath.roundDecimal(Math.max(0.25, FlxG.sound.music.pitch - 0.25), 2);
				FlxG.sound.music.pitch = newP;
				if (vocals != null) vocals.pitch = newP;
			case "section_back":
				changeSection(curSection - 1);
			case "section_forward":
				changeSection(curSection + 1);
			case "step_back":
				Conductor.songPosition = Math.max(0, Conductor.songPosition - Conductor.stepCrochet);
				if (FlxG.sound.music != null) FlxG.sound.music.time = Conductor.songPosition;
				if (vocals != null) vocals.time = Conductor.songPosition;
				updateCurStep();
				updateGrid();
			case "step_forward":
				Conductor.songPosition += Conductor.stepCrochet;
				if (FlxG.sound.music != null) FlxG.sound.music.time = Conductor.songPosition;
				if (vocals != null) vocals.time = Conductor.songPosition;
				updateCurStep();
				updateGrid();

			case "add_note":
				addNote();
			case "add_event":
				var noteStrum = getStrumTime(dummyArrow.y) + sectionStartTime();
				events.push([eventName, noteStrum, eventValue1, eventValue2]);
				hasUnsavedChanges = true;
				updateGrid();
			case "change_bpm":
				_song.notes[curSection].changeBPM = true;
				_song.notes[curSection].bpm = Conductor.bpm;
				hasUnsavedChanges = true;
				// the section timeline is derived from the tempo map, so it has to
				// be rebuilt or every later section keeps its old timing
				Conductor.mapBPMChanges(_song);
				Conductor.syncBPM(sectionStartTime(curSection));
				updateSectionUI();
				updateGrid();
			default:
				if (StringTools.startsWith(action, "event:")) {
					var evName = action.substring(6);
					var noteStrum = getStrumTime(dummyArrow.y) + sectionStartTime();
					events.push([evName, noteStrum, "", ""]);
					hasUnsavedChanges = true;
					updateGrid();
				}
		}
	}

	function setSongSpeed(spd:Float):Void {
		spd = FlxMath.roundDecimal(spd, 2);
		playbackSpeed = spd;
		if (FlxG.sound.music != null) FlxG.sound.music.pitch = spd;
		if (vocals != null) vocals.pitch = spd;
	}

	function formatTime(ms:Float):String {
		if (ms < 0) ms = 0;
		var totalSec = Math.floor(ms / 1000);
		var min = Math.floor(totalSec / 60);
		var sec = totalSec % 60;
		return (min < 10 ? "0" + min : "" + min) + ":" + (sec < 10 ? "0" + sec : "" + sec);
	}

	function playtestChart(startMode:Int = 0, asOpponent:Bool = false):Void {
		_song.events = events;
		globalSecton = curSection;
		var startT:Float = 0;
		if (startMode == 1) {
			startT = Conductor.songPosition;
		} else if (startMode == 2) {
			startT = sectionStartTime(curSection);
		}
		if (FlxG.sound.music != null) FlxG.sound.music.pause();
		if (vocals != null) vocals.pause();
		var ps = new toolbox.PlaytestSubState(_song, events, startT, asOpponent);
		ps.closeCallback = function() {
			onPlaytestSubStateClosed();
		};
		openSubState(ps);
	}

	override public function closeSubState():Void {
		var wasPlaytest:Bool = (subState is toolbox.PlaytestSubState);
		super.closeSubState();
		if (wasPlaytest) {
			onPlaytestSubStateClosed();
		}
	}

	function onPlaytestSubStateClosed():Void {
		if (_song == null) return;
		var pos:Float = Conductor.songPosition;
		if (Math.isNaN(pos) || pos < 0) pos = 0;
		Conductor.songPosition = pos;

		if (FlxG.sound.music != null) {
			FlxG.sound.music.time = pos;
			FlxG.sound.music.pause();
		}
		if (vocals != null) {
			vocals.time = pos;
			vocals.pause();
		}

		// `pos` is an absolute time, so the section has to be looked up through the
		// BPM map instead of dividing by a fixed measure length.
		var targetSec:Int = Conductor.getSectionAtTime(pos);
		if (_song.notes != null) {
			while (_song.notes.length <= targetSec) {
				addSection();
			}
			changeSection(targetSec, false);
		} else {
			updateGrid();
		}
	}

	/**
	 * Start time in ms of a section.
	 *
	 * This used to be a second, independent BPM walker that ignored
	 * `lengthInSteps` and hardcoded `timeScale[0]` beats per section, so it
	 * disagreed with `Conductor.mapBPMChanges` on any chart with tempo changes
	 * and was O(n) on every call (including every frame). The map built by
	 * `Conductor.mapBPMChanges` already holds the exact timeline.
	 */
	function sectionStartTime(?section:Int):Float {
		if (section == null)
			section = curSection;

		return Conductor.getSectionStartTime(section);
	}

	var beatSnap:Int = 4;

	private var blockPressWhileTypingOn:Array<FlxInputText> = [];
	private var blockPressWhileTypingOnStepper:Array<FlxUINumericStepper> = [];
	private var blockPressWhileScrolling:Array<FlxScrollableDropDownMenu> = [];

	inline function getMouseScreenX():Float {
		return (camUI != null) ? FlxG.mouse.getScreenPosition(camUI).x : FlxG.mouse.getScreenPosition(FlxG.camera).x;
	}

	inline function getMouseScreenY():Float {
		return (camUI != null) ? FlxG.mouse.getScreenPosition(camUI).y : FlxG.mouse.getScreenPosition(FlxG.camera).y;
	}

	override function onFocusLost():Void {
		super.onFocusLost();
		if (FlxG.autoPause) return;
		if (FlxG.sound.music != null && FlxG.sound.music.playing) {
			FlxG.sound.music.pause();
		}
		if (vocals != null) vocals.pause();
	}

	override function onFocus():Void {
		super.onFocus();
	}

	public function togglePlayback():Void {
		if (FlxG.sound.music == null) return;

		try {
			if (FlxG.sound.music.playing) {
				FlxG.sound.music.pause();
				if (vocals != null) vocals.pause();
			} else {
				var curT:Float = Conductor.songPosition;
				if (curT < 0) curT = 0;
				if (FlxG.sound.music.length > 0 && curT >= FlxG.sound.music.length) {
					curT = 0;
					changeSection(0, false);
				}

				Conductor.songPosition = curT;
				FlxG.sound.music.time = curT;
				FlxG.sound.music.play(false, curT);

				if (vocals != null) {
					vocals.time = curT;
					vocals.play(false, curT);
				}
			}
		} catch (e:Dynamic) {
			Main.logSilentError(e, "ChartingState: togglePlayback");
		}
	}

	function isUserTyping():Bool {
		if (blockPressWhileTypingOn != null) {
			for (inputText in blockPressWhileTypingOn) {
				if (inputText != null && inputText.hasFocus) {
					return true;
				}
			}
		}
		if (blockPressWhileTypingOnStepper != null) {
			for (stepper in blockPressWhileTypingOnStepper) {
				@:privateAccess
				if (stepper != null && stepper.text_field != null && cast(stepper.text_field, flixel.addons.ui.FlxInputText).hasFocus) {
					return true;
				}
			}
		}
		return false;
	}

	function unfocusAllInputs():Void {
		if (blockPressWhileTypingOn != null) {
			for (inputText in blockPressWhileTypingOn) {
				if (inputText != null) {
					inputText.endFocus();
				}
			}
		}
		if (blockPressWhileTypingOnStepper != null) {
			for (stepper in blockPressWhileTypingOnStepper) {
				@:privateAccess
				if (stepper != null && stepper.text_field != null) {
					cast(stepper.text_field, flixel.addons.ui.FlxInputText).hasFocus = false;
				}
			}
		}
		if (FlxInputText.globalManager != null) FlxInputText.globalManager.setFocus(null);
		if (FlxG.stage != null) FlxG.stage.focus = null;
	}

	private function updateInputFocus():Void {
		if (FlxG.mouse.justPressed) {
			var clickedOnInput:Bool = false;
			if (blockPressWhileTypingOn != null) {
				for (inputText in blockPressWhileTypingOn) {
					if (inputText != null && FlxG.mouse.overlaps(inputText)) {
						clickedOnInput = true;
						break;
					}
				}
			}
			if (!clickedOnInput && blockPressWhileTypingOnStepper != null) {
				for (stepper in blockPressWhileTypingOnStepper) {
					@:privateAccess
					if (stepper != null && stepper.text_field != null && FlxG.mouse.overlaps(cast(stepper.text_field, FlxSprite))) {
						clickedOnInput = true;
						break;
					}
				}
			}
			if (!clickedOnInput) {
				unfocusAllInputs();
			}
		}

		if (isUserTyping()) {
			if (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.ESCAPE) {
				unfocusAllInputs();
			}
		}

		if (FlxG.keys.justPressed.SPACE) {
			var isPlaying:Bool = (FlxG.sound.music != null && FlxG.sound.music.playing);
			if (isPlaying || !isUserTyping()) {
				togglePlayback();
			}
		}
	}

	private function updateTopMenuAndHover(msX:Float, msY:Float, elapsed:Float):Void {
		var hoveredMenuIndex:Int = -1;
		var currentHoveredText:String = null;

		if (msY >= 0 && msY <= 48 && topMenuItems != null) {
			for (i in 0...topMenuItems.length) {
				var item = topMenuItems[i];
				var itemW:Float = item.width > 0 ? item.width : (item.fieldWidth > 0 ? item.fieldWidth : 50);
				if (msX >= item.x - 6 && msX <= item.x + itemW + 8) {
					hoveredMenuIndex = i;
					currentHoveredText = item.text;
					break;
				}
			}
		}

		if (contextMenuVisible && activeSubmenuIndex != -1) {
			hoveredMenuIndex = activeSubmenuIndex;
			if (currentHoveredText == null && topMenuItems != null && activeSubmenuIndex < topMenuItems.length) {
				currentHoveredText = topMenuItems[activeSubmenuIndex].text;
			}
		}

		if (hoveredMenuIndex != -1 && topMenuItems != null && topMenuItems[hoveredMenuIndex] != null) {
			var item = topMenuItems[hoveredMenuIndex];
			var itemW:Float = item.width > 0 ? item.width : (item.fieldWidth > 0 ? item.fieldWidth : 50);
			topMenuHighlight.x = item.x - 6;
			topMenuHighlight.y = 0;
			if (hoveredMenuIndex != prevHoveredMenuIndex) {
				topMenuHighlight.makeGraphic(Std.int(itemW + 12), 48, FlxColor.WHITE);
				prevHoveredMenuIndex = hoveredMenuIndex;
			}
			topMenuHighlight.visible = true;

			for (i in 0...topMenuItems.length) {
				topMenuItems[i].color = (i == hoveredMenuIndex) ? FlxColor.BLACK : FlxColor.WHITE;
			}
		} else {
			if (topMenuHighlight != null) topMenuHighlight.visible = false;
			prevHoveredMenuIndex = -1;
			if (topMenuItems != null) {
				for (item in topMenuItems) item.color = FlxColor.WHITE;
			}
		}

		var hoveredDropdownText:String = null;
		if (contextMenuVisible && contextMenuItems != null && contextMenuBG != null) {
			var bgX:Float = contextMenuBG.x;
			var bgY:Float = contextMenuBG.y;
			var bgW:Float = contextMenuBG.width;
			var bgH:Float = contextMenuBG.height;
			var isInsideBG:Bool = (msX >= bgX && msX <= bgX + bgW && msY >= bgY && msY <= bgY + bgH);

			for (i in 0...contextMenuItems.length) {
				var item = contextMenuItems[i];
				if (item == null || !item.visible) continue;
				if (item.text == "---") {
					item.color = 0xFF888888;
					continue;
				}
				if (isInsideBG && msY >= item.y - 3 && msY <= item.y + 19) {
					item.color = 0xFFFFFF00;
					hoveredDropdownText = item.text;
				} else {
					item.color = FlxColor.WHITE;
				}
			}
		}

		if (hoveredDropdownText != null) {
			currentHoveredText = hoveredDropdownText;
		}

		if (currentHoveredText != null && currentHoveredText != "---" && menuDescriptions != null) {
			var desc:String = menuDescriptions.get(currentHoveredText);
			if (desc == null) {
				for (k in menuDescriptions.keys()) {
					if (currentHoveredText.startsWith(k) || k.startsWith(currentHoveredText)) {
						desc = menuDescriptions.get(k);
						break;
					}
				}
			}
			if (desc == null && currentHoveredText.startsWith("1/")) {
				desc = "Sets note placement snap division to " + currentHoveredText + ".";
			}

			if (desc != null) {
				if (headerInfoTitle != null) headerInfoTitle.text = currentHoveredText;
				if (headerInfoDesc != null) headerInfoDesc.text = desc;
				headerInfoTargetX = FlxG.width - 415;
			} else {
				headerInfoTargetX = FlxG.width + 20;
			}
		} else {
			headerInfoTargetX = FlxG.width + 20;
		}

		if (headerInfoBox != null) {
			var lerpSpeed:Float = FlxMath.bound(elapsed * 18, 0, 1);
			headerInfoBox.x = FlxMath.lerp(headerInfoBox.x, headerInfoTargetX, lerpSpeed);
			if (headerInfoBorder != null) headerInfoBorder.x = headerInfoBox.x - 2;
			if (headerInfoTitle != null) headerInfoTitle.x = headerInfoBox.x + 12;
			if (headerInfoDesc != null) headerInfoDesc.x = headerInfoBox.x + 12;

			var isVisible:Bool = headerInfoBox.x < FlxG.width + 5;
			headerInfoBox.visible = isVisible;
			if (headerInfoBorder != null) headerInfoBorder.visible = isVisible;
			if (headerInfoTitle != null) headerInfoTitle.visible = isVisible;
			if (headerInfoDesc != null) headerInfoDesc.visible = isVisible;
		}
	}

	private function checkBlockInput():Bool {
		for (inputText in blockPressWhileTypingOn) {
			if (inputText != null && inputText.hasFocus) {
				FlxG.sound.muteKeys = [];
				FlxG.sound.volumeDownKeys = [];
				FlxG.sound.volumeUpKeys = [];
				return true;
			}
		}

		for (stepper in blockPressWhileTypingOnStepper) {
			@:privateAccess
			if (stepper != null && stepper.text_field != null && cast(stepper.text_field, flixel.addons.ui.FlxInputText).hasFocus) {
				FlxG.sound.muteKeys = [];
				FlxG.sound.volumeDownKeys = [];
				FlxG.sound.volumeUpKeys = [];
				return true;
			}
		}

		FlxG.sound.muteKeys = [ZERO, NUMPADZERO];
		FlxG.sound.volumeDownKeys = [MINUS, NUMPADMINUS];
		FlxG.sound.volumeUpKeys = [PLUS, NUMPADPLUS];

		for (dropDownMenu in blockPressWhileScrolling) {
			if (dropDownMenu != null && dropDownMenu.dropPanel.visible) {
				return true;
			}
		}

		return false;
	}

	private function updateKeyboardShortcuts():Void {
		if (FlxG.keys.pressed.CONTROL) {
			if (FlxG.keys.justPressed.S) {
				if (FlxG.keys.pressed.SHIFT)
					exportCodename();
				else
					saveLevel(false);
			} else if (FlxG.keys.justPressed.Z) {
				if (FlxG.keys.pressed.SHIFT)
					performRedo();
				else
					performUndo();
			} else if (FlxG.keys.justPressed.Y) {
				performRedo();
			} else if (FlxG.keys.justPressed.C) {
				copySection();
			} else if (FlxG.keys.justPressed.V) {
				pasteSection();
			} else if (FlxG.keys.justPressed.X) {
				copySection();
				clearSection();
			} else if (FlxG.keys.justPressed.PLUS) {
				if (FlxG.keys.pressed.SHIFT) {
					GRID_SIZE = Std.int(Math.min(GRID_SIZE_MAX, GRID_SIZE + 5));
					refreshCursorSprites();
					updateGrid();
					updateHeads();
				} else {
					zoomLevel = Math.min(MAX_ZOOM, zoomLevel + 0.25);
					updateGrid();
				}
			} else if (FlxG.keys.justPressed.MINUS || FlxG.keys.justPressed.NUMPADMINUS) {
				if (FlxG.keys.pressed.SHIFT) {
					GRID_SIZE = Std.int(Math.max(GRID_SIZE_MIN, GRID_SIZE - 5));
					refreshCursorSprites();
					updateGrid();
					updateHeads();
				} else {
					zoomLevel = Math.max(MIN_ZOOM, zoomLevel - 0.25);
					updateGrid();
				}
			} else if (FlxG.keys.justPressed.ZERO || FlxG.keys.justPressed.NUMPADZERO) {
				if (FlxG.keys.pressed.SHIFT) {
					GRID_SIZE = GRID_SIZE_DEFAULT;
					refreshCursorSprites();
					updateGrid();
					updateHeads();
				} else {
					zoomLevel = 1.0;
					updateGrid();
				}
			}
		}

		if (FlxG.keys.justPressed.PERIOD) {
			var newP = Math.min(2.0, FlxG.sound.music.pitch + 0.25);
			FlxG.sound.music.pitch = (vocals != null ? vocals.pitch = newP : newP);
		} else if (FlxG.keys.justPressed.COMMA) {
			var newP = Math.max(0.25, FlxG.sound.music.pitch - 0.25);
			FlxG.sound.music.pitch = (vocals != null ? vocals.pitch = newP : newP);
		}

		if (patternModeEnabled && FlxG.keys.pressed.SHIFT) {
			var tc:Int = -1;
			if (FlxG.mouse.x >= gridBG.x + GRID_SIZE && FlxG.mouse.x <= gridBG.x + gridBG.width) {
				tc = Math.floor((FlxG.mouse.x - gridBG.x) / GRID_SIZE) - 1;
				var kCounts = getKeyCountsAtSection(curSection);
				if (tc >= kCounts.keyCount + kCounts.playerKeyCount || tc < 0) tc = -1;
			}

			if (FlxG.keys.justPressed.ONE) generatePattern("stream", Conductor.songPosition, tc);
			if (FlxG.keys.justPressed.TWO) generatePattern("staircase", Conductor.songPosition, tc);
			if (FlxG.keys.justPressed.THREE) generatePattern("jack", Conductor.songPosition, tc);
			if (FlxG.keys.justPressed.FOUR) generatePattern("trill", Conductor.songPosition, tc);
		}

		if (patternModeEnabled && FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.Z) {
			if (patternUndoHistory.length > 0) {
				var lastPattern = patternUndoHistory.pop();
				for (section in _song.notes) {
					var toRemove = [];
					for (note in section.sectionNotes) {
						if (lastPattern.indexOf(note) != -1) {
							toRemove.push(note);
						}
					}
					for (note in toRemove) {
						section.sectionNotes.remove(note);
					}
				}
				updateGrid();
			}
		}
	}

	private function updateEventValues():Void {
		var oldValue1 = eventValue1;
		var oldValue2 = eventValue2;

		eventValue1 = value1.text;
		eventValue2 = value2.text;

		if (oldValue1 != eventValue1 && curSelectedEvent != null) {
			curSelectedEvent[2] = eventValue1;
			hasUnsavedChanges = true;
			updateGrid();
		}

		if (oldValue2 != eventValue2 && curSelectedEvent != null) {
			curSelectedEvent[3] = eventValue2;
			hasUnsavedChanges = true;
			updateGrid();
		}
	}

	private function updateSongSyncAndConductor():Void {
		if (tempBpm <= 1.0 || Math.isNaN(tempBpm))
			tempBpm = (_song != null && _song.bpm > 1.0) ? _song.bpm : 100.0;

		if (Conductor.bpm <= 1.0 || Math.isNaN(Conductor.bpm))
			Conductor.bpm = tempBpm;

		if (_song != null && _song.notes != null && curSection >= 0 && curSection < _song.notes.length && _song.notes[curSection] != null) {
			if (_song.notes[curSection].bpm <= 1.0 || Math.isNaN(_song.notes[curSection].bpm)) {
				_song.notes[curSection].bpm = _song.bpm;
				Conductor.mapBPMChanges(_song);
			}
		}

		Conductor.timeScale = _song.timescale;
		curStep = Math.floor(Conductor.getStep(Conductor.songPosition));

		if (FlxG.sound.music != null && FlxG.sound.music.playing) {
			updateSongPosition();
		}

		if (typingShit.text != _song.song) _song.song = typingShit.text;
		var newDiff:String = swagShit.text.toLowerCase();
		if (newDiff != difficulty) {
			difficulty = newDiff;
			PlayState.storyDifficultyStr = difficulty.toUpperCase();
		}
		if (modchart_Input.text != _song.modchartPath) _song.modchartPath = modchart_Input.text;
		if (cutscene_Input.text != _song.cutscene) _song.cutscene = cutscene_Input.text;
		if (endCutscene_Input.text != _song.endCutscene) _song.endCutscene = endCutscene_Input.text;

		strumLine.y = getYfromStrum(Conductor.songPosition - sectionStartTime());
		cameraShitThing.y = strumLine.y;

		var activePlayheadTime:Float = (FlxG.sound.music != null && FlxG.sound.music.playing)
			? Conductor.songPosition
			: (sectionStartTime(curSection) + getStrumTime(strumLine != null ? strumLine.y : (gridBG != null ? gridBG.y : 50)));
		var activeKCounts = getKeyCountsAtTime(activePlayheadTime);
		var activePlayheadCols:Int = 1 + activeKCounts.keyCount + activeKCounts.playerKeyCount;
		if (strumLine != null && gridBG != null) {
			var expectedLineW:Int = activePlayheadCols * GRID_SIZE;
			if (strumLine.width != expectedLineW) {
				strumLine.makeGraphic(expectedLineW, 4);
			}
		}
		rebuildStrumlineReceptors(activeKCounts);
	}

	private function updateScrollBar(msY:Float):Void {
		if (isDraggingScrollBar) {
			if (FlxG.mouse.justReleased || !FlxG.mouse.pressed) {
				isDraggingScrollBar = false;
			} else {
				var trackTop:Float = 48;
				var trackHeight:Float = FlxG.height - 48;
				var thumbH:Float = scrollBarThumb != null ? scrollBarThumb.height : 60;
				var maxScrollY:Float = trackHeight - thumbH;
				if (maxScrollY > 0) {
					var clampedY:Float = Math.max(trackTop, Math.min(FlxG.height - thumbH, msY - thumbH / 2));
					var scrollRatio:Float = (clampedY - trackTop) / maxScrollY;
					scrollRatio = Math.max(0, Math.min(1.0, scrollRatio));

					var totalLen:Float = (FlxG.sound.music != null && FlxG.sound.music.length > 0) ? FlxG.sound.music.length : 0;
					if (totalLen > 0) {
						var targetTime:Float = scrollRatio * totalLen;
						Conductor.songPosition = targetTime;
						if (FlxG.sound.music != null) FlxG.sound.music.time = targetTime;
						if (vocals != null) vocals.time = targetTime;

						var targetSec:Int = Conductor.getSectionAtTime(targetTime);
						if (targetSec >= 0 && _song != null && _song.notes != null && targetSec < _song.notes.length && targetSec != curSection) {
							changeSection(targetSec, false);
						} else {
							updateCurStep();
							updateGrid();
						}
					}
				}
			}
		}

		var totalSongSteps:Float = (FlxG.sound.music != null && FlxG.sound.music.length > 0) ? Conductor.getStep(FlxG.sound.music.length) : 0;
		if (totalSongSteps > 0 && !isDraggingScrollBar) {
			var curSongStep:Float = Conductor.getStep(Conductor.songPosition);
			var thumbRatio:Float = Math.min(1.0, (Conductor.stepsPerSection * 16) / totalSongSteps);
			scrollBarThumb.height = Math.max(20, (FlxG.height - 48) * thumbRatio);
			var maxScroll:Float = FlxG.height - 48 - scrollBarThumb.height;
			scrollBarThumb.y = 48 + Math.max(0, Math.min(1.0, curSongStep / totalSongSteps)) * maxScroll;
		}
	}

	private function updateInfoReadouts():Void {
		if (quantText != null && quantText.visible) {
			quantText.text = "Snap: 1/" + beatSnap;
		}

		var timePos:Float = Conductor.songPosition;
		var totalMs:Float = FlxG.sound.music != null ? FlxG.sound.music.length : 0;
		var curMin:Int = Std.int(Math.floor(timePos / 60000));
		var curSec:Int = Std.int(Math.floor((timePos % 60000) / 1000));
		var totMin:Int = Std.int(Math.floor(totalMs / 60000));
		var totSec:Int = Std.int(Math.floor((totalMs % 60000) / 1000));
		var timeStr:String = '${StringTools.lpad(Std.string(curMin), "0", 2)}:${StringTools.lpad(Std.string(curSec), "0", 2)} / ${StringTools.lpad(Std.string(totMin), "0", 2)}:${StringTools.lpad(Std.string(totSec), "0", 2)}';

		var liveBpm:Float = Conductor.getBPMAtTime(Conductor.songPosition);
		var liveBpmTxt:String = FlxMath.roundDecimal(liveBpm, 2) + "";
		var curSecObj = (_song != null && _song.notes != null && curSection >= 0 && curSection < _song.notes.length) ? _song.notes[curSection] : null;
		var bpmChangeTag:String = (curSecObj != null && curSecObj.changeBPM) ? " *" : "";
		var scaleTag:String = (curSecObj != null && curSecObj.changeTimeScale && curSecObj.timeScale != null && curSecObj.timeScale.length >= 2) ? " | Sig: " + curSecObj.timeScale[0] + "/" + curSecObj.timeScale[1] : "";
		var curLen:Int = Conductor.sectionLengthInSteps(curSecObj);

		if (sectionInfoText != null && sectionInfoText.visible) {
			sectionInfoText.text = timeStr
				+ '\nStep: $curStep'
				+ '\nBeat: ${Std.int(curBeat)}'
				+ '\nMeasure: $curSection'
				+ '\nBPM: $liveBpmTxt$bpmChangeTag'
				+ scaleTag;
		}

		if (topInfoTxt != null) {
			var realTimePos:Float = Math.max(0, Conductor.songPosition);
			var realTotalMs:Float = (FlxG.sound.music != null) ? FlxG.sound.music.length : 0;
			var rMin:Int = Std.int(Math.floor(realTimePos / 60000));
			var rSec:Int = Std.int(Math.floor((realTimePos % 60000) / 1000));
			var tMin:Int = Std.int(Math.floor(realTotalMs / 60000));
			var tSec:Int = Std.int(Math.floor((realTotalMs % 60000) / 1000));
			var spdStr:String = FlxG.sound.music != null ? FlxMath.roundDecimal(FlxG.sound.music.pitch, 2) + "x" : "1x";

			var newInfoStr:String = _song.song
				+ " (" + difficulty.toUpperCase() + ")"
				+ " | Time: " + StringTools.lpad(Std.string(rMin), "0", 2) + ":" + StringTools.lpad(Std.string(rSec), "0", 2)
				+ " / " + StringTools.lpad(Std.string(tMin), "0", 2) + ":" + StringTools.lpad(Std.string(tSec), "0", 2)
				+ " | Speed: " + spdStr;
			if (newInfoStr != topInfoTxt.text) {
				topInfoTxt.text = newInfoStr;
			}
		}

		if (sideInfoTxt != null && sideInfoTxt.visible) {
			var decStepStr:String = FlxMath.roundDecimal(curDecStep, 2) + "";
			var decBeatStr:String = FlxMath.roundDecimal(curDecBeat, 2) + "";
			var curDecSec:Float = (Conductor.stepsPerSection > 0) ? (curDecStep / Conductor.stepsPerSection) : curSection;
			var decSecStr:String = FlxMath.roundDecimal(curDecSec, 2) + "";

			var newSideTxt:String = "bpm " + liveBpmTxt + bpmChangeTag
				+ "\ncurSection " + curSection
				+ "\ncurDecSection " + decSecStr
				+ "\ncurStep " + curStep
				+ "\ncurDecStep " + decStepStr
				+ "\ncurBeat " + curBeat
				+ "\ncurDecBeat " + decBeatStr
				+ "\ncurLen " + curLen + scaleTag
				+ "\nbeatSnap 1/" + beatSnap;
			if (newSideTxt != sideInfoTxt.text) {
				sideInfoTxt.text = newSideTxt;
			}
		}
	}

	private function handleTopMenuClicks(msX:Float, msY:Float):Bool {
		if (FlxG.mouse.justPressed) {
			if (msX >= FlxG.width - 24 && msY >= 48) {
				isDraggingScrollBar = true;
				return true;
			}

			if (msY >= 0 && msY <= 48 && topMenuItems != null) {
				hideContextMenu();
				for (i in 0...topMenuItems.length) {
					var item = topMenuItems[i];
					var itemW:Float = item.width > 0 ? item.width : (item.fieldWidth > 0 ? item.fieldWidth : 50);
					if (msX >= item.x - 6 && msX <= item.x + itemW + 8) {
						activeSubmenuIndex = i;
						openTopSubmenu(item.text, item.x - 4, 48);
						return true;
					}
				}
				activeSubmenuIndex = -1;
				return true;
			} else if (contextMenuVisible && msY > 48) {
				handleContextMenuClick(msX, msY);
				return true;
			}
		}
		return false;
	}

	private function updateStagePreviewAndHitsounds(elapsed:Float):Void {
		if (showStagePreview && (charPreviewP1 != null || charPreviewP2 != null) && FlxG.sound.music != null && FlxG.sound.music.playing) {
			curRenderedNotes.forEach(function(note:Note) {
				if (note.wasGoodHit) return;
				if (Math.abs(note.y - strumLine.y) < 16) {
					note.wasGoodHit = true;
					var singAnims:Array<String> = ["singLEFT", "singDOWN", "singUP", "singRIGHT"];
					var anim = singAnims[note.noteData % singAnims.length];
					var charToSing:game.Character = note.mustPress ? charPreviewP1 : charPreviewP2;
					if (charToSing != null) {
						if (note.isSustainNote) {
							charToSing.holdTimer = 0;
							if (charToSing.isCharacterGroup && charToSing.otherCharacters != null) {
								for (c in charToSing.otherCharacters) c.holdTimer = 0;
							}
						} else {
							playAnimOnNotePreview(charToSing, note, anim);
						}
					}
				}
			});
		}

		if (showStagePreview) {
			updateStagePreviewCamera(elapsed);
			danceCharPreview(charPreviewP1, elapsed);
			danceCharPreview(charPreviewP2, elapsed);
			danceCharPreview(charPreviewGF, elapsed);
		}

		if ((playerHitsounds || enemyHitsounds) && FlxG.sound.music != null && FlxG.sound.music.playing) {
			curRenderedNotes.forEach(function(note:Note) {
				if (note.isSustainNote) return;

				if (Conductor.songPosition < note.strumTime - 100) {
					note.playedHitSound = false;
				} else if (!note.playedHitSound && Conductor.songPosition >= note.strumTime - 10) {
					note.playedHitSound = true;

					if (note.mustPress) {
						if (playerHitsounds) FlxG.sound.play(Paths.sound('CLAP'), 0.5);
					} else if (enemyHitsounds) {
						FlxG.sound.play(Paths.sound('SNAP'), 0.5);
					}
				}
			});
		}

		if (FlxG.sound.music != null && FlxG.sound.music.playing) {
			try {
				if (vocals != null && vocals.playing && Math.abs(vocals.time - FlxG.sound.music.time) > 100) {
					vocals.time = FlxG.sound.music.time;
				}
			} catch (e:Dynamic) { Main.logSilentError(e, "ChartingState: vocal sync correction"); }

			var targetSec:Int = Conductor.getSectionAtTime(Conductor.songPosition);
			if (targetSec >= 0 && targetSec < _song.notes.length) {
				if (targetSec != curSection && _song.notes[targetSec] != null) {
					changeSection(targetSec, false);
				}
			}
		}

		if (_song.notes[curSection] == null)
			addSection();
	}

	private function handleGridClicks():Void {
		if (FlxG.mouse.justPressed) {
			var coolNess = true;

			if (FlxG.mouse.overlaps(curRenderedNotes)) {
				curRenderedNotes.forEach(function(note:Note) {
					if (FlxG.mouse.overlaps(note) && coolNess) {
						coolNess = false;

						if (FlxG.keys.pressed.CONTROL) {
							selectNote(note);
						} else {
							deleteNote(note);
						}
					}
				});
			}

			if (coolNess && curRenderedEvents != null) {
				var clickedEvent:EventSprite = null;
				for (event in curRenderedEvents.members) {
					if (event != null && event.alive && event.exists && event.eventSprite != null && FlxG.mouse.overlaps(event.eventSprite)) {
						clickedEvent = event;
						break;
					}
				}

				if (clickedEvent != null) {
					coolNess = false;

					var matched:Array<Dynamic> = clickedEvent.eventData;
					if (matched == null) {
						for (ev in events) {
							if (ev != null && ev.length > 1 && Math.abs(Std.parseFloat(Std.string(ev[1])) - clickedEvent.strumTime) < 2.0) {
								matched = ev;
								break;
							}
						}
					}

					if (FlxG.keys.pressed.CONTROL) {
						deleteEvent(clickedEvent);
					} else {
						selectEvent(clickedEvent);
						openEventEditor(clickedEvent.strumTime, matched);
					}
				}
			}

			if (coolNess) {
				var totalGridH:Float = gridBG.height + (gridBGNext != null ? gridBGNext.height : 0);
				if (FlxG.mouse.x >= gridBG.x
					&& FlxG.mouse.x <= gridBG.x + gridBG.width
					&& FlxG.mouse.y >= gridBG.y
					&& FlxG.mouse.y <= gridBG.y + totalGridH) {
					addNote();
				}
			}
		}
	}

	private function updateGridHover():Void {
		var canHoverGrid:Bool = !contextMenuVisible && mouseOnGrid();
		if (canHoverGrid) {
			var snappedGridSize = snapGridSize();
			var relY:Float = FlxG.mouse.y - gridBG.y;
			var snappedY:Float = gridBG.y + Math.floor(relY / snappedGridSize) * snappedGridSize;
			var hoverTime:Float = sectionStartTime() + getStrumTime(snappedY);
			var hoverCol:Int = Math.floor((FlxG.mouse.x - gridBG.x) / GRID_SIZE);

			var hoverK = getKeyCountsAtTime(hoverTime);
			var totalColsAtTime:Int = 1 + hoverK.playerKeyCount + hoverK.keyCount;

			if (hoverCol >= 0 && hoverCol < totalColsAtTime) {
				dummyArrow.x = gridBG.x + hoverCol * GRID_SIZE;
				dummyArrow.y = FlxG.keys.pressed.SHIFT ? FlxG.mouse.y : snappedY;
				if (noteHoverer != null) {
					noteHoverer.x = dummyArrow.x + 2;
					noteHoverer.y = dummyArrow.y + 2;
					noteHoverer.color = (hoverCol == 0) ? 0xFFEAB308 : 0xFF994BC2;
					noteHoverer.visible = true;
				}
			} else {
				if (noteHoverer != null)
					noteHoverer.visible = false;
			}
		} else {
			if (noteHoverer != null)
				noteHoverer.visible = false;
		}
	}

	private function updateEditorNavigation():Void {
		if (FlxG.keys.justPressed.ENTER) {
			_song.events = events;
			globalSecton = curSection;
			PlayState.SONG = _song;
			FlxG.sound.music.stop();
			vocals.stop();
			PlayState.playCutscenes = true;
			PlayState.loadChartEvents = false;
			LoadingState.loadAndSwitchState(() -> new PlayState());
			PlayState.chartingMode = true;
			if (FlxG.keys.pressed.SHIFT) {
				PlayState.startOnTime = Conductor.songPosition;
			}
		}

		if (FlxG.keys.justPressed.E)
			changeNoteSustain(Conductor.stepCrochet);
		if (FlxG.keys.justPressed.Q)
			changeNoteSustain(-Conductor.stepCrochet);

		if (FlxG.keys.justPressed.X) {
			zoomLevel *= 2;
			zoomLevel = FlxMath.bound(zoomLevel, MIN_ZOOM, MAX_ZOOM);
			updateGrid();
		} else if (FlxG.keys.justPressed.Z) {
			zoomLevel /= 2;
			zoomLevel = FlxMath.bound(zoomLevel, MIN_ZOOM, MAX_ZOOM);
			updateGrid();
		}

		if (FlxG.keys.justPressed.TAB) {
			if (FlxG.keys.pressed.SHIFT) {
				UI_box.selected_tab--;
				if (UI_box.selected_tab < 0)
					UI_box.selected_tab = 4;
			} else {
				UI_box.selected_tab++;
				if (UI_box.selected_tab >= 5)
					UI_box.selected_tab = 0;
			}
		}

		var control = FlxG.keys.pressed.CONTROL;

		if (FlxG.keys.justPressed.W) {
			executeContextMenuAction("step_back");
		}
		if (FlxG.keys.justPressed.S) {
			executeContextMenuAction("step_forward");
		}
		if (FlxG.keys.justPressed.PERIOD) {
			executeContextMenuAction("playback_speed_up");
		}
		if (FlxG.keys.justPressed.COMMA) {
			executeContextMenuAction("playback_speed_down");
		}

		if (FlxG.keys.justPressed.R) {
			if (FlxG.keys.pressed.SHIFT)
				resetSection(true);
			else
				resetSection();
		}

		if (FlxG.keys.justPressed.ESCAPE) {
			if (hasUnsavedChanges && !escConfirmActive) {
				escConfirmActive = true;
				autosaveText.text = "Unsaved changes! Press ESC again to exit";
				autosaveText.color = FlxColor.RED;
				new FlxTimer().start(2, function(_) {
					escConfirmActive = false;
					if (autosaveText.text == "Unsaved changes! Press ESC again to exit")
						autosaveText.text = "";
				});
			} else {
				openSubState(new substates.ExitChartingSubstate());
			}
		}

		if (FlxG.keys.pressed.CONTROL && FlxG.mouse.pressed) {
			if (isDraggingGrid) {
				cameraShitThing.x -= (FlxG.mouse.x - lastDragMouseX);
			}
			isDraggingGrid = true;
			lastDragMouseX = FlxG.mouse.x;
		} else {
			isDraggingGrid = false;
		}

		if (FlxG.mouse.wheel != 0) {
			if (control) {
				cameraShitThing.x += FlxG.mouse.wheel * 25;
			} else {
				Conductor.songPosition -= (FlxG.mouse.wheel * Conductor.stepCrochet * 0.4);
				if (Conductor.songPosition < sectionStartTime()) {
					changeSection(curSection - 1, false);
				} else if (Conductor.songPosition >= sectionStartTime(curSection + 1)) {
					changeSection(curSection + 1, false);
				}
				if (FlxG.sound.music != null && !FlxG.sound.music.playing) {
					FlxG.sound.music.time = Conductor.songPosition;
				}
				if (vocals != null && !vocals.playing) {
					vocals.time = Conductor.songPosition;
				}
			}
		}

		if (FlxG.keys.pressed.W || FlxG.keys.pressed.S) {
			var daTime:Float = (FlxG.keys.pressed.SHIFT ? Conductor.stepCrochet : 700 * FlxG.elapsed);

			if (FlxG.keys.pressed.W) {
				Conductor.songPosition -= daTime;
			} else {
				Conductor.songPosition += daTime;
			}

			if (Conductor.songPosition < sectionStartTime()) {
				changeSection(curSection - 1, false);
			} else if (Conductor.songPosition >= sectionStartTime(curSection + 1)) {
				changeSection(curSection + 1, false);
			}

			if (FlxG.sound.music != null && !FlxG.sound.music.playing) {
				FlxG.sound.music.time = Conductor.songPosition;
			}
			if (vocals != null && !vocals.playing) {
				vocals.time = Conductor.songPosition;
			}

			if (FlxG.sound.music != null && FlxG.sound.music.length > 0 && Conductor.songPosition >= FlxG.sound.music.length) {
				changeSection(0, false);
			}
		}

		var shiftThing:Int = FlxG.keys.pressed.SHIFT ? 4 : 1;
		var navRight:Bool = ((controls.RIGHT_P) || FlxG.keys.justPressed.D || FlxG.keys.justPressed.RIGHT) && !control;
		var navLeft:Bool = ((controls.LEFT_P) || FlxG.keys.justPressed.A || FlxG.keys.justPressed.LEFT) && !control;

		if (navRight) {
			var songLength:Float = (FlxG.sound.music != null && FlxG.sound.music.length > 0) ? FlxG.sound.music.length : 0;
			if (_song != null && _song.needsVoices && vocals != null && vocals.maxLength > 0) {
				songLength = Math.min(songLength > 0 ? songLength : vocals.maxLength, vocals.maxLength);
			}
			var targetSec:Int = curSection + shiftThing;
			if (songLength > 0 && sectionStartTime(targetSec) >= songLength) {
				targetSec = 0;
			} else if (_song != null && _song.notes != null && targetSec >= _song.notes.length) {
				targetSec = _song.notes.length - 1;
			}
			changeSection(targetSec);
		} else if (navLeft) {
			var targetSec:Int = curSection - shiftThing;
			if (targetSec < 0) targetSec = 0;
			changeSection(targetSec);
		}

		if (controls.RIGHT_P && control) {
			if (NoteVariables.beats.indexOf(beatSnap) + 1 <= NoteVariables.beats.length - 1)
				beatSnap = NoteVariables.beats[NoteVariables.beats.indexOf(beatSnap) + 1];
		}

		if (controls.LEFT_P && control) {
			if (NoteVariables.beats.indexOf(beatSnap) - 1 >= 0)
				beatSnap = NoteVariables.beats[NoteVariables.beats.indexOf(beatSnap) - 1];
		}
	}

	private function updateIconsAndBpmText():Void {
		_song.bpm = tempBpm;

		if (_song != null && _song.notes != null && curSection >= 0 && curSection < _song.notes.length && _song.notes[curSection] != null) {
			if (_song.notes[curSection].bpm <= 1.0 || Math.isNaN(_song.notes[curSection].bpm))
				_song.notes[curSection].bpm = _song.bpm;
		}

		if (Conductor.songPosition < 0)
			Conductor.songPosition = 0;
		if (FlxG.sound.music != null && FlxG.sound.music.time < 0)
			FlxG.sound.music.time = 0;

		#if FLX_PITCH
		if (FlxG.sound.music != null) FlxG.sound.music.pitch = playbackSpeed;
		if (vocals != null) vocals.pitch = playbackSpeed;
		#end

		var kCounts = getKeyCountsAtSection(curSection);

		if (bpmTxt != null && bpmTxt.visible) {
			var newBpmTxt:String = ("Time: "
				+ Std.string(FlxMath.roundDecimal(Conductor.songPosition / 1000, 2))
				+ " / "
				+ Std.string(FlxMath.roundDecimal(FlxG.sound.music.length / 1000, 2))
				+ "\nSection: "
				+ curSection
				+ "\nKeys: "
				+ kCounts.playerKeyCount + "K (P1) / " + kCounts.keyCount + "K (P2)"
				+ "\nBPM: "
				+ Conductor.bpm
				+ (Math.abs(Conductor.bpm - _song.bpm) > 0.01 ? " (base " + FlxMath.roundDecimal(_song.bpm, 2) + ")" : "")
				+ "\nTime Sig: "
				+ Conductor.timeScale[0]
				+ "/"
				+ Conductor.timeScale[1]
				+ "\nSection Start: "
				+ FlxMath.roundDecimal(sectionStartTime(curSection) / 1000, 2)
				+ "s"
				+ "\nSection Len: "
				+ Conductor.sectionLengthInSteps((_song != null && _song.notes != null && curSection >= 0 && curSection < _song.notes.length) ? _song.notes[curSection] : null)
				+ " steps"
				+ "\nCurStep: "
				+ curStep
				+ "\nCurBeat: "
				+ curBeat
				+ "\nCurDecStep: "
				+ FlxMath.roundDecimal(curDecStep, 2)
				+ "\nCurDecBeat: "
				+ FlxMath.roundDecimal(curDecBeat, 2)
				+ "\nNote Snap: "
				+ beatSnap
				+ (FlxG.keys.pressed.SHIFT ? "\n(DISABLED)" : "\n(CONTROL + ARROWS)")
				+ "\nZoom Level: "
				+ zoomLevel
				+ (patternModeEnabled ? "\n\n[PATTERN MODE ON]\nHold SHIFT + 1: Stream\nHold SHIFT + 2: Staircase\nHold SHIFT + 3: Jack\nHold SHIFT + 4: Trill\nCTRL + Z: Undo Pattern" : "")
				+ "\n");
			if (newBpmTxt != bpmTxt.text) {
				bpmTxt.text = newBpmTxt;
			}
			bpmTxt.antialiasing = false;
		}

		var isMustHitSec:Bool = (_song != null && _song.notes != null && _song.notes.length > curSection && _song.notes[curSection] != null) ? _song.notes[curSection].mustHitSection : true;
		var firstSideCols:Int = isMustHitSec ? kCounts.playerKeyCount : kCounts.keyCount;
		var bgX:Float = (gridBG != null) ? gridBG.x : 240.0;
		var rightBaseX:Float = (gridBlackLine != null) ? gridBlackLine.x : (bgX + (GRID_SIZE * (firstSideCols + 1)));

		for (i in 0...leftIcons.length) {
			leftIcons[i].x = bgX + GRID_SIZE + i * 30;
		}
		for (i in 0...rightIcons.length) {
			rightIcons[i].x = rightBaseX + i * 30;
		}

		// Refresh grid and notes when zoom level changes
		if (zoomLevel != prevZoomLevel) {
			updateGrid();
			prevZoomLevel = zoomLevel;
		}
	}

	override function update(elapsed:Float) {
		updateInputFocus();

		var msX:Float = getMouseScreenX();
		var msY:Float = getMouseScreenY();
		updateTopMenuAndHover(msX, msY, elapsed);

		var blockInput:Bool = checkBlockInput();
		if (!blockInput) {
			updateKeyboardShortcuts();
		}

		updateEventValues();
		updateSongSyncAndConductor();
		updateScrollBar(msY);
		updateInfoReadouts();

		if (!handleTopMenuClicks(msX, msY)) {
			if (FlxG.mouse.justPressedRight) {
				var smx:Float = getMouseScreenX();
				var smy:Float = getMouseScreenY();
				if (contextMenuVisible) {
					hideContextMenu();
				} else {
					showContextMenu(smx, smy);
				}
			}

			updateStagePreviewAndHitsounds(elapsed);
			handleGridClicks();
			updateGridHover();

			if (!blockInput) {
				updateEditorNavigation();
			}
		}

		updateIconsAndBpmText();
		super.update(elapsed);
	}

	function changeNoteSustain(value:Float):Void {
		var stepChange:Float = (value > 0) ? Conductor.stepCrochet : -Conductor.stepCrochet;
		var targets:Array<Array<Dynamic>> = [];

		if (selectedNotes != null && selectedNotes.length > 0) {
			for (sel in selectedNotes) {
				if (sel.section < _song.notes.length && _song.notes[sel.section] != null) {
					for (n in _song.notes[sel.section].sectionNotes) {
						if (n[0] == sel.strumTime && n[1] == sel.noteData) {
							if (!targets.contains(n)) targets.push(n);
							break;
						}
					}
				}
			}
		}
		if (curSelectedNote != null && !targets.contains(curSelectedNote)) {
			targets.push(curSelectedNote);
		}

		for (n in targets) {
			var curSus:Float = (n[2] != null) ? n[2] : 0;
			var newSus:Float = Math.max(0, curSus + stepChange);
			n[2] = newSus;
		}

		hasUnsavedChanges = true;
		updateNoteUI();
		updateGrid();
	}

	function resetSection(songBeginning:Bool = false):Void {
		FlxG.sound.music.pause();
		vocals.pause();

		// Basically old shit from changeSection???
		FlxG.sound.music.time = sectionStartTime();

		if (songBeginning) {
			FlxG.sound.music.time = 0;
			curSection = 0;
		}

		vocals.time = FlxG.sound.music.time;
		updateCurStep();

		hasUnsavedChanges = true;
		updateGrid();
		updateSectionUI();
	}

	function playAnimOnNotePreview(char:game.Character, note:Note, singAnim:String):Void {
		if (!char.isCharacterGroup) {
			char.playAnim(singAnim, true);
			char.holdTimer = 0;
			return;
		}

		var chars:Array<Int> = note?.characters ?? [];
		var charID:Int = note?.character ?? char.mainCharacterID;
		var targets:Array<Int> = (chars.length <= 1) ? [charID] : chars;

		for (i in targets) {
			if (char.otherCharacters != null && i < char.otherCharacters.length) {
				var c = char.otherCharacters[i];
				if (c != null) {
					char.activeCharacterID = i;
					c.playAnim(singAnim, true);
					c.holdTimer = 0;
				}
			}
		}
	}

	function danceCharPreview(char:game.Character, elapsed:Float):Void {
		if (char == null) return;
		if (char.isCharacterGroup && char.otherCharacters != null) {
			for (c in char.otherCharacters) {
				if (c.animation.curAnim != null && c.animation.curAnim.name.startsWith("sing")) {
					c.holdTimer += elapsed;
					if (c.holdTimer >= Conductor.stepCrochet * 0.004) {
						c.dance();
						c.holdTimer = 0;
					}
				}
			}
		} else {
			if (char.animation.curAnim != null && char.animation.curAnim.name.startsWith("sing")) {
				char.holdTimer += elapsed;
				if (char.holdTimer >= Conductor.stepCrochet * 0.004) {
					char.dance();
					char.holdTimer = 0;
				}
			}
		}
	}

	function danceCharOnSectionChange(char:game.Character):Void {
		if (char == null) return;
		if (char.isCharacterGroup && char.otherCharacters != null) {
			for (c in char.otherCharacters) c.dance();
		} else {
			char.dance();
		}
	}

	function changeSection(sec:Int = 0, ?updateMusic:Bool = true):Void {
		if (_song == null || _song.notes == null || _song.notes.length == 0) {
			return;
		}
		if (sec < 0) sec = 0;
		if (sec >= _song.notes.length) sec = _song.notes.length - 1;
		if (_song.notes[sec] != null) {
			curSection = sec;

			try {
				if (updateMusic) {
					if (FlxG.sound.music != null) {
						FlxG.sound.music.pause();
					}
					if (vocals != null) {
						vocals.pause();
					}

					var targetTime:Float = sectionStartTime(sec);
					if (targetTime < 0) targetTime = 0;
					if (FlxG.sound.music != null && FlxG.sound.music.length > 0 && targetTime >= FlxG.sound.music.length) {
						targetTime = Math.max(0, FlxG.sound.music.length - 1);
					}
					Conductor.songPosition = targetTime;
					if (FlxG.sound.music != null) FlxG.sound.music.time = targetTime;
					if (vocals != null) vocals.time = targetTime;
					updateCurStep();
				} else {
					var curPos:Float = Conductor.songPosition;
					if (curPos < 0) curPos = 0;
					if (FlxG.sound.music != null && !FlxG.sound.music.playing) {
						if (FlxG.sound.music.length > 0 && curPos >= FlxG.sound.music.length) curPos = Math.max(0, FlxG.sound.music.length - 1);
						FlxG.sound.music.time = curPos;
					}
					if (vocals != null && !vocals.playing) {
						vocals.time = curPos;
					}
					updateCurStep();
				}
			} catch (e:Dynamic) {}

			try {
				updateGrid();
			} catch (e:Dynamic) {}

			try {
				updateSectionUI();
				updateDuplicateBoxes();
			} catch (e:Dynamic) {}
			
			try {
				if (waveformTimer != null) waveformTimer.cancel();
				waveformTimer = new FlxTimer().start(0.1, function(tmr:FlxTimer) {
					updateWaveform();
				});
			} catch (e:Dynamic) {}

			if (showStagePreview) {
				try {
					danceCharOnSectionChange(charPreviewP1);
					danceCharOnSectionChange(charPreviewP2);
					danceCharOnSectionChange(charPreviewGF);
				} catch (e:Dynamic) {}
			}
		}
	}

	static var doFunnyNumbers:Bool = true;

	function copySection(?sectionNum:Int = 1) {
		var daSec = FlxMath.maxInt(curSection, sectionNum);

		if (daSec - sectionNum != curSection) {
			// shift by the real distance between the two section starts, so the
			// copy keeps its timing on charts that change tempo along the way
			var srcStart:Float = sectionStartTime(daSec - sectionNum);
			var dstStart:Float = sectionStartTime(curSection);

			for (note in _song.notes[daSec - sectionNum].sectionNotes) {
				var strum = dstStart + (note[0] - srcStart);

				var copiedNote:Array<Dynamic> = [strum, note[1], note[2], note[3], note[4]];
				_song.notes[curSection].sectionNotes.push(copiedNote);
			}
		}

		hasUnsavedChanges = true;
		updateGrid();
	}

	var copiedEvents:Array<Array<Dynamic>> = [];
	var copiedEventsSection:Int = 0;

	function copyEvents(sectionNum:Int = 1) {
		copiedEvents = [];
		for (event in events) {
			if (event[1] >= sectionStartTime() && event[1] < sectionStartTime(sectionNum + 1)) {
				copiedEvents.push(event);
			}
		}
	}

	function pasteEvents() {
		for (event in copiedEvents) {
			var strumTime:Float = sectionStartTime() + (event[1] - sectionStartTime(copiedEventsSection));
			var pastedEvent:Array<Dynamic> = [event[0], strumTime, event[2], event[3]];
			if (!events.contains(pastedEvent)) {
				events.push(pastedEvent);
			}
		}
		hasUnsavedChanges = true;
		updateGrid();
	}

	function pasteSection() {
		var daSec = copiedSection;

		if (daSec != curSection) {
			for (note in _song.notes[daSec].sectionNotes) {
				var strum = sectionStartTime() + (note[0] - sectionStartTime(daSec));

				var copiedNote:Array<Dynamic> = [strum, note[1], note[2], note[3], note[4]];
				_song.notes[curSection].sectionNotes.push(copiedNote);
			}
		}

		hasUnsavedChanges = true;
		updateGrid();
	}

	function updateSectionUI():Void {
		var sec = (_song != null && _song.notes != null && curSection >= 0 && curSection < _song.notes.length) ? _song.notes[curSection] : null;
		if (sec != null) {
			if (sec.bpm <= 1.0 || Math.isNaN(sec.bpm)) sec.bpm = (_song != null && _song.bpm > 1.0) ? _song.bpm : 100.0;
			check_mustHitSection.checked = sec.mustHitSection;
			check_altAnim.checked = sec.altAnim;
			check_changeBPM.checked = sec.changeBPM;
			check_changeTimeScale.checked = sec.changeTimeScale;
			stepperSectionBPM.value = sec.bpm;
		}

		updateHeads();
		if (FlxG.sound.music != null && !FlxG.sound.music.playing) {
			updateStagePreviewCamera(0.0);
		}
	}

	function getOrderedStrumlineIDs(?mustHitOverride:Null<Bool>):Array<Int> {
		return [0, 1];
	}

	public function getSectionEndTime(sec:Int):Float {
		if (Conductor.sectionStartTimes != null && sec + 1 < Conductor.sectionStartTimes.length) {
			return Conductor.getSectionStartTime(sec + 1);
		}
		var secObj = (_song != null && _song.notes != null && sec >= 0 && sec < _song.notes.length) ? _song.notes[sec] : null;
		var lenSteps:Int = Conductor.sectionLengthInSteps(secObj);
		if (lenSteps <= 0) lenSteps = Conductor.stepsPerSection;
		return Conductor.getSectionStartTime(sec) + (Conductor.stepCrochet * lenSteps);
	}

	public function getKeyCountsAtTime(daTime:Float):{keyCount:Int, playerKeyCount:Int} {
		var baseKey:Int = (_song != null && _song.keyCount != null && _song.keyCount > 0) ? _song.keyCount : 4;
		var basePKey:Int = (_song != null && _song.playerKeyCount != null && _song.playerKeyCount > 0) ? _song.playerKeyCount : 4;
		if (events == null || events.length == 0) return {keyCount: baseKey, playerKeyCount: basePKey};

		var curKey:Int = baseKey;
		var curPKey:Int = basePKey;

		var sortedChanges:Array<{time:Float, pKey:Int, key:Int}> = [];
		for (ev in events) {
			if (ev != null && ev.length >= 4) {
				var evName = Std.string(ev[0]).toLowerCase();
				if (evName == "change keycount" || evName == "change mania" || evName == "change keys") {
					var t:Float = Std.parseFloat(Std.string(ev[1]));
					var pkStr:String = StringTools.trim(Std.string(ev[2]));
					var kStr:String = StringTools.trim(Std.string(ev[3]));
					var pk:Null<Int> = Std.parseInt(pkStr);
					var k:Null<Int> = Std.parseInt(kStr);
					if (pk == null || pk < 1) pk = (k != null && k >= 1) ? k : basePKey;
					if (k == null || k < 1) k = pk;
					sortedChanges.push({time: t, pKey: pk, key: k});
				}
			}
		}
		sortedChanges.sort((a, b) -> (a.time < b.time ? -1 : (a.time > b.time ? 1 : 0)));

		for (sc in sortedChanges) {
			if (sc.time <= daTime + 0.1) {
				curPKey = sc.pKey;
				curKey = sc.key;
			}
		}
		return {keyCount: curKey, playerKeyCount: curPKey};
	}

	public function getKeyCountsAtSection(?sec:Null<Int>):{keyCount:Int, playerKeyCount:Int} {
		var targetSec:Int = (sec != null) ? sec : curSection;
		if (targetSec < 0) targetSec = 0;
		return getKeyCountsAtTime(sectionStartTime(targetSec));
	}

	public function getSectionMaxKeyCounts(sec:Int):{keyCount:Int, playerKeyCount:Int, maxCols:Int} {
		var secStart:Float = sectionStartTime(sec);
		var secEnd:Float = getSectionEndTime(sec);
		var startK = getKeyCountsAtTime(secStart);
		var maxP1:Int = startK.playerKeyCount;
		var maxOpp:Int = startK.keyCount;
		var maxTotal:Int = 1 + maxP1 + maxOpp;

		if (events != null) {
			for (ev in events) {
				if (ev != null && ev.length >= 4) {
					var evName = Std.string(ev[0]).toLowerCase();
					if (evName == "change keycount" || evName == "change mania" || evName == "change keys") {
						var t:Float = Std.parseFloat(Std.string(ev[1]));
						if (t >= secStart - 1.0 && t < secEnd + 1.0) {
							var pkStr:String = StringTools.trim(Std.string(ev[2]));
							var kStr:String = StringTools.trim(Std.string(ev[3]));
							var pk:Null<Int> = Std.parseInt(pkStr);
							var k:Null<Int> = Std.parseInt(kStr);
							if (pk == null || pk < 1) pk = (k != null && k >= 1) ? k : maxP1;
							if (k == null || k < 1) k = pk;
							if (pk > maxP1) maxP1 = pk;
							if (k > maxOpp) maxOpp = k;
							if (1 + pk + k > maxTotal) maxTotal = 1 + pk + k;
						}
					}
				}
			}
		}

		var endK = getKeyCountsAtTime(secEnd - 0.5);
		if (endK.playerKeyCount > maxP1) maxP1 = endK.playerKeyCount;
		if (endK.keyCount > maxOpp) maxOpp = endK.keyCount;
		if (1 + endK.playerKeyCount + endK.keyCount > maxTotal) maxTotal = 1 + endK.playerKeyCount + endK.keyCount;

		return {keyCount: maxOpp, playerKeyCount: maxP1, maxCols: maxTotal};
	}

	function getGridColumnFromStrumlineIDAndDataAtTime(stID:Int, dir:Int, ?mustHitOverride:Null<Bool>, time:Float):Int {
		var sec:Int = Conductor.getSectionAtTime(time);
		var mustHit:Bool = mustHitOverride != null ? mustHitOverride : ((_song != null && _song.notes != null && _song.notes.length > sec && _song.notes[sec] != null) ? _song.notes[sec].mustHitSection : true);
		var isPlayerNote:Bool = (stID == 1);
		var kCounts = getKeyCountsAtTime(time);
		var p1Key:Int = (kCounts.playerKeyCount > 0) ? kCounts.playerKeyCount : 4;
		var oppKey:Int = (kCounts.keyCount > 0) ? kCounts.keyCount : 4;
		var side0:Int = mustHit ? p1Key : oppKey;
		if (mustHit) {
			return isPlayerNote ? dir : (side0 + dir);
		} else {
			return isPlayerNote ? (side0 + dir) : dir;
		}
	}

	function getStrumlineIDFromColumnAtTime(col:Int, ?mustHitOverride:Null<Bool>, time:Float):Int {
		var sec:Int = Conductor.getSectionAtTime(time);
		var kCounts = getKeyCountsAtTime(time);
		var p1KeyCount:Int = (kCounts.playerKeyCount > 0) ? kCounts.playerKeyCount : 4;
		var p2KeyCount:Int = (kCounts.keyCount > 0) ? kCounts.keyCount : 4;
		var useMustHit:Bool = mustHitOverride != null ? mustHitOverride : ((_song != null && _song.notes != null && _song.notes.length > sec && _song.notes[sec] != null) ? _song.notes[sec].mustHitSection : true);
		if (useMustHit) {
			return (col < p1KeyCount) ? 1 : 0;
		} else {
			return (col < p2KeyCount) ? 0 : 1;
		}
	}

	function getGridColumnFromStrumlineIDAndData(stID:Int, dir:Int, ?mustHitOverride:Null<Bool>, ?sec:Null<Int>):Int {
		var targetSec:Int = (sec != null) ? sec : curSection;
		return getGridColumnFromStrumlineIDAndDataAtTime(stID, dir, mustHitOverride, sectionStartTime(targetSec));
	}

	function getStrumlineIDFromColumn(col:Int, ?mustHitOverride:Null<Bool>, ?sec:Null<Int>):Int {
		var targetSec:Int = (sec != null) ? sec : curSection;
		return getStrumlineIDFromColumnAtTime(col, mustHitOverride, sectionStartTime(targetSec));
	}

	function destroyDisplayObjects(arr:Array<flixel.FlxBasic>):Void {
		if (arr == null) return;
		for (item in arr) {
			if (item != null) { remove(item); item.destroy(); }
		}
		arr.resize(0);
	}

	function updateHeads():Void {
		if (extraHeaderIcons != null) {
			for (grp in extraHeaderIcons) {
				if (grp != null) destroyDisplayObjects(cast grp);
			}
			extraHeaderIcons.resize(0);
		} else {
			extraHeaderIcons = [];
		}

		if (extraHeaderLabels != null) {
			destroyDisplayObjects(cast extraHeaderLabels);
		} else {
			extraHeaderLabels = [];
		}

		if (leftIcons != null) {
			destroyDisplayObjects(cast leftIcons);
		} else {
			leftIcons = [];
		}
		if (rightIcons != null) {
			destroyDisplayObjects(cast rightIcons);
		} else {
			rightIcons = [];
		}

		if (_song == null) return;

		leftIconLabel.visible = true;
		rightIconLabel.visible = true;

		var iconsP1:Array<String> = loadHealthIconsForChar(_song.player1);
		var iconsP2:Array<String> = loadHealthIconsForChar(_song.player2);

			var leftNames:Array<String>;
			var rightNames:Array<String>;

			if (_song.notes[curSection].mustHitSection) {
				leftNames = iconsP1;
				rightNames = iconsP2;
				leftIconLabel.text = "Player";
				rightIconLabel.text = "Opponent";
			} else {
				leftNames = iconsP2;
				rightNames = iconsP1;
				leftIconLabel.text = "Opponent";
				rightIconLabel.text = "Player";
			}

			var startK = getKeyCountsAtSection(curSection);
			var isMustHitSec:Bool = (_song != null && _song.notes != null && _song.notes.length > curSection && _song.notes[curSection] != null) ? _song.notes[curSection].mustHitSection : true;
			var firstSideCols:Int = isMustHitSec ? startK.playerKeyCount : startK.keyCount;
			var bgX:Float = (gridBG != null) ? gridBG.x : 240.0;
			var leftX:Float = bgX + GRID_SIZE;
			var rightX:Float = bgX + (GRID_SIZE * (firstSideCols + 1));

			refreshIconGroup(leftIcons, leftNames, leftX);
			refreshIconGroup(rightIcons, rightNames, rightX);

			if (leftIcons.length > 0) {
				leftIconLabel.setPosition(leftIcons[0].x + leftIcons[0].width / 2 - leftIconLabel.width / 2, leftIcons[0].y - 14);
			}
			if (rightIcons.length > 0) {
				rightIconLabel.setPosition(rightIcons[0].x + rightIcons[0].width / 2 - rightIconLabel.width / 2, rightIcons[0].y - 14);
			}
	}

	function refreshIconGroup(group:Array<HealthIcon>, names:Array<String>, baseX:Float):Void {
		for (icon in group) {
			remove(icon);
			icon.destroy();
		}
		group.resize(0);

		var bgY:Float = (gridBG != null) ? gridBG.y : 50.0;
		for (i in 0...names.length) {
			var icon = new HealthIcon(names[i]);
			icon.scrollFactor.set(1, 1);
			icon.setGraphicSize(0, 30);
			icon.updateHitbox();
			icon.setPosition(baseX + i * 30, bgY - 32);
			add(icon);
			group.push(icon);
		}
	}

	function loadHealthIconsForChar(char:String):Array<String> {
		var characterPath:String = 'character data/' + char + '/config';
		var path:String = Paths.json(characterPath);

		if (!Assets.exists(path) && !Assets.exists(Paths.image("icons/" + char, "preload")))
			path = Paths.json('character data/bf/config');
		else if (!Assets.exists(path) && Assets.exists(Paths.image("icons/" + char, "preload")))
			return [char];

		var rawJson:String = Assets.getText(path).trim();
		var json:CharacterConfig = cast Json.parse(rawJson);
		var iconVal:Dynamic = json.healthIcon ?? char;

		if (Std.isOfType(iconVal, Array))
			return cast iconVal;

		return [cast(iconVal, String)];
	}

	function loadHealthIconFromCharacter(char:String) {
		var icons = loadHealthIconsForChar(char);
		return icons[0];
	}

	inline function updateNoteUI():Void {
		if (curSelectedNote != null)
			stepperSusLength.value = curSelectedNote[2];
	}

	var uiSettings:Array<String>;

	function getArrowConfig(daType:String):Array<String> {
		var type = daType ?? "default";
		if (!arrow_Configs.exists(type)) {
			if (PlayState.instance != null && PlayState.instance.arrow_Configs != null && PlayState.instance.arrow_Configs.exists(type)) {
				arrow_Configs.set(type, PlayState.instance.arrow_Configs.get(type));
			} else {
				var skin = _song != null ? _song.ui_Skin : "default";
				var path = Paths.txt("ui skins/" + skin + "/" + type);
				if (Assets.exists(path)) {
					arrow_Configs.set(type, CoolUtil.coolTextFile(path));
				} else {
					path = Paths.txt("ui skins/default/" + type);
					if (Assets.exists(path)) {
						arrow_Configs.set(type, CoolUtil.coolTextFile(path));
					} else {
						if (!arrow_Configs.exists("default")) {
							arrow_Configs.set("default", CoolUtil.coolTextFile(Paths.txt("ui skins/default/default")));
						}
						return arrow_Configs.get("default");
					}
				}
			}
		}
		return arrow_Configs.get(type);
	}

	function generatePattern(patternType:String, startTime:Float, targetColumn:Int = -1) {
		if (!patternDefinitions.exists(patternType)) return;
		var pat = patternDefinitions.get(patternType);
		
		var snappedTime = Math.round(startTime / Conductor.stepCrochet) * Conductor.stepCrochet;
		var generatedNotes:Array<Array<Dynamic>> = [];
		
		for (pNote in pat) {
			var noteTime = snappedTime + (pNote.offset * Conductor.stepCrochet);
			var targetSection = Conductor.getSectionAtTime(noteTime);
			
			// Fill empty sections if needed
			while (_song.notes.length <= targetSection) {
				_song.notes.push({
					lengthInSteps: 16,
					bpm: _song.bpm,
					changeBPM: false,
					mustHitSection: true,
					sectionNotes: [],
					altAnim: false,
					timeScale: [4, 4],
					changeTimeScale: false
				});
			}
			
			var finalDir = pNote.dir;
			if (targetColumn != -1) {
				var kCounts = getKeyCountsAtTime(noteTime);
				var oppKeys:Int = kCounts.keyCount;
				var p1Keys:Int = kCounts.playerKeyCount;
				if (targetColumn < oppKeys) {
					finalDir = (pNote.dir + targetColumn) % oppKeys;
				} else {
					finalDir = oppKeys + ((pNote.dir + targetColumn - oppKeys) % p1Keys);
				}
			}
			
			var noteData:Array<Dynamic> = [noteTime, finalDir, pNote.sus != null ? pNote.sus : 0, current_Note_Character];
			if (cur_Note_Type != "default" && cur_Note_Type != null) {
				noteData.push(cur_Note_Type);
			}
			
			_song.notes[targetSection].sectionNotes.push(noteData);
			generatedNotes.push(noteData);
		}
		
		patternUndoHistory.push(generatedNotes);
		updateGrid();
	}

	function updateWaveform() {
		try {
			if (!waveformEnabled || FlxG.sound.music == null || FlxG.sound.music.playing) {
				if (waveformSprite != null) waveformSprite.visible = false;
				return;
			}

			var sound:FlxSound = switch (waveformTarget) {
				case INST:
					FlxG.sound.music;
				case PLAYER:
					(vocals != null && vocals.members.length > 0) ? vocals.members[0] : FlxG.sound.music;
				default:
					FlxG.sound.music;
			};

			if (sound == null || sound.length <= 0) {
				if (waveformSprite != null) waveformSprite.visible = false;
				return;
			}

			if (waveformAnalyzer == null || waveformAnalyzer.sound != sound) {
				waveformAnalyzer = new system.AudioAnalyzer(sound);
			}

			if (waveformAnalyzer.buffer == null || waveformAnalyzer.buffer.sampleRate <= 0) {
				if (waveformSprite != null) waveformSprite.visible = false;
				return;
			}

			waveformSprite.visible = true;
			waveformSprite.y = (gridBG != null) ? gridBG.y : 50;
			var width:Int = (gridBG != null) ? Std.int(gridBG.width) : 320;
			var height:Int = (gridBG != null) ? Std.int(gridBG.height) : 640;

			if (width <= 0 || height <= 0) {
				waveformSprite.visible = false;
				return;
			}

			if (Std.int(waveformSprite.height) != height || Std.int(waveformSprite.width) != width || waveformSprite.pixels == null) {
				waveformSprite.makeGraphic(width, height, 0x00FFFFFF, true);
			}

			if (waveformSprite.pixels == null) {
				waveformSprite.visible = false;
				return;
			}

			var fillRect:openfl.geom.Rectangle = new openfl.geom.Rectangle(0, 0, width, height);
			waveformSprite.pixels.fillRect(fillRect, 0x00FFFFFF);

			var startT:Float = sectionStartTime();
			var endT:Float = sectionStartTime(curSection + 1);
			if (startT < 0) startT = 0;
			if (endT > sound.length) endT = sound.length;
			if (startT >= endT) {
				waveformSprite.visible = false;
				return;
			}

			var gSize:Int = Std.int(GRID_SIZE * 8);
			var hSize:Int = Std.int(gSize / 2);
			var duration:Float = endT - startT;
			var msPerPixel:Float = duration / height;

			fillRect.setTo(0, 0, 0, 1);
			for (y in 0...height) {
				var pixelStart:Float = startT + y * msPerPixel;
				var pixelEnd:Float = pixelStart + msPerPixel;
				if (pixelEnd > endT) pixelEnd = endT;

				var amp:Float = waveformAnalyzer.analyze(pixelStart, pixelEnd);
				var ampWidth:Float = FlxMath.bound(amp * gSize, 0, hSize);

				if (ampWidth > 0.5) {
					fillRect.x = hSize - ampWidth;
					fillRect.y = y;
					fillRect.width = ampWidth * 2;
					fillRect.height = 1;
					waveformSprite.pixels.fillRect(fillRect, FlxColor.WHITE);
				}
			}
		} catch (e:Dynamic) {
			if (waveformSprite != null) waveformSprite.visible = false;
		}
	}

	function removeCharGroupMembers(char:game.Character):Void {
		if (char != null && char.isCharacterGroup && char.otherCharacters != null) {
			for (c in char.otherCharacters) {
				if (c != null) remove(c);
			}
		}
	}

	function insertCharGroup(char:game.Character, idx:Int):Void {
		if (char == null) return;
		if (char.isCharacterGroup && char.otherCharacters != null) {
			for (c in char.otherCharacters) {
				if (c != null) {
					insert(idx++, c);
					c.visible = true;
				}
			}
		} else {
			insert(idx, char);
			char.visible = true;
		}
	}

	function charGroupCount(char:game.Character):Int {
		if (char == null) return 0;
		if (char.isCharacterGroup && char.otherCharacters != null) {
			return char.otherCharacters.length;
		}
		return 1;
	}

	function setCharGroupCamera(char:game.Character, cam:FlxCamera):Void {
		if (char == null) return;
		if (char.isCharacterGroup && char.otherCharacters != null) {
			for (c in char.otherCharacters) {
				if (c != null) {
					setCamerasRecursive(c, cam);
					c.visible = true;
				}
			}
		} else {
			setCamerasRecursive(char, cam);
			char.visible = true;
		}
	}

	function setCharGroupVisible(char:game.Character, vis:Bool):Void {
		if (char == null) return;
		if (char.isCharacterGroup && char.otherCharacters != null) {
			for (c in char.otherCharacters) {
				if (c != null) c.visible = vis;
			}
		}
	}

	// ==================== PERFORMANCE HELPERS ====================

	function destroyGroupMembers<T:flixel.FlxBasic>(group:flixel.group.FlxGroup.FlxTypedGroup<T>):Void {
		if (group == null) return;
		for (member in group.members) {
			if (member != null) member.destroy();
		}
		group.clear();
	}

	function applyGridAlpha(a:Float):Void {
		if (gridBG != null) gridBG.alpha = a;
		if (gridBGNext != null) gridBGNext.alpha = a * 0.9;
	}

	function refreshAll():Void {
		refreshCursorSprites();
		updateGrid();
		updateHeads();
	}

	function extractNoteChars(i:Array<Dynamic>):{noteChar:Dynamic, noteChars:Array<Int>} {
		var noteChar:Dynamic = i[3];
		var noteChars:Array<Int> = [];
		if (noteChar != null && Std.isOfType(noteChar, Array)) {
			noteChars = cast noteChar;
			noteChar = noteChars.length > 0 ? noteChars[0] : 0;
		} else if (noteChar == null) {
			noteChar = 0;
		}
		return {noteChar: noteChar, noteChars: noteChars};
	}

	function resolveStrumlineInfo(stID:Int, noteInfo:Int, secMustHit:Bool, ?sec:Null<Int>, ?time:Null<Float>):{mustPress:Bool, strumKeyCount:Int} {
		var kCounts = (time != null) ? getKeyCountsAtTime(time) : getKeyCountsAtSection(sec != null ? sec : curSection);
		var p1Key:Int = (kCounts.playerKeyCount > 0) ? kCounts.playerKeyCount : 4;
		var oppKey:Int = (kCounts.keyCount > 0) ? kCounts.keyCount : 4;
		var side0:Int = secMustHit ? p1Key : oppKey;
		var mustPress:Bool = (stID == 1) ? true : ((stID == 0) ? false : (secMustHit ? (noteInfo < side0) : (noteInfo >= side0)));
		var strumKeyCount:Int = mustPress ? p1Key : oppKey;
		if (strumKeyCount <= 0) strumKeyCount = 4;
		return {mustPress: mustPress, strumKeyCount: strumKeyCount};
	}

	var lastReceptorKeyCount:Int = -1;
	var lastReceptorPlayerKeyCount:Int = -1;
	var lastReceptorMustHit:Bool = false;

	public function rebuildStrumlineReceptors(?kCounts:{keyCount:Int, playerKeyCount:Int}, ?force:Bool = false):Void {
		var curTime:Float = (FlxG.sound.music != null && FlxG.sound.music.playing)
			? Conductor.songPosition
			: (sectionStartTime(curSection) + getStrumTime(strumLine != null ? strumLine.y : (gridBG != null ? gridBG.y : 50)));
		if (kCounts == null) kCounts = getKeyCountsAtTime(curTime);

		var isMustHitSec:Bool = (_song != null && _song.notes != null && _song.notes.length > curSection && _song.notes[curSection] != null) ? _song.notes[curSection].mustHitSection : true;

		if (!force && lastReceptorKeyCount == kCounts.keyCount && lastReceptorPlayerKeyCount == kCounts.playerKeyCount && lastReceptorMustHit == isMustHitSec) {
			return;
		}

		lastReceptorKeyCount = kCounts.keyCount;
		lastReceptorPlayerKeyCount = kCounts.playerKeyCount;
		lastReceptorMustHit = isMustHitSec;

		if (strumlineReceptors != null) {
			for (m in strumlineReceptors.members) {
				if (m != null) m.destroy();
			}
			strumlineReceptors.clear();
		} else {
			strumlineReceptors = new FlxTypedGroup<FlxSprite>();
			add(strumlineReceptors);
		}

		var leftKeyCnt:Int = isMustHitSec ? kCounts.playerKeyCount : kCounts.keyCount;
		var rightKeyCnt:Int = isMustHitSec ? kCounts.keyCount : kCounts.playerKeyCount;
		var totalKeyCols = leftKeyCnt + rightKeyCnt;

		for (i in 0...totalKeyCols) {
			var isLeftSide:Bool = (i < leftKeyCnt);
			var isPlayerCol = isMustHitSec ? isLeftSide : !isLeftSide;
			var keyDir = isLeftSide ? i : (i - leftKeyCnt);
			var receptorKeyCount = isPlayerCol ? kCounts.playerKeyCount : kCounts.keyCount;

			var receptor:Note = new Note(0, keyDir % receptorKeyCount, null, false, 0, "default", _song, [0], isPlayerCol, true, -1, receptorKeyCount);
			var targetY:Float = (gridBG != null ? gridBG.y : 50);
			receptor.x = (gridBG != null ? gridBG.x : 240) + (i + 1) * GRID_SIZE;
			receptor.setGraphicSize(GRID_SIZE, GRID_SIZE);
			receptor.updateHitbox();

			receptor.y = targetY;
			receptor.alpha = 0.55;

			strumlineReceptors.add(receptor);
		}
	}

	private function setCamerasRecursive(basic:flixel.FlxBasic, cam:FlxCamera):Void {
		if (basic == null) return;
		if (Std.isOfType(basic, FlxSprite)) {
			cast(basic, FlxSprite).cameras = [cam];
		} else if (Std.isOfType(basic, flixel.group.FlxGroup)) {
			var grp:flixel.group.FlxGroup = cast basic;
			grp.cameras = [cam];
			for (m in grp.members) {
				setCamerasRecursive(m, cam);
			}
		}
	}

	function reloadStagePreview():Void {
		if (!showStagePreview) return;
		// Destroy existing preview objects
		if (stageGroupPreview != null) {
			remove(stageGroupPreview);
			if (stageGroupPreview.foregroundSprites != null) remove(stageGroupPreview.foregroundSprites);
			if (stageGroupPreview.infrontOfGFSprites != null) remove(stageGroupPreview.infrontOfGFSprites);
			stageGroupPreview.destroy();
			stageGroupPreview = null;
		}
		if (charPreviewGF != null) { remove(charPreviewGF); removeCharGroupMembers(charPreviewGF); charPreviewGF.destroy(); charPreviewGF = null; }
		if (charPreviewP2 != null) { remove(charPreviewP2); removeCharGroupMembers(charPreviewP2); charPreviewP2.destroy(); charPreviewP2 = null; }
		if (charPreviewP1 != null) { remove(charPreviewP1); removeCharGroupMembers(charPreviewP1); charPreviewP1.destroy(); charPreviewP1 = null; }

		// Recreate without toggling - buildPreview handles the actual creation
		buildStagePreview();
	}

	function toggleStagePreview():Void {
		showStagePreview = !showStagePreview;
		if (menuBG != null) menuBG.visible = !showStagePreview;

		if (showStagePreview) {
			buildStagePreview();
		} else {
			FlxG.camera.bgColor = 0xFF181818;
			if (camStagePreview != null) camStagePreview.visible = false;
			if (stageGroupPreview != null) stageGroupPreview.visible = false;
			if (charPreviewP1 != null) { charPreviewP1.visible = false; setCharGroupVisible(charPreviewP1, false); }
			if (charPreviewP2 != null) { charPreviewP2.visible = false; setCharGroupVisible(charPreviewP2, false); }
			if (charPreviewGF != null) { charPreviewGF.visible = false; setCharGroupVisible(charPreviewGF, false); }

			if (gridBG != null) gridBG.alpha = 1.0;
			if (gridBGNext != null) gridBGNext.alpha = 1.0;
			applyGridAlpha(gridAlpha);
			if (UI_box != null) UI_box.visible = true;
			if (topMenuBar != null) topMenuBar.visible = true;
			if (topMenuItems != null) {
				for (item in topMenuItems) item.visible = true;
			}
		}
	}

	function buildStagePreview():Void {
			FlxG.camera.bgColor = FlxColor.TRANSPARENT;
			if (camStagePreview != null) {
				camStagePreview.bgColor = 0xFF181818;
				camStagePreview.visible = true;
			}

			if (stageGroupPreview == null) {
				var stgName:String = (_song != null && _song.stage != null && _song.stage != "") ? _song.stage : "stage";
				stageGroupPreview = new game.StageGroup();
				stageGroupPreview.stage = stgName;
			try {
				stageGroupPreview.updateStage(stgName);
			} catch (e:Dynamic) {}
			}
			stageGroupPreview.visible = true;

			if (charPreviewP1 == null && _song != null) {
				try {
					var p1Char:String = (_song.player1 != null && _song.player1 != "") ? _song.player1 : "bf";
					var p2Char:String = (_song.player2 != null && _song.player2 != "") ? _song.player2 : "dad";
					var gfChar:String = (_song.gf != null && _song.gf != "") ? _song.gf : ((_song.gfVersion != null && _song.gfVersion != "") ? _song.gfVersion : ((_song.player3 != null && _song.player3 != "") ? _song.player3 : "gf"));

					charPreviewGF = new game.Character(400, 130, gfChar, false);
					charPreviewP2 = new game.Character(100, 100, p2Char, false);
					charPreviewP1 = new game.Character(770, 450, p1Char, true);
				} catch (e:Dynamic) {}
			}

			// Ensure proper z-stacking: stage BG -> GF -> Dad -> BF -> InfrontGF -> Foreground
			var baseIdx:Int = (menuBG != null && members.contains(menuBG)) ? members.indexOf(menuBG) : 0;
			remove(stageGroupPreview);
			if (charPreviewGF != null) { remove(charPreviewGF); removeCharGroupMembers(charPreviewGF); }
			if (charPreviewP2 != null) { remove(charPreviewP2); removeCharGroupMembers(charPreviewP2); }
			if (charPreviewP1 != null) { remove(charPreviewP1); removeCharGroupMembers(charPreviewP1); }
			if (stageGroupPreview != null && stageGroupPreview.infrontOfGFSprites != null) remove(stageGroupPreview.infrontOfGFSprites);
			if (stageGroupPreview != null && stageGroupPreview.foregroundSprites != null) remove(stageGroupPreview.foregroundSprites);

			insert(baseIdx, stageGroupPreview);
			var currIdx:Int = members.indexOf(stageGroupPreview) + 1;

			if (charPreviewGF != null) {
				charPreviewGF.visible = true;
				setCharGroupVisible(charPreviewGF, true);
				insertCharGroup(charPreviewGF, currIdx);
				currIdx += charGroupCount(charPreviewGF);
			}
			if (charPreviewP2 != null) {
				charPreviewP2.visible = true;
				setCharGroupVisible(charPreviewP2, true);
				insertCharGroup(charPreviewP2, currIdx);
				currIdx += charGroupCount(charPreviewP2);
			}
			if (charPreviewP1 != null) {
				charPreviewP1.visible = true;
				setCharGroupVisible(charPreviewP1, true);
				insertCharGroup(charPreviewP1, currIdx);
				currIdx += charGroupCount(charPreviewP1);
			}
			if (stageGroupPreview != null && stageGroupPreview.infrontOfGFSprites != null) { insert(currIdx++, stageGroupPreview.infrontOfGFSprites); }
			if (stageGroupPreview != null && stageGroupPreview.foregroundSprites != null) { insert(currIdx++, stageGroupPreview.foregroundSprites); }

			if (stageGroupPreview != null && charPreviewP1 != null && charPreviewP2 != null && charPreviewGF != null) {
				stageGroupPreview.setCharOffsets(charPreviewP1, charPreviewGF, charPreviewP2);
				updateStagePreviewCamera(0.0);
			}

			if (stageGroupPreview != null) {
				setCamerasRecursive(stageGroupPreview, camStagePreview);
				if (stageGroupPreview.foregroundSprites != null) setCamerasRecursive(stageGroupPreview.foregroundSprites, camStagePreview);
				if (stageGroupPreview.infrontOfGFSprites != null) setCamerasRecursive(stageGroupPreview.infrontOfGFSprites, camStagePreview);
			}
			setCharGroupCamera(charPreviewGF, camStagePreview);
			setCharGroupCamera(charPreviewP2, camStagePreview);
			setCharGroupCamera(charPreviewP1, camStagePreview);

			if (gridBG != null) gridBG.alpha = 0.6;
			if (gridBGNext != null) gridBGNext.alpha = 0.5;
	}

	function updateStagePreviewCamera(elapsed:Float = 0.0):Void {
		if (!showStagePreview || camStagePreview == null) return;
		if (stageGroupPreview == null || charPreviewP1 == null || charPreviewP2 == null) return;

		try {
			var secIndex:Int = curSection;
			if (FlxG.sound.music != null && FlxG.sound.music.playing) {
				var calculatedSec = Conductor.getSectionAtTime(Conductor.songPosition);
				if (calculatedSec >= 0 && _song != null && _song.notes != null && calculatedSec < _song.notes.length) {
					secIndex = calculatedSec;
				}
			}
			if (secIndex < 0) secIndex = 0;
			if (_song != null && _song.notes != null && secIndex >= _song.notes.length) secIndex = _song.notes.length - 1;

			var secData = (_song != null && _song.notes != null && _song.notes.length > secIndex) ? _song.notes[secIndex] : null;
			var mustHit:Bool = (secData != null) ? secData.mustHitSection : true;
			var isGf:Bool = (secData != null && Reflect.hasField(secData, "gfSection") && Reflect.field(secData, "gfSection") == true);

			var curPos:Float = (FlxG.sound.music != null && FlxG.sound.music.playing) ? Conductor.songPosition : sectionStartTime(secIndex);

			var camOverrideTarget:Int = -1;
			var targetZoom:Float = stageGroupPreview.camZoom > 0 ? stageGroupPreview.camZoom : 1.0;

			if (events != null && events.length > 0) {
				var activeEvents:Array<Array<Dynamic>> = events.filter(e -> e != null && e.length >= 2 && (e[1] : Float) <= curPos);
				activeEvents.sort((a, b) -> (a[1] : Float) < (b[1] : Float) ? -1 : 1);

				for (ev in activeEvents) {
					var evName:String = (ev[0] != null) ? Std.string(ev[0]).trim() : "";
					var val1:String = (ev.length > 2 && ev[2] != null) ? Std.string(ev[2]).trim() : "";
					var val2:String = (ev.length > 3 && ev[3] != null) ? Std.string(ev[3]).trim() : "";
					var evTime:Float = (ev[1] : Float);

					if (evName == "Camera Movement" || evName == "Change Camera Focus" || evName == "Camera Focus") {
						var vLower = val1.toLowerCase();
						if (vLower == "0" || vLower == "dad" || vLower == "opponent" || vLower == "p2") {
							camOverrideTarget = 0;
						} else if (vLower == "1" || vLower == "bf" || vLower == "boyfriend" || vLower == "player" || vLower == "p1") {
							camOverrideTarget = 1;
						} else if (vLower == "2" || vLower == "gf" || vLower == "girlfriend") {
							camOverrideTarget = 2;
						}
					} else if (evName == "Set Cam Zoom" || evName == "Camera Zoom") {
						var zVal:Float = Std.parseFloat(val1);
						if (!Math.isNaN(zVal) && zVal > 0) {
							targetZoom = zVal;
						}
					} else if (evName == "Add Camera Zoom") {
						var zVal:Float = Std.parseFloat(val1);
						if (!Math.isNaN(zVal)) {
							targetZoom += zVal;
						}
					} else if (evName == "Play Animation" || evName == "Sing Animation") {
						if (curPos - evTime <= 1200 && curPos - evTime >= 0) {
							var vLower = val1.toLowerCase();
							var targetCharSpr:game.Character = null;
							if (vLower == "bf" || vLower == "boyfriend" || vLower == "1" || vLower == "player" || vLower == "p1")
								targetCharSpr = charPreviewP1;
							else if (vLower == "dad" || vLower == "opponent" || vLower == "0" || vLower == "p2")
								targetCharSpr = charPreviewP2;
							else if (vLower == "gf" || vLower == "girlfriend" || vLower == "2")
								targetCharSpr = charPreviewGF;

							if (targetCharSpr != null && val2 != "" && targetCharSpr.hasAnim(val2)) {
								targetCharSpr.playAnim(val2, true);
							}
						}
					}
				}
			}

			var targetChar:game.Character = null;
			if (camOverrideTarget == 2 || (camOverrideTarget == -1 && isGf)) {
				targetChar = charPreviewGF;
			} else if (camOverrideTarget == 1 || (camOverrideTarget == -1 && mustHit)) {
				targetChar = charPreviewP1;
			} else if (camOverrideTarget == 0 || (camOverrideTarget == -1 && !mustHit)) {
				targetChar = charPreviewP2;
			}
			if (targetChar == null) targetChar = mustHit ? charPreviewP1 : charPreviewP2;

			var targetX:Float = 0;
			var targetY:Float = 0;

			if (targetChar == charPreviewGF && charPreviewGF != null) {
				var gfMid = charPreviewGF.getMidpoint();
				var gfStgOff = (stageGroupPreview.gf_Cam_Offset != null) ? stageGroupPreview.gf_Cam_Offset : null;
				targetX = gfMid.x + charPreviewGF.cameraOffset[0] + (gfStgOff != null ? gfStgOff.x : 0);
				targetY = gfMid.y + charPreviewGF.cameraOffset[1] + (gfStgOff != null ? gfStgOff.y : 0);
				gfMid.put();
			} else if (targetChar == charPreviewP1 && charPreviewP1 != null) {
				var bfMid = charPreviewP1.getMidpoint();
				var stgP1CamX:Float = stageGroupPreview.p1_Cam_Offset != null ? stageGroupPreview.p1_Cam_Offset.x : 0;
				var stgP1CamY:Float = stageGroupPreview.p1_Cam_Offset != null ? stageGroupPreview.p1_Cam_Offset.y : 0;
				targetX = bfMid.x - 100 + charPreviewP1.cameraOffset[0] + stgP1CamX;
				targetY = bfMid.y - 100 + charPreviewP1.cameraOffset[1] + stgP1CamY;
				bfMid.put();
			} else if (charPreviewP2 != null) {
				var dadMid = charPreviewP2.getMidpoint();
				var stgP2CamX:Float = stageGroupPreview.p2_Cam_Offset != null ? stageGroupPreview.p2_Cam_Offset.x : 0;
				var stgP2CamY:Float = stageGroupPreview.p2_Cam_Offset != null ? stageGroupPreview.p2_Cam_Offset.y : 0;
				targetX = dadMid.x + 150 + charPreviewP2.cameraOffset[0] + stgP2CamX;
				targetY = dadMid.y - 100 + charPreviewP2.cameraOffset[1] + stgP2CamY;
				dadMid.put();
			}

			// Direction offset from current sing animation (like CameraSystem.getDirectionOffset)
			var dirOffsetX:Float = 0;
			var dirOffsetY:Float = 0;
			if (targetChar != null) {
				var camChar = targetChar.getCameraCharacter();
				if (camChar != null && camChar.hasAnims() && camChar.animation.curAnim != null) {
					var anim = camChar.animation.curAnim.name.toLowerCase();
					switch (anim) {
						case "singleft": dirOffsetX = -50;
						case "singright": dirOffsetX = 50;
						case "singup": dirOffsetY = -50;
						case "singdown": dirOffsetY = 50;
					}
				}
			}

			targetX += dirOffsetX;
			targetY += dirOffsetY;

			var destX:Float = targetX - FlxG.width * 0.5;
			var destY:Float = targetY - FlxG.height * 0.5;

			if (elapsed > 0) {
				var k:Float = FlxMath.bound(elapsed * 2.4, 0, 1);
				camStagePreview.scroll.x = FlxMath.lerp(camStagePreview.scroll.x, destX, k);
				camStagePreview.scroll.y = FlxMath.lerp(camStagePreview.scroll.y, destY, k);
			} else {
				camStagePreview.scroll.x = destX;
				camStagePreview.scroll.y = destY;
			}

			camStagePreview.zoom = targetZoom;
		} catch (e:Dynamic) { Main.logSilentError(e, "ChartingState: stage preview camera"); }
	}

	function refreshCursorSprites():Void {
		if (dummyArrow != null) {
			var oldX = dummyArrow.x;
			var oldY = dummyArrow.y;
			dummyArrow.makeGraphic(GRID_SIZE, GRID_SIZE);
			dummyArrow.x = oldX;
			dummyArrow.y = oldY;
		}
		if (noteHoverer != null) {
			var oldX = noteHoverer.x;
			var oldY = noteHoverer.y;
			noteHoverer.makeGraphic(GRID_SIZE - 4, GRID_SIZE - 4, 0xFFFFFFFF);
			noteHoverer.alpha = 0.4;
			noteHoverer.x = oldX;
			noteHoverer.y = oldY;
		}
	}

	function updateGrid():Void {
		var oldGridX:Float = (gridBG != null) ? gridBG.x : 240.0;
		if (gridBG != null) {
			remove(gridBG);
			gridBG.kill();
			gridBG.destroy();
		}

		var secMax = getSectionMaxKeyCounts(curSection);
		var totalCols:Int = secMax.maxCols;

		var gridW:Int = GRID_SIZE * totalCols;
		var gridH:Int = Std.int((GRID_SIZE * Conductor.stepsPerSection) * zoomLevel);
		var gridX:Float = oldGridX;

		gridBG = new FlxSprite().makeGraphic(gridW, gridH, FlxColor.TRANSPARENT, true);
		gridBG.x = gridX;
		gridBG.y = 50;
		var tex = gridBG.pixels;
		var drawRect:openfl.geom.Rectangle = new openfl.geom.Rectangle();
		drawRect.setTo(0, 0, gridW, gridH);
		tex.fillRect(drawRect, 0x00000000);
		var rows:Int = Std.int(gridH / GRID_SIZE);

		var isMustHitSec:Bool = (_song != null && _song.notes != null && _song.notes.length > curSection && _song.notes[curSection] != null) ? _song.notes[curSection].mustHitSection : true;
		var curSecStartStep:Float = Conductor.getSectionStartStep(curSection);

		for (cy in 0...rows) {
			var rowStep:Float = curSecStartStep + (cy / zoomLevel);
			var rowTime:Float = Conductor.getTimeInSteps(rowStep);
			var rowK = getKeyCountsAtTime(rowTime);
			var rowLeft:Int = isMustHitSec ? rowK.playerKeyCount : rowK.keyCount;
			var rowRight:Int = isMustHitSec ? rowK.keyCount : rowK.playerKeyCount;
			var rowCols:Int = 1 + rowLeft + rowRight;

			for (cx in 0...rowCols) {
				var isDark:Bool = (cx + cy) % 2 != 0;
				var col:FlxColor = (cx == 0) ? (isDark ? 0xFF1C1C1C : 0xFF282828) : (isDark ? 0xFF242424 : 0xFF363636);
				drawRect.setTo(cx * GRID_SIZE, cy * GRID_SIZE, GRID_SIZE, GRID_SIZE);
				tex.fillRect(drawRect, col);
				drawRect.setTo(cx * GRID_SIZE, cy * GRID_SIZE, 1, GRID_SIZE);
				tex.fillRect(drawRect, 0xFF141414);
				drawRect.setTo(cx * GRID_SIZE, cy * GRID_SIZE, GRID_SIZE, 1);
				tex.fillRect(drawRect, 0xFF141414);
			}

			drawRect.setTo(rowCols * GRID_SIZE - 1, cy * GRID_SIZE, 1, GRID_SIZE);
			tex.fillRect(drawRect, 0xFF141414);
			drawRect.setTo(GRID_SIZE, cy * GRID_SIZE, 2, GRID_SIZE);
			tex.fillRect(drawRect, 0x99FFFFFF);
			var midX:Int = (1 + rowLeft) * GRID_SIZE;
			drawRect.setTo(midX, cy * GRID_SIZE, 2, GRID_SIZE);
			tex.fillRect(drawRect, 0x99FFFFFF);

			if (cy % 4 == 0) {
				var beatLineCol:FlxColor = (cy % 16 == 0) ? 0xFFFFFFFF : 0xFF777777;
				var lineH:Int = (cy % 16 == 0) ? 2 : 1;
				drawRect.setTo(0, cy * GRID_SIZE, rowCols * GRID_SIZE, lineH);
				tex.fillRect(drawRect, beatLineCol);
			}
		}
		gridBG.pixels = tex;
		gridBG.dirty = true;

		remove(gridBGNext);
		gridBGNext.kill();
		gridBGNext.destroy();

		var nextSecIdx:Int = curSection + 1;
		var nextSecMax = (nextSecIdx < _song.notes.length) ? getSectionMaxKeyCounts(nextSecIdx) : secMax;
		var nextTotalCols:Int = nextSecMax.maxCols;
		var gridW2:Int = GRID_SIZE * nextTotalCols;
		var gridH2:Int = gridH;

		gridBGNext = new FlxSprite().makeGraphic(gridW2, gridH2, FlxColor.TRANSPARENT, true);
		gridBGNext.x = gridX;
		gridBGNext.y = gridBG.y + gridBG.height;
		var tex2 = gridBGNext.pixels;
		drawRect.setTo(0, 0, gridW2, gridH2);
		tex2.fillRect(drawRect, 0x00000000);
		var nextSecMustHit:Bool = (nextSecIdx < _song.notes.length && _song.notes[nextSecIdx] != null) ? _song.notes[nextSecIdx].mustHitSection : true;
		var nextSecStartStep:Float = Conductor.getSectionStartStep(nextSecIdx);

		for (cy in 0...rows) {
			var rowStep:Float = nextSecStartStep + (cy / zoomLevel);
			var rowTime:Float = Conductor.getTimeInSteps(rowStep);
			var rowK = getKeyCountsAtTime(rowTime);
			var rowLeft:Int = nextSecMustHit ? rowK.playerKeyCount : rowK.keyCount;
			var rowRight:Int = nextSecMustHit ? rowK.keyCount : rowK.playerKeyCount;
			var rowCols:Int = 1 + rowLeft + rowRight;

			for (cx in 0...rowCols) {
				var isDark:Bool = (cx + cy) % 2 != 0;
				var col:FlxColor = (cx == 0) ? (isDark ? 0xFF141414 : 0xFF1E1E1E) : (isDark ? 0xFF181818 : 0xFF2A2A2A);
				drawRect.setTo(cx * GRID_SIZE, cy * GRID_SIZE, GRID_SIZE, GRID_SIZE);
				tex2.fillRect(drawRect, col);
				drawRect.setTo(cx * GRID_SIZE, cy * GRID_SIZE, 1, GRID_SIZE);
				tex2.fillRect(drawRect, 0xFF101010);
				drawRect.setTo(cx * GRID_SIZE, cy * GRID_SIZE, GRID_SIZE, 1);
				tex2.fillRect(drawRect, 0xFF101010);
			}

			drawRect.setTo(rowCols * GRID_SIZE - 1, cy * GRID_SIZE, 1, GRID_SIZE);
			tex2.fillRect(drawRect, 0xFF101010);
			drawRect.setTo(GRID_SIZE, cy * GRID_SIZE, 2, GRID_SIZE);
			tex2.fillRect(drawRect, 0x66FFFFFF);
			var midX:Int = (1 + rowLeft) * GRID_SIZE;
			drawRect.setTo(midX, cy * GRID_SIZE, 2, GRID_SIZE);
			tex2.fillRect(drawRect, 0x66FFFFFF);

			if (cy % 4 == 0) {
				var beatLineCol:FlxColor = (cy % 16 == 0) ? 0xFFCCCCCC : 0xFF666666;
				var lineH:Int = (cy % 16 == 0) ? 2 : 1;
				drawRect.setTo(0, cy * GRID_SIZE, rowCols * GRID_SIZE, lineH);
				tex2.fillRect(drawRect, beatLineCol);
			}
		}
		gridBGNext.pixels = tex2;
		gridBGNext.dirty = true;

		var insertIdx:Int = members.length;
		inline function checkIdx(obj:flixel.FlxBasic):Void {
			if (obj != null) {
				var idx = members.indexOf(obj);
				if (idx != -1 && idx < insertIdx) insertIdx = idx;
			}
		}
		checkIdx(waveformSprite);
		checkIdx(leftIconLabel);
		checkIdx(rightIconLabel);
		checkIdx(strumLine);
		checkIdx(dummyArrow);
		checkIdx(noteHoverer);
		checkIdx(gridEventReceptors);
		checkIdx(strumlineReceptors);
		checkIdx(gridSeparators);
		checkIdx(curRenderedNotes);
		checkIdx(curRenderedIds);
		checkIdx(duplicateBoxes);
		checkIdx(curRenderedEvents);

		if (insertIdx < members.length) {
			insert(insertIdx, gridBG);
			insert(insertIdx + 1, gridBGNext);
		} else {
			add(gridBG);
			add(gridBGNext);
		}

		if (gridSeparators != null) {
			for (m in gridSeparators.members) {
				if (m != null) m.destroy();
			}
			gridSeparators.clear();
		} else {
			gridSeparators = new FlxTypedGroup<FlxSprite>();
			add(gridSeparators);
		}

		var startK = getKeyCountsAtSection(curSection);
		rebuildStrumlineReceptors(startK, false);

		if (gridEventReceptors != null) {
			for (m in gridEventReceptors.members) {
				if (m != null) m.destroy();
			}
			gridEventReceptors.clear();
		} else {
			gridEventReceptors = new FlxTypedGroup<FlxSprite>();
			add(gridEventReceptors);
		}

		// Render updated receptors at the exact event rows where keycount changes in this section
		var curSecStart:Float = sectionStartTime();
		var curSecEnd:Float = getSectionEndTime(curSection);
		if (events != null && events.length > 0) {
			for (ev in events) {
				if (ev != null && ev.length >= 4) {
					var evName = Std.string(ev[0]).toLowerCase();
					if (evName == "change keycount" || evName == "change mania" || evName == "change keys") {
						var evTime:Float = Std.parseFloat(Std.string(ev[1]));
						if (evTime >= curSecStart + 0.5 && evTime < curSecEnd - 0.5) {
							var evY:Float = Math.floor(getYfromStrum(evTime - curSecStart));
							var evKCounts = getKeyCountsAtTime(evTime + 0.1);
							var evLeftKeyCnt:Int = isMustHitSec ? evKCounts.playerKeyCount : evKCounts.keyCount;
							var evRightKeyCnt:Int = isMustHitSec ? evKCounts.keyCount : evKCounts.playerKeyCount;
							var evTotalKeyCols:Int = evLeftKeyCnt + evRightKeyCnt;

							for (i in 0...evTotalKeyCols) {
								var isLeftSide:Bool = (i < evLeftKeyCnt);
								var isPlayerCol:Bool = isMustHitSec ? isLeftSide : !isLeftSide;
								var keyDir:Int = isLeftSide ? i : (i - evLeftKeyCnt);
								var receptorKeyCount:Int = isPlayerCol ? evKCounts.playerKeyCount : evKCounts.keyCount;

								var midReceptor:Note = new Note(0, keyDir % receptorKeyCount, null, false, 0, "default", _song, [0], isPlayerCol, true, -1, receptorKeyCount);
								midReceptor.x = gridBG.x + (i + 1) * GRID_SIZE;
								midReceptor.setGraphicSize(GRID_SIZE, GRID_SIZE);
								midReceptor.updateHitbox();
								midReceptor.y = evY;
								midReceptor.alpha = 0.55;
								gridEventReceptors.add(midReceptor);
							}

							var evDivider:FlxSprite = new FlxSprite(gridBG.x + GRID_SIZE, evY).makeGraphic(GRID_SIZE * evTotalKeyCols, 2, FlxColor.WHITE);
							evDivider.alpha = 0.8;
							gridSeparators.add(evDivider);
						}
					}
				}
			}
		}

		if (strumLine != null) {
			strumLine.x = gridBG.x;
			var secStartCols:Int = 1 + startK.keyCount + startK.playerKeyCount;
			strumLine.makeGraphic(secStartCols * GRID_SIZE, 4);
		}

		updateHeads();

		destroyGroupMembers(curRenderedNotes);
		destroyGroupMembers(curRenderedEvents);
		destroyGroupMembers(curRenderedIds);
		destroyGroupMembers(duplicateBoxes);

		if (_song == null || _song.notes == null || _song.notes.length == 0) {
			addSection();
		}
		if (curSection < 0) curSection = 0;
		if (_song != null && _song.notes != null && curSection >= _song.notes.length) {
			curSection = _song.notes.length - 1;
		}

		var curSec = (_song != null && _song.notes != null && curSection >= 0 && curSection < _song.notes.length) ? _song.notes[curSection] : null;
		if (curSec == null) {
			return;
		}

		var sectionInfo:Array<Dynamic> = (curSec.sectionNotes != null) ? curSec.sectionNotes : [];
		var nextSectionNotes:Array<Dynamic> = (_song != null && _song.notes != null && curSection + 1 < _song.notes.length && _song.notes[curSection + 1] != null && _song.notes[curSection + 1].sectionNotes != null) ? _song.notes[curSection + 1].sectionNotes : null;

		// The grid is laid out in steps, so the conductor has to be on the tempo
		// of the section being drawn. Resolved through the BPM map so it always
		// matches the timeline `sectionStartTime` reports.
		Conductor.syncBPM(sectionStartTime(curSection));

		function renderNoteFromSection(i:Array<Dynamic>, secIdx:Int):Void {
			var noteInfo:Int = Std.int(i[1]);
			var daStrumTime:Float = i[0];
			var daSus:Float = i[2];

			var daType:String = i[4];
			if (daType == null) daType = "default";

			var curSecMustHit:Bool = (_song.notes[curSection] != null) ? _song.notes[curSection].mustHitSection : true;
			var secMustHit:Bool = (_song.notes[secIdx] != null) ? _song.notes[secIdx].mustHitSection : true;

			var noteKCounts = getKeyCountsAtTime(daStrumTime);
			var noteOppKeys:Int = (noteKCounts.keyCount > 0) ? noteKCounts.keyCount : 4;
			var noteP1Keys:Int = (noteKCounts.playerKeyCount > 0) ? noteKCounts.playerKeyCount : 4;
			var totalNoteCols:Int = noteOppKeys + noteP1Keys;
			if (noteInfo < 0 || noteInfo >= totalNoteCols) return;

			var stID:Int = (i.length > 5 && i[5] != null) ? Std.int(i[5]) : getStrumlineIDFromColumnAtTime(noteInfo, secMustHit, daStrumTime);
			var resolved = resolveStrumlineInfo(stID, noteInfo, secMustHit, secIdx, daStrumTime);
			var mustPress = resolved.mustPress;
			var strumKeyCount = resolved.strumKeyCount;

			var side0Keys:Int = secMustHit ? noteP1Keys : noteOppKeys;
			var isSide0:Bool = (noteInfo < side0Keys);
			var goodNoteInfo:Int = isSide0 ? noteInfo : (noteInfo - side0Keys);
			if (goodNoteInfo < 0) goodNoteInfo = 0;
			if (goodNoteInfo >= strumKeyCount) goodNoteInfo = goodNoteInfo % strumKeyCount;

			var noteCharInfo = extractNoteChars(i);
			var noteChar:Dynamic = noteCharInfo.noteChar;
			var noteChars:Array<Int> = noteCharInfo.noteChars;

			var note:Note = new Note(daStrumTime, goodNoteInfo, null, false, Std.int(noteChar), daType, _song, noteChars, mustPress, true, stID, strumKeyCount);
			note.sustainLength = daSus;

			var arrowCfg:Array<String> = getArrowConfig(daType);
			var scaleRatio:Float = GRID_SIZE / 40.0;
			var rawW:Float = Std.parseFloat(arrowCfg[4]);
			if (Math.isNaN(rawW) || rawW <= 0) rawW = 40;
			var rawH:Float = Std.parseFloat(arrowCfg[2]);
			if (Math.isNaN(rawH) || rawH <= 0) rawH = 40;

			var cfgW:Int = Math.round(rawW * scaleRatio);
			var cfgH:Int = Math.round(rawH * scaleRatio);
			note.setGraphicSize(cfgW, cfgH);
			note.updateHitbox();

			var gridCol:Int;
			if (secIdx == curSection) {
				gridCol = noteInfo;
			} else {
				var curLeftKeys = curSecMustHit ? noteP1Keys : noteOppKeys;
				if (curSecMustHit) {
					gridCol = mustPress ? (goodNoteInfo % noteP1Keys) : (curLeftKeys + (goodNoteInfo % noteOppKeys));
				} else {
					gridCol = mustPress ? (curLeftKeys + (goodNoteInfo % noteP1Keys)) : (goodNoteInfo % noteOppKeys);
				}
			}

			note.x = gridBG.x + Math.floor((gridCol + 1) * GRID_SIZE);
			note.y = Math.floor(getYfromStrum((daStrumTime - sectionStartTime())));
			var isNextSectionNote:Bool = (daStrumTime >= sectionStartTime(curSection + 1));
			note.alpha = isNextSectionNote ? 0.4 : 1.0;

			note.rawNoteData = noteInfo;

			if (doFunnyNumbers && !note.isSustainNote) {
				if (i[3] == null)
					i[3] = 0;

				var id:FlxText = new FlxText(gridBG.x + Math.floor((gridCol + 1) * GRID_SIZE), Math.floor(getYfromStrum((daStrumTime - sectionStartTime()))), GRID_SIZE,
					Std.string(i[3]).replace("[", "").replace("]", ""), 16);
				id.setBorderStyle(OUTLINE, FlxColor.BLACK, 1.5);
				id.font = Paths.font("vcr.ttf");

				var idIcon:FlxSprite = new FlxSprite(gridBG.x + Math.floor((gridCol + 1) * GRID_SIZE) - 16,
					Math.floor(getYfromStrum((daStrumTime - sectionStartTime()))) - 12);
				idIcon.loadGraphic(Paths.gpuBitmap("charter/idSprite", "shared"));
				idIcon.setGraphicSize(20, 20);
				idIcon.updateHitbox();
				idIcon.antialiasing = false;

				curRenderedIds.add(idIcon);
				curRenderedIds.add(id);
			}

		var sustainGroup:Array<Note> = [];
		var secEnd:Float = sectionStartTime(secIdx + 1);
		// Segments come from the BPM map and stop at the real end of the section.
		// The old guard compared against `secEnd + stepCrochet * stepsPerSection`,
		// which is not where the next section starts once the tempo changes, so it
		// let a piece through past the end of the hold. Anything spilling into the
		// following section is drawn by the pass further down.
		var susClip:Null<Float> = (secEnd > daStrumTime) ? secEnd : null;
		var susStepTimes:Array<Float> = sustainStepTimes(daStrumTime, note.sustainLength, susClip);
		var susCount:Int = susStepTimes.length;
		var susRealEnd:Float = daStrumTime + Math.max(0, note.sustainLength);

		// Seam heights resolved once, so the head, this piece and the previous one
		// can never disagree about where a step begins.
		var segH:Array<Int> = [];
		for (k in 0...susCount) {
			var s0:Float = susStepTimes[k];
			var s1:Float = (k < susCount - 1) ? susStepTimes[k + 1] : susRealEnd;
			segH.push(Math.ceil(sustainSegHeight(s0, s1, sectionStartTime())));
		}

		var rawXOff:Float = Std.parseFloat(arrowCfg[1]);
		if (Math.isNaN(rawXOff)) rawXOff = 0;
		var rawYOff:Float = Std.parseFloat(arrowCfg[3]);
		if (Math.isNaN(rawYOff)) rawYOff = 0;

		var xOff:Float = rawXOff * scaleRatio;
		var yOff:Float = rawYOff * scaleRatio;

		for (susNote in 0...susCount) {
			var susStepStrumTime:Float = susStepTimes[susNote];
			var susTime:Float = (susNote < susCount - 1) ? susStepTimes[susNote + 1] : susRealEnd;

			var prevSustain:Note = (susNote == 0) ? note : sustainGroup[susNote - 1];

			var sustainNote:Note = new Note(susTime, goodNoteInfo, prevSustain, true, Std.int(noteChar),
				daType, _song, noteChars, mustPress, true, stID, strumKeyCount);
			sustainNote.scale.set(note.scale.x, note.scale.x);
			sustainNote.antialiasing = (uiSettings != null && uiSettings.length > 3 && uiSettings[3] == "true");

			var susEndsHere:Bool = (susRealEnd <= secEnd + 1.0);
			var isLastSusStep:Bool = (susNote == susCount - 1) && susEndsHere;
			var frameW:Float = (sustainNote.frameWidth > 0) ? (sustainNote.frameWidth * sustainNote.scale.x) : GRID_SIZE;
			if (!isLastSusStep || !sustainNote.hasHoldEndAnim) {
				if (sustainNote.hasHoldAnim) sustainNote.animation.play("hold");
				var pieceH:Float = (segH != null && susNote < segH.length) ? segH[susNote] : GRID_SIZE;
				if (Math.isNaN(pieceH) || pieceH < 1) pieceH = 1;
				sustainNote.setGraphicSize(frameW, Math.ceil(pieceH));
				sustainNote.updateHitbox();
			} else {
				if (sustainNote.hasHoldEndAnim) sustainNote.animation.play("holdend");
				// Keep holdend in its uniform natural scale (Codename/Psych style) instead of vertically stretching into needles
				var naturalH:Float = (sustainNote.frameHeight > 0) ? (sustainNote.frameHeight * sustainNote.scale.x) : GRID_SIZE;
				sustainNote.setGraphicSize(frameW, Math.round(naturalH));
				sustainNote.updateHitbox();
			}

			if (susNote > 0 && prevSustain != null && prevSustain.isSustainNote) {
				if (prevSustain.hasHoldAnim) prevSustain.animation.play("hold");
				var prevH:Float = (segH != null && susNote - 1 < segH.length) ? segH[susNote - 1] : GRID_SIZE;
				if (Math.isNaN(prevH) || prevH < 1) prevH = 1;
				var prevFrameW:Float = (prevSustain.frameWidth > 0) ? (prevSustain.frameWidth * prevSustain.scale.x) : GRID_SIZE;
				prevSustain.setGraphicSize(prevFrameW, Math.ceil(prevH));
				prevSustain.updateHitbox();
			}

			sustainNote.x = note.x + (GRID_SIZE / 2) - xOff - sustainNote.width / 2;
			var susY:Float = Math.floor(getYfromStrum(susStepStrumTime - sectionStartTime()));
			sustainNote.y = susY + (cfgH / 2) + yOff;

			sustainNote.alpha = note.alpha;

			curRenderedNotes.add(sustainNote);

			sustainGroup.push(sustainNote);
			sustainNote.sustains = sustainGroup;
		}
		note.sustains = sustainGroup;
		curRenderedNotes.add(note);
		}

		// Render current section notes FIRST
		for (i in sectionInfo) {
			renderNoteFromSection(i, curSection);
		}

		// Render next section ghost notes AFTER (on top, semi-transparent)
		if (nextSectionNotes != null) {
			for (i in nextSectionNotes) {
				renderNoteFromSection(i, curSection + 1);
			}
		}

		// Render sustain tails from ANY previous section that extends into current section
		if (curSection > 0) {
			try {
				var curSecStart:Float = sectionStartTime();
				var curSecEnd:Float = getSectionEndTime(curSection);
				var curSecMustHit:Bool = (_song != null && _song.notes != null && _song.notes[curSection] != null) ? _song.notes[curSection].mustHitSection : true;

				for (prevSecIdx in 0...curSection) {
					var prevSec = (_song != null && _song.notes != null) ? _song.notes[prevSecIdx] : null;
					if (prevSec == null || prevSec.sectionNotes == null) continue;

					for (i in prevSec.sectionNotes) {
						if (i == null || i.length < 3) continue;
						var daStrumTime:Float = i[0];
						var daSus:Float = i[2];
						if (daSus <= 0) continue;
						var susEnd:Float = daStrumTime + daSus;
						if (susEnd <= curSecStart) continue;

						var noteInfo:Int = Std.int(i[1]);
						var daType:String = (i[4] != null) ? Std.string(i[4]) : "default";

						var secMustHit:Bool = prevSec.mustHitSection;
						var prevSecIdx:Int = curSection - 1;
						var stID:Int = (i.length > 5 && i[5] != null) ? Std.int(i[5]) : getStrumlineIDFromColumnAtTime(noteInfo, secMustHit, daStrumTime);
						var resolved = resolveStrumlineInfo(stID, noteInfo, secMustHit, null, daStrumTime);
						var mustPress = resolved.mustPress;
						var strumKeyCount = resolved.strumKeyCount;
						var kCounts = getKeyCountsAtTime(daStrumTime);
						var p1Key:Int = (kCounts.playerKeyCount > 0) ? kCounts.playerKeyCount : 4;
						var oppKey:Int = (kCounts.keyCount > 0) ? kCounts.keyCount : 4;
						var side0Keys:Int = secMustHit ? p1Key : oppKey;
						var isSide0:Bool = (noteInfo < side0Keys);
						var goodNoteInfo:Int = isSide0 ? noteInfo : (noteInfo - side0Keys);
						if (goodNoteInfo < 0) goodNoteInfo = 0;
						if (goodNoteInfo >= strumKeyCount) goodNoteInfo = goodNoteInfo % strumKeyCount;
						var noteCharInfo = extractNoteChars(i);
						var noteChar:Dynamic = noteCharInfo.noteChar;
						var noteChars:Array<Int> = noteCharInfo.noteChars;

						var gridCol:Int = getGridColumnFromStrumlineIDAndDataAtTime(stID, goodNoteInfo, curSecMustHit, daStrumTime);
						var arrowCfg:Array<String> = getArrowConfig(daType);
						var scaleRatio:Float = GRID_SIZE / 40.0;
						var rawW:Float = Std.parseFloat(arrowCfg[4]);
						if (Math.isNaN(rawW) || rawW <= 0) rawW = 40;
						var rawH:Float = Std.parseFloat(arrowCfg[2]);
						if (Math.isNaN(rawH) || rawH <= 0) rawH = 40;

						var cfgW:Int = Math.round(rawW * scaleRatio);
						var cfgH:Int = Math.round(rawH * scaleRatio);
						var rawXOff:Float = Std.parseFloat(arrowCfg[1]);
						if (Math.isNaN(rawXOff)) rawXOff = 0;
						var rawYOff:Float = Std.parseFloat(arrowCfg[3]);
						if (Math.isNaN(rawYOff)) rawYOff = 0;

						var xOff:Float = rawXOff * scaleRatio;
						var yOff:Float = rawYOff * scaleRatio;

						var headX:Float = (gridBG != null ? gridBG.x : 240) + Math.floor((gridCol + 1) * GRID_SIZE);

						var susEndTime:Float = daStrumTime + daSus;
						var susStepTimes:Array<Float> = sustainStepTimes(daStrumTime, daSus);
						var susEndsHere:Bool = (susEndTime <= curSecEnd + 1.0);

						// Create a non-sustain dummy head note so Note.hx's getParentNote() terminates immediately!
						var dummyHead:Note = new Note(daStrumTime, goodNoteInfo, null, false, Std.int(noteChar), daType, _song, noteChars, mustPress, true, stID, strumKeyCount);
						var prevCrossSus:Note = dummyHead;
						var createdSustains:Array<Note> = [];

						for (susNote in 0...susStepTimes.length) {
							var susStepStrumTime:Float = susStepTimes[susNote];
							if (susStepStrumTime < curSecStart) continue;
							if (susStepStrumTime >= curSecEnd) break;

							var susTime:Float = (susNote < susStepTimes.length - 1) ? susStepTimes[susNote + 1] : susEndTime;
							var segStop:Float = (susNote < susStepTimes.length - 1) ? susTime : (susEndsHere ? susTime : Math.min(susTime, curSecEnd));

							var sustainNote:Note = new Note(susTime, goodNoteInfo, prevCrossSus, true, Std.int(noteChar),
								daType, _song, noteChars, mustPress, true);
							sustainNote.rawNoteData = noteInfo;
							sustainNote.sustainLength = daSus;
							prevCrossSus = sustainNote;
							createdSustains.push(sustainNote);

							var noteScaleX:Float = (cfgW / 40.0) * (40.0 / 157.0);
							sustainNote.scale.set(noteScaleX, noteScaleX);
							sustainNote.antialiasing = (uiSettings != null && uiSettings.length > 3 && uiSettings[3] == "true");

							var isLastSusStep:Bool = (susNote == susStepTimes.length - 1) && susEndsHere;
							var frameW:Float = (sustainNote.frameWidth > 0) ? (sustainNote.frameWidth * sustainNote.scale.x) : GRID_SIZE;
							if (!isLastSusStep || !sustainNote.hasHoldEndAnim) {
								if (sustainNote.hasHoldAnim) sustainNote.animation.play("hold");
								var segH:Float = Math.ceil(sustainSegHeight(susStepStrumTime, segStop, curSecStart));
								if (Math.isNaN(segH) || segH < 1) segH = 1;
								sustainNote.setGraphicSize(frameW, Math.ceil(segH));
								sustainNote.updateHitbox();
							} else {
								if (sustainNote.hasHoldEndAnim) sustainNote.animation.play("holdend");
								var naturalH:Float = (sustainNote.frameHeight > 0) ? (sustainNote.frameHeight * sustainNote.scale.x) : GRID_SIZE;
								sustainNote.setGraphicSize(frameW, Math.round(naturalH));
								sustainNote.updateHitbox();
							}

							sustainNote.x = headX + (GRID_SIZE / 2) - xOff - sustainNote.width / 2;
							sustainNote.y = Math.floor(getYfromStrum(susStepStrumTime - curSecStart)) + (cfgH / 2) + yOff;
							sustainNote.alpha = 0.4;
							curRenderedNotes.add(sustainNote);
						}

						for (sn in createdSustains) {
							sn.prevNote = null;
						}
						dummyHead.destroy();
					}
				}
			} catch (e:Dynamic) {
				Main.logSilentError(e, "ChartingState: crossSectionSustains");
			}
		}

		if (curRenderedNotes?.members != null) {
			curRenderedNotes.members.sort((a, b) -> {
				if (a == null || b == null) return 0;
				if (a.isSustainNote != b.isSustainNote) return a.isSustainNote ? -1 : 1;
				return 0;
			});
		}

		if (colorQuantization) {
			Note.applyColorQuants(curRenderedNotes.members);
		}

		if (events.length >= 1) {
			var curSecStart:Float = sectionStartTime();
			var curSecEnd:Float = getSectionEndTime(curSection);
			for (event in events) {
				if (event != null && event.length > 1 && event[1] >= curSecStart - 0.1 && event[1] < curSecEnd - 0.1) {
					var eventSprite:EventSprite = new EventSprite(event);

					eventSprite.x = gridBG.x;
					// Same reason as the strum line: a `%` against a single measure of the
					// active tempo put every event that sat outside that window back at
					// the top of the grid, which is why BPM changes were not showing up
					// where they actually happen.
					eventSprite.y = Math.floor(getYfromStrum(event[1] - curSecStart));

					curRenderedEvents.add(eventSprite);
				}
			}
		}

		if (gridAlpha < 1.0 && !showStagePreview) {
			applyGridAlpha(gridAlpha);
		}
	}

	var events:Array<Array<Dynamic>> = [];

	function addSection(?coolLength:Int = 0):Void {
		var col:Int = Conductor.stepsPerSection;

		if (coolLength == 0)
			col = Std.int(Conductor.timeScale[0] * Conductor.timeScale[1]);

		// a new section keeps whatever tempo is currently playing, not the song's
		// base one, otherwise inserting a section after a tempo change silently
		// snaps the chart back to the base BPM
		var inheritedBpm:Float = (_song.notes.length > 0 && _song.notes[_song.notes.length - 1] != null)
			? _song.notes[_song.notes.length - 1].bpm
			: _song.bpm;

		var sec:Section = {
			sectionNotes: [],
			lengthInSteps: col,
			bpm: inheritedBpm,
			changeBPM: false,
			mustHitSection: true,
			altAnim: false,
			changeTimeScale: false,
			timeScale: Conductor.timeScale
		};

		_song.notes.push(sec);
		Conductor.mapBPMChanges(_song);
	}

	function selectNote(note:Note):Void {
		var noteRef = {strumTime: note.strumTime, noteData: note.rawNoteData, section: curSection};
		var alreadySelected = false;
		for (s in selectedNotes) {
			if (s.strumTime == noteRef.strumTime && s.noteData == noteRef.noteData && s.section == noteRef.section) {
				alreadySelected = true;
				break;
			}
		}
		if (FlxG.keys.pressed.CONTROL) {
			// Toggle selection
			if (alreadySelected)
				selectedNotes = selectedNotes.filter(s -> !(s.strumTime == noteRef.strumTime && s.noteData == noteRef.noteData));
			else
				selectedNotes.push(noteRef);
		} else if (FlxG.keys.pressed.SHIFT) {
			// Remove from selection
			selectedNotes = selectedNotes.filter(s -> !(s.strumTime == noteRef.strumTime && s.noteData == noteRef.noteData));
		} else {
			// Single select
			selectedNotes = [noteRef];
		}

		// Also set curSelectedNote for UI compatibility
		curSelectedNote = null;
		if (curSection < _song.notes.length && _song.notes[curSection] != null) {
			for (n in _song.notes[curSection].sectionNotes) {
				if (n[0] == note.strumTime && n[1] == note.rawNoteData) {
					curSelectedNote = n;
					break;
				}
			}
		}

		updateGrid();
		updateNoteUI();
	}

	function deleteNote(note:Note):Void {
		var noteSec:Int = Conductor.getSectionAtTime(note.strumTime);
		if (noteSec < 0) noteSec = curSection;

		// Add to undo
		pushUndo({type: "delete_note", data: {
			strumTime: note.strumTime,
			noteData: note.rawNoteData,
			sustainLen: note.sustainLength,
			noteType: note.arrow_Type,
			section: noteSec
		}});

		if (noteSec < _song.notes.length && _song.notes[noteSec] != null) {
			var toRemove:Array<Dynamic> = [];
			for (i in _song.notes[noteSec].sectionNotes) {
				if (i[0] == note.strumTime && i[1] == note.rawNoteData)
					toRemove.push(i);
			}
			for (i in toRemove) {
				_song.notes[noteSec].sectionNotes.remove(i);
			}
		}

		hasUnsavedChanges = true;
		updateGrid();
	}

	function selectEvent(event:EventSprite):Void {
		curSelectedEvent = (event.eventData != null) ? event.eventData : null;
		if (curSelectedEvent == null) {
			for (i in events) {
				if (i != null && Math.abs(Std.parseFloat(Std.string(i[1])) - event.strumTime) < 2.0) {
					curSelectedEvent = i;
					break;
				}
			}
		}

		if (curSelectedEvent == null) return;

		eventValue1 = (curSelectedEvent.length > 2 && curSelectedEvent[2] != null) ? Std.string(curSelectedEvent[2]) : "";
		eventValue2 = (curSelectedEvent.length > 3 && curSelectedEvent[3] != null) ? Std.string(curSelectedEvent[3]) : "";

		value1.text = eventValue1;
		value2.text = eventValue2;

		// Match the stored event name case-insensitively so internal/CNE events
		// (e.g. "focuscamera", "health drain") are picked up by the editor list.
		curEvent = -1;
		var storedName = Std.string(curSelectedEvent[0]);
		var i2:Int = 0;
		for (ev in eventList) {
			if (ev != null && ev.toLowerCase() == storedName.toLowerCase()) {
				curEvent = i2;
				break;
			}
			i2++;
		}
		if (curEvent == -1)
			curEvent = 0;

		eventDropDown.selectedLabel = (curEvent == 0 && eventList.length > 0 && eventList[0].toLowerCase() != storedName.toLowerCase()) ? storedName : (eventList.length > curEvent ? eventList[curEvent] : storedName);
		var desc1:String = (curEvent >= 0 && curEvent < eventListData.length && eventListData[curEvent] != null && eventListData[curEvent].length > 1) ? eventListData[curEvent][1] : "";
		var desc2:String = (curEvent >= 0 && curEvent < eventListData.length && eventListData[curEvent] != null && eventListData[curEvent].length > 2) ? eventListData[curEvent][2] : "";
		valueDescriptions.text = "Value 1 - " + desc1 + "\nValue 2 - " + desc2 + "\n";

		eventName = storedName;
		UI_box.selected_tab = 2;

		updateGrid();
		updateNoteUI();
	}

	function deleteEvent(event:EventSprite):Void {
		// Add to undo
		pushUndo({type: "delete_event", data: {
			name: event.name,
			strumTime: event.strumTime,
			value1: event.value1,
			value2: event.value2
		}});
		if (event.eventData != null && events.contains(event.eventData)) {
			events.remove(event.eventData);
		} else {
			for (i in events) {
				if (i != null && Math.abs(Std.parseFloat(Std.string(i[1])) - event.strumTime) < 2.0)
					events.remove(i);
			}
		}

		if (curSelectedEvent == event.eventData || (curSelectedEvent != null && Math.abs(Std.parseFloat(Std.string(curSelectedEvent[1])) - event.strumTime) < 2.0)) {
			curSelectedEvent = null;
		}

		hasUnsavedChanges = true;
		updateGrid();
	}

	// ==================== UNDO/REDO SYSTEM ====================

	function pushUndo(action:UndoAction):Void {
		undoList.push(action);
		if (undoList.length > maxUndoSteps)
			undoList.shift();
		redoList = [];
	}

	function performUndo():Void {
		if (undoList.length == 0) return;
		var action = undoList.pop();
		redoList.push(action);
		applyUndoAction(action, true);
		hasUnsavedChanges = true;
		updateGrid();
	}

	function performRedo():Void {
		if (redoList.length == 0) return;
		var action = redoList.pop();
		undoList.push(action);
		applyUndoAction(action, false);
		hasUnsavedChanges = true;
		updateGrid();
	}

	function applyUndoAction(action:UndoAction, isUndo:Bool):Void {
		switch (action.type) {
			case "delete_note":
				var d = action.data;
				if (isUndo) {
					// Re-create the note
					if (d.section < _song.notes.length) {
						var noteArr:Array<Dynamic> = [d.strumTime, d.noteData, d.sustainLen, null];
						if (d.noteType != null && d.noteType != "default")
							noteArr.push(d.noteType);
						_song.notes[d.section].sectionNotes.push(noteArr);
					}
				} else {
					// Delete the note again
					if (d.section < _song.notes.length) {
						for (n in _song.notes[d.section].sectionNotes) {
							if (n[0] == d.strumTime && n[1] == d.noteData) {
								_song.notes[d.section].sectionNotes.remove(n);
								break;
							}
						}
					}
				}
			case "delete_event":
				var d = action.data;
				if (isUndo) {
					events.push([d.name, d.strumTime, d.value1, d.value2]);
				} else {
					events = events.filter(e -> e[1] != d.strumTime);
				}
			case "create_notes":
				var notes:Array<Dynamic> = action.data;
				if (isUndo) {
					// Remove created notes
					for (nd in notes) {
						if (nd.section < _song.notes.length) {
							for (n in _song.notes[nd.section].sectionNotes) {
								if (n[0] == nd.strumTime && n[1] == nd.noteData) {
									_song.notes[nd.section].sectionNotes.remove(n);
									break;
								}
							}
						}
					}
				} else {
					// Re-create them
					for (nd in notes) {
						if (nd.section < _song.notes.length) {
							var noteArr:Array<Dynamic> = [nd.strumTime, nd.noteData, nd.sustainLen, nd.mustPress ? 0 : null];
							if (nd.noteType != null && nd.noteType != "default")
								noteArr.push(nd.noteType);
							_song.notes[nd.section].sectionNotes.push(noteArr);
						}
					}
				}
			case "move_notes":
				var d = action.data;
				var sourceArr = isUndo ? d.orig : d.moved;
				var targetArr = isUndo ? d.moved : d.orig;
				if (sourceArr.length == targetArr.length) {
					for (idx in 0...sourceArr.length) {
						var src = sourceArr[idx];
						var tgt = targetArr[idx];
						// Find and update the note
						if (src.origSection < _song.notes.length) {
							for (n in _song.notes[src.origSection].sectionNotes) {
								if (n[0] == src.origTime && n[1] == src.origData) {
									n[0] = tgt.newTime;
									n[1] = tgt.newData;
									break;
								}
							}
						}
					}
				}
			default:
		}
	}

	// ==================== CLIPBOARD ====================

	function copySelected():Void {
		clipboardNotes = [];
		clipboardEvents = [];
		for (sel in selectedNotes) {
			if (sel.section < _song.notes.length) {
				for (n in _song.notes[sel.section].sectionNotes) {
					if (n[0] == sel.strumTime && n[1] == sel.noteData) {
						clipboardNotes.push({
							strumTime: n[0],
							noteData: n[1],
							sustainLen: n[2] != null ? n[2] : 0,
							noteType: n[4] != null ? n[4] : "default",
							section: sel.section
						});
						break;
					}
				}
			}
		}
		autosaveText.text = "Copied " + clipboardNotes.length + " note(s)";
		autosaveText.color = FlxColor.WHITE;
		new FlxTimer().start(1.5, function(_) { autosaveText.text = ""; });
	}

	function cutSelected():Void {
		copySelected();
		deleteSelected();
	}

	function pasteClipboard():Void {
		if (clipboardNotes.length == 0) return;
		var createdNotes:Array<Dynamic> = [];
		// Offset by the destination section's real duration instead of a fixed
		// measure, otherwise pasted notes land past the end of a section whose
		// length or BPM differs.
		var timeOffset = sectionStartTime(curSection + 1) - sectionStartTime(curSection);
		for (cn in clipboardNotes) {
			var newSection = curSection;
			var newTime = cn.strumTime + timeOffset;
			if (newSection < _song.notes.length) {
				var noteArr:Array<Dynamic> = [newTime, cn.noteData, cn.sustainLen, null];
				if (cn.noteType != null && cn.noteType != "default")
					noteArr.push(cn.noteType);
				_song.notes[newSection].sectionNotes.push(noteArr);
				createdNotes.push({
					strumTime: newTime,
					noteData: cn.noteData,
					sustainLen: cn.sustainLen,
					mustPress: false,
					noteType: cn.noteType,
					section: newSection
				});
			}
		}
		if (createdNotes.length > 0)
			pushUndo({type: "create_notes", data: createdNotes});
		hasUnsavedChanges = true;
		updateGrid();
		autosaveText.text = "Pasted " + createdNotes.length + " note(s)";
		autosaveText.color = FlxColor.LIME;
		new FlxTimer().start(1.5, function(_) { autosaveText.text = ""; });
	}

	function deleteSelected():Void {
		if (selectedNotes.length == 0) return;
		var deletedNotes:Array<Dynamic> = [];
		for (sel in selectedNotes) {
			if (sel.section < _song.notes.length) {
				for (n in _song.notes[sel.section].sectionNotes) {
					if (n[0] == sel.strumTime && n[1] == sel.noteData) {
						deletedNotes.push({
							strumTime: n[0],
							noteData: n[1],
							sustainLen: n[2] != null ? n[2] : 0,
							noteType: n[4] != null ? n[4] : "default",
							section: sel.section
						});
						_song.notes[sel.section].sectionNotes.remove(n);
						break;
					}
				}
			}
		}
		if (deletedNotes.length > 0)
			pushUndo({type: "create_notes", data: deletedNotes});
		selectedNotes = [];
		curSelectedNote = null;
		hasUnsavedChanges = true;
		updateGrid();
	}

	function selectAll():Void {
		selectedNotes = [];
		for (secIdx in 0..._song.notes.length) {
			if (_song.notes[secIdx] == null || _song.notes[secIdx].sectionNotes == null) continue;
			for (n in _song.notes[secIdx].sectionNotes) {
				selectedNotes.push({strumTime: n[0], noteData: n[1], section: secIdx});
			}
		}
		hasUnsavedChanges = true;
		updateGrid();
	}

	function clearSelection():Void {
		selectedNotes = [];
		curSelectedNote = null;
		updateGrid();
	}

	function isNoteSelected(strumTime:Float, noteData:Int, section:Int):Bool {
		for (s in selectedNotes) {
			if (s.strumTime == strumTime && s.noteData == noteData && s.section == section)
				return true;
		}
		return false;
	}

	// ==================== BOX SELECTION ====================

	function updateBoxSelection():Void {
		if (!isBoxSelecting) return;

		var mx:Float = FlxG.mouse.x;
		var my:Float = FlxG.mouse.y;

		var x = Math.min(boxSelectStartX, mx);
		var y = Math.min(boxSelectStartY, my);
		var w = Math.abs(mx - boxSelectStartX);
		var h = Math.abs(my - boxSelectStartY);

		selectionBox.x = x;
		selectionBox.y = y;
		selectionBox.setGraphicSize(Std.int(w), Std.int(h));
		selectionBox.updateHitbox();
		selectionBox.visible = true;

		if (FlxG.mouse.justReleased) {
			isBoxSelecting = false;
			selectionBox.visible = false;

			// Select all notes within the box
			for (note in curRenderedNotes.members) {
				if (note == null || !note.alive) continue;
				if (note.x + note.width >= x && note.x <= x + w && note.y + note.height >= y && note.y <= y + h) {
					var noteRef = {strumTime: note.strumTime, noteData: note.rawNoteData, section: curSection};
					var alreadySelected = false;
					for (s in selectedNotes) {
						if (s.strumTime == noteRef.strumTime && s.noteData == noteRef.noteData && s.section == noteRef.section) {
							alreadySelected = true;
							break;
						}
					}
					if (!alreadySelected && !note.isSustainNote) {
						selectedNotes.push(noteRef);
					}
				}
			}
			updateGrid();
		}
	}

	// ==================== NOTE DRAGGING ====================

	function startNoteDrag():Void {
		if (selectedNotes.length == 0) return;
		isDraggingNotes = true;
		dragStartX = FlxG.mouse.x;
		dragStartY = FlxG.mouse.y;
		dragOffsets = [];
		for (sel in selectedNotes) {
			dragOffsets.push({
				noteIndex: -1,
				section: sel.section,
				origTime: sel.strumTime,
				origData: sel.noteData
			});
		}
	}

	function updateNoteDrag():Void {
		if (!isDraggingNotes) return;

		var deltaY:Float = FlxG.mouse.y - dragStartY;
		var deltaTime:Float = deltaY / GRID_SIZE * Conductor.stepCrochet;
		var deltaX:Float = FlxG.mouse.x - dragStartX;
		var deltaData:Int = Math.round(deltaX / GRID_SIZE);

		for (idx in 0...selectedNotes.length) {
			var sel = selectedNotes[idx];
			if (sel.section < _song.notes.length) {
				for (n in _song.notes[sel.section].sectionNotes) {
					if (n[0] == dragOffsets[idx].origTime && n[1] == dragOffsets[idx].origData) {
						n[0] = dragOffsets[idx].origTime + deltaTime;
						sel.strumTime = n[0];
						if (deltaData != 0) {
							n[1] = dragOffsets[idx].origData + deltaData;
							sel.noteData = n[1];
							n[5] = getStrumlineIDFromColumnAtTime(n[1], null, n[0]);
						}
						break;
					}
				}
			}
		}

		if (FlxG.mouse.justReleased) {
			isDraggingNotes = false;
			hasUnsavedChanges = true;
			updateGrid();
		}
	}

	function clearSection():Void {
		_song.notes[curSection].sectionNotes = [];

		hasUnsavedChanges = true;
		updateGrid();
	}

	function clearSectionSide(side:Int = 0):Void {
		var removeThese = [];
		var kCounts = getKeyCountsAtSection(curSection);
		var oppKeys:Int = kCounts.keyCount;

		for (noteIndex in 0..._song.notes[curSection].sectionNotes.length) {
			if (side == 0) {
				if (_song.notes[curSection].sectionNotes[noteIndex][1] < oppKeys) {
					removeThese.push(_song.notes[curSection].sectionNotes[noteIndex]);
				}
			} else if (side == 1) {
				if (_song.notes[curSection].sectionNotes[noteIndex][1] >= oppKeys) {
					removeThese.push(_song.notes[curSection].sectionNotes[noteIndex]);
				}
			}
		}

		if (removeThese.length > 0) {
			for (x in removeThese) {
				_song.notes[curSection].sectionNotes.remove(x);
			}

			hasUnsavedChanges = true;
			updateGrid();
		}
	}

	function characterSectionSide(side:Int = 0, character:Int = 0):Void {
		var changeThese = [];
		var kCounts = getKeyCountsAtSection(curSection);
		var oppKeys:Int = kCounts.keyCount;

		var charactersArray:Array<Int> = [];

		if (characterGroup_Input.text != "" && characterGroup_Input.text != " ") {
			var yes = characterGroup_Input.text.split(",");

			for (char in yes) {
				charactersArray.push(Std.parseInt(char));
			}
		}

		for (noteIndex in 0..._song.notes[curSection].sectionNotes.length) {
			var noteData = _song.notes[curSection].sectionNotes[noteIndex][1];

			if (side == 0) {
				if (noteData < oppKeys) {
					changeThese.push(noteIndex);
				}
			} else if (side == 1) {
				if (noteData >= oppKeys) {
					changeThese.push(noteIndex);
				}
			}
		}

		if (changeThese.length > 0) {
			for (x in changeThese) {
				if (charactersArray.length < 1)
					_song.notes[curSection].sectionNotes[x][3] = character;
				else
					_song.notes[curSection].sectionNotes[x][3] = charactersArray;
			}

			hasUnsavedChanges = true;
			updateGrid();
		}
	}

	var eventName:String = "Change Character";
	var eventValue1:String = "Dad";
	var eventValue2:String = "spooky";

	function getDuplicateNotes():Array<Array<Dynamic>> {
		var duplicates:Array<Array<Dynamic>> = [];
		var seen:Map<String, Bool> = new Map();

		for (section in _song.notes) {
			if (section == null || section.sectionNotes == null) continue;
			for (note in section.sectionNotes) {
				var key:String = '${note[0]}_${note[1]}';
				if (seen.exists(key)) {
					duplicates.push(note);
				} else {
					seen.set(key, true);
				}
			}
		}

		return duplicates;
	}

	function deleteAllDuplicates():Void {
		var seen:Map<String, Bool> = new Map();
		var removed:Int = 0;

		for (section in _song.notes) {
			if (section == null || section.sectionNotes == null) continue;
			var toRemove:Array<Array<Dynamic>> = [];
			for (note in section.sectionNotes) {
				var key:String = '${note[0]}_${note[1]}';
				if (seen.exists(key)) {
					toRemove.push(note);
					removed++;
				} else {
					seen.set(key, true);
				}
			}
			for (note in toRemove) {
				section.sectionNotes.remove(note);
			}
		}

		hasUnsavedChanges = true;
		updateGrid();
	}

	function updateDuplicateBoxes():Void {
		for (member in duplicateBoxes.members) {
			if (member != null) member.destroy();
		}
		duplicateBoxes.clear();

		if (!showDuplicateBoxes) return;

		var seenKeys:Map<String, Bool> = new Map();
		var duplicateKeys:Map<String, Bool> = new Map();

		var sectionsToCheck = [{sec: _song.notes[curSection], idx: curSection}];
		if (_song.notes[curSection + 1] != null) {
			sectionsToCheck.push({sec: _song.notes[curSection + 1], idx: curSection + 1});
		}

		for (entry in sectionsToCheck) {
			if (entry.sec == null || entry.sec.sectionNotes == null) continue;
			for (note in entry.sec.sectionNotes) {
				var key:String = '${note[0]}_${note[1]}';
				if (seenKeys.exists(key)) {
					duplicateKeys.set(key, true);
				} else {
					seenKeys.set(key, true);
				}
			}
		}

		if (!duplicateKeys.keys().hasNext()) return;

		for (entry in sectionsToCheck) {
			if (entry.sec == null || entry.sec.sectionNotes == null) continue;
			var secMustHit:Bool = entry.sec.mustHitSection;
			for (note in entry.sec.sectionNotes) {
				var noteInfo:Int = Std.int(note[1]);
				var daStrumTime:Float = note[0];
				var key:String = '${daStrumTime}_${noteInfo}';

				if (duplicateKeys.exists(key)) {
					var daType:String = (note.length > 4 && note[4] != null) ? note[4] : "default";
					var stID:Int = getStrumlineIDFromColumnAtTime(noteInfo, secMustHit, daStrumTime);
					var sInfo = resolveStrumlineInfo(stID, noteInfo, secMustHit, null, daStrumTime);
					var gridCol:Int = getGridColumnFromStrumlineIDAndDataAtTime(stID, noteInfo % sInfo.strumKeyCount, secMustHit, daStrumTime);
					var boxX = gridBG.x + Math.floor((gridCol + 1) * GRID_SIZE);
					var boxY = Math.floor(getYfromStrum((daStrumTime - sectionStartTime())));

					var cfgW:Int = Std.parseInt(getArrowConfig(daType)[4]);
					if (cfgW <= 0) cfgW = GRID_SIZE;
					var cfgH:Int = Std.parseInt(getArrowConfig(daType)[2]);
					if (cfgH <= 0) cfgH = GRID_SIZE;

					var box:FlxSprite = new FlxSprite(boxX - 2, boxY - 2).makeGraphic(cfgW + 4, cfgH + 4, FlxColor.RED);
					box.alpha = 0.5;
					duplicateBoxes.add(box);
				}
			}
		}
	}

	private function addNote():Void {
		var snappedGridSize = snapGridSize();
		var relY:Float = FlxG.mouse.y - gridBG.y;
		if (relY < 0) relY = 0;
		var snappedY:Float = gridBG.y + Math.floor(relY / snappedGridSize) * snappedGridSize;

		var isClickOnCurrentSec:Bool = (snappedY < gridBG.y + gridBG.height);
		var targetSec:Int = isClickOnCurrentSec ? curSection : (curSection + 1);

		var noteStrum:Float;
		if (isClickOnCurrentSec && Math.abs(snappedY - gridBG.y) < 1.0) {
			noteStrum = sectionStartTime(curSection);
		} else {
			noteStrum = getStrumTime(snappedY) + sectionStartTime();
		}

		if (targetSec < 0) targetSec = 0;
		while (_song.notes.length <= targetSec) {
			addSection();
		}

		var hoverCol:Int = Math.floor((FlxG.mouse.x - gridBG.x) / GRID_SIZE);
		var mouseCol:Int = hoverCol - 1;

		if (mouseCol == -1) {
			if (FlxG.keys.pressed.SHIFT) {
				var evName:String = (eventName != null && eventName != "") ? eventName : "Change Character";
				var val1:String = (eventValue1 != null) ? eventValue1 : "";
				var val2:String = (eventValue2 != null) ? eventValue2 : "";
				events.push([evName, noteStrum, val1, val2]);
				_song.events = events;
				hasUnsavedChanges = true;
				updateGrid();
				return;
			}
			openEventEditor(noteStrum);
			return;
		}
		if (mouseCol < 0) return;

		var secMustHit:Bool = (_song.notes[targetSec] != null) ? _song.notes[targetSec].mustHitSection : true;
		var kCounts = getKeyCountsAtTime(noteStrum);
		var side0Active:Int = secMustHit ? kCounts.playerKeyCount : kCounts.keyCount;
		var side1Active:Int = secMustHit ? kCounts.keyCount : kCounts.playerKeyCount;
		var totalColsAtTime:Int = side0Active + side1Active;

		if (mouseCol >= totalColsAtTime) return;

		var rawNoteData:Int = mouseCol;

		var noteSus = 0;
		var characters:Array<Int> = [];

		if (characterGroup_Input.text != "" && characterGroup_Input.text != " ") {
			var yes = characterGroup_Input.text.split(",");

			for (char in yes) {
				characters.push(Std.parseInt(char));
			}
		}

		var stID:Int = getStrumlineIDFromColumnAtTime(rawNoteData, null, noteStrum);
		var nType:String = (cur_Note_Type != null && cur_Note_Type != "" && cur_Note_Type != "default") ? cur_Note_Type : "default";

		_song.notes[targetSec].sectionNotes.push([
			noteStrum,
			rawNoteData,
			noteSus,
			(characters.length <= 0 ? current_Note_Character : characters),
			nType,
			stID
		]);

		curSelectedNote = _song.notes[targetSec].sectionNotes[_song.notes[targetSec].sectionNotes.length - 1];
		selectedNotes = [{strumTime: noteStrum, noteData: rawNoteData, section: targetSec}];

		if (FlxG.keys.pressed.CONTROL) {
			var isSide0:Bool = (rawNoteData < side0Active);
			var targetRawData:Int;
			if (isSide0) {
				var lane = rawNoteData % side1Active;
				targetRawData = side0Active + lane;
			} else {
				var lane = (rawNoteData - side0Active) % side0Active;
				targetRawData = lane;
			}
			var targetStID:Int = getStrumlineIDFromColumnAtTime(targetRawData, null, noteStrum);
			_song.notes[targetSec].sectionNotes.push([
				noteStrum,
				targetRawData,
				noteSus,
				current_Note_Character,
				nType,
				targetStID
			]);
		}

		hasUnsavedChanges = true;
		updateGrid();
		updateNoteUI();
	}

	function openEventEditor(strumTime:Float, ?existingEvent:Array<Dynamic>):Void {
		unfocusAllInputs();
		openSubState(new toolbox.EventSubState(strumTime, existingEvent, function(savedEv:Array<Dynamic>) {
			if (existingEvent != null) {
				if (!events.remove(existingEvent)) {
					for (ev in events) {
						if (ev != null && ev.length > 1 && Math.abs(Std.parseFloat(Std.string(ev[1])) - strumTime) < 2.0 && Std.string(ev[0]) == Std.string(existingEvent[0])) {
							events.remove(ev);
							break;
						}
					}
				}
			}
			events.push(savedEv);
			curSelectedEvent = savedEv;
			_song.events = events;
			hasUnsavedChanges = true;
			updateGrid();
		}, function() {
			if (existingEvent != null) {
				if (!events.remove(existingEvent)) {
					for (ev in events) {
						if (ev != null && ev.length > 1 && Math.abs(Std.parseFloat(Std.string(ev[1])) - strumTime) < 2.0 && Std.string(ev[0]) == Std.string(existingEvent[0])) {
							events.remove(ev);
							break;
						}
					}
				}
			}
			if (curSelectedEvent == existingEvent) curSelectedEvent = null;
			_song.events = events;
			hasUnsavedChanges = true;
			updateGrid();
		}));
	}

	/**
	 * Pixels per step of the grid.
	 *
	 * The vertical axis used to be measured in milliseconds using the *current*
	 * section's `stepCrochet`, so as soon as a section changed the BPM the whole
	 * grid rescaled itself and every note in it jumped. Working in steps keeps
	 * the grid stable, and the time of a note is then resolved through the BPM
	 * map, which is where tempo changes are actually honoured.
	 */
	inline function getPixelPerStep():Float {
		if (gridBG == null || gridBG.height <= 0) return GRID_SIZE;
		return gridBG.height / Conductor.stepsPerSection;
	}

	inline function getStrumTime(yPos:Float):Float {
		var bgY:Float = (gridBG != null) ? gridBG.y : 50;
		var steps:Float = (yPos - bgY) / getPixelPerStep();
		var startStep:Float = Conductor.getSectionStartStep(curSection);
		return Conductor.getTimeInSteps(startStep + steps) - sectionStartTime();
	}

	/**
	 * Is the mouse over the note grid? Every place that reacts to the pointer went
	 * through three slightly different copies of this test, one of which measured
	 * the height from the top of the screen instead of from `gridBG.y` and another
	 * of which was strict on the top edge, so the first row of the grid was dead.
	 */
	inline function mouseOnGrid():Bool {
		if (gridBG == null) return false;
		var totalGridH:Float = gridBG.height + (gridBGNext != null ? gridBGNext.height : 0);
		return FlxG.mouse.x >= gridBG.x
			&& FlxG.mouse.x <= gridBG.x + gridBG.width
			&& FlxG.mouse.y >= gridBG.y
			&& FlxG.mouse.y <= gridBG.y + totalGridH;
	}

	/**
	 * Distance between two snapped rows, in pixels. The rows themselves are laid
	 * out in steps, so the snap has to follow `getPixelPerStep()` and not the raw
	 * `GRID_SIZE` or the highlight drifts away from the note as the zoom changes.
	 */
	inline function snapGridSize():Float {
		if (beatSnap <= 0) return getPixelPerStep();
		return getPixelPerStep() * 4 / beatSnap;
	}

	function getYfromStrum(strumTime:Float):Float {
		var absTime:Float = sectionStartTime() + strumTime;
		var steps:Float = Conductor.getStep(absTime) - Conductor.getSectionStartStep(curSection);
		var bgY:Float = (gridBG != null) ? gridBG.y : 50;
		return bgY + steps * getPixelPerStep();
	}

	/**
	 * Pixel height of the sustain piece running from `segStart` to `segEnd`, both
	 * absolute ms. Measured through `getYfromStrum` so it follows the zoom level
	 * and the tempo, and so the final piece can be cut short exactly where the
	 * hold ends instead of always being one whole grid tall.
	 */
	inline function sustainSegHeight(segStart:Float, segEnd:Float, secStart:Float):Float {
		var y0:Float = getYfromStrum(segStart - secStart);
		var y1:Float = getYfromStrum(segEnd - secStart);
		var h:Float = y1 - y0;
		return (h > 1) ? h : 1;
	}

	/**
	 * Absolute times of the steps a sustain covers, resolved through the BPM map.
	 *
	 * The segments used to be `strumTime + stepCrochet * k` against a single
	 * `stepCrochet`, which only holds while the tempo is constant. Once a hold
	 * crossed a tempo change the pieces landed on the wrong rows, the longer the
	 * hold the further off it got, and the count itself was wrong because it came
	 * from a step duration belonging to a different part of the song.
	 */
	function sustainStepTimes(strumTime:Float, sustainLength:Float, ?clipTo:Float):Array<Float> {
		var out:Array<Float> = [];
		if (sustainLength <= 0) return out;

		// `null` means "no cut", and is used instead of `Math.POSITIVE_INFINITY`
		// because that is not a constant expression and so cannot be a default
		// argument value.
		var realEnd:Float = strumTime + sustainLength;
		var end:Float = (clipTo == null) ? realEnd : Math.min(realEnd, clipTo);
		if (end <= strumTime) return out;

		var startStep:Float = Conductor.getStep(strumTime);
		var maxSteps:Int = 2048;
		var k:Int = 0;
		while (k < maxSteps) {
			var t:Float = Conductor.getTimeInSteps(startStep + k);
			// `>=` rather than `>`, and the monotonicity guard below, both exist
			// because the two conversions are inverse but not exact: a segment
			// landing a fraction of a millisecond past the end is what left a lone
			// tail standing after the hold was over.
			if (k > 0 && t >= end) break;
			if (k > 0 && t <= out[out.length - 1]) break;
			out.push(t);
			k++;
		}
		return out;
	}

	function loadJson(song:String, ?diff:String):Void {
		PlayState.storyDifficultyStr = diff;
		PlayState.SONG = SongLoader.loadFromJson(diff, song);

		#if NO_PRELOAD_ALL
		LoadingState.instance.checkLoadSong(LoadingState.getSongPath());

		if (PlayState.SONG.needsVoices)
			LoadingState.instance.checkLoadSong(LoadingState.getVocalPath());
		#end

		FlxG.sound.music.stop();
		vocals.stop();

		FlxG.resetState();
	}

	function loadChart():Void {
		var fileOpen:FileDialog = new FileDialog();
		fileOpen.browse(OPEN, "json", #if sys Sys.getCwd() #else '' #end, "Select A Chart File");
		fileOpen.onSelect.add((data) -> {
			try {
				var rawContent:String = #if sys File.getContent(data) #else Assets.getText(data) #end;
				var rawJson:Dynamic = Json.parse(rawContent);
				var parsedJson:Dynamic = null;

				if (rawJson.codenameChart == true || rawJson.strumLines != null) {
					parsedJson = SongLoader.parseCodename(rawJson, _song.song);
				} else if (rawJson.song == null) {
					parsedJson = SongLoader.parseFNFC(rawJson, _song.song, difficulty);
				} else {
					parsedJson = SongLoader.parseLegacy(rawJson);
				}

				if (parsedJson == null || !Reflect.hasField(parsedJson, "notes") || parsedJson.notes == null) {
					CoolUtil.coolError('Leather Engine Chart Editor', 'Invalid chart at path $data');
				} else {
					if (data != null) {
						var fileName:String = haxe.io.Path.withoutDirectory(data);
						var dashIdx:Int = fileName.lastIndexOf("-");
						if (dashIdx != -1) {
							var diffPart:String = fileName.substring(dashIdx + 1);
							if (StringTools.endsWith(diffPart.toLowerCase(), ".json")) {
								diffPart = diffPart.substring(0, diffPart.length - 5);
							}
							if (diffPart != "") {
								PlayState.storyDifficultyStr = diffPart;
							}
						}
					}
					PlayState.SONG = parsedJson;
					FlxG.resetState();
				}
			} catch (e) {
				CoolUtil.coolError('Leather Engine Chart Editor', 'Invalid chart at path $data: ' + e);
			}
		});
	}

	private function exportPsych():Void {
		var psychJson:Dynamic = SongLoader.exportToPsych(_song, events);
		var data:String = Json.stringify(psychJson, null, "\t");

		if ((data != null) && (data.length > 0)) {
			var gamingName = _song.song.toLowerCase();
			if (difficulty.toLowerCase() != 'normal')
				gamingName = gamingName + '-' + difficulty.toLowerCase();

			#if sys
			saveToModFolder(data, gamingName + "-psych.json");
			if (autosaveText != null) {
				autosaveText.text = "Psych Chart Exported!";
				autosaveText.color = FlxColor.LIME;
				new FlxTimer().start(2, function(_) { autosaveText.text = ""; });
			}
			#else
			fileDialogue = new FileReference();
			fileDialogue.addEventListener(Event.COMPLETE, onSaveComplete);
			fileDialogue.addEventListener(Event.CANCEL, onSaveCancel);
			fileDialogue.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			fileDialogue.save(data.trim(), gamingName + ".json");
			#end
		}
	}

	private function exportCodename():Void {
		var cneJson:Dynamic = SongLoader.exportToCodename(_song, events, difficulty);
		var data:String = Json.stringify(cneJson, null, "\t");

		if ((data != null) && (data.length > 0)) {
			var cneFileName = (difficulty != null && difficulty != '') ? difficulty.toLowerCase() + ".json" : "normal.json";

			#if sys
			saveToModFolder(data, cneFileName);
			if (autosaveText != null) {
				autosaveText.text = "Codename Chart Exported!";
				autosaveText.color = FlxColor.LIME;
				new FlxTimer().start(2, function(_) { autosaveText.text = ""; });
			}
			#else
			fileDialogue = new FileReference();
			fileDialogue.addEventListener(Event.COMPLETE, onSaveComplete);
			fileDialogue.addEventListener(Event.CANCEL, onSaveCancel);
			fileDialogue.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			fileDialogue.save(data.trim(), cneFileName);
			#end
		}
	}

	private function saveLevel(saveEvents:Bool = false) {
		if (_song != null && (_song.chartType == CODENAME || _song.strumLines != null)) {
			exportCodename();
			return;
		}
		var json:Dynamic;

		if (saveEvents)
			json = {
				"song": {
					"events": []
				}
			};
		else
			json = {"song": _song};

		if (!saveEvents)
			json.song.events = [];
		else
			json.song.events = events;

		var data:String = Json.stringify(json);

		if ((data != null) && (data.length > 0)) {
			var gamingName = _song.song.toLowerCase();
			var diff = difficulty.toLowerCase();

			if (saveEvents)
				gamingName = "events" + (diff != 'normal' ? '-' + diff : '');
			else if (diff != 'normal')
				gamingName = gamingName + '-' + diff;

			#if sys
			saveToModFolder(data, gamingName + ".json");
			saveToBackups(data, saveEvents ? "events-" : "");
			hasUnsavedChanges = false;
			if (autosaveText != null) {
				autosaveText.text = saveEvents ? "Events saved!" : "Chart saved!";
				autosaveText.color = FlxColor.LIME;
				new FlxTimer().start(2, function(_) { autosaveText.text = ""; });
			}
			FlxG.log.notice("Successfully saved LEVEL DATA.");
			#else
			fileDialogue = new FileReference();
			fileDialogue.addEventListener(Event.COMPLETE, onSaveComplete);
			fileDialogue.addEventListener(Event.CANCEL, onSaveCancel);
			fileDialogue.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			fileDialogue.save(data.trim(), gamingName + ".json");
			#end
		}
	}

	function onSaveComplete(_):Void {
		fileDialogue.removeEventListener(Event.COMPLETE, onSaveComplete);
		fileDialogue.removeEventListener(Event.CANCEL, onSaveCancel);
		fileDialogue.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		fileDialogue = null;
		hasUnsavedChanges = false;
		autosaveText.text = "Saved!";
		autosaveText.color = FlxColor.LIME;
		new FlxTimer().start(2, function(_) { autosaveText.text = ""; });
		FlxG.log.notice("Successfully saved LEVEL DATA.");
	}

	/**
	 * Called when the save file dialog is cancelled.
	 */
	function onSaveCancel(_):Void {
		fileDialogue.removeEventListener(Event.COMPLETE, onSaveComplete);
		fileDialogue.removeEventListener(Event.CANCEL, onSaveCancel);
		fileDialogue.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		fileDialogue = null;
	}

	/**
	 * Called if there is an error while saving the gameplay recording.
	 */
	function onSaveError(_):Void {
		fileDialogue.removeEventListener(Event.COMPLETE, onSaveComplete);
		fileDialogue.removeEventListener(Event.CANCEL, onSaveCancel);
		fileDialogue.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		fileDialogue = null;
		FlxG.log.error("Problem saving Level data");
	}

	private function initMenuDescriptions():Void {
		menuDescriptions = new Map<String, String>();
		// Header Categories
		menuDescriptions.set("File", "FILE CATEGORY: Save chart files, export in Codename Engine / Psych / FNF Legacy formats, and exit editor.");
		menuDescriptions.set("Edit", "EDIT CATEGORY: Undo/redo actions, section copy/paste/cut, note selection, and duplicate note removal.");
		menuDescriptions.set("Chart", "CHART CATEGORY: Full screen or substate playtesting options, song data tabs, section options, and event editor.");
		menuDescriptions.set("View", "VIEW CATEGORY: Grid vertical zoom, lane size, line alpha, stage background preview, and grid horizontal scrolling.");
		menuDescriptions.set("Song", "SONG CATEGORY: Toggle vocal/inst audio mutes, playback speed multipliers, and player/opponent hitsounds.");
		menuDescriptions.set("Note", "NOTE CATEGORY: Select active note type to place on grid (Default, Alt Anim, Hurt, Hey).");
		menuDescriptions.set("Snap", "SNAP CATEGORY: Set the rhythmic beat snap division for grid note placement.");
		menuDescriptions.set("Playback", "PLAYBACK CATEGORY: Play/pause controls, playback speed multipliers, and section/step navigation.");

		// File Menu Items
		menuDescriptions.set("Save (Ctrl+S)", "Saves current song chart to active mod directory.");
		menuDescriptions.set("Save As (Ctrl+Shift+S)", "Exports chart copy in Codename Engine JSON format.");
		menuDescriptions.set("Save Global Events (Ctrl+B+S)", "Saves global events to events.json.");
		menuDescriptions.set("Save Metadata (Ctrl+M+S)", "Saves song metadata (BPM, stage, characters).");
		menuDescriptions.set("Export Codename CNE", "Exports chart in Codename Engine JSON format (includes events & strumlines).");
		menuDescriptions.set("Export Psych", "Exports chart in Psych Engine JSON format.");
		menuDescriptions.set("Export FNF Legacy", "Exports chart in vanilla Friday Night Funkin' format.");
		menuDescriptions.set("Exit", "Exits chart editor and returns to Charter Menu.");

		// Edit Menu Items
		menuDescriptions.set("Undo (Ctrl+Z)", "Reverts last action performed in chart editor.");
		menuDescriptions.set("Redo (Ctrl+Y)", "Re-applies last undone action.");
		menuDescriptions.set("Copy Section (Ctrl+C)", "Copies all notes in current section to clipboard.");
		menuDescriptions.set("Paste Section (Ctrl+V)", "Pastes notes from clipboard into current section.");
		menuDescriptions.set("Cut Section (Ctrl+X)", "Copies and clears all notes in current section.");
		menuDescriptions.set("Delete Note (Delete)", "Deletes currently selected note.");
		menuDescriptions.set("Delete Stacked Notes (Shift+Delete)", "Removes all duplicate overlapping notes on grid.");
		menuDescriptions.set("Select All Notes (Ctrl+A)", "Selects all notes across entire chart.");
		menuDescriptions.set("Clear Current Section", "Deletes all notes in active section.");
		menuDescriptions.set("Clear Entire Chart", "Deletes all notes across all sections in chart.");
		menuDescriptions.set("Remove Duplicates", "Scans and removes any duplicated overlapping notes.");

		// Chart Menu Items
		menuDescriptions.set("Playtest (Enter)", "Starts playtest from very beginning of song.");
		menuDescriptions.set("Playtest Here (Shift+Enter)", "Starts playtest from current audio time position.");
		menuDescriptions.set("Playtest Preview SubState", "Previews playtesting inside a fast popup substate.");
		menuDescriptions.set("Playtest Preview Here SubState", "Previews playtesting from current time in popup substate.");
		menuDescriptions.set("Playtest Opponent (Ctrl+Enter)", "Starts playtest playing as opponent character.");
		menuDescriptions.set("Playtest Opponent Here (Ctrl+Shift+Enter)", "Plays as opponent from current audio position.");
		menuDescriptions.set("Edit Song Data (Song Tab)", "Opens Song settings tab (BPM, speed, characters).");
		menuDescriptions.set("Edit Section Data (Section Tab)", "Opens Section settings tab (mustHitSection, etc).");
		menuDescriptions.set("Edit Events (Events Tab)", "Opens event editor to add or modify events at current time.");

		// View Menu Items
		menuDescriptions.set("Zoom In (Ctrl++)", "Increases grid vertical zoom scale.");
		menuDescriptions.set("Zoom Out (Ctrl+-)", "Decreases grid vertical zoom scale.");
		menuDescriptions.set("Reset Zoom (Ctrl+0)", "Resets grid vertical zoom scale to default.");
		menuDescriptions.set("Grid Size + (Ctrl+Shift++)", "Increases grid lane width and arrow graphic size.");
		menuDescriptions.set("Grid Size - (Ctrl+Shift+-)", "Decreases grid lane width and arrow graphic size.");
		menuDescriptions.set("Reset Grid Size (Ctrl+Shift+0)", "Resets grid lane width to default.");
		menuDescriptions.set("Grid Alpha +", "Increases grid background line opacity.");
		menuDescriptions.set("Grid Alpha -", "Decreases grid background line opacity.");
		menuDescriptions.set("Reset Grid Alpha", "Resets grid background line opacity to default.");
		menuDescriptions.set("Toggle Gameplay/Stage Preview", "Toggles background stage rendering behind grid.");
		menuDescriptions.set("Toggle Color Quants", "Toggles note coloring based on beat quantization.");
		menuDescriptions.set("Toggle Duplicate Boxes", "Highlights duplicate overlapping notes with warning boxes.");
		menuDescriptions.set("Toggle Waveforms", "Toggles rendering audio waveform behind grid lanes.");
		menuDescriptions.set("Scroll Left (Shift+Left)", "Scrolls grid view offset to the left.");
		menuDescriptions.set("Scroll Right (Shift+Right)", "Scrolls grid view offset to the right.");
		menuDescriptions.set("Scroll Reset (Shift+Down)", "Resets grid horizontal scroll offset to center.");

		// Song Menu Items
		menuDescriptions.set("Toggle Vocals Mute", "Mutes or unmutes vocal audio track.");
		menuDescriptions.set("Toggle Inst Mute", "Mutes or unmutes instrumental audio track.");
		menuDescriptions.set("Playback 0.25x", "Sets audio playback speed multiplier to 0.25x.");
		menuDescriptions.set("Playback 0.5x", "Sets audio playback speed multiplier to 0.5x.");
		menuDescriptions.set("Playback 0.75x", "Sets audio playback speed multiplier to 0.75x.");
		menuDescriptions.set("Playback 1.0x (Normal)", "Sets audio playback speed multiplier to 1.0x (Normal).");
		menuDescriptions.set("Playback 1.25x", "Sets audio playback speed multiplier to 1.25x.");
		menuDescriptions.set("Playback 1.5x", "Sets audio playback speed multiplier to 1.5x.");
		menuDescriptions.set("Playback 2.0x", "Sets audio playback speed multiplier to 2.0x.");
		menuDescriptions.set("Player Hitsounds", "Toggles hitsound feedback audio when player notes pass.");
		menuDescriptions.set("Opponent Hitsounds", "Toggles hitsound feedback audio when opponent notes pass.");

		// Note Menu Items
		menuDescriptions.set("Default Note", "Sets active note type to standard arrow note.");
		menuDescriptions.set("Alt Animation Note", "Sets active note type to play character alt animation.");
		menuDescriptions.set("Hurt Note", "Sets active note type to mine / hurt note.");
		menuDescriptions.set("Hey Note", "Sets active note type to play character 'Hey!' animation.");

		// Playback Menu Items
		menuDescriptions.set("Play / Pause (Space)", "Toggles chart audio playback between play and pause.");
		menuDescriptions.set("Speed Up (.)", "Increases song playback speed multiplier.");
		menuDescriptions.set("Reset Speed", "Resets playback speed multiplier to 1.0x.");
		menuDescriptions.set("Slow Down (,)", "Decreases song playback speed multiplier.");
		menuDescriptions.set("Section Back (A)", "Jumps backward by one section.");
		menuDescriptions.set("Section Forward (D)", "Jumps forward by one section.");
		menuDescriptions.set("Step Back (W)", "Jumps backward by one step.");
		menuDescriptions.set("Step Forward (S)", "Jumps forward by one step.");
	}

	function exitCharting():Void
	{
		PlayState.chartingMode = PlayState.modchartingMode = false;
		PlayState.botUsed = PlayState.noDeathUsed = PlayState.tooSlow = false;
		PlayState.startOnTime = 0;
		if (FlxG.sound.music != null) FlxG.sound.music.stop();
		if (vocals != null) vocals.stop();
		openSubState(new substates.ExitChartingSubstate());
	}

	override function destroy() {
		unfocusAllInputs();
		if (instance == this)
			instance = null;
		super.destroy();
	}
}
