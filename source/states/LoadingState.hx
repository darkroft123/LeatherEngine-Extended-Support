package states;

import flixel.text.FlxText;
import flixel.math.FlxMath;
import flixel.ui.FlxBar;
import game.StageGroup;
import flixel.sound.FlxSound;
import flixel.addons.transition.FlxTransitionableState;
import lime.app.Promise;
import lime.app.Future;
import flixel.FlxG;
import flixel.FlxState;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.util.FlxTimer;
import flixel.util.FlxColor;
import game.SongLoader;
import openfl.utils.Assets;
import lime.utils.Assets as LimeAssets;
import lime.utils.AssetLibrary;
import lime.utils.AssetManifest;
import haxe.Json;
import states.FreeplayState;
import haxe.io.Path;
#if sys
import sys.FileSystem;
#end

#if DISCORD_ALLOWED
import utilities.DiscordClient;
#end
class AsyncAssetPreloader
{
	var uiSkins:Array<String> = [];
	var characters:Array<String> = [];
	var stages:Array<String> = [];
	var noteTypes:Array<String> = [];
	var audio:Array<String> = [];

	var onComplete:Void->Void = null;

	public var percent(get, default):Float = 0;
	public var totalLoadCount:Int = 0;
	public var loadedCount:Int = 0;

	var totalFinishes:Int = 0;
	var finshCount:Int = 0;

	private function get_percent()
	{
		if (totalLoadCount > 0)
			percent = loadedCount / totalLoadCount;

		return percent;
	}

	public function new(onComplete:Void->Void)
	{
		this.onComplete = onComplete;
		generatePreloadList();
	}

	private function generatePreloadList()
	{
		var song = PlayState.SONG;
		var diff = PlayState.storyDifficultyStr.toLowerCase();

		var uiSkin:String = song.ui_Skin;
		if (Std.string(uiSkin) == "null")
			uiSkin = "default";
		if (uiSkin == "default")
			uiSkin = utilities.Options.getData("uiSkin");

		uiSkins.push(uiSkin);
		if (!uiSkins.contains("default"))
			uiSkins.push("default");
		stages.push(song.stage);

		characters.push(song.player1);
		characters.push(song.player2);
		characters.push(song.gf);

		var audioName = song.specialAudioName == null ? diff : song.specialAudioName;
		var instAudio = Paths.inst(song.song, audioName);
		if (instAudio != null && instAudio != "") audio.push(instAudio);
		var voiceAudio = Paths.voices(song.song, audioName);
		if (voiceAudio != null && voiceAudio != "") audio.push(voiceAudio);

		var events:Array<Array<Dynamic>> = [];

		if (song.events.length > 0)
		{
			for (event in song.events)
				events.push(event);
		}

		var songEventPath = Paths.songEvents(song.song.toLowerCase(), diff);
		if (Assets.exists(songEventPath))
		{
			try {
				var rawText = Assets.getText(songEventPath);
				var parsedJson = Json.parse(rawText);
				var parsedSong:SongData = SongLoader.parseLegacy(parsedJson, song.song);
				var eventFunnies:Array<Array<Dynamic>> = parsedSong != null ? parsedSong.events : null;

				if (eventFunnies != null) {
					for (event in eventFunnies)
						events.push(event);
				}
			} catch (e:Dynamic) {
				trace('Error loading events in LoadingState: ' + e);
			}
		}

		if (events.length > 0)
		{
			events.sort(function(a, b)
			{
				if (a[1] < b[1])
					return -1;
				else if (a[1] > b[1])
					return 1;
				else
					return 0;
			});
		}

		for (event in events)
		{
			var eventStr:String = Std.string(event[0]).toLowerCase().trim();

			switch (eventStr)
			{
				case "change character":
					if (event[3] != null && Std.string(event[3]).trim() != "")
					{
						var charName = Std.string(event[3]).trim();
						if (!characters.contains(charName))
							characters.push(charName);
					}

				case "change stage":
					if (event[2] != null && Std.string(event[2]).trim() != "")
					{
						var stageName = Std.string(event[2]).trim();
						if (!stages.contains(stageName))
							stages.push(stageName);
					}

				case "change ui skin":
					if (event[2] != null && Std.string(event[2]).trim() != "")
					{
						var uiSkinName = Std.string(event[2]).trim();
						if (!uiSkins.contains(uiSkinName))
							uiSkins.push(uiSkinName);
					}
			}
		}

		for (section in song.notes)
		{
			if (section != null && section.sectionNotes != null)
			{
				for (songNotes in section.sectionNotes)
				{
					if (songNotes != null && songNotes.length > 4 && songNotes[4] != null && Std.isOfType(songNotes[4], String))
					{
						var noteType:String = Std.string(songNotes[4]).trim();
						if (noteType != "" && noteType != "default" && !noteTypes.contains(noteType))
						{
							noteTypes.push(noteType);
						}
					}
				}
			}
		}

		totalLoadCount = audio.length + characters.length + stages.length + uiSkins.length + noteTypes.length - 1;
	}

	public function load(async:Bool = true)
	{
		var loadAll = function()
		{
			loadAudio();
			loadCharacters();
			loadStages();
			loadUISkins();
			loadNoteTypes();
			return true;
		};

		if (async)
		{
			trace('loading async');

			var multi:Bool = false;

			if (multi)
			{
				setupFuture(function()
				{
					loadAudio();
					return true;
				});
				setupFuture(function()
				{
					loadStages();
					return true;
				});
				setupFuture(function()
				{
					loadCharacters();
					return true;
				});
				setupFuture(function()
				{
					loadUISkins();
					return true;
				});
			}
			else
			{
				setupFuture(loadAll);
			}
		}
		else
		{
			loadAll();
			finish();
		}
	}

	function setupFuture(func:Void->Bool)
	{
		var fut:Future<Bool> = new Future(func, true);

		fut.onComplete(function(_)
		{
			finish();
		});

		fut.onError(function(_)
		{
			finish();
		});

		totalFinishes++;
	}

	private function finish()
	{
		finshCount++;

		if (finshCount >= totalFinishes && onComplete != null)
			onComplete();
	}

	public function loadAudio()
	{
		var tempSounds:Array<FlxSound> = [];
		for (i in audio)
		{
			loadedCount++;
			if (i == null || i == "") continue;
			// Register the id first. `loadEmbedded` refuses anything the asset
			// library does not already know about, and song audio that `Paths`
			// resolved off the file system is in neither cache until it is put
			// there, so without this the preload silently did nothing and logged
			// "Could not find a Sound asset".
			system.OptimizedAssets.ensureSoundCached(i);
			var snd = new FlxSound();
			snd.loadEmbedded(i);
			tempSounds.push(snd);
		}

		for (snd in tempSounds)
			snd.destroy();

		trace('loaded audio');
	}

	private function preloadCharacterAssets(char:String):Void {
		if (char == null) return;
		var cLow = char.toLowerCase().trim();
		switch (cLow) {
			case '' | 'none' | 'empty' | 'nogf': return;
		}

		var charDataPath = "character data/" + char;
		var jsonPath = Paths.json(charDataPath);
		var configPath = Paths.json(charDataPath + "/config");
		var imagePath:String = "";
		var iconName:String = "";

		try {
			if (Assets.exists(jsonPath)) {
				var raw = Assets.getText(jsonPath);
				if (raw != null && raw.trim() != "") {
					var psychCharacter = Json.parse(raw);
					if (psychCharacter != null) {
						if (psychCharacter.image != null)
							imagePath = Std.string(psychCharacter.image).replace("characters/", "");
						if (psychCharacter.healthicon != null)
							iconName = Std.string(psychCharacter.healthicon);
					}
				}
			} else if (Assets.exists(configPath)) {
				var raw = Assets.getText(configPath);
				if (raw != null && raw.trim() != "") {
					var config = Json.parse(raw);
					if (config != null) {
						if (config.imagePath != null)
							imagePath = Std.string(config.imagePath);
						if (config.icon != null)
							iconName = Std.string(config.icon);
						if (config.characters != null) {
							var charList:Array<Dynamic> = config.characters;
							for (c in charList) {
								if (c != null && c.name != null) {
									preloadCharacterAssets(Std.string(c.name));
								}
							}
						}
					}
				}
			}
		} catch (e:Dynamic) {
			trace("Error preloading character json for: " + char);
		}

		if (imagePath == "") {
			imagePath = char;
		}

		Paths.getAtlas(imagePath);

		if (iconName == "") iconName = char;
		if (iconName != "") {
			if (Assets.exists(Paths.file('images/icons/$iconName.xml', TEXT))) {
				Paths.getSparrowAtlas('icons/$iconName');
			} else if (Assets.exists(Paths.file('images/icons/$iconName.png', IMAGE))) {
				Paths.gpuBitmap('icons/$iconName');
			}
		}
	}

	private function preloadStageAssets(stage:String):Void {
		var stageJsonPath = Paths.json("stage data/" + stage);
		if (!Assets.exists(stageJsonPath)) return;

		try {
			var raw = Assets.getText(stageJsonPath);
			if (raw == null || raw.trim() == "") return;
			var stageData = Json.parse(raw);
			if (stageData == null || stageData.objects == null) return;

			var imageDirectory:String = stageData.imageDirectory != null ? stageData.imageDirectory : stage;
			var objects:Array<Dynamic> = stageData.objects;

			for (object in objects) {
				if (object.file_Name != null && object.object_Name != "vortex") {
					var fileName:String = Std.string(object.file_Name).trim();
					if (fileName != "" && !fileName.startsWith('#')) {
						var atlasData = utilities.PorteadorXml.resolveStageAtlasPaths(imageDirectory, fileName);
						if (atlasData != null || object.is_Animated == true) {
							if (atlasData != null) {
								system.OptimizedAssets.getSparrowAtlas(atlasData.imagePath, atlasData.xmlPath);
							} else {
								var path = (imageDirectory != null && imageDirectory != "") ? imageDirectory + "/" + fileName : fileName;
								Paths.getSparrowAtlas(path, "stages");
							}
						} else {
							var gPath = utilities.PorteadorXml.resolveStageGraphicPath(imageDirectory, fileName);
							if (gPath != null) {
								system.OptimizedAssets.getGraphic(gPath);
							} else {
								var path = (imageDirectory != null && imageDirectory != "") ? imageDirectory + "/" + fileName : fileName;
								Paths.gpuBitmap(path, "stages");
							}
						}
					}
				}
			}
		} catch (e:Dynamic) {
			trace("Error preloading stage assets for: " + stage);
		}
	}

	public function loadCharacters()
	{
		if (!utilities.Options.getData("charsAndBGs"))
			return;

		for (i in characters)
		{
			loadedCount++;
			preloadCharacterAssets(i);
		}

		trace('loaded characters');
	}

	public function loadStages()
	{
		if (!utilities.Options.getData("charsAndBGs"))
			return;

		for (i in stages)
		{
			loadedCount++;
			preloadStageAssets(i);
		}

		trace('loaded stages');
	}

	public function loadUISkins()
	{
		for (i in uiSkins)
		{
			loadedCount++;
			
			// Load strums
			var spritesheetPath:String;
			if (Assets.exists(Paths.image('ui skins/$i/arrows/strums', 'shared'))) {
				spritesheetPath = 'ui skins/$i/arrows/strums';
			} else if (Assets.exists(Paths.image('ui skins/$i/arrows/default', 'shared'))) {
				spritesheetPath = 'ui skins/$i/arrows/default';
			} else if (Assets.exists(Paths.image('ui skins/default/arrows/strums', 'shared'))) {
				spritesheetPath = 'ui skins/default/arrows/strums';
			} else {
				spritesheetPath = 'ui skins/default/arrows/default';
			}
			// Strums/notes need CPU-readable BitmapData for SustainStrip.paint()
			Paths.getSparrowAtlas(spritesheetPath, 'shared');

			var txtPath = Paths.txt('ui skins/$i/default');
			if (Assets.exists(txtPath)) {
				var config = CoolUtil.coolTextFile(txtPath);
				if (config != null && config.length > 0) {
					var notePath = 'ui skins/$i/arrows/' + config[0];
					if (Assets.exists(Paths.image(notePath, 'shared'))) {
						Paths.getSparrowAtlas(notePath, 'shared', true);
					}
				}
			}

			// Load splashes
			var splashPath = 'ui skins/$i/arrows/Note_Splashes';
			if (Assets.exists(Paths.image(splashPath, 'shared'))) {
				// Splashes use sparrow atlas on CPU
				Paths.getSparrowAtlas(splashPath, 'shared');
			}

			// Preload countdown sprites
			for (cd in ["ready", "set", "go"]) {
				var cdPath = 'ui skins/$i/countdown/$cd';
				if (Assets.exists(Paths.image(cdPath)))
					Paths.gpuBitmap(cdPath);
				else if (Assets.exists(Paths.image('ui skins/default/countdown/$cd')))
					Paths.gpuBitmap('ui skins/default/countdown/$cd');
			}

			// Preload countdown sounds
			for (snd in ["intro3", "intro2", "intro1", "introGo"]) {
				var skinSnd = '$snd-$i';
				if (Assets.exists(Paths.sound(skinSnd)))
					system.OptimizedAssets.ensureSoundCached(Paths.sound(skinSnd));
				else if (Assets.exists(Paths.sound(snd)))
					system.OptimizedAssets.ensureSoundCached(Paths.sound(snd));
			}

			// Preload ratings and numbers
			for (r in ["sick", "good", "bad", "shit"]) {
				var rPath = 'ui skins/$i/ratings/$r';
				if (Assets.exists(Paths.image(rPath, 'shared')))
					Paths.gpuBitmap(rPath, 'shared');
				else if (Assets.exists(Paths.image('ui skins/default/ratings/$r', 'shared')))
					Paths.gpuBitmap('ui skins/default/ratings/$r', 'shared');
			}
			for (n in 0...10) {
				var numPath = 'ui skins/$i/numbers/num$n';
				if (Assets.exists(Paths.image(numPath, 'shared')))
					Paths.gpuBitmap(numPath, 'shared');
				else if (Assets.exists(Paths.image('ui skins/default/numbers/num$n', 'shared')))
					Paths.gpuBitmap('ui skins/default/numbers/num$n', 'shared');
			}

			// Preload healthBar
			var hbPath = 'ui skins/$i/other/healthBar';
			if (Assets.exists(Paths.image(hbPath)))
				Paths.gpuBitmap(hbPath);
			else if (Assets.exists(Paths.image('ui skins/default/other/healthBar')))
				Paths.gpuBitmap('ui skins/default/other/healthBar');
		}

		if (PlayState.practiceMode && PlayState.startOnTime > 0 && PlayState.instance != null)
		{
			var i = PlayState.instance.notes.members.length - 1;
			while (i >= 0)
			{
				var note = PlayState.instance.notes.members[i];
				if (note.strumTime < PlayState.startOnTime)
				{
					note.active = false;
					note.visible = false;
					PlayState.instance.invalidateNote(note);
					PlayState.instance.notes.remove(note, true);
				}
				i--;
			}

			i = PlayState.instance.unspawnNotes.length - 1;
			while (i >= 0)
			{
				var note = PlayState.instance.unspawnNotes[i];
				if (note.strumTime < PlayState.startOnTime)
				{
					note.kill();
					note.destroy();
					PlayState.instance.unspawnNotes.remove(note);
				}
				i--;
			}
		}

		trace('loaded UI Skins');
	}

	private function preloadNoteType(noteType:String):Void {
		var song = PlayState.SONG;
		var uiSkin = song.ui_Skin;
		if (Std.string(uiSkin) == "null")
			uiSkin = "default";
		if (uiSkin == "default")
			uiSkin = utilities.Options.getData("uiSkin");

		var typesList:Array<String> = [];
		var typesPath = Paths.txt("ui skins/" + uiSkin + "/types");
		if (Assets.exists(typesPath)) {
			typesList = CoolUtil.coolTextFile(typesPath);
		}

		var containsType = typesList.contains(noteType);
		var basePath = containsType ? 'ui skins/$uiSkin/arrows/' : 'ui skins/default/arrows/';
		var path = basePath + noteType;

		if (Assets.exists(Paths.image(path, 'shared'))) {
			Paths.getSparrowAtlas(path, 'shared', true);
		} else {
			Paths.getSparrowAtlas('ui skins/default/arrows/default', 'shared', true);
		}
	}

	public function loadNoteTypes()
	{
		for (i in noteTypes)
		{
			loadedCount++;
			preloadNoteType(i);
		}
		trace('loaded note types');
	}
}
class LoadingState extends MusicBeatState
{
	inline static var MIN_TIME = 1.0;

	var target:FlxState;
	var stopMusic = false;
	var callbacks:MultiCallback;
	var currentIndex = 0;
	var logo:FlxSprite;
	var gfDance:FlxSprite;
	var danceLeft = false;
	var songNames:Array<String> = FreeplayState.songs.map(song -> song.name);
	public static var instance:LoadingState = null;

	var loader:AsyncAssetPreloader = null;
	var loadingBar:FlxBar;
	var loadingText:FlxText;
	var lerpedPercent:Float = 0;
	var loadTime:Float = 0;
	var isPreloadDone:Bool = false;
	var isWarmedUp:Bool = false;

	function new(target:FlxState, stopMusic:Bool)
	{
		super();
		this.target = target;
		this.stopMusic = stopMusic;
	}

	override function create()
	{
		MusicBeatState.windowNameSuffix = " is loading...";
		instance = this;

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Loading - " + PlayState.SONG.song, null);
		#end

		#if PRELOAD_ALL
		var loadingScreen = new FlxSprite(0, 0);
		var songImageMap:Map<String, String> = new Map();
		var loadingLines:Array<String> = [];

		#if sys
		var curMod = Options.getData("curMod");
		var modPath = "mods/" + curMod;
		var loadingPath = modPath + "/data/loadingScreen.txt";
		var appendPath = modPath + "/_append/data/loadingScreen.txt";
		var appendPathCaps = modPath + "/_append/data/LoadingScreen.txt";

		if (sys.FileSystem.exists(loadingPath))
			loadingLines = CoolUtil.coolTextFileSys(loadingPath);
		else if (sys.FileSystem.exists(appendPath))
			loadingLines = CoolUtil.coolTextFileSys(appendPath);
		else if (sys.FileSystem.exists(appendPathCaps))
			loadingLines = CoolUtil.coolTextFileSys(appendPathCaps);
		#else
		loadingLines = CoolUtil.coolTextFile(Paths.txt('loadingScreen'));
		#end

		for (line in loadingLines)
		{
			var parts = line.split(':');
			if (parts.length == 2)
			{
				var song = StringTools.trim(parts[0].toLowerCase());
				var image = StringTools.trim(parts[1]);
				songImageMap.set(song, image);
			}
		}

		var currentSong = PlayState.SONG.song.toLowerCase();
		var imgName = songImageMap.exists(currentSong) ? songImageMap.get(currentSong) : "loadingscreen";

		loadingScreen.loadGraphic(Paths.gpuBitmap("loading/" + imgName));
		loadingScreen.setGraphicSize(1280, 720);
		loadingScreen.updateHitbox();
		loadingScreen.screenCenter();
		loadingScreen.antialiasing = true;
		add(loadingScreen);

		loadingText = new FlxText(50, FlxG.height - 100, 0, "");
		loadingText.setFormat(Paths.font("consola.ttf"), 34, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(loadingText);

		var barWidth = 500;
		var barHeight = 30;
		var barX = (FlxG.width - barWidth) / 2;
		var barY = FlxG.height - 80;

		var border = new FlxSprite(barX + 200, barY).makeGraphic(barWidth + 15, barHeight + 15, 0xFF000000);
		border.scrollFactor.set();
		add(border);

		loadingBar = new FlxBar(barX + 205, barY + 7, LEFT_TO_RIGHT, barWidth, barHeight, this, 'lerpedPercent', 0, 1);
		loadingBar.scrollFactor.set();
		loadingBar.createFilledBar(0xFF444444, 0xFFFFFFFF);
		add(loadingBar);

		loader = new AsyncAssetPreloader(function()
		{
			isPreloadDone = true;
			trace("Load time: " + loadTime);
		});
		loader.load(true);

		#else
		logo = new FlxSprite(-150, -100);
		logo.frames = Paths.getSparrowAtlas('title/logoBumpin');
		logo.antialiasing = true;
		logo.animation.addByPrefix('bump', 'logo bumpin', 24);
		logo.animation.play('bump');
		logo.updateHitbox();

		gfDance = new FlxSprite(FlxG.width * 0.4, FlxG.height * 0.07);
		gfDance.frames = Paths.getSparrowAtlas('title/gfDanceTitle');
		gfDance.animation.addByIndices('danceLeft', 'gfDance', [30, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], "", 24, false);
		gfDance.animation.addByIndices('danceRight', 'gfDance', [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29], "", 24, false);
		gfDance.antialiasing = true;
		add(gfDance);
		add(logo);

		initSongsManifest().onComplete(function(lib)
		{
			callbacks = new MultiCallback(onLoad);
			var introComplete = callbacks.add("introComplete");

			checkLoadSong(getSongPath());

			if (PlayState.SONG.needsVoices)
				checkLoadSong(getVocalPath());

			checkLibrary("shared");
			checkLibrary("stages");
			checkLibrary("songs");

			var fadeTime = 0.5;
			FlxG.camera.fade(FlxG.camera.bgColor, fadeTime, true);
			new FlxTimer().start(fadeTime + MIN_TIME, function(_) introComplete());
		});
		#end
	}

	public function checkLoadSong(path:String)
	{
		if (!Assets.exists(path) || Assets.cache.hasSound(path))
			return;

		if (callbacks == null)
			callbacks = new MultiCallback(onLoad);

		var callback = callbacks.add("song:" + path);
		Assets.loadSound(path).onComplete(function(_) callback());
	}

	function checkLibrary(library:String)
	{
		trace(Assets.hasLibrary(library));

		if (Assets.getLibrary(library) != null)
			return;

		@:privateAccess
		if (!LimeAssets.libraryPaths.exists(library))
			throw "Missing library: " + library;

		var callback = callbacks.add("library:" + library);
		Assets.loadLibrary(library).onComplete(function(_) callback());
	}

	override function beatHit()
	{
		super.beatHit();

		#if NO_PRELOAD_ALL
		logo.animation.play('bump');
		danceLeft = !danceLeft;

		if (danceLeft)
			gfDance.animation.play('danceRight');
		else
			gfDance.animation.play('danceLeft');
		#end
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (loader != null)
		{
			loadTime += elapsed;
			lerpedPercent = FlxMath.lerp(lerpedPercent, loader.percent, elapsed * 8);

			var currentSong = "";
			#if STORY_MODE
			if (PlayState.storyPlaylist != null && PlayState.storyPlaylist.length > 0)
				currentSong = PlayState.storyPlaylist[PlayState.storyPlaylist.length - 1];
			#else
			if (PlayState.SONG != null)
				currentSong = PlayState.SONG.song;
			#end

			var dots = Std.int((loadTime * 2) % 4);
			var dotStr = StringTools.lpad("", ".", dots);

			if (!isPreloadDone) {
				loadingText.text = "Loading" + dotStr + "\n" + currentSong + " (" + loader.loadedCount + "/" + (loader.totalLoadCount + 1) + ")";
			} else if (!isWarmedUp) {
				loadingText.text = "Preparing..." + "\n" + currentSong;
				lerpedPercent = 1.0;
				isWarmedUp = true;
				system.OptimizedBitmapData.releaseAllCPUData();
				#if cpp
				utilities.MemoryUtil.clearMajor();
				#end
			} else {
				loadingText.text = "Ready!" + "\n" + currentSong;
				lerpedPercent = 1.0;
				loader = null;
				FlxTransitionableState.skipNextTransOut = true;
				onLoad();
			}
		}

		#if debug
		if (FlxG.keys.justPressed.SPACE)
			trace('fired: ' + callbacks.getFired() + " unfired:" + callbacks.getUnfired());
		#end
	}

	function onLoad()
	{
		#if MODCHARTING_TOOLS
		modcharting.SustainStrip.clearCache();
		#end

		if (stopMusic && FlxG.sound.music != null)
			FlxG.sound.music.stop();

		FlxG.switchState(target);
	}

	public static function getSongPath()
	{
		return Paths.inst(PlayState.SONG.song);
	}

	public static function getVocalPath()
	{
		return Paths.voices(PlayState.SONG.song);
	}

	inline static public function loadAndSwitchState(target:Void->FlxState, stopMusic = false)
	{
		FlxG.switchState(getNextState(target(), stopMusic));
	}

	static function getNextState(target:FlxState, stopMusic = false):FlxState
	{
		Paths.setCurrentLevel("week" + PlayState.storyWeek);

		#if NO_PRELOAD_ALL
		var loaded = isSoundLoaded(getSongPath())
			&& (!PlayState.SONG.needsVoices || isSoundLoaded(getVocalPath()))
			&& isLibraryLoaded("shared");

		if (!loaded)
			return new LoadingState(target, stopMusic);
		#end

		if (stopMusic && FlxG.sound.music != null)
			FlxG.sound.music.stop();

		return new LoadingState(target, stopMusic);
	}

	#if NO_PRELOAD_ALL
	static function isSoundLoaded(path:String):Bool
	{
		return Assets.cache.hasSound(path);
	}

	static function isLibraryLoaded(library:String):Bool
	{
		return Assets.getLibrary(library) != null;
	}
	#end

	override public function destroy()
	{
		super.destroy();
		instance = null;
		loader = null;
		callbacks = null;
		logo = null;
		gfDance = null;
		loadingText = null;
		loadingBar = null;
	}

	static function initSongsManifest()
	{
		var id = "songs";
		var promise = new Promise<AssetLibrary>();
		var library = LimeAssets.getLibrary(id);

		if (library != null)
			return Future.withValue(library);

		var path = id;
		var rootPath = null;

		@:privateAccess
		var libraryPaths = LimeAssets.libraryPaths;

		if (libraryPaths.exists(id))
		{
			path = libraryPaths[id];
			rootPath = Path.directory(path);
		}
		else
		{
			if (StringTools.endsWith(path, ".bundle"))
			{
				rootPath = path;
				path += "/library.json";
			}
			else
			{
				rootPath = Path.directory(path);
			}

			@:privateAccess
			path = LimeAssets.__cacheBreak(path);
		}

		AssetManifest.loadFromFile(path, rootPath).onComplete(function(manifest)
		{
			if (manifest == null)
			{
				promise.error("Cannot parse asset manifest for library \"" + id + "\"");
				return;
			}

			var library = AssetLibrary.fromManifest(manifest);

			if (library == null)
			{
				promise.error("Cannot open library \"" + id + "\"");
			}
			else
			{
				@:privateAccess
				LimeAssets.libraries.set(id, library);
				library.onChange.add(LimeAssets.onChange.dispatch);
				promise.completeWith(Future.withValue(library));
			}
		}).onError(function(_)
		{
			promise.error("There is no asset library with an ID of \"" + id + "\"");
		});

		return promise.future;
	}
}

class MultiCallback
{
	public var callback:Void->Void;
	public var logId:String = null;
	public var length(default, null) = 0;
	public var numRemaining(default, null) = 0;

	var unfired = new Map<String, Void->Void>();
	var fired = new Array<String>();

	public function new(callback:Void->Void, logId:String = null)
	{
		this.callback = callback;
		this.logId = logId;
	}

	public function add(id = "untitled")
	{
		id = '$length:$id';
		length++;
		numRemaining++;

		var func:Void->Void = null;
		func = function()
		{
			if (unfired.exists(id))
			{
				unfired.remove(id);
				fired.push(id);
				numRemaining--;

				if (logId != null)
					log('fired $id, $numRemaining remaining');

				if (numRemaining == 0)
				{
					if (logId != null)
						log('all callbacks fired');

					callback();
				}
			}
			else
			{
				log('already fired $id');
			}
		};

		unfired[id] = func;
		return func;
	}

	inline function log(msg):Void
	{
		if (logId != null)
			trace('$logId: $msg');
	}

	public function getFired()
	{
		return fired.copy();
	}

	public function getUnfired()
	{
		return [for (id in unfired.keys()) id];
	}
}