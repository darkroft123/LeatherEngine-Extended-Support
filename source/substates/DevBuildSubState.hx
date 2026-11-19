package substates;

import states.MainMenuState;
import states.MusicBeatState;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;

class DevBuildSubState extends MusicBeatState
{
    var canAccept:Bool = false;
    var enterText:FlxText;

    override function create()
    {
        super.create();

        add(new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK));

        var title:FlxText = new FlxText(0, 40, FlxG.width, "DEV BUILD", 48);
        title.setFormat(Paths.font("vcr.ttf"), 48, FlxColor.RED, CENTER);
        add(title);

        var warning:FlxText = new FlxText(0, 120, FlxG.width,
        "You are playing a DEV BUILD of the game.\nThis version may contain bugs, crashes or unfinished features.",
        32);

        warning.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER);
        add(warning);

        var rule:FlxText = new FlxText(0, FlxG.height - 400, FlxG.width,
        "DO NOT share this build with other people.\nUsing private assets without permission is NOT allowed.\nBreaking this rule may result in a PERMANENT BAN\nfrom future builds and released build.\nIf you want to use private assets, ask permission first.",
        38);

        rule.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.RED, CENTER);
        add(rule);


        enterText = new FlxText(0, FlxG.height - 100, FlxG.width, "Press ENTER to continue", 28);
        enterText.setFormat(Paths.font("vcr.ttf"), 40, FlxColor.WHITE, CENTER);
        enterText.visible = false;
        add(enterText);

        new FlxTimer().start(7, function(tmr:FlxTimer)
        {
            canAccept = true;
            enterText.visible = true;
        });
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        if (canAccept && controls.ACCEPT)
        {
            FlxG.switchState(() -> new MainMenuState());
        }
    }
}