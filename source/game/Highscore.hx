package game;

import flixel.math.FlxMath;
import states.PlayState;

class Highscore {
	public static var songScores:Map<String, Int> = new Map<String, Int>();
	public static var songRanks:Map<String, String> = new Map<String, String>();
	public static var songAccuracies:Map<String, Float> = new Map<String, Float>();
	public static var songMisses:Map<String, Int> = new Map<String, Int>();
	public static var songStars:Map<String, Int> = new Map<String, Int>();
	public static var songBeats:Map<String, Bool> = new Map<String, Bool>();
	public static var oneshotBeats:Map<String, Bool> = new Map<String, Bool>();

	static function isUserMode():Bool {
		return Options.isLogged();
	}

	static function getUserKey():String {
		return Options.currentUser;
	}

	static function getOrCreateUserData(song:String):Dynamic {
		var all:Map<String, Dynamic> = Options.getData("userScores", "scores");
		if (all == null) all = new Map<String, Dynamic>();
		var userKey = getUserKey();
		if (!all.exists(userKey))
			all.set(userKey, new Map<String, Dynamic>());
		var userMap:Map<String, Dynamic> = cast all.get(userKey);
		if (!userMap.exists(song)) {
			userMap.set(song, {score: 0, accuracy: 0.0, misses: -1, rank: "N/A", stars: 0, beaten: false});
			all.set(userKey, userMap);
			Options.setData(all, "userScores", "scores");
		}
		var um:Map<String, Dynamic> = cast all.get(userKey);
		return um.get(song);
	}

	static function saveUserProp(song:String, prop:String, value:Dynamic):Void {
		var all:Map<String, Dynamic> = Options.getData("userScores", "scores");
		if (all == null) all = new Map<String, Dynamic>();
		var userKey = getUserKey();
		if (!all.exists(userKey))
			all.set(userKey, new Map<String, Dynamic>());
		var userMap:Map<String, Dynamic> = cast all.get(userKey);
		var data:Dynamic = userMap.get(song);
		if (data == null) {
			data = {score: 0, accuracy: 0.0, misses: -1, rank: "N/A", stars: 0, beaten: false};
		}
		var da:haxe.DynamicAccess<Dynamic> = data;
		da.set(prop, value);
		userMap.set(song, data);
		all.set(userKey, userMap);
		Options.setData(all, "userScores", "scores");
	}

	static function getUserProp(song:String, prop:String, defaultValue:Dynamic):Dynamic {
		var all:Map<String, Dynamic> = Options.getData("userScores", "scores");
		if (all == null) return defaultValue;
		var userKey = getUserKey();
		if (!all.exists(userKey)) return defaultValue;
		var userMap:Map<String, Dynamic> = cast all.get(userKey);
		if (!userMap.exists(song)) return defaultValue;
		var data:Dynamic = userMap.get(song);
		if (data != null) {
			var da:haxe.DynamicAccess<Dynamic> = data;
			if (da.exists(prop)) return da.get(prop);
		}
		return defaultValue;
	}

	public static function onBeatSong(instance:PlayState):Void {
		if (PlayState.SONG.validScore) {
			var key = PlayState.SONG.song.toLowerCase();
			if (isUserMode()) {
				saveUserProp(key, "beaten", true);
			} else {
				songBeats.set(key, true);
				Options.setData(songBeats, "songBeats", "scores");
			}
		}
	}

	public static function isSongBeaten(song:String):Bool {
		var key = song.toLowerCase();
		if (isUserMode())
			return getUserProp(key, "beaten", false);
		if (!songBeats.exists(key)) {
			songBeats = Options.getData("songBeats", "scores");
			if (songBeats == null) songBeats = new Map<String, Bool>();
			if (!songBeats.exists(key)) songBeats.set(key, false);
		}
		return songBeats.get(key);
	}

	public static function onBeatOneshot(oneshotId:String):Void {
		if (PlayState.SONG.validScore && PlayState.oneshotMode) {
			var key = 'oneshot_' + oneshotId.toLowerCase();
			if (isUserMode()) {
				saveUserProp(key, "oneshotBeaten", true);
			} else {
				oneshotBeats.set(key, true);
				Options.setData(oneshotBeats, "oneshotBeats", "scores");
			}
		}
	}

	public static function isOneshotBeaten(oneshotId:String):Bool {
		var key = 'oneshot_' + oneshotId.toLowerCase();
		if (isUserMode())
			return getUserProp(key, "oneshotBeaten", false);
		if (!oneshotBeats.exists(key)) {
			var saved:Bool = Options.getData("oneshotBeats", "scores") != null;
			if (saved) {
				var all:Map<String, Bool> = Options.getData("oneshotBeats", "scores");
				if (all != null && all.exists(key))
					oneshotBeats.set(key, all.get(key));
				else
					oneshotBeats.set(key, false);
			} else {
				oneshotBeats.set(key, false);
			}
		}
		return oneshotBeats.get(key);
	}

	public static function resetSong(song:String, ?diff:String = "easy"):Void {
		var daSong:String = formatSong(song, diff);
		setScore(daSong, 0);
		setRank(daSong, "N/A");
		setAccuracy(daSong, 0);
		setMisses(daSong, -1);
		
		if (isUserMode()) {
			saveUserProp(daSong, "stars", 0);
		} else {
			if (songStars.exists(daSong)) {
				songStars.set(daSong, 0);
				Options.setData(songStars, "songStars", "scores");
			}
		}
	}

	public static inline function resetWeek(week:Int = 1, ?diff:String = "easy", ?weekName:String = 'week'):Void {
		var daWeek = formatSong(weekName + week, diff);
		setScore(daWeek, 0);
		if (isUserMode()) {
			saveUserProp(daWeek, "stars", 0);
		} else {
			if (songStars.exists(daWeek)) {
				songStars.set(daWeek, 0);
				Options.setData(songStars, "songStars", "scores");
			}
		}
	}

	public static function saveScore(song:String, score:Int = 0, ?diff:String = "easy"):Void {
		var daSong:String = formatSong(song, diff);
		if (songScores.exists(daSong)) {
			if (songScores.get(daSong) < score)
				setScore(daSong, score);
		} else
			setScore(daSong, score);
	}

	public static function saveRank(song:String, rank:String = "N/A", diff:String = "easy", accuracy:Float = 0):Void {
		var daSong:String = formatSong(song, diff);
		if (songRanks.exists(daSong)) {
			if (accuracy > getSongAccuracy(song, diff)) {
				setRank(daSong, rank);
				setAccuracy(daSong, accuracy);
			}
		} else {
			setRank(daSong, rank);
			setAccuracy(daSong, accuracy);
		}
	}

	public static function saveWeekScore(week:Int = 1, score:Int = 0, ?diff:String = "easy", ?weekName:String = 'week'):Void {
		var daWeek:String = formatSong(weekName + week, diff);
		if (songScores.exists(daWeek)) {
			if (songScores.get(daWeek) < score)
				setScore(daWeek, score);
		} else
			setScore(daWeek, score);
	}

	static function setScore(song:String, score:Int):Void {
		if (isUserMode()) {
			saveUserProp(song, "score", score);
		} else {
			songScores.set(song, score);
			Options.setData(songScores, "songScores", "scores");
		}

	}

	static function setRank(song:String, rank:String):Void {
		if (isUserMode()) {
			saveUserProp(song, "rank", rank);
		} else {
			songRanks.set(song, rank);
			Options.setData(songRanks, "songRanks", "scores");
		}

	}

	static function setAccuracy(song:String, accuracy:Float):Void {
		if (isUserMode()) {
			saveUserProp(song, "accuracy", accuracy);
		} else {
			songAccuracies.set(song, accuracy);
			Options.setData(songAccuracies, "songAccuracies", "scores");
		}

	}

	static function setMisses(song:String, misses:Int):Void {
		if (isUserMode()) {
			saveUserProp(song, "misses", misses);
		} else {
			songMisses.set(song, misses);
			Options.setData(songMisses, "songMisses", "scores");
		}

	}

	public static function getMisses(song:String, diff:String, ?formatted:Bool = false):Int {
		var key = (!formatted ? formatSong(song, diff) : song);
		if (isUserMode()) {
			var userMisses = getUserProp(key, "misses", -999);
			if (userMisses != -999) return userMisses;
		}
		if (!songMisses.exists(key))
			setMisses(key, -1);
		return songMisses.get(key);
	}

	public static function saveMisses(song:String, diff:String, misses:Int):Void {
		var daSong:String = formatSong(song, diff);
		setMisses(daSong, misses);
	}

	public static function saveStars(song:String, diff:String, stars:Int):Void {
		var key = formatSong(song, diff);
		if (isUserMode()) {
			var oldStars:Int = getUserProp(key, "stars", 0);
			if (stars > oldStars)
				saveUserProp(key, "stars", stars);
		} else {
			if (!songStars.exists(key) || songStars.get(key) < stars) {
				songStars.set(key, stars);
				Options.setData(songStars, "songStars", "scores");
		
			}
		}
	}

	public static function getSongStars(song:String, diff:String, ?formatted:Bool = false):Int {
		var key = (!formatted ? formatSong(song, diff) : song);
		if (isUserMode()) {
			var userStars = getUserProp(key, "stars", -1);
			if (userStars >= 0) return userStars;
		}
		if (!songStars.exists(key)) {
			songStars.set(key, 0);
			Options.setData(songStars, "songStars", "scores");
		}
		return songStars.get(key);
	}

	public static function starsFromAccuracy(accuracy:Float):Int {
		if (accuracy >= 95) return 3;
		if (accuracy >= 90) return 2;
		if (accuracy >= 75) return 1;
		return 0;
	}

	public static function getGlobalPink():Int return getGlobalStars(1);
	public static function getGlobalCyan():Int return getGlobalStars(2);
	public static function getGlobalOrange():Int return getGlobalStars(3);

	public static function getGlobalGreenMarks():Int {
		var total = 0;
		if (isUserMode()) {
			var all:Map<String, Dynamic> = Options.getData("userScores", "scores");
			if (all != null && all.exists(getUserKey())) {
				var userMap:Map<String, Dynamic> = cast all.get(getUserKey());
				for (key in userMap.keys()) {
					var data = userMap.get(key);
					if (data != null) {
						var da:haxe.DynamicAccess<Dynamic> = data;
						if (da.exists("beaten") && cast(da.get("beaten"), Bool) == true) total++;
					}
				}
			}
		} else {
			if (songBeats == null) {
				songBeats = Options.getData("songBeats", "scores");
				if (songBeats == null) songBeats = new Map<String, Bool>();
			}
			for (beaten in songBeats) if (beaten) total++;
		}
		return total;
	}

	static function getGlobalStars(minStars:Int):Int {
		var total = 0;
		if (isUserMode()) {
			var all:Map<String, Dynamic> = Options.getData("userScores", "scores");
			if (all != null && all.exists(getUserKey())) {
				var userMap:Map<String, Dynamic> = cast all.get(getUserKey());
				for (key in userMap.keys()) {
					var data = userMap.get(key);
					if (data != null) {
						var da:haxe.DynamicAccess<Dynamic> = data;
						if (da.exists("stars") && cast(da.get("stars"), Int) >= minStars) total++;
					}
				}
			}
		} else {
			for (stars in songStars) if (stars >= minStars) total++;
		}
		return total;
	}

	public static function formatSong(song:String, diff:String, ?mix:String):String {
		var returnSong:String = song.toLowerCase();
		if (diff.toLowerCase() != "normal")
			returnSong += "-" + diff.toLowerCase();
		if (mix != null)
			returnSong += "-" + mix.toLowerCase();
		return returnSong;
	}

	public static function getScore(song:String, diff:String, ?mix:String, ?formatted:Bool = false):Int {
		var key = formatSong(song, diff, mix);
		if (isUserMode()) {
			var userScore = getUserProp(key, "score", -1);
			if (userScore != -1) return userScore;
		}
		if (!songScores.exists(key))
			setScore(key, 0);
		return songScores.get(key);
	}

	public static function getWeekScore(week:Int, diff:String, ?weekName:String = 'week', ?formatted:Bool = false):Int {
		var key = formatSong(weekName + week, diff);
		if (isUserMode()) {
			var userScore = getUserProp(key, "score", -1);
			if (userScore != -1) return userScore;
		}
		if (!songScores.exists(key))
			setScore(key, 0);
		return songScores.get(key);
	}

	public static function getSongRank(song:String, diff:String, ?formatted:Bool = false):String {
		var key = (!formatted ? formatSong(song, diff) : song);
		if (isUserMode()) {
			var userRank = getUserProp(key, "rank", "~~");
			if (userRank != "~~") return userRank;
		}
		if (!songRanks.exists(key))
			setRank(key, "N/A");
		return songRanks.get(key);
	}

	public static function getSongAccuracy(song:String, diff:String, ?formatted:Bool = false):Float {
		var key = (!formatted ? formatSong(song, diff) : song);
		if (isUserMode()) {
			var userAcc = getUserProp(key, "accuracy", -1.0);
			if (userAcc >= 0) return FlxMath.roundDecimal(userAcc, 2);
		}
		if (!songAccuracies.exists(key))
			setAccuracy(key, 0);
		return FlxMath.roundDecimal(songAccuracies.get(key), 2);
	}

	public static function load():Void {
		if (Options.getData("songScores", "scores") != null)
			songScores = Options.getData("songScores", "scores");
		if (Options.getData("songRanks", "scores") != null)
			songRanks = Options.getData("songRanks", "scores");
		if (Options.getData("songAccuracies", "scores") != null)
			songAccuracies = Options.getData("songAccuracies", "scores");
		if (Options.getData("songMisses", "scores") != null)
			songMisses = Options.getData("songMisses", "scores");
		if (Options.getData("songStars", "scores") != null)
			songStars = Options.getData("songStars", "scores");
		if (Options.getData("songBeats", "scores") != null)
			songBeats = Options.getData("songBeats", "scores");
	}

	public static function importOldData() {
		flixel.FlxG.save.bind('leathersfunkinengine', 'leather128');

		var funnyScores = songScores;
		var funnyRanks = songRanks;
		var funnyAccuracies = songAccuracies;

		if (flixel.FlxG.save.data.songScores != null)
			funnyScores = flixel.FlxG.save.data.songScores;
		if (flixel.FlxG.save.data.songRanks != null)
			funnyRanks = flixel.FlxG.save.data.songRanks;
		if (flixel.FlxG.save.data.songAccuracies != null)
			funnyAccuracies = flixel.FlxG.save.data.songAccuracies;

		for (key in funnyScores.keys()) {
			if (key != null) {
				if (getScore(key, "", true) < funnyScores.get(key)) {
					setScore(key, funnyScores.get(key));
					if (funnyAccuracies.exists(key))
						setAccuracy(key, funnyAccuracies.get(key));
					if (funnyRanks.exists(key))
						setRank(key, funnyRanks.get(key));
				}
			}
		}

		flixel.FlxG.save.close();
	}
}
