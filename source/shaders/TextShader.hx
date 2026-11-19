package shaders;

import flixel.system.FlxAssets.FlxShader;

class TextShader {
	public var outerColorTop(default, set):Array<Float> = [1, 1, 1];
	public var outerColorBot(default, set):Array<Float> = [1, 1, 1];
	public var midColorTop(default, set):Array<Float> = [1, 1, 1];
	public var midColorBot(default, set):Array<Float> = [1, 1, 1];
	public var innerColorTop(default, set):Array<Float> = [1, 1, 1];
	public var innerColorBot(default, set):Array<Float> = [1, 1, 1];

	public var strength:Float = 0.0;
	public var intensity:Float = 0.0;
	public var mixGap:Float = 2.0;
	public var opacity:Float = 1.0;
	public var textIndex:Int = 0;
	public var selectedIndex:Int = 0;

	public var shader(default, null):TextShaderSEXO = new TextShaderSEXO();

	public static var shaderCache:Map<String, TextShader> = new Map();

		public static function getCached(id:String):TextShader
		{
			if (shaderCache.exists(id))
				return shaderCache.get(id);

			var s = new TextShader();
			shaderCache.set(id, s);
			return s;
		}
	public function new():Void {
		set_outerColorTop(outerColorTop);
		set_outerColorBot(outerColorBot);
		set_midColorTop(midColorTop);
		set_midColorBot(midColorBot);
		set_innerColorTop(innerColorTop);
		set_innerColorBot(innerColorBot);
		shader.strength.value = [strength];
		shader.intensity.value = [intensity];
		shader.mixGap.value = [mixGap];
		shader.opacity.value = [opacity];
		shader.textIndex.value = [textIndex];
		shader.selectedIndex.value = [selectedIndex];
	}

	public function update(elapsed:Float):Void {
		if (shader.strength.value == null) {
			shader.strength.value = [strength];
		}
		else if (shader.strength.value[0] != strength)
			shader.strength.value[0] = strength;

		if (shader.intensity.value == null) {
			shader.intensity.value = [intensity];
		}
		else if (shader.intensity.value[0] != intensity)
			shader.intensity.value[0] = intensity;

		if (shader.mixGap.value == null) {
			shader.mixGap.value = [mixGap];
		}
		else if (shader.mixGap.value[0] != mixGap)
			shader.mixGap.value[0] = mixGap;

		if (shader.opacity.value == null) {
			shader.opacity.value = [opacity];
		}
		else if (shader.opacity.value[0] != opacity)
			shader.opacity.value[0] = opacity;

		if (shader.textIndex.value == null) {
			shader.textIndex.value = [textIndex];
		}
		else if (shader.textIndex.value[0] != textIndex)
			shader.textIndex.value[0] = textIndex;

		if (shader.selectedIndex.value == null) {
			shader.selectedIndex.value = [selectedIndex];
		}
		else if (shader.selectedIndex.value[0] != selectedIndex)
			shader.selectedIndex.value[0] = selectedIndex;
	}

	private function set_outerColorTop(v:Array<Float>):Array<Float> {
		shader.outerColorTop.value = v;
		return outerColorTop = v;
	}
	private function set_outerColorBot(v:Array<Float>):Array<Float> {
		shader.outerColorBot.value = v;
		return outerColorBot = v;
	}
	private function set_midColorTop(v:Array<Float>):Array<Float> {
		shader.midColorTop.value = v;
		return midColorTop = v;
	}
	private function set_midColorBot(v:Array<Float>):Array<Float> {
		shader.midColorBot.value = v;
		return midColorBot = v;
	}
	private function set_innerColorTop(v:Array<Float>):Array<Float> {
		shader.innerColorTop.value = v;
		return innerColorTop = v;
	}
	private function set_innerColorBot(v:Array<Float>):Array<Float> {
		shader.innerColorBot.value = v;
		return innerColorBot = v;
	}
}

class TextShaderSEXO extends FlxShader {
    @:glFragmentSource('
        #pragma header

        uniform vec3 outerColorTop;
        uniform vec3 outerColorBot;
        uniform vec3 midColorTop;
        uniform vec3 midColorBot;
        uniform vec3 innerColorTop;
        uniform vec3 innerColorBot;

        uniform float strength;
        uniform float intensity;
        uniform float opacity;
        uniform float textIndex;
        uniform float selectedIndex;
        uniform float mixGap;

        vec4 applyGradient(vec2 uv)
        {
            vec4 col = texture2D(bitmap, uv);
            float m = ((uv.y - 0.5) * mixGap) + 0.5;
            vec3 gradMid   = mix(midColorTop, midColorBot, m);
            vec3 gradInner = mix(innerColorTop, innerColorBot, m);
            vec3 gradOuter = mix(outerColorTop, outerColorBot, m);
            vec3 finalRGB = col.r * gradMid + col.g * gradInner + col.b * gradOuter;
            return vec4(finalRGB, col.a);
        }

        void main()
        {
            vec2 uv = openfl_TextureCoordv;
            vec4 base = applyGradient(uv);

            if (strength > 0.0)
            {
                vec2 resFactor = (1.0 / openfl_TextureSize.xy) * intensity;

                vec4 topLeft     = applyGradient(uv + vec2(-resFactor.x, -resFactor.y));
                vec4 topMiddle   = applyGradient(uv + vec2(0.0, -resFactor.y));
                vec4 topRight    = applyGradient(uv + vec2( resFactor.x, -resFactor.y));
                vec4 midLeft     = applyGradient(uv + vec2(-resFactor.x, 0.0));
                vec4 midRight    = applyGradient(uv + vec2( resFactor.x, 0.0));
                vec4 bottomLeft  = applyGradient(uv + vec2(-resFactor.x,  resFactor.y));
                vec4 bottomMiddle= applyGradient(uv + vec2(0.0,  resFactor.y));
                vec4 bottomRight = applyGradient(uv + vec2( resFactor.x,  resFactor.y));

                vec4 Gx = topLeft + 2.0*midLeft + bottomLeft - topRight - 2.0*midRight - bottomRight;
                vec4 Gy = topLeft + 2.0*topMiddle + topRight - bottomLeft - 2.0*bottomMiddle - bottomRight;
                vec4 G = sqrt(Gx*Gx + Gy*Gy);
                G.a = base.a;
                base = mix(base, base + G, strength);
            }

            base.rgb *= opacity;
            base.a *= opacity;

            gl_FragColor = base;
        }
    ')
    public function new() { super(); }
}