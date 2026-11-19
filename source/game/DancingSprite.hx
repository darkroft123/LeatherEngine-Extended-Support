package game;

import flixel.FlxSprite;

class DancingSprite extends FlxSprite {
	var dancingRight:Bool = false;
	var oneDanceAnimation:Bool = false;

	public function new(x:Float, y:Float, ?oneDanceAnimation:Bool = false, ?antialiasing:Bool = true) {
		super(x, y);

		this.antialiasing = antialiasing;
		this.oneDanceAnimation = oneDanceAnimation;
	}

	public function dance(?altAnim:String = ''):Void {
		if (animation == null) return;

		var hasLeft = animation.getByName('danceLeft' + altAnim) != null;
		var hasRight = animation.getByName('danceRight' + altAnim) != null;

		if (!oneDanceAnimation && hasLeft && hasRight) {
			dancingRight = !dancingRight;

			if (dancingRight)
				animation.play('danceRight' + altAnim, true);
			else
				animation.play('danceLeft' + altAnim, true);
		} else if (animation.getByName('idle' + altAnim) != null) {
			animation.play('idle' + altAnim, true);
		} else if (animation.getByName('beatHit' + altAnim) != null) {
			animation.play('beatHit' + altAnim, true);
		} else if (animation.getByName('dance' + altAnim) != null) {
			animation.play('dance' + altAnim, true);
		} else if (animation.curAnim != null) {
			animation.play(animation.curAnim.name, true);
		}
	}
}