package substates;

import states.OptionsMenu;

class ResetOptionsSubstate extends ConfirmSubstate
{
	public function new()
	{
		super("RESET OPTIONS?", function() { OptionsMenu.resetToDefaults(); }, "Are you sure you want to reset all\noptions to their default values?");
	}
}
