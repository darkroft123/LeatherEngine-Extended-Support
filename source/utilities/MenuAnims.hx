package utilities;

import flixel.FlxSprite;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;

/**
 * Shared, lightweight UI animation helpers for menu states.
 */
class MenuAnims
{
	/**
	 * Framerate-independent exponential smoothing factor for FlxMath.lerp.
	 */
	public static inline function smooth(elapsed:Float, speed:Float = 12.0):Float
	{
		return 1.0 - Math.exp(-speed * elapsed);
	}

	/**
	 * Slides an FlxSprite from (targetX + offsetX, targetY + offsetY) into (targetX, targetY) while fading in.
	 */
	public static function slideFadeIn(
		obj:FlxSprite,
		targetX:Float,
		targetY:Float,
		offsetX:Float = 0,
		offsetY:Float = 0,
		targetAlpha:Float = 1.0,
		duration:Float = 0.36,
		delay:Float = 0,
		?tracker:Array<FlxTween>
	):FlxTween
	{
		if (obj == null)
			return null;

		obj.x = targetX + offsetX;
		obj.y = targetY + offsetY;
		obj.alpha = 0;

		var t = FlxTween.tween(obj, {x: targetX, y: targetY, alpha: targetAlpha}, duration, {
			ease: FlxEase.quartOut,
			startDelay: delay
		});
		if (tracker != null)
			tracker.push(t);
		return t;
	}

	/**
	 * Applies a crisp scale punch/squash-and-stretch to a sprite and settles back to (restX, restY).
	 */
	public static function punchScale(
		obj:FlxSprite,
		peakX:Float = 1.14,
		peakY:Float = 1.14,
		restX:Float = 1.0,
		restY:Float = 1.0,
		duration:Float = 0.22,
		?tracker:Array<FlxTween>
	):FlxTween
	{
		if (obj == null || obj.scale == null)
			return null;

		FlxTween.cancelTweensOf(obj.scale);
		obj.scale.set(peakX, peakY);

		var t = FlxTween.tween(obj.scale, {x: restX, y: restY}, duration, {ease: FlxEase.backOut});
		if (tracker != null)
			tracker.push(t);
		return t;
	}

	/**
	 * Nudges a sprite horizontally (e.g. navigation arrows) with a quick scale pop.
	 */
	public static function nudge(
		obj:FlxSprite,
		baseX:Float,
		offsetX:Float,
		peakScale:Float = 1.25,
		duration:Float = 0.20,
		?tracker:Array<FlxTween>
	):FlxTween
	{
		if (obj == null)
			return null;

		FlxTween.cancelTweensOf(obj);
		obj.x = baseX + offsetX;
		obj.scale.set(peakScale, peakScale);

		var t = FlxTween.tween(obj, {x: baseX, "scale.x": 1.0, "scale.y": 1.0}, duration, {ease: FlxEase.backOut});
		if (tracker != null)
			tracker.push(t);
		return t;
	}

	/**
	 * Cancels and clears all tracked tweens safely.
	 */
	public static function cancelAll(tweens:Array<FlxTween>):Void
	{
		if (tweens == null)
			return;
		for (t in tweens)
		{
			if (t != null)
				t.cancel();
		}
		tweens.resize(0);
	}
}
