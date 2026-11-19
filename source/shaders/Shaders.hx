package shaders;

import flixel.FlxCamera;
import openfl.display.BitmapData;
import game.Character;
import flixel.math.FlxPoint;
import flixel.FlxSprite;
import flixel.util.FlxColor;
import flixel.math.FlxAngle;
import flixel.FlxG;
import flixel.system.FlxAssets;
import flixel.graphics.frames.FlxFrame;
import flixel.graphics.FlxGraphic;


class Shaders {
	public static function newEffect(?name:String = "3d"):Dynamic {
		switch (name.toLowerCase()) {
			case "3d":
				return new ThreeDEffect();
		}

		return new ThreeDEffect();
	}
}

class ShaderEffect {
	public function update(elapsed:Float) {
		// nothing yet
	}
}

class VortexEffect extends ShaderEffect
{
	public var shader(default,null):VortexShader = new VortexShader();
	public var iTime:Float = 0;
    public var speed:Float = 3;

    public var red:Float = 2.5;
    public var green:Float = 1.0;
    public var blue:Float = 1.5;

	public function new():Void
	{
        shader.uTime.value = [0, 0, 0];
        red = 2.5 * 0.7;
        green = 1.0 * 0.7;
        blue = 1.5 * 0.7;
        shader.spiralColor.value = [red, green, blue];
        update(0);
	}

	override public function update(elapsed:Float):Void
	{
        iTime += elapsed * speed;
		shader.iTime.value = [iTime];
	}

    public var hue(default, set):Float = 0;
	public var saturation(default, set):Float = 0;
	public var brightness(default, set):Float = 0;

	private function set_hue(value:Float) {
		hue = value;
		shader.uTime.value[0] = hue;
		return hue;
	}

	private function set_saturation(value:Float) {
		saturation = value;
		shader.uTime.value[1] = saturation;
		return saturation;
	}

	private function set_brightness(value:Float) {
		brightness = value;
		shader.uTime.value[2] = brightness;
		return brightness;
	}
}

class VortexShader extends FlxShader
{
	@:glFragmentSource('
    #pragma header

    // forked from https://www.shadertoy.com/view/Md3SWH
    
    uniform float iTime;
    uniform vec3 spiralColor;
    const float radius = 20.0;
    const float radiusInv = 0.05;

    uniform vec3 uTime; // colorswap stuff
    vec3 rgb2hsv(vec3 c)
    {
        vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
        vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
        vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

        float d = q.x - min(q.w, q.y);
        float e = 1.0e-10;
        return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
    }

    vec3 hsv2rgb(vec3 c)
    {
        vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
        vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
        return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
    }
    
    // noise funcs: https://gist.github.com/patriciogonzalezvivo/670c22f3966e662d2f83
    float mod289(float x){return x - floor(x * 0.0034602076) * 289.0;}
    vec4 mod289(vec4 x){return x - floor(x * 0.0034602076) * 289.0;}
    vec4 perm(vec4 x){return mod289(((x * 34.0) + 1.0) * x);}
    
    float noise(vec3 p){
        vec3 a = floor(p);
        vec3 d = p - a;
        d = d * d * (3.0 - 2.0 * d);
    
        vec4 b = a.xxyy + vec4(0.0, 1.0, 0.0, 1.0);
        vec4 k1 = perm(b.xyxy);
        vec4 k2 = perm(k1.xyxy + b.zzww);
    
        vec4 c = k2 + a.zzzz;
        vec4 k3 = perm(c);
        vec4 k4 = perm(c + 1.0);
    
        vec4 o1 = fract(k3 * 0.0243902439);
        vec4 o2 = fract(k4 * 0.0243902439);
    
        vec4 o3 = mix(o1, o2, d.z);
        vec2 o4 = mix(o3.xz, o3.yw, d.x);
    
        return mix(o4.x, o4.y, d.y);
    }
    
    float fbm(vec3 pos)
    {
        vec3 q = pos;
        float f = 0.5000 * noise(q); q = q * 2.02;
        f += 0.2500 * noise(q); q = q * 2.03;
        f += 0.1250 * noise(q);
        return f;
    }
    
    float galaxyNoise(vec2 uv, float dist, float angle, float speed)
    {
        float percent = (radius - dist) * radiusInv;
        float theta = iTime * speed + percent * percent * angle;
        float s = sin(theta);
        float c = cos(theta);
        uv = vec2(uv.x * c - uv.y * s, uv.x * s + uv.y * c);
        
        float n = abs(fbm(vec3(uv, iTime) * 0.2) - 0.5) * 2.5;
        float nSmall = smoothstep(0.2, 0.0, n);
        
        float result = (nSmall * 0.6 + n + smoothstep(0.75, 1.0, percent)) * smoothstep(0.2, 0.7, percent);
        return result * result;
    }
    
    vec3 galaxy(vec2 uv)
    {
        float dist = length(uv);
        if (dist >= 16.0) return vec3(0.0);

        float f = galaxyNoise(uv, dist, 9.0, 0.15) * 0.5;
        if (dist < 12.3077) f += galaxyNoise(uv * 1.3, dist * 1.3, 11.0, -0.1) * 0.6;
        if (dist < 10.0) f += galaxyNoise(uv * 1.6, dist * 1.6, 8.0, 0.1) * 0.7;
        f = max(0.0, f);
        
        vec3 color = mix(spiralColor, vec3(0.0), dist * radiusInv);
        return color * f;
    }
    
    void main()
    {
        vec2 uv = (openfl_TextureCoordv.xy - 0.5) * 15.0;
        vec3 col = galaxy(uv);

        if (dot(col, col) > 0.000001 && (abs(uTime.x) + abs(uTime.y) + abs(uTime.z)) > 0.0001) {
            vec3 swagColor = rgb2hsv(col);
            swagColor.x += uTime.x;
            swagColor.y = clamp(swagColor.y + uTime.y, 0.0, 1.0);
            swagColor.z *= (1.0 + uTime.z);
            col = hsv2rgb(swagColor);
        }
        gl_FragColor = vec4(col, 1.0);
    }
    ')
	public function new()
	{
		super();
	}
}

class ThreeDEffect extends ShaderEffect {
	public var shader(default, null):ThreeDShader = new ThreeDShader();

	public var waveSpeed(default, set):Float = 0;
	public var waveFrequency(default, set):Float = 0;
	public var waveAmplitude(default, set):Float = 0;

	public function new():Void {
		shader.uTime.value = [0];
	}

	override public function update(elapsed:Float):Void {
		super.update(elapsed);

		shader.uTime.value[0] += elapsed;
	}

	function set_waveSpeed(v:Float):Float {
		waveSpeed = v;
		shader.uSpeed.value = [waveSpeed];
		return v;
	}

	function set_waveFrequency(v:Float):Float {
		waveFrequency = v;
		shader.uFrequency.value = [waveFrequency];
		return v;
	}

	function set_waveAmplitude(v:Float):Float {
		waveAmplitude = v;
		shader.uWaveAmplitude.value = [waveAmplitude];
		return v;
	}
}
class Galaxyffect extends ShaderEffect {
     public var shader(default, null):GalaxyShader = new GalaxyShader();

	public var time(default, set):Float = 0;
    public var strength:Float = 1;   
  
   private function set_time(value:Float) {
		time = value;
		shader.iTime.value = [time];
		return time;
	}


	public function new() {
		shader.iTime.value = [0];
        shader.strength.value = [strength];
	}

    	override public function update(elapsed:Float):Void
	{
	
		shader.strength.value[0] = strength;
        
	}

}

class GalaxyShader extends FlxShader {
	@:glFragmentSource('#pragma header

#define iResolution vec3(openfl_TextureSize, 0.)
#define iChannel0 bitmap
#define texture flixel_texture2D

uniform int iFrame;
uniform float strength;
uniform float iTime;

float Noise2d(vec2 x)
{
    float xhash = cos(x.x * 37.0);
    float yhash = cos(x.y * 57.0);
    return fract(415.92653 * (xhash + yhash));
}

float NoisyStarField(vec2 vSamplePos, float fThreshhold)
{
    float StarVal = Noise2d(vSamplePos);
    if (StarVal >= fThreshhold)
        StarVal = pow((StarVal - fThreshhold) / (1.0 - fThreshhold), 6.0);
    else
        StarVal = 0.0;
    return StarVal;
}

float StableStarField(vec2 vSamplePos, float fThreshhold)
{
    float fractX = fract(vSamplePos.x);
    float fractY = fract(vSamplePos.y);
    vec2 floorSample = floor(vSamplePos);    
    float v1 = NoisyStarField(floorSample, fThreshhold);
    float v2 = NoisyStarField(floorSample + vec2(0.0, 1.0), fThreshhold);
    float v3 = NoisyStarField(floorSample + vec2(1.0, 0.0), fThreshhold);
    float v4 = NoisyStarField(floorSample + vec2(1.0, 1.0), fThreshhold);

    float StarVal =
          v1 * (1.0 - fractX) * (1.0 - fractY)
        + v2 * (1.0 - fractX) * fractY
        + v3 * fractX * (1.0 - fractY)
        + v4 * fractX * fractY;

    return StarVal;
}

vec4 starShader(vec2 fragCoord)
{
    vec3 vColor = vec3(0.1, 0.4, 0.2) * fragCoord.y / iResolution.y;

    float StarFieldThreshhold = 0.97;
    float t = floor(iTime * 150.0);
    vec2 vSamplePos = fragCoord + vec2(0.2 * t, -0.06 * t);
    float StarVal = StableStarField(vSamplePos, StarFieldThreshhold);
    vColor += vec3(StarVal);

    return vec4(vColor, 1.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec4 base = texture(iChannel0, fragCoord / iResolution.xy);

    vec2 uvStars = fragCoord;
    uvStars.y = iResolution.y - uvStars.y;

    vec4 stars = starShader(uvStars);

    fragColor = mix(base, stars, strength);
    fragColor.a = base.a;
}

void main()
{
    mainImage(gl_FragColor, openfl_TextureCoordv * openfl_TextureSize);
}')
	public function new() {
		super();
	}
    
}


/**
 * Class for 3d Shader.
 * This will be softcoded in a .frag file one day.
 */
class ThreeDShader extends FlxShader {
	@:glFragmentSource('
    #pragma header
    //uniform float tx, ty; // x,y waves phase

    //modified version of the wave shader to create weird garbled corruption like messes
    uniform float uTime;
    
    /**
     * How fast the waves move over time
     */
    uniform float uSpeed;
    
    /**
     * Number of waves over time
     */
    uniform float uFrequency;
    
    /**
     * How much the pixels are going to stretch over the waves
     */
    uniform float uWaveAmplitude;

    vec2 sineWave(vec2 pt)
    {
        float x = 0.0;
        float y = 0.0;
        
        float offsetX = sin(pt.y * uFrequency + uTime * uSpeed) * (uWaveAmplitude / pt.x * pt.y);
        float offsetY = sin(pt.x * uFrequency - uTime * uSpeed) * (uWaveAmplitude / pt.y * pt.x);
        pt.x += offsetX; // * (pt.y - 1.0); // <- Uncomment to stop bottom part of the screen from moving
        pt.y += offsetY;

        return vec2(pt.x + x, pt.y + y);
    }

    void main()
    {
        vec2 uv = sineWave(openfl_TextureCoordv);
        gl_FragColor = texture2D(bitmap, uv);
    }')
	public function new() {
		super();
	}
}

class GreyscaleEffect extends ShaderEffect
{
    public var shader(default,null):GreyscaleShader = new GreyscaleShader();

    public var strength(get, set):Float;
    public var radius(get, set):Float;
    public var smoothness(get, set):Float;
    public var borderSize(get, set):Float;
    public var bordersEnabled(get, set):Bool;
    public var enter(get, set):Float;
    public var iTime(get, set):Float;

    var _strength:Float = 0.0;
    var _radius:Float = 0.0;
    var _smoothness:Float = 0.0;
    var _borderSize:Float = 0.0;
    var _bordersEnabled:Bool = false;
    var _enter:Float = 0.0;
    var _iTime:Float = 0.0;

    function get_strength() return _strength;
    function set_strength(v:Float) { _strength = v; pushStrength(); return v; }
    function get_radius() return _radius;
    function set_radius(v:Float) { _radius = v; pushRadius(); return v; }
    function get_smoothness() return _smoothness;
    function set_smoothness(v:Float) { _smoothness = v; pushSmoothness(); return v; }
    function get_borderSize() return _borderSize;
    function set_borderSize(v:Float) { _borderSize = v; pushBorderSize(); return v; }
    function get_bordersEnabled() return _bordersEnabled;
    function set_bordersEnabled(v:Bool) { _bordersEnabled = v; pushBordersEnabled(); return v; }
    function get_enter() return _enter;
    function set_enter(v:Float) { _enter = v; pushEnter(); return v; }
    function get_iTime() return _iTime;
    function set_iTime(v:Float) { _iTime = v; pushITime(); return v; }

    inline function pushStrength() { if (shader.strength.value == null) shader.strength.value = [_strength]; else shader.strength.value[0] = _strength; }
    inline function pushRadius() { if (shader.radius.value == null) shader.radius.value = [_radius]; else shader.radius.value[0] = _radius; }
    inline function pushSmoothness() { if (shader.smoothness.value == null) shader.smoothness.value = [_smoothness]; else shader.smoothness.value[0] = _smoothness; }
    inline function pushBorderSize() { if (shader.borderSize.value == null) shader.borderSize.value = [_borderSize]; else shader.borderSize.value[0] = _borderSize; }
    inline function pushBordersEnabled() { if (shader.bordersEnabled.value == null) shader.bordersEnabled.value = [_bordersEnabled ? 1.0 : 0.0]; else shader.bordersEnabled.value[0] = _bordersEnabled ? 1.0 : 0.0; }
    inline function pushEnter() { if (shader.enter.value == null) shader.enter.value = [_enter]; else shader.enter.value[0] = _enter; }
    inline function pushITime() { if (shader.iTime.value == null) shader.iTime.value = [_iTime]; else shader.iTime.value[0] = _iTime; }

    public function new():Void
    {
        pushStrength();
        pushRadius();
        pushSmoothness();
        pushBorderSize();
        pushBordersEnabled();
        pushEnter();
        pushITime();
    }

    override public function update(elapsed:Float):Void
    {
        _iTime += elapsed;
        pushITime();
    }
}
class GreyscaleShader extends FlxShader
{
    @:glFragmentSource('
        #pragma header

        #define iResolution vec3(openfl_TextureSize, 0.)
        #define iChannel0 bitmap
        #define texture flixel_texture2D

        uniform float radius;
        uniform float smoothness;
        uniform float strength;
        uniform float borderSize;
        uniform float bordersEnabled;
        uniform float enter;
        uniform float iTime;

        float sdRoundRect(vec2 p, vec2 b, float r){
            vec2 q = abs(p) - b + vec2(r);
            return length(max(q, vec2(0.0))) - r + min(max(q.x, q.y), 0.0);
        }

        void mainImage(out vec4 fragColor, in vec2 fragCoord){
            vec2 uv = openfl_TextureCoordv;
            vec2 centered = uv - 0.5;
            vec2 halfSize = vec2(0.5);
            float dist = sdRoundRect(centered, halfSize, radius);
            float mask = 1.0 - smoothstep(0.0, smoothness, dist);

            float outerW = borderSize * 1.8;
            float innerW = outerW - 0.015;
            float borderOuter = 1.0 - smoothstep(outerW, outerW + 0.002, abs(dist));
            float borderInner = 1.0 - smoothstep(innerW, innerW + 0.002, abs(dist));
            float whiteBorder = clamp(borderOuter - borderInner, 0.0, 1.0) * mask * bordersEnabled;

            float blackW1 = outerW + 0.01;
            float blackOuter1 = 1.0 - smoothstep(blackW1, blackW1 + 0.002, abs(dist));
            float blackInner1 = 1.0 - smoothstep(outerW, outerW + 0.002, abs(dist));
            float blackBorder1 = clamp(blackOuter1 - blackInner1, 0.0, 1.0) * mask * bordersEnabled;

            float blackW2 = innerW - 0.008;
            float blackOuter2 = 1.0 - smoothstep(innerW, innerW + 0.002, abs(dist));
            float blackInner2 = 1.0 - smoothstep(blackW2, blackW2 + 0.002, abs(dist));
            float blackBorder2 = clamp(blackOuter2 - blackInner2, 0.0, 1.0) * mask * bordersEnabled;
vec4 col = texture(iChannel0, uv);
            float gray = dot(col.rgb, vec3(0.299, 0.587, 0.114));
            vec3 colGray = vec3(gray);
            vec3 finalColor = mix(col.rgb, colGray, strength);

            float flip = enter * (sin(iTime * 10.0) * 0.5 + 0.5);
            float activeGlow = (1.0 - clamp(strength, 0.0, 1.0)) * bordersEnabled;
            float sweep = 0.5 + 0.5 * sin((uv.x * 4.0 + uv.y * 3.0) - iTime * 2.5);
            vec3 shimmer = mix(vec3(0.65, 0.95, 1.0), vec3(1.0), sweep);
            vec3 whiteC = mix(vec3(1.0), shimmer, activeGlow * 0.7);
            whiteC = mix(whiteC, vec3(0.0), flip);
            vec3 blackC = mix(vec3(0.0), vec3(1.0), flip);

            finalColor += vec3(0.22) * flip;
            finalColor = mix(finalColor, whiteC, whiteBorder);
            finalColor = mix(finalColor, blackC, blackBorder1);
            finalColor = mix(finalColor, blackC, blackBorder2);

            float outAlpha = col.a * mask;
            fragColor = vec4(finalColor * outAlpha, outAlpha);
        }

        void main(){
            mainImage(gl_FragColor, gl_FragCoord.xy);
        }
    ')
    public function new()
    {
        super();
    }
}

class ChesslolEffect extends ShaderEffect {
	public var shader(default, null):ChesslolShader = new ChesslolShader();

	public var time(default, set):Float = 0;

	private function set_time(value:Float) {
		time = value;
		shader.iTime.value = [time];
		return time;
	}

	public function new() {
		shader.iTime.value = [0];
	}
}


class ChesslolShader extends FlxShader {
	@:glFragmentSource('
    #pragma header

    #define iResolution vec3(openfl_TextureSize, 0.)
    uniform float iTime;
    #define iChannel0 bitmap
    #define texture flixel_texture2D

    // end of ShadertoyToFlixel header

    void mainImage( out vec4 fragColor, in vec2 fragCoord )
    {
        float aspect_ratio = iResolution.y/iResolution.x;
        vec2 uv = fragCoord.xy / iResolution.x;
        uv -= vec2(0.45, 0.4 * aspect_ratio);
        float rot = radians(-30. -iTime);
        mat2 rotation_matrix = mat2(cos(rot), -sin(rot), sin(rot), cos(rot));
        uv = rotation_matrix * uv;
        vec2 scaled_uv = 12.0 * uv; 
        vec2 tile = fract(scaled_uv);
        float tile_dist = min(min(tile.x, 1.0-tile.x), min(tile.y, 1.0-tile.y));
        float square_dist = length(floor(scaled_uv));
        
        float edge = sin(iTime-square_dist*20.);
        edge = mod(edge * edge, 11.0); 



        float value = mix(tile_dist, 1.0-tile_dist, step(1.0, edge));
        edge = pow(abs(1.0-edge), 2.2) * 0.5;
        
        value = smoothstep( edge-0.05, edge, 0.95*value);
        
        
        value += square_dist*.1;
        value *= 1.5 - 0.5;
        
        vec3 col = vec3(pow(value, 2.), pow(value, 1.5), pow(value, 1.2));
        col *= 0.25;
        fragColor = vec4(col, texture(iChannel0, fragCoord / iResolution.xy).a);

    }

    void main() {
        mainImage(gl_FragColor, openfl_TextureCoordv*openfl_TextureSize);
    }')
	public function new() {
		super();
	}
}

class CutBitmapEffect extends ShaderEffect {
    public var shader(default,null):CutBitmapShader = new CutBitmapShader();

    public var side(default,set):Float = 1.0;
    public var topX(default,set):Float = 1.0;
    public var bottomX(default,set):Float = 1.0;
    public var borderWidth(default,set):Float = 1.0;

    public var time(default,set):Float = 0.0;
    public var hue(default,set):Float = 0.0;
    public var brightness(default,set):Float = 1.0;
    public var contrast(default,set):Float = 1.0;

    public var strength(default,set):Float = 0.0;
    public var strengthChrom(default,set):Float = 0.0;

    private function set_time(value:Float):Float {
        time = value;
        shader.iTime.value[0] = time;
        return time;
    }

    private function set_hue(value:Float):Float {
        hue = value;
        shader.hue.value[0] = hue;
        return hue;
    }

    private function set_brightness(value:Float):Float {
        brightness = value;
        shader.brightness.value[0] = brightness;
        return brightness;
    }

    private function set_contrast(value:Float):Float {
        contrast = value;
        shader.contrast.value[0] = contrast;
        return contrast;
    }

    private function set_side(value:Float):Float {
        side = value;
        shader.side.value[0] = side;
        return side;
    }

    private function set_topX(value:Float):Float {
        topX = value;
        shader.topX.value[0] = topX;
        return topX;
    }

    private function set_bottomX(value:Float):Float {
        bottomX = value;
        shader.bottomX.value[0] = bottomX;
        return bottomX;
    }

    private function set_borderWidth(value:Float):Float {
        borderWidth = value;
        shader.borderWidth.value[0] = borderWidth;
        return borderWidth;
    }

    private function set_strength(value:Float):Float {
        strength = value;
        shader.strength.value[0] = strength;
        return strength;
    }

    private function set_strengthChrom(value:Float):Float {
        strengthChrom = value;
        shader.strengthChrom.value[0] = strengthChrom;
        return strengthChrom;
    }

    override public function update(elapsed:Float):Void {
        time += elapsed;
        shader.iTime.value[0] = time;
    }

    public function new() {
        shader.side.value = [0];
        shader.topX.value = [0];
        shader.bottomX.value = [1];
        shader.borderWidth.value = [2];
        shader.iTime.value = [0];
        shader.hue.value = [0];
        shader.brightness.value = [1];
        shader.contrast.value = [1];
        shader.strength.value = [0];
        shader.strengthChrom.value = [0];
    }
}




class CutBitmapShader extends FlxShader {
	@:glFragmentSource('
      #pragma header

#define iResolution vec3(openfl_TextureSize, 0.)
#define iChannel0 bitmap
#define texture flixel_texture2D

uniform float side;
uniform float topX;
uniform float bottomX;
uniform float borderWidth;

uniform float iTime;
uniform float brightness;
uniform float contrast;
uniform float hue;

uniform float strength;

uniform float strengthChrom;

float hash2(vec2 p)
{
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float hash3(vec2 p, float t)
{
    return fract(sin(dot(p, vec2(269.5, 183.3)) + t * 17.13) * 43758.5453);
}

vec2 mask_coord(vec2 coord, int shift)
{
    float m = exp2(float(shift));
    return floor(coord / m) * m;
}

float get_sample(vec2 coord, int shift)
{
    coord = mask_coord(coord, shift);
    vec2 uv = coord / iResolution.xy;
    uv.y = 1.0 - uv.y;
    float offset = 1.2 * (uv.x + uv.y - 1.0);
    float hxy = hash2(coord);
    float tf = 13.0 * iTime / (6.0 * abs(uv.y - uv.x) + 1.8) + hxy;
    float h1 = hash3(coord, floor(tf));
    float c = 1.2 * h1 + offset;
    return (c - 0.5) * 2.5 / (1.5 + float(shift)) + 0.5;
}

float get_sample_t(vec2 coord, float time)
{
    int shift = 0;
    for (int s = 10; s >= 0; s--) {
        vec2 xy = mask_coord(coord, s) / iResolution.xy;
        xy.y = 1.0 - xy.y;
        if (s < int(6.0 * abs(xy.y - xy.x) + 1.0 + hash3(xy, time))) {
            shift = s;
            break;
        }
    }
    return (get_sample(coord, shift) + get_sample(coord, shift + 1)) * 0.4;
}

vec3 hueToRGB(float h)
{
    float r = abs(h * 6.0 - 3.0) - 1.0;
    float g = 2.0 - abs(h * 6.0 - 2.0);
    float b = 2.0 - abs(h * 6.0 - 4.0);
    return clamp(vec3(r, g, b), 0.0, 1.0);
}

vec4 specialShader(vec2 fragCoord)
{
    float tf = 0.3 * iTime;
    float c = mix(
        get_sample_t(fragCoord, floor(tf)),
        get_sample_t(fragCoord, floor(tf) + 1.0),
        tf - floor(tf)
    );
    vec3 col = hueToRGB(hue) * (c * brightness);
    col *= contrast;
    col += vec3(brightness * 0.1);
    return vec4(col, 1.0);
}

vec2 barDistFlat(vec2 uv, vec2 pos, float angleRad, float barLen)
{
    vec2 dir = vec2(cos(angleRad), sin(angleRad));
    vec2 pa = uv - pos;
    float t = clamp(dot(pa, dir) / barLen, 0.0, 1.0);
    float d = length(pa - dir * (t * barLen)) * iResolution.x;
    return vec2(d, t);
}

vec2 PincushionDistortion(vec2 uv, float strengthArg)
{
    vec2 st = uv - 0.5;
    float uvD = dot(st, st);
    float uvA = atan(st.x, st.y);
    return 0.5 + vec2(sin(uvA), cos(uvA)) * sqrt(uvD) * (1.0 - strengthArg * uvD);
}

vec3 ChromaticAbberationFull(vec3 col, vec2 uv)
{
    vec3 c;
    c.r = texture(iChannel0, vec2(uv.x + strengthChrom, uv.y)).r;
    c.g = texture(iChannel0, vec2(uv.x - strengthChrom, uv.y)).g;
    c.b = col.b;
    return mix(col, c, strengthChrom);
}

vec4 grayscaleBitmap(vec2 uv)
{
    vec4 c = texture(iChannel0, uv);
    float grey = dot(c.rgb, vec3(0.299, 0.587, 0.114));
    return mix(c, vec4(grey, grey, grey, c.a), strength);
}

void main() {
    vec2 uv = openfl_TextureCoordv.xy;

    vec2 p1 = vec2(topX, 0.0);
    vec2 p2 = vec2(bottomX, 1.0);

    float d = (uv.x - p1.x) * (p2.y - p1.y) - (uv.y - p1.y) * (p2.x - p1.x);
    bool cutSide = side > 0.5 ? (d > 0.0) : (d < 0.0);

    vec2 pa = uv - p1;
    vec2 ba = p2 - p1;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    float dist = length(pa - ba * h) * iResolution.x;

    float bwOuter = borderWidth;
    float bwMiddle = borderWidth * 0.66;
    float bwInner = borderWidth * 0.33;

    vec4 col;

    if (cutSide)
        col = specialShader(openfl_TextureCoordv * openfl_TextureSize);
    else if (dist < bwInner)
        col = vec4(0.0, 0.0, 0.0, 1.0);
    else if (dist < bwMiddle)
        col = vec4(1.0, 1.0, 1.0, 1.0);
    else if (dist < bwOuter)
        col = vec4(0.0, 0.0, 0.0, 1.0);
    else {
        vec4 tex = grayscaleBitmap(uv);

        if (uv.y < 0.08) {
            col = vec4(0.0, 0.0, 0.0, 1.0);
        }
        else if (uv.y > 0.08 && uv.y < 0.1659 && uv.x > 0.108 && uv.x < 0.314) {
            col = vec4(0.0, 0.0, 0.0, 1.0);
        }
        else if (uv.x > 0.0787 && uv.x < 0.108) {
            float yMax = 0.08 + (uv.x - 0.0787) * tan(radians(70.0));
            if (uv.y > 0.08 && uv.y < yMax) {
                col = vec4(0.0, 0.0, 0.0, 1.0);
            } else {
                col = tex;
            }
        }
        else if (uv.x > 0.314 && uv.x < 0.344095) {
            float yMax = 0.1659 - (uv.x - 0.314) * tan(radians(70.0));
            if (uv.y > 0.08 && uv.y < yMax) {
                col = vec4(0.0, 0.0, 0.0, 1.0);
            } else {
                col = tex;
            }
        }
        else {
            col = tex;
        }
    }

    vec4 specialCol = cutSide ? specialShader(openfl_TextureCoordv * openfl_TextureSize) : col;

    if (cutSide && uv.x > 0.44 && uv.x < 1.0 && uv.y > 0.0 && uv.y < 0.17) {
        specialCol = vec4(0.0, 0.0, 0.0, 1.0);
    }

    if (cutSide && uv.x > 0.965 && uv.x < 1.0 && uv.y > 0.4 && uv.y < 0.8) {
        specialCol = vec4(0.0, 0.0, 0.0, 1.0);
    }
 

    col = specialCol;

    vec2 d1 = barDistFlat(uv, vec2(0.0, 0.08), radians(0.0), 0.08);
    vec2 d2 = barDistFlat(uv, vec2(0.0787, 0.082), radians(70.0), 0.09);
    vec2 d3 = barDistFlat(uv, vec2(0.344095, 0.08), radians(0.0), 0.1077);
    vec2 d4 = barDistFlat(uv, vec2(0.314, 0.1659), radians(-70.0), 0.09);
    vec2 d5 = barDistFlat(uv, vec2(0.108, 0.161), radians(0.0), 0.208);
    vec2 d6 = barDistFlat(uv, vec2(0.4643, 0.170), radians(0.0), 0.62);
    vec2 d7 = barDistFlat(uv, vec2(0.966, 0.4), radians(0.0), 0.04);
    vec2 d8 = barDistFlat(uv, vec2(0.966, 0.8), radians(0.0), 0.04);
    vec2 d9 = barDistFlat(uv, vec2(0.967, 0.402), radians(90.0), 0.395);
    vec2 d10 = barDistFlat(uv, vec2(0.459, 0.125), radians(0.0), 0.55);
    vec2 d11 = barDistFlat(uv, vec2(0.4679, 0.21), radians(0.0), 0.15);
    vec2 d12 = barDistFlat(uv, vec2(0.481, 0.35), radians(0.0), 0.0995);
    vec2 d13 = barDistFlat(uv, vec2(0.616, 0.213), radians(105.0), 0.1403);

    float factor1 = 1.0;
    float factor2 = 0.5;
    float factor3 = 1.0;
    float factor4 = 0.5;
    float factor5 = 1.0;
    float factor6 = 1.0;
    float factor7 = 1.0;
    float factor8 = 1.0;
    float factor9 = 0.5;
    float factor10 = 0.5;
    float factor11 = 0.75;
    float factor12 = 0.75;
    float factor13 = 0.35;

    if(cutSide){

    vec2 A = vec2(0.4679, 0.21);
    vec2 B = vec2(0.481, 0.35);
    vec2 C = vec2(0.616, 0.213);
    vec2 D = vec2(0.58, 0.35);

    vec2 v0 = C - A;
    vec2 v1 = B - A;
    vec2 v2 = uv - A;

    float dot00 = dot(v0,v0);
    float dot01 = dot(v0,v1);
    float dot02 = dot(v0,v2);
    float dot11 = dot(v1,v1);
    float dot12 = dot(v1,v2);

    float invDen = 1.0/(dot00*dot11-dot01*dot01);
    float u = (dot11*dot02-dot01*dot12)*invDen;
    float v = (dot00*dot12-dot01*dot02)*invDen;

    bool tri1 = (u>=0.0 && v>=0.0 && (u+v)<=1.0);

    v0 = D - B;
    v1 = C - B;
    v2 = uv - B;

    dot00 = dot(v0,v0);
    dot01 = dot(v0,v1);
    dot02 = dot(v0,v2);
    dot11 = dot(v1,v1);
    dot12 = dot(v1,v2);

    invDen = 1.0/(dot00*dot11-dot01*dot01);
    u = (dot11*dot02-dot01*dot12)*invDen;
    v = (dot00*dot12-dot01*dot02)*invDen;

    bool tri2 = (u>=0.0 && v>=0.0 && (u+v)<=1.0);

    if(tri1 || tri2){
        col = vec4(0.0,0.0,0.0,1.0);
    }
}

    if (d2.x < bwOuter * factor2 && d2.y > 0.0 && d2.y < 1.0) {
        if (d2.x < bwInner * factor2) col = vec4(1.0);
        else col = vec4(0.0, 0.0, 0.0, 1.0);
    }

    if (d4.x < bwOuter * factor4 && d4.y > 0.0 && d4.y < 1.0) {
        if (d4.x < bwInner * factor4) col = vec4(1.0);
        else col = vec4(0.0, 0.0, 0.0, 1.0);
    }

    if (d1.x < bwOuter * factor1 && d1.y > 0.0 && d1.y < 1.0) {
        if (d1.x < bwInner * factor1) col = vec4(1.0);
        else col = vec4(0.0, 0.0, 0.0, 1.0);
    }

    if (d3.x < bwOuter * factor3 && d3.y > 0.0 && d3.y < 1.0) {
        if (d3.x < bwInner * factor3) col = vec4(1.0);
        else col = vec4(0.0, 0.0, 0.0, 1.0);
    }

    if (d5.x < bwOuter * factor5 && d5.y > 0.0 && d5.y < 1.0) {
        if (d5.x < bwInner * factor5) col = vec4(1.0);
        else col = vec4(0.0, 0.0, 0.0, 1.0);
    }

    if (d6.x < bwOuter * factor6 && d6.y > 0.0 && d6.y < 1.0) {
        if (d6.x < bwInner * factor6) col = vec4(1.0);
        else col = vec4(0.0, 0.0, 0.0, 1.0);
    }

    if (d7.x < bwOuter * factor7 && d7.y > 0.0 && d7.y < 1.0) {
        if (d7.x < bwInner * factor7) col = vec4(1.0);
        else col = vec4(0.0,0.0,0.0,1.0);
    }

    if (d8.x < bwOuter * factor8 && d8.y > 0.0 && d8.y < 1.0) {
        if (d8.x < bwInner * factor8) col = vec4(1.0);
        else col = vec4(0.0,0.0,0.0,1.0);
    }

    if (d9.x < bwOuter * factor9 && d9.y > 0.0 && d9.y < 1.0) {
        if (d9.x < bwInner * factor9) col = vec4(1.0);
        else col = vec4(0.0,0.0,0.0,1.0);
    }
    
    if (d10.x < bwOuter * factor10 && d10.y > 0.0 && d10.y < 1.0) {
        if (d10.x < bwInner * factor10) col = vec4(1.0);
        else col = vec4(0.0,0.0,0.0,1.0);
    }

    if (d11.x < bwOuter * factor11 && d11.y > 0.0 && d11.y < 1.0) {
        if (d11.x < bwInner * factor11) col = vec4(1.0);
        else col = vec4(0.0,0.0,0.0,1.0);
    }

    if (d12.x < bwOuter * factor12 && d12.y > 0.0 && d12.y < 1.0) {
        if (d12.x < bwInner * factor12) col = vec4(1.0);
        else col = vec4(0.0,0.0,0.0,1.0);
    }
    if (d13.x < bwOuter * factor13 && d13.y > 0.0 && d13.y < 1.0) {
        if (d13.x < bwInner * factor13) col = vec4(1.0);
        else col = vec4(0.0,0.0,0.0,1.0);
    }
    
    col.rgb = ChromaticAbberationFull(col.rgb, uv);
    gl_FragColor = col;
}')
	public function new() {
		super();
	}
}


class CosmicMenuEffect extends ShaderEffect {
    public var shader(default,null):CosmicMenuShader = new CosmicMenuShader();

    public var side(default,set):Float = 0;
    public var topX(default,set):Float = 0.65;
    public var bottomX(default,set):Float = 0.55;
    public var borderWidth(default,set):Float = 10.0;
    public var hue(default,set):Float = 0.0;
    public var time(default,set):Float = 0.0;

    public var strength(default,set):Float = 1.0;
    public var zoom(default,set):Float = 0.5;

    private function set_time(value:Float):Float {
        time = value;
        shader.iTime.value[0] = time;
        return time;
    }

    private function set_side(value:Float):Float {
        side = value;
        shader.side.value[0] = side;
        return side;
    }

    private function set_topX(value:Float):Float {
        topX = value;
        shader.topX.value[0] = topX;
        return topX;
    }

    private function set_bottomX(value:Float):Float {
        bottomX = value;
        shader.bottomX.value[0] = bottomX;
        return bottomX;
    }

    private function set_borderWidth(value:Float):Float {
        borderWidth = value;
        shader.borderWidth.value[0] = borderWidth;
        return borderWidth;
    }

    private function set_strength(value:Float):Float {
        strength = value;
        shader.strength.value[0] = strength;
        return strength;
    }

    private function set_zoom(value:Float):Float {
        zoom = value;
        shader.zoom.value[0] = zoom;
        return zoom;
    }
      private function set_hue(value:Float):Float {
        hue = value;
        shader.hue.value[0] = hue;
        return hue;
    }
    override public function update(elapsed:Float):Void {
        time += elapsed;
        shader.iTime.value[0] = time;
    }

    public function new() {
        shader.side.value = [0];
        shader.topX.value = [0.65];
        shader.bottomX.value = [0.55];
        shader.borderWidth.value = [10];
        shader.iTime.value = [0];
        shader.strength.value = [1];
        shader.zoom.value = [0.5];
        shader.hue.value = [0];
    }
}




class CosmicMenuShader extends FlxShader {
	@:glFragmentSource('
      #pragma header

#define iResolution vec3(openfl_TextureSize, 0.)
#define iChannel0 bitmap
#define texture flixel_texture2D

uniform float side;
uniform float topX;
uniform float bottomX;
uniform float borderWidth;

uniform float iTime;
uniform float strength;
uniform float zoom;
uniform float hue;

vec2 r(vec2 v,float t){float s=sin(t),c=cos(t);return mat2(c,-s,s,c)*v;}

vec3 a(vec3 c)
{
    mat3 m1=mat3(0.59719,0.07600,0.02840,0.35458,0.90834,0.13383,0.04823,0.01566,0.83777);
    mat3 m2=mat3(1.60475,-0.10208,-0.00327,-0.53108,1.10813,-0.07276,-0.07367,-0.00605,1.07602);
    vec3 v=m1*c, a=v*(v+0.0245786)-0.000090537, b=v*(0.983729*v+0.4329510)+0.238081;
    return m2*(a/b);
}

float n(vec3 p)
{
    const float PHI = 1.618033988;
    const mat3 GOLD = mat3(
        -0.571464913, +0.814921382, +0.096597072,
        -0.278044873, -0.303026659, +0.911518454,
        +0.772087367, +0.494042493, +0.399753815);
    return dot(cos(GOLD * p), sin(PHI * p * GOLD));
}

vec3 hueShift(vec3 c, float h)
{
    const vec3 k = vec3(0.57735);
    float cosA = cos(h * 6.2831853);
    float sinA = sin(h * 6.2831853);
    return c * cosA + cross(k, c) * sinA + k * dot(k, c) * (1.0 - cosA);
}

vec4 specialShader(vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;
    vec2 uvCentered = (fragCoord - 0.5*iResolution.xy)/iResolution.y;
    vec2 uvTunnel = uvCentered;
    uvCentered /= max(0.0001, zoom);

    vec3 p = vec3(uvCentered, iTime);
    vec3 l = vec3(0.0);
    vec3 b, d;

    d = normalize(vec3(2.0*uvCentered - iResolution.xy, iResolution.y));

    for(float i=0.0; i<10.0; i++){
        b = p;
        p.xy = r(p.xy, 10.0);
        b.xy = r(sin(b.xy), iTime*0.5 + b.z*3.0);

        float s = 0.1 + abs(n(b*12.0)/12.0 - n(b))*0.2;
        s = max(s, 1.5 - length(uvTunnel*5.5));
        s += abs(p.y*0.1 + sin(p.x*1.5 + 5.0));

        p += d*s;
        l += (1.0 + sin(i + vec3(2.0,1.1,0.0)+3.0))/s;
    }

    vec3 effectColor = a(l*l*l/3000.0);
    effectColor = hueShift(effectColor, hue);

    vec3 bitmapColor = texture(iChannel0, uv).rgb;

    return vec4(mix(bitmapColor, effectColor, clamp(strength,0.0,1.0)), 1.0);
}

vec2 barDistFlat(vec2 uv, vec2 pos, float angleRad, float barLen)
{
    vec2 dir = vec2(cos(angleRad), sin(angleRad));
    vec2 pa = uv - pos;
    float t = clamp(dot(pa, dir) / barLen, 0.0, 1.0);
    float d = length(pa - dir * (t * barLen)) * iResolution.x;
    return vec2(d, t);
}

vec2 barDistCurved(vec2 uv, vec2 pos, float width, float curve)
{
    float x = uv.x - pos.x;
    float y = uv.y - pos.y;
    float arc = curve * (x - 0.5) * (x - 0.5);
    float d = abs(y + arc) * iResolution.y;
    return vec2(d, clamp(x / width, 0.0, 1.0));
}

void main() {
    vec2 uv = openfl_TextureCoordv.xy;
    vec4 col = texture(iChannel0, uv);

    float arc6 = 0.9 * (uv.x - 0.5) * (uv.x - 0.5);
    float curveY6 = 0.87 - arc6;

    vec2 p1 = vec2(topX, 0.0);
    vec2 p2 = vec2(bottomX, 1.0);
    float d = (uv.x - p1.x) * (p2.y - p1.y) - (uv.y - p1.y) * (p2.x - p1.x);
    bool cutSide = side > 0.5 ? (d > 0.0) : (d < 0.0);

    if (cutSide && uv.y < curveY6)
        col = specialShader(openfl_TextureCoordv * iResolution.xy);

    if (uv.y > curveY6)
        col = vec4(0.0,0.0,0.0,1.0);

    vec2 pa = uv - p1;
    vec2 ba = p2 - p1;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    float dist = length(pa - ba * h) * iResolution.x;

    float bwOuter = borderWidth;
    float bwMiddle = borderWidth * 0.66;
    float bwInner = borderWidth * 0.33;

    if (!cutSide && uv.y < curveY6) {
        if (dist < bwInner) col = vec4(0.0,0.0,0.0,1.0);
        else if (dist < bwMiddle) col = vec4(1.0,1.0,1.0,1.0);
        else if (dist < bwOuter) col = vec4(0.0,0.0,0.0,1.0);
    }

    if (uv.y < 0.15) col = vec4(0.0,0.0,0.0,1.0);
    else if (uv.y > 0.15 && uv.y < 0.2359 && uv.x > 0.358 && uv.x < 0.654) col = vec4(0.0,0.0,0.0,1.0);
    else if (uv.x > 0.3087 && uv.x < 0.358){
        float yMax = 0.15 + (uv.x - 0.3267) * tan(radians(70.0));
        if (uv.y > 0.15 && uv.y < yMax) col = vec4(0.0,0.0,0.0,1.0);
    }
    else if (uv.x > 0.654 && uv.x < 0.7024){
        float yMax = 0.1659 - (uv.x - 0.6784) * tan(radians(70.0));
        if (uv.y > 0.15 && uv.y < yMax) col = vec4(0.0,0.0,0.0,1.0);
    }

    vec2 d1 = barDistFlat(uv, vec2(0.0, 0.15), radians(0.0), 0.3267);
    vec2 d2 = barDistFlat(uv, vec2(0.3267, 0.15), radians(70.0), 0.101);
    vec2 d3 = barDistFlat(uv, vec2(0.686, 0.15), radians(0.0), 0.3267);
    vec2 d4 = barDistFlat(uv, vec2(0.654, 0.237), radians(-70.0), 0.096);
    vec2 d5 = barDistFlat(uv, vec2(0.358, 0.237), radians(0.0), 0.296);
    vec2 d6 = barDistCurved(uv, vec2(0.0, 0.87), 1.0, 0.9);
    vec2 d7 = barDistFlat(uv, vec2(0.966, 0.4), radians(0.0), 0.04);
    vec2 d8 = barDistFlat(uv, vec2(0.66, 0.85), radians(90.0), 0.23);
    vec2 d9 = barDistFlat(uv, vec2(0.33, 0.85), radians(90.0), 0.23);

    float factor1 = 1.0;
    float factor2 = 0.5;
    float factor3 = 1.0;
    float factor4 = 0.5;
    float factor5 = 1.0;
    float factor6 = 0.5;
    float factor7 = 0.0;
    float factor8 = 0.5;
    float factor9 = 0.5;

    if (d2.x < bwOuter * factor2 && d2.y > 0.0 && d2.y < 1.0) col = (d2.x < bwInner * factor2) ? vec4(1.0) : vec4(0.0,0.0,0.0,1.0);
    if (d4.x < bwOuter * factor4 && d4.y > 0.0 && d4.y < 1.0) col = (d4.x < bwInner * factor4) ? vec4(1.0) : vec4(0.0,0.0,0.0,1.0);
    if (d1.x < bwOuter * factor1 && d1.y > 0.0 && d1.y < 1.0) col = (d1.x < bwInner * factor1) ? vec4(1.0) : vec4(0.0,0.0,0.0,1.0);
    if (d3.x < bwOuter * factor3 && d3.y > 0.0 && d3.y < 1.0) col = (d3.x < bwInner * factor3) ? vec4(1.0) : vec4(0.0,0.0,0.0,1.0);
    if (d5.x < bwOuter * factor5 && d5.y > 0.0 && d5.y < 1.0) col = (d5.x < bwInner * factor5) ? vec4(1.0) : vec4(0.0,0.0,0.0,1.0);
    if (d6.x < bwOuter * factor6 && d6.y > 0.0 && d6.y < 1.0) col = (d6.x < bwInner * factor6) ? vec4(1.0) : vec4(0.0,0.0,0.0,1.0);
    if (d7.x < bwOuter * factor7 && d7.y > 0.0 && d7.y < 1.0) col = (d7.x < bwInner * factor7) ? vec4(1.0) : vec4(0.0,0.0,0.0,1.0);
    if (d8.x < bwOuter * factor8 && d8.y > 0.0 && d8.y < 1.0) col = (d8.x < bwInner * factor8) ? vec4(1.0) : vec4(0.0,0.0,0.0,1.0);
    if (d9.x < bwOuter * factor9 && d9.y > 0.0 && d9.y < 1.0) col = (d9.x < bwInner * factor9) ? vec4(1.0) : vec4(0.0,0.0,0.0,1.0);

    gl_FragColor = col;
}')
	public function new() {
		super();
	}
}


class BloomEffect extends ShaderEffect
{
    public var shader:BloomShader = new BloomShader();
    public var effect(get, set):Float;
    public var strength(get, set):Float;
    public var contrast(get, set):Float;
    public var brightness(get, set):Float;

    var _effect:Float = 15;
    var _strength:Float = 0.5;
    var _contrast:Float = 1.3;
    var _brightness:Float = -0.2;

    function get_effect() return _effect;
    function set_effect(v:Float) { _effect = v; shader.effect.value = [v]; return v; }
    function get_strength() return _strength;
    function set_strength(v:Float) { _strength = v; shader.strength.value = [v]; return v; }
    function get_contrast() return _contrast;
    function set_contrast(v:Float) { _contrast = v; shader.contrast.value = [v]; return v; }
    function get_brightness() return _brightness;
    function set_brightness(v:Float) { _brightness = v; shader.brightness.value = [v]; return v; }

    public function new(){
        shader.effect.value = [15];
        shader.strength.value = [0.5];
        shader.iResolution.value = [FlxG.width,FlxG.height];
        shader.contrast.value = [1.3];
        shader.brightness.value = [-0.2];
    }
}
class BloomShader extends FlxShader
{
    @:glFragmentSource('
    #pragma header

    uniform float effect;
    uniform float strength;


    uniform float contrast;
    uniform float brightness;

    uniform vec2 iResolution;

    void main()
    {
        vec2 uv = openfl_TextureCoordv;


		vec4 color = flixel_texture2D(bitmap,uv);
        //float brightness = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));

        //vec4 newColor = vec4(color.rgb * brightness * strength * color.a, color.a);

        //got some stuff from here: https://github.com/amilajack/gaussian-blur/blob/master/src/9.glsl
        //this also helped to understand: https://learnopengl.com/Advanced-Lighting/Bloom


        color.rgb *= contrast;
        color.rgb += vec3(brightness,brightness,brightness);

        if (effect <= 0.0 || strength <= 0.0)
        {
            gl_FragColor = color;
            return;
        }


        vec2 off1 = vec2(1.3846153846) * effect;
        vec2 off2 = vec2(3.2307692308) * effect;

        color += flixel_texture2D(bitmap, uv) * 0.2270270270 * strength;
        color += flixel_texture2D(bitmap, uv + (off1 / iResolution)) * 0.3162162162 * strength;
        color += flixel_texture2D(bitmap, uv - (off1 / iResolution)) * 0.3162162162 * strength;
        color += flixel_texture2D(bitmap, uv + (off2 / iResolution)) * 0.0702702703 * strength;
        color += flixel_texture2D(bitmap, uv - (off2 / iResolution)) * 0.0702702703 * strength;

		gl_FragColor = color;
    }')
    public function new()
        {
          super();
        } 
}


class ChromAbEffect extends ShaderEffect
{
	public var shader:ChromAbShader = new ChromAbShader();
	public var strength(get, set):Float;
	var _strength:Float = 0.0;

	function get_strength() return _strength;
	function set_strength(v:Float) { _strength = v; shader.strength.value = [v]; return v; }

	public function new():Void
	{
		shader.strength.value = [0.0];
	}
}

class ChromAbShader extends FlxShader
{
	@:glFragmentSource('
		#pragma header
		
		uniform float strength;

		void main()
		{
			vec2 uv = openfl_TextureCoordv;
			vec4 col = flixel_texture2D(bitmap, uv);
			col.r = flixel_texture2D(bitmap, vec2(uv.x+strength, uv.y)).r;
			col.b = flixel_texture2D(bitmap, vec2(uv.x-strength, uv.y)).b;

			col = col * (1.0 - strength * 0.5);

			gl_FragColor = col;
		}')
	public function new()
	{
		super();
	}
}

class SnowCutEffect extends ShaderEffect {
	public var shader(default, null):SnowCutShader = new SnowCutShader();

	public var side(get, set):Float;
	public var topX(get, set):Float;
	public var bottomX(get, set):Float;
	public var borderWidth(get, set):Float;
	public var strength(get, set):Float;
	public var hue1(get, set):Float;
	public var hue2(get, set):Float;
	public var specialRotation(get, set):Float;

	var _side:Float = 0.0;
	var _topX:Float = 0.0;
	var _bottomX:Float = 0.0;
	var _borderWidth:Float = 0.0;
	var _strength:Float = 1.0;
	var _hue1:Float = 0.0;
	var _hue2:Float = 0.0;
	var _specialRotation:Float = 0.0;

	public var time(default, set):Float = 0.0;
	public var iTime(get, set):Float;

	function get_iTime() return time;
	function set_iTime(v:Float) return set_time(v);

	function set_time(v:Float):Float {
		time = v;
		if (shader != null && shader.iTime != null && shader.iTime.value != null)
			shader.iTime.value[0] = time;
		return time;
	}

	function get_side() return _side;
	function set_side(v:Float) { _side = v; shader.side.value[0] = v; return v; }

	function get_topX() return _topX;
	function set_topX(v:Float) { _topX = v; shader.topX.value[0] = v; return v; }

	function get_bottomX() return _bottomX;
	function set_bottomX(v:Float) { _bottomX = v; shader.bottomX.value[0] = v; return v; }

	function get_borderWidth() return _borderWidth;
	function set_borderWidth(v:Float) { _borderWidth = v; shader.borderWidth.value[0] = v; return v; }

	function get_strength() return _strength;
	function set_strength(v:Float) { _strength = v; shader.strength.value[0] = v; return v; }

	function get_hue1() return _hue1;
	function set_hue1(v:Float) { _hue1 = v; shader.hue1.value[0] = v; return v; }

	function get_hue2() return _hue2;
	function set_hue2(v:Float) { _hue2 = v; shader.hue2.value[0] = v; return v; }

	function get_specialRotation() return _specialRotation;
	function set_specialRotation(v:Float) { _specialRotation = v; shader.specialRotation.value[0] = v; return v; }

	override public function update(elapsed:Float):Void {
		iTime += elapsed;
	}

	public function new() {
		shader.side.value = [0.0];
		shader.topX.value = [0.0];
		shader.bottomX.value = [0.0];
		shader.borderWidth.value = [0.0];
		shader.strength.value = [1.0];
		shader.hue1.value = [0.0];
		shader.hue2.value = [0.0];
		shader.specialRotation.value = [0.0];
		shader.iTime.value = [0.0];
	}
}

class SnowCutShader extends FlxShader
{
	@:glFragmentSource('
		#pragma header

#define iResolution vec3(openfl_TextureSize, 0.)
#define iChannel0 bitmap
#define texture flixel_texture2D

uniform float side;
uniform float topX;
uniform float bottomX;
uniform float borderWidth;

uniform float iTime;
uniform float strength;

uniform float hue1;
uniform float hue2;
uniform float specialRotation;

float snow(vec2 uv,float scale)
{
    
	float _t = (iTime)*2.3;
	uv*=scale;    
	uv.x+=_t; 
	vec2 s=floor(uv);
    vec2 f=fract(uv);
	vec2 p=.5+.35*sin(11.*fract(sin((s+scale)*mat2(7,3,6,5))*5.))-f;
    float d=length(p);
	float k=smoothstep(0.,d,sin(f.x+f.y)*0.003);
	return k;
}

vec3 _globalmix(vec2 uv)
{
	float dd = 0.5-length(uv);
	uv.x += sin(iTime*0.08);
	uv.y += sin(uv.x*1.4)*0.2;
	uv.x *= 0.1;
	float c=snow(uv,30.)*.3;
	c+=snow(uv,20.)*.5;
	c+=snow(uv,15.)*.8;
	c+=snow(uv,10.);
	c+=snow(uv,8.);
	c+=snow(uv,6.);
	c+=snow(uv,5.);
	c*=0.2/dd;
	vec3 finalColor=(vec3(0.7,0.35,0.9))*c*30.0;
    finalColor += vec3(1.1,0.55,0.9)*0.02/dd;
    return finalColor;
}

vec3 hueRotate(vec3 color,float h)
{
    float angle = h * 6.2831853;

    vec3 k = vec3(0.57735);
    float c = cos(angle);
    float s = sin(angle);

    return color * c
        + cross(k,color) * s
        + k * dot(k,color) * (1.0-c);
}

vec4 specialShader(vec2 fragCoord)
{
    vec2 uvSnow = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    float specialZoomX = 1.6;
    float specialZoomY = 1.5;

    float specialPosX = -0.2;
    float specialPosY = 0.0;

    uvSnow.x /= max(0.0001, specialZoomX);
    uvSnow.y /= max(0.0001, specialZoomY);

    uvSnow.x -= specialPosX;
    uvSnow.y -= specialPosY;

    float angle = radians(specialRotation);

    float cs = cos(angle);
    float sn = sin(angle);

    uvSnow = vec2(
        uvSnow.x * cs - uvSnow.y * sn,
        uvSnow.x * sn + uvSnow.y * cs
    );

    float colorValue = clamp(uvSnow.y + 0.5, 0.0, 1.0);

    vec3 color1 = hueRotate(vec3(1.0,0.0,0.0), hue1);
    vec3 color2 = hueRotate(vec3(1.0,0.0,0.0), hue2);

    vec3 gradientColor = mix(color1, color2, colorValue);

    vec3 effectColor = _globalmix(uvSnow);

    effectColor *= gradientColor;

    return vec4(effectColor,1.0);
}

vec2 barDistFlat(vec2 uv, vec2 pos, float angleRad, float barLen)
{
    vec2 dir = vec2(cos(angleRad), sin(angleRad));
    vec2 pa = uv - pos;
    float t = clamp(dot(pa, dir) / barLen, 0.0, 1.0);
    float d = length(pa - dir * (t * barLen)) * iResolution.x;
    return vec2(d, t);
}

void main() {
    vec2 uv = openfl_TextureCoordv.xy;
    vec4 col = texture(iChannel0, uv);

    vec2 p1 = vec2(topX + 0.65, 0.0);
    vec2 p2 = vec2(bottomX + 0.55, 1.0);
    float d = (uv.x - p1.x) * (p2.y - p1.y) - (uv.y - p1.y) * (p2.x - p1.x);
    bool cutSide = side > 0.5 ? (d > 0.0) : (d < 0.0);

    
    if (uv.y > 0.0 && uv.y < 0.3 && uv.x > 0.62825 && uv.x < 1.0) col = vec4(0.0,0.0,0.0,1.0);

    if (cutSide)
        col = specialShader(openfl_TextureCoordv * iResolution.xy);

    vec2 pa = uv - p1;
    vec2 ba = p2 - p1;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    float dist = length(pa - ba * h) * iResolution.x;

    float bwOuter = borderWidth + 15.0;
    float bwMiddle = borderWidth + 15.0 * 0.66;
    float bwInner = borderWidth + 15.0 * 0.33;

    if (!cutSide) {
        if (dist < bwInner) col = vec4(0.0,0.0,0.0,1.0);
        else if (dist < bwMiddle) col = vec4(1.0,1.0,1.0,1.0);
        else if (dist < bwOuter) col = vec4(0.0,0.0,0.0,1.0);
    }

    if (uv.y < 0.0) col = vec4(0.0,0.0,0.0,1.0);
    else if (uv.y > 0.0 && uv.y < 0.143 && uv.x > 0.128 && uv.x < 0.481) col = vec4(0.0,0.0,0.0,1.0);
    else if (uv.x > 0.08 && uv.x < 0.128){
        float yMax = 0.07 + (uv.x - 0.104) * tan(radians(70.0));
        if (uv.y > 0.0 && uv.y < yMax) col = vec4(0.0,0.0,0.0,1.0);
    }
    else if (uv.x > 0.481 && uv.x < 0.527){
        float yMax = 0.092 - (uv.x - 0.497) * tan(radians(70.0));
        if (uv.y > 0.0 && uv.y < yMax) col = vec4(0.0,0.0,0.0,1.0);
    }
    else if (uv.y > 0.853 && uv.y < 1.0 && uv.x > 0.137 && uv.x < 0.453) col = vec4(0.0,0.0,0.0,1.0);
    if (uv.x > 0.05 && uv.x < 0.137){
        float yMin = 1.0 + (uv.x - 0.09) * tan(radians(-70.0));
        if (uv.y > yMin && uv.y < 1.0)
        col = vec4(0.0,0.0,0.0,1.0);
    }

    if (uv.x > 0.453 && uv.x < 0.557){
        float yMin = 1.0 + (uv.x - 0.50) * tan(radians(-110.0));
        if (uv.y > yMin && uv.y < 1.0)
        col = vec4(0.0,0.0,0.0,1.0);
    }

    vec2 d1 = barDistFlat(uv, vec2(0.08, 0.0), radians(70.0), 0.15);
    vec2 d2 = barDistFlat(uv, vec2(0.477, 0.136), radians(-70.0), 0.15);
    vec2 d3 = barDistFlat(uv, vec2(0.545, 1.0), radians(-84.2), 1.1);
    vec2 d4 = barDistFlat(uv, vec2(0.09, 1.0), radians(-70.0), 0.15);
    vec2 d5 = barDistFlat(uv, vec2(0.128, 0.132), radians(0.0), 0.35);
    vec2 d7 = barDistFlat(uv, vec2(0.62825, 0.3), radians(0.0), 0.4);
    vec2 d8 = barDistFlat(uv, vec2(0.5, 1.0), radians(-110.0), 0.15);
    vec2 d9 = barDistFlat(uv, vec2(0.14, 0.862), radians(0.0), 0.31);

    float factor1 = 0.5;
    float factor2 = 0.5;
    float factor3 = 0.5;
    float factor4 = 0.5;
    float factor5 = 0.9;
    float factor7 = 1.0;
    float factor8 = 0.5;
    float factor9 = 0.9;

    if (d2.x < bwOuter * factor2 && d2.y > 0.0 && d2.y < 1.0) col = (d2.x < bwInner * factor2) ? vec4(1.0) : vec4(0.0,0.0,0.0,1.0);
    if (d4.x < bwOuter * factor4 && d4.y > 0.0 && d4.y < 1.0) col = (d4.x < bwInner * factor4) ? vec4(1.0) : vec4(0.0,0.0,0.0,1.0);
    if (d1.x < bwOuter * factor1 && d1.y > 0.0 && d1.y < 1.0) col = (d1.x < bwInner * factor1) ? vec4(1.0) : vec4(0.0,0.0,0.0,1.0);
    if (d3.x < bwOuter * factor3 && d3.y > 0.0 && d3.y < 1.0) col = (d3.x < bwInner * factor3) ? vec4(1.0) : vec4(0.0,0.0,0.0,1.0);
    if (d5.x < bwOuter * factor5 && d5.y > 0.0 && d5.y < 1.0) col = (d5.x < bwInner * factor5) ? vec4(1.0) : vec4(0.0,0.0,0.0,1.0);
    if (d7.x < bwOuter * factor7 && d7.y > 0.0 && d7.y < 1.0) col = (d7.x < bwInner * factor7) ? vec4(1.0) : vec4(0.0,0.0,0.0,1.0);
    if (d8.x < bwOuter * factor8 && d8.y > 0.0 && d8.y < 1.0) col = (d8.x < bwInner * factor8) ? vec4(1.0) : vec4(0.0,0.0,0.0,1.0);
    if (d9.x < bwOuter * factor9 && d9.y > 0.0 && d9.y < 1.0) col = (d9.x < bwInner * factor9) ? vec4(1.0) : vec4(0.0,0.0,0.0,1.0);

    gl_FragColor = col;
}')
	public function new()
	{
		super();
	}
}