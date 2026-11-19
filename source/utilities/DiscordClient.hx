package utilities;

import haxe.Json;
#if DISCORD_ALLOWED
import cpp.ConstCharStar;
import cpp.RawConstPointer;
import flixel.util.FlxSignal;
import hxdiscord_rpc.Discord;
import hxdiscord_rpc.Types;
import sys.FileSystem;
import sys.io.File;
import sys.thread.Thread;

using cpp.RawPointer;
using cpp.Function;

class DiscordClient {
	public static var started(default, null):Bool = false;
	public static var active(default, null):Bool = false;
	public static var defaultID(default, null):String = "1461846984208941353";
	public static var ID(default, set):String = defaultID;
	public static var presence(default, null):DiscordRichPresence = new DiscordRichPresence();
	public static var onError(default, null):FlxTypedSignal<(Int, String) -> Void> = new FlxTypedSignal<(Int, String) -> Void>();
	public static var onDisconnect(default, null):FlxTypedSignal<(Int, ConstCharStar) -> Void> = new FlxTypedSignal<(Int, ConstCharStar) -> Void>();
	public static var onReady(default, null):FlxTypedSignal<RawConstPointer<DiscordUser> -> Void> = new FlxTypedSignal<RawConstPointer<DiscordUser> -> Void>();
	public static var userID:String = "";
		public static var displayName:String = "";
	static var cachedSongPresenceData:Dynamic = null;
	static var cachedSongPresencePath:String = null;

	public static function startup() {
		if (started)
			return;

		final handlers:DiscordEventHandlers = new DiscordEventHandlers();

		handlers.ready = _onReady.fromStaticFunction();
		handlers.disconnected = _onDisconnect.fromStaticFunction();
		handlers.errored = _onError.fromStaticFunction();
		Discord.Initialize(defaultID, handlers.addressOf(), false, null);

		started = true;

		Thread.create(() -> {
			while (true) {
				#if DISCORD_DISABLE_IO_THREAD
				Discord.UpdateConnection();
				#end

				Discord.RunCallbacks();
				Sys.sleep(1);
			}
		});
	}

	public static inline function shutdown() {
		if (!active) return;
		trace("Discord: Shutting down...");
		Discord.Shutdown();
		active = false;
	}

	public static function normalizeSongName(str:String):String {
		if (str == null) return "";
		return str.toLowerCase();
	}

	public static function getSongPresencePath():String {
		#if sys
		var modName:String = Options.getData("curMod");

		var modPath:String = "mods/" + modName + "/data/songPresence.json";
		var appendPath:String = "mods/" + modName + "/_append/data/songPresence.json";

		if (FileSystem.exists(modPath))
			return modPath;

		if (FileSystem.exists(appendPath))
			return appendPath;
		#end

		return "assets/data/songPresence.json";
	}

	public static function loadSongPresenceData():Dynamic {
		#if sys
		var jsonPath:String = getSongPresencePath();

		if (cachedSongPresenceData != null && cachedSongPresencePath == jsonPath)
			return cachedSongPresenceData;

		if (FileSystem.exists(jsonPath)) {
			try {
				cachedSongPresenceData = Json.parse(File.getContent(jsonPath));
				cachedSongPresencePath = jsonPath;
				return cachedSongPresenceData;
			} catch (e:Dynamic) {
				trace("Error leyendo songPresence JSON: " + e);
			}
		}
		#end

		cachedSongPresenceData = null;
		cachedSongPresencePath = null;
		return null;
	}

	public static function getSongPresenceAssets(songName:String, ?difficulty:String = ""):{curPortrait:String, image:String} {
		var curPortrait:String = "icon";
		var image:String = "icon";
		var data:Dynamic = loadSongPresenceData();

		if (data != null) {
			var target:String = normalizeSongName(songName);

			if (Reflect.hasField(data, "songs")) {
				var songsData:Dynamic = Reflect.field(data, "songs");
				var targetDiff = target + "-" + normalizeSongName(difficulty);

				var matchKey:String = null;

				if (difficulty != "") {
					for (key in Reflect.fields(songsData)) {
						if (normalizeSongName(key) == targetDiff) {
							matchKey = key;
							break;
						}
					}
				}

				if (matchKey == null) {
					for (key in Reflect.fields(songsData)) {
						if (normalizeSongName(key) == target) {
							matchKey = key;
							break;
						}
					}
				}

				if (matchKey != null) {
					var songData:Dynamic = Reflect.field(songsData, matchKey);

					if (Reflect.hasField(songData, "curPortrait"))
						curPortrait = songData.curPortrait;

					if (Reflect.hasField(songData, "image"))
						image = songData.image;
				}
			}

			if (Reflect.hasField(data, "default")) {
				var def:Dynamic = Reflect.field(data, "default");

				if (curPortrait == "icon" && Reflect.hasField(def, "curPortrait"))
					curPortrait = def.curPortrait;

				if (image == "icon" && Reflect.hasField(def, "image"))
					image = def.image;
			}
		}

		return {
			curPortrait: curPortrait,
			image: image
		};
	}

	private static function _onReady(request:RawConstPointer<DiscordUser>) {
			DiscordClient.userID = request[0].userId;

			var username:String = request[0].username;

			if (request[0].globalName != null && request[0].globalName != "")
				username = request[0].globalName;

			DiscordClient.displayName = username;
			Main.display.discordUserName = username;

			active = true;

			changePresence();

			onReady.dispatch(request);

			
		}

	public static function changePresence(details:String = "", ?state:String, ?smallImageKey:String, ?hasStartTimestamp:Bool, ?endTimestamp:Float,
		largeImageKey:String = "icon", largeImageText:String = "Leather Engine", ?buttonLabel:String, ?buttonUrl:String) {
		var startTimestamp:Float = hasStartTimestamp ? Date.now().getTime() : 0;

		if (endTimestamp > 0) {
			endTimestamp = startTimestamp + endTimestamp;
		}

		presence.details = details;
		presence.state = state;
		presence.largeImageKey = largeImageKey;
		presence.largeImageText = largeImageText;
		presence.smallImageKey = smallImageKey;
		presence.startTimestamp = Std.int(startTimestamp / 1000);
		presence.endTimestamp = Std.int(endTimestamp / 1000);
		
		if (buttonLabel != null && buttonLabel != "" && buttonUrl != null && buttonUrl != "") {
			var btn:DiscordButton = new DiscordButton();
			btn.label = buttonLabel;
			btn.url = buttonUrl;
			presence.buttons[0] = btn;
		} else {
			var btn:DiscordButton = new DiscordButton();
			btn.label = "perroxd";
			btn.url = "https://discord.gg/bGrBry2gc3"; 
			presence.buttons[0] = btn;
		}

		updatePresence();
	}

	public static inline function updatePresence() {
		if (!active) {
			return;
		}
		Discord.UpdatePresence(presence.addressOf());
	}

	public static function loadModPresence():Bool {
		var jsonPath:String = 'mods/${Options.getData("curMod")}/discord.json';
		if (FileSystem.exists(jsonPath)) {
			var discordData:DiscordData = cast Json.parse(File.getContent(jsonPath));
			ID = discordData.ID;
			changePresence("", null, null, null, null, discordData.key, discordData.text);
			trace('Found mod presence at $jsonPath');
			return true;
		} else {
			ID = defaultID;
			changePresence();
		}
		trace("didnt find mod presence");
		return false;
	}

	private static inline function _onDisconnect(errorCode:Int, message:ConstCharStar):Void {
		trace('Discord: Disconnected ($errorCode:$message)', WARNING);
		onDisconnect.dispatch(errorCode, message);
	}

	private static inline function _onError(errorCode:Int, message:ConstCharStar):Void {
		trace('Discord: Error ($errorCode:$message)', ERROR);
		onError.dispatch(errorCode, message);
	}

	@:noCompletion
	static inline function set_ID(newID:String):String {
		if (ID == newID) {
			return ID;
		}
		if (started) {
			shutdown();
			startup();
			Discord.UpdatePresence(presence.addressOf());
		}
		return ID = newID;
	}

	
}

typedef DiscordData = {
	var ID:String;
	var key:String;
	var text:String;
}
#end