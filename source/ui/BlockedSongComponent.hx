package ui;

import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import game.FreeplaySong;
import utilities.DevList;
import flixel.FlxG;

class BlockedSongComponent extends FlxTypedSpriteGroup<FlxSprite>
{
    public static final authoritativeBlockedSongs:Array<String> = [];

    public var outerBorder:FlxSprite;
    public var innerBorder:FlxSprite;
    public var overlay:FlxSprite;
    public var notAvailableText:FlxText;
    public var song:FreeplaySong;
    public var isSongBlocked(default, null):Bool = false;

    public function new(song:FreeplaySong)
    {
        super();
        this.song = song;
        this.visible = false;
        this.isSongBlocked = checkBlockedStatus(song);
        if (isSongBlocked)
        {
            outerBorder = new FlxSprite().makeGraphic(1, 1, 0xFF00FFD2);
            outerBorder.scrollFactor.set(0, 0);
            outerBorder.visible = false;
            add(outerBorder);

            innerBorder = new FlxSprite().makeGraphic(1, 1, 0xFF120024);
            innerBorder.scrollFactor.set(0, 0);
            innerBorder.visible = false;
            add(innerBorder);

            overlay = new FlxSprite().makeGraphic(1, 1, 0xFF0A0A10);
            overlay.scrollFactor.set(0, 0);
            overlay.visible = false;
            add(overlay);

            notAvailableText = new FlxText(0, 0, 0, "NOT AVAILABLE");
            notAvailableText.setFormat("Ethnocentric-Regular.otf", 32, FlxColor.WHITE, CENTER, flixel.text.FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
            notAvailableText.borderSize = 3;
            notAvailableText.angle = 0;
            notAvailableText.scrollFactor.set(0, 0);
            notAvailableText.visible = false;
            add(notAvailableText);
        }
    }

    public static function checkBlockedStatus(song:FreeplaySong):Bool
    {
        if (song == null) return false;
        if (utilities.DevList.isCurrentUserDev()) return false;

        var isBlockedByJson:Bool = (Reflect.field(song, "isBlocked") == true);
        return isBlockedByJson || authoritativeBlockedSongs.contains(song.name.toLowerCase());
    }
    
    /**
     * Position and scale the blocked overlay elements relative to the song card.
     */
    public function updateLayout(x:Float, y:Float, textW:Float, textH:Float, scale:Float, alpha:Float, icons:Array<HealthIcon>):Void
    {
        if (!isSongBlocked)
        {
            this.visible = false;
            return;
        }

        if (alpha <= 0.001)
        {
            this.visible = false;
            if (outerBorder != null) outerBorder.visible = false;
            if (innerBorder != null) innerBorder.visible = false;
            if (overlay != null) overlay.visible = false;
            if (notAvailableText != null) notAvailableText.visible = false;
            return;
        }
        
        // Hide standard health icons for the blocked song entry
        if (icons != null)
        {
            for (icon in icons)
            {
                icon.visible = false;
                icon.alpha = 0;
            }
        }
        
        var overlayX = x - 15;
        var overlayW = FlxG.width - overlayX;
        
        var boxHeight = textH * 0.85;
        var boxY = y + 5;

        outerBorder.x = overlayX - 3;
        outerBorder.y = boxY - 3;
        outerBorder.scale.set(overlayW + 6, boxHeight + 6);
        outerBorder.updateHitbox();
        outerBorder.alpha = alpha * 0.15;
        outerBorder.visible = true;

        innerBorder.x = overlayX - 1;
        innerBorder.y = boxY - 1;
        innerBorder.scale.set(overlayW + 2, boxHeight + 2);
        innerBorder.updateHitbox();
        innerBorder.alpha = alpha * 0.5;
        innerBorder.visible = true;

        overlay.x = overlayX;
        overlay.y = boxY;
        overlay.scale.set(overlayW, boxHeight);
        overlay.updateHitbox();
        overlay.alpha = alpha * 0.6;
        overlay.visible = true;
        
        notAvailableText.alpha = alpha;
        notAvailableText.fieldWidth = overlayW;
        notAvailableText.x = overlay.x;
        notAvailableText.y = overlay.y + (boxHeight - notAvailableText.height) / 2;
        notAvailableText.visible = true;

        this.visible = true;
    }
}