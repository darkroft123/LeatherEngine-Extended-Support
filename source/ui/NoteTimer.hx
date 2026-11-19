package ui;

import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.FlxG;
import flixel.system.FlxAssets.FlxShader;
import flixel.math.FlxMath;
import game.Conductor;
import flixel.util.FlxColor;
import flixel.text.FlxText;
import states.PlayState;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;

using flixel.util.FlxSpriteUtil;

class BarShader extends FlxShader
{
    @:glFragmentSource('
        #pragma header
        uniform float percent;

        void main()
        {
            vec2 uv = openfl_TextureCoordv;
            vec4 color = flixel_texture2D(bitmap, uv);

            float center = 0.5;
            float halfWidth = max(percent * 0.5, 0.001);

            if (uv.x < center - halfWidth || uv.x > center + halfWidth)
                discard;

            gl_FragColor = color;
        }
    ')

    public function new()
    {
        super();
    }
}

class NoteTimer extends FlxTypedSpriteGroup<FlxSprite>
{
    private var instance:PlayState;
    private var timerText:FlxText;
    private var timerBar:FlxSprite;
    private var barShader:BarShader = new BarShader();
    private var barBG:FlxSprite;
    private var skipText:FlxText;
    private var firstNoteTime:Float = 0;
    private var lastStartTime:Float = FlxMath.MAX_VALUE_FLOAT;
    public var introSkipped:Bool = false;
    private var alphaSine:Float = 0;

    public function new(instance:PlayState)
    {
        super();
        this.instance = instance;

        if (!Options.getData("noteTimer"))
        {
            introSkipped = true;
            destroy();
            return;
        }

        barBG = new FlxSprite().makeGraphic(240, 14, FlxColor.BLACK);
        barBG.antialiasing = true;
        barBG.scale.set(0.65, 1.3);
        barBG.updateHitbox();

        timerBar = new FlxSprite().makeGraphic(240, 14, FlxColor.WHITE);
        timerBar.antialiasing = true;
        timerBar.shader = barShader;
        timerBar.scale.set(0.65, 0.65);
        timerBar.updateHitbox();

        add(barBG);
        add(timerBar);

        timerText = new FlxText(0, 0, 0, "");
        timerText.setFormat(Paths.font("consola.ttf"), 22, FlxColor.WHITE, CENTER,
            FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        add(timerText);

        skipText = new FlxText(0, 0, 0, "PRESS SHIFT TO SKIP INTRO");
        skipText.setFormat(Paths.font("consola.ttf"), 40, FlxColor.WHITE, LEFT,
            FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        add(skipText);
        skipText.visible = false;
        skipText.alpha = 1;

        timerBar.alpha = 0;
        barBG.alpha = 0;
        timerText.alpha = 0;

        updatePosition();
        barShader.percent.value = [0.0];

        firstNoteTime = getClosestNote();

        if (Options.getData("skipTimer")
            && firstNoteTime != FlxMath.MAX_VALUE_FLOAT
            && firstNoteTime > 5000)
        {
            introSkipped = false;

            skipText.visible = true;
            skipText.alpha = 0;

            PlayState.instance.tweenManager.tween(skipText, {alpha: 1}, 1, {
                ease: FlxEase.cubeInOut,
                startDelay: Conductor.crochet * 0.001 * 5,
                onComplete: function(_)
                {
                    PlayState.instance.tweenManager.tween(skipText, {alpha: 0}, 1, {
                        ease: FlxEase.cubeIn,
                        startDelay: Conductor.crochet * 0.001 * 5
                    });
                }
            });
        }
        else
        {
            introSkipped = true;
            skipText.visible = false;
        }
    }

    override public function update(elapsed:Float)
    {
        if (instance == null)
            return;

        super.update(elapsed);

        var showSkipText:Bool = false;

        if (instance.inCutscene || instance.activeDialogue != null)
        {
            skipText.text = "PRESS SHIFT TO SKIP CUTSCENE";
            showSkipText = true;
        }
        else 
        {
            var timeBeforeFirstNote = firstNoteTime - Conductor.songPosition;

            if (!introSkipped)
            {
                if (timeBeforeFirstNote <= 1000)
                {
                    introSkipped = true;
                }
                else
                {
                    skipText.text = "PRESS SHIFT TO SKIP INTRO";
                    showSkipText = true;
                }
            }
        }

        skipText.visible = showSkipText;

        if (showSkipText) {
            alphaSine += elapsed * 2; 
            skipText.alpha = 0.5 + 0.5 * Math.sin(alphaSine * Math.PI); 
        } else {
            skipText.alpha = 0; 
        }

        if (FlxG.keys.justPressed.SHIFT)
        {
            if (instance.inCutscene || instance.activeDialogue != null)
            {
                instance.cutsceneAborted = true;
                PlayState.instance.tweenManager.cancelTweensOf(skipText);
                instance.clearCurrentCutscene();
                instance.startCountdown();
            }
            else if (!introSkipped && showSkipText)
            {
                skipToTime(firstNoteTime - 1000);
            }
        }

        var timeTillNextNote:Float = FlxMath.MAX_VALUE_FLOAT;
        var targetAlpha:Float = 0.0;

        if (Conductor.songPosition > 0)
        {
            for (daNote in instance.notes)
                if (daNote.mustPress)
                {
                    var timeDiff = daNote.strumTime - Conductor.songPosition;
                    if (timeDiff < timeTillNextNote)
                        timeTillNextNote = timeDiff;
                }

            if (timeTillNextNote == FlxMath.MAX_VALUE_FLOAT)
            {
                var i = instance.unspawnNotes.length - 1;
                while (i >= 0)
                {
                    var daNote = instance.unspawnNotes[i];
                    if (daNote.mustPress)
                    {
                        var timeDiff = daNote.strumTime - Conductor.songPosition;
                        if (timeDiff < timeTillNextNote)
                        {
                            timeTillNextNote = timeDiff;
                            break;
                        }
                    }
                    i--;
                }
            }

            var show:Bool = (timeTillNextNote != FlxMath.MAX_VALUE_FLOAT);

            if (show)
            {
                if (lastStartTime == FlxMath.MAX_VALUE_FLOAT && timeTillNextNote > 3000)
                    lastStartTime = timeTillNextNote;

                if (lastStartTime != FlxMath.MAX_VALUE_FLOAT)
                {
                    var secsLeft:Float = Math.ceil(timeTillNextNote * 0.001);
                    var percent:Float = FlxMath.bound(timeTillNextNote / lastStartTime, 0, 1);

                    if (percent <= 0)
                    {
                        lastStartTime = FlxMath.MAX_VALUE_FLOAT;
                        barShader.percent.value = [0.0];
                        timerText.text = "";
                        targetAlpha = 0.0;
                    }
                    else
                    {
                        barShader.percent.value = [percent];
                        timerText.text = "" + secsLeft;
                        targetAlpha = timeTillNextNote <= 1000 ? 0.0 : 1.0;
                    }

                    updatePosition();
                }
            }
            else
            {
                barShader.percent.value = [0.0];
                timerText.text = "";
                targetAlpha = 0.0;
            }

            timerText.alpha = FlxMath.lerp(timerText.alpha, targetAlpha, elapsed * 4);
            timerBar.alpha = timerText.alpha;
            barBG.alpha = timerText.alpha;
        }
    }

    function updatePosition()
    {
        skipText.x = FlxG.width - skipText.width - 80;
        skipText.y = utilities.Options.getData("downscroll")
            ? 20
            : FlxG.height - skipText.height - 20;

        timerBar.x = (FlxG.width - timerBar.width) / 2;
        timerBar.y = utilities.Options.getData("downscroll")
            ? (FlxG.height - timerBar.height - 80)
            : 80;

        barBG.x = timerBar.x;
        barBG.y = timerBar.y + (timerBar.height - barBG.height) / 2;

        timerText.x = timerBar.x + (timerBar.width - timerText.width) / 2;
        timerText.y = timerBar.y + (timerBar.height - timerText.height) / 2;
    }

    public function getClosestNote()
    {
        var t:Float = FlxMath.MAX_VALUE_FLOAT;
        for (daNote in instance.notes)
        {
            var timeDiff = daNote.strumTime;
            if (timeDiff < t)
                t = timeDiff;
        }

        if (instance.unspawnNotes.length > 0)
        {
            var timeDiff = instance.unspawnNotes[instance.unspawnNotes.length - 1].strumTime;
            if (timeDiff < t)
                t = timeDiff;
        }
        return t;
    }

    public function skipToTime(time:Float)
    {
        if (introSkipped)
            return;

        introSkipped = true;

        var ps = PlayState.instance;
        if (ps == null)
            return;

        ps.inCutscene = false;
        ps.activeDialogue = null;

        var timeDiff:Float = time - Conductor.songPosition;
        if (timeDiff <= 0)
            return;

        ps.tweenManager.cancelTweensOf(skipText);
        skipText.visible = false;
        skipText.alpha = 0;

        @:privateAccess
        if (ps.startingSong || (ps.startTimer != null && !ps.startTimer.finished))
        {
            if (ps.startTimer != null)
                ps.startTimer.cancel();
            ps.startSong();
        }

        if (PlayState.strumLineNotes != null)
        {
            for (i in 0...PlayState.strumLineNotes.length)
            {
                var babyArrow = PlayState.strumLineNotes.members[i];
                if (babyArrow != null)
                {
                    FlxTween.cancelTweensOf(babyArrow);
                    if (ps.tweenManager != null) ps.tweenManager.cancelTweensOf(babyArrow);
                    var isPlayerArrow:Bool = (PlayState.playerStrums != null && PlayState.playerStrums.members.contains(babyArrow));
                    var targetAlpha:Float = (Options.getData("middlescroll") && !isPlayerArrow) ? 0.35 : 1.0;
                    babyArrow.alpha = targetAlpha;
                    if (@:privateAccess ps.strumLine != null)
                        babyArrow.y = @:privateAccess ps.strumLine.y - (babyArrow.height / 2);
                    babyArrow.visible = true;
                }
            }
        }

        @:privateAccess ps.clearNotesBefore(time);
        @:privateAccess ps.setSongTime(time);

        @:privateAccess
        while (ps.events.length > 0 && ps.events[0][1] + Conductor.offset <= time)
        {
            ps.processEvent(ps.events.shift());
        }

        var oldStep = ps.curStep;
        var newStep = Math.floor(time / Conductor.stepCrochet);
        if (newStep > oldStep)
        {
            for (i in (oldStep + 1)...(newStep + 1))
            {
                ps.curStep = i;
                ps.updateBeat();
                ps.stepHit();
            }
        }

        var delta:Float = timeDiff * 0.001;
        try {
            if (ps.tweenManager != null) ps.tweenManager.update(delta);
        } catch(e:Dynamic) {}
        try {
            flixel.util.FlxTimer.globalManager.update(delta);
        } catch(e:Dynamic) {}
        for (camera in FlxG.cameras.list)
        {
            if (camera != null)
                @:privateAccess camera.updateFade(delta);
        }

        FlxG.camera.flash(FlxColor.WHITE, 0.4);
    }
}