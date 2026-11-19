package utilities;

import flixel.FlxG;

class MusicTransition {
	static var _id:Int = 0;
	static var _currentPath:String = null;
	static var _normalVolume:Float = 0.7;

	static var _initialized:Bool = false;

	public static function init():Void {
		if (_initialized) return;
		_initialized = true;
	}

	public static function reset():Void {
		_currentPath = null;
	}

	public static function to(path:String, volume:Float = 0.7, loop:Bool = true, duration:Float = 0.5):Void {
		_normalVolume = volume;

		var music = FlxG.sound.music;

		if (music != null && music.active && _currentPath == path) {
			if (music.volume != volume)
				music.fadeIn(duration, music.volume, volume);
			return;
		}

		var id = ++_id;
		_currentPath = path;

		if (music != null && music.active && music.volume > 0.01) {
			music.fadeOut(duration, 0, function(_) {
				if (id != _id) return;
				FlxG.sound.playMusic(path, 0, loop);
				var m = FlxG.sound.music;
				if (m != null) {
					m.fadeIn(duration, 0, volume);
				}
			});
		} else {
			FlxG.sound.playMusic(path, 0, loop);
			var m = FlxG.sound.music;
			if (m != null) {
				m.fadeIn(duration, 0, volume);
			}
		}
	}
}
