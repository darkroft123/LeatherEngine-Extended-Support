package game;

import flixel.addons.ui.U as FlxU;
import flixel.sound.FlxSound;
import game.SongLoader.SongData;


/**
 * A single point in the BPM map. Stores the change point in BOTH time
 * (milliseconds) and step coordinates so time<->step conversion is O(1) per
 * segment, exactly like CodenameEngine's `Conductor.BPMChangeEvent`.
 */
typedef BPMChangeEvent = {
	/**
	 * Step this change takes effect on. Kept as `Int` because external modding
	 * libraries (Camera-utilities-dc) read this field, so sub-step precision has
	 * to come from `songTime` instead.
	 */
	var stepTime:Int;
	var songTime:Float;
	var bpm:Float;

	@:optional
	var stepCrochet:Float;

	/** Denominator (note value) active at this change point, 4 = 1/16th. **/
	@:optional
	var timeScaleDenom:Int;

	/** True when a `Continuous BPM Change` starts at this point. **/
	@:optional
	var continuous:Bool;

	/** Target BPM of a continuous ramp. **/
	@:optional
	var endBpm:Float;

	/** Ramp length, in milliseconds. `0` when not continuous. **/
	@:optional
	var endSongTime:Float;

	/** Ramp length, in steps (absolute step index at the end of the ramp). **/
	@:optional
	var endStepTime:Float;
}

typedef TimeScaleChangeEvent = {
	var stepTime:Int;
	var songTime:Float;
	var timeScale:Array<Int>;
}

typedef ScrollVelocityChangeEvent = {
	var songTime:Float;
	var speed:Float;
}

class Conductor {
	/**
	 * The BPM (Beats Per Minute) of the current song.
	 */
	public static var bpm:Float = 100;

	/**
	 * Beats in milliseconds
	 */
	public static var crochet:Float = ((60 / bpm) * 1000);

	/**
	 * Steps in milliseconds
	 */
	public static var stepCrochet:Float = crochet / 4;

	/**
	 * The position of the song in milliseconds.
	 */
	public static var songPosition:Float;

	public static var visualPosition:Float;

	public static var offset:Float = 0;

	public static var safeFrames:Int = 10;
	public static var safeZoneOffset:Float = Math.floor((safeFrames / 60) * 1000); // is calculated in create(), is safeFrames in milliseconds

	public static var bpmChangeMap:Array<BPMChangeEvent> = [];
	public static var timeScaleChangeMap:Array<TimeScaleChangeEvent> = [];
	public static var scrollVelocityChangeMap:Array<ScrollVelocityChangeEvent> = [];

	/**
	 * Start time (ms) / start step of every section, filled by `mapBPMChanges`.
	 * `sectionStartTimes[i]` is the time at which section `i` begins, and the
	 * array has one extra trailing entry with the end of the last section.
	 */
	public static var sectionStartTimes:Array<Float> = [];
	public static var sectionStartSteps:Array<Int> = [];

	public static var timeScale:Array<Int> = [4, 4];

	public static var stepsPerSection:Int = 16;

	public static var tracks:Array<FlxSound> = [];

	public static var playing:Bool = false;

	public static function start(offset:Float = 0) {
		for (track in tracks) {
			track.play(true, offset);
		}
		songPosition = offset;
		playing = true;
		resync();
	}

	public static function pause() {
		if (!playing) {
			return;
		}
		playing = false;
		for (track in tracks) {
			track.pause();
		}
	}

	public static function resume() {
		if (playing)
			return;

		start(songPosition);
	}

	public static function cleanup() {
		pause();
		songPosition = 0;
		bpmChangeMap = [];
		timeScaleChangeMap = [];
		scrollVelocityChangeMap = [];
		sectionStartTimes = [];
		sectionStartSteps = [];
		FlxU.clearArray(tracks);
	}

	public static function recalculateStuff(?multi:Float = 1) {
		safeZoneOffset = Math.floor((safeFrames / 60) * 1000) * multi;

		crochet = ((60 / bpm) * 1000);
		stepCrochet = crochet / timeScale[1];

		stepsPerSection = Math.floor((16 / timeScale[1]) * timeScale[0]);
	}

	/**
	 * Steps occupied by a section, honouring `lengthInSteps` when the chart
	 * provides it and falling back to the current time signature.
	 */
	public static function sectionLengthInSteps(sec:Dynamic, ?curTimeScale:Array<Int>):Int {
		if (sec != null) {
			if (sec.changeTimeScale == true && sec.timeScale != null && sec.timeScale.length >= 2 && sec.timeScale[1] > 0) {
				return Math.floor((16 / sec.timeScale[1]) * sec.timeScale[0]);
			}
			if (Reflect.hasField(sec, "sectionBeats")) {
				var sb = Reflect.field(sec, "sectionBeats");
				if (sb != null) {
					var beats:Float = Std.parseFloat(Std.string(sb));
					if (beats > 0) return Math.floor(beats * 4);
				}
			}
		}
		var activeScale:Array<Int> = (curTimeScale != null && curTimeScale.length >= 2 && curTimeScale[1] > 0) ? curTimeScale : timeScale;
		if (activeScale != null && activeScale.length >= 2 && activeScale[1] > 0) {
			return Math.floor((16 / activeScale[1]) * activeScale[0]);
		}
		return stepsPerSection > 0 ? stepsPerSection : 16;
	}

	/**
	 * Builds the BPM / time-signature maps out of a chart's section list.
	 *
	 * The previous implementation accumulated song time as
	 * `((60 / bpm) * 1000 / timeScale[0]) * deltaSteps`, which divided by the
	 * numerator instead of the denominator and therefore desynced every section
	 * boundary on any non 4/4 chart. It also ignored `lengthInSteps`, so any
	 * chart with irregular measures drifted. Both are fixed here.
	 */
	public static function mapBPMChanges(song:SongData, ?songMultiplier:Float = 1.0) // also maps time signature changes cuz frick u
	{
		bpmChangeMap = [];
		timeScaleChangeMap = [];
		scrollVelocityChangeMap = [];
		sectionStartTimes = [];
		sectionStartSteps = [];

		var curBPM:Float = (song.bpm > 1.0 && !Math.isNaN(song.bpm)) ? song.bpm : 100.0;
		var curTimeScale:Array<Int> = (timeScale != null && timeScale.length >= 2 && timeScale[1] > 0) ? timeScale : [4, 4];
		var totalSteps:Int = 0;
		var totalPos:Float = 0;

		// Section 0 always defines the starting point of the map.
		bpmChangeMap.push({
			stepTime: 0,
			songTime: 0,
			bpm: curBPM,
			timeScaleDenom: curTimeScale[1]
		});

		for (i in 0...song.notes.length) {
			var sec = song.notes[i];
			if (sec == null) continue;

			if (sec.changeBPM && sec.bpm > 1.0 && !Math.isNaN(sec.bpm) && sec.bpm != curBPM) {
				curBPM = sec.bpm;

				bpmChangeMap.push({
					stepTime: totalSteps,
					songTime: totalPos,
					bpm: curBPM,
					timeScaleDenom: curTimeScale[1]
				});
			}

			if (sec.changeTimeScale
				&& sec.timeScale != null
				&& sec.timeScale.length >= 2
				&& sec.timeScale[1] > 0
				&& (sec.timeScale[0] != curTimeScale[0]
				|| sec.timeScale[1] != curTimeScale[1])) {
				curTimeScale = sec.timeScale;

				timeScaleChangeMap.push({
					stepTime: totalSteps,
					songTime: totalPos,
					timeScale: curTimeScale
				});

				// The step density of the following sections depends on the new
				// signature, so the section starting here needs a fresh anchor.
				bpmChangeMap.push({
					stepTime: totalSteps,
					songTime: totalPos,
					bpm: curBPM,
					timeScaleDenom: curTimeScale[1]
				});
			}

			var deltaSteps:Int = sectionLengthInSteps(sec, curTimeScale);

			sectionStartTimes.push(totalPos);
			sectionStartSteps.push(totalSteps);

			totalSteps += deltaSteps;
			var safeBPM = (curBPM > 1.0) ? curBPM : 100.0;
			var safeDenom = (curTimeScale != null && curTimeScale.length >= 2 && curTimeScale[1] > 0) ? curTimeScale[1] : 4;
			totalPos += ((60 / safeBPM) * 1000 / safeDenom) * deltaSteps;
		}

		sectionStartTimes.push(totalPos);
		sectionStartSteps.push(totalSteps);

		if (song.events != null) {
			for (event in song.events) {
				if (event != null && event[0] != null && event[0].toLowerCase() == "change scroll velocity") {
					var scrollEvent:ScrollVelocityChangeEvent = {
						songTime: event[1],
						speed: Std.parseFloat(event[2])
					};

					scrollVelocityChangeMap.push(scrollEvent);
				}
			}
			scrollVelocityChangeMap.sort((a, b) -> Std.int(a.songTime - b.songTime));
		}

		recalculateStuff(songMultiplier);
	}

	/**
	 * Adds a non section aligned BPM change at an arbitrary point in time.
	 * Used by the Codename loader and the `BPM Change` event so charts that
	 * change tempo mid section still move notes at the right speed.
	 */
	public static function addBPMChangeAtTime(songTime:Float, newBpm:Float) {
		if (bpmChangeMap == null || bpmChangeMap.length == 0) {
			bpmChangeMap = [{stepTime: 0, songTime: 0, bpm: bpm, timeScaleDenom: timeScale[1]}];
		}

		var lastChange:BPMChangeEvent = bpmChangeMap[bpmChangeMap.length - 1];
		if (songTime <= lastChange.songTime) {
			lastChange.bpm = newBpm;
			if (bpmChangeMap.length == 1) {
				bpm = newBpm;
				recalculateStuff();
			}
			return;
		}

		lastChange = getBPMFromSeconds(songTime);
		bpmChangeMap.push({
			stepTime: Math.round(getStep(songTime)),
			songTime: songTime,
			bpm: newBpm,
			timeScaleDenom: lastChange.timeScaleDenom != null ? lastChange.timeScaleDenom : timeScale[1]
		});
	}

	public static function changeBPM(newBpm:Float, ?multi:Float = 1) {
		bpm = newBpm;
		recalculateStuff(multi);
	}

	/**
	 * Registers a `Continuous BPM Change`: BPM ramps logarithmically from the
	 * current tempo to `targetBpm` over `durationSteps` steps.
	 */
	public static function registerContinuousBPMChange(songTime:Float, targetBpm:Float, durationSteps:Float) {
		if (bpmChangeMap == null || bpmChangeMap.length == 0) {
			bpmChangeMap = [{stepTime: 0, songTime: 0, bpm: bpm, timeScaleDenom: timeScale[1]}];
		}

		var idx = getChangeIndexAtTime(songTime);
		var startBpm:Float = bpmChangeMap[idx].bpm;
		var denom:Int = bpmChangeMap[idx].timeScaleDenom != null ? bpmChangeMap[idx].timeScaleDenom : timeScale[1];

		var startStep:Float = getStep(songTime);
		var endStep:Float = startStep + durationSteps;

		// ms needed to walk `durationSteps` while ramping from startBpm to targetBpm.
		// The ramp length is what we are solving for, so it must stay unbounded here;
		// passing a finite cap would collapse every ramp into a few milliseconds.
		var duration:Float = timeInRamp(startBpm, targetBpm, Math.POSITIVE_INFINITY, durationSteps);

		if (songTime <= bpmChangeMap[0].songTime) {
			bpmChangeMap[0] = {
				stepTime: 0,
				songTime: 0,
				bpm: startBpm,
				timeScaleDenom: denom,
				continuous: true,
				endBpm: targetBpm,
				endSongTime: duration,
				endStepTime: endStep
			};
			return;
		}

		bpmChangeMap.push({
			stepTime: Math.round(startStep),
			songTime: songTime,
			bpm: startBpm,
			timeScaleDenom: denom,
			continuous: true,
			endBpm: targetBpm,
			endSongTime: songTime + duration,
			endStepTime: endStep
		});
	}

	/**
	 * Pushes the BPM active at `time` into the static `bpm` value so
	 * `crochet` / `stepCrochet` stay in sync. Needed for continuous changes,
	 * which move the tempo every single frame.
	 */
	public static function syncBPM(?time:Float, ?multi:Float = 1) {
		if (bpmChangeMap == null || bpmChangeMap.length == 0) return;
		var t = time != null ? time : songPosition;
		if (t < bpmChangeMap[0].songTime) return;
		var active:Float = getBPMAtTime(t);
		if (active > 0 && Math.abs(active - bpm) > 0.0001) {
			bpm = active;
			recalculateStuff(multi);
		}
	}

	/**
	 * Scroll speed requested by a `Change Scroll Velocity` event at `time`,
	 * or `null` when no such change is active.
	 */
	public static function getScrollVelocityAtTime(time:Float):Null<Float> {
		var result:Null<Float> = null;
		for (change in scrollVelocityChangeMap) {
			if (change.songTime <= time) result = change.speed;
			else break;
		}
		return result;
	}

	inline public static function calculateCrochet(bpm:Float) {
		return (60 / bpm) * 1000;
	}

	public static function resync() {
		if (!playing) {
			return;
		}
		for (track in tracks) {
			if (track.playing && Math.abs(track.time - Conductor.songPosition) > 30) {
				trace("resynced tracks", DEBUG);
				track.stop();
				track.play(true, Conductor.songPosition);
			}
		}
	}

	/**
	 * Index of the last BPM change whose `songTime` is <= `time`.
	 * Binary search so it stays cheap on songs with hundreds of changes.
	 */
	public static function getChangeIndexAtTime(time:Float):Int {
		var map = bpmChangeMap;
		if (map == null || map.length == 0) return -1;
		if (time <= map[0].songTime) return 0;

		var lo = 0;
		var hi = map.length - 1;
		while (lo < hi) {
			var mid = (lo + hi + 1) >> 1;
			if (map[mid].songTime <= time) lo = mid; else hi = mid - 1;
		}
		return lo;
	}

	/**
	 * BPM map entry active at the given position of the song.
	 */
	public static function getBPMFromSeconds(time:Float):BPMChangeEvent {
		var idx = getChangeIndexAtTime(time);
		if (idx < 0) {
			return {
				stepTime: 0,
				songTime: 0,
				bpm: bpm,
				timeScaleDenom: timeScale[1]
			};
		}

		var change = bpmChangeMap[idx];
		var denom:Int = change.timeScaleDenom != null ? change.timeScaleDenom : timeScale[1];
		if (denom < 1) denom = 4;

		// Interpolate logarithmically while a continuous ramp is in progress.
		if (change.continuous && change.endSongTime > change.songTime) {
			// `change.bpm` already holds the tempo the ramp starts from, so it is
			// the interpolation origin. Reaching into the previous map entry would
			// use whatever tempo came before the ramp started.
			var startBpm:Float = change.bpm;
			if (change.endBpm != null && change.endBpm > 0 && startBpm > 0) {
				var ratio = (time - change.songTime) / (change.endSongTime - change.songTime);
				if (ratio < 0) ratio = 0;
				if (ratio > 1) ratio = 1;
				var interpolated:Float = Math.pow(startBpm, 1 - ratio) * Math.pow(change.endBpm, ratio);
				return {
					stepTime: change.stepTime,
					songTime: change.songTime,
					bpm: interpolated,
					timeScaleDenom: denom
				};
			}
		}

		return {
			stepTime: change.stepTime,
			songTime: change.songTime,
			bpm: change.bpm,
			timeScaleDenom: denom
		};
	}

	/**
	 * BPM active at the given position of the song.
	 */
	public static function getBPMAtTime(time:Float):Float {
		return getBPMFromSeconds(time).bpm;
	}

	inline public static function stepCrochetForBPM(changeBpm:Float, ?denom:Int) {
		return (60 / changeBpm) * 1000 / (denom != null && denom > 0 ? denom : timeScale[1]);
	}

	/** Steps per millisecond (1 step == 1/16th note). **/
	inline static function stepsPerMs(changeBpm:Float):Float {
		return changeBpm / 240000;
	}

	/**
	 * Elapsed steps inside a logarithmic BPM ramp.
	 *
	 * A `Continuous BPM Change` interpolates BPM exponentially
	 * (`bpm(t) = b0 * (b1/b0)^(t/D)`), so the number of steps covered is the
	 * integral of that curve. The closed form below is the exact integral,
	 * which is what CodenameEngine does in `getTimeWithBPMInSteps`.
	 */
	public static function stepsInRamp(b0:Float, b1:Float, duration:Float, elapsed:Float):Float {
		if (elapsed <= 0) return 0;
		if (duration <= 0) return 0;
		if (elapsed > duration) elapsed = duration;

		var ratio:Float = b1 / b0;
		if (Math.abs(ratio - 1) < 0.000001) return elapsed * stepsPerMs(b0);

		return b0 * (b1 - b0) * elapsed / Math.log(ratio) * stepsPerMs(1);
	}

	/**
	 * Inverse of `stepsInRamp`: time needed inside a ramp to cover `steps`.
	 */
	public static function timeInRamp(b0:Float, b1:Float, duration:Float, steps:Float):Float {
		if (steps <= 0) return 0;

		var ratio:Float = b1 / b0;
		if (Math.abs(ratio - 1) < 0.000001) return steps / stepsPerMs(b0);

		var elapsed:Float = steps / (b0 * (b1 - b0) * stepsPerMs(1)) * Math.log(ratio);
		return elapsed > duration ? duration : elapsed;
	}

	/**
	 * Note value the chart is currently in, as a usable step length. `timeScale`
	 * is `Array<Int>`, so a bogus or missing denominator falls back to 4 (1/16).
	 */
	inline static function currentDenom():Int {
		return (timeScale != null && timeScale.length > 1 && timeScale[1] > 0) ? timeScale[1] : 4;
	}

	/**
	 * Returns the current step at the given position of the song.
	 * @param time the position of the song (in millseconds)
	 */
	public static function getStep(time:Float):Float {
		var idx = getChangeIndexAtTime(time);
		if (idx < 0) {
			return time / stepCrochetForBPM(bpm, currentDenom());
		}

		var change = bpmChangeMap[idx];

		if (change.continuous && change.endSongTime > change.songTime) {
			var startBpm:Float = change.bpm;
			var endBpm:Float = change.endBpm != null ? change.endBpm : startBpm;
			if (time > change.songTime && time < change.endSongTime) {
				return change.stepTime + stepsInRamp(startBpm, endBpm, change.endSongTime - change.songTime, time - change.songTime);
			}
			if (time >= change.endSongTime) return change.stepTime + change.endStepTime - change.stepTime;
		}

		var denom:Int = change.timeScaleDenom != null ? change.timeScaleDenom : timeScale[1];
		return change.stepTime + (time - change.songTime) / stepCrochetForBPM(change.bpm, denom);
	}

	/**
	 * Returns the current beat at the given position of the song.
	 * @param time the position of the song (in millseconds)
	 */
	public static function getBeat(time:Float):Float {
		return getStep(time) / currentDenom();
	}

	/**
	 * Inverse of `getStep`: converts a step index into a position in
	 * milliseconds, walking the BPM map so tempo changes are respected.
	 */
	public static function getTimeInSteps(step:Float):Float {
		if (bpmChangeMap == null || bpmChangeMap.length == 0) {
			return step * ((60 / bpm) * 1000 / currentDenom());
		}

		var idx = 0;
		for (i in 0...bpmChangeMap.length) {
			if (bpmChangeMap[i].stepTime <= step) idx = i; else break;
		}

		var change = bpmChangeMap[idx];

		if (change.continuous && change.endSongTime > change.songTime) {
			var startBpm:Float = change.bpm;
			var endBpm:Float = change.endBpm != null ? change.endBpm : startBpm;
			var rampEndStep:Float = change.endStepTime;
			if (step <= rampEndStep) {
				return change.songTime + timeInRamp(startBpm, endBpm, change.endSongTime - change.songTime, step - change.stepTime);
			}
			var denomR:Int = change.timeScaleDenom != null ? change.timeScaleDenom : timeScale[1];
			return change.endSongTime + (step - rampEndStep) * stepCrochetForBPM(endBpm, denomR);
		}

		var denom:Int = change.timeScaleDenom != null ? change.timeScaleDenom : timeScale[1];
		return change.songTime + (step - change.stepTime) * stepCrochetForBPM(change.bpm, denom);
	}

	/**
	 * How many milliseconds one step lasts at `time`.
	 *
	 * `stepCrochet` is a single live value, so it only describes the tempo the
	 * conductor happens to be on. Anything that has to size a note against the
	 * song rather than against the playhead — a sustain segment drawn at its own
	 * position, for instance — has to ask for the step length where that note
	 * actually is, otherwise the pieces of a hold that crosses a tempo change
	 * come out in the wrong proportion.
	 */
	public static function getStepDurationAt(time:Float):Float {
		return getStepDuration(getStep(time));
	}

	/** Milliseconds covered by the step starting at `step`. */
	public static function getStepDuration(step:Float):Float {
		if (bpmChangeMap == null || bpmChangeMap.length == 0) return stepCrochet;
		var d:Float = getTimeInSteps(step + 1) - getTimeInSteps(step);
		return (d > 0) ? d : stepCrochet;
	}

	/**
	 * Start times, in absolute ms, of the steps a sustain covers.
	 *
	 * Single owner of "which steps does this hold span". The piece count used to be
	 * `sustainLength / Std.int(stepCrochet)`, and `Std.int` truncates the step to
	 * whole milliseconds, so the count was off by a fraction of a step on every
	 * single hold; `Math.floor` on top of that dropped the final step whenever the
	 * hold was not a whole number of steps long, and the hold visibly ended early.
	 *
	 * Counting through the BPM map instead also holds when the song changes tempo,
	 * which the live `stepCrochet` cannot do.
	 */
	public static function sustainSteps(strumTime:Float, sustainLength:Float):Array<Float> {
		var out:Array<Float> = [];
		if (sustainLength <= 0) return out;

		var end:Float = strumTime + sustainLength;
		var startStep:Float = getStep(strumTime);
		var k:Int = 0;
		// Cap guards against a malformed map; a step is never zero-length.
		while (k < 2048) {
			var t:Float = getTimeInSteps(startStep + k);
			if (t >= end) break;
			// The two conversions are inverse but not exact, so a piece can land a
			// fraction of a millisecond past the end. Stopping as soon as time stops
			// advancing keeps a lone piece from trailing after the hold.
			if (k > 0 && t <= out[out.length - 1]) break;
			out.push(t);
			k++;
		}
		return out;
	}

	/**
	 * End of the last sustain piece, never closer than one step to its start.
	 *
	 * The `holdend` cap is drawn on the last piece, and it is the one piece that
	 * no successor resizes, so it has to be told how tall it is. The floor of one
	 * step means the chain can finish a fraction of a step past the real end of
	 * the hold, the same way `Math.ceil` on the piece count used to round up.
	 *
	 * Pair with `sustainSteps`, which reports where the pieces start.
	 */
	public static function sustainPieceEnd(start:Float, realEnd:Float):Float {
		var step:Float = getStepDurationAt(start);
		return (realEnd - start < step) ? start + step : realEnd;
	}

	/**
	 * Start time in milliseconds of a given section, taken from the map built
	 * by `mapBPMChanges`. O(1) instead of the O(n) walk the chart editor used.
	 */
	public static function getSectionStartTime(section:Int):Float {
		if (sectionStartTimes == null || sectionStartTimes.length == 0) return 0;
		if (section < 0) return 0;
		if (section >= sectionStartTimes.length) return sectionStartTimes[sectionStartTimes.length - 1];
		return sectionStartTimes[section];
	}

	/**
	 * Index of the section that contains the given position in time.
	 */
	public static function getSectionAtTime(time:Float):Int {
		if (sectionStartTimes == null || sectionStartTimes.length <= 1) return 0;
		var lo = 0;
		var hi = sectionStartTimes.length - 2;
		if (hi < 0) return 0;
		while (lo < hi) {
			var mid = (lo + hi + 1) >> 1;
			if (sectionStartTimes[mid] <= time) lo = mid; else hi = mid - 1;
		}
		return lo;
	}

	/**
	 * Start step of a given section, from the map built by `mapBPMChanges`.
	 */
	public static function getSectionStartStep(section:Int):Float {
		if (sectionStartSteps == null || sectionStartSteps.length == 0) return 0;
		if (section < 0) return 0;
		if (section >= sectionStartSteps.length) return sectionStartSteps[sectionStartSteps.length - 1];
		return sectionStartSteps[section];
	}
}
