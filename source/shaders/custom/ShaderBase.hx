package shaders.custom;

import flixel.addons.display.FlxRuntimeShader;
import openfl.display3D._internal.GLProgram;
import openfl.display3D._internal.GLShader;
import lime.utils.Assets;
import haxe.ds.StringMap;


/**
 * Enhanced shader base with GL program caching, #import directives,
 * and #pragma header/body expansion.
 *
 * Features from CodenameEngine's FunkinShader adapted for this engine.
 */
@:access(openfl.display.Shader)
@:access(openfl.display3D.Context3D)
@:access(openfl.display3D.Program3D)
@:access(openfl.display.ShaderInput)
@:access(openfl.display.ShaderParameter)
class ShaderBase extends FlxRuntimeShader {
	private static var FRAGMENT_SHADER:Int = 0;
	private static var VERTEX_SHADER:Int = 1;

	public var glslVer:String = "120";
	public var shaderPrefix:String = "";
	public var fragmentPrefix:String = "";
	public var vertexPrefix:String = "";

	public var fragFileName:String = "";
	public var vertFileName:String = "";

	// Cached raw sources before processing (for debugging)
	private var glRawFragmentSource:String;
	private var glRawVertexSource:String;

	// Static GL program cache shared across all ShaderBase instances
	private static var glProgramCache:StringMap<GLProgram> = new StringMap();

	// Performance tracking
	private static var cacheHits:Int = 0;
	private static var cacheMisses:Int = 0;
	private static var totalCompilations:Int = 0;
	private static var activeShaders:Int = 0;
	private static var lastStatsTime:Float = 0;

	static var IMPORT_REGEX:EReg = ~/#import\s+<(.*)>/;

	/**
	 * Creates a new shader.
	 * @param frag Fragment GLSL source (null = default)
	 * @param vert Vertex GLSL source (null = default)
	 * @param glslVer GLSL version string (default "120")
	 */
	public override function new(?frag:String, ?vert:String, ?glslVer:String) {
		if (glslVer == null) glslVer = "120";
		this.glslVer = glslVer;

		if (frag == null) frag = ShaderTemplates.defaultFragmentSource;
		if (vert == null) vert = ShaderTemplates.defaultVertexSource;

		// Set sources before super() to process imports/pragma via our setters.
		// super() will also set them, but our setters check for changes
		// and won't mark __glSourceDirty if the processed value is identical.
		this.glFragmentSource = frag;
		this.glVertexSource = vert;

		super(frag, vert);
		activeShaders++;
	}

	// ─── #import Directive Processing ──────────────────────────────────────

	/**
	 * Processes #import <path> directives by inlining GLSL from assets/shaders/.
	 * Supports nested imports.
	 */
	private function processImports(value:String, type:Int):String {
		var importCount:Int = 0;
		var maxDepth:Int = 10; // prevent infinite recursion
		while (IMPORT_REGEX.match(value) && maxDepth-- > 0) {
			var importPath:String = IMPORT_REGEX.matched(1);
			var importSource:String = null;

			try {
				if (Assets.exists("assets/shaders/" + importPath))
					importSource = Assets.getText("assets/shaders/" + importPath);
				else if (Assets.exists(importPath))
					importSource = Assets.getText(importPath);
			} catch (e:Dynamic) {
				importSource = null;
			}

			if (importSource == null) {
				var fileName:String = type == FRAGMENT_SHADER ? fragFileName : vertFileName;
				trace('[ShaderBase] ERROR: Failed to import "${importPath}" in ${fileName}', ERROR);
			} else {
				value = value.replace(IMPORT_REGEX.matched(0), importSource);
				importCount++;
			}
		}
		if (importCount > 0) {
			var fileName:String = type == FRAGMENT_SHADER ? fragFileName : vertFileName;
		}
		return value;
	}

	// ─── #pragma header/body Expansion ─────────────────────────────────────

	/**
	 * Expands #pragma header and #pragma body with Flixel-compatible GLSL.
	 */
	private function processPragmas(value:String, isVertex:Bool):String {
		var useBackCompat:Bool = true;

		if (isVertex) {
			for (regex in ShaderTemplates.vertBackCompatVarList) {
				if (!regex.match(value)) {
					useBackCompat = false;
					break;
				}
			}

			var header:String = useBackCompat ? ShaderTemplates.vertHeaderBackCompat : ShaderTemplates.vertHeader;
			var body:String = useBackCompat ? ShaderTemplates.vertBodyBackCompat : ShaderTemplates.vertBody;

			value = value.replace("#pragma header", header);
			value = value.replace("#pragma body", body);
		} else {
			value = value.replace("#pragma header", ShaderTemplates.fragHeader);
			value = value.replace("#pragma body", ShaderTemplates.fragBody);
		}

		return value;
	}

	// ─── Source Setters with Processing ────────────────────────────────────

	@:noCompletion override private function set_glFragmentSource(value:String):String {
		if (value == null) value = ShaderTemplates.defaultFragmentSource;

		glRawFragmentSource = value;
		value = processImports(value, FRAGMENT_SHADER);
		value = processPragmas(value, false);

		if (value != __glFragmentSource) {
			__glSourceDirty = true;
		}

		return __glFragmentSource = value;
	}

	@:noCompletion override private function set_glVertexSource(value:String):String {
		if (value == null) value = ShaderTemplates.defaultVertexSource;

		glRawVertexSource = value;
		value = processImports(value, VERTEX_SHADER);
		value = processPragmas(value, true);

		if (value != __glVertexSource) {
			__glSourceDirty = true;
		}

		return __glVertexSource = value;
	}

	// ─── GL Program Caching ────────────────────────────────────────────────

	@:noCompletion private override function __initGL():Void {
		if (__glSourceDirty || __paramBool == null) {
			__glSourceDirty = false;
			program = null;

			__inputBitmapData = new Array();
			__paramBool = new Array();
			__paramFloat = new Array();
			__paramInt = new Array();

			__processGLData(glVertexSource, "attribute");
			__processGLData(glVertexSource, "uniform");
			__processGLData(glFragmentSource, "uniform");
		}

		if (__context != null && program == null) {
			var prefixBuf = new StringBuf();
			var gl = __context.gl;
			openfl.display.Shader.__detectGLContext(gl);
			var compatVer:String = openfl.display.Shader.__getCompatibleGLSLVersion(glslVer);
			prefixBuf.add('#version ${compatVer}\n');
			prefixBuf.add(shaderPrefix);

			var gl = __context.gl;

			prefixBuf.add("#ifdef GL_ES\n");
			if (precisionHint == FULL) {
				prefixBuf.add("#ifdef GL_FRAGMENT_PRECISION_HIGH\n");
				prefixBuf.add("precision highp float;\n");
				prefixBuf.add("#else\n");
				prefixBuf.add("precision mediump float;\n");
				prefixBuf.add("#endif\n");
			} else {
				prefixBuf.add("precision lowp float;\n");
			}
			prefixBuf.add("#endif\n");

			var prefix:String = prefixBuf.toString();
			var vertex:String = prefix + vertexPrefix + glVertexSource;
			var fragment:String = prefix + fragmentPrefix + glFragmentSource;

			// Ensure all varyings declared in fragment shader are also declared and written in vertex shader to prevent GL link failures
			var varyingRegex:EReg = ~/\bvarying\s+([a-zA-Z0-9_]+)\s+([a-zA-Z0-9_]+)\s*;/;
			var tempFrag:String = fragment;
			var missingVaryings:Array<{type:String, name:String}> = [];
			while (varyingRegex.match(tempFrag)) {
				var vType:String = varyingRegex.matched(1);
				var vName:String = varyingRegex.matched(2);
				if (vertex.indexOf(vName) == -1) {
					missingVaryings.push({type: vType, name: vName});
				}
				tempFrag = varyingRegex.matchedRight();
			}

			if (missingVaryings.length > 0) {
				var decls:String = "";
				var inits:String = "";
				for (mv in missingVaryings) {
					decls += 'varying ${mv.type} ${mv.name};\n';
					var defaultVal:String = switch (mv.type) {
						case "float": "0.0";
						case "vec2": "vec2(0.0)";
						case "vec3": "vec3(0.0)";
						case "vec4": "vec4(0.0)";
						case "int": "0";
						case "ivec2": "ivec2(0)";
						case "ivec3": "ivec3(0)";
						case "ivec4": "ivec4(0)";
						case "mat2": "mat2(1.0)";
						case "mat3": "mat3(1.0)";
						case "mat4": "mat4(1.0)";
						default: '${mv.type}(0.0)';
					};
					inits += '${mv.name} = $defaultVal;\n\t';
				}
				vertex = prefix + decls + vertexPrefix + glVertexSource;
				if (vertex.indexOf("main()") != -1 || vertex.indexOf("main ()") != -1) {
					var mainIdx:Int = vertex.indexOf("{", vertex.indexOf("main"));
					if (mainIdx != -1) {
						vertex = vertex.substring(0, mainIdx + 1) + "\n\t" + inits + vertex.substring(mainIdx + 1);
					}
				}
			}

			// GL Program Cache - reuse compiled programs by source key
			var cacheKey:String = vertex + fragment;

			if (glProgramCache.exists(cacheKey)) {
				cacheHits++;
				program = __context.createProgram(GLSL);
				program.__glProgram = glProgramCache.get(cacheKey);
			} else {
				cacheMisses++;
				totalCompilations++;
				program = __context.createProgram(GLSL);
				program.__glProgram = __createGLProgram(vertex, fragment);

				if (program.__glProgram != null) {
					glProgramCache.set(cacheKey, program.__glProgram);
				}
			}

			if (program != null) {
				glProgram = program.__glProgram;

				for (input in __inputBitmapData) {
					if (input.__isUniform) {
						input.index = gl.getUniformLocation(glProgram, input.name);
					} else {
						input.index = gl.getAttribLocation(glProgram, input.name);
					}
				}

				for (parameter in __paramBool) {
					if (parameter.__isUniform) {
						parameter.index = gl.getUniformLocation(glProgram, parameter.name);
					} else {
						parameter.index = gl.getAttribLocation(glProgram, parameter.name);
					}
				}

				for (parameter in __paramFloat) {
					if (parameter.__isUniform) {
						parameter.index = gl.getUniformLocation(glProgram, parameter.name);
					} else {
						parameter.index = gl.getAttribLocation(glProgram, parameter.name);
					}
				}

				for (parameter in __paramInt) {
					if (parameter.__isUniform) {
						parameter.index = gl.getUniformLocation(glProgram, parameter.name);
					} else {
						parameter.index = gl.getAttribLocation(glProgram, parameter.name);
					}
				}
			}
		}
	}

	// ─── GL Shader Compilation with Error Reporting ────────────────────────

	static var ERROR_POS_REGEX:EReg = ~/(\d+):(\d+): (.*)/g;
	static var ERROR_REGEX:EReg = ~/ERROR: (\d+):(\d+): (.*)/g;
	static var ERROR_REGEX_2:EReg = ~/(\d+)\((\d+)\) : error ([^:]+): (.*)/g;

	@:noCompletion private override function __createGLShader(source:String, type:Int):GLShader {
		var gl = __context.gl;
		var shader = gl.createShader(type);

		gl.shaderSource(shader, source);
		gl.compileShader(shader);

		var shaderInfoLog:String = gl.getShaderInfoLog(shader);
		var hasInfoLog:Bool = shaderInfoLog != null && shaderInfoLog.trim() != "";
		var compileStatus:Int = gl.getShaderParameter(shader, gl.COMPILE_STATUS);

		if (hasInfoLog || compileStatus == 0) {
			var isVertexShader:Bool = type == gl.VERTEX_SHADER;
			var msgBuf = new StringBuf();

			msgBuf.add((compileStatus == 0) ? "Shader Error" : "Shader Info");
			msgBuf.add(isVertexShader ? " (vertex)" : " (fragment)");
			if (fragFileName.length > 0) msgBuf.add(' [${isVertexShader ? vertFileName : fragFileName}]');
			msgBuf.add("\n");

			// Parse error positions
			var errorPositions:Array<{line:String, col:String, msg:String}> = [];
			var tmp:String = shaderInfoLog;

			if (shaderInfoLog.contains(" : error ")) {
				while (ERROR_REGEX_2.match(tmp)) {
					errorPositions.push({line: ERROR_REGEX_2.matched(2), col: ERROR_REGEX_2.matched(1), msg: ERROR_REGEX_2.matched(4)});
					tmp = ERROR_REGEX_2.matchedRight();
				}
			} else if (shaderInfoLog.contains("ERROR: ")) {
				while (ERROR_REGEX.match(tmp)) {
					errorPositions.push({line: ERROR_REGEX.matched(1), col: ERROR_REGEX.matched(2), msg: ERROR_REGEX.matched(3)});
					tmp = ERROR_REGEX.matchedRight();
				}
			} else {
				while (ERROR_POS_REGEX.match(tmp)) {
					errorPositions.push({line: ERROR_POS_REGEX.matched(1), col: ERROR_POS_REGEX.matched(2), msg: ERROR_POS_REGEX.matched(3)});
					tmp = ERROR_POS_REGEX.matchedRight();
				}
			}

			var splitSource:Array<String> = source.split("\n");
			for (error in errorPositions) {
				msgBuf.add("ERROR: Line " + error.line);
				if (Std.parseInt(error.col) > 0) msgBuf.add(", Col " + error.col);
				msgBuf.add(": " + error.msg);
				var lineNum = Std.parseInt(error.line);
				if (lineNum != null && lineNum < splitSource.length) {
					msgBuf.add("\n  -> " + splitSource[lineNum - 1].trim());
				}
				msgBuf.add("\n\n");
			}

			if (errorPositions.length == 0) {
				msgBuf.add(shaderInfoLog);
				msgBuf.add("\n");
			}

			if (compileStatus == 0) {
				trace(msgBuf.toString(), ERROR);
			} else {
				trace(msgBuf.toString());
			}
		}

		return shader;
	}

	@:noCompletion private override function __createGLProgram(vertexSource:String, fragmentSource:String):GLProgram {
		var program:GLProgram = null;

		try {
			var gl = __context.gl;

			var vertexShader:GLShader = __createGLShader(vertexSource, gl.VERTEX_SHADER);
			var fragmentShader:GLShader = __createGLShader(fragmentSource, gl.FRAGMENT_SHADER);

			program = gl.createProgram();

			// Fix for drivers that don't draw if attribute 0 is disabled
			for (param in __paramFloat) {
				if (param.name.indexOf("Position") > -1 && StringTools.startsWith(param.name, "openfl_")) {
					gl.bindAttribLocation(program, 0, param.name);
					break;
				}
			}

			gl.attachShader(program, vertexShader);
			gl.attachShader(program, fragmentShader);
			gl.linkProgram(program);

			if (gl.getProgramParameter(program, gl.LINK_STATUS) == 0) {
				trace("Shader link error: " + gl.getProgramInfoLog(program), ERROR);
			}
		} catch (e:Dynamic) {
			trace('[ShaderBase] Failed to compile program: ${e}', ERROR);
		}

		return program;
	}

	// ─── Static Cache Management ───────────────────────────────────────────

	/**
	 * Clears the GL program cache. Call on state switches to free GPU memory.
	 */
	public static function clearProgramCache():Void {
		var oldSize = getCachedProgramCount();
		glProgramCache = new StringMap();
		trace('[ShaderBase] Cache CLEARED (freed ${oldSize} programs, hits=${cacheHits} misses=${cacheMisses} compilations=${totalCompilations})');
		cacheHits = 0;
		cacheMisses = 0;
		totalCompilations = 0;
	}

	/**
	 * Returns the number of cached GL programs.
	 */
	public static function getCachedProgramCount():Int {
		var count = 0;
		for (_ in glProgramCache) count++;
		return count;
	}

	/**
	 * Returns performance stats summary string.
	 */
	public static function getStatsSummary():String {
		var hitRate:Float = (cacheHits + cacheMisses > 0) ? (cacheHits / (cacheHits + cacheMisses) * 100) : 0;
		return '[ShaderBase Stats] active=${activeShaders} cached=${getCachedProgramCount()} hits=${cacheHits} misses=${cacheMisses} hitRate=${Std.string(hitRate)}% compilations=${totalCompilations}';
	}

	/**
	 * Prints performance stats to trace.
	 */
	public static function printStats():Void {
		trace(getStatsSummary());
	}

	public static function decrementActiveShaders():Void {
		activeShaders--;
	}
}
