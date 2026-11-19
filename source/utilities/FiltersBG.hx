package utilities;

import flixel.FlxSprite;

/**
 * Helper class for loading filter backgrounds.
 */
class FiltersBG {
    public static function makeBackground(enabled:Bool, filterName:String = "Filter1"):FlxSprite {
        if (!enabled) return null;
        var filter = new FlxSprite().loadGraphic(Paths.gpuBitmap('general/$filterName'));
        filter.setGraphicSize(Std.int(1280));
        filter.updateHitbox();
        filter.screenCenter();
        filter.antialiasing = true;
        filter.scrollFactor.set();
        return filter;
    }
}
