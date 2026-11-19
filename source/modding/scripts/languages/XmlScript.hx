package modding.scripts.languages;

#if LUA_ALLOWED
import shaders.custom.CustomShader;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import flixel.FlxG;
import lime.app.Application;
import lime.utils.Assets;
import openfl.filters.ShaderFilter;
import openfl.display.ShaderParameter;
import states.PlayState;
import game.Conductor;


private typedef ScheduledEvent = {
	var step:Null<Int>;
	var beat:Null<Int>;
	var time:Null<Float>;
	var triggered:Bool;
	var actions:Array<Void->Void>;
}

class XmlScript extends Script {
	static inline final PREFIX:String = "[XML SCRIPT]";

	public static var xmlVariables:Map<String, Dynamic> = new Map();

	private var events:Array<ScheduledEvent> = [];
	private var shaderTimes:Map<String, Map<String, Float>> = [];

	public function new(path:String, executeOn:ExecuteOn = BOTH) {
		super(path, executeOn);

		try {
			var content:String = sys.FileSystem.exists(path)
				? sys.io.File.getContent(path)
				: Assets.getText(path);
			var root:Xml = Xml.parse(content).firstElement();

			if (root == null) {
				trace('$PREFIX Error: empty document', ERROR);
				return;
			}
			if (root.nodeName.toLowerCase() != "modchart") {
				trace('$PREFIX Error: root must be <Modchart>, got <${root.nodeName}>', ERROR);
				return;
			}

			for (child in root.elements()) {
				switch (child.nodeName.toLowerCase()) {
					case "init":     parseInit(child);
					case "events":   parseEvents(child);
			case "shader":   parseShader(child);
		}
			}
		} catch (e:Dynamic) {
			trace('$PREFIX Parse error: $e', ERROR);
		}
	}

	// ── Init ─────────────────────────────────────────────────────────

	function parseInit(container:Xml) {
		for (child in container.elements()) {
			switch (child.nodeName.toLowerCase()) {
				case "shader":   parseShader(child);
			}
		}
	}

	// ── Shader ───────────────────────────────────────────────────────

	function parseShader(elem:Xml) {
		if (!Options.getData("shaders")) return;

		var name:String  = elem.get("name");
		var shader:String = elem.exists("shader") ? elem.get("shader") : null;

		if (name == null || name == "") {
			trace('$PREFIX WARNING: Missing required attribute "name" in <Shader>', WARNING);
			return;
		}
		if (shader == null) {
			trace('$PREFIX WARNING: Missing required attribute "shader" in <Shader name="$name">', WARNING);
			return;
		}

		var _frag:String = Assets.exists(Paths.frag(shader)) ? Assets.getText(Paths.frag(shader)) : (sys.FileSystem.exists('mods/' + utilities.Options.getData("curMod") + '/shaders/' + shader + '.frag') ? sys.io.File.getContent('mods/' + utilities.Options.getData("curMod") + '/shaders/' + shader + '.frag') : null);
		if (_frag == null) {
			trace('$PREFIX WARNING: Shader source "$shader" not found (no file ${shader}.frag)', WARNING);
			return;
		}

		var vert:String = Assets.exists(Paths.vert(shader))
			? Assets.getText(Paths.vert(shader)) : (sys.FileSystem.exists('mods/' + utilities.Options.getData("curMod") + '/shaders/' + shader + '.vert') ? sys.io.File.getContent('mods/' + utilities.Options.getData("curMod") + '/shaders/' + shader + '.vert') : null);
		var cs = new CustomShader(_frag, vert);
		cs.fragFileName = shader + ".frag";
		cs.vertFileName = shader + ".vert";
		LuaScript.lua_Custom_Shaders.set(name, cs);

		// Parse <Property> children (case-insensitive)
		for (prop in elem.elements()) {
			if (prop.nodeName.toLowerCase() != "property") continue;
			var pname:String = prop.get("name");
			var pval:String  = prop.get("value");
			if (pname == null || pval == null) continue;
			applyShaderProp(name, pname, pval);
		}

		// Camera assignment
		var camGame:Bool  = elem.exists("camGame")  && elem.get("camGame")  == "true";
		var camHUD:Bool   = elem.exists("camHUD")   && elem.get("camHUD")   == "true";
		var camOther:Bool = elem.exists("camOther") && elem.get("camOther") == "true";

		var camIds:Array<String> = [];
		if (camGame)  camIds.push("game");
		if (camHUD)   camIds.push("hud");
		if (camOther) camIds.push("other");

		for (camId in camIds) {
			ensureCamera(camId);
			var cd = LuaScript.lua_Cameras.get(camId);
			if (cd == null) continue;

			var cs:CustomShader = LuaScript.lua_Custom_Shaders.get(name);
			if (cs != null) {
				cd.shaders.push(new ShaderFilter(cs));
				cd.shaderNames.push(name);
				cd.cam.filters = cd.shaders;
			} else {
				trace('$PREFIX WARNING: Shader instance \'$name\' not found in lua_Custom_Shaders', WARNING);
			}
		}
	}

	// Shared shader property setter (used by both Init and Events)
	function applyShaderProp(shaderName:String, prop:String, rawValue:String) {
		var shader:CustomShader = LuaScript.lua_Custom_Shaders.get(shaderName);
		if (shader == null) {
			if (Options.getData("shaders"))
				trace('$PREFIX WARNING: Shader instance "$shaderName" does not exist', WARNING);
			return;
		}

		var fv:Float = Std.parseFloat(rawValue);
		if (!Math.isNaN(fv)) {
			var ip:ShaderParameter<Int> = Reflect.field(shader.data, prop);
			if (ip != null)
				shader.setInt(prop, Std.parseInt(rawValue));
			else
				shader.setFloat(prop, fv);

			var propLow = prop.toLowerCase();
			if (propLow == "itime" || propLow == "utime") {
				if (!shaderTimes.exists(shaderName))
					shaderTimes.set(shaderName, []);
				shaderTimes.get(shaderName).set(prop, fv);
			}
			return;
		}
		if (rawValue == "true" || rawValue == "false") {
			shader.setBool(prop, rawValue == "true");
			return;
		}
		if (rawValue.indexOf(",") != -1) {
			var floats:Array<Float> = [for (p in rawValue.split(",")) Std.parseFloat(p.trim())];
			shader.setFloatArray(prop, floats);
			return;
		}
		if (rawValue.startsWith("#") || rawValue.startsWith("0x")) {
			var c:FlxColor = FlxColor.fromString(rawValue);
			shader.setFloatArray(prop, [c.redFloat, c.greenFloat, c.blueFloat, 1.0]);
			return;
		}
		trace('$PREFIX WARNING: Invalid float value "$rawValue" for property "$prop"', WARNING);
	}

	// ── Events ───────────────────────────────────────────────────────

	function parseEvents(container:Xml) {
		for (elem in container.elements()) {
			if (elem.nodeName.toLowerCase() != "event") continue;

			var step:Null<Int>   = elem.exists("step") ? Std.parseInt(elem.get("step")) : null;
			var beat:Null<Int>   = elem.exists("beat") ? Std.parseInt(elem.get("beat")) : null;
			var time:Null<Float> = null;

			// time is a trigger only when step and beat are absent
			if (step == null && beat == null)
				time = elem.exists("time") ? Std.parseFloat(elem.get("time")) : null;
			if (step == null && beat == null && time == null)
				step = 0;

			var actions:Array<Void->Void> = [];

			// Attribute-based action (Modchart Editor format)
			if (elem.exists("type"))
				actions.push(buildInlineAction(elem));

			// Child-element actions (backward compat)
			for (child in elem.elements()) {
				var fn:Void->Void = buildChildAction(child);
				if (fn != null) actions.push(fn);
			}

			if (actions.length > 0) {
				events.push({
					step: step, beat: beat, time: time,
					triggered: false, actions: actions
				});
			}
		}
	}

	// Action from Event attributes: <Event type="..." name="..." .../>
	function buildInlineAction(elem:Xml):Void->Void {
		var type:String = elem.get("type").toLowerCase();
		var name:String = elem.exists("name") ? elem.get("name") : elem.get("id");
		var easeStr:String = elem.exists("ease") ? elem.get("ease") : "linear";

		// time/duration in steps, converted to seconds
		var durSteps:Float = 1.0;
		if (elem.exists("time"))     durSteps = Std.parseFloat(elem.get("time"));
		if (elem.exists("duration")) durSteps = Std.parseFloat(elem.get("duration"));

		return switch (type) {
			case "tweenshaderproperty":
				var prop   = elem.get("property");
				var value  = Std.parseFloat(elem.get("value"));
				var start  = elem.exists("startValue") ? Std.parseFloat(elem.get("startValue")) : null;
				function() {
					var s = LuaScript.lua_Custom_Shaders.get(name);
					if (s == null) {
						if (Options.getData("shaders"))
							trace('$PREFIX WARNING: Shader instance "$name" does not exist', WARNING);
						return;
					}
					if (start != null) s.setFloat(prop, start);
					s.tween(prop, value, stepsToSec(durSteps), resolveEase(easeStr), 0);
				};

			case "setshaderproperty":
				var prop  = elem.get("property");
				var value = elem.get("value");
				function() applyShaderProp(name, prop, value);

			case "addcamerazoom":
				var value = elem.exists("value") ? Std.parseFloat(elem.get("value")) : 0.015;
				function() {
					var ps = PlayState.instance;
					if (ps == null) return;
					if (ps.cameraZooms && ((FlxG.camera.zoom < 1.35 && ps.camZooming) || !ps.camZooming)) {
						if (!Math.isNaN(value))
							FlxG.camera.zoom += value * ps.cameraZoomStrength;
					}
				};

			case "addhudzoom":
				var value = elem.exists("value") ? Std.parseFloat(elem.get("value")) : 0.03;
				function() {
					var ps = PlayState.instance;
					if (ps == null) return;
					if (ps.cameraZooms) {
						if (!Math.isNaN(value))
							ps.camHUD.zoom += value * ps.cameraZoomStrength;
					}
				};

			case "setcamerazoom":
				var gameZoom = elem.exists("value") ? Std.parseFloat(elem.get("value")) : null;
				var hudZoom  = elem.exists("hudValue") ? Std.parseFloat(elem.get("hudValue")) : 1.0;
				function() {
					var ps = PlayState.instance;
					if (ps == null) return;
					if (gameZoom != null && !Math.isNaN(gameZoom))
						ps.defaultCamZoom = gameZoom;
					if (!Math.isNaN(hudZoom))
						ps.defaultHudCamZoom = hudZoom;
				};

			case "setnoteeffect":
				var effectName = elem.exists("effect") ? elem.get("effect") : name;
				var prop = elem.exists("property") ? elem.get("property") : "alpha";
				var rawValue = elem.exists("value") ? elem.get("value") : "1";
				function() {
					var ps = PlayState.instance;
					if (ps == null) return;
					// Store note effect in LuaScript for note rendering
					var key = 'noteEffect_${effectName}_$prop';
					XmlScript.xmlVariables.set(key, rawValue);
				};

			case "tweennoteeffect":
				var effectName = elem.exists("effect") ? elem.get("effect") : name;
				var prop = elem.exists("property") ? elem.get("property") : "alpha";
				var value = Std.parseFloat(elem.get("value"));
				var startVal = elem.exists("startValue") ? Std.parseFloat(elem.get("startValue")) : null;
				var ease = resolveEase(easeStr);
				var dur = stepsToSec(durSteps);
				function() {
					var ps = PlayState.instance;
					if (ps == null) return;
					// Tween note effect via LuaScript bridge
					var key = 'noteEffect_${effectName}_$prop';
					var start = startVal != null ? startVal : 0.0;
					XmlScript.xmlVariables.set(key, start);
					// Store tween info for update loop
					var tweenKey = 'noteEffectTween_${effectName}_$prop';
					XmlScript.xmlVariables.set(tweenKey, {
						from: start, to: value, duration: dur, ease: ease, elapsed: 0.0
					});
				};

			case "setcameraeffect":
				var effectName = elem.exists("effect") ? elem.get("effect") : name;
				var prop = elem.exists("property") ? elem.get("property") : "strength";
				var rawValue = elem.exists("value") ? elem.get("value") : "0";
				function() {
					var shader:CustomShader = LuaScript.lua_Custom_Shaders.get(effectName);
					if (shader != null) {
						applyShaderProp(effectName, prop, rawValue);
					}
				};

			case "tweencameraeffect":
				var effectName = elem.exists("effect") ? elem.get("effect") : name;
				var prop = elem.exists("property") ? elem.get("property") : "strength";
				var value = Std.parseFloat(elem.get("value"));
				var startVal = elem.exists("startValue") ? Std.parseFloat(elem.get("startValue")) : null;
				function() {
					var shader:CustomShader = LuaScript.lua_Custom_Shaders.get(effectName);
					if (shader != null) {
						if (startVal != null) shader.setFloat(prop, startVal);
						shader.tween(prop, value, stepsToSec(durSteps), resolveEase(easeStr), 0);
					}
				};

			default:
				trace('$PREFIX WARNING: Unknown event type "${elem.get("type")}"', WARNING);
				function() {};
		};
	}

	// Action from child elements: <Event><TweenShader .../></Event>
	function buildChildAction(elem:Xml):Void->Void {
		var tag:String = elem.nodeName.toLowerCase();
		var name:String = elem.exists("name") ? elem.get("name") : elem.get("id");

		return switch (tag) {
			case "tweenshader" | "tweenshaderproperty":
				var prop  = elem.get("property");
				var to    = Std.parseFloat(elem.get("to"));
				var durSteps = elem.exists("duration") ? Std.parseFloat(elem.get("duration")) : 1.0;
				var ease  = resolveEase(elem.exists("ease") ? elem.get("ease") : "linear");
				var delay = elem.exists("delay") ? Std.parseFloat(elem.get("delay")) : 0.0;
				delay /= PlayState.songMultiplier;
				function() {
					var s = LuaScript.lua_Custom_Shaders.get(name);
					if (s != null) s.tween(prop, to, stepsToSec(durSteps), ease, delay);
				};

			case "setshader" | "setshaderproperty":
				var prop = elem.get("property");
				var val  = elem.get("value");
				function() applyShaderProp(name, prop, val);

			case "addcamerazoom":
				var value = elem.exists("value") ? Std.parseFloat(elem.get("value")) : 0.015;
				function() {
					var ps = PlayState.instance;
					if (ps == null) return;
					if (ps.cameraZooms && ((FlxG.camera.zoom < 1.35 && ps.camZooming) || !ps.camZooming)) {
						if (!Math.isNaN(value))
							FlxG.camera.zoom += value * ps.cameraZoomStrength;
					}
				};

			case "addhudzoom":
				var value = elem.exists("value") ? Std.parseFloat(elem.get("value")) : 0.03;
				function() {
					var ps = PlayState.instance;
					if (ps == null) return;
					if (ps.cameraZooms) {
						if (!Math.isNaN(value))
							ps.camHUD.zoom += value * ps.cameraZoomStrength;
					}
				};

			case "setcamerazoom":
				var gameZoom = elem.exists("value") ? Std.parseFloat(elem.get("value")) : null;
				var hudZoom  = elem.exists("hudValue") ? Std.parseFloat(elem.get("hudValue")) : 1.0;
				function() {
					var ps = PlayState.instance;
					if (ps == null) return;
					if (gameZoom != null && !Math.isNaN(gameZoom))
						ps.defaultCamZoom = gameZoom;
					if (!Math.isNaN(hudZoom))
						ps.defaultHudCamZoom = hudZoom;
				};

			default:
				function() {};
		};
	}

	// ── Helpers ──────────────────────────────────────────────────────

	inline function stepsToSec(steps:Float):Float {
		return ((steps * Conductor.stepCrochet) / 1000.0) / PlayState.songMultiplier;
	}

	function resolveEase(name:String):Float->Float {
		var fn = LuaScript.easeFromString(name);
		if (fn == FlxEase.linear && name.toLowerCase().trim() != "linear")
			trace('$PREFIX WARNING: Unknown ease "$name", using linear', WARNING);
		return fn;
	}

	function ensureCamera(camId:String) {
		switch (camId) {
			case "camGame" | "game":
				if (!LuaScript.lua_Cameras.exists("game"))
					LuaScript.lua_Cameras.set("game", {
						cam: PlayState.instance.camGame, shaders: [], shaderNames: []
					});
			case "camHUD" | "hud":
				if (!LuaScript.lua_Cameras.exists("hud"))
					LuaScript.lua_Cameras.set("hud", {
						cam: PlayState.instance.camHUD, shaders: [], shaderNames: []
					});
			case "camOther" | "other":
				if (!LuaScript.lua_Cameras.exists("other"))
					LuaScript.lua_Cameras.set("other", {
						cam: PlayState.instance.camOther, shaders: [], shaderNames: []
					});
		}
	}

	// ── Lifecycle ────────────────────────────────────────────────────

	override public function call(func:String, ?arguments:Array<Any>):Bool {
		if (arguments == null) arguments = [];

		for (script in otherScripts) {
			var xs:XmlScript = Std.downcast(script, XmlScript);
			if (xs != null) xs.call(func, arguments);
		}

		switch (func) {
			case "stepHit":
				if (arguments.length > 0) {
					var cur:Int = arguments[0];
					for (evt in events) {
						if (!evt.triggered && evt.step != null && cur >= evt.step) {
							evt.triggered = true;
							for (act in evt.actions) act();
						}
					}
				}

			case "beatHit":
				if (arguments.length > 0) {
					var cur:Int = arguments[0];
					for (evt in events) {
						if (!evt.triggered && evt.beat != null && cur >= evt.beat) {
							evt.triggered = true;
							for (act in evt.actions) act();
						}
					}
				}

			case "update":
				var elapsed:Float = arguments.length > 0 ? arguments[0] : 0;
				elapsed *= PlayState.songMultiplier;
				for (shaderName => props in shaderTimes) {
					var shader = LuaScript.lua_Custom_Shaders.get(shaderName);
					if (shader == null) continue;
					for (prop => time in props) {
						time += elapsed;
						props.set(prop, time);
						shader.setFloat(prop, time);
					}
				}
				for (evt in events) {
					if (!evt.triggered && evt.time != null && Conductor.songPosition >= evt.time * 1000) {
						evt.triggered = true;
						for (act in evt.actions) act();
					}
				}

			case "create":
				for (evt in events) {
					if (evt.triggered) continue;
					var fire:Bool = (evt.step != null && evt.step == 0)
						|| (evt.beat != null && evt.beat == 0);
					if (fire) {
						evt.triggered = true;
						for (act in evt.actions) act();
					}
				}
		}

		return true;
	}

	override public function setup() {}
	override public function set(variable:String, value:Any) {}

	override public function destroy() {
		events = null;
		for (script in otherScripts) script.destroy();
		otherScripts = null;
	}
}
#end
