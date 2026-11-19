package states;

import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.FlxSprite;
import ui.FreeplayTxt;
import flixel.FlxG;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import shaders.Shaders.GreyscaleEffect;
import shaders.Shaders.ChesslolEffect;
import flixel.math.FlxMath;
import sys.io.File;
import sys.FileSystem;
import lime.utils.Assets;
import haxe.Json;
import game.FreeplaySong;
import utilities.FiltersBG;
import utilities.MenuAnims;
import game.Highscore;

class GroupSelectState extends MusicBeatState
{
    public var groupList:Array<Int>;
    public var onGroupSelected:Int->Void;
    public static var groupID:Int = 0;
    public static var groupSongs:Array<FreeplaySong> = [];

    var vortexEffect:ChesslolEffect;
    var vortexSprite:FlxSprite;
    var grpTexts:FlxTypedGroup<FreeplayTxt>;
    var blockArray:Array<FlxSprite> = [];
    var shadersArray:Array<GreyscaleEffect> = [];
    var baseScaleX:Array<Float> = [];
    var baseScaleY:Array<Float> = [];
    var blockMult:Array<Float> = [];
    var activeTweens:Array<FlxTween> = [];

    public static var curSelected:Int = 0;
    var visibleStart:Int = 0;
    inline static var VISIBLE_COUNT:Int = 3;

    public var selectedGroup:Int;

    public static var groupImages:Map<Int, String> = new Map();
    public static var groupFonts:Map<Int, String> = new Map();
    public static var groupTextSizes:Map<Int, Int> = new Map();
    public static var groupNames:Array<String>;
    public static var groupDataMap:Map<Int, game.FreeplayGroup.FreeplayGroupData> = new Map();

    public var songs:Array<FreeplaySong>;

    var groupInfoBG:FlxSprite;
    var groupInfoAccent:FlxSprite;
    var groupInfoText:FlxText;
    var pageText:FlxText;

    var leftArrow:FlxText;
    var rightArrow:FlxText;
    var leftArrowBaseX:Float = 20;
    var rightArrowBaseX:Float = 0;

    var noGroupsText:FlxText;
    var hasGroups:Bool = true;

    var delta:Int = 0;
    var idleTimer:Float = 0;
    var transitioning:Bool = false;

    public function new(groups:Array<Int> = null, names:Array<String> = null, onSelect:Int->Void = null, selectedGroup:Int = 0)
    {
        super();
        if (groups == null) groups = [];
        if (names == null) names = [];
        groupList = groups;
        groupNames = names;
        onGroupSelected = onSelect;
        this.selectedGroup = selectedGroup;
        visibleStart = Math.floor(selectedGroup / VISIBLE_COUNT) * VISIBLE_COUNT;
        curSelected = selectedGroup;

        if (groupList != null && groupList.length > 0)
        {
            if (curSelected < 0 || curSelected >= groupList.length)
                curSelected = 0;
        }
        else
        {
            curSelected = 0;
        }
    }

    override function create()
    {
        super.create();

        if (groupList == null || groupList.length == 0)
        {
            loadFreeplayData();
        }

        visibleStart = Std.int(Math.min(visibleStart, Math.max(0, groupList.length - VISIBLE_COUNT)));
        curSelected = groupList.length > 0 ? selectedGroup % VISIBLE_COUNT : 0;
        hasGroups = groupList.length > 0;

        createBackground();
        createOverlay();

        grpTexts = new FlxTypedGroup<FreeplayTxt>();
        add(grpTexts);

        groupImages = new Map();
        loadGroupImages();

        if (!hasGroups)
        {
            createNoGroupsText();
            return;
        }

        groupID = groupList[visibleStart + curSelected];

        createGroupInfoBar();
        createVisibleGroups();
        updateVisibleGroups();
        updateGroupInfo(false);

        leftArrow = createArrow(20, "<");
        leftArrowBaseX = leftArrow.x;
        rightArrow = createArrow(FlxG.width - 56, ">");
        rightArrowBaseX = rightArrow.x;

        playEntrance();
    }

    function loadFreeplayData()
    {
        var curMod:String = utilities.Options.getData("curMod");
        var path:String = (curMod != null && curMod != "") ? 'mods/' + curMod + '/data/freeplay.json' : 'assets/data/freeplay.json';

        if (!FileSystem.exists(path)) path = 'assets/data/freeplay.json';
        if (!FileSystem.exists(path)) path = 'assets/preload/data/freeplay.json';

        if (FileSystem.exists(path))
        {
            try {
                var content:String = File.getContent(path);
                if (content.charCodeAt(0) == 0xFEFF) {
                    content = content.substr(1);
                }
                var rawData:Dynamic = Json.parse(content);
                songs = cast rawData.songs;
                groupNames = cast rawData.groups;
                groupList = [];

                if (groupNames != null) {
                    for (i in 0...groupNames.length)
                        groupList.push(i);
                }
            } catch (e:Dynamic) {
                songs = [];
                groupNames = [];
                groupList = [];
            }
        }
        else
        {
            songs = [];
            groupNames = [];
            groupList = [];
        }
    }

    function createBackground()
    {
        vortexSprite = new FlxSprite(0, 0);
        vortexSprite.makeGraphic(FlxG.width, FlxG.height, FlxColor.WHITE);
        vortexEffect = new ChesslolEffect();
        vortexSprite.shader = vortexEffect.shader;
        add(vortexSprite);
    }

    function createOverlay()
    {
        var black = new FlxSprite(0, 0);
        black.makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        black.alpha = 0.7;
        add(black);

        if (hasGroups)
        {
            var filter = FiltersBG.makeBackground(true, "Filter1");
            if (filter != null)
                add(filter);
        }
    }

    function createNoGroupsText()
    {
        noGroupsText = new FlxText(0, 0, FlxG.width, "NO EXISTE GROUPS", 64);
        noGroupsText.setFormat(Paths.font("Ethnocentric-Regular.otf"), 64, FlxColor.WHITE, "center");
        noGroupsText.borderStyle = OUTLINE;
        noGroupsText.borderColor = FlxColor.BLACK;
        noGroupsText.borderSize = 4;
        noGroupsText.screenCenter();
        add(noGroupsText);
    }

    function createGroupInfoBar()
    {
        groupInfoBG = new FlxSprite(0, FlxG.height - 80);
        groupInfoBG.makeGraphic(FlxG.width, 80, FlxColor.BLACK);
        groupInfoBG.alpha = 0.84;
        add(groupInfoBG);

        groupInfoAccent = new FlxSprite(0, FlxG.height - 80);
        groupInfoAccent.makeGraphic(FlxG.width, 3, FlxColor.CYAN);
        groupInfoAccent.alpha = 0.85;
        add(groupInfoAccent);

        groupInfoText = new FlxText(0, FlxG.height - 60, FlxG.width, "", 24);
        groupInfoText.setFormat(Paths.font("Ethnocentric-Regular.otf"), 26, FlxColor.CYAN, "center");
        add(groupInfoText);

        pageText = new FlxText(0, 18, FlxG.width, "", 20);
        pageText.setFormat(Paths.font("Ethnocentric-Regular.otf"), 20, FlxColor.WHITE, "center");
        pageText.borderStyle = OUTLINE;
        pageText.borderColor = FlxColor.BLACK;
        pageText.borderSize = 2.5;
        pageText.alpha = 0.85;
        add(pageText);
    }

    function createArrow(x:Float, symbol:String):FlxText
    {
        var arrow = new FlxText(x, FlxG.height / 2 - 20, 0, symbol, 64);
        arrow.setFormat(Paths.font("Ethnocentric-Regular.otf"), 64, FlxColor.WHITE, CENTER);
        arrow.borderStyle = OUTLINE;
        arrow.borderColor = FlxColor.BLACK;
        arrow.borderSize = 3;
        add(arrow);
        return arrow;
    }

    function calculateGroupProgress():{totalSongs:Int, clearedSongs:Int, totalDifficulties:Int, clearedDifficulties:Int}
    {
        var totalSongs = 0;
        var clearedSongs = 0;
        var totalDifficulties = 0;
        var clearedDifficulties = 0;

        for (song in songs)
        {
            var gID = song.group != null ? song.group : 0;
            if (gID != groupID)
                continue;

            totalSongs++;

            var hasScore = false;
            var diffs = (song.difficulties != null && song.difficulties.length > 0)
                ? song.difficulties
                : ["easy", "normal", "hard"];

            totalDifficulties += diffs.length;

            for (diff in diffs)
            {
                if (diff == null || diff.trim() == "")
                    continue;

                var score = Highscore.getScore(song.name, diff.toLowerCase());
                if (score > 0)
                {
                    clearedDifficulties++;
                    hasScore = true;
                }
            }

            if (hasScore)
                clearedSongs++;
        }

        return {totalSongs: totalSongs, clearedSongs: clearedSongs, totalDifficulties: totalDifficulties, clearedDifficulties: clearedDifficulties};
    }

    function updateGroupInfo(animate:Bool = true)
    {
        var progress = calculateGroupProgress();

        var percent:Int = 0;
        if (progress.totalDifficulties > 0)
            percent = Std.int((progress.clearedDifficulties / progress.totalDifficulties) * 100);

        groupInfoText.text = 'Songs: ${progress.clearedSongs}/${progress.totalSongs}  -  Difficulties: ${progress.clearedDifficulties}/${progress.totalDifficulties} - Progress : $percent%';
        groupInfoText.updateHitbox();

        var paddingY = 22;
        var targetHeight = groupInfoText.height + paddingY;

        groupInfoBG.scale.y = targetHeight / groupInfoBG.frameHeight;
        groupInfoBG.updateHitbox();
        groupInfoBG.y = FlxG.height - targetHeight;
        if (groupInfoAccent != null)
            groupInfoAccent.y = groupInfoBG.y;

        var targetTextY = groupInfoBG.y + (targetHeight - groupInfoText.height) / 2;
        if (animate)
        {
            groupInfoText.y = targetTextY + 10;
            groupInfoText.alpha = 0;
            trackTween(FlxTween.tween(groupInfoText, {y: targetTextY, alpha: 1}, 0.20, {ease: FlxEase.quartOut}));
        }
        else
        {
            groupInfoText.y = targetTextY;
            groupInfoText.alpha = 1;
        }

        if (pageText != null && groupList.length > 0)
        {
            var absIdx = visibleStart + curSelected + 1;
            pageText.text = 'GROUP $absIdx / ${groupList.length}';
        }
    }

    function loadGroupImages()
    {
        groupDataMap = new Map();
        var stylePath = Paths.json("groupStyles");
        var rawData:Dynamic = null;

        #if MODDING_ALLOWED
        var modStylePath = 'mods/${utilities.Options.getData("curMod")}/data/groupStyles.json';
        if (sys.FileSystem.exists(modStylePath))
            rawData = Json.parse(sys.io.File.getContent(modStylePath));
        #end

        if (rawData == null && Assets.exists(stylePath))
            rawData = Json.parse(Assets.getText(stylePath));

        if (rawData != null)
        {
            for (key in Reflect.fields(rawData))
            {
                var id = Std.parseInt(key);
                if (id == null) continue;

                var gData:game.FreeplayGroup.FreeplayGroupData = Reflect.field(rawData, key);
                gData.id = id;
                groupDataMap.set(id, gData);

                if (gData.image != null && gData.image.trim() != "")
                    groupImages.set(id, gData.image.trim());

                if (gData.font != null && gData.font.trim() != "")
                    groupFonts.set(id, gData.font.trim());

                if (gData.size != null)
                    groupTextSizes.set(id, gData.size);
            }
        }

        var filePath = #if MODDING_ALLOWED 'mods/${utilities.Options.getData("curMod")}/images/groupimages/groupimages.txt'; #else 'assets/images/groupimages/groupimages.txt'; #end
        if (!sys.FileSystem.exists(filePath))
            filePath = 'assets/images/groupimages/groupimages.txt';

        if (sys.FileSystem.exists(filePath))
        {
            for (line in sys.io.File.getContent(filePath).split("\n"))
            {
                var parts = line.split(":");
                if (parts.length < 1)
                    continue;

                var id = Std.parseInt(parts[0].trim());
                if (id == null)
                    continue;

                if (!groupImages.exists(id) && parts.length > 1 && parts[1].trim() != "")
                    groupImages.set(id, parts[1].trim());

                if (!groupFonts.exists(id) && parts.length > 2 && parts[2].trim() != "")
                    groupFonts.set(id, parts[2].trim());

                if (!groupTextSizes.exists(id) && parts.length > 3 && parts[3].trim() != "")
                {
                    var size = Std.parseInt(parts[3].trim());
                    if (size != null)
                        groupTextSizes.set(id, size);
                }
            }
        }
    }

    function getBlockLayout(i:Int, yBase:Float):{x:Float, y:Float, width:Int, height:Int}
    {
        var spacing = FlxG.width / 3.5;
        var centerX = FlxG.width / 2;
        var width = Std.int(FlxG.width / 3.5);
        var height = Std.int(FlxG.height * 0.75);
        var trueSpacing = spacing + (width * 0.15);
        var offsetFromCenter = (i - Math.floor(VISIBLE_COUNT / 2)) * trueSpacing;
        var x = centerX + offsetFromCenter - (width / 2);
        var y = yBase - (height / 2);
        return {x: x, y: y, width: width, height: height};
    }

    function createVisibleGroups()
    {
        for (i in 0...VISIBLE_COUNT)
        {
            var layout = getBlockLayout(i, FlxG.height / 2 - 150);
            var width = layout.width;
            var height = layout.height;
            var x = layout.x;
            var y = layout.y;

            var block = new FlxSprite(x, y);
            block.makeGraphic(width, height, FlxColor.CYAN);
            block.scrollFactor.set();
            block.antialiasing = true;

            var shader = new GreyscaleEffect();
            shader.radius = 0.2;
            shader.borderSize = 0.01;
            shader.smoothness = 0.002;
            shader.bordersEnabled = true;
            shader.strength = 1;
            block.shader = shader.shader;

            insert(members.indexOf(groupInfoBG), block);

            blockArray.push(block);
            shadersArray.push(shader);
            baseScaleX.push(1.0);
            baseScaleY.push(1.0);
            blockMult.push(1.0);

            var label = new FreeplayTxt(0, 0, "", true, false);
            label.alignment = "center";
            label.size = 56;
            insert(members.indexOf(block) + 2, label);
            grpTexts.add(label);
        }
    }

    function updateVisibleGroups(pageDir:Int = 0)
    {
        for (i in 0...VISIBLE_COUNT)
        {
            var block = blockArray[i];
            var shader = (i < shadersArray.length) ? shadersArray[i] : null;
            var label = cast(grpTexts.members[i], FreeplayTxt);
            var realIndex = visibleStart + i;

            if (realIndex >= groupList.length)
            {
                block.visible = false;
                if (label != null) label.visible = false;
                continue;
            }

            block.visible = true;
            if (label != null) label.visible = true;

            var localGroupID = groupList[realIndex];
            var layout = getBlockLayout(i, FlxG.height / 2 - 150);
            var width = layout.width;
            var height = layout.height;
            var x = layout.x;
            var y = layout.y;

            var img = null;
            if (groupImages.exists(localGroupID))
            {
                img = Paths.gpuBitmap("groupimages/" + groupImages.get(localGroupID));
            }

            if (img != null)
            {
                block.loadGraphic(img);
                block.setGraphicSize(width, height);
            }
            else
            {
                block.makeGraphic(width, height, FlxColor.CYAN);
            }

            block.updateHitbox();
            baseScaleX[i] = block.scale.x;
            baseScaleY[i] = block.scale.y;
            blockMult[i] = (i == curSelected) ? 1.12 : 0.96;

            block.x = x;
            block.y = y;

            if (pageDir != 0)
            {
                block.alpha = 0;
                var targetAlpha:Float = (i == curSelected) ? 1.0 : 0.65;
                trackTween(FlxTween.tween(block, {alpha: targetAlpha}, 0.22, {ease: FlxEase.cubeOut}));
            }

            if (shader != null)
            {
                shader.strength = (i == curSelected) ? 0 : 1;
            }

            if (label != null)
            {
                var fontName = groupFonts.exists(localGroupID) ? groupFonts.get(localGroupID) : "freeplayTxt.ttf";
                var labelText = (localGroupID >= 0 && localGroupID < groupNames.length) ? groupNames[localGroupID] : Std.string(localGroupID);

                label.font = Paths.font(fontName);
                label.text = labelText;
                label.updateHitbox();
                label.x = x + width / 2 - label.width / 2;
                label.y = y - 90;
                if (pageDir != 0)
                {
                    label.alpha = 0;
                    trackTween(FlxTween.tween(label, {alpha: (i == curSelected) ? 1.0 : 0.68}, 0.22, {ease: FlxEase.cubeOut}));
                }
            }
        }
    }

    function playEntrance()
    {
        for (i in 0...blockArray.length)
        {
            var block = blockArray[i];
            if (!block.visible) continue;

            var targetAlpha:Float = (i == curSelected) ? 1.0 : 0.65;
            block.alpha = 0;
            blockMult[i] = 0.85;
            trackTween(FlxTween.tween(block, {alpha: targetAlpha}, 0.32, {
                ease: FlxEase.quartOut,
                startDelay: i * 0.06
            }));

            if (i < grpTexts.length)
            {
                var label = cast(grpTexts.members[i], FreeplayTxt);
                if (label != null && label.visible)
                {
                    label.alpha = 0;
                    trackTween(FlxTween.tween(label, {alpha: (i == curSelected) ? 1.0 : 0.68}, 0.32, {
                        ease: FlxEase.quartOut,
                        startDelay: i * 0.06
                    }));
                }
            }
        }

        if (groupInfoBG != null)
        {
            var targetBgY = groupInfoBG.y;
            groupInfoBG.y = FlxG.height;
            trackTween(FlxTween.tween(groupInfoBG, {y: targetBgY}, 0.34, {ease: FlxEase.quartOut}));
        }

        if (groupInfoAccent != null)
        {
            var targetAccY = groupInfoAccent.y;
            groupInfoAccent.y = FlxG.height;
            trackTween(FlxTween.tween(groupInfoAccent, {y: targetAccY}, 0.34, {ease: FlxEase.quartOut}));
        }

        if (groupInfoText != null)
        {
            var targetTxtY = groupInfoText.y;
            groupInfoText.y = FlxG.height + 20;
            groupInfoText.alpha = 0;
            trackTween(FlxTween.tween(groupInfoText, {y: targetTxtY, alpha: 1}, 0.36, {ease: FlxEase.quartOut}));
        }

        if (pageText != null)
        {
            pageText.y = 4;
            pageText.alpha = 0;
            trackTween(FlxTween.tween(pageText, {y: 18, alpha: 0.85}, 0.32, {ease: FlxEase.quartOut}));
        }

        if (leftArrow != null)
        {
            leftArrow.x = leftArrowBaseX - 24;
            leftArrow.alpha = 0;
            trackTween(FlxTween.tween(leftArrow, {x: leftArrowBaseX, alpha: 0.85}, 0.32, {ease: FlxEase.quartOut}));
        }

        if (rightArrow != null)
        {
            rightArrow.x = rightArrowBaseX + 24;
            rightArrow.alpha = 0;
            trackTween(FlxTween.tween(rightArrow, {x: rightArrowBaseX, alpha: 0.85}, 0.32, {ease: FlxEase.quartOut}));
        }
    }

    function nudgeArrow(arrow:FlxText, baseX:Float, offset:Float)
    {
        MenuAnims.nudge(arrow, baseX, offset, 1.25, 0.20, activeTweens);
    }

    function changeSelection(change:Int)
    {
        var total = groupList.length;
        var oldVisibleStart = visibleStart;
        var absoluteIndex = visibleStart + curSelected + change;

        if (absoluteIndex < 0)
            absoluteIndex = total - 1;
        else if (absoluteIndex >= total)
            absoluteIndex = 0;

        visibleStart = Std.int(Math.floor(absoluteIndex / VISIBLE_COUNT) * VISIBLE_COUNT);
        curSelected = absoluteIndex % VISIBLE_COUNT;

        groupID = groupList[absoluteIndex];
        var pageChanged = (visibleStart != oldVisibleStart);
        updateVisibleGroups(pageChanged ? change : 0);
        updateGroupInfo(true);

        if (change < 0)
            nudgeArrow(leftArrow, leftArrowBaseX, -14);
        else
            nudgeArrow(rightArrow, rightArrowBaseX, 14);

        FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
    }

    function updateBlocks(elapsed:Float)
    {
        var spacing = FlxG.width / 3.5;
        var centerX = FlxG.width / 2;
        var baseWidth = Std.int(FlxG.width / 3.5);
        var scaleUp = 1.14;
        var yBase = FlxG.height / 2 + 20;
        var smooth = MenuAnims.smooth(elapsed, 12.0);

        for (i in 0...blockArray.length)
        {
            var block = blockArray[i];
            if (!block.visible) continue;

            var shader = (i < shadersArray.length) ? shadersArray[i] : null;
            var isSelected = (i == curSelected);
            var targetMult = isSelected ? scaleUp : 0.96;

            blockMult[i] = FlxMath.lerp(blockMult[i], targetMult, smooth);
            block.scale.set(baseScaleX[i] * blockMult[i], baseScaleY[i] * blockMult[i]);
            block.updateHitbox();

            var floatY:Float = isSelected ? Math.sin(idleTimer * 2.4) * 5.0 : 0.0;
            var trueSpacing = spacing + (baseWidth * (scaleUp - 1));
            var offsetFromCenter = (i - Math.floor(blockArray.length / 2)) * trueSpacing;
            block.x = centerX + offsetFromCenter - block.width / 2;
            block.y = yBase - block.height / 2 + floatY;

            block.alpha = FlxMath.lerp(block.alpha, isSelected ? 1.0 : 0.65, smooth);

            if (shader != null)
            {
                shader.strength = FlxMath.lerp(shader.strength, isSelected ? 0 : 1, smooth);
            }

            if (i < grpTexts.length)
            {
                var label = cast(grpTexts.members[i], FreeplayTxt);
                if (label != null)
                {
                    label.scale.set(blockMult[i], blockMult[i]);
                    label.x = block.x + block.width / 2 - label.width / 2;
                    label.y = block.y - 50;
                    label.alpha = FlxMath.lerp(label.alpha, isSelected ? 1.0 : 0.68, smooth);
                }
            }
        }
    }

    function confirmSelection()
    {
        if (transitioning)
            return;

        var selectedIndex = visibleStart + curSelected;
        if (selectedIndex >= groupList.length)
            return;

        transitioning = true;
        groupID = groupList[selectedIndex];
        groupSongs = [];
        updateGroupInfo(false);

        for (song in songs)
        {
            var gID = song.group != null ? song.group : 0;
            if (gID == groupID)
                groupSongs.push(song);
        }

        FlxG.sound.play(Paths.sound('confirmMenu'));

        for (i in 0...blockArray.length)
        {
            var block = blockArray[i];
            if (!block.visible) continue;

            if (i < grpTexts.length)
            {
                var label = cast(grpTexts.members[i], FreeplayTxt);
                if (label != null && label.visible)
                    trackTween(FlxTween.tween(label, {alpha: 0}, 0.22, {ease: FlxEase.cubeOut}));
            }

            if (i != curSelected)
                trackTween(FlxTween.tween(block, {alpha: 0}, 0.22, {ease: FlxEase.cubeOut}));
        }

        if (pageText != null)
            trackTween(FlxTween.tween(pageText, {alpha: 0, y: pageText.y - 16}, 0.22, {ease: FlxEase.cubeOut}));
        if (leftArrow != null)
            trackTween(FlxTween.tween(leftArrow, {alpha: 0, x: leftArrow.x - 20}, 0.22, {ease: FlxEase.cubeOut}));
        if (rightArrow != null)
            trackTween(FlxTween.tween(rightArrow, {alpha: 0, x: rightArrow.x + 20}, 0.22, {ease: FlxEase.cubeOut}));
        if (groupInfoBG != null)
            trackTween(FlxTween.tween(groupInfoBG, {alpha: 0}, 0.22, {ease: FlxEase.cubeOut}));
        if (groupInfoAccent != null)
            trackTween(FlxTween.tween(groupInfoAccent, {alpha: 0}, 0.22, {ease: FlxEase.cubeOut}));
        if (groupInfoText != null)
            trackTween(FlxTween.tween(groupInfoText, {alpha: 0}, 0.22, {ease: FlxEase.cubeOut}));

        var selectedBlock = (curSelected < blockArray.length) ? blockArray[curSelected] : null;
        var selectedShader = (curSelected < shadersArray.length) ? shadersArray[curSelected] : null;
        if (selectedShader != null)
        {
            selectedShader.strength = 0;
            selectedShader.enter = 1.0;
        }
        if (selectedBlock != null)
        {
            blockMult[curSelected] = 1.24;
            trackTween(FlxTween.tween(selectedBlock, {alpha: 0}, 0.28, {
                ease: FlxEase.cubeIn,
                onComplete: function(_) {
                    selectedBlock.visible = false;
                    FlxG.switchState(() -> new FreeplayState(groupID, groupSongs));
                }
            }));
        }
        else
        {
            FlxG.switchState(() -> new FreeplayState(groupID, groupSongs));
        }
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);
        idleTimer += elapsed;

        if (vortexEffect != null)
            vortexEffect.time += elapsed;

        for (sh in shadersArray)
        {
            if (sh != null)
                sh.update(elapsed);
        }

        if (!transitioning)
        {
            if (leftArrow != null)
                leftArrow.alpha = 0.78 + Math.sin(idleTimer * 3.0) * 0.16;
            if (rightArrow != null)
                rightArrow.alpha = 0.78 + Math.sin(idleTimer * 3.0 + Math.PI) * 0.16;
        }

        if (controls.BACK && !transitioning)
        {
            transitioning = true;
            cancelTweens();
            FlxG.sound.play(Paths.sound('cancelMenu'));
            FlxG.switchState(() -> new MainMenuState());
            return;
        }

        if (!hasGroups)
            return;

        if (!transitioning)
        {
            delta = 0;
            if (FlxG.keys.justPressed.RIGHT || controls.RIGHT_P)
                delta = 1;
            else if (FlxG.keys.justPressed.LEFT || controls.LEFT_P)
                delta = -1;

            if (delta != 0)
                changeSelection(delta);

            if (FlxG.keys.justPressed.ENTER || controls.ACCEPT)
                confirmSelection();

            updateBlocks(elapsed);
        }
    }

    function trackTween(t:FlxTween):FlxTween
    {
        if (t != null)
            activeTweens.push(t);
        return t;
    }

    function cancelTweens()
    {
        MenuAnims.cancelAll(activeTweens);
    }

    override function destroy()
    {
        cancelTweens();
        blockArray = [];
        shadersArray = [];
        baseScaleX = [];
        baseScaleY = [];
        blockMult = [];
        vortexEffect = null;
        super.destroy();
    }
}
