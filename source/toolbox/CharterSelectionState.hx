package toolbox;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import sys.io.File;
import sys.FileSystem;
import haxe.Json;
import lime.utils.Assets;
import flixel.util.FlxTimer;

import states.MusicBeatState;
import states.PlayState;
import ui.Alphabet;
import ui.HealthIcon;
import game.FreeplaySong;
import game.SongLoader;

class CharterSelectionState extends MusicBeatState
{
	var songs:Array<FreeplaySong> = [];
	var curSelected:Int = 0;
	var curDifficulty:Int = 0;
	var grpSongs:FlxTypedGroup<Alphabet>;
	var grpIcons:Array<Array<HealthIcon>> = [];
	var bg:FlxSprite;
	var diffText:FlxText;
	
	var currentPlayingTrack:String = "";
	var playDelayTimer:FlxTimer;

	override function create()
	{
		super.create();

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFF353535;
		add(bg);

		grpSongs = new FlxTypedGroup<Alphabet>();
		add(grpSongs);

		loadSongs();

		for (i in 0...songs.length)
		{
			var songText:Alphabet = new Alphabet(90, 320, songs[i].name, true);
			songText.isMenuItem = true;
			songText.targetY = i;
			grpSongs.add(songText);

			var iconData:Array<Dynamic> = [];
			if (Std.isOfType(songs[i].icon, String)) {
				iconData.push({name: songs[i].icon, offsetX: 0, offsetY: 0});
			} else if (Std.isOfType(songs[i].icon, Array)) {
				for (item in cast(songs[i].icon, Array<Dynamic>)) {
					if (Std.isOfType(item, String))
						iconData.push({name: item, offsetX: 0, offsetY: 0});
					else
						iconData.push(item);
				}
			} else {
				// Fallback to "face" if it's some other complex format like difficulty-specific icons
				iconData.push({name: "face", offsetX: 0, offsetY: 0});
			}
			
			var songIcons:Array<HealthIcon> = [];
			var j = 0;
			for (info in iconData) {
				var icon = new HealthIcon(info.name);
				icon.sprTracker = songText;
				icon.offset.set(info.offsetX, info.offsetY);
				icon.xOffset = 10 + (j * 150); // Spacing between multiple icons
				songIcons.push(icon);
				add(icon);
				j++;
			}
			grpIcons.push(songIcons);
		}

		diffText = new FlxText(0, FlxG.height - 44, FlxG.width, "< NORMAL >", 24);
		diffText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		diffText.scrollFactor.set();
		diffText.borderSize = 2;
		add(diffText);

		changeSelection();
	}

	function loadSongs()
	{
		var path:String = #if MODDING_ALLOWED 'mods/${Options.getData("curMod")}/data/freeplay.json'; #else 'assets/data/freeplay.json'; #end
		if (FileSystem.exists(path))
		{
			var rawData:Dynamic = Json.parse(File.getContent(path));
			songs = cast rawData.songs;
		}
		
		if (songs == null) songs = [];
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (controls.UP_P)
			changeSelection(-1);
		if (controls.DOWN_P)
			changeSelection(1);

		if (controls.LEFT_P)
			changeDifficulty(-1);
		if (controls.RIGHT_P)
			changeDifficulty(1);

		if (controls.BACK)
		{
			if (playDelayTimer != null)
				playDelayTimer.cancel();

			if (currentPlayingTrack != "")
				FlxG.sound.playMusic(Paths.music('freakyMenu'));

			FlxG.sound.play(Paths.sound('cancelMenu'));
			FlxG.switchState(() -> new toolbox.ToolboxState());
		}
		
		if (controls.ACCEPT)
		{
			if (songs.length == 0) return;
			
			if (playDelayTimer != null)
				playDelayTimer.cancel();
			
			var song = songs[curSelected];
			var diffs = (song.difficulties != null && song.difficulties.length > 0) ? song.difficulties : ["normal"];
			var diff = diffs[curDifficulty];
			if (diff == null) diff = "normal";
			
			PlayState.SONG = SongLoader.loadFromJson(diff, song.name.toLowerCase());
			PlayState.storyDifficultyStr = diff.toUpperCase();
			PlayState.practiceMode = false;
			PlayState.isStoryMode = false;
			
			if (PlayState.instance == null) {
				PlayState.instance = new states.PlayState();
				@:privateAccess PlayState.instance.setupUISkinConfigs("default");
			}

			FlxG.sound.play(Paths.sound('confirmMenu'));
			FlxG.switchState(() -> new toolbox.ChartingState());
		}
	}

	function changeSelection(change:Int = 0)
	{
		if (songs.length == 0) return;
		
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		curSelected += change;

		if (curSelected < 0)
			curSelected = songs.length - 1;
		if (curSelected >= songs.length)
			curSelected = 0;

		var bullShit:Int = 0;
		for (i in 0...grpSongs.members.length)
		{
			var item = grpSongs.members[i];
			item.targetY = bullShit - curSelected;
			bullShit++;
			item.alpha = 0.6;
			if (item.targetY == 0)
				item.alpha = 1;

			if (grpIcons[i] != null) {
				for (icon in grpIcons[i]) {
					icon.alpha = item.alpha;
				}
			}
		}

		curDifficulty = 0;
		changeDifficulty(0);
	}

	function changeDifficulty(change:Int = 0)
	{
		if (songs.length == 0) return;
		
		var song = songs[curSelected];
		var diffs = (song.difficulties != null && song.difficulties.length > 0) ? song.difficulties : ["normal"];
		
		curDifficulty += change;
		if (curDifficulty < 0)
			curDifficulty = diffs.length - 1;
		if (curDifficulty >= diffs.length)
			curDifficulty = 0;

		var currentDiffName = diffs[curDifficulty];
		if (currentDiffName == null) currentDiffName = "normal";

		diffText.text = "< " + currentDiffName.toUpperCase() + " >";

		checkPlayMusic();
	}

	function checkPlayMusic()
	{
		if (Options.getData("freeplayMusic") && songs.length > 0)
		{
			var song = songs[curSelected];
			var diffs = (song.difficulties != null && song.difficulties.length > 0) ? song.difficulties : ["normal"];
			var diff = diffs[curDifficulty];
			if (diff == null) diff = "normal";

			var nextTrack:String = Paths.inst(song.name, diff.toLowerCase());
			if (nextTrack == currentPlayingTrack)
				return;
			
			if (playDelayTimer != null)
				playDelayTimer.cancel();

			playDelayTimer = new FlxTimer().start(0.5, function(tmr:FlxTimer)
			{
				if (FlxG.sound.music != null)
				{
					FlxG.sound.music.stop();
					FlxG.sound.music.destroy();
					FlxG.sound.music = null;
				}

				FlxG.sound.playMusic(nextTrack, 1.0);
				if (FlxG.sound.music != null)
				{
					FlxG.sound.music.time = FlxG.sound.music.length / 2;
				}

				currentPlayingTrack = nextTrack;
			});
		}
	}

	override function destroy()
	{
		if (playDelayTimer != null)
		{
			playDelayTimer.cancel();
			playDelayTimer = null;
		}
		super.destroy();
	}
}
