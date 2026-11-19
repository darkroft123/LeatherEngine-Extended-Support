package states;

import flixel.addons.transition.FlxTransitionableState;
import flixel.addons.transition.TransitionData;

import flixel.FlxBasic;
import modding.scripts.ExecuteOn;
import modding.scripts.languages.HScript;
import flixel.input.FlxInput.FlxInputState;
import game.Conductor;
import utilities.PlayerSettings;
import game.Conductor.BPMChangeEvent;
import utilities.Controls;
import flixel.FlxG;

import flixel.sound.FlxSound;
/**
 * The backend state all states will extend from.
 */
class MusicBeatState extends #if MODCHARTING_TOOLS modcharting.ModchartMusicBeatState #else flixel.addons.ui.FlxUIState #end {
	public var curStep:Int = 0;
	public var curBeat:Int = 0;

	public var curDecStep:Float = 0;
	public var curDecBeat:Float = 0;

	private var controls(get, never):Controls;

	public static var windowNameSuffix(default, set):String = "";
	public static var windowNamePrefix(default, set):String = "Leather Engine Extended Support";

	public static var fullscreenBind:String = "F11";
	public static var autoTestStateDuration:Float = -1;
	public static var autoTestStateElapsed:Float = 0;

	#if HSCRIPT_ALLOWED
	public var stateScript:HScript;
	#end

	public var hasTransitions:Bool = true;

	override public function create() {
		if (FlxTransitionableState.defaultTransIn == null) {
			FlxTransitionableState.defaultTransIn = new TransitionData(
				FADE,
				flixel.util.FlxColor.BLACK,
				0.7
			);
		}
		if (FlxTransitionableState.defaultTransOut == null) {
			FlxTransitionableState.defaultTransOut = new TransitionData(
				FADE,
				flixel.util.FlxColor.BLACK,
				0.7
			);
		}

		if (hasTransitions) {
			if (transIn == null)
				transIn = FlxTransitionableState.defaultTransIn;
			if (transOut == null)
				transOut = FlxTransitionableState.defaultTransOut;
		} else {
			transIn = null;
			transOut = null;
		}

		super.create();
		#if HSCRIPT_ALLOWED
		var statePath:String = Type.getClassName(Type.getClass(this)).replace(".", "/");
		if (sys.FileSystem.exists('mods/${Options.getData("curMod")}/classes/${statePath}.hx')) {
			stateScript = new HScript('mods/${Options.getData("curMod")}/classes/${statePath}.hx');
		}
		#end
	}

	public function call(func:String, ?args:Array<Any>, executeOn:ExecuteOn = BOTH) {
		#if HSCRIPT_ALLOWED
		stateScript?.call(func, args);
		#end
	}

	private function updateSongPosition(?inst:FlxSound):Void {
		inst ??= Conductor.tracks[0] ?? FlxG.sound.music;
		if (inst == null)
			return;

		if (inst.playing) {
			Conductor.songPosition += FlxG.elapsed * 1000.0 * inst.pitch;
		}

		var gamerValue = 20 * inst.pitch;
		var time = inst.time;
		var songPos = Conductor.songPosition;

		if (time > songPos + gamerValue
			|| time < songPos - gamerValue
			|| (time < 500 && (time > songPos + 5 || time < songPos - 5))) {

			if (!(songPos > 20 && time < 20)) {
				if (time >= inst.length)
					Conductor.songPosition = inst.length;
				else
					Conductor.songPosition = inst.time;
			}
		}
	}
	override function update(elapsed:Float) {
		var oldStep:Int = curStep;

		updateCurStep();
		updateBeat();

		if (oldStep != curStep && curStep > 0)
		{
			if (oldStep < curStep && oldStep > 0)
			{
				var targetStep = curStep;
				var targetDecStep = curDecStep;
				var maxCatchup:Int = 16;
				var startStep:Int = (targetStep - oldStep > maxCatchup) ? (targetStep - maxCatchup) : (oldStep + 1);
				
				for (i in startStep...(targetStep + 1))
				{
					curStep = i;
					curDecStep = i;
					updateBeat();
					stepHit();
				}
				
				curStep = targetStep;
				curDecStep = targetDecStep;
				updateBeat();
			}
			else
			{
				stepHit();
			}
		}

		super.update(elapsed);

		/*if (!Options.getData("antialiasing")) {
			forEachAlive(function(basic:FlxBasic) {
				if (!(basic is FlxSprite)) {
					return;
				}
				cast(basic, FlxSprite).antialiasing = false;
			}, true);
		}*/

		if (FlxG.keys.checkStatus(FlxKey.fromString(Options.getData("fullscreenBind", "binds")), FlxInputState.JUST_PRESSED))
			FlxG.fullscreen = !FlxG.fullscreen;

		if (FlxG.keys.justPressed.F5 && Options.getData("developer"))
			FlxG.resetState();

		var newAutoPause:Bool = Options.getData("autoPause");
		if (FlxG.autoPause != newAutoPause)
			FlxG.autoPause = newAutoPause;

		#if sys
		if (autoTestStateDuration > 0) {
			autoTestStateElapsed += elapsed;
			if (autoTestStateElapsed >= autoTestStateDuration) {
				Sys.println("[STATE_TEST_OK] " + Type.getClassName(Type.getClass(FlxG.state)) + " (" + Math.round(autoTestStateElapsed * 10) / 10 + "s)");
				Sys.exit(0);
			}
		}
		#end
	}

	

	public function updateBeat():Void {
		curDecBeat = curStep / Conductor.timeScale[1];
		curBeat = Math.floor(curDecBeat);
	}

	public function updateCurStep():Void {
		var dumb:TimeScaleChangeEvent = {
			stepTime: 0,
			songTime: 0,
			timeScale: [4, 4]
		};

		var lastTimeChange:TimeScaleChangeEvent = dumb;

		for (i in 0...Conductor.timeScaleChangeMap.length) {
			if (Conductor.songPosition >= Conductor.timeScaleChangeMap[i].songTime)
				lastTimeChange = Conductor.timeScaleChangeMap[i];
		}

		if (lastTimeChange != dumb)
			Conductor.timeScale = lastTimeChange.timeScale;

		var multi:Float = 1;

		if (FlxG.state == PlayState.instance)
			multi = PlayState.songMultiplier;

		Conductor.recalculateStuff(multi);

		// `getStep` walks the BPM map, so mid song tempo changes and continuous
		// ramps are accounted for instead of only snapping on section borders.
		curDecStep = Conductor.getStep(Conductor.songPosition);
		curStep = Math.floor(curDecStep);
		updateBeat();
	}

	public function stepHit():Void {
		if (curStep % Conductor.timeScale[0] == 0)
			beatHit();
	}

	public function beatHit():Void {/* do literally nothing dumbass */}

	/**
	 * Adds `behind` behind `obj`
	 * @param behind The object to add behind
	 * @param obj The object that will be in front
	 */
	function addBehind(behind:FlxBasic, obj:FlxBasic) {
		insert(members.indexOf(obj), behind);
	}

	@:noCompletion
	inline static function set_windowNameSuffix(value:String):String {
		windowNameSuffix = value;
		_refreshWindowName();
		return value;
	}

	@:noCompletion
	inline static function set_windowNamePrefix(value:String):String {
		windowNamePrefix = (value != null && value != "") ? value : "Leather Engine Extended Support";
		_refreshWindowName();
		return value;
	}

	@:noCompletion
	inline function get_controls():Controls
		return PlayerSettings.player1.controls;

	@:noCompletion
	inline static function _refreshWindowName():Void {
		var newTitle = windowNamePrefix + windowNameSuffix #if debug + ' (DEBUG)' #end;
		if (FlxG.stage.window.title != newTitle) {
			FlxG.stage.window.title = newTitle;
		}
	}

	override public function destroy() {
		flixel.tweens.FlxTween.cancelTweensOf(this);
		forEach(function(basic:flixel.FlxBasic) {
			if (basic != null) flixel.tweens.FlxTween.cancelTweensOf(basic);
		});
		#if HSCRIPT_ALLOWED
		if (stateScript != null) {
			stateScript.destroy();
			stateScript = null;
		}
		#end
		super.destroy();
	}
}
