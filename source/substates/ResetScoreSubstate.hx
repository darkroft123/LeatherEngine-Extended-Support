package substates;

import game.Highscore;

class ResetScoreSubstate extends ConfirmSubstate
{
	public var songName:String = "tutorial";
	public var difficulty:String = "normal";
	public var story:Bool = false;
	public var weekPath:String = "original_weeksWeek";
	public var weekNum:Int = 0;

	public function new(_songName:String, _difficulty:String, ?_weekNum:Int = 0, ?_weekPath:String = "original_weeksWeek", ?_story:Bool = false)
	{
		super("RESET SCORE?", function() {}, "Are you sure you want to reset your score\nfor " + (_story ? "this week" : "this song") + "?" + (Highscore.getSongStars(_story ? (_weekPath + _weekNum) : _songName, _difficulty) > 0 ? "\n(You will lose your stars too)" : ""));
		songName = _songName;
		difficulty = _difficulty;
		story = _story;
		weekPath = _weekPath;
		weekNum = _weekNum;
		onYes = doReset;
	}

	function doReset()
	{
		if (story)
			Highscore.resetWeek(weekNum, difficulty, weekPath);
		else
			Highscore.resetSong(songName, difficulty);
	}
}
