package;

class DPIFix {
	public static inline var FLAG_FILE:String = "dpi_off.flag";

	// SetProcessDPIAware() runs inside NativeWindow.new() BEFORE lime creates the
	// window (calling it later left windows off-center on scaled displays).
	// Since it cannot be undone once set, the saved option is honored through a
	// plain marker file that NativeWindow can read before flixel even loads.
	// The file always exists once written; its content ("on"/"off") decides.
	// NOTE: only sys.io.File is used here on purpose, sys.io.FileSystem does not
	// resolve in this Haxe installation (its files are misplaced in the std lib).
	public static function apply() {
		#if windows
		var flagPath:String = getFlagPath();
		var save = new flixel.util.FlxSave();
		save.bind("darks_collection_v3.5_v4-options", lime.app.Application.current.meta.get('company'));

		if (save.data.dpiAware == false) {
			// Migration: user had it OFF before this system existed.
			writeFlag(flagPath, true);
			trace("DPI Awareness is OFF: restart again so the window starts without native DPI scaling.");
		} else {
			writeFlag(flagPath, false);
		}
		#end
	}

	// Called right before the automatic restart when toggling the option,
	// so the relaunched process picks the new value up immediately.
	public static function syncFlagFile():Void {
		#if windows
		writeFlag(getFlagPath(), utilities.Options.getData("dpiAware") == false);
		#end
	}

	#if windows
	private static function getFlagPath():String {
		return lime.system.System.applicationStorageDirectory + FLAG_FILE;
	}

	private static function writeFlag(path:String, dpiOff:Bool):Void {
		try {
			sys.io.File.saveContent(path, dpiOff ? "off" : "on");
		} catch (e:Dynamic) {}
	}
	#end
}
