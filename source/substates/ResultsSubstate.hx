package substates;

import utilities.Ratings;
import ui.NoteGraph;
import flixel.text.FlxText;

import game.Replay;
import flixel.FlxCamera;
import flixel.util.FlxColor;
import flixel.FlxSprite;
import flixel.FlxG;
import states.PlayState;
import states.OneShotsState;
import game.Highscore;

class ResultsSubstate extends MusicBeatSubstate {
	var uiCamera:FlxCamera = new FlxCamera();
	var fontPath:String = "Ethnocentric-Regular.otf";
	var blackStars:Array<FlxSprite> = [];

	public function new(replay:Replay) {
		super();

		if (utilities.Options.getData("skipResultsScreen")) {
			PlayState.instance.finishSongStuffs();
			return;
		}

		uiCamera.bgColor.alpha = 0;
		FlxG.cameras.add(uiCamera, false);

		var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0.8;
		bg.scrollFactor.set();
		add(bg);

		var panelW = FlxG.width - 60;
		var panelH = 260;
		var panelX = 30;
		var panelY = FlxG.height - panelH - 30;
		var colW = Std.int(panelW / 3);
		var boxH = 60;

		createBox(panelX, panelY, panelW, panelH);

		createBox(panelX + 10, panelY + 10, colW - 20, boxH);
		createBox(panelX + colW + 10, panelY + 10, colW - 20, boxH);
		createBox(panelX + colW * 2 + 10, panelY + 10, colW - 20, boxH);

		createBox(panelX + 10, panelY + boxH + 30, colW - 20, panelH - boxH - 40);
		createBox(panelX + colW + 10, panelY + boxH + 30, colW - 20, panelH - boxH - 40);
		createBox(panelX + colW * 2 + 10, panelY + boxH + 30, colW - 20, panelH - boxH - 40);
		addText(
			panelX + colW * 2 + 25,
			panelY + boxH + 35,
			colW - 50,
			"SCROLL SPEED: " + (
				PlayState.previousScrollSpeed > 0
				? PlayState.previousScrollSpeed
				: PlayState.SONG.speed
			) + "\n" +
			"GHOST TAPPING: " + (Options.getData("ghostTapping") ? "YES" : "NO") + "\n" +
			"NO HIT: " + (Options.getData("noHit") ? "YES" : "NO") + "\n" +
			"BOTPLAY: " + (Options.getData("botplay") ? "YES" : "NO") + "\n" +
			"NO DEATH: " + (Options.getData("noDeath") ? "YES" : "NO") + "\n" +
			"PLAYING AS: " + (PlayState.characterPlayingAs == BF ? "PLAYER" : "OPPONENT") + "\n\n" +
			"TOTAL NOTES: " + PlayState.instance.totalNotes + "\n" +
			"HIT NOTES: " + Std.int(PlayState.instance.hitNotes),
			18
		);



		addText(
			panelX + 25,
			panelY + 18,
			colW - 50,
			"SONG: " + PlayState.SONG.song.toUpperCase(),
			18,
			FlxColor.fromString("#29E887")
		);

		addText(
			panelX + colW + 25,
			panelY + 18,
			colW - 50,
			"DIFFICULTY: " + PlayState.storyDifficultyStr.toUpperCase(),
			18,
			FlxColor.fromString("#29E8BD")
		);

		addText(
			panelX + colW * 2 + 25,
			panelY + 35,
			200,
			"STARS:",
			22,
			FlxColor.fromString("#E8CB29")
		);

		for (i in 0...3) {
			var star = new FlxSprite(panelX + colW * 2 + 150 + i * 60, panelY + 17);
			star.loadGraphic(Paths.gpuBitmap("black star"));
			star.scale.set(0.1, 0.1);
			star.updateHitbox();
			star.color = FlxColor.GRAY;
			star.scrollFactor.set();
			add(star);
			blackStars.push(star);
		}

		var formatted = Highscore.formatSong(PlayState.SONG.song, PlayState.storyDifficultyStr);
		var savedStars = Highscore.getSongStars(formatted, PlayState.storyDifficultyStr, true);

		for (i in 0...blackStars.length)
			blackStars[i].color = FlxColor.GRAY;
		if (!PlayState.SONG.validScore) {
			for (star in blackStars)
				star.color = FlxColor.RED;
		} else {
			for (i in 0...savedStars)
				if (i < blackStars.length)
					blackStars[i].color = [0xFFFF69B4, FlxColor.CYAN, FlxColor.ORANGE][i];
		}


		addText(
			panelX + 25,
			panelY + boxH + 45,
			colW - 50,
			PlayState.instance.getRatingText(),
			18,
			FlxColor.PINK
		);

		createBox(
			panelX + colW + 10,
			panelY + boxH + 10,
			colW - 20,
			40
		);

		addText(
			panelX + colW + 25,
			panelY + boxH + 23,
			colW - 50,
			"SONG SPEED: " + Std.string(PlayState.songMultiplier) + "x",
			18,
			FlxColor.ORANGE
		);


		addText(
			panelX + colW + 25,
			panelY + boxH + 80,
			colW - 50,
			"SCORE: " + PlayState.instance.songScore +
			"\nACCURACY: " + Std.int(PlayState.instance.accuracy) + "%" +
			"\nMISSES: " + PlayState.instance.misses +
			"\nRANK: " + Ratings.getRank(
				PlayState.instance.accuracy,
				PlayState.instance.misses
			),
			22,
			FlxColor.CYAN
		);


		createBox(
			30,
			40,
			Std.int(FlxG.width / 2) - 120,
			Std.int(panelY - 50)
		);


		add(new NoteGraph(replay, 40, 60));

		var topStatus = new FlxText(
			0,
			8,
			FlxG.width - 20,
			"COMPLETE SONG — SONG VALID: " + (PlayState.SONG.validScore ? "YES" : "NO"),
			20
		);
		topStatus.setFormat(
			fontPath,
			20,
			PlayState.SONG.validScore ? 0xFF78E012 : 0xFFFF4848,
			RIGHT,
			FlxTextBorderStyle.OUTLINE,
			FlxColor.BLACK
		);
		topStatus.scrollFactor.set();
		add(topStatus);

		var bottom = new FlxText(
			0,
			panelY - 36,
			FlxG.width - 30,
			"PRESS ENTER TO CONTINUE",
			26
		);
		bottom.setFormat(
			fontPath,
			26,
			FlxColor.fromString("#48C9FF"),
			RIGHT,
			FlxTextBorderStyle.OUTLINE,
			FlxColor.BLACK
		);
		bottom.borderSize = 3;
		bottom.scrollFactor.set();
		add(bottom);

		var modeText = new FlxText(
			0,
			panelY - 60,
			FlxG.width - 30,
			"",
			20
		);
		modeText.scrollFactor.set();

		var modes:Array<String> = [];
		if (PlayState.practiceMode) modes.push("Press R to RESTART PRACTICE");
		if (PlayState.oneshotMode) modes.push("Press E to EXIT ONE-SHOTS");

		if (modes.length > 0) {
			modeText.text = modes.join(" • ");
			modeText.setFormat(
				fontPath,
				26,
				FlxColor.YELLOW,
				RIGHT,
				FlxTextBorderStyle.OUTLINE,
				FlxColor.BLACK
			);
			modeText.borderSize = 2;
			add(modeText);
		}


		var clearedText = new FlxText(
			0,
			panelY - 380,
			FlxG.width - 30,
			"",
			22
		);
		clearedText.scrollFactor.set();

		if (PlayState.SONG.validScore) {
			clearedText.setFormat(fontPath, 22, 0xFF78E012, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			clearedText.text = "SCORE SAVED!";
		} else {
			clearedText.setFormat(fontPath, 22, 0xFFFF4848, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			clearedText.text =
				"SCORE NOT SAVED\n" +
				(PlayState.tooSlow ? "- Song Speed is less than 1x\n" : "") +
				(PlayState.botUsed ? "- Botplay was enabled\n" : "") +
				(PlayState.diedInNoDeath ? "- You died during No Death mode\n" : (PlayState.noDeathUsed ? "- You activate No Death mode\n" : "")) +
				(PlayState.invalidJudgements ? "- Judgement Timings are invalid\n" : "") +
				(PlayState.characterPlayingAs != BF ? "- Opponent Play was enabled\n" : "") +
				(PlayState.chartingMode ? "- Chart Editor was used\n" : "") +
				(PlayState.modchartingMode ? "- Modchart Editor was used\n" : "") +
				(PlayState.practiceMode ? "- Practice Mode Songs are not valid\n" : "");
		}
		clearedText.borderSize = 3;
		add(clearedText);

		cameras = [uiCamera];
	}

	function createBox(x:Float, y:Float, w:Int, h:Int) {
		var border = new FlxSprite(x - 2, y - 2).makeGraphic(w + 4, h + 4, FlxColor.WHITE);
		var box = new FlxSprite(x, y).makeGraphic(w, h, FlxColor.BLACK);
		border.scrollFactor.set();
		box.scrollFactor.set();
		add(border);
		add(box);
	}

	function addText(x:Float, y:Float, w:Int, text:String, size:Int, ?color:FlxColor) {
		var finalColor:FlxColor = (color == null) ? FlxColor.WHITE : color;
		var t = new FlxText(x, y, w, text, size);
		t.setFormat(fontPath, size, finalColor, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		t.borderSize = 2;
		t.scrollFactor.set();
		add(t);
	}

	var accepted:Bool = false;

	override function update(elapsed:Float) {
		super.update(elapsed);

		if (FlxG.keys.justPressed.ENTER && !accepted) {
			accepted = true;
			PlayState.instance.finishSongStuffs();
		}

		if (PlayState.practiceMode && FlxG.keys.justPressed.R) {
			PlayState.startOnTime = PlayState.practiceStartTime;
			PlayState.practiceEndTime = PlayState.practiceEndTime;
			PlayState.SONG.speed = PlayState.previousScrollSpeed;
			FlxG.switchState(() -> new PlayState());
			}

		if (PlayState.oneshotMode && FlxG.keys.justPressed.E) {
			PlayState.oneshotMode = false;
			PlayState.oneshotId = "";
			FlxG.switchState(() -> new OneShotsState());
		}
	}

	override function destroy() {
		if (uiCamera != null) {
			if (FlxG.cameras != null && FlxG.cameras.list.contains(uiCamera)) {
				FlxG.cameras.remove(uiCamera, true);
			}
			uiCamera = null;
		}
		super.destroy();
	}
}
