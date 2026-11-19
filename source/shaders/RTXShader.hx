package shaders;

import flixel.math.FlxAngle;
import flixel.util.FlxColor;
import flixel.system.FlxAssets;

class RTXShader extends FlxShader {
	public var overlay(default, set):FlxColor;

	public var satin(default, set):FlxColor;

	public var shadow(default, set):FlxColor;
	public var shadowAngle(default, set):Float;
	public var shadowDistance(default, set):Float;

	public var rotated(default, set):Bool;

	public var baseHue(default, set):Float;

	public var baseSaturation(default, set):Float;

	public var baseBrightness(default, set):Float;

	public var baseContrast(default, set):Float;

	public var colorStroke(default, set):Array<Float>;

	public var stroke(default, set):Bool;
	public var strokeR(default, set):Float;
	public var strokeG(default, set):Float;
	public var strokeB(default, set):Float;
	public var strokeStrength(default, set):Float;

	// Shader by TheZoroForce240
	// Modified by Vortex

	@:glFragmentSource('
		#pragma header


		//https://github.com/jamieowen/glsl-blend !!!!

		float blendOverlay(float base, float blend) {
			return base<0.5?(2.0*base*blend):(1.0-2.0*(1.0-base)*(1.0-blend));
		}

		vec3 blendOverlay(vec3 base, vec3 blend) {
			return vec3(blendOverlay(base.r,blend.r),blendOverlay(base.g,blend.g),blendOverlay(base.b,blend.b));
		}

		vec3 blendOverlay(vec3 base, vec3 blend, float opacity) {
			return (blendOverlay(base, blend) * opacity + base * (1.0 - opacity));
		}

		float blendColorDodge(float base, float blend) {
			return (blend==1.0)?blend:min(base/(1.0-blend),1.0);
		}

		vec3 blendColorDodge(vec3 base, vec3 blend) {
			return vec3(blendColorDodge(base.r,blend.r),blendColorDodge(base.g,blend.g),blendColorDodge(base.b,blend.b));
		}

		vec3 blendColorDodge(vec3 base, vec3 blend, float opacity) {
			return (blendColorDodge(base, blend) * opacity + base * (1.0 - opacity));
		}

		float blendLighten(float base, float blend) {
			return max(blend,base);
		}
		vec3 blendLighten(vec3 base, vec3 blend) {
			return vec3(blendLighten(base.r,blend.r),blendLighten(base.g,blend.g),blendLighten(base.b,blend.b));
		}
		vec3 blendLighten(vec3 base, vec3 blend, float opacity) {
			return (blendLighten(base, blend) * opacity + base * (1.0 - opacity));
		}

		vec3 blendMultiply(vec3 base, vec3 blend) {
			return base*blend;
		}
		vec3 blendMultiply(vec3 base, vec3 blend, float opacity) {
			return (blendMultiply(base, blend) * opacity + base * (1.0 - opacity));
		}

		float inv(float val)
		{
			return (0.0 - val) + 1.0;
		}

		//Shader by TheZoroForce240

		uniform vec3 overlayColor;
		uniform vec3 satinColor; //not proper satin but yea still works
		uniform vec3 innerShadowColor;
		uniform float innerShadowAlpha;
		uniform float innerShadowAngle;
		uniform float innerShadowDistance;

		uniform float overlayAlpha;
		uniform float satinAlpha;

		uniform bool isRotated;

		uniform float hue;
		uniform float saturation;
		uniform float brightness;
		uniform float contrast;

		uniform bool strokeEnabled;
		uniform float strokeRed;
		uniform float strokeGreen;
		uniform float strokeBlue;
		uniform float _strokeStrength;

		float SAMPLEDIST = 5.0;

		#define PI 3.1415926535897932384626433

		// hue rotation based on https://github.com/FunkinCrew/Funkin/blob/main/source/funkin/graphics/shaders/DropShadowShader.hx#L320
		const vec3 grayscaleValues = vec3(0.3098039215686275, 0.607843137254902, 0.0823529411764706);
		const float e = 2.718281828459045;

		vec3 applyHueRotate(vec3 aColor, float aHue){
			float angle = radians(aHue * 360.0);

			mat3 m1 = mat3(0.213, 0.213, 0.213, 0.715, 0.715, 0.715, 0.072, 0.072, 0.072);
			mat3 m2 = mat3(0.787, -0.213, -0.213, -0.715, 0.285, -0.715, -0.072, -0.072, 0.928);
			mat3 m3 = mat3(-0.213, 0.143, -0.787, -0.715, 0.140, 0.715, 0.928, -0.283, 0.072);
			mat3 m = m1 + cos(angle) * m2 + sin(angle) * m3;

			return m * aColor;
		}
		vec3 applySaturation(vec3 aColor, float value){
			if(value > 0.0){ 
				value = value * 3.0; 
			}
			value = (1.0 + (value / 100.0));
			vec3 grayscale = vec3(dot(aColor, grayscaleValues));
        	return clamp(mix(grayscale, aColor, value), 0.0, 1.0);
		}

		vec3 applyContrast(vec3 aColor, float value){
			value = (1.0 + (value / 100.0));
			if(value > 1.0){
				value = (((0.00852259 * pow(e, 4.76454 * (value - 1.0))) * 1.01) - 0.0086078159) * 10.0; //Just roll with it...
				value += 1.0;
			}
       		return clamp((aColor - 0.25) * value + 0.25, 0.0, 1.0);
		}

		vec3 applyHSBCEffect(vec3 color){
			//Brightness
			color += ((brightness) / 255.0);

			//Hue
			color = applyHueRotate(color, hue);

			//Contrast
			color = applyContrast(color, contrast);

			//Saturation
			color = applySaturation(color, saturation);

			return color;
		}
				
		void main()
		{	
			vec2 uv = openfl_TextureCoordv.xy;
			vec4 spritecolor = flixel_texture2D(bitmap, uv);
			if (!strokeEnabled && spritecolor.a <= 0.001) {
				gl_FragColor = vec4(0.0);
				return;
			}
			vec2 resFactor = 1.0 / openfl_TextureSize.xy;

			spritecolor.rgb = applyHSBCEffect(spritecolor.rgb);

			if (satinAlpha > 0.0001) {
				spritecolor.rgb = blendMultiply(spritecolor.rgb, satinColor.rgb, satinAlpha); //apply satin (but no blur)
			}

			if (innerShadowAlpha > 0.0001) {
				//inner shadow
				//offset by pi/2 because thats 90 in radians on the unit circle.
				//sparrow rotated frames are rotated by -90.
				float offsetX = cos(innerShadowAngle + (isRotated ? (PI / 2.0) : 0.0));
				float offsetY = sin(innerShadowAngle + (isRotated ? (PI / 2.0) : 0.0));
				vec2 distMult = (innerShadowDistance*resFactor) / SAMPLEDIST;
				for (float i = 0.0; i < SAMPLEDIST; i++) //sample nearby pixels to see if theyre transparent, multiply blend by inverse alpha to brighten the edge pixels
				{
					vec4 col = texture2D(bitmap, uv + vec2(offsetX * (distMult.x * i), offsetY * (distMult.y * i)));
					spritecolor.rgb = blendColorDodge(spritecolor.rgb, innerShadowColor.rgb, innerShadowAlpha * inv(col.a)); //mult by the inverse alpha so it blends from the outside
				}
			}

			if (overlayAlpha > 0.0001) {
				spritecolor.rgb = blendLighten(spritecolor.rgb, overlayColor.rgb, overlayAlpha); //apply overlay
			}

			if (strokeEnabled && spritecolor.a < 1.0) {
				float step = _strokeStrength;
				float n  = texture2D(bitmap, uv + vec2(0.0, -step) * resFactor).a;
				float s  = texture2D(bitmap, uv + vec2(0.0,  step) * resFactor).a;
				float e  = texture2D(bitmap, uv + vec2( step, 0.0) * resFactor).a;
				float w  = texture2D(bitmap, uv + vec2(-step, 0.0) * resFactor).a;
				float maxA = max(max(n, s), max(e, w));
				
				if (maxA < 1.0) {
					float ne = texture2D(bitmap, uv + vec2( step, -step) * resFactor).a;
					float nw = texture2D(bitmap, uv + vec2(-step, -step) * resFactor).a;
					float se = texture2D(bitmap, uv + vec2( step,  step) * resFactor).a;
					float sw = texture2D(bitmap, uv + vec2(-step,  step) * resFactor).a;
					maxA = max(maxA, max(max(ne, nw), max(se, sw)));
				}

				float isEdge = maxA - spritecolor.a;
				
				if (isEdge > 0.0) {
					spritecolor.rgb = mix(spritecolor.rgb, vec3(strokeRed / 255.0, strokeGreen / 255.0, strokeBlue / 255.0), clamp(isEdge * 10.0, 0.0, 1.0));
					spritecolor.a = max(spritecolor.a, maxA * clamp(isEdge * 10.0, 0.0, 1.0));
				}
			}

			gl_FragColor = spritecolor * spritecolor.a;
		}
    ')
	public function new() {
		super();

		overlay = FlxColor.TRANSPARENT;
		satin = FlxColor.TRANSPARENT;
		shadow = FlxColor.TRANSPARENT;

		baseHue = 0;
		baseSaturation = 0;
		baseBrightness = 0;
		baseContrast = 0;

		stroke = false;
		strokeStrength = 5.0;
		strokeR = 0;
		strokeG = 0;
		strokeB = 0;
	}

	@:noCompletion
	inline function set_overlay(value:FlxColor):FlxColor {
		overlay = value;
		overlayColor.value = [value.redFloat, value.greenFloat, value.blueFloat];
		overlayAlpha.value = [value.alphaFloat];
		return value;
	}

	@:noCompletion
	inline function set_satin(value:FlxColor):FlxColor {
		satin = value;
		satinColor.value = [value.redFloat, value.greenFloat, value.blueFloat];
		satinAlpha.value = [value.alphaFloat];
		return value;
	}

	@:noCompletion
	inline function set_shadow(value:FlxColor):FlxColor {
		shadow = value;
		innerShadowColor.value = [value.redFloat, value.greenFloat, value.blueFloat];
		innerShadowAlpha.value = [value.alphaFloat];
		return value;
	}
	@:noCompletion
	inline function set_shadowAngle(value:Float):Float {
		shadowAngle = value;
		innerShadowAngle.value = [FlxAngle.asRadians(value)];
		return value;
	}

	@:noCompletion
	inline function set_shadowDistance(value:Float):Float {
		shadowDistance = value;
		innerShadowDistance.value = [value];
		return value;
	}

	@:noCompletion
	inline function set_rotated(value:Bool):Bool {
		rotated = value;
		isRotated.value = [value];
		return value;
	}

	@:noCompletion
	inline function set_baseHue(val:Float):Float {
		baseHue = val;
		hue.value = [val];
		return val;
	}

	@:noCompletion
	inline function set_baseSaturation(val:Float):Float {
		baseSaturation = val;
		saturation.value = [val];
		return val;
	}

	@:noCompletion
	inline function set_baseBrightness(val:Float):Float {
		baseBrightness = val;
		brightness.value = [val];
		return val;
	}

	@:noCompletion
	inline function set_baseContrast(val:Float):Float {
		baseContrast = val;
		contrast.value = [val];
		return val;
	}

	@:noCompletion
	inline function set_stroke(v:Bool):Bool {
		stroke = v;
		strokeEnabled.value = [v];
		return v;
	}

	@:noCompletion
	inline function set_colorStroke(v:Array<Float>):Array<Float> {
		colorStroke = v;
		if (v != null && v.length >= 3) {
			strokeR = v[0];
			strokeG = v[1];
			strokeB = v[2];
		}
		return v;
	}

	@:noCompletion
	inline function set_strokeR(v:Float):Float {
		strokeR = v;
		strokeRed.value = [v];
		return v;
	}

	@:noCompletion
	inline function set_strokeG(v:Float):Float {
		strokeG = v;
		strokeGreen.value = [v];
		return v;
	}

	@:noCompletion
	inline function set_strokeB(v:Float):Float {
		strokeB = v;
		strokeBlue.value = [v];
		return v;
	}

	@:noCompletion
	function set_strokeStrength(v:Float):Float {
		_strokeStrength.value = [v];
		return strokeStrength = v;
	}
}