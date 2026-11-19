package ui;

import flixel.FlxG;
import flixel.math.FlxMath;
import openfl.Lib;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.text.TextField;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFormat;
import openfl.utils.Assets;
import external.memory.Memory;
#if cpp
import cpp.vm.Gc;
#end
import ui.logs.Logs;
import utilities.CoolUtil;
import utilities.DevList;
import utilities.Options;
import macros.GithubCommitHash;

using StringTools;

/**
 * Modern info and framerate display.
 * Features bold FPS with baseline-aligned 'FPS' label,
 * real-time GC/RSS memory indicators, engine version and git hash,
 * with full support for compact/small sizes and 100% transparent background.
 */
class SimpleInfoDisplay extends Sprite {

    public var infoDisplayed:Array<Bool> = [false, false, false, false, false, false];
    public var framerate:Int = 0;
    public var version:String = CoolUtil.getCurrentVersion();
    public var discordUserName:String = "";

    // Support for compact/small sizes
    public var fpsSize:Int = 16;
    public var smallSize:Int = 10;

    // Line 1: FPS Counter
    public var fpsGroup:Sprite;
    public var fpsNum:TextField;
    public var fpsLabel:TextField;
    public var lastFPS:Float = 60.0;
    private var frameCount:Int = 0;
    private var accumulatedTime:Float = 0;
    private var lastFrameTime:Float = 0;
    private var lastUpdateTime:Float = 0;
    private final updateInterval:Float = 1.0 / 15.0;
    private final history:Array<Float> = [];

    // Line 2: Memory Counter
    public var memoryGroup:Sprite;
    public var memoryText:TextField;
    public var memoryPeakText:TextField;

    // Line 3: Build & Commit
    public var buildGroup:Sprite;
    public var versionText:TextField;
    public var commitText:TextField;

    // Line 4: Logs
    public var logsText:TextField;

    // Line 5: User / Role Profile
    public var userText:TextField;

    // Formatting & Font
    private var _fontName:String = "_sans";
    private var _textColor:Int = 0xFFFFFF;
    private var tfFps:TextFormat;
    private var tfSmall:TextFormat;

    public var textColor(get, set):Int;
    private inline function get_textColor():Int return _textColor;
    private function set_textColor(value:Int):Int {
        _textColor = value;
        reloadFormats();
        return value;
    }

    public var defaultTextFormat(get, set):TextFormat;
    private function get_defaultTextFormat():TextFormat {
        return new TextFormat(_fontName, smallSize, _textColor);
    }
    private function set_defaultTextFormat(value:TextFormat):TextFormat {
        if (value != null) {
            if (value.font != null) _fontName = value.font;
            if (value.color != null) _textColor = value.color;
            if (value.size != null && value.size > 0) {
                smallSize = value.size;
                fpsSize = Math.round(value.size * 1.6);
            }
            reloadFormats();
        }
        return value;
    }

    /**
     * Changes display font sizes dynamically (supports small / compact sizes).
     */
    public function setSizes(fps:Int, small:Int):Void {
        fpsSize = fps;
        smallSize = small;
        reloadFormats();
    }

    @:isVar public var text(get, set):String;
    private function get_text():String {
        var sb = new StringBuf();
        if (infoDisplayed[0]) sb.add(fpsNum.text + fpsLabel.text + "\n");
        if (infoDisplayed[1]) sb.add(memoryText.text + memoryPeakText.text + "\n");
        if (infoDisplayed[2]) sb.add(versionText.text + commitText.text + "\n");
        return sb.toString();
    }
    private function set_text(v:String):String {
        return v;
    }

    public function setTextFormat(format:TextFormat, beginIndex:Int = -1, endIndex:Int = -1):Void {
        // Compatibility stub for external callers
    }

    public static function getGcHeapUsage():Float {
        #if cpp
        return Gc.memInfo64(Gc.MEM_INFO_USAGE);
        #else
        return 0;
        #end
    }

    public static function formatMemory(bytes:Float):String {
        var rSize:Float = bytes;
        var label:Int = 0;
        var labels = ["B", "KB", "MB", "GB", "TB"];
        while (rSize >= 1024 && label < labels.length - 1) {
            label++;
            rSize /= 1024;
        }
        if (label <= 0) return Std.int(rSize) + " B";
        var decimal = Std.int((rSize % 1) * 100);
        var decStr = (decimal < 10 ? "0" : "") + decimal;
        return Std.int(rSize) + "." + decStr + " " + labels[label];
    }

    private static function resolveFont(?font:String):String {
        if (font != null && font != "" && font != "_sans") {
            return font;
        }
        try {
            if (Assets.exists(Paths.font("consola.ttf"))) {
                return Assets.getFont(Paths.font("consola.ttf")).fontName;
            }
        } catch (e:Dynamic) {}
        #if windows
        var winConsolas = Sys.getEnv("windir") + "\\Fonts\\consola.ttf";
        if (sys.FileSystem.exists(winConsolas)) {
            return winConsolas;
        }
        #end
        return "_sans";
    }

    public function new(x:Float = 10, y:Float = 10, color:Int = 0xFFFFFF, ?font:String) {
        super();

        this.x = x;
        this.y = y;
        this._textColor = color;
        this._fontName = resolveFont(font);

        // Pre-fill history with current target framerate so reading is stable immediately
        var initialFps:Float = (Lib.current.stage != null) ? Lib.current.stage.frameRate : 60.0;
        lastFPS = initialFps;
        framerate = Math.round(initialFps);
        for (i in 0...15) history.push(initialFps);

        // Line 1: FPS Counter (bold number + baseline-aligned label)
        fpsGroup = new Sprite();
        fpsNum = createTextField(fpsSize, _textColor, 1.0, true);
        fpsLabel = createTextField(smallSize, _textColor, 1.0, false);

        fpsNum.text = Std.string(framerate);
        fpsLabel.text = " FPS";

        fpsGroup.addChild(fpsNum);
        fpsGroup.addChild(fpsLabel);
        addChild(fpsGroup);

        // Line 2: Memory Counter (GC heap + 0.5 alpha OS working set)
        memoryGroup = new Sprite();
        memoryText = createTextField(smallSize, _textColor, 1.0, false);
        memoryPeakText = createTextField(smallSize, _textColor, 0.5, false);

        memoryText.text = "0 MB";
        memoryPeakText.text = " | 0 MB";

        memoryGroup.addChild(memoryText);
        memoryGroup.addChild(memoryPeakText);
        addChild(memoryGroup);

        // Line 3: Build & Commit
        buildGroup = new Sprite();
        versionText = createTextField(smallSize, _textColor, 1.0, false);
        commitText = createTextField(smallSize, _textColor, 0.5, false);

        versionText.text = "DC V3.5";
        commitText.text = "";

        buildGroup.addChild(versionText);
        buildGroup.addChild(commitText);
        addChild(buildGroup);

        // Line 4: Logs
        logsText = createTextField(smallSize, _textColor, 0.6, false);
        logsText.visible = false;
        addChild(logsText);

        // Line 5: User Profile
        userText = createTextField(smallSize, _textColor, 1.0, false);
        userText.visible = false;
        addChild(userText);

        reloadFormats();
        addEventListener(Event.ENTER_FRAME, onEnterFrame);
    }

    private function createTextField(size:Int, color:Int, alphaVal:Float = 1.0, bold:Bool = false):TextField {
        var tf = new TextField();
        tf.autoSize = TextFieldAutoSize.LEFT;
        tf.multiline = false;
        tf.wordWrap = false;
        tf.selectable = false;
        tf.defaultTextFormat = new TextFormat(_fontName, size, color, bold);
        tf.alpha = alphaVal;
        return tf;
    }

    public function reloadFormats():Void {
        tfFps = new TextFormat(_fontName, fpsSize, _textColor, true);
        tfSmall = new TextFormat(_fontName, smallSize, _textColor, false);

        if (fpsNum != null) {
            fpsNum.defaultTextFormat = tfFps;
            fpsNum.setTextFormat(tfFps);
        }

        for (tf in [fpsLabel, memoryText, memoryPeakText, versionText, commitText, logsText, userText]) {
            if (tf != null) {
                tf.defaultTextFormat = tfSmall;
                tf.setTextFormat(tfSmall);
            }
        }

        if (memoryPeakText != null) memoryPeakText.alpha = 0.5;
        if (commitText != null) commitText.alpha = 0.5;
        if (logsText != null) logsText.alpha = 0.6;
    }

    private function onEnterFrame(e:Event):Void {
        updateDisplay();
    }

    public function update():Void {
        updateDisplay();
    }

    public function updateDisplay():Void {
        if (!visible || alpha < 0.05) return;

        var timer = Lib.getTimer();
        if (accumulatedTime == 0) accumulatedTime = timer;
        if (lastFrameTime == 0) lastFrameTime = timer;

        var frameDeltaMs = timer - lastFrameTime;
        lastFrameTime = timer;

        frameCount++;
        lastUpdateTime += (frameDeltaMs / 1000.0);

        var shouldUpdateNumbers = (lastUpdateTime >= updateInterval);

        if (shouldUpdateNumbers) {
            var delta = timer - accumulatedTime;
            accumulatedTime = timer;

            history.shift();
            var instantFPS = (delta <= 0) ? 0.0 : (1000.0 / delta * frameCount);
            lastFPS = FlxMath.lerp(lastFPS, instantFPS, 1.0 - Math.pow(0.75, delta * 0.06));
            history.push(lastFPS);

            framerate = Math.round(lastFPS);
            fpsNum.text = Std.string(framerate);
            fpsLabel.text = " FPS";

            lastUpdateTime = 0;
            frameCount = 0;
        }

        var currentY:Float = 0;

        // --- Line 1: FPS Counter ---
        var showFps = infoDisplayed[0];
        fpsGroup.visible = showFps;
        if (showFps) {
            fpsNum.x = 0;
            fpsNum.y = 0;

            fpsLabel.x = fpsNum.x + fpsNum.width;
            fpsLabel.y = (fpsNum.y + fpsNum.height) - fpsLabel.height;

            fpsGroup.y = currentY;
            currentY += fpsNum.height;
        }

        // --- Line 2: Memory Counter ---
        var showMem = infoDisplayed[1];
        memoryGroup.visible = showMem;
        if (showMem) {
            if (shouldUpdateNumbers) {
                var gcMem = getGcHeapUsage();
                var osMem = Memory.getCurrentUsage();

                memoryText.text = formatMemory(gcMem);
                memoryPeakText.text = ' | ' + formatMemory(osMem);
            }

            memoryText.x = 0;
            memoryText.y = 0;

            memoryPeakText.x = memoryText.x + memoryText.width;
            memoryPeakText.y = 0;

            memoryGroup.y = currentY;
            currentY += memoryText.height;
        }

        // --- Line 3: Build & Commit ---
        var showVers = infoDisplayed[2];
        var showCommit = infoDisplayed[4];
        buildGroup.visible = (showVers || showCommit);

        if (buildGroup.visible) {
            versionText.visible = showVers;
            commitText.visible = showCommit;

            var curX:Float = 0;
            if (showVers) {
                var vStr = version != null ? version : "";
                versionText.text = "DC V3.5" + (vStr.startsWith(" -") ? vStr : (vStr.length > 0 ? " " + vStr : ""));
                versionText.x = curX;
                versionText.y = 0;
                curX += versionText.width;
            }

            if (showCommit) {
                var rawHash = GithubCommitHash.getGitCommitHash();
                var hash = (rawHash != null && rawHash.length > 7) ? rawHash.substring(0, 7) : (rawHash != null ? rawHash : "");
                if (showVers) {
                    commitText.text = ' (' + hash + ')';
                    commitText.x = curX;
                    commitText.y = 0;
                    curX += commitText.width;
                } else {
                    commitText.text = 'Commit (' + hash + ')';
                    commitText.x = 0;
                    commitText.y = 0;
                    curX = commitText.width;
                }
            }

            buildGroup.y = currentY;
            var lineH = showVers ? versionText.height : commitText.height;
            currentY += lineH;
        }

        // --- Line 4: Logs / Errors ---
        var showLogs = infoDisplayed[3];
        var hasLogs = (Main.logsOverlay != null && Main.logsOverlay.logs != null && Main.logsOverlay.logs.length > 0) || Logs.errors > 0;
        logsText.visible = showLogs && hasLogs;
        if (logsText.visible) {
            var logCount = (Main.logsOverlay != null && Main.logsOverlay.logs != null) ? Main.logsOverlay.logs.length : 0;
            var logInfo = "";
            if (logCount > 0) logInfo += '${logCount} traced lines';
            if (Logs.errors > 0) {
                if (logInfo.length > 0) logInfo += " | ";
                logInfo += '${Logs.errors} errors';
            }
            if (logCount > 0) logInfo += ". F3 to view.";
            logsText.text = logInfo;
            logsText.x = 0;
            logsText.y = currentY;

            currentY += logsText.height;
        }

        // --- Line 5: User Profile ---
        var showUser = infoDisplayed[5];
        userText.visible = showUser;
        if (showUser) {
            var username = Options.isLogged() ? Options.currentUser : "";
            if (username == null || username == "") {
                userText.text = "NOT LOGGED";
                userText.textColor = 0xFFFFFF;
                userText.alpha = 0.5;
            } else {
                var dev = DevList.getByName(username);
                if (dev != null) {
                    var role = (dev.roles != null && dev.roles.length > 0) ? dev.roles[0].toUpperCase() : "USER";
                    userText.text = '[${role}] ${username}';
                    userText.textColor = dev.color;
                    userText.alpha = 1.0;
                } else {
                    userText.text = '[USER] ${username}';
                    userText.textColor = 0xFFFFFF;
                    userText.alpha = 1.0;
                }
            }
            userText.x = 0;
            userText.y = currentY;

            currentY += userText.height;
        }
    }
}
