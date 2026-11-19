package utilities;

import lime.app.Application;
import haxe.Json;
import openfl.Assets;
import flixel.util.FlxSave;
import game.Conductor;

typedef DefaultOptions = {
	var options:Array<DefaultOption>;
}

typedef DefaultOption = {
	var option:String;
	var value:Dynamic;
	var save:Null<String>;
}

class Options {
	public inline static final bindNamePrefix:String = "darks_collection_v3.5_v4-";
	public static var bindPath(default, null):String;

	public static var saves:Map<String, FlxSave> = [];

	public static var defaultOptions:DefaultOptions;

	public static var currentUser(default, null):String = "";
	public static var sessionActive(default, null):Bool = false;

	public static function setSession(user:String, token:String):Void {
		currentUser = user;
		sessionActive = (user != null && user != "" && token != null && token != "");
		setData(user, "sessionUser", "main");
		setData(token, "sessionToken", "main");
		game.Highscore.load();
		clearOnlineScores();
	}

	public static function clearSession():Void {
		currentUser = "";
		sessionActive = false;
		setData("", "sessionUser", "main");
		setData("", "sessionToken", "main");
		game.Highscore.load();
		clearOnlineScores();
	}

	public static function getSessionToken():String {
		return getData("sessionToken", "main");
	}

	public static function isLogged():Bool {
		return sessionActive;
	}

	public static function clearGlobalScores():Void {
		setData(new Map<String, Dynamic>(), "songScores", "scores");
		setData(new Map<String, String>(), "songRanks", "scores");
		setData(new Map<String, Float>(), "songAccuracies", "scores");
		setData(new Map<String, Int>(), "songMisses", "scores");
		setData(new Map<String, Int>(), "songStars", "scores");
	}

	public static function init() {
		bindPath = Application.current.meta.get('company');
		createSave("main", "options");
		createSave("binds", "binds");
		createSave("scores", "scores");
		createSave("arrowColors", "arrowColors");
		createSave("autosave", "autosave");
		createSave("modlist", "modlist");
		createSave("progress", "progress");

		defaultOptions = Json.parse(Assets.getText(Paths.json("defaultOptions")));

		for (option in defaultOptions.options) {
			var saveKey = option.save ?? "main";
			var dataKey = option.option;

			if (Reflect.getProperty(Reflect.getProperty(saves.get(saveKey), "data"), dataKey) == null)
				setData(option.value, option.option, saveKey);
		}

		Conductor.offset = getData("songOffset");

		if (getData("modlist", "modlist") == null)
			setData(new Map<String, Bool>(), "modlist", "modlist");

		if (getData("songScores", "scores") == null)
			setData(new Map<String, Int>(), "songScores", "scores");

		if (getData("songRanks", "scores") == null)
			setData(new Map<String, String>(), "songRanks", "scores");

		if (getData("songAccuracies", "scores") == null)
			setData(new Map<String, Float>(), "songAccuracies", "scores");

		if (getData("songMisses", "scores") == null)
			setData(new Map<String, Int>(), "songMisses", "scores");

		if (getData("songStars", "scores") == null)
			setData(new Map<String, Int>(), "songStars", "scores");

		if (getData("oneshotBeats", "scores") == null)
			setData(new Map<String, Bool>(), "oneshotBeats", "scores");

		if (getData("arrowColors", "arrowColors") == null)
			setData(new Map<String, Array<Int>>(), "arrowColors", "arrowColors");

		if (getData("userScores", "scores") == null)
			setData(new Map<String, Dynamic>(), "userScores", "scores");

		loadSession();
	}

	static function loadSession():Void {
		var savedUser:String = getData("sessionUser", "main");
		var savedToken:String = getData("sessionToken", "main");

		if (savedUser != null && savedUser != "" && savedToken != null && savedToken != "") {
			currentUser = savedUser;
			sessionActive = true;
		}
	}

	#if MODDING_ALLOWED
	public static function initModOptions() {
		for (mod in modding.ModList.getActiveMods(modding.PolymodHandler.metadataArrays)) {
			createSave(mod, mod);
			if (sys.FileSystem.exists('mods/$mod/data/options.json')) {
				var modOptions:modding.ModOptions = cast Json.parse(sys.io.File.getContent('mods/$mod/data/options.json'));
				for (option in modOptions.options) {
					var trimmedType:String = option.type.trim().toLowerCase();
					if (trimmedType == "bool" || trimmedType == "string") {
						if (getData(option.save, mod) == null) {
							setData(option.defaultValue, option.save, mod);
						}
					}
				}
			}
		}
	}
	#end

	public static var onlineScores:Map<String, Array<Dynamic>> = new Map();

	public static function clearOnlineScores():Void {
		onlineScores.clear();
	}

	public static function createSave(key:String, bindNameSuffix:String) {
		var save = new FlxSave();
		save.bind(bindNamePrefix + bindNameSuffix, bindPath);

		saves.set(key, save);
	}

	public static function getData(dataKey:String, ?saveKey:String = "main"):Dynamic {
		if (saves.exists(saveKey))
			return Reflect.getProperty(Reflect.getProperty(saves.get(saveKey), "data"), dataKey);

		return null;
	}

	public static function setData(value:Dynamic, dataKey:String, ?saveKey:String = "main") {
		if (saves.exists(saveKey)) {
			Reflect.setProperty(Reflect.getProperty(saves.get(saveKey), "data"), dataKey, value);

			saves.get(saveKey).flush();
		}
	}

	public static function fixBinds() {
		if (getData("binds", "binds") == null)
			setData(NoteVariables.defaultBinds, "binds", "binds");
		else {
			var bindArray:Array<Dynamic> = getData("binds", "binds");

			if (bindArray.length < NoteVariables.defaultBinds.length) {
				for (i in Std.int(bindArray.length - 1)...NoteVariables.defaultBinds.length) {
					bindArray[i] = NoteVariables.defaultBinds[i];
				}

				setData(bindArray, "binds", "binds");
			}
		}
	}
}
