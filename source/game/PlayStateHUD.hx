package game;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.ui.FlxBar;
import flixel.util.FlxColor;
import flixel.util.FlxStringUtil;
import openfl.utils.Assets;
import states.PlayState;
import ui.HealthIcon;
import ui.ResortUI;
import game.Character;
import game.HealthBarStyle;
import game.TimeBar;
import game.SongLoader.SongData;
import utilities.CoolUtil;
import utilities.Options;
import Paths;

using StringTools;

/**
 * Modular HUD component for PlayState.
 * Encapsulates the health bar, health icons, score texts, time bar, died indicator,
 * and skin elements while maintaining 100% backwards compatibility with scripts and instances.
 */
class PlayStateHUD extends FlxGroup {

    public var state:PlayState;

    public var healthBarBG:FlxSprite;
    public var healthBar:FlxBar;
    public var healthBarStyleData:HealthBarStyle;
    public var iconP1:Array<HealthIcon> = [];
    public var iconP2:Array<HealthIcon> = [];

    public var scoreTxt:FlxText;
    public var accText:FlxText;
    public var ratingSuffix:FlxText;
    public var rankTxt:FlxText;

    public var timeBar:TimeBar;
    public var diedTxt:FlxText;
    public var ratingText:FlxText;
    public var resortUI:ResortUI;
    public var isResortSkin:Bool = false;

    public function new(state:PlayState, camera:FlxCamera, song:SongData, storyDifficultyStr:String) {
        super();
        this.state = state;
        this.camera = camera;
        this.cameras = [camera];

        isResortSkin = (song != null && song.ui_Skin == "resort");

        var healthBarPosY:Float = FlxG.height * 0.9;
        if (Options.getData("downscroll"))
            healthBarPosY = 60;

        // Health Bar Background
        var uiSkin = (song != null && song.ui_Skin != null) ? song.ui_Skin : "default";
        var healthBarPath:String = Assets.exists(Paths.image('ui skins/${uiSkin}/other/healthBar')) ? 'ui skins/${uiSkin}/other/healthBar' : 'ui skins/default/other/healthBar';
        healthBarBG = new FlxSprite(0, healthBarPosY).loadGraphic(Paths.gpuBitmap(healthBarPath));
        healthBarBG.screenCenter(X);
        healthBarBG.scrollFactor.set();
        healthBarBG.pixelPerfectPosition = true;
        healthBarBG.cameras = [camera];
        add(healthBarBG);

        // Health Bar
        var minH:Float = state != null ? state.minHealth : 0;
        var maxH:Float = state != null ? state.maxHealth : 2;
        healthBar = new FlxBar(healthBarBG.x + 4, healthBarBG.y + 4, RIGHT_TO_LEFT, Std.int(healthBarBG.width - 8), Std.int(healthBarBG.height - 8), state,
            'healthShown', minH, maxH);
        healthBar.scrollFactor.set();
        healthBar.pixelPerfectPosition = true;
        healthBar.cameras = [camera];

        healthBarStyleData = new HealthBarStyle();
        healthBarStyleData.style = Options.getData("healthBarStyle");
        if (PlayState.dad != null && PlayState.boyfriend != null)
            healthBarStyleData.apply(healthBar, PlayState.dad.barColor, PlayState.boyfriend.barColor);

        add(healthBar);
        healthBar.visible = healthBarBG.visible = Options.getData('healthBar');

        // Health Icons
        iconP1 = [];
        iconP2 = [];
        if (Options.getData("healthIcons")) {
            if (PlayState.boyfriend != null) {
                for (iconName in getHealthIcons(PlayState.boyfriend))
                    iconP1.push(createIcon(iconName, true));
            }
            if (PlayState.dad != null) {
                for (iconName in getHealthIcons(PlayState.dad))
                    iconP2.push(createIcon(iconName, false));
            }
        }

        // Score Text Elements
        scoreTxt = new FlxText(0, healthBarBG.y + 45, 0, "");
        accText = new FlxText(0, healthBarBG.y + 45, 0, "");
        ratingSuffix = new FlxText(0, healthBarBG.y + 45, 0, "");
        rankTxt = new FlxText(0, healthBarBG.y + 45, 0, "");

        var biggerScore = Options.getData("biggerScoreInfo");
        var texts = [scoreTxt, accText, ratingSuffix, rankTxt];
        for (txt in texts) {
            txt.screenCenter(X);
            txt.setFormat(
                Paths.font("vcr.ttf"),
                biggerScore ? 20 : 16,
                FlxColor.WHITE, CENTER,
                FlxTextBorderStyle.OUTLINE_FAST,
                FlxColor.BLACK
            );
            txt.scrollFactor.set();
            txt.cameras = [camera];
            if (biggerScore) txt.borderSize = 1.25;
            add(txt);
        }

        // Time Bar
        if (song != null) {
            timeBar = new TimeBar(song, storyDifficultyStr);
            timeBar.cameras = [camera];
            add(timeBar);

            diedTxt = new FlxText(0, 0, 0, "(DIED)", timeBar.text.size);
            diedTxt.setFormat(timeBar.text.font, timeBar.text.size, FlxColor.RED, LEFT, FlxTextBorderStyle.OUTLINE_FAST, FlxColor.BLACK);
            diedTxt.borderSize = timeBar.text.borderSize;
            diedTxt.cameras = [camera];
            diedTxt.scrollFactor.set();
            diedTxt.visible = false;
            diedTxt.alpha = timeBar.text.alpha;
            add(diedTxt);

            updateTime(0, song.song, storyDifficultyStr, Options.getData("timeBarStyle"), PlayState.diedInNoDeath);
        }

        // Side Ratings
        if (Options.getData("sideRatings")) {
            ratingText = new FlxText(4, 0, 0, "");
            ratingText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE_FAST, FlxColor.BLACK);
            ratingText.screenCenter(Y);
            var off = Options.getData("ratingTextOffset");
            if (off != null && off.length > 1) {
                ratingText.x += off[0];
                ratingText.y += off[1];
            }
            ratingText.alignment = Options.getData("ratingTextAlign");
            ratingText.scrollFactor.set();
            ratingText.cameras = [camera];
            add(ratingText);
        }

        // Resort Skin UI
        if (isResortSkin) {
            resortUI = ResortUI.create(camera);
            add(resortUI.bolt0);
            add(resortUI.bolt1);
            add(resortUI.comboText);
            for (spr in resortUI.comboNumbers) add(spr);
            add(resortUI.fc);
        }
    }

    public function createIcon(charIcon:String, isPlayer:Bool):HealthIcon {
        var icon = new HealthIcon(charIcon, isPlayer);
        if (healthBar != null)
            icon.y = healthBar.y - (icon.height / 2) - icon.offsetY;
        icon.cameras = [camera];
        add(icon);
        return icon;
    }

    public static function getHealthIcons(char:Character):Array<String> {
        if (char == null) return ["face"];
        if (char.config == null || char.config.healthIcon == null)
            return [char.icon];

        if (Std.isOfType(char.config.healthIcon, Array))
            return cast char.config.healthIcon;

        return [cast char.config.healthIcon];
    }

    public static function getIconData(char:Character, index:Int):Dynamic {
        if (char == null || char.config == null || char.config.icons == null || index >= char.config.icons.length)
            return null;

        return char.config.icons[index];
    }

    public static function getIconOffset(char:Character, index:Int):{x:Float, y:Float} {
        var data = getIconData(char, index);

        var offX:Float = (data != null && data.offset != null && data.offset.length > 0) ? data.offset[0] : 0;
        var offY:Float = (data != null && data.offset != null && data.offset.length > 1) ? data.offset[1] : 0;

        return {x: offX, y: offY};
    }

    public function refreshIcons(char:Character, isPlayer:Bool):Void {
        var iconList = getHealthIcons(char);

        var oldArray:Array<HealthIcon> = isPlayer ? iconP1 : iconP2;
        var oldMain:HealthIcon = (oldArray != null && oldArray.length > 0) ? oldArray[0] : null;

        var newIcons:Array<HealthIcon> = [];
        for (i in 0...iconList.length) {
            var icon = createIcon(iconList[i], isPlayer);
            if (oldMain != null) {
                icon.visible = oldMain.visible;
                icon.alpha = oldMain.alpha;
                icon.cameras = oldMain.cameras;
                icon.x = oldMain.x;
                icon.y = oldMain.y;
                icon.angle = oldMain.angle;
            }
            newIcons.push(icon);
        }

        if (oldArray != null) {
            for (icon in oldArray) {
                if (icon != null) {
                    FlxTween.cancelTweensOf(icon);
                    if (icon.scale != null) FlxTween.cancelTweensOf(icon.scale);
                    remove(icon);
                    icon.destroy();
                }
            }
        }

        if (isPlayer)
            iconP1 = newIcons;
        else
            iconP2 = newIcons;
    }

    public function updateIcons(elapsed:Float, dad:Character, boyfriend:Character, songMultiplier:Float):Void {
        if (!Options.getData("healthIcons"))
            return;

        if (iconP1 == null || iconP2 == null || iconP1.length == 0 || iconP2.length == 0)
            return;

        var mainP1 = iconP1[0];
        var mainP2 = iconP2[0];

        if (mainP1 == null || mainP2 == null)
            return;

        var iconLerp = elapsed * 9 * songMultiplier;

        var maxScaleP1 = mainP1.startSize * 1.2;
        var maxScaleP2 = mainP2.startSize * 1.2;

        var prevScaleP1X = mainP1.scale.x;
        var prevScaleP1Y = mainP1.scale.y;
        var prevScaleP2X = mainP2.scale.x;
        var prevScaleP2Y = mainP2.scale.y;

        mainP1.scale.set(
            Math.min(FlxMath.lerp(mainP1.scale.x, mainP1.startSize, iconLerp), maxScaleP1),
            Math.min(FlxMath.lerp(mainP1.scale.y, mainP1.startSize, iconLerp), maxScaleP1)
        );

        mainP2.scale.set(
            Math.min(FlxMath.lerp(mainP2.scale.x, mainP2.startSize, iconLerp), maxScaleP2),
            Math.min(FlxMath.lerp(mainP2.scale.y, mainP2.startSize, iconLerp), maxScaleP2)
        );

        if (mainP1.scale.x != prevScaleP1X || mainP1.scale.y != prevScaleP1Y)
            mainP1.updateHitbox();
        if (mainP2.scale.x != prevScaleP2X || mainP2.scale.y != prevScaleP2Y)
            mainP2.updateHitbox();

        if (healthBar == null) return;

        var iconOffset = 26.0;
        var healthPercent = FlxMath.remapToRange(healthBar.percent, 0, 100, 100, 0) * 0.01;
        var iconX = healthBar.x + healthBar.width * healthPercent;

        var animP1 = "neutral";
        var animP2 = "neutral";

        if (healthBar.percent <= 20) {
            animP1 = "lose";
            animP2 = "win";
        } else if (healthBar.percent >= 80) {
            animP1 = "win";
            animP2 = "lose";
        }

        if (mainP1.animation != null && (mainP1.animation.curAnim == null || mainP1.animation.curAnim.name != animP1))
            mainP1.animation.play(animP1);

        if (mainP2.animation != null && (mainP2.animation.curAnim == null || mainP2.animation.curAnim.name != animP2))
            mainP2.animation.play(animP2);

        updateMainIcon(mainP1, boyfriend, iconX, iconOffset, true);
        updateMainIcon(mainP2, dad, iconX, iconOffset, false);

        updateIconGroup(iconP1, boyfriend, animP1, true);
        updateIconGroup(iconP2, dad, animP2, false);
    }

    private function updateMainIcon(icon:HealthIcon, char:Character, iconX:Float, iconOffset:Float, isPlayer:Bool):Void {
        if (icon == null || char == null || healthBar == null)
            return;

        var off = getIconOffset(char, 0);

        if (Options.getData("downscroll"))
            off.y = -off.y;

        if (isPlayer)
            off.x = -off.x;

        if (isPlayer)
            icon.x = iconX - iconOffset - icon.offsetX + off.x;
        else
            icon.x = iconX - (icon.width - iconOffset) - icon.offsetX + off.x;

        icon.y = healthBar.y - (icon.height * 0.5) + (healthBar.height * 0.5) + off.y;
    }

    private function updateIconGroup(group:Array<HealthIcon>, char:Character, anim:String, isPlayer:Bool):Void {
        if (group == null || group.length == 0 || char == null)
            return;

        var main = group[0];
        if (main == null)
            return;

        var isDownscroll:Bool = Options.getData("downscroll");
        var baseCenterX = main.x + main.width * 0.5;
        var baseCenterY = main.y + main.height * 0.5;

        for (i in 1...group.length) {
            var icon = group[i];
            if (icon == null)
                continue;

            var off = getIconOffset(char, i);

            if (isDownscroll)
                off.y = -off.y;

            if (isPlayer)
                off.x = -off.x;

            icon.startSize = main.startSize;
            icon.flipX = main.flipX;
            icon.flipY = main.flipY;

            if (icon.frameWidth > 0 && icon.frameHeight > 0) {
                icon.scale.set(
                    main.width / icon.frameWidth,
                    main.height / icon.frameHeight
                );
            }

            icon.updateHitbox();

            if (icon.animation != null && (icon.animation.curAnim == null || icon.animation.curAnim.name != anim))
                icon.animation.play(anim);

            icon.x = baseCenterX - (icon.width * 0.5) + off.x + icon.offsetX;
            icon.y = baseCenterY - (icon.height * 0.5) + off.y + icon.offsetY;
        }
    }

    public function bopIcons():Void {
        if (iconP1 != null) {
            for (icon in iconP1) {
                if (icon != null) {
                    icon.scale.add(0.2 * icon.startSize, 0.2 * icon.startSize);
                }
            }
        }
        if (iconP2 != null) {
            for (icon in iconP2) {
                if (icon != null) {
                    icon.scale.add(0.2 * icon.startSize, 0.2 * icon.startSize);
                }
            }
        }
    }

    public function updateScore(songScore:Int, misses:Int, accuracy:Float, ratingStr:String):Void {
        if (isResortSkin && resortUI != null) {
            resortUI.updateScoreText(scoreTxt, songScore, misses, accuracy, ratingStr);
            return;
        }
        if (scoreTxt == null) return;

        scoreTxt.text = 'SCORE: ${songScore} | MISSES: ${misses} | ACCURACY: ';
        accText.text = '${accuracy}%';
        rankTxt.text = "| RANK:";
        ratingSuffix.text = ratingStr;

        var t = if (accuracy <= 25) accuracy / 25.0 
                else if (accuracy <= 75) (accuracy - 25.0)/50.0 
                else (accuracy - 75.0)/25.0;

        var dynamicColor = if (accuracy <= 25) FlxColor.interpolate(FlxColor.RED, FlxColor.ORANGE, t)
                        else if (accuracy <= 75) FlxColor.interpolate(FlxColor.ORANGE, FlxColor.YELLOW, t)
                        else FlxColor.interpolate(FlxColor.YELLOW, FlxColor.CYAN, t);

        accText.color = dynamicColor;
        ratingSuffix.color = dynamicColor;
        scoreTxt.screenCenter(X);
        scoreTxt.x -= 100;
        accText.x = scoreTxt.x + scoreTxt.width;
        rankTxt.x = accText.x + accText.width;
        ratingSuffix.x = rankTxt.x + rankTxt.width;
    }

    public function updateHealthBarStyle(elapsed:Float, dad:Character, boyfriend:Character, mustHit:Bool):Void {
        if (healthBarStyleData != null && healthBar != null && dad != null && boyfriend != null) {
            if (healthBarStyleData.style == "by type") {
                healthBarStyleData.updateByType(healthBar, elapsed, dad.barColor, boyfriend.barColor, mustHit);
            }
        }
    }

    public function applyHealthBarStyle(dad:Character, boyfriend:Character, curSection:Int, mustHit:Bool):Void {
        if (healthBar == null || healthBarStyleData == null || dad == null || boyfriend == null) return;
        healthBarStyleData.apply(healthBar, dad.barColor, boyfriend.barColor, curSection, mustHit);
    }

    public function updateTime(timeSeconds:Float, songTitle:String, diffStr:String, timeBarStyle:String, diedInNoDeath:Bool):Void {
        if (timeBar == null || timeBar.text == null) return;

        var seconds:Float = Math.max(0, timeSeconds);
        var suffix:String = (Options.getData("botplay") ? " (BOT)" : "") + (Options.getData("noDeath") ? " (NO DEATH)" : "");

        switch ((timeBarStyle != null ? timeBarStyle : "").toLowerCase()) {
            default: // includes 'leather engine'
                timeBar.text.text = songTitle + " ~ " + diffStr + ' (${FlxStringUtil.formatTime(seconds, false)})$suffix';
            case "psych engine":
                timeBar.text.text = '${FlxStringUtil.formatTime(seconds, false)}$suffix';
            case "old kade engine", "kade engine":
                timeBar.text.text = songTitle + suffix;
        }
        timeBar.text.screenCenter(X);

        if (diedTxt != null && timeBar != null && timeBar.text != null) {
            if (diedInNoDeath && Options.getData("noDeath") && timeBar.visible && timeBar.text.visible) {
                diedTxt.visible = true;
                diedTxt.x = timeBar.text.x + timeBar.text.width + 6;
                diedTxt.y = timeBar.text.y;
                diedTxt.alpha = timeBar.text.alpha;
            } else {
                diedTxt.visible = false;
            }
        }
    }

    override public function destroy():Void {
        if (iconP1 != null) {
            for (icon in iconP1) {
                if (icon != null) {
                    FlxTween.cancelTweensOf(icon);
                    if (icon.scale != null) FlxTween.cancelTweensOf(icon.scale);
                }
            }
        }
        if (iconP2 != null) {
            for (icon in iconP2) {
                if (icon != null) {
                    FlxTween.cancelTweensOf(icon);
                    if (icon.scale != null) FlxTween.cancelTweensOf(icon.scale);
                }
            }
        }
        super.destroy();
    }
}
