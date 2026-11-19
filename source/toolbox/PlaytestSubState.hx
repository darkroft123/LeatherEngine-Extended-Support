package toolbox;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.sound.FlxSound;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.tweens.FlxTween;
import flixel.input.keyboard.FlxKey;
import flixel.math.FlxMath;
import flixel.math.FlxRect;
import openfl.utils.Assets;
import openfl.display.BitmapData;
import game.SongLoader.SongData;
import game.Conductor;
import game.SoundGroup;
import game.StrumNote;
import game.Note;
import utilities.Ratings;
import utilities.NoteVariables;
import substates.MusicBeatSubstate;


class PlaytestSubState extends MusicBeatSubstate {
	var _song:SongData;
	var _startTime:Float;
	var _events:Array<Array<Dynamic>>;

	var overlayBG:FlxSprite;
	var bannerTxt:FlxText;
	var timeTxt:FlxText;
	var infoTxt:FlxText;
	var judgementsTxt:FlxText;

	var subMusic:FlxSound;
	var subVocals:SoundGroup;

	var playerStrums:FlxTypedGroup<StrumNote>;
	var opponentStrums:FlxTypedGroup<StrumNote>;
	var playerStrumlineID:Int = 1;

	// UI & Mania layout configurations
	var ui_settings:Array<String>;
	var mania_size:Array<String>;
	var mania_gap:Array<String>;
	var mania_offset:Array<String>;

	// Distinct rendering groups: sustains always render behind tap notes without per-frame sorting
	var sustainsGroup:FlxTypedGroup<Note>;
	var notesGroup:FlxTypedGroup<Note>;
	var unspawnNotes:Array<Note> = [];
	var unspawnIndex:Int = 0;
	var playbackRate:Float = 1.0;

	// Interactive Options & Gameplay Settings
	public var isBotplay:Bool = false;
	public var playAsOpponent:Bool = false;
	public var inputMode:String = "psych";
	public var ghostTapping:Bool = true;
	public var displayMs:Bool = true;
	public var ratingsAndCombo:Bool = true;
	public var showJudgements:Bool = true;

	// Keybinds
	var cachedPlayerKeys:Array<Array<FlxKey>> = [];
	var cachedPossibleNotes:Array<Note> = [];

	// Popups & Visual Groups
	var ratingsGroup:FlxTypedGroup<FlxSprite>;
	var comboGroup:FlxTypedGroup<FlxSprite>;
	var msGroup:FlxTypedGroup<FlxText>;
	var uiMap:Map<String, BitmapData> = new Map<String, BitmapData>();

	// Judgements & Stats
	public var songScore:Int = 0;
	public var combo:Int = 0;
	public var marvelousCount:Int = 0;
	public var sickCount:Int = 0;
	public var goodCount:Int = 0;
	public var badCount:Int = 0;
	public var shitCount:Int = 0;
	public var missesCount:Int = 0;
	public var hitNotes:Float = 0;
	public var totalNotes:Int = 0;
	public var accuracy:Float = 0.0;
	var statsDirty:Bool = true;
	var lastTimeSec:Int = -1;
	var lastPlaybackRate:Float = -1.0;

	var missSounds:Array<String> = ["missnote1", "missnote2", "missnote3"];
	var hitSoundString:String = "none";
	var hitSoundVolume:Float = 1.0;

	public function new(song:SongData, events:Array<Array<Dynamic>>, startTime:Float = 0, playAsOpponent:Bool = false) {
		super();
		this._song = song;
		this._events = events;
		this._startTime = startTime;
		this.playAsOpponent = playAsOpponent;
	}

	override public function create():Void {
		super.create();

		// Synchronize Conductor with song data and BPM maps
		if (_song != null) {
			Conductor.mapBPMChanges(_song);
			Conductor.changeBPM(_song.bpm > 1.0 ? _song.bpm : 100.0);
		}

		if (Options.getData("inputSystem") != null) inputMode = Options.getData("inputSystem");
		if (Options.getData("ghostTapping") != null) ghostTapping = Options.getData("ghostTapping");
		if (Options.getData("displayMs") != null) displayMs = Options.getData("displayMs");
		if (Options.getData("ratingsAndCombo") != null) ratingsAndCombo = Options.getData("ratingsAndCombo");
		if (Options.getData("botplay") != null) isBotplay = Options.getData("botplay");

		var hsOpt:String = Options.getData("hitSound");
		if (hsOpt != null) hitSoundString = hsOpt;
		var hsVol:Dynamic = Options.getData("hitSoundVolume");
		if (hsVol != null) hitSoundVolume = (cast(hsVol, Float) / 100.0);

		loadSkinConfigurations();

		overlayBG = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, 0xD9000000);
		overlayBG.scrollFactor.set(0, 0);
		add(overlayBG);

		var isDownscroll:Bool = Options.getData("downscroll") == true;
		var strumY:Float = isDownscroll ? (FlxG.height - 150) : 100;
		var uiSkin:String = (_song != null && _song.ui_Skin != null && _song.ui_Skin != "") ? _song.ui_Skin : "default";

		opponentStrums = new FlxTypedGroup<StrumNote>();
		playerStrums = new FlxTypedGroup<StrumNote>();
		add(opponentStrums);
		add(playerStrums);

		var keyCountP2:Int = (_song != null && _song.keyCount > 0) ? _song.keyCount : 4;
		var keyCountP1:Int = (_song != null && _song.playerKeyCount > 0) ? _song.playerKeyCount : 4;
		var isMiddlescroll:Bool = Options.getData("middlescroll") == true;

		for (i in 0...keyCountP2) {
			var strumX:Float = getStrumX(i, keyCountP2, false);
			var strum:StrumNote = new StrumNote(strumX, strumY, i, uiSkin, ui_settings, mania_size, keyCountP2, 0);
			strum.scrollFactor.set(0, 0);
			strum.x = strumX;
			strum.y = strumY - (strum.height / 2);
			if (isMiddlescroll && !playAsOpponent) {
				strum.visible = false;
			}
			opponentStrums.add(strum);
		}
		for (i in 0...keyCountP1) {
			var strumX:Float = getStrumX(i, keyCountP1, true);
			var strum:StrumNote = new StrumNote(strumX, strumY, i, uiSkin, ui_settings, mania_size, keyCountP1, 1);
			strum.scrollFactor.set(0, 0);
			strum.x = strumX;
			strum.y = strumY - (strum.height / 2);
			if (isMiddlescroll && playAsOpponent) {
				strum.visible = false;
			}
			playerStrums.add(strum);
		}

		setupStrumlineTargeting();

		// Distinct groups ensure sustained tails always render behind tap notes
		sustainsGroup = new FlxTypedGroup<Note>();
		notesGroup = new FlxTypedGroup<Note>();
		add(sustainsGroup);
		add(notesGroup);

		// Groups for rating popups
		ratingsGroup = new FlxTypedGroup<FlxSprite>();
		comboGroup = new FlxTypedGroup<FlxSprite>();
		msGroup = new FlxTypedGroup<FlxText>();
		add(ratingsGroup);
		add(comboGroup);
		add(msGroup);

		loadUIAssets();
		generateNotes();
		setupPlayerKeybinds();

		bannerTxt = new FlxText(0, 4, FlxG.width, "PLAYTEST PREVIEW", 14);
		bannerTxt.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.YELLOW, CENTER, OUTLINE, FlxColor.BLACK);
		bannerTxt.scrollFactor.set(0, 0);
		add(bannerTxt);

		infoTxt = new FlxText(0, 22, FlxG.width, "", 11);
		infoTxt.setFormat(Paths.font("vcr.ttf"), 11, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		infoTxt.scrollFactor.set(0, 0);
		add(infoTxt);

		judgementsTxt = new FlxText(10, 50, FlxG.width - 20, "", 12);
		judgementsTxt.setFormat(Paths.font("vcr.ttf"), 12, FlxColor.WHITE, RIGHT, OUTLINE, FlxColor.BLACK);
		judgementsTxt.scrollFactor.set(0, 0);
		add(judgementsTxt);

		timeTxt = new FlxText(10, FlxG.height - 25, 450, "", 12);
		timeTxt.setFormat(Paths.font("vcr.ttf"), 12, FlxColor.CYAN, LEFT, OUTLINE, FlxColor.BLACK);
		timeTxt.scrollFactor.set(0, 0);
		add(timeTxt);

		updateInfoText();

		// Audio playback
		Conductor.songPosition = _startTime + Conductor.offset;
		if (_song != null && _song.song != null) {
			subMusic = new FlxSound();
			var instTrack = Paths.inst(_song.song);
			if (instTrack != null) {
				subMusic.loadEmbedded(instTrack);
				FlxG.sound.list.add(subMusic);
				subMusic.time = _startTime;
				subMusic.pitch = playbackRate;
				subMusic.onComplete = function() {
					close();
				};
				subMusic.play();
			}

			if (_song.needsVoices) {
				var voiceTrack = Paths.voices(_song.song);
				if (voiceTrack != null) {
					subVocals = new SoundGroup(2);
					var vocSnd:FlxSound = new FlxSound().loadEmbedded(voiceTrack);
					FlxG.sound.list.add(vocSnd);
					subVocals.add(vocSnd);
					subVocals.time = _startTime;
					subVocals.pitch = playbackRate;
					subVocals.play();
				}
			}
		}

		// Fast-forward unspawn notes if preview started mid-song
		if (_startTime > 0) {
			var threshold:Float = _startTime + Conductor.offset - 150;
			while (unspawnIndex < unspawnNotes.length && unspawnNotes[unspawnIndex].strumTime < threshold) {
				unspawnIndex++;
			}
		}
	}

	function loadSkinConfigurations():Void {
		var uiSkin:String = (_song != null && _song.ui_Skin != null && _song.ui_Skin != "") ? _song.ui_Skin : "default";
		var base:String = "ui skins/" + uiSkin;

		try {
			if (Assets.exists(Paths.txt(base + "/config")))
				ui_settings = CoolUtil.coolTextFile(Paths.txt(base + "/config"));
		} catch (e:Dynamic) {}
		if (ui_settings == null || ui_settings.length < 4) ui_settings = ["0.7", "0.7", "1", "true"];

		try {
			if (Assets.exists(Paths.txt(base + "/maniasize")))
				mania_size = CoolUtil.coolTextFile(Paths.txt(base + "/maniasize"));
			else if (Assets.exists(Paths.txt("ui skins/default/maniasize")))
				mania_size = CoolUtil.coolTextFile(Paths.txt("ui skins/default/maniasize"));
		} catch (e:Dynamic) {}
		if (mania_size == null || mania_size.length < 10)
			mania_size = ["0.0", "0.0", "0.0", "0.0", "0.0", "0.0", "0.0", "0.0", "0.0", "0.0"];

		try {
			if (Assets.exists(Paths.txt(base + "/maniaoffset")))
				mania_offset = CoolUtil.coolTextFile(Paths.txt(base + "/maniaoffset"));
			else if (Assets.exists(Paths.txt("ui skins/default/maniaoffset")))
				mania_offset = CoolUtil.coolTextFile(Paths.txt("ui skins/default/maniaoffset"));
		} catch (e:Dynamic) {}
		if (mania_offset == null || mania_offset.length < 10)
			mania_offset = ["0.0", "0.0", "0.0", "0.0", "0.0", "0.0", "0.0", "0.0", "0.0", "0.0"];

		try {
			if (Assets.exists(Paths.txt(base + "/maniagap")))
				mania_gap = CoolUtil.coolTextFile(Paths.txt(base + "/maniagap"));
			else if (Assets.exists(Paths.txt("ui skins/default/maniagap")))
				mania_gap = CoolUtil.coolTextFile(Paths.txt("ui skins/default/maniagap"));
		} catch (e:Dynamic) {}
		if (mania_gap == null || mania_gap.length < 10)
			mania_gap = ["0.0", "0.0", "0.0", "0.0", "0.0", "0.0", "0.0", "0.0", "0.0", "0.0"];
	}

	public function getStrumX(lane:Int, keyCount:Int, isPlayerStrum:Bool):Float {
		var isMiddlescroll:Bool = Options.getData("middlescroll") == true;
		var isUserTarget:Bool = playAsOpponent ? !isPlayerStrum : isPlayerStrum;

		var pos:Float = 0;
		if (isMiddlescroll) {
			pos = isUserTarget ? 0.5 : 50;
		} else {
			pos = isPlayerStrum ? 1 : 0;
		}

		var kcIdx:Int = (keyCount > 0 && keyCount <= mania_size.length) ? (keyCount - 1) : 3;
		var scale:Float = Std.parseFloat(ui_settings[0]) * (Std.parseFloat(ui_settings[2]) - Std.parseFloat(mania_size[kcIdx]));
		var w:Float = 160 * scale;
		var gapVal:Float = (kcIdx < mania_gap.length) ? Std.parseFloat(mania_gap[kcIdx]) : 0;
		var offVal:Float = (kcIdx < mania_offset.length) ? Std.parseFloat(mania_offset[kcIdx]) : 0;

		var x:Float = (w + (2 + gapVal)) * Math.abs(lane) + offVal;
		x += 100 - ((keyCount - 4) * 16) + (keyCount >= 10 ? 30 : 0);
		x += ((FlxG.width / 2) * pos);
		return x;
	}

	function repositionStrums():Void {
		var keyCountP2:Int = (_song != null && _song.keyCount > 0) ? _song.keyCount : 4;
		var keyCountP1:Int = (_song != null && _song.playerKeyCount > 0) ? _song.playerKeyCount : 4;
		var isMiddlescroll:Bool = Options.getData("middlescroll") == true;

		for (i in 0...opponentStrums.length) {
			var s = opponentStrums.members[i];
			if (s != null) {
				s.x = getStrumX(i, keyCountP2, false);
				s.visible = !(isMiddlescroll && !playAsOpponent);
			}
		}
		for (i in 0...playerStrums.length) {
			var s = playerStrums.members[i];
			if (s != null) {
				s.x = getStrumX(i, keyCountP1, true);
				s.visible = !(isMiddlescroll && playAsOpponent);
			}
		}
	}

	function loadUIAssets():Void {
		uiMap = new Map<String, BitmapData>();
		var uiSkin:String = (_song != null && _song.ui_Skin != null && _song.ui_Skin != "") ? _song.ui_Skin : "default";
		var base:String = "ui skins/" + uiSkin;

		for (rating in ["marvelous", "sick", "good", "bad", "shit"]) {
			var imgPath:String = base + "/ratings/" + rating;
			if (!Assets.exists(Paths.image(imgPath, 'shared'))) {
				imgPath = "ui skins/default/ratings/" + rating;
			}
			if (Assets.exists(Paths.image(imgPath, 'shared'))) {
				uiMap.set(rating, Paths.gpuBitmap(imgPath, 'shared'));
			}
		}

		for (i in 0...10) {
			var imgPath:String = base + "/numbers/num" + i;
			if (!Assets.exists(Paths.image(imgPath, 'shared'))) {
				imgPath = "ui skins/default/numbers/num" + i;
			}
			if (Assets.exists(Paths.image(imgPath, 'shared'))) {
				uiMap.set(Std.string(i), Paths.gpuBitmap(imgPath, 'shared'));
			}
		}
	}

	function setupStrumlineTargeting():Void {
		playerStrumlineID = playAsOpponent ? 0 : 1;
	}

	inline function isPlayerControlledNote(note:Note):Bool {
		if (note.strumlineID >= 0) {
			return note.strumlineID == playerStrumlineID;
		}
		return playAsOpponent ? !note.mustPress : note.mustPress;
	}

	function setupPlayerKeybinds():Void {
		cachedPlayerKeys = [];
		var pKeyCount:Int = (playerStrums != null && playerStrums.length > 0) ? playerStrums.length : 4;

		var rawBinds:Dynamic = Options.getData("binds", "binds");
		var bindStrings:Array<String> = null;

		if (rawBinds != null && Std.isOfType(rawBinds, Array)) {
			var arr:Array<Dynamic> = cast rawBinds;
			if (arr.length >= pKeyCount && arr[pKeyCount - 1] != null) {
				bindStrings = cast arr[pKeyCount - 1];
			}
		}

		if (bindStrings == null && NoteVariables.defaultBinds != null && NoteVariables.defaultBinds.length >= pKeyCount) {
			bindStrings = NoteVariables.defaultBinds[pKeyCount - 1];
		}

		var fallback4K:Array<String> = ["A", "S", "W", "D"];
		var fallbackArrows:Array<String> = ["LEFT", "DOWN", "UP", "RIGHT"];

		for (i in 0...pKeyCount) {
			var keyList:Array<FlxKey> = [];

			if (bindStrings != null && i < bindStrings.length) {
				var kStr:String = bindStrings[i];
				var kVal:FlxKey = FlxKey.fromString(kStr);
				if (kVal != NONE && !keyList.contains(kVal)) keyList.push(kVal);
			}

			if (pKeyCount == 4) {
				var wasdKey:FlxKey = FlxKey.fromString(fallback4K[i]);
				var arrowKey:FlxKey = FlxKey.fromString(fallbackArrows[i]);
				if (wasdKey != NONE && !keyList.contains(wasdKey)) keyList.push(wasdKey);
				if (arrowKey != NONE && !keyList.contains(arrowKey)) keyList.push(arrowKey);
			}

			cachedPlayerKeys.push(keyList);
		}
	}

	function updateInfoText():Void {
		var spdStr:String = FlxMath.roundDecimal(playbackRate, 2) + "x";
		var modeStr:String = isBotplay ? "BOTPLAY" : "PLAYER";
		var sideStr:String = playAsOpponent ? "OPPONENT" : "PLAYER";
		infoTxt.text = 'ESC: Exit | SPACE: Play/Pause | R: Restart | B: Mode (${modeStr}) | O: Side (${sideStr}) | I: Input (${inputMode})\nG: GhostTap (${ghostTapping ? "ON" : "OFF"}) | H: HUD (${showJudgements ? "ON" : "OFF"}) | M: MS (${displayMs ? "ON" : "OFF"}) | Shift+Arrows: Speed (${spdStr})';
	}

	inline function resolveMustPress(section:Dynamic, note:Int, keyCnt1:Int, keyCnt2:Int):Bool {
		var hit:Bool = section.mustHitSection;
		if (note >= (!hit ? keyCnt2 : keyCnt1)) hit = !hit;
		return hit;
	}

	function generateNotes():Void {
		if (_song == null || _song.notes == null) return;
		unspawnNotes = [];
		unspawnIndex = 0;

		var keyCnt2:Int = _song.keyCount > 0 ? _song.keyCount : 4;
		var keyCnt1:Int = _song.playerKeyCount > 0 ? _song.playerKeyCount : 4;
		var speed:Float = (_song != null && _song.speed > 0) ? _song.speed : 1.0;
		var isDownscroll:Bool = Options.getData("downscroll") == true;

		var chartOffset:Float = (_song != null && _song.chartOffset != null) ? _song.chartOffset : 0;

		for (section in _song.notes) {
			if (section == null || section.sectionNotes == null) continue;
			for (n in section.sectionNotes) {
				var daStrumTime:Float = n[0] + Conductor.offset + chartOffset;
				var noteInfo:Int = n[1];
				var daSus:Float = n[2];
				var daType:String = (n.length > 4 && n[4] != null) ? n[4] : "default";
				var stID:Int = (n.length > 5 && n[5] != null) ? Std.int(n[5]) : -1;
				var kCount:Int = 4;
				if (stID >= 0 && _song.strumLines != null && stID < _song.strumLines.length) {
					var st = _song.strumLines[stID];
					if (st != null && st.keyCount != null && st.keyCount > 0) kCount = Std.int(st.keyCount);
				}

				var gottaHitNote = resolveMustPress(section, noteInfo, keyCnt1, keyCnt2);
				var noteData = Std.int(noteInfo % (keyCnt2 + keyCnt1));

				if (stID >= 0 && _song.strumLines != null && stID < _song.strumLines.length) {
					gottaHitNote = (_song.strumLines[stID].type == 1);
					noteData = Std.int(noteInfo % kCount);
				} else {
					if (section.mustHitSection && noteData >= keyCnt1) {
						noteData = (noteData - keyCnt1) % keyCnt2;
					} else if (!section.mustHitSection && noteData >= keyCnt2) {
						noteData = (noteData - keyCnt2) % keyCnt1;
					}
				}

				var parentNote:Note = new Note(daStrumTime, noteData, null, false, 0, daType, _song, [0], gottaHitNote, false, stID, gottaHitNote ? keyCnt1 : keyCnt2);
				parentNote.sustainLength = daSus;
				parentNote.scrollFactor.set(0, 0);
				unspawnNotes.push(parentNote);

				var sustainGroup:Array<Note> = [];
				var susRealEnd:Float = daStrumTime + daSus;
				var susStarts:Array<Float> = Conductor.sustainSteps(daStrumTime, daSus);
				if (susStarts.length == 0 && daSus > 0) susStarts.push(daStrumTime);

				var susSpace:Float = (isDownscroll ? 1 : FlxMath.roundDecimal(speed, 2));

				for (i in 0...susStarts.length) {
					var oldNote:Note = unspawnNotes[unspawnNotes.length - 1];

					var susSegStart:Float = susStarts[i];
					var susSegEnd:Float = (i < susStarts.length - 1) ? susStarts[i + 1] : Conductor.sustainPieceEnd(susSegStart, susRealEnd);

					var sustainNote:Note = new Note(
						susSegStart + (susSegEnd - susSegStart) / susSpace,
						noteData,
						oldNote,
						true,
						0,
						daType,
						_song,
						[0],
						gottaHitNote,
						false,
						stID,
						gottaHitNote ? keyCnt1 : keyCnt2
					);

					sustainNote.sustainMs = susSegEnd - susSegStart;
					sustainNote.scrollFactor.set(0, 0);
					sustainNote.speed = speed;
					sustainNote.mustPress = gottaHitNote;
					sustainNote.correctionOffset = isDownscroll ? 0 : parentNote.height / 2;

					unspawnNotes.push(sustainNote);
					sustainGroup.push(sustainNote);
					sustainNote.sustains = sustainGroup;
				}

				parentNote.sustains = sustainGroup;
			}
		}

		unspawnNotes.sort((a, b) -> {
			if (a.strumTime != b.strumTime) return a.strumTime < b.strumTime ? -1 : 1;
			return a.isSustainNote ? -1 : 1;
		});
	}

	override public function update(elapsed:Float):Void {
		super.update(elapsed);

		if (subMusic != null && subMusic.playing) {
			Conductor.songPosition += (elapsed * 1000.0) * playbackRate;
			if (Math.abs((subMusic.time + Conductor.offset) - Conductor.songPosition) > 20) {
				Conductor.songPosition = subMusic.time + Conductor.offset;
			}
		}

		if (subVocals != null && subMusic != null && Math.abs(subVocals.time - subMusic.time) > 40) {
			subVocals.time = subMusic.time;
		}

		var songPos:Float = Conductor.songPosition;

		// Spool incoming notes via index pointer (O(1) amortized, zero stutter)
		while (unspawnIndex < unspawnNotes.length && unspawnNotes[unspawnIndex].strumTime - songPos < 1500) {
			var note = unspawnNotes[unspawnIndex++];
			if (note.isSustainNote)
				sustainsGroup.add(note);
			else
				notesGroup.add(note);
		}

		var pKeyCount:Int = (playerStrums != null && playerStrums.length > 0) ? playerStrums.length : 4;

		// Player input update
		if (!isBotplay && playerStrums != null && playerStrums.length > 0) {
			var justPressedArray:Array<Bool> = [for (i in 0...pKeyCount) false];
			var heldArray:Array<Bool> = [for (i in 0...pKeyCount) false];
			var justReleasedArray:Array<Bool> = [for (i in 0...pKeyCount) false];

			for (i in 0...pKeyCount) {
				var keys = (i < cachedPlayerKeys.length) ? cachedPlayerKeys[i] : [];
				for (k in keys) {
					if (FlxG.keys.checkStatus(k, JUST_PRESSED)) justPressedArray[i] = true;
					if (FlxG.keys.checkStatus(k, PRESSED)) heldArray[i] = true;
					if (FlxG.keys.checkStatus(k, JUST_RELEASED)) justReleasedArray[i] = true;
				}
			}

			// Key press handling
			if (justPressedArray.contains(true)) {
				cachedPossibleNotes.resize(0);
				notesGroup.forEachAlive(function(note:Note) {
					note.calculateCanBeHit();
					var noteInWindow:Bool = note.mustPress ? note.canBeHit : (Math.abs(note.strumTime - songPos) <= Conductor.safeZoneOffset);
					if (isPlayerControlledNote(note) && noteInWindow && !note.tooLate && !note.wasGoodHit && !note.isSustainNote) {
						cachedPossibleNotes.push(note);
					}
				});

				if (inputMode == "cne") {
					cachedPossibleNotes.sort((a, b) -> {
						var distA:Float = Math.abs(a.strumTime - songPos);
						var distB:Float = Math.abs(b.strumTime - songPos);
						return (distA > distB) ? 1 : ((distA < distB) ? -1 : 0);
					});
				} else if (inputMode == "rhythm") {
					cachedPossibleNotes.sort((b, a) -> Std.int(songPos - a.strumTime));
				} else if (inputMode == "psych") {
					cachedPossibleNotes.sort((a, b) -> {
						if (a.lowPriority && !b.lowPriority) return 1;
						else if (!a.lowPriority && b.lowPriority) return -1;
						return (a.strumTime > b.strumTime) ? 1 : ((a.strumTime < b.strumTime) ? -1 : 0);
					});
				} else {
					cachedPossibleNotes.sort((a, b) -> Std.int(a.strumTime - b.strumTime));
				}

				for (i in 0...pKeyCount) {
					if (justPressedArray[i]) {
						var strum:StrumNote = playerStrums.members[i];
						if (strum != null) {
							strum.playAnim("pressed", true);
							strum.resetAnim = 0;
						}

						var colNotes:Array<Note> = cachedPossibleNotes.filter(n -> (n.noteData % pKeyCount) == i);
						if (colNotes.length > 0) {
							var hitNote = colNotes[0];

							if (inputMode == "psych" && colNotes.length > 1) {
								var secondNote = colNotes[1];
								if (Math.abs(secondNote.strumTime - hitNote.strumTime) < 2.0) {
									secondNote.kill();
									notesGroup.remove(secondNote, true);
									secondNote.destroy();
									cachedPossibleNotes.remove(secondNote);
								}
							}

							goodNoteHit(hitNote, false);
						} else {
							if (!ghostTapping) {
								noteMiss(i);
							}
						}
					}
				}
			}

			// Key release handling
			for (i in 0...pKeyCount) {
				if (justReleasedArray[i] || (!heldArray[i] && (inputMode == "cne" || inputMode == "psych"))) {
					var strum:StrumNote = playerStrums.members[i];
					if (strum != null && strum.animation.curAnim != null && (strum.animation.curAnim.name == "confirm" || strum.animation.curAnim.name == "pressed")) {
						strum.playAnim("static", true);
						strum.resetAnim = 0;
					}
				}
			}

			// Hold sustain handling
			sustainsGroup.forEachAlive(function(note:Note) {
				if (isPlayerControlledNote(note) && !note.wasGoodHit) {
					var col:Int = note.noteData % pKeyCount;
					var parent:Note = note.getParentNote();
					var parentHit:Bool = (parent == null || parent.wasGoodHit);

					if (heldArray[col]) {
						if (parentHit && songPos >= note.strumTime - (Conductor.safeZoneOffset * 0.5)) {
							note.wasGoodHit = true;
							var strum:StrumNote = playerStrums.members[col];
							if (strum != null) {
								strum.playAnim("confirm", true);
								strum.resetAnim = 0.15;
							}
							note.kill();
						}
					} else {
						if ((inputMode == "psych" || inputMode == "cne") && note.canBeHit && parent != null && parent.wasGoodHit) {
							noteMiss(col);
							note.tooLate = true;
							note.kill();
						}
					}
				}
			});
		}

		// Update note positions, sustain clipping, auto-play, and miss checks
		updateNoteGroupPositions(sustainsGroup, pKeyCount, songPos);
		updateNoteGroupPositions(notesGroup, pKeyCount, songPos);

		// Update strum timers
		if (opponentStrums != null) {
			for (s in opponentStrums.members) {
				if (s != null && s.resetAnim > 0) {
					s.resetAnim -= elapsed;
					if (s.resetAnim <= 0) {
						s.playAnim("static", true);
						s.resetAnim = 0;
					}
				}
			}
		}
		if (playerStrums != null) {
			for (s in playerStrums.members) {
				if (s != null && s.resetAnim > 0) {
					s.resetAnim -= elapsed;
					if (s.resetAnim <= 0) {
						s.playAnim("static", true);
						s.resetAnim = 0;
					}
				}
			}
		}

		// Live Judgements HUD text (only re-render when values change)
		if (showJudgements) {
			if (statsDirty) {
				statsDirty = false;
				var accStr:String = FlxMath.roundDecimal(accuracy, 2) + "%";
				judgementsTxt.text = 'Score: ${songScore} | Combo: ${combo} | Acc: ${accStr}\n'
					+ 'Marv: ${marvelousCount} | Sick: ${sickCount} | Good: ${goodCount} | Bad: ${badCount} | Shit: ${shitCount} | Miss: ${missesCount}';
			}
		} else {
			if (judgementsTxt.text != "") {
				judgementsTxt.text = "";
			}
		}

		var curTime:Float = (subMusic != null) ? subMusic.time : 0;
		var curSecTotal:Int = Std.int(curTime / 1000);
		if (curSecTotal != lastTimeSec || playbackRate != lastPlaybackRate) {
			lastTimeSec = curSecTotal;
			lastPlaybackRate = playbackRate;
			var durTime:Float = (subMusic != null) ? subMusic.length : 0;
			var curMin:Int = Std.int(Math.floor(curTime / 60000));
			var curSec:Int = Std.int(Math.floor((curTime % 60000) / 1000));
			var durMin:Int = Std.int(Math.floor(durTime / 60000));
			var durSec:Int = Std.int(Math.floor((durTime % 60000) / 1000));
			var spdStr:String = FlxMath.roundDecimal(playbackRate, 2) + "x";
			timeTxt.text = 'Time: ${StringTools.lpad(Std.string(curMin), "0", 2)}:${StringTools.lpad(Std.string(curSec), "0", 2)} / ${StringTools.lpad(Std.string(durMin), "0", 2)}:${StringTools.lpad(Std.string(durSec), "0", 2)} | Speed: ${spdStr}';
		}

		// Hotkey Controls
		if (FlxG.keys.justPressed.B) {
			isBotplay = !isBotplay;
			statsDirty = true;
			updateInfoText();
		}

		if (FlxG.keys.justPressed.O) {
			playAsOpponent = !playAsOpponent;
			setupStrumlineTargeting();
			setupPlayerKeybinds();
			repositionStrums();
			statsDirty = true;
			updateInfoText();
		}

		if (FlxG.keys.justPressed.I) {
			switch (inputMode) {
				case "standard": inputMode = "rhythm";
				case "rhythm": inputMode = "cne";
				case "cne": inputMode = "psych";
				case "psych": inputMode = "standard";
				default: inputMode = "psych";
			}
			updateInfoText();
		}

		if (FlxG.keys.justPressed.G) {
			ghostTapping = !ghostTapping;
			updateInfoText();
		}

		if (FlxG.keys.justPressed.H) {
			showJudgements = !showJudgements;
			statsDirty = true;
			updateInfoText();
		}

		if (FlxG.keys.justPressed.M) {
			displayMs = !displayMs;
			updateInfoText();
		}

		var changedRate:Bool = false;
		if (FlxG.keys.pressed.SHIFT) {
			if (FlxG.keys.justPressed.RIGHT) {
				playbackRate = FlxMath.roundDecimal(Math.min(3.0, playbackRate + 0.1), 2);
				changedRate = true;
			} else if (FlxG.keys.justPressed.LEFT) {
				playbackRate = FlxMath.roundDecimal(Math.max(0.1, playbackRate - 0.1), 2);
				changedRate = true;
			}
		}

		if (FlxG.keys.justPressed.ZERO) {
			playbackRate = 1.0;
			changedRate = true;
		}

		if (changedRate) {
			if (subMusic != null) subMusic.pitch = playbackRate;
			if (subVocals != null) subVocals.pitch = playbackRate;
			updateInfoText();
		}

		if (FlxG.keys.justPressed.ESCAPE || FlxG.keys.justPressed.BACKSPACE) {
			exitSubstate();
			return;
		}

		if (FlxG.keys.justPressed.SPACE) {
			if (subMusic != null) {
				if (subMusic.playing) {
					subMusic.pause();
					if (subVocals != null) subVocals.pause();
				} else {
					subMusic.play();
					if (subVocals != null) subVocals.play();
				}
			}
		}

		if (FlxG.keys.justPressed.R) {
			restartPlaytest();
		}
	}

	function updateNoteGroupPositions(group:FlxTypedGroup<Note>, pKeyCount:Int, songPos:Float):Void {
		var isDown:Bool = Options.getData("downscroll") == true;

		group.forEachAlive(function(note:Note) {
			var strumGroup:FlxTypedGroup<StrumNote> = note.mustPress ? playerStrums : opponentStrums;

			if (strumGroup != null && strumGroup.length > 0) {
				var targetStrum:StrumNote = strumGroup.members[note.noteData % strumGroup.length];

				if (targetStrum != null) {
					note.x = targetStrum.x + (targetStrum.width / 2) - (note.width / 2);
					note.calculateY(targetStrum);

					// Precise sustain note clipping matching engine gameplay
					if (note.isSustainNote) {
						if (note.sustainClipRect == null)
							note.sustainClipRect = new FlxRect(0, 0, note.frameWidth, note.frameHeight);
						else
							note.sustainClipRect.set(0, 0, note.frameWidth, note.frameHeight);

						var targetStrumY:Float = targetStrum.y;
						var targetStrumH:Float = targetStrum.height;
						if (isDown) {
							note.sustainClipRect.height = (targetStrumY + (targetStrumH / 2) - note.y) / note.scale.y;
							note.sustainClipRect.y = note.frameHeight - note.sustainClipRect.height;
						} else {
							note.sustainClipRect.y = (targetStrumY + (targetStrumH / 2) - note.y) / note.scale.y;
							note.sustainClipRect.height -= note.sustainClipRect.y;
						}
						if (note.sustainClipRect.height < 0) note.sustainClipRect.height = 0;
						if (note.sustainClipRect.y < 0) note.sustainClipRect.y = 0;
						note.clipRect = note.sustainClipRect;
					}

					var isPlayerNote:Bool = isPlayerControlledNote(note);

					if (isBotplay && isPlayerNote) {
						if (songPos >= note.strumTime && !note.wasGoodHit) {
							goodNoteHit(note, true);
						}
					} else if (!isPlayerNote) {
						if (songPos >= note.strumTime && !note.wasGoodHit) {
							note.wasGoodHit = true;
							var oppStrum:StrumNote = strumGroup.members[note.noteData % strumGroup.length];
							if (oppStrum != null && !note.isSustainNote) {
								oppStrum.playAnim("confirm", true);
								oppStrum.resetAnim = 0.15;
							}
							if (subVocals != null) subVocals.volume = 1;
							note.kill();
						}
					} else {
						// Late miss check for player-controlled notes
						if (!note.wasGoodHit && songPos > note.strumTime + (note.isSustainNote ? 100 : Conductor.safeZoneOffset)) {
							noteMiss(note.noteData % pKeyCount, note);
						}
					}
				}
			}
		});
	}

	function goodNoteHit(note:Note, isAuto:Bool):Void {
		note.wasGoodHit = true;
		var noteDiff:Float = note.strumTime - Conductor.songPosition;
		if (isAuto) noteDiff = 0;

		var daRating:String = Ratings.getRating(Math.abs(noteDiff));

		if (daRating == "shit" && Options.getData("missOnShit") == true) {
			noteMiss(note.noteData % ((playerStrums != null && playerStrums.length > 0) ? playerStrums.length : 4), note);
			return;
		}

		songScore += Ratings.getScore(daRating);
		combo++;
		totalNotes++;

		switch (daRating) {
			case "marvelous":
				marvelousCount++;
				hitNotes += 1.0;
			case "sick":
				sickCount++;
				hitNotes += 1.0;
			case "good":
				goodCount++;
				hitNotes += 0.8;
			case "bad":
				badCount++;
				hitNotes += 0.3;
			case "shit":
				shitCount++;
				if (Options.getData("antiMash") == true) songScore -= 50;
		}

		if (totalNotes > 0) accuracy = (hitNotes / totalNotes) * 100.0;
		statsDirty = true;

		var strumGroup:FlxTypedGroup<StrumNote> = note.mustPress ? playerStrums : opponentStrums;

		if (strumGroup != null && strumGroup.length > 0) {
			var targetStrum:StrumNote = strumGroup.members[note.noteData % strumGroup.length];
			if (targetStrum != null && !note.isSustainNote) {
				targetStrum.playAnim("confirm", true);
				targetStrum.resetAnim = 0.15;
			}
		}

		if (!note.isSustainNote && hitSoundString != "none" && hitSoundString != "") {
			try {
				FlxG.sound.play(Paths.sound("hitsounds/" + hitSoundString.toLowerCase()), hitSoundVolume);
			} catch (e:Dynamic) {}
		}

		if (ratingsAndCombo || displayMs) {
			popUpScore(daRating, noteDiff, isAuto);
		}

		note.kill();
	}

	function noteMiss(direction:Int, ?note:Note):Void {
		if (note != null && inputMode == "psych") {
			var daNote = note;
			var targetGroup:FlxTypedGroup<Note> = daNote.isSustainNote ? sustainsGroup : notesGroup;
			targetGroup.forEachAlive(function(n:Note) {
				if (daNote != n && daNote.mustPress && daNote.noteData == n.noteData && daNote.isSustainNote == n.isSustainNote && Math.abs(daNote.strumTime - n.strumTime) < 1.0) {
					n.kill();
					targetGroup.remove(n, true);
					n.destroy();
				}
			});
		}

		combo = 0;
		missesCount++;
		totalNotes++;
		songScore -= 10;
		if (totalNotes > 0) accuracy = (hitNotes / totalNotes) * 100.0;
		statsDirty = true;

		if (missSounds.length > 0) {
			var snd:String = missSounds[FlxG.random.int(0, missSounds.length - 1)];
			FlxG.sound.play(Paths.sound(snd), FlxG.random.float(0.1, 0.2));
		}

		if (displayMs) {
			popUpScore("shit", 166.0, false);
		}

		if (note != null) {
			note.wasGoodHit = true;
			note.kill();
		}
	}

	function popUpScore(daRating:String, noteDiff:Float, isAuto:Bool):Void {
		var initX:Float = FlxG.width * 0.45;
		var initY:Float = (FlxG.height * 0.4) - 60;

		if (ratingsAndCombo) {
			var bData:BitmapData = uiMap.get(daRating);
			if (bData == null && daRating == "marvelous") bData = uiMap.get("sick");

			if (bData != null) {
				var ratingSpr:FlxSprite = ratingsGroup.recycle(FlxSprite);
				ratingSpr.revive();
				ratingSpr.loadGraphic(bData);
				ratingSpr.screenCenter();
				ratingSpr.x = initX;
				ratingSpr.y = initY;
				ratingSpr.velocity.y = FlxG.random.int(-140, -175);
				ratingSpr.acceleration.y = 550;
				ratingSpr.velocity.x = FlxG.random.int(-10, 10);
				ratingSpr.setGraphicSize(Std.int(ratingSpr.width * 0.7));
				ratingSpr.updateHitbox();
				ratingSpr.alpha = 1;
				ratingsGroup.add(ratingSpr);

				FlxTween.tween(ratingSpr, {alpha: 0}, 0.35, {startDelay: 0.2, onComplete: _ -> {
					if (ratingSpr != null && ratingsGroup != null && ratingsGroup.members != null && ratingsGroup.members.contains(ratingSpr)) {
						ratingsGroup.remove(ratingSpr, true);
						ratingSpr.destroy();
					}
				}});
			}

			if (combo >= 10 || daRating == "sick" || daRating == "marvelous") {
				var digits:Array<String> = StringTools.lpad(Std.string(combo), "0", 3).split("");
				var startComboX:Float = initX + 20;

				for (idx in 0...digits.length) {
					var numData:BitmapData = uiMap.get(digits[idx]);
					if (numData != null) {
						var numSpr:FlxSprite = comboGroup.recycle(FlxSprite);
						numSpr.revive();
						numSpr.loadGraphic(numData);
						numSpr.screenCenter();
						numSpr.x = startComboX + (idx * 38);
						numSpr.y = initY + 80;
						numSpr.velocity.y = FlxG.random.int(-140, -160);
						numSpr.acceleration.y = 300;
						numSpr.velocity.x = FlxG.random.float(-5, 5);
						numSpr.setGraphicSize(Std.int(numSpr.width * 0.5));
						numSpr.updateHitbox();
						numSpr.alpha = 1;
						comboGroup.add(numSpr);

						FlxTween.tween(numSpr, {alpha: 0}, 0.35, {startDelay: 0.2, onComplete: _ -> {
							if (numSpr != null && comboGroup != null && comboGroup.members != null && comboGroup.members.contains(numSpr)) {
								comboGroup.remove(numSpr, true);
								numSpr.destroy();
							}
						}});
					}
				}
			}
		}

		if (displayMs) {
			var noteMath:Float = -FlxMath.roundDecimal(noteDiff, 2);
			if (Math.abs(noteMath) == 0) noteMath = 0;

			var msTxt:FlxText = msGroup.recycle(FlxText);
			msTxt.revive();
			var sign:String = (noteMath >= 0) ? "+" : "";
			msTxt.text = '${sign}${noteMath} ms' + (isAuto ? " (BOT)" : "");
			msTxt.setFormat(Paths.font("vcr.ttf"), 15, (noteMath >= 0 ? FlxColor.ORANGE : FlxColor.CYAN), CENTER, OUTLINE, FlxColor.BLACK);
			msTxt.borderSize = 1.2;
			msTxt.setPosition(initX - 20, initY + 130);
			msTxt.alpha = 1;
			msGroup.add(msTxt);

			FlxTween.tween(msTxt, {y: msTxt.y - 20, alpha: 0}, 0.45, {onComplete: _ -> {
				if (msTxt != null && msGroup != null && msGroup.members != null && msGroup.members.contains(msTxt)) {
					msGroup.remove(msTxt, true);
					msTxt.destroy();
				}
			}});
		}
	}

	function restartPlaytest():Void {
		Conductor.songPosition = _startTime + Conductor.offset;
		if (subMusic != null) {
			subMusic.time = _startTime;
			subMusic.pitch = playbackRate;
			subMusic.play();
		}
		if (subVocals != null) {
			subVocals.time = _startTime;
			subVocals.pitch = playbackRate;
			subVocals.play();
		}

		notesGroup.clear();
		sustainsGroup.clear();

		unspawnIndex = 0;
		for (n in unspawnNotes) {
			n.revive();
			n.wasGoodHit = false;
			n.tooLate = false;
			n.clipRect = null;
		}

		if (_startTime > 0) {
			var threshold:Float = _startTime + Conductor.offset - 150;
			while (unspawnIndex < unspawnNotes.length && unspawnNotes[unspawnIndex].strumTime < threshold) {
				unspawnIndex++;
			}
		}

		combo = 0;
		songScore = 0;
		marvelousCount = 0;
		sickCount = 0;
		goodCount = 0;
		badCount = 0;
		shitCount = 0;
		missesCount = 0;
		hitNotes = 0;
		totalNotes = 0;
		accuracy = 0;

		ratingsGroup.clear();
		comboGroup.clear();
		msGroup.clear();
		statsDirty = true;
		lastTimeSec = -1;

		if (opponentStrums != null) {
			for (s in opponentStrums.members) {
				if (s != null) {
					s.playAnim("static", true);
					s.resetAnim = 0;
				}
			}
		}
		if (playerStrums != null) {
			for (s in playerStrums.members) {
				if (s != null) {
					s.playAnim("static", true);
					s.resetAnim = 0;
				}
			}
		}
	}

	public function exitSubstate():Void {
		if (subMusic != null) {
			subMusic.stop();
			FlxG.sound.list.remove(subMusic, true);
			subMusic.destroy();
			subMusic = null;
		}
		if (subVocals != null) {
			subVocals.stop();
			subVocals.destroy();
			subVocals = null;
		}
		if (uiMap != null) {
			uiMap.clear();
			uiMap = null;
		}
		close();
	}

	override function destroy():Void {
		if (subMusic != null) {
			subMusic.stop();
			FlxG.sound.list.remove(subMusic, true);
			subMusic.destroy();
			subMusic = null;
		}
		if (subVocals != null) {
			subVocals.stop();
			subVocals.destroy();
			subVocals = null;
		}
		if (uiMap != null) {
			uiMap.clear();
			uiMap = null;
		}
		super.destroy();
	}
}
