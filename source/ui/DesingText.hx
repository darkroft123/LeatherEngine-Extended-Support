package ui;

import flixel.text.FlxText;
import flixel.util.FlxColor;
import openfl.display.BitmapData;
import flixel.FlxG;
import haxe.Json;
import flixel.math.FlxMath;
import shaders.TextShader;

class DesingText extends FlxText
{
	public var textShaderWrapper:TextShader;

	public var border1Size:Float = 7;
	public var border1Color:FlxColor = 0xFF0000FF;

	public var border2Size:Float = 3;
	public var border2Color:FlxColor = 0xFFFF0000;

	public var targetY:Float = 0;
	public var targetX:Float = 0;
	public var z:Float = 0;
	public var isMenuItem:Bool = false;

	public var childText:DesingText;
	public var vipOffsetX:Float = 0;
	public var vipOffsetY:Float = 0;

	public var scaleX:Float = 1.0;
	public var scaleY:Float = 1.0;

	private var baseStyle:Dynamic = null;
	private var applyingBase:Bool = false;

	private static var defaultData:String = '{
		"outerBorderTop": "#000000",
		"outerBorderBot": "#000000",
		"midBorderTop": "#c735ff",
		"midBorderBot": "#6414ea",
		"innerBorderTop": "#3f3f3f",
		"innerBorderBot": "#121617"
	}';

	private static var parsedDefaultData:Dynamic = Json.parse(defaultData);
	private static var colorCache:Map<String, Array<Float>> = new Map();
	private static var colorArrayCache:Map<String, Array<Float>> = new Map();
	private static var OPACITY_VALUES:Array<Float> = [1.0, 0.5, 0.25];

	private var lastOpacity:Float = -1;
	private var lastSelected:Int = -1;

	var borderIterations:Int = 16;

	private inline function totalBorderPad():Float
	{
		return (border1Size + border2Size) * 5;
	}

	private inline function textOffset():Float
	{
		return (border1Size + border2Size) * 2;
	}

	private static function getBaseColor(colorString:String):Array<Float>
	{
		var cached = colorCache.get(colorString);
		if (cached != null)
			return cached;

		var col:FlxColor = FlxColor.fromString(colorString);
		var arr = [
			((col >> 16) & 0xff) / 255,
			((col >> 8) & 0xff) / 255,
			(col & 0xff) / 255
		];

		colorCache.set(colorString, arr);
		return arr;
	}

	public static function getColorArray(colorString:String, offset:Float):Array<Float>
	{
		var key = colorString + "_" + offset;
		var cached = colorArrayCache.get(key);
		if (cached != null)
			return cached;

		var base = getBaseColor(colorString);
		var mul = 1 + offset;
		var arr = [base[0] * mul, base[1] * mul, base[2] * mul];
		colorArrayCache.set(key, arr);
		return arr;
	}

	override function regenGraphic():Void
	{
		if (textField == null || !_regen)
			return;

		var tfText = textField.text;
		if (tfText == null || tfText.length == 0)
			return;
		var oldWidth:Int = 0;
		var oldHeight:Int = FlxText.VERTICAL_GUTTER;

		if (graphic != null)
		{
			oldWidth = graphic.width;
			oldHeight = graphic.height;
		}

		var tf = textField;
		var tfTextHeight = tf.textHeight;
		var pad = totalBorderPad();
		var newWidth:Int = Math.ceil(tf.width + pad);
		var textHeight = _autoHeight ? tfTextHeight : tf.height;
		var gutter = _autoHeight ? FlxText.VERTICAL_GUTTER : 0;
		var newHeight:Int = Math.ceil(textHeight + pad) + gutter;

		if (tfTextHeight == 0)
			newHeight = oldHeight;

		if (oldWidth != newWidth || oldHeight != newHeight)
		{
			height = newHeight;
			var key:String = FlxG.bitmap.getUniqueKey("text");
			makeGraphic(newWidth, newHeight, FlxColor.TRANSPARENT, false, key);

			if (_hasBorderAlpha)
			{
				if (_borderPixels == null || _borderPixels.width != newWidth || _borderPixels.height != newHeight)
				{
					if (_borderPixels != null)
						_borderPixels.dispose();
					_borderPixels = new BitmapData(newWidth, newHeight, true);
				}
				else
				{
					_borderPixels.fillRect(_flashRect, FlxColor.TRANSPARENT);
				}
			}

			if (_autoHeight)
				tf.height = newHeight;

			_flashRect.setTo(0, 0, newWidth, newHeight);
		}
		else
		{
			graphic.bitmap.fillRect(_flashRect, FlxColor.TRANSPARENT);

			if (_hasBorderAlpha)
			{
				if (_borderPixels == null)
					_borderPixels = new BitmapData(frameWidth, frameHeight, true);
				else
					_borderPixels.fillRect(_flashRect, FlxColor.TRANSPARENT);
			}
		}

		copyTextFormat(_defaultFormat, _formatAdjusted);
		_matrix.identity();

		borderColor = border1Color;
		borderSize = border1Size;
		applyBorderStyle();
		applyBorderTransparency();

		borderColor = border2Color;
		borderSize = border2Size;
		applyBorderStyle();
		applyBorderTransparency();

		applyFormats(_formatAdjusted, false);
		drawTextFieldTo(graphic.bitmap);

		_regen = false;
		resetFrame();
	}

	override function drawTextFieldTo(graphic:BitmapData):Void
	{
		var off = textOffset();
		_matrix.translate(off, off);
		graphic.draw(textField, _matrix);
		_matrix.translate(-off, -off);
	}

	override function applyBorderStyle():Void
	{
		applyFormats(_formatAdjusted, true);

		var bmp:BitmapData = _hasBorderAlpha ? _borderPixels : graphic.bitmap;
		var sz = borderSize;
		var step = (Math.PI * 2) / borderIterations;

		for (i in 0...borderIterations)
		{
			var ox = Math.cos(step * i) * sz;
			var oy = Math.sin(step * i) * sz;

			_matrix.translate(-ox, -oy);
			drawTextFieldTo(bmp);
			_matrix.translate(ox, oy);
		}
	}

	override public function draw():Void
	{
		if (alpha <= 0 || (textShaderWrapper != null && textShaderWrapper.opacity <= 0))
			return;

		super.draw();

		var child = childText;
		if (child != null)
		{
			child.cameras = cameras;
			child.scale.set(scale.x * 0.75, scale.y * 0.75);
			child.updateHitbox();

			var halfWidth = width * 0.5;
			var halfHeight = height * 0.5;

			child.x = x + halfWidth - (child.width * 0.5) + vipOffsetX;
			child.y = y + (halfHeight - (child.height * 0.2)) + vipOffsetY;

			child.draw();
		}
	}

	public function updateShaderFade(curSelected:Int, index:Int):Void
	{
		if (textShaderWrapper == null)
			return;

		var distance = Std.int(Math.abs(index - curSelected));
		var opacity = (distance < OPACITY_VALUES.length) ? OPACITY_VALUES[distance] : 0.0;

		if (lastOpacity == opacity && lastSelected == curSelected)
			return;

		var child = childText;
		var childShader = (child != null) ? child.textShaderWrapper : null;

		if (lastOpacity != opacity)
		{
			textShaderWrapper.opacity = opacity;

			if (childShader != null)
				childShader.opacity = opacity;

			lastOpacity = opacity;
		}

		if (lastSelected != curSelected)
		{
			textShaderWrapper.selectedIndex = curSelected;
			lastSelected = curSelected;
		}

		textShaderWrapper.update(FlxG.elapsed);

		if (childShader != null)
			childShader.update(FlxG.elapsed);

		var scl = Math.max(0.5, 1 - 0.2 * distance);
		if (scale.x != scl || scale.y != scl)
		{
			scale.set(scl, scl);
		}
	}

	public static function createSongText(
		x:Float,
		y:Float,
		song:String,
		size:Int,
		spacing:Float,
		?data:Dynamic,
		?alpha:Float = 1.0
	):DesingText
	{
		if (data == null)
			data = parsedDefaultData;

		var vipLabel:String = null;

		if (data.createVipText != null && Std.string(data.createVipText).length > 0)
		{
			vipLabel = Std.string(data.createVipText);
		}
		else if (data.vipText != null && Std.string(data.vipText).length > 0)
		{
			var label = Std.string(data.vipText);
			var idx = song.indexOf(label);

			if (idx != -1)
			{
				vipLabel = label;
				var before = song.substr(0, idx);
				var after = song.substr(idx + label.length);
				song = (before + after).trim();

				while (song.indexOf("  ") != -1)
					song = song.replace("  ", " ");
			}
		}

		if (data.songFontSize != null)
			size = Std.int(Std.parseFloat(Std.string(data.songFontSize)));

		var songText = new DesingText(0, 0, 0, song, size);
		songText.borderStyle = OUTLINE;
		songText.letterSpacing = spacing;
		songText.borderSize = 5;

		if (data.outerBorderSize != null) songText.border1Size = data.outerBorderSize;
		if (data.midBorderSize != null) songText.border2Size = data.midBorderSize;
		if (data.innerBorderSize != null) songText.borderSize = data.innerBorderSize;

		songText.font = (data.songFont != null) ? Paths.font(data.songFont) : Paths.font("dumbnerd.ttf");

		var shader = new TextShader();
		songText.shader = shader.shader;
		songText.textShaderWrapper = shader;

		shader.outerColorTop = getColorArray(data.outerBorderTop, 0);
		shader.outerColorBot = getColorArray(data.outerBorderBot, 0);
		shader.midColorTop = getColorArray(data.midBorderTop, -0.1);
		shader.midColorBot = getColorArray(data.midBorderBot, 0.1);
		shader.innerColorTop = getColorArray(data.innerBorderTop, -0.3);
		shader.innerColorBot = getColorArray(data.innerBorderBot, 0.3);
		shader.mixGap = (data.mixGap != null) ? data.mixGap : 2.0;
		shader.strength = (data.sobelStrength != null) ? data.sobelStrength : 0.0;
		shader.intensity = (data.sobelIntensity != null) ? data.sobelIntensity : 0.0;
		shader.opacity = ((data.opacity != null) ? data.opacity : 1.0) * alpha;

		songText.color = 0xFF00FF00;
		songText.antialiasing = true;
		songText.baseStyle = Json.parse(Json.stringify(data));
		songText.applyVipData(data, vipLabel);

		songText.x = x;
		songText.y = y;

		return songText;
	}

	private function applyVipData(data:Dynamic, vipLabel:String):Void
	{
		if (vipLabel == null || vipLabel.length == 0)
		{
			if (childText != null)
			{
				childText.destroy();
				childText = null;
			}
			return;
		}

		if (childText == null)
		{
			var vipSize:Int = size;
			if (data.songFontSizeVIP != null)
				vipSize = Std.int(Std.parseFloat(Std.string(data.songFontSizeVIP)));

			childText = new DesingText(0, 0, 0, vipLabel, vipSize);
			childText.borderStyle = OUTLINE;
			childText.borderSize = 5;
			childText.letterSpacing = (data.vipLetterSpacing != null) ? data.vipLetterSpacing : 80;
			childText.font = (data.songFontVIP != null) ? Paths.font(data.songFontVIP) : font;
			childText.color = color;
			childText.antialiasing = true;

			var vipShader = new TextShader();
			childText.shader = vipShader.shader;
			childText.textShaderWrapper = vipShader;
		}

		childText.text = vipLabel;

		if (data.vipOffsetX != null) vipOffsetX = data.vipOffsetX;
		if (data.vipOffsetY != null) vipOffsetY = data.vipOffsetY;

		var s:TextShader = cast childText.textShaderWrapper;
		if (s != null)
		{
			if (data.outerBorderTopVIP != null) s.outerColorTop = getColorArray(data.outerBorderTopVIP, 0);
			if (data.outerBorderBotVIP != null) s.outerColorBot = getColorArray(data.outerBorderBotVIP, 0);
			if (data.midBorderTopVIP != null) s.midColorTop = getColorArray(data.midBorderTopVIP, -0.1);
			if (data.midBorderBotVIP != null) s.midColorBot = getColorArray(data.midBorderBotVIP, 0.1);
			if (data.innerBorderTopVIP != null) s.innerColorTop = getColorArray(data.innerBorderTopVIP, -0.3);
			if (data.innerBorderBotVIP != null) s.innerColorBot = getColorArray(data.innerBorderBotVIP, 0.3);

			s.update(0);
		}
	}

	override function update(elapsed:Float)
	{
		if (isMenuItem)
		{
			var scaledY = FlxMath.remapToRange(targetY, 0, 1, 0, 1.3);
			var lerpVal:Float = CoolUtil.boundTo(elapsed * 9.6, 0, 1);
			var targetPosY = (scaledY * 90) + (FlxG.height * 0.48);

			if (y != targetPosY)
			{
				var newY = FlxMath.lerp(y, targetPosY, lerpVal);
				if (Math.abs(newY - targetPosY) < 0.1)
					y = targetPosY;
				else
					y = newY;
			}

			if (x != targetX)
			{
				var newX = FlxMath.lerp(x, targetX, lerpVal);
				if (Math.abs(newX - targetX) < 0.1)
					x = targetX;
				else
					x = newX;
			}
		}

		if (childText != null)
			childText.angle = angle;

		super.update(elapsed);
	}

	public function applyStyleData(data:Dynamic):Void
	{
		if (data == null)
			return;

		if (!applyingBase && baseStyle != null)
		{
			applyingBase = true;
			applyStyleInternal(baseStyle);
			applyingBase = false;
		}

		applyStyleInternal(data);

		var vipLabel:String = null;
		if (Reflect.hasField(data, "createVipText"))
		{
			var raw = Std.string(data.createVipText).trim();
			if (raw.length > 0)
				vipLabel = raw;
		}

		applyVipData(data, vipLabel);

		_regen = true;
		regenGraphic();
		updateHitbox();
	}

	private function applyStyleInternal(data:Dynamic):Void
	{
		var fallback:Dynamic = (baseStyle != null) ? baseStyle : parsedDefaultData;

		var outerTop = (data.outerBorderTop != null) ? data.outerBorderTop : fallback.outerBorderTop;
		var outerBot = (data.outerBorderBot != null) ? data.outerBorderBot : fallback.outerBorderBot;
		var midTop = (data.midBorderTop != null) ? data.midBorderTop : fallback.midBorderTop;
		var midBot = (data.midBorderBot != null) ? data.midBorderBot : fallback.midBorderBot;
		var innerTop = (data.innerBorderTop != null) ? data.innerBorderTop : fallback.innerBorderTop;
		var innerBot = (data.innerBorderBot != null) ? data.innerBorderBot : fallback.innerBorderBot;

		var s:TextShader = cast textShaderWrapper;
		if (s != null)
		{
			s.outerColorTop = getColorArray(outerTop, 0);
			s.outerColorBot = getColorArray(outerBot, 0);
			s.midColorTop = getColorArray(midTop, -0.1);
			s.midColorBot = getColorArray(midBot, 0.1);
			s.innerColorTop = getColorArray(innerTop, -0.3);
			s.innerColorBot = getColorArray(innerBot, 0.3);

			s.mixGap = (data.mixGap != null) ? data.mixGap : ((fallback.mixGap != null) ? fallback.mixGap : 2.0);
			s.strength = (data.sobelStrength != null) ? data.sobelStrength : ((fallback.sobelStrength != null) ? fallback.sobelStrength : 0.0);
			s.intensity = (data.sobelIntensity != null) ? data.sobelIntensity : ((fallback.sobelIntensity != null) ? fallback.sobelIntensity : 0.0);
			s.opacity = (data.opacity != null) ? data.opacity : ((fallback.opacity != null) ? fallback.opacity : 1.0);

			s.update(0);
		}

		font = (data.songFont != null) ? Paths.font(data.songFont)
			: ((fallback.songFont != null) ? Paths.font(fallback.songFont) : font);

		size = (data.songFontSize != null)
			? Std.int(Std.parseFloat(Std.string(data.songFontSize)))
			: ((fallback.songFontSize != null) ? Std.int(Std.parseFloat(Std.string(fallback.songFontSize))) : size);

		border1Size = (data.outerBorderSize != null) ? data.outerBorderSize
			: ((fallback.outerBorderSize != null) ? fallback.outerBorderSize : border1Size);

		border2Size = (data.midBorderSize != null) ? data.midBorderSize
			: ((fallback.midBorderSize != null) ? fallback.midBorderSize : border2Size);

		borderSize = (data.innerBorderSize != null) ? data.innerBorderSize
			: ((fallback.innerBorderSize != null) ? fallback.innerBorderSize : borderSize);

		color = (data.textColor != null) ? FlxColor.fromString(data.textColor)
			: ((fallback.textColor != null) ? FlxColor.fromString(fallback.textColor) : color);
	}

	override public function destroy():Void
	{
		flixel.tweens.FlxTween.cancelTweensOf(this);
		if (scale != null) flixel.tweens.FlxTween.cancelTweensOf(scale);
		if (childText != null)
		{
			childText.destroy();
			childText = null;
		}
		textShaderWrapper = null;
		baseStyle = null;
		super.destroy();
	}
}
