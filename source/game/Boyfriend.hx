package game;

import lime.utils.Assets;

class Boyfriend extends Character
{
	public var stunned:Bool = false;

	public function new(x:Float, y:Float, ?char:String = 'bf', ?isDeathCharacter:Bool = false, scaleMult:Float = 1.0)
	{
		if (isDeathCharacter && !Assets.exists(Paths.json('character data/$char/config')))
			char = 'bf-dead';

		super(x, y, char, true, isDeathCharacter, scaleMult);
	}

	override function update(elapsed:Float)
	{
		if (!debugMode)
		{
			// Normal
			if (animation.curAnim != null)
			{
				updateHoldTimer(animation.curAnim.name, elapsed);

				if (animation.curAnim.name.endsWith('miss') && animation.curAnim.finished)
					dance();

				if (animation.curAnim.name == 'firstDeath' && animation.curAnim.finished)
					playAnim('deathLoop');
			}
			else if (atlasMode && atlas != null && atlas.anim != null)
			{
				var curAnim:String = (Reflect.hasField(atlas.anim, "curAnimName") ? Reflect.field(atlas.anim, "curAnimName") : (Reflect.hasField(atlas, "curAnimName") ? Reflect.field(atlas, "curAnimName") : ""));
				updateHoldTimer(curAnim, elapsed);
				if (atlas.anim.finished && !preventDanceForAnim && curAnim != null && !curAnim.endsWith("idle") && !curAnim.endsWith("miss"))
					dance();
			}
		}

		super.update(elapsed);
	}
}
