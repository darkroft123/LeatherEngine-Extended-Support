package ui;

import flixel.math.FlxMath;
import flixel.FlxSubState;
import haxe.extern.EitherType;
import flixel.group.FlxSpriteContainer;
import flixel.system.debug.log.LogStyle;
#if DISCORD_ALLOWED
import utilities.DiscordClient;
#end
#if MODDING_ALLOWED
import modding.PolymodHandler;
#end
import utilities.NoteVariables;
import lime.app.Application;
import states.TitleState;
import states.MusicBeatState;
import modding.ModList;
import flixel.FlxSprite;
import flixel.FlxState;
import states.OptionsMenu;
import flixel.FlxG;
import ui.ModIcon;
import flixel.util.typeLimit.NextState;
import flixel.tweens.*;
import game.Conductor;
import flixel.input.gamepad.FlxGamepadInputID;
import flixel.input.gamepad.FlxGamepad;
import flixel.FlxCamera;
import states.PlayState;
class Option extends FlxSpriteContainer {
    public var alphabetText(default, null):TextOption;

    public var optionName(default, null):String;
    public var optionValue(default, null):String;
    public var optionDescription(default, null):String;
    public var optionSaveKey(default, null):String;

    public function new(optionName:String, optionValue:String, optionDescription:String = "", optionSaveKey:String = "main") {
        super();

        this.optionName = optionName;
        this.optionValue = optionValue;
        this.optionDescription = optionDescription;
        this.optionSaveKey = optionSaveKey;

        alphabetText = new TextOption(20, 20, optionName, true);
        alphabetText.isMenuItem = true;
        add(alphabetText);
    }

    public function setText(newText:String):Void {
        optionName = newText;
        if (alphabetText != null) {
            alphabetText.text = newText;
        }
    }

    public function getTextOptionWidth():Float {
        return alphabetText.width;
    }

    public function onPress():Void {}

    override public function update(elapsed:Float) {
        super.update(elapsed);
    }
}
class BoolOption extends Option {
    public var checkbox(default, null):Checkbox;
    public var optionChecked(default, null):Bool = false;

    override public function new(optionName:String, optionValue:String, optionDescription:String = "", optionSaveKey:String = "main") {
        super(optionName, optionValue, optionDescription, optionSaveKey);

        alphabetText.color = 0xFF87FAAD;
        alphabetText.isMenuItem = true;

        checkbox = new Checkbox(alphabetText);
        optionChecked = checkbox.checked = getObjectValue();
        add(checkbox);
    }

    public inline function getObjectValue():Bool {
        return Options.getData(optionValue, optionSaveKey);
    }

    override public function onPress():Void {
        changeValue();
    }

    override function update(elapsed:Float) {
        super.update(elapsed);
    }

    public function changeValue() {
        Options.setData(!optionChecked, optionValue, optionSaveKey);

        optionChecked = !optionChecked;
        checkbox.checked = optionChecked;

        switch (optionValue) {
            case "fpsCounter": Main.toggleFPS(optionChecked);
            case "memoryCounter": Main.toggleMem(optionChecked);
            #if DISCORD_ALLOWED
            case "discordRPC":
                if (optionChecked && !DiscordClient.active) {
                    DiscordClient.startup();
                    DiscordClient.loadModPresence();
                } else if (!optionChecked && DiscordClient.active)
                    DiscordClient.shutdown();
            #end
            case "versionDisplay": Main.toggleVers(optionChecked);
            case "developer": Main.toggleLogs(optionChecked);
            case "showCommitHash": Main.toggleCommitHash(optionChecked);
            case "showDiscord": Main.toggleDiscord(optionChecked);
            case "antialiasing":
                for (member in FlxG.state.members) {
                    if (member is FlxSprite) cast(member, FlxSprite).antialiasing = optionChecked;
                }
                FlxSprite.defaultAntialiasing = optionChecked;
            case "vSync": FlxG.stage.window.vsync = optionChecked;
            case "throwExceptionOnError": LogStyle.ERROR.throwException = optionChecked;
        }
    }
}
class PageOption extends Option {
	public var pageName:String = "Categories";

	override public function new(optionName:String, pageName:String = "Categories", optionDescription:String = "") {
		super(optionName, pageName, optionDescription);

		this.pageName = pageName;

		if (alphabetText != null) {
			remove(alphabetText);
			alphabetText.kill();
			alphabetText.destroy();
		}

		alphabetText = new TextOption(20, 20, optionName, true, false, 0xFFE6FF81);
		alphabetText.isMenuItem = true;
		add(alphabetText);
	}

	override public function onPress():Void {
		if (!OptionsMenu.instance.inMenu) {
			OptionsMenu?.instance?.loadPage(pageName ?? "Categories");
		}
	}

	override function update(elapsed:Float) {
		super.update(elapsed);
	}
}

class GameSubStateOption extends Option {
	public var gameSubState:EitherType<NextState, Class<FlxSubState>>;

	public function new(optionName:String, gameSubState:EitherType<NextState, Class<FlxSubState>>, optionDescription:String = "") {
		super(optionName, null, optionDescription);

		this.gameSubState = gameSubState;

		alphabetText.color = 0xFFD181FF;
		alphabetText.isMenuItem = true;
	}

	override public function onPress():Void {
		if (gameSubState is Class) {
			FlxG.state.openSubState(Type.createInstance(cast gameSubState, []));
		} else {
			FlxG.state.openSubState(cast gameSubState);
		}
	}

	override function update(elapsed:Float) {
		super.update(elapsed);
	}
}

class GameStateOption extends Option {
	public var gameState:NextState;

	public function new(optionName:String = "", gameState:EitherType<NextState, Class<FlxState>>, optionDescription:String = "") {
		super(optionName, null, optionDescription);

		this.gameState = gameState;
		alphabetText.isMenuItem = true;
	}

	override public function onPress():Void {
		if (gameState is Class) {
			FlxG.switchState(Type.createInstance(cast this.gameState, []));
		} else {
			FlxG.switchState(cast gameState);
		}
	}

	override function update(elapsed:Float) {
		super.update(elapsed);
	}
}

class CharacterCreatorOption extends GameStateOption {
	public function new(optionName:String = "", gameState:EitherType<NextState, Class<FlxState>>, optionDescription:String = "") {
		super(optionName, gameState, optionDescription);
		toolbox.CharacterCreator.lastState = "OptionsMenu";
	}
}
#if MODDING_ALLOWED
class ModOption extends FlxSpriteContainer {
	public var alphabetText:TextOption;
	public var modIcon:ModIcon;
	public var modEnabled:Bool = false;
	public var optionName:String = "";
	public var optionValue:String = "Unknown Mod";

	public function new(_optionName:String = "", _optionValue:String = "Unknown Mod") {
		super();
		this.optionName = _optionName;
		this.optionValue = _optionValue;

		alphabetText = new TextOption(20, 20, optionName, true);
		alphabetText.isMenuItem = true;
		add(alphabetText);

		modIcon = new ModIcon(optionValue, alphabetText);
		modIcon.sprTracker = alphabetText;
		add(modIcon);

		modEnabled = ModList.modList.get(optionValue);
	}

	override function update(elapsed:Float) {
		super.update(elapsed);

		if (FlxG.keys.justPressed.ENTER && alphabetText.targetY == 0) {
			if (optionValue == Options.getData("curMod")) {
				CoolUtil.coolError("Leather Engine Mods", optionValue + " is your current mod\nPlease switch to a different mod to disable it!");
				FlxTween.color(this, 1, 0xFFFF0000, 0xFFFFFFFF, {ease: FlxEase.quartOut});
			} else {
				modEnabled = !modEnabled;
				ModList.setModEnabled(optionValue, modEnabled);
			}
		}

		alpha = modEnabled ? 1 : 0.6;
	}
}

class ChangeModOption extends FlxSpriteContainer {
	public var alphabetText:TextOption;
	public var modIcon:ModIcon;
	public var modEnabled:Bool = false;
	public var optionName:String = "";
	public var optionValue:String = "Template Mod";

	public function new(_optionName:String = "", _optionValue:String = "") {
		super();
		this.optionName = _optionName;
		this.optionValue = _optionValue;

		alphabetText = new TextOption(20, 20, optionName, true);
		alphabetText.isMenuItem = true;
		alphabetText.scrollFactor.set();
		add(alphabetText);

		modIcon = new ModIcon(optionValue);
		modIcon.sprTracker = alphabetText;
		modIcon.scrollFactor.set();
		add(modIcon);

		modEnabled = ModList.modList.get(optionValue);
	}

	override function update(elapsed:Float) {
		super.update(elapsed);

		if (alphabetText.targetY == 0) {
			alpha = 1;
			if (FlxG.keys.justPressed.ENTER) {
				Options.setData(optionValue, "curMod");
				modEnabled = !modEnabled;
				if (FlxG.state is TitleState)
					TitleState.initialized = false;
				if (FlxG.sound.music != null) {
					FlxG.sound.music.fadeOut(0.25, 0);
					FlxG.sound.music.persist = false;
				}
				FlxG.sound.play(Paths.sound('confirmMenu'), 1);
				CoolUtil.setWindowIcon("mods/" + Options.getData("curMod") + "/_polymod_icon.png");
				MusicBeatState.windowNamePrefix = Options.getData("curMod");
				PolymodHandler.loadMods();
				NoteVariables.init();
				Options.fixBinds();
				Options.initModOptions();
				#if DISCORD_ALLOWED
				DiscordClient.loadModPresence();
				#end
				if (FlxG.state is modding.custom.CustomState) {
					FlxG.switchState(() -> new TitleState());
				} else {
					FlxG.resetState();
				}
				if (FlxG.sound.music == null || FlxG.sound.music.playing != true)
					TitleState.playTitleMusic();
			}
		} else {
			alpha = 0.6;
		}
	}
}
#end
class StringSaveOption extends Option {
	public var currentMode(default, null):String;
	public var modes(default, null):Array<String>;
	public var displayName(default, null):String;
	public var saveDataName(default, null):String;

	override public function new(optionName:String, modes:Array<String>, saveDataName:String, optionDescription:String = "", optionSaveKey:String = "main") {
		super(optionName, null, optionDescription, optionSaveKey);

		this.modes = modes;
		this.saveDataName = saveDataName;
		this.currentMode = Options.getData(saveDataName, optionSaveKey);
		this.displayName = optionName;
		this.optionName = displayName + " " + currentMode;

		if (alphabetText != null) {
			remove(alphabetText);
			alphabetText.kill();
			alphabetText.destroy();
		}

		alphabetText = new TextOption(20, 20, this.optionName, true, false, 0xFFFEB9B9);
		alphabetText.isMenuItem = true;
		add(alphabetText);
	}

	override public function onPress():Void {
		if (OptionsMenu.instance.inMenu) return;

		var prevIndex = modes.indexOf(currentMode);
		prevIndex = if (prevIndex == -1 || prevIndex + 1 >= modes.length) 0 else prevIndex + 1;

		currentMode = modes[prevIndex];
		this.optionName = displayName + " " + currentMode;

		remove(alphabetText);
		alphabetText.kill();
		alphabetText.destroy();

		alphabetText = new TextOption(20, 20, optionName, true, false, 0xFFFEB9B9);
		alphabetText.isMenuItem = true;
		add(alphabetText);

		setData();
	}

	function setData() {
		Options.setData(currentMode, saveDataName, optionSaveKey);
	}
}

class LanguageOption extends StringSaveOption {
	override function setData() {
		super.setData();
		if (OptionsMenu.instance != null) {
			OptionsMenu.instance.reloadLanguage();
		}
	}
}

class StepperSaveDeveloperOption extends StepperSaveOption {
	override function setData() {
		if (!Options.getData("developer")) return;
		super.setData();
	}
}

class StepperSaveOption extends Option {
	public var min(default, null):Float;
	public var max(default, null):Float;
	public var step(default, null):Float;
	public var currentValue(default, null):Float;
	private var prevValue:Float;

	override public function new(displayName:String, min:Float, max:Float, saveString:String, step:Float = 1, optionDescription:String = "") {
		super(displayName, saveString, optionDescription);

		if (max <= min) throw "Max value must be greater than min value.";
		if (step <= 0) throw "Step must be greater than 0.";

		this.min = min;
		this.max = max;
		this.step = step;
		currentValue = Options.getData(saveString);

		if (alphabetText != null) {
			remove(alphabetText);
			alphabetText.kill();
			alphabetText.destroy();
		}

		alphabetText = new TextOption(20, 20, '$optionName: $currentValue', true);
		alphabetText.isMenuItem = true;
		add(alphabetText);
	}

	override function update(elapsed:Float) {
		super.update(elapsed);

		if (OptionsMenu.instance.curSelected == OptionsMenu.instance.page.members.indexOf(this) && !OptionsMenu.instance.inMenu) {
			prevValue = currentValue;

			if (FlxG.keys.anyJustPressed([LEFT, A])) currentValue = Math.max(min, currentValue - step);
			else if (FlxG.keys.anyJustPressed([RIGHT, D])) currentValue = Math.min(max, currentValue + step);

			setData();
		}
	}

	function setData() {
		if (prevValue == currentValue) return;

		Options.setData(currentValue, optionValue);

		if (alphabetText != null) {
			remove(alphabetText);
			alphabetText.kill();
			alphabetText.destroy();
		}

		alphabetText = new TextOption(20, 20, '$optionName: $currentValue', true);
		alphabetText.isMenuItem = true;
		add(alphabetText);
	}
}

class DisplayFontOption extends StringSaveOption {
	override function setData() {
		super.setData();
		Main.changeFont(Options.getData("infoDisplayFont"));
	}
}

class DeveloperOption extends BoolOption {
	override function changeValue() {
		if (!Options.getData("developer")) return;
		super.changeValue();
	}
}

class OpenUrlOption extends Option {
	public var title:String;
	public var url:String;

	public function new(optionName:String, title:String, url:String, optionDescription:String = "") {
		super(optionName, null, optionDescription);
		this.title = title;
		this.url = url;
	}

	override public function onPress():Void {
		FlxG.openURL(url);
	}
}

class ResetOption extends Option {
	override public function new(optionName:String, optionDescription:String) {
		super(optionName, null, optionDescription);
		alphabetText.color = 0xFFFF6666;
	}

	override public function onPress():Void {
		if (OptionsMenu.instance.inMenu) return;
		FlxG.state.openSubState(new substates.ResetOptionsSubstate());
	}
}

class ConfirmBoolOption extends BoolOption {
    public var warningTitle:String;
    public var warningBody:String;
    public var warnOnTurnOff:Bool = false;

    override public function new(optionName:String, optionValue:String, optionDescription:String = "", warningTitle:String, warningBody:String = "", optionSaveKey:String = "main") {
        super(optionName, optionValue, optionDescription, optionSaveKey);
        this.warningTitle = warningTitle;
        this.warningBody = warningBody;
        if (optionName == "Shaders") warnOnTurnOff = true;
    }

    override public function onPress():Void {
        var willWarn:Bool = (!optionChecked && !warnOnTurnOff) || (optionChecked && warnOnTurnOff);
        
        if (willWarn) {
            FlxG.state.openSubState(new substates.ConfirmSubstate(warningTitle, function() {
                this.changeValue();
            }, warningBody));
        } else {
            this.changeValue();
        }
    }
}

class RestartConfirmBoolOption extends BoolOption {
    public var warningTitle:String;
    public var warningBody:String;

    override public function new(optionName:String, optionValue:String, optionDescription:String = "", warningTitle:String, warningBody:String = "", optionSaveKey:String = "main") {
        super(optionName, optionValue, optionDescription, optionSaveKey);
        this.warningTitle = warningTitle;
        this.warningBody = warningBody;
    }

    override public function onPress():Void {
        FlxG.state.openSubState(new substates.ConfirmSubstate(warningTitle, function() {
            this.changeValue();

            #if windows
            if (optionValue == "dpiAware")
                DPIFix.syncFlagFile();
            Sys.command("start \"\" \"" + Sys.programPath() + "\"");
            Sys.exit(0);
            #end
        }, warningBody));
    }
}


class VRAMConfirmBoolOption extends BoolOption {
    override public function new(optionName:String, optionValue:String, optionDescription:String = "", optionSaveKey:String = "main") {
        super(optionName, optionValue, optionDescription, optionSaveKey);
    }

    override public function onPress():Void {
        // If already enabled, turning it off does not require a warning/substate
        if (optionChecked) {
            this.changeValue();
            return;
        }

        // Hardware analysis
        var gpuName:String = "GPU Desconocida / Unknown GPU";
        var vendorName:String = "";
        var rendererName:String = "";

        try {
            @:privateAccess
            if (FlxG.stage != null && FlxG.stage.context3D != null && FlxG.stage.context3D.gl != null) {
                var gl = FlxG.stage.context3D.gl;
                var r = gl.getParameter(gl.RENDERER);
                var v = gl.getParameter(gl.VENDOR);
                rendererName = r != null ? StringTools.trim(Std.string(r)).split("/")[0] : "";
                vendorName = v != null ? StringTools.trim(Std.string(v)) : "";
                if (rendererName.length > 0) {
                    gpuName = rendererName + (vendorName.length > 0 && rendererName.indexOf(vendorName) == -1 ? ' (' + vendorName + ')' : '');
                } else if (FlxG.stage.context3D.driverInfo != null) {
                    gpuName = FlxG.stage.context3D.driverInfo;
                }
            }
        } catch (e:Dynamic) {}

        var lowerGPU = gpuName.toLowerCase();
        var isSpanish = (utilities.Localization.getLanguage() == "español");

        // Classification flags
        var isDedicated:Bool = false;
        var isModernIntegrated:Bool = false;
        var isOldOrSoftware:Bool = false;

        // Software or legacy / weak integrated GPUs
        if (lowerGPU.indexOf("llvmpipe") != -1
            || lowerGPU.indexOf("software") != -1
            || lowerGPU.indexOf("basic render") != -1
            || lowerGPU.indexOf("swiftshader") != -1
            || lowerGPU.indexOf("microsoft") != -1
            || (lowerGPU.indexOf("intel") != -1 && (lowerGPU.indexOf("gma") != -1 || lowerGPU.indexOf("express") != -1)))
        {
            isOldOrSoftware = true;
        }
        else if (lowerGPU.indexOf("intel") != -1 && lowerGPU.indexOf("hd graphics") != -1)
        {
            isOldOrSoftware = true;
        }
        // Dedicated GPUs (NVIDIA, AMD RX/Pro, Intel Arc)
        else if (lowerGPU.indexOf("nvidia") != -1
            || lowerGPU.indexOf("geforce") != -1
            || lowerGPU.indexOf("rtx") != -1
            || lowerGPU.indexOf("gtx") != -1
            || lowerGPU.indexOf("quadro") != -1
            || lowerGPU.indexOf("radeon rx") != -1
            || lowerGPU.indexOf("radeon pro") != -1
            || lowerGPU.indexOf("arc a") != -1
            || lowerGPU.indexOf("dedicated") != -1)
        {
            isDedicated = true;
        }
        // Modern Integrated GPUs (Intel UHD, Iris Xe, AMD Vega, Radeon Graphics, Apple Silicon)
        else if (lowerGPU.indexOf("uhd") != -1
            || lowerGPU.indexOf("iris") != -1
            || lowerGPU.indexOf("xe") != -1
            || lowerGPU.indexOf("vega") != -1
            || lowerGPU.indexOf("radeon graphics") != -1
            || lowerGPU.indexOf("apple") != -1)
        {
            isModernIntegrated = true;
        }

        var statusTitle:String = "";
        var statusDiagnostic:String = "";
        var explanation:String = "";

        if (isSpanish) {
            statusTitle = "ANÁLISIS DE HARDWARE (VRAM SPRITES)";
            if (isDedicated) {
                statusDiagnostic = "DIAGNÓSTICO: APTO (ALTAMENTE RECOMENDADO)";
                explanation = "Tu sistema cuenta con una GPU dedicada con VRAM propia de alta velocidad.
Activar esta opción reducirá drásticamente el uso de RAM del sistema
y evitará congelamientos (stuttering) durante el juego.";
            } else if (isModernIntegrated) {
                statusDiagnostic = "DIAGNÓSTICO: APTO CON PRECAUCIÓN (GPU INTEGRADA)";
                explanation = "Tu tarjeta gráfica es integrada moderna y comparte memoria con el sistema.
Ahorrará memoria RAM de proceso, pero si experimentas tirones
o parpadeos en escenarios con muchos elementos, puedes desactivarlo.";
            } else if (isOldOrSoftware) {
                statusDiagnostic = "DIAGNÓSTICO: NO RECOMENDADO (GPU ANTIGUA / BÁSICA)";
                explanation = "Tu tarjeta gráfica es integrada antigua o por software con recursos limitados.
Activar VRAM Sprites podría provocar parpadeos, lentitud
o pantallas negras al reactivar la pantalla.";
            } else {
                statusDiagnostic = "DIAGNÓSTICO: COMPATIBLE";
                explanation = "Esta opción guardará los sprites en la GPU para ahorrar memoria RAM.
Puedes desactivarlo en cualquier momento si notas algún problema.";
            }
        } else {
            statusTitle = "HARDWARE ANALYSIS (VRAM SPRITES)";
            if (isDedicated) {
                statusDiagnostic = "DIAGNOSTIC: FULLY CAPABLE (HIGHLY RECOMMENDED)";
                explanation = "Your system has a dedicated GPU with high-speed VRAM.
Enabling this will heavily optimize system RAM usage
and prevent GC garbage collector stutters.";
            } else if (isModernIntegrated) {
                statusDiagnostic = "DIAGNOSTIC: CAPABLE WITH CAUTION (INTEGRATED GPU)";
                explanation = "Your system has a modern integrated GPU (shared system memory).
It will reduce process RAM usage, but if you notice any lag
on massive stages, consider keeping it disabled.";
            } else if (isOldOrSoftware) {
                statusDiagnostic = "DIAGNOSTIC: NOT RECOMMENDED (LEGACY / BASIC GPU)";
                explanation = "Your system uses an older integrated GPU or software renderer.
Enabling VRAM Sprites may cause stuttering, instability
or black screens after screen sleep.";
            } else {
                statusDiagnostic = "DIAGNOSTIC: COMPATIBLE";
                explanation = "Stores sprites in GPU memory to save system RAM.
You can disable it anytime if issues occur.";
            }
        }

        var question:String = isSpanish ? "¿Deseas activar esta opción?" : "Do you want to enable this option?";
        var headerIntro:String = isSpanish
            ? "Esta opción almacena sprites en tu tarjeta gráfica (GPU) para ahorrar memoria RAM."
            : "This option stores sprites directly in GPU memory to reduce RAM usage.";

        var bodyText:String = headerIntro
            + "

• " + (isSpanish ? "GPU Detectada: " : "Detected GPU: ") + gpuName
            + "
• " + statusDiagnostic
            + "

" + explanation
            + "

" + question;

        FlxG.state.openSubState(new substates.ConfirmSubstate(statusTitle, function() {
            this.changeValue();
        }, bodyText));
    }
}

class DevWatermarkBoolOption extends BoolOption {
    override public function new(optionName:String, optionValue:String, optionDescription:String = "", optionSaveKey:String = "main") {
        super(optionName, optionValue, optionDescription, optionSaveKey);
    }

    override public function changeValue() {
        super.changeValue();
        if (optionChecked)
        {
            ui.DevWatermark.show(utilities.Options.currentUser);
        }
        else
        {
            ui.DevWatermark.hide();
        }
    }
}
