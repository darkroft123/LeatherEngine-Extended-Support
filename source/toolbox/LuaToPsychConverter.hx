package toolbox;


class ConversionEntry {
	public var line:Int;
	public var original:String;
	public var converted:String;
	public var description:String;

	public function new(line:Int, original:String, converted:String, description:String) {
		this.line = line;
		this.original = original;
		this.converted = converted;
		this.description = description;
	}
}

class ConversionResult {
	public var originalCode:String;
	public var convertedCode:String;
	public var entries:Array<ConversionEntry>;
	public var totalChanges:Int;

	public function new(originalCode:String, convertedCode:String, entries:Array<ConversionEntry>) {
		this.originalCode = originalCode;
		this.convertedCode = convertedCode;
		this.entries = entries;
		this.totalChanges = entries.length;
	}
}

/**
 * Clean & non-invasive Leather to Psych Lua converter.
 * Maps hooks and direct function aliases cleanly, and attaches a lightweight
 * Psych compatibility bridge with runHaxeCode for Leather-specific functions.
 */
class LuaToPsychConverter {
	static final HOOK_REPLACEMENTS:Array<{regex:EReg, original:String, replacement:String}> = [
		{regex: ~/function\s+start\s*\(/g, original: "function start(", replacement: "function onCreate("},
		{regex: ~/function\s+create\s*\(/g, original: "function create(", replacement: "function onCreate("},
		{regex: ~/function\s+songStart\s*\(/g, original: "function songStart(", replacement: "function onSongStart("},
		{regex: ~/function\s+stepHit\s*\(/g, original: "function stepHit(", replacement: "function onStepHit("},
		{regex: ~/function\s+beatHit\s*\(/g, original: "function beatHit(", replacement: "function onBeatHit("},
		{regex: ~/function\s+update\s*\(/g, original: "function update(", replacement: "function onUpdate("},
		{regex: ~/function\s+updatePost\s*\(/g, original: "function updatePost(", replacement: "function onUpdatePost("}
	];

	static final DIRECT_ALIASES:Map<String, String> = [
		// Shaders
		"initShader" => "initLuaShader",
		"setActorShader" => "setSpriteShader",
		"removeActorShader" => "removeSpriteShader",
		"getCustomShaderBool" => "getShaderBool",
		"getCustomShaderInt" => "getShaderInt",
		"getCustomShaderFloat" => "getShaderFloat",
		"setCustomShaderBool" => "setShaderBool",
		"setCustomShaderInt" => "setShaderInt",
		"setCustomShaderFloat" => "setShaderFloat",
		"tweenShader" => "tweenShaderProperty",
		// Sprites & Animations
		"playCharAnim" => "characterPlayAnim",
		"playCharacterAnimation" => "characterPlayAnim",
		"playAnimation" => "playAnim",
		"playActorAnimation" => "playAnim",
		"dance" => "characterDance",
		"playActorDance" => "characterDance",
		"makeSprite" => "makeLuaSprite",
		"makeAnimatedSprite" => "makeAnimatedLuaSprite",
		"destroySprite" => "removeLuaSprite",
		"destroyGhost" => "removeLuaSprite",
		"removeGhost" => "removeLuaSprite",
		"addActorAnimation" => "addAnimationByPrefix",
		"getIsColliding" => "objectsOverlap",
		// Cameras
		"flashCamera" => "cameraFlash",
		"stopFlash" => "cameraFlash",
		"fadeCamera" => "cameraFade",
		// Tweens & Audio
		"tweenCancel" => "cancelTween",
		// Text
		"makeText" => "makeLuaText",
		"setActorTextColor" => "setTextColor",
		"setActorText" => "setTextString",
		"setActorFont" => "setTextFont",
		"setActorOutlineColor" => "setTextBorder",
		"setActorAlignment" => "setTextAlignment",
		"setActorTextSize" => "setTextSize",
		"setActorTextWidth" => "setTextWidth",
		"getActorText" => "getTextString"
	];

	// Lua compatibility bridge for Leather functions running on Psych Engine
	static final PSYCH_BRIDGE_HEADER:String =
		"-- [Psych Engine Compatibility Bridge for Leather Lua Scripts]\n" +
		"local function _getActor(tag)\n" +
		"    return game.getLuaObject(tag) or (tag == 'boyfriend' and game.boyfriend or tag == 'dad' and game.dad or tag == 'gf' and game.gf)\n" +
		"end\n\n" +
		"function setActorX(x, tag) setProperty(tag .. '.x', x) end\n" +
		"function setActorY(y, tag) setProperty(tag .. '.y', y) end\n" +
		"function setActorAlpha(a, tag) setProperty(tag .. '.alpha', a) end\n" +
		"function setActorAngle(r, tag) setProperty(tag .. '.angle', r) end\n" +
		"function setActorVisible(v, tag) setProperty(tag .. '.visible', v) end\n" +
		"function setActorScale(s, tag) scaleObject(tag, s, s) end\n" +
		"function setActorScaleXY(x, y, tag) scaleObject(tag, x, y) end\n" +
		"function setActorScroll(x, y, tag) setScrollFactor(tag, x, y) end\n" +
		"function getActorX(tag) return getProperty(tag .. '.x') end\n" +
		"function getActorY(tag) return getProperty(tag .. '.y') end\n" +
		"function getActorAngle(tag) return getProperty(tag .. '.angle') end\n" +
		"function getActorAlpha(tag) return getProperty(tag .. '.alpha') end\n" +
		"function getActorWidth(tag) return getProperty(tag .. '.width') end\n" +
		"function getActorHeight(tag) return getProperty(tag .. '.height') end\n" +
		"function setActorVelocityX(x, tag) setProperty(tag .. '.velocity.x', x) end\n" +
		"function setActorVelocityY(y, tag) setProperty(tag .. '.velocity.y', y) end\n" +
		"function setActorAccelerationX(x, tag) setProperty(tag .. '.acceleration.x', x) end\n" +
		"function setActorAccelerationY(y, tag) setProperty(tag .. '.acceleration.y', y) end\n" +
		"function setActorDragX(x, tag) setProperty(tag .. '.drag.x', x) end\n" +
		"function setActorDragY(y, tag) setProperty(tag .. '.drag.y', y) end\n" +
		"function screenShake(intensity, steps) cameraShake('camGame', intensity, (steps or 4) * (stepCrochet * 0.001)) end\n\n" +
		"-- runHaxeCode Polyfills for functions missing in Psych Engine\n" +
		"function setActorColorTrans(tag, r, g, b)\n" +
		"    runHaxeCode(string.format([[\n" +
		"        var obj = game.getLuaObject('%s');\n" +
		"        if (obj == null) { if ('%s' == 'boyfriend') obj = game.boyfriend; else if ('%s' == 'dad') obj = game.dad; else if ('%s' == 'gf') obj = game.gf; }\n" +
		"        if (obj != null) obj.setColorTransform(0, 0, 0, 1, %d, %d, %d, 0);\n" +
		"    ]], tag, tag, tag, tag, r, g, b))\n" +
		"end\n\n" +
		"function resetActorColorTrans(tag)\n" +
		"    runHaxeCode(string.format([[\n" +
		"        var obj = game.getLuaObject('%s');\n" +
		"        if (obj == null) { if ('%s' == 'boyfriend') obj = game.boyfriend; else if ('%s' == 'dad') obj = game.dad; else if ('%s' == 'gf') obj = game.gf; }\n" +
		"        if (obj != null) obj.setColorTransform(1, 1, 1, 1, 0, 0, 0, 0);\n" +
		"    ]], tag, tag, tag, tag))\n" +
		"end\n\n" +
		"function tweenActorColorTrans(tag, r1, g1, b1, r2, g2, b2, time, onComplete)\n" +
		"    runHaxeCode(string.format([[\n" +
		"        var obj = game.getLuaObject('%s');\n" +
		"        if (obj == null) { if ('%s' == 'boyfriend') obj = game.boyfriend; else if ('%s' == 'dad') obj = game.dad; else if ('%s' == 'gf') obj = game.gf; }\n" +
		"        if (obj != null) {\n" +
		"            flixel.tweens.FlxTween.num(0, 1, %f, {\n" +
		"                ease: flixel.tweens.FlxEase.circIn,\n" +
		"                onUpdate: function(t) {\n" +
		"                    var s = t.scale;\n" +
		"                    obj.setColorTransform(0, 0, 0, 1, Std.int(%d + (%d - %d) * s), Std.int(%d + (%d - %d) * s), Std.int(%d + (%d - %d) * s), 0);\n" +
		"                },\n" +
		"                onComplete: function(t) {\n" +
		"                    var cb = '%s';\n" +
		"                    if (cb != '' && cb != 'nil') game.callOnLuas(cb, ['%s']);\n" +
		"                }\n" +
		"            });\n" +
		"        }\n" +
		"    ]], tag, tag, tag, tag, time, r1, r2, r1, g1, g2, g1, b1, b2, b1, onComplete or '', tag))\n" +
		"end\n" +
		"-- --------------------------------------------------------------------\n\n";

	public static function convert(source:String):ConversionResult {
		if (source == null || source.trim() == "") return new ConversionResult("", "", []);

		var lines:Array<String> = source.split("\n");
		var outLines:Array<String> = [];
		var entries:Array<ConversionEntry> = [];
		var usesLeatherBridge = false;

		for (i in 0...lines.length) {
			var line:String = lines[i];
			var trimmed:String = line.trim();

			// Skip comment lines
			if (trimmed.startsWith("--")) {
				outLines.push(line);
				continue;
			}

			var lineNum = i + 1;

			// Check hooks
			for (hook in HOOK_REPLACEMENTS) {
				if (hook.regex.match(line)) {
					line = hook.regex.replace(line, hook.replacement);
					entries.push(new ConversionEntry(lineNum, hook.original, hook.replacement, "Lifecycle hook mapping"));
				}
			}

			// Check direct aliases with word boundaries
			for (orig => rep in DIRECT_ALIASES) {
				var reg = new EReg('\\b' + orig + '\\b', 'g');
				if (reg.match(line)) {
					line = reg.replace(line, rep);
					entries.push(new ConversionEntry(lineNum, orig, rep, 'Direct function alias'));
				}
			}

			// Check if any Leather-specific function is used to include the bridge
			if (!usesLeatherBridge) {
				if (line.indexOf("setActor") != -1 || line.indexOf("getActor") != -1
					|| line.indexOf("screenShake") != -1 || line.indexOf("ColorTrans") != -1) {
					usesLeatherBridge = true;
				}
			}

			outLines.push(line);
		}

		// Prepend bridge header if Leather actor/trans functions were used
		if (usesLeatherBridge) {
			outLines.unshift(PSYCH_BRIDGE_HEADER);
			entries.unshift(new ConversionEntry(1, "[Bridge]", "Psych Compatibility Bridge", "Added clean Lua polyfill header for Leather functions using Psych API & runHaxeCode"));
		}

		return new ConversionResult(source, outLines.join("\n"), entries);
	}
}
