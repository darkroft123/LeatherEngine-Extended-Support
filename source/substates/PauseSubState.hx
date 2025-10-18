package substates;

import states.OptionsMenu;
import flixel.util.FlxStringUtil;
import flixel.FlxCamera;
import game.Conductor;
import states.FreeplayState;
import states.StoryMenuState;
import states.PlayState;
import ui.Alphabet;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import openfl.utils.Assets;
import ui.Option;
import flixel.FlxSubState;

using StringTools;

class PauseSubState extends MusicBeatSubstate {
	var grpMenuShit = new FlxTypedGroup<Alphabet>();
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

	var menus = [
		"default" => ['Resume', 'Restart Song','Quickly Options','Edit Keybinds','Options','Exit To Menu'],
		"Quickly Options" => ['Back', 'Bot', 'Auto Restart', 'No Miss', 'Ghost Tapping', 'No Death']
	];

	public function new() {
		super();
		var skin = PlayState.boyfriend.curCharacter;
		var path = Paths.music('breakfast' + (Assets.exists(Paths.music('breakfast-' + skin, 'shared')) ? '-' + skin : ''), 'shared');
		pauseMusic = new FlxSound().loadEmbedded(path, true, true);
		pauseMusic.volume = 0;
		pauseMusic.play();
		FlxG.sound.list.add(pauseMusic);

		pauseCamera.bgColor.alpha = 0;
		FlxG.cameras.add(pauseCamera, false);

		if (PlayState.chartingMode) {
			var opts = menus.get("default");
			opts.insert(opts.length - 1, "Skip Time");
			menus.set("default", opts);
		}

		var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0;
		bg.scrollFactor.set();
		add(bg);

		var song = new FlxText(20, 15, 0, PlayState.SONG.song, 32);
		song.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);
		song.x = FlxG.width - (song.width + 20);
		add(song);

		var diff = new FlxText(20, 47, 0, PlayState.storyDifficultyStr.toUpperCase(), 32);
		diff.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, RIGHT);
		diff.x = FlxG.width - (diff.width + 20);
		add(diff);

		scoreWarning = new FlxText(20, 79, 0, "Remember, changing options invalidates your score!", 32);
		scoreWarning.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);
		scoreWarning.screenCenter(X);
		add(scoreWarning);

		for (t in [song, diff, scoreWarning]) t.alpha = 0;

		FlxTween.tween(bg, {alpha: 0.35}, 0.4, {ease: FlxEase.quartInOut});
		FlxTween.tween(song, {alpha: 1, y: 20}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.3});
		FlxTween.tween(diff, {alpha: 1, y: diff.y + 5}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.5});
		FlxTween.tween(scoreWarning, {alpha: 1, y: scoreWarning.y + 10}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.7});
		FlxTween.tween(scoreWarning, {alpha: 0, y: scoreWarning.y - 10}, 0.4, {ease: FlxEase.quartInOut, startDelay: 4});

		add(grpMenuShit);
		updateAlphabets();
		cameras = PlayState.instance.usedLuaCameras ? [FlxG.cameras.list[FlxG.cameras.list.length - 1]] : [pauseCamera];
	}

	override function update(elapsed:Float) {
		if (pauseMusic.volume < MAX_MUSIC_VOLUME) pauseMusic.volume += MUSIC_INCREASE_SPEED * elapsed;
		super.update(elapsed);

		if (!controls.ACCEPT) justPressedAcceptLol = false;
		if (controls.UP_P) changeSelection(-1);
		if (controls.DOWN_P) changeSelection(1);
		if (FlxG.mouse.wheel != 0) changeSelection(-Math.floor(FlxG.mouse.wheel));
		if (FlxG.keys.justPressed.F6) PlayState.instance.toggleBotplay();

		if (menus.get(menu)[curSelected].toLowerCase().contains("skip time")) handleSkipTime(elapsed);

		if (controls.ACCEPT && !justPressedAcceptLol) {
			justPressedAcceptLol = true;
			handleSelection(menus.get(menu)[curSelected]);
		}
	}

	function handleSkipTime(elapsed:Float) {
		if (controls.LEFT_P) curTime -= 1000;
		if (controls.RIGHT_P) curTime += 1000;
		if (controls.LEFT || controls.RIGHT) {
			holdTime += elapsed;
			if (holdTime > 0.5) curTime += 45000 * elapsed * (controls.LEFT ? -1 : 1);
			if (curTime >= FlxG.sound.music.length) curTime -= FlxG.sound.music.length;
			if (curTime < 0) curTime += FlxG.sound.music.length;
		}
		updateAlphabets(false, false);
	}

	function updateAlphabets(?jump:Bool = true, ?playSound:Bool = true) {
		grpMenuShit.clear();
		var defaultMenu = menus.get("default").copy();
		var playAs = utilities.Options.getData("playAs");
		defaultMenu = defaultMenu.filter(function(item) return !item.toLowerCase().startsWith("play as"));
		defaultMenu.push("Play As: " + playAs.charAt(0).toUpperCase() + playAs.substr(1));
		menus.set("default", defaultMenu);

		for (i in 0...menus.get(menu).length) {
			var txt = menus.get(menu)[i];
			var content = txt.toLowerCase().contains("skip time") 
				? "Skip Time " + FlxStringUtil.formatTime(Math.floor(curTime / 1000), false) + " / " + FlxStringUtil.formatTime(Math.floor(FlxG.sound.music.length / 1000), false) 
				: txt;
			var songText = new Alphabet(0, (70 * i) + 30, content, true);
			songText.isMenuItem = true;
			songText.targetY = i;
			grpMenuShit.add(songText);
		}

		if (jump && !(menus.get(menu)[curSelected].toLowerCase().startsWith("play as"))) {
			curSelected = 0;
		} 
		else if (playSound) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		changeSelection();
	}

	function handleSelection(sel:String) {
		var s = sel.toLowerCase().trim();
		switch(s) {
			case "resume": closePause(); return;
			case "restart song": restartSong(); return;
			case "quickly options": switchMenu("Quickly Options"); return;
			case "edit keybinds": openSub(new ControlMenuSubstate()); return;
			case "options": openOptions(); return;
			case "back": switchMenu("default"); return;
			case "exit to menu": exitToMenu(); return;
			case "bot": toggleOption("botplay", true); return;
			case "auto restart": toggleOption("quickRestart"); return;
			case "no miss": toggleOption("noHit"); return;
			case "ghost tapping": toggleOption("ghostTapping", true); return;
			case "no death": toggleOption("noDeath", true); return;
			case "skip time": skipTimeAction(); return;
			default:
				if(s.startsWith("play as")) {
					var current = utilities.Options.getData("playAs");
					if(current == "bf") utilities.Options.setData("opponent", "playAs");
					else utilities.Options.setData("bf", "playAs");
					updateAlphabets(false);
					return;
				}
		}
	}

	function toggleOption(opt:String, invalidate:Bool = false) {
		utilities.Options.setData(!utilities.Options.getData(opt), opt);
		if (invalidate || opt != "quickRestart") PlayState.SONG.validScore = false;
		showWarning();
	}

	function showWarning() {
		FlxTween.tween(scoreWarning, {alpha: 1}, 0.4, {ease: FlxEase.quartInOut});
		FlxTween.tween(scoreWarning, {alpha: 0}, 0.4, {ease: FlxEase.quartInOut, startDelay: 3});
		warningAmountLols++;
	}

	function closePause() {
		stopPauseMusic();
		PlayState.instance.call("onResume", []);
		close();
	}

	function restartSong() {
		resetSongValues();
		stopPauseMusic();
		FlxG.resetState();
	}

	function openOptions() {
		stopPauseMusic();
		FlxG.switchState(() -> new PauseOptions());
	}

	function exitToMenu() {
		stopPauseMusic();
		FlxG.switchState(PlayState.isStoryMode ? () -> new StoryMenuState() : new FreeplayState());
	}

	function skipTimeAction() {
		if (curTime < Conductor.songPosition) {
			PlayState.startOnTime = curTime;
			resetSongValues();
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

	function stopPauseMusic() {
		pauseMusic.stop();
		pauseMusic.destroy();
		FlxG.sound.list.remove(pauseMusic);
		FlxG.cameras.remove(pauseCamera);
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

	function changeSelection(change:Int = 0) {
		FlxG.sound.play(Paths.sound('scrollMenu'));
		curSelected = (curSelected + change + menus.get(menu).length) % menus.get(menu).length;
		var i = 0;
		for (item in grpMenuShit.members) {
			item.targetY = i - curSelected;
			item.alpha = item.targetY == 0 ? 1 : 0.6;
			i++;
		}
	}
}

class PauseOptions extends OptionsMenu {
	override public function goBack() {
		if (pageName != "Categories") {
			loadPage(cast(page.members[0], PageOption).pageName);
			return;
		}
		FlxG.switchState(() -> new PlayState());
	}
}
