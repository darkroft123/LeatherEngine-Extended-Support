package game;

import flixel.util.FlxStringUtil;
import flixel.group.FlxContainer.FlxTypedContainer;
import flixel.sound.FlxSound;

class SoundGroup extends FlxTypedContainer<FlxSound> {
	/**
	 * The volume of this group
	 */
	public var volume(default, set):Float;

	/**
	 * The pitch of this group
	 */
	public var pitch(default, set):Float = 1.0;

	/**
	 * The position of this group in milliseconds.
	 * If set while paused, changes only come into effect after a `resume()` call.
	 */
	public var time(get, set):Float;
	private var _time:Float = 0;

	/**
	 * The length of the *longest* sound in the group
	 */
	public var maxLength(get, never):Float;

	/**
	 * Whether or not the sound group is currently playing.
	 * Returns true if ANY member is actually playing (reflects real audio state).
	 */
	public var playing(get, null):Bool;
	function get_playing():Bool {
		for (member in members)
			if (member != null && member.playing) return true;
		return false;
	}


	public function play(forceRestart:Bool = false, ?startTime:Null<Float>, ?endTime:Float) {
		for (member in members) {
			if (member != null) {
				try {
					if (startTime != null) {
						member.play(forceRestart, startTime, endTime);
					} else {
						member.play(forceRestart, member.time, endTime);
					}
				} catch (e:Dynamic) {}
			}
		}
	}

	public function stop() {
		for (member in members) {
			try {
				member?.stop();
			} catch (e:Dynamic) {}
		}
	}

	public function resume() {
		for (member in members) {
			try {
				member?.resume();
			} catch (e:Dynamic) {}
		}
	}

	public function pause() {
		for (member in members) {
			try {
				member?.pause();
			} catch (e:Dynamic) {}
		}
	}

	function set_volume(volume:Float):Float {
		this.volume = volume;
		for (sound in members) {
			if(sound != null){
				sound.volume = volume;
			}
		}
		return volume;
	}

	function get_time():Float {
		for (sound in members) {
			if (sound != null && sound.playing) {
				return sound.time;
			}
		}
		if (members.length > 0 && members[0] != null) {
			return members[0].time;
		}
		return _time;
	}

	function set_time(time:Float):Float {
		this._time = time;
		for (sound in members) {
			if (sound != null) {
				var targetT:Float = time;
				if (sound.length > 0 && targetT > sound.length) {
					targetT = sound.length;
				}
				if (targetT < 0) targetT = 0;
				try {
					sound.time = targetT;
				} catch (e:Dynamic) {}
			}
		}
		return time;
	}

	function set_pitch(pitch:Float):Float {
		this.pitch = pitch;
		for (sound in members) {
			if(sound != null){
				sound.pitch = pitch;
			}
		}
		return pitch;
	}

	function get_maxLength():Float {
		var m:Float = 0.0;
		for (sound in members) {
			if (sound != null && sound.length > m) {
				m = sound.length;
			}
		}
		return m;
	}

	#if FLX_SOUND_SYSTEM
	function onFocus():Void {
		for (sound in members)
			@:privateAccess sound?.onFocus();
	}

	function onFocusLost():Void {
		for (sound in members)
			@:privateAccess sound?.onFocusLost();
	}
	#end

	override public function toString():String {
		return FlxStringUtil.getDebugString([
			LabelValuePair.weak("playing", playing),
			LabelValuePair.weak("time", time),
			LabelValuePair.weak("length", length),
			LabelValuePair.weak("volume", volume)
		]);
	}
}
