package shaders.custom;

import states.PlayState;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import haxe.ds.StringMap;


/**
 * Custom shader with tween support, GL program caching,
 * #import directives, and #pragma header/body expansion.
 *
 * Usage:
 *   - From source: new CustomShader(fragSource, vertSource)
 *   - From file:   CustomShader.fromFile("myShader")
 *   - With imports: use #import <path> in GLSL to inline other shaders
 *   - With pragma:  use #pragma header / #pragma body for Flixel compatibility
 */
class CustomShader extends ShaderBase {
	private var activeTweens:StringMap<FlxTween> = new StringMap();

	/** The file path this shader was loaded from (for debugging) */
	public var filePath:String = "";

	/**
	 * Creates a new CustomShader from GLSL source strings.
	 * Supports #import <path> and #pragma header/body.
	 * @param fragmentSource Fragment GLSL (null = default)
	 * @param vertexSource Vertex GLSL (null = default)
	 * @param glslVer GLSL version (default "120")
	 */
	override public function new(?fragmentSource:String, ?vertexSource:String, ?glslVer:String) {
		super(fragmentSource, vertexSource, glslVer);
	}

	/**
	 * Creates a CustomShader by loading .frag/.vert files from assets/shaders/.
	 * @param name Shader name (path without extension from assets/shaders/)
	 * @param glslVer GLSL version (default "120")
	 * @return The loaded CustomShader, or null on failure
	 */
	public static function fromFile(name:String, ?glslVer:String):CustomShader {
		var fragPath:String = "assets/shaders/" + name + ".frag";
		var vertPath:String = "assets/shaders/" + name + ".vert";

		var fragSource:String = null;
		var vertSource:String = null;

		try {
			if (lime.utils.Assets.exists(fragPath))
				fragSource = lime.utils.Assets.getText(fragPath);
		} catch (e:Dynamic) {
			trace('[CustomShader] Failed to load fragment: ${name}.frag', ERROR);
		}

		try {
			if (lime.utils.Assets.exists(vertPath))
				vertSource = lime.utils.Assets.getText(vertPath);
		} catch (e:Dynamic) {
			trace('[CustomShader] Failed to load vertex: ${name}.vert', ERROR);
		}

		if (fragSource == null && vertSource == null) {
			trace('[CustomShader] Shader "${name}" not found (neither .frag nor .vert)', ERROR);
			return null;
		}

		var shader = new CustomShader(fragSource, vertSource, glslVer);
		shader.filePath = name;
		shader.fragFileName = name + ".frag";
		shader.vertFileName = name + ".vert";
		return shader;
	}

	/**
	 * Tweens a uniform float property.
	 * @param property The uniform name
	 * @param to Target value
	 * @param duration Duration in seconds
	 * @param ease Easing function
	 * @param startDelay Delay before starting
	 * @param onComplete Callback when done
	 */
	public function tween(property:String, to:Float, duration:Float = 1, ease:EaseFunction, ?startDelay:Float = 0.0, ?onComplete:Dynamic) {
		var oldTween = activeTweens.get(property);
		if (oldTween != null) {
			oldTween.cancel();
		}

		var tween = PlayState.instance.tweenManager.num(getFloat(property), to, duration, {
			ease: ease,
			onComplete: (_) -> {
				setFloat(property, to);
				activeTweens.remove(property);
				if (onComplete != null)
					onComplete();
			},
			startDelay: startDelay,
		}, value -> {
			setFloat(property, value);
		});

		activeTweens.set(property, tween);
	}

	/**
	 * Cancels all active tweens on this shader.
	 */
	public function cancelAllTweens():Void {
		for (tween in activeTweens) {
			if (tween != null) tween.cancel();
		}
		activeTweens.clear();
	}

	public function cleanup() {
		cancelAllTweens();
		ShaderBase.decrementActiveShaders();
	}
}
