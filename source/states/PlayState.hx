package states;
import Popup.MessagePopup;
import game.Replay;
import game.CharacterPlayingAs;
import game.PlayStateHUD;
#if MODCHARTING_TOOLS

#end
import flixel.util.FlxDestroyUtil;
import modding.helpers.FlxTweenUtil;
import haxe.Json;
import substates.ResultsSubstate;
import flixel.FlxBasic;
import shaders.ColorSwap;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.addons.transition.FlxTransitionableState;
import flixel.group.FlxGroup;
import flixel.group.FlxSpriteGroup;
import flixel.input.FlxInput.FlxInputState;
import flixel.input.keyboard.FlxKey;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.sound.FlxSound;
import flixel.system.FlxAssets.FlxGraphicAsset;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.tweens.misc.VarTween;
import flixel.ui.FlxBar;
import flixel.util.FlxColor;
import flixel.util.FlxSort;
import flixel.util.FlxStringUtil;
import flixel.util.FlxTimer;
import game.Boyfriend;
import game.Character;
import game.Conductor;
import game.Cutscene;
import game.Highscore;
import game.Note;
import game.NoteGroup;
import game.NoteSplash;
import game.SongLoader;
import game.SoundGroup;
import game.StageGroup;
import game.StrumNote;
import game.TimeBar;
import game.HealthBarStyle;
import lime.utils.Assets;
import modding.*;
import modding.scripts.*;
import modding.scripts.languages.*;
import substates.GameOverSubstate;
import substates.PauseSubState;
import toolbox.ChartingState;
import ui.DialogueBox;
import ui.NoteTimer;
import ui.HealthIcon;
import utilities.NoteVariables;
import utilities.Ratings;
import utilities.ScoreValidator;
import game.EventHandler;
import sys.FileSystem;
import ui.ResortUI;
import game.FreeplaySong;
import utilities.CameraSystem;
#if CAMERA_TOOLS
import camera.CameraEventHandler;
#end


#if DISCORD_ALLOWED
import utilities.DiscordClient;
#end
#if VIDEOS_ALLOWED
import hxvlc.flixel.FlxVideo;
#end
#if MODCHARTING_TOOLS
import modcharting.NoteMovement;
import modcharting.PlayfieldRenderer;
#end
/**
	The main gameplay state.
**/
@:publicFields
class PlayState extends MusicBeatState {
	/**
		Current instance of `PlayState`.
	**/
	public static var instance:PlayState = null;

	public static var cachedChartEvents:Array<Array<Dynamic>> = null;
	public function new() {
		super();
		instance = this;
	}


	/**
		The current stage in `PlayState`.
	**/
	static var curStage:String = '';
	/**
		Current song data in `PlayState`.
	**/
	static var SONG:SongData;

	/**
		`Bool` for whether we are currently in Story Mode.
	**/
	static var isStoryMode:Bool = false;

	/**
		Current Story Mode week as an `Int`.

		(Generally unused / deprecated).
	**/
	static var storyWeek:Int = 0;

	/**
		`Array` of all the songs that you are going
		to play next in Story Mode as `String`.
	**/
	static var storyPlaylist:Array<String> = [];

	/**
		`String` representation of the current Story Mode difficulty.
	**/
	static var storyDifficultyStr:String = "NORMAL";

	/**
		Total score over your current run in Story Mode.
	**/
	static var campaignScore:Int = 0;

	/**
		Title of current week in Story Mode.
	**/
	static var campaignTitle:String;
	public static var autoTestDuration:Float = 0;
	public static var autoTestStartTime:Float = 0;
	#if sys
	static var _testFrames:Int = 0;
	static var _testTotalTime:Float = 0.0;
	static var _testMinFps:Float = 9999.0;
	static var _testMaxFps:Float = 0.0;
	static var _testMaxActiveNotes:Int = 0;
	static var _testLastSec:Int = -1;
	#end

	/**
		Vocal tracks for the current song as a `SoundGroup`.
	**/
	var vocals:SoundGroup = new SoundGroup(2);

	/**
		Your current opponent.
	**/
	static var dad:Character;

	/**
		The current character in the middle of the 3 main characters.
	**/
	static var gf:Character;

	/**
		The current player character.
	**/
	static var boyfriend:Boyfriend;

	/**
		The current stage.
	**/
	var stage:StageGroup;

	/**
		`FlxTypedGroup` of all currently active notes in the game.
	**/
	var notes:NoteGroup;

	/**
		`Array` of all the notes waiting to be spawned into the game (when their time comes to prevent lag).
	**/
	var unspawnNotes:Array<Note> = [];
	public var spawnTimeAhead:Float = 1500.0;
	var noteDataPossibles:Array<Bool> = [];
	var rythmArray:Array<Bool> = [];

	/**
		Simple `FlxSprite` to help represent the strum line the strums initially spawn at.
	**/
	var strumLine:FlxSprite;

	/**
		`FlxTypedGroup` of all current strums (enemy strums are first).
	**/
	static var strumLineNotes:FlxTypedGroup<StrumNote>;

	/**
		`FlxTypedGroup` of all current player strums.
	**/
	static var playerStrums:FlxTypedGroup<StrumNote>;

	/**
		`FlxTypedGroup` of all current enemy strums.
	**/
	static var enemyStrums:FlxTypedGroup<StrumNote>;

	/**
		Simple `FlxObject` to store the camera's current position that it's following.
	**/

	public var camFollow:utilities.CameraSystem.LuaCameraFollow;
	public var cameraSystem:CameraSystem;
	var centerCamera:Bool = false;
	public var healthDrainAmount:Float = 0;
	var savedCam:FlxPoint;
	/**
		`Bool` for whether or not the camera is currently zooming in and out to the song's beat.
	**/
	var camZooming:Bool = false;

	/**
	 * `Bool` for if the camera is allowed to zoom in.
	 */
	var cameraZooms:Bool = Options.getData("cameraZooms");

	/**
		Speed of camera.
	**/
	var cameraSpeed:Float = 1;

	/**
		Speed of camera zooming.
	**/
	var cameraZoomSpeed:Float = 1;

	/**
	 * Multiplier for strength of camera bops.
	 */
	var cameraZoomStrength:Float = 1;

	/**
	 * Multiplier for speed of camera bops.
	 */
	var cameraZoomRate:Float = 1;

	/**
		Shortner for `SONG.song`.
	**/
	var curSong:String = "";

	/**
		The interval of beats the current `gf` waits till their `dance` function gets called. (as an `Int`)

		Example:
			1 = Every Beat,
			2 = Every Other Beat,
			etc.
	**/
	var gfSpeed:Int = 1;

	/**
		Current `health` of the player (stored as a range from `minHealth` to `maxHealth`, which is by default 0 to 2).
	**/
	var health:Float = 1;

	/**
		Current `health` being shown on the `healthBar`. (Is inverted from normal when playing as opponent)
	**/
	public var healthShown:Float = 1;

	/**
		Minimum `health` value. (Defaults to 0)
	**/
	public var minHealth:Float = 0;

	/**
		Maximum `health` value. (Defaults to 2)
	**/
	public var maxHealth:Float = 2;

	/**
	 * Is the player dead?
	 */
	var dead(get, default):Bool = false;

	/**
		Current combo (or amount of notes hit in a row without a combo break).
	**/
	var combo:Int = 0;

	/**
		Current combo (or amount of notes hit in a row without a combo break).
	**/
	var maxCombo:Int = 0;

	/**
		Current score for the player.
	**/
	var songScore:Int = 0;

	/**
		Current miss count for the player.
	**/
	var misses:Int = 0;

	/**
		Current accuracy for the player (0 - 100).
	**/
	var accuracy:Float = 100.0;

	public var hud:PlayStateHUD;

	public var healthBarBG(get, set):FlxSprite;
	inline function get_healthBarBG():FlxSprite return hud != null ? hud.healthBarBG : null;
	inline function set_healthBarBG(v:FlxSprite):FlxSprite return hud != null ? (hud.healthBarBG = v) : v;

	public var healthBar(get, set):FlxBar;
	inline function get_healthBar():FlxBar return hud != null ? hud.healthBar : null;
	inline function set_healthBar(v:FlxBar):FlxBar return hud != null ? (hud.healthBar = v) : v;

	public var healthBarStyleData(get, set):HealthBarStyle;
	inline function get_healthBarStyleData():HealthBarStyle return hud != null ? hud.healthBarStyleData : null;
	inline function set_healthBarStyleData(v:HealthBarStyle):HealthBarStyle return hud != null ? (hud.healthBarStyleData = v) : v;

	public var timeBar(get, set):TimeBar;
	inline function get_timeBar():TimeBar return hud != null ? hud.timeBar : null;
	inline function set_timeBar(v:TimeBar):TimeBar return hud != null ? (hud.timeBar = v) : v;

	/**
		Current time bar style selected by the player.
	**/
	var timeBarStyle(default, null):String = Options.getData("timeBarStyle");

	@:deprecated("infoTxt is deprecated, use timeBar.txt instead")
	var infoTxt(get, set):FlxText;

	@:deprecated("timeBarBG is deprecated, use timeBar.bg instead")
	var timeBarBG(get, set):FlxSprite;

	/**
		Variable for if `generateSong` has been called successfully yet.
	**/
	var generatedMusic:Bool = false;

	/**
		Whether or not the player has started the song yet.
	**/
	var startingSong:Bool = false;
	var cutsceneAborted:Bool = false;

	public var iconP1(get, set):Array<HealthIcon>;
	inline function get_iconP1():Array<HealthIcon> return hud != null ? hud.iconP1 : [];
	inline function set_iconP1(v:Array<HealthIcon>):Array<HealthIcon> return hud != null ? (hud.iconP1 = v) : v;

	public var iconP2(get, set):Array<HealthIcon>;
	inline function get_iconP2():Array<HealthIcon> return hud != null ? hud.iconP2 : [];
	inline function set_iconP2(v:Array<HealthIcon>):Array<HealthIcon> return hud != null ? (hud.iconP2 = v) : v;

	var _luaConductor:Dynamic = {};
	var _luaFlxG:Dynamic = {};
		/**
	 * `FlxCamera` for misc elements.
	 * Drawn over hud.
	 */
	var camOther:FlxCamera;

	/**
		`FlxCamera` for all HUD/UI elements.
	**/
	var camHUD:FlxCamera;
	
	/**
		`FlxCamera` for all elements part of the main scene.
	**/
	var camGame:FlxCamera;

	/**
		Current text under the health bar (displays score and other stats).
	**/
	public var scoreTxt(get, set):FlxText;
	inline function get_scoreTxt():FlxText return hud != null ? hud.scoreTxt : null;
	inline function set_scoreTxt(v:FlxText):FlxText return hud != null ? (hud.scoreTxt = v) : v;

	public var accText(get, set):FlxText;
	inline function get_accText():FlxText return hud != null ? hud.accText : null;
	inline function set_accText(v:FlxText):FlxText return hud != null ? (hud.accText = v) : v;

	public var ratingSuffix(get, set):FlxText;
	inline function get_ratingSuffix():FlxText return hud != null ? hud.ratingSuffix : null;
	inline function set_ratingSuffix(v:FlxText):FlxText return hud != null ? (hud.ratingSuffix = v) : v;

	public var diedTxt(get, set):FlxText;
	inline function get_diedTxt():FlxText return hud != null ? hud.diedTxt : null;
	inline function set_diedTxt(v:FlxText):FlxText return hud != null ? (hud.diedTxt = v) : v;

	public var rankTxt(get, set):FlxText;
	inline function get_rankTxt():FlxText return hud != null ? hud.rankTxt : null;
	inline function set_rankTxt(v:FlxText):FlxText return hud != null ? (hud.rankTxt = v) : v;

	var noteTimes:Array<Float> = [];
	public var nps:Int = 0;
	public var npsPeak:Int = 0;


	/**
		Total notes interacted with. (Includes missing and hitting)
	**/
	var totalNotes:Int = 0;

	/**
		Total notes hit (is a `Float` because it's used for accuracy calculations).
	**/
	var hitNotes:Float = 0.0;

	/**
		`FlxGroup` for all the sprites that should go above the characters in a stage.
	**/
	var foregroundSprites:FlxGroup = new FlxGroup();

	/**
		The default camera zoom (used for camera zooming properly).
	**/
	var defaultCamZoom:Float = 1.05;

	/**
		The default hud camera zoom (used for zoom the hud properly).
	**/
	var defaultHudCamZoom:Float = 1.0;

	#if CAMERA_TOOLS
	public var cameraEventHandler:CameraEventHandler;
	#end

	/**
		Current alt animation for any characters that may be using it (should just be `dad`).
	**/
	var altAnim:String = "";

	/**
		Whether or not you are currently in a cutscene.
	**/
	var inCutscene:Bool = false;

	/**
		Current group of weeks you are playing from.
	**/
	static var groupWeek:String = "";

	/**
		Small Icon to use in RPC.
	**/
	var iconRPC:String = "";
	var curPortrait:String = "";
	var curImage:String = "";
	/**
		Details to use in RPC.
	**/
	var detailsText:String = "Freeplay";

	/**
		Paused Details to use in RPC.
	**/
	var detailsPausedText:String = "";

	/**
		Length of the current song's instrumental track in milliseconds.
	**/
	var songLength:Float = 0;

	/**
		Your current key bindings stored as `Strings`.
	**/
	var binds:Array<String>;
	var cachedFlxKeys:Array<FlxKey> = [];
	static final ARROW_KEYS:Array<FlxKey> = [FlxKey.LEFT, FlxKey.DOWN, FlxKey.UP, FlxKey.RIGHT];

	// wack ass ui shit i need to fucking change like oh god i hate this shit mate
	var ui_settings:Array<String> = [];
	var mania_size:Array<String> = [];
	var mania_offset:Array<String> = [];
	var mania_gap:Array<String> = [];
	var types:Array<String> = [];

	// this sucks too, sorry i'm not documentating this bullshit that ima replace at some point with nice clean yummy jsons
	// - leather128
	var arrow_Configs:Map<String, Array<String>> = new Map<String, Array<String>>();
	var type_Configs:Map<String, Array<String>> = new Map<String, Array<String>>();
	/**
		`Array` of cached miss sounds.
	**/
	var missSounds:Array<FlxSound> = [];

	/**
		Current song multiplier. (Should be minimum 0.25)
	**/
	public static var songMultiplier:Float = 1;

	/**
		Variable that stores the original scroll speed before being divided by `songMultiplier`.

		Usage: ChartingState
	**/
	static var previousScrollSpeed:Float = 0;

	/**
		Current `Cutscene` data.
	**/
	var cutscene:Cutscene;

	/**
		Current time of the song in milliseconds used for the progress bar.
	**/
	var time:Float = 0.0;

	/**
		A `Map` of the `String` names of the ratings to the amount of times you got them.
	**/
	var ratings:Map<String, Int> = ["marvelous" => 0, "sick" => 0, "good" => 0, "bad" => 0, "shit" => 0];

	/**
		Current text that displays your ratings (plus misses and MA/PA).
	**/
	public var ratingText(get, set):FlxText;
	inline function get_ratingText():FlxText return hud != null ? hud.ratingText : null;
	inline function set_ratingText(v:FlxText):FlxText return hud != null ? (hud.ratingText = v) : v;

	/**
		Variable used by Lua Modcharts to stop the song midway.
	**/
	var stopSong:Bool = false;

	/**
		`Array` of current events used by the song.
	**/
	var events:Array<Array<Dynamic>> = [];

	/**
		Original `Array` of the current song's events.
	**/
	var baseEvents:Array<Array<Dynamic>> = [];

	var usedLuaCameras:Bool = false;
	static var chartingMode:Bool = false;
	static var modchartingMode:Bool = false;
	public static var startInCharter:Bool = false;
	static var practiceMode:Bool = false;
	static var oneshotMode:Bool = false;
	public static var oneshotId:String = "";
	public static var lastCurOneshot:Int = 0;
	static var tooSlow:Bool = false;
	static var botUsed:Bool = false;
	static var noDeathUsed:Bool = false;
	public static var diedInNoDeath:Bool = false;
	public static var deathCounter:Int = 0;
	static var invalidJudgements:Bool = false;
	static var ogSkin:String = "default";

	/**
		0 = bf
		1 = opponent
		-1 = both
	**/
	public static var characterPlayingAs:CharacterPlayingAs = BF;

	/**
		The current hitsound the player is using. (By default is 'none')
	**/
	var hitSoundString:String = Options.getData("hitsound");
	public var enteringChartEditor:Bool = false;
	/**
		`Map` of `String` to `Boyfriend` for changing `bf - gf - dad`'s character.
	**/
	var bfMap:Map<String, Boyfriend> = [];
	var gfMap:Map<String, Character> = [];
	var dadMap:Map<String, Character> = [];

	/**
		`Map` of `String` to `StageGroup` for changing the `stage`.
	**/
	var stageMap:Map<String, StageGroup> = [];

	/**
		Whether the game will or will not load events from the chart's `events.json` file.
		(Disabled while charting as the events are already loaded)
	**/
	static var loadChartEvents:Bool = true;

	/**
		Keeps track of the original player key count.

		(Used when playing as opponent).
	**/
	var ogPlayerKeyCount:Int = 4;

	/**
		Keeps track of the original opponent (or both if not specified for player) key count.

		(Used when playing as opponent).
	**/
	var ogKeyCount:Int = 4;

	/**
		`Map` of `String` to `LuaScript` used for custom events.
	**/
	var scripts:Map<String, Script> = new Map();
	var cutsceneScripts:Map<String, HScript> = new Map(); 
	public var activeDialogue:DialogueBox; 

	/**
		`FlxTypedGroup` of `NoteSplash`s used to contain all note splashes
		and make performance better as a result by using `.recycle`.
	**/
	var splash_group:FlxTypedSpriteGroup<NoteSplash> = new FlxTypedSpriteGroup<NoteSplash>();

	/**
	 * Should the player spawn a notesplash on a sick or marvelous rating?
	 */
	var playerNoteSplashes:Bool = Options.getData("playerNoteSplashes");

	/**
	 * Should the opponent spawn a notesplash on a sick or marvelous rating?
	 */
	var opponentNoteSplashes:Bool = Options.getData("opponentNoteSplashes");

	var enemyStrumsGlow:Bool = Options.getData("enemyStrumsGlow");

	var ratingsGroup:FlxSpriteGroup = new FlxSpriteGroup();

	var marvelousRatings:Bool = Options.getData("marvelousRatings");

	static var playCutscenes:Bool = false;

	var noteTimer:NoteTimer;
	var isResortSkin:Bool = false;
	/**
	 * Manages tweens in lua scripts to pause when game is
	 */
	var tweenManager:FlxTweenManager;
	public var resortUI(get, set):ResortUI;
	inline function get_resortUI():ResortUI return hud != null ? hud.resortUI : null;
	inline function set_resortUI(v:ResortUI):ResortUI return hud != null ? (hud.resortUI = v) : v;
	public var replay:Replay;
	//freeplay - pause - playstate conection (text assets idk lol)
	public static var songRender:String = null;
	public static var songMetadata:FreeplayMetadata = null;
	public static var currentFreeplaySong:FreeplaySong = null;

	//practice mode
	    public static var practiceStartTime:Float = 0;
    public static var practiceEndTime:Float = 0;


	public var rpcData:{curPortrait:String, image:String};
	private static var _ONE_ARG:Array<Dynamic> = [null];
	private var _lastReportedBeat:Float = -999;
	private var _lastReportedBpm:Float = -999;
	override function create() {
		utilities.MusicTransition.reset();
		diedInNoDeath = false;
		closeScripts();
		// set instance because duh
		instance = this;


		onPreCreate();

		tweenManager = new FlxTweenManager();
		
		replay = new Replay();

		FlxG.mouse.visible = false;

		if (!chartingMode) {
			ChartingState.globalSecton = 0;
		}

		// preload pause music
		var pauseMusicPreload = new FlxSound();
		pauseMusicPreload.loadEmbedded(Paths.music('breakfast'));
		pauseMusicPreload.destroy();

		if (SONG == null) // this should never happen, but just in case
			SONG = SongLoader.loadFromJson('normal', 'tutorial');

		// gaming time
		curSong = SONG.song;
		#if DISCORD_ALLOWED
		rpcData = DiscordClient.getSongPresenceAssets(SONG.song, storyDifficultyStr);
		#end

		// if we have a hitsound, preload it nerd
		if (hitSoundString != "none")
			hitsound = FlxG.sound.load(Paths.sound("hitsounds/" + hitSoundString.toLowerCase()));

		// set the character we playing as
		switch (Options.getData("playAs").toLowerCase()) {
			case "opponent":
				characterPlayingAs = OPPONENT;
			case "both":
				characterPlayingAs = BOTH;
			default:
				characterPlayingAs = BF;
		}

		resolveCharacterPlayingAs();

		// key count flipping
		ogPlayerKeyCount = SONG.playerKeyCount;
		ogKeyCount = SONG.keyCount;

		if (characterPlayingAs == OPPONENT) {
			var oldRegKeyCount = SONG.playerKeyCount;
			var oldPlrKeyCount = SONG.keyCount;

			SONG.playerKeyCount = oldPlrKeyCount;
			SONG.keyCount = oldRegKeyCount;
		}

		if (songMultiplier < 1) {
			tooSlow = true;
		}

		if (Options.getData("botplay")) {
			botUsed = true;
		}

		var timings:Array<Float> = Options.getData("judgementTimings");

		if (timings[0] > 25 || timings[1] > 50 || timings[2] > 90 || timings[3] > 135) {
			invalidJudgements = true;
		}

		// check for invalid settings
		if (tooSlow || Options.getData("botplay")|| invalidJudgements || characterPlayingAs != BF || PlayState.practiceMode || PlayState.chartingMode || PlayState.modchartingMode ) {
			SONG.validScore = false;
		}

		// preload the miss sounds
		for (i in 0...2) {
			var sound = FlxG.sound.load(Paths.sound('missnote' + Std.string((i + 1))), 0.2);
			missSounds.push(sound);
		}

		// load our binds
		binds = Options.getData("binds", "binds")[SONG.playerKeyCount - 1];
		cachedFlxKeys = [for (b in binds) FlxKey.fromString(b)];

		// remove old insts and destroy them
		if (FlxG.sound.music != null) {
			FlxG.sound.music.stop();
			FlxG.sound.music.destroy();
			FlxG.sound.music = null;
		}

		// setup the cameras
		camGame = new FlxCamera();
		camHUD = new FlxCamera();
		camOther = new FlxCamera();

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camOther, false);

		camHUD.bgColor.alpha = 0;
		camOther.bgColor.alpha = 0;
				
		persistentUpdate = true;
		persistentDraw = true;

		#if sys
		// minimum of 0.25
		songMultiplier = FlxMath.bound(songMultiplier, 0.25);
		#else
		// this shouldn't happen, but just in case
		songMultiplier = 1;
		#end

		// this is broken btw
		Conductor.timeScale = SONG.timescale;

		// bpm shits
		Conductor.mapBPMChanges(SONG, songMultiplier);
		Conductor.changeBPM(SONG.bpm, songMultiplier);

		previousScrollSpeed = SONG.speed;

		// SONG.speed /= songMultiplier;

		// just in case haxe does something weird af
		if (SONG.speed < 0)
			SONG.speed = 0;

		speed = SONG.speed;

		Conductor.recalculateStuff(songMultiplier);
		noteKillOffset = Math.max(Conductor.stepCrochet, 350 / Math.max(0.1, SONG.speed));
		updateSpawnTimeAhead();

		// not sure why this is here and not later but sure
		noteBG = new FlxSprite(0, 0);
		noteBG.cameras = [camHUD];
		noteBG.makeGraphic(1, 1000, FlxColor.BLACK);
		add(noteBG);

		if (SONG.stage == null) {
			SONG.stage = 'stage';
		}
		
		ogSkin = SONG.ui_Skin;

		var skin = Options.getData("uiSkin");
		SONG.ui_Skin = (skin != null && skin != "default")
			? skin
			: (ogSkin != null ? ogSkin : "default");
		setupUISkinConfigs(SONG.ui_Skin);
		isResortSkin = SONG.ui_Skin == "Resort";
		curStage = SONG.stage;

		// set gf lol
		if (SONG.gf == null) {
			SONG.gf = 'gf';
		}

		/* character time :) */

		// create the characters nerd
		if (!Options.getData("charsAndBGs")) {
			gf = new Character(400, 130, "");
			gf.scrollFactor.set(0.95, 0.95);

			dad = new Character(100, 100, "");
			boyfriend = new Boyfriend(770, 450, "");
		} else {
			gf = new Character(400, 130, SONG.gf);
			gf.scrollFactor.set(0.95, 0.95);

			dad = new Character(100, 100, SONG.player2);
			boyfriend = new Boyfriend(770, 450, SONG.player1);

			bfMap.set(SONG.player1, boyfriend);
			dadMap.set(SONG.player2, dad);
			gfMap.set(SONG.gf, gf);
		}
		/* end of character time */
		
		#if DISCORD_ALLOWED
		iconRPC = dad.icon;

		// String that contains the mode defined here so it isn't necessary to call changePresence for each mode
		if (isStoryMode)
			detailsText = "Story Mode";

		detailsPausedText = 'Paused - $detailsText';

		// Updating Discord Rich Presence.
		DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyStr + ")", iconRPC);
		#end

		strumLine = new FlxSprite(0, 100).makeGraphic(FlxG.width, 10);

		if (Options.getData("downscroll"))
			strumLine.y = FlxG.height - 100;

		// stage maker
		stage = new StageGroup(Options.getData("charsAndBGs") ? curStage : "");
		stageMap.set(stage.stage, stage);
		if (stage.stageScript != null) {
			stage.stageScript.executeOn = STAGE;
			scripts.set(stage.stage, stage.stageScript);
		}
		add(stage);
		call("createStage", [stage.stage]);

		defaultCamZoom = stage.camZoom;
        camGame.bgColor = FlxColor.fromString(stage.stageData.backgroundColor ?? "#000000");

		var dadMid = dad.getMainCharacter().getMidpoint();
		var camPos:FlxPoint = FlxPoint.get(dadMid.x, dadMid.y);
		dadMid.put();

		if (dad.curCharacter.startsWith("gf")) {
			dad.setPosition(gf.x, gf.y);
			gf.visible = false;

			if (isStoryMode) {
				camPos.x += 600;
				tweenCamIn();
			}
		}

		// REPOSITIONING PER STAGE
		if (Options.getData("charsAndBGs"))
			stage.setCharOffsets();

		addCharacter(gf, false);

		if (!dad.curCharacter.startsWith("gf"))
			add(stage.infrontOfGFSprites);

		addCharacter(dad, false);

		if (dad.curCharacter.startsWith("gf"))
			add(stage.infrontOfGFSprites);

		/* we do a little trolling */
		var midPos:FlxPoint = dad.getMainCharacter().getMidpoint();

		camPos.set(midPos.x + 150 + dad.getMainCharacter().cameraOffset[0], midPos.y - 100 + dad.getMainCharacter().cameraOffset[1]);
		midPos.put();

		addCharacter(boyfriend, false);

		add(stage.foregroundSprites);
		
		Conductor.songPosition = -5000;

		strumLine.scrollFactor.set();

		strumLineNotes = new FlxTypedGroup<StrumNote>();

		playerStrums = new FlxTypedGroup<StrumNote>();
		enemyStrums = new FlxTypedGroup<StrumNote>();

		#if (MODCHARTING_TOOLS)
		if (!Options.getData("disableModcharts")) {
			if (SONG.modchartingTools
				|| Assets.exists(Paths.json("song data/" + SONG.song.toLowerCase() + "/modchart"))
				|| Assets.exists(Paths.json("song data/" + SONG.song.toLowerCase() + "/modchart-" + storyDifficultyStr.toLowerCase()))) {
				SONG.modchartingTools = true;
			}
		} else {
			SONG.modchartingTools = false;
		}
		#end

		#if CAMERA_TOOLS
		if (!Options.getData("disableCameraEvents")) {
			if (SONG.cameraEvents == true
				|| Assets.exists(Paths.json("song data/" + SONG.song.toLowerCase() + "/cameraevents"))
				|| Assets.exists(Paths.json("song data/" + SONG.song.toLowerCase() + "/cameraevents-" + storyDifficultyStr.toLowerCase()))) {
				SONG.cameraEvents = true;
				var songPath = "song data/" + SONG.song.toLowerCase();
				var path = Paths.json(songPath + "/cameraevents");
				var diffPath = Paths.json(songPath + "/cameraevents-" + storyDifficultyStr.toLowerCase());
				var jsonText = Assets.exists(path) ? Assets.getText(path) : Assets.getText(diffPath);
				if (jsonText != null) {
					cameraEventHandler = new camera.CameraEventHandler(haxe.Json.parse(jsonText), camGame, camHUD);
					cameraEventHandler.dad = dad;
					cameraEventHandler.boyfriend = boyfriend;
				}
			} else {
				cameraEventHandler = null;
			}
		} else {
			SONG.cameraEvents = false;
			cameraEventHandler = null;
		}
		#end

		generareNoteChangeEvents();
		generateSong(SONG.song);
		generateEvents();
		
		camFollow = new utilities.CameraSystem.LuaCameraFollow(camPos.x, camPos.y);
		add(camFollow);
		cameraSystem = new CameraSystem();
		cameraSystem.camFollow = camFollow;
		cameraSystem.camBase.set(camPos.x, camPos.y);
		
		if (Options.getData("charsAndBGs")) {

			FlxG.camera.zoom = defaultCamZoom;
		}

		FlxG.fixedTimestep = false;

		var healthBarPosY:Float = FlxG.height * 0.9;

		if (Options.getData("downscroll"))
			healthBarPosY = 60;

		{
			var currentDiffLower:String = (storyDifficultyStr != null) ? storyDifficultyStr.toLowerCase() : "";
			var knownDiffs:Array<String> = [];
			if (currentDiffLower != "" && !knownDiffs.contains(currentDiffLower)) {
				knownDiffs.push(currentDiffLower);
			}
			if (currentFreeplaySong != null && currentFreeplaySong.difficulties != null) {
				for (d in currentFreeplaySong.difficulties) {
					if (d != null) {
						var dl = d.toLowerCase();
						if (dl != "" && !knownDiffs.contains(dl)) knownDiffs.push(dl);
					}
				}
			}

			var foldersToCheck:Array<String> = [
					'assets/data/scripts/global/',
					'assets/data/scripts/local/',
					'assets/data/song data/${curSong.toLowerCase()}/',
					'assets/data/song data/${curSong.toLowerCase()}/$currentDiffLower/',
					#if MODDING_ALLOWED
					'mods/${Options.getData("curMod")}/data/scripts/local/',
					'mods/${Options.getData("curMod")}/data/song data/${curSong.toLowerCase()}/',
					'mods/${Options.getData("curMod")}/data/song data/${curSong.toLowerCase()}/$currentDiffLower/',
					#end
				];
			#if MODDING_ALLOWED
			for (mod in ModList.getActiveMods(PolymodHandler.metadataArrays)) {
				if (FileSystem.exists('mods/$mod/data/scripts/global/')) {
					foldersToCheck.push('mods/$mod/data/scripts/global/');
				}
			}
			#end

			// Collect difficulty suffixes from chart .json files in the song data folder as well
			var songPrefixLower = curSong.toLowerCase() + "-";
			for (folder in foldersToCheck) {
				if (FileSystem.exists(folder)) {
					for (file in FileSystem.readDirectory(folder)) {
						var fl = file.toLowerCase();
						if (fl.endsWith('.json') && fl.startsWith(songPrefixLower)) {
							var d = fl.substr(songPrefixLower.length, fl.length - songPrefixLower.length - 5);
							if (d != "" && !knownDiffs.contains(d)) knownDiffs.push(d);
						}
					}
				}
			}

			for (folder in foldersToCheck) {
				if (FileSystem.exists(folder)) {
					for (file in FileSystem.readDirectory(folder)) {
						if (!(file.endsWith('.hx') || file.endsWith('.lua') || file.endsWith('.xml'))) continue;

						// If script filename ends with -<difficulty>.<ext>, only load it for that difficulty
						var dotIdx = file.lastIndexOf('.');
						var baseLower = (dotIdx > 0 ? file.substr(0, dotIdx) : file).toLowerCase();
						var diffMismatch = false;
						for (d in knownDiffs) {
							if (d != currentDiffLower && baseLower.endsWith('-' + d)) {
								diffMismatch = true;
								break;
							}
						}
						if (diffMismatch) continue;

						var skipScript:Bool = false;
						if (Options.getData("forceDisableScripts")) {
							var isGlobal = folder.indexOf('/global/') != -1;
							if (!isGlobal && (file.endsWith('.lua') || file.endsWith('.hx'))) {
								try {
									var content = sys.io.File.getContent('$folder/$file').toLowerCase();
									if (content.indexOf('shader') != -1) {
										skipScript = true;
									}
								} catch (e:Dynamic) { Main.logSilentError(e, "PlayState: scan script for shader"); }
							}
						}
						if (skipScript) continue;

						#if HSCRIPT_ALLOWED
						if (file.endsWith('.hx')) {
							scripts.set('$folder/$file.hx', new HScript('$folder$file'));
						}
						#end
						#if LUA_ALLOWED
						if (file.endsWith('.lua')) {
							scripts.set('$folder$file.lua', new LuaScript('$folder$file'));
						}
						if (file.endsWith('.xml')) {
							scripts.set('$folder$file.xml', new XmlScript('$folder$file'));
						}
						#end
					}
				}
			}

			// TODO: Deprecate and convert this to new script system on script load.
			#if LUA_ALLOWED
			if (Assets.exists(Paths.lua("modcharts/" + PlayState.SONG.modchartPath))) {
				//trace("The 'modcharts' folder is deprecated! Use the 'scripts' folder instead!", WARNING);
				scripts.set(PlayState.SONG.modchartPath, new LuaScript(Paths.getModPath(Paths.lua("modcharts/" + PlayState.SONG.modchartPath))));
			} else if (Assets.exists(Paths.lua("scripts/" + PlayState.SONG.modchartPath))) {
				scripts.set(PlayState.SONG.modchartPath, new LuaScript(Paths.getModPath(Paths.lua("scripts/" + PlayState.SONG.modchartPath))));
			}
		#end

		call("create", [PlayState.SONG.song.toLowerCase()], MODCHART);
		call("create", [stage.stage], STAGE);
				}

		ratingsGroup.cameras = [camHUD];
		add(ratingsGroup);
		add(strumLineNotes);

		var cache_splash:NoteSplash = new NoteSplash();
		cache_splash.kill();

		splash_group.add(cache_splash);

		add(splash_group);
		add(notes);

		hud = new PlayStateHUD(this, camHUD, SONG, storyDifficultyStr);
		add(hud);

		strumLineNotes.cameras = [camHUD];
		notes.cameras = [camHUD];
		splash_group.cameras = [camHUD];

		#if MODCHARTING_TOOLS
		NoteMovement.keyCount = SONG.keyCount;
		NoteMovement.playerKeyCount = SONG.playerKeyCount;
		NoteMovement.totalKeyCount = SONG.keyCount + SONG.playerKeyCount;
		if (!Options.getData("disableModcharts")) {
			if (SONG.modchartingTools
				|| Assets.exists(Paths.json("song data/" + SONG.song.toLowerCase() + "/modchart"))
				|| Assets.exists(Paths.json("song data/" + SONG.song.toLowerCase() + "/modchart-" + storyDifficultyStr.toLowerCase()))) {
				SONG.modchartingTools = true;
				playfieldRenderer = new PlayfieldRenderer(strumLineNotes, notes, this);
				playfieldRenderer.cameras = [camHUD];
				add(playfieldRenderer);
			}
		} else {
			SONG.modchartingTools = false;
		}
		#end

		#if CAMERA_TOOLS
		if (!Options.getData("disableCameraEvents")) {
			if (SONG.cameraEvents == true
				|| Assets.exists(Paths.json("song data/" + SONG.song.toLowerCase() + "/cameraevents"))
				|| Assets.exists(Paths.json("song data/" + SONG.song.toLowerCase() + "/cameraevents-" + storyDifficultyStr.toLowerCase()))) {
				SONG.cameraEvents = true;
				if (cameraEventHandler == null) {
					var songPath = "song data/" + SONG.song.toLowerCase();
					var path = Paths.json(songPath + "/cameraevents");
					var diffPath = Paths.json(songPath + "/cameraevents-" + storyDifficultyStr.toLowerCase());
					var jsonText = Assets.exists(path) ? Assets.getText(path) : Assets.getText(diffPath);
					if (jsonText != null) {
						cameraEventHandler = new camera.CameraEventHandler(haxe.Json.parse(jsonText), camGame, camHUD);
						cameraEventHandler.dad = dad;
						cameraEventHandler.boyfriend = boyfriend;
					}
				}
			} else {
				cameraEventHandler = null;
			}
		} else {
			SONG.cameraEvents = false;
			cameraEventHandler = null;
		}
		#end

		noteTimer = new NoteTimer(this);  
    	noteTimer.cameras = [camOther]; 
    	add(noteTimer);
		startingSong = true;

		// WINDOW TITLE POG
		MusicBeatState.windowNameSuffix = " - " + SONG.song + " " + (isStoryMode ? "(Story Mode)" : "(Freeplay)");





		var cutscenePlays:String = Options.getData("cutscenePlaysOn");
		playCutsceneOnPauseLmao = playCutsceneLmao = ((cutscenePlays == "both")
			|| (isStoryMode && cutscenePlays == "story")
			|| (!isStoryMode && cutscenePlays == "freeplay"))
			&& !playCutscenes;

		playCutscenes = false;
		if (playCutsceneLmao && SONG.cutscene != null && SONG.cutscene != "") {
			cutscene = CutsceneUtil.loadFromJson(SONG.cutscene);
			playCutscene(cutscene, false);
		} else {
			startCountdown();
		}


		for (event in events) {
			call("onEventLoaded", [event[0], event[1], event[2], event[3]]);
		}

		Note.applyColorQuants(unspawnNotes);
		notes.limit = spawnTimeAhead;

		super.create();
		system.OptimizedBitmapData.releaseAllCPUData();

		call("createPost", []);
		system.OptimizedBitmapData.releaseAllCPUData();
			
		for (script in scripts) {
			script.createPost = true;
		}

		calculateAccuracy();
		updateSongInfoText();
	}

	function reorderCameras(?newCam:FlxCamera = null) {
		var cameras = FlxG.cameras.list.copy();
		for (c in cameras) {
			FlxG.cameras.remove(c, false);
		}
		for (i in 0...cameras.length) {
			if (i == cameras.length - 1 && newCam != null) {
				FlxG.cameras.add(newCam, false);
			}
			FlxG.cameras.add(cameras[i], false);
		}
		FlxG.cameras.setDefaultDrawTarget(camGame, true);
	}

	static var playCutsceneLmao:Bool = false;
	static var playCutsceneOnPauseLmao:Bool = false;

	function playCutscene(cut:Cutscene, ?endSongVar:Bool = false):Void {
		if (!endSongVar)
			clearCurrentCutscene();

		switch (cut.type.toLowerCase()) {
			case "script":
				#if HSCRIPT_ALLOWED
				var cutsceneScript:HScript = new HScript(Paths.hx('data/${cut.scriptPath}'));
				for (object in stage.stageObjects)
					cutsceneScript.interp.variables.set(object[0], object[1]);
				cutsceneScripts.set(cut.scriptPath, cutsceneScript);
				cutsceneScript.call("startCutscene");
				#else
				throw "HScript is not enabled!";
				#end
				return;

			case "video":
				startVideo(cut.videoPath, cut.videoExt, endSongVar);
				return;

			case "dialogue":
				activeDialogue = new DialogueBox(cut);
				activeDialogue.scrollFactor.set();
				activeDialogue.onDialogueFinish.add(() -> bruhDialogue(endSongVar));
				activeDialogue.cameras = [camHUD];
				activeDialogue.zIndex = 99999;
				startDialogue(activeDialogue, endSongVar);
				return;

			default:
				if (!endSongVar) startCountdown();
				else moveToResultsScreen();
				return;
		}
	}
	function startDialogue(?dialogueBox:DialogueBox, ?endSongVar:Bool = false):Void {
		if (cutsceneAborted)
			return;

		if (endSongVar) {
			paused = true;
			canPause = false;
			switchedStates = true;
			endingSong = true;
		}

		new FlxTimer().start(0.3, function(_) {
			if (cutsceneAborted)
				return;

			if (dialogueBox != null) {
				add(dialogueBox);
				return;
			}

			if (!endSongVar)
				clearCurrentCutscene();

			if (cutscene.cutsceneAfter == null) {
				if (!endSongVar)
					startCountdown();
				else
					moveToResultsScreen();
				return;
			}

			cutscene = CutsceneUtil.loadFromJson(cutscene.cutsceneAfter);
			playCutscene(cutscene, endSongVar);
		});
	}


	#if VIDEOS_ALLOWED
	public var videoHandler:FlxVideo = null;
	#end

	function startVideo(name:String, ?ext:String, ?endSongVar:Bool = false):Void {
		inCutscene = true;

		if (endSongVar) {
			paused = true;
			canPause = false;
			switchedStates = true;
			endingSong = true;
		}

		#if VIDEOS_ALLOWED
		if (videoHandler.load(Paths.getModPath(Paths.video(name, ext))))
			FlxTimer.wait(0.001, () -> videoHandler.play());
		videoHandler.onEndReached.add(function() {
			videoHandler.dispose();
			FlxG.removeChild(videoHandler);
			bruhDialogue(endSongVar);
		}, true);
		FlxG.addChildBelowMouse(videoHandler);
		#else
		bruhDialogue(endSongVar);
		trace("Videos aren't supported on this platform!", ERROR);
		#end
	}

function bruhDialogue(?endSongVar:Bool = false):Void
{
    if (cutsceneAborted)
        return;

    if (cutscene.cutsceneAfter != null)
    {
        var oldcutscene = cutscene;
        cutscene = CutsceneUtil.loadFromJson(oldcutscene.cutsceneAfter);
        playCutscene(cutscene, endSongVar);
    }
    else
    {
        if (!endSongVar) startCountdown();
        else moveToResultsScreen();
    }
}
var startTimer:FlxTimer = new FlxTimer();
static var startOnTime:Float = 0;

function startCountdown():Void {
    clearCurrentCutscene();

    if (curStep < -20) curStep = -20;

    inCutscene = false;
    paused = false;
    canPause = true;

    if (FlxG.sound.music != null) {
        FlxG.sound.music.pause();
        FlxG.sound.music.volume = 0;
    }
    if (vocals != null)
        vocals.pause();

    if (Options.getData("middlescroll")) {
        generateStaticArrows(50, false);
        generateStaticArrows(0.5, true);
    } else {
        generateStaticArrows(characterPlayingAs == BF ? 0 : 1, false);
        generateStaticArrows(characterPlayingAs == BF ? 1 : 0, true);
    }

    #if MODCHARTING_TOOLS
    NoteMovement.getDefaultStrumPos(this);
    if (playfieldRenderer != null)
        playfieldRenderer.modifierTable.reconstructTable();
    #end

    startedCountdown = true;

    var skipCountdown:Bool = (Options.getData("skipCountdown") == true);
    if (!skipCountdown) {
        for (i in 0...strumLineNotes.length) {
            var babyArrow:StrumNote = strumLineNotes.members[i];
            if (babyArrow != null) {
                var isPlayerArrow:Bool = playerStrums.members.contains(babyArrow);
                var targetAlpha:Float = (Options.getData("middlescroll") && !isPlayerArrow) ? 0.35 : 1.0;
                var targetY:Float = babyArrow.y;
                babyArrow.y = targetY - 10;
                babyArrow.alpha = 0;
                FlxTween.tween(babyArrow, {y: targetY, alpha: targetAlpha}, 1, {
                    ease: FlxEase.circOut,
                    startDelay: 0.5 + (0.2 * (babyArrow.ID % (isPlayerArrow ? SONG.playerKeyCount : SONG.keyCount)))
                });
            }
        }
    }

    if (PlayState.startOnTime > 0) {
        var timeToSeek = PlayState.startOnTime;
        PlayState.startOnTime = 0;
        startedCountdown = true;
        if (PlayState.practiceMode) {
            clearNotesBefore(timeToSeek);
            if (FlxG.sound.music != null) {
                FlxG.sound.music.stop();
                FlxG.sound.music.volume = 0;
            }
            Conductor.songPosition = timeToSeek - Conductor.crochet * 5;
        } else {
            clearNotesBefore(timeToSeek);
            #if LUA_ALLOWED
            setupLuaScripts();
            call("start", [SONG.song.toLowerCase()], BOTH);
            #end
            setSongTime(timeToSeek - 350);
            resyncVocals();
            startSong();
            return;
        }
    } else {
        Conductor.songPosition = skipCountdown ? 0 : -Conductor.crochet * 5;
    }

    #if LUA_ALLOWED
    setupLuaScripts();
    call("start", [SONG.song.toLowerCase()], BOTH);
    #end

    if (skipCountdown) {
        startTimer.start(0.001, function(tmr:FlxTimer) startSong(), 1);
        return;
    }

    var swagCounter:Int = 0;

    var basePath:String = 'ui skins/' + SONG.ui_Skin + '/countdown';
    var defaultPath:String = 'ui skins/default/countdown';

    function getImage(name:String):Dynamic {
        var path = Paths.image(basePath + "/" + name);
        if (Assets.exists(path)) {
            return Paths.gpuBitmap(basePath + "/" + name);
        } else {
            return Paths.gpuBitmap(defaultPath + "/" + name);
        }
    }

    function getSound(name:String):String {
        var skin = name + '-' + SONG.ui_Skin;
        var path = Paths.sound(skin);

        if (Assets.exists(path)) {
            return path;
        } else {
            return Paths.sound(name);
        }
    }

    function spawn(name:String, sound:String):Void {
        var spr:FlxSprite = new FlxSprite().loadGraphic(getImage(name));

        spr.scrollFactor.set();
        spr.antialiasing = ui_settings[3] == "true" && Options.getData("antialiasing");

        var scale:Float = Std.parseFloat(ui_settings[0]) * Std.parseFloat(ui_settings[7]);
        spr.setGraphicSize(Std.int(spr.width * scale));

        spr.updateHitbox();
        spr.screenCenter();
        spr.zIndex = 99999;
        spr.cameras = [camOther];

        add(spr);

        FlxTween.tween(spr, { y: spr.y + 100, alpha: 0 }, Conductor.crochet / 1000, {
            ease: FlxEase.cubeInOut,
            onComplete: function(_) spr.destroy()
        });

        FlxG.sound.play(getSound(sound), 0.6);
    }

    startTimer.start(Conductor.crochet / 1000, function(tmr:FlxTimer) {
        if (switchedStates || instance != this) {
            tmr.cancel();
            return;
        }
        call("countdownTick", [swagCounter]);

        if (dad != null) {
            if (dad.otherCharacters == null) dad.dance();
            else for (c in dad.otherCharacters) if (c != null) c.dance(altAnim);
        }
        if (gf != null) {
            if (gf.otherCharacters == null) gf.dance();
            else for (c in gf.otherCharacters) if (c != null) c.dance();
        }
        if (boyfriend != null) {
            if (boyfriend.otherCharacters == null) boyfriend.dance();
            else for (c in boyfriend.otherCharacters) if (c != null) c.dance();
        }

        switch (swagCounter) {
            case 0:
                FlxG.sound.play(getSound('intro3'), 0.6);
            case 1:
                spawn("ready", "intro2");
            case 2:
                spawn("set", "intro1");
            case 3:
                spawn("go", "introGo");
                startSong();
        }

        swagCounter++;
    }, 5);
}
	var invincible:Bool = false;
	
	function clearNotesBefore(time:Float):Void
	{
		var limit = time - 350;

		while (unspawnNotes.length > 0 && unspawnNotes[unspawnNotes.length - 1].strumTime < limit)
		{
			var note:Note = unspawnNotes.pop();
			note.kill();
			note.destroy();
		}

		if (notes != null && notes.members != null) {
			var i = notes.length - 1;
			while (i >= 0)
			{
				var note:Note = notes.members[i];
				if (note != null && note.strumTime < limit)
				{
					invalidateNote(note, i);
				}
				--i;
			}
		}
	}

	var _noteLuaData:Array<Dynamic> = [0, 0.0, "", 0.0, 0];
	var _noteExtraLuaData:Array<Dynamic> = [0, 0, "", false];

	inline function invalidateNote(note:Note, knownIdx:Int = -1):Void {
		FlxTween.cancelTweensOf(note);
		if (tweenManager != null) tweenManager.cancelTweensOf(note);
		note.kill();
		var mem = notes.members;
		var idx:Int = (knownIdx >= 0 && knownIdx < mem.length && mem[knownIdx] == note) ? knownIdx : mem.indexOf(note);
		if (idx >= 0) {
			mem.splice(idx, 1);
			notes.length--;
		}
		note.destroy();
	}

   
	function setSongTime(time:Float) {
		invincible = true;
		set("bot", true);
		if (time < 0)
			time = 0;

		if (FlxG.sound.music != null) {
			FlxG.sound.music.pause();
			FlxG.sound.music.time = time;
			#if FLX_PITCH FlxG.sound.music.pitch = songMultiplier; #end
			FlxG.sound.music.volume = 1;
			FlxG.sound.music.play();
		}

		if (vocals != null) {
			vocals.pause();
			if (Conductor.songPosition <= vocals.maxLength) {
				vocals.time = time;
				#if FLX_PITCH
				vocals.pitch = songMultiplier;
				#end
			}
			vocals.volume = 1;
			vocals.play();
		}
		Conductor.songPosition = time;
		invincible = false;
		set("bot", Options.getData("botplay"));
	}

function startSong():Void {
	startingSong = false;

	if (!paused && FlxG.sound.music != null) {
		@:privateAccess if (FlxG.sound.music.fadeTween != null) FlxG.sound.music.fadeTween.cancel();
		FlxG.sound.music.play();
		FlxG.sound.music.volume = 1;
	}

	if (vocals != null)
		vocals.play();

	if (startOnTime > 0)
		setSongTime(PlayState.practiceMode ? startOnTime : startOnTime - 500);

	startOnTime = 0;
	songLength = (FlxG.sound.music != null) ? FlxG.sound.music.length : 0;

	#if desktop
	Conductor.recalculateStuff(songMultiplier);

	#if DISCORD_ALLOWED
	var safeMultiplier:Float = (songMultiplier <= 0) ? 1 : songMultiplier;
	var timeLeft:Float = Math.max(1, (songLength - Conductor.songPosition) / safeMultiplier);
	DiscordClient.changePresence(
		detailsText + ', Misses: ' + misses,
		SONG.song + " (" + storyDifficultyStr + ") Acc: " + Std.string(accuracy) + "%",
		rpcData.curPortrait,
		true,
		timeLeft,
		rpcData.image
	);
	#end
	#end

	call("startSong", []);
	call("songStart", []);

	resyncVocals();
}

	var maniaChanges:Array<Dynamic> = [];
	var currentParsingKeyCount:Int = SONG?.keyCount ?? 4;
	var currentParsingPlayerKeyCount:Int = SONG?.playerKeyCount ?? 4;

	var addedVocals:Array<String> = [];
	inline function safeNumber(v:Dynamic):Float {
		return (Std.isOfType(v, Float) || Std.isOfType(v, Int)) ? v : 0;
	}

	inline function resolveMustPress(section:Section, note:Int):Bool {
		var hit = section.mustHitSection;

		if (note >= (!hit ? currentParsingKeyCount : currentParsingPlayerKeyCount))
			hit = !hit;

		if (characterPlayingAs == OPPONENT)
			hit = !hit;
		else if (characterPlayingAs == BOTH)
			hit = true;

		return hit;
	}

	function generateSong(dataPath:String):Void {
		Conductor.changeBPM(SONG.bpm, songMultiplier);

		if (SONG.needsVoices) {
			for (character in ['player', 'opponent', SONG.player1, SONG.player2, 'dad', 'bf']) {
				if (vocals.members.length >= 2) break;

				var soundPath = Paths.voices(
					SONG.song,
					SONG.specialAudioName ?? storyDifficultyStr.toLowerCase(),
					character,
					boyfriend.curCharacter
				);

				if (soundPath != null && !addedVocals.contains(soundPath)) {
					system.OptimizedAssets.ensureSoundCached(soundPath);
					vocals.add(FlxG.sound.list.add(new FlxSound().loadEmbedded(soundPath)));
					addedVocals.push(soundPath);
				}
			}
		}

		if (FlxG.sound.music != null && FlxG.sound.music.active)
			FlxG.sound.music.stop();

		var instPath:String = Paths.inst(SONG.song, SONG.specialAudioName ?? storyDifficultyStr.toLowerCase(), boyfriend.curCharacter);
		system.OptimizedAssets.ensureSoundCached(instPath);
		FlxG.sound.music = new FlxSound().loadEmbedded(instPath);
		FlxG.sound.music.persist = true;
		FlxG.sound.music.volume = 0;
		songLength = FlxG.sound.music.length;


		notes = new NoteGroup();
		if (Options.getData("invisibleNotes"))
			notes.visible = false;
		currentParsingKeyCount = (SONG != null && SONG.keyCount != null && SONG.keyCount > 0) ? SONG.keyCount : 4;
		currentParsingPlayerKeyCount = (SONG != null && SONG.playerKeyCount != null && SONG.playerKeyCount > 0) ? SONG.playerKeyCount : 4;

		for (section in SONG.notes) {
			// The tempo that plays while this section runs has to be active before
			// any note of the section is processed, otherwise `stepCrochet` is the
			// wrong size and sustains get cut into the wrong number of pieces.
			if (section.changeBPM && section.bpm > 0)
				Conductor.changeBPM(section.bpm, songMultiplier);
			else if (section.changeTimeScale && section.timeScale != null)
				Conductor.timeScale = section.timeScale;

			Conductor.recalculateStuff(songMultiplier);

			for (songNotes in section.sectionNotes) {
				songNotes[0] = safeNumber(songNotes[0]);
				songNotes[1] = Std.isOfType(songNotes[1], Int) ? songNotes[1] : 0;
				songNotes[2] = safeNumber(songNotes[2]);

				if (!Std.isOfType(songNotes[3], Int) && !Std.isOfType(songNotes[3], Array)) {
					if (Std.string(songNotes[3]).toLowerCase() == "hurt note")
						songNotes[4] = "hurt";
					songNotes[3] = 0;
				}

				if (!Std.isOfType(songNotes[4], String))
					songNotes[4] = "default";

				var daStrumTime = songNotes[0] + Conductor.offset + SONG.chartOffset;

				for (mchange in maniaChanges) {
					if (daStrumTime >= mchange[0]) {
						currentParsingKeyCount = mchange[2];
						currentParsingPlayerKeyCount = mchange[1];
						SONG.keyCount = currentParsingKeyCount;
						SONG.playerKeyCount = currentParsingPlayerKeyCount;
					}
				}

				var gottaHitNote = resolveMustPress(section, songNotes[1]);
				var noteData = Std.int(songNotes[1] % (currentParsingKeyCount + currentParsingPlayerKeyCount));

				if (section.mustHitSection && noteData >= SONG.playerKeyCount) {
					noteData = (noteData - SONG.playerKeyCount) % SONG.keyCount;
				} else if (!section.mustHitSection && noteData >= SONG.keyCount) {
					noteData = (noteData - SONG.keyCount) % SONG.playerKeyCount;
				}

				var oldNote = unspawnNotes.length > 0 ? unspawnNotes[unspawnNotes.length - 1] : null;

				var char:Dynamic = songNotes[3];
				var chars:Array<Int> = [];

				if (Std.isOfType(char, Array)) {
					chars = char;
					char = chars[0];
				}

				var targetKeyCount:Int = gottaHitNote ? currentParsingPlayerKeyCount : currentParsingKeyCount;
				var swagNote = new Note(daStrumTime, noteData, oldNote, false, char, songNotes[4], null,
					chars,
					gottaHitNote,
					false,
					-1,
					targetKeyCount
				);

				swagNote.sustainLength = songNotes[2];
				swagNote.mustPress = gottaHitNote;
				unspawnNotes.push(swagNote);

				var sustainGroup:Array<Note> = [];

				// Where each piece starts comes from the BPM map. The count used to be
				// `Math.floor(sustainLength / Std.int(stepCrochet))`: `Std.int` cut the
				// step to whole milliseconds and the `floor` then dropped the last step
				// of any hold that was not a whole number of steps, so holds ended early
				// and the end cap had nothing to sit on.
				var susRealEnd:Float = daStrumTime + swagNote.sustainLength;
				var susStarts:Array<Float> = Conductor.sustainSteps(daStrumTime, swagNote.sustainLength);
				// A hold shorter than a step still needs one piece to close it.
				if (susStarts.length == 0 && swagNote.sustainLength > 0) susStarts.push(daStrumTime);

				var susSpace:Float = (Options.getData("downscroll") || SONG.modchartingTools) ? 1 : FlxMath.roundDecimal(speed, 2);

				for (i in 0...susStarts.length) {
					oldNote = unspawnNotes[unspawnNotes.length - 1];

					var susSegStart:Float = susStarts[i];
					// The last piece is floored at one step so the `holdend` cap has room.
					var susSegEnd:Float = (i < susStarts.length - 1) ? susStarts[i + 1] : Conductor.sustainPieceEnd(susSegStart, susRealEnd);

					var sustainNote = new Note(
						susSegStart + (susSegEnd - susSegStart) / susSpace,
						noteData,
						oldNote,
						true,
						char,
						songNotes[4],
						null,
						chars,
						gottaHitNote,
						false,
						-1,
						targetKeyCount
					);

					// Before `speed`, which is what bakes the height.
					sustainNote.sustainMs = susSegEnd - susSegStart;

					sustainNote.scrollFactor.set();
					sustainNote.speed = oldNote.speed;
					sustainNote.mustPress = gottaHitNote;
					sustainNote.correctionOffset = Options.getData("downscroll") ? 0 : swagNote.height / 2;

					unspawnNotes.push(sustainNote);
					sustainGroup.push(sustainNote);
					sustainNote.sustains = sustainGroup;
				}

				swagNote.sustains = sustainGroup;
			}
		}

		SONG.keyCount = ogKeyCount;
		SONG.playerKeyCount = ogPlayerKeyCount;

		if (characterPlayingAs == OPPONENT) {
			SONG.keyCount = ogPlayerKeyCount;
			SONG.playerKeyCount = ogKeyCount;
		}

		unspawnNotes.sort(sortNotes);
		generatedMusic = true;
		SONG.validScore = SONG.validScore == true ? songMultiplier >= 1 : false;

		// The loop above leaves the conductor on the last section's tempo; the
		// song starts from the base one and `beatHit` takes it from there.
		Conductor.timeScale = SONG.timescale;
		Conductor.changeBPM(SONG.bpm, songMultiplier);
	}

	inline function sortNotes(a:Note, b:Note):Int {
		return FlxSort.byValues(FlxSort.DESCENDING, a.strumTime, b.strumTime);
	}


	/**
	 * The note underlay colored black.
	 * Turned off by default.
	 */
	var noteBG:FlxSprite;

	public function getStrumX(lane:Int, keyCount:Int, isPlayer:Bool):Float {
		var pos:Float = Options.getData("middlescroll") ? (isPlayer ? 0.5 : 50) : (characterPlayingAs == BF ? (isPlayer ? 1 : 0) : (isPlayer ? 0 : 1));
		var kcIdx:Int = (keyCount > 0 && keyCount <= mania_size.length) ? (keyCount - 1) : 3;
		var scale:Float = Std.parseFloat(ui_settings[0]) * (Std.parseFloat(ui_settings[2]) - Std.parseFloat(mania_size[kcIdx]));
		var w:Float = 160 * scale;
		var x:Float = (w + (2 + Std.parseFloat(mania_gap[kcIdx]))) * Math.abs(lane) + Std.parseFloat(mania_offset[kcIdx]);
		x += 100 - ((keyCount - 4) * 16) + (keyCount >= 10 ? 30 : 0);
		x += ((FlxG.width / 2) * pos);
		return x;
	}

	function generateStaticArrows(pos:Float, ?isPlayer:Bool = false, ?showReminders:Bool = true):Void {
		call("generateStaticArrows", [pos, isPlayer, showReminders]);
		var usedKeyCount:Int = isPlayer ? PlayState.SONG.playerKeyCount : PlayState.SONG.keyCount;

		for (i in 0...usedKeyCount) {
			var babyArrow:StrumNote = new StrumNote(0, strumLine.y, i, null, null, null, usedKeyCount, pos);
			babyArrow.scrollFactor.set();
			babyArrow.x += (babyArrow.width
				+ (2 + Std.parseFloat(mania_gap[usedKeyCount - 1]))) * Math.abs(i)
				+ Std.parseFloat(mania_offset[usedKeyCount - 1]);
			babyArrow.y = strumLine.y - (babyArrow.height / 2);

			babyArrow.alpha = (Options.getData("middlescroll") && !isPlayer) ? 0.35 : 1.0;

			babyArrow.ID = i;

			if (isPlayer)
				playerStrums.add(babyArrow);
			else
				enemyStrums.add(babyArrow);

			babyArrow.x += 100 - ((usedKeyCount - 4) * 16) + (usedKeyCount >= 10 ? 30 : 0);
			babyArrow.x += ((FlxG.width / 2) * pos);

			strumLineNotes.add(babyArrow);

			if (usedKeyCount != 4 && isPlayer && Options.getData("extraKeyReminders") && showReminders) {
				// var coolWidth = Std.int(40 - ((key_Count - 5) * 2) + (key_Count == 10 ? 30 : 0));
				// funny 4 key math i guess, full num is 2.836842105263158 (width / previous key width thingy which was 38)
				var coolWidth:Int = Math.ceil(babyArrow.width / 2.83684);

				// had to modify some backend shit to make this not clip off
				// https://github.com/HaxeFlixel/flixel/pull/3226
				// if this pr is merged there should be no issues.
				var keyThingLol:FlxText = new FlxText((babyArrow.x + (babyArrow.width / 2)) - (coolWidth / 2), babyArrow.y - (coolWidth / 2), coolWidth,
					binds[i], coolWidth);
				keyThingLol.cameras = [camHUD];
				keyThingLol.scrollFactor.set();
				keyThingLol.borderStyle = SHADOW_XY(6, 6);
				keyThingLol.antialiasing = false;
				add(keyThingLol);
				FlxTween.tween(keyThingLol, {y: keyThingLol.y + 10, alpha: 0}, 3, {
					ease: FlxEase.circOut,
					startDelay: 0.5 + (0.2 * i),
					onComplete: function(_) {
						remove(keyThingLol);
						keyThingLol.kill();
						keyThingLol.destroy();
					}
				});
			}
		}

		if (isPlayer && Options.getData("noteBGAlpha") != 0) {
			updateNoteBGPos();
			noteBG.alpha = Options.getData("noteBGAlpha");
		}
	}

	function updateNoteBGPos() {
		if (startedCountdown) {
			var bruhVal:Float = 0.0;

			for (note in playerStrums) {
				bruhVal += note.swagWidth + (2 + Std.parseFloat(mania_gap[SONG.playerKeyCount - 1]));
			}

			noteBG.setGraphicSize(Std.int(playerStrums.members[playerStrums.members.length-1].x+playerStrums.members[playerStrums.members.length-1].width-playerStrums.members[0].x), FlxG.height * 2);
			noteBG.updateHitbox();

			noteBG.x = playerStrums.members[0].x;
		}
	}

	inline function tweenCamIn():Void {
		FlxTween.tween(FlxG.camera, {zoom: 1.3}, (Conductor.stepCrochet * SONG.timescale[0] / 1000), {ease: FlxEase.elasticInOut});
	}

	override function openSubState(subState:FlxSubState) {
		if (paused) {
			FlxG.sound.music?.pause();

			vocals?.pause();

			#if LUA_ALLOWED
			for (sound in LuaScript.lua_Sounds) {
				sound?.pause();
			}
			#end

			if (!startTimer.finished)
				startTimer.active = false;
		}

		super.openSubState(subState);
	}

override function closeSubState() {
	if (paused) {
		if (FlxG.sound.music != null && !startingSong) {
			@:privateAccess if (FlxG.sound.music.fadeTween != null) FlxG.sound.music.fadeTween.cancel();
			FlxG.sound.music.volume = 1;
			if (vocals != null)
				vocals.volume = 1;
			resyncVocals();
		}

		if (!startTimer.finished && startTimer != null)
			startTimer.active = true;

		#if LUA_ALLOWED
		for (sound in LuaScript.lua_Sounds) {
			sound?.resume();
		}
		#end

		paused = false;

		binds = Options.getData("binds", "binds")[SONG.playerKeyCount - 1];
		cachedFlxKeys = [for (b in binds) FlxKey.fromString(b)];

		#if DISCORD_ALLOWED
		var safeMultiplier:Float = (songMultiplier <= 0) ? 1 : songMultiplier;
		if (startTimer.finished) {
			var timeLeft:Float = (songLength - Conductor.songPosition) / safeMultiplier;
			if (timeLeft < 1) timeLeft = 1;
			DiscordClient.changePresence(detailsText + ', Misses: ' + misses, SONG.song + " (" + storyDifficultyStr + ") Acc: " + Std.string(accuracy) + "%", rpcData.curPortrait, true, timeLeft, rpcData.image);
		} else {
			DiscordClient.changePresence(detailsText + ', Misses: ' + misses, SONG.song + " (" + storyDifficultyStr + ") Acc: " + Std.string(accuracy) + "%", rpcData.curPortrait, false, 0, rpcData.image);
		}
		#end

		call("onResumePost", []);
	}

	super.closeSubState();
}

	override function onFocus():Void {
		#if DISCORD_ALLOWED
		if (health > minHealth && !paused) {
			var accuracyStr = Std.string(accuracy) + "%";
			var statusText = SONG.song + " (" + storyDifficultyStr + ") Acc: " + accuracyStr;
			var safeMultiplier:Float = (songMultiplier <= 0) ? 1 : songMultiplier;
			if (Conductor.songPosition > 0.0) {
				var timeLeft:Float = (songLength - Conductor.songPosition) / safeMultiplier;
				if (timeLeft < 1) timeLeft = 1;
				DiscordClient.changePresence(detailsText + ', Misses: ' + misses, statusText, rpcData.curPortrait, true, timeLeft, rpcData.image);
			} else {
				DiscordClient.changePresence(detailsText + ', Misses: ' + misses, statusText, rpcData.curPortrait, false, 0, rpcData.image);
			}
		}
		#end

		super.onFocus();

		if (FlxG.autoPause && vocals != null)
			@:privateAccess vocals.onFocus();

		if (FlxG.sound.music != null) {
			@:privateAccess if (FlxG.sound.music.fadeTween != null) FlxG.sound.music.fadeTween.cancel();
			if (!paused && !startingSong && FlxG.sound.music.playing) {
				FlxG.sound.music.volume = 1;
				if (vocals != null && vocals.playing) {
					vocals.volume = 1;
				}
				if (FlxG.autoPause) {
					resyncVocals();
				}
			}
		}
	}
	override function onFocusLost():Void {
		#if DISCORD_ALLOWED
		if (health > minHealth && !paused && FlxG.autoPause) {
			var accuracyStr = Std.string(accuracy) + "%";
			var statusText = SONG.song + " (" + storyDifficultyStr + ") Acc: " + accuracyStr;
			DiscordClient.changePresence(detailsPausedText + ', Misses: ' + misses, statusText, rpcData.curPortrait, false, 0, rpcData.image);
		}
		#end

		if (FlxG.autoPause && vocals != null)
			@:privateAccess vocals.onFocusLost();

		super.onFocusLost();
	}

	function resyncVocals():Void {
		if (startingSong || FlxG.sound.music == null) return;

		@:privateAccess if (FlxG.sound.music.fadeTween != null) FlxG.sound.music.fadeTween.cancel();
		FlxG.sound.music.volume = 1;
		FlxG.sound.music.pitch = songMultiplier;
			
		if (vocals != null && vocals.active && vocals.playing) {
			vocals.volume = 1;
			vocals.pitch = songMultiplier;
		}

		if (!switchedStates) {
			if (!(Conductor.songPosition > 20 && FlxG.sound.music.time < 20)) {
				#if debug
				trace('Resynced Vocals {Conductor.songPosition: ${Conductor.songPosition}, FlxG.sound.music.time: ${FlxG.sound.music.time} / ${FlxG.sound.music.length}}',
					DEBUG);
				#end

				if (vocals != null) vocals.pause();
				FlxG.sound.music.pause();

				if (FlxG.sound.music.time >= FlxG.sound.music.length)
					Conductor.songPosition = FlxG.sound.music.length;
				else
					Conductor.songPosition = FlxG.sound.music.time;

				if (vocals != null) vocals.time = Conductor.songPosition;

				FlxG.sound.music.play();
				if (vocals != null) vocals.play();
			} else {
				if (Conductor.songPosition > 20 && FlxG.sound.music.time < 20) {
					#if debug
					trace('Resynced Vocals {Conductor.songPosition: ${Conductor.songPosition}, FlxG.sound.music.time: ${FlxG.sound.music.time} / ${FlxG.sound.music.length}}',
						DEBUG);
					#end

					FlxG.sound.music.time = Conductor.songPosition;
					if (vocals != null) vocals.time = Conductor.songPosition;

					FlxG.sound.music.play();
					if (vocals != null) vocals.play();
				}
			}
		}
	}

	var paused:Bool = false;

	var startedCountdown:Bool = false;
	var canPause:Bool = true;

	var canFullscreen:Bool = true;

	var switchedStates:Bool = false;

	// give: [noteDataThingy, noteType]
	// get : [xOffsetToUse]

	public var prevPlayerXVals:Map<String, Float> = [];
	public var prevEnemyXVals:Map<String, Float> = [];

	var speed(default, set):Float = 1.0;
	var noteKillOffset:Float = 350;

	var ratingStr:String = "";

	var song_info_timer:Float = 0.0;

	inline function fixedUpdate() {
		call("fixedUpdate", [1 / 120]);
	}
	
		var fixedUpdateTime:Float = 0.0;
		var lastTurn:String = "";

	function clearCurrentCutscene():Void {
		
		cutsceneScripts.clear();
		#if VIDEOS_ALLOWED
		if (videoHandler != null) {
			videoHandler.onEndReached.removeAll();
			videoHandler.dispose();
			FlxG.removeChild(videoHandler);
			videoHandler = null;
		}
		#end
		if (activeDialogue != null) {
			remove(activeDialogue);
			activeDialogue.destroy();
			activeDialogue = null;
		}
		if (cutsceneAborted) {
			for (sound in FlxG.sound.list) {
				if (sound != null && sound.exists && sound.active) {
					sound.stop();
				}
			}
		}
	}
	var discordUpdateTimer:Float = 0;
	var noteUpdateFrame:Int = 0;
	var _perfMsSuper:Float = 0;
	var _perfMsNotes:Float = 0;
	var _perfMsLua:Float = 0;
	var _perfSampleCount:Int = 0;

	override function update(elapsed:Float) {
		noteUpdateFrame++;
		var _t0:Float = Sys.cpuTime();
		var _tNotesStart:Float = 0;
		var _tLuaStart:Float = 0;
		super.update(elapsed);
		var _t1:Float = Sys.cpuTime();
		_perfMsSuper += (_t1 - _t0);


		#if sys
		if (PlayState.autoTestDuration > 0) {
			invincible = true;
			Options.setData(true, "botplay");
			set("bot", true);
			if (startingSong && startedCountdown && Conductor.songPosition >= -500) {
				startSong();
			}
			if (!startingSong && Conductor.songPosition >= PlayState.autoTestStartTime * 1000) {
				_testFrames++;
				_perfSampleCount++;
				_testTotalTime += elapsed;
				var curFps:Float = elapsed > 0 ? (1.0 / elapsed) : 60.0;
				if (_testFrames > 10) {
					if (curFps < _testMinFps) _testMinFps = curFps;
					if (curFps > _testMaxFps) _testMaxFps = curFps;
				}
				if (notes != null && notes.members.length > _testMaxActiveNotes) {
					_testMaxActiveNotes = notes.members.length;
				}
				var curSec:Int = Math.floor(Conductor.songPosition / 1000);
				if (curSec != _testLastSec) {
					_testLastSec = curSec;
					var unspawnCount:Int = (unspawnNotes != null) ? unspawnNotes.length : 0;
					var activeCount:Int = (notes != null) ? notes.members.length : 0;
					var avgSuper:Float = _perfSampleCount > 0 ? (_perfMsSuper * 1000 / _perfSampleCount) : 0;
					var avgNotes:Float = _perfSampleCount > 0 ? (_perfMsNotes * 1000 / _perfSampleCount) : 0;
					var avgLua:Float = _perfSampleCount > 0 ? (_perfMsLua * 1000 / _perfSampleCount) : 0;
					var ramMb:Float = Math.round(external.memory.Memory.getCurrentUsage() / (1024 * 1024));
					_perfMsSuper = 0;
					_perfMsNotes = 0;
					_perfMsLua = 0;
					_perfSampleCount = 0;
				}
			}
			if (!startingSong && Conductor.songPosition >= (PlayState.autoTestStartTime + PlayState.autoTestDuration) * 1000) {
				var avgFps:Float = (_testTotalTime > 0) ? (_testFrames / _testTotalTime) : 60.0;
				var finalRamMb:Float = Math.round(external.memory.Memory.getCurrentUsage() / (1024 * 1024));
				Sys.println('[SONG_TEST_METRICS] avgFps=' + Math.round(avgFps) + ' minFps=' + Math.round(_testMinFps) + ' maxActiveNotes=' + _testMaxActiveNotes + ' finalRam=' + finalRamMb + 'MB score=' + songScore);
				Sys.println("[SONG_TEST_PASS] " + SONG.song + " (" + storyDifficultyStr + ")");
				Sys.exit(0);
			}
		}
		#end

		if (PlayState.startInCharter) {
			PlayState.startInCharter = false;
			openChartEditor();
			return;
		}

		if (isResortSkin) {
			resortUI.updateBolts(notes.members, playerStrums);
      		resortUI.update(elapsed);
		}
		
		accText.alpha = ratingSuffix.alpha = rankTxt.alpha = scoreTxt.alpha;
		if (diedTxt != null && timeBar != null && timeBar.text != null)
			diedTxt.alpha = timeBar.text.alpha;

		discordUpdateTimer += elapsed;
		if (discordUpdateTimer >= 5.0) {
			if (!paused && health > minHealth) {
				var accuracyStr = Std.string(accuracy) + "%";
				var statusText = SONG.song + " (" + storyDifficultyStr + ") Acc: " + accuracyStr;
				#if DISCORD_ALLOWED
				var safeMultiplier:Float = (songMultiplier <= 0) ? 1 : songMultiplier;
				var timeLeft:Float = songLength / safeMultiplier;
				if (timeLeft < 1) timeLeft = 1;
				DiscordClient.changePresence(detailsText + ', Misses: ' + misses, statusText, rpcData.curPortrait, true, timeLeft, rpcData.image);
				#end
			}
			discordUpdateTimer = 0;
		}
		tweenManager.update(elapsed);

		var zoomLerp:Float = (elapsed * 3) * cameraZoomSpeed;
		if (cameraEventHandler == null) {
			if (cameraZooms && camZooming && !switchedStates) {
				FlxG.camera.zoom = FlxMath.lerp(FlxG.camera.zoom, defaultCamZoom, zoomLerp);
				camHUD.zoom = FlxMath.lerp(camHUD.zoom, defaultHudCamZoom, zoomLerp);
			} else if (!cameraZooms) {
				FlxG.camera.zoom = defaultCamZoom;
				camHUD.zoom = 1;
			}
		}

		song_info_timer += elapsed;
		fixedUpdateTime += elapsed;

		if (fixedUpdateTime >= 1 / 120) {
			fixedUpdate();
			fixedUpdateTime = 0;
		}

		if (song_info_timer >= 0.25 / songMultiplier) {
			updateSongInfoText();
			song_info_timer = 0;
		}

		if (stopSong && !switchedStates) {
			paused = true;
			FlxG.sound.music.volume = 0;
			vocals.volume = 0;
			FlxG.sound.music.time = 0;
			vocals.time = 0;
			Conductor.songPosition = 0;
		}

		if (!switchedStates) {
			var curSec = SONG.notes[Math.floor(curStep / Conductor.stepsPerSection)];
			if (curSec != null) {
				if (!curSec.mustHitSection || curSec.altAnim) {
					if (curSec.altAnim)
						altAnim = '-alt';
					else
						altAnim = "";
				}
			}
		}

		if (generatedMusic && startedCountdown && canPause && !endingSong && !switchedStates) {
			if (FlxG.sound.music != null && FlxG.sound.music.length > 0 && FlxG.sound.music.length - Conductor.songPosition <= 20) {
				time = FlxG.sound.music.length;
				endSong();
			}
		}

		if (timeBar != null)
			timeBar.time = time = (FlxG.sound.music != null) ? (endingSong ? FlxG.sound.music.length : FlxG.sound.music.time) : 0;
		if (healthDrainAmount != 0)
			health -= healthDrainAmount * elapsed;
		health = Math.min(health, maxHealth);

		if (characterPlayingAs == OPPONENT)
			healthShown = maxHealth - health;
		else
			healthShown = health;

		if (hud != null && generatedMusic && startedCountdown) {
			var curSection = Math.floor(curStep / Conductor.stepsPerSection);
			var mustHit = (SONG.notes[curSection] != null && SONG.notes[curSection].mustHitSection);
			hud.updateHealthBarStyle(elapsed, dad, boyfriend, mustHit);
		}

		updateHealthIcons(elapsed);
		if (!switchedStates) {
			if (startingSong) {
				if (startedCountdown) {
					if (!PlayState.practiceMode || (PlayState.practiceMode && startTimer.finished)) {
						Conductor.songPosition += FlxG.elapsed * 1000.0;

						if (Conductor.songPosition >= 0.0) {
							startSong();
						}
					} else {
						Conductor.songPosition += FlxG.elapsed * 1000.0;
					}
				}
			} else {
				Conductor.songPosition += (FlxG.elapsed * 1000.0) * songMultiplier;
			}

			// Tempo can change mid section (Codename charts are time based) and a
			// continuous change moves it every frame, so the conductor is pushed
			// from the BPM map here instead of only on `beatHit`.
			if (generatedMusic && startedCountdown)
				Conductor.syncBPM(Conductor.songPosition, songMultiplier);
		}
			var now:Float = Conductor.songPosition;

			while (noteTimes.length > 0 && (now - noteTimes[0] > 1000 || noteTimes[0] > now))
			{
				noteTimes.shift();
			}

			var lastNps:Int = nps;
			nps = noteTimes.length;
			npsPeak = Std.int(Math.max(npsPeak, nps));
			if (nps != lastNps && Options.getData("sideRatings"))
			{
				updateRatingText();
			}
			if (generatedMusic)
			{
				var section = PlayState.SONG.notes[Std.int(curStep / Conductor.stepsPerSection)];

				if (section != null && !switchedStates && startedCountdown)
				{
					set("mustHit", section.mustHitSection);

					#if CAMERA_TOOLS
					if (cameraEventHandler == null)
					#end
					{
						if (PlayState.SONG.moveCamera)
						{
							var currentTurn = section.mustHitSection ? "bf" : "dad";

							if (Options.getData("vsliceCamera"))
							{
								if (lastTurn != currentTurn)
								{
									lastTurn = currentTurn;
									turnChange(currentTurn);
								}
							}
							else
							{
								turnChange(currentTurn);
							}

							if (centerCamera)
								applyGameplayCenterCamera();
						}

						var targetChar:Character = (lastTurn == "gf" && gf != null) ? gf : (lastTurn == "dad" ? dad : (section.mustHitSection ? boyfriend : dad));
						cameraSystem.update(targetChar);
					}
				}
			}
		// RESET = Quick Game Over Screen
		if ((Options.getData("resetButton") && !switchedStates && controls.RESET) || (Options.getData("noHit") && misses > 0))
			health = minHealth;

		if (Options.getData("noDeath") && health <= minHealth && !switchedStates) {
			if (!diedInNoDeath) {
				diedInNoDeath = true;
				SONG.validScore = false;
				noDeathUsed = true;
				updateSongInfoText();
			}
		}

		if (dead) {
			boyfriend.stunned = true;
			var deadChar:Character = (characterPlayingAs == OPPONENT ? dad : boyfriend);

			persistentUpdate = false;
			persistentDraw = false;
			paused = true;

			vocals.stop();
			FlxG.sound.music.stop();

			camGame.bgColor = FlxColor.BLACK;

			openSubState(new GameOverSubstate(deadChar.getScreenPosition().x, deadChar.getScreenPosition().y));

			onPlayerDeath();

			#if DISCORD_ALLOWED
			var accuracyStr = Std.string(accuracy) + "%";
			var statusText = SONG.song + " (" + storyDifficultyStr + ") Acc: " + accuracyStr;
			DiscordClient.changePresence("Game Over - " + detailsText + ', Misses: ' + misses, statusText, rpcData.curPortrait, false, 0, rpcData.image);
			#end

			call("onDeath", [Conductor.songPosition]);
			// closeScripts();
		}

		health = Math.max(health, minHealth);

		if (!switchedStates) {
			var canSpawn:Bool = true;
			if (PlayState.practiceMode) {
				canSpawn = startedCountdown && startTimer.finished;
			}

			if (canSpawn && unspawnNotes.length > 0) {
				while (
					unspawnNotes.length > 0 &&
					unspawnNotes[unspawnNotes.length - 1].strumTime - Conductor.songPosition < spawnTimeAhead
				) {
					var spawnedNote:Note = unspawnNotes.pop();
					notes.members.push(spawnedNote);
					notes.length = notes.members.length;
				}
			}
		}


		if (generatedMusic && !switchedStates && startedCountdown && notes != null && playerStrums.members.length != 0 && enemyStrums.members.length != 0) {
			_tNotesStart = Sys.cpuTime();
			var playerStrumLen:Int = playerStrums.members.length;
			var enemyStrumLen:Int = enemyStrums.members.length;
			var isDown:Bool = Options.getData("downscroll");
			var hasPlayfield:Bool = #if MODCHARTING_TOOLS (playfieldRenderer != null) #else false #end;
			var maxNoteTime:Float = Conductor.songPosition + spawnTimeAhead;
			var noteIdx:Int = 0;
			while (noteIdx < notes.members.length) {
				var note:Note = notes.members[noteIdx];
				if (note == null || !note.alive) {
					noteIdx++;
					continue;
				}
				if (note.strumTime > maxNoteTime)
					break;
				var rawData:Int = Math.floor(Math.abs(note.noteData));
				var curStrums = note.mustPress ? playerStrums : enemyStrums;
				var matchesActiveKeyCount:Bool = (note.keyCount == curStrums.members.length);
				var coolStrum:StrumNote = (matchesActiveKeyCount && rawData < curStrums.members.length) ? curStrums.members[rawData] : null;

				note.visible = true;
				note.active = true;
				if (coolStrum != null) {
					note.calculateY(coolStrum);
				} else {
					var fallbackY:Float = strumLine.y - (note.height / 2);
					var posMath:Float = 0.45 * (Conductor.songPosition - note.strumTime) * FlxMath.roundDecimal(note.speed, 2);
					note.y = (!isDown) ? (fallbackY - posMath) : (fallbackY + note.correctionOffset + posMath);
					if (isDown && note.isSustainNote)
						note.y -= (note.frameHeight * note.scale.y) - Note.swagWidth;
					note.x = getStrumX(rawData, note.keyCount, note.mustPress);
				}
				if (note.isSustainNote && !hasPlayfield) {
					var targetStrumY:Float = (coolStrum != null) ? coolStrum.y : (strumLine.y - (note.height / 2));
					var targetStrumH:Float = (coolStrum != null) ? coolStrum.height : note.height;
					var targetStrumMid:Float = targetStrumY + (targetStrumH / 2);
					var needsClip:Bool = isDown ? (note.y + note.height > targetStrumMid) : (note.y < targetStrumMid);
					if (needsClip) {
						if (note.sustainClipRect == null)
							note.sustainClipRect = FlxRect.get(0, 0, note.frameWidth, note.frameHeight);
						else
							note.sustainClipRect.set(0, 0, note.frameWidth, note.frameHeight);
						if (isDown) {
							note.sustainClipRect.height = (targetStrumMid - note.y) / note.scale.y;
							note.sustainClipRect.y = note.frameHeight - note.sustainClipRect.height;
						} else {
							note.sustainClipRect.y = (targetStrumMid - note.y) / note.scale.y;
							note.sustainClipRect.height -= note.sustainClipRect.y;
						}
						note.clipRect = note.sustainClipRect;
					} else if (note.clipRect != null) {
						note.clipRect = null;
					}
				}
				note.calculateCanBeHit();

				if (!note.mustPress && note.canBeHit && note.shouldHit) {
					camZooming = true;

					var kcIndex:Int = (note.keyCount > 0 && note.keyCount <= NoteVariables.characterAnimations.length) ? (note.keyCount - 1) : (getCorrectKeyCount(false) - 1);
					var animList = (kcIndex >= 0 && kcIndex < NoteVariables.characterAnimations.length) ? NoteVariables.characterAnimations[kcIndex] : null;
					var animDir:String = (animList != null && rawData >= 0 && rawData < animList.length) ? animList[rawData] : "singUP";
					var singAnim:String = animDir
						+ (characterPlayingAs == BF ? altAnim : "") + note.singAnimSuffix;
					if (note.singAnimPrefix != 'sing') {
						singAnim = singAnim.replace('sing', note.singAnimPrefix);
					}

					_noteLuaData[0] = rawData;
					_noteLuaData[1] = Conductor.songPosition;
					_noteLuaData[2] = note.arrow_Type;
					_noteLuaData[3] = note.strumTime;
					_noteLuaData[4] = note.character;

					if (characterPlayingAs == BF) {
						playAnimOnNote(dad, note, singAnim);

						if (note.isSustainNote) {
							call('playerTwoSingHeld', _noteLuaData);
						} else {
							call('playerTwoSing', _noteLuaData);
						}
					} else {
						playAnimOnNote(boyfriend, note, singAnim);

						if (note.isSustainNote) {
							call('playerOneSingHeld', _noteLuaData);
						} else {
							call('playerOneSing', _noteLuaData);
						}
					}

					_noteExtraLuaData[0] = rawData;
					_noteExtraLuaData[1] = noteIdx;
					_noteExtraLuaData[2] = note.arrow_Type;
					_noteExtraLuaData[3] = note.isSustainNote;
					call(getSingLuaFuncName(false) + 'SingExtra', _noteExtraLuaData);

					// how was it THIS SIMPLE this WHOLE TIME??????
					// this has been broken for who knows how long :sob:
					note.wasGoodHit = true;

					if (enemyStrumsGlow && coolStrum != null) {
						coolStrum.playAnim('confirm', true);
						coolStrum.resetAnim = 0.2;
						copyColorSwap(coolStrum, note);

						if (!note.isSustainNote && opponentNoteSplashes) {
							var splash:NoteSplash = splash_group.recycle(NoteSplash);
							splash.setup_splash(coolStrum.ID, coolStrum, false, note);
							splash_group.add(splash);
						}
					}

					resetHoldTimer(note);
					/* @:privateAccess */
					if (vocals != null && /* vocals._transform != null && */ SONG != null && SONG.needsVoices) {
						vocals.volume = 1;
					}

					if (!note.isSustainNote) {
						invalidateNote(note, noteIdx);
					} else {
						// my favorite part about this hack is that you can technically override it with a script
						note.shouldHit = false;
					}
				}

				if (!hasPlayfield) {
					if (coolStrum != null) {
						if (note.mustPress || !note.wasGoodHit)
							alignNoteToStrum(note, coolStrum);
					} else {
						note.x = getStrumX(rawData, note.keyCount, note.mustPress);
					}
				}

				if (Conductor.songPosition - noteKillOffset > note.strumTime) {
					if (note != null
						&& note.animation != null
						&& note.animation.curAnim != null
						&& note.mustPress
						&& note.playMissOnMiss
						&& !(note.isSustainNote && note.animation.curAnim.name == "holdend")
						&& !note.wasGoodHit) {
						if (vocals != null) {
							vocals.volume = 0;
						}

						noteMiss(note.noteData, note);
					}

					note.active = false;
					note.visible = false;

					invalidateNote(note, noteIdx);
				}

				if (noteIdx < notes.members.length && notes.members[noteIdx] == note)
					noteIdx++;
			}
			_perfMsNotes += (Sys.cpuTime() - _tNotesStart);

			if (Options.getData("noteBGAlpha") != 0 && !switchedStates)
				updateNoteBGPos();
		}

		if (!inCutscene && !switchedStates)
			keyShit();

		if (Options.getData("enablePause")
		&& FlxG.keys.checkStatus(
			FlxKey.fromString(Options.getData("pauseBind", "binds")),
			FlxInputState.JUST_PRESSED
		)
		&& startedCountdown
		&& canPause
		&& !switchedStates
	) {
		persistentUpdate = false;
		persistentDraw = true;
		paused = true;

		#if LUA_ALLOWED
		for (tween in LuaScript.lua_Tweens) {
			FlxTweenUtil.pauseTween(tween);
		}
		#end

		call('onPause', []);
		openSubState(new PauseSubState());
		call('onPausePost', []);

		#if DISCORD_ALLOWED
			var accuracyStr = Std.string(accuracy) + "%";
			var statusText = '${SONG.song} (${storyDifficultyStr}) Acc: ${accuracyStr}';

DiscordClient.changePresence(
				detailsPausedText + ', Misses: ' + misses,
				statusText,
				rpcData.curPortrait,
				false,
				0,
				rpcData.image
			);
		#end
	}

if (allowDebugMenus()) {
			if (FlxG.keys.justPressed.SEVEN && !switchedStates && !inCutscene) {
				openChartEditor();
			}

			if (FlxG.keys.justPressed.EIGHT && !switchedStates && !inCutscene) {
				prepareTransition();
				FlxG.switchState(() -> new toolbox.CharacterCreator(SONG.player2, curStage));
				toolbox.CharacterCreator.lastState = "PlayState";
				#if DISCORD_ALLOWED
				DiscordClient.changePresence("Creating A Character", null, null, true);
				#end
			}

			if (FlxG.keys.justPressed.FIVE && !switchedStates && !inCutscene) {
				prepareTransition();
				PlayState.cachedChartEvents = baseEvents;
				FlxG.switchState(() -> new pages.ModchartEditor());
				#if DISCORD_ALLOWED
				DiscordClient.changePresence("In The Camera Editor", null, null, true);
				#end
			}

			#if MODCHARTING_TOOLS
			if (FlxG.keys.justPressed.NINE && !switchedStates && !inCutscene) {
				prepareTransition();
				PlayState.modchartingMode = true;
				FlxG.switchState(() -> new modcharting.ModchartEditorState());
				#if DISCORD_ALLOWED
				DiscordClient.changePresence("In The Modchart Editor" , null, null, true);
				#end
			}
			#end

		}
		if (FlxG.keys.justPressed.F6 && allowDebugMenus()) {
			toggleBotplay();
		}

		if (practiceMode && SONG != null) {
			if (Conductor.songPosition >= practiceEndTime) {
			 moveToResultsScreen(true);

			}
		}

		if (!switchedStates) {
			while (events.length > 0 && events[0][1] + Conductor.offset <= Conductor.songPosition) {
				var event = events[0];
				processEvent(event);
				events.splice(0, 1);
			}
		}

		var i:Int = splash_group.members.length - 1;
		while (i >= 0) {
			var splash:NoteSplash = splash_group.members[i];
			if (!splash.alive) {
			} else if (splash.animation.finished) {
				splash.kill();
			}
			i--;
		}

		#if LUA_ALLOWED
		if (generatedMusic && !switchedStates && startedCountdown) {
			for (shader in LuaScript.lua_Shaders) {
				shader.update(elapsed);
			}

			set("songPos", Conductor.songPosition);
			set("hudZoom", camHUD.zoom);
			set("cameraZoom", FlxG.camera.zoom);

			if (_lastReportedBeat != curBeat) {
				_lastReportedBeat = curBeat;
				set("curBeat", curBeat);
			}

			if (_lastReportedBpm != Conductor.bpm) {
				_lastReportedBpm = Conductor.bpm;
				set("bpm", Conductor.bpm);
				set("songBpm", Conductor.bpm);
				set("crochet", Conductor.crochet / songMultiplier);
				set("stepCrochet", Conductor.stepCrochet / songMultiplier);
			}

			_luaConductor.bpm = Conductor.bpm;
			_luaConductor.crochet = Conductor.crochet;
			_luaConductor.stepCrochet = Conductor.stepCrochet;
			_luaConductor.songPosition = Conductor.songPosition;
			_luaConductor.offset = Conductor.offset;
			_luaConductor.safeFrames = Conductor.safeFrames;
			_luaConductor.safeZoneOffset = Conductor.safeZoneOffset;
			// bpmChangeMap and timeScaleChangeMap are set once in setupLuaScripts
			_luaConductor.timeScale = Conductor.timeScale;
			_luaConductor.stepsPerSection = Conductor.stepsPerSection;
			_luaConductor.curBeat = curBeat;
			_luaConductor.curStep = curStep;
			set("conductor", _luaConductor);

			_luaFlxG.width = FlxG.width;
			_luaFlxG.height = FlxG.height;
			_luaFlxG.elapsed = FlxG.elapsed;
			set("flxG", _luaFlxG);

			_tLuaStart = Sys.cpuTime();
			_ONE_ARG[0] = elapsed;
			call("update", _ONE_ARG);

			// var showOnlyStrums:Bool = getLuaVar("showOnlyStrums", "bool") ?? false;

			/*for (i in 0...SONG.keyCount) {
					strumLineNotes.members[i].visible = getLuaVar("strumLine1Visible", "bool") ?? true;
				}

				for (i in 0...SONG.playerKeyCount) {
					if (i <= playerStrums.length)
						playerStrums.members[i].visible = getLuaVar("strumLine2Visible", "bool") ?? true;
			}*/

			if (!canFullscreen && FlxG.fullscreen)
				FlxG.fullscreen = false;
		} else {
		#else
		call("update", [elapsed]);
		#end
		#if LUA_ALLOWED
		}
		#end

		call("updatePost", [elapsed]);
		_perfMsLua += (Sys.cpuTime() - _tLuaStart);

		#if CAMERA_TOOLS
		if (cameraEventHandler != null) cameraEventHandler.update(elapsed, curDecStep, defaultCamZoom, defaultHudCamZoom, cameraZoomSpeed);
		#end
	}

	public function updateSpawnTimeAhead():Void {
		var spd:Float = (SONG != null && SONG.speed != null) ? SONG.speed : 1.0;
		var screenTime:Float = (FlxG.height / (0.45 * Math.max(0.2, spd))) * songMultiplier;
		spawnTimeAhead = Math.min(Math.max(650.0, screenTime + 200.0), 1250.0);
		if (notes != null) notes.limit = spawnTimeAhead;
	}

	override public function remove(basic:flixel.FlxBasic, splice:Bool = false):flixel.FlxBasic {
		var result = super.remove(basic, splice);
		if (result == null && hud != null) {
			result = hud.remove(basic, splice);
		}
		return result;
	}

	override function destroy() {
		game.Character.configCache.clear();
		if (instance == this)
			instance = null;
		call("onDestroy", []);
		closeScripts();
		if (startTimer != null) {
			startTimer.cancel();
			startTimer.destroy();
			startTimer = null;
		}
		FlxTimer.globalManager.clear();
		FlxTween.globalManager.clear();
		FlxDestroyUtil.destroy(tweenManager);

		if (!enteringChartEditor)
		{
			// Remove FlxG.sound.music from list and clear persist BEFORE SoundFrontEnd.destroy() runs
			if (FlxG.sound.music != null)
			{
				FlxG.sound.list.remove(FlxG.sound.music);
				FlxG.sound.music.persist = false;
			}
			// Vocals are FlxSounds inside a SoundGroup — remove each from FlxG.sound.list
			if (vocals != null)
			{
				for (i in 0...vocals.members.length)
				{
					var snd = vocals.members[i];
					if (snd != null)
					{
						FlxG.sound.list.remove(snd);
						snd.persist = false;
					}
				}
			}
		}
		// Now safely destroy — FlxG.sound.destroy() won't touch persist=false sounds
		FlxDestroyUtil.destroy(vocals);
		vocals = null;
		if (FlxG.sound.music != null)
		{
			FlxG.sound.music.stop();
			FlxG.sound.music.persist = false;
			FlxG.sound.music.destroy();
			FlxG.sound.music = null;
		}
		FlxDestroyUtil.destroyArray(unspawnNotes);
		unspawnNotes = null;

		FlxDestroyUtil.destroy(stage);
		stage = null;

		#if MODCHARTING_TOOLS
		FlxDestroyUtil.destroy(playfieldRenderer);
		playfieldRenderer = null;
		#end

		FlxDestroyUtil.destroy(strumLineNotes);
		FlxDestroyUtil.destroy(playerStrums);
		FlxDestroyUtil.destroy(enemyStrums);
		strumLineNotes = null;
		playerStrums = null;
		enemyStrums = null;

		FlxDestroyUtil.destroy(notes);
		notes = null;

		if (iconP1 != null) {
			for (icon in iconP1) {
				if (icon != null) {
					flixel.tweens.FlxTween.cancelTweensOf(icon);
					if (icon.scale != null) flixel.tweens.FlxTween.cancelTweensOf(icon.scale);
				}
			}
		}
		if (iconP2 != null) {
			for (icon in iconP2) {
				if (icon != null) {
					flixel.tweens.FlxTween.cancelTweensOf(icon);
					if (icon.scale != null) flixel.tweens.FlxTween.cancelTweensOf(icon.scale);
				}
			}
		}

		FlxDestroyUtil.destroy(dad);
		FlxDestroyUtil.destroy(gf);
		FlxDestroyUtil.destroy(boyfriend);
		dad = null;
		gf = null;
		boyfriend = null;

		for (s in bfMap)
			FlxDestroyUtil.destroy(s);
		bfMap.clear();
		for (s in gfMap)
			FlxDestroyUtil.destroy(s);
		gfMap.clear();
		for (s in dadMap)
			FlxDestroyUtil.destroy(s);
		dadMap.clear();
		for (s in stageMap)
			FlxDestroyUtil.destroy(s);
		stageMap.clear();

		arrow_Configs.clear();
		type_Configs.clear();
		uiMap.clear();
		scripts = null;
		cutsceneScripts = null;

		// Do not nullify events and baseEvents here so ChartingState can read them from PlayState.instance

		numbers = null;
		number_Tweens = null;
		ratings = null;

		if (ratingsGroup != null) {
			ratingsGroup.forEachAlive(function(s) { s.destroy(); });
			ratingsGroup.clear();
		}
		ratingsGroup = null;

		prevPlayerXVals = null;
		prevEnemyXVals = null;
		noteDataPossibles = null;
		rythmArray = null;

		foregroundSprites = null;

		if (!chartingMode)
		{
			ChartingState.globalSecton = 0;
		}

		#if CAMERA_TOOLS
		cameraEventHandler = null;
		#end

		PlayState.characterPlayingAs = BF;
		PlayState.botUsed = false;
		PlayState.tooSlow = false;
		PlayState.noDeathUsed = false;
		PlayState.invalidJudgements = false;


		FlxG.camera.bgColor = FlxColor.BLACK;
		super.destroy();

		#if MODCHARTING_TOOLS
		modcharting.SustainStrip.clearCache();
		#end
		utilities.MemoryUtil.clearMajor();
		#if (cpp && windows)
		external.memory.Memory.trimWorkingSet();
		#end
	}

	function applyHealthBarStyle()
	{
		if (hud != null) {
			var curSection = Math.floor(curStep / Conductor.stepsPerSection);
			var mustHit = (SONG.notes[curSection] != null && SONG.notes[curSection].mustHitSection);
			hud.applyHealthBarStyle(dad, boyfriend, curSection, mustHit);
		}
	}

	function updateHealthIcons(elapsed:Float)
	{
		if (hud != null)
			hud.updateIcons(elapsed, dad, boyfriend, songMultiplier);
	}
	function playAnimOnNote(char:Character, note:Note, singAnim:String, force:Bool = true)
	{
		var shouldForce = force;
		if (note != null && note.isSustainNote)
		{
			var currentAnim = char.curAnimName();
			var targetAnim = singAnim + char.extraSuffix;
			var loopAnim = singAnim + "-loop";
			if (currentAnim == singAnim || currentAnim == targetAnim || currentAnim == loopAnim)
			{
				shouldForce = false;
			}
		}

		if (!char.isCharacterGroup)
		{
			char.playAnim(singAnim, shouldForce);
			return;
		}

		var chars:Array<Int> = note?.characters ?? [];
		var charID:Int = note?.character ?? char.mainCharacterID;
		var targets:Array<Int> = (chars.length <= 1) ? [charID] : chars;

		for (i in targets)
		{
			if (char.otherCharacters != null && i < char.otherCharacters.length)
			{
				var c = char.otherCharacters[i];
				if (c != null)
				{
					char.activeCharacterID = i;
					var cForce = force;
					if (note != null && note.isSustainNote)
					{
						var cAnim = c.curAnimName();
						var cTarget = singAnim + c.extraSuffix;
						var cLoop = singAnim + "-loop";
						if (cAnim == singAnim || cAnim == cTarget || cAnim == cLoop)
						{
							cForce = false;
						}
					}
					c.playAnim(singAnim, cForce);
				}
			}
		}
	}
	function turnChange(char:String)
	{
		call("turnChange", [char]);

		if (stage == null) return;
		if (cameraSystem == null || cameraSystem.customTween != null) return;

		var pos = getCameraTarget(char);
		if (pos == null) return;
		cameraSystem.setTarget(pos.x, pos.y, Options.getData("vsliceCamera"));
		pos.put();

		switch (char)
		{
			case 'dad':
				call("playerTwoTurn", []);
				call("onCameraMove", ["dad"]);
			case 'bf':
				call("playerOneTurn", []);
				call("onCameraMove", ["bf"]);
			case 'gf':
				call("onCameraMove", ["gf"]);
			case 'center' | 'middle':
				call("onCameraMove", ["center"]);
		}
	}

	/**
		Computes the camera anchor point for a target. Returns an owned FlxPoint
		(call `put()` after use) or null if the target can't be resolved.
	**/
	function getCameraTarget(char:String):FlxPoint
	{
		switch (char)
		{
			case 'dad':
				centerCamera = false;
				var t = dad != null ? dad.getCameraCharacter() : null;
				if (t == null) return null;
				var m = t.getMidpoint();
				if (stage != null && stage.p2_Cam_Offset != null)
				{
					m.x += stage.p2_Cam_Offset.x;
					m.y += stage.p2_Cam_Offset.y;
				}
				var p = FlxPoint.get(m.x + 150 + t.cameraOffset[0], m.y - 100 + t.cameraOffset[1]);
				m.put();
				return p;

			case 'bf':
				centerCamera = false;
				var t = boyfriend != null ? boyfriend.getCameraCharacter() : null;
				if (t == null) return null;
				var m = t.getMidpoint();
				if (stage != null && stage.p1_Cam_Offset != null)
				{
					m.x += stage.p1_Cam_Offset.x;
					m.y += stage.p1_Cam_Offset.y;
				}
				var p = FlxPoint.get(m.x - 100 + t.cameraOffset[0], m.y - 100 + t.cameraOffset[1]);
				m.put();
				return p;

			case 'gf':
				centerCamera = false;
				var t = gf != null ? gf.getCameraCharacter() : null;
				if (t == null) return null;
				var m = t.getMidpoint();
				var stOff = (stage != null && stage.gf_Cam_Offset != null) ? stage.gf_Cam_Offset : null;
				var stX = stOff != null ? stOff.x : 0;
				var stY = stOff != null ? stOff.y : 0;
				var p = FlxPoint.get(m.x + t.cameraOffset[0] + stX, m.y + t.cameraOffset[1] + stY);
				m.put();
				return p;

			case 'center' | 'middle':
				// The live center is recomputed every frame by applyGameplayCenterCamera(),
				// so here we only flag centering and keep the current anchor as a seed.
				centerCamera = true;
				return FlxPoint.get(cameraSystem.camBase.x, cameraSystem.camBase.y);
		}
		return null;
	}

	/** Keeps the camera centered during gameplay by tracking both characters' current midpoints. **/
	function applyGameplayCenterCamera():Void
	{
		var bfMidPos:FlxPoint = boyfriend.getMainCharacter().getMidpoint();
		var p1X = bfMidPos.x + (stage.p1_Cam_Offset != null ? stage.p1_Cam_Offset.x : 0) + boyfriend.getMainCharacter().cameraOffset[0];
		var p1Y = bfMidPos.y + (stage.p1_Cam_Offset != null ? stage.p1_Cam_Offset.y : 0) + boyfriend.getMainCharacter().cameraOffset[1];
		bfMidPos.put();

		var dadMidPos:FlxPoint = dad.getMainCharacter().getMidpoint();
		var p2X = dadMidPos.x + (stage.p2_Cam_Offset != null ? stage.p2_Cam_Offset.x : 0) + dad.getMainCharacter().cameraOffset[0];
		var p2Y = dadMidPos.y + (stage.p2_Cam_Offset != null ? stage.p2_Cam_Offset.y : 0) + dad.getMainCharacter().cameraOffset[1];
		dadMidPos.put();

		cameraSystem.camBase.x = (p1X + p2X) * 0.5;
		cameraSystem.camBase.y = (p1Y + p2Y) * 0.5;
	}
	function endSong():Void {
		call("endSong", []);
		canPause = false;

		FlxG.sound.music.volume = 0;
		vocals.volume = 0;

		if (FlxG.state != instance) return;

		if (SONG.validScore) {

			if (ScoreValidator.isValid(SONG, songScore)) {

				var rank:String = Ratings.getRank(accuracy, misses);
				var stars:Int = Highscore.starsFromAccuracy(accuracy);

				// ALWAYS SAVE LOCALLY! (This fixes Freeplay and Results not showing scores)
				var rateVal = FlxMath.roundDecimal(songMultiplier, 2);
				var diffKey = (rateVal != 1.0) ? storyDifficultyStr + "-r" + rateVal : storyDifficultyStr;
				Highscore.saveScore(SONG.song, songScore, diffKey);
				Highscore.saveRank(SONG.song, rank, diffKey, accuracy);
				Highscore.saveMisses(SONG.song, diffKey, misses);
				Highscore.saveStars(SONG.song, diffKey, stars);
				Highscore.onBeatSong(this);
			} else {
				Main.popupManager.addPopup(new MessagePopup(6, 320, 80, "Score exceeds song maximum", 13));
			}
		}

		if (playCutsceneOnPauseLmao && SONG.endCutscene != null && SONG.endCutscene != "") {
			cutscene = CutsceneUtil.loadFromJson(SONG.endCutscene);
			playCutscene(cutscene, true);
		} else {
			moveToResultsScreen(true);
		}
	}

	function openChartEditor():Void {
		enteringChartEditor = true;
		PlayState.chartingMode = true;
		prepareTransition();
		FlxG.switchState(() -> new ChartingState());
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Chart Editor - " + PlayState.SONG.song, null, null, true);
		#end
	}

	function finishSongStuffs() {
		if (PlayState.practiceMode) {
			PlayState.practiceMode = false;
			prepareTransition();

			FlxG.switchState(new PracticeState());
			return;
		}

		if (chartingMode) {
			openChartEditor();
			return;
		}

		if (isStoryMode) {
			campaignScore += songScore;
			storyPlaylist.remove(storyPlaylist[0]);

			if (storyPlaylist.length <= 0) {
				prepareTransition();

				FlxG.sound.playMusic(Paths.music('freakyMenu'));

				transIn = FlxTransitionableState.defaultTransIn;
				transOut = FlxTransitionableState.defaultTransOut;

				if (PlayState.oneshotMode) {
					PlayState.oneshotMode = false;
					var completedId = PlayState.oneshotId;
					PlayState.oneshotId = "";
					Highscore.onBeatOneshot(completedId);
					FlxG.switchState(() -> new OneShotsState());
				} else {
					FlxG.switchState(() -> new StoryMenuState());
				}

				if (SONG.validScore)
					Highscore.saveWeekScore(campaignScore, storyDifficultyStr, (groupWeek != "" ? groupWeek + "Week" : "week") + Std.string(storyWeek));

				trace('Song beaten: ${PlayState.SONG.song}');
			} else {
				trace('LOADING NEXT SONG: ${PlayState.storyPlaylist[0].toLowerCase()}');
				FlxTransitionableState.skipNextTransIn = true;
				FlxTransitionableState.skipNextTransOut = true;
				savedCam = new FlxPoint(cameraSystem.camBase.x, cameraSystem.camBase.y);

				PlayState.SONG = SongLoader.loadFromJson(storyDifficultyStr, PlayState.storyPlaylist[0]);

				stopAudio();

				switchedStates = true;
				SONG.keyCount = ogKeyCount;
				SONG.playerKeyCount = ogPlayerKeyCount;
				PlayState.loadChartEvents = true;
				LoadingState.loadAndSwitchState(() -> new PlayState());

				if (PlayState.oneshotMode && SONG.validScore) {
					Highscore.onBeatOneshot(PlayState.oneshotId);
					trace('Oneshot song beaten: ${PlayState.SONG.song}');
				}
			}
		} else {
			prepareTransition();
			PlayState.chartingMode = false;
			PlayState.modchartingMode = false;
			FlxG.switchState(() -> new FreeplayState(GroupSelectState.groupID, GroupSelectState.groupSongs));
		}
	}

	var endingSong:Bool = false;

	var rating:FlxSprite = new FlxSprite();
	var ratingTween:VarTween;

	var accuracyText:FlxText = new FlxText(0, 0, 0, "bruh", 24);
	var accuracyTween:VarTween;

	var numbers:Array<FlxSprite> = [];
	var number_Tweens:Array<VarTween> = [];

	var uiMap:Map<String, FlxGraphicAsset> = [];


	function popUpScore(strumtime:Float, noteData:Int, ?setNoteDiff:Float, ?sourceNote:Note = null):Void {
		var noteDiff:Null<Float> = (strumtime - Conductor.songPosition);
		
		if (Options.getData("botplay")) noteDiff = 0;
			noteDiff ??= setNoteDiff;

			replay.recordKeyHit(strumtime, noteDiff);
		if (isResortSkin)
			resortUI.updateScoreText(scoreTxt, songScore, misses, accuracy, ratingStr);

		if (vocals != null) vocals.volume = 1;

		// PsychEngine: noteDiff includes ratingOffset, divided by playbackRate for accuracy
		var adjustedDiff:Float = Math.abs(noteDiff) / songMultiplier;
		var daRating = Ratings.getRating(adjustedDiff);
		var score = Ratings.getScore(daRating);
		var hitNoteAmount = 0.0;

		switch (daRating) {
			case "sick", "marvelous":
				health += 0.035;
				hitNoteAmount = 1;
			case "good":
				health += 0.015;
				hitNoteAmount = 0.8;
			case "bad":
				health += 0.005;
				hitNoteAmount = 0.3;
			case "shit":
				if (Options.getData("antiMash")) health -= 0.075;
				if (Options.getData("missOnShit")) misses++;
				combo = 0;
		}

		hitNotes += hitNoteAmount;
		calculateAccuracy();

		call("popUpScore", [daRating, combo]);
		if (ratings.exists(daRating)) ratings.set(daRating, ratings.get(daRating) + 1);
		if (Options.getData("sideRatings")) updateRatingText();

		if ((daRating == "sick" || daRating == "marvelous") && playerNoteSplashes) {
			playerStrums.forEachAlive(function(spr:StrumNote) {
				if (spr.ID == Math.abs(noteData)) {
					var splash:NoteSplash = splash_group.recycle(NoteSplash);
					splash.setup_splash(noteData, spr, true, sourceNote);
					splash_group.add(splash);
				}
			});
		}

		songScore += score;
		calculateAccuracy();

		if (!Options.getData('ratingsAndCombo')) return;

		// === RATING SPRITE ===
		rating.revive();
		rating.alpha = 1;
		rating.loadGraphic(uiMap.get(daRating));
		rating.screenCenter();

		var initRatingX:Float = rating.x -= (Options.getData("middlescroll") ? 350 : (Options.getData("playAs") == 0 ? 0 : -150));
		var initRatingY:Float = rating.y -= 60;
		rating.x += Options.getData("ratingsOffset")[0];
		rating.y += Options.getData("ratingsOffset")[1];
		rating.velocity.y = FlxG.random.int(30, 60);
		rating.velocity.x = FlxG.random.int(-10, 10);

		rating.setGraphicSize(rating.width * Std.parseFloat(ui_settings[0]) * Std.parseFloat(ui_settings[4]));
		rating.antialiasing = ui_settings[3] == "true" && Options.getData("antialiasing");
		rating.updateHitbox();
		ratingsGroup.add(rating);
		if (ratingTween != null) ratingTween.cancel();
		rating.alpha = 1;
		ratingTween = FlxTween.tween(rating, {alpha: 0}, 0.2, {startDelay: Conductor.crochet * 0.001, onComplete: _ -> {
			if (rating != null && ratingsGroup.members.contains(rating)) {
				ratingsGroup.remove(rating);
				rating.kill();
			}
		}});

		if (Options.getData("displayMs")) {
			var noteMath = -FlxMath.roundDecimal(noteDiff, 2);
			if (Math.abs(noteMath) == 0) noteMath = 0;

			accuracyText.revive();
			accuracyText.text = noteMath + " ms" + (Options.getData("botplay") ? " (BOT)" : "");
			accuracyText.setPosition(initRatingX + Options.getData("accuracyTextOffset")[0], initRatingY + 100 + Options.getData("accuracyTextOffset")[1]);
			accuracyText.color = (noteMath >= 0) ? FlxColor.ORANGE : FlxColor.CYAN;
			accuracyText.borderStyle = FlxTextBorderStyle.OUTLINE_FAST;
			accuracyText.borderSize = 1;
			accuracyText.font = Paths.font("vcr.ttf");
			accuracyText.antialiasing = ui_settings[3] == "true" && Options.getData("antialiasing");
			ratingsGroup.add(accuracyText);

			if (accuracyTween != null) accuracyTween.cancel();
			accuracyText.alpha = 1;
			accuracyTween = FlxTween.tween(accuracyText, {alpha: 0}, 0.2, {startDelay: Conductor.crochet * 0.001, onComplete: _ -> {
				if (accuracyText != null && ratingsGroup.members.contains(accuracyText)) {
					ratingsGroup.remove(accuracyText);
					accuracyText.kill();
				}
			}});
		}

		// === COMBO NUMBERS ===
		if (!isResortSkin) {
			var digits = Std.string(combo).split("");
			for (i in 0...digits.length) {
				if (numbers.length <= i) numbers.push(new FlxSprite());
				var numScore = numbers[i];
				numScore.revive();
				numScore.alpha = 1;

				numScore.loadGraphic(uiMap.get(digits[i]));
				numScore.screenCenter();
				numScore.x -= (Options.getData("middlescroll") ? 350 : (characterPlayingAs == BF ? 0 : -150));
				numScore.x += (43 * i) - 90 + Options.getData("comboOffset")[0];
				numScore.y += 80 + Options.getData("comboOffset")[1];
				numScore.setGraphicSize(numScore.width * Std.parseFloat(ui_settings[1]));
				numScore.updateHitbox();
				numScore.antialiasing = ui_settings[3] == "true" && Options.getData("antialiasing");
				numScore.velocity.y = FlxG.random.int(30, 60);
				numScore.velocity.x = FlxG.random.float(-5, 5);
				ratingsGroup.add(numScore);

				// === FADE OUT ===
				if (number_Tweens[i] != null) number_Tweens[i].cancel();
				numScore.alpha = 1;
				var numIdx = i;
				number_Tweens[i] = FlxTween.tween(numScore, {alpha: 0}, 0.2, {startDelay: Conductor.crochet * 0.002, onComplete: _ -> {
					if (numScore != null && ratingsGroup.members.contains(numScore)) {
						ratingsGroup.remove(numScore);
						numScore.kill();
					}
				}});

			}
		}
	}

	function updateScoreText() {
		if (hud != null)
			hud.updateScore(songScore, misses, accuracy, ratingStr);
	}


	function toggleBotplay() {
		Options.setData(!Options.getData("botplay"), "botplay");
		set("bot", Options.getData("botplay"));
		SONG.validScore = false;
		botUsed = true;
		updateSongInfoText();
	}
var justPressedArray:Array<Bool> = [];
var releasedArray:Array<Bool> = [];
var justReleasedArray:Array<Bool> = [];
var heldArray:Array<Bool> = [];

inline function stopAudio() {
	if (vocals != null) {
		for (i in 0...vocals.members.length) {
			var snd = vocals.members[i];
			if (snd != null) {
				FlxG.sound.list.remove(snd);
				snd.persist = false;
			}
		}
		vocals.stop();
		vocals.destroy();
		vocals = null;
	}
	if (FlxG.sound.music != null) {
		FlxG.sound.list.remove(FlxG.sound.music);
		FlxG.sound.music.persist = false;
		FlxG.sound.music.stop();
		FlxG.sound.music.destroy();
		FlxG.sound.music = null;
	}
}

inline function prepareTransition() {
	switchedStates = true;
	stopAudio();
	SONG.keyCount = ogKeyCount;
	SONG.playerKeyCount = ogPlayerKeyCount;
}

inline function alignNoteToStrum(note:Note, coolStrum:StrumNote) {
	note.visible = coolStrum.visible;
	var centerOffset:Float = (coolStrum.width - note.width) * 0.5;
	note.x = coolStrum.x + centerOffset - note.xOffset;
	var alignMap = note.mustPress ? prevPlayerXVals : prevEnemyXVals;
	if (!alignMap.exists(note.alignmentKey))
		alignMap.set(note.alignmentKey, centerOffset);

	if (coolStrum.alpha != 1)
		note.alpha = note.isSustainNote ? 0.6 * coolStrum.alpha : coolStrum.alpha;
	else
		note.alpha = note.isSustainNote ? 0.6 : 1.0;

	if (!note.isSustainNote) {
		note.modAngle = coolStrum.angle;
		note.flipY = coolStrum.flipY;
	}
	note.flipX = coolStrum.flipX;
	note.color = coolStrum.color;
}

	inline function copyColorSwap(target:Dynamic, source:Note) {
		if (source != null && target != null && target.colorSwap != null) {
			var strum:StrumNote = Std.isOfType(target, StrumNote) ? cast target : null;
			var globalAffected:Bool = strum != null ? (strum.defaultAffectedByColor || strum.affectedbycolor) : (target.affectedbycolor == true);

			if (globalAffected) {
				var col:Array<Float> = (source.customNoteColor != null) ? source.customNoteColor : (source.noteColor != null ? source.noteColor : (source.colorSwap != null ? [source.colorSwap.r, source.colorSwap.g, source.colorSwap.b] : null));
				if (col != null) {
					target.colorSwap.r = col[0];
					target.colorSwap.g = col[1];
					target.colorSwap.b = col[2];
					target.shader = target.colorSwap.shader;
					if (strum != null) strum.affectedbycolor = true;
				}
			} else {
				target.colorSwap.r = 255;
				target.colorSwap.g = 0;
				target.colorSwap.b = 0;
				target.shader = null;
				if (strum != null) strum.affectedbycolor = false;
			}
		}
	}

inline function swapCharacterEvent(oldChar:Character, newChar:Character, ?onSwap:Void->Void):Character {
	oldChar.alpha = 0.00001;
	if (oldChar.otherCharacters != null)
		for (c in oldChar.otherCharacters) c.alpha = 0.00001;

	newChar.x = oldChar.x - oldChar.positioningOffset[0] + newChar.positioningOffset[0];
	newChar.y = oldChar.y - oldChar.positioningOffset[1] + newChar.positioningOffset[1];
	newChar.cameras = oldChar.cameras;
	newChar.alpha = 1;

	if (newChar.otherCharacters != null) {
		for (c in newChar.otherCharacters) {
			c.x = oldChar.x - oldChar.positioningOffset[0] + c.positioningOffset[0];
			c.y = oldChar.y - oldChar.positioningOffset[1] + c.positioningOffset[1];
			c.cameras = oldChar.cameras;
			c.alpha = 1;
		}
	}

	if (onSwap != null) onSwap();
	newChar.dance();
	return newChar;
}

inline function updateDiscordPresence(details:String, state:String, ?showTime:Bool = false, ?timeLeft:Float = 0) {
	#if DISCORD_ALLOWED
	if (timeLeft < 1) timeLeft = 1;
	DiscordClient.changePresence(details, state, rpcData.curPortrait, showTime, timeLeft, rpcData.image);
	#end
}

inline function resetHoldTimer(note:Note) {
	var targetChar:Character = (characterPlayingAs == BF) ? boyfriend : dad;
	if (targetChar.otherCharacters == null || targetChar.otherCharacters.length - 1 < note.character)
		targetChar.holdTimer = 0;
	else if (note.characters.length <= 1)
		targetChar.otherCharacters[note.character].holdTimer = 0;
	else
		for (c in note.characters)
			if (targetChar.otherCharacters.length - 1 >= c)
				targetChar.otherCharacters[c].holdTimer = 0;
}

inline function handleIdleDance() {
	var targetChar:Character = (characterPlayingAs == BF) ? boyfriend : dad;
	var holding = heldArray.contains(true);
	targetChar.isHoldingNote = holding;
	if (holding && targetChar.lastAnimContext != "dance")
		targetChar.__lockAnimThisFrame = true;

	if (targetChar.otherCharacters != null) {
		for (c in targetChar.otherCharacters) {
			c.isHoldingNote = holding;
			if (holding && c.lastAnimContext != "dance")
				c.__lockAnimThisFrame = true;
		}
	}
}
function keyShit() {
	if (!generatedMusic || !startedCountdown) return;

	var isBot:Bool = Options.getData("botplay");
	if (!isBot) {
		var keyCount:Int = SONG.playerKeyCount;
		var is4k:Bool = (keyCount == 4);
		var bindsLen:Int = binds.length;

		if (justPressedArray.length != bindsLen) {
			justPressedArray.resize(bindsLen);
			heldArray.resize(bindsLen);
			justReleasedArray.resize(bindsLen);
			releasedArray.resize(bindsLen);
		}

		var hasPressed:Bool = false;
		var hasHeld:Bool = false;

		for (i in 0...bindsLen) {
			var k:FlxKey = (i < cachedFlxKeys.length) ? cachedFlxKeys[i] : FlxKey.NONE;
			var arrow:FlxKey = is4k ? ARROW_KEYS[i] : FlxKey.NONE;

			var jp:Bool = FlxG.keys.checkStatus(k, JUST_PRESSED) || (is4k && FlxG.keys.checkStatus(arrow, JUST_PRESSED));
			var hd:Bool = FlxG.keys.checkStatus(k, PRESSED) || (is4k && FlxG.keys.checkStatus(arrow, PRESSED));
			var jr:Bool = FlxG.keys.checkStatus(k, JUST_RELEASED) || (is4k && FlxG.keys.checkStatus(arrow, JUST_RELEASED));

			justPressedArray[i] = jp;
			heldArray[i] = hd;
			justReleasedArray[i] = jr;
			releasedArray[i] = !hd;

			if (jp) {
				hasPressed = true;
				call("keyPressed", [i]);
			}
			if (!hd) call("keyReleased", [i]);
			if (hd) hasHeld = true;
		}

		var inputMode:String = Options.getData("inputSystem");

		if (hasPressed) {
			var possibleNotes:Array<Note> = [];
			var dontHit:Array<Note> = [];

			// PsychEngine: more accurate hit time for ratings
			var lastTime:Float = Conductor.songPosition;
			if (Conductor.songPosition >= 0) Conductor.songPosition = FlxG.sound.music.time + Conductor.offset;

			notes.forEachAlive(function(note:Note) {
				note.calculateCanBeHit();
				if (note.canBeHit && note.mustPress && !note.tooLate && !note.wasGoodHit && !note.isSustainNote)
					possibleNotes.push(note);
			});

			if (inputMode == "cne") {
				possibleNotes.sort((a, b) -> {
					var distA:Float = Math.abs(a.strumTime - Conductor.songPosition);
					var distB:Float = Math.abs(b.strumTime - Conductor.songPosition);
					return (distA > distB) ? 1 : ((distA < distB) ? -1 : 0);
				});
			} else if (inputMode == "rhythm") {
				possibleNotes.sort((b, a) -> Std.int(Conductor.songPosition - a.strumTime));
			} else if (inputMode == "psych") {
				possibleNotes.sort((a, b) -> {
					if (a.lowPriority && !b.lowPriority) return 1;
					else if (!a.lowPriority && b.lowPriority) return -1;
					return (a.strumTime > b.strumTime) ? 1 : ((a.strumTime < b.strumTime) ? -1 : 0);
				});
			} else {
				possibleNotes.sort((a, b) -> Std.int(a.strumTime - b.strumTime));
			}

			if (inputMode == "rhythm") {
				var cool:Note = null;
				for (n in possibleNotes) {
					if (cool != null) {
						if (n.strumTime > cool.strumTime && n.shouldHit)
							dontHit.push(n);
					} else if (n.shouldHit) {
						cool = n;
					}
				}
			}

			if (noteDataPossibles.length < keyCount)
				noteDataPossibles.resize(keyCount);
			if (rythmArray.length < keyCount)
				rythmArray.resize(keyCount);

			for (i in 0...keyCount) {
				noteDataPossibles[i] = false;
				rythmArray[i] = false;
			}

			if (possibleNotes.length > 0) {
				for (i in 0...keyCount) {
					if (justPressedArray[i] && !noteDataPossibles[i]) {
						var n:Note = null;
						var secondNote:Note = null;
						for (cand in possibleNotes) {
							if (cand.noteData == i) {
								if (n == null) {
									n = cand;
									if (inputMode != "psych") break;
								} else {
									secondNote = cand;
									break;
								}
							}
						}

					if (n != null) {
						if (inputMode == "psych" && secondNote != null) {
							if (Math.abs(secondNote.strumTime - n.strumTime) < 1.0) {
								secondNote.kill();
								notes.remove(secondNote, true);
								secondNote.destroy();
								possibleNotes.remove(secondNote);
							}
						}

						resetHoldTimer(n);

						if (inputMode == "rhythm" && dontHit.contains(n)) {
							noteMiss(i, n);
							rythmArray[i] = true;
						} else {
							noteDataPossibles[i] = true;
							goodNoteHit(n);
						}
					}
				}
			}
			}

			var ghostTapping:Bool = Options.getData("ghostTapping");
			if (!ghostTapping) {
				for (i in 0...keyCount) {
					if (justPressedArray[i] && !noteDataPossibles[i] && !rythmArray[i])
						noteMiss(i);
				}
			} else if (Options.getData("animGhostTapping")) {
				var singDirs = (NoteVariables.maniaDirections != null && keyCount <= NoteVariables.maniaDirections.length)
					? NoteVariables.maniaDirections[keyCount - 1]
					: null;

				var targetChar:Character = (characterPlayingAs == BF) ? boyfriend : dad;
				for (i in 0...keyCount) {
					if (justPressedArray[i] && !noteDataPossibles[i] && !rythmArray[i]) {
						if (playerStrums.members.length > i && playerStrums.members[i] != null) {
							playerStrums.members[i].playAnim("pressed");
							playerStrums.members[i].resetAnim = 0;
						}

						if (targetChar != null && singDirs != null && i < singDirs.length) {
							var animName = "sing" + singDirs[i];
							if (targetChar.animation.curAnim != null && targetChar.animation.curAnim.name == animName)
								targetChar.animation.curAnim.curFrame = 0;
							else
								targetChar.playAnim(animName, true);

							targetChar.holdTimer = 0;
						}
					}
				}
			}

			// PsychEngine: restore song position after accurate hit calculation
			Conductor.songPosition = lastTime;
		}

		if (hasHeld) {
			var maxHoldTime:Float = Conductor.songPosition + spawnTimeAhead;
			var hIdx:Int = 0;
			while (hIdx < notes.members.length) {
				var note:Note = notes.members[hIdx];
				if (note == null || !note.exists || !note.alive) {
					hIdx++;
					continue;
				}
				if (note.strumTime > maxHoldTime) break;
				note.calculateCanBeHit();
				var lane:Int = note.noteData;
				if (lane >= 0 && lane < keyCount && heldArray[lane] && note.isSustainNote && note.mustPress && note.canBeHit) {
					var parent:Note = note.getParentNote();
					var parentHit:Bool = (parent == null || parent.wasGoodHit);

				if (inputMode == "cne" || inputMode == "psych" || inputMode == "standard") {
					// PsychEngine/CodenameEngine behavior: sustain can only be hit after
					// its strumTime has passed AND parent head note was already hit
					if (note.strumTime <= Conductor.songPosition && parentHit) {
						resetHoldTimer(note);
						goodNoteHit(note);
					}
				} else {
					// Fallback: original behavior (no parent check)
					resetHoldTimer(note);
					goodNoteHit(note);
				}
			}
			if (hIdx < notes.members.length && notes.members[hIdx] == note)
				hIdx++;
		}
	}

		// Handle premature key releases during sustain notes for Psych and CNE (O(N) single pass)
		if (inputMode == "psych" || inputMode == "cne") {
			notes.forEachAlive(function(note:Note) {
				if (note.mustPress && note.isSustainNote && !note.wasGoodHit && note.canBeHit) {
					var lane:Int = note.noteData;
					if (lane >= 0 && lane < keyCount && !heldArray[lane]) {
						var parent:Note = note.getParentNote();
						if (parent != null && parent.wasGoodHit) {
							noteMiss(lane, note);
							note.tooLate = true;
							note.kill();
						}
					}
				}
			});
		}

		handleIdleDance();

		for (spr in playerStrums.members) {
			if (spr == null || !spr.exists) continue;
			var id:Int = spr.ID;
			if (id < 0 || id >= bindsLen) continue;

			if (justPressedArray[id] && (spr.animation.curAnim == null || spr.animation.curAnim.name != "confirm")) {
				spr.playAnim("pressed");
				spr.resetAnim = 0;
			}
			// PsychEngine behavior: strum always goes to "static" on key release
			if (releasedArray[id] || (!heldArray[id] && spr.animation.curAnim != null && (spr.animation.curAnim.name == "confirm" || spr.animation.curAnim.name == "pressed"))) {
				spr.playAnim("static");
				spr.resetAnim = 0;
			}
		}
	} else {
		var maxBotTime:Float = Conductor.songPosition + spawnTimeAhead;
		var bIdx:Int = 0;
		while (bIdx < notes.members.length) {
			var note:Note = notes.members[bIdx];
			if (note != null && note.strumTime > maxBotTime) break;
			if (note != null && note.exists && note.alive && note.shouldHit && note.mustPress && note.strumTime <= Conductor.songPosition) {
				resetHoldTimer(note);
				goodNoteHit(note);
			}
			if (bIdx < notes.members.length && notes.members[bIdx] == note)
				bIdx++;
		}

		for (spr in playerStrums.members) {
			if (spr != null && spr.exists && spr.animation.finished)
				spr.playAnim("static");
		}

		handleIdleDance();
	}
}



	function noteMiss(direction:Int = 1, ?note:Note):Void {
		if (note != null && Options.getData("inputSystem") == "psych") {
			var daNote = note;
			notes.forEachAlive(function(n:Note) {
				if (daNote != n && daNote.mustPress && daNote.noteData == n.noteData && daNote.isSustainNote == n.isSustainNote && Math.abs(daNote.strumTime - n.strumTime) < 1.0) {
					n.kill();
					notes.remove(n, true);
					n.destroy();
				}
			});
		}

		var canMiss = false;

		if (note == null)
			canMiss = true;
		else {
			if (note.mustPress)
				canMiss = true;
		}

			if (isResortSkin) {

			resortUI.noteMiss(playerStrums);
		}

		if (canMiss && !invincible && !Options.getData("botplay")) {
			if (note != null) {
				if (!note.isSustainNote)
					health -= note.missDamage;
				else
					health -= note.heldMissDamage;
			} else
				health -= Std.parseFloat(type_Configs.get("default")[2]);

			if (combo > 5 && gf.animOffsets.exists('sad'))
				gf.playAnim('sad');

			combo = 0;

			var missValues = false;

			if (note != null) {
				if (!note.isSustainNote || (Options.getData("missOnHeldNotes") && !note.missesSustains))
					missValues = true;
			} else
				missValues = true;

			if (missValues) {
				if (note != null) {
					if (Options.getData("missOnHeldNotes") && !note.missesSustains) {
						note.missesSustains = true;

						for (sustain in note.sustains) {
							if (sustain != null)
								sustain.missesSustains = true;
						}
					}
				}

				misses++;

				if (Options.getData("sideRatings"))
					updateRatingText();

				updateScoreText();
			}

			totalNotes++;

			missSounds[FlxG.random.int(0, missSounds.length - 1)].play(true);

			songScore -= 10;

			if (characterPlayingAs == BF) {
				playAnimOnNote(boyfriend, note, NoteVariables.characterAnimations[getCorrectKeyCount(true) - 1][direction] + "miss");
			} else {
				playAnimOnNote(dad, note, NoteVariables.characterAnimations[getCorrectKeyCount(true) - 1][direction] + "miss");
			}

			calculateAccuracy();

			call("playerOneMiss", [
				direction,
				Conductor.songPosition,
				(note != null ? note.arrow_Type : "default"),
				(note != null ? note.isSustainNote : false)
			]);

			set("misses", misses);
		}
	}

	var hitsound:FlxSound;

	function goodNoteHit(note:Note, ?setNoteDiff:Float):Void {
		#if HSCRIPT_ALLOWED
		for (script in scripts) {
			if (script is HScript) {
				script.call("goodNoteHit", [note, setNoteDiff]);
			}
		}
		#end
		if (isResortSkin) {
			resortUI.noteHit(note, combo, playerStrums);
		}
		if (!note.wasGoodHit) {
			if (note.shouldHit && note.isSustainNote)
				health += 0.02;

			if (!note.isSustainNote) {
				totalNotes++;
				noteTimes.push(Conductor.songPosition);
			}

			var lua_Data:Array<Dynamic> = [
				note.noteData,
				Conductor.songPosition,
				note.arrow_Type,
				note.strumTime,
				note.character
			];

			var singAnim:String = NoteVariables.characterAnimations[getCorrectKeyCount(true) - 1][Std.int(Math.abs(note.noteData % getCorrectKeyCount(true)))]
				+ (characterPlayingAs == OPPONENT ? altAnim : "")
				+ note.singAnimSuffix;
			if (note.singAnimPrefix != 'sing') {
				singAnim = singAnim.replace('sing', note.singAnimPrefix);
			}
			var noteIdx:Int = -1;
			if (characterPlayingAs == BF) {
				playAnimOnNote(boyfriend, note, singAnim);

				if (note.isSustainNote) {
					call("playerOneSingHeld", lua_Data);
				} else {
					call("playerOneSing", lua_Data);
				}
				noteIdx = notes.members.indexOf(note);
				call('playerOneSingExtra', [
					Math.abs(note.noteData),
					noteIdx,
					note.arrow_Type,
					note.isSustainNote
				]);
			} else {
				playAnimOnNote(dad, note, singAnim);

				if (note.isSustainNote) {
					call("playerTwoSingHeld", lua_Data);
				} else {
					call("playerTwoSing", lua_Data);
				}
			}

			if (startedCountdown) {
				playerStrums.forEach(function(spr:StrumNote) {
					if (Math.abs(note.noteData) == spr.ID) {
						spr.playAnim('confirm', true);
						copyColorSwap(spr, note);
					}
				});
			}

			if (note.shouldHit && !note.isSustainNote) {
				combo++;
				maxCombo = Std.int(Math.max(maxCombo, combo));
				popUpScore(note.strumTime, note.noteData % getCorrectKeyCount(true), setNoteDiff, note);

				if (hitSoundString != "none") {
					hitsound.play(true);
				}
			} else if (!note.shouldHit) {
				health -= note.hitDamage;
				misses++;
				missSounds[FlxG.random.int(0, missSounds.length - 1)].play(true);
			}

			note.wasGoodHit = true;
			vocals.volume = 1;

			if (!note.isSustainNote) {
				invalidateNote(note, noteIdx);
			}
		}
		call("goodNoteHitPost", [
			note.noteData,
			Conductor.songPosition,
			note.arrow_Type,
			note.strumTime,
			note.character,
			note.mustPress
		]);
	}

	override function stepHit() {
		super.stepHit();

		var gamerValue = 20 * songMultiplier;

		if (FlxG.sound.music != null && FlxG.sound.music.playing && FlxG.sound.music.time > 0)
		{
			if (FlxG.sound.music.time > Conductor.songPosition + gamerValue
				|| FlxG.sound.music.time < Conductor.songPosition - gamerValue
				|| FlxG.sound.music.time < 500
				&& (FlxG.sound.music.time > Conductor.songPosition + 5 || FlxG.sound.music.time < Conductor.songPosition - 5))
				resyncVocals();
		}

		set("curStep", curStep);
		_ONE_ARG[0] = curStep;
		call("stepHit", _ONE_ARG);
	}

	function danceCharacter(char:Character) {
		if (!char.isCharacterGroup) {
			if (char.lastAnimContext == "sing" || char.lastAnimContext == "miss")
				return;
			char.dance(altAnim);
		} else {
			for (character in char.otherCharacters) {
				danceCharacter(character);
			}
		}
	}

	override function beatHit() {
		super.beatHit();

		// NoteGroup.draw() renders sustains before head notes in DESCENDING strumTime order,
		// so per-beat FlxSort.byY is unnecessary.

		// Sections no longer have to be exactly `stepsPerSection` steps long
		// (charts with mid section tempo changes get shorter/longer ones), so the
		// active section is resolved through the Conductor timeline instead of
		// dividing the step counter.
		var activeSection:Int = Conductor.getSectionAtTime(Conductor.songPosition);
		if (activeSection < 0) activeSection = 0;

		if (SONG.notes[activeSection] != null) {
			var prevSection:Int = Conductor.getSectionAtTime(Conductor.songPosition - Conductor.stepCrochet);
			var sectionChanged:Bool = activeSection != prevSection;

			if (timeBarStyle == 'leather engine'
				&& sectionChanged
				&& SONG.chartType != VSLICE) {
				var target:FlxColor = SONG.notes[activeSection].mustHitSection ? boyfriend.barColor : dad.barColor;
				FlxTween.color(timeBar.bar, Conductor.crochet * 0.002, timeBar.bar.color, target);
			}

			if (healthBarStyleData != null
				&& healthBarStyleData.style == "by type"
				&& sectionChanged
				&& SONG.chartType != VSLICE) {
				var target:FlxColor = SONG.notes[activeSection].mustHitSection ? boyfriend.barColor : dad.barColor;
				healthBarStyleData.curR = target.redFloat;
				healthBarStyleData.curG = target.greenFloat;
				healthBarStyleData.curB = target.blueFloat;
			}
		}

		// Dad doesnt interupt his own notes
		if (characterPlayingAs == BF) {
			danceCharacter(dad);
		} else {
			danceCharacter(boyfriend);
		}
		if (camZooming
			&& FlxG.camera.zoom < (1.35 * FlxCamera.defaultZoom)
			&& cameraZoomRate > 0
			&& curBeat % ((Conductor.timeScale[0]) / cameraZoomRate) == 0) {
			FlxG.camera.zoom += 0.015 * cameraZoomStrength;
			camHUD.zoom += 0.03 * cameraZoomStrength;
		}

		if (hud != null) {
			hud.bopIcons();
			hud.updateIcons(0, dad, boyfriend, songMultiplier);
		}


		if (gfSpeed < 1)
			gfSpeed = 1;

		if (curBeat % gfSpeed == 0 && !dad.curCharacter.startsWith('gf')) {
			danceCharacter(gf);
		}

		if (dad.animation.curAnim != null) {
			if (!dad.animation.curAnim.name.startsWith("sing") && curBeat % gfSpeed == 0 && dad.curCharacter.startsWith('gf')) {
				danceCharacter(dad);
			}
		}

		if (characterPlayingAs == BF) {
			danceCharacter(boyfriend);
		} else {
			danceCharacter(dad);
		}

		stage.beatHit();

		_ONE_ARG[0] = curBeat;
		call("beatHit", _ONE_ARG);
	}

	function updateRatingText() {
		if (Options.getData("sideRatings")) {
			ratingText.text = getRatingText();
			ratingText.screenCenter(Y);
			ratingText.y += Options.getData("ratingTextOffset")[1];
			if (isResortSkin) {
				ratingText.setFormat(Paths.font("freeplaytext.ttf"), 20, FlxColor.WHITE, LEFT);
				ratingText.setBorderStyle(OUTLINE, FlxColor.BLACK, 2);
			}
		}
	}

	/**
		 * Move to the results screen right goddamn now.
		 * @param pause Should the game pause?
		 */
	function moveToResultsScreen(pause:Bool = false):Void {
		call("onResults", [pause]);
		if (pause) {
			persistentUpdate = false;
			persistentDraw = true;
			paused = true;
		}
		vocals?.stop();

		var res:ResultsSubstate = new ResultsSubstate(replay);
		openSubState(res);
	}
	function getRatingText():String {
		var ratingArray:Array<Int> = [
			ratings.get("marvelous"),
			ratings.get("sick"),
			ratings.get("good"),
			ratings.get("bad"),
			ratings.get("shit")
		];

		var MA:Int = ratingArray[1] + ratingArray[2] + ratingArray[3] + ratingArray[4];
		var PA:Int = MA - ratingArray[1];

var currentNps:String = Std.string(nps);
var peakNps:String = Std.string(npsPeak);

		function buildText(names:Array<String>):String {
			return ((marvelousRatings ? names[0] + ": " + Std.string(ratingArray[0]) + "\n" : "")
				+ names[1] + ": " + Std.string(ratingArray[1]) + "\n"
				+ names[2] + ": " + Std.string(ratingArray[2]) + "\n"
				+ names[3] + ": " + Std.string(ratingArray[3]) + "\n"
				+ names[4] + ": " + Std.string(ratingArray[4]) + "\n"
				+ "Misses: " + Std.string(misses) + "\n"
				+ (marvelousRatings && ratingArray[0] > 0 && MA > 0
					? "MA: " + Std.string(FlxMath.roundDecimal(ratingArray[0] / MA, 2)) + "\n"
					: "")
				+ (ratingArray[1] > 0 && PA > 0
					? "PA: " + Std.string(FlxMath.roundDecimal((ratingArray[1] + ratingArray[0]) / PA, 2)) + "\n"
					: "")
				// Mostramos NPS / NPS Peak
				+ "NPS: " + currentNps + " / " + peakNps + "\n"
			);
		}

		switch (SONG.ui_Skin) {
			case "voiid":
				return buildText(["Krazy", "Sick", "Good", "Guh", "Mid"]);
			case "Resort":
				return buildText(["Marvelous", "Sick", "Good", "Okey", "Bad"]);
			case "Corrupted":
				return buildText(["Marvelous", "Sick", "Good", "Okey", "Bad"]);
			case "scalable cel":
				return buildText(["Marvelous", "Perfect", "Great", "Good", "Bad"]);
			default:
				return buildText(["Glorious", "Great", "Nice", "Auful", "Rusty"]);
		}
	}



	static function getCharFromEvent(eventVal:String):Character {
		switch (eventVal.toLowerCase()) {
			case "girlfriend" | "gf" | "player3" | "2":
				return gf.getMainCharacter();
			case "dad" | "opponent" | "player2" | "1":
				return dad.getMainCharacter();
		}

		return boyfriend.getMainCharacter();
	}

	function removeCharacter(char:Character) {
		if (!char.isCharacterGroup) {
			if (char.coolTrail != null)
				remove(char.coolTrail);

			remove(char);
		} else {
			for (character in char.otherCharacters) {
				removeCharacter(character);
			}
		}
	}

	function removeBgStuff() {
		remove(stage);
		remove(stage.foregroundSprites);
		remove(stage.infrontOfGFSprites);

		removeCharacter(gf);
		removeCharacter(dad);
		removeCharacter(boyfriend);
	}

	function addCharacter(char:Character, removeOld:Bool = true) {
		if (char.otherCharacters == null) {
			if (char.coolTrail != null) {
				if (removeOld) {
					remove(char.coolTrail);
				}
				add(char.coolTrail);
			}

			if (removeOld) {
				remove(char);
			}
			add(char);
		} else {
			for (character in char.otherCharacters) {
				if (character.coolTrail != null) {
					if (removeOld) {
						remove(character.coolTrail);
					}
					add(character.coolTrail);
				}

				if (removeOld) {
					remove(character);
				}
				add(character);
			}
		}
	}

	function addBgStuff() {
		stage.setCharOffsets();

		add(stage);

		if (dad.curCharacter.startsWith("gf")) {
			dad.setPosition(gf.x, gf.y);
			gf.visible = false;
		} else if (!gf.visible && gf.curCharacter != "") {
			gf.visible = true;
		}

		addCharacter(gf, true);

		if (!dad.curCharacter.startsWith("gf"))
			add(stage.infrontOfGFSprites);

		addCharacter(dad, true);

		if (dad.curCharacter.startsWith("gf"))
			add(stage.infrontOfGFSprites);

		addCharacter(boyfriend, true);

		add(stage.foregroundSprites);
			}

	function cacheEventCharacter(event:Array<Dynamic>) {
		removeBgStuff();

		if (gfMap.exists(event[3]) || bfMap.exists(event[3]) || dadMap.exists(event[3])) // prevent game crash
		{
			switch (event[2].toLowerCase()) {
				case "girlfriend" | "gf" | "2":
					gf = swapCharacterEvent(gf, gfMap.get(event[3]));
					setupLuaScripts();
				case "dad" | "opponent" | "1":
					dad = swapCharacterEvent(dad, dadMap.get(event[3]), function() {
						lastTurn = "";
					});
					#if CAMERA_TOOLS
					if (cameraEventHandler != null) cameraEventHandler.dad = dad;
					#end
					refreshIcons(dad, false);
					setupLuaScripts();
					applyHealthBarStyle();
				case "bf" | "boyfriend" | "player" | "0":
					boyfriend = cast swapCharacterEvent(boyfriend, bfMap.get(event[3]), function() {
						lastTurn = "";
					});
					#if CAMERA_TOOLS
					if (cameraEventHandler != null) cameraEventHandler.boyfriend = boyfriend;
					#end
					refreshIcons(boyfriend, true);
					setupLuaScripts();
					applyHealthBarStyle();
			}
		} else
			CoolUtil.coolError("The character " + event[3] + " isn't in any character cache!\nHow did this happen?",
				"Leather Engine's No Crash, We Help Fix Stuff Tool");

		addBgStuff();
	}

	function updateSongInfoText() {
		if (hud == null) return;
		var songThingy:Float = (FlxG.sound.music != null) ? (songLength - FlxG.sound.music.time) : songLength;
		var seconds:Int = Math.floor(songThingy / 1000);
		seconds = Std.int(seconds / songMultiplier);
		if (seconds < 0) seconds = 0;
		hud.updateTime(seconds, SONG.song, storyDifficultyStr, timeBarStyle, diedInNoDeath);
	}

	inline function set(name:String, data:Any, ?executeOn:ExecuteOn = BOTH) {
		if (scripts == null) return;
		for (script in scripts) {
			if (script.executeOn == executeOn || executeOn == BOTH) {
				script.set(name, data);
			}
		}
	}

	override function call(func:String, ?args:Array<Any>, executeOn:ExecuteOn = BOTH) {
		super.call(func, args);
		if (scripts == null) return;
		for (key => script in scripts) {
			if ((script.executeOn == executeOn || executeOn == BOTH)) {
				script.call(func, args);
			}
		}
	}

	inline function setupLuaScripts() {
		_luaConductor.bpmChangeMap = Conductor.bpmChangeMap;
		_luaConductor.timeScaleChangeMap = Conductor.timeScaleChangeMap;
		#if LUA_ALLOWED
		{

		for (script in scripts) {
			if (script is LuaScript)
				script.setup();
		}

		for (i in 0...strumLineNotes.length) {
			var member = strumLineNotes.members[i];

			set("defaultStrum" + i + "X", member.x);
			set("defaultStrum" + i + "Y", member.y);
			set("defaultStrum" + i + "Angle", member.angle);

			set("defaultStrum" + i, {
				x: member.x,
				y: member.y,
				angle: member.angle,
			});

			if (enemyStrums.members.contains(member)) {
				set("enemyStrum" + i % SONG.keyCount, {
					x: member.x,
					y: member.y,
					angle: member.angle,
				});
			} else {
				set("playerStrum" + i % SONG.playerKeyCount, {
					x: member.x,
					y: member.y,
					angle: member.angle,
				});
			}
		}}
		#end
	}
	function getLuaVar(name:String, type:String):Any {
		#if LUA_ALLOWED
		var luaVar:Any = null;

		for (script in scripts) {
			if (script is LuaScript) {
				var newLuaVar = cast(script, LuaScript).getVar(name, type);

				if (newLuaVar != null)
					luaVar = newLuaVar;
			}
		}

		if (luaVar != null)
			return luaVar;
		#end

		return null;
	}


	function closeScripts() {
		#if LUA_ALLOWED
		for (script in scripts)
		{
			script?.destroy();
		}
		
		if (LuaScript.lua_Sounds != null) {
			for (sound in LuaScript.lua_Sounds) {
				sound?.stop();
				sound?.kill();
				sound?.destroy();
			}
			for (key => sound in LuaScript.lua_Sounds) {
				if (sound != null && key != "Inst" && key != "Voices" && key.indexOf("Voices") != 0) {
					sound.stop();
					FlxG.sound.list.remove(sound);
					sound.destroy();
				}
			}
			LuaScript.lua_Sounds.clear();
		}
		LuaScript.killShaders();
		if (LuaScript.lua_Characters != null) LuaScript.lua_Characters.clear();
		if (LuaScript.lua_Sprites != null) {
			for (key => sprite in LuaScript.lua_Sprites) {
				if (sprite != null && key != "boyfriend" && key != "girlfriend" && key != "dad") {
					sprite.destroy();
				}
			}
			LuaScript.lua_Sprites.clear();
		}
		if (LuaScript.lua_Shaders != null) LuaScript.lua_Shaders.clear();
		if (LuaScript.lua_Custom_Shaders != null) LuaScript.lua_Custom_Shaders.clear();
		if (LuaScript.lua_Cameras != null) LuaScript.lua_Cameras.clear();
		if (LuaScript.lua_Jsons != null) LuaScript.lua_Jsons.clear();
		if (LuaScript.lua_Tweens != null) {
			for (tween in LuaScript.lua_Tweens) {
				if (tween != null) {
					tween.cancel();
					tween.destroy();
				}
			}
			LuaScript.lua_Tweens.clear();
		}
		#end
		for (script in cutsceneScripts)
		{
			script?.destroy();
		}
		cutsceneScripts.clear();
		scripts.clear();
		ColorSwap.colorSwapCache.clear();
		Note.framesCache.clear();
		Note.clearFallbackCaches();
		StrumNote.clearCache();
		NoteSplash.clearCache();
	}
	
		function processEvent(event:Array<Dynamic>) {
			#if LUA_ALLOWED
			var key = event[0].toLowerCase();
			var script = scripts.get(key);

			if (script != null) {
				for (i in 0...strumLineNotes.length) {
					var member = strumLineNotes.members[i];

					script.set("defaultStrum" + i + "X", member.x);
					script.set("defaultStrum" + i + "Y", member.y);
					script.set("defaultStrum" + i + "Angle", member.angle);

					script.set("defaultStrum" + i, {
						x: member.x,
						y: member.y,
						angle: member.angle,
					});
				}
			}
			#end


			EventHandler.processEvent(this, event);

			//                name       pos      param 1   param 2
			call("onEvent", [event[0], event[1], event[2], event[3]]);
		}


	function calculateAccuracy() {
		if (totalNotes != 0 && !switchedStates)
			accuracy = FlxMath.roundDecimal(100.0 / (totalNotes / hitNotes), 2);

		set("accuracy", accuracy);

		updateRating();
		updateScoreText();
	}

	inline function updateRating()
		ratingStr = Ratings.getRank(accuracy, misses);

	function generareNoteChangeEvents():Void {
		if (SONG.events.length > 0) {
			for (event in SONG.events) {
				baseEvents.push(event);
				events.push(event);
			}
		}

		if (Assets.exists(Paths.songEvents(SONG.song.toLowerCase(), storyDifficultyStr.toLowerCase())) && loadChartEvents) {
			var eventFunnies:Array<Array<Dynamic>> = SongLoader.parseLegacy(
				Json.parse(Assets.getText(Paths.songEvents(
					SONG.song.toLowerCase(),
					storyDifficultyStr.toLowerCase()
				))),
				SONG.song
			).events;

			for (event in eventFunnies) {
				baseEvents.push(event);
				events.push(event);
			}
		}

		for (event in events) {
			var evName = Std.string(event[0]).toLowerCase();
			if (evName == "change keycount" || evName == "change mania" || evName == "change keys") {
				var pkStr:String = (event.length > 2) ? StringTools.trim(Std.string(event[2])) : "";
				var kStr:String = (event.length > 3) ? StringTools.trim(Std.string(event[3])) : "";
				var pKeys:Null<Int> = Std.parseInt(pkStr);
				var oKeys:Null<Int> = Std.parseInt(kStr);
				if (pKeys == null || pKeys < 1) pKeys = (oKeys != null && oKeys >= 1) ? oKeys : (SONG.playerKeyCount != null && SONG.playerKeyCount > 0 ? SONG.playerKeyCount : 4);
				if (oKeys == null || oKeys < 1) oKeys = pKeys;
				maniaChanges.push([event[1], pKeys, oKeys]);
			}
		}

		events.sort((a, b) -> Std.int(a[1] - b[1]));
	}

	function generateEvents():Void {
		baseEvents = [];
		events = [];

		if (SONG.events.length > 0) {
			for (event in SONG.events) {
				baseEvents.push(event);
				events.push(event);
			}
		}

		if (Assets.exists(Paths.songEvents(SONG.song.toLowerCase(), storyDifficultyStr.toLowerCase())) && loadChartEvents) {
			var eventFunnies:Array<Array<Dynamic>> = SongLoader.parseLegacy(
				Json.parse(Assets.getText(Paths.songEvents(
					SONG.song.toLowerCase(),
					storyDifficultyStr.toLowerCase()
				))),
				SONG.song
			).events;

			for (event in eventFunnies) {
				baseEvents.push(event);
				events.push(event);
			}
		}


		for (event in events) {
			if (Options.getData("charsAndBGs")) {
				var map:Map<String, Dynamic>;

				switch (Std.string(event[2]).toLowerCase()) {
					case "dad" | "opponent" | "player2" | "1":
						map = dadMap;
					case "gf" | "girlfriend" | "player3" | "2":
						map = gfMap;
					default:
						map = bfMap;
				}
				if (event[0].toLowerCase() == "change character" && !map.exists(event[3])) {
					var tmr:Float = Sys.time();
					var funnyCharacter:Character;
					trace('Caching ${event[3]}');

					if (map == bfMap)
						funnyCharacter = new Boyfriend(100, 100, event[3]);
					else
						funnyCharacter = new Character(100, 100, event[3]);

					funnyCharacter.alpha = 0.00001;
					add(funnyCharacter);

					map.set(event[3], funnyCharacter);

					if (funnyCharacter.otherCharacters != null) {
						for (character in funnyCharacter.otherCharacters) {
							character.alpha = 0.00001;
							add(character);
						}
					}

					trace('Cached ${event[3]} in ${FlxMath.roundDecimal(Sys.time() - tmr, 2)} seconds');
				}

				if (event[0].toLowerCase() == "change stage" && !stageMap.exists(event[2])) {
					var funnyStage = new StageGroup(event[2]);
					funnyStage.visible = false;

					stageMap.set(event[2], funnyStage);
				}
			}
		}

		{
			for (event in events) {
				#if LUA_ALLOWED
				if (!scripts.exists(event[0].toLowerCase())
					&& Assets.exists(Paths.lua("event data/" + event[0].toLowerCase()))) {
					scripts.set(
						event[0].toLowerCase(),
						new LuaScript(Paths.getModPath(Paths.lua("event data/" + event[0].toLowerCase())))
					);
				}
				#end

				#if HSCRIPT_ALLOWED
				if (!scripts.exists(event[0].toLowerCase())
					&& Assets.exists(Paths.hx("data/event data/" + event[0].toLowerCase()))) {
					scripts.set(
						event[0].toLowerCase(),
						new HScript(Paths.hx("data/event data/" + event[0].toLowerCase()))
					);
				}
				#end
			}
		}

		events.sort((a, b) -> Std.int(a[1] - b[1]));
	}


	function setupNoteTypeScript(noteType:String) {
		{
		if (FlxG.state != this)
			return;
		#if LUA_ALLOWED
		if (!scripts.exists(noteType.toLowerCase()) && Assets.exists(Paths.lua("arrow types/" + noteType.toLowerCase()))) {
			scripts.set(noteType.toLowerCase(), new LuaScript(Paths.getModPath(Paths.lua("arrow types/" + noteType.toLowerCase()))));
		}
		#end
		#if HSCRIPT_ALLOWED
		if (Assets.exists(Paths.hx("data/arrow types/" + noteType.toLowerCase()))) {
			scripts.set(noteType.toLowerCase(), new HScript(Paths.hx("data/arrow types/" + noteType.toLowerCase())));
		}
		#end
	    }
	}


	function getCorrectKeyCount(player:Bool) {
		var kc = SONG.keyCount;
		if ((player && characterPlayingAs == BF) || (characterPlayingAs == OPPONENT && !player)) {
			kc = SONG.playerKeyCount;
		}
		return kc;
	}

	function getSingLuaFuncName(player:Bool) {
		var name = "playerTwo";
		if ((player && characterPlayingAs == BF) || (characterPlayingAs == OPPONENT && !player)) {
			name = "playerOne";
		}
		return name;
	}

	function addBehindGF(behind:FlxBasic) {
		insert(members.indexOf(gf.otherCharacters != null ? gf.otherCharacters[0] : gf), behind);
	}

	function addBehindDad(behind:FlxBasic) {
		insert(members.indexOf(dad.otherCharacters != null ? dad.otherCharacters[0] : dad), behind);
	}

	function addBehindBF(behind:FlxBasic) {
		insert(members.indexOf(boyfriend.otherCharacters != null ? boyfriend.otherCharacters[0] : boyfriend), behind);
	}
	private function createIcon(charIcon:String, isPlayer:Bool):HealthIcon
	{
		return hud != null ? hud.createIcon(charIcon, isPlayer) : null;
	}

	function getHealthIcons(char:Character):Array<String>
	{
		return PlayStateHUD.getHealthIcons(char);
	}

	function getIconData(char:Character, index:Int):Dynamic
	{
		return PlayStateHUD.getIconData(char, index);
	}

	function getIconOffset(char:Character, index:Int):{x:Float, y:Float}
	{
		return PlayStateHUD.getIconOffset(char, index);
	}

	function refreshIcons(char:Character, isPlayer:Bool):Void
	{
		if (hud != null)
			hud.refreshIcons(char, isPlayer);
	}
	public function setupUISkinConfigs(skin:String)
	{
		var base:String = "ui skins/" + skin;
		ui_settings  = CoolUtil.coolTextFile(Paths.txt(base + "/config"));
		mania_size   = CoolUtil.coolTextFile(Paths.txt(base + "/maniasize"));
		mania_offset = CoolUtil.coolTextFile(Paths.txt(base + "/maniaoffset"));
		if (Assets.exists(Paths.txt(base + "/maniagap")))
			mania_gap = CoolUtil.coolTextFile(Paths.txt(base + "/maniagap"));
		else
			mania_gap = CoolUtil.coolTextFile(Paths.txt("ui skins/default/maniagap"));

		types = CoolUtil.coolTextFile(Paths.txt(base + "/types"));
		arrow_Configs.set("default",
			CoolUtil.coolTextFile(Paths.txt(base + "/default"))
		);

		type_Configs.set("default",
			CoolUtil.coolTextFile(Paths.txt("arrow types/default"))
		);

		for (rating in ["marvelous", "sick", "good", "bad", "shit"])
		{
			if (Assets.exists(Paths.image(base + "/ratings/" + rating, 'shared'))) {
				uiMap.set(rating, Paths.gpuBitmap(base + "/ratings/" + rating, 'shared'));
			} else {
				uiMap.set(rating, Paths.gpuBitmap("ui skins/default/ratings/" + rating, 'shared'));
			}
		}

		// preload numbers
		for (i in 0...10) {
			if (Assets.exists(Paths.image(base + "/numbers/num" + i, 'shared'))) {
				uiMap.set(Std.string(i), Paths.gpuBitmap(base + "/numbers/num" + i, 'shared'));
			} else {
				uiMap.set(Std.string(i), Paths.gpuBitmap("ui skins/default/numbers/num" + i, 'shared'));
			}
		}
	}

		
	
	@:noCompletion
	@:allow(game.EventHandler)
	private function set_speed(speed:Float):Float {
		if (Options.getData("useCustomScrollSpeed")) {
			speed = Options.getData("customScrollSpeed");
		}
		if (notes?.members != null && unspawnNotes != null) {
			for (note in notes.members) {
				note.speed = speed;
			}
			for (note in unspawnNotes) {
				note.speed = speed;
			}
		}
		return this.speed = speed;
	}

	@:noCompletion
	inline private function get_dead():Bool {
		return health <= minHealth && !switchedStates && !invincible && !Options.getData("noDeath");
	}

	@:noCompletion
	inline private function get_infoTxt():FlxText {
		return timeBar.text;
	}

	@:noCompletion
	inline private function set_infoTxt(value:FlxText):FlxText {
		return timeBar.text = value;
	}

	@:noCompletion
	inline private function set_timeBarBG(value:FlxSprite):FlxSprite {
		return timeBar != null ? (timeBar.bg = value) : null;
	}

	@:noCompletion
	inline private function get_timeBarBG():FlxSprite {
		return timeBar != null ? timeBar.bg : null;
	}

	function collectAllActiveSprites():Array<FlxSprite> {
		var list:Array<FlxSprite> = [];
		findSpritesInGroup(this, list);
		if (bfMap != null) {
			for (char in bfMap) {
				if (char != null && !list.contains(char)) list.push(char);
			}
		}
		if (dadMap != null) {
			for (char in dadMap) {
				if (char != null && !list.contains(char)) list.push(char);
			}
		}
		if (gfMap != null) {
			for (char in gfMap) {
				if (char != null && !list.contains(char)) list.push(char);
			}
		}
		return list;
	}

	
	function findSpritesInGroup(group:Dynamic, list:Array<FlxSprite>):Void {
		if (group == null) return;
		
		if (Std.isOfType(group, FlxSprite) && !list.contains(cast group)) {
			list.push(cast group);
		}

		if (Reflect.hasField(group, "members")) {
			var members:Array<Dynamic> = Reflect.field(group, "members");
			if (members != null) {
				for (m in members) {
					findSpritesInGroup(m, list);
				}
			}
		}
	}

	function onPreCreate():Void {}

	function resolveCharacterPlayingAs():Void {}

	function allowDebugMenus():Bool {
		return !Options.getData("disableDebugMenus");
	}

	function onPlayerDeath():Void {}
}
