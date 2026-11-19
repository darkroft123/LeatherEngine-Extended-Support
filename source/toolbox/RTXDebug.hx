package toolbox;

import flixel.FlxG;
import flixel.FlxCamera;
import flixel.util.FlxColor;
import flixel.ui.FlxButton;
import flixel.addons.ui.FlxUIDropDownMenu;
import flixel.addons.ui.FlxSlider;
import ui.FlxScrollableDropDownMenu;
import openfl.events.IOErrorEvent;
import openfl.events.Event;
import states.MusicBeatState;
import states.OptionsMenu;
import flixel.FlxSprite;
import game.Character;
import game.StageGroup;
import flixel.FlxObject;
import shaders.RTXShader;
import flixel.math.FlxMath;
import haxe.Json;
import openfl.net.FileReference;

class RTXDebug extends MusicBeatState
{
    var shader:RTXShader = new RTXShader();

    var camGame:FlxCamera;
    var camHUD:FlxCamera;
    var stageDrop:FlxScrollableDropDownMenu;
    var stage:StageGroup;
    var dad:Character;
    var fakeBF:Character;
    var fakeGF:Character;
    var charList:Array<String>;
    var stageList:Array<String>;

    var overlayR:Float = 0;
    var overlayG:Float = 0;
    var overlayB:Float = 0;
    var overlayA:Float = 0;

    var shadowR:Float = 0;
    var shadowG:Float = 0;
    var shadowB:Float = 0;
    var shadowA:Float = 0;

    var shadowDistance:Float = 10;
    var shadowAngle:Float = 270;

    var satinR:Float = 0;
    var satinG:Float = 0;
    var satinB:Float = 0;
    var satinA:Float = 0;

    var hue:Float = 0;
    var saturation:Float = 0;
    var brightness:Float = 0;
    var contrast:Float = 0;

	var sliders:Array<{slider:FixedSlider, varName:String}> = [];
    var startChar:String = "dad";
    var file:FileReference;

    var useStageRTX:Bool = false;
    var toggleBtn:FlxButton;

    var extraChars:Array<Character> = [];
    public function new(char:String = "dad")
    {
        super();
        startChar = char;
    }

   override function create()
{
		hasTransitions = false;
  
    fakeBF = new Character(0, 0, "bf");
    fakeGF = new Character(0, 0, "gf");

    fakeBF.visible = false;
    fakeGF.visible = false;

    camGame = new FlxCamera();
    camHUD = new FlxCamera();
    camHUD.bgColor.alpha = 0;

    FlxG.cameras.reset(camGame);
    FlxG.cameras.add(camHUD, false);

    FlxG.mouse.visible = true;
    FlxG.mouse.useSystemCursor = true;

    // Stage
    stageList = CoolUtil.coolTextFile(Paths.txt("stageList"));
    stage = new StageGroup(stageList[0]);
    stage.cameras = [camGame];
    add(stage);

    // Characters
    charList = CoolUtil.coolTextFile(Paths.txt("characterList"));
    loadCharacter(startChar);
   
    
    add(createCharDropdown());
    add(createStageDropdown());

    // UI background
    var bg = new FlxSprite(0, 0);
    bg.makeGraphic(800, 250, FlxColor.BLACK);
    bg.alpha = 0.6;
    bg.scrollFactor.set();
    bg.cameras = [camHUD];
    add(bg);

    // Sliders
    createSliderGroup([
        {n:"overlayR", min:0, max:1},
        {n:"overlayG", min:0, max:1},
        {n:"overlayB", min:0, max:1},
        {n:"overlayA", min:0, max:1}
    ], 10);

    createSliderGroup([
        {n:"shadowR", min:0, max:1},
        {n:"shadowG", min:0, max:1},
        {n:"shadowB", min:0, max:1},
        {n:"shadowA", min:0, max:1},
        {n:"shadowDistance", min:0, max:50},
        {n:"shadowAngle", min:0, max:360}
    ], 220);

    createSliderGroup([
        {n:"satinR", min:0, max:1},
        {n:"satinG", min:0, max:1},
        {n:"satinB", min:0, max:1},
        {n:"satinA", min:0, max:1}
    ], 430);

    createSliderGroup([
        {n:"hue", min:0, max:1},
        {n:"saturation", min:-100, max:100},
        {n:"brightness", min:-255, max:255},
        {n:"contrast", min:-100, max:100}
    ], 640);

    // Buttons
    add(makeButton(10, 300, "Save", saveRTX));

    toggleBtn = makeButton(10, 340, "RTX: OFF", function()
    {
        useStageRTX = !useStageRTX;
        toggleBtn.text = "RTX: " + (useStageRTX ? "ON" : "OFF");

        if (useStageRTX)
        {
            loadRTX();
            refreshSliders();
        }
    });

    super.create();
}
function newSlider(varName:String, x:Float, y:Float, min:Float, max:Float)
{
    var s = new FixedSlider(this, varName, x, y, min, max, 100);
    s.cameras = [camHUD];
    s.scrollFactor.set(0, 0);

    // TEXTO BLANCO
    s.nameLabel.color = FlxColor.WHITE;
    s.valueLabel.color = FlxColor.WHITE;
    s.minLabel.color = FlxColor.WHITE;
    s.maxLabel.color = FlxColor.WHITE;

    add(s);
    sliders.push({slider: s, varName: varName});
}
function createSliderGroup(list:Array<{n:String, min:Float, max:Float}>, x:Float)
{
    var y = 10;
    for (item in list)
    {
        newSlider(item.n, x, y, item.min, item.max);
        y += 40;
    }
}
function makeButton(x:Float, y:Float, text:String, func:Void->Void):FlxButton
{
    var btn = new FlxButton(x, y, text, func);
    btn.cameras = [camHUD];
    add(btn);
    return btn;
}
function loadCharacter(name:String)
{
    if (dad != null)
    {
        remove(dad);
        dad.destroy();
        dad = null;
    }

    for (c in extraChars)
    {
        remove(c);
        c.destroy();
    }
    extraChars = [];

    dad = new Character(0, 0, name);
    dad.cameras = [camGame];
    dad.shader = shader;

    add(dad);

    stage.setCharOffsets(fakeBF, fakeGF, dad);

    if (dad.isCharacterGroup && dad.otherCharacters != null)
    {
        for (c in dad.otherCharacters)
        {
            c.cameras = [camGame];
            c.shader = shader;

            c.x = dad.x + c.positioningOffset[0];
            c.y = dad.y + c.positioningOffset[1];

            add(c);
            extraChars.push(c);
        }
    }
}
function createCharDropdown()
{
    var cleanList:Array<String> = [];

    for (char in charList)
    {
        cleanList.push(char.split(":")[0].trim());
    }

    var drop = new FlxScrollableDropDownMenu(10, 500,
        FlxUIDropDownMenu.makeStrIdLabelArray(cleanList, true),
        function(id:String)
        {
            startChar = cleanList[Std.parseInt(id)];
            loadCharacter(startChar);
        });

    drop.selectedId = Std.string(cleanList.indexOf(startChar));
    drop.cameras = [camHUD];
    return drop;
}
function createStageDropdown()
{
    stageDrop = new FlxScrollableDropDownMenu(220, 500,
        FlxUIDropDownMenu.makeStrIdLabelArray(stageList, true),
        function(id:String)
        {
            remove(stage);
            stage.destroy();

            stage = new StageGroup(stageList[Std.parseInt(id)]);
            stage.cameras = [camGame];
            add(stage);

            loadCharacter(startChar);
            trace("Selected: " + startChar);
           
            if (useStageRTX)
            {
                loadRTX();
                refreshSliders();
            }
        });

    stageDrop.cameras = [camHUD];
    return stageDrop;
}
function refreshSliders()
{
    for (e in sliders)
        e.slider.value = Reflect.field(this, e.varName);
}
override function destroy()
{
    if (dad != null) dad.destroy();

    for (c in extraChars)
        c.destroy();

    if (fakeBF != null) fakeBF.destroy();
    if (fakeGF != null) fakeGF.destroy();

    super.destroy();
}
function makeColor(r:Float, g:Float, b:Float, a:Float):FlxColor
{
    return FlxColor.fromRGBFloat(r, g, b, a);
}

function applyShader()
{
    shader.overlay = makeColor(overlayR, overlayG, overlayB, overlayA);
    shader.shadow  = makeColor(shadowR, shadowG, shadowB, shadowA);
    shader.satin   = makeColor(satinR, satinG, satinB, satinA);

    shader.shadowDistance = shadowDistance;
    shader.shadowAngle = shadowAngle;

    shader.baseHue = hue;
    shader.baseSaturation = saturation;
    shader.baseBrightness = brightness;
    shader.baseContrast = contrast;
}
   override function update(elapsed:Float)
{
    applyShader();
    updateCamera(elapsed);

    super.update(elapsed);

    if (FlxG.keys.justPressed.ESCAPE)
        FlxG.switchState(new OptionsMenu());
}
function updateCamera(elapsed:Float)
{
    var speed = 300 * elapsed;
    if (FlxG.keys.pressed.SHIFT) speed *= 3;

    if (FlxG.mouse.pressed && FlxG.mouse.y < 250) return;

    if (FlxG.keys.pressed.J) camGame.scroll.x -= speed;
    if (FlxG.keys.pressed.L) camGame.scroll.x += speed;
    if (FlxG.keys.pressed.I) camGame.scroll.y -= speed;
    if (FlxG.keys.pressed.K) camGame.scroll.y += speed;

    if (FlxG.keys.pressed.Q) camGame.zoom += 0.8 * elapsed;
    if (FlxG.keys.pressed.E) camGame.zoom -= 0.8 * elapsed;
}
   function loadRTX()
{
    if (!useStageRTX) return;

    var data = stage.stageData.rtxData;
    if (data == null) return;

    applyColor(data.overlay, function(c) {
        overlayR = c.redFloat;
        overlayG = c.greenFloat;
        overlayB = c.blueFloat;
    });
    overlayA = data.overlayAlpha;

    applyColor(data.inner, function(c) {
        shadowR = c.redFloat;
        shadowG = c.greenFloat;
        shadowB = c.blueFloat;
    });
    shadowA = data.innerAlpha;

    shadowDistance = data.innerDistance;
    shadowAngle = data.innerAngle;

    hue = data.hue ?? 0;
    saturation = data.saturation ?? 0;
    brightness = data.brightness ?? 0;
    contrast = data.contrast ?? 0;

    if (data.satin != null)
    {
        applyColor(data.satin, function(c) {
            satinR = c.redFloat;
            satinG = c.greenFloat;
            satinB = c.blueFloat;
        });
        satinA = data.satinAlpha;
    }
}
function applyColor(str:String, fn:FlxColor->Void)
{
    var c = FlxColor.fromString(str);
    fn(c);
}
    private function saveRTX():Void
{
    stage.stageData.rtxData = {
        overlay: shader.overlay.toHexString(false),
        overlayAlpha: overlayA,
        satin: shader.satin.toHexString(false),
        satinAlpha: satinA,
        inner: shader.shadow.toHexString(false),
        innerAlpha: shadowA,
        innerDistance: shader.shadowDistance,
        innerAngle: shadowAngle,
        hue: hue,
        saturation: saturation,
        brightness: brightness,
        contrast: contrast
    };

    var data = Json.stringify(stage.stageData, null, "\t");
    if (data == null || data.length == 0) return;

    file = new FileReference();
    addFileListeners();

    file.save(data.trim(), stageDrop.selectedLabel + ".json");
}
function addFileListeners()
{
    file.addEventListener(Event.COMPLETE, onSaveComplete);
    file.addEventListener(Event.CANCEL, onSaveCancel);
    file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
}

function clearFileListeners()
{
    if (file == null) return;

    file.removeEventListener(Event.COMPLETE, onSaveComplete);
    file.removeEventListener(Event.CANCEL, onSaveCancel);
    file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
    file = null;
}
 function onSaveComplete(_):Void
{
    clearFileListeners();
    FlxG.log.notice("Successfully saved RTX Data.");
}

function onSaveCancel(_):Void
{
    clearFileListeners();
}

function onSaveError(_):Void
{
    clearFileListeners();
    FlxG.log.error("Problem saving RTX Data");
}
}


class FixedSlider extends FlxSlider
{
	var boundsObject = new FlxObject();
	override public function update(elapsed:Float):Void
	{
		boundsObject.setPosition(_bounds.x, _bounds.y);
		boundsObject.setSize(_bounds.width, _bounds.height);
		//_bounds.overlaps()
		var mousePos = FlxG.mouse.getWorldPosition(camera);
		// Clicking and sound logic
		if (boundsObject.overlapsPoint(mousePos, false, camera))
		{
			if (hoverAlpha != 1)
			{
				alpha = hoverAlpha;
			}

			#if FLX_SOUND_SYSTEM
			if (hoverSound != null && !_justHovered)
			{
				FlxG.sound.play(hoverSound);
			}
			#end

			_justHovered = true;

			if (FlxG.mouse.pressed)
			{
				handle.x = mousePos.x;
				updateValue();

				#if FLX_SOUND_SYSTEM
				if (clickSound != null && !_justClicked)
				{
					FlxG.sound.play(clickSound);
					_justClicked = true;
				}
				#end
			}
			if (!FlxG.mouse.pressed)
			{
				_justClicked = false;
			}
		}
		else
		{
			if (hoverAlpha != 1)
			{
				alpha = 1;
			}

			_justHovered = false;
		}

		// Update the target value whenever the slider is being used
		if ((FlxG.mouse.pressed) && (FlxMath.mouseInFlxRect(true, _bounds)))
		{
			updateValue();
		}

		// Update the value variable
		if ((varString != null) && (Reflect.getProperty(_object, varString) != null))
		{
			value = Reflect.getProperty(_object, varString);
		}

		// Changes to value from outside update the handle pos
		if (handle.x != expectedPos)
		{
			handle.x = expectedPos;
		}

		// Finally, update the valueLabel
		valueLabel.text = Std.string(FlxMath.roundDecimal(value, decimals));

		//super.update(elapsed);
		group.update(elapsed);

		if (moves)
			updateMotion(elapsed);
	}
}