package substates;

import flixel.FlxG;
import states.FreeplayState;
import states.StoryMenuState;
import states.GroupSelectState;
import states.PlayState;
import states.LoadingState;
import substates.CustomDialogSubstate.DialogOption;

class ExitChartingSubstate extends CustomDialogSubstate
{
	public function new(
		title:String = "EXIT CHARTING MODE",
		subtitle:String = "Select destination:",
		options:Array<DialogOption> = null
	)
	{
		if (options == null || options.length == 0)
		{
			var isFromCharter:Bool = (FlxG.state is toolbox.ChartingState);
			options = [
				{
					label: PlayState.isStoryMode ? "STORY MENU" : "FREEPLAY",
					callback: function() {
						PlayState.chartingMode = PlayState.modchartingMode = false;
						PlayState.botUsed = PlayState.noDeathUsed = PlayState.tooSlow = false;
						PlayState.startOnTime = 0;
						if (FlxG.sound.music != null) FlxG.sound.music.stop();
						if (FlxG.state is toolbox.ChartingState) {
							var charter:toolbox.ChartingState = cast FlxG.state;
							if (charter.vocals != null) charter.vocals.stop();
						}
						if (PlayState.instance != null && PlayState.instance.vocals != null)
							PlayState.instance.vocals.stop();
						FlxG.switchState(
							PlayState.isStoryMode
							? () -> new StoryMenuState()
							: () -> new FreeplayState(GroupSelectState.groupID, GroupSelectState.groupSongs)
						);
					}
				},
				{
					label: "CHARTER MENU",
					callback: function() {
						PlayState.startOnTime = 0;
						if (FlxG.sound.music != null) FlxG.sound.music.stop();
						if (FlxG.state is toolbox.ChartingState) {
							var charter:toolbox.ChartingState = cast FlxG.state;
							if (charter.vocals != null) charter.vocals.stop();
						}
						if (PlayState.instance != null && PlayState.instance.vocals != null)
							PlayState.instance.vocals.stop();

						PlayState.chartingMode = false;
						PlayState.botUsed = PlayState.noDeathUsed = PlayState.tooSlow = false;
						FlxG.switchState(() -> new toolbox.ChartingState());
					}
				}
			];

			if (isFromCharter) {
				options.push({
					label: "PLAY",
					callback: function() {
						PlayState.startOnTime = 0;
						if (FlxG.sound.music != null) FlxG.sound.music.stop();
						if (FlxG.state is toolbox.ChartingState) {
							var charter:toolbox.ChartingState = cast FlxG.state;
							if (charter.vocals != null) charter.vocals.stop();
						}
						if (PlayState.instance != null && PlayState.instance.vocals != null)
							PlayState.instance.vocals.stop();

						PlayState.chartingMode = true;
						PlayState.playCutscenes = true;
						PlayState.loadChartEvents = false;
						LoadingState.loadAndSwitchState(() -> new PlayState());
					}
				});
			}

			options.push({
				label: "CANCEL",
				callback: null
			});
		}

		super(title, subtitle, options);
	}
}
