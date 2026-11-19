package utilities;

class SpecialDate {
	public static function matches(
		?day:Int,
		?hour:Int,
		?month:Int,
		?date:Int
	):Bool {

		var now = Date.now();

		if (day != null && now.getDay() != day)
			return false;

		if (hour != null && now.getHours() < hour)
			return false;

		if (month != null && now.getMonth() != month)
			return false;

		if (date != null && now.getDate() != date)
			return false;

		return true;
	}
}