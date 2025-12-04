package states;

import flixel.FlxBasic;
import modding.scripts.ExecuteOn;
import modding.scripts.languages.HScript;
import flixel.input.FlxInput.FlxInputState;
import game.Conductor;
import utilities.PlayerSettings;
import game.Conductor.BPMChangeEvent;
import utilities.Controls;
import flixel.FlxG;
import lime.app.Application;
#if mobile //mobile stuff
import flixel.input.gamepad.FlxGamepad;
import mobile.flixel.FlxVirtualPad;
import flixel.FlxCamera;
import flixel.input.actions.FlxActionInput;
import flixel.util.FlxDestroyUtil;
#end
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
	public static var windowNamePrefix(default, set):String = "Leather Engine";

	public static var fullscreenBind:String = "F11";

	#if HSCRIPT_ALLOWED
	public var stateScript:HScript;
	#end
	public static var usingController:Bool = false;
	#if mobile
	var virtualPad:FlxVirtualPad;
	var trackedInputsVirtualPad:Array<FlxActionInput> = [];

	//mobile
	public function addVirtualPad(DPad:FlxDPadMode, Action:FlxActionMode, visible:Bool = true):Void
	{
		if (virtualPad != null)
			removeVirtualPad();

		virtualPad = new FlxVirtualPad(DPad, Action);
		virtualPad.visible = visible;
		add(virtualPad);

		controls.setVirtualPad(virtualPad, DPad, Action);
		trackedInputsVirtualPad = controls.trackedInputs;
		controls.trackedInputs = [];
	}

	public function addVirtualPadCamera(DefaultDrawTarget:Bool = false):Void
	{
		if (virtualPad != null)
		{
			var camControls:FlxCamera = new FlxCamera();
			camControls.bgColor.alpha = 0;
			FlxG.cameras.add(camControls, DefaultDrawTarget);
			virtualPad.cameras = [camControls];
		}
	}

	public function removeVirtualPad():Void
	{
		if (trackedInputsVirtualPad.length > 0)
			controls.removeVirtualControlsInput(trackedInputsVirtualPad);

		if (virtualPad != null)
			remove(virtualPad);
	}
	#end

	override public function create() {
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

	override function update(elapsed:Float) {
		var oldStep:Int = curStep;

		updateCurStep();
		updateBeat();

		if (oldStep != curStep && curStep > 0)
			stepHit();

		super.update(elapsed);

		/*if (!Options.getData("antialiasing")) {
			forEachAlive(function(basic:FlxBasic) {
				if (!(basic is FlxSprite)) {
					return;
				}
				cast(basic, FlxSprite).antialiasing = false;
			}, true);
		}*/

		if(FlxG.keys.checkStatus(FlxKey.fromString(Options.getData("fullscreenBind", "binds")), FlxInputState.JUST_PRESSED))
			FlxG.fullscreen = !FlxG.fullscreen;

		Application.current.window.title = windowNamePrefix + windowNameSuffix;		

		if (FlxG.mouse.justPressed || FlxG.mouse.justMoved || FlxG.keys.justPressed.ANY #if mobile || MobileControls.justPressedAny() #end)
		{
			usingController = false;
		}
		#if mobile
		var gamepad:FlxGamepad = FlxG.gamepads.lastActive;
		if (gamepad != null)
		{
			if (gamepad.anyInput())
				usingController = true;
		}
		#end
	}
	#if mobile
	override function destroy():Void {
		if (trackedInputsVirtualPad.length > 0)
			controls.removeVirtualControlsInput(trackedInputsVirtualPad);

		super.destroy();

		if (virtualPad != null)
			virtualPad = FlxDestroyUtil.destroy(virtualPad);
	}#end


	public function updateBeat():Void {
		curDecBeat = curStep / Conductor.timeScale[1];
		curBeat = Math.floor(curDecBeat);
	}

	public function updateCurStep():Void {
		var lastChange:BPMChangeEvent = Conductor.getBPMFromSeconds(Conductor.songPosition);

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

		var value:Float = (Conductor.songPosition - lastChange.songTime) / Conductor.stepCrochet;
		curDecStep = value;
		curStep = Math.floor(curDecStep);
		curStep += lastChange.stepTime;
		curDecStep += lastChange.stepTime;
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
		windowNamePrefix = value;
		_refreshWindowName();
		return value;
	}

	@:noCompletion
	inline function get_controls():Controls
		return PlayerSettings.player1.controls;

	@:noCompletion
	inline static function _refreshWindowName():Void {
		FlxG.stage.window.title = windowNamePrefix + windowNameSuffix #if debug + ' (DEBUG)' #end;
	}
}
