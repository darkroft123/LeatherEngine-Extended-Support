package utilities;

import game.SongLoader.SongData;
import game.SongLoader.Section;

class ScoreValidator {
	static inline final MAX_PER_NOTE:Int = 400;

	public static function isValid(song:SongData, score:Int, ?totalNotes:Int):Bool {
		if (song == null) return true;
		if (totalNotes == null || totalNotes <= 0)
			totalNotes = countTotalNotes(song);
		var maxScore:Int = totalNotes * MAX_PER_NOTE;
		return score <= maxScore;
	}

	public static function getMaxScore(song:SongData):Int {
		if (song == null) return 0;
		return countTotalNotes(song) * MAX_PER_NOTE;
	}

	public static function countTotalNotes(song:SongData):Int {
		var total:Int = 0;
		if (song.notes == null) return 0;
		for (section in song.notes) {
			if (section == null || section.sectionNotes == null) continue;
			total += section.sectionNotes.length;
		}
		return total;
	}
}
