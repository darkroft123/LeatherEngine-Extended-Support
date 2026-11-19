package states;

import flixel.FlxSprite;
import flixel.FlxG;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextBorderStyle;
import flixel.addons.text.FlxTypeText;
import flixel.util.FlxColor;
import flixel.FlxCamera;
import game.Conductor;
import game.SongLoader;
import game.Highscore;
import shaders.Shaders.GreyscaleEffect;
import shaders.Shaders.SnowCutEffect;
import haxe.Json;
import sys.io.File;
import sys.FileSystem;
#if DISCORD_ALLOWED
import utilities.DiscordClient;
#end
import flixel.math.FlxMath;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import utilities.Localization;
import utilities.MenuAnims;

class OneShotsState extends MusicBeatState
{
	var bgCam:FlxCamera;
	var uiCam:FlxCamera;
	var bgSprite:FlxSprite;

	
	var coverGreyscale:GreyscaleEffect;
	var snowCutShader:SnowCutEffect;
	var targetHue1:Float = 0.0;
	var targetHue2:Float = 0.0;
	var targetSpecialRotation:Float = 0.0;

	var titleText:FlxText;

	var logo:FlxSprite;

	var coverSprite:FlxSprite;
	var coverBaseY:Float = 0;
	var hasCover:Bool = false;
	var coverSetupDone:Bool = false;

	var statsText:FlxText;
	var markSprite:FlxSprite;

	var songNameText:FlxText;
	var descText:FlxTypeText;

	var diffText:FlxText;
	var leftDiff:FlxSprite;
	var rightDiff:FlxSprite;

	var leftArrow:FlxSprite;
	var rightArrow:FlxSprite;

	var playButton:FlxSprite;
	var playText:FlxText;

	var coverOverlay:FlxSprite;
	var blockIcon:FlxSprite;

	var oneshots:Array<Dynamic>;
	var curOneshot:Int = 0;
	var curSong:Int = 0;
	var curDifficulty:Int = 0;
		public var time:Float = 0;
	var unlockedSongs:Array<Bool> = [];

	var startingSong:Bool = false;
	var canInteract:Bool = true;
	var currentMusic:String = "";

	var fontPath:String = "Contb___.ttf";

	override public function create():Void
	{
		MusicBeatState.windowNameSuffix = Localization.getString("oneshots_window_title", " - One-Shots");

		#if DISCORD_ALLOWED
		DiscordClient.changePresence(Localization.getString("oneshots_discord_presence", "One-Shots Menu"), null, null, false, 0, "yobien");
		#end

		FlxG.mouse.visible = true;

		loadOneshotsData();

		coverGreyscale = new GreyscaleEffect();
		coverGreyscale.radius = 0.035;
		coverGreyscale.borderSize = 0.0075;
		coverGreyscale.smoothness = 0.001;
		coverGreyscale.bordersEnabled = true;
		coverGreyscale.update(0);

		bgCam = new FlxCamera();
		bgCam.bgColor = 0x00000000;
		FlxG.cameras.add(bgCam, false);

		uiCam = new FlxCamera();
		uiCam.bgColor = 0x00000000;
		FlxG.cameras.add(uiCam, false);

		

		snowCutShader = new SnowCutEffect();
		snowCutShader.hue1 = 0.0;
		snowCutShader.hue2 = 0.8333;
		snowCutShader.specialRotation = 45.0;

		bgSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.TRANSPARENT);
		bgSprite.shader = snowCutShader.shader;
		bgSprite.cameras = [bgCam];
		add(bgSprite);
		
		buildUI();

		if (oneshots.length > 0)
		{
			curOneshot = PlayState.lastCurOneshot;
			if (curOneshot < 0 || curOneshot >= oneshots.length)
				curOneshot = 0;
			curSong = 0;
			curDifficulty = 0;
			refreshOneshot();
			refreshSong();
		}

		playEntrance();

		super.create();
	}

	function loadOneshotsData():Void
	{
		var path:String = #if MODDING_ALLOWED 'mods/${Options.getData("curMod")}/data/oneshots.json'; #else 'assets/data/oneshots.json'; #end

		if (FileSystem.exists(path))
		{
			var rawData:Dynamic = Json.parse(File.getContent(path));
			oneshots = cast rawData.oneshots;
		}
		else
		{
			oneshots = [];
		}

		if (oneshots.length == 0)
		{
			var fallback = {
				"oneshots": [
					{
						"id": "empty",
						"title": Localization.getString("oneshots_no_available", "No One-Shots Available"),
						"logo": "",
						"songs": []
					}
				]
			};
			oneshots = fallback.oneshots;
		}
	}

	function buildUI():Void
	{
		coverSprite = new FlxSprite(80, 200);
		coverSprite.scrollFactor.set(0, 0);
		coverSprite.shader = coverGreyscale.shader;
		coverSprite.cameras = [uiCam];
		add(coverSprite);
		coverBaseY = 200;

		coverOverlay = new FlxSprite(80, 200);
		coverOverlay.makeGraphic(400, 400, FlxColor.BLACK);
		coverOverlay.scrollFactor.set(0, 0);
		coverOverlay.alpha = 0;
		coverOverlay.cameras = [uiCam];
		add(coverOverlay);

		blockIcon = new FlxSprite(0, 0);
		try {
			blockIcon.loadGraphic(Paths.gpuBitmap("oneshots/locked"));
		} catch (e:Dynamic) {
			blockIcon.makeGraphic(1, 1, FlxColor.TRANSPARENT);
		}
		blockIcon.scrollFactor.set(0, 0);
		blockIcon.visible = false;
		blockIcon.cameras = [uiCam];
		add(blockIcon);

		titleText = new FlxText(0, 0, 400, "", 64);
		titleText.setFormat(Paths.font(fontPath), 48, FlxColor.WHITE, CENTER);
		titleText.borderStyle = FlxTextBorderStyle.OUTLINE;
		titleText.borderColor = FlxColor.BLACK;
		titleText.borderSize = 2;
		titleText.cameras = [uiCam];
		add(titleText);

		leftArrow = createArrow(0, 0, "<");
		leftArrow.cameras = [uiCam];
		add(leftArrow);

		rightArrow = createArrow(0, 0, ">");
		rightArrow.cameras = [uiCam];
		add(rightArrow);

		statsText = new FlxText(0, 0, 600, "", 28);
		statsText.setFormat(Paths.font(fontPath), 28, FlxColor.WHITE, CENTER);
		statsText.borderStyle = FlxTextBorderStyle.OUTLINE;
		statsText.borderColor = FlxColor.BLACK;
		statsText.borderSize = 1;
		statsText.cameras = [uiCam];
		add(statsText);

		markSprite = new FlxSprite(0, 0);
		markSprite.makeGraphic(16, 16, FlxColor.GRAY);
		markSprite.scrollFactor.set(0, 0);
		markSprite.cameras = [uiCam];
		add(markSprite);

		logo = new FlxSprite(0, 0);
		logo.scrollFactor.set(0, 0);
		logo.cameras = [uiCam];
		add(logo);

		leftDiff = createArrow(0, 0, "<");
		leftDiff.cameras = [uiCam];
		add(leftDiff);

		diffText = new FlxText(0, 0, 200, "", 22);
		diffText.setFormat(Paths.font(fontPath), 22, FlxColor.WHITE, CENTER);
		diffText.borderStyle = FlxTextBorderStyle.OUTLINE;
		diffText.borderColor = FlxColor.BLACK;
		diffText.borderSize = 2;
		diffText.cameras = [uiCam];
		add(diffText);

		rightDiff = createArrow(0, 0, ">");
		rightDiff.cameras = [uiCam];
		add(rightDiff);

		descText = new FlxTypeText(0, 0, 350, "", 32);
		descText.setFormat(Paths.font(fontPath), 32, FlxColor.WHITE, CENTER);
		descText.borderStyle = FlxTextBorderStyle.OUTLINE;
		descText.borderColor = FlxColor.BLACK;
		descText.borderSize = 1;
		descText.wordWrap = true;
		descText.cameras = [uiCam];
		add(descText);

		songNameText = new FlxText(0, 0, 400, "", 28);
		songNameText.setFormat(Paths.font(fontPath), 28, FlxColor.WHITE, CENTER);
		songNameText.borderStyle = FlxTextBorderStyle.OUTLINE;
		songNameText.borderColor = FlxColor.BLACK;
		songNameText.borderSize = 2;
		songNameText.letterSpacing = 3;
		songNameText.cameras = [uiCam];
		add(songNameText);

		playButton = new FlxSprite(0, 0);
		playButton.makeGraphic(200, 50, FlxColor.fromRGB(30, 30, 30));
		playButton.scrollFactor.set(0, 0);
		playButton.cameras = [uiCam];
		add(playButton);

		playText = new FlxText(0, 0, 200, Localization.getString("oneshots_play", "PLAY"), 24);
		playText.setFormat(Paths.font(fontPath), 24, FlxColor.WHITE, CENTER);
		playText.borderStyle = FlxTextBorderStyle.OUTLINE;
		playText.borderColor = FlxColor.BLACK;
		playText.borderSize = 1;
		playText.cameras = [uiCam];
		add(playText);
	}

	function createArrow(x:Float, y:Float, char:String):FlxSprite
	{
		var arrow = new FlxSprite(x, y);
		arrow.makeGraphic(40, 40, FlxColor.fromRGB(50, 50, 50));
		arrow.scrollFactor.set(0, 0);

		var arrowText = new FlxText(0, 0, 40, char, 24);
		arrowText.setFormat(Paths.font(fontPath), 24, FlxColor.WHITE, CENTER);
		arrowText.y = (40 - arrowText.height) / 2;

		var container = new FlxSprite(x, y);
		container.makeGraphic(40, 40, FlxColor.TRANSPARENT);
		container.scrollFactor.set(0, 0);

		return arrow;
	}

	function playEntrance():Void
	{
		if (coverSprite != null)
		{
			coverSprite.alpha = 0;
			FlxTween.tween(coverSprite, {alpha: 1}, 0.42, {ease: FlxEase.quartOut});
		}
		if (titleText != null)
		{
			titleText.alpha = 0;
			FlxTween.tween(titleText, {alpha: 1}, 0.38, {ease: FlxEase.quartOut});
		}
		if (songNameText != null)
		{
			songNameText.alpha = 0;
			FlxTween.tween(songNameText, {alpha: 1}, 0.40, {ease: FlxEase.quartOut, startDelay: 0.06});
		}
		if (statsText != null)
		{
			statsText.alpha = 0;
			FlxTween.tween(statsText, {alpha: 1}, 0.40, {ease: FlxEase.quartOut, startDelay: 0.10});
		}
		if (playButton != null && playText != null)
		{
			playButton.alpha = 0;
			playText.alpha = 0;
			FlxTween.tween(playButton, {alpha: 1}, 0.36, {ease: FlxEase.quartOut, startDelay: 0.12});
			FlxTween.tween(playText, {alpha: 1}, 0.36, {ease: FlxEase.quartOut, startDelay: 0.12});
		}
	}

	function punchSprite(spr:FlxSprite, peak:Float = 1.12):Void
	{
		if (spr == null) return;
		FlxTween.cancelTweensOf(spr.scale);
		spr.scale.set(peak, peak);
		FlxTween.tween(spr.scale, {x: 1.0, y: 1.0}, 0.22, {ease: FlxEase.backOut});
	}

	function refreshOneshot():Void
	{
		if (oneshots.length == 0) return;

		var oneshot = oneshots[curOneshot];
		titleText.text = oneshot.title;
		punchSprite(titleText, 1.14);
		punchSprite(logo, 1.08);

		var musicPath:String = oneshot.music;
		if (musicPath != null && musicPath != "" && musicPath != currentMusic)
		{
			if (FlxG.sound.music != null)
			{
				FlxG.sound.music.stop();
				FlxG.sound.music.destroy();
				FlxG.sound.music = null;
			}
			try {
				FlxG.sound.playMusic(Paths.music(musicPath), 0.7);
			} catch (e:Dynamic) {
				trace('[ONE-SHOTS] Missing menu music "music/$musicPath.ogg", keeping previous track.');
			}
			currentMusic = musicPath;
		}

		var songs:Array<Dynamic> = oneshot.songs;

		unlockedSongs = [];
		for (i in 0...songs.length)
		{
			if (i == 0)
			{
				unlockedSongs.push(true);
			}
			else
			{
				var prevSong:Dynamic = songs[i - 1];
				var prevName:String = prevSong.songName;
				var prevDiffs:Array<Dynamic> = prevSong.difficulties;
				var prevDiffStr:String = "normal";
				if (prevDiffs != null && prevDiffs.length > 0)
					prevDiffStr = prevDiffs[0];
				var beaten:Bool = Highscore.getScore(prevName, prevDiffStr) > 0;
				unlockedSongs.push(beaten);
			}
		}

		var logoName:String = oneshot.logo;
		var logoLoaded:Bool = false;
		if (logoName != null && logoName != "")
		{
			try {
				logo.loadGraphic(Paths.gpuBitmap("oneshots/logos/" + logoName));
				logo.scale.set(0.25, 0.25);
				logo.updateHitbox();
				logo.x = FlxG.width - logo.width - 70;
				logoLoaded = true;
			} catch (e:Dynamic) {
				logoLoaded = false;
			}
		}

		if (logoLoaded)
		{
			logo.visible = true;

			songNameText.visible = true;
			leftDiff.visible = true;
			diffText.visible = true;
			rightDiff.visible = true;
			playButton.visible = true;
			playText.visible = true;
		}
		else
		{
			logo.visible = false;
			leftArrow.visible = false;
			rightArrow.visible = false;
			descText.visible = false;
			songNameText.visible = false;
			leftDiff.visible = false;
			diffText.visible = false;
			rightDiff.visible = false;
			playButton.visible = false;
			playText.visible = false;
		}

	}

	function refreshSong():Void
	{
		if (oneshots.length == 0) return;

		var songs:Array<Dynamic> = oneshots[curOneshot].songs;
		if (songs.length == 0)
		{
			songNameText.text = Localization.getString("oneshots_no_songs", "No songs available");
			statsText.text = Localization.getString("oneshots_stats", "Score: {0}  |  Misses: {1}  |  Acc: {2}", [0, "N/A", "N/A"]);
			diffText.text = "";
			coverSprite.visible = false;
			hasCover = false;
			return;
		}

		var song:Dynamic = songs[curSong];

		songNameText.text = song.songName;

		var desc:String = song.lore;
		if (desc != null && desc != "")
		{
			descText.resetText(desc);
			descText.start(0.015, true);
			descText.visible = true;
		}
		else
		{
			descText.visible = false;
		}

		var coverName:String = song.cover;
		if (coverName != null && coverName != "")
		{
			try {
				var coverPath = "oneshots/covers/" + coverName;
				coverSprite.loadGraphic(Paths.gpuBitmap(coverPath));
				coverSprite.x = 60;
				coverBaseY = 200;
				coverSprite.y = coverBaseY;
				coverSprite.visible = true;
				hasCover = true;
			} catch (e:Dynamic) {
				coverSprite.visible = false;
				hasCover = false;
			}
			if (hasCover)
			{
				coverSetupDone = false;
				setupCoverVisual();
			}
		}
		else
		{
			coverSprite.visible = false;
			hasCover = false;
		}

		var diff:Array<Dynamic> = song.difficulties;
		if (diff != null && diff.length > 0)
		{
			if (curDifficulty >= diff.length)
				curDifficulty = 0;
			diffText.text = "< " + diff[curDifficulty] + " >";
		}
		else
		{
			diffText.text = "< Normal >";
		}

		var oneshotData:Dynamic = oneshots[curOneshot];
		targetHue1 = (song.hue1 != null) ? song.hue1 : ((oneshotData.hue1 != null) ? oneshotData.hue1 : 0.0);
		targetHue2 = (song.hue2 != null) ? song.hue2 : ((oneshotData.hue2 != null) ? oneshotData.hue2 : 0.8333);
		targetSpecialRotation = (song.specialRotation != null) ? song.specialRotation : ((oneshotData.specialRotation != null) ? oneshotData.specialRotation : 45.0);

		updateStats();
		layoutRightPanel();
		punchSprite(diffText, 1.16);
	}

	function setupCoverVisual():Void
	{
		if (!hasCover || !coverSprite.visible) return;
		if (coverSprite.width <= 0 || coverSprite.height <= 0) return;

		coverSprite.setGraphicSize(0, 350);
		coverSprite.updateHitbox();
		
		coverSprite.x = 60;
		coverBaseY = 200;
		coverSprite.y = coverBaseY;

		var isUnlocked:Bool = curSong < unlockedSongs.length && unlockedSongs[curSong];
		if (isUnlocked)
		{
			coverGreyscale.strength = 0;
			coverOverlay.alpha = 0;
			blockIcon.visible = false;
		}
		else
		{
			coverGreyscale.strength = 1;
			coverOverlay.alpha = 0.6;
			coverOverlay.x = coverSprite.x;
			coverOverlay.y = coverSprite.y;
			coverOverlay.setGraphicSize(Std.int(coverSprite.width), Std.int(coverSprite.height));
			coverOverlay.updateHitbox();
			blockIcon.visible = true;
			blockIcon.x = coverSprite.x + (coverSprite.width - blockIcon.width) / 2;
			blockIcon.y = coverSprite.y + (coverSprite.height - blockIcon.height) / 2;
		}
		coverGreyscale.update(0);
		coverSetupDone = true;
	}

	function updateLayout():Void
	{
		if (logo.visible && logo.width > 0 && logo.height > 0)
		{
			logo.x = FlxG.width - logo.width - 50;
			logo.y = 30;
		}

		leftArrow.x = logo.x - 50;
		leftArrow.y = logo.y + logo.height / 2 - 20;
		rightArrow.x = logo.x + logo.width + 10;
		rightArrow.y = logo.y + logo.height / 2 - 20;

		if (hasCover && !coverSetupDone)
			setupCoverVisual();

		layoutRightPanel();
	}

	function layoutRightPanel():Void
	{
		if (!logo.visible) return;

		var coverCenterX:Float = coverSprite.x + coverSprite.width / 2;

		titleText.x = coverCenterX - titleText.width / 2;
		titleText.y = coverBaseY - titleText.height - 100;

		var statsY:Float = coverBaseY + coverSprite.height + 40;

		statsText.x = coverCenterX - statsText.width / 2;
		statsText.y = statsY;

		markSprite.x = statsText.x + statsText.width + 8;
		markSprite.y = statsY + 2;

		var baseX:Float = logo.x;
		var centerX:Float = baseX + logo.width / 2;

		if (descText.visible)
		{
			descText.x = baseX + 50;
			descText.y = logo.y + logo.height + 15;
			descText.width = logo.width;
		}

		var songNameY:Float = logo.y + logo.height + 220;
		songNameText.x = centerX - songNameText.width / 2;
		songNameText.y = songNameY;

		var diffY:Float = songNameY + songNameText.height + 10;
		var diffTotalW:Float = leftDiff.width + 5 + diffText.width + 5 + rightDiff.width;
		var diffStartX:Float = centerX - diffTotalW / 2;
		leftDiff.x = diffStartX;
		leftDiff.y = diffY;
		diffText.x = leftDiff.x + leftDiff.width + 5;
		diffText.y = diffY + 5;
		rightDiff.x = diffText.x + diffText.width + 5;
		rightDiff.y = diffY;

		var playY:Float = diffY + leftDiff.height + 15;
		playButton.x = centerX - playButton.width / 2;
		playButton.y = playY;
		playText.x = playButton.x;
		playText.y = playButton.y + (playButton.height - playText.height) / 2;
	}

	function updateStats():Void
	{
		if (oneshots.length == 0) return;

		var songs:Array<Dynamic> = oneshots[curOneshot].songs;
		if (songs.length == 0) return;

		var song:Dynamic = songs[curSong];
		var songName:String = song.songName;

		var diff:Array<Dynamic> = song.difficulties;
		var diffStr:String = "normal";
		if (diff != null && diff.length > 0)
			diffStr = diff[curDifficulty];

		var score:Int = Highscore.getScore(songName, diffStr);
		var misses:Int = Highscore.getMisses(songName, diffStr);
		var accuracy:Float = Highscore.getSongAccuracy(songName, diffStr);

		var accStr:String = (accuracy > 0) ? Std.string(accuracy) + "%" : "N/A";
		var missStr:String = (misses >= 0) ? Std.string(misses) : "N/A";
		statsText.text = Localization.getString("oneshots_stats", "Score: {0}  |  Misses: {1}  |  Acc: {2}", [score, missStr, accStr]);

		markSprite.color = (score > 0) ? FlxColor.LIME : FlxColor.GRAY;
	}

	function updateDifficultyDisplay():Void
	{
		if (oneshots.length == 0) return;

		var songs:Array<Dynamic> = oneshots[curOneshot].songs;
		if (songs.length == 0) return;

		var song:Dynamic = songs[curSong];
		var diff:Array<Dynamic> = song.difficulties;

		if (diff != null && diff.length > 0)
		{
			if (curDifficulty >= diff.length)
				curDifficulty = 0;
			diffText.text = "< " + diff[curDifficulty] + " >";
		}
		else
		{
			diffText.text = "< Normal >";
		}

		updateStats();
		layoutRightPanel();
		punchSprite(diffText, 1.16);
	}

	function playSelectedSong():Void
	{
		if (oneshots.length == 0) return;

		var songs:Array<Dynamic> = oneshots[curOneshot].songs;
		if (songs.length == 0) return;

		var song:Dynamic = songs[curSong];
		var songName:String = song.songName;

		var diff:Array<Dynamic> = song.difficulties;
		var diffStr:String = "normal";
		if (diff != null && diff.length > 0)
			diffStr = diff[curDifficulty];

		var playlist:Array<String> = [];
		for (i in curSong...songs.length)
		{
			var s:Dynamic = songs[i];
			var sName:String = s.songName;
			playlist.push(sName);
		}

		if (playlist.length == 0)
			playlist = [songName];

		if (!CoolUtil.songExists(playlist[0], diffStr))
		{
			trace('Song not found: ${playlist[0]} ($diffStr)');
			return;
		}

		PlayState.lastCurOneshot = curOneshot;
		PlayState.SONG = SongLoader.loadFromJson(diffStr, playlist[0]);
		PlayState.isStoryMode = true;
		PlayState.storyPlaylist = playlist;
		PlayState.storyDifficultyStr = diffStr;
		PlayState.storyWeek = curOneshot;
		PlayState.campaignScore = 0;
		PlayState.deathCounter = 0;
		substates.PauseSubState.lastPromptedDeathCount = -1;
		PlayState.songMultiplier = 1;
		PlayState.oneshotMode = true;
		PlayState.oneshotId = oneshots[curOneshot].id;
		PlayState.loadChartEvents = true;
		PlayState.chartingMode = false;

		if (coverGreyscale != null) coverGreyscale.enter = 1.0;
		FlxG.sound.play(Paths.sound("confirmMenu"));
		LoadingState.loadAndSwitchState(() -> new PlayState());
	}

	function isOverlapping(sprite:FlxSprite):Bool
	{
		if (sprite == null || !sprite.visible) return false;
		return FlxG.mouse.overlaps(sprite);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (snowCutShader != null)
		{
			var lerpVal:Float = CoolUtil.boundTo(elapsed * 5, 0, 1);
			snowCutShader.hue1 = FlxMath.lerp(snowCutShader.hue1, targetHue1, lerpVal);
			snowCutShader.hue2 = FlxMath.lerp(snowCutShader.hue2, targetHue2, lerpVal);
			snowCutShader.specialRotation = FlxMath.lerp(snowCutShader.specialRotation, targetSpecialRotation, lerpVal);
			snowCutShader.update(elapsed);
		}

		if (!canInteract) return;

		time += elapsed;

		if (hasCover && coverSprite.visible)
		{
			coverSprite.y = coverBaseY + Math.sin(time * 1.5) * 10;

			var isUnlocked:Bool = curSong < unlockedSongs.length && unlockedSongs[curSong];
			if (!isUnlocked)
			{
				coverOverlay.y = coverSprite.y;
				blockIcon.y = coverSprite.y + (coverSprite.height - blockIcon.height) / 2;
			}

			var isUnlocked:Bool = curSong < unlockedSongs.length && unlockedSongs[curSong];
			if (isUnlocked)
			{
				coverGreyscale.strength = 0.3 + Math.sin(time * 2) * 0.15;
			}
			coverGreyscale.update(elapsed);
		}

		updateLayout();

		if (playButton != null && playText != null && playButton.visible)
		{
			var hoverPlay = isOverlapping(playButton);
			var targetPlayScale = hoverPlay ? 1.07 : 1.0;
			var ps = FlxMath.lerp(playButton.scale.x, targetPlayScale, MenuAnims.smooth(elapsed, 12.0));
			playButton.scale.set(ps, ps);
			playText.scale.set(ps, ps);
		}

		if (isOverlapping(leftArrow) && FlxG.mouse.justPressed)
		{
			curOneshot--;
			if (curOneshot < 0)
				curOneshot = oneshots.length - 1;
			curSong = 0;
			curDifficulty = 0;
			refreshOneshot();
			refreshSong();
		}

		if (isOverlapping(rightArrow) && FlxG.mouse.justPressed)
		{
			curOneshot++;
			if (curOneshot >= oneshots.length)
				curOneshot = 0;
			curSong = 0;
			curDifficulty = 0;
			refreshOneshot();
			refreshSong();
		}

		if (FlxG.keys.justPressed.LEFT)
		{
			var songs:Array<Dynamic> = oneshots[curOneshot].songs;
			curSong--;
			if (curSong < 0)
				curSong = songs.length - 1;
			curDifficulty = 0;
			refreshSong();
		}

		if (FlxG.keys.justPressed.RIGHT)
		{
			var songs:Array<Dynamic> = oneshots[curOneshot].songs;
			curSong++;
			if (curSong >= songs.length)
				curSong = 0;
			curDifficulty = 0;
			refreshSong();
		}

		if (isOverlapping(leftDiff) && FlxG.mouse.justPressed)
		{
			var songs:Array<Dynamic> = oneshots[curOneshot].songs;
			if (songs.length > 0)
			{
				var song:Dynamic = songs[curSong];
				var diff:Array<Dynamic> = song.difficulties;
				if (diff != null && diff.length > 0)
				{
					curDifficulty--;
					if (curDifficulty < 0)
						curDifficulty = diff.length - 1;
					updateDifficultyDisplay();
				}
			}
		}

		if (isOverlapping(rightDiff) && FlxG.mouse.justPressed)
		{
			var songs:Array<Dynamic> = oneshots[curOneshot].songs;
			if (songs.length > 0)
			{
				var song:Dynamic = songs[curSong];
				var diff:Array<Dynamic> = song.difficulties;
				if (diff != null && diff.length > 0)
				{
					curDifficulty++;
					if (curDifficulty >= diff.length)
						curDifficulty = 0;
					updateDifficultyDisplay();
				}
			}
		}

		if ((isOverlapping(playButton) && FlxG.mouse.justPressed || FlxG.keys.justPressed.ENTER) && !startingSong)
		{
			var isUnlocked:Bool = curSong < unlockedSongs.length && unlockedSongs[curSong];
			if (!isUnlocked) return;

			startingSong = true;
			canInteract = false;

			var soundName:String = "confirmMenu";
			if (oneshots.length > 0)
			{
				var oneshotData:Dynamic = oneshots[curOneshot];
				var songs:Array<Dynamic> = oneshotData.songs;
				if (songs != null && songs.length > 0)
				{
					var songData:Dynamic = songs[curSong];
					if (songData != null && songData.sound != null)
						soundName = songData.sound;
					else if (oneshotData.sound != null)
						soundName = oneshotData.sound;
				}
			}

			if (FlxG.sound.music != null)
			{
				FlxG.sound.music.stop();
				FlxG.sound.music.destroy();
				FlxG.sound.music = null;
			}

			FlxG.sound.play(Paths.sound(soundName));
			FlxG.camera.flash(FlxColor.WHITE, 1.0, function()
			{
				playSelectedSong();
			});
		}

		if (controls.BACK)
		{
			if (FlxG.sound.music != null)
			{
				FlxG.sound.music.stop();
				FlxG.sound.music.destroy();
				FlxG.sound.music = null;
			}
			FlxG.sound.playMusic(Paths.music('freakyMenu'));
			FlxG.switchState(new MainMenuState());
		}
	}

	override function destroy()
	{
		if (bgCam != null)
		{
			if (FlxG.cameras != null && FlxG.cameras.list.contains(bgCam))
				FlxG.cameras.remove(bgCam, true);
			bgCam = null;
		}
		if (uiCam != null)
		{
			if (FlxG.cameras != null && FlxG.cameras.list.contains(uiCam))
				FlxG.cameras.remove(uiCam, true);
			uiCam = null;
		}
		super.destroy();
	}
}