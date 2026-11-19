package game;

import utilities.NoteVariables;
import haxe.Json;
import lime.utils.Assets;

class SongLoader {


	public static function getPath(difficulty:String, ?folder:String, ?mix:String):String {
		var chartSuffix:String = '';
		if (difficulty.toLowerCase() == 'erect' || difficulty.toLowerCase() == 'nightmare') {
			chartSuffix = '-erect';
		}
		if (mix != null) {
			chartSuffix += '-${mix.toLowerCase()}';
		}
		folder = folder.toLowerCase();
		difficulty = difficulty.toLowerCase();
		var path:String = Paths.json('song data/$folder/$folder-chart$chartSuffix');
		if (!Assets.exists(path)) { // prefer FNFC charts lol
			path = Paths.json('song data/$folder/$folder${difficulty != 'normal' ? '-$difficulty' : ''}');
		}

		return path;
	}

	public static function loadFromJson(difficulty:String, ?folder:String, ?mix:String):SongData {
		var path:String = getPath(difficulty, folder, mix);
		var raw:String = Assets.getText(path).trim();
		if (raw == '') { // should never happen but just in case
			var tutorialPath:String = getPath('normal', 'tutorial', null);
			if (!Assets.exists(tutorialPath)) {
				trace("Why the fuck did you remove tutorial and the song doesn't exist too");
				// Never return null here: downstream code dereferences the result
				// (e.g. PlayState.SONG.song) and a null crashes the host mid-pick,
				// which the opponent then reads as a disconnect/timeout.
				return parseRaw("", folder, difficulty, mix);
			}

			raw = Assets.getText(tutorialPath).trim();
			return parseRaw(raw, folder, difficulty, mix, true);
		}

		return parseRaw(raw, folder, difficulty, mix);
	}

	public static function parseRaw(raw:String, songName:String, difficulty:String, ?mix:String, force:Bool = false):SongData {
		var parsedJSON:Dynamic = null;
		
		try {
			if (raw != null && raw != "") {
				parsedJSON = Json.parse(raw);
			} else {
				throw "Raw JSON string is empty or null";
			}
		} catch(e:Dynamic) {
			trace("CRITICAL ERROR PARSING JSON FOR SONG: " + songName + " -> " + e);
			// Fallback dummy song to prevent game crash
			return {
				song: songName != null ? songName : "Error",
				notes: [],
				bpm: 100,
				needsVoices: false,
				speed: 1.0,
				player1: "bf",
				player2: "dad",
				player3: "gf",
				validScore: false,
				gf: "gf",
				stage: "stage",
				ui_Skin: "default",
				modchartPath: "",
				modchartingTools: false,
				cameraEvents: false,
				keyCount: 4,
				playerKeyCount: 4,
				events: [],
				cutscene: "",
				endCutscene: "",
				timescale: [4, 4],
				chartOffset: 0.0,
				specialAudioName: null,
				chartType: LEGACY,
				gfVersion: "gf",
				mania: null,
				moveCamera: true
			};
		}

		if (parsedJSON.codenameChart == true || parsedJSON.strumLines != null) {
			return sanitizeSong(parseCodename(parsedJSON, songName, difficulty, mix));
		} else if (parsedJSON.song == null) { // invalid chart OR (more likely) new format!
			return sanitizeSong(parseFNFC(parsedJSON, songName, difficulty, mix));
		} else {
			return sanitizeSong(parseLegacy(parsedJSON, songName, force));
		}
	}

	/**
	 * Ignores chart values we can't actually use so they don't crash the game later.
	 * Currently guards the UI skin, falling back to the default when missing.
	 */
	public static function sanitizeSong(song:SongData):SongData
	{
		if (song == null)
			return null;

		if (song.ui_Skin != null && song.ui_Skin != "default") {
			if (!Assets.exists(Paths.txt("ui skins/" + song.ui_Skin + "/config"))) {
				trace('UI skin "' + song.ui_Skin + '" not found, ignoring and falling back to default');
				song.ui_Skin = "default";
			}
		}

		return song;
	}

	public static function parseFNFC(parsedJSON:Dynamic, songName:String, difficulty:String, ?mix:String):SongData {
		difficulty = difficulty.toLowerCase();
		var chartSuffix:String = '';
		if (difficulty.toLowerCase() == 'erect' || difficulty.toLowerCase() == 'nightmare') {
			chartSuffix = '-erect';
		}
		if (mix != null) {
			chartSuffix += '-${mix.toLowerCase()}';
		}
		var metaPath:String = Paths.json('song data/$songName/$songName-metadata$chartSuffix');
		if (!Assets.exists(metaPath)) {
			if (Assets.exists(metaPath.toLowerCase())) {
				metaPath = metaPath.toLowerCase();
			} else {
				trace('You can\'t load an FNFC chart without putting in the metadata!', ERROR);
				return null;
			}
		}

		var metadata:FNFCMetadata = cast Json.parse(Assets.getText(metaPath).trim());
		var song:FNFCSong = cast parsedJSON;
		// TODO: BPM CHANGES
		var output:SongData = {
			validScore: true,
			keyCount: 4,
			playerKeyCount: 4,
			chartOffset: 0.0,
			timescale: [4, 4],
			needsVoices: true, // no way to specify this really
			song: metadata.songName,
			bpm: metadata.timeChanges[0].bpm,
			player1: metadata.playData.characters.player,
			player2: metadata.playData.characters.opponent,
			gf: metadata.playData.characters.girlfriend,
			stage: metadata.playData.stage,
			speed: Reflect.field(song.scrollSpeed, difficulty),
			ui_Skin: 'default',
			notes: [
				{
					sectionNotes: [],
					lengthInSteps: 16,
					mustHitSection: true,
					bpm: metadata.timeChanges[0].bpm,
					changeBPM: false,
					altAnim: false,
					timeScale: [0, 0],
					changeTimeScale: false
				}
			],
			specialAudioName: null,
			player3: null,
			modchartingTools: false,
			modchartPath: null,
			cameraEvents: false,
			mania: null,
			gfVersion: null,
			events: [],
			endCutscene: metadata.playData.endCutscene,
			cutscene: metadata.playData.cutscene,
			moveCamera: true,
			chartType: VSLICE
		};

		// should work with custom skins i think
		if (metadata.playData.noteStyle != 'funkin') {
			output.ui_Skin = metadata.playData.noteStyle;
		}

		if (song == null) {
			trace("Couldn't find FNFC chart json properly");
			return output;
		}

		var notes:Array<FNFCNote> = cast Reflect.field(song.notes, difficulty);
		if (notes == null) {
			trace("Couldn't find the difficulty '" + difficulty + "' for the chart being loaded, sorry! (FNFC)");
			return output;
		}
		var bpm:Float = metadata.timeChanges[0].bpm;
		var curSection:Int = 0;
		var crochet:Float = Conductor.calculateCrochet(bpm);
		for (note in notes) {
			if (Math.ceil(note.t) >= Math.floor((curSection + 1) * (crochet * 4))) {
				curSection++;
				output.notes.push({
					sectionNotes: [],
					lengthInSteps: 16,
					mustHitSection: true,
					bpm: bpm,
					changeBPM: false,
					altAnim: false,
					timeScale: [0, 0],
					changeTimeScale: false
				});
			}
			output.notes[curSection].sectionNotes.push([note.t, note.d, note.l, 0, note.k ?? 'default']);
		}

		// engine specific shit

		// TODO: implement all events
		for (event in song.events) {
			switch (event.e.toLowerCase()) {
				case 'focuscamera':
					output.events.push([event.e, event.t, event.v.char ?? event.v, '${event.v.x},${event.v.y}']);
				case 'zoomcamera':
					output.events.push([event.e, event.t, event.v.zoom, '${event.v.ease},${event.v.duration}']);
				case 'setcamerabop':
					output.events.push(['change camera zoom strength', event.t, event.v.intensity, event.v.rate]);
				case 'playanimation':
					output.events.push([event.e, event.t, event.v.target, '${event.v.anim},${event.v.force}']);
				case 'scrollspeed':
					output.events.push([
						event.e,
						event.t,
						'${event.v.duration},${event.v.scroll}',
						'${event.v.strumline},${event.v.ease},${event.v.absolute}'
					]);
				default:
					output.events.push([event.e, event.t, Std.string(event.v), '']);
			}
		}

		return output;
	}

	public static function makeDefaultSongData(?songName:String, ?events:Array<Array<Dynamic>>):SongData {
		return {
			song: songName != null ? songName : "Song",
			notes: [],
			bpm: 100.0,
			needsVoices: true,
			speed: 1.0,
			player1: "bf",
			player2: "dad",
			validScore: true,
			gf: "gf",
			stage: "stage",
			ui_Skin: "default",
			modchartPath: "",
			modchartingTools: false,
			cameraEvents: false,
			keyCount: 4,
			playerKeyCount: 4,
			events: events != null ? events : [],
			cutscene: "",
			endCutscene: "",
			timescale: [4, 4],
			chartOffset: 0.0,
			specialAudioName: null,
			chartType: LEGACY,
			gfVersion: "gf",
			player3: "gf",
			mania: null,
			moveCamera: true
		};
	}

	public static function convertCneEvent(name:String, time:Float, params:Array<Dynamic>):Array<Array<Dynamic>> {
		if (name == null || name == "Intro Card") return [];

		switch (name.toLowerCase()) {
			case "camera movement":
				var target:Int = params.length > 0 ? Std.int(params[0]) : 0;
				var tween = params.length > 1 ? Std.string(params[1]) : "true";
				var steps = params.length > 2 ? Std.string(params[2]) : "4";
				var ease = params.length > 3 ? Std.string(params[3]) : "CLASSIC";
				var easeDir = params.length > 4 ? Std.string(params[4]) : "In";
				var offX = params.length > 5 ? Std.string(params[5]) : "0";
				var offY = params.length > 6 ? Std.string(params[6]) : "0";
				var p1 = (target == 1 ? "bf" : (target == 2 ? "gf" : "dad"));
				var p2 = '$steps,$ease,$easeDir,$offX,$offY,$tween';
				return [["focuscamera", time, p1, p2]];

			case "camera zoom":
				var zoomVal:Float = params.length > 1 ? Std.parseFloat(Std.string(params[1])) : 1.0;
				var steps = params.length > 3 ? Std.string(params[3]) : "4";
				var ease = params.length > 4 ? Std.string(params[4]) : "linear";
				var easeDir = params.length > 5 ? Std.string(params[5]) : "In";
				var cam = params.length > 2 ? Std.string(params[2]) : "camGame";
				var tween = params.length > 0 ? Std.string(params[0]) : "true";
				var mode = params.length > 6 ? Std.string(params[6]) : "direct";
				var mult = params.length > 7 ? Std.string(params[7]) : "false";
				return [["camera zoom", time, Std.string(zoomVal), '$steps,$ease,$easeDir,$cam,$tween,$mode,$mult']];

			case "camera position":
				var posX:Float = params.length > 0 ? Std.parseFloat(Std.string(params[0])) : 0.0;
				var posY:Float = params.length > 1 ? Std.parseFloat(Std.string(params[1])) : 0.0;
				var tween = params.length > 2 ? Std.string(params[2]) : "true";
				var steps = params.length > 3 ? Std.string(params[3]) : "4";
				var ease = params.length > 4 ? Std.string(params[4]) : "CLASSIC";
				var easeDir = params.length > 5 ? Std.string(params[5]) : "In";
				var isOffset = params.length > 6 ? Std.string(params[6]) : "false";
				return [["set camera position", time, Std.string(posX), '$posY,$steps,$ease,$easeDir,$tween,$isOffset']];

			case "add camera zoom":
				var addVal:Float = params.length > 0 ? Std.parseFloat(Std.string(params[0])) : 0.05;
				var camType:String = params.length > 1 ? Std.string(params[1]) : "camGame";
				return [["add camera zoom", time, Std.string(addVal), camType == "camHUD" ? Std.string(addVal) : "0"]];

			case "camera bop":
				var bopStrength:Float = params.length > 0 ? Std.parseFloat(Std.string(params[0])) : 0.1;
				return [["change camera zoom strength", time, Std.string(bopStrength), ""]];

			case "camera flash":
				var color:String = params.length > 1 ? Std.string(params[1]) : "#FFFFFF";
				var flashTime:Float = params.length > 2 ? Std.parseFloat(Std.string(params[2])) : 1.0;
				return [["camera flash", time, color, Std.string(flashTime)]];

			case "health drain":
				var drainAmount:Float = params.length > 0 ? Std.parseFloat(Std.string(params[0])) : 0.02;
				return [["health drain", time, Std.string(drainAmount), ""]];

			case "scroll speed change":
				var newSpeed:Float = params.length > 1 ? Std.parseFloat(Std.string(params[1])) : 1.0;
				var tweenDuration:Float = params.length > 2 ? Std.parseFloat(Std.string(params[2])) : 0.0;
				return [["scrollspeed", time, '${tweenDuration},${newSpeed}', "linear,Out,false"]];

			case "play animation":
				var charTarget:Int = params.length > 0 ? Std.int(params[0]) : 0;
				var animName:String = params.length > 1 ? Std.string(params[1]) : "idle";
				return [["play character animation", time, charTarget == 1 ? "bf" : (charTarget == 2 ? "gf" : "dad"), animName]];

			case "alt animation toggle":
				var enable:Bool = params.length > 0 ? (params[0] == true || params[0] == 1) : true;
				return [["alt animation toggle", time, enable ? "true" : "false", ""]];

			default:
				var p1:String = params.length > 0 ? Std.string(params[0]) : "";
				var p2:String = params.length > 1 ? Std.string(params[1]) : "";
				return [[name, time, p1, p2]];
		}
	}

	public static function normalizeEvents(rawEvents:Dynamic):Array<Array<Dynamic>> {
		var result:Array<Array<Dynamic>> = [];
		if (rawEvents == null) return result;

		var list:Array<Dynamic> = [];
		if (rawEvents is Array) {
			list = cast rawEvents;
		} else if (Reflect.hasField(rawEvents, "events") && rawEvents.events is Array) {
			list = cast rawEvents.events;
		}

		for (ev in list) {
			if (ev == null) continue;

			if (ev is Array && ev.length >= 2 && (ev[0] is Float || ev[0] is Int) && (ev[1] is Array)) {
				var time:Float = Std.parseFloat(Std.string(ev[0]));
				var subList:Array<Dynamic> = cast ev[1];
				for (sub in subList) {
					if (sub != null && sub is Array && sub.length >= 1) {
						var eName:String = Std.string(sub[0]);
						var v1:String = sub.length > 1 ? Std.string(sub[1]) : "";
						var v2:String = sub.length > 2 ? Std.string(sub[2]) : "";
						result.push([eName, time, v1, v2]);
					}
				}
			} else if (ev is Array && ev.length >= 2) {
				var eName:String = Std.string(ev[0]);
				var time:Float = Std.parseFloat(Std.string(ev[1]));
				if (Math.isNaN(time)) {
					if (!Math.isNaN(Std.parseFloat(Std.string(ev[0])))) {
						time = Std.parseFloat(Std.string(ev[0]));
						eName = Std.string(ev[1]);
					} else {
						time = 0.0;
					}
				}
				var v1:String = ev.length > 2 ? Std.string(ev[2]) : "";
				var v2:String = ev.length > 3 ? Std.string(ev[3]) : "";
				result.push([eName, time, v1, v2]);
			} else if (Reflect.hasField(ev, "name") && Reflect.hasField(ev, "time")) {
				var eName:String = Std.string(ev.name);
				var time:Float = Std.parseFloat(Std.string(ev.time));
				var params:Array<Dynamic> = Reflect.hasField(ev, "params") && ev.params != null && (ev.params is Array) ? cast ev.params : [];
				var convertedList = convertCneEvent(eName, time, params);
				if (convertedList.length > 0) {
					for (conv in convertedList) result.push(conv);
				} else {
					var p1:String = params.length > 0 ? Std.string(params[0]) : "";
					var p2:String = params.length > 1 ? Std.string(params[1]) : "";
					result.push([eName, time, p1, p2]);
				}
			} else if (Reflect.hasField(ev, "e") && Reflect.hasField(ev, "t")) {
				var eName:String = Std.string(ev.e);
				var time:Float = Std.parseFloat(Std.string(ev.t));
				var v:Dynamic = Reflect.field(ev, "v");
				var vStr:String = v != null ? Std.string(v) : "";
				result.push([eName, time, vStr, ""]);
			}
		}

		result.sort((a, b) -> Std.int(a[1] - b[1]));
		return result;
	}

	public static function parseLegacy(parsedJSON:Dynamic, ?songName:String, force:Bool = false):SongData {
		if (parsedJSON == null) {
			return makeDefaultSongData(songName);
		}

		var song:SongData = null;
		if (parsedJSON.song != null) {
			song = cast parsedJSON.song;
		} else if (parsedJSON.events != null) {
			var parsedEvents:Array<Array<Dynamic>> = [];
			if (Std.isOfType(parsedJSON.events, Array)) {
				for (ev in cast(parsedJSON.events, Array<Dynamic>)) {
					if (ev != null) {
						if (Std.isOfType(ev, Array)) {
							if (ev.length >= 2 && Std.isOfType(ev[1], Array)) {
								var time:Float = Std.parseFloat(Std.string(ev[0]));
								for (subEv in cast(ev[1], Array<Dynamic>)) {
									if (subEv != null && subEv.length >= 1) {
										var eName:String = Std.string(subEv[0]);
										var v1:String = subEv.length > 1 ? Std.string(subEv[1]) : "";
										var v2:String = subEv.length > 2 ? Std.string(subEv[2]) : "";
										parsedEvents.push([eName, time, v1, v2]);
									}
								}
							} else {
								parsedEvents.push(ev);
							}
						} else if (Reflect.hasField(ev, "name") && Reflect.hasField(ev, "time")) {
							var eName:String = Std.string(ev.name);
							var time:Float = Std.parseFloat(Std.string(ev.time));
							var params:Array<Dynamic> = Reflect.hasField(ev, "params") && ev.params != null ? cast ev.params : [];
							for (converted in convertCneEvent(eName, time, params)) {
								parsedEvents.push(converted);
							}
						} else if (Reflect.hasField(ev, "e") && Reflect.hasField(ev, "t")) {
							var eName:String = Std.string(ev.e);
							var time:Float = Std.parseFloat(Std.string(ev.t));
							var val:String = ev.v != null ? Std.string(ev.v) : "";
							parsedEvents.push([eName, time, val, ""]);
						}
					}
				}
			}
			return makeDefaultSongData(songName, parsedEvents);
		} else {
			song = cast parsedJSON;
		}

		if (song == null) {
			return makeDefaultSongData(songName);
		}

		song.validScore = true;

		if (force)
			song.song = songName;

		if (song.keyCount == null)
			song.keyCount = 4;

		// support the dumb psych exkey shit
		if (song.mania != null) {
			song.keyCount = song.mania + 1;
			song.mania = null;
		}

		if (song.playerKeyCount == null)
			song.playerKeyCount = song.keyCount;

		if (song.ui_Skin == null)
			song.ui_Skin = song.song == "Senpai" || song.song == "Roses" || song.song == "Thorns" ? "pixel" : "default";

		if (song.timescale == null)
			song.timescale = [4, 4];

		if (song.chartOffset == null)
			song.chartOffset = 0.0;

		// guarenteed safe value
		song.keyCount = Math.floor(Math.min(song.keyCount, NoteVariables.maniaDirections.length));

		if (song.events == null)
			song.events = [];

		if (song.gf == null) {
			if (song.gfVersion != null)
				song.gf = song.gfVersion;

			// prefer player3 since it's newer ig
			if (song.player3 != null)
				song.gf = song.player3;
		}

		var events:Array<Array<Dynamic>> = [];
		for (rawEvent in song.events) {
			// aka, if(event == A Psych Engine Event Lmfao)
			if ((rawEvent[0] is Float || rawEvent[0] is Int) && rawEvent[1] is Array) {
				var psychEvents:Array<Array<Dynamic>> = rawEvent[1];
				var time:Float = rawEvent[0]; // might cast to float, oh well
				// convert all events to correct format
				for (psychEvent in psychEvents) {
					events.push([
						Std.string(psychEvent[0]), // name
						time, // time
						Std.string(psychEvent[1]), // param 1
						Std.string(psychEvent[2]) // param 2
					]);
				}
			} else { // should be supported since it's not psych
				events.push(rawEvent);
			}
		}

		// parse older psych events too
		if (song.notes != null) {
			for (i in 0...song.notes.length) {
				var sec:Section = song.notes[i];
				if (sec.changeTimeScale != true && (sec.timeScale == null || sec.timeScale.length < 2)) {
					sec.lengthInSteps = Math.floor((16 / (song.timescale != null ? song.timescale[1] : 4)) * (song.timescale != null ? song.timescale[0] : 4));
				}
				var notes:Array<Dynamic> = sec.sectionNotes;
				var noteCount:Int = notes.length;
				var noteIndex:Int = 0;
				while (noteIndex < noteCount) {
					var note:Array<Dynamic> = notes[noteIndex];
					if (note[3] is String) {
						note[4] = note[3];
					}
					if (note[1] < 0 && note[2] is String) {
						if (note[3] == null)
							note[3] = '';
						if (note[4] == null)
							note[4] = '';

						events.push([note[2], note[0], note[3], note[4]]);
						notes.remove(note);
						noteCount = notes.length;
					} else {
						noteIndex++;
					}
				}
			}
		}

		song.events = normalizeEvents(events);
		song.moveCamera = true;

		song.chartType = LEGACY;

		return song;
	}

	public static function parseCodename(parsedJSON:Dynamic, ?songName:String, ?difficulty:String, ?mix:String):SongData {
		var meta:Dynamic = parsedJSON.meta != null ? parsedJSON.meta : {};
		if (meta.bpm == null && songName != null && songName != "") {
			var folderName = songName.toLowerCase();
			var diffName = difficulty != null ? difficulty.toLowerCase() : "";
			var mixName = mix != null ? mix.toLowerCase() : "";

			var candidatePaths:Array<String> = [];
			if (mixName != "" && diffName != "" && diffName != "normal")
				candidatePaths.push(Paths.json('song data/$folderName/meta-$mixName-$diffName'));
			if (mixName != "")
				candidatePaths.push(Paths.json('song data/$folderName/meta-$mixName'));
			if (diffName != "" && diffName != "normal")
				candidatePaths.push(Paths.json('song data/$folderName/meta-$diffName'));
			candidatePaths.push(Paths.json('song data/$folderName/meta'));

			for (p in candidatePaths) {
				if (Assets.exists(p)) {
					try {
						var loadedMeta = Json.parse(Assets.getText(p));
						if (loadedMeta != null) {
							meta = loadedMeta;
							break;
						}
					} catch (e:Dynamic) { Main.logSilentError(e, "SongLoader: parse metadata.json"); }
				}
			}
		}
		var songTitle:String = (songName != null && songName != "") ? songName : (meta.name != null ? Std.string(meta.name) : (meta.displayName != null ? Std.string(meta.displayName) : "Song"));
		var bpm:Float = meta.bpm != null ? Std.parseFloat(Std.string(meta.bpm)) : (parsedJSON.bpm != null ? Std.parseFloat(Std.string(parsedJSON.bpm)) : 100.0);
		var speed:Float = parsedJSON.scrollSpeed != null ? Std.parseFloat(Std.string(parsedJSON.scrollSpeed)) : 1.0;
		var stage:String = parsedJSON.stage != null ? Std.string(parsedJSON.stage) : "stage";
		var needsVoices:Bool = meta.needsVoices != null ? meta.needsVoices == true : true;
		var noteTypes:Array<String> = parsedJSON.noteTypes != null ? cast parsedJSON.noteTypes : [];

		var player1:String = "bf";
		var player2:String = "dad";
		var gf:String = "gf";

		var strumLines:Array<Dynamic> = parsedJSON.strumLines != null ? cast parsedJSON.strumLines : [];
		for (strum in strumLines) {
			var characters:Array<Dynamic> = strum.characters != null ? cast strum.characters : [];
			var charName:String = characters.length > 0 ? Std.string(characters[0]) : null;
			var type:Int = strum.type != null ? Std.int(strum.type) : 0;
			if (charName != null && charName != "") {
				switch (type) {
					case 0:
						player2 = charName;
					case 1:
						player1 = charName;
					case 2:
						gf = charName;
				}
			}
		}

		var uiSkin:String = "default";
		if (meta.customValues != null && meta.customValues.noteSkin != null)
			uiSkin = Std.string(meta.customValues.noteSkin);
		else if (meta.noteSkin != null)
			uiSkin = Std.string(meta.noteSkin);

		var output:SongData = {
			song: songTitle,
			notes: [],
			bpm: bpm,
			needsVoices: needsVoices,
			speed: speed,
			player1: player1,
			player2: player2,
			player3: gf,
			gf: gf,
			gfVersion: gf,
			stage: stage,
			ui_Skin: uiSkin,
			modchartPath: "",
			modchartingTools: false,
			cameraEvents: false,
			keyCount: 4,
			playerKeyCount: 4,
			events: [],
			cutscene: "",
			endCutscene: "",
			timescale: [4, 4],
				chartOffset: 0.0,
				specialAudioName: null,
				chartType: CODENAME,
			mania: null,
			moveCamera: false,
			validScore: true,
			strumLines: strumLines
		};

		var allNotes:Array<{time:Float, id:Int, sLen:Float, isPlayer:Bool, noteType:String, strumlineID:Int}> = [];
		var strumIndex:Int = 0;
		for (strum in strumLines) {
			var type:Int = strum.type != null ? Std.int(strum.type) : strumIndex;
			var isPlayer:Bool = (type == 1);
			var rawNotes:Array<Dynamic> = strum.notes != null ? cast strum.notes : [];
			for (n in rawNotes) {
				var time:Float = n.time != null ? Std.parseFloat(Std.string(n.time)) : 0.0;
				var id:Int = n.id != null ? Std.int(n.id) : 0;
				var sLen:Float = n.sLen != null ? Std.parseFloat(Std.string(n.sLen)) : 0.0;
				var typeIdx:Int = n.type != null ? Std.int(n.type) : 0;
				var typeStr:String = (typeIdx > 0 && typeIdx <= noteTypes.length) ? noteTypes[typeIdx - 1] : "default";
				allNotes.push({time: time, id: id, sLen: sLen, isPlayer: isPlayer, noteType: typeStr, strumlineID: strumIndex});
			}
			strumIndex++;
		}

		allNotes.sort((a, b) -> Std.int(a.time - b.time));

		var cneEvents:Array<Dynamic> = parsedJSON.events != null ? cast parsedJSON.events : [];
		if (cneEvents.length == 0 && songName != null && songName != "") {
			var folderName = songName.toLowerCase();
			var diffName = difficulty != null ? difficulty.toLowerCase() : "";
			var mixName = mix != null ? mix.toLowerCase() : "";

			var candidateEventPaths:Array<String> = [];
			if (mixName != "" && diffName != "" && diffName != "normal")
				candidateEventPaths.push(Paths.json('song data/$folderName/events-$mixName-$diffName'));
			if (mixName != "")
				candidateEventPaths.push(Paths.json('song data/$folderName/events-$mixName'));
			if (diffName != "" && diffName != "normal")
				candidateEventPaths.push(Paths.json('song data/$folderName/events-$diffName'));
			candidateEventPaths.push(Paths.json('song data/$folderName/events'));

			for (p in candidateEventPaths) {
				if (Assets.exists(p)) {
					try {
						var rawEvData = Json.parse(Assets.getText(p));
						if (rawEvData != null) {
							if (rawEvData.events != null && rawEvData.events is Array) {
								cneEvents = cast rawEvData.events;
								break;
							} else if (rawEvData is Array) {
								cneEvents = cast rawEvData;
								break;
							}
						}
					} catch (e:Dynamic) { Main.logSilentError(e, "SongLoader: parse chart events"); }
				}
			}
		}
		var cameraFocusSections:Map<Int, Bool> = new Map();
		var altAnimSections:Map<Int, Bool> = new Map();

		// Tempo changes are stored in *time* by Codename, but our chart model is
		// section based and a section is 16 steps, so its length in milliseconds
		// depends on the tempo that is playing while it runs. The old code froze
		// `measureCrochet` at the base BPM, which meant every BPM change landed on
		// the wrong section and every later section boundary drifted out of sync
		// with the notes. Here the section timeline is built first, cutting a new
		// section wherever a tempo change happens so the mapping stays exact.
		var maxNoteTime:Float = 0;
		for (n in allNotes) {
			if (n.time + n.sLen > maxNoteTime) maxNoteTime = n.time + n.sLen;
		}
		for (ev in cneEvents) {
			if (ev != null && ev.time != null) {
				var evTime:Float = Std.parseFloat(Std.string(ev.time));
				if (evTime > maxNoteTime) maxNoteTime = evTime;
			}
		}

		var crochet:Float = (60 / bpm) * 1000;
		var measureCrochet:Float = crochet * 4;

		// ---- 1. collect tempo events -------------------------------------
		var tempoEvents:Array<{time:Float, bpm:Float, continuous:Bool, steps:Float}> = [];
		for (ev in cneEvents) {
			var name:String = ev.name != null ? Std.string(ev.name) : "";
			if (name != "BPM Change" && name != "Continuous BPM Change") continue;

			var params:Array<Dynamic> = ev.params != null ? cast ev.params : [];
			var newBpm:Float = params.length > 0 ? Std.parseFloat(Std.string(params[0])) : bpm;
			if (Math.isNaN(newBpm) || newBpm <= 0) newBpm = bpm;

			var newTime:Float = ev.time != null ? Std.parseFloat(Std.string(ev.time)) : 0.0;
			var rampSteps:Float = params.length > 1 ? Std.parseFloat(Std.string(params[1])) : 0.0;
			var isRamp:Bool = name == "Continuous BPM Change";

			// A continuous change starts ramping now and finishes `steps` steps
			// later, so for the section timeline it counts as a change at its end.
			if (isRamp) {
				var sc:Float = (60 / bpm) * 1000 / 4;
				if (sc <= 0) sc = 1;
				if (Math.isNaN(rampSteps) || rampSteps < 0) rampSteps = 0;
				newTime += rampSteps * sc;
			}

			tempoEvents.push({time: newTime, bpm: newBpm, continuous: isRamp, steps: rampSteps});
		}
		tempoEvents.sort((a, b) -> Std.int(a.time - b.time));

		// ---- 2. build the section timeline -------------------------------
		var secStart:Array<Float> = [];
		var secBpm:Array<Float> = [];
		var secChange:Array<Bool> = [];
		var secSteps:Array<Int> = [];

		var t:Float = 0;
		var curBpm:Float = bpm;
		var pendingChange:Bool = false;
		var ti:Int = 0;
		var guard:Int = 0;
		var hardLimit:Float = maxNoteTime + measureCrochet * 4;

		while (t < hardLimit && guard++ < 10000) {
			// consume every tempo change that begins at this exact position
			while (ti < tempoEvents.length && tempoEvents[ti].time <= t + 0.01) {
				curBpm = tempoEvents[ti].bpm;
				ti++;
				pendingChange = true;
			}

			var naturalEnd:Float = t + 4 * (60 / curBpm) * 1000;
			var nextTime:Float = ti < tempoEvents.length ? tempoEvents[ti].time : Math.POSITIVE_INFINITY;

			if (nextTime < naturalEnd - 0.01) {
				// a tempo change falls inside this section: close it early so
				// the new tempo gets a section of its own
				var sc0:Float = (60 / curBpm) * 1000 / 4;
				var partial:Int = sc0 > 0 ? Std.int(Math.max(1, Math.round((nextTime - t) / sc0))) : 16;
				secStart.push(t);
				secBpm.push(curBpm);
				secChange.push(pendingChange);
				secSteps.push(partial);
				pendingChange = false;
				t = nextTime;
				continue;
			}

			secStart.push(t);
			secBpm.push(curBpm);
			secChange.push(pendingChange);
			secSteps.push(16);
			pendingChange = false;
			t = naturalEnd;
		}

		if (secStart.length < 4) {
			while (secStart.length < 4) {
				secStart.push(t);
				secBpm.push(bpm);
				secChange.push(false);
				secSteps.push(16);
				t += 4 * (60 / bpm) * 1000;
			}
		}

		var totalSections:Int = secStart.length;

		function sectionAt(time:Float):Int {
			if (time <= 0) return 0;
			var lo:Int = 0;
			var hi:Int = totalSections - 1;
			while (lo < hi) {
				var mid:Int = (lo + hi + 1) >> 1;
				if (secStart[mid] <= time) lo = mid; else hi = mid - 1;
			}
			return lo;
		}

		// ---- 3. events ----------------------------------------------------
		for (ev in cneEvents) {
			var name:String = ev.name != null ? Std.string(ev.name) : "";
			var time:Float = ev.time != null ? Std.parseFloat(Std.string(ev.time)) : 0.0;
			var params:Array<Dynamic> = ev.params != null ? cast ev.params : [];
			var secIndex:Int = sectionAt(time);

			switch (name) {
				case "BPM Change":
					var newBpm:Float = params.length > 0 ? Std.parseFloat(Std.string(params[0])) : bpm;
					if (!Math.isNaN(newBpm) && newBpm > 0)
						output.events.push(["BPM Change", time, Std.string(newBpm), ""]);
				case "Continuous BPM Change":
					var rampBpm:Float = params.length > 0 ? Std.parseFloat(Std.string(params[0])) : bpm;
					var rampSteps:Float = params.length > 1 ? Std.parseFloat(Std.string(params[1])) : 0.0;
					if (!Math.isNaN(rampBpm) && rampBpm > 0)
						output.events.push(["Continuous BPM Change", time, '${rampBpm},${rampSteps}', ""]);
				case "Scroll Speed Change":
					var newSpeed:Float = params.length > 1 ? Std.parseFloat(Std.string(params[1])) : 1.0;
					var tweenDuration:Float = params.length > 2 ? Std.parseFloat(Std.string(params[2])) : 0.0;
					output.events.push(["scrollspeed", time, '${tweenDuration},${newSpeed}', "linear,Out,false"]);
				case "Play Animation":
					var charTarget:Int = params.length > 0 ? Std.int(params[0]) : 0;
					var animName:String = params.length > 1 ? Std.string(params[1]) : "idle";
					output.events.push(["play character animation", time, charTarget == 1 ? "bf" : (charTarget == 2 ? "gf" : "dad"), animName]);
				case "Alt Animation Toggle":
					var enable:Bool = params.length > 0 ? (params[0] == true || params[0] == 1) : true;
					altAnimSections.set(secIndex, enable);
					output.events.push(["alt animation toggle", time, enable ? "true" : "false", ""]);
				default:
					for (converted in convertCneEvent(name, time, params)) {
						if (converted[0] == "focuscamera") {
							cameraFocusSections.set(secIndex, converted[2] == "bf");
						}
						output.events.push(converted);
					}
			}
		}

		// ---- 4. emit sections ---------------------------------------------
		var curMustHit:Bool = true;
		var curAlt:Bool = false;

		for (sec in 0...totalSections) {
			if (cameraFocusSections.exists(sec)) curMustHit = cameraFocusSections.get(sec);
			if (altAnimSections.exists(sec)) curAlt = altAnimSections.get(sec);

			output.notes.push({
				sectionNotes: [],
				lengthInSteps: secSteps[sec],
				mustHitSection: curMustHit,
				bpm: secBpm[sec],
				changeBPM: secChange[sec],
				altAnim: curAlt,
				timeScale: [4, 4],
				changeTimeScale: false
			});
		}

		// ---- 5. place notes -------------------------------------------------
		for (n in allNotes) {
			var secIndex:Int = sectionAt(n.time);
			while (secIndex >= output.notes.length) {
				var prevSec = output.notes[output.notes.length - 1];
				output.notes.push({
					sectionNotes: [],
					lengthInSteps: 16,
					mustHitSection: prevSec.mustHitSection,
					bpm: prevSec.bpm,
					changeBPM: false,
					altAnim: prevSec.altAnim,
					timeScale: [4, 4],
					changeTimeScale: false
				});
			}

			var sec = output.notes[secIndex];
			var noteData:Int = n.id % 4;
			if (sec.mustHitSection) {
				if (!n.isPlayer) noteData += 4;
			} else {
				if (n.isPlayer) noteData += 4;
			}

			sec.sectionNotes.push([n.time, noteData, n.sLen, 0, n.noteType, n.strumlineID]);
		}

		output.events = normalizeEvents(output.events);

		return output;
	}

	public static function getSectionStartTimes(song:SongData):Array<Float> {
		var startTimes:Array<Float> = [];
		if (song == null || song.notes == null || song.notes.length == 0) return [0.0];

		var curTime:Float = 0.0;
		var curBpm:Float = (song.bpm != null && song.bpm > 0) ? song.bpm : 100.0;

		for (i in 0...song.notes.length) {
			startTimes.push(curTime);
			var sec = song.notes[i];
			if (sec != null) {
				if (sec.changeBPM == true && sec.bpm > 0) {
					curBpm = sec.bpm;
				}
				var steps:Int = Conductor.sectionLengthInSteps(sec);
				var stepCrochet:Float = (60.0 / curBpm) * 1000.0 / 4.0;
				curTime += steps * stepCrochet;
			}
		}
		return startTimes;
	}

	public static function exportToPsych(song:SongData, events:Array<Array<Dynamic>>):Dynamic {
		var psychNotes:Array<Dynamic> = [];
		var kCount:Int = song.keyCount > 0 ? song.keyCount : 4;
		var pKeyCount:Int = song.playerKeyCount > 0 ? song.playerKeyCount : 4;

		if (song.notes != null) {
			for (sec in song.notes) {
				var cleanSectionNotes:Array<Dynamic> = [];
				if (sec.sectionNotes != null) {
					for (n in sec.sectionNotes) {
						var nTime:Float = n[0];
						var nData:Int = Std.int(n[1]);
						var nLen:Float = n[2] != null ? Std.parseFloat(Std.string(n[2])) : 0.0;
						var nType:String = (n.length > 4 && n[4] != null && n[4] != "" && n[4] != "default") ? Std.string(n[4]) : "";
						cleanSectionNotes.push([nTime, nData, nLen, nType]);
					}
				}
				psychNotes.push({
					sectionNotes: cleanSectionNotes,
					lengthInSteps: sec.lengthInSteps,
					mustHitSection: sec.mustHitSection,
					bpm: sec.bpm,
					changeBPM: sec.changeBPM == true,
					altAnim: sec.altAnim == true,
					sectionBeats: 4
				});
			}
		}

		var groupedMap:Map<String, Array<Array<Dynamic>>> = new Map<String, Array<Array<Dynamic>>>();
		var timeOrder:Array<Float> = [];
		var secStartTimes = getSectionStartTimes(song);

		var rawEvents = (events != null && events.length > 0) ? events : (song.events != null ? song.events : []);
		for (e in rawEvents) {
			var name:String = Std.string(e[0]);
			var time:Float = Std.parseFloat(Std.string(e[1]));
			var v1:String = e[2] != null ? Std.string(e[2]) : "";
			var v2:String = e[3] != null ? Std.string(e[3]) : "";

			if (name.toLowerCase() == "bpm change" || name.toLowerCase() == "change bpm" || name.toLowerCase() == "set bpm") {
				name = "Change BPM";
			}

			var timeKey:String = Std.string(time);

			if (!groupedMap.exists(timeKey)) {
				groupedMap.set(timeKey, []);
				timeOrder.push(time);
			}
			groupedMap.get(timeKey).push([name, v1, v2]);
		}

		// Also convert section-based BPM changes into Psych "Change BPM" events if not already present
		if (song.notes != null) {
			for (i in 0...song.notes.length) {
				var sec = song.notes[i];
				if (sec != null && sec.changeBPM == true && sec.bpm > 0) {
					var st = secStartTimes[i];
					var stKey = Std.string(st);
					var alreadyHas = false;
					if (groupedMap.exists(stKey)) {
						for (ev in groupedMap.get(stKey)) {
							if (ev[0] == "Change BPM" || ev[0] == "BPM Change") {
								alreadyHas = true;
								break;
							}
						}
					}
					if (!alreadyHas) {
						if (!groupedMap.exists(stKey)) {
							groupedMap.set(stKey, []);
							timeOrder.push(st);
						}
						groupedMap.get(stKey).push(["Change BPM", Std.string(sec.bpm), ""]);
					}
				}
			}
		}

		timeOrder.sort((a, b) -> Std.int(a - b));

		var psychEvents:Array<Dynamic> = [];
		for (t in timeOrder) {
			psychEvents.push([t, groupedMap.get(Std.string(t))]);
		}

		var psychSong:Dynamic = {
			song: song.song,
			notes: psychNotes,
			events: psychEvents,
			bpm: song.bpm,
			needsVoices: song.needsVoices == true,
			speed: song.speed,
			player1: song.player1 != null ? song.player1 : "bf",
			player2: song.player2 != null ? song.player2 : "dad",
			gfVersion: song.gf != null ? song.gf : (song.gfVersion != null ? song.gfVersion : "gf"),
			stage: song.stage != null ? song.stage : "stage",
			keyCount: kCount,
			playerKeyCount: pKeyCount,
			format: "psych_v1"
		};

		if (kCount > 4) {
			psychSong.mania = kCount - 1;
		}

		return {"song": psychSong};
	}

	public static function exportToCodename(song:SongData, events:Array<Array<Dynamic>>, difficulty:String = "normal"):Dynamic {
		var noteTypes:Array<String> = [];
		inline function getNoteTypeIndex(tName:String):Int {
			if (tName == null || tName == "" || tName == "default" || tName == "Default Note") return 0;
			var idx = noteTypes.indexOf(tName);
			if (idx != -1) return idx + 1;
			noteTypes.push(tName);
			return noteTypes.length;
		}

		var hasCustomStrumLines:Bool = (song.strumLines != null && song.strumLines.length > 0);
		var strumLineNoteBuckets:Array<Array<Dynamic>> = [];
		var strumLinesExport:Array<Dynamic> = [];

		if (hasCustomStrumLines) {
			for (stIdx in 0...song.strumLines.length) {
				strumLineNoteBuckets.push([]);
				var st = song.strumLines[stIdx];
				var chars:Array<String> = st.characters != null ? cast st.characters : [stIdx == 1 ? "bf" : "dad"];
				strumLinesExport.push({
					characters: chars,
					type: st.type != null ? Std.int(st.type) : (stIdx == 1 ? 1 : 0),
					position: st.position != null ? st.position : (stIdx == 0 ? 0.25 : 0.75),
					keyCount: st.keyCount != null ? Std.int(st.keyCount) : 4,
					scale: st.scale != null ? st.scale : 1.0,
					strumScale: st.strumScale != null ? st.strumScale : 1.0,
					strumSpacing: st.strumSpacing != null ? st.strumSpacing : 1.0,
					notes: strumLineNoteBuckets[stIdx]
				});
			}
		} else {
			strumLineNoteBuckets.push([]); // opponent
			strumLineNoteBuckets.push([]); // player
			var p1 = song.player1 != null ? song.player1 : "bf";
			var p2 = song.player2 != null ? song.player2 : "dad";
			strumLinesExport = [
				{
					characters: [p2],
					type: 0,
					position: 0.25,
					keyCount: song.keyCount > 0 ? song.keyCount : 4,
					notes: strumLineNoteBuckets[0]
				},
				{
					characters: [p1],
					type: 1,
					position: 0.75,
					keyCount: song.playerKeyCount > 0 ? song.playerKeyCount : 4,
					notes: strumLineNoteBuckets[1]
				}
			];
		}

		if (song.notes != null) {
			for (sec in song.notes) {
				if (sec.sectionNotes != null) {
					for (n in sec.sectionNotes) {
						var nTime:Float = n[0];
						var nData:Int = Std.int(n[1]);
						var nLen:Float = n[2] != null ? Std.parseFloat(Std.string(n[2])) : 0.0;
						var nTypeStr:String = (n.length > 4 && n[4] != null) ? Std.string(n[4]) : "";
						var nTypeIdx:Int = getNoteTypeIndex(nTypeStr);
						var targetStrumIdx:Int = -1;

						if (n.length > 5 && n[5] != null) {
							targetStrumIdx = Std.int(n[5]);
						}

						if (targetStrumIdx < 0 || targetStrumIdx >= strumLineNoteBuckets.length) {
							var isPlayer:Bool = nData < 4 ? sec.mustHitSection : !sec.mustHitSection;
							targetStrumIdx = isPlayer ? 1 : 0;
							if (targetStrumIdx >= strumLineNoteBuckets.length) targetStrumIdx = 0;
						}

						var strumKeyCount:Int = 4;
						if (targetStrumIdx < strumLinesExport.length && strumLinesExport[targetStrumIdx].keyCount != null) {
							strumKeyCount = Std.int(strumLinesExport[targetStrumIdx].keyCount);
						}
						var columnId:Int = nData % strumKeyCount;

						var noteObj = {
							time: nTime,
							id: columnId,
							type: nTypeIdx,
							sLen: nLen
						};

						strumLineNoteBuckets[targetStrumIdx].push(noteObj);
					}
				}
			}
		}

		for (bucket in strumLineNoteBuckets) {
			bucket.sort((a, b) -> Std.int(a.time - b.time));
		}

		var cneEvents:Array<Dynamic> = [];
		var rawEvents = (events != null && events.length > 0) ? events : (song.events != null ? song.events : []);
		for (e in rawEvents) {
			if (e == null || e.length < 2) continue;
			var time:Float = Std.parseFloat(Std.string(e[1]));
			if (Math.isNaN(time)) continue;
			var conv = toCneEvent(e);
			if (conv == null) continue;
			cneEvents.push({
				name: conv.name,
				time: time,
				params: conv.params
			});
		}

		// Also export section-based BPM changes as Codename "BPM Change" events
		if (song.notes != null) {
			var secStartTimes = getSectionStartTimes(song);
			for (i in 0...song.notes.length) {
				var sec = song.notes[i];
				if (sec != null && sec.changeBPM == true && sec.bpm > 0) {
					var st = secStartTimes[i];
					var alreadyHas = false;
					for (ev in cneEvents) {
						if (ev.name == "BPM Change" && Math.abs(ev.time - st) < 1.0) {
							alreadyHas = true;
							break;
						}
					}
					if (!alreadyHas) {
						cneEvents.push({
							name: "BPM Change",
							time: st,
							params: [sec.bpm]
						});
					}
				}
			}
		}

		cneEvents.sort((a, b) -> {
			var dt = a.time - b.time;
			if (dt != 0) return dt > 0 ? 1 : -1;
			if (a.name == b.name) return 0;
			return a.name < b.name ? -1 : 1;
		});
		var seenEvents = new Map<String, Bool>();
		var uniqueEvents:Array<Dynamic> = [];
		for (ev in cneEvents) {
			var key = Std.string(ev.time) + "|" + ev.name + "|" + Json.stringify(ev.params);
			if (seenEvents.exists(key)) continue;
			seenEvents.set(key, true);
			uniqueEvents.push(ev);
		}
		cneEvents = uniqueEvents;

		var cneChart:Dynamic = {
			codenameChart: true,
			stage: song.stage != null ? song.stage : "stage",
			scrollSpeed: song.speed != null ? song.speed : 1.0,
			noteTypes: noteTypes,
			events: cneEvents,
			strumLines: strumLinesExport,
			meta: {
				name: song.song,
				bpm: song.bpm,
				needsVoices: song.needsVoices == true,
				difficulties: [difficulty.toLowerCase()]
			}
		};

		return cneChart;
	}

	// Inverse of convertCneEvent: turns an internal [name, time, v1, v2] event back into a
	// full Codename Engine event using its param schema, so the export round-trips.
	static function toCneEvent(e:Array<Dynamic>):{name:String, params:Array<Dynamic>} {
		var name:String = Std.string(e[0]);
		var v1:Dynamic = e.length > 2 ? e[2] : "";
		var v2:Dynamic = e.length > 3 ? e[3] : "";

		function numf(v:Dynamic, dflt:Float):Float {
			var s = Std.string(v);
			if (s == null || s == "" || s == "null") return dflt;
			var f = Std.parseFloat(s);
			return Math.isNaN(f) ? dflt : f;
		}
		function parts(p:Dynamic):Array<String> {
			if (p == null) return [];
			return Std.string(p).split(",");
		}

		switch (name.toLowerCase()) {
			case "focuscamera" | "camera movement":
				var targetStr = Std.string(v1).toLowerCase();
				var target:Int = (targetStr == "bf" || targetStr == "1" || targetStr == "boyfriend") ? 1
					: (targetStr == "gf" || targetStr == "2") ? 2 : 0;
				var p = parts(v2);
				return {name: "Camera Movement", params: [
					target,
					(p.length > 5 ? Std.string(p[5]) : "true") != "false",
					numf(p.length > 0 ? p[0] : "", 4),
					(p.length > 1 && p[1] != "" ? p[1] : "CLASSIC"),
					(p.length > 2 && p[2] != "" ? p[2] : "In"),
					numf(p.length > 3 ? p[3] : "", 0),
					numf(p.length > 4 ? p[4] : "", 0)
				]};

			case "set camera position" | "camera position":
				var p = parts(v2);
				return {name: "Camera Position", params: [
					numf(v1, 0),
					numf(p.length > 0 ? p[0] : "", 0),
					(p.length > 4 ? Std.string(p[4]) : "true") != "false",
					numf(p.length > 1 ? p[1] : "", 4),
					(p.length > 2 && p[2] != "" ? p[2] : "CLASSIC"),
					(p.length > 3 && p[3] != "" ? p[3] : "In"),
					(p.length > 5 ? Std.string(p[5]).toLowerCase() : "") == "true"
				]};

			case "camera zoom":
				var p = parts(v2);
				var cam = p.length > 3 ? (Std.string(p[3]).toLowerCase() == "camhud" ? "camHUD" : "camGame") : "camGame";
				return {name: "Camera Zoom", params: [
					(p.length > 4 ? Std.string(p[4]) : "true") != "false",
					numf(v1, 1),
					cam,
					numf(p.length > 0 ? p[0] : "", 4),
					(p.length > 1 && p[1] != "" ? p[1] : "linear"),
					(p.length > 2 && p[2] != "" ? p[2] : "In"),
					(p.length > 5 && p[5] != "" ? p[5] : "direct"),
					(p.length > 6 ? Std.string(p[6]).toLowerCase() : "") == "true"
				]};

			case "set camera zoom":
				return {name: "Camera Zoom", params: [
					false,
					numf(v1, 1),
					"camGame",
					4,
					"linear",
					"In",
					"direct",
					false
				]};

			case "add camera zoom":
				var camType = Std.string(v2) == "0" ? "camGame" : "camHUD";
				return {name: "Add Camera Zoom", params: [numf(v1, 0.05), camType]};

			case "change camera zoom strength":
				if (v2 == null || Std.string(v2) == "")
					return {name: "Camera Bop", params: [numf(v1, 0.1)]};
				return {name: "Change Camera Zoom Strength", params: [numf(v1, 0.001), numf(v2, 1)]};

			case "camera flash":
				return {name: "Camera Flash", params: [
					false,
					(Std.string(v1) != "" && Std.string(v1) != "null" ? v1 : "#FFFFFF"),
					numf(v2, 1),
					"camHUD"
				]};

			case "health drain":
				return {name: "Health Drain", params: [numf(v1, 0.02)]};

			case "bpm change" | "change bpm" | "set bpm":
				return {name: "BPM Change", params: [numf(v1, 100)]};

			case "altanim" | "alt animation toggle":
				var sv = Std.string(v1).toLowerCase();
				return {name: "Alt Animation Toggle", params: [sv == "true" || sv == "1" || v1 == 1 || v1 == true, false, 0]};

			case "scrollspeed" | "change scroll speed":
				var p = parts(v1);
				var dur = numf(p.length > 0 ? p[0] : "", 0);
				var speed = numf(p.length > 1 ? p[1] : "", 1);
				var ev = parts(v2);
				return {name: "Scroll Speed Change", params: [
					dur > 0,
					speed,
					dur,
					(ev.length > 0 && ev[0] != "" ? ev[0] : "linear"),
					(ev.length > 1 && ev[1] != "" ? ev[1] : "In"),
					false
				]};

			case "play character animation":
				return {name: "Play Animation", params: [Std.string(v1), Std.string(v2), true, "NONE"]};

			case "hey" | "hey!":
				var sv = Std.string(v1).toUpperCase();
				return {name: "Hey!", params: [sv == "BF" ? "BF" : "GF"]};

			default:
				if (v2 == null || Std.string(v2) == "") return {name: name, params: [v1]};
				return {name: name, params: [v1, v2]};
		}
	}
}

typedef Section = {
	var sectionNotes:Array<Dynamic>;
	var lengthInSteps:Int;
	var mustHitSection:Bool;
	var bpm:Float;
	var changeBPM:Bool;
	var altAnim:Bool;
	var ?gfSection:Bool;

	var timeScale:Array<Int>;
	var changeTimeScale:Bool;
}

enum abstract ChartType(String) to String from String {
	var LEGACY = "LEGACY";
	var VSLICE = "VSLICE";
	var CODENAME = "CODENAME";
}

typedef SongData = {
	// 0.2.8 and before stuff
	var song:Null<String>;
	var notes:Null<Array<Section>>;
	var bpm:Null<Float>;
	var needsVoices:Null<Bool>;
	var speed:Null<Float>;
	var player1:Null<String>;
	var player2:Null<String>;
	var validScore:Null<Bool>;

	// engine specific shit
	var gf:Null<String>;
	var stage:Null<String>;
	var ui_Skin:Null<String>;

	var modchartPath:Null<String>;
	var modchartingTools:Null<Bool>;
	var cameraEvents:Null<Bool>;

	var keyCount:Null<Int>;
	var playerKeyCount:Null<Int>;
	var events:Null<Array<Array<Dynamic>>>;

	var cutscene:Null<String>;
	var endCutscene:Null<String>;

	var timescale:Null<Array<Int>>;
	var chartOffset:Null<Float>; // in milliseconds
	var specialAudioName:Null<String>;

	var chartType:ChartType;

	// psych compat
	var gfVersion:Null<String>;
	var player3:Null<String>;

	// shaggy moment (ugh)
	var mania:Null<Int>;
	var moveCamera:Null<Bool>;

	@:optional var strumLines:Null<Array<Dynamic>>;
}

typedef FNFCTimeChange = {
	var t:Float; // time
	var b:Float; // beat
	var bpm:Float;
	// there are other values
	// but we won't use them
	// sorry! :p (we don't have good time sig support lo)
}

typedef FNFCCharacters = {
	var player:String;
	var girlfriend:String;
	var opponent:String;
}

typedef FNFCPlayData = {
	var difficulties:Array<String>;
	var characters:FNFCCharacters;
	var stage:String;
	var noteStyle:String;
	var cutscene:String;
	var endCutscene:String;
}

// this doesn't have everything,
// just the important stuff we need.
typedef FNFCMetadata = {
	var songName:String;
	var playData:FNFCPlayData;
	var timeChanges:Array<FNFCTimeChange>;
}

typedef FNFCEvent = {
	var t:Float; // time
	var e:String; // event
	var v:Dynamic; // value
}

typedef FNFCNote = {
	var t:Float; // time
	var d:Int; // direction
	var l:Float; // length
	var k:Null<String>; // kind
}

typedef FNFCSong = {
	var scrollSpeed:Dynamic; // basically a Map<String, Float> but not really
	var events:Array<FNFCEvent>;
	var notes:Dynamic; // basically a Map<String, Array<FNFCNote>> but not really
}