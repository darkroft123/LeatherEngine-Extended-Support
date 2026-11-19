package substates;

import flixel.util.FlxColor;
import flixel.FlxSprite;
import flixel.FlxG;
import flixel.text.FlxText;
import flixel.FlxCamera;
import game.Highscore;
import game.FreeplaySong;
import sys.FileSystem;
import sys.io.File;
import haxe.Json;

class StarInfoSubState extends MusicBeatSubstate {

    var uiCamera:FlxCamera = new FlxCamera();
    var fontPath:String = "Ethnocentric-Regular.otf";

    var songs:Array<FreeplaySong> = [];
    var groupNames:Array<String> = [];
    var curGroupIndex:Int = 0;

    var groupNameText:FlxText;
    var groupStarsText:FlxText;

    public function new(){
        super();

        uiCamera.bgColor.alpha = 0;
        FlxG.cameras.add(uiCamera, false);
        cameras = [uiCamera];

        var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        bg.alpha = 0.85;
        add(bg);

        var title = new FlxText(0, 15, FlxG.width, "OBTAINED STARS");
        title.setFormat(fontPath, 42, 0xFF00FFD2, "center", flixel.text.FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        add(title);

        var panelW = Std.int(FlxG.width - 200);
        var panel1H = 430;
        var panelX = 100;
        var panelY = 80;

        makeBox(panelX, panelY, panelW, panel1H);

        var starsData = [
            { count: Highscore.getGlobalPink(), color: 0xFFFF69B4, label: "ROSE STAR", graphic: "black star" },  
            { count: Highscore.getGlobalCyan(), color: FlxColor.CYAN, label: "BLUE STAR", graphic: "black star" },
            { count: Highscore.getGlobalOrange(), color: FlxColor.ORANGE, label: "GOLD STAR", graphic: "black star" },
            { count: Highscore.getGlobalGreenMarks(), color: FlxColor.LIME, label: "GREEN MARK", graphic: "black mark" }
        ];

        var spacing = panelW / 4;
        for (i in 0...4) {
            var xPos = panelX + (spacing * i) + (spacing / 2);

            var star = new FlxSprite(xPos - 50, panelY + 15);
            star.loadGraphic(Paths.gpuBitmap(starsData[i].graphic));
            star.color = starsData[i].color; 
            star.scale.set(0.25, 0.25);
            star.antialiasing = true;
            star.updateHitbox();
            add(star);

            var numberText = new FlxText(xPos - 100, star.y + 130, 200, Std.string(starsData[i].count));
            numberText.setFormat(fontPath, 32, FlxColor.WHITE, "center", flixel.text.FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
            add(numberText);
            
            var labelText = new FlxText(xPos - 150, numberText.y + 40, 300, starsData[i].label);
            labelText.setFormat(fontPath, 20, starsData[i].color, "center", flixel.text.FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
            add(labelText);
        }

        var reqTitle = new FlxText(panelX, panelY + 240, panelW, "REQUIREMENTS");
        reqTitle.setFormat(fontPath, 24, 0xFFFFB800, "center", flixel.text.FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        add(reqTitle);

        var reqs = [
            "ROSE STAR : 80% ACC",
            "BLUE STAR : 90% ACC",
            "GOLD STAR : 95% ACC",
            "GREEN MARK : CLEAR"
        ];
        
        var reqColors = [0xFFFF69B4, FlxColor.CYAN, FlxColor.ORANGE, FlxColor.LIME];

        for (i in 0...reqs.length) {
            var reqText = new FlxText(panelX, reqTitle.y + 35 + (i * 28), panelW, reqs[i]);
            reqText.setFormat(fontPath, 18, reqColors[i], "center", flixel.text.FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
            add(reqText);
        }

        // --- GROUP STATS PANEL ---
        var panel2Y = panelY + panel1H + 20;
        var panel2H = 120;
        makeBox(panelX, panel2Y, panelW, panel2H);

        var groupTitle = new FlxText(panelX, panel2Y + 10, panelW, "GROUP CATEGORY");
        groupTitle.setFormat(fontPath, 20, 0xFFC467FF, "center", flixel.text.FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        add(groupTitle);

        groupNameText = new FlxText(panelX, panel2Y + 45, panelW, "");
        groupNameText.setFormat(fontPath, 24, FlxColor.WHITE, "center", flixel.text.FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        add(groupNameText);

        groupStarsText = new FlxText(panelX, panel2Y + 80, panelW, "");
        groupStarsText.setFormat(fontPath, 22, 0xFFFFB800, "center", flixel.text.FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        add(groupStarsText);

        var arrowL = new FlxText(panelX + 20, panel2Y + 40, 50, "<");
        arrowL.setFormat(fontPath, 32, FlxColor.WHITE, "center", flixel.text.FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        add(arrowL);

        var arrowR = new FlxText(panelX + panelW - 70, panel2Y + 40, 50, ">");
        arrowR.setFormat(fontPath, 32, FlxColor.WHITE, "center", flixel.text.FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        add(arrowR);

        var info = new FlxText(0, FlxG.height - 40, FlxG.width, "LEFT / RIGHT : CHANGE GROUP  |  ESC / ENTER : CLOSE");
        info.setFormat(fontPath, 14, 0xFF888899, "center", flixel.text.FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        add(info);

        var warningText = new FlxText(0, FlxG.height - 20, FlxG.width, "WARNING: RESETTING A SCORE WILL ALSO DELETE ITS STARS!");
        warningText.setFormat(fontPath, 14, FlxColor.RED, "center", flixel.text.FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        add(warningText);

        loadFreeplayData();
        updateGroupStats();
    }

    function loadFreeplayData() {
        var path:String = #if MODDING_ALLOWED 'mods/${Options.getData("curMod")}/data/freeplay.json'; #else 'assets/data/freeplay.json'; #end
        if (FileSystem.exists(path)) {
            var rawData:Dynamic = Json.parse(File.getContent(path));
            songs = cast rawData.songs;
            groupNames = rawData.groups;
        }
    }

    function getGroupStars(groupIndex:Int):{obtained:Int, total:Int} {
        var obtained = 0;
        var total = 0;

        for (song in songs) {
            var gID = song.group != null ? song.group : 0;
            if (gID == groupIndex) {
                var diffs = (song.difficulties != null && song.difficulties.length > 0)
                    ? song.difficulties
                    : ["easy", "normal", "hard"];
                
                total += diffs.length * 3;

                for (diff in diffs) {
                    if (diff == null || StringTools.trim(diff) == "") continue;
                    obtained += Highscore.getSongStars(song.name, diff.toLowerCase());
                }
            }
        }
        return {obtained: obtained, total: total};
    }

    function updateGroupStats() {
        if (groupNames.length == 0) {
            groupNameText.text = "NO GROUPS";
            groupStarsText.text = "0 / 0 STARS";
            return;
        }

        groupNameText.text = groupNames[curGroupIndex];
        var stats = getGroupStars(curGroupIndex);
        
        groupStarsText.text = "STARS: " + stats.obtained + " / " + stats.total;
    }

    function makeBox(x:Float, y:Float, w:Int, h:Int):FlxSprite
    {
        var outerBorder = new FlxSprite(x - 3, y - 3).makeGraphic(w + 6, h + 6, 0xFF00FFD2);
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

    override function update(elapsed:Float) {
        super.update(elapsed);

        if (FlxG.keys.justPressed.LEFT) {
            curGroupIndex--;
            if (curGroupIndex < 0) curGroupIndex = groupNames.length - 1;
            updateGroupStats();
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
        }
        
        if (FlxG.keys.justPressed.RIGHT) {
            curGroupIndex++;
            if (curGroupIndex >= groupNames.length) curGroupIndex = 0;
            updateGroupStats();
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
        }

        if (FlxG.keys.justPressed.ESCAPE || FlxG.keys.justPressed.ENTER) {
            FlxG.state.closeSubState();
        }
    }

    override function destroy() {
        if (uiCamera != null) {
            if (FlxG.cameras != null && FlxG.cameras.list.contains(uiCamera)) {
                FlxG.cameras.remove(uiCamera, true);
            }
            uiCamera = null;
        }
        super.destroy();
    }
}
