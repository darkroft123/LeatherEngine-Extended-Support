package utilities;

class NoteVariables {
	public static var maniaDirections(get, null):Array<Array<String>>;
	public static var defaultBinds(get, null):Array<Array<String>>;
	public static var animationDirections(get, null):Array<Array<String>>;
	public static var characterAnimations(get, null):Array<Array<String>>;

	/**
	 * @see https://step-mania.fandom.com/wiki/Notes
	 */
	public static var beats(default, null):Array<Int> = [4, 6, 8, 12, 16, 24, 32, 48, 64, 128, 192];

	static var initialized:Bool = false;

	static function get_maniaDirections():Array<Array<String>> {
		ensureInit();
		return maniaDirections;
	}

	static function get_defaultBinds():Array<Array<String>> {
		ensureInit();
		return defaultBinds;
	}

	static function get_animationDirections():Array<Array<String>> {
		ensureInit();
		return animationDirections;
	}

	static function get_characterAnimations():Array<Array<String>> {
		ensureInit();
		return characterAnimations;
	}

	static function ensureInit() {
		if (!initialized)
			init();
	}

	public static function init() {
		initialized = true;
		maniaDirections = CoolUtil.coolTextFileOfArrays(Paths.txt("mania data/maniaDirections"));
		defaultBinds = CoolUtil.coolTextFileOfArrays(Paths.txt("mania data/defaultBinds"));
		animationDirections = CoolUtil.coolTextFileOfArrays(Paths.txt("mania data/maniaAnimationDirections"));
		characterAnimations = CoolUtil.coolTextFileOfArrays(Paths.txt("mania data/maniaCharacterAnimations"));
	}
}
