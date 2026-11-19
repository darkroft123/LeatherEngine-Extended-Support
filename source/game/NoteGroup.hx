package game;

import flixel.FlxCamera;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxSort;
import game.Conductor;

/**
 * Group of notes (ported from Codename Engine) that updates, iterates,
 * and renders only notes within the active `limit` window, drawing sustains
 * before head notes without needing per-beat sorting.
 */
class NoteGroup extends FlxTypedGroup<Note> {
	var __loopSprite:Note;
	var i:Int = 0;
	var __currentlyLooping:Bool = false;
	var __time:Float = -1.0;

	/**
	 * How many milliseconds ahead of `Conductor.songPosition` to update/draw notes.
	 */
	public var limit:Float = 1500.0;

	/**
	 * Preallocates the members array with fixed length.
	 */
	public inline function preallocate(len:Int) {
		members = cast new haxe.ds.Vector<Note>(len);
		length = len;
	}

	/**
	 * Adds an array of notes to the group and sorts them descending by strumTime.
	 */
	public inline function addNotes(notes:Array<Note>) {
		for (e in notes) add(e);
		sortNotes();
	}

	/**
	 * Sorts notes descending by strumTime (earliest at the end, sustains drawn first).
	 */
	public inline function sortNotes() {
		sort(function(i, n1, n2) {
			if (n1.strumTime == n2.strumTime)
				return n1.isSustainNote ? 1 : -1;
			return FlxSort.byValues(FlxSort.DESCENDING, n1.strumTime, n2.strumTime);
		});
	}

	public var __forcedSongPos:Null<Float> = null;

	private inline function __getSongPos():Float
		return __forcedSongPos == null ? Conductor.songPosition : __forcedSongPos;

	public override function update(elapsed:Float) {
		i = 0;
		__loopSprite = null;
		__time = __getSongPos() + limit;
		while (i < length) {
			__loopSprite = members[i++];
			if (__loopSprite == null || !__loopSprite.exists || !__loopSprite.active) continue;
			if (__loopSprite.strumTime > __time) break;
			__loopSprite.update(elapsed);
		}
	}

	public override function draw() @:privateAccess {
		var oldDefaultCameras = FlxCamera._defaultCameras;
		if (_cameras != null) FlxCamera._defaultCameras = _cameras;

		var oldCur = __currentlyLooping;
		__currentlyLooping = true;
		__time = __getSongPos() + limit;

		// Draw sustain notes first
		i = 0;
		__loopSprite = null;
		while (i < length) {
			__loopSprite = members[i++];
			if (__loopSprite == null || !__loopSprite.isSustainNote || !__loopSprite.exists || !__loopSprite.visible) continue;
			if (__loopSprite.strumTime > __time) break;
			__loopSprite.draw();
		}

		// Then draw regular head notes
		i = 0;
		__loopSprite = null;
		while (i < length) {
			__loopSprite = members[i++];
			if (__loopSprite == null || __loopSprite.isSustainNote || !__loopSprite.exists || !__loopSprite.visible) continue;
			if (__loopSprite.strumTime > __time) break;
			__loopSprite.draw();
		}
		__currentlyLooping = oldCur;

		FlxCamera._defaultCameras = oldDefaultCameras;
	}

	public function get(id:Int):Note {
		return members[id];
	}

	public override function forEach(noteFunc:Note->Void, recursive:Bool = false) {
		__doForEach(noteFunc, false);
	}

	public override function forEachAlive(noteFunc:Note->Void, recursive:Bool = false) {
		__doForEach(noteFunc, true);
	}

	private function __doForEach(noteFunc:Note->Void, onlyAlive:Bool):Void {
		i = 0;
		__loopSprite = null;
		__time = __getSongPos() + limit;

		var oldCur = __currentlyLooping;
		__currentlyLooping = true;

		while (i < length) {
			__loopSprite = members[i++];
			if (__loopSprite == null || !__loopSprite.exists) continue;
			if (__loopSprite.strumTime > __time) break;
			if (!onlyAlive || __loopSprite.alive) noteFunc(__loopSprite);
		}
		__currentlyLooping = oldCur;
	}

	public override function remove(Object:Note, Splice:Bool = false):Note {
		if (members == null)
			return null;

		var index:Int = members.indexOf(Object);

		if (index < 0)
			return null;

		if (Splice && __currentlyLooping && i > index)
			i--;

		if (Splice) {
			members.splice(index, 1);
			length--;
		} else {
			members[index] = null;
		}

		if (_memberRemoved != null)
			_memberRemoved.dispatch(Object);

		return Object;
	}
}
