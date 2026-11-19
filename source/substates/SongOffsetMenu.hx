package substates;

import game.Conductor;

class SongOffsetMenu extends ValueAdjustSubstate
{
	public function new()
	{
		super("Offset: ", "songOffset", 0, -99999, 99999, 0.1, true);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (controls.ACCEPT)
			curValue = Math.round(curValue);

		curValue = Math.round(curValue * 100) / 100;
	}

	override function updateText()
	{
		offsetText.text = "Offset: " + curValue + "\nPress ENTER to round number\n";
		offsetText.screenCenter();
	}

	override function onSave()
	{
		Conductor.offset = curValue;
	}
}
