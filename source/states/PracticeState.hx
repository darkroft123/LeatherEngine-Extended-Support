package states;

import flixel.FlxSprite;
import flixel.addons.display.FlxBackdrop;
import flixel.addons.display.FlxGridOverlay;
import openfl.display.BlendMode;
import game.Conductor;
import flixel.FlxG;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.group.FlxGroup.FlxTypedGroup;
import shaders.Shaders.GreyscaleEffect;
import substates.BlockedAndErrorSubState;
import lime.utils.Assets;
import game.SongLoader;
import ui.Checkbox;
import ui.InfoBanner;
import utilities.MenuAnims;

typedef PracticeDiff = {
    var name:String;
    var practices:Array<{ label:String, startTime:Float, endTime:Float }>;
}

typedef PracticeSong = {
    var name:String;
    var diffs:Array<PracticeDiff>;
}

class PracticeState extends MusicBeatState
{
    var practiceSongs:Array<PracticeSong> = [];
    static final EXPECTED_HASH:String = "89e7625eee118c609dc4b7f621f09232";

    var songTexts:FlxTypedGroup<FlxText>;
    var practiceTexts:FlxTypedGroup<FlxText>;
    var diffText:FlxText;

    public static var targetSongName:String = null;
    public static var targetDiffName:String = null;
    public static var fromPlayState:Bool = false;

    var curSelected:Int = 0;
    var songPage:Int = 0;
    var practiceSelected:Int = 0;
    var practicePage:Int = 0;
    var curDiff:Int = 0;

    var songVisible:Int = 8;
    var practiceVisible:Int = 4;

    var startY:Int = 160;
    var spacing:Int = 60;

    var inPractice:Bool = false;
    var transitioning:Bool = false;
    var idleTimer:Float = 0;

    var greyscale:GreyscaleEffect;
    var bg:FlxSprite;
    var ajedrez:FlxBackdrop;
    var rightPanel:FlxSprite;
    var topPanel:FlxSprite;
    var bottomPanel:FlxSprite;
    var titleText:FlxText;

    var topCheckboxes:Array<Checkbox> = [];
    var checkboxTexts:Array<FlxText> = [];
    var topLabels:Array<String> = ["Shaders", "Disable\nScripts", "Chars and BGs"];
    var topKeys:Array<String> = ["shaders", "forceDisableScripts", "charsAndBGs"];
    var activeTweens:Array<FlxTween> = [];

    var speedText:FlxText;
    var curSpeed:Float = 1.0;

    static inline var SPEED_MIN:Float = 0.25;
    static inline var SPEED_STEP:Float = 0.05;

    inline function makePanel(x:Float, y:Float, w:Int, h:Int, color:Int):FlxSprite
    {
        var s = new FlxSprite(x, y).makeGraphic(w, h, color);
        s.scrollFactor.set();
        s.shader = greyscale.shader;
        add(s);
        return s;
    }

    inline function getCurrentSong():PracticeSong
    {
        return practiceSongs[curSelected];
    }

    inline function getCurrentDiff():PracticeDiff
    {
        return practiceSongs[curSelected].diffs[curDiff];
    }

    function trackTween(t:FlxTween):FlxTween
    {
        if (t != null)
            activeTweens.push(t);
        return t;
    }

    function cancelTweens():Void
    {
        MenuAnims.cancelAll(activeTweens);
    }

    override public function create():Void
    {
        greyscale = new GreyscaleEffect();

        FlxG.mouse.visible = true;

        bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF183C10);
        bg.scrollFactor.set();
        add(bg);

        var rawJson:String = "";
        try {
            var path = #if MODDING_ALLOWED 'mods/${utilities.Options.getData("curMod")}/data/practices.json'; #else 'assets/preload/data/practices.json'; #end
            if (sys.FileSystem.exists(path)) {
                rawJson = sys.io.File.getContent(path);
            } else {
                rawJson = lime.utils.Assets.getText("assets/preload/data/practices.json");
            }

            practiceSongs = haxe.Json.parse(rawJson);
        } catch(e:Dynamic) {
            trace("Error loading practices.json: " + e);
            practiceSongs = [{
                name: "ERROR LOADING DATA",
                diffs: [{ name: "ERROR", practices: [{label:"NONE", startTime:0, endTime:0}] }]
            }];
        }

        ajedrez = new FlxBackdrop(
            FlxGridOverlay.createGrid(30, 30, FlxG.width, FlxG.height, true, FlxColor.BLACK, FlxColor.WHITE)
        );
        ajedrez.blend = BlendMode.ADD;
        ajedrez.scale.set(3, 3);
        ajedrez.alpha = 0.1;
        ajedrez.velocity.set(Conductor.crochet);
        add(ajedrez);

        rightPanel = makePanel(650, -50, 500, FlxG.height + 150, 0xFF242322);
        bottomPanel = makePanel(-120, FlxG.height - 50, FlxG.width + 150, 100, FlxColor.BLACK);

        topPanel = makePanel(-20, -20, 600, 100, FlxColor.BLACK);

        titleText = new FlxText(0, 0, topPanel.width, "PRACTICE MODE", 32);
        titleText.setFormat(Paths.font("Ethnocentric-Regular.otf"), 32, FlxColor.WHITE, CENTER);
        titleText.scrollFactor.set();
        titleText.x = topPanel.x + (topPanel.width - titleText.width) / 2;
        titleText.y = topPanel.y + 40;
        add(titleText);

        songTexts = new FlxTypedGroup<FlxText>();
        practiceTexts = new FlxTypedGroup<FlxText>();
        add(songTexts);
        add(practiceTexts);

        diffText = new FlxText(0, 0, 500, "", 28);
        diffText.setFormat(Paths.font("Ethnocentric-Regular.otf"), 28, FlxColor.WHITE, CENTER);
        diffText.scrollFactor.set();
        diffText.x = rightPanel.x;
        diffText.y = rightPanel.y + rightPanel.height - 250;
        add(diffText);

        createCheckboxes();

        speedText = new FlxText(0, 0, 500, "", 22);
        speedText.setFormat(Paths.font("Ethnocentric-Regular.otf"), 22, FlxColor.WHITE, CENTER);
        speedText.scrollFactor.set();
        speedText.x = diffText.x;
        speedText.y = diffText.y + 40;
        add(speedText);

        var infoBanner = new InfoBanner(FlxColor.BLACK, 1, 24, Paths.font("vcr.ttf"), 0xFF00FFC8);
        add(infoBanner);
        infoBanner.show([
            "UP / DOWN - SELECT PRACTICE",
            "LEFT / RIGHT - CHANGE DIFFICULTY",
            "SHIFT + LEFT / RIGHT - SCROLL SPEED",
            "ENTER - START PRACTICE",
            "ESC - BACK"
        ], 3.0);

        updateSpeedText();

        greyscale.radius = 0.035;
        greyscale.borderSize = 0.0075;
        greyscale.smoothness = 0.001;
        greyscale.bordersEnabled = true;
        greyscale.update(0);

        if (targetSongName != null)
        {
            for (i in 0...practiceSongs.length)
            {
                if (practiceSongs[i].name.toLowerCase() == targetSongName.toLowerCase())
                {
                    curSelected = i;
                    if (targetDiffName != null)
                    {
                        for (d in 0...practiceSongs[i].diffs.length)
                        {
                            if (practiceSongs[i].diffs[d].name.toLowerCase() == targetDiffName.toLowerCase())
                            {
                                curDiff = d;
                                break;
                            }
                        }
                    }
                    break;
                }
            }
            targetSongName = null;
            targetDiffName = null;
        }

        songPage = Std.int(curSelected / songVisible) * songVisible;

        rebuildSongs();
        rebuildPractices();
        playEntrance();

        super.create();
    }

    function playEntrance():Void
    {
        var targetTopY = topPanel.y;
        var targetTitleY = titleText.y;
        topPanel.y = targetTopY - 90;
        titleText.y = targetTitleY - 90;
        titleText.alpha = 0;
        trackTween(FlxTween.tween(topPanel, {y: targetTopY}, 0.38, {ease: FlxEase.quartOut}));
        trackTween(FlxTween.tween(titleText, {y: targetTitleY, alpha: 1}, 0.38, {ease: FlxEase.quartOut}));

        var targetRightX = rightPanel.x;
        rightPanel.x = targetRightX + 90;
        rightPanel.alpha = 0;
        trackTween(FlxTween.tween(rightPanel, {x: targetRightX, alpha: 1}, 0.40, {ease: FlxEase.quartOut}));

        diffText.alpha = 0;
        speedText.alpha = 0;
        trackTween(FlxTween.tween(diffText, {alpha: 1}, 0.35, {ease: FlxEase.quartOut, startDelay: 0.12}));
        trackTween(FlxTween.tween(speedText, {alpha: 1}, 0.35, {ease: FlxEase.quartOut, startDelay: 0.16}));

        for (i in 0...checkboxTexts.length)
        {
            var t = checkboxTexts[i];
            t.alpha = 0;
            trackTween(FlxTween.tween(t, {alpha: 1}, 0.30, {ease: FlxEase.quartOut, startDelay: 0.08 + i * 0.05}));
        }
        for (i in 0...topCheckboxes.length)
        {
            var cb = topCheckboxes[i];
            cb.alpha = 0;
            trackTween(FlxTween.tween(cb, {alpha: 1}, 0.30, {ease: FlxEase.quartOut, startDelay: 0.08 + i * 0.05}));
        }
    }

    function createCheckboxes():Void
    {
        var topY = diffText.y - 500;
        var spacingX = 250;

        for (i in 0...topLabels.length - 1)
        {
            var txt = new FlxText(rightPanel.x + 20 + i * spacingX, topY, 300, topLabels[i]);
            txt.setFormat(Paths.font("Ethnocentric-Regular.otf"), 26, FlxColor.WHITE, LEFT);
            txt.scrollFactor.set();
            add(txt);
            checkboxTexts.push(txt);

            var cb = new Checkbox(txt);

            cb.manualOffsetX = 150;
            cb.checked = Options.getData(topKeys[i]);
            cb.setGraphicSize(Std.int(cb.width * 0.5));
            cb.updateHitbox();
            add(cb);

            topCheckboxes.push(cb);
        }

        var lastIndex = topLabels.length - 1;
        var bottomY = rightPanel.y + 200;

        var txt = new FlxText(rightPanel.x + 70, bottomY, 400, topLabels[lastIndex]);
        txt.setFormat(Paths.font("Ethnocentric-Regular.otf"), 26, FlxColor.WHITE, LEFT);
        txt.scrollFactor.set();
        add(txt);
        checkboxTexts.push(txt);

        var cb = new Checkbox(txt);
        cb.useDefaultOffset = false;
        cb.manualOffsetX = -80;
        cb.checked = Options.getData(topKeys[lastIndex]);
        cb.setGraphicSize(Std.int(cb.width * 0.5));
        cb.updateHitbox();
        add(cb);

        topCheckboxes.push(cb);
    }

    function rebuildSongs():Void
    {
        songTexts.clear();

        for (i in 0...songVisible)
        {
            var idx = songPage + i;
            if (idx >= practiceSongs.length)
                break;

            var t = new FlxText(50, startY + i * spacing, 600, practiceSongs[idx].name, 36);
            t.setFormat(Paths.font("Ethnocentric-Regular.otf"), 36, FlxColor.BLACK, LEFT);
            t.scrollFactor.set();
            t.ID = idx;
            t.alpha = 0;
            trackTween(FlxTween.tween(t, {alpha: 1}, 0.20, {ease: FlxEase.quartOut, startDelay: i * 0.02}));
            songTexts.add(t);
        }

        updateSongs();
    }

    function rebuildPractices():Void
    {
        practiceTexts.clear();

        var diff = getCurrentDiff();
        var list = diff.practices;
        var totalH = practiceVisible * spacing;
        var baseY = rightPanel.y + (rightPanel.height - totalH) / 2 - 40;

        for (i in 0...practiceVisible)
        {
            var idx = practicePage + i;
            if (idx >= list.length)
                break;

            var t = new FlxText(rightPanel.x, baseY + i * spacing, rightPanel.width, list[idx].label, 32);
            t.setFormat(Paths.font("Ethnocentric-Regular.otf"), 32, FlxColor.BLACK, CENTER);
            t.scrollFactor.set();
            t.ID = idx;
            t.alpha = 0;
            trackTween(FlxTween.tween(t, {alpha: 1}, 0.20, {ease: FlxEase.quartOut, startDelay: i * 0.025}));
            practiceTexts.add(t);
        }

        diffText.text = "< " + diff.name + " >";
        updatePractices();
    }

    function updateSongs():Void
    {
        for (t in songTexts.members)
        {
            if (t != null)
                t.color = (!inPractice && t.ID == curSelected) ? FlxColor.WHITE : FlxColor.BLACK;
        }
    }

    function updateSpeedText():Void
    {
        curSpeed = Math.round(curSpeed * 100) / 100;
        speedText.text = "SCROLL SPEED : " + curSpeed;
    }

    function punchText(t:FlxText):Void
    {
        MenuAnims.punchScale(t, 1.12, 1.12, 1.0, 1.0, 0.18, activeTweens);
    }

    function updatePractices():Void
    {
        for (t in practiceTexts.members)
        {
            if (t != null)
                t.color = (inPractice && t.ID == practiceSelected) ? FlxColor.WHITE : FlxColor.BLACK;
        }
    }

    function animateItemLists(elapsed:Float):Void
    {
        var smooth = MenuAnims.smooth(elapsed, 12.0);

        for (t in songTexts.members)
        {
            if (t == null) continue;
            var active = (!inPractice && t.ID == curSelected);
            var targetX:Float = active ? 68 : 50;
            var targetScale:Float = active ? 1.05 : 1.0;
            var targetAlpha:Float = active ? 1.0 : (inPractice ? 0.50 : 0.78);

            t.x = FlxMath.lerp(t.x, targetX, smooth);
            var s = FlxMath.lerp(t.scale.x, targetScale, smooth);
            t.scale.set(s, s);
            t.alpha = FlxMath.lerp(t.alpha, targetAlpha, smooth);
        }

        for (t in practiceTexts.members)
        {
            if (t == null) continue;
            var active = (inPractice && t.ID == practiceSelected);
            var targetScale:Float = active ? 1.08 : 1.0;
            var targetAlpha:Float = active ? 1.0 : (inPractice ? 0.72 : 0.55);

            var s = FlxMath.lerp(t.scale.x, targetScale, smooth);
            t.scale.set(s, s);
            t.alpha = FlxMath.lerp(t.alpha, targetAlpha, smooth);
        }
    }

    function moveSongs(dir:Int):Void
    {
        curSelected += dir;

        if (curSelected < 0)
            curSelected = practiceSongs.length - 1;
        else if (curSelected >= practiceSongs.length)
            curSelected = 0;

        songPage = Std.int(curSelected / songVisible) * songVisible;
        curDiff = 0;
        practiceSelected = 0;
        practicePage = 0;

        rebuildSongs();
        rebuildPractices();
        FlxG.sound.play(Paths.sound("scrollMenu"), 0.4);
    }

    function movePractices(dir:Int):Void
    {
        var list = getCurrentDiff().practices;
        practiceSelected += dir;

        if (practiceSelected < 0)
            practiceSelected = list.length - 1;
        else if (practiceSelected >= list.length)
            practiceSelected = 0;

        practicePage = Std.int(practiceSelected / practiceVisible) * practiceVisible;

        rebuildPractices();
        FlxG.sound.play(Paths.sound("scrollMenu"), 0.4);
    }

    function moveDiff(dir:Int):Void
    {
        var diffs = getCurrentSong().diffs;
        if (diffs.length <= 1)
            return;

        curDiff += dir;

        if (curDiff < 0)
            curDiff = diffs.length - 1;
        else if (curDiff >= diffs.length)
            curDiff = 0;

        practiceSelected = 0;
        practicePage = 0;

        rebuildPractices();
        punchText(diffText);
        FlxG.sound.play(Paths.sound("scrollMenu"), 0.4);
    }

    function chartExists(songName:String, diff:String, ?mix:String):Bool
    {
        var path = SongLoader.getPath(diff, songName, mix);
        return Assets.exists(path);
    }

    function syncCheckboxOptions():Void
    {
        for (i in 0...topCheckboxes.length)
        {
            var cb = topCheckboxes[i];
            var key = topKeys[i];

            if (cb.checked != Options.getData(key))
                Options.setData(cb.checked, key);
        }
    }

    function startPractice():Void
    {
        if (transitioning)
            return;

        var song = getCurrentSong();
        var diff = getCurrentDiff();
        var practice = diff.practices[practiceSelected];

        if (!chartExists(song.name, diff.name))
        {
            if (!Options.getData("autoOpenCharter"))
            {
                openSubState(new BlockedAndErrorSubState(
                    song.name.toLowerCase() + " (" + diff.name.toUpperCase() + ") doesn't seem to exist!",
                    "Leather Engine's No Crash, We Help Fix Stuff Tool"
                ));
            }

            FlxG.sound.play(Paths.sound("cancelMenu"));
            return;
        }

        transitioning = true;
        FlxG.sound.play(Paths.sound("confirmMenu"));
        greyscale.enter = 1.0;

        PlayState.songMultiplier = curSpeed;
        PlayState.SONG = SongLoader.loadFromJson(diff.name, song.name.toLowerCase());
        PlayState.isStoryMode = false;
        PlayState.storyDifficultyStr = diff.name.toUpperCase();
        PlayState.loadChartEvents = true;
        PlayState.practiceMode = true;
        PlayState.practiceStartTime = practice.startTime;
        PlayState.practiceEndTime = practice.endTime;
        PlayState.startOnTime = practice.startTime;

        LoadingState.loadAndSwitchState(() -> new PlayState());
    }

    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);
        idleTimer += elapsed;

        if (greyscale != null)
            greyscale.update(elapsed);

        if (subState != null) return;

        animateItemLists(elapsed);

        if (transitioning) return;

        if (!inPractice)
        {
            if (FlxG.keys.justPressed.UP || controls.UP_P)
                moveSongs(-1);

            if (FlxG.keys.justPressed.DOWN || controls.DOWN_P)
                moveSongs(1);

            if (FlxG.keys.justPressed.ENTER || controls.ACCEPT)
            {
                inPractice = true;
                updateSongs();
                updatePractices();
                FlxG.sound.play(Paths.sound("confirmMenu"));
            }

            if (controls.BACK)
            {
                if (fromPlayState)
                {
                    var title:String = utilities.Localization.getString("practice_exit_title", "WHERE DO YOU WANT TO GO?");
                    var msg:String = utilities.Localization.getString("practice_exit_msg", "You entered Practice Mode from Gameplay. Select your destination:");
                    var opts:Array<String> = [
                        utilities.Localization.getString("practice_exit_opt1", "RETURN TO GAMEPLAY"),
                        utilities.Localization.getString("practice_exit_opt2", "MAIN MENU"),
                        utilities.Localization.getString("practice_exit_opt3", "CANCEL")
                    ];

                    openSubState(new substates.CustomSelectSubState(
                        title,
                        msg,
                        opts,
                        function(idx:Int) {
                            if (idx == 0) {
                                fromPlayState = false;
                                LoadingState.loadAndSwitchState(() -> new PlayState());
                            } else if (idx == 1) {
                                fromPlayState = false;
                                FlxG.switchState(() -> new MainMenuState());
                            }
                        },
                        null
                    ));
                }
                else
                {
                    transitioning = true;
                    cancelTweens();
                    FlxG.sound.play(Paths.sound("cancelMenu"));
                    FlxG.switchState(() -> new MainMenuState());
                }
            }

            return;
        }

        if (FlxG.keys.justPressed.UP || controls.UP_P)
            movePractices(-1);

        if (FlxG.keys.justPressed.DOWN || controls.DOWN_P)
            movePractices(1);

        if (FlxG.keys.pressed.SHIFT)
        {
            if (FlxG.keys.justPressed.LEFT || controls.LEFT_P)
            {
                curSpeed = Math.max(SPEED_MIN, curSpeed - SPEED_STEP);
                updateSpeedText();
                punchText(speedText);
                FlxG.sound.play(Paths.sound("scrollMenu"), 0.4);
            }

            if (FlxG.keys.justPressed.RIGHT || controls.RIGHT_P)
            {
                curSpeed += SPEED_STEP;
                updateSpeedText();
                punchText(speedText);
                FlxG.sound.play(Paths.sound("scrollMenu"), 0.4);
            }
        }
        else
        {
            if (FlxG.keys.justPressed.LEFT || controls.LEFT_P)
                moveDiff(-1);

            if (FlxG.keys.justPressed.RIGHT || controls.RIGHT_P)
                moveDiff(1);
        }

        if (FlxG.keys.justPressed.ENTER || controls.ACCEPT)
            startPractice();

        syncCheckboxOptions();

        if (controls.BACK)
        {
            inPractice = false;
            updateSongs();
            updatePractices();
            FlxG.sound.play(Paths.sound("cancelMenu"));
        }
    }

    override public function destroy():Void
    {
        cancelTweens();
        super.destroy();
    }
}
