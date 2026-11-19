package substates;

import game.StrumNote;
import lime.utils.Assets;
import flixel.FlxCamera;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextBorderStyle;
import game.Note;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.group.FlxGroup;
import flixel.math.FlxRect;
import flixel.util.FlxColor;
import flixel.FlxG;
import flixel.FlxSprite;

class UISkinSelect extends MusicBeatSubstate
{
    public static inline var FONT_PATH:String = "vcr.ttf";
    public static inline var COLOR_TITLE:Int = 0xFF00FFD2;
    public static inline var COLOR_GOLD:Int = 0xFFFFB800;
    public static inline var COLOR_HINTS:Int = 0xFF888899;
    public static inline var P1_COLOR:Int = 0xFF66FF33;
    public static inline var P2_COLOR:Int = 0xFFFF0000;

    public var keyCount:Int = 4;
    public var previewGroup:FlxTypedGroup<FlxSprite> = new FlxTypedGroup<FlxSprite>();
    public var ui_Skin:String = Options.getData("uiSkin");
    public var ui_Skins:Array<String> = [];

    public var ui_settings:Array<String>;
    public var mania_gap:Array<String>;
    public var mania_size:Array<String>;
    public var mania_offset:Array<String>;

    public var titleText:FlxText;
    public var subtitleText:FlxText;
    public var stripText:FlxText;
    public var hintText:FlxText;
    public var infoLine:FlxText;
    public var bg:FlxSprite;

    public var leaving:Bool = false;
    public var curSelected:Int = 0;

    var panelX:Float;
    var panelY:Float;
    var panelW:Float;
    var panelH:Float;

    var uiCamera:FlxCamera;

    public function new()
    {
        super();

        uiCamera = new FlxCamera();
        uiCamera.bgColor.alpha = 0;
        FlxG.cameras.add(uiCamera, false);
        cameras = [uiCamera];

        bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        bg.alpha = 0;
        bg.scrollFactor.set();
        add(bg);

        FlxTween.tween(bg, {alpha: 0.85}, 0.6, {ease: FlxEase.circOut});

        ui_Skins = CoolUtil.coolTextFile(Paths.txt("uiSkinList"));
        if (ui_Skins == null || ui_Skins.length == 0) ui_Skins = ["default"];

        if(!ui_Skins.contains(ui_Skin))
        {
            Options.setData("default", "uiSkin");
            ui_Skin = "default";
        }

        curSelected = ui_Skins.indexOf(ui_Skin);
        if (curSelected < 0) curSelected = 0;

        panelX = 30;
        panelY = 100;
        panelW = FlxG.width - 60;
        panelH = 430;

        titleText = new FlxText(0, 15, FlxG.width, "UI SKIN SELECT");
        titleText.setFormat(FONT_PATH, 42, COLOR_TITLE, "center", FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        add(titleText);

        subtitleText = new FlxText(0, 64, FlxG.width, "");
        subtitleText.setFormat(FONT_PATH, 24, COLOR_GOLD, "center", FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        add(subtitleText);

        var stripW:Int = Std.int(panelW * 0.7);
        makeBox((FlxG.width - stripW) / 2, 600, stripW, 40);

        stripText = new FlxText((FlxG.width - stripW) / 2, 610, stripW, "");
        stripText.setFormat(FONT_PATH, 16, FlxColor.WHITE, "center", FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        add(stripText);

        infoLine = new FlxText(0, 648, FlxG.width, "");
        infoLine.setFormat(FONT_PATH, 14, FlxColor.YELLOW, "center", FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        add(infoLine);

        hintText = new FlxText(0, FlxG.height - 32, FlxG.width, "LEFT / RIGHT : CHANGE SKIN   •   ENTER : APPLY   •   ESC : EXIT");
        hintText.setFormat(FONT_PATH, 14, COLOR_HINTS, "center", FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        add(hintText);

        refreshTexts();

        #if PRELOAD_ALL
        rebuildPreview();
        #else
        leaving = true;
        Assets.loadLibrary("shared").onComplete(function (_) {
            leaving = false;
            rebuildPreview();
        });
        #end
    }

    function makeBox(x:Float, y:Float, w:Int, h:Int):FlxSprite
    {
        var outerBorder = new FlxSprite(x - 3, y - 3).makeGraphic(w + 6, h + 6, COLOR_TITLE);
        var innerBorder = new FlxSprite(x - 1, y - 1).makeGraphic(w + 2, h + 2, 0xFF120024);
        var box = new FlxSprite(x, y).makeGraphic(w, h, 0xFF0A0A10);

        outerBorder.alpha = 0.3;
        innerBorder.alpha = 0.8;
        box.alpha = 0.9;

        add(outerBorder);
        add(innerBorder);
        add(box);

        return box;
    }

    function refreshTexts():Void
    {
        subtitleText.text = "SELECTED:  > " + ui_Skin.toUpperCase() + " <";
        stripText.text = "CURRENT SKIN: [ " + Options.getData("uiSkin") + " ]      PRESS ENTER TO APPLY";

        var s = ui_Skin.toLowerCase();
        if (ui_Skin == "default")
            infoLine.text = "NOTESKINS FALL BACK TO DEFAULT ON SONGS WITHOUT CUSTOM UI.";
        else if (ui_Skin == "Corrupted" || ui_Skin == "Corrupted Glitched" || ui_Skin == "Resort" || ui_Skin == "scalable cel")
            infoLine.text = "THIS SKIN WAS ORIGINALLY MADE ONLY FOR 4K. MULTIKEY MAY LOOK WEIRD BUT WILL STILL WORK!";
        else
            infoLine.text = "";
    }

    override function update(elapsed:Float) {
        super.update(elapsed);

        var left = controls.LEFT_P;
        var right = controls.RIGHT_P;
        var accepted = controls.ACCEPT;
        var back = controls.BACK;

        if(back && !leaving)
        {
            leaving = true;

            FlxG.save.flush();

            FlxTween.tween(bg, {alpha: 0}, 0.4, {ease: FlxEase.circOut, startDelay: 0,
                onUpdate: function(tween:FlxTween) {
                    for(x in previewGroup.members)
                    {
                        if (x != null) x.alpha = bg.alpha;
                    }

                    titleText.alpha = bg.alpha;
                    subtitleText.alpha = bg.alpha;
                    stripText.alpha = bg.alpha;
                    hintText.alpha = bg.alpha * 0.9;
                    infoLine.alpha = 0;
                },
                onComplete: function(tween:FlxTween) {
                    close();
                }
            });
        }

        if((left || right) && !leaving)
        {
            if(left)
                curSelected--;
            if(right)
                curSelected++;

            if (curSelected < 0)
                curSelected = ui_Skins.length - 1;

            if (curSelected >= ui_Skins.length)
                curSelected = 0;

            ui_Skin = ui_Skins[curSelected];
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

            refreshTexts();
            rebuildPreview();
        }

        if(accepted && !leaving) {
            Options.setData(ui_Skin, "uiSkin");
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
            refreshTexts();
        }
    }

    function safeCoolFile(path:String):Array<String>
    {
        try {
            if (path != null && Assets.exists(path))
                return CoolUtil.coolTextFile(path);
        } catch(e:Dynamic) { Main.logSilentError(e, "UISkinSelect: safeCoolFile read"); }
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

    function skinImageExists(key:String):Bool
    {
        try {
            return Assets.exists(Paths.image(key));
        } catch(e:Dynamic) { Main.logSilentError(e, "UISkinSelect: skinImageExists check"); }
        return false;
    }

    function tryLoadSprite(key:String):FlxSprite
    {
        if (!skinImageExists(key)) return null;
        try {
            var s = new FlxSprite().loadGraphic(Paths.gpuBitmap(key));
            if (s.graphic != null && s.width > 0 && s.height > 0) return s;
            s.destroy();
        } catch(e:Dynamic) { Main.logSilentError(e, "UISkinSelect: tryLoadSprite load graphic"); }
        return null;
    }

    function tryLoadFirst(keys:Array<String>):FlxSprite
    {
        for (key in keys)
        {
            var s = tryLoadSprite(key);
            if (s != null) return s;
        }
        return null;
    }

    public function rebuildPreview():Void
    {
        for(x in previewGroup.members)
        {
            if (x != null) {
                FlxTween.cancelTweensOf(x);
                x.kill();
                x.destroy();
            }
        }
        previewGroup.clear();

        try {
            ui_settings = safeCoolFile(Paths.txt("ui skins/" + ui_Skin + "/config"));
            if (ui_settings == null || ui_settings.length < 5)
                ui_settings = safeCoolFile(Paths.txt("ui skins/default/config"));
            if (ui_settings == null) ui_settings = [];

            mania_size = safeCoolFile(Paths.txt("ui skins/" + ui_Skin + "/maniasize"));
            if (mania_size == null || mania_size.length < 4) mania_size = safeCoolFile(Paths.txt("ui skins/default/maniasize"));

            mania_offset = safeCoolFile(Paths.txt("ui skins/" + ui_Skin + "/maniaoffset"));
            if (mania_offset == null || mania_offset.length < 4) mania_offset = safeCoolFile(Paths.txt("ui skins/default/maniaoffset"));

            mania_gap = safeCoolFile(Paths.txt("ui skins/" + ui_Skin + "/maniagap"));
            if (mania_gap == null || mania_gap.length < 4) mania_gap = safeCoolFile(Paths.txt("ui skins/default/maniagap"));

            create_Arrows();
            createHealthBar();

            if (isTextHudSkin())
                createTextHUD();
            else
                createRatingSprites();
        } catch(e:Dynamic) {
            trace("UISkinSelect preview failed for '" + ui_Skin + "': " + e);
        }

        if (members.indexOf(previewGroup) != -1)
            remove(previewGroup);
        add(previewGroup);

        for(x in previewGroup.members)
        {
            if (x == null) continue;
            var targetAlpha = x.alpha;
            var targetY = x.y;
            x.alpha = 0;
            x.y = targetY - 10;
            FlxTween.tween(x, {y: targetY, alpha: targetAlpha}, 0.8, {ease: FlxEase.circOut});
        }
    }

    function isTextHudSkin():Bool
    {
        var s = ui_Skin.toLowerCase();
        return (s == "redemption" || s == "redemptiion");
    }

    function create_Arrows(?new_keyCount = 4)
    {
        if(new_keyCount != null)
            keyCount = new_keyCount;

        Note.swagWidth = 160 * 0.7;

        var gapVal = parseSafe(mania_gap, 3, 10);
        var offsetVal = parseSafe(mania_offset, 3, 0);

        var arrowsY = panelY + 105;

        for (i in 0...keyCount)
        {
            var babyArrow:StrumNote = new StrumNote(0, arrowsY, i, ui_Skin, ui_settings, mania_size, keyCount, 0.5);
            babyArrow.screenCenter(X);
            babyArrow.x += (babyArrow.width + (2 + gapVal)) * Math.abs(i) + offsetVal;
            babyArrow.scrollFactor.set();
            babyArrow.setPosition(babyArrow.x - (babyArrow.width * 1.4), babyArrow.y - (babyArrow.height / 2));
            babyArrow.ID = i;
            babyArrow.animation.play('static');
            previewGroup.add(babyArrow);
        }
    }

    function addPreviewSprite(spr:FlxSprite):Void
    {
        spr.scrollFactor.set();
        previewGroup.add(spr);
    }

    function fitWithin(spr:FlxSprite, maxW:Float, maxH:Float):Void
    {
        if (spr.width <= 0 || spr.height <= 0) return;
        var s = Math.min(maxW / spr.width, maxH / spr.height);
        if (s > 1) s = 1;
        spr.scale.set(spr.scale.x * s, spr.scale.y * s);
        spr.updateHitbox();
    }

    function createRatingSprites():Void
    {
        var rating_List:Array<String> = ['marvelous', 'sick', 'good', 'bad', 'shit'];

        var mult = parseSafe(ui_settings, 0, 0.7) * parseSafe(ui_settings, 4, 0.7);
        if (mult <= 0) mult = 0.49;
        var aa = cfg(ui_settings, 3, "true") == "true" && Options.getData("antialiasing");

        for(i in 0...rating_List.length)
        {
            var rating = tryLoadFirst([
                "ui skins/" + ui_Skin + "/ratings/" + rating_List[i],
                "ui skins/default/ratings/" + rating_List[i]
            ]);
            if (rating == null) continue;

            rating.setPosition(panelX + 35, panelY + 45 + (i * 76));
            rating.antialiasing = aa;
            rating.setGraphicSize(rating.width * mult);
            rating.updateHitbox();
            fitWithin(rating, 230, 70);

            addPreviewSprite(rating);
        }

        var comboX = panelX + panelW - 265;

        var combo = tryLoadFirst([
            "ui skins/" + ui_Skin + "/ratings/combo",
            "ui skins/default/ratings/combo"
        ]);
        if (combo != null)
        {
            combo.setPosition(comboX, panelY + 40);
            combo.antialiasing = aa;
            combo.setGraphicSize(combo.width * mult);
            combo.updateHitbox();
            fitWithin(combo, 230, 90);
            addPreviewSprite(combo);
        }

        var numMult = parseSafe(ui_settings, 1, 0.5);
        if (numMult <= 0) numMult = 0.5;

        for(i in 0...10)
        {
            var number = tryLoadFirst([
                "ui skins/" + ui_Skin + "/numbers/num" + i,
                "ui skins/default/numbers/num" + i
            ]);
            if (number == null) continue;

            number.setPosition(comboX + ((i % 3) * 62), panelY + 170 + ((Math.floor(i / 3)) * 68));
            number.antialiasing = aa;
            number.setGraphicSize(number.width * numMult);
            number.updateHitbox();

            addPreviewSprite(number);
        }
    }

    function hudFont():String
    {
        return Paths.font("vcr.ttf");
    }

    function createTextHUD():Void
    {
        var font = hudFont();

        inline function makeTxt(x:Float, y:Float, w:Float, text:String, size:Int, align:String, color:Int = FlxColor.WHITE):FlxText {
            var t = new FlxText(x, y, w, text, size);
            t.setFormat(font, size, color, align, FlxTextBorderStyle.SHADOW, FlxColor.BLACK);
            t.borderSize = 2;
            t.scrollFactor.set();
            return t;
        }

        var ratingNames:Array<String> = ["Marvelous!", "Sick!", "Good", "Bad", "Shit"];
        var ratingColors:Array<Int> = [COLOR_TITLE, P1_COLOR, COLOR_GOLD, 0xFFFF8800, P2_COLOR];

        for (i in 0...ratingNames.length)
        {
            var t = makeTxt(panelX + 40, panelY + 52 + (i * 76), 230, ratingNames[i], 24, "left", ratingColors[i]);
            t.borderSize = 3;
            if (i == 0) t.angle = -2;
            if (i == 4) t.angle = 2;
            addPreviewSprite(t);
        }

        var comboCaption = makeTxt(0, panelY + 120, panelW, "COMBO", 16, "center", COLOR_HINTS);
        addPreviewSprite(comboCaption);

        var comboNum = makeTxt(0, panelY + 140, panelW, "127", 34, "center");
        addPreviewSprite(comboNum);

        addPreviewSprite(makeTxt(0, panelY + 8, panelW, "128350", 26, "center"));
        addPreviewSprite(makeTxt(panelX + 30, panelY + panelH - 60, 320, "Accuracy: 98.5%", 18, "left"));
        addPreviewSprite(makeTxt(panelX + panelW - 350, panelY + panelH - 60, 320, "Misses: 0", 18, "right"));
    }

    function barLabel():Void
    {
        var label = new FlxText(0, panelY + 392, FlxG.width, "HEALTH BAR PREVIEW", 13);
        label.setFormat(FONT_PATH, 13, COLOR_HINTS, "center", FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        addPreviewSprite(label);
    }

    function createHealthBar():Void
    {
        var built:Bool = false;
        var s = ui_Skin.toLowerCase();

        try {
            if (s == "corrupted" || s == "corrupted glitched")
                built = buildTwoLayerBar(["barra de vida/full"], false, panelY + 285);
            else if (s == "mvp")
                built = buildMvpBar();
            else if (s == "matt v3")
                built = buildMattV3Bar();
            else if (s == "redemption" || s == "redemptiion")
                built = buildRedemptionBar();
            else if (s == "velma")
                built = buildSimpleBar("ui skins/velma/other/main", 470, 235);
            else if (s == "voiid" || s == "pixelvoiid")
                built = buildFilledBar(["barra de vida/newHealthBar", "ui skins/voiid/other/NewHealthBar"], 12, 15, 0.94);
            else if (s == "bsides")
                built = buildFilledBar(["ui skins/Bsides/other/healthbarSacorg"], 10, 22, 0.94);
        } catch(e:Dynamic) {
            trace("Custom bar preview failed for '" + ui_Skin + "': " + e);
            built = false;
        }

        if (!built)
            buildGenericBar();

        barLabel();
    }

    function buildGenericBar():Void
    {
        var spr = tryLoadFirst([
            "ui skins/" + ui_Skin + "/other/healthBar",
            "ui skins/default/other/healthBar"
        ]);

        if (spr != null)
        {
            fitWithin(spr, 520, 130);
            spr.screenCenter(X);
            spr.y = panelY + 290;
            spr.antialiasing = true;
            addPreviewSprite(spr);
        }
        else
        {
            var cx = FlxG.width / 2;
            var bw = 520;
            var bh = 34;
            var fb = new FlxSprite(cx - bw / 2, panelY + 290).makeGraphic(bw, bh, 0xFF2A2A35);
            var half = Std.int((bw - 4) / 2);
            var left = new FlxSprite(fb.x + 2, fb.y + 2).makeGraphic(half, bh - 4, P1_COLOR);
            var right = new FlxSprite(fb.x + bw / 2, fb.y + 2).makeGraphic(half, bh - 4, P2_COLOR);
            addPreviewSprite(fb);
            addPreviewSprite(left);
            addPreviewSprite(right);
        }
    }

    function buildSimpleBar(key:String, maxW:Float, maxH:Float):Bool
    {
        var spr = tryLoadSprite(key);
        if (spr == null) return false;

        fitWithin(spr, maxW, maxH);
        spr.screenCenter(X);
        spr.y = panelY + 265;
        spr.antialiasing = true;
        addPreviewSprite(spr);
        return true;
    }

    function centerPair(bottom:FlxSprite, top:FlxSprite, y:Float):Void
    {
        bottom.screenCenter(X);
        bottom.y = y;
        top.setPosition(bottom.x, bottom.y);
    }

    function buildTwoLayerBar(keys:Array<String>, anchorRight:Bool, y:Float):Bool
    {
        var bottom = tryLoadFirst(keys);
        if (bottom == null) return false;

        fitWithin(bottom, 540, 140);

        var top = tryLoadFirst(keys);
        if (top == null) { bottom.destroy(); return false; }
        top.scale.set(bottom.scale.x, bottom.scale.y);
        top.updateHitbox();

        centerPair(bottom, top, y);

        bottom.color = P1_COLOR;
        top.color = P2_COLOR;

        var rect:FlxRect;
        if (anchorRight)
            rect = new FlxRect(top.frameWidth * 0.5, 0, top.frameWidth * 0.5, top.frameHeight);
        else
            rect = new FlxRect(0, 0, top.frameWidth * 0.5, top.frameHeight);
        top.clipRect = rect;

        bottom.antialiasing = true;
        top.antialiasing = true;

        addPreviewSprite(bottom);
        addPreviewSprite(top);
        return true;
    }

    function buildFilledBar(keys:Array<String>, insetX:Float, insetY:Float, widthRatio:Float):Bool
    {
        var bgBar = tryLoadFirst(keys);
        if (bgBar == null) return false;

        fitWithin(bgBar, 520, 120);
        bgBar.screenCenter(X);
        bgBar.y = panelY + 290;
        bgBar.antialiasing = true;
        addPreviewSprite(bgBar);

        var innerW = bgBar.width * widthRatio;
        var innerH = bgBar.height - insetY * 2;
        if (innerH < 6) innerH = 6;
        var startX = bgBar.x + (bgBar.width - innerW) / 2;

        var half = Std.int(innerW / 2);
        if (half < 2) half = 2;

        var left = new FlxSprite(startX, bgBar.y + insetY).makeGraphic(half, Std.int(innerH), P1_COLOR);
        var right = new FlxSprite(startX + half, bgBar.y + insetY).makeGraphic(half, Std.int(innerH), P2_COLOR);

        left.antialiasing = false;
        right.antialiasing = false;

        addPreviewSprite(left);
        addPreviewSprite(right);
        return true;
    }

    function buildMvpBar():Bool
    {
        var bgBar = tryLoadSprite("barra de vida/healthbar2-mvp");
        if (bgBar == null) return false;

        var top = new FlxSprite();
        var bottom = new FlxSprite();

        try {
            top.frames = Paths.getSparrowAtlas("barra de vida/healthbar3-mvp");
            bottom.frames = Paths.getSparrowAtlas("barra de vida/healthbar3-mvp");
        } catch(e:Dynamic) {
            return false;
        }

        var added:Bool = false;
        for (i in 1...7)
        {
            var animName = Std.string(i);
            try {
                top.animation.addByPrefix(animName, "healthbar 6-" + i, 24, false);
                bottom.animation.addByPrefix(animName, "healthbar 6-" + i, 24, false);
                added = true;
            } catch(e:Dynamic) { Main.logSilentError(e, "UISkinSelect: load healthbar animation"); }
        }

        if (!added || !top.animation.exists("6") || !bottom.animation.exists("3"))
        {
            top.destroy();
            bottom.destroy();
            return false;
        }

        top.animation.play("6");
        bottom.animation.play("3");

        fitWithin(bgBar, 500, 125);
        bgBar.screenCenter(X);
        bgBar.y = panelY + 288;
        bgBar.antialiasing = true;
        addPreviewSprite(bgBar);

        fitWithin(top, 500, 125);
        fitWithin(bottom, 500, 125);
        top.setPosition(bgBar.x, bgBar.y);
        bottom.setPosition(bgBar.x, bgBar.y);

        top.color = P1_COLOR;
        bottom.color = P2_COLOR;

        top.antialiasing = true;
        bottom.antialiasing = true;

        addPreviewSprite(top);
        addPreviewSprite(bottom);
        return true;
    }

    function buildMattV3Bar():Bool
    {
        var frameSpr = tryLoadSprite("ui skins/Matt V3/other/healthBar");
        var fillSample = tryLoadSprite("ui skins/Matt V3/other/healthBarBar");
        if (frameSpr == null || fillSample == null)
        {
            if (frameSpr != null) frameSpr.destroy();
            if (fillSample != null) fillSample.destroy();
            return false;
        }
        fillSample.destroy();

        fitWithin(frameSpr, 540, 190);
        frameSpr.screenCenter(X);
        frameSpr.y = panelY + 272;
        frameSpr.antialiasing = true;
        addPreviewSprite(frameSpr);

        var bottom = tryLoadSprite("ui skins/Matt V3/other/healthBarBar");
        var top = tryLoadSprite("ui skins/Matt V3/other/healthBarBar");
        if (bottom == null || top == null)
        {
            if (bottom != null) bottom.destroy();
            if (top != null) top.destroy();
            return false;
        }

        fitWithin(bottom, 470, 110);
        top.scale.set(bottom.scale.x, bottom.scale.y);
        top.updateHitbox();

        centerPair(bottom, top, frameSpr.y + frameSpr.height * 0.32);

        bottom.color = P1_COLOR;
        top.color = P2_COLOR;

        var rect = new FlxRect(0, 0, top.frameWidth * 0.5, top.frameHeight);
        top.clipRect = rect;

        bottom.antialiasing = true;
        top.antialiasing = true;

        addPreviewSprite(bottom);
        addPreviewSprite(top);
        return true;
    }

    function buildRedemptionBar():Bool
    {
        var bgBar = tryLoadFirst([
            "ui skins/redemptiion/other/bar",
            "ui skins/Redemption/other/bar"
        ]);
        if (bgBar == null) return false;

        var maskKeys:Array<String> = [
            "ui skins/redemptiion/other/mask",
            "ui skins/Redemption/other/mask"
        ];

        var bottom = tryLoadFirst(maskKeys);
        if (bottom == null) { bgBar.destroy(); return false; }

        fitWithin(bgBar, 520, 130);

        var maskScale = bgBar.width / bottom.width;
        if (Math.isNaN(maskScale) || maskScale <= 0) { bgBar.destroy(); bottom.destroy(); return false; }
        bottom.scale.set(maskScale, maskScale);
        bottom.updateHitbox();

        var top = tryLoadFirst(maskKeys);
        if (top == null) { bgBar.destroy(); bottom.destroy(); return false; }
        top.scale.set(maskScale, maskScale);
        top.updateHitbox();

        bgBar.screenCenter(X);
        bgBar.y = panelY + 282;
        bgBar.antialiasing = true;
        addPreviewSprite(bgBar);

        bottom.screenCenter(X);
        bottom.y = bgBar.y + (bgBar.height - bottom.height) / 2;
        top.setPosition(bottom.x, bottom.y);

        bottom.color = P2_COLOR;
        top.color = P1_COLOR;

        var rect = new FlxRect(top.frameWidth * 0.5, 0, top.frameWidth * 0.5, top.frameHeight);
        top.clipRect = rect;

        bottom.antialiasing = true;
        top.antialiasing = true;

        addPreviewSprite(bottom);
        addPreviewSprite(top);
        return true;
    }

    override function destroy()
    {
        if (uiCamera != null) {
            if (FlxG.cameras != null && FlxG.cameras.list.contains(uiCamera)) {
                FlxG.cameras.remove(uiCamera, true);
            }
            uiCamera = null;
        }

        if (previewGroup != null) {
            for (x in previewGroup.members) {
                if (x != null) {
                    FlxTween.cancelTweensOf(x);
                    x.destroy();
                }
            }
            previewGroup.clear();
        }

        super.destroy();
    }
}
