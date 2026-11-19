package states;

import game.Conductor;
#if sys
import sys.thread.Thread;
import sys.FileSystem;
import sys.io.File;
#end
#if DISCORD_ALLOWED
import utilities.DiscordClient;
#end
import utilities.Options;
import flixel.util.FlxTimer;
import substates.ResetScoreSubstate;
import flixel.sound.FlxSound;
import lime.app.Application;
import flixel.tweens.FlxTween;
import game.SongLoader;
import game.Highscore;
import utilities.CoolUtil;
import ui.HealthIcon;
import ui.Alphabet;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import openfl.utils.Assets;
import flixel.tweens.FlxEase;
import haxe.Json;

using StringTools;

class FreeplayState extends MusicBeatState {
	public static var songs:Array<SongMetadata> = [];

	var selector:FlxText;

	public static var curSelected:Int = 0;
	public static var curDifficulty:Int = 1;
	public static var curSpeed:Float = 1;

	var scoreText:FlxText;
	var diffText:FlxText;
	var speedText:FlxText;
	var lerpScore:Int = 0;
	var intendedScore:Int = 0;

	private var grpSongs:FlxTypedGroup<Alphabet>;
	private var curPlaying:Bool = false;

	private var iconArray:Array<HealthIcon> = [];

	public static var songsReady:Bool = false;

	public static var coolColors:Array<Int> = [
		0xFF7F1833,
		0xFF7C689E,
		-14535868,
		0xFFA8E060,
		0xFFFF87FF,
		0xFF8EE8FF,
		0xFFFF8CCD,
		0xFFFF9900
	];

	private var bg:FlxSprite;
	private var selectedColor:Int = 0xFF7F1833;
	private var scoreBG:FlxSprite;

	private var curRank:String = "N/A";

	private var curDiffString:String = "normal";
	private var curDiffArray:Array<String> = ["easy", "normal", "hard"];

	var vocals:FlxSound = new FlxSound();

	var canEnterSong:Bool = true;

	var colorTween:FlxTween;

	#if (cpp && sys)
	public var loading_songs:Thread;
	public var stop_loading_songs:Bool = false;
	#end

	var ui_Skin:Null<String>;
	var lastSelectedSong:Int = -1;

	public function new() {
		super();
	}

	override function create() {
		super.create();

		if (ui_Skin == null || ui_Skin == "default")
			ui_Skin = Options.getData("uiSkin");

		MusicBeatState.windowNameSuffix = " Freeplay";

		songs = [];
		iconArray = [];

		loadSongs();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Freeplay Menu", null);
		#end

		var menuBGPath:String = 'ui skins/' + ui_Skin + '/backgrounds/menuDesat';
		if (!Assets.exists(Paths.image(menuBGPath)))
			menuBGPath = 'ui skins/default/backgrounds/menuDesat';

		if (Assets.exists(Paths.image(menuBGPath)))
			bg = new FlxSprite().loadGraphic(Paths.image(menuBGPath));
		else
			bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.fromString("#E1E1E1"));

		add(bg);

		grpSongs = new FlxTypedGroup<Alphabet>();
		add(grpSongs);

		scoreText = new FlxText(FlxG.width, 5, 0, "", 32);

		scoreBG = new FlxSprite(scoreText.x - 6, 0).makeGraphic(1, 1, 0xFF000000);
		scoreBG.alpha = 0.6;
		add(scoreBG);

		scoreText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);
		add(scoreText);

		diffText = new FlxText(FlxG.width, scoreText.y + 36, 0, "", 24);
		diffText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, RIGHT);
		add(diffText);

		speedText = new FlxText(FlxG.width, diffText.y + 36, 0, "", 24);
		speedText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, RIGHT);
		add(speedText);

		for (i in 0...songs.length) {
			var songText:Alphabet = new Alphabet(0, (70 * i) + 30, songs[i].songName, true, false);
			songText.isMenuItem = true;
			songText.targetY = i;
			grpSongs.add(songText);

			if (Options.getData("healthIcons")) {
				var icon:HealthIcon = new HealthIcon(songs[i].songCharacter);
				icon.sprTracker = songText;
				iconArray.push(icon);
				add(icon);
			}
		}

		if (curSelected >= songs.length)
			curSelected = 0;

		if (songs.length > 0) {
			selectedColor = songs[curSelected].color;
			bg.color = selectedColor;
		}

		var textBG:FlxSprite = new FlxSprite(0, FlxG.height - 26).makeGraphic(FlxG.width, 26, 0xFF000000);
		textBG.alpha = 0.6;
		add(textBG);

		var text:FlxText = new FlxText(textBG.x - 1, textBG.y + 4, FlxG.width,
			"Press RESET to reset song score and rank ~ Press SPACE to play Song Audio ~ Shift + LEFT and RIGHT to change song speed",
			16);
		text.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, RIGHT);
		text.scrollFactor.set();
		add(text);

		songsReady = true;

		if (songs.length > 0)
			changeSelection();
	}

	function loadSongs():Void {
		var loadedFromMod:Bool = false;

		#if MODDING_ALLOWED
		var curMod:String = Options.getData("curMod");
		if (curMod != null && curMod != "") {
			var modJsonPath:String = 'mods/$curMod/data/freeplay.json';
			if (FileSystem.exists(modJsonPath)) {
				try {
					var rawJson = File.getContent(modJsonPath);
					var parsed:Dynamic = Json.parse(rawJson);
					if (parsed != null && parsed.songs != null) {
						var jsonSongs:Array<Dynamic> = parsed.songs;
						for (s in jsonSongs) {
							var sName:String = s.name;
							var sWeek:Int = s.week != null ? s.week : 0;
							var sIcon:String = s.icon != null ? s.icon : "bf";
							var sDiffs:Array<String> = (s.difficulties != null && s.difficulties.length > 0) ? s.difficulties : ["easy", "normal", "hard"];
							var sColor:Null<FlxColor> = (s.color != null && s.color != "") ? FlxColor.fromString(s.color) : null;
							songs.push(new SongMetadata(sName, sWeek, sIcon, sDiffs, sColor));
						}
						loadedFromMod = true;
					}
				} catch (e:Dynamic) {
					trace("Error parsing mod freeplay.json: " + e);
				}
			}

			if (!loadedFromMod) {
				var modTxtPath:String = 'mods/$curMod/data/freeplaySonglist.txt';
				if (FileSystem.exists(modTxtPath)) {
					var lines = CoolUtil.coolTextFileSys(modTxtPath);
					for (line in lines) {
						if (line.trim() != "") {
							var parts = line.split(":");
							var sName = parts[0];
							var sIcon = parts.length > 1 ? parts[1] : "bf";
							var sWeek = parts.length > 2 ? Std.parseInt(parts[2]) : 0;
							var sDiffs = parts.length > 3 ? parts[3].split(",") : ["easy", "normal", "hard"];
							var sColor:Null<FlxColor> = (parts.length > 4 && parts[4] != null) ? FlxColor.fromString(parts[4]) : null;
							songs.push(new SongMetadata(sName, sWeek, sIcon, sDiffs, sColor));
						}
					}
					if (songs.length > 0)
						loadedFromMod = true;
				}
			}
		}
		#end

		if (!loadedFromMod) {
			if (Assets.exists(Paths.json('freeplay'))) {
				try {
					var rawJson = Assets.getText(Paths.json('freeplay'));
					var parsed:Dynamic = Json.parse(rawJson);
					if (parsed != null && parsed.songs != null) {
						var jsonSongs:Array<Dynamic> = parsed.songs;
						for (s in jsonSongs) {
							var sName:String = s.name;
							var sWeek:Int = s.week != null ? s.week : 0;
							var sIcon:String = s.icon != null ? s.icon : "bf";
							var sDiffs:Array<String> = (s.difficulties != null && s.difficulties.length > 0) ? s.difficulties : ["easy", "normal", "hard"];
							var sColor:Null<FlxColor> = (s.color != null && s.color != "") ? FlxColor.fromString(s.color) : null;
							songs.push(new SongMetadata(sName, sWeek, sIcon, sDiffs, sColor));
						}
					}
				} catch (e:Dynamic) {}
			}

			if (songs.length == 0 && Assets.exists(Paths.txt('freeplaySonglist'))) {
				var lines = CoolUtil.coolTextFile(Paths.txt('freeplaySonglist'));
				for (line in lines) {
					if (line.trim() != "") {
						var parts = line.split(":");
						var sName = parts[0];
						var sIcon = parts.length > 1 ? parts[1] : "bf";
						var sWeek = parts.length > 2 ? Std.parseInt(parts[2]) : 0;
						var sDiffs = parts.length > 3 ? parts[3].split(",") : ["easy", "normal", "hard"];
						var sColor:Null<FlxColor> = (parts.length > 4 && parts[4] != null) ? FlxColor.fromString(parts[4]) : null;
						songs.push(new SongMetadata(sName, sWeek, sIcon, sDiffs, sColor));
					}
				}
			}
		}
	}

	override function update(elapsed:Float) {
		super.update(elapsed);

		if (FlxG.sound.music != null && FlxG.sound.music.playing)
			Conductor.songPosition = FlxG.sound.music.time;

		for (i in 0...iconArray.length) {
			if (i == lastSelectedSong)
				continue;
			iconArray[i].scale.set(1, 1);
		}

		if (lastSelectedSong != -1 && iconArray[lastSelectedSong] != null)
			iconArray[lastSelectedSong].scale.set(
				FlxMath.lerp(iconArray[lastSelectedSong].scale.x, 1, elapsed * 9),
				FlxMath.lerp(iconArray[lastSelectedSong].scale.y, 1, elapsed * 9)
			);

		lerpScore = Math.floor(FlxMath.lerp(lerpScore, intendedScore, 0.4));
		if (Math.abs(lerpScore - intendedScore) <= 10)
			lerpScore = intendedScore;

		var funnyObject:FlxText = scoreText;
		if (speedText.width >= scoreText.width && speedText.width >= diffText.width)
			funnyObject = speedText;
		if (diffText.width >= scoreText.width && diffText.width >= speedText.width)
			funnyObject = diffText;

		scoreBG.x = funnyObject.x - 6;
		if (Std.int(scoreBG.width) != Std.int(funnyObject.width + 6))
			scoreBG.makeGraphic(Std.int(funnyObject.width + 6), 108, FlxColor.BLACK);

		scoreText.x = FlxG.width - scoreText.width;
		scoreText.text = "PERSONAL BEST:" + lerpScore;

		diffText.x = FlxG.width - diffText.width;

		curSpeed = FlxMath.roundDecimal(curSpeed, 2);
		if (curSpeed < 0.25)
			curSpeed = 0.25;

		speedText.text = "Speed: " + curSpeed + " (R+SHIFT)";
		speedText.x = FlxG.width - speedText.width;

		var leftP = controls.LEFT_P;
		var rightP = controls.RIGHT_P;
		var shift = FlxG.keys.pressed.SHIFT;
		var upP = controls.UP_P;
		var downP = controls.DOWN_P;

		if (songsReady && songs.length > 0) {
			if (-1 * Math.floor(FlxG.mouse.wheel) != 0 && !shift)
				changeSelection(-1 * Math.floor(FlxG.mouse.wheel));
			else if (-1 * (Math.floor(FlxG.mouse.wheel) / 10) != 0 && shift)
				curSpeed += -1 * (Math.floor(FlxG.mouse.wheel) / 10);

			if (upP)
				changeSelection(-1);
			if (downP)
				changeSelection(1);

			if (leftP && !shift)
				changeDiff(-1);
			else if (leftP && shift)
				curSpeed -= 0.05;

			if (rightP && !shift)
				changeDiff(1);
			else if (rightP && shift)
				curSpeed += 0.05;

			if (FlxG.keys.justPressed.R && shift)
				curSpeed = 1;

			if (controls.BACK) {
				if (colorTween != null)
					colorTween.cancel();

				destroyFreeplayVocals();
				if (FlxG.sound.music != null && FlxG.sound.music.playing)
					FlxG.sound.music.pitch = 1;

				FlxG.switchState(() -> new MainMenuState());
			}

			if (FlxG.keys.justPressed.SPACE) {
				destroyFreeplayVocals();

				var songKey:String = songs[curSelected].songName.toLowerCase();
				var voicePath = Paths.voices(songKey, curDiffString.toLowerCase());
				if (voicePath != null && Assets.exists(voicePath))
					vocals = new FlxSound().loadEmbedded(voicePath);
				else
					vocals = new FlxSound();

				vocals.persist = false;
				vocals.looped = true;
				vocals.volume = 0.7;
				FlxG.sound.list.add(vocals);

				var instPath = Paths.inst(songKey, curDiffString.toLowerCase());
				FlxG.sound.music = new FlxSound().loadEmbedded(instPath);
				FlxG.sound.music.persist = true;
				FlxG.sound.music.looped = true;
				FlxG.sound.music.volume = 0.7;
				FlxG.sound.list.add(FlxG.sound.music);

				FlxG.sound.music.play();
				vocals.play();

				lastSelectedSong = curSelected;
			}

			if (FlxG.sound.music != null && FlxG.sound.music.active && FlxG.sound.music.playing && !FlxG.keys.justPressed.ENTER)
				FlxG.sound.music.pitch = curSpeed;
			if (vocals != null && vocals.active && vocals.playing && !FlxG.keys.justPressed.ENTER)
				vocals.pitch = curSpeed;

			if (controls.RESET && !shift) {
				openSubState(new ResetScoreSubstate(songs[curSelected].songName, curDiffString));
				changeSelection();
			}

			if (FlxG.keys.justPressed.ENTER && canEnterSong) {
				try {
					PlayState.SONG = SongLoader.loadFromJson(curDiffString.toLowerCase(), songs[curSelected].songName.toLowerCase());
					PlayState.isStoryMode = false;
					PlayState.songMultiplier = curSpeed;
					PlayState.storyDifficultyStr = curDiffString.toUpperCase();
					PlayState.storyWeek = songs[curSelected].week;

					if (colorTween != null)
						colorTween.cancel();

					PlayState.loadChartEvents = true;
					destroyFreeplayVocals();
					LoadingState.loadAndSwitchState(() -> new PlayState());
				} catch (e:Dynamic) {
					trace("Error starting song: " + e);
				}
			}
		}
	}

	override function closeSubState() {
		changeSelection();
		FlxG.mouse.visible = false;
		super.closeSubState();
	}

	function changeDiff(change:Int = 0) {
		if (curDiffArray.length == 0)
			return;

		curDifficulty = FlxMath.wrap(curDifficulty + change, 0, curDiffArray.length - 1);
		curDiffString = curDiffArray[curDifficulty].toUpperCase();

		intendedScore = Highscore.getScore(songs[curSelected].songName, curDiffString);
		curRank = Highscore.getSongRank(songs[curSelected].songName, curDiffString);

		if (curDiffArray.length > 1)
			diffText.text = "< " + curDiffString + " ~ " + curRank + " >";
		else
			diffText.text = curDiffString + " ~ " + curRank + "  ";
	}

	function changeSelection(change:Int = 0) {
		if (songs.length == 0)
			return;

		curSelected = FlxMath.wrap(curSelected + change, 0, grpSongs.length - 1);

		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		if (Options.getData("freeplayMusic")) {
			FlxG.sound.playMusic(Paths.inst(songs[curSelected].songName.toLowerCase(), curDiffString.toLowerCase()), 0.7);
			if (vocals.active && vocals.playing)
				destroyFreeplayVocals(false);
		}

		curDiffArray = songs[curSelected].difficulties;
		if (curDifficulty >= curDiffArray.length)
			curDifficulty = 0;

		changeDiff();

		var bullShit:Int = 0;

		if (iconArray.length > 0) {
			for (i in 0...iconArray.length) {
				iconArray[i].alpha = 0.6;
				if (iconArray[i].animation.curAnim != null && !iconArray[i].animatedIcon)
					iconArray[i].animation.curAnim.curFrame = 0;
			}

			if (iconArray[curSelected] != null) {
				iconArray[curSelected].alpha = 1;
				if (iconArray[curSelected].animation.curAnim != null && !iconArray[curSelected].animatedIcon) {
					iconArray[curSelected].animation.curAnim.curFrame = 2;
					if (iconArray[curSelected].animation.curAnim.curFrame != 2)
						iconArray[curSelected].animation.curAnim.curFrame = 0;
				}
			}
		}

		for (item in grpSongs.members) {
			item.targetY = bullShit - curSelected;
			bullShit++;

			item.alpha = 0.6;

			if (item.targetY == 0) {
				item.alpha = 1;
			}
		}

		if (change != 0) {
			var newColor:FlxColor = songs[curSelected].color;
			if (newColor != selectedColor) {
				if (colorTween != null)
					colorTween.cancel();

				selectedColor = newColor;
				colorTween = FlxTween.color(bg, 0.25, bg.color, selectedColor, {
					onComplete: function(twn:FlxTween) {
						colorTween = null;
					}
				});
			}
		} else {
			bg.color = songs[curSelected].color;
		}
	}

	public function destroyFreeplayVocals(?destroyInst:Bool = true) {
		if (vocals != null) {
			vocals.stop();
			vocals.destroy();
		}
		vocals = null;

		if (!destroyInst)
			return;

		if (FlxG.sound.music != null) {
			FlxG.sound.music.stop();
			FlxG.sound.music.destroy();
		}
		FlxG.sound.music = null;
	}

	override function beatHit() {
		super.beatHit();

		if (lastSelectedSong != -1 && iconArray[lastSelectedSong] != null)
			iconArray[lastSelectedSong].scale.add(0.2, 0.2);
	}
}

class SongMetadata {
	public var songName:String = "";
	public var name(get, set):String;
	inline function get_name():String return songName;
	inline function set_name(v:String):String return songName = v;

	public var week:Int = 0;
	public var songCharacter:String = "";
	public var difficulties:Array<String> = ["easy", "normal", "hard"];
	public var color:FlxColor = FlxColor.GREEN;

	public function new(song:String, week:Int, songCharacter:String, ?difficulties:Array<String>, ?color:FlxColor) {
		this.songName = song;
		this.week = week;
		this.songCharacter = songCharacter;

		if (difficulties != null)
			this.difficulties = difficulties;

		if (color != null)
			this.color = color;
		else {
			if (FreeplayState.coolColors.length - 1 >= this.week)
				this.color = FreeplayState.coolColors[this.week];
			else
				this.color = FreeplayState.coolColors[0];
		}
	}
}
