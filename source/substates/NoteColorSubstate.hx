package substates;

import shaders.NoteColors;
import shaders.ColorSwap;
import game.StrumNote;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextBorderStyle;
import flixel.util.FlxColor;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.group.FlxSpriteGroup;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFramesCollection;
import flixel.math.FlxMath;
import openfl.display.BitmapData;
import lime.utils.Assets;
import utilities.Options;
import utilities.NoteVariables;
import flixel.input.keyboard.FlxKey;

using StringTools;

class ModernButton extends FlxSpriteGroup
{
    public var bg:FlxSprite;
    public var border:FlxSprite;
    public var label:FlxText;
    public var onClick:Void->Void;
    public var hovered:Bool = false;
    public var isFocused:Bool = false;
    public var baseColor:FlxColor = 0xFF141422;
    public var hoverColor:FlxColor = 0xFF28283E;
    public var borderColor:FlxColor = 0xFF00FFD2;
    public var focusColor:FlxColor = 0xFF00FFD2;

    public function new(X:Float, Y:Float, Width:Int, Height:Int, Text:String, OnClick:Void->Void, ?BorderCol:FlxColor, ?FontSize:Int = 14)
    {
        super(X, Y);
        this.onClick = OnClick;
        if (BorderCol != null) {
            this.borderColor = BorderCol;
            this.focusColor = BorderCol;
        }

        if (NoteColorSubstate.instance != null && NoteColorSubstate.instance.uiCamera != null)
            cameras = [NoteColorSubstate.instance.uiCamera];

        border = new FlxSprite(-1, -1).makeGraphic(Width + 2, Height + 2, borderColor);
        border.alpha = 0.45;
        add(border);

        bg = new FlxSprite(0, 0).makeGraphic(Width, Height, baseColor);
        add(bg);

        label = new FlxText(0, (Height - FontSize - 4) / 2, Width, Text);
        label.setFormat(Paths.font("vcr.ttf"), FontSize, FlxColor.WHITE, "center");
        add(label);
    }

    override public function update(elapsed:Float)
    {
        super.update(elapsed);

        var cam:FlxCamera = (NoteColorSubstate.instance != null && NoteColorSubstate.instance.uiCamera != null) ? NoteColorSubstate.instance.uiCamera : (camera != null ? camera : FlxG.camera);
        var mPos = FlxG.mouse.getWorldPosition(cam);
        var overlaps:Bool = (mPos.x >= x && mPos.x <= x + bg.width &&
                             mPos.y >= y && mPos.y <= y + bg.height);

        hovered = overlaps;
        if (isFocused)
        {
            border.alpha = 1.0;
            border.color = focusColor;
            bg.color = hoverColor;
        }
        else if (hovered)
        {
            border.alpha = 1.0;
            border.color = borderColor;
            bg.color = hoverColor;
        }
        else
        {
            border.alpha = 0.45;
            border.color = borderColor;
            bg.color = baseColor;
        }

        if (hovered && FlxG.mouse.justPressed)
        {
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
            if (onClick != null)
                onClick();
        }
    }
}

@:publicFields
class NoteColorSubstate extends MusicBeatSubstate
{
    public static var instance:NoteColorSubstate;

    public static inline var FONT_TITLE:String = "vcr.ttf";
    public static inline var FONT_UI:String = "vcr.ttf";
    public static inline var COLOR_CYAN:Int = 0xFF00FFD2;
    public static inline var COLOR_PURPLE:Int = 0xFFC735FF;
    public static inline var COLOR_GOLD:Int = 0xFFFFB800;

    var uiCamera:FlxCamera = new FlxCamera();

    var key_Count:Int = 4;
    var ui_Skin:String = "default";
    var ui_Skins:Array<String> = [];

    var ui_settings:Array<String>;
    var mania_size:Array<String>;
    var mania_offset:Array<String>;
    var mania_gap:Array<String>;

    var selectedControl:Int = 0;
    var current_ColorVals:Array<Int> = [255, 0, 0];

    // HSB state
    var curHue:Float = 0;
    var curSat:Float = 1.0;
    var curBrt:Float = 1.0;

    // Color Wheel & Brightness Slider
    var wheelSize:Int = 190;
    var wheelRadius:Float = 95;
    var wheelSprite:FlxSprite;
    var wheelCursor:FlxSprite;
    var brightBar:FlxSprite;
    var brightBmp:BitmapData;
    var brightCursor:FlxSprite;
    var draggingWheel:Bool = false;
    var draggingBright:Bool = false;

    // Preview
    var note_Group:FlxTypedGroup<FlxSprite> = new FlxTypedGroup<FlxSprite>();
    var labelGroup:FlxTypedGroup<FlxText> = new FlxTypedGroup<FlxText>();
    var noteSwaps:Array<ColorSwap> = [];
    var selectionBox:FlxSprite;

    // Header & Info
    var title:FlxText;
    var keysLabel:FlxText;
    var skinLabel:FlxText;

    // Swatch & Hex
    var colorSwatch:FlxSprite;
    var swatchBorder:FlxSprite;
    var hexButton:ModernButton;
    var hexEditing:Bool = false;
    var hexBuffer:String = "";

    // RGB Controls
    var rValText:FlxText;
    var gValText:FlxText;
    var bValText:FlxText;

    var hintText:FlxText;

    var NOTES_FRAMES_CACHE:Map<String, FlxAtlasFrames> = new Map();

    public function new()
    {
        super();
        instance = this;

        var currentSong = (FlxG.state is states.PlayState) ? states.PlayState.SONG : null;
        if (currentSong != null && currentSong.ui_Skin != null && currentSong.ui_Skin != "")
            ui_Skin = currentSong.ui_Skin;
        else
        {
            var storedSkin:Dynamic = Options.getData("uiSkin");
            ui_Skin = (storedSkin != null && Std.string(storedSkin) != "") ? Std.string(storedSkin) : "default";
        }

        if (currentSong != null && currentSong.keyCount != null)
            key_Count = Std.int(currentSong.keyCount);
    }

    override function create()
    {
        instance = this;
        super.create();

        uiCamera.bgColor.alpha = 0;
        FlxG.cameras.add(uiCamera, false);
        cameras = [uiCamera];

        var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF080812);
        bg.alpha = 0.90;
        add(bg);

        FlxG.mouse.visible = true;
        FlxG.mouse.useSystemCursor = true;

        ui_Skins = CoolUtil.coolTextFile(Paths.txt("uiSkinList"));
        if (ui_Skins == null || ui_Skins.length == 0)
            ui_Skins = ["default"];
        if (!ui_Skins.contains(ui_Skin))
            ui_Skin = "default";

        loadSkinConfigs();

        buildHeader();
        buildNotePreviews();
        buildColorWheel();
        buildColorControls();
        buildFooter();

        updateColorValsBase();
        updateHSBFromRGB();
        updateWheelCursors();
        updateBrightnessBarBitmap();
        updateUI();
    }

    function buildHeader():Void
    {
        title = new FlxText(0, 16, FlxG.width, "NOTE COLORS");
        title.setFormat(Paths.font(FONT_TITLE), 34, COLOR_CYAN, "center", FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        add(title);

        var headerY:Float = 62;

        // Keys selector
        var kx:Float = 260;
        var kLabel = new FlxText(kx - 90, headerY + 4, 85, "KEYS:");
        kLabel.setFormat(Paths.font(FONT_UI), 16, COLOR_GOLD, "right");
        add(kLabel);

        add(new ModernButton(kx, headerY, 34, 26, "<", () -> changeKeys(-1), COLOR_CYAN, 12));
        keysLabel = new FlxText(kx + 38, headerY + 4, 50, Std.string(key_Count));
        keysLabel.setFormat(Paths.font(FONT_UI), 18, FlxColor.WHITE, "center");
        add(keysLabel);
        add(new ModernButton(kx + 92, headerY, 34, 26, ">", () -> changeKeys(1), COLOR_CYAN, 12));

        // Skin selector
        var sx:Float = 680;
        var sLabel = new FlxText(sx - 90, headerY + 4, 85, "SKIN:");
        sLabel.setFormat(Paths.font(FONT_UI), 16, COLOR_GOLD, "right");
        add(sLabel);

        add(new ModernButton(sx, headerY, 34, 26, "<", () -> cycleSkin(-1), COLOR_PURPLE, 12));
        skinLabel = new FlxText(sx + 38, headerY + 4, 220, ui_Skin.toUpperCase());
        skinLabel.setFormat(Paths.font(FONT_UI), 16, FlxColor.WHITE, "center");
        add(skinLabel);
        add(new ModernButton(sx + 262, headerY, 34, 26, ">", () -> cycleSkin(1), COLOR_PURPLE, 12));
    }

    function buildNotePreviews():Void
    {
        selectionBox = new FlxSprite().makeGraphic(70, 70, FlxColor.TRANSPARENT);
        for (px in 0...70)
        {
            for (py in 0...70)
            {
                if (px <= 2 || px >= 67 || py <= 2 || py >= 67)
                    selectionBox.pixels.setPixel32(px, py, 0xFF00FFD2);
            }
        }
        add(selectionBox);

        add(note_Group);
        add(labelGroup);

        createArrows();
    }

    function buildColorWheel():Void
    {
        var wheelX:Float = 140;
        var wheelY:Float = 265;

        // Circular Color Wheel Bitmap
        var wheelBmp = new BitmapData(wheelSize, wheelSize, true, 0x00000000);
        var cx:Float = wheelRadius;
        var cy:Float = wheelRadius;
        for (px in 0...wheelSize)
        {
            for (py in 0...wheelSize)
            {
                var dx = px - cx;
                var dy = py - cy;
                var dist = Math.sqrt(dx * dx + dy * dy);
                if (dist <= wheelRadius)
                {
                    var angle = Math.atan2(dy, dx);
                    var hue = (angle * 180 / Math.PI + 360) % 360;
                    var sat = dist / wheelRadius;
                    var alpha:Float = (dist > wheelRadius - 1.5) ? (wheelRadius - dist) / 1.5 : 1.0;
                    if (alpha < 0) alpha = 0;
                    if (alpha > 1) alpha = 1;
                    var col = FlxColor.fromHSB(hue, sat, 1.0, alpha);
                    wheelBmp.setPixel32(px, py, col);
                }
            }
        }

        // Circular Frame
        var frameSize = wheelSize + 8;
        var frameBmp = new BitmapData(frameSize, frameSize, true, 0x00000000);
        var fcx = frameSize / 2;
        var fcy = frameSize / 2;
        for (px in 0...frameSize)
        {
            for (py in 0...frameSize)
            {
                var dx = px - fcx;
                var dy = py - fcy;
                var dist = Math.sqrt(dx * dx + dy * dy);
                if (dist >= wheelRadius + 0.5 && dist <= wheelRadius + 3.0)
                    frameBmp.setPixel32(px, py, 0xAA00FFD2);
            }
        }
        add(new FlxSprite(wheelX - 4, wheelY - 4).loadGraphic(frameBmp));

        wheelSprite = new FlxSprite(wheelX, wheelY).loadGraphic(wheelBmp);
        add(wheelSprite);

        // Wheel cursor (ring)
        var curSize = 14;
        var curBmp = new BitmapData(curSize, curSize, true, 0x00000000);
        var cc = curSize / 2;
        for (px in 0...curSize)
        {
            for (py in 0...curSize)
            {
                var dx = px - cc;
                var dy = py - cc;
                var d = Math.sqrt(dx * dx + dy * dy);
                if (d >= 3 && d <= 5)
                    curBmp.setPixel32(px, py, 0xFFFFFFFF);
                else if (d > 5 && d <= 6.5)
                    curBmp.setPixel32(px, py, 0xFF000000);
            }
        }
        wheelCursor = new FlxSprite(0, 0).loadGraphic(curBmp);
        add(wheelCursor);

        // Brightness Slider
        var barX = wheelX + wheelSize + 28;
        var barY = wheelY;
        var barW = 26;
        var barH = wheelSize;

        // Brightness Frame
        var bFrame = new FlxSprite(barX - 2, barY - 2).makeGraphic(barW + 4, barH + 4, 0xAA00FFD2);
        add(bFrame);

        brightBmp = new BitmapData(barW, barH, false, 0xFF000000);
        brightBar = new FlxSprite(barX, barY).loadGraphic(brightBmp);
        add(brightBar);

        // Brightness pointer
        var pointerBmp = new BitmapData(34, 6, true, 0x00000000);
        for (px in 0...34)
        {
            for (py in 0...6)
            {
                if (py >= 1 && py <= 4)
                    pointerBmp.setPixel32(px, py, 0xFFFFFFFF);
                else
                    pointerBmp.setPixel32(px, py, 0xFF000000);
            }
        }
        brightCursor = new FlxSprite(barX - 4, barY).loadGraphic(pointerBmp);
        add(brightCursor);

        // Labels under wheel & slider
        var wLabel = new FlxText(wheelX, wheelY + wheelSize + 10, wheelSize, "COLOR WHEEL");
        wLabel.setFormat(Paths.font(FONT_UI), 12, COLOR_GOLD, "center");
        add(wLabel);

        var brLabel = new FlxText(barX - 10, barY + barH + 10, barW + 20, "BRIGHT");
        brLabel.setFormat(Paths.font(FONT_UI), 11, COLOR_GOLD, "center");
        add(brLabel);
    }

    function buildColorControls():Void
    {
        var colX:Float = 470;
        var colY:Float = 265;

        // Color Swatch with glowing border
        swatchBorder = new FlxSprite(colX - 2, colY - 2).makeGraphic(224, 52, COLOR_CYAN);
        swatchBorder.alpha = 0.8;
        add(swatchBorder);

        colorSwatch = new FlxSprite(colX, colY).makeGraphic(220, 48, FlxColor.WHITE);
        add(colorSwatch);

        // HEX Button / Input Pill
        hexButton = new ModernButton(colX + 240, colY, 210, 48, "#FFFFFF", onHexButtonClick, COLOR_PURPLE, 18);
        add(hexButton);

        // RGB channel rows
        var rowBaseY:Float = colY + 70;
        var rowH:Float = 42;

        // Channel RED
        buildRGBRow(colX, rowBaseY, 0, "R", 0xFFFF3344);
        // Channel GREEN
        buildRGBRow(colX, rowBaseY + rowH, 1, "G", 0xFF33FF55);
        // Channel BLUE
        buildRGBRow(colX, rowBaseY + rowH * 2, 2, "B", 0xFF3399FF);
    }

    function buildRGBRow(startX:Float, y:Float, channel:Int, letter:String, col:FlxColor):Void
    {
        // Badge
        var badge = new FlxSprite(startX, y).makeGraphic(42, 32, col);
        add(badge);
        var badgeTxt = new FlxText(startX, y + 5, 42, letter);
        badgeTxt.setFormat(Paths.font(FONT_UI), 18, FlxColor.BLACK, "center");
        add(badgeTxt);

        var curX = startX + 50;

        // -10 button
        add(new ModernButton(curX, y, 46, 32, "-10", () -> adjustChannel(channel, -10), col, 12));
        curX += 52;

        // -1 button
        add(new ModernButton(curX, y, 42, 32, "-1", () -> adjustChannel(channel, -1), col, 12));
        curX += 48;

        // Value box
        var valBox = new FlxSprite(curX, y).makeGraphic(80, 32, 0xFF141422);
        add(valBox);
        var valTxt = new FlxText(curX, y + 5, 80, "255");
        valTxt.setFormat(Paths.font(FONT_UI), 18, FlxColor.WHITE, "center");
        add(valTxt);

        if (channel == 0) rValText = valTxt;
        else if (channel == 1) gValText = valTxt;
        else bValText = valTxt;

        curX += 86;

        // +1 button
        add(new ModernButton(curX, y, 42, 32, "+1", () -> adjustChannel(channel, 1), col, 12));
        curX += 48;

        // +10 button
        add(new ModernButton(curX, y, 46, 32, "+10", () -> adjustChannel(channel, 10), col, 12));
    }

    function buildFooter():Void
    {
        var footY:Float = 575;

        // Action Buttons
        add(new ModernButton(220, footY, 200, 38, "RESET NOTE", resetSelectedColor, COLOR_GOLD, 14));
        add(new ModernButton(460, footY, 200, 38, "RESET ALL", resetAllColors, COLOR_PURPLE, 14));
        add(new ModernButton(700, footY, 200, 38, "CLOSE [ESC]", () -> {
            FlxG.mouse.visible = false;
            close();
        }, COLOR_CYAN, 14));

        hintText = new FlxText(0, footY + 54, FlxG.width,
            "CLICK / DRAG COLOR WHEEL & BRIGHTNESS  •  CLICK NOTE TO SELECT  •  LEFT/RIGHT: SELECT  •  R: RESET  •  ESC: EXIT");
        hintText.setFormat(Paths.font(FONT_UI), 12, 0xFF888899, "center", FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        add(hintText);
    }

    function createArrows(?newKeyCount:Int):Void
    {
        if (newKeyCount != null)
            key_Count = newKeyCount;

        note_Group.clear();
        labelGroup.clear();
        noteSwaps = [];

        var gapVal = parseSafe(mania_gap, key_Count - 1, 10);
        if (gapVal > 30) gapVal = 30;

        var notesFrames = getNoteFrames();
        var previewY:Float = 115;
        var tempNotes:Array<FlxSprite> = [];

        var uiScale = parseSafe(ui_settings, 0, 0.7);
        var uiMult = parseSafe(ui_settings, 2, 1.0);
        var mSizeVal = parseSafe(mania_size, key_Count - 1, 0.0);
        var isPixelSkin:Bool = uiScale >= 2.0;

        for (i in 0...key_Count)
        {
            var dir:String = NoteVariables.animationDirections[key_Count - 1][i];
            var noteSpr = new FlxSprite(0, previewY);
            noteSpr.ID = i;

            if (notesFrames != null)
            {
                noteSpr.frames = notesFrames;
                var foundPrefix:String = null;
                var candidatePrefixes:Array<String> = [
                    dir + "0",
                    dir + " static",
                    "arrow" + dir.toUpperCase(),
                    dir
                ];
                if (key_Count == 4)
                {
                    var colorName = switch (dir.toLowerCase())
                    {
                        case "left": "purple";
                        case "down": "blue";
                        case "up": "green";
                        case "right": "red";
                        default: "";
                    };
                    if (colorName != "")
                    {
                        candidatePrefixes.push(colorName + "0");
                        candidatePrefixes.push(colorName);
                    }
                }

                for (cand in candidatePrefixes)
                {
                    if (framesContainPrefix(notesFrames, cand))
                    {
                        foundPrefix = cand;
                        break;
                    }
                }

                if (foundPrefix != null)
                {
                    noteSpr.animation.addByPrefix("default", foundPrefix, 24);
                    noteSpr.animation.play("default");
                }
            }

            var isHighResSprite:Bool = noteSpr.frameWidth > 50;
            var baseScale:Float = (isPixelSkin && isHighResSprite) ? (0.7 * (uiMult - mSizeVal)) : (uiScale * (uiMult - mSizeVal));
            if (baseScale <= 0.1 || Math.isNaN(baseScale)) baseScale = 0.7;

            noteSpr.antialiasing = (!isPixelSkin || (ui_settings != null && ui_settings.length > 3 && ui_settings[3] == "true")) && Options.getData("antialiasing");
            noteSpr.scale.set(baseScale, baseScale);
            noteSpr.updateHitbox();

            var cs = new ColorSwap();
            noteSwaps.push(cs);
            noteSpr.shader = cs.shader;

            tempNotes.push(noteSpr);
        }

        // Calculate total width and center notes
        var totalW:Float = 0;
        for (n in tempNotes)
            totalW += n.width + gapVal;
        totalW -= gapVal;

        var startX:Float = (FlxG.width - totalW) / 2;
        var curX:Float = startX;

        for (i in 0...tempNotes.length)
        {
            var n = tempNotes[i];
            n.x = curX;
            n.y = previewY;
            note_Group.add(n);

            var dir = NoteVariables.animationDirections[key_Count - 1][i].toUpperCase();
            var txt = new FlxText(curX - 10, previewY + n.height + 6, n.width + 20, dir);
            txt.setFormat(Paths.font(FONT_UI), 13, FlxColor.WHITE, "center", FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
            txt.ID = i;
            labelGroup.add(txt);

            curX += n.width + gapVal;
        }

        if (selectedControl >= key_Count)
            selectedControl = key_Count - 1;
        if (selectedControl < 0)
            selectedControl = 0;

        updateArrowHighlights();
    }

    function updateArrowHighlights():Void
    {
        for (i in 0...note_Group.length)
        {
            var noteSpr = note_Group.members[i];
            if (noteSpr == null) continue;

            var c:Array<Int> = getDirectionColor(i);
            var cs:ColorSwap = (i < noteSwaps.length) ? noteSwaps[i] : null;
            if (cs != null)
            {
                cs.r = c[0];
                cs.g = c[1];
                cs.b = c[2];
            }

            noteSpr.alpha = (i == selectedControl) ? 1.0 : 0.65;
        }

        for (i in 0...labelGroup.length)
        {
            var txt = labelGroup.members[i];
            if (txt == null) continue;
            txt.color = (i == selectedControl) ? COLOR_GOLD : FlxColor.WHITE;
        }

        if (selectedControl < note_Group.length && note_Group.members[selectedControl] != null)
        {
            var sel = note_Group.members[selectedControl];
            selectionBox.x = sel.x + (sel.width - selectionBox.width) / 2;
            selectionBox.y = sel.y + (sel.height - selectionBox.height) / 2;
            selectionBox.visible = true;
        }
        else
        {
            selectionBox.visible = false;
        }
    }

    inline function getDirectionColor(i:Int):Array<Int>
    {
        return NoteColors.getNoteColor(NoteVariables.animationDirections[key_Count - 1][i]);
    }

    inline function getSelectedDirection():String
    {
        return NoteVariables.animationDirections[key_Count - 1][selectedControl];
    }

    function updateColorValsBase():Void
    {
        var c:Array<Int> = NoteColors.getNoteColor(getSelectedDirection());
        current_ColorVals = [c[0], c[1], c[2]];
    }

    function updateHSBFromRGB():Void
    {
        var col:FlxColor = FlxColor.fromRGB(current_ColorVals[0], current_ColorVals[1], current_ColorVals[2]);
        curHue = col.hue;
        curSat = col.saturation;
        curBrt = col.brightness;
    }

    function saveColor():Void
    {
        var copy:Array<Int> = [current_ColorVals[0], current_ColorVals[1], current_ColorVals[2]];
        NoteColors.setNoteColor(getSelectedDirection(), copy);
        updateArrowHighlights();
    }

    function resetSelectedColor():Void
    {
        var def = NoteColors.defaultColors.get(getSelectedDirection());
        if (def != null)
        {
            current_ColorVals = def.copy();
            saveColor();
            updateHSBFromRGB();
            updateWheelCursors();
            updateBrightnessBarBitmap();
            updateUI();
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
        }
    }

    function resetAllColors():Void
    {
        for (k in NoteColors.defaultColors.keys())
        {
            var def = NoteColors.defaultColors.get(k);
            if (def != null)
                NoteColors.setNoteColor(k, def.copy());
        }
        updateColorValsBase();
        updateHSBFromRGB();
        updateWheelCursors();
        updateBrightnessBarBitmap();
        updateArrowHighlights();
        updateUI();
        FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
    }

    function changeKeys(delta:Int):Void
    {
        key_Count += delta;
        if (key_Count < 1) key_Count = 1;
        if (key_Count > NoteVariables.maniaDirections.length) key_Count = NoteVariables.maniaDirections.length;

        keysLabel.text = Std.string(key_Count);
        createArrows();
        updateColorValsBase();
        updateHSBFromRGB();
        updateWheelCursors();
        updateBrightnessBarBitmap();
        updateUI();
        FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
    }

    function cycleSkin(delta:Int):Void
    {
        if (ui_Skins.length == 0) return;
        var idx = ui_Skins.indexOf(ui_Skin);
        if (idx < 0) idx = 0;
        idx = (idx + delta + ui_Skins.length) % ui_Skins.length;

        ui_Skin = ui_Skins[idx];
        skinLabel.text = ui_Skin.toUpperCase();

        loadSkinConfigs();
        createArrows();
        updateArrowHighlights();
        FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
    }

    function selectControlTo(i:Int):Void
    {
        if (selectedControl != i && i >= 0 && i < key_Count)
        {
            selectedControl = i;
            updateColorValsBase();
            updateHSBFromRGB();
            updateWheelCursors();
            updateBrightnessBarBitmap();
            updateArrowHighlights();
            updateUI();
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.3);
        }
    }

    function adjustChannel(ch:Int, delta:Int):Void
    {
        current_ColorVals[ch] = Std.int(FlxMath.bound(current_ColorVals[ch] + delta, 0, 255));
        saveColor();
        updateHSBFromRGB();
        updateWheelCursors();
        updateBrightnessBarBitmap();
        updateUI();
    }

    function onHexButtonClick():Void
    {
        startHexEditing();
    }

    function startHexEditing():Void
    {
        if (!hexEditing)
        {
            hexEditing = true;
            hexBuffer = "";
            if (hexButton != null)
                hexButton.isFocused = true;
            updateUI();
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
        }
    }

    function stopHexEditing(apply:Bool = true):Void
    {
        if (hexEditing)
        {
            if (apply && hexBuffer.length >= 6)
                applyHex(true);
            hexEditing = false;
            hexBuffer = "";
            if (hexButton != null)
                hexButton.isFocused = false;
            updateUI();
        }
    }

    function applyHex(clearBuffer:Bool = true):Bool
    {
        var cleaned = "";
        for (ch in hexBuffer)
            if ((ch >= '0'.code && ch <= '9'.code) || (ch >= 'a'.code && ch <= 'f'.code) || (ch >= 'A'.code && ch <= 'F'.code))
                cleaned += String.fromCharCode(ch);

        if (cleaned.length < 6) return false;

        var val = Std.parseInt("0x" + cleaned);
        if (val == null) return false;

        current_ColorVals = [(val >> 16) & 255, (val >> 8) & 255, val & 255];
        saveColor();
        updateHSBFromRGB();
        updateWheelCursors();
        updateBrightnessBarBitmap();
        if (clearBuffer) hexBuffer = "";
        updateUI();
        FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
        return true;
    }

    function hexFromRGB():String
    {
        return hex2(current_ColorVals[0]) + hex2(current_ColorVals[1]) + hex2(current_ColorVals[2]);
    }

    inline function hex2(v:Int):String
    {
        var s = StringTools.hex(v, 2);
        return s.length < 2 ? "0" + s : s;
    }

    function updateWheelCursors():Void
    {
        if (wheelCursor == null || brightCursor == null) return;

        // Position on wheel
        var rad = curSat * wheelRadius;
        var angle = curHue * Math.PI / 180;
        var wx = (wheelSprite.x + wheelRadius) + (rad * Math.cos(angle)) - (wheelCursor.width / 2);
        var wy = (wheelSprite.y + wheelRadius) + (rad * Math.sin(angle)) - (wheelCursor.height / 2);
        wheelCursor.x = wx;
        wheelCursor.y = wy;

        // Position on brightness slider
        var by = brightBar.y + ((1.0 - curBrt) * brightBar.height) - (brightCursor.height / 2);
        brightCursor.y = by;
    }

    function updateBrightnessBarBitmap():Void
    {
        if (brightBmp == null) return;
        var barW = brightBmp.width;
        var barH = brightBmp.height;
        for (py in 0...barH)
        {
            var v:Float = 1.0 - (py / barH);
            var col:FlxColor = FlxColor.fromHSB(curHue, curSat, v);
            for (px in 0...barW)
            {
                brightBmp.setPixel32(px, py, col);
            }
        }
    }

    function updateWheelColor(mx:Float, my:Float):Void
    {
        var dx = mx - (wheelSprite.x + wheelRadius);
        var dy = my - (wheelSprite.y + wheelRadius);
        var dist = Math.sqrt(dx * dx + dy * dy);
        if (dist > wheelRadius) dist = wheelRadius;

        curHue = (Math.atan2(dy, dx) * 180 / Math.PI + 360) % 360;
        curSat = dist / wheelRadius;

        applyHSBToCurrent();
        updateBrightnessBarBitmap();
    }

    function updateBrightVal(my:Float):Void
    {
        var relY = my - brightBar.y;
        curBrt = FlxMath.bound(1.0 - (relY / brightBar.height), 0.0, 1.0);
        applyHSBToCurrent();
    }

    function applyHSBToCurrent():Void
    {
        var col:FlxColor = FlxColor.fromHSB(curHue, curSat, curBrt);
        current_ColorVals[0] = col.red;
        current_ColorVals[1] = col.green;
        current_ColorVals[2] = col.blue;

        saveColor();
        updateWheelCursors();
        updateUI();
    }

    function updateUI():Void
    {
        var curCol:FlxColor = FlxColor.fromRGB(current_ColorVals[0], current_ColorVals[1], current_ColorVals[2]);
        colorSwatch.color = curCol;

        if (rValText != null) rValText.text = Std.string(current_ColorVals[0]);
        if (gValText != null) gValText.text = Std.string(current_ColorVals[1]);
        if (bValText != null) bValText.text = Std.string(current_ColorVals[2]);

        if (hexButton != null)
        {
            if (hexEditing)
            {
                var blink = (Math.floor(FlxG.game.ticks / 320) % 2 == 0) ? "_" : " ";
                hexButton.label.text = "#" + (hexBuffer + blink + "______").substr(0, 6);
                hexButton.isFocused = true;
            }
            else
            {
                hexButton.label.text = "#" + hexFromRGB();
                hexButton.isFocused = false;
            }
        }

        if (hintText != null)
        {
            if (hexEditing)
                hintText.text = "HEX: TYPE 0-9 / A-F (OR CTRL+V TO PASTE)  •  ENTER: CONFIRM  •  ESC: CANCEL";
            else
                hintText.text = "COLOR WHEEL / BRIGHTNESS  •  CLICK NOTE TO SELECT  •  CLICK HEX BOX OR PRESS ENTER TO WRITE  •  ESC: EXIT";
        }
    }

    function getTypedHexChar():String
    {
        // 0-9 top row
        for (i in 0...10)
        {
            var k:FlxKey = FlxKey.ZERO + i;
            if (FlxG.keys.checkStatus(k, JUST_PRESSED))
                return Std.string(i);
        }

        // 0-9 numpad
        for (i in 0...10)
        {
            var k:FlxKey = FlxKey.NUMPADZERO + i;
            if (FlxG.keys.checkStatus(k, JUST_PRESSED))
                return Std.string(i);
        }

        // A-F keys
        var letters:Array<FlxKey> = [FlxKey.A, FlxKey.B, FlxKey.C, FlxKey.D, FlxKey.E, FlxKey.F];
        var chars:Array<String> = ["A", "B", "C", "D", "E", "F"];
        for (i in 0...letters.length)
        {
            if (FlxG.keys.checkStatus(letters[i], JUST_PRESSED))
                return chars[i];
        }

        return null;
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        var mPos = FlxG.mouse.getWorldPosition(uiCamera);
        var mx:Float = mPos.x;
        var my:Float = mPos.y;

        // Mouse interactions for Color Wheel & Brightness Slider
        if (FlxG.mouse.justPressed)
        {
            if (hexEditing && hexButton != null)
            {
                var hxOver = (mx >= hexButton.x && mx <= hexButton.x + hexButton.bg.width &&
                              my >= hexButton.y && my <= hexButton.y + hexButton.bg.height);
                if (!hxOver)
                {
                    stopHexEditing(true);
                }
            }

            var wdx = mx - (wheelSprite.x + wheelRadius);
            var wdy = my - (wheelSprite.y + wheelRadius);
            var wdist = Math.sqrt(wdx * wdx + wdy * wdy);
            if (wdist <= wheelRadius + 8)
            {
                draggingWheel = true;
                updateWheelColor(mx, my);
            }
            else if (mx >= brightBar.x - 10 && mx <= brightBar.x + brightBar.width + 10 &&
                     my >= brightBar.y - 6 && my <= brightBar.y + brightBar.height + 6)
            {
                draggingBright = true;
                updateBrightVal(my);
            }
            else
            {
                // Check clicking on preview notes
                for (i in 0...note_Group.length)
                {
                    var n = note_Group.members[i];
                    if (n != null && mx >= n.x - 8 && mx <= n.x + n.width + 8 && my >= n.y - 8 && my <= n.y + n.height + 30)
                    {
                        selectControlTo(i);
                        break;
                    }
                }
            }
        }

        if (FlxG.mouse.pressed)
        {
            if (draggingWheel)
                updateWheelColor(mx, my);
            else if (draggingBright)
                updateBrightVal(my);
        }

        if (FlxG.mouse.justReleased)
        {
            draggingWheel = false;
            draggingBright = false;
        }

        // Hex Editing Input
        if (hexEditing)
        {
            if (hexButton != null)
            {
                var blink = (Math.floor(FlxG.game.ticks / 320) % 2 == 0) ? "_" : " ";
                hexButton.label.text = "#" + (hexBuffer + blink + "______").substr(0, 6);
            }

            // Clipboard Paste (Ctrl+V)
            if ((FlxG.keys.pressed.CONTROL || FlxG.keys.pressed.WINDOWS) && FlxG.keys.justPressed.V)
            {
                var clip:String = "";
                #if lime
                clip = lime.system.Clipboard.text;
                #elseif openfl
                clip = openfl.system.Clipboard.text;
                #end
                if (clip != null && clip.length > 0)
                {
                    clip = clip.trim();
                    if (clip.startsWith("#")) clip = clip.substr(1);
                    var valid = "";
                    for (ch in clip)
                    {
                        if ((ch >= '0'.code && ch <= '9'.code) || (ch >= 'a'.code && ch <= 'f'.code) || (ch >= 'A'.code && ch <= 'F'.code))
                            valid += String.fromCharCode(ch).toUpperCase();
                    }
                    if (valid.length >= 6)
                    {
                        hexBuffer = valid.substr(0, 6);
                        applyHex(false);
                        updateUI();
                        return;
                    }
                    else if (valid.length > 0)
                    {
                        hexBuffer = (hexBuffer + valid).substr(0, 6);
                        if (hexBuffer.length == 6)
                            applyHex(false);
                        updateUI();
                        return;
                    }
                }
            }

            var typed = getTypedHexChar();
            if (typed != null && hexBuffer.length < 6)
            {
                hexBuffer += typed;
                if (hexBuffer.length == 6)
                    applyHex(false);
                updateUI();
                return;
            }

            if (FlxG.keys.justPressed.BACKSPACE && hexBuffer.length > 0)
            {
                hexBuffer = hexBuffer.substr(0, hexBuffer.length - 1);
                updateUI();
                return;
            }

            if (controls.ACCEPT || FlxG.keys.justPressed.ENTER)
            {
                stopHexEditing(true);
                return;
            }

            if (FlxG.keys.justPressed.ESCAPE)
            {
                stopHexEditing(false);
                return;
            }
            return;
        }

        // Direct typing to start hex editing (0-9, B, C, E, F; A & D reserved for navigation)
        var directTyped = getTypedHexChar();
        if (directTyped != null && directTyped != "A" && directTyped != "D")
        {
            startHexEditing();
            hexBuffer = directTyped;
            updateUI();
            return;
        }

        // Keyboard navigation
        if (controls.BACK || FlxG.keys.justPressed.ESCAPE)
        {
            FlxG.mouse.visible = false;
            close();
            return;
        }

        if (controls.LEFT_P)
        {
            selectControlTo((selectedControl - 1 + key_Count) % key_Count);
            return;
        }

        if (controls.RIGHT_P)
        {
            selectControlTo((selectedControl + 1) % key_Count);
            return;
        }

        if (controls.RESET || FlxG.keys.justPressed.R)
        {
            resetSelectedColor();
            return;
        }

        if (controls.ACCEPT || FlxG.keys.justPressed.ENTER)
        {
            startHexEditing();
            return;
        }
    }

    function safeCoolFile(path:String):Array<String>
    {
        try {
            if (path != null && Assets.exists(path))
                return CoolUtil.coolTextFile(path);
        } catch(e:Dynamic) {}
        return [];
    }

    function cfg(arr:Array<String>, idx:Int, def:String):String
    {
        if (arr != null && arr.length > idx && arr[idx] != null && arr[idx] != "")
            return arr[idx];
        return def;
    }

    function parseSafe(arr:Array<String>, idx:Int, def:Float):Float
    {
        var v = Std.parseFloat(cfg(arr, idx, Std.string(def)));
        return Math.isNaN(v) ? def : v;
    }

    function loadSkinConfigs():Void
    {
        ui_settings = safeCoolFile(Paths.txt("ui skins/" + ui_Skin + "/config"));
        if (ui_settings == null || ui_settings.length < 4)
            ui_settings = safeCoolFile(Paths.txt("ui skins/default/config"));
        if (ui_settings == null || ui_settings.length < 4)
            ui_settings = ["0.7", "0.7", "1", "true"];

        mania_size = safeCoolFile(Paths.txt("ui skins/" + ui_Skin + "/maniasize"));
        if (mania_size == null || mania_size.length < 4)
            mania_size = safeCoolFile(Paths.txt("ui skins/default/maniasize"));
        if (mania_size == null || mania_size.length < 4)
            mania_size = ["0.0", "0.0", "0.0", "0.0", "0.0", "0.0", "0.0", "0.0", "0.0", "0.0"];

        mania_offset = safeCoolFile(Paths.txt("ui skins/" + ui_Skin + "/maniaoffset"));
        if (mania_offset == null || mania_offset.length < 4)
            mania_offset = safeCoolFile(Paths.txt("ui skins/default/maniaoffset"));

        mania_gap = safeCoolFile(Paths.txt("ui skins/" + ui_Skin + "/maniagap"));
        if (mania_gap == null || mania_gap.length < 4)
            mania_gap = safeCoolFile(Paths.txt("ui skins/default/maniagap"));
    }

    function framesContainPrefix(atl:FlxFramesCollection, prefix:String):Bool
    {
        if (atl == null || atl.frames == null) return false;
        for (frame in atl.frames)
            if (frame != null && frame.name != null && frame.name.startsWith(prefix))
                return true;
        return false;
    }

    function getNoteFrames():FlxAtlasFrames
    {
        var cacheKey = 'default_${ui_Skin}_true';
        if (NOTES_FRAMES_CACHE.exists(cacheKey)) {
            var cached = NOTES_FRAMES_CACHE.get(cacheKey);
            if (cached != null && cached.parent != null && !cached.parent.isDestroyed)
                return cached;
            NOTES_FRAMES_CACHE.remove(cacheKey);
        }

        var result:FlxAtlasFrames = null;
        var defaultSkinPath = 'ui skins/default/arrows/';
        var skinPath = 'ui skins/${ui_Skin}/arrows/';

        try {
            if (Assets.exists(Paths.image(skinPath + "default", "shared")))
                result = Paths.getSparrowAtlas(skinPath + "default", "shared", true);
            else if (Assets.exists(Paths.image(skinPath + "strums", "shared")))
                result = Paths.getSparrowAtlas(skinPath + "strums", "shared", true);
            else if (Assets.exists(Paths.image(skinPath + "NOTE_assets", "shared")))
                result = Paths.getSparrowAtlas(skinPath + "NOTE_assets", "shared", true);
            else if (Assets.exists(Paths.image(defaultSkinPath + "default", "shared")))
                result = Paths.getSparrowAtlas(defaultSkinPath + "default", "shared", true);
            else if (Assets.exists(Paths.image(defaultSkinPath + "strums", "shared")))
                result = Paths.getSparrowAtlas(defaultSkinPath + "strums", "shared", true);
            else
                result = Paths.getSparrowAtlas("ui skins/default/arrows/default", "shared", false);
        } catch(e:Dynamic) {}

        if (result != null)
            NOTES_FRAMES_CACHE.set(cacheKey, result);
        return result;
    }

    override function destroy()
    {
        if (instance == this)
            instance = null;

        FlxG.mouse.visible = false;

        if (uiCamera != null)
        {
            if (FlxG.cameras != null && FlxG.cameras.list.contains(uiCamera))
                FlxG.cameras.remove(uiCamera, true);
            uiCamera = null;
        }

        if (note_Group != null)
            note_Group.clear();

        noteSwaps = [];
        NOTES_FRAMES_CACHE.clear();

        super.destroy();
    }
}
