package ui;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.util.FlxTimer;
import game.Note;
import game.Conductor;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.group.FlxGroup;
import game.StrumNote;
import states.PlayState;
class ResortUI {
    public var bolts:Array<FlxSprite> = [];
    public var bolt0:FlxSprite;
    public var bolt1:FlxSprite;
    public var comboText:FlxSprite;
    public var comboNumbers:Array<FlxSprite> = [];
    public var fc:FlxSprite;
    public var canBolt:Bool = false;
    public var inCooldown:Bool = true;
    public var total:Int = 0;
    public var neverMissed:Bool = true;
    public var boltNotesSeen:Array<Float> = [];
    public var comboTimers:Array<FlxTimer> = [];
    public var numberTimers:Array<FlxTimer> = [];
    public var fcTimers:Array<FlxTimer> = [];
    public var hudCam:FlxCamera;

    public var fcFollowStrum:StrumNote = null;
    public var fcOffsetX:Float = -50;
    public var fcOffsetY:Float = -50;

    public var comboFollowStrum:StrumNote = null;
    public var comboOffsetX:Float = 50;
    public var comboOffsetY:Float = 20;

    public var numbersOffsetX:Array<Float> = [70, 98, 126];
    public var numbersOffsetY:Float = 70;


    public function new() {
    comboText = new FlxSprite();
    fc = new FlxSprite();
    comboNumbers = [];
    }
     public static function create(camHUD:FlxCamera):ResortUI {
        var ui = new ResortUI();
        ui.hudCam = camHUD;
        for (i in 0...2) {
        var bolt = new FlxSprite();
        bolt.frames = Paths.getSparrowAtlas('ui skins/Resort/arrows/bolt');
        bolt.animation.addByPrefix('zap', 'rayito', 24, false);
        bolt.setGraphicSize(Std.int(bolt.width * 0.7));
        bolt.updateHitbox();
        bolt.antialiasing = true;
        bolt.visible = false;
        bolt.flipY = Options.getData("downscroll");
        bolt.cameras = [camHUD];
        bolt.animation.finishCallback = function(name:String) {
        if (name == 'zap') bolt.visible = false;
        };
        ui.bolts.push(bolt);
        }
        ui.bolt0 = ui.bolts[0];
        ui.bolt1 = ui.bolts[1];


        ui.comboText.frames = Paths.getSparrowAtlas('ui skins/Resort/ratings/xcombo');
        ui.comboText.animation.addByPrefix('comboAppear', 'comboappear', 24, false);
        ui.comboText.animation.addByPrefix('comboDisappear', 'combodissappear', 24, false);
        ui.comboText.setGraphicSize(Std.int(ui.comboText.width * 0.725));
        ui.comboText.updateHitbox();
        ui.comboText.antialiasing = true;
        ui.comboText.visible = false;
        ui.comboText.cameras = [camHUD];

        for (i in 0...3) {
        var numSpr = new FlxSprite();
        numSpr.frames = Paths.getSparrowAtlas('ui skins/Resort/numbers/comboNumbers');
        for (j in 0...10) {
        var digit = Std.string(j);
        numSpr.animation.addByPrefix(digit, digit + "appearing", 24, false);
        numSpr.animation.addByPrefix(digit + "dissappearing", digit + "dissappearing", 24, false);
        }
        numSpr.setGraphicSize(Std.int(numSpr.width * 0.725));
        numSpr.updateHitbox();
        numSpr.antialiasing = true;
        numSpr.visible = false;
        numSpr.cameras = [camHUD];
        ui.comboNumbers.push(numSpr);
        }


        ui.fc.frames = Paths.getSparrowAtlas('ui skins/Resort/ratings/fc');
        ui.fc.animation.addByPrefix('appear', 'Fc_appear', 24, false);
        ui.fc.animation.addByPrefix('disappear', 'Fc_FuckingDIESHAHAHA', 24, false);
        ui.fc.setGraphicSize(Std.int(ui.fc.width * 0.7));
        ui.fc.updateHitbox();
        ui.fc.antialiasing = true;
        ui.fc.visible = false;
        ui.fc.cameras = [camHUD];

        PlayState.instance.timeBar.visible = false;
        PlayState.instance.timeBar.bar.visible = false;

        return ui;
    }


   

    public function flash(dir:Int, playHit:Bool, special:Bool, playerStrums:FlxTypedGroup<StrumNote>) {
        canBolt = false;
        if (playHit) {
            inCooldown = true;
            total = 0;
        }

        var strums = playerStrums.members.filter(n -> n != null);
        if (dir >= strums.length) return;
        var strum = strums[dir];

        var ds = Options.getData("downscroll");
        var mult = ds ? -1 : 1;

        var offset = strum.height * 2.5;
        var boltY = strum.y - offset * mult;

        bolt0.setPosition(strum.x + strum.width * (dir == 1 || dir == 3 ? 0.3 : -1), boltY);
        bolt0.flipX = (dir == 1 || dir == 3);
        bolt0.visible = true;
        bolt0.animation.play("zap", true);

        if (special) {
            bolt1.setPosition(strum.x + strum.width * (dir == 1 || dir == 3 ? -1 : 0.4), boltY);
            bolt1.flipX = !(dir == 1 || dir == 3);
            bolt1.visible = true;
            bolt1.animation.play("zap", true);
        }

        new FlxTimer().start(bolt0.animation.curAnim.frames.length / bolt0.animation.curAnim.frameRate, (_) -> bolt0.visible = false);
        if (special) new FlxTimer().start(bolt1.animation.curAnim.frames.length / bolt1.animation.curAnim.frameRate, (_) -> bolt1.visible = false);
    }


    public function showCombo(combo:Int, playerStrums:FlxTypedGroup<StrumNote>) {
        if (combo < 15) return;
        for (timer in comboTimers) timer.cancel();
        for (timer in numberTimers) timer.cancel();
        for (timer in fcTimers) timer.cancel();
        comboTimers = [];
        numberTimers = [];
        fcTimers = [];

        var strums:Array<StrumNote> = playerStrums.members;
        comboText.visible = true;
        comboFollowStrum = strums[3];

        if (comboText.animation.curAnim == null || comboText.animation.curAnim.name != 'comboAppear')
            comboText.animation.play('comboAppear', true);

        var appearDuration = comboText.animation.getByName('comboAppear').frames.length / comboText.animation.getByName('comboAppear').frameRate;
        var disappearDuration = comboText.animation.getByName('comboDisappear').frames.length / comboText.animation.getByName('comboDisappear').frameRate;

        var appearTimer = new FlxTimer().start(appearDuration + 0.01, (_) -> {
            comboText.animation.play('comboDisappear', true);
            var disappearTimer = new FlxTimer().start(disappearDuration, (_) -> comboText.visible = false);
            comboTimers.push(disappearTimer);
        });
        comboTimers.push(appearTimer);

        var digits = Std.string(combo).split('');
        while (digits.length < 3) digits.insert(0, '0');

        for (i in 0...3) {
            var spr = comboNumbers[i];
            var digit = digits[i];
            spr.visible = true;
           
            if (spr.animation.curAnim == null || spr.animation.curAnim.name != digit)
                spr.animation.play(digit, true);

            var digitTime = spr.animation.curAnim.frames.length / spr.animation.curAnim.frameRate;
            var t = new FlxTimer().start(digitTime + 0.01, (_) -> {
                spr.animation.play(digit + 'dissappearing', true);
                var t2 = new FlxTimer().start(digitTime, (_) -> spr.visible = false);
                numberTimers.push(t2);
            });
            numberTimers.push(t);
        }

        if (neverMissed && combo >= 15) {
                fcFollowStrum = strums[0];
                fc.visible = true;

                if (fc.animation.curAnim == null || fc.animation.curAnim.name != 'appear')
                    fc.animation.play('appear', true);


            var fcAppearDuration = fc.animation.getByName('appear').frames.length / fc.animation.getByName('appear').frameRate;
            var fcDisappearDuration = fc.animation.getByName('disappear').frames.length / fc.animation.getByName('disappear').frameRate;

            var appearTimer2 = new FlxTimer().start(fcAppearDuration + 0.01, (_) -> {
                fc.animation.play('disappear', true);
                var disappearTimer2 = new FlxTimer().start(fcDisappearDuration, (_) -> fc.visible = false);
                fcTimers.push(disappearTimer2);
            });
            fcTimers.push(appearTimer2);
        }
    }

    public function updateBolts(notes:Array<Note>, playerStrums:FlxTypedGroup<StrumNote>) {
        for (note in notes) {
            if (note != null && !note.isSustainNote && note.mustPress && !boltNotesSeen.contains(note.strumTime)) {
                boltNotesSeen.push(note.strumTime);
                var timeToHit = (Conductor.crochet / 1000) * Conductor.bpm / (15 * 2 + (Conductor.stepCrochet / 57));
                new FlxTimer().start(timeToHit, (_) -> canBolt = true);
            }
        }
    }

    public function noteHit(note:Note, combo:Int, playerStrums:FlxTypedGroup<StrumNote>) {
        if (combo > 0) showCombo(combo, playerStrums);

        if (!note.isSustainNote || combo >= 15) {
            total++;
            if (canBolt && !inCooldown && total >= 5)
                flash(note.noteData, true, FlxG.random.bool(20), playerStrums);
            inCooldown = false;
        }

        if (note.isSustainNote || note.sustainLength > 0 || bolt0.visible) {
            flash(note.noteData, false, FlxG.random.bool(15), playerStrums);
            var boltsToPlay = FlxG.random.bool(50) ? 1 : 2;
            new FlxTimer().start(0.08 * 2.5, (_) -> {
                for (i in 0...boltsToPlay) {
                    if (i < bolts.length) {
                        var bolt = bolts[i];
                        if (bolt.animation != null && bolt.animation.curAnim != null) {
                            bolt.animation.curAnim.frameRate += FlxG.random.int(-2, 2);
                            bolt.animation.play("zap", true, false);
                        }
                    }
                }
            });
        }
    }

    public function noteMiss(playerStrums:FlxTypedGroup<StrumNote>){
        comboText.animation.play("comboDisappear", true);
        new FlxTimer().start(0.5, function(t:FlxTimer) { comboText.visible = false; });

        if (neverMissed) {
            neverMissed = false;
            if (fc != null) {
                fc.animation.play('disappear', true);
                var disappearDuration = fc.animation.getByName('disappear').frames.length / fc.animation.getByName('disappear').frameRate;
                new FlxTimer().start(disappearDuration, (_) -> fc.visible = false);
            }
        }

        for (spr in comboNumbers) spr.visible = false;
    }

    public function updateScoreText(scoreTxt:FlxText, songScore:Int, misses:Int, accuracy:Float, ratingStr:String) {
        scoreTxt.setFormat(Paths.font("freeplaytext.ttf"), 20, FlxColor.WHITE, LEFT);
        scoreTxt.setBorderStyle(OUTLINE, FlxColor.BLACK, 2);
        scoreTxt.text = 
            'Score: ' + songScore + '\n' +
            'Misses: ' + misses + '\n' +
            'Accuracy: ' + Std.string(accuracy) + '%' + '\n' +
            'Rating: ' + ratingStr;
        scoreTxt.x = 20;
        scoreTxt.y = 50;

        if (hudCam != null && !scoreTxt.cameras.contains(hudCam))
    scoreTxt.cameras = [hudCam];

    }


    public function update(elapsed:Float) {
        if (fc.visible && fcFollowStrum != null) {
            fc.x = fcFollowStrum.x + fcOffsetX;
            fc.y = fcFollowStrum.y + fcOffsetY;
        }
        if (comboText.visible && comboFollowStrum != null) {

            comboText.x = comboFollowStrum.x + comboOffsetX;
            comboText.y = comboFollowStrum.y + comboOffsetY;

            for (i in 0...comboNumbers.length) {
                var num = comboNumbers[i];
                if (num.visible) {
                    num.x = comboText.x + numbersOffsetX[i];
                    num.y = comboText.y + numbersOffsetY;
                }
            }
        }
    }

}
