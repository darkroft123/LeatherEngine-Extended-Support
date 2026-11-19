package substates;

import states.OptionsMenu;
import flixel.util.FlxStringUtil;
import flixel.FlxCamera;
import game.Conductor;
import states.FreeplayState;
import states.StoryMenuState;
import states.OneShotsState;
import states.PlayState;
import ui.DesingText;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import openfl.utils.Assets;
import ui.Option;
import flixel.FlxSubState;
import flixel.math.FlxMath;
import states.GroupSelectState;
import states.PracticeState;
import game.FreeplaySong;
import shaders.Shaders.GreyscaleEffect;
import states.LoadingState;
import game.SongLoader;
import substates.BlockedAndErrorSubState;


class PauseSubState extends MusicBeatSubstate {
	public static var instance:PauseSubState = null;
	public static var lastPromptedDeathCount:Int = -1;

	public static function getSongIntensity(songName:String, diffName:String):Float
	{
		if (songName == null) return 0;

		if (PlayState.currentFreeplaySong != null && PlayState.currentFreeplaySong.intensity != null && PlayState.currentFreeplaySong.intensity.length > 0)
		{
			var songData = PlayState.currentFreeplaySong;
			if (songData.difficulties != null && diffName != null)
			{
				for (i in 0...songData.difficulties.length)
				{
					if (songData.difficulties[i].toLowerCase() == diffName.toLowerCase())
					{
						if (i < songData.intensity.length)
							return songData.intensity[i];
					}
				}
			}
			return songData.intensity[0];
		}

		var curMod:String = utilities.Options.getData("curMod");
		var path:String = #if MODDING_ALLOWED 'mods/$curMod/data/freeplay.json'; #else 'assets/preload/data/freeplay.json'; #end

		if (!sys.FileSystem.exists(path))
			path = 'assets/preload/data/freeplay.json';

		if (sys.FileSystem.exists(path))
		{
			try
			{
				var rawJson:Dynamic = haxe.Json.parse(sys.io.File.getContent(path));
				var songs:Array<Dynamic> = cast rawJson.songs;
				if (songs != null)
				{
					for (s in songs)
					{
						if (s.name != null && Std.string(s.name).toLowerCase() == songName.toLowerCase())
						{
							var intensities:Array<Dynamic> = s.intensity;
							var diffs:Array<Dynamic> = s.difficulties;
							if (intensities != null && intensities.length > 0)
							{
								if (diffs != null && diffName != null)
								{
									for (i in 0...diffs.length)
									{
										if (Std.string(diffs[i]).toLowerCase() == diffName.toLowerCase())
										{
											if (i < intensities.length)
												return cast intensities[i];
										}
									}
								}
								return cast intensities[0];
							}
						}
					}
				}
			}
			catch (e:Dynamic)
			{
				trace("Error parsing freeplay.json for intensity: " + e);
			}
		}

		return 0;
	}

	public static function shouldShowPracticeModal(intensity:Float, deathCount:Int):Bool
	{
		if (intensity < 4) return false;
		if (deathCount == 5) return true;
		if (deathCount == 10) return true;
		if (deathCount > 10 && deathCount % 10 == 0) return true;
		return false;
	}
	var desingTextStyle:Dynamic = {
		 songFont: "Ethnocentric-Regular.otf",
		outerBorderTop: "#000000",
		outerBorderBot: "#000000",
		midBorderTop: "#a7face",
		midBorderBot: "#32b7a0",
		innerBorderTop: "#393939",
		innerBorderBot: "#2e2d2d",
		outerBorderSize: 6,
		shadowAlpha:0
	};
	
    var greyscale:GreyscaleEffect;
	var grpMenuShit = new FlxTypedGroup<DesingText>();
	var curSelected = 0;
	var menu = "default";
	var warningAmountLols = 0;
	var curTime = Math.max(0, Conductor.songPosition);
	var holdTime = 0.0;
	var justPressedAcceptLol = true;
	var pauseCamera = new FlxCamera();
	var pauseMusic:FlxSound;
	var scoreWarning:FlxText;

	public var MAX_MUSIC_VOLUME = 0.5;
	public var MUSIC_INCREASE_SPEED = 0.02;
	var meta = PlayState.songMetadata;
	var info:Array<String> = [];
	var infoTexts:Array<FlxText> = [];


	var menus = [
		"default" => ['Resume', 'Restart Song', 'Quick Options', 'Play As', 'Edit Keybinds','Change Noteskin', 'Note Colors', 'Options', 'Exit To Menu'],
		"Quick Options" => ['Back', 'Bot', 'Auto Restart', 'No Miss', 'Ghost Tapping', 'No Death']
	];
	
    inline function makePanel(x:Float, y:Float, w:Int, h:Int, color:Int):FlxSprite {
        var s = new FlxSprite(x, y).makeGraphic(w, h, color);
        s.scrollFactor.set();
        s.shader = greyscale.shader;
        add(s);
        return s;
    }
	static function resolveMetaString(rawValue:Dynamic):String {
		if (rawValue == null) return null;
		if (Std.isOfType(rawValue, Array)) {
			var arr:Array<Dynamic> = cast rawValue;
			var clean = [for (item in arr) if (item != null && StringTools.trim(Std.string(item)) != "") StringTools.trim(Std.string(item))];
			return clean.join(", ");
		}
		var str = StringTools.trim(Std.string(rawValue));
		return (str == "" || str == "null") ? null : str;
	}

	public function new() {
		super();
		greyscale = new GreyscaleEffect();
		
		if (meta != null) {
			var comp = resolveMetaString(meta.composer);
			if (comp != null && comp != "") info.push("Composer: " + comp);
			var char = resolveMetaString(meta.charter);
			if (char != null && char != "") info.push("Charter: " + char);
			var modc = resolveMetaString(meta.modcharter);
			if (modc != null && modc != "") info.push("Modcharter: " + modc);
			var orig = resolveMetaString(meta.originalsong);
			if (orig != null && orig != "") info.push("Original Song: " + orig);
		}
		var skin = (PlayState.boyfriend != null) ? PlayState.boyfriend.curCharacter : "bf";
		var path = Paths.music('breakfast' + (Assets.exists(Paths.music('breakfast-' + skin, 'shared')) ? '-' + skin : ''), 'shared');
		pauseMusic = new FlxSound().loadEmbedded(path, true, true);
		pauseMusic.volume = 0;
		pauseMusic.play();
		FlxG.sound.list.add(pauseMusic);

		pauseCamera.bgColor.alpha = 0;
		FlxG.cameras.add(pauseCamera, false);

		if (PlayState.chartingMode) {
			var opts = menus.get("default");
			if (!opts.contains("Skip Time")) {
				opts.insert(opts.length - 1, "Skip Time");
				menus.set("default", opts);
			}
		}


		

		var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0;
		bg.scrollFactor.set();
		add(bg);

		
		var song = new FlxText(20, 15, 0, PlayState.SONG.song, 36);
		song.setFormat(Paths.font("Ethnocentric-Regular.otf"), 36, FlxColor.WHITE, RIGHT);
		song.x = FlxG.width - (song.width + 20);

		var diff = new FlxText(20, 52, 0, PlayState.storyDifficultyStr.toUpperCase(), 36);
		diff.setFormat(Paths.font('Ethnocentric-Regular.otf'), 36, FlxColor.WHITE, RIGHT);
		diff.x = FlxG.width - (diff.width + 20);
		
		var blueballedTxt:FlxText;
		if (PlayState.diedInNoDeath) {
			blueballedTxt = new FlxText(20, 120, 0, "YOU DIED (NO DEATH)", 26);
			blueballedTxt.setFormat(Paths.font('Ethnocentric-Regular.otf'), 26, FlxColor.RED, RIGHT);
		} else {
			blueballedTxt = new FlxText(20, 120, 0, "Blueballed: " + PlayState.deathCounter, 36);
			blueballedTxt.setFormat(Paths.font('Ethnocentric-Regular.otf'), 36, FlxColor.YELLOW, RIGHT);
		}
		blueballedTxt.x = FlxG.width - (blueballedTxt.width + 20);

		var panelWidth:Float = Math.max(song.width, diff.width);
		panelWidth = Math.max(panelWidth, blueballedTxt.width);
		var panelX:Float = FlxG.width - (panelWidth + 30);

		var topPanel = makePanel(
			Std.int(panelX),
			Std.int(song.y - 10),
			Std.int(panelWidth + 50), 
			Std.int((blueballedTxt.y + blueballedTxt.height + 10) - (song.y - 10)),
			FlxColor.BLACK
		);
		topPanel.alpha = 0;

		add(song);
		add(diff);
		add(blueballedTxt);

	
		scoreWarning = new FlxText(20, 79, 0, PlayState.diedInNoDeath ? "YOU DIED! Score is invalidated for this run." : "Remember, changing options invalidates your score!", 32);
		scoreWarning.setFormat(Paths.font("Ethnocentric-Regular.otf"), 20, PlayState.diedInNoDeath ? FlxColor.RED : FlxColor.WHITE, RIGHT);
		scoreWarning.screenCenter(X);
		scoreWarning.alpha = 0;
		add(scoreWarning);

		

		add(grpMenuShit);
		
		var songData:FreeplaySong = PlayState.currentFreeplaySong;
		var renderKey = PlayState.songRender;

		if (renderKey != null && renderKey.length > 0) {
			var renderPath = Paths.gpuBitmap('freeplay/Renders/' + renderKey);
			if (Assets.exists(renderPath)) {
				var spriteToShow = new FlxSprite().loadGraphic(renderPath);
				spriteToShow.antialiasing = Options.getData("antialiasing");
					spriteToShow.x = FlxG.width - spriteToShow.width + 600;
				spriteToShow.y = 520;
				spriteToShow.scrollFactor.set();
				spriteToShow.alpha = 0;

				insert(members.indexOf(bg) + 1, spriteToShow);

				FlxTween.tween(
					spriteToShow,
					{ alpha: 1, y: 0 },
					1,
					{ ease: FlxEase.backInOut, startDelay: 0.2 }
				);
			}
		}

		
        greyscale.radius = 0.035; greyscale.borderSize = 0.0075; greyscale.smoothness = 0.001;greyscale.bordersEnabled = true; greyscale.update(0);
		var currentSong:FreeplaySong = PlayState.currentFreeplaySong;

		if (currentSong != null
			&& currentSong.difficulties != null
			&& currentSong.difficulties.length > 1)
		{
			var opts = menus.get("default");
			opts.insert(opts.length - 1, "Change Difficulty");
			menus.set("default", opts);
		}


		updateAlphabets();
		var bottomPanel = makePanel(
			-20,
			FlxG.height - 80,
			FlxG.width + 50,
			180,
			FlxColor.BLACK
		);
		bottomPanel.alpha = 0;

		var columnX:Array<Float> = [20, 640];
		var columnY:Array<Float> = [FlxG.height - 74, FlxG.height - 74];

		var enterOffset = 100;

		for (i in 0...info.length) {
			var column = Std.int(i / 2); 

			var txt = new FlxText(
				columnX[column],
				columnY[column] + enterOffset,
				560,
				info[i],
				18
			);

			txt.setFormat(
				Paths.font("Ethnocentric-Regular.otf"),
				18,
				FlxColor.WHITE,
				LEFT
			);

			txt.wordWrap = true;
			txt.alpha = 0;
			add(txt);
			infoTexts.push(txt);
			columnY[column] += txt.height + 5;
		}


		for (t in [song, diff, blueballedTxt, scoreWarning]) t.alpha = 0;

		var songFinalY:Float = song.y;
		var diffFinalY:Float = diff.y;
		var blueFinalY:Float = blueballedTxt.y;
		var topPanelFinalY:Float = topPanel.y;
		var bottomPanelFinalY:Float = bottomPanel.y;

		song.y -= 30;
		diff.y -= 30;
		blueballedTxt.y -= 30;
		topPanel.y -= 30;
		bottomPanel.y += 40;

		FlxTween.tween(bg, {alpha: 0.65}, 0.45, {ease: FlxEase.quartOut});
		FlxTween.tween(topPanel, {alpha: 0.85, y: topPanelFinalY}, 0.45, {ease: FlxEase.backOut, startDelay: 0.1});
		FlxTween.tween(bottomPanel, {alpha: 0.85, y: bottomPanelFinalY}, 0.45, {ease: FlxEase.quartOut, startDelay: 0.2});

		FlxTween.tween(song, {alpha: 1, y: songFinalY}, 0.4, {ease: FlxEase.backOut, startDelay: 0.18});
		FlxTween.tween(diff, {alpha: 1, y: diffFinalY}, 0.4, {ease: FlxEase.backOut, startDelay: 0.25}); 
		FlxTween.tween(blueballedTxt, {alpha: 1, y: blueFinalY}, 0.4, {ease: FlxEase.backOut, startDelay: 0.32}); 

		if (PlayState.diedInNoDeath) {
			scoreWarning.alpha = 0;
			FlxTween.tween(scoreWarning, {alpha: 1, y: scoreWarning.y + 10}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.4});
		}

		for (i in 0...infoTexts.length) {
			var txt = infoTexts[i];
			FlxTween.tween(txt, {alpha: 1, y: txt.y - enterOffset}, 0.35, {
				ease: FlxEase.quartOut,
				startDelay: 0.3 + (i * 0.08)
			});
		}


	

		instance = this;

		cameras = (PlayState.instance != null && PlayState.instance.usedLuaCameras) ? [FlxG.cameras.list[FlxG.cameras.list.length - 1]] : [pauseCamera];

		var songName:String = (PlayState.SONG != null) ? PlayState.SONG.song : null;
		var intensity:Float = getSongIntensity(songName, PlayState.storyDifficultyStr);

		if (!PlayState.practiceMode
			&& shouldShowPracticeModal(intensity, PlayState.deathCounter)
			&& lastPromptedDeathCount != PlayState.deathCounter)
		{
			lastPromptedDeathCount = PlayState.deathCounter;
			var currentSong:String = (songName != null) ? songName.toUpperCase() : "THIS SONG";
			var title:String = utilities.Localization.getString("practice_modal_title", "NEED PRACTICE?");
			var rawMsg:String = utilities.Localization.getString("practice_modal_msg", "You have accumulated {0} attempts on '{1}' (Intensity >= 4).\n\nWould you like to enter Practice Mode to practice the difficult parts?");
			var msg:String = rawMsg.replace("{0}", Std.string(PlayState.deathCounter)).replace("{1}", currentSong);
			var yesText:String = utilities.Localization.getString("practice_modal_yes", "YES, PRACTICE");
			var noText:String = utilities.Localization.getString("practice_modal_no", "NO, CONTINUE");

			openSubState(new PopupSubState(
				title,
				msg,
				yesText,
				noText,
				function() {
					states.PracticeState.targetSongName = (PlayState.SONG != null) ? PlayState.SONG.song : null;
					states.PracticeState.targetDiffName = PlayState.storyDifficultyStr;
					states.PracticeState.fromPlayState = true;
					if (instance != null)
						instance.stopPauseMusic();
					flixel.FlxG.switchState(new states.PracticeState());
				},
				function() {
					if (instance != null)
						instance.justPressedAcceptLol = true;
				}
			));
		}
	}

	override function closeSubState() {
		super.closeSubState();
		justPressedAcceptLol = true;
	}

	override function update(elapsed:Float) {
		if (pauseMusic != null && pauseMusic.volume < MAX_MUSIC_VOLUME)
			pauseMusic.volume += MUSIC_INCREASE_SPEED * elapsed;

		super.update(elapsed);

		if (subState != null) {
			justPressedAcceptLol = true;
			return;
		}

		if (!controls.ACCEPT) justPressedAcceptLol = false;
		if (controls.UP_P) changeSelection(-1);
		if (controls.DOWN_P) changeSelection(1);
		if (FlxG.mouse.wheel != 0) changeSelection(-Math.floor(FlxG.mouse.wheel));

		if (FlxG.keys.justPressed.F6 && PlayState.instance != null) PlayState.instance.toggleBotplay();

		if (menus.get(menu)[curSelected].toLowerCase().contains("skip time"))
			handleSkipTime(elapsed);

		if (controls.ACCEPT && !justPressedAcceptLol) {
			justPressedAcceptLol = true;
			handleSelection(menus.get(menu)[curSelected].toLowerCase());

			return;
		}

		if (controls.BACK || controls.PAUSE || FlxG.keys.justPressed.ESCAPE) {
			if (menu != "default") {
				switchMenu("default");
			} else {
				closePause();
			}
		}
	}

	function handleSkipTime(elapsed:Float) {
		if (FlxG.sound.music == null) return;

		var changed:Bool = false;

		if (controls.LEFT_P) {
			curTime -= 1000;
			holdTime = 0;
			changed = true;
		}
		if (controls.RIGHT_P) {
			curTime += 1000;
			holdTime = 0;
			changed = true;
		}

		if (controls.LEFT || controls.RIGHT) {
			holdTime += elapsed;
			if (holdTime > 0.5) {
				curTime += 45000 * elapsed * (controls.LEFT ? -1 : 1);
				changed = true;
			}

			if (curTime >= FlxG.sound.music.length)
				curTime -= FlxG.sound.music.length;
			else if (curTime < 0)
				curTime += FlxG.sound.music.length;
		}

		if (changed) {
			updateSkipTimeText();
		}
	}

	function updateSkipTimeText() {
		var musicLen = (FlxG.sound.music != null) ? FlxG.sound.music.length : 0;
		var str = "Skip Time "
			+ FlxStringUtil.formatTime(Math.max(0, Math.floor(curTime / 1000)), false)
			+ " / "
			+ FlxStringUtil.formatTime(Math.max(0, Math.floor(musicLen / 1000)), false);

		var options = menus.get(menu);
		if (options != null) {
			for (i in 0...options.length) {
				if (options[i].toLowerCase().contains("skip time")) {
					if (i < grpMenuShit.members.length && grpMenuShit.members[i] != null) {
						grpMenuShit.members[i].text = str;
					}
					break;
				}
			}
		}
	}

	function handleSelection(sel:String) {
		var s = sel.toLowerCase().trim();

		var selItem = (curSelected < grpMenuShit.members.length) ? grpMenuShit.members[curSelected] : null;
		if (selItem != null) {
			if (selItem != null && selItem.scale != null) FlxTween.cancelTweensOf(selItem.scale);
			selItem.scale.set(selectedScale * 1.18, selectedScale * 0.85);
			FlxTween.tween(selItem.scale, {x: selectedScale, y: selectedScale}, 0.2, {ease: FlxEase.backOut});
		}

		if (s == "resume") { closePause(); return; }
		if (s == "restart song") { restartSong(); return; }
		if (s == "quick options") { switchMenu("Quick Options"); return; }
		if (s == "edit keybinds") { openSub(new ControlMenuSubstate()); return; }
		if (s == "change noteskin") { openSub(new UISkinSelect()); return;}
		if (s == "note colors") { openSub(new NoteColorSubstate()); return; }
		if (s == "options") { openOptions(); return; }
		if (s == "back") { switchMenu("default"); return; }
		if (s == "exit to menu") { exitToMenu(); return; }
		if (s == "bot") { toggleOption("botplay", true); return; }
		if (s == "auto restart") { toggleOption("quickRestart"); return; }
		if (s == "no miss") { toggleOption("noHit"); return; }
		if (s == "ghost tapping") { toggleOption("ghostTapping", true); return; }
		if (s == "no death") { toggleOption("noDeath", false); return; }
		if (s == "skip time") { skipTimeAction(); return; }
		if (s.startsWith("play as")) {
			var current:Dynamic = utilities.Options.getData("playAs");
			var cur:String = Std.string(current).toLowerCase().trim();
			if (cur == "" || cur == "null") cur = "bf";

			if (cur == "bf")
				utilities.Options.setData("opponent", "playAs");
			else
				utilities.Options.setData("bf", "playAs");


			updateAlphabets(false);
			return;
		}
		if (s == "change difficulty") {
			openDifficultyMenu();
			return;
		}
			if (menu == "diffMenu" && s == "back") {
				menu = "default";
				updateAlphabets();
				return;
			}
		if (menu == "diffMenu") {
			var selected = menus.get("diffMenu")[curSelected];

			if (selected.toLowerCase() == "back") {
				menu = "default";
				curSelected = 0;
				updateAlphabets();
				return;
			}

			applyDifficulty(selected);
			return;
		}

	}
	function openDifficultyMenu() {
		var currentSong:FreeplaySong = PlayState.currentFreeplaySong;
		if (currentSong == null) return;

		var diffs = currentSong.difficulties;
		if (diffs == null || diffs.length <= 1) return;

		menu = "diffMenu";
		menus.set("diffMenu", ["Back"].concat(diffs));
		curSelected = 0;
		updateAlphabets(false);
	}

	function applyDifficulty(newDiff:String) {
		newDiff = newDiff.toLowerCase();
		if (PlayState.storyDifficultyStr.toLowerCase() == newDiff) return;

		var songName:String = PlayState.SONG.song.toLowerCase();

		if (!CoolUtil.songExists(songName, newDiff)) {
			var sub = new BlockedAndErrorSubState(
				"Chart for difficulty '" + newDiff.toUpperCase() + "' does not exist!",
				"Leather Engine's No Crash, We Help Fix Stuff Tool"
			);
			sub.cameras = cameras;
			openSubState(sub);
			return;
		}

		var newSong = SongLoader.loadFromJson(newDiff, songName);

		if (!Assets.exists(Paths.inst(newSong.song, newDiff))) {
			var sub2 = new BlockedAndErrorSubState(
				"Your song seems to not have an Inst.ogg for this difficulty!",
				"Leather Engine's No Crash, We Help Fix Stuff Tool"
			);
			sub2.cameras = cameras;
			openSubState(sub2);
			return;
		}

		PlayState.SONG = newSong;
		PlayState.storyDifficultyStr = newDiff;

		stopPauseMusic();
		LoadingState.loadAndSwitchState(() -> new PlayState());
	}

	function toggleOption(opt:String, invalidate:Bool = false) {
		utilities.Options.setData(!utilities.Options.getData(opt), opt);
		if (invalidate || (opt != "quickRestart" && opt != "noDeath")) PlayState.SONG.validScore = false;
		showWarning();
	}

	function showWarning() {
		FlxTween.tween(scoreWarning, {alpha: 1}, 0.4, {ease: FlxEase.quartInOut});
		FlxTween.tween(scoreWarning, {alpha: 0}, 0.4, {ease: FlxEase.quartInOut, startDelay: 3});
		warningAmountLols++;
	}

	function closePause() {
		stopPauseMusic();
		if (grpMenuShit != null) {
			for (item in grpMenuShit.members) {
				if (item != null) {
					FlxTween.cancelTweensOf(item);
					if (item.scale != null) FlxTween.cancelTweensOf(item.scale);
				}
			}
		}
		if (PlayState.instance != null)
			PlayState.instance.call("onResume", []);
		close();
	}

	function restartSong() {
		if (grpMenuShit != null) {
			for (item in grpMenuShit.members) {
				if (item != null) {
					FlxTween.cancelTweensOf(item);
					if (item.scale != null) FlxTween.cancelTweensOf(item.scale);
				}
			}
		}
		if (PlayState.instance != null && PlayState.instance.startTimer != null) {
			PlayState.instance.startTimer.cancel();
		}
		FlxTimer.globalManager.clear();
		FlxTween.globalManager.clear();
		resetSongValues();
		PlayState.diedInNoDeath = false;
		if (PlayState.practiceMode) {
			PlayState.SONG.speed = PlayState.previousScrollSpeed;
			PlayState.startOnTime = PlayState.practiceStartTime;
		}

		stopPauseMusic();
		PlayState.deathCounter++;
		FlxG.resetState();
		
	}

	function openOptions() {
		if (grpMenuShit != null) {
			for (item in grpMenuShit.members) {
				if (item != null) {
					FlxTween.cancelTweensOf(item);
					if (item.scale != null) FlxTween.cancelTweensOf(item.scale);
				}
			}
		}
		stopPauseMusic();
		FlxG.switchState(() -> new PauseOptions());
		PlayState.chartingMode = false;
	}

	function exitToMenu() {
		if (PlayState.chartingMode) {
			var exitSub = new ExitChartingSubstate();
			exitSub.cameras = cameras;
			openSubState(exitSub);
			return;
		}

		stopPauseMusic();

		PlayState.chartingMode = PlayState.modchartingMode = false;
		PlayState.botUsed = PlayState.noDeathUsed = PlayState.tooSlow = false;
		PlayState.diedInNoDeath = false;
		PlayState.startOnTime = 0;

		if (PlayState.practiceMode) {
			PlayState.practiceMode = false; 
			FlxG.switchState(new PracticeState());
		}
		else if (PlayState.oneshotMode) {
			PlayState.oneshotMode = false;
			PlayState.oneshotId = "";
			FlxG.switchState(() -> new OneShotsState());
		}
		else {
			FlxG.switchState(
				PlayState.isStoryMode
				? () -> new StoryMenuState()
				: new FreeplayState(GroupSelectState.groupID, GroupSelectState.groupSongs)
			);
		}
	}

	function skipTimeAction() {
		if (curTime < Conductor.songPosition) {
			PlayState.startOnTime = curTime;
			PlayState.SONG.speed = PlayState.previousScrollSpeed;
			PlayState.playCutscenes = true;
			PlayState.SONG.keyCount = PlayState.instance.ogKeyCount;
			PlayState.SONG.playerKeyCount = PlayState.instance.ogPlayerKeyCount;
			stopPauseMusic();
			FlxG.resetState();
		} else {
			if (curTime != Conductor.songPosition) {
				PlayState.instance.clearNotesBefore(curTime);
				PlayState.instance.setSongTime(curTime);
			}
			stopPauseMusic();
			close();
		}
	}

	public function stopPauseMusic() {
		if (pauseMusic != null) {
			pauseMusic.stop();
			pauseMusic.destroy();
			FlxG.sound.list.remove(pauseMusic);
			pauseMusic = null;
		}
		if (pauseCamera != null) {
			if (FlxG.cameras != null && FlxG.cameras.list.contains(pauseCamera)) {
				FlxG.cameras.remove(pauseCamera, true);
			}
			pauseCamera = null;
		}
	}

	function switchMenu(newMenu:String) {
		menu = newMenu;
		updateAlphabets();
	}

	function openSub(sub:FlxSubState) {
		sub.cameras = [pauseCamera];
		openSubState(sub);
	}

	function resetSongValues() {
		PlayState.SONG.speed = PlayState.previousScrollSpeed;
		PlayState.SONG.keyCount = PlayState.instance.ogKeyCount;
		PlayState.SONG.playerKeyCount = PlayState.instance.ogPlayerKeyCount;
		PlayState.SONG.validScore = true;
	}
	var normalScale:Float = 0.85;
	var selectedScale:Float = 1.08; 

	function updateAlphabets(?jump:Bool = true) {
		if (grpMenuShit != null) {
			for (item in grpMenuShit.members) {
				if (item != null) {
					FlxTween.cancelTweensOf(item);
					if (item.scale != null) FlxTween.cancelTweensOf(item.scale);
				}
			}
		}
		grpMenuShit.clear();

		var playAs = utilities.Options.getData("playAs");
		if (playAs == null || playAs == "") {
			playAs = "bf";
			utilities.Options.setData("bf", "playAs");
		}

		var playAsText = playAs == "bf" ? "BF" : "Opponent";
		var options = menus.get(menu);

		for (i in 0...options.length) {
			var item = options[i];
			var displayText = item;

			if (item.toLowerCase().startsWith("play as")) {
				displayText = "Play As: " + playAsText;
			}

			var finalText = displayText;

			if (item.toLowerCase().contains("skip time")) {
				var musicLen = (FlxG.sound.music != null) ? FlxG.sound.music.length : 0;
				finalText =
					"Skip Time "
					+ FlxStringUtil.formatTime(Math.max(0, Math.floor(curTime / 1000)), false)
					+ " / "
					+ FlxStringUtil.formatTime(
						Math.max(0, Math.floor(musicLen / 1000)),
						false
					);
			}

			var songText:DesingText = DesingText.createSongText(
				-280,
				(70 * i) + 30,
				finalText,
				48,
				0,
				desingTextStyle,
				1.0
			);

			songText.scale.set(normalScale, normalScale);
			songText.isMenuItem = true;
			songText.targetY = i;
			songText.targetX = -380;
			songText.ID = i; 
			songText.alpha = 0;
			songText.origin.set(0, songText.height * 0.5);

			grpMenuShit.add(songText);
		}

		if (jump)
			curSelected = 0;
		else
			FlxG.sound.play(Paths.sound("scrollMenu"), 0.4);

		changeSelection(0, true);
	}

	function changeSelection(change:Int = 0, isInitial:Bool = false) {
		if (change != 0)
			FlxG.sound.play(Paths.sound("scrollMenu"), 0.4);

		curSelected = (curSelected + change + menus.get(menu).length) % menus.get(menu).length;

		for (i in 0...grpMenuShit.members.length) {
			var item = grpMenuShit.members[i];
			if (item == null) continue;

			var diffY:Float = i - curSelected;
			item.targetY = diffY;

			var isSelected:Bool = (diffY == 0);
			var absDiff:Float = Math.abs(diffY);

			// Half-roulette / wheel arc on the left side of the screen
			// Circular wheel arc with hub on the left (shifted 100px left per user request)
			var wheelAngle:Float = diffY * 0.22; // In radians (~12.6 deg per step)
			var cosVal:Float = Math.cos(wheelAngle);
			var targetXPos:Float = -40 + (90 * cosVal);
			if (absDiff > 4.5)
				targetXPos = -60; // Park far items cleanly

			item.targetX = targetXPos;

			// Roulette curvature angle tilt (tangent along the wheel perimeter)
			var targetAngle:Float = diffY * -3.2;

			var targetScale:Float = isSelected ? selectedScale : Math.max(0.55, normalScale - (absDiff * 0.05));
			var targetAlpha:Float = isSelected ? 1.0 : Math.max(0.0, 0.70 - (absDiff * 0.16));

			FlxTween.cancelTweensOf(item);
			if (item.scale != null) FlxTween.cancelTweensOf(item.scale);

			if (isInitial) {
				item.x = -260 - (i * 20);
				item.alpha = 0;
				item.angle = targetAngle;
				item.scale.set(targetScale, targetScale);
				FlxTween.tween(item, {alpha: targetAlpha}, 0.35 + (i * 0.035), {
					ease: FlxEase.quartOut
				});
				if (isSelected) {
					item.scale.set(targetScale * 1.15, targetScale * 0.88);
					FlxTween.tween(item.scale, {x: targetScale, y: targetScale}, 0.35 + (i * 0.035), {
						ease: FlxEase.backOut
					});
				}
			} else {
				if (isSelected) {
					item.scale.set(selectedScale * 1.10, selectedScale * 0.92);
					FlxTween.tween(item.scale, {x: selectedScale, y: selectedScale}, 0.22, {
						ease: FlxEase.backOut
					});
					FlxTween.tween(item, {alpha: 1.0, angle: 0}, 0.2, {ease: FlxEase.quartOut});
				} else {
					FlxTween.tween(item.scale, {x: targetScale, y: targetScale}, 0.2, {
						ease: FlxEase.quartOut
					});
					FlxTween.tween(item, {alpha: targetAlpha, angle: targetAngle}, 0.2, {ease: FlxEase.quartOut});
				}
			}
		}
	}

	override function destroy() {
		stopPauseMusic();
		if (grpMenuShit != null) {
			for (item in grpMenuShit.members) {
				if (item != null) {
					FlxTween.cancelTweensOf(item);
					if (item.scale != null) FlxTween.cancelTweensOf(item.scale);
				}
			}
		}
		FlxTween.cancelTweensOf(scoreWarning);
		super.destroy();
	}
}

class PauseOptions extends OptionsMenu {
	override public function goBack() {
		if (pageName != "Categories") {
			loadPage(cast(page.members[0], PageOption).pageName);
			return;
		}
		LoadingState.loadAndSwitchState(() -> new PlayState());
	}
}
