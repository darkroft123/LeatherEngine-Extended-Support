package game;

import states.PlayState;
import flixel.FlxG;
import lime.utils.Assets;
using StringTools;

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
				if (animation.curAnim.name.startsWith('sing'))
					holdTimer += elapsed * (FlxG.state == PlayState.instance ? PlayState.songMultiplier : 1);
				else
					holdTimer = 0;

				if (animation.curAnim.name.endsWith('miss') && animation.curAnim.finished)
					dance();

				if (animation.curAnim.name == 'firstDeath' && animation.curAnim.finished)
					playAnim('deathLoop');
			}
			else if (atlasMode && atlas != null && atlas.anim != null)
			{
				var curAnim:String = "";
				if (Reflect.hasField(atlas.anim, "curAnimName"))
					curAnim = Reflect.field(atlas.anim, "curAnimName");
				else if (Reflect.hasField(atlas, "curAnimName"))
					curAnim = Reflect.field(atlas, "curAnimName");

				if (curAnim != null && curAnim.startsWith("sing"))
					holdTimer += elapsed * (FlxG.state == PlayState.instance ? PlayState.songMultiplier : 1);
				else
					holdTimer = 0;

				if (atlas.anim.finished && !preventDanceForAnim)
				{
					if (curAnim != null && !curAnim.endsWith("idle") && !curAnim.endsWith("miss"))
						dance();
				}
			}
		}

		super.update(elapsed);
	}
}
