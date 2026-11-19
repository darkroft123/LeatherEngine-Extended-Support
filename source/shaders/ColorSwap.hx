package shaders;

import haxe.extern.EitherType;
import flixel.system.FlxAssets.FlxShader;

/**
 * Stripped down version of https://github.com/FNF-CNE-Devs/YoshiCrafterEngine/blob/main/source/NoteShader.hx
 */
class ColorSwap {
	public var shader(default, null):ColorSwapShader = new ColorSwapShader();

	public var r(default, set):Float = 255;
	public var g(default, set):Float = 0;
	public var b(default, set):Float = 0;

	public var rFlash(default, set):Float = 0;
	public var gFlash(default, set):Float = 0;
	public var bFlash(default, set):Float = 0;
	public var aFlash(default, set):Float = 0;

	public var saturation(default, set):Float = 0;
	public var brightness(default, set):Float = 0;

	public static var colorSwapCache:Map<String, ColorSwap> = new Map();

	private function set_r(value:Float):Float {
		r = value;
		shader.red.value = [r / 255];
		return r;
	}

	private function set_g(value:Float):Float {
		g = value;
		shader.green.value = [g / 255];
		return g;
	}

	private function set_b(value:Float):Float {
		b = value;
		shader.blue.value = [b / 255];
		return b;
	}

	private function set_saturation(value:Float):Float {
		saturation = value;
		shader.saturation.value = [saturation];
		return saturation;
	}

	private function set_brightness(value:Float):Float {
		brightness = value;
		shader.brightness.value = [brightness];
		return brightness;
	}

	private function set_rFlash(value:Float):Float {
		rFlash = value;
		shader.redFlash.value = [rFlash / 255];
		return rFlash;
	}

	private function set_gFlash(value:Float):Float {
		gFlash = value;
		shader.greenFlash.value = [gFlash / 255];
		return gFlash;
	}

	private function set_bFlash(value:Float):Float {
		bFlash = value;
		shader.blueFlash.value = [bFlash / 255];
		return bFlash;
	}

	private function set_aFlash(value:Float):Float {
		aFlash = value;
		shader.alphaFlash.value = [aFlash];
		return aFlash;
	}

	public inline function isIdentity():Bool {
		return r == 255 && g == 0 && b == 0 && saturation == 0 && brightness == 0 && aFlash == 0;
	}

	public function new(?colArray:Array<EitherType<Int, Float>>) {
		colArray ??= [255, 0, 0];

		this.r = colArray[0];
		this.g = colArray[1];
		this.b = colArray[2];

		this.rFlash = 0;
		this.gFlash = 0;
		this.bFlash = 0;
		this.aFlash = 0;

		this.saturation = 0;
		this.brightness = 0;
	}
}

class ColorSwapShader extends FlxShader {
	@:glFragmentSource('
	#pragma header

	uniform float red;
	uniform float green;
	uniform float blue;

	uniform float redFlash;
	uniform float greenFlash;
	uniform float blueFlash;
	uniform float alphaFlash;

	uniform float saturation;
	uniform float brightness;

	vec3 rgb2hsv(vec3 c) {
		vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
		vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
		vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

		float d = q.x - min(q.w, q.y);
		float e = 1.0e-10;
		return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
	}

	vec3 hsv2rgb(vec3 c) {
		vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
		vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
		return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
	}

	void main() {
		vec4 col = flixel_texture2D(bitmap, openfl_TextureCoordv);
		
		vec4 colUnpacked = vec4(col.rgb / (col.a + 0.00001), col.a);

		float avgGB = (colUnpacked.g + colUnpacked.b) * 0.5;
		float diff = colUnpacked.r - avgGB;

		vec4 colFinal = vec4(
			avgGB + (red * diff),
			colUnpacked.g + (green * diff),
			colUnpacked.b + (blue * diff),
			colUnpacked.a
		);

		colFinal.rgb = mix(colFinal.rgb, vec3(redFlash, greenFlash, blueFlash), alphaFlash);

		vec3 hsv = rgb2hsv(colFinal.rgb);
		hsv.y = clamp(hsv.y * (1.0 + saturation), 0.0, 1.0);
		hsv.z = hsv.z * (1.0 + brightness);
		colFinal.rgb = hsv2rgb(hsv);

		gl_FragColor = vec4(colFinal.rgb * colFinal.a, colFinal.a);
	}
	')
	public function new() {
		super();
	}
}