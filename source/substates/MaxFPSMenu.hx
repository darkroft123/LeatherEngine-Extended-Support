package substates;

import flixel.FlxG;
import lime.app.Application;

@:publicFields
class MaxFPSMenu extends ValueAdjustSubstate
{
	var fps(get, set):Int;

	inline function get_fps() return Std.int(curValue);
	inline function set_fps(v:Int) return Std.int(curValue = v);

	public function new()
	{
		super("Max FPS: ", "maxFPS", 120, 10, 1000, 1, true);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		#if !linux
		if (controls.ACCEPT)
			fps = Application.current.window.displayMode.refreshRate;
		#end
	}

	override function updateText()
	{
		offsetText.text = "Max FPS: " + fps #if !linux + "\nENTER for VSYNC\n" #end;
		offsetText.screenCenter();
	}

	override function onSave()
	{
		if (fps > FlxG.drawFramerate)
		{
			FlxG.updateFramerate = fps;
			FlxG.drawFramerate = fps;
		}
		else
		{
			FlxG.drawFramerate = fps;
			FlxG.updateFramerate = fps;
		}
	}
}
