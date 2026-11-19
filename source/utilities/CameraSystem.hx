package utilities;

import flixel.FlxG;
import flixel.FlxObject;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.tweens.misc.NumTween;
import game.Character;
import states.PlayState;
import game.Conductor;

class CameraSystem
{
	public var camBase:FlxPoint = new FlxPoint();
	public var camTweenOffset:FlxPoint = new FlxPoint();
	public var camFollow:FlxObject;
	public static var targetAngle:Float = 0;

	var tween:Dynamic;
	public var customTween:FlxTween;

	public function new() {}

	public function tweenTo(x:Float, y:Float, duration:Float, easeFunc:Float->Float, ?onComplete:Void->Void)
	{
		cancelTween();
		if (customTween != null)
		{
			customTween.cancel();
			customTween = null;
		}

		var startScrollX = FlxG.camera.scroll.x;
		var startScrollY = FlxG.camera.scroll.y;
		var targetScrollX = x + camTweenOffset.x - FlxG.width * 0.5;
		var targetScrollY = y + camTweenOffset.y - FlxG.height * 0.5;

		var options = {
			ease: easeFunc != null ? easeFunc : FlxEase.linear,
			onComplete: function(t:FlxTween) {
				customTween = null;
				FlxG.camera.scroll.x = targetScrollX;
				FlxG.camera.scroll.y = targetScrollY;
				camBase.set(x, y);
				if (camFollow != null) {
					camFollow.setPosition(x, y);
				}
				if (onComplete != null) onComplete();
			}
		};

		var manager = PlayState.instance != null ? PlayState.instance.tweenManager : FlxTween.globalManager;
		customTween = manager.num(0.0, 1.0, duration, options, function(progress:Float) {
			FlxG.camera.scroll.x = startScrollX + (targetScrollX - startScrollX) * progress;
			FlxG.camera.scroll.y = startScrollY + (targetScrollY - startScrollY) * progress;
			camBase.x = FlxG.camera.scroll.x + FlxG.width * 0.5 - camTweenOffset.x;
			camBase.y = FlxG.camera.scroll.y + FlxG.height * 0.5 - camTweenOffset.y;
			if (camFollow != null) {
				camFollow.setPosition(camBase.x, camBase.y);
			}
		});
	}

	public function setTarget(x:Float, y:Float, useTween:Bool, force:Bool = false)
	{
		if (customTween != null && !force)
		{
			camBase.set(x, y);
			return;
		}
		if (customTween != null)
		{
			customTween.cancel();
			customTween = null;
		}
		cancelTween();

		var sx = camBase.x;
		var sy = camBase.y;

		if (camFollow != null && !Std.isOfType(camFollow, LuaCameraFollow))
		{
			camFollow.setPosition(x, y);
		}

		if (force)
		{
			camBase.set(x, y);
			FlxG.camera.scroll.x = camBase.x + camTweenOffset.x - FlxG.width * 0.5;
			FlxG.camera.scroll.y = camBase.y + camTweenOffset.y - FlxG.height * 0.5;
			if (camFollow != null && Std.isOfType(camFollow, LuaCameraFollow))
			{
				var luaFollow:LuaCameraFollow = cast camFollow;
				luaFollow.forceCamActive = true;
				luaFollow.forceFrameCounter = 0;
				luaFollow.setPosition(x, y);
			}
			return;
		}

		if (!useTween)
		{
			camBase.set(x, y);
			return;
		}

		var manager = PlayState.instance != null ? PlayState.instance.tweenManager : FlxTween.globalManager;
		tween = manager.num(0, 1, Conductor.stepCrochet * 0.012, {
			ease: FlxEase.cubeInOut,
			onUpdate: function(t)
			{
				var numT:NumTween = cast t;
				var k = numT != null ? numT.value : FlxEase.cubeInOut(t.percent);
				camBase.x = FlxMath.lerp(sx, x, k);
				camBase.y = FlxMath.lerp(sy, y, k);
			},
			onComplete: function(t)
			{
				camBase.set(x, y);
			}
		});
	}

	public function update(target:Character)
	{
		var forceCamFollow = false;
		if (camFollow != null && Std.isOfType(camFollow, LuaCameraFollow))
		{
			var luaFollow:LuaCameraFollow = cast camFollow;
			if (luaFollow.forceCamActive)
			{
				forceCamFollow = true;
				camBase.set(luaFollow.x, luaFollow.y);
				luaFollow.forceFrameCounter++;
				if (luaFollow.forceFrameCounter > LuaCameraFollow.FORCE_EXPIRE_FRAMES)
				{
					luaFollow.forceCamActive = false;
					luaFollow.forceFrameCounter = 0;
				}
			}
		}

		var dir = FlxPoint.get(0, 0);
		if (!isCentered() && target != null && !forceCamFollow)
			dir = getDirectionOffset(target);

		var targetX:Float;
		var targetY:Float;

		if (isCentered())
		{
			targetX = camBase.x + camTweenOffset.x - FlxG.width * 0.5;
			targetY = camBase.y + camTweenOffset.y - FlxG.height * 0.5;
		}
		else
		{
			if (target == null)
			{
				dir.put();
				return;
			}

			if (forceCamFollow)
			{
				targetX = camBase.x + camTweenOffset.x - FlxG.width * 0.5;
				targetY = camBase.y + camTweenOffset.y - FlxG.height * 0.5;
			}
			else
			{
				targetX = camBase.x + camTweenOffset.x + dir.x - FlxG.width * 0.5;
				targetY = camBase.y + camTweenOffset.y + dir.y - FlxG.height * 0.5;
			}
		}

		dir.put();

		if (customTween == null)
			lerpCamera(targetX, targetY);
		else
			FlxG.camera.angle = FlxMath.lerp(FlxG.camera.angle, targetAngle, FlxMath.bound(FlxG.elapsed * 2.4, 0, 1));
	}

	static inline function isCentered():Bool
	{
		return PlayState.instance != null && PlayState.instance.centerCamera;
	}

	function cancelTween()
	{
		if (tween != null)
		{
			tween.cancel();
			tween = null;
		}
	}

	static function getDirectionOffset(char:Character):FlxPoint
	{
		var mode:Dynamic = Options.getData("cameraTracksDirections");
		
		if (Std.isOfType(mode, Bool)) {
			mode = (mode == true) ? "Normal" : "None";
		}

		if (mode == "None") {
			targetAngle = 0;
			return FlxPoint.get(0, 0);
		}

		var camChar = char.getCameraCharacter();

		var dx:Float = 0;
		var dy:Float = 0;
		targetAngle = 0;

		if (camChar != null && camChar.hasAnims())
		{
			var anim = camChar.curAnimName().toLowerCase();
			
			var offsetSing:Float = (mode == "CNE") ? 30 : 50;
			var tilt:Float = (mode == "CNE") ? 2 : 0;

			switch (anim)
			{
				case "singleft":
					dx = -offsetSing;
					targetAngle = -tilt;
				case "singright":
					dx = offsetSing;
					targetAngle = tilt;
				case "singup":
					dy = -offsetSing;
				case "singdown":
					dy = offsetSing;
			}
		}

		return FlxPoint.get(dx, dy);
	}

	static function lerpCamera(targetX:Float, targetY:Float)
	{
		var speed:Float = (PlayState.instance != null) ? PlayState.instance.cameraSpeed : 1.0;
		var k = FlxMath.bound(FlxG.elapsed * 2.4 * speed, 0, 1);

		FlxG.camera.scroll.x = FlxMath.lerp(FlxG.camera.scroll.x, targetX, k);
		FlxG.camera.scroll.y = FlxMath.lerp(FlxG.camera.scroll.y, targetY, k);
		FlxG.camera.angle = FlxMath.lerp(FlxG.camera.angle, targetAngle, k);
	}
}

class LuaCameraFollow extends FlxObject
{
	public var forceCamActive:Bool = false;
	public var forceFrameCounter:Int = 0;

	public static inline var FORCE_EXPIRE_FRAMES:Int = 5;

	public function new(x:Float, y:Float)
	{
		super(x, y);
	}

	override function set_x(NewX:Float):Float
	{
		forceCamActive = true;
		forceFrameCounter = 0;
		return super.set_x(NewX);
	}

	override function set_y(NewY:Float):Float
	{
		forceCamActive = true;
		forceFrameCounter = 0;
		return super.set_y(NewY);
	}
}
