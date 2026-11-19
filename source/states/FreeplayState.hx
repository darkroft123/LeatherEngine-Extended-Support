package states;

import toolbox.ChartingState;
import sys.io.File;
import sys.FileSystem;
import haxe.Json;
import substates.BlockedAndErrorSubState;

#if (target.threaded)
import sys.thread.Thread;
#end
#if DISCORD_ALLOWED
import utilities.DiscordClient;
#end
import game.Conductor;
import ui.BlockedSongComponent;
import flixel.util.FlxTimer;
import substates.ResetScoreSubstate;
import substates.StarInfoSubState;
import flixel.sound.FlxSound;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import game.SongLoader;
import game.Highscore;
import game.FreeplaySong;
import ui.HealthIcon;
import ui.InfoBanner;
import flixel.FlxG;
import utilities.MenuAnims;
#if MODCHARTING_TOOLS
import modcharting.ModchartUtil;
#end
import openfl.geom.Vector3D;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import lime.utils.Assets;
import ui.DesingText;
import states.GroupSelectState;
import shaders.Shaders.CutBitmapEffect;
import flixel.FlxCamera;
using utilities.BackgroundUtil;
typedef SongIconGroup = {
    var icons:Array<HealthIcon>;
    var parent:DesingText;
}
class FreeplayState extends MusicBeatState {
	public var camGame:FlxCamera;
	public var camHUD:FlxCamera;

	public static var songs:Array<FreeplaySong> = [];
	public var iconGroups:Array<SongIconGroup> = [];
	public static var groupCurSelected:Map<Int, Int> = new Map();
	public static var curSelected:Int = 0;
	public static var curDifficulty:Int = 1;
	public static var curSpeed:Float = 1;
	public static var lastAppliedSpeed:Float = 1;
	public var rankText:FlxText;
	public var curMisses:Int = 0;

	public var intensityBoxes:Array<FlxSprite> = [];
	public var scoreText:FlxText;
	
	public var menuStrs:Array<FlxSprite> = [];
	public var curMenuStr:Int = 0;
	public var menuStrsTimer:Float = 0;
	public var diffText:FlxText;
	public var speedText:FlxText;
	public var lerpScore:Int = 0;
	public var intendedScore:Int = 0;
	public var grpSongs:FlxTypedGroup<DesingText>;
	var _perspVec:Vector3D = new Vector3D();
	public var blockedComponents:Map<DesingText, BlockedSongComponent> = new Map();
	
	public static var songsReady:Bool = false;
	public var bg:FlxSprite;
	public var scoreBG:FlxSprite;
	public var curRank:String = "N/A";
	public var curDiffString:String = "normal";
	public var curDiffArray:Array<String> = ["easy", "normal", "hard"];
	public var canEnterSong:Bool = true;
	public static var alphaValues:Array<Float> = [1.0, 0.5, 0.25];

	// thx psych engine devs
	public var colorTween:FlxTween;
	#if (target.threaded)
	public var loading_songs:Thread;
	public var stop_loading_songs:Bool = false;
	#end
	public var lastSelectedSong:Int = -1;

	public var bgVisual:FlxSprite;
	public var bgOriginalX:Float;
    public var bgOriginalY:Float;
    
	public var renderVisual:FlxSprite;

	var lastBG:String = null;
	var lastRender:String = null;

	var bumpScale:Float = 1.0;
	var beatTimer:Float = 0;
	var currentSongBPM:Float = 100;
	var musicPlaying:Bool = false;

	public var cutShader = new CutBitmapEffect(); 
	

	/**
		Current instance of `FreeplayState`.
	**/
	public static var instance:FreeplayState = null;
	public static var lastGroup:Int = 0;
	var preloadedStyles:Array<Dynamic> = [];
	public static var groupStyles:Map<Int, Dynamic> = new Map();
	public static var curSong:FreeplaySong = null;

	public var selectedGroup:Int;
	var previewInst:FlxSound = null;
	var currentPlayingTrack:String = "";
	var playDelayTimer:FlxTimer = null;
	var previewTimer:Float = 0;
	var isFading:Bool = false;
	var fadeTimer:Float = 0;
	var fadeDirection:Int = 0; // -1 for out, 1 for in
	var baseVolume:Float = 1;
	
	var blackStars:Array<FlxSprite> = [];
	var spr2:FlxSprite;
	
	var startX:Float;
	var yPos:Float;
	var panelWidth:Float;
	var panelHeight:Float;
	var panelGap:Float;
	
	public function new(selectedGroup:Int = 0, groupSongs:Array<FreeplaySong> = null) {
		super();
		this.selectedGroup = selectedGroup;

		if (groupCurSelected.exists(selectedGroup))
			curSelected = groupCurSelected.get(selectedGroup);
		else
			curSelected = 0;
		FreeplayState.lastGroup = selectedGroup;
		grpSongs = new FlxTypedGroup<DesingText>();
		preloadedStyles = [];
		if (GroupSelectState.groupNames == null || GroupSelectState.groupNames.length == 0 || groupSongs == null) {
			var gState = new GroupSelectState();
			@:privateAccess gState.loadFreeplayData();
			if (groupSongs == null) {
				groupSongs = [];
				var targetGroupID:Int = (gState.groupList != null && gState.groupList.length > 0) ? gState.groupList[0] : selectedGroup;
				if (gState.songs != null) {
					for (s in gState.songs) {
						var gID = s.group != null ? s.group : 0;
						if (gID == targetGroupID)
							groupSongs.push(s);
					}
				}
				GroupSelectState.groupSongs = groupSongs;
			}
		}

		if (groupSongs != null) {
			loadGroupStyles();
			loadGroupSongs(groupSongs);
		}
	}

	override function create() {
	instance = this;

	camGame = new FlxCamera();
	camHUD = new FlxCamera();
	camHUD.bgColor = 0; 
	FlxG.cameras.reset(camGame);
	FlxG.cameras.add(camHUD);

	var grpName:String = (GroupSelectState.groupNames != null && selectedGroup >= 0 && selectedGroup < GroupSelectState.groupNames.length) ? GroupSelectState.groupNames[selectedGroup] : "Default";
	MusicBeatState.windowNameSuffix = " Freeplay | Group : " + grpName;

	panelWidth = 180;
	 panelHeight = 120;
	 panelGap = 15;
	var totalWidth = (panelWidth * 3) + (panelGap * 2);

	startX = FlxG.width - totalWidth - 110;
	yPos = 5;

	var black = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);

	#if MODDING_ALLOWED
	CoolUtil.convertFromFreeplaySongList();
	#end

	initSongs(black);

	if (curSelected >= songs.length) curSelected = songs.length - 1;

	#if DISCORD_ALLOWED
	DiscordClient.changePresence("Freeplay", "Group | " + grpName, null, false, 0, "oyesi");
	#end

	loadGroupStyles();
	initBackgroundAndShader();
	initPanels();
	initIntensity();
	initGrupoTextAndStars();

	initInfoBanner();

	var groupStyle = groupStyles.exists(selectedGroup) ? groupStyles.get(selectedGroup) : null;

	var fontName:String = "vcr.ttf";
	var titleSize:Int = 50;
	var offsetX:Float = 0;
	var offsetY:Float = 0;

	if (groupStyle != null) {
		if (Reflect.hasField(groupStyle, "font") && Reflect.field(groupStyle, "font") != null)
			fontName = Reflect.field(groupStyle, "font");
		else if (GroupSelectState.groupFonts.exists(selectedGroup))
			fontName = GroupSelectState.groupFonts.get(selectedGroup);

		if (Reflect.hasField(groupStyle, "size") && Reflect.field(groupStyle, "size") != null)
			titleSize = Reflect.field(groupStyle, "size");

		if (Reflect.hasField(groupStyle, "offsets") && Reflect.field(groupStyle, "offsets") != null) {
			var offs:Dynamic = Reflect.field(groupStyle, "offsets");
			if (Std.isOfType(offs, Array) && cast(offs, Array<Dynamic>).length >= 2) {
				offsetX = cast(offs, Array<Dynamic>)[0];
				offsetY = cast(offs, Array<Dynamic>)[1];
			}
		}
	} else if (GroupSelectState.groupFonts.exists(selectedGroup)) {
		fontName = GroupSelectState.groupFonts.get(selectedGroup);
	}

	var groupTitle:String = (GroupSelectState.groupNames != null && selectedGroup >= 0 && selectedGroup < GroupSelectState.groupNames.length)
        ? GroupSelectState.groupNames[selectedGroup]
        : Std.string(selectedGroup);

	var grupoText = new FlxText(150 + offsetX, 40 + offsetY, FlxG.width - 140, groupTitle);
	grupoText.setFormat(Paths.font(fontName), titleSize, FlxColor.WHITE, "left");

	grupoText.scrollFactor.set(0, 0);
	grupoText.cameras = [camHUD];
	var targetGrupoX:Float = grupoText.x;
	grupoText.x = targetGrupoX - 45;
	grupoText.alpha = 0;
	add(grupoText);
	FlxTween.tween(grupoText, {x: targetGrupoX, alpha: 1}, 0.45, {ease: FlxEase.quartOut});

	if (FlxG.sound.music != null) {
		FlxG.sound.music.stop();
		FlxG.sound.music.destroy();
		FlxG.sound.music = null;
	}

	if (previewInst != null) {
		previewInst.stop();
		previewInst.destroy();
		previewInst = null;
	}
	super.create();

	changeSelection(0);
	call("createPost");
}
private function initSongs(black:FlxSprite):Void {
	#if NO_PRELOAD_ALL
	if (!songsReady) {
		Assets.loadLibrary("songs").onComplete(function(_) { hideBlack(black); songsReady = true; });
	}
	#else
	songsReady = true;
	#end
}
private function initIntensity():Void {

	add(createText(startX + 50, yPos + 90, panelWidth, "INTENSITY : ", 16, FlxColor.WHITE, "Orbitron Bold.otf"));
    intensityBoxes = [];
	

	var boxStartX = startX + 200;
	var boxY = yPos + 90;
	var boxSpacing = 30;

    for (i in 0...10) {
        var box = new FlxSprite(boxStartX + (i * boxSpacing), boxY);
        box.makeGraphic(16, 16, FlxColor.GRAY);                          
        box.cameras = [camHUD];
        intensityBoxes.push(box);
        add(box);
    }
}
function createIcon(path:String, x:Float, y:Float):FlxSprite
	{
		var spr = new FlxSprite(x, y);
		spr.loadGraphic((Paths.gpuBitmap(path)));
		spr.scale.set(0.09, 0.09);
		spr.updateHitbox();
		spr.color = FlxColor.GRAY;
		return spr;
	}

private function initGrupoTextAndStars():Void {
    blackStars = [];
	var xpos:Float = FlxG.width * 0.97;
	var yposStart:Float = FlxG.height * 0.525;
	var spacing:Float = 65;
	for (i in 0...3)
	{
		var spr = createIcon("black star", xpos, yposStart + (i * spacing));
		spr.cameras = [camHUD];
		blackStars.push(spr);
		add(spr);
	}
	spr2 = createIcon("black mark", xpos, yposStart - 60);
	spr2.cameras = [camHUD];
	add(spr2);
}
private function initInfoBanner():Void {
    var banner = new InfoBanner(FlxColor.BLACK, 0.6, 20, Paths.font("vcr.ttf"), FlxColor.LIME);
    add(banner);
    var messages = [
        "Press E to open the Stars Menu",
        "Press RESET to restart the song",
        "Press SPACE to preview the level's song"
    ];

    banner.show(messages, 3.0, true); 
}
private function initBackgroundAndShader():Void {
	bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.TRANSPARENT);
	bg.shader = cutShader.shader;
	var currentHue:Float = 0.0;
	var currentContrast:Float = 1.0;
	var currentBrightness:Float = 1.0;
	if (groupStyles.exists(selectedGroup)) {
		var style = groupStyles.get(selectedGroup);
		if (Reflect.hasField(style, "hue"))
			currentHue = Reflect.field(style, "hue");
		if (Reflect.hasField(style, "contrast"))
			currentContrast = Reflect.field(style, "contrast");
		if (Reflect.hasField(style, "brightness"))
			currentBrightness = Reflect.field(style, "brightness");
	}
	cutShader.hue = currentHue;
	cutShader.brightness = currentBrightness;
	cutShader.contrast = currentContrast;
	cutShader.borderWidth = 10;
	cutShader.topX = 0.45;
	cutShader.bottomX = 0.55;
	cutShader.side = 1;
	cutShader.strength = 2;

	bgVisual = new FlxSprite();
	renderVisual = new FlxSprite();
	renderVisual.cameras = [camGame];

	add(bgVisual);
	add(bg);
	add(renderVisual);

	bg.cameras = [camGame];
	bgVisual.cameras = [camGame];
}

private function initPanels():Void {
	var panelData = [
		{title:"SCORE", size:22, value:"N/A", offsetX:30},
		{title:"SONG SPEED", size:22, value:"", offsetX:0},
		{title:"DIFFICULTY", size:18, value:"N/A", offsetX:-10},
		{title:"RANK", size:18, value:"N/A", offsetX:-40}
	];
	
	for (i in 0...panelData.length) {
		var p = panelData[i];
		
		var xOffset = startX + (panelWidth + panelGap) * i - 50 + p.offsetX;
		
		var titleTxt = createText(xOffset, yPos+10, panelWidth, p.title, 22, FlxColor.WHITE, "Orbitron Bold.otf");
		var titleTargetY = titleTxt.y;
		titleTxt.y = titleTargetY + 18;
		titleTxt.alpha = 0;
		add(titleTxt);
		FlxTween.tween(titleTxt, {y: titleTargetY, alpha: 1}, 0.36, {ease: FlxEase.quartOut, startDelay: i * 0.05});

		var txt = createText(xOffset, yPos+panelHeight-65, panelWidth, p.value, p.size, 0xFF00FFC8);
		var valTargetY = txt.y;
		txt.y = valTargetY + 18;
		txt.alpha = 0;
		add(txt);
		FlxTween.tween(txt, {y: valTargetY, alpha: 1}, 0.36, {ease: FlxEase.quartOut, startDelay: 0.06 + i * 0.05});
		
		switch(i) {
			case 0: 
				scoreText = txt;
				
				for (j in 1...3) {
					var spr = new FlxSprite(scoreText.x  + 37, scoreText.y + 70).loadGraphic(Paths.image('menustrs' + j));
					spr.setGraphicSize(Std.int(spr.width * 0.3));
					spr.updateHitbox();
					spr.cameras = [camHUD];
					spr.alpha = (j == 1) ? 1 : 0;
					add(spr);
					menuStrs.push(spr);
				}
			case 1: speedText = txt;
			case 2: diffText = txt;
			case 3: rankText = txt;
		}
	}
}
private function hideBlack(black:FlxSprite):Void {
	FlxTween.tween(black, {alpha:0}, 0.5, {
		ease: FlxEase.quadOut,
		onComplete: function(_) { remove(black); black.kill(); black.destroy(); }
	});
}

private function createText(x:Float, y:Float, w:Float, txt:String, size:Int, color:Int, ?font:String="Ethnocentric-Regular.otf"):FlxText {
	var t = new FlxText(x, y, w, txt, size);
	t.setFormat(Paths.font(font), size, color, CENTER);
	t.cameras = [camHUD];
	t.setBorderStyle(OUTLINE, FlxColor.BLACK, 2);
	return t;
}

    static function loadStyleFile(modPath:String, assetPath:String):Dynamic
    {
        if (FileSystem.exists(modPath))
            return Json.parse(File.getContent(modPath));
        if (Assets.exists(assetPath))
            return Json.parse(Assets.getText(assetPath));
        return null;
    }

    static function mergeStyles(styles:Array<Dynamic>):Dynamic
    {
        var merged:Dynamic = {};
        for (style in styles)
        {
            if (style != null)
                for (f in Reflect.fields(style))
                    Reflect.setField(merged, f, Reflect.field(style, f));
        }
        return merged;
    }

    function loadGroupStyles():Void {
		var stylePath = Paths.json("groupStyles");
		var rawData:Dynamic = null;

		#if MODDING_ALLOWED
		var modStylePath = 'mods/${Options.getData("curMod")}/data/groupStyles.json';
		if (FileSystem.exists(modStylePath)) {
			rawData = Json.parse(File.getContent(modStylePath));
		}
		#end

		if (rawData == null && Assets.exists(stylePath)) {
			rawData = Json.parse(Assets.getText(stylePath));
		}

		if (rawData != null) {
			for (key in Reflect.fields(rawData)) {
				var styleData = Reflect.field(rawData, key);
				groupStyles.set(Std.parseInt(key), styleData);
			}
		}
	}

    function loadStyleForSong(song:FreeplaySong, diff:String):Dynamic
    {
        var baseMod = 'mods/${Options.getData("curMod")}/data/song data/' + song.name;
        var diffLower = diff.toLowerCase();

        var globalStyle = loadStyleFile(
            baseMod + '/style.json',
            Paths.json('song data/${song.name}/style')
        );
        var diffStyle = loadStyleFile(
            baseMod + '/style-' + diffLower + '.json',
            Paths.json('song data/${song.name}/style-${diffLower}')
        );
        var groupSongStyle = loadStyleFile(
            baseMod + '/style-group-' + song.group + '.json',
            Paths.json('song data/${song.name}/style-group-${song.group}')
        );
        var groupStyle = groupStyles.exists(selectedGroup) ? groupStyles.get(selectedGroup) : null;

        return mergeStyles([groupStyle, globalStyle, groupSongStyle, diffStyle]);
    }
    function parseIconData(song:FreeplaySong, diff:String):Array<Dynamic>
    {
        var iconData:Array<Dynamic> = [];
        var diffUse = diff.toLowerCase();

        if (Std.isOfType(song.icon, String))
            iconData.push({name: song.icon, offsetX: 0, offsetY: 0});
        else if (Std.isOfType(song.icon, Array))
        {
            for (i in cast(song.icon, Array<Dynamic>))
            {
                if (Std.isOfType(i, String))
                    iconData.push({name: i, offsetX: 0, offsetY: 0});
                else
                    iconData.push(i);
            }
        }
        else
        {
            var diffIcons:Dynamic = Reflect.field(song.icon, diffUse);
            if (diffIcons == null)
                diffIcons = Reflect.field(song.icon, "normal");

            if (diffIcons != null)
            {
                for (i in cast(diffIcons, Array<Dynamic>))
                {
                    if (Std.isOfType(i, String))
                        iconData.push({name: i, offsetX: 0, offsetY: 0});
                    else
                        iconData.push(i);
                }
            }
        }

        return iconData;
    }

    function loadGroupSongs(groupSongs:Array<FreeplaySong>):Void {
	songs = groupSongs;

	if (curSelected < 0) curSelected = 0;
	else if (curSelected >= songs.length) curSelected = songs.length - 1;

	groupCurSelected.set(selectedGroup, curSelected);

	if (grpSongs == null) {
		grpSongs = new FlxTypedGroup<DesingText>();
	} else {
		for (item in grpSongs.members) {
			if (item != null) item.destroy();
		}
		grpSongs.clear();
	}
	for (group in iconGroups)
	{
		for (icon in group.icons)
		{
			remove(icon, true);
			icon.kill();
			icon.destroy();
		}
	}
	iconGroups = [];
	add(grpSongs);

	if (blockedComponents != null)
	{
		for (comp in blockedComponents)
		{
			remove(comp);
			comp.destroy();
		}
		blockedComponents.clear();
	}
	else
	{
		blockedComponents = new Map();
	}

	for (i in 0...groupSongs.length)
	{
		var song = groupSongs[i];
		var diff:String = curDiffArray[curDifficulty];
		var data = loadStyleForSong(song, diff);
		var spacing = (data != null && data.letterSpacing != null) ? data.letterSpacing : 0;

		var defaultSize = 80;
		var textSize:Int = defaultSize;

		if (data != null && data.songFontSize != null)
			textSize = Std.int(Std.parseFloat(Std.string(data.songFontSize)));

		var songText = DesingText.createSongText(0, 60 * i, song.name, textSize, spacing, data, 1);

		songText.isMenuItem = true;
		songText.targetY = i;

		if (data == null || data.songFont == null)
			songText.font = Paths.font("freeplayTxt.ttf");

		var padding = 100;
		var textWidth = songText.textField.textWidth * songText.scale.x;

		songText.targetX = FlxG.width - textWidth - padding;
		songText.scrollFactor.set(0, 0);
		songText.origin.x = songText.width;
		songText.origin.y = songText.height / 2;

		grpSongs.add(songText);

            if (Options.getData("healthIcons"))
            {
                var group:SongIconGroup = {icons: [], parent: songText};
                var iconData:Array<Dynamic> = parseIconData(song, curDiffArray[curDifficulty]);

			for (iconInfo in iconData)
			{
				var icon = new HealthIcon(iconInfo.name);
				icon.sprTracker = songText;
				icon.disableTracking = true;
				icon.origin.x = icon.width;
				icon.origin.y = icon.height / 2;
				icon.offset.x = iconInfo.offsetX;
				icon.offset.y = iconInfo.offsetY;
				group.icons.push(icon);
				add(icon);
			}

			iconGroups.push(group);
		}

		var blockedComponent = new BlockedSongComponent(song);
		if (blockedComponent.isSongBlocked)
		{
			add(blockedComponent);
			blockedComponents.set(songText, blockedComponent);
		}
	}
}
var bgTargetAlpha:Float = 0;
var renderTargetAlpha:Float = 0;
var renderTargetX:Float = -300;

    function getVisualAsset(assets:Array<String>, diffIndex:Int):String
    {
        if (assets != null && assets.length > 0) {
            var asset = diffIndex < assets.length && assets[diffIndex] != null ? assets[diffIndex] : assets[0];
            if (asset != null && StringTools.trim(asset) != "")
                return asset;
        }
        return null;
    }

    function updateVisualSprite(sprite:FlxSprite, assets:Array<String>, diffIndex:Int, folder:String,
            defaultX:Float, defaultY:Float, last:Null<String>):String
    {
        var newAsset = getVisualAsset(assets, diffIndex);
        if (newAsset == last)
            return last;

        if (newAsset != null)
        {
            sprite.loadGraphic(Paths.gpuBitmap(folder + newAsset));
            sprite.x = defaultX;
            sprite.y = defaultY;
        }
        else
        {
            sprite.makeGraphic(1, 1, flixel.util.FlxColor.TRANSPARENT);
            sprite.alpha = 0;
        }
        return newAsset;
    }

    function updateVisuals():Void {
        if (songs == null || songs.length == 0 || curSong == null) return;
        var diffIndex = curDifficulty;

        lastBG = updateVisualSprite(bgVisual, curSong.bgs, diffIndex, "freeplay/ports/", -250, 50, lastBG);
        if (lastBG != null) {
            bgOriginalX = bgVisual.x;
            bgOriginalY = bgVisual.y;
            bgTargetAlpha = 1;
        } else {
            bgTargetAlpha = 0;
            bgVisual.alpha = 0;
        }

        lastRender = updateVisualSprite(renderVisual, curSong.renders, diffIndex, "freeplay/Renders/", -700, 0, lastRender);
        if (lastRender != null) {
            renderTargetAlpha = 1;
            renderTargetX = 0;
        } else {
            renderTargetAlpha = 0;
            renderTargetX = -700;
            renderVisual.alpha = 0;
        }
    }

	public var mix:String = null;

	public var time:Float = 0;

    var lastDiffTextStr:String = "";
    var lastShownScore:Int = -999999;
    var lastShownSpeed:Float = -1;

    inline function punchHudText(t:FlxText):Void
    {
        MenuAnims.punchScale(t, 1.15, 1.15, 1.0, 1.0, 0.2);
    }

    function updateDiffText():Void
    {
        var showArrows = (curDiffArray.length > 1);
        var nextDiffText:String = showArrows ? "< " + curDiffString + " >" : curDiffString;
        if (nextDiffText != lastDiffTextStr) {
            lastDiffTextStr = nextDiffText;
            diffText.text = nextDiffText;
            punchHudText(diffText);
        }
    }

    function updateMusicFade(elapsed:Float):Void
    {
        if (FlxG.sound.music != null && FlxG.sound.music.playing && !isFading) {
            previewTimer += elapsed;
            if (previewTimer >= 15.0) {
                isFading = true;
                fadeTimer = 0;
                fadeDirection = -1;
            }
        }

        if (isFading && FlxG.sound.music != null) {
            fadeTimer += elapsed;
            if (fadeDirection == -1) {
                var volume:Float = Math.max(0, 1.0 - (fadeTimer / 1.0));
                FlxG.sound.music.volume = volume;
                if (fadeTimer >= 1.0) {
                    FlxG.sound.music.time = FlxG.sound.music.length / 2;
                    FlxG.sound.music.volume = 0;
                    fadeDirection = 1;
                    fadeTimer = 0;
                    previewTimer = 0;
                }
            } else if (fadeDirection == 1) {
                var volume:Float = Math.min(1.0, fadeTimer / 1.0);
                FlxG.sound.music.volume = volume;
                if (fadeTimer >= 1.0) {
                    isFading = false;
                    FlxG.sound.music.volume = 1.0;
                }
            }
        }
    }

    function updateIconLayout(elapsed:Float):Void
    {
        var smooth:Float = MenuAnims.smooth(elapsed, 12.0);
        for (groupIndex in 0...iconGroups.length)
        {
            var group = iconGroups[groupIndex];
            var txt = group.parent;

            var diff = groupIndex - curSelected;
            var distance = diff < 0 ? -diff : diff;

            if (distance > 4)
            {
                for (icon in group.icons)
                    icon.visible = false;
                continue;
            }

            var targetZ:Float = -distance * 400.0;
            txt.z = FlxMath.lerp(txt.z, targetZ, smooth);
            var targetAngle:Float = (diff == 0) ? 0.0 : diff * 3.5;
            txt.angle = FlxMath.lerp(txt.angle, targetAngle, smooth);

            var baseScale:Float = 1.0;
            #if MODCHARTING_TOOLS
            _perspVec.setTo(FlxG.width * 0.5, txt.y + txt.height * 0.5, txt.z * 0.001);
            var persp = ModchartUtil.calculatePerspective(
                _perspVec,
                ModchartUtil.defaultFOV * (Math.PI / 180),
                0,
                0
            );
            baseScale = (persp.z < 0) ? (1.0 / -persp.z) : 1.0;
            baseScale = FlxMath.bound(baseScale, 0.35, 1.3);
            #else
            var val = 1.0 - 0.2 * distance;
            baseScale = val < 0.5 ? 0.5 : (val > 1.0 ? 1.0 : val);
            #end
            var alphaValues = FreeplayState.alphaValues;

            var textWidth = txt.width * txt.scale.x;
            var scaleFix = (1 - txt.scale.x) * 100;
            var baseX = FlxG.width - textWidth - 100 - scaleFix - 50;
            var spacing = 90;

            var isBlocked = blockedComponents.exists(txt);

            for (icon in group.icons)
            {
                if (isBlocked)
                {
                    icon.visible = false;
                    icon.alpha = 0;
                }
                else
                {
                    icon.visible = true;
                    icon.scale.set(baseScale * icon.startSize, baseScale * icon.startSize);

                    icon.alpha = (distance < alphaValues.length)
                        ? alphaValues[distance]
                        : 0.0;

                    icon.x = baseX
                        - 150 * icon.scale.x
                        - 10
                        - (icon.slot * spacing);

                    var floatY:Float = (distance == 0) ? Math.sin(time * 2.5) * 3.0 : 0.0;
                    icon.y = txt.y + (txt.height * txt.scale.y - 150 * icon.scale.y) / 2 + floatY;
                    icon.angle = FlxMath.lerp(icon.angle, targetAngle, smooth);
                }
            }

            if (isBlocked)
            {
                var comp = blockedComponents.get(txt);
                comp.updateLayout(baseX, txt.y, textWidth, txt.height * txt.scale.y, baseScale, (distance < alphaValues.length) ? alphaValues[distance] : 0.0, group.icons);
            }
        }
    }

    function handleInput():Void
    {
        if (!songsReady)
            return;

        var leftP = controls.LEFT_P;
        var rightP = controls.RIGHT_P;
        var upP = controls.UP_P;
        var downP = controls.DOWN_P;
        var shift = FlxG.keys.pressed.SHIFT;

        if (FlxG.keys.justPressed.SPACE && songs.length > 0) {

            if (FlxG.sound.music != null)
                FlxG.sound.music.stop();

            if (previewInst == null) {
                previewInst = new FlxSound();
                FlxG.sound.list.add(previewInst);
            }

            previewInst.stop();
            previewInst.loadEmbedded(Paths.inst(songs[curSelected].name.toLowerCase(), curDiffString));
            previewInst.pitch = curSpeed;
            previewInst.volume = baseVolume;
            previewInst.play(true);

            Conductor.songPosition = 0;

            // Load chart BPM for beat sync
            loadSongBPM();
            musicPlaying = true;
            beatTimer = 0;
        }

        if (songs.length > 1) {
            var wheel = -1 * Math.floor(FlxG.mouse.wheel);

            if (wheel != 0 && !shift)
                changeSelection(wheel);
		else if (wheel != 0 && shift) {
			curSpeed += (wheel > 0 ? 0.05 : -0.05);
			if (previewInst != null && previewInst.playing) previewInst.pitch = curSpeed;
		}

            if (upP) changeSelection(-1);
            if (downP) changeSelection(1);
        }

		if (leftP) shift ? curSpeed -= 0.05 : changeDiff(-1);
		if (rightP) shift ? curSpeed += 0.05 : changeDiff(1);
		if (FlxG.keys.justPressed.R && shift) curSpeed = 1;

		if (!shift && (leftP || rightP)) {
			// Already handled above (changeDiff)
		} else if (!shift && FlxG.keys.justPressed.R) {
			changeDiff(0);
		}

		if (previewInst != null && previewInst.playing && (leftP || rightP || FlxG.keys.justPressed.R) && shift)
			previewInst.pitch = curSpeed;

        if (controls.BACK) {
            colorTween?.cancel();

            if (previewInst != null) {
                previewInst.stop();
                previewInst.destroy();
                previewInst = null;
            }

            #if (target.threaded)
            stop_loading_songs = true;
            #end

            FlxG.switchState(() -> new GroupSelectState(
                MainMenuState.keysArray,
                MainMenuState.namesArray,
                function(selectedGroup:Int) {
                    FlxG.switchState(() -> new FreeplayState(selectedGroup));
                },
                FreeplayState.lastGroup
            ));
        }

        if (FlxG.keys.justPressed.E)
            openSubState(new StarInfoSubState());

        if (controls.RESET && !shift) {
            var diffKey = (curSpeed != 1.0) ? curDiffString + "-r" + curSpeed : curDiffString;
            var resetSub = new ResetScoreSubstate(curSong.name, diffKey);
            resetSub.closeCallback = function() {
                changeSelection();
            };
            openSubState(resetSub);
        }

        if (FlxG.keys.justPressed.ENTER && canEnterSong) {
            if (songs != null && curSelected >= 0 && curSelected < songs.length) {
                var selectedSong:FreeplaySong = songs[curSelected];
                if (selectedSong != null)
                    playSong(selectedSong.name, curDiffString);
            }
        }
    }

    override function update(elapsed:Float) {
        call("update", [elapsed]);

	if (menuStrs.length > 0) {
		menuStrsTimer += elapsed;
		if (menuStrsTimer >= 5.0) {
			menuStrsTimer = 0;
			var oldSpr = menuStrs[curMenuStr];
			curMenuStr = (curMenuStr + 1) % menuStrs.length;
			var newSpr = menuStrs[curMenuStr];
			
			FlxTween.tween(oldSpr, {alpha: 0}, 0.5, {ease: FlxEase.quadInOut});
			FlxTween.tween(newSpr, {alpha: 1}, 0.5, {ease: FlxEase.quadInOut});
		}
	}

    updateMusicFade(elapsed);

    bgVisual.alpha = FlxMath.lerp(bgVisual.alpha, bgTargetAlpha, elapsed * 8);
	renderVisual.alpha = FlxMath.lerp(renderVisual.alpha, renderTargetAlpha, elapsed * 8);
	renderVisual.x = FlxMath.lerp(renderVisual.x, renderTargetX, elapsed * 8);

	#if MODDING_ALLOWED
	if (FlxG.keys.justPressed.TAB) {
		openSubState(new modding.SwitchModSubstate());
		persistentUpdate = false;
	}
	#end

	super.update(elapsed);
	cutShader.time += elapsed;

	// Beat-synced bump for bgVisual and renderVisual
	var isMusicActive = (FlxG.sound.music != null && FlxG.sound.music.playing)
		|| (previewInst != null && previewInst.playing);

	if (musicPlaying) {
		var beatInterval:Float = (60.0 / currentSongBPM) * 4;
		beatTimer += elapsed;

		if (beatTimer >= beatInterval) {
			beatTimer -= beatInterval;
			bumpScale = 1.12;
		}

		bumpScale = FlxMath.lerp(bumpScale, 1.0, elapsed * 10);
	} else {
		bumpScale = FlxMath.lerp(bumpScale, 1.0, elapsed * 8);
	}

	if (Math.abs(bumpScale - 1.0) < 0.005) bumpScale = 1.0;

	if (bgVisual != null) bgVisual.scale.set(bumpScale, bumpScale);
	if (renderVisual != null) renderVisual.scale.set(bumpScale, bumpScale);

	bgVisual.x = bgOriginalX;
	bgVisual.y = bgOriginalY;


    updateIconLayout(elapsed);

	if (bumpScale != 1.0 && curSelected >= 0 && curSelected < iconGroups.length) {
		for (icon in iconGroups[curSelected].icons)
			icon.scale.set(icon.scale.x * bumpScale, icon.scale.y * bumpScale);
	}

    var songCount = grpSongs.members.length;
    for (i in 0...songCount)
    {
        var songText = cast(grpSongs.members[i], DesingText);
        if (songText == null) continue;
        var dist = Std.int(Math.abs(i - curSelected));
        if (dist <= 4) {
            songText.visible = true;
            songText.updateShaderFade(curSelected, i);
        } else {
            songText.visible = false;
        }
    }


			
	lerpScore = Math.floor(FlxMath.lerp(lerpScore, intendedScore, 0.3));
	if (Math.abs(lerpScore - intendedScore) <= 10)
		lerpScore = intendedScore;

	if (lerpScore != lastShownScore) {
		lastShownScore = lerpScore;
		scoreText.text = (lerpScore == 0 ? "N/A" : Std.string(lerpScore));
	}

    curSpeed = Math.max(0.25, FlxMath.roundDecimal(curSpeed, 2));
    if (curSpeed != lastShownSpeed) {
        lastShownSpeed = curSpeed;
        speedText.text = "< " + Std.string(curSpeed) + " >";
        punchHudText(speedText);
    }

    if (curSpeed != lastAppliedSpeed)
    {
        if (previewInst != null && previewInst.playing)
            previewInst.pitch = curSpeed;

        if (FlxG.sound.music != null && FlxG.sound.music.playing)
            FlxG.sound.music.pitch = curSpeed;

        lastAppliedSpeed = curSpeed;
    }

    updateDiffText();

    handleInput();

	call("updatePost", [elapsed]);
}
	// TODO: Make less nested

	/**
		 * Plays a specific song
		 * @param songName
		 * @param diff
		 */
function setupSongState(curSong:FreeplaySong, diff:String):Void {
	PlayState.isStoryMode = false;
	PlayState.songMultiplier = curSpeed;
	PlayState.storyDifficultyStr = diff.toUpperCase();
	PlayState.storyWeek = curSong.week;

	var selectedRender:String = null;

	if (curSong.renders != null && curSong.renders.length > 0)
		selectedRender = (curDifficulty < curSong.renders.length && curSong.renders[curDifficulty] != null)
			? curSong.renders[curDifficulty]
			: curSong.renders[0];

	PlayState.songRender = selectedRender;
	PlayState.songMetadata = curSong.metadata;
	PlayState.currentFreeplaySong = curSong;

	#if (target.threaded)
	stop_loading_songs = true;
	#end

	colorTween?.cancel();
	PlayState.loadChartEvents = true;
}

    function createEmptyChart(songName:String, diff:String):Void
    {
        #if MODDING_ALLOWED
        var modPath:String = 'mods/${Options.getData('curMod')}';
        if (!FileSystem.exists('$modPath/data'))
            FileSystem.createDirectory('$modPath/data');
        if (!FileSystem.exists('$modPath/data/song data'))
            FileSystem.createDirectory('$modPath/data/song data');
        if (!FileSystem.exists('$modPath/data/song data/${songName.toLowerCase()}'))
            FileSystem.createDirectory('$modPath/data/song data/${songName.toLowerCase()}');

        File.saveContent('$modPath/data/song data/${songName.toLowerCase()}/${songName.toLowerCase()}-${diff.toLowerCase()}.json', Json.stringify({
            song: {
                validScore: true,
                keyCount: 4,
                playerKeyCount: 4,
                chartOffset: 0.0,
                timescale: [4, 4],
                needsVoices: true,
                song: songName,
                bpm: 100,
                player1: 'bf',
                player2: 'dad',
                gf: 'gf',
                stage: 'stage',
                speed: 1,
                ui_Skin: 'default',
                notes: [{
                    sectionNotes: [],
                    lengthInSteps: 16,
                    mustHitSection: true,
                    bpm: 0.0,
                    changeBPM: false,
                    altAnim: false,
                    timeScale: [0, 0],
                    changeTimeScale: false
                }],
                specialAudioName: null,
                player3: null,
                modchartingTools: false,
                modchartPath: null,
                cameraEvents: false,
                mania: null,
                gfVersion: null,
                events: [],
                endCutscene: '',
                cutscene: '',
                moveCamera: true,
                chartType: LEGACY
            }
        }, '\t'));
        #end
    }

    public function playSong(songName:String, diff:String) {
	if (!canEnterSong) return;

	if (!CoolUtil.songExists(songName, diff, mix)) {
		if (!Options.getData("autoOpenCharter")) {
			openSubState(new BlockedAndErrorSubState(
				songName.toLowerCase() + " doesn't seem to exist!\nTry fixing its name in freeplay.json",
				"Leather Engine's No Crash, We Help Fix Stuff Tool"
			));
		} else {
            if (Options.getData("developer")) {
                #if MODDING_ALLOWED
                createEmptyChart(songName, diff);

                PlayState.SONG = SongLoader.loadFromJson(diff, songName.toLowerCase(), mix);
                PlayState.practiceMode = false;

                setupSongState(curSong, diff);

                FlxG.switchState(() -> new ChartingState());
                #end
            }
		}
		return;
	}

	PlayState.SONG = SongLoader.loadFromJson(diff, songName.toLowerCase(), mix);
	if (PlayState.SONG == null) {
		openSubState(new substates.BlockedAndErrorSubState(
			"Could not load the chart JSON for '" + songName + "'. Check the 'song data' folder inside the mod.",
			"Leather Engine's No Crash, We Help Fix Stuff Tool"
		));
		return;
	}
	PlayState.deathCounter = 0;
	substates.PauseSubState.lastPromptedDeathCount = -1;

	if (!Assets.exists(Paths.inst(PlayState.SONG.song, diff.toLowerCase(), mix))) {
		if (Assets.exists(Paths.inst(songName.toLowerCase(), diff.toLowerCase(), mix))) {
			openSubState(new BlockedAndErrorSubState(
				PlayState.SONG.song.toLowerCase() + " (JSON) does not match " + songName + " (FREEPLAY)\nTry making them the same.",
				"Leather Engine's No Crash, We Help Fix Stuff Tool"
			));
		} else {
			openSubState(new BlockedAndErrorSubState(
				"Your song seems to not have an Inst.ogg, check the folder name in 'songs'!",
				"Leather Engine's No Crash, We Help Fix Stuff Tool"
			));
		}
		return;
	}

	setupSongState(curSong, diff);

	LoadingState.loadAndSwitchState(() -> new PlayState());
}

	override function closeSubState() {
		changeSelection();
		FlxG.mouse.visible = false;
		super.closeSubState();
	}
	function updateRankDisplay():Void {
	if (rankText != null) {
		var fcDisplay = (curMisses == 0 && curRank != "N/A") ? " - FC" : "";
		rankText.text = curRank.toUpperCase() + fcDisplay;
		rankText.color = (curMisses == 0 && curRank != "N/A") ? 0xFFFFD700 : 0xFF00FFC8;
	}

	if (songs == null || songs.length == 0) return;
	if (curSong == null) return;

	var diffKey = (curSpeed != 1.0) ? curDiffString + "-r" + curSpeed : curDiffString;
	var formatted = Highscore.formatSong(curSong.name, curDiffString, (curSpeed != 1.0) ? "r" + curSpeed : null);
	var savedStars:Int = Highscore.getSongStars(formatted, diffKey, true);

	for (i in 0...blackStars.length)
		if (blackStars[i] != null)
			blackStars[i].color = FlxColor.GRAY;

	for (i in 0...savedStars)
		if (i < blackStars.length && blackStars[i] != null)
			blackStars[i].color = [0xFFFF69B4, FlxColor.CYAN, FlxColor.ORANGE][i];

	if (spr2 != null)
	{
		spr2.color = (intendedScore > 0) ? FlxColor.LIME : FlxColor.GRAY;
	}
}
function updateIntensityDisplay():Void
{
	if (songs == null || songs.length == 0 || curSong == null) return;
	if (curSelected < 0 || curSelected >= songs.length) return;

	var value:Float = (curSong.intensity != null && curDifficulty >= 0 && curDifficulty < curSong.intensity.length)
		? curSong.intensity[curDifficulty]
		: 0;

	value = Math.max(0, Math.min(10, value));

	for (i in 0...intensityBoxes.length)
	{
		var box = intensityBoxes[i];

		if (i < value)
		{
			var t:Float = i / 9;
			box.color = (t <= 0.5)
				? FlxColor.interpolate(FlxColor.GREEN, FlxColor.YELLOW, t * 2)
				: FlxColor.interpolate(FlxColor.YELLOW, FlxColor.RED, (t - 0.5) * 2);
		}
		else
		{
			box.color = FlxColor.GRAY;
		}
	}
}
	function changeDiff(change:Int = 0) {
		call("changeDiff", [change]);

		curDifficulty = FlxMath.wrap(curDifficulty + change, 0, curDiffArray.length - 1);
		curDiffString = curDiffArray[curDifficulty].toUpperCase();

		if (songs.length != 0 && curSong != null) {
			var diffKey = (curSpeed != 1.0) ? curDiffString + "-r" + curSpeed : curDiffString;

			intendedScore = Highscore.getScore(curSong.name, diffKey);
			curRank = Highscore.getSongRank(curSong.name, diffKey);
			curMisses = Highscore.getMisses(curSong.name, diffKey);
		}

        updateDiffText();

        updateRankDisplay();
		updateIntensityDisplay();
		updateVisuals();
		checkPlayMusic();

		call("changeDiffPost", [change]);
	}


	function changeSelection(change:Int = 0) {
		call("changeSelection", [change]);

		if (grpSongs.length <= 0)
			return;

		curSelected = FlxMath.wrap(curSelected + change, 0, grpSongs.length - 1);
		if (change != 0) {
			punchHudText(scoreText);
			punchHudText(rankText);
		}
		curSong = songs[curSelected];
		groupCurSelected.set(selectedGroup, curSelected);

		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		// Reset bump on song change
		bumpScale = 1.0;
		beatTimer = 0;
		musicPlaying = false;
		
		scoreText.visible = diffText.visible = speedText.visible =
			(curSong?.menuConfig?.showStats) ?? true;

		if (songs.length > 0) {
			curDiffArray = curSong.difficulties;
			changeDiff();
		}

		checkPlayMusic();
		var group = (curSelected >= 0 && curSelected < iconGroups.length)
			? iconGroups[curSelected]
			: null;

		if (group != null)
		{
			for (g in iconGroups)
			{
				for (icon in g.icons)
				{
					if (icon.animation.getByName("neutral") != null)
						icon.animation.play("neutral");
				}
			}

			for (icon in group.icons)
			{
				if (icon.animation.getByName("win") != null)
					icon.animation.play("win");
				else if (icon.animation.getByName("neutral") != null)
					icon.animation.play("neutral");
			}
		}

		var bullShit:Int = 0;

		for (item in grpSongs.members) {
			item.targetY = bullShit - curSelected;
			bullShit++;
		}

		grpSongs.members.sort(function(a, b)
		{
			var ta:DesingText = cast a;
			var tb:DesingText = cast b;

			if (ta.targetY < tb.targetY) return -1;
			if (ta.targetY > tb.targetY) return 1;
			return 0;
		});
		
		refreshIconLayers();

		canEnterSong = (curSong?.menuConfig?.canBeEntered) ?? true;

		call("changeSelectionPost", [change]);
	}

	var lastIconRefreshSelected:Int = -999;

function refreshIconLayers()
{
	if (lastIconRefreshSelected == curSelected)
		return;
	lastIconRefreshSelected = curSelected;

	var allIcons:Array<{
		icon:HealthIcon,
		groupIndex:Int
	}> = [];

	for (groupIndex in 0...iconGroups.length)
	{
		for (icon in iconGroups[groupIndex].icons)
		{
			allIcons.push({
				icon: icon,
				groupIndex: groupIndex
			});
		}
	}

	allIcons.sort(function(a, b)
	{
		var da = Math.abs(a.groupIndex - curSelected);
		var db = Math.abs(b.groupIndex - curSelected);

		if (da < db) return 1;
		if (da > db) return -1;

		if (a.icon.slot < b.icon.slot) return 1;
		if (a.icon.slot > b.icon.slot) return -1;

		return 0;
	});

	for (data in allIcons)
	{
		remove(data.icon, true);
		add(data.icon);
	}
}

function checkPlayMusic() {
	if (Options.getData("freeplayMusic") && curSong != null) {
		var nextTrack:String = Paths.inst(curSong.name, curDiffString.toLowerCase());
		if (nextTrack == currentPlayingTrack) {
			return;
		}
		if (playDelayTimer != null) {
			playDelayTimer.cancel();
		}

		// Add a small delay (0.5 seconds) before switching to the different track
		playDelayTimer = new FlxTimer().start(0.5, function(tmr:FlxTimer) {
			previewInst?.stop();

			if (FlxG.sound.music != null) {
				FlxG.sound.music.stop();
				FlxG.sound.music.destroy();
				FlxG.sound.music = null;
			}

			loadSongBPM();
			musicPlaying = true;
			beatTimer = 0;

			FlxG.sound.playMusic(nextTrack, 1.0);
			if (FlxG.sound.music != null) {
				FlxG.sound.music.pitch = curSpeed;
				FlxG.sound.music.time = FlxG.sound.music.length / 2;
			}

			currentPlayingTrack = nextTrack;
			previewTimer = 0;
			isFading = false;
		});
	}
}

function loadSongBPM():Void {
	if (curSong == null) return;
	var chart = SongLoader.loadFromJson(curDiffString.toLowerCase(), curSong.name.toLowerCase());
	if (chart != null && chart.bpm != null && chart.bpm > 0)
		currentSongBPM = chart.bpm;
}

override function destroy() {
	if (instance == this)
		instance = null;

	if (playDelayTimer != null) {
		playDelayTimer.cancel();
		playDelayTimer = null;
	}

	if (previewInst != null) {
		previewInst.stop();
		previewInst.destroy();
		previewInst = null;
	}

	if (colorTween != null) {
		colorTween.cancel();
		colorTween.destroy();
		colorTween = null;
	}

	blockedComponents.clear();
	iconGroups = [];
	intensityBoxes = [];
	menuStrs = [];

	super.destroy();
}
}