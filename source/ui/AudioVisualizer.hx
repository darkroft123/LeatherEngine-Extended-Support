package ui;

import flixel.group.FlxSpriteGroup;
import flixel.sound.FlxSound;
import flixel.FlxSprite;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
import system.AudioAnalyzer;

class AudioVisualizer extends FlxSpriteGroup {
    public var analyzers:Array<AudioAnalyzer> = [];
    public var sounds:Array<FlxSound> = [];
    private var analyzerLevels:Array<Array<Float>> = [];
    
    public var barCount:Int = 32;
    public var visualWidth:Float;
    public var visualHeight:Float;
    public var mode:String = "up"; // "up", "down", "both"
    public var spacing:Float = 2.0;

    private var bars:Array<FlxSprite> = [];
    private var barColors:Array<FlxColor> = [FlxColor.WHITE];

    public function new(x:Float, y:Float, sounds:Array<FlxSound>, barCount:Int = 32, width:Float = 400, height:Float = 100) {
        super(x, y);
        this.visualWidth = width;
        this.visualHeight = height;
        
        setSounds(sounds);
        setBars(barCount);
    }

    public function setSounds(newSounds:Array<FlxSound>):Void {
        this.sounds = newSounds;
        this.analyzers = [];
        this.analyzerLevels = [];
        for (snd in sounds) {
            if (snd != null) {
                this.analyzers.push(new AudioAnalyzer(snd, 2048, false));
                this.analyzerLevels.push([]); // allocate empty array for this analyzer
            }
        }
    }

    public function setBars(count:Int):Void {
        this.barCount = count;
        
        // Remove old bars
        for (bar in bars) {
            remove(bar, true);
            bar.destroy();
        }
        bars = [];
        
        if (barCount <= 0) return;
        
        var totalSpacing = spacing * (barCount - 1);
        var barWidth = (visualWidth - totalSpacing) / barCount;
        if (barWidth <= 0) barWidth = 1;

        for (i in 0...barCount) {
            var bar = new FlxSprite(i * (barWidth + spacing), 0);
            bar.makeGraphic(Std.int(barWidth), Std.int(visualHeight), FlxColor.WHITE);
            // Set origin based on mode
            if (this.mode == "down") {
                bar.origin.set(barWidth / 2, 0);
            } else if (this.mode == "both") {
                bar.origin.set(barWidth / 2, visualHeight / 2);
            } else {
                bar.origin.set(barWidth / 2, visualHeight);
            }
            bar.scale.y = 0.05; // initial scale
            
            var cIdx = i % barColors.length;
            bar.color = barColors[cIdx];
            
            add(bar);
            bars.push(bar);
        }
    }

    public function setColors(colors:Array<FlxColor>):Void {
        if (colors.length == 0) return;
        this.barColors = colors;
        
        for (i in 0...bars.length) {
            var cIdx = i % barColors.length;
            bars[i].color = barColors[cIdx];
        }
    }

    public function setMode(newMode:String):Void {
        this.mode = newMode.toLowerCase();
        for (bar in bars) {
            if (this.mode == "down") {
                bar.origin.y = 0;
            } else if (this.mode == "both") {
                bar.origin.y = visualHeight / 2;
            } else {
                bar.origin.y = visualHeight;
            }
        }
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        
        var hasActiveSound = false;
        var activeAnalyzers = 0;
        var tempLevels:Array<Float> = [];
        for (i in 0...barCount) tempLevels.push(0.0);

        for (i in 0...sounds.length) {
            var snd = sounds[i];
            var an = analyzers[i];
            if (an != null && snd != null && snd.playing) {
                hasActiveSound = true;
                activeAnalyzers++;
                analyzerLevels[i] = an.getLevels(snd.time, snd.volume, barCount, analyzerLevels[i], 0.4);
                
                var hasMath = false;
                for (j in 0...barCount) {
                    if (analyzerLevels[i][j] > 0.001) {
                        hasMath = true;
                        break;
                    }
                }
                
                if (!hasMath) {
                    // Fallback to FlxSound.amplitude if AudioAnalyzer fails due to streaming audio issues
                    var amp = snd.amplitude;
                    var ampLeft = snd.amplitudeLeft;
                    var ampRight = snd.amplitudeRight;
                    var baseAmp = (amp + ampLeft + ampRight) / 3.0;
                    
                    for (j in 0...barCount) {
                        // Generate a fake spectrum based on the raw amplitude
                        var phase = (j / barCount) * Math.PI + (snd.time / 400.0);
                        var fakeFreq = Math.abs(Math.sin(phase) * Math.cos(phase * 1.5));
                        analyzerLevels[i][j] = baseAmp * fakeFreq * 1.5;
                    }
                }

                for (j in 0...barCount) {
                    tempLevels[j] += analyzerLevels[i][j];
                }
            }
        }

        if (hasActiveSound && activeAnalyzers > 0) {
            for (j in 0...barCount) {
                var val = tempLevels[j] / activeAnalyzers;
                if (Math.isNaN(val) || !Math.isFinite(val)) val = 0;
                
                var newScale = 0.01 + (val * 0.99); 
                bars[j].scale.y = FlxMath.lerp(bars[j].scale.y, newScale, elapsed * 12);
            }
        } else {
            // Fall back to zero slowly
            for (i in 0...bars.length) {
                bars[i].scale.y -= elapsed * 2;
                if (bars[i].scale.y < 0.01) bars[i].scale.y = 0.01;
            }
        }
    }
}
