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
	public static var defaultID(default, null):String = "864980501004812369";
	public static var ID(default, set):String = defaultID;

	public static var presence(default, null):DiscordRichPresence = new DiscordRichPresence();

	public static var onError(default, null):FlxTypedSignal<(Int, String) -> Void> = new FlxTypedSignal<(Int, String) -> Void>();
	public static var onDisconnect(default, null):FlxTypedSignal<(Int, ConstCharStar) -> Void> = new FlxTypedSignal<(Int, ConstCharStar) -> Void>();
	public static var onReady(default, null):FlxTypedSignal<RawConstPointer<DiscordUser> -> Void> = new FlxTypedSignal<RawConstPointer<DiscordUser> -> Void>();
	public static var discordThread:Thread;

	public static function startup() {
		if (started)
			return;

		final handlers:DiscordEventHandlers = new DiscordEventHandlers();
		handlers.ready = _onReady.fromStaticFunction();
		handlers.disconnected = _onDisconnect.fromStaticFunction();
		handlers.errored = _onError.fromStaticFunction();
		Discord.Initialize(ID, handlers.addressOf(), false, null);
		started = true;
		active = true;

		if (discordThread == null) {
			discordThread = Thread.create(() -> {
				while (active) {
					#if DISCORD_DISABLE_IO_THREAD
					Discord.UpdateConnection();
					#end
					Discord.RunCallbacks();
					Sys.sleep(1);
				}
				discordThread = null;
				trace("Discord thread stopped.");
			});
		}
	}

	public static function shutdown() {
		if (!started) return;
		trace("Discord: Shutting down...");
		started = false;
		active = false;
		Sys.sleep(0.05);
		try {
			Discord.Shutdown();
		} catch (e) {
			trace("Discord shutdown error: " + e);
		}
		trace("Discord: Shut down complete.");
	}

	private static function _onReady(request:RawConstPointer<DiscordUser>) {
		final username:String = request[0].username;
		final globalName:String = request[0].username;
		final discriminator:Int = Std.parseInt(request[0].discriminator);
		Main.display.discordUserName = username;

		if (discriminator != 0)
			trace('Discord: Connected to user ${username}#${discriminator} ($globalName)');
		else
			trace('Discord: Connected to user @${username} ($globalName)');

		active = true;
		changePresence();
		onReady.dispatch(request);
	}

	public static function changePresence(details:String = "", ?state:String, ?smallImageKey:String, ?hasStartTimestamp:Bool, ?endTimestamp:Float,
			largeImageKey:String = "icon", largeImageText:String = "Leather Engine") {

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

		updatePresence();
	}

	public static inline function updatePresence() {
		if (!active) return;
		Discord.UpdatePresence(presence.addressOf());
	}

	public static function loadModPresence():Bool {
		var jsonPath:String = 'mods/${Options.getData("curMod")}/discord.json';

		if (FileSystem.exists(jsonPath)) {
			var discordData:DiscordData = cast Json.parse(File.getContent(jsonPath));
			trace('Found mod presence at $jsonPath');
			ID = discordData.ID;
			if (started) {
				shutdown();
				Sys.sleep(0.1);
			}
			startup();
			changePresence("", null, null, null, null, discordData.key, discordData.text);
			trace('Discord RPC updated with mod presence: ID=${discordData.ID}, key=${discordData.key}');
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
		if (ID == newID) return ID;
		ID = newID;
		shutdown();
		startup();
		updatePresence();
		return newID;
	}
}

typedef DiscordData = {
	var ID:String;
	var key:String;
	var text:String;
}
#end
